class_name MapRegistry
extends RefCounted

## Map definitions: background color (placeholder until art), hotspots, exits.

const MAPS := {
	"archives": {
		"display_name": "Archives",
		"bg_color": Color(0.12, 0.14, 0.22),
		"hotspots": [
			{
				"id": "desk",
				"label": "Desk drawer",
				"rect": [0.62, 0.48, 0.14, 0.12],
				"type": "pickup",
				"item_id": "researcher_id",
				"knot": "archives_find_id",
				"empty_knot": "archives_desk_empty",
			},
			{
				"id": "locker",
				"label": "Locker",
				"rect": [0.18, 0.42, 0.12, 0.22],
				"type": "pickup",
				"item_id": "keycard",
				"knot": "archives_find_keycard",
				"empty_knot": "archives_locker_empty",
			},
			{
				"id": "door",
				"label": "Security door",
				"rect": [0.44, 0.12, 0.12, 0.28],
				"type": "door",
				"target_map": "hall_papers",
				"knot_locked": "archives_door_locked",
				"knot_need_name": "archives_need_name",
				"knot_exit": "archives_exit",
			},
			{
				"id": "shelf",
				"label": "Redacted shelf",
				"rect": [0.72, 0.22, 0.1, 0.35],
				"type": "examine",
				"knot": "archives_shelf_flavor",
			},
		],
	},
	"hall_papers": {
		"display_name": "East corridor",
		"bg_color": Color(0.18, 0.15, 0.12),
		"hotspots": [
			{
				"id": "paper_left",
				"label": "Paper (left)",
				"rect": [0.22, 0.62, 0.12, 0.1],
				"type": "paper",
				"paper_id": "left",
				"knot": "paper_left",
				"empty_knot": "paper_left_done",
			},
			{
				"id": "paper_middle",
				"label": "Paper (center)",
				"rect": [0.44, 0.58, 0.12, 0.12],
				"type": "paper",
				"paper_id": "middle",
				"knot": "paper_middle",
				"trigger_encounter": true,
				"empty_knot": "paper_middle_done",
			},
			{
				"id": "paper_right",
				"label": "Paper (right)",
				"rect": [0.66, 0.64, 0.12, 0.09],
				"type": "paper",
				"paper_id": "right",
				"knot": "paper_right",
				"empty_knot": "paper_right_done",
			},
			{
				"id": "return_archives",
				"label": "Back to Archives",
				"rect": [0.04, 0.82, 0.1, 0.08],
				"type": "exit",
				"target_map": "archives",
				"knot": "hall_return_archives",
			},
		],
	},
}


static func get_map(map_id: String) -> Dictionary:
	return MAPS.get(map_id, {})
