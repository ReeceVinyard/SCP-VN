class_name InteractableRegistry
extends RefCounted

## Full-screen hover overlays aligned to the background art (lab1 = Archives).

const MAP_OVERLAYS := {
	"archives": {
		"desk": "res://assets/Interactables/lab1_drawer.png",
		"locker": "res://assets/Interactables/lab1_locker.png",
		"door": "res://assets/Interactables/lab1_door.png",
		"door_keypad_unlocked": "res://assets/Interactables/lab1_keypad_green.png",
		"shelf": "res://assets/Interactables/lab1_notebook.png",
	},
	"hall_papers": {
		"paper_left": "res://assets/Interactables/corridor2_paper_L.png",
		"paper_middle": "res://assets/Interactables/corridor2_paper_mid.png",
		"paper_right": "res://assets/Interactables/corridor2_paper_R.png",
		"return_archives": "res://assets/Interactables/corridor2_door_L_close.png",
		"door_l_far": "res://assets/Interactables/corridor2_door_L_far.png",
		"door_r_close": "res://assets/Interactables/corridor2_door_R_close.png",
		"door_r_far": "res://assets/Interactables/corridor2_door_R_far.png",
	},
}

## Overlay keys that layer on top of a hotspot (not separate interactables).
const SECONDARY_OVERLAY_KEYS := {
	"archives": {
		"door": ["door_keypad_unlocked"],
	},
}


static func get_overlay_paths(map_id: String) -> Dictionary:
	return MAP_OVERLAYS.get(map_id, {})


static func resolve_texture_path(map_id: String, hotspot_id: String) -> String:
	var paths: Dictionary = get_overlay_paths(map_id)
	if hotspot_id.is_empty():
		return ""
	return paths.get(hotspot_id, "")


static func resolve_secondary_overlay_paths(map_id: String, hotspot_id: String) -> Array[String]:
	var paths: Dictionary = get_overlay_paths(map_id)
	var keys: Array = SECONDARY_OVERLAY_KEYS.get(map_id, {}).get(hotspot_id, [])
	var resolved: Array[String] = []
	for key in keys:
		if hotspot_id == "door" and str(key) == "door_keypad_unlocked":
			if not GameState.has_item("keycard"):
				continue
		var path: String = paths.get(key, "")
		if not path.is_empty():
			resolved.append(path)
	return resolved


static func has_overlay_art(map_id: String, hotspot_id: String) -> bool:
	if not resolve_texture_path(map_id, hotspot_id).is_empty():
		return true
	return not resolve_secondary_overlay_paths(map_id, hotspot_id).is_empty()
