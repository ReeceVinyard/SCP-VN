@tool
extends Control

## Keeps the map scene at the same size as the game (1920×1080) while editing hotspots.
## Does not change anything at runtime when the scene is played from main.tscn.

const DESIGN_SIZE := Vector2(1920, 1080)


func _ready() -> void:
	if Engine.is_editor_hint():
		_apply_design_canvas_size()


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		call_deferred("_apply_design_canvas_size")


func _apply_design_canvas_size() -> void:
	# Minimum size only — do not assign `size` here; forcing size in the editor
	# reflows child controls and Godot may write stray offsets into the .tscn on save (F5).
	custom_minimum_size = DESIGN_SIZE


@export_tool_button("Snap ALL hotspots to anchors", "Zeros offset/scale/rotation on every HotspotZone in this map")
var _snap_all_hotspots_action = _snap_all_hotspots_to_anchors
@export_tool_button("Fit ALL hotspots to overlay art", "Sets each zone's anchors from interactable_registry hit rects")
var _fit_all_overlay_art_action = _fit_all_hotspots_to_overlay_art


func _fit_all_hotspots_to_overlay_art() -> void:
	if not Engine.is_editor_hint():
		return
	_fit_hotspots_overlay_recursive(self)


func _fit_hotspots_overlay_recursive(node: Node) -> void:
	if node is HotspotZone:
		node._fit_to_overlay_art()
	for child in node.get_children():
		_fit_hotspots_overlay_recursive(child)


func _snap_all_hotspots_to_anchors() -> void:
	if not Engine.is_editor_hint():
		return
	_snap_hotspots_recursive(self)


func _snap_hotspots_recursive(node: Node) -> void:
	if node is HotspotZone:
		node._editor_snap_layout_to_anchors()
	for child in node.get_children():
		_snap_hotspots_recursive(child)
