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
		"clock": "res://assets/Interactables/lab1_clock.png",
		"biohazard": "res://assets/Interactables/lab1_biohazard.png",
		"beakers": "res://assets/Interactables/lab1_big_beaker.png",
		"bottles": "res://assets/Interactables/lab1_strange_bottles.png",
		"periodic_table": "res://assets/Interactables/lab1_periodic_table.png",
		"trash": "res://assets/Interactables/lab1_trash.png",
	},
	"hall_papers": {
		"paper_left": "res://assets/Interactables/corridor2_paper_L.png",
		"paper_middle": "res://assets/Interactables/corridor2_paper_mid.png",
		"paper_right": "res://assets/Interactables/corridor2_paper_R.png",
		"return_archives": "res://assets/Interactables/corridor2_door_L_close.png",
		"door_l_far": "res://assets/Interactables/corridor2_door_L_far.png",
		"door_r_close": "res://assets/Interactables/corridor2_door_R_close.png",
		"door_r_far": "res://assets/Interactables/corridor2_door_R_far.png",
		"door_r_far_open": "res://assets/Interactables/corridor2_open_door.png",
		"chase_at_door": "res://assets/Characters/Chase/chase.png",
	},
	"corridor_forward": {
		"return_hall": "res://assets/Interactables/corridor3_door_L_close.png",
		"door_l_far": "res://assets/Interactables/corridor3_door_L_far.png",
		"door_r_close": "res://assets/Interactables/corridor3_door_R_close.png",
		"door_r_far": "res://assets/Interactables/corridor3_door_R_far.png",
		"vent": "res://assets/Interactables/corridor3_vent.png",
		"sign": "res://assets/Interactables/corridor3_sign.png",
		"camera": "res://assets/Interactables/corridor3_camera.png",
	},
}

## Overlay only glows when GameState has this flag (empty = no extra requirement).
const OVERLAY_REQUIRES_FLAG := {
	"hall_papers": {},
	"corridor_forward": {},
}

## Keys that only supply art for resolve_texture_path / state overlays — not hover hotspots.
const OVERLAY_ART_ALIASES := ["door_r_far_open"]

## Shown without hover while the flag is true (open door, Chase silhouette, etc.).
const OVERLAY_SHOW_WHILE_FLAG := {
	"hall_papers": {
		"door_r_far": "hall_door_r_far_open",
		"chase_at_door": "chase_at_door_visible",
	},
	"corridor_forward": {
		"chase_with_player": "chase_escort_visible",
	},
}

## Draw order inside InteractableOverlays (higher = in front).
const OVERLAY_Z_DEFAULT := 5
const OVERLAY_Z_DOOR_OPEN := 10
const CHARACTER_PRESENCE_Z_INDEX := 30


static func overlay_z_index_for(map_id: String, overlay_key: String) -> int:
	if map_id == "hall_papers" and overlay_key == "door_r_far":
		return OVERLAY_Z_DOOR_OPEN
	return OVERLAY_Z_DEFAULT


## Overlay keys that layer on top of a hotspot (not separate interactables).
const SECONDARY_OVERLAY_KEYS := {
	"archives": {
		"door": ["door_keypad_unlocked"],
	},
}

## Normalized hit bounds (x, y, width, height) from opaque pixels in each overlay PNG at 1920×1080.
const OVERLAY_HIT_RECTS := {
	"archives": {
		"desk": Rect2(0.2484, 0.6519, 0.1052, 0.1083),
		"locker": Rect2(0.7875, 0.2120, 0.0917, 0.5602),
		"door": Rect2(0.5005, 0.2269, 0.1427, 0.5018),
		"shelf": Rect2(0.6661, 0.8102, 0.1589, 0.1444),
		"clock": Rect2(0.5167, 0.1713, 0.1104, 0.0472),
		"biohazard": Rect2(0.8182, 0.1398, 0.0412, 0.0769),
		"beakers": Rect2(0.0125, 0.4009, 0.0641, 0.1695),
		"bottles": Rect2(0.2281, 0.1574, 0.0662, 0.1176),
		"periodic_table": Rect2(0.3057, 0.2185, 0.0766, 0.2222),
		"trash": Rect2(0.8875, 0.6120, 0.0813, 0.1556),
	},
	"hall_papers": {
		"paper_left": Rect2(0.2172, 0.8343, 0.1141, 0.0843),
		"paper_middle": Rect2(0.4349, 0.8546, 0.1115, 0.0981),
		"paper_right": Rect2(0.6917, 0.8389, 0.1193, 0.0898),
		"return_archives": Rect2(0.0375, 0.0481, 0.1292, 0.8759),
		"door_l_far": Rect2(0.2427, 0.2241, 0.0594, 0.4981),
		"door_r_close": Rect2(0.8281, 0.0333, 0.1292, 0.8870),
		"door_r_far": Rect2(0.6937, 0.2241, 0.0594, 0.4981),
	},
	"corridor_forward": {
		"return_hall": Rect2(0.0365, 0.0389, 0.1302, 0.8889),
		"door_l_far": Rect2(0.2427, 0.2259, 0.0594, 0.4981),
		"door_r_close": Rect2(0.826, 0.0315, 0.1313, 0.8963),
		"door_r_far": Rect2(0.6937, 0.2204, 0.0583, 0.5056),
		"vent": Rect2(0.4495, 0.4954, 0.0901, 0.0963),
		"sign": Rect2(0.4484, 0.325, 0.0974, 0.0935),
		"camera": Rect2(0.6245, 0.2278, 0.024, 0.0667),
	},
}


static func get_overlay_hit_rect(map_id: String, hotspot_id: String) -> Rect2:
	return OVERLAY_HIT_RECTS.get(map_id, {}).get(hotspot_id, Rect2())


static func get_overlay_paths(map_id: String) -> Dictionary:
	return MAP_OVERLAYS.get(map_id, {})


static func resolve_texture_path(map_id: String, hotspot_id: String) -> String:
	var paths: Dictionary = get_overlay_paths(map_id)
	if hotspot_id.is_empty():
		return ""
	var presence_path := CharacterRegistry.resolve_map_presence_texture(map_id, hotspot_id)
	if not presence_path.is_empty():
		return presence_path
	if map_id == "hall_papers" and hotspot_id == "door_r_far":
		if GameState.has_flag("hall_door_r_far_open"):
			var open_path: String = paths.get("door_r_far_open", "")
			if not open_path.is_empty():
				return open_path
	return paths.get(hotspot_id, "")


static func persistent_overlay_flag(map_id: String, overlay_key: String) -> String:
	return str(OVERLAY_SHOW_WHILE_FLAG.get(map_id, {}).get(overlay_key, ""))


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


static func overlay_requires_flag(map_id: String, hotspot_id: String) -> String:
	return str(OVERLAY_REQUIRES_FLAG.get(map_id, {}).get(hotspot_id, ""))


static func can_show_overlay(map_id: String, hotspot_id: String) -> bool:
	var required := overlay_requires_flag(map_id, hotspot_id)
	if not required.is_empty() and not GameState.has_flag(required):
		return false
	return has_overlay_art(map_id, hotspot_id)


static func has_overlay_art(map_id: String, hotspot_id: String) -> bool:
	if not resolve_texture_path(map_id, hotspot_id).is_empty():
		return true
	return not resolve_secondary_overlay_paths(map_id, hotspot_id).is_empty()
