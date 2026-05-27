extends Node

signal line_shown(speaker: String, text: String)
signal dialogue_started
signal dialogue_ended
signal choices_requested(options: Array)
signal encounter_triggered

var is_active: bool = false
var _knots: Dictionary = {}
var _current_knot: String = ""
var _line_index: int = 0
var _pending_encounter: bool = false
var _last_speaker: String = ""
var _last_text: String = ""


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
	var next_knot: String = choice.get("next", "")
	if next_knot.is_empty():
		_end_dialogue()
	else:
		start_knot(next_knot)


func _show_current_line() -> void:
	var knot: Dictionary = _knots[_current_knot]
	var lines: Array = knot.get("lines", [])
	if _line_index >= lines.size():
		_end_dialogue()
		return
	var entry: Dictionary = lines[_line_index]
	var tags: Array = entry.get("tags", [])
	for tag in tags:
		var tag_str: String = str(tag)
		if tag_str == "trigger:scp1_encounter" and not GameState.has_flag("scp1_encounter_done"):
			_pending_encounter = true
			encounter_triggered.emit()
	var text: String = _substitute(str(entry.get("text", "")))
	var speaker: String = str(entry.get("speaker", ""))
	_last_speaker = speaker
	_last_text = text
	line_shown.emit(speaker, text)
	if _pending_encounter and _line_index == lines.size() - 1:
		_pending_encounter = false


func _format_choices(raw: Array) -> Array:
	var formatted: Array = []
	for choice in raw:
		var c: Dictionary = choice
		var label: String = _substitute(str(c.get("text", "Continue")))
		var disabled: bool = false
		if c.has("requires_flag") and not GameState.has_flag(str(c["requires_flag"])):
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
	if choice.has("clear_flag"):
		GameState.set_flag(str(choice["clear_flag"]), false)


func _substitute(text: String) -> String:
	return text.replace("{player_name}", GameState.display_name())


func _end_dialogue() -> void:
	is_active = false
	_current_knot = ""
	_line_index = 0
	dialogue_ended.emit()
