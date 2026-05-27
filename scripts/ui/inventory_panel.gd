extends PanelContainer

@onready var _list: ItemList = %ItemList
@onready var _description: Label = %DescriptionLabel


func _ready() -> void:
	hide()
	GameState.inventory_changed.connect(_refresh)
	_list.item_selected.connect(_on_item_selected)


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
		return
	var item_id: String = GameState.inventory[index]
	_description.text = ItemRegistry.get_description(item_id)
	if update_selection:
		GameState.select_item(item_id, false)
