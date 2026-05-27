extends PanelContainer

signal advance_requested

@onready var _speaker_label: Label = %SpeakerLabel
@onready var _body_label: RichTextLabel = %BodyLabel
@onready var _choices_box: VBoxContainer = %ChoicesBox
@onready var _continue_hint: Label = %ContinueHint


func _ready() -> void:
	DialogueManager.line_shown.connect(_on_line_shown)
	DialogueManager.choices_requested.connect(_on_choices_requested)
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not DialogueManager.is_active:
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		if _choices_box.get_child_count() == 0:
			advance_requested.emit()
			get_viewport().set_input_as_handled()


func _on_dialogue_started() -> void:
	show()
	_choices_box.hide()
	_continue_hint.show()


func _on_dialogue_ended() -> void:
	hide()
	_clear_choices()


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
		var idx: int = opt["index"]
		btn.pressed.connect(func() -> void:
			DialogueManager.choose(idx)
		)
		_choices_box.add_child(btn)


func _clear_choices() -> void:
	for child in _choices_box.get_children():
		child.queue_free()
