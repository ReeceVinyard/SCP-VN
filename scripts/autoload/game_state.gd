extends Node

signal inventory_changed
signal flags_changed
signal player_name_changed
signal objective_changed

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
	_picked_hotspots.clear()
	inventory_changed.emit()
	flags_changed.emit()
	_emit_objective()


func has_item(item_id: String) -> bool:
	return item_id in inventory


func add_item(item_id: String) -> void:
	if item_id in inventory:
		return
	inventory.append(item_id)
	inventory_changed.emit()
	_check_naming_required()
	_emit_objective()


func has_flag(flag: String) -> bool:
	return flags.get(flag, false)


func set_flag(flag: String, value: bool = true) -> void:
	flags[flag] = value
	flags_changed.emit()
	_emit_objective()


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
	_emit_objective()


func assign_scp_name(assigned_name: String) -> void:
	scp_assigned_name = assigned_name.strip_edges()
	set_flag("named_by_scp")
	player_name_changed.emit()
	_emit_objective()


func is_hotspot_consumed(map_id: String, hotspot_id: String) -> bool:
	return _picked_hotspots.get("%s:%s" % [map_id, hotspot_id], false)


func consume_hotspot(map_id: String, hotspot_id: String) -> void:
	_picked_hotspots["%s:%s" % [map_id, hotspot_id]] = true
	_emit_objective()


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
	_emit_objective()


func get_objective_text() -> String:
	match current_map_id:
		"archives":
			return _archives_objective()
		"hall_papers":
			return _hall_objective()
	return ""


func _archives_objective() -> String:
	if not exploration_enabled:
		return ""
	if needs_mandatory_naming():
		return "Can you remember your name? Head to the security door when you're ready."
	if has_both_credentials() and has_flag("has_named_player"):
		return "Head to the security door and use your keycard."
	if has_item("keycard") and not has_item("researcher_id"):
		return "You have your keycard. The door works—but your ID is still missing."
	if has_item("researcher_id") and not has_item("keycard"):
		return "You found your ID. Is your Keycard here?"
	if has_item("researcher_id") or has_item("keycard"):
		return "Find your Researcher ID and keycard."
	return "Search the room. Click objects to interact."


func _hall_objective() -> String:
	if has_flag("scp1_encounter_done"):
		return ""
	if has_read_paper("left") and has_read_paper("right") and not has_read_paper("middle"):
		return "One of these papers still feels… off. Try the others."
	if has_read_paper("left") or has_read_paper("right"):
		return "Keep searching the papers."
	return "Search the papers scattered on the floor."


func enable_exploration() -> void:
	exploration_enabled = true
	_emit_objective()


func _emit_objective() -> void:
	objective_changed.emit()


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
