@tool
class_name NameEntryModal
extends Control

signal name_confirmed(chosen_name: String)

const CHAR_REVEAL_SEC := 0.055
const CARD_MAX_WIDTH_RATIO := 0.72
const SWAP_RESERVE_PX := 100.0

const ID_MALE: Texture2D = preload("res://assets/items/ID_M.png")
const ID_FEMALE: Texture2D = preload("res://assets/items/ID_F.png")

## Name typing area on the ID (x, y, width, height — each 0 to 1 on the card image).
@export_category("Name Field On Card")
@export var name_line_on_card: Rect2 = Rect2(0.385, 0.528, 0.23, 0.078)

@onready var _backdrop: ColorRect = %Backdrop
@onready var _id_stage: MarginContainer = %IdStage
@onready var _card_frame: Control = %CardFrame
@onready var _id_preview: TextureRect = %IdPreview
@onready var _name_on_id: Label = %NameOnId
@onready var _name_overlay: Control = %NameOverlay
@onready var _field: LineEdit = %NameField
@onready var _instruction: Label = %InstructionLabel
@onready var _error: Label = %ErrorLabel
@onready var _confirm: Button = %ConfirmButton
@onready var _male_button: Button = %IdMaleButton
@onready var _female_button: Button = %IdFemaleButton
@onready var _id_swap_label: Label = %IdSwapLabel
@onready var _swap_block: VBoxContainer = %IdSwapBlock
@onready var _swap_row: HBoxContainer = %IdSwapRow

var _target_name: String = ""
var _revealed_name: String = ""
var _reveal_timer: float = 0.0
var _empty_style: StyleBoxEmpty
var _swap_button_group: ButtonGroup
var _style_selected: StyleBoxFlat
var _style_unselected: StyleBoxFlat


func _ready() -> void:
	if not Engine.is_editor_hint():
		hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty_style = StyleBoxEmpty.new()
	_build_swap_styles()
	_setup_swap_buttons()
	_apply_card_input_style()
	_confirm.pressed.connect(_submit)
	_field.text_changed.connect(_on_name_typed)
	_field.text_submitted.connect(func(_t: String) -> void: _submit())
	_male_button.pressed.connect(_on_male_pressed)
	_female_button.pressed.connect(_on_female_pressed)
	_connect_game_state_signals()
	visibility_changed.connect(_on_visibility_changed)
	_id_stage.resized.connect(_sync_layout)
	_card_frame.resized.connect(_sync_layout)
	_id_preview.gui_input.connect(_on_id_clicked)
	_name_overlay.gui_input.connect(_on_id_clicked)
	if Engine.is_editor_hint():
		set_process(true)
	_refresh_id_preview()
	call_deferred("_sync_layout")


func _on_visibility_changed() -> void:
	if Engine.is_editor_hint():
		call_deferred("_sync_layout")


func _process(delta: float) -> void:
	if Engine.is_editor_hint() and is_visible_in_tree():
		_sync_layout()
	if not is_visible_in_tree():
		return
	if _revealed_name == _target_name:
		return
	if _revealed_name.length() < _target_name.length():
		_reveal_timer += delta
		while _reveal_timer >= CHAR_REVEAL_SEC and _revealed_name.length() < _target_name.length():
			_reveal_timer -= CHAR_REVEAL_SEC
			_revealed_name = _target_name.substr(0, _revealed_name.length() + 1)
			_name_on_id.text = _revealed_name
	else:
		_revealed_name = _target_name
		_name_on_id.text = _revealed_name


func show_modal() -> void:
	_field.text = ""
	_target_name = ""
	_revealed_name = ""
	_reveal_timer = 0.0
	_name_on_id.text = ""
	_error.text = ""
	_refresh_id_preview()
	_update_swap_buttons()
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	await get_tree().process_frame
	_sync_layout()
	_field_grab_focus()


func _field_grab_focus() -> void:
	_field.grab_focus()
	_field.caret_column = _field.text.length()


func _on_id_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_field_grab_focus()
			accept_event()


func _on_name_typed(_new_text: String) -> void:
	_error.text = ""
	_target_name = _field.text


func _setup_swap_buttons() -> void:
	_swap_button_group = ButtonGroup.new()
	_male_button.button_group = _swap_button_group
	_female_button.button_group = _swap_button_group
	_male_button.toggle_mode = true
	_female_button.toggle_mode = true


func _build_swap_styles() -> void:
	_style_selected = StyleBoxFlat.new()
	_style_selected.bg_color = Color(0.22, 0.42, 0.62, 1.0)
	_style_selected.border_color = Color(0.75, 0.9, 1.0, 1.0)
	_style_selected.set_border_width_all(2)
	_style_selected.set_corner_radius_all(8)
	_style_selected.content_margin_left = 12
	_style_selected.content_margin_right = 12
	_style_selected.content_margin_top = 8
	_style_selected.content_margin_bottom = 8

	_style_unselected = StyleBoxFlat.new()
	_style_unselected.bg_color = Color(0.1, 0.12, 0.18, 0.92)
	_style_unselected.border_color = Color(0.38, 0.42, 0.5, 1.0)
	_style_unselected.set_border_width_all(2)
	_style_unselected.set_corner_radius_all(8)
	_style_unselected.content_margin_left = 12
	_style_unselected.content_margin_right = 12
	_style_unselected.content_margin_top = 8
	_style_unselected.content_margin_bottom = 8


func _connect_game_state_signals() -> void:
	if Engine.is_editor_hint():
		return
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return
	if gs.has_signal("id_variant_changed") and not gs.is_connected("id_variant_changed", _on_id_variant_changed):
		gs.connect("id_variant_changed", _on_id_variant_changed)
	if not gs.is_connected("inventory_changed", _on_inventory_changed):
		gs.connect("inventory_changed", _on_inventory_changed)


func _on_inventory_changed() -> void:
	if is_visible_in_tree():
		_on_id_variant_changed()


func _on_male_pressed() -> void:
	if Engine.is_editor_hint():
		return
	GameState.set_id_variant("male")
	_on_id_variant_changed()


func _on_female_pressed() -> void:
	if Engine.is_editor_hint():
		return
	GameState.set_id_variant("female")
	_on_id_variant_changed()


func _on_id_variant_changed() -> void:
	_refresh_id_preview()
	_update_swap_buttons()


func _refresh_id_preview() -> void:
	if Engine.is_editor_hint():
		_id_preview.texture = ID_MALE
	else:
		_id_preview.texture = ID_FEMALE if GameState.id_variant == "female" else ID_MALE
	call_deferred("_sync_layout")


func _update_swap_buttons() -> void:
	var can_swap := true
	if not Engine.is_editor_hint():
		can_swap = GameState.can_swap_id_variant()
	_swap_block.visible = can_swap
	if not can_swap:
		return

	var is_male := GameState.id_variant == "male" if not Engine.is_editor_hint() else true
	_male_button.set_pressed_no_signal(is_male)
	_female_button.set_pressed_no_signal(not is_male)
	_male_button.disabled = false
	_female_button.disabled = false

	_apply_swap_style(_male_button, is_male, "Male ID")
	_apply_swap_style(_female_button, not is_male, "Female ID")


func _apply_swap_style(btn: Button, selected: bool, label: String) -> void:
	var style := _style_selected if selected else _style_unselected
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style)
	btn.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0) if selected else Color(0.72, 0.76, 0.82))
	btn.text = "▸ %s" % label if selected else label


func _apply_card_input_style() -> void:
	for style_name in ["normal", "focus", "read_only"]:
		_field.add_theme_stylebox_override(style_name, _empty_style)
	var hidden := Color(0.12, 0.1, 0.08, 0)
	_field.add_theme_color_override("font_color", hidden)
	_field.add_theme_color_override("font_uneditable_color", hidden)
	_field.add_theme_color_override("font_placeholder_color", hidden)
	_field.add_theme_color_override("caret_color", Color(0.12, 0.1, 0.08, 1))
	_field.placeholder_text = ""


func _name_uv_rect() -> Rect2:
	var uv := name_line_on_card
	return Rect2(
		clampf(uv.position.x, 0.0, 0.95),
		clampf(uv.position.y, 0.0, 0.95),
		clampf(uv.size.x, 0.02, 1.0),
		clampf(uv.size.y, 0.02, 1.0)
	)


func _available_stage_size() -> Vector2:
	var size := _id_stage.size
	if size.x <= 0.0 or size.y <= 0.0:
		return Vector2(1280, 720)
	return size


func _compute_card_pixel_size() -> Vector2:
	var tex: Texture2D = _id_preview.texture
	if tex == null:
		return Vector2(960, 540)
	var stage := _available_stage_size()
	var swap_reserve := SWAP_RESERVE_PX if _swap_block.visible else 0.0
	var max_w := stage.x * CARD_MAX_WIDTH_RATIO
	var max_h := maxf(280.0, stage.y - swap_reserve - 24.0)
	var tex_size := tex.get_size()
	var scale: float = minf(max_w / tex_size.x, max_h / tex_size.y)
	return tex_size * scale


func _sync_layout() -> void:
	if _card_frame == null or _name_overlay == null:
		return
	var card_size := _compute_card_pixel_size()
	_card_frame.custom_minimum_size = card_size
	_card_frame.size = card_size

	var uv := _name_uv_rect()
	var region := Rect2(
		Vector2(card_size.x * uv.position.x, card_size.y * uv.position.y),
		Vector2(card_size.x * uv.size.x, card_size.y * uv.size.y)
	)
	_name_overlay.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_name_overlay.position = region.position
	_name_overlay.size = region.size

	var font_size := int(maxf(14.0, region.size.y * 0.62))
	_name_on_id.add_theme_font_size_override("font_size", font_size)
	_field.add_theme_font_size_override("font_size", font_size)


func _submit() -> void:
	if Engine.is_editor_hint():
		return
	var entered := _field.text.strip_edges()
	if entered.length() < 2:
		_error.text = "Enter at least 2 characters on the card."
		_field_grab_focus()
		return
	if entered.length() > 24:
		_error.text = "Keep the name under 24 characters."
		_field_grab_focus()
		return
	GameState.set_player_name(entered)
	name_confirmed.emit(entered)
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _unhandled_input(event: InputEvent) -> void:
	if not visible or Engine.is_editor_hint():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_submit()
			get_viewport().set_input_as_handled()
