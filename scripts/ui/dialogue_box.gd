extends PanelContainer

signal advance_requested

@onready var _speaker_label: Label = %SpeakerLabel
@onready var _body_label: Label = %BodyLabel
@onready var _choices_box: VBoxContainer = %ChoicesBox
@onready var _continue_hint: Label = %ContinueHint


func _ready() -> void:
	DialogueManager.line_shown.connect(_on_line_shown)
	DialogueManager.choices_requested.connect(_on_choices_requested)
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	%ClickCatcher.gui_input.connect(_on_gui_input)
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not DialogueManager.is_active:
		return
	if _choices_box.get_child_count() > 0:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			advance_requested.emit()
			get_viewport().set_input_as_handled()


func _on_gui_input(event: InputEvent) -> void:
	if not DialogueManager.is_active or _choices_box.get_child_count() > 0:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance_requested.emit()
		%ClickCatcher.accept_event()


func _on_dialogue_started() -> void:
	show()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	%ClickCatcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_choices_box.hide()
	_continue_hint.show()


func _on_dialogue_ended() -> void:
	hide()
	%ClickCatcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear_choices()
	_speaker_label.text = ""
	_body_label.text = ""
	get_viewport().gui_release_focus()


func _on_line_shown(speaker: String, text: String) -> void:
	_speaker_label.text = speaker if not speaker.is_empty() else " "
	_body_label.text = text
	_clear_choices()
	_choices_box.hide()
	_continue_hint.show()


func _on_choices_requested(options: Array) -> void:
	_clear_choices()
	_continue_hint.hide()
	_choices_box.show()
	for opt in options:
		var btn := Button.new()
		btn.text = opt["text"]
		btn.disabled = opt.get("disabled", false)
		btn.focus_mode = Control.FOCUS_ALL
		var idx: int = opt["index"]
		btn.pressed.connect(func() -> void:
			DialogueManager.choose(idx)
		)
		_choices_box.add_child(btn)
	if _choices_box.get_child_count() > 0:
		(_choices_box.get_child(0) as Button).grab_focus()


func _clear_choices() -> void:
	for child in _choices_box.get_children():
		child.queue_free()
