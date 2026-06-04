extends Control

## Close-up vent beat in the security room: click each screw with the screwdriver
## until the grille comes loose. Art paths are placeholders — drop files in when ready.

signal unscrew_complete

const VENT_ART_PATH := "res://assets/Interactables/security_vent.png"
const SCREW_ART_PATH := "res://assets/Interactables/vent_screw.png"
const SCREW_COUNT := 4
## Normalized click targets for each screw on the close-up vent art (tune when art lands).
## Screw heads on security_vent.png (vent grille, bottom-left of the close-up).
const SCREW_RECTS := [
	Rect2(0.012, 0.668, 0.028, 0.045),
	Rect2(0.078, 0.668, 0.028, 0.045),
	Rect2(0.012, 0.858, 0.028, 0.045),
	Rect2(0.078, 0.858, 0.028, 0.045),
]

@onready var _vent_art: TextureRect = %VentCloseupArt
@onready var _prompt: Label = %VentUnscrewPrompt
@onready var _screw_root: Control = %ScrewRoot

var _screw_zones: Array[Control] = []


func _ready() -> void:
	add_to_group("vent_unscrew")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_screw_zones()
	_apply_placeholder_art()


func show_unscrew() -> void:
	_sync_screw_visibility()
	if _prompt:
		_prompt.text = "Click each screw with the screwdriver (%d / %d left)." % [
			SCREW_COUNT - GameState.count_vent_screws_removed(),
			SCREW_COUNT,
		]
	visible = true


func hide_unscrew() -> void:
	visible = false


func _apply_placeholder_art() -> void:
	if _vent_art:
		if ResourceLoader.exists(VENT_ART_PATH):
			_vent_art.texture = load(VENT_ART_PATH) as Texture2D
		else:
			_vent_art.texture = null
			_vent_art.self_modulate = Color(0.12, 0.13, 0.15, 1.0)


func _build_screw_zones() -> void:
	if _screw_root == null:
		return
	for child in _screw_root.get_children():
		child.queue_free()
	_screw_zones.clear()
	for i in SCREW_COUNT:
		var zone := _make_screw_zone(i)
		_screw_root.add_child(zone)
		_screw_zones.append(zone)


func _make_screw_zone(index: int) -> Control:
	var norm: Rect2 = SCREW_RECTS[index]
	var zone := Control.new()
	zone.name = "Screw%d" % (index + 1)
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
	var screw_vis := TextureRect.new()
	screw_vis.name = "ScrewSprite"
	screw_vis.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screw_vis.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screw_vis.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	screw_vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(SCREW_ART_PATH):
		screw_vis.texture = load(SCREW_ART_PATH) as Texture2D
	else:
		# Placeholder until vent_screw.png exists.
		screw_vis.texture = null
		screw_vis.self_modulate = Color(0.55, 0.52, 0.48, 1.0)
	zone.add_child(screw_vis)
	var idx := index
	zone.gui_input.connect(func(event: InputEvent) -> void: _on_screw_input(idx, event))
	zone.mouse_entered.connect(func() -> void: _set_screw_hover(idx, true))
	zone.mouse_exited.connect(func() -> void: _set_screw_hover(idx, false))
	return zone


func _set_screw_hover(index: int, on: bool) -> void:
	if index < 0 or index >= _screw_zones.size():
		return
	if GameState.is_vent_screw_removed(index):
		return
	var zone := _screw_zones[index]
	var glow := Color(1.12, 1.05, 0.85, 1.0)
	zone.modulate = glow if on else Color.WHITE


func _on_screw_input(index: int, event: InputEvent) -> void:
	if not (
		event is InputEventMouseButton
		and (event as InputEventMouseButton).pressed
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	):
		return
	if not GameState.has_item("screwdriver"):
		return
	if GameState.is_vent_screw_removed(index):
		return
	GameState.mark_vent_screw_removed(index)
	SoundManager.play("paper_rustle")  # placeholder until a screw-turn SFX exists
	_sync_screw_visibility()
	if _prompt:
		var left := SCREW_COUNT - GameState.count_vent_screws_removed()
		_prompt.text = "Click each screw with the screwdriver (%d / %d left)." % [left, SCREW_COUNT]
	if GameState.count_vent_screws_removed() >= SCREW_COUNT:
		hide_unscrew()
		unscrew_complete.emit()


func _sync_screw_visibility() -> void:
	for i in _screw_zones.size():
		var zone := _screw_zones[i]
		var removed := GameState.is_vent_screw_removed(i)
		zone.visible = not removed
