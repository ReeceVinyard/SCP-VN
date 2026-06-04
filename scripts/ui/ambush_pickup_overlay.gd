extends Control

## Visual "take the gun or the dog tags" beat after Chase falls. Shows the floor
## scene art with two click zones; picking one emits pickup_chosen and hides.

signal pickup_chosen(choice: String)

const ART_PATH := "res://assets/Interactables/gunordogtags.png"
## Normalized click regions on gunordogtags.png (1920×1080).
const PISTOL_RECT := Rect2(0.38, 0.08, 0.6, 0.9)
const DOGTAGS_RECT := Rect2(0.02, 0.22, 0.48, 0.58)

@onready var _art: TextureRect = %PickupArt
@onready var _pistol_zone: Control = %PistolZone
@onready var _dogtags_zone: Control = %DogtagsZone
@onready var _prompt: Label = %PickupPrompt

var _hover_pistol := false
var _hover_tags := false


func _ready() -> void:
	add_to_group("ambush_pickup")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_apply_art()
	_layout_zones()
	_pistol_zone.mouse_entered.connect(func() -> void:
		_hover_pistol = true
		_update_zone_highlight()
	)
	_pistol_zone.mouse_exited.connect(func() -> void:
		_hover_pistol = false
		_update_zone_highlight()
	)
	_dogtags_zone.mouse_entered.connect(func() -> void:
		_hover_tags = true
		_update_zone_highlight()
	)
	_dogtags_zone.mouse_exited.connect(func() -> void:
		_hover_tags = false
		_update_zone_highlight()
	)
	_pistol_zone.gui_input.connect(_on_pistol_input)
	_dogtags_zone.gui_input.connect(_on_dogtags_input)


func show_pickup() -> void:
	_apply_art()
	_layout_zones()
	_hover_pistol = false
	_hover_tags = false
	_update_zone_highlight()
	if _prompt:
		_prompt.show()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func hide_pickup() -> void:
	visible = false
	if _prompt:
		_prompt.hide()


func _apply_art() -> void:
	if _art == null:
		return
	if ResourceLoader.exists(ART_PATH):
		_art.texture = load(ART_PATH) as Texture2D
	else:
		push_warning("ambush_pickup: missing %s" % ART_PATH)


func _layout_zones() -> void:
	_anchor_zone(_pistol_zone, PISTOL_RECT)
	_anchor_zone(_dogtags_zone, DOGTAGS_RECT)


func _anchor_zone(zone: Control, norm: Rect2) -> void:
	if zone == null:
		return
	zone.anchor_left = norm.position.x
	zone.anchor_top = norm.position.y
	zone.anchor_right = norm.position.x + norm.size.x
	zone.anchor_bottom = norm.position.y + norm.size.y
	zone.offset_left = 0.0
	zone.offset_top = 0.0
	zone.offset_right = 0.0
	zone.offset_bottom = 0.0
	zone.mouse_filter = Control.MOUSE_FILTER_STOP
	zone.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _update_zone_highlight() -> void:
	var glow := Color(1.15, 1.1, 0.88, 1.0)
	if _pistol_zone:
		_pistol_zone.modulate = glow if _hover_pistol else Color.WHITE
	if _dogtags_zone:
		_dogtags_zone.modulate = glow if _hover_tags else Color.WHITE


func _on_pistol_input(event: InputEvent) -> void:
	if not _is_click(event):
		return
	_finish_pick("pistol")


func _on_dogtags_input(event: InputEvent) -> void:
	if not _is_click(event):
		return
	_finish_pick("dogtags")


func _is_click(event: InputEvent) -> bool:
	return (
		event is InputEventMouseButton
		and (event as InputEventMouseButton).pressed
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	)


func _finish_pick(choice: String) -> void:
	hide_pickup()
	pickup_chosen.emit(choice)
