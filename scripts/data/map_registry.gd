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
	"corridor_forward": {
		"display_name": "Corridor 3",
		"scene": "res://scenes/maps/corridor_forward.tscn",
	},
	"staircase": {
		"display_name": "Stairwell",
		"scene": "res://scenes/maps/staircase.tscn",
	},
	"security_room": {
		"display_name": "Security Room",
		"scene": "res://scenes/maps/security_room.tscn",
	},
	"storage_room": {
		"display_name": "Storage Room",
		"scene": "res://scenes/maps/storage_room.tscn",
	},
}


static func get_map(map_id: String) -> Dictionary:
	return MAPS.get(map_id, {})
