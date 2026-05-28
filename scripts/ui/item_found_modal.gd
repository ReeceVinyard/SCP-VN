extends PanelContainer

signal confirmed

@onready var _title: Label = %FoundTitle
@onready var _item_name: Label = %FoundItemName
@onready var _description: Label = %FoundDescription
@onready var _icon: TextureRect = %FoundItemIcon
@onready var _confirm: Button = %FoundConfirmButton

var _exploration_was_enabled: bool = false


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.pressed.connect(_dismiss)


func show_item(item_id: String) -> void:
	_title.text = "You found"
	_item_name.text = ItemRegistry.get_display_name(item_id)
	_description.text = ItemRegistry.get_description(item_id)
	var icon_path := ItemRegistry.get_icon_path(item_id)
	if icon_path.is_empty():
		_icon.texture = null
		_icon.visible = false
	else:
		_icon.texture = load(icon_path) as Texture2D
		_icon.visible = _icon.texture != null
	_exploration_was_enabled = GameState.exploration_enabled
	GameState.exploration_enabled = false
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm.grab_focus()


func _dismiss() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.exploration_enabled = _exploration_was_enabled
	confirmed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			_dismiss()
			get_viewport().set_input_as_handled()
