class_name MemoryRegistry
extends RefCounted

## Recovered-memory fragments the player pieces together about the Main Character.
##
## Artwork is not final: `icon` may be empty and the UI shows a placeholder.
## Unlock a fragment from code with `GameState.unlock_memory_fragment(id)` or from
## dialogue with a line tag `memory:<id>` (see DialogueManager).

const FRAGMENTS := {
	"frag_waking": {
		"title": "Waking",
		"order": 10,
		"chapter": "Before the Alarms",
		"locked_hint": "The first thing you remember — or the first thing you've lost.",
		"text": "Fluorescent light. The taste of dust and something chemical. You were already standing when the thought arrived: you are not supposed to be here, and you do not know why.",
		"icon": "",
	},
	"frag_id_photo": {
		"title": "The Face on the Card",
		"order": 20,
		"chapter": "Before the Alarms",
		"locked_hint": "A name and a face you should recognise.",
		"text": "The photo on the ID is yours. You're almost sure of it. The name underneath is smudged past reading, as if someone pressed a thumb to it and held on.",
		"icon": "",
	},
	"frag_corridor": {
		"title": "A Familiar Hallway",
		"order": 30,
		"chapter": "Before the Alarms",
		"locked_hint": "You've walked these halls before. When?",
		"text": "You've turned this corner a hundred times. The scuff on the wall at shoulder height — you know it. You just can't remember being the person who made it.",
		"icon": "",
	},
	"frag_voice": {
		"title": "A Voice, Insisting",
		"order": 40,
		"chapter": "The Breach",
		"locked_hint": "Someone told you something important. You weren't listening.",
		"text": "A voice over your shoulder, calm and too fast: \"Don't sign for it. Whatever they tell you, don't sign for it.\" You can't picture their face. You think you signed anyway.",
		"icon": "",
	},
	"frag_alarm": {
		"title": "When the Lights Changed",
		"order": 50,
		"chapter": "The Breach",
		"locked_hint": "The moment everything went wrong.",
		"text": "Amber light, then red. The pressure doors coming down like guillotines, one after another, deeper into the building. You remember running the wrong way — toward something, not away.",
		"icon": "",
	},
	"frag_name": {
		"title": "Your Name",
		"order": 60,
		"chapter": "Who You Are",
		"locked_hint": "The thing you want most to remember.",
		"text": "It's right there, behind your teeth. A shape, a sound, the way someone used to say it. Not yet. But closer.",
		"icon": "",
	},
}


static func has_fragment(fragment_id: String) -> bool:
	return FRAGMENTS.has(fragment_id)


static func ordered_ids() -> Array:
	var ids: Array = FRAGMENTS.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var oa: int = int(FRAGMENTS[a].get("order", 0))
		var ob: int = int(FRAGMENTS[b].get("order", 0))
		if oa == ob:
			return a < b
		return oa < ob
	)
	return ids


static func total_count() -> int:
	return FRAGMENTS.size()


static func get_title(fragment_id: String) -> String:
	return str(FRAGMENTS.get(fragment_id, {}).get("title", fragment_id))


static func get_text(fragment_id: String) -> String:
	return str(FRAGMENTS.get(fragment_id, {}).get("text", ""))


static func get_locked_hint(fragment_id: String) -> String:
	return str(FRAGMENTS.get(fragment_id, {}).get("locked_hint", "A memory you haven't recovered yet."))


static func get_chapter(fragment_id: String) -> String:
	return str(FRAGMENTS.get(fragment_id, {}).get("chapter", ""))


static func get_icon_path(fragment_id: String) -> String:
	return str(FRAGMENTS.get(fragment_id, {}).get("icon", ""))
