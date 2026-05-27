extends PanelContainer

signal name_confirmed(chosen_name: String)

@onready var _field: LineEdit = %NameField
@onready var _error: Label = %ErrorLabel
@onready var _confirm: Button = %ConfirmButton


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.pressed.connect(_submit)
	_field.text_submitted.connect(func(_t: String) -> void: _submit())


func show_modal() -> void:
	_field.text = ""
	_error.text = ""
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_field.grab_focus()


func _submit() -> void:
	var entered := _field.text.strip_edges()
	if entered.length() < 2:
		_error.text = "Enter at least 2 characters."
		return
	if entered.length() > 24:
		_error.text = "Keep the name under 24 characters."
		return
	GameState.set_player_name(entered)
	name_confirmed.emit(entered)
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
