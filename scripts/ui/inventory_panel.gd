extends Control

const ICON_MIN_SIZE := Vector2(560, 360)

@onready var _dim: ColorRect = %InvDim
@onready var _list: ItemList = %ItemList
@onready var _item_name: Label = %InvItemName
@onready var _description: Label = %DescriptionLabel
@onready var _icon: TextureRect = %ItemIcon
@onready var _swap_row: HBoxContainer = %IdSwapRow
@onready var _male_button: Button = %InvIdMaleButton
@onready var _female_button: Button = %InvIdFemaleButton
@onready var _close_button: Button = %InvCloseButton
@onready var _empty_label: Label = %InvEmptyLabel

var _exploration_was_enabled: bool = false


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.custom_minimum_size = ICON_MIN_SIZE
	GameState.inventory_changed.connect(_refresh)
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_signal("id_variant_changed") and not gs.is_connected("id_variant_changed", _refresh):
		gs.connect("id_variant_changed", _refresh)
	_list.item_selected.connect(_on_item_selected)
	_male_button.pressed.connect(func() -> void: GameState.set_id_variant("male"))
	_female_button.pressed.connect(func() -> void: GameState.set_id_variant("female"))
	_close_button.pressed.connect(close)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if visible or not GameState.exploration_enabled:
		return
	_exploration_was_enabled = GameState.exploration_enabled
	GameState.exploration_enabled = false
	_dim.modulate.a = 1.0
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh()
	_close_button.grab_focus()


func close() -> void:
	if not visible:
		return
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.exploration_enabled = _exploration_was_enabled


func _refresh() -> void:
	_list.clear()
	for item_id in GameState.inventory:
		var label: String = ItemRegistry.get_display_name(item_id)
		if GameState.selected_item_id == item_id:
			label = "▸ " + label
		_list.add_item(label)
	var has_items := _list.item_count > 0
	_empty_label.visible = not has_items
	_list.visible = has_items
	if not has_items:
		_show_empty()
		return
	var select_index := 0
	if not GameState.selected_item_id.is_empty():
		select_index = GameState.inventory.find(GameState.selected_item_id)
		if select_index < 0:
			select_index = 0
	_list.select(select_index)
	_show_item(select_index, false)


func _show_empty() -> void:
	_item_name.text = "No items"
	_description.text = "Search the room and pick up anything useful."
	_icon.texture = null
	_icon.visible = false
	_swap_row.visible = false


func _on_item_selected(index: int) -> void:
	_show_item(index, true)


func _show_item(index: int, update_selection: bool) -> void:
	if index < 0:
		_show_empty()
		return
	var item_id: String = GameState.inventory[index]
	_item_name.text = ItemRegistry.get_display_name(item_id)
	_description.text = ItemRegistry.get_description(item_id)
	var icon_path := ItemRegistry.get_icon_path(item_id)
	if icon_path.is_empty():
		_icon.texture = null
		_icon.visible = false
	else:
		_icon.texture = load(icon_path) as Texture2D
		_icon.visible = _icon.texture != null
	var show_swap := item_id == "researcher_id" and GameState.can_swap_id_variant()
	_swap_row.visible = show_swap
	if show_swap:
		_apply_swap_style(_male_button, GameState.id_variant == "male", "Male ID")
		_apply_swap_style(_female_button, GameState.id_variant == "female", "Female ID")
	if update_selection:
		GameState.select_item(item_id, false)


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
