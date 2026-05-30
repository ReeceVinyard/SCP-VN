extends Node

signal inventory_changed
signal item_acquired(item_id: String)
signal flags_changed
signal player_name_changed
signal id_variant_changed
signal exploration_enabled_changed(enabled: bool)

const FLAG_DEFAULTS := {
	"tutorial_seen_click": false,
	"has_named_player": false,
	"named_by_scp": false,
	"missing_researcher_id": false,
	"archives_complete": false,
	"scp1_encounter_done": false,
	"scp1_befriended": false,
	"scp1_hostile": false,
	"chase_encounter_done": false,
	"chase_sequence_started": false,
	"hall_door_r_far_open": false,
	"chase_at_door_visible": false,
	"chase_escort_visible": false,
	"chase_first_line_spoken": false,
	"chase_told_amnesia": false,
	"chase_lied_keycard": false,
	"chase_ready_to_leave": false,
	"paper_left_read": false,
	"paper_middle_read": false,
	"paper_right_read": false,
	"hall_intro_seen": false,
	"corridor_forward_seen": false,
	"eh_14_read": false,
}

var current_map_id: String = "archives"
var player_name: String = ""
var scp_assigned_name: String = ""
var inventory: Array[String] = []
var flags: Dictionary = FLAG_DEFAULTS.duplicate(true)
var selected_item_id: String = ""
var exploration_enabled: bool = false
var id_variant: String = "male"
var opening_cinematic_done: bool = false

var _picked_hotspots: Dictionary = {}


func _ready() -> void:
	reset_run()


func reset_run() -> void:
	current_map_id = "archives"
	player_name = ""
	scp_assigned_name = ""
	inventory.clear()
	flags = FLAG_DEFAULTS.duplicate(true)
	selected_item_id = ""
	exploration_enabled = false
	id_variant = "male"
	opening_cinematic_done = false
	_picked_hotspots.clear()
	_emit_state_refresh()


func capture_save_data() -> Dictionary:
	var flags_out: Dictionary = {}
	for key in FLAG_DEFAULTS.keys():
		flags_out[key] = bool(flags.get(key, false))
	var inventory_out: Array[String] = []
	for item_id in inventory:
		if ItemRegistry.ITEMS.has(item_id) and item_id not in inventory_out:
			inventory_out.append(item_id)
	var picked_out: Dictionary = {}
	for key in _picked_hotspots.keys():
		if _picked_hotspots[key]:
			picked_out[str(key)] = true
	return {
		"current_map_id": current_map_id,
		"player_name": player_name,
		"scp_assigned_name": scp_assigned_name,
		"inventory": inventory_out,
		"flags": flags_out,
		"selected_item_id": selected_item_id,
		"exploration_enabled": exploration_enabled,
		"id_variant": id_variant,
		"opening_cinematic_done": opening_cinematic_done,
		"picked_hotspots": picked_out,
	}


func apply_save_data(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var map_id := str(data.get("current_map_id", ""))
	if map_id.is_empty() or MapRegistry.get_map(map_id).is_empty():
		push_error("Save has invalid map_id: %s" % map_id)
		return false
	var next_flags: Dictionary = FLAG_DEFAULTS.duplicate(true)
	var saved_flags: Variant = data.get("flags", {})
	if typeof(saved_flags) == TYPE_DICTIONARY:
		for key in FLAG_DEFAULTS.keys():
			if saved_flags.has(key):
				next_flags[key] = bool(saved_flags[key])
	flags = next_flags
	current_map_id = map_id
	player_name = str(data.get("player_name", ""))
	scp_assigned_name = str(data.get("scp_assigned_name", ""))
	var variant := str(data.get("id_variant", "male"))
	id_variant = "female" if variant == "female" else "male"
	inventory = _load_inventory_list(data.get("inventory", []))
	selected_item_id = ""
	var saved_selected := str(data.get("selected_item_id", ""))
	if saved_selected in inventory:
		selected_item_id = saved_selected
	exploration_enabled = bool(data.get("exploration_enabled", false))
	opening_cinematic_done = bool(data.get("opening_cinematic_done", true))
	_picked_hotspots.clear()
	var picked: Variant = data.get("picked_hotspots", {})
	if typeof(picked) == TYPE_DICTIONARY:
		for key in picked.keys():
			if picked[key]:
				_picked_hotspots[str(key)] = true
	_emit_state_refresh()
	if has_flag("has_named_player") or has_flag("named_by_scp"):
		player_name_changed.emit()
	return true


func _load_inventory_list(raw: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(raw) != TYPE_ARRAY:
		return result
	for entry in raw:
		var item_id := str(entry)
		if ItemRegistry.ITEMS.has(item_id) and item_id not in result:
			result.append(item_id)
	return result


func _emit_state_refresh() -> void:
	inventory_changed.emit()
	flags_changed.emit()


func mark_opening_cinematic_done() -> void:
	opening_cinematic_done = true


func has_item(item_id: String) -> bool:
	return item_id in inventory


func add_item(item_id: String, emit_pickup_signal: bool = true) -> void:
	if item_id in inventory:
		return
	inventory.append(item_id)
	inventory_changed.emit()
	if emit_pickup_signal:
		item_acquired.emit(item_id)
	_check_naming_required()


func has_flag(flag: String) -> bool:
	return flags.get(flag, false)


func set_flag(flag: String, value: bool = true) -> void:
	flags[flag] = value
	flags_changed.emit()


func display_name() -> String:
	if has_flag("has_named_player"):
		return player_name
	if has_flag("named_by_scp"):
		return scp_assigned_name
	return "Researcher"


func set_player_name(chosen_name: String) -> void:
	player_name = chosen_name.strip_edges()
	set_flag("has_named_player")
	player_name_changed.emit()


func assign_scp_name(assigned_name: String) -> void:
	scp_assigned_name = assigned_name.strip_edges()
	set_flag("named_by_scp")
	player_name_changed.emit()


func is_hotspot_consumed(map_id: String, hotspot_id: String) -> bool:
	return _picked_hotspots.get("%s:%s" % [map_id, hotspot_id], false)


func consume_hotspot(map_id: String, hotspot_id: String) -> void:
	_picked_hotspots["%s:%s" % [map_id, hotspot_id]] = true


func mark_paper_read(paper_id: String) -> void:
	set_flag("paper_%s_read" % paper_id)


func has_read_paper(paper_id: String) -> bool:
	return has_flag("paper_%s_read" % paper_id)


func _check_naming_required() -> bool:
	return has_item("researcher_id") and has_item("keycard")


func needs_mandatory_naming() -> bool:
	return _check_naming_required() and not has_flag("has_named_player")


func has_both_credentials() -> bool:
	return has_item("researcher_id") and has_item("keycard")


func can_use_archives_door() -> bool:
	if not has_item("keycard"):
		return false
	if needs_mandatory_naming():
		return false
	return true


func leave_archives() -> void:
	set_flag("archives_complete")
	set_flag("missing_researcher_id", not has_item("researcher_id"))
	current_map_id = "hall_papers"


func enable_exploration() -> void:
	if exploration_enabled:
		return
	exploration_enabled = true
	exploration_enabled_changed.emit(true)


func disable_exploration() -> void:
	if not exploration_enabled:
		return
	exploration_enabled = false
	exploration_enabled_changed.emit(false)


func set_id_variant(variant: String) -> void:
	var next := "female" if variant == "female" else "male"
	if id_variant == next:
		return
	id_variant = next
	id_variant_changed.emit()
	inventory_changed.emit()


func toggle_id_variant() -> void:
	set_id_variant("female" if id_variant == "male" else "male")


func can_swap_id_variant() -> bool:
	return has_item("researcher_id") and has_item("keycard")


func select_item(item_id: String, toggle: bool = true) -> void:
	var next_id := ""
	if toggle and selected_item_id == item_id:
		next_id = ""
	else:
		next_id = item_id
	if selected_item_id == next_id:
		return
	selected_item_id = next_id
	inventory_changed.emit()
