extends Control

signal closed(item_id: String, grant_item_on_close: bool)

const VIEWPORT_MARGIN := Vector2(48, 40)
const MAX_DOC_SIZE := Vector2(1680, 920)

@onready var _dim: ColorRect = %DocDim
@onready var _panel: PanelContainer = %DocPanel
@onready var _title: Label = %DocTitle
@onready var _scroll: ScrollContainer = %DocScroll
@onready var _image: TextureRect = %DocImage
@onready var _done_button: Button = %DocDoneButton

var _item_id: String = ""
var _grant_item_on_close: bool = false
var _exploration_was_enabled: bool = false
var _busy: bool = false


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_done_button.pressed.connect(_dismiss)


func show_document(item_id: String, grant_item_on_close: bool = false) -> void:
	if _busy:
		return
	if not ItemRegistry.is_readable_document(item_id):
		push_warning("Not a readable document: %s" % item_id)
		return
	_busy = true
	_item_id = item_id
	_grant_item_on_close = grant_item_on_close
	_populate()
	_exploration_was_enabled = GameState.exploration_enabled
	GameState.disable_exploration()
	_dim.modulate.a = 0.0
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	await get_tree().process_frame
	_layout_document()
	var fade := create_tween()
	fade.tween_property(_dim, "modulate:a", 1.0, 0.2)
	_done_button.grab_focus()


func _populate() -> void:
	_title.text = ItemRegistry.get_display_name(_item_id)
	var icon_path := ItemRegistry.get_icon_path(_item_id)
	var texture: Texture2D = load(icon_path) as Texture2D if not icon_path.is_empty() else null
	_image.texture = texture
	_image.visible = texture != null


func _layout_document() -> void:
	var viewport_size := get_viewport_rect().size
	if size.x > 0.0 and size.y > 0.0:
		viewport_size = size
	var panel_size := Vector2(
		minf(MAX_DOC_SIZE.x, viewport_size.x - VIEWPORT_MARGIN.x * 2.0),
		minf(MAX_DOC_SIZE.y, viewport_size.y - VIEWPORT_MARGIN.y * 2.0)
	)
	_panel.custom_minimum_size = panel_size
	_panel.size = panel_size
	_panel.position = (viewport_size - panel_size) * 0.5
	if _image.texture == null:
		return
	var tex_size := _image.texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var scroll_size := _scroll.size
	if scroll_size.x < 8.0 or scroll_size.y < 8.0:
		await get_tree().process_frame
		scroll_size = _scroll.size
	var width_fit := scroll_size.x / tex_size.x
	width_fit = minf(width_fit, 1.0)
	var display_size := Vector2(tex_size.x * width_fit, tex_size.y * width_fit)
	_image.custom_minimum_size = display_size
	_image.size = display_size
	_scroll.scroll_vertical = 0
	_scroll.scroll_horizontal = 0


func _dismiss() -> void:
	if not visible or not _busy:
		return
	_done_button.disabled = true
	var fade := create_tween()
	fade.tween_property(_dim, "modulate:a", 0.0, 0.15)
	await fade.finished
	_finish()


func _finish() -> void:
	var item_id := _item_id
	var grant := _grant_item_on_close
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_done_button.disabled = false
	if _exploration_was_enabled:
		GameState.enable_exploration()
	else:
		GameState.disable_exploration()
	_item_id = ""
	_grant_item_on_close = false
	_busy = false
	closed.emit(item_id, grant)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _busy:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_ESCAPE:
			_dismiss()
			get_viewport().set_input_as_handled()
