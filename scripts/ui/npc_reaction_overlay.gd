extends Control

signal finished

const _ReactionRegistry = preload("res://scripts/data/reaction_registry.gd")

@export var default_duration_sec: float = 5.0

@onready var _dim: ColorRect = %ReactionDim
@onready var _accent_bar: ColorRect = %ReactionAccent
@onready var _npc_label: Label = %ReactionNpc
@onready var _mood_label: Label = %ReactionMood
@onready var _headline_label: Label = %ReactionHeadline
@onready var _detail_label: Label = %ReactionDetail
@onready var _timer_bar: ProgressBar = %ReactionTimerBar

var _busy: bool = false
var _exploration_was_enabled: bool = false
var _tween: Tween


func _ready() -> void:
	add_to_group("npc_reaction_overlay")
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_bar.show_percentage = false


func show_reaction(reaction: Dictionary) -> void:
	if _busy:
		return
	var data: Dictionary = _ReactionRegistry.resolve(reaction)
	_busy = true
	_populate(data)
	_exploration_was_enabled = GameState.exploration_enabled
	GameState.disable_exploration()
	_dim.modulate.a = 0.0
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	await get_tree().process_frame
	var fade_in := create_tween()
	fade_in.tween_property(_dim, "modulate:a", 1.0, 0.25)
	var duration: float = maxf(0.5, float(data.get("duration_sec", default_duration_sec)))
	_timer_bar.max_value = duration
	_timer_bar.value = duration
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_timer_bar, "value", 0.0, duration)
	await _tween.finished
	await _fade_out_and_finish()


func _populate(data: Dictionary) -> void:
	var npc: String = str(data.get("npc", ""))
	var mood_label: String = str(data.get("mood_label", ""))
	_npc_label.text = npc
	_mood_label.text = mood_label
	_headline_label.text = str(data.get("headline", ""))
	var detail: String = str(data.get("detail", ""))
	_detail_label.text = detail
	_detail_label.visible = not detail.is_empty()
	var accent: Color = data.get("accent", Color.WHITE)
	_accent_bar.color = accent
	_mood_label.add_theme_color_override("font_color", accent)


func _fade_out_and_finish() -> void:
	_kill_tween()
	var fade := create_tween()
	fade.tween_property(_dim, "modulate:a", 0.0, 0.2)
	await fade.finished
	_finish()


func _finish() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _exploration_was_enabled:
		GameState.enable_exploration()
	else:
		GameState.disable_exploration()
	_busy = false
	finished.emit()


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _busy:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_ESCAPE:
			_skip()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_skip()
		get_viewport().set_input_as_handled()


func _skip() -> void:
	if not _busy:
		return
	_kill_tween()
	_finish()
