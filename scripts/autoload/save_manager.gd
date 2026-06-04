extends Node

## Persists full run state (flags, inventory, map, hotspots) to user://saves/.

signal save_finished(slot: int, success: bool)
signal load_finished(slot: int, success: bool)

const SAVE_VERSION := 1
const SAVE_DIR := "user://saves"
const SLOT_QUICK := 0
const SLOT_MANUAL := 1

const _SLOT_FILES := {
	SLOT_QUICK: "quick_save.json",
	SLOT_MANUAL: "slot_1.json",
}


func _ready() -> void:
	_ensure_save_dir()


func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func has_save(slot: int = SLOT_QUICK) -> bool:
	return FileAccess.file_exists(_path_for_slot(slot))


func get_slot_summary(slot: int = SLOT_QUICK) -> Dictionary:
	var data := _read_slot_file(slot)
	if data.is_empty():
		return {}
	return {
		"slot": slot,
		"map_id": str(data.get("game_state", {}).get("current_map_id", "")),
		"player_name": str(data.get("game_state", {}).get("player_name", "")),
		"saved_at_unix": int(data.get("saved_at_unix", 0)),
		"inventory_count": int(data.get("game_state", {}).get("inventory", []).size()),
	}


func save_game(slot: int = SLOT_QUICK) -> bool:
	_ensure_save_dir()
	var exploration := _get_exploration_map()
	var payload := {
		"version": SAVE_VERSION,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"game_state": GameState.capture_save_data(),
		"exploration": exploration.capture_save_data() if exploration else {},
		"dialogue": DialogueManager.capture_save_data(),
	}
	var ok := _write_slot_file(slot, payload)
	save_finished.emit(slot, ok)
	return ok


func load_game(slot: int = SLOT_QUICK) -> bool:
	var payload := _read_slot_file(slot)
	if payload.is_empty():
		load_finished.emit(slot, false)
		return false
	var version := int(payload.get("version", 0))
	if version > SAVE_VERSION:
		push_error("Save file version %d is newer than this build (%d)." % [version, SAVE_VERSION])
		load_finished.emit(slot, false)
		return false
	if not _apply_payload(payload):
		load_finished.emit(slot, false)
		return false
	load_finished.emit(slot, true)
	return true


## Applies a save-shaped payload (game_state / exploration / dialogue) to the live
## game. Shared by disk loads and the in-memory hunt checkpoint.
func _apply_payload(payload: Dictionary) -> bool:
	if not GameState.apply_save_data(payload.get("game_state", {})):
		push_error("Save game_state failed validation.")
		return false
	# Cancel any in-progress hunt timer so we don't fail right after restoring.
	HuntManager.abort()
	DialogueManager.force_end()
	var exploration := _get_exploration_map()
	if exploration:
		exploration.apply_save_data(payload.get("exploration", {}))
	var dialogue: Variant = payload.get("dialogue", {})
	if DialogueManager.restore_from_save(dialogue):
		if exploration and exploration.has_method("_sync_chase_presence"):
			exploration._sync_chase_presence()
			if exploration.has_method("_sync_world_after_load_async"):
				exploration.call_deferred("_sync_world_after_load_async")
	elif exploration and exploration.has_method("stabilize_playback_state"):
		exploration.stabilize_playback_state()
	return true


## --- Hunt checkpoint (in-memory; set when the hunt begins) ------------------

var _checkpoint: Dictionary = {}


## Snapshots the current run for hunt Retry. Pass `map_id` (e.g. "staircase") so the
## save stays correct even if a deferred callback runs after a later load_map.
func set_checkpoint(map_id: String = "") -> void:
	var exploration := _get_exploration_map()
	var game_state := GameState.capture_save_data()
	var exploration_data: Dictionary = exploration.capture_save_data() if exploration else {}
	if not map_id.is_empty():
		game_state["current_map_id"] = map_id
		exploration_data["map_id"] = map_id
	_checkpoint = {
		"game_state": game_state,
		"exploration": exploration_data,
		"dialogue": DialogueManager.capture_save_data(),
	}


func has_checkpoint() -> bool:
	return not _checkpoint.is_empty()


func clear_checkpoint() -> void:
	_checkpoint = {}


func restore_checkpoint() -> bool:
	if _checkpoint.is_empty():
		return false
	return _apply_payload(_checkpoint.duplicate(true))


func delete_save(slot: int = SLOT_QUICK) -> bool:
	var path := _path_for_slot(slot)
	if not FileAccess.file_exists(path):
		return false
	var err := DirAccess.remove_absolute(path)
	return err == OK


func _get_exploration_map() -> Node:
	var nodes := get_tree().get_nodes_in_group("exploration_map")
	if nodes.is_empty():
		return null
	return nodes[0]


func _path_for_slot(slot: int) -> String:
	var file_name: String = _SLOT_FILES.get(slot, "slot_%d.json" % slot)
	return "%s/%s" % [SAVE_DIR, file_name]


func _write_slot_file(slot: int, payload: Dictionary) -> bool:
	var path := _path_for_slot(slot)
	var tmp_path := "%s.tmp" % path
	var text := JSON.stringify(payload, "\t")
	if text.is_empty() and not payload.is_empty():
		return false
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write save temp file: %s" % tmp_path)
		return false
	file.store_string(text)
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var rename_err := DirAccess.rename_absolute(tmp_path, path)
	if rename_err != OK:
		# Fallback: write directly.
		var direct := FileAccess.open(path, FileAccess.WRITE)
		if direct == null:
			return false
		direct.store_string(text)
		direct.close()
		if FileAccess.file_exists(tmp_path):
			DirAccess.remove_absolute(tmp_path)
	return true


func _read_slot_file(slot: int) -> Dictionary:
	var path := _path_for_slot(slot)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid save JSON in %s" % path)
		return {}
	return parsed
