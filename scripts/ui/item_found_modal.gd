extends Control

signal confirmed

const CARD_SIZE := Vector2(920, 380)
const ICON_MAX_SIZE := Vector2(400, 300)
const SLIDE_IN_SEC := 0.5
const SLIDE_OUT_SEC := 0.42
const OFFSCREEN_PAD := 48.0

@onready var _dim: ColorRect = %FoundDim
@onready var _slide_host: Control = %FoundSlideHost
@onready var _title: Label = %FoundTitle
@onready var _item_name: Label = %FoundItemName
@onready var _description: Label = %FoundDescription
@onready var _icon: TextureRect = %FoundItemIcon
@onready var _confirm: Button = %FoundConfirmButton

var _exploration_was_enabled: bool = false
var _center_x: float = 0.0
var _tween: Tween
var _busy: bool = false


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.custom_minimum_size = ICON_MAX_SIZE
	_icon.size = ICON_MAX_SIZE
	_confirm.pressed.connect(_dismiss)


func show_item(item_id: String) -> void:
	if _busy:
		return
	_busy = true
	_populate(item_id)
	_exploration_was_enabled = GameState.exploration_enabled
	GameState.disable_exploration()
	_confirm.disabled = true
	_dim.modulate.a = 0.0
	_slide_host.modulate.a = 1.0
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	await get_tree().process_frame
	await get_tree().process_frame
	_lock_slide_host_layout()
	_slide_host.position = Vector2(-CARD_SIZE.x - OFFSCREEN_PAD, _slide_host.position.y)
	await _play_slide_in()


func _populate(item_id: String) -> void:
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


func _lock_slide_host_layout() -> void:
	var viewport_size := get_viewport_rect().size
	if size.x > 0.0 and size.y > 0.0:
		viewport_size = size
	_slide_host.custom_minimum_size = CARD_SIZE
	_slide_host.size = CARD_SIZE
	_slide_host.position.y = (viewport_size.y - CARD_SIZE.y) * 0.5
	_center_x = (viewport_size.x - CARD_SIZE.x) * 0.5


func _play_slide_in() -> void:
	_kill_tween()
	var fade := create_tween()
	fade.tween_property(_dim, "modulate:a", 1.0, SLIDE_IN_SEC * 0.65)
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_slide_host, "position:x", _center_x, SLIDE_IN_SEC)
	await _tween.finished
	_confirm.disabled = false
	_confirm.grab_focus()


func _dismiss() -> void:
	if not visible or _confirm.disabled:
		return
	_confirm.disabled = true
	await _play_slide_out()


func _play_slide_out() -> void:
	_kill_tween()
	var viewport_size := get_viewport_rect().size
	var exit_x := viewport_size.x + OFFSCREEN_PAD
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_slide_host, "position:x", exit_x, SLIDE_OUT_SEC)
	var fade := create_tween()
	fade.tween_property(_dim, "modulate:a", 0.0, SLIDE_OUT_SEC * 0.85)
	await _tween.finished
	_finish_dismiss()


func _finish_dismiss() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _exploration_was_enabled:
		GameState.enable_exploration()
	else:
		GameState.disable_exploration()
	_busy = false
	confirmed.emit()


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _confirm.disabled:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			_dismiss()
			get_viewport().set_input_as_handled()
