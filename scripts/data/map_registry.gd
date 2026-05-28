class_name MapRegistry
extends RefCounted

## Map definitions: background color (placeholder until art), hotspots, exits.

const MAPS := {
	"archives": {
		"display_name": "Archives",
		"scene": "res://scenes/maps/archives.tscn",
	},
	"hall_papers": {
		"display_name": "East corridor",
		"scene": "res://scenes/maps/hall_papers.tscn",
	},
}


static func get_map(map_id: String) -> Dictionary:
	return MAPS.get(map_id, {})
