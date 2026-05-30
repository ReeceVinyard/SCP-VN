extends Control

## Letterboxes the map into a centered 16:9 region so anchors match background + overlay art.

const ASPECT_RATIO := 16.0 / 9.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var aspect := AspectRatioContainer.new()
	aspect.name = "Aspect"
	aspect.ratio = ASPECT_RATIO
	aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	aspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(aspect)


func host_map(map_root: Node) -> void:
	var aspect := get_node("Aspect") as AspectRatioContainer
	for child in aspect.get_children():
		child.queue_free()
	if map_root is Control:
		var ctrl := map_root as Control
		ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ctrl.offset_left = 0
		ctrl.offset_top = 0
		ctrl.offset_right = 0
		ctrl.offset_bottom = 0
		ctrl.grow_horizontal = Control.GROW_DIRECTION_BOTH
		ctrl.grow_vertical = Control.GROW_DIRECTION_BOTH
	aspect.add_child(map_root)
