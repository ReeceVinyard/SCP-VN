extends Control

const MapAspectWrapperScript := preload("res://scripts/maps/map_aspect_wrapper.gd")
const _CharacterRegistry = preload("res://scripts/data/character_registry.gd")

signal map_changed(map_id: String)
signal naming_required
signal document_requested(item_id: String, grant_item_on_close: bool)

@onready var _bg_color: ColorRect = %BackgroundColor
@onready var _bg_image: TextureRect = %BackgroundImage
@onready var _map_title: Label = %MapTitle
@onready var _map_host: Control = %MapHost
@onready var _hotspots: Control = %Hotspots

var _map_id: String = ""
var _last_knot: String = ""
var _encounter_pending: bool = false
var _scene_hotspot_zones: Array = []
var _pending_pickup: Dictionary = {}
var _restore_chase_visible: bool = false

const CHASE_DOOR_BEAT_BEFORE_DIALOGUE_SEC := 0.75
const CHASE_PRESENCE_FADE_SEC := 2.0
const MAP_TRANSITION_FADE_OUT_SEC := 0.7
const MAP_TRANSITION_HOLD_SEC := 0.2
const MAP_TRANSITION_FADE_IN_SEC := 0.95
const CHASE_ESCORT_OVERLAY_KEY := "chase_with_player"
const CHASE_BRIEFING_CENTER_OVERLAY_KEY := "chase_briefing_center"
const CHASE_GUIDE_KNOTS := ["chase_guide_gentle", "chase_guide_harsh"]
const CORRIDOR_BRIEFING_KNOTS := ["corridor3_chase_briefing_gentle", "corridor3_chase_briefing_harsh"]
const CORRIDOR_QUESTIONS_KNOT := "corridor3_questions"
const CORRIDOR_QA_KNOTS := ["corridor3_questions", "corridor3_q_evac", "corridor3_q_work", "corridor3_q_exit"]

var _corridor_transition_running: bool = false


func _ready() -> void:
	add_to_group("exploration_map")
	DialogueManager.encounter_triggered.connect(func() -> void: _encounter_pending = true)
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	if not GameState.exploration_enabled_changed.is_connected(_on_exploration_enabled_changed):
		GameState.exploration_enabled_changed.connect(_on_exploration_enabled_changed)


func capture_save_data() -> Dictionary:
	var pending: Dictionary = {}
	if not _pending_pickup.is_empty():
		pending = _pending_pickup.duplicate(true)
	# Persist the map the player is actually standing in (not a pre-transition target).
	GameState.current_map_id = _map_id
	var chase_shown := _capture_chase_presence_shown()
	return {
		"pending_pickup": pending,
		"map_id": _map_id,
		"chase_presence_shown": chase_shown,
	}


func apply_save_data(data: Variant) -> void:
	var payload: Dictionary = data if typeof(data) == TYPE_DICTIONARY else {}
	_pending_pickup = {}
	var raw_pending: Variant = payload.get("pending_pickup", {})
	if typeof(raw_pending) == TYPE_DICTIONARY:
		_pending_pickup = raw_pending.duplicate(true)
	_encounter_pending = false
	_last_knot = ""
	var chase_shown: Variant = payload.get("chase_presence_shown", payload.get("chase_at_door_shown", {}))
	_apply_chase_presence_shown_save(chase_shown)
	var saved_map := str(payload.get("map_id", ""))
	if saved_map.is_empty():
		saved_map = GameState.current_map_id
	GameState.current_map_id = saved_map
	load_map(saved_map)
	call_deferred("_sync_world_after_load_async")


func load_map(map_id: String) -> void:
	_map_id = map_id
	GameState.current_map_id = map_id
	_clear_map()
	var data: Dictionary = MapRegistry.get_map(map_id)
	_map_title.text = data.get("display_name", map_id)

	if data.has("scene"):
		_load_scene_map(data["scene"])
	else:
		_load_legacy_map(data)

	map_changed.emit(map_id)


func _clear_map() -> void:
	for child in _map_host.get_children():
		child.queue_free()
	for child in _hotspots.get_children():
		child.queue_free()
	_scene_hotspot_zones.clear()
	_hotspots.visible = false
	_map_host.visible = false
	_bg_color.visible = true
	_bg_image.visible = false


func _load_scene_map(scene_path: String) -> void:
	_bg_color.visible = false
	_bg_image.visible = false
	_map_host.visible = true
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("Missing map scene: %s" % scene_path)
		_bg_color.visible = true
		return
	var instance: Node = packed.instantiate()
	var wrapper := Control.new()
	wrapper.set_script(MapAspectWrapperScript)
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_host.add_child(wrapper)
	wrapper.host_map(instance)
	_connect_scene_hotspots(instance)


func _load_legacy_map(data: Dictionary) -> void:
	_bg_color.color = data.get("bg_color", Color.BLACK)
	var texture_path: String = data.get("bg_texture", "")
	if texture_path.is_empty():
		_bg_image.texture = null
		_bg_image.visible = false
	else:
		_bg_image.texture = load(texture_path) as Texture2D
		_bg_image.visible = _bg_image.texture != null
	_hotspots.visible = true
	_build_hotspots(data.get("hotspots", []))


func _connect_scene_hotspots(root: Node) -> void:
	_scene_hotspot_zones = _find_hotspot_zones(root)
	for zone in _scene_hotspot_zones:
		if zone.pressed_zone.is_connected(_on_scene_hotspot_pressed):
			continue
		zone.pressed_zone.connect(_on_scene_hotspot_pressed)


func _find_hotspot_zones(node: Node) -> Array:
	var found: Array = []
	if node is HotspotZone:
		found.append(node)
	for child in node.get_children():
		found.append_array(_find_hotspot_zones(child))
	return found


func try_handle_map_click(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton):
		return false
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return false
	var pos := get_viewport().get_mouse_position()
	for i in range(_scene_hotspot_zones.size() - 1, -1, -1):
		var zone: HotspotZone = _scene_hotspot_zones[i] as HotspotZone
		if zone == null or not is_instance_valid(zone):
			continue
		if zone.contains_global_point(pos):
			_on_scene_hotspot_pressed(zone)
			return true
	return false


func _on_scene_hotspot_pressed(zone: HotspotZone) -> void:
	if DialogueManager.is_active:
		DialogueManager.advance()
		return
	if not GameState.exploration_enabled:
		return
	zone.flash_click()
	var hs: Dictionary = zone.to_dictionary()
	if hs.get("id", "") == "door_r_far" and GameState.has_flag("chase_ready_to_leave"):
		hs["type"] = "exit"
		hs["target_map"] = "corridor_forward"
		hs["knot"] = "hall_forward_enter"
		hs["use_map_transition"] = true
	_on_hotspot_pressed(hs)


func _build_hotspots(hotspots: Array) -> void:
	for hs in hotspots:
		var rect: Array = hs["rect"]
		var zone := Control.new()
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
	if DialogueManager.is_active:
		DialogueManager.advance()
		return
	if not GameState.exploration_enabled:
		return
	zone.accept_event()
	var tween := create_tween()
	highlight.color = Color(1, 0.95, 0.7, 0.55)
	tween.tween_property(highlight, "color", Color(0.9, 0.85, 0.5, 0.12), 0.35)
	_on_hotspot_pressed(hs)


func _on_hotspot_pressed(hs: Dictionary) -> void:
	get_viewport().gui_release_focus()
	if not GameState.has_flag("tutorial_seen_click"):
		GameState.set_flag("tutorial_seen_click")
	_last_knot = hs.get("knot", "")
	if hs.get("id", "") == "door_r_far":
		if GameState.has_flag("chase_ready_to_leave"):
			_launch_corridor_forward_transition(_briefing_knot_for_door())
			return
		if GameState.has_flag("hall_door_r_far_open"):
			return
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
	_pending_pickup = hs.duplicate()
	GameState.add_item(item_id)


func complete_pending_pickup() -> void:
	if _pending_pickup.is_empty():
		return
	var hs := _pending_pickup
	_pending_pickup = {}
	var hid: String = hs.get("id", "")
	GameState.consume_hotspot(_map_id, hid)
	_last_knot = hs.get("knot", "")
	_start_knot(_last_knot)
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
	if hs.get("use_map_transition", false) and hs.get("target_map", "") == "corridor_forward":
		var briefing := str(hs.get("knot", ""))
		if briefing == "hall_forward_enter":
			briefing = "corridor3_chase_briefing_harsh" if GameState.has_flag("chase_lied_keycard") else "corridor3_chase_briefing_gentle"
		_launch_corridor_forward_transition(briefing)
		return
	GameState.current_map_id = hs.get("target_map", _map_id)
	_start_knot(hs.get("knot", ""))


func _enable_free_exploration() -> void:
	GameState.enable_exploration()


func _on_exploration_enabled_changed(enabled: bool) -> void:
	if enabled:
		_sync_chase_presence()


func _on_dialogue_started() -> void:
	_last_knot = DialogueManager.get_current_knot()
	if _last_knot in CHASE_GUIDE_KNOTS:
		GameState.set_flag("chase_ready_to_leave")


func _on_dialogue_ended(ended_knot: String) -> void:
	get_viewport().gui_release_focus()
	var knot := ended_knot if not ended_knot.is_empty() else _last_knot
	if _map_id == "archives" and knot == "archives_exit":
		GameState.leave_archives()
		load_map("hall_papers")
		return
	if knot == "paper_middle":
		var hs_id := _hotspot_id_for_knot("paper_middle")
		if not hs_id.is_empty():
			GameState.mark_paper_read("middle")
			GameState.consume_hotspot(_map_id, hs_id)
		if not GameState.has_flag("eh_14_read"):
			document_requested.emit("eh_14", true)
		elif not GameState.has_flag("chase_sequence_started"):
			begin_chase_sequence()
		return
	if knot in ["paper_left", "paper_right"]:
		var hs_id := _hotspot_id_for_knot(knot)
		if not hs_id.is_empty():
			var paper_id := _paper_id_from_knot(knot)
			if not paper_id.is_empty():
				GameState.mark_paper_read(paper_id)
				GameState.consume_hotspot(_map_id, hs_id)
		return
	if knot == "chase_arrival":
		call_deferred("_start_knot", "chase_evacuation")
		return
	if knot in CHASE_GUIDE_KNOTS:
		GameState.set_flag("chase_ready_to_leave")
		_launch_corridor_forward_transition(_briefing_knot_for_guide(knot))
		return
	if knot in CORRIDOR_BRIEFING_KNOTS:
		call_deferred("_start_knot", CORRIDOR_QUESTIONS_KNOT)
		return
	if knot in CORRIDOR_QA_KNOTS:
		_enable_free_exploration()
		call_deferred("_show_side_escort_after_briefing")
		return
	if knot == "hall_forward_enter":
		_launch_corridor_forward_transition(_briefing_knot_for_door())
		return
	if knot == "hall_return_archives":
		load_map(GameState.current_map_id)
		return
	if knot == "corridor_return_hall":
		load_map(GameState.current_map_id)
	call_deferred("_reconcile_exploration_after_dialogue", knot)


func _briefing_knot_for_guide(guide_knot: String) -> String:
	if guide_knot == "chase_guide_harsh":
		return "corridor3_chase_briefing_harsh"
	return "corridor3_chase_briefing_gentle"


func _briefing_knot_for_door() -> String:
	if GameState.has_flag("chase_lied_keycard"):
		return "corridor3_chase_briefing_harsh"
	return "corridor3_chase_briefing_gentle"


func _launch_corridor_forward_transition(briefing_knot: String) -> void:
	if briefing_knot.is_empty() or _corridor_transition_running:
		return
	_corridor_transition_running = true
	_run_corridor_forward_transition_async(briefing_knot)


func _run_corridor_forward_transition_async(briefing_knot: String) -> void:
	var map_before := _map_id
	await _run_corridor_forward_transition(briefing_knot)
	_corridor_transition_running = false
	if _map_id == map_before and map_before == "hall_papers" and GameState.has_flag("chase_ready_to_leave"):
		if not DialogueManager.is_active:
			GameState.enable_exploration()


func _run_corridor_forward_transition(briefing_knot: String) -> void:
	if not is_inside_tree():
		return
	GameState.set_flag("chase_ready_to_leave")
	GameState.disable_exploration()
	var transition := _get_map_transition()
	if transition:
		await transition.fade_to_black(MAP_TRANSITION_FADE_OUT_SEC, MAP_TRANSITION_HOLD_SEC)
	if not is_inside_tree():
		return
	GameState.set_flag("chase_at_door_visible", false)
	GameState.set_flag("chase_escort_visible", false)
	GameState.set_flag("chase_briefing_center_visible", false)
	load_map("corridor_forward")
	GameState.set_flag("corridor_forward_seen")
	await get_tree().process_frame
	_refresh_map_overlays()
	if transition:
		await transition.fade_from_black(MAP_TRANSITION_FADE_IN_SEC)
	if not is_inside_tree():
		return
	# Chase briefs the player centered (like the previous corridor) before exploration begins.
	GameState.set_flag("chase_briefing_center_visible")
	_show_chase_presence(CHASE_BRIEFING_CENTER_OVERLAY_KEY, CHASE_PRESENCE_FADE_SEC)
	_start_knot(briefing_knot)


func _get_map_transition() -> Node:
	var nodes := get_tree().get_nodes_in_group("map_transition")
	if nodes.is_empty():
		return null
	return nodes[0]


func _show_side_escort_after_briefing() -> void:
	if not is_inside_tree():
		return
	# Fade the large centered Chase fully out first, then fade the small side escort in.
	var center_zone := _find_character_presence_zone(CHASE_BRIEFING_CENTER_OVERLAY_KEY)
	if center_zone:
		await center_zone.hide_with_fade(CHASE_PRESENCE_FADE_SEC)
	GameState.set_flag("chase_briefing_center_visible", false)
	if not is_inside_tree():
		return
	GameState.set_flag("chase_escort_visible")
	await _show_chase_presence(CHASE_ESCORT_OVERLAY_KEY, CHASE_PRESENCE_FADE_SEC)


func _show_chase_presence(overlay_key: String, duration_sec: float) -> void:
	var zone := _find_character_presence_zone(overlay_key)
	if zone == null:
		DialogueManager.character_presence_fade_in.emit(overlay_key, duration_sec)
		return
	await zone.show_with_fade(duration_sec)


func _find_character_presence_zone(overlay_key: String) -> CharacterPresenceZone:
	for child in _map_host.get_children():
		var zone := _find_presence_in_node(child, overlay_key)
		if zone != null:
			return zone
	return null


func _find_presence_in_node(node: Node, overlay_key: String) -> CharacterPresenceZone:
	var layer := node.get_node_or_null("InteractableOverlays")
	if layer:
		for child in layer.get_children():
			if child is CharacterPresenceZone and (child as CharacterPresenceZone).overlay_key == overlay_key:
				return child as CharacterPresenceZone
	for child in node.get_children():
		var found := _find_presence_in_node(child, overlay_key)
		if found != null:
			return found
	return null


func sync_world_after_load() -> void:
	_sync_chase_presence()
	_refresh_map_overlays()
	_sync_chase_presence()


func _sync_world_after_load_async() -> void:
	await get_tree().process_frame
	sync_world_after_load()
	await get_tree().process_frame
	_sync_chase_presence()
	_restore_chase_visible = false


func _capture_chase_presence_shown() -> Dictionary:
	var out := {"chase_at_door": false, "chase_with_player": false, "chase_briefing_center": false}
	for overlay_key in out.keys():
		var zone := _find_character_presence_zone(overlay_key)
		if zone and zone.is_present_visible():
			out[overlay_key] = true
			var flag := _CharacterRegistry.chase_presence_flag(overlay_key)
			if not flag.is_empty():
				GameState.set_flag(flag)
	return out


func _apply_chase_presence_shown_save(data: Variant) -> void:
	_restore_chase_visible = false
	if typeof(data) != TYPE_DICTIONARY:
		if bool(data):
			_restore_chase_visible = true
			GameState.set_flag("chase_at_door_visible")
		return
	if bool(data.get("chase_at_door", false)):
		GameState.set_flag("chase_at_door_visible")
	if bool(data.get("chase_with_player", false)):
		GameState.set_flag("chase_escort_visible")
	if bool(data.get("chase_briefing_center", false)):
		GameState.set_flag("chase_briefing_center_visible")
	_restore_chase_visible = (
		GameState.has_flag("chase_at_door_visible")
		or GameState.has_flag("chase_escort_visible")
		or GameState.has_flag("chase_briefing_center_visible")
	)


func _sync_chase_presence() -> void:
	for overlay_key in _CharacterRegistry.PRESENCE_OVERLAY_KEYS.get(_map_id, []):
		if not _CharacterRegistry.is_chase_presence_visible(overlay_key):
			continue
		var zone := _find_character_presence_zone(overlay_key)
		if zone:
			zone.sync_presence_from_flags()


func _reconcile_exploration_after_dialogue(ended_knot: String) -> void:
	if DialogueManager.is_active or _corridor_transition_running:
		return
	if GameState.needs_mandatory_naming():
		return
	if ended_knot in CORRIDOR_BRIEFING_KNOTS + CHASE_GUIDE_KNOTS:
		return
	if ended_knot in ["chase_arrival", "paper_middle"]:
		return
	if GameState.has_flag("chase_sequence_started") and not GameState.has_flag("corridor_forward_seen"):
		return
	if not GameState.exploration_enabled:
		GameState.enable_exploration()


func stabilize_playback_state() -> void:
	call_deferred("_sync_world_after_load_async")
	if DialogueManager.is_active:
		return
	if GameState.exploration_enabled:
		return
	if GameState.needs_mandatory_naming():
		return
	if GameState.has_flag("chase_sequence_started") and not GameState.has_flag("corridor_forward_seen"):
		return
	if GameState.has_flag("corridor_forward_seen") or not GameState.has_flag("chase_sequence_started"):
		if GameState.current_map_id in ["archives", "hall_papers", "corridor_forward"]:
			GameState.enable_exploration()


func _start_knot(knot_id: String) -> void:
	if knot_id.is_empty():
		return
	_last_knot = knot_id
	DialogueManager.start_knot(knot_id)


func _hotspot_id_for_knot(knot: String) -> String:
	for zone in _scene_hotspot_zones:
		if zone.knot == knot or zone.empty_knot == knot:
			return zone.hotspot_id
	for hs in MapRegistry.get_map(_map_id).get("hotspots", []):
		if hs.get("knot") == knot or hs.get("empty_knot") == knot:
			return hs.get("id", "")
	return ""


func begin_chase_sequence() -> void:
	if GameState.has_flag("chase_sequence_started"):
		return
	GameState.set_flag("chase_sequence_started")
	GameState.set_flag("hall_door_r_far_open")
	GameState.set_flag("chase_encounter_done")
	GameState.disable_exploration()
	_refresh_map_overlays()
	_run_chase_entrance_timeline()


func _run_chase_entrance_timeline() -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(CHASE_DOOR_BEAT_BEFORE_DIALOGUE_SEC).timeout
	if not is_inside_tree():
		return
	_start_chase_arrival_dialogue()


func _start_chase_arrival_dialogue() -> void:
	_start_knot("chase_arrival")


func refresh_map_overlays() -> void:
	_refresh_map_overlays()


func _refresh_map_overlays() -> void:
	for child in _map_host.get_children():
		_refresh_overlays_in_node(child)


func _refresh_overlays_in_node(node: Node) -> void:
	var layer := node.get_node_or_null("InteractableOverlays")
	if layer and layer.has_method("refresh_state"):
		layer.refresh_state()
	for child in node.get_children():
		_refresh_overlays_in_node(child)


func _paper_id_from_knot(knot: String) -> String:
	match knot:
		"paper_left":
			return "left"
		"paper_middle":
			return "middle"
		"paper_right":
			return "right"
	return ""
