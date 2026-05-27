class_name ItemRegistry
extends RefCounted

const ITEMS := {
	"researcher_id": {
		"display_name": "Researcher ID",
		"description": "Your photo stares back. The name line is smudged.",
	},
	"keycard": {
		"display_name": "Level-2 Keycard",
		"description": "Facility keycard. It still works—for now.",
	},
}


static func get_display_name(item_id: String) -> String:
	return ITEMS.get(item_id, {}).get("display_name", item_id)


static func get_description(item_id: String) -> String:
	return ITEMS.get(item_id, {}).get("description", "")
