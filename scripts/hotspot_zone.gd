@tool
extends Control
class_name HotspotZone

const _InteractableRegistry = preload("res://scripts/data/interactable_registry.gd")

signal pressed_zone(zone: HotspotZone)
signal hover_started(zone: HotspotZone)
signal hover_ended(zone: HotspotZone)

@export_group("Identity")
@export var hotspot_id: String = ""
@export var label_text: String = "Interact"

@export_group("Interaction")
@export_enum("pickup", "door", "paper", "exit", "examine") var interaction_type: String = "examine"
@export var knot: String = ""
@export var empty_knot: String = ""
@export var item_id: String = ""
@export var target_map: String = ""
@export var knot_locked: String = ""
@export var knot_need_name: String = ""
@export var knot_exit: String = ""
@export var paper_id: String = ""
## Hotspot only accepts clicks when this flag is true (empty = always active).
@export var requires_flag: String = ""

@export_group("Editor")
@export var show_zone_in_editor: bool = true
@export_tool_button("Snap click box to anchors", "Clears offset, scale, and rotation so the cyan box matches clicks")
var _snap_click_box_action = _snap_click_box_to_anchors
@export_tool_button("Fit to overlay art", "Resize anchors to the glowing art bounds for this hotspot_id")
var _fit_overlay_art_action = _fit_to_overlay_art

var _hovering: bool = false
var _flash_strength: float = 0.0
var _use_art_overlay: bool = false
var _overlay_hit_image: Image
var _overlay_hit_tex_size: Vector2i = Vector2i.ZERO
var _overlay_hit_norm: Rect2 = Rect2()


func _ready() -> void:
	tooltip_text = label_text
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_use_art_overlay = _detect_art_overlay()
	_cache_overlay_hit_data()
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	if not Engine.is_editor_hint() and not GameState.flags_changed.is_connected(_on_flags_changed):
		GameState.flags_changed.connect(_on_flags_changed)
	_update_interaction_enabled()
	queue_redraw()


func _detect_art_overlay() -> bool:
	if hotspot_id.is_empty():
		return false
	return _InteractableRegistry.can_show_overlay(_resolve_map_id(), hotspot_id)


func _find_overlay_layer() -> Node:
	var node: Node = get_parent()
	while node:
		var parent := node.get_parent()
		if parent:
			var layer := parent.get_node_or_null("InteractableOverlays")
			if layer:
				return layer
		node = parent
	return null


func _resolve_map_id() -> String:
	var layer := _find_overlay_layer()
	if layer:
		var map_id: String = layer.get("map_id")
		if not map_id.is_empty():
			return map_id
	return "archives"


func _has_stray_transform() -> bool:
	return (
		absf(offset_left) > 0.5
		or absf(offset_top) > 0.5
		or absf(offset_right) > 0.5
		or absf(offset_bottom) > 0.5
	)


func _snap_click_box_to_anchors() -> void:
	_editor_snap_layout_to_anchors()


func _fit_to_overlay_art() -> void:
	if not Engine.is_editor_hint():
		return
	var map_id := _resolve_map_id()
	var hit_rect := _InteractableRegistry.get_overlay_hit_rect(map_id, hotspot_id)
	if hit_rect.size == Vector2.ZERO:
		push_warning("No overlay hit rect for %s:%s" % [map_id, hotspot_id])
		return
	anchor_left = hit_rect.position.x
	anchor_top = hit_rect.position.y
	anchor_right = hit_rect.position.x + hit_rect.size.x
	anchor_bottom = hit_rect.position.y + hit_rect.size.y
	_editor_snap_layout_to_anchors()


func _cache_overlay_hit_data() -> void:
	_overlay_hit_image = null
	_overlay_hit_tex_size = Vector2i.ZERO
	_overlay_hit_norm = Rect2()
	if not _use_art_overlay:
		return
	var map_id := _resolve_map_id()
	_overlay_hit_norm = _InteractableRegistry.get_overlay_hit_rect(map_id, hotspot_id)
	if _overlay_hit_norm.size == Vector2.ZERO:
		return
	var path := _InteractableRegistry.resolve_texture_path(map_id, hotspot_id)
	if path.is_empty():
		return
	var texture := load(path) as Texture2D
	if texture == null:
		return
	_overlay_hit_tex_size = texture.get_size()
	_overlay_hit_image = texture.get_image()
	if _overlay_hit_image == null or _overlay_hit_image.is_empty():
		_overlay_hit_image = null
		return
	if _overlay_hit_image.get_format() != Image.FORMAT_RGBA8:
		_overlay_hit_image.convert(Image.FORMAT_RGBA8)


func _editor_snap_layout_to_anchors() -> void:
	if not Engine.is_editor_hint():
		return
	scale = Vector2.ONE
	rotation = 0.0
	pivot_offset = Vector2.ZERO
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	queue_redraw()


func _on_resized() -> void:
	queue_redraw()


func contains_global_point(global_pos: Vector2) -> bool:
	if not is_visible_in_tree() or not _is_interaction_enabled():
		return false
	var local := get_global_transform_with_canvas().affine_inverse() * global_pos
	return _has_point(local)


func _has_point(point: Vector2) -> bool:
	if not _is_interaction_enabled():
		return false
	var rect_size := size
	if rect_size.x < 1.0 or rect_size.y < 1.0:
		rect_size = get_rect().size
	if rect_size.x < 1.0 or rect_size.y < 1.0:
		return false
	if not Rect2(Vector2.ZERO, rect_size).has_point(point):
		return false
	if not _use_art_overlay or _overlay_hit_image == null or _overlay_hit_norm.size == Vector2.ZERO:
		return true
	if _point_hits_overlay_alpha(point):
		return true
	# Fallback: anchor box is authoritative if glow PNG alpha is sparse/misaligned.
	return true


func _point_hits_overlay_alpha(local_point: Vector2) -> bool:
	var u := _overlay_hit_norm.position.x + (local_point.x / size.x) * _overlay_hit_norm.size.x
	var v := _overlay_hit_norm.position.y + (local_point.y / size.y) * _overlay_hit_norm.size.y
	var px := int(u * float(_overlay_hit_tex_size.x))
	var py := int(v * float(_overlay_hit_tex_size.y))
	if px < 0 or py < 0 or px >= _overlay_hit_tex_size.x or py >= _overlay_hit_tex_size.y:
		return false
	return _overlay_hit_image.get_pixel(px, py).a > 0.08


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if Engine.is_editor_hint():
		if show_zone_in_editor:
			draw_rect(rect, Color(0.3, 0.85, 1.0, 0.35), true)
			draw_rect(rect, Color(0.3, 0.85, 1.0, 0.9), false, 2.0)
			if _has_stray_transform():
				draw_rect(rect, Color(1.0, 0.25, 0.25, 0.85), false, 4.0)
			if scale != Vector2.ONE or absf(rotation) > 0.001:
				draw_rect(rect, Color(1.0, 0.45, 0.2, 0.55), false, 3.0)
		return
	if _use_art_overlay:
		return
	if _flash_strength > 0.0:
		draw_rect(rect, Color(1.0, 0.95, 0.7, 0.2 + _flash_strength * 0.45), true)
	elif _hovering:
		draw_rect(rect, Color(0.9, 0.85, 0.5, 0.28), true)


func _is_interaction_enabled() -> bool:
	if requires_flag.is_empty():
		return true
	return GameState.has_flag(requires_flag)


func _update_interaction_enabled() -> void:
	if Engine.is_editor_hint():
		return
	var enabled := _is_interaction_enabled()
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW


func _on_flags_changed() -> void:
	_update_interaction_enabled()


func _on_gui_input(event: InputEvent) -> void:
	if not _is_interaction_enabled():
		return
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if Engine.is_editor_hint():
		return
	accept_event()
	pressed_zone.emit(self)


func _on_mouse_entered() -> void:
	if not _is_interaction_enabled():
		return
	_hovering = true
	hover_started.emit(self)
	if not _use_art_overlay:
		queue_redraw()


func _on_mouse_exited() -> void:
	_hovering = false
	hover_ended.emit(self)
	if not _use_art_overlay:
		queue_redraw()


func flash_click() -> void:
	if _use_art_overlay:
		return
	var tween := create_tween()
	_flash_strength = 1.0
	queue_redraw()
	tween.tween_property(self, "_flash_strength", 0.0, 0.35)
	tween.tween_callback(queue_redraw)


func to_dictionary() -> Dictionary:
	var data := {
		"id": hotspot_id,
		"label": label_text,
		"type": interaction_type,
		"knot": knot,
	}
	if not empty_knot.is_empty():
		data["empty_knot"] = empty_knot
	if not item_id.is_empty():
		data["item_id"] = item_id
	if not target_map.is_empty():
		data["target_map"] = target_map
	if not knot_locked.is_empty():
		data["knot_locked"] = knot_locked
	if not knot_need_name.is_empty():
		data["knot_need_name"] = knot_need_name
	if not knot_exit.is_empty():
		data["knot_exit"] = knot_exit
	if not paper_id.is_empty():
		data["paper_id"] = paper_id
	return data
