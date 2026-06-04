extends Control

const MapAspectWrapperScript := preload("res://scripts/maps/map_aspect_wrapper.gd")
const _CharacterRegistry = preload("res://scripts/data/character_registry.gd")

signal map_changed(map_id: String)
signal naming_required
signal document_requested(item_id: String, grant_item_on_close: bool)
signal computer_login_requested

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
const ARCHIVES_DEPART_SHAKE_HOLD_SEC := 0.45
const ARCHIVES_DEPART_FADE_OUT_SEC := 0.6
const ARCHIVES_DEPART_FADE_HOLD_SEC := 0.35
const ARCHIVES_DEPART_FADE_IN_SEC := 0.85
const CHASE_ESCORT_OVERLAY_KEY := "chase_with_player"
const CHASE_BRIEFING_CENTER_OVERLAY_KEY := "chase_briefing_center"
const CHASE_GUIDE_KNOTS := ["chase_guide_gentle", "chase_guide_harsh"]
const CORRIDOR_BRIEFING_KNOTS := ["corridor3_chase_briefing_gentle", "corridor3_chase_briefing_harsh"]
const CORRIDOR_QUESTIONS_KNOT := "corridor3_questions"
const CORRIDOR_QA_KNOTS := ["corridor3_questions", "corridor3_q_evac", "corridor3_q_work", "corridor3_q_exit"]
## Corridor 3 dead-end doors → (knot, "tried" flag). None of these let the player leave.
const CORRIDOR3_DEADEND_DOORS := {
	"return_hall": {"knot": "corridor3_back_blocked", "flag": "c3_tried_return"},
	"door_l_far": {"knot": "corridor3_door_l_far_flavor", "flag": "c3_tried_l_far"},
	"door_r_far": {"knot": "corridor3_door_r_far_flavor", "flag": "c3_tried_r_far"},
	"door_r_close": {"knot": "corridor3_door_r_close_flavor", "flag": "c3_tried_r_close"},
}
const CORRIDOR3_DEADEND_KNOTS := ["corridor3_back_blocked", "corridor3_door_l_far_flavor", "corridor3_door_r_far_flavor", "corridor3_door_r_close_flavor"]
const CORRIDOR3_WEST_WING_KNOT := "corridor3_west_wing"
const WEST_WING_DOOR_VIDEO := "res://assets/Videosandgifs/doorclosing.ogv"
const WEST_WING_TESLA_VIDEO := "res://assets/Videosandgifs/Teslagate.ogv"
const WEST_WING_FADE_OUT_SEC := 0.6
const WEST_WING_FADE_HOLD_SEC := 0.15
const WEST_WING_FADE_IN_SEC := 0.8
const WEST_WING_DOOR_SLAM_SETTLE_SEC := 0.4

## --- Hunt sequence (Chase's death -> staircase -> security room -> storage) ---
## Per-beat timer windows. Placeholders — tune in playtest (the player never sees
## the number; rising audio is the only cue).
const STAIRCASE_HUNT_SEC := 8.0
const STAIRCASE_BANNER := "FIND THE SECURITY ROOM"
const HUNT_FADE_OUT_SEC := 0.5
const HUNT_FADE_HOLD_SEC := 0.15
const HUNT_FADE_IN_SEC := 0.7
## How long the "use the screwdriver" vent interaction takes (the rattle SFX plays
## across this window before the grille comes off).
const VENT_UNSCREW_SEC := 5.0
## Background variant shown once the security-room vent is open (grille on floor).
const SECURITY_VENT_OPEN_BG := "res://assets/backgrounds/secuirty vent floor.png"
## Security-room hotspot id -> item it grants (picked up silently, no found-modal).
const SECURITY_PICKUPS := {
	"ammo": "ammo",
	"walkie": "walkie_talkie",
	"tool": "screwdriver",
}

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
	call_deferred("_on_hunt_map_loaded", map_id)


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
	var pickup := _get_ambush_pickup()
	if pickup is Control and (pickup as Control).visible:
		return false
	var vent_unscrew := _get_vent_unscrew()
	if vent_unscrew is Control and (vent_unscrew as Control).visible:
		return false
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
	if _map_id == "hall_papers" and hs.get("id", "") == "door_r_far" and GameState.has_flag("chase_ready_to_leave"):
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
	if _map_id == "hall_papers" and hs.get("id", "") == "door_r_far":
		if GameState.has_flag("chase_ready_to_leave"):
			_launch_corridor_forward_transition(_briefing_knot_for_door())
			return
		if GameState.has_flag("hall_door_r_far_open"):
			return
	if _map_id == "corridor_forward" and _handle_corridor3_door(hs):
		return
	if _map_id == "staircase" and _handle_staircase_door(hs):
		return
	if _map_id == "security_room" and _handle_security_room(hs):
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
	# Keypad accepts the keycard and the reader chirps.
	SoundManager.play("keypad_beep")
	_last_knot = hs.get("knot_exit", "")
	_start_knot(_last_knot)


func _handle_paper(hs: Dictionary) -> void:
	# Handling paperwork on the floor — rustle whether it's new or re-read.
	SoundManager.play("paper_rustle")
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
	# An ordinary door swinging open onto the next/previous room.
	SoundManager.play("door_opening")
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
		_run_archives_departure()
		return
	if knot == "archives_amnesia":
		_run_archives_to_hall_transition()
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
	if knot in CORRIDOR3_DEADEND_KNOTS:
		if _all_corridor3_doors_tried() and not GameState.has_flag("c3_west_wing_pointed"):
			GameState.set_flag("c3_west_wing_pointed")
			GameState.disable_exploration()
			call_deferred("_start_knot", CORRIDOR3_WEST_WING_KNOT)
		else:
			call_deferred("_reconcile_exploration_after_dialogue", knot)
		return
	if knot == CORRIDOR3_WEST_WING_KNOT:
		_prepare_west_wing_cutscene()
		_run_west_wing_sequence()
		return
	if knot == "corridor3_tesla_trapped":
		# The Tesla gate is sealed; the anomaly strikes. Chase dies here.
		if not GameState.has_flag("chase_dead"):
			call_deferred("_start_knot", "west_wing_ambush")
		return
	if knot == "west_wing_ambush":
		_show_ambush_pickup()
		return
	if knot in ["ambush_took_pistol", "ambush_took_dogtags"]:
		_on_chase_died()
		return
	if knot == "sec_vent_use":
		_run_vent_unscrew()
		return
	if knot == "sec_door_leave":
		HuntManager.kill("left_anyway")
		return
	if knot == "sec_door_stay":
		call_deferred("_reconcile_exploration_after_dialogue", knot)
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


## In Corridor 3 every side door is a dead end: the way back is blocked by Chase,
## the rest are locked. Each click is tracked so Chase can point on once all tried.
func _handle_corridor3_door(hs: Dictionary) -> bool:
	var id := str(hs.get("id", ""))
	if not CORRIDOR3_DEADEND_DOORS.has(id):
		return false
	if GameState.has_flag("c3_west_wing_pointed"):
		# Past the point of no return; ignore stray door clicks during the cutscene.
		return true
	var entry: Dictionary = CORRIDOR3_DEADEND_DOORS[id]
	GameState.set_flag(str(entry["flag"]))
	_start_knot(str(entry["knot"]))
	return true


func _all_corridor3_doors_tried() -> bool:
	for id in CORRIDOR3_DEADEND_DOORS:
		if not GameState.has_flag(str(CORRIDOR3_DEADEND_DOORS[id]["flag"])):
			return false
	return true


func _run_archives_departure() -> void:
	if not is_inside_tree():
		return
	GameState.disable_exploration()
	# The unlocked door swings open as the player steps through.
	SoundManager.play("door_opening")
	# A slight shake as the fog hits, then a fade out-and-in to black.
	DialogueManager.screen_shake_requested.emit("light")
	await get_tree().create_timer(ARCHIVES_DEPART_SHAKE_HOLD_SEC).timeout
	if not is_inside_tree():
		return
	var transition := _get_map_transition()
	if transition:
		await transition.fade_to_black(ARCHIVES_DEPART_FADE_OUT_SEC, ARCHIVES_DEPART_FADE_HOLD_SEC)
		await transition.fade_from_black(ARCHIVES_DEPART_FADE_IN_SEC)
	if not is_inside_tree():
		return
	_start_knot("archives_amnesia")


func _run_archives_to_hall_transition() -> void:
	if not is_inside_tree():
		return
	var transition := _get_map_transition()
	if transition:
		await transition.fade_to_black(MAP_TRANSITION_FADE_OUT_SEC, MAP_TRANSITION_HOLD_SEC)
	if not is_inside_tree():
		return
	GameState.leave_archives()
	load_map("hall_papers")
	await get_tree().process_frame
	_refresh_map_overlays()
	if transition:
		await transition.fade_from_black(MAP_TRANSITION_FADE_IN_SEC)


func _launch_corridor_forward_transition(briefing_knot: String) -> void:
	if briefing_knot.is_empty() or _corridor_transition_running:
		return
	_corridor_transition_running = true
	# The door ahead opens as Chase leads the player through to the next corridor.
	SoundManager.play("door_opening")
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


func _get_dialogue_box() -> Control:
	if has_node("%DialogueBox"):
		return get_node("%DialogueBox") as Control
	for node in get_tree().get_nodes_in_group("dialogue_box"):
		if node is Control:
			return node as Control
	return null


func _hide_dialogue_box_now() -> void:
	var box := _get_dialogue_box()
	if box == null:
		return
	if box.has_method("hide_for_cutscene"):
		box.hide_for_cutscene()
	else:
		box.hide()


func _prepare_west_wing_cutscene() -> void:
	_hide_dialogue_box_now()
	_hide_all_character_presence_now()
	if _map_host:
		_map_host.visible = false


func _restore_map_after_west_wing_cutscene() -> void:
	if _map_host:
		_map_host.visible = true


func _hide_all_character_presence_now() -> void:
	GameState.set_flag("chase_escort_visible", false)
	GameState.set_flag("chase_briefing_center_visible", false)
	GameState.set_flag("chase_at_door_visible", false)
	for child in _map_host.get_children():
		_hide_presence_in_node(child)


func _hide_presence_in_node(node: Node) -> void:
	var layer := node.get_node_or_null("InteractableOverlays")
	if layer:
		for child in layer.get_children():
			if child is CharacterPresenceZone:
				(child as CharacterPresenceZone).hide_presence()
	for child in node.get_children():
		_hide_presence_in_node(child)


func _get_scene_video() -> Node:
	var nodes := get_tree().get_nodes_in_group("scene_video")
	if nodes.is_empty():
		return null
	return nodes[0]


func _get_run_cinematic() -> Node:
	var nodes := get_tree().get_nodes_in_group("run_cinematic")
	if nodes.is_empty():
		return null
	return nodes[0]


func _get_ambush_pickup() -> Node:
	var nodes := get_tree().get_nodes_in_group("ambush_pickup")
	if nodes.is_empty():
		return null
	return nodes[0]


func _show_ambush_pickup() -> void:
	if not is_inside_tree():
		return
	GameState.disable_exploration()
	_hide_dialogue_box_now()
	var video := _get_scene_video()
	if video and video.has_method("stop_clip"):
		video.stop_clip()
	var overlay := _get_ambush_pickup()
	if overlay == null or not overlay.has_method("show_pickup"):
		push_warning("ambush_pickup overlay missing — cannot show gun/dogtag choice")
		return
	if overlay.pickup_chosen.is_connected(_on_ambush_pickup_chosen):
		overlay.pickup_chosen.disconnect(_on_ambush_pickup_chosen)
	overlay.pickup_chosen.connect(_on_ambush_pickup_chosen, CONNECT_ONE_SHOT)
	overlay.show_pickup()


func _on_ambush_pickup_chosen(choice: String) -> void:
	if choice == "pistol":
		GameState.set_flag("took_pistol")
		GameState.add_item("chase_pistol", false)
		_start_knot("ambush_took_pistol")
	elif choice == "dogtags":
		GameState.set_flag("took_dogtags")
		GameState.add_item("chase_dogtags", false)
		_start_knot("ambush_took_dogtags")
	else:
		push_warning("ambush_pickup: unknown choice %s" % choice)


## Chase falls to the anomaly. Grab his gear (no found-modal — it's frantic) and
## hand off to the uncontrolled escape run that drops us at the staircase.
func _on_chase_died() -> void:
	# The item the player chose (pistol or dog tags) is granted by the calling
	# ambush_took_* branch; only one is taken.
	GameState.set_flag("chase_dead")
	GameState.disable_exploration()
	_run_escape_to_stairs()


func _run_escape_to_stairs() -> void:
	if not is_inside_tree():
		return
	# Kill the looping Tesla gate video behind us.
	var video := _get_scene_video()
	if video and video.has_method("stop_clip"):
		video.stop_clip()
	# Uncontrolled sprint (placeholder frames until the blurry run art is in).
	var run := _get_run_cinematic()
	if run and run.has_method("play_run"):
		await run.play_run(PackedStringArray(), 1.0)
	if not is_inside_tree():
		return
	GameState.set_flag("hunt_escape_done")
	var transition := _get_map_transition()
	if transition:
		await transition.fade_to_black(HUNT_FADE_OUT_SEC, HUNT_FADE_HOLD_SEC)
	load_map("staircase")
	# Capture immediately — a deferred _on_hunt_map_loaded can run after the player
	# has already loaded security_room and would snapshot the wrong map for Retry.
	_setup_staircase_hunt_checkpoint()
	if transition:
		await transition.fade_from_black(HUNT_FADE_IN_SEC)


## Runs after any map loads. Starts/clears the per-beat hunt depending on which
## hunt map we just entered. Harmless no-op for non-hunt maps.
func _on_hunt_map_loaded(map_id: String) -> void:
	if not is_inside_tree():
		return
	if GameState.has_flag("reached_storage_room"):
		return
	match map_id:
		"staircase":
			_setup_staircase_hunt_checkpoint()
		"security_room":
			# Safe room: the staircase beat already ended, so no timer/hunt audio
			# runs here. The only danger is leaving the vent without checking cameras.
			GameState.set_flag("reached_security_room")
			GameState.enable_exploration()
			if GameState.has_flag("vent_opened"):
				_apply_security_vent_open_background()
		"storage_room":
			GameState.set_flag("reached_storage_room")
			SaveManager.clear_checkpoint()
			GameState.enable_exploration()
			_start_knot("storage_arrival")


func _setup_staircase_hunt_checkpoint() -> void:
	GameState.set_flag("reached_staircase")
	GameState.enable_exploration()
	SaveManager.set_checkpoint("staircase")
	if not HuntManager.is_active():
		HuntManager.start_beat("staircase", STAIRCASE_HUNT_SEC, STAIRCASE_BANNER)


## Fallback when Retry is pressed but the in-memory checkpoint was lost (deferred
## map race). Rewinds hunt progress to the staircase beat and rebuilds the snapshot.
func rewind_hunt_to_staircase() -> void:
	GameState.set_flag("reached_security_room", false)
	GameState.set_flag("checked_cameras", false)
	GameState.set_flag("vent_opened", false)
	GameState.vent_screws_mask = 0
	HuntManager.abort()
	DialogueManager.force_end()
	load_map("staircase")
	_setup_staircase_hunt_checkpoint()


## Staircase beat: the security door is the only safe exit. Any other door, or
## running out of time, gets the player caught. Returns true if handled.
func _handle_staircase_door(hs: Dictionary) -> bool:
	if not HuntManager.is_active():
		return false
	var hid := str(hs.get("id", ""))
	if hid == "security_door":
		# Refresh the hunt retry point while we are still on the staircase map.
		SaveManager.set_checkpoint("staircase")
		HuntManager.survive_beat()
		_go_to_map_with_fade("security_room")
		return true
	HuntManager.fail("wrong_door")
	return true


## Security-room beat: grab gear, but you MUST check the cameras before opening the
## vent or SCP-14 takes you. Returns true if handled.
func _handle_security_room(hs: Dictionary) -> bool:
	var hid := str(hs.get("id", ""))
	if SECURITY_PICKUPS.has(hid):
		var item_id: String = SECURITY_PICKUPS[hid]
		if GameState.has_item(item_id) or GameState.is_hotspot_consumed(_map_id, hid):
			_start_knot(str(hs.get("empty_knot", "")))
			return true
		# Route through the standard pickup flow so the item flies into view (the
		# found-modal slides in); the flavor knot plays after it's dismissed.
		SoundManager.play("paper_rustle")
		_pending_pickup = hs.duplicate()
		GameState.add_item(item_id)
		return true
	if hid == "cameras":
		GameState.set_flag("checked_cameras")
		_start_knot("sec_cameras")
		return true
	if hid == "door":
		_handle_security_exit_door()
		return true
	if hid == "login":
		# Open the desk terminal (login -> desktop -> folders/documents).
		computer_login_requested.emit()
		return true
	if hid in ["alarm", "notepad"]:
		_start_knot("sec_%s_flavor" % hid)
		return true
	if hid == "vent":
		_handle_security_vent()
		return true
	return false


## Exit back toward the stairwell. Without checking the cameras first, the anomaly
## is an instant kill. After the feeds, the player gets a warning and a choice.
func _handle_security_exit_door() -> void:
	if not GameState.has_flag("checked_cameras"):
		SoundManager.play("anomaly")
		HuntManager.kill("door_blind")
		return
	_start_knot("sec_door_warn")


func _handle_security_vent() -> void:
	# Already open: clicking the exposed opening crawls into the duct.
	if GameState.has_flag("vent_opened"):
		_finish_vent_escape()
		return
	if not GameState.has_item("screwdriver"):
		_start_knot("sec_vent_locked")
		return
	# The vent is always a safe route — no camera-check gate. Offer the choice
	# to work the grille loose or leave it.
	_start_knot("sec_vent_prompt")


## "Use the screwdriver": play the rattle SFX across a short timed interaction
## (cut at exactly VENT_UNSCREW_SEC), then swap the room to the vent-open
## background variant and let the narration play.
func _run_vent_unscrew() -> void:
	if not is_inside_tree():
		return
	GameState.disable_exploration()
	_hide_dialogue_box_now()
	SoundManager.play_cuttable("vent_open")
	await get_tree().create_timer(VENT_UNSCREW_SEC).timeout
	SoundManager.stop_cuttable()
	if not is_inside_tree():
		return
	GameState.set_flag("vent_opened")
	# The grille comes free and clatters to the floor — jolt the screen as it lands.
	DialogueManager.screen_shake_requested.emit("medium")
	_apply_security_vent_open_background()
	_refresh_map_overlays()
	_start_knot("sec_vent_opened")


## Swap the security-room background to the variant that shows the grille on the
## floor and the duct open. Re-applied on map (re)load while vent_opened is set.
func _apply_security_vent_open_background() -> void:
	var bg := _security_background()
	if bg == null:
		return
	if not ResourceLoader.exists(SECURITY_VENT_OPEN_BG):
		push_warning("Vent-open background missing: %s" % SECURITY_VENT_OPEN_BG)
		return
	var tex := load(SECURITY_VENT_OPEN_BG) as Texture2D
	if tex:
		bg.texture = tex


func _security_background() -> TextureRect:
	for child in _map_host.get_children():
		var bg := _find_security_background(child)
		if bg != null:
			return bg
	return null


func _find_security_background(node: Node) -> TextureRect:
	var layer := node.get_node_or_null("InteractableOverlays")
	if layer != null and str(layer.get("map_id")) == "security_room":
		var bg := node.get_node_or_null("Background")
		return bg as TextureRect if bg is TextureRect else null
	for child in node.get_children():
		var found := _find_security_background(child)
		if found != null:
			return found
	return null


func _get_vent_unscrew() -> Node:
	var nodes := get_tree().get_nodes_in_group("vent_unscrew")
	if nodes.is_empty():
		return null
	return nodes[0]


func _show_vent_unscrew() -> void:
	if not is_inside_tree():
		return
	GameState.disable_exploration()
	_hide_dialogue_box_now()
	var overlay := _get_vent_unscrew()
	if overlay == null or not overlay.has_method("show_unscrew"):
		push_warning("vent_unscrew overlay missing")
		return
	if overlay.unscrew_complete.is_connected(_on_vent_unscrew_complete):
		overlay.unscrew_complete.disconnect(_on_vent_unscrew_complete)
	overlay.unscrew_complete.connect(_on_vent_unscrew_complete, CONNECT_ONE_SHOT)
	overlay.show_unscrew()


func _on_vent_unscrew_complete() -> void:
	_start_knot("sec_vent_opened")


func _finish_vent_escape() -> void:
	if not is_inside_tree():
		return
	GameState.set_flag("vent_opened")
	SoundManager.play("door_opening")
	_go_to_map_with_fade("storage_room")


func _go_to_map_with_fade(map_id: String) -> void:
	if not is_inside_tree():
		return
	GameState.disable_exploration()
	var transition := _get_map_transition()
	if transition:
		await transition.fade_to_black(HUNT_FADE_OUT_SEC, HUNT_FADE_HOLD_SEC)
	load_map(map_id)
	if transition:
		await transition.fade_from_black(HUNT_FADE_IN_SEC)


## The West wing approach: behind a fade, reveal a large open Tesla gate that
## slams shut once, then crackles on a loop until the scene moves on (monster beat).
func _run_west_wing_sequence() -> void:
	if not is_inside_tree():
		return
	GameState.disable_exploration()
	GameState.set_flag("west_wing_reached")
	_prepare_west_wing_cutscene()
	var video := _get_scene_video()
	var transition := _get_map_transition()
	if transition:
		await transition.fade_to_black(WEST_WING_FADE_OUT_SEC, WEST_WING_FADE_HOLD_SEC)
	if not is_inside_tree():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if video and video.has_method("play_clip_when_ready"):
		await video.play_clip_when_ready(WEST_WING_DOOR_VIDEO, false)
	elif video and video.has_method("play_clip"):
		await video.play_clip(WEST_WING_DOOR_VIDEO, false)
	if transition:
		await transition.fade_from_black(WEST_WING_FADE_IN_SEC)
	if video:
		# Wait for the door to finish slamming shut, then hold a beat.
		if not video.is_finished():
			await video.sequence_finished
		DialogueManager.screen_shake_requested.emit("medium")
		await get_tree().create_timer(WEST_WING_DOOR_SLAM_SETTLE_SEC).timeout
		if not is_inside_tree():
			return
		# Swap to the looping Tesla arc without hiding the player (avoids a map flash).
		if video.has_method("play_clip_when_ready"):
			await video.play_clip_when_ready(WEST_WING_TESLA_VIDEO, true, true)
		elif video.has_method("play_clip"):
			await video.play_clip(WEST_WING_TESLA_VIDEO, true)
	if not is_inside_tree():
		return
	_restore_map_after_west_wing_cutscene()
	_start_knot("corridor3_tesla_trapped")


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
