class_name ReactionRegistry
extends RefCounted

## Mood presentation for post-choice NPC feedback overlays.

const MOODS := {
	"trusting": {
		"label": "Trusting",
		"accent": Color(0.45, 0.82, 0.58, 1.0),
		"icon": "◆",
	},
	"happy": {
		"label": "Relieved",
		"accent": Color(0.92, 0.78, 0.35, 1.0),
		"icon": "◆",
	},
	"sad": {
		"label": "Troubled",
		"accent": Color(0.45, 0.55, 0.78, 1.0),
		"icon": "◆",
	},
	"angry": {
		"label": "Angry",
		"accent": Color(0.9, 0.32, 0.28, 1.0),
		"icon": "◆",
	},
	"suspicious": {
		"label": "Suspicious",
		"accent": Color(0.85, 0.55, 0.22, 1.0),
		"icon": "◆",
	},
	"neutral": {
		"label": "Watching",
		"accent": Color(0.65, 0.68, 0.72, 1.0),
		"icon": "◆",
	},
}


static func resolve(reaction: Dictionary) -> Dictionary:
	var mood_id := str(reaction.get("mood", "neutral"))
	var mood: Dictionary = MOODS.get(mood_id, MOODS["neutral"])
	var npc := str(reaction.get("npc", "???"))
	var headline := str(reaction.get("headline", ""))
	if headline.is_empty():
		headline = "%s seems %s" % [npc, str(mood.get("label", "reacting")).to_lower()]
	var detail := str(reaction.get("detail", ""))
	return {
		"npc": npc,
		"mood_id": mood_id,
		"mood_label": str(mood.get("label", "Reacting")),
		"headline": headline,
		"detail": detail,
		"accent": mood.get("accent", Color.WHITE),
		"icon": str(mood.get("icon", "◆")),
		"duration_sec": float(reaction.get("duration_sec", 5.0)),
	}
