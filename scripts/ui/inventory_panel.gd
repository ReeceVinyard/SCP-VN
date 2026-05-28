extends PanelContainer

@onready var _list: ItemList = %ItemList
@onready var _description: Label = %DescriptionLabel
@onready var _icon: TextureRect = %ItemIcon
@onready var _swap_row: HBoxContainer = %IdSwapRow
@onready var _male_button: Button = %InvIdMaleButton
@onready var _female_button: Button = %InvIdFemaleButton


func _ready() -> void:
	hide()
	GameState.inventory_changed.connect(_refresh)
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_signal("id_variant_changed") and not gs.is_connected("id_variant_changed", _refresh):
		gs.connect("id_variant_changed", _refresh)
	_list.item_selected.connect(_on_item_selected)
	_male_button.pressed.connect(func() -> void: GameState.set_id_variant("male"))
	_female_button.pressed.connect(func() -> void: GameState.set_id_variant("female"))


func toggle() -> void:
	visible = not visible
	if visible:
		_refresh()


func _refresh() -> void:
	_list.clear()
	for item_id in GameState.inventory:
		var label: String = ItemRegistry.get_display_name(item_id)
		if GameState.selected_item_id == item_id:
			label = "▸ " + label
		_list.add_item(label)
	if _list.item_count == 0:
		_description.text = "No items yet."
		_icon.texture = null
		_swap_row.visible = false
		return
	var select_index := 0
	if not GameState.selected_item_id.is_empty():
		select_index = GameState.inventory.find(GameState.selected_item_id)
		if select_index < 0:
			select_index = 0
	_list.select(select_index)
	_show_item(select_index, false)


func _on_item_selected(index: int) -> void:
	_show_item(index, true)


func _show_item(index: int, update_selection: bool) -> void:
	if index < 0:
		_description.text = "No items yet."
		_icon.texture = null
		_swap_row.visible = false
		return
	var item_id: String = GameState.inventory[index]
	_description.text = ItemRegistry.get_description(item_id)
	var icon_path := ItemRegistry.get_icon_path(item_id)
	if icon_path.is_empty():
		_icon.texture = null
	else:
		_icon.texture = load(icon_path) as Texture2D
	var show_swap := item_id == "researcher_id" and GameState.can_swap_id_variant()
	_swap_row.visible = show_swap
	if show_swap:
		_male_button.disabled = GameState.id_variant == "male"
		_female_button.disabled = GameState.id_variant == "female"
	if update_selection:
		GameState.select_item(item_id, false)
