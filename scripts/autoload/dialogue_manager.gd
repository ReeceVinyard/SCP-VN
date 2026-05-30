extends Node

const _CharacterRegistry = preload("res://scripts/data/character_registry.gd")

signal line_shown(speaker: String, text: String)
signal map_character_mood_changed(character: String, mood: String)
signal character_presence_fade_in(overlay_key: String, duration_sec: float)
signal screen_shake_requested(strength: String)
signal dialogue_started
signal dialogue_ended(ended_knot: String)
signal choices_requested(options: Array)
signal post_choice_reaction(reaction: Dictionary)
signal encounter_triggered

var is_active: bool = false
var _knots: Dictionary = {}
var _current_knot: String = ""
var _line_index: int = 0
var _pending_encounter: bool = false
var _last_speaker: String = ""
var _last_text: String = ""
var _pending_next_knot: String = ""
var _pending_reaction: Dictionary = {}


func get_current_knot() -> String:
	return _current_knot


func get_last_speaker() -> String:
	return _last_speaker


func _ready() -> void:
	_load_story()


func _load_story() -> void:
	var path := "res://story/story.json"
	if not FileAccess.file_exists(path):
		push_error("Missing story.json at %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("story.json must be a JSON object")
		return
	_knots = parsed.get("knots", {})


func start_knot(knot_id: String) -> void:
	if not _knots.has(knot_id):
		push_warning("Unknown knot: %s" % knot_id)
		return
	is_active = true
	_current_knot = knot_id
	_line_index = 0
	_pending_encounter = false
	_last_speaker = ""
	_last_text = ""
	dialogue_started.emit()
	_show_current_line()


func advance() -> void:
	if not is_active:
		return
	var knot: Dictionary = _knots[_current_knot]
	var lines: Array = knot.get("lines", [])
	if _line_index < lines.size() - 1:
		_line_index += 1
		_show_current_line()
		return
	if knot.has("choices"):
		choices_requested.emit(_format_choices(knot["choices"]))
		return
	_end_dialogue()


func choose(index: int) -> void:
	if not is_active:
		return
	var knot: Dictionary = _knots[_current_knot]
	var choices: Array = knot.get("choices", [])
	if index < 0 or index >= choices.size():
		return
	var choice: Dictionary = choices[index]
	_apply_choice_effects(choice)
	_refresh_chase_map_presence_after_choice(choice)
	var next_knot: String = str(choice.get("next", ""))
	var reaction: Variant = choice.get("reaction", {})
	if typeof(reaction) == TYPE_DICTIONARY and not reaction.is_empty():
		_pending_next_knot = next_knot
		_pending_reaction = reaction.duplicate()
		post_choice_reaction.emit(reaction)
		return
	_continue_after_choice(next_knot)


func continue_after_reaction() -> void:
	_continue_after_choice(_pending_next_knot)
	_pending_next_knot = ""
	_pending_reaction = {}


func _continue_after_choice(next_knot: String) -> void:
	if next_knot.is_empty():
		_end_dialogue()
	else:
		start_knot(next_knot)


func capture_save_data() -> Dictionary:
	if not is_active or _current_knot.is_empty():
		return {"active": false}
	var knot: Dictionary = _knots.get(_current_knot, {})
	var lines: Array = knot.get("lines", [])
	var awaiting_choices := false
	if not _pending_reaction.is_empty():
		awaiting_choices = false
	elif knot.has("choices") and not lines.is_empty():
		awaiting_choices = _line_index >= lines.size() - 1
	return {
		"active": true,
		"knot_id": _current_knot,
		"line_index": _line_index,
		"awaiting_choices": awaiting_choices,
		"pending_next_knot": _pending_next_knot,
		"pending_reaction": _pending_reaction.duplicate(),
	}


func restore_from_save(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not bool(data.get("active", false)):
		return false
	var knot_id := str(data.get("knot_id", ""))
	if knot_id.is_empty() or not _knots.has(knot_id):
		return false
	is_active = true
	_current_knot = knot_id
	_line_index = maxi(0, int(data.get("line_index", 0)))
	_pending_next_knot = str(data.get("pending_next_knot", ""))
	_pending_reaction = {}
	var raw_reaction: Variant = data.get("pending_reaction", {})
	if typeof(raw_reaction) == TYPE_DICTIONARY:
		_pending_reaction = raw_reaction.duplicate()
	_pending_encounter = false
	dialogue_started.emit()
	if not _pending_reaction.is_empty():
		post_choice_reaction.emit(_pending_reaction)
		return true
	var knot: Dictionary = _knots[_current_knot]
	var lines: Array = knot.get("lines", [])
	if lines.is_empty():
		_end_dialogue()
		return false
	if _line_index >= lines.size():
		_line_index = lines.size() - 1
	_show_current_line(true)
	if bool(data.get("awaiting_choices", false)) and knot.has("choices"):
		choices_requested.emit(_format_choices(knot["choices"]))
	return true


func _show_current_line(skip_story_tags: bool = false) -> void:
	var knot: Dictionary = _knots[_current_knot]
	var lines: Array = knot.get("lines", [])
	if _line_index >= lines.size():
		_end_dialogue()
		return
	var entry: Dictionary = lines[_line_index]
	var tags: Array = entry.get("tags", [])
	if not skip_story_tags:
		for tag in tags:
			var tag_str: String = str(tag)
			if tag_str.begins_with("trigger:"):
				var encounter_id := tag_str.substr(8)
				if encounter_id == "chase_encounter" and not GameState.has_flag("chase_encounter_done"):
					_pending_encounter = true
					encounter_triggered.emit()
			elif tag_str.begins_with("shake:"):
				screen_shake_requested.emit(tag_str.substr(6))
			elif tag_str == "show_chase" or tag_str.begins_with("show_chase:"):
				var fade_sec := 2.0
				if tag_str.contains(":"):
					fade_sec = float(tag_str.substr(11))
				GameState.set_flag("chase_at_door_visible")
				character_presence_fade_in.emit("chase_at_door", fade_sec)
			elif tag_str.begins_with("memory:"):
				GameState.unlock_memory_fragment(tag_str.substr(7))
	var text: String = _substitute(str(entry.get("text", "")))
	var speaker: String = str(entry.get("speaker", ""))
	var portrait: String = str(entry.get("portrait", ""))
	_last_speaker = speaker
	_last_text = text
	line_shown.emit(speaker, text)
	if speaker == "Chase" and not GameState.has_flag("chase_first_line_spoken"):
		GameState.set_flag("chase_first_line_spoken")
	_emit_portrait(speaker, portrait)


func _format_choices(raw: Array) -> Array:
	var formatted: Array = []
	for choice in raw:
		var c: Dictionary = choice
		var label: String = _substitute(str(c.get("text", "Continue")))
		var disabled: bool = false
		if c.has("requires_flag") and not GameState.has_flag(str(c["requires_flag"])):
			disabled = true
		if c.has("disabled_if_flag") and GameState.has_flag(str(c["disabled_if_flag"])):
			disabled = true
		if c.has("requires_any_flags"):
			var any_ok := false
			for f in c["requires_any_flags"]:
				if GameState.has_flag(str(f)):
					any_ok = true
					break
			if not any_ok:
				disabled = true
		if c.has("requires_item") and not GameState.has_item(str(c["requires_item"])):
			disabled = true
		formatted.append({"text": label, "disabled": disabled, "index": formatted.size()})
	return formatted


func _apply_choice_effects(choice: Dictionary) -> void:
	if choice.has("set_flag"):
		var f := str(choice["set_flag"])
		GameState.set_flag(f)
		if f == "scp1_befriended":
			GameState.set_flag("scp1_hostile", false)
		if f == "scp1_hostile":
			GameState.set_flag("scp1_befriended", false)
		if f == "chase_told_amnesia":
			GameState.set_flag("chase_lied_keycard", false)
		if f == "chase_lied_keycard":
			GameState.set_flag("chase_told_amnesia", false)
	if choice.has("clear_flag"):
		GameState.set_flag(str(choice["clear_flag"]), false)


func _refresh_chase_map_presence_after_choice(choice: Dictionary) -> void:
	if _CharacterRegistry.active_chase_presence_key(GameState.current_map_id).is_empty():
		return
	var mood := "normal"
	if GameState.has_flag("chase_lied_keycard"):
		mood = "angry"
	else:
		var reaction: Variant = choice.get("reaction", {})
		if typeof(reaction) == TYPE_DICTIONARY and str(reaction.get("npc", "")) == "Chase":
			mood = _CharacterRegistry.reaction_mood_to_map_mood(str(reaction.get("mood", "")))
	map_character_mood_changed.emit("Chase", mood)


func _emit_portrait(speaker: String, line_portrait: String) -> void:
	if speaker.is_empty() or not _CharacterRegistry.has_character(speaker):
		return
	var mood := line_portrait
	if mood.is_empty():
		mood = _CharacterRegistry.resolve_chase_mood_for_dialogue(_current_knot, "")
		if speaker != "Chase":
			mood = "normal"
	var presence_key := _CharacterRegistry.active_chase_presence_key(GameState.current_map_id)
	if speaker == "Chase" and not presence_key.is_empty():
		map_character_mood_changed.emit(speaker, mood)


func _substitute(text: String) -> String:
	return text.replace("{player_name}", GameState.display_name())


func force_end() -> void:
	if not is_active:
		_pending_next_knot = ""
		_pending_reaction = {}
		return
	_pending_encounter = false
	_pending_next_knot = ""
	_pending_reaction = {}
	_end_dialogue()


func _end_dialogue() -> void:
	var ended_knot := _current_knot
	is_active = false
	_current_knot = ""
	_line_index = 0
	_pending_encounter = false
	dialogue_ended.emit(ended_knot)
