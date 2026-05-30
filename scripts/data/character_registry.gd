class_name CharacterRegistry
extends RefCounted

## Character portrait art (VN-style) and map presence overlays.

const PORTRAITS := {
	"Chase": {
		"normal": "res://assets/Characters/Chase/chase.png",
		"angry": "res://assets/Characters/Chase/chase_angry.png",
		"scared": "res://assets/Characters/Chase/chase_scared.png",
	},
}

## Map overlay key → mood when the character first appears at the door.
const MAP_PRESENCE_MOOD := {
	"chase_at_door": "normal",
	"chase_with_player": "normal",
	"chase_briefing_center": "normal",
}

const PRESENCE_OVERLAY_KEYS := {
	"hall_papers": ["chase_at_door"],
	"corridor_forward": ["chase_briefing_center", "chase_with_player"],
}


static func has_character(speaker: String) -> bool:
	return PORTRAITS.has(speaker)


static func resolve_portrait_path(speaker: String, mood: String) -> String:
	var moods: Dictionary = PORTRAITS.get(speaker, {})
	if moods.is_empty():
		return ""
	var path: String = str(moods.get(mood, ""))
	if path.is_empty():
		path = str(moods.get("normal", ""))
	return path


static func reaction_mood_to_map_mood(reaction_mood: String) -> String:
	match reaction_mood:
		"angry", "suspicious":
			return "angry"
		"scared":
			return "scared"
		_:
			return "normal"


static func resolve_chase_mood_for_dialogue(knot_id: String, line_portrait: String = "") -> String:
	if not line_portrait.is_empty():
		return line_portrait
	if GameState.has_flag("chase_lied_keycard"):
		return "angry"
	match knot_id:
		"chase_lie_response", "chase_guide_harsh", "corridor3_chase_briefing_harsh":
			return "angry"
		_:
			return "normal"


static func chase_presence_flag(overlay_key: String) -> String:
	match overlay_key:
		"chase_at_door":
			return "chase_at_door_visible"
		"chase_with_player":
			return "chase_escort_visible"
		"chase_briefing_center":
			return "chase_briefing_center_visible"
		_:
			return ""


static func is_chase_presence_visible(overlay_key: String) -> bool:
	var flag_name := chase_presence_flag(overlay_key)
	return not flag_name.is_empty() and GameState.has_flag(flag_name)


static func resolve_map_presence_texture(map_id: String, overlay_key: String) -> String:
	var keys: Array = PRESENCE_OVERLAY_KEYS.get(map_id, [])
	if overlay_key not in keys:
		return ""
	if not is_chase_presence_visible(overlay_key):
		return ""
	var mood := "normal"
	if DialogueManager.is_active:
		mood = resolve_chase_mood_for_dialogue(DialogueManager.get_current_knot(), "")
	else:
		mood = "angry" if GameState.has_flag("chase_lied_keycard") else str(MAP_PRESENCE_MOOD.get(overlay_key, "normal"))
	return resolve_portrait_path("Chase", mood)


static func active_chase_presence_key(map_id: String) -> String:
	for overlay_key in PRESENCE_OVERLAY_KEYS.get(map_id, []):
		if is_chase_presence_visible(overlay_key):
			return overlay_key
	return ""
