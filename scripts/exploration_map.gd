extends Control

signal map_changed(map_id: String)
signal naming_required

@onready var _background: ColorRect = %Background
@onready var _map_title: Label = %MapTitle
@onready var _hotspots: Control = %Hotspots

var _map_id: String = ""
var _last_knot: String = ""
var _encounter_pending: bool = false


func _ready() -> void:
	DialogueManager.encounter_triggered.connect(func() -> void: _encounter_pending = true)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)


func load_map(map_id: String) -> void:
	_map_id = map_id
	var data: Dictionary = MapRegistry.get_map(map_id)
	_background.color = data.get("bg_color", Color.BLACK)
	_map_title.text = data.get("display_name", map_id)
	_build_hotspots(data.get("hotspots", []))
	map_changed.emit(map_id)


func _build_hotspots(hotspots: Array) -> void:
	for child in _hotspots.get_children():
		child.queue_free()
	for hs in hotspots:
		var rect: Array = hs["rect"]
		var zone := Control.new()
		zone.set_anchors_preset(Control.PRESET_TOP_LEFT)
		zone.anchor_left = rect[0]
		zone.anchor_top = rect[1]
		zone.anchor_right = rect[0] + rect[2]
		zone.anchor_bottom = rect[1] + rect[3]
		zone.offset_left = 0
		zone.offset_top = 0
		zone.offset_right = 0
		zone.offset_bottom = 0
		zone.mouse_filter = Control.MOUSE_FILTER_STOP
		zone.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		zone.tooltip_text = hs.get("label", "Interact")
		var highlight := ColorRect.new()
		highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
		highlight.color = Color(0.9, 0.85, 0.5, 0.12)
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zone.add_child(highlight)
		var label := Label.new()
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.text = hs.get("label", "")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zone.add_child(label)
		zone.gui_input.connect(_on_hotspot_gui_input.bind(hs, highlight, zone))
		zone.mouse_entered.connect(func() -> void: highlight.color = Color(0.9, 0.85, 0.5, 0.28))
		zone.mouse_exited.connect(func() -> void: highlight.color = Color(0.9, 0.85, 0.5, 0.12))
		_hotspots.add_child(zone)


func _on_hotspot_gui_input(event: InputEvent, hs: Dictionary, highlight: ColorRect, zone: Control) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if not GameState.exploration_enabled:
		return
	if DialogueManager.is_active:
		# Don't stack actions — finish or skip current line first.
		DialogueManager.advance()
		get_viewport().set_input_as_handled()
		return
	zone.accept_event()
	_flash_hotspot(highlight)
	_on_hotspot_pressed(hs)


func _flash_hotspot(highlight: ColorRect) -> void:
	var tween := create_tween()
	highlight.color = Color(1, 0.95, 0.7, 0.55)
	tween.tween_property(highlight, "color", Color(0.9, 0.85, 0.5, 0.12), 0.35)


func _on_hotspot_pressed(hs: Dictionary) -> void:
	get_viewport().gui_release_focus()
	if not GameState.has_flag("tutorial_seen_click"):
		GameState.set_flag("tutorial_seen_click")
	_last_knot = hs.get("knot", "")
	match hs.get("type", "examine"):
		"pickup":
			_handle_pickup(hs)
		"door":
			_handle_door(hs)
		"paper":
			_handle_paper(hs)
		"exit":
			_handle_exit(hs)
		_:
			_start_knot(hs.get("knot", ""))


func _handle_pickup(hs: Dictionary) -> void:
	var hid: String = hs["id"]
	if GameState.is_hotspot_consumed(_map_id, hid):
		_start_knot(hs.get("empty_knot", ""))
		return
	var item_id: String = hs.get("item_id", "")
	if GameState.has_item(item_id):
		_start_knot(hs.get("empty_knot", ""))
		return
	_start_knot(hs.get("knot", ""))
	GameState.add_item(item_id)
	GameState.consume_hotspot(_map_id, hid)
	if GameState.needs_mandatory_naming():
		naming_required.emit()


func _handle_door(hs: Dictionary) -> void:
	if not GameState.has_item("keycard"):
		_start_knot(hs.get("knot_locked", ""))
		return
	if GameState.needs_mandatory_naming():
		_start_knot(hs.get("knot_need_name", ""))
		return
	_last_knot = hs.get("knot_exit", "")
	_start_knot(_last_knot)


func _handle_paper(hs: Dictionary) -> void:
	var paper_id: String = hs.get("paper_id", "")
	if GameState.has_read_paper(paper_id):
		_start_knot(hs.get("empty_knot", ""))
		return
	_last_knot = hs.get("knot", "")
	_start_knot(_last_knot)


func _handle_exit(hs: Dictionary) -> void:
	GameState.current_map_id = hs.get("target_map", _map_id)
	_start_knot(hs.get("knot", ""))


func _on_dialogue_ended() -> void:
	get_viewport().gui_release_focus()
	if _map_id == "archives" and _last_knot == "archives_exit":
		GameState.leave_archives()
		load_map("hall_papers")
		return
	if _last_knot == "paper_middle" or _last_knot.begins_with("paper_"):
		var hs_id := _hotspot_id_for_knot(_last_knot)
		if not hs_id.is_empty():
			var paper_id := _paper_id_from_knot(_last_knot)
			if not paper_id.is_empty():
				GameState.mark_paper_read(paper_id)
				GameState.consume_hotspot(_map_id, hs_id)
	if _encounter_pending and not GameState.has_flag("scp1_encounter_done"):
		_encounter_pending = false
		GameState.set_flag("scp1_encounter_done")
		_start_knot("scp1_encounter")
		return
	if _last_knot == "hall_return_archives":
		load_map(GameState.current_map_id)


func _start_knot(knot_id: String) -> void:
	if knot_id.is_empty():
		return
	_last_knot = knot_id
	DialogueManager.start_knot(knot_id)


func _hotspot_id_for_knot(knot: String) -> String:
	for hs in MapRegistry.get_map(_map_id).get("hotspots", []):
		if hs.get("knot") == knot:
			return hs.get("id", "")
	return ""


func _paper_id_from_knot(knot: String) -> String:
	match knot:
		"paper_left":
			return "left"
		"paper_middle":
			return "middle"
		"paper_right":
			return "right"
	return ""
