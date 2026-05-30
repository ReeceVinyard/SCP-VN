class_name ItemRegistry
extends RefCounted

const ITEMS := {
	"researcher_id": {
		"display_name": "Researcher ID",
		"description_male": "A smudged name, If I have keycard it doesn't matter.",
		"description_female": "A smudged name, If I have keycard it doesn't matter.",
		"icon_male": "res://assets/items/ID_M.png",
		"icon_female": "res://assets/items/ID_F.png",
	},
	"keycard": {
		"display_name": "Level-2 Keycard",
		"description": "Facility keycard. It still works—for now.",
		"icon": "res://assets/items/LEVEL_2_KEYCARD.png",
	},
	"eh_14": {
		"display_name": "EH-14 Incident Appendix",
		"description": "Redacted incident follow-up—subject interaction logged. Appendix pages torn out.",
		"icon": "res://assets/items/EH-14.png",
		"readable": true,
	},
}


static func is_readable_document(item_id: String) -> bool:
	return bool(ITEMS.get(item_id, {}).get("readable", false))


static func get_display_name(item_id: String) -> String:
	return ITEMS.get(item_id, {}).get("display_name", item_id)


static func get_description(item_id: String) -> String:
	var data: Dictionary = ITEMS.get(item_id, {})
	if item_id == "researcher_id":
		if GameState.id_variant == "female":
			return data.get("description_female", "")
		return data.get("description_male", "")
	return data.get("description", "")


static func get_icon_path(item_id: String) -> String:
	var data: Dictionary = ITEMS.get(item_id, {})
	if item_id == "researcher_id":
		if GameState.id_variant == "female":
			return data.get("icon_female", "")
		return data.get("icon_male", "")
	return data.get("icon", "")
