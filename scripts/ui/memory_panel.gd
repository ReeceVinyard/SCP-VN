extends Control

## Memory Fragment menu. The player pieces together the Main Character's memory.
## Locked fragments show as silhouettes so progress is visible; unlocked ones
## reveal their title, chapter, recovered text, and art (placeholder until final).

@onready var _dim: ColorRect = %MemDim
@onready var _list: ItemList = %MemList
@onready var _empty_label: Label = %MemEmptyLabel
@onready var _progress_label: Label = %MemProgress
@onready var _title: Label = %FragTitle
@onready var _chapter: Label = %FragChapter
@onready var _text: Label = %FragText
@onready var _image: TextureRect = %FragImage
@onready var _placeholder: Panel = %FragPlaceholder
@onready var _placeholder_label: Label = %FragPlaceholderLabel
@onready var _close_button: Button = %MemCloseButton

const LOCKED_LABEL := "🔒  Locked memory"

var _exploration_was_enabled: bool = false
var _ids: Array = []


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.memory_fragments_changed.connect(_on_memories_changed)
	_list.item_selected.connect(_on_item_selected)
	_close_button.pressed.connect(close)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if visible or not GameState.exploration_enabled:
		return
	_exploration_was_enabled = GameState.exploration_enabled
	GameState.disable_exploration()
	_dim.modulate.a = 1.0
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh()
	_close_button.grab_focus()


func close() -> void:
	if not visible:
		return
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _exploration_was_enabled:
		GameState.enable_exploration()
	else:
		GameState.disable_exploration()


func _on_memories_changed() -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	var prev_index := -1
	var selected := _list.get_selected_items()
	if not selected.is_empty():
		prev_index = selected[0]
	_list.clear()
	_ids = MemoryRegistry.ordered_ids()
	for fragment_id in _ids:
		if GameState.is_memory_unlocked(fragment_id):
			_list.add_item(MemoryRegistry.get_title(fragment_id))
		else:
			var idx := _list.add_item(LOCKED_LABEL)
			_list.set_item_custom_fg_color(idx, Color(0.55, 0.58, 0.66))
	_progress_label.text = "Recovered %d / %d" % [GameState.unlocked_memory_count(), GameState.total_memory_count()]
	var total := _list.item_count
	_empty_label.visible = total == 0
	_list.visible = total > 0
	if total == 0:
		_show_blank()
		return
	var select_index: int = clampi(prev_index, 0, total - 1) if prev_index >= 0 else 0
	_list.select(select_index)
	_show_fragment(select_index)


func _show_blank() -> void:
	_title.text = ""
	_chapter.text = ""
	_text.text = ""
	_set_art("")


func _on_item_selected(index: int) -> void:
	_show_fragment(index)


func _show_fragment(index: int) -> void:
	if index < 0 or index >= _ids.size():
		_show_blank()
		return
	var fragment_id: String = _ids[index]
	if not GameState.is_memory_unlocked(fragment_id):
		_title.text = "Locked memory"
		_chapter.text = MemoryRegistry.get_chapter(fragment_id)
		_text.text = MemoryRegistry.get_locked_hint(fragment_id)
		_set_art("", true)
		return
	_title.text = MemoryRegistry.get_title(fragment_id)
	_chapter.text = MemoryRegistry.get_chapter(fragment_id)
	_text.text = MemoryRegistry.get_text(fragment_id)
	_set_art(MemoryRegistry.get_icon_path(fragment_id))


## Show the fragment art, or a styled placeholder when art is missing/locked.
func _set_art(icon_path: String, locked: bool = false) -> void:
	var texture: Texture2D = null
	if not icon_path.is_empty():
		texture = load(icon_path) as Texture2D
	if texture != null:
		_image.texture = texture
		_image.visible = true
		_placeholder.visible = false
		return
	_image.texture = null
	_image.visible = false
	_placeholder.visible = true
	_placeholder_label.text = "Memory not yet recovered" if locked else "Artwork pending"


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_memories") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
