class_name ItemRegistry
extends RefCounted

## Item fields:
##   display_name        : label shown in the inventory
##   description[/_male/_female] : detail text (variant-aware for researcher_id)
##   icon[/_male/_female] : artwork path; empty/missing shows a placeholder
##   readable            : true if the item opens in the document reader
##   category            : optional grouping label (e.g. "Document", "Credential")
##   examine             : optional longer "examine" text for future use
const ITEMS := {
	"researcher_id": {
		"display_name": "Researcher ID",
		"category": "Credential",
		"description_male": "A smudged name, If I have keycard it doesn't matter.",
		"description_female": "A smudged name, If I have keycard it doesn't matter.",
		"icon_male": "res://assets/items/ID_M.png",
		"icon_female": "res://assets/items/ID_F.png",
	},
	"keycard": {
		"display_name": "Level-2 Keycard",
		"category": "Credential",
		"description": "Facility keycard. It still works—for now.",
		"icon": "res://assets/items/LEVEL_2_KEYCARD.png",
	},
	"eh_14": {
		"display_name": "EH-14 Incident Appendix",
		"category": "Document",
		"description": "Redacted incident follow-up—subject interaction logged. Appendix pages torn out.",
		"icon": "res://assets/items/EH-14.png",
		"readable": true,
	},
	# --- Hunt-sequence items ---------------------------------------------------
	"chase_pistol": {
		"display_name": "Chase's Sidearm",
		"category": "Equipment",
		"description": "Chase's pistol. Heavier than it looks. Nearly empty.",
		"examine": "Standard security-issue sidearm. The slide's scratched to hell. One round left in the magazine.",
		"icon": "res://assets/items/pistol.png",
	},
	"chase_dogtags": {
		"display_name": "Chase's Dog Tags",
		"category": "Keepsake",
		"description": "Still warm. CHASE, R. — Security, Tier 2.",
		"examine": "Two stamped tags on a chain. You don't remember him, but you took these. It felt wrong to leave them.",
		"icon": "res://assets/Interactables/dogtag.png",
	},
	"ammo": {
		"display_name": "Pistol Rounds",
		"category": "Equipment",
		"description": "A loose handful of rounds. Enough to matter, maybe.",
		"icon": "res://assets/items/ammo.png",
	},
	# Icon is battery-aware (see get_icon_path / WALKIE_BATTERY_ICONS), so no static "icon".
	"walkie_talkie": {
		"display_name": "Walkie-Talkie",
		"category": "Equipment",
		"description": "Crackling with static. Someone, somewhere, might still be listening.",
	},
	"screwdriver": {
		"display_name": "Screwdriver",
		"category": "Tool",
		"description": "A flat-head screwdriver from the security desk. Good for vent grilles.",
		"icon": "res://assets/items/screwdriver.png",
	},
}

## Walkie-talkie icon swaps with the current battery percentage (GameState.walkie_battery).
## The art is named by the level it represents; we show the highest level at or below
## the current charge.
const WALKIE_BATTERY_ICONS := [
	{"min": 75, "path": "res://assets/items/walkietalkie_battery_75.png"},
	{"min": 35, "path": "res://assets/items/walkietalkie_battery_35.png"},
	{"min": 5, "path": "res://assets/items/walkietalkie_battery_5perc.png"},
	{"min": 0, "path": "res://assets/items/walkietalkie_battery_dead.png"},
]


static func walkie_icon_for_battery(pct: int) -> String:
	for entry in WALKIE_BATTERY_ICONS:
		if pct >= int(entry["min"]):
			return str(entry["path"])
	return str(WALKIE_BATTERY_ICONS[-1]["path"])


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
	if item_id == "walkie_talkie":
		return walkie_icon_for_battery(GameState.walkie_battery)
	return data.get("icon", "")


static func get_category(item_id: String) -> String:
	return str(ITEMS.get(item_id, {}).get("category", ""))


static func get_examine_text(item_id: String) -> String:
	return str(ITEMS.get(item_id, {}).get("examine", ""))
