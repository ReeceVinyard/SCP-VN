extends PanelContainer

signal advance_requested

const CHOICE_BUTTON_WIDTH := 640
const CHOICE_BUTTON_MIN_HEIGHT := 36
const CHOICE_FONT_SIZE := 16

@onready var _speaker_label: Label = %SpeakerLabel
@onready var _body_label: Label = %BodyLabel
@onready var _choice_overlay: Control = %ChoiceOverlay
@onready var _choices_box: VBoxContainer = %ChoicesBox
@onready var _continue_hint: Label = %ContinueHint

var _suppress_for_cutscene := false


func _ready() -> void:
	add_to_group("dialogue_box")
	DialogueManager.line_shown.connect(_on_line_shown)
	DialogueManager.choices_requested.connect(_on_choices_requested)
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_overlay.hide()
	_choice_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%ClickCatcher.gui_input.connect(_on_gui_input)
	hide()


func _has_active_choices() -> bool:
	return _choice_overlay.visible and _choices_box.get_child_count() > 0


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not DialogueManager.is_active:
		return
	if _has_active_choices():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			advance_requested.emit()
			get_viewport().set_input_as_handled()


func _on_gui_input(event: InputEvent) -> void:
	if not DialogueManager.is_active or _has_active_choices():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance_requested.emit()
		%ClickCatcher.accept_event()


## Hides the panel immediately and blocks deferred dialogue_ended from re-showing it
## for a frame while a full-screen cutscene starts.
func hide_for_cutscene() -> void:
	_suppress_for_cutscene = true
	hide()
	%ClickCatcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hide_choices()
	_speaker_label.text = ""
	_body_label.text = ""
	get_viewport().gui_release_focus()


func _on_dialogue_started() -> void:
	_suppress_for_cutscene = false
	show()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	%ClickCatcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_hide_choices()
	_continue_hint.show()


func _on_dialogue_ended(_ended_knot: String = "") -> void:
	call_deferred("_apply_dialogue_end_visibility")


func _apply_dialogue_end_visibility() -> void:
	if _suppress_for_cutscene:
		hide()
		%ClickCatcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hide_choices()
		return
	if DialogueManager.is_active:
		show()
		%ClickCatcher.mouse_filter = Control.MOUSE_FILTER_STOP
		_continue_hint.show()
		return
	hide()
	%ClickCatcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hide_choices()
	_speaker_label.text = ""
	_body_label.text = ""
	get_viewport().gui_release_focus()


func _on_line_shown(speaker: String, text: String) -> void:
	_speaker_label.text = speaker if not speaker.is_empty() else " "
	_body_label.text = text
	_hide_choices()
	_continue_hint.show()


func _on_choices_requested(options: Array) -> void:
	if _choices_box == null:
		push_error("ChoicesBox missing — check ChoiceLayer paths in main.tscn")
		return
	_clear_choices()
	_continue_hint.hide()
	_choice_overlay.show()
	_choice_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	for opt in options:
		var btn := Button.new()
		btn.text = opt["text"]
		btn.disabled = opt.get("disabled", false)
		btn.focus_mode = Control.FOCUS_ALL
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(CHOICE_BUTTON_WIDTH, CHOICE_BUTTON_MIN_HEIGHT)
		btn.add_theme_font_size_override("font_size", CHOICE_FONT_SIZE)
		var idx: int = opt["index"]
		btn.pressed.connect(func() -> void:
			_hide_choices()
			DialogueManager.choose(idx)
		)
		_choices_box.add_child(btn)
	if _choices_box.get_child_count() > 0:
		(_choices_box.get_child(0) as Button).grab_focus()


func _hide_choices() -> void:
	_clear_choices()
	_choice_overlay.hide()
	_choice_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _clear_choices() -> void:
	for child in _choices_box.get_children():
		child.queue_free()
