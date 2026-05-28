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

@export_group("Editor")
@export var show_zone_in_editor: bool = true

var _hovering: bool = false
var _flash_strength: float = 0.0
var _use_art_overlay: bool = false


func _ready() -> void:
	tooltip_text = label_text
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_use_art_overlay = _detect_art_overlay()
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	queue_redraw()


func _detect_art_overlay() -> bool:
	if hotspot_id.is_empty():
		return false
	return _InteractableRegistry.has_overlay_art(_resolve_map_id(), hotspot_id)


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


func _notification(what: int) -> void:
	if Engine.is_editor_hint() and what == NOTIFICATION_EDITOR_PRE_SAVE:
		queue_redraw()


func _on_resized() -> void:
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if Engine.is_editor_hint():
		if show_zone_in_editor:
			draw_rect(rect, Color(0.3, 0.85, 1.0, 0.35), true)
			draw_rect(rect, Color(0.3, 0.85, 1.0, 0.9), false, 2.0)
		return
	if _use_art_overlay:
		return
	if _flash_strength > 0.0:
		draw_rect(rect, Color(1.0, 0.95, 0.7, 0.2 + _flash_strength * 0.45), true)
	elif _hovering:
		draw_rect(rect, Color(0.9, 0.85, 0.5, 0.28), true)


func _on_gui_input(event: InputEvent) -> void:
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
