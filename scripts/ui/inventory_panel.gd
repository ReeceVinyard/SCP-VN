extends Control

const ICON_MIN_SIZE := Vector2(520, 320)
const CARD_SIZE := Vector2(900, 760)
const SLIDE_SEC := 0.24
const OFFSCREEN_PAD := 80.0

@onready var _dim: ColorRect = %InvDim
@onready var _card_host: Control = %InvCardHost
@onready var _item_name: Label = %InvItemName
@onready var _description: Label = %DescriptionLabel
@onready var _icon: TextureRect = %ItemIcon
@onready var _icon_placeholder: Panel = %InvIconPlaceholder
@onready var _category: Label = %InvCategoryLabel
@onready var _swap_row: HBoxContainer = %IdSwapRow
@onready var _male_button: Button = %InvIdMaleButton
@onready var _female_button: Button = %InvIdFemaleButton
@onready var _close_button: Button = %InvCloseButton
@onready var _read_button: Button = %InvReadButton
@onready var _empty_label: Label = %InvEmptyLabel
@onready var _prev_button: Button = %InvPrevButton
@onready var _next_button: Button = %InvNextButton
@onready var _counter: Label = %InvCounterLabel

signal read_document_requested(item_id: String)

var _exploration_was_enabled: bool = false
var _index: int = 0
var _center: Vector2 = Vector2.ZERO
var _anim_busy: bool = false
var _tween: Tween


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.custom_minimum_size = ICON_MIN_SIZE
	_icon_placeholder.custom_minimum_size = ICON_MIN_SIZE
	_card_host.custom_minimum_size = CARD_SIZE
	GameState.inventory_changed.connect(_on_inventory_changed)
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_signal("id_variant_changed") and not gs.is_connected("id_variant_changed", _on_id_variant_changed):
		gs.connect("id_variant_changed", _on_id_variant_changed)
	_male_button.pressed.connect(func() -> void: GameState.set_id_variant("male"))
	_female_button.pressed.connect(func() -> void: GameState.set_id_variant("female"))
	_close_button.pressed.connect(close)
	_read_button.pressed.connect(_on_read_pressed)
	_prev_button.pressed.connect(func() -> void: _go(-1))
	_next_button.pressed.connect(func() -> void: _go(1))


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if visible or not GameState.exploration_enabled:
		return
	_exploration_was_enabled = GameState.exploration_enabled
	GameState.disable_exploration()
	_dim.modulate.a = 1.0
	_index = _current_selected_index()
	_layout_card()
	_refresh()
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_close_button.grab_focus()


func close() -> void:
	if not visible:
		return
	_kill_tween()
	_anim_busy = false
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _exploration_was_enabled:
		GameState.enable_exploration()
	else:
		GameState.disable_exploration()


## Index of the currently selected item, so the carousel opens on it.
func _current_selected_index() -> int:
	if GameState.selected_item_id.is_empty():
		return 0
	var idx := GameState.inventory.find(GameState.selected_item_id)
	return idx if idx >= 0 else 0


## Size + centre the sliding card for the current viewport.
func _layout_card() -> void:
	var vp := get_viewport_rect().size
	_card_host.size = CARD_SIZE
	_center = Vector2((vp.x - CARD_SIZE.x) * 0.5, (vp.y - CARD_SIZE.y) * 0.5)
	_card_host.position = _center


func _on_inventory_changed() -> void:
	if not visible:
		return
	_refresh()


func _on_id_variant_changed(_variant: Variant = null) -> void:
	if visible and not GameState.inventory.is_empty():
		_show_item(_index, false)


func _refresh() -> void:
	var n := GameState.inventory.size()
	var has_items := n > 0
	var multi := n > 1
	_empty_label.visible = not has_items
	_card_host.visible = has_items
	_prev_button.visible = has_items
	_next_button.visible = has_items
	_counter.visible = has_items
	_prev_button.disabled = not multi
	_next_button.disabled = not multi
	if not has_items:
		return
	_index = clampi(_index, 0, n - 1)
	_card_host.position = _center
	_show_item(_index, true)


## Slide to the next (+1) or previous (-1) item: current card exits one side and
## the new one enters from the other, mirroring the found-item animation.
func _go(direction: int) -> void:
	if _anim_busy or not visible:
		return
	var n := GameState.inventory.size()
	if n <= 1:
		return
	_anim_busy = true
	_layout_card()
	_index = (_index + direction + n) % n
	var travel := CARD_SIZE.x + OFFSCREEN_PAD
	var out_x := _center.x - travel if direction > 0 else _center.x + travel
	var in_x := _center.x + travel if direction > 0 else _center.x - travel
	_kill_tween()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_card_host, "position:x", out_x, SLIDE_SEC)
	await _tween.finished
	if not visible:
		_anim_busy = false
		return
	_show_item(_index, true)
	_card_host.position.x = in_x
	_kill_tween()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_card_host, "position:x", _center.x, SLIDE_SEC)
	await _tween.finished
	_anim_busy = false


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


## Show the item icon, or a styled placeholder when art is missing.
func _set_icon(icon_path: String) -> void:
	var texture: Texture2D = null
	if not icon_path.is_empty():
		texture = load(icon_path) as Texture2D
	if texture != null:
		_icon.texture = texture
		_icon.visible = true
		_icon_placeholder.visible = false
	else:
		_icon.texture = null
		_icon.visible = false
		_icon_placeholder.visible = true


func _show_item(index: int, update_selection: bool) -> void:
	if index < 0 or index >= GameState.inventory.size():
		return
	var item_id: String = GameState.inventory[index]
	_item_name.text = ItemRegistry.get_display_name(item_id)
	_description.text = ItemRegistry.get_description(item_id)
	var category := ItemRegistry.get_category(item_id)
	_category.text = category
	_category.visible = not category.is_empty()
	_set_icon(ItemRegistry.get_icon_path(item_id))
	var show_swap := item_id == "researcher_id" and GameState.can_swap_id_variant()
	_swap_row.visible = show_swap
	_read_button.visible = ItemRegistry.is_readable_document(item_id)
	if show_swap:
		_apply_swap_style(_male_button, GameState.id_variant == "male", "Male ID")
		_apply_swap_style(_female_button, GameState.id_variant == "female", "Female ID")
	_counter.text = "%d / %d" % [index + 1, GameState.inventory.size()]
	if update_selection:
		GameState.select_item(item_id, false)


func _on_read_pressed() -> void:
	if _index < 0 or _index >= GameState.inventory.size():
		return
	var item_id: String = GameState.inventory[_index]
	if not ItemRegistry.is_readable_document(item_id):
		return
	read_document_requested.emit(item_id)


func _apply_swap_style(btn: Button, selected: bool, label: String) -> void:
	btn.disabled = false
	btn.text = "▸ %s" % label if selected else label
	btn.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0) if selected else Color(0.72, 0.76, 0.82))


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_inventory") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_left"):
		_go(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_go(1)
		get_viewport().set_input_as_handled()
