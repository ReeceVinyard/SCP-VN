extends Node

signal inventory_changed
signal item_acquired(item_id: String)
signal flags_changed
signal player_name_changed
signal id_variant_changed

const FLAG_DEFAULTS := {
	"tutorial_seen_click": false,
	"has_named_player": false,
	"named_by_scp": false,
	"missing_researcher_id": false,
	"archives_complete": false,
	"scp1_encounter_done": false,
	"scp1_befriended": false,
	"scp1_hostile": false,
	"paper_left_read": false,
	"paper_middle_read": false,
	"paper_right_read": false,
	"hall_intro_seen": false,
}

var current_map_id: String = "archives"
var player_name: String = ""
var scp_assigned_name: String = ""
var inventory: Array[String] = []
var flags: Dictionary = FLAG_DEFAULTS.duplicate(true)
var selected_item_id: String = ""
var exploration_enabled: bool = false
var id_variant: String = "male"

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
	_picked_hotspots.clear()
	inventory_changed.emit()
	flags_changed.emit()


func has_item(item_id: String) -> bool:
	return item_id in inventory


func add_item(item_id: String) -> void:
	if item_id in inventory:
		return
	inventory.append(item_id)
	inventory_changed.emit()
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
	exploration_enabled = true


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
