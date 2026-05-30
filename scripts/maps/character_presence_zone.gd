@tool
extends Control
class_name CharacterPresenceZone

## Place characters in the map scene. Visibility is driven by story tags + GameState flags.

const _CharacterRegistry = preload("res://scripts/data/character_registry.gd")
const _InteractableRegistry = preload("res://scripts/data/interactable_registry.gd")
const DEFAULT_FADE_SEC := 2.0

@export var overlay_key: String = "chase_at_door"
@export var show_in_editor: bool = true
@export var editor_preview_mood: String = "normal"

@onready var _sprite: TextureRect = _resolve_sprite()

var _fade_tween: Tween
var _is_faded_in: bool = false


func _ready() -> void:
	z_index = _InteractableRegistry.CHARACTER_PRESENCE_Z_INDEX
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _sprite:
		_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Engine.is_editor_hint():
		_apply_editor_preview()
		return
	if _sprite:
		_sprite.visible = false
		_sprite.modulate = Color(1, 1, 1, 0)
	if not DialogueManager.character_presence_fade_in.is_connected(_on_fade_in_requested):
		DialogueManager.character_presence_fade_in.connect(_on_fade_in_requested)
	if not DialogueManager.map_character_mood_changed.is_connected(_on_map_mood_changed):
		DialogueManager.map_character_mood_changed.connect(_on_map_mood_changed)
	if not GameState.flags_changed.is_connected(_on_flags_changed):
		GameState.flags_changed.connect(_on_flags_changed)
	call_deferred("sync_presence_from_flags")


func is_present_visible() -> bool:
	return _is_faded_in


func get_texture_rect() -> TextureRect:
	return _resolve_sprite()


## Resolve this zone's own sprite by relative path so multiple presence zones
## can coexist in one scene (no shared %Sprite unique-name collision).
func _resolve_sprite() -> TextureRect:
	var direct := get_node_or_null("Sprite")
	if direct is TextureRect:
		return direct as TextureRect
	for child in get_children():
		if child is TextureRect:
			return child as TextureRect
	return null


func _on_fade_in_requested(key: String, duration_sec: float) -> void:
	if key != overlay_key:
		return
	show_with_fade(duration_sec)


func _on_map_mood_changed(_character: String, _mood: String) -> void:
	if _character != "Chase":
		return
	if not _CharacterRegistry.is_chase_presence_visible(overlay_key):
		return
	sync_presence_from_flags()


func _on_flags_changed() -> void:
	if not _is_faded_in:
		return
	if GameState.has_flag("chase_lied_keycard") or GameState.has_flag("chase_told_amnesia"):
		_apply_runtime_texture()


func show_with_fade(duration_sec: float = DEFAULT_FADE_SEC) -> void:
	var sprite := get_texture_rect()
	if sprite == null:
		return
	_apply_runtime_texture()
	sprite.visible = true
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	sprite.modulate = Color(1, 1, 1, 0)
	z_index = _InteractableRegistry.CHARACTER_PRESENCE_Z_INDEX
	var parent_layer := get_parent()
	if parent_layer:
		parent_layer.move_child(self, -1)
	_fade_tween = create_tween()
	_fade_tween.set_ease(Tween.EASE_OUT)
	_fade_tween.set_trans(Tween.TRANS_SINE)
	_fade_tween.tween_property(sprite, "modulate:a", 1.0, maxf(0.1, duration_sec))
	_fade_tween.tween_callback(func() -> void: _is_faded_in = true)


func hide_with_fade(duration_sec: float = DEFAULT_FADE_SEC) -> void:
	var sprite := get_texture_rect()
	if sprite == null or not _is_faded_in:
		hide_presence()
		return
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.set_ease(Tween.EASE_IN)
	_fade_tween.set_trans(Tween.TRANS_SINE)
	_fade_tween.tween_property(sprite, "modulate:a", 0.0, maxf(0.1, duration_sec))
	await _fade_tween.finished
	hide_presence()


func sync_presence_from_flags() -> void:
	if not _CharacterRegistry.is_chase_presence_visible(overlay_key):
		hide_presence()
		return
	_apply_runtime_texture()
	var sprite := get_texture_rect()
	if sprite == null:
		return
	# Don't interrupt an in-progress fade (e.g. dialogue mood updates firing
	# while Chase is still fading in) — let the tween finish so he doesn't snap.
	if _fade_tween and _fade_tween.is_valid() and _fade_tween.is_running():
		sprite.visible = true
		return
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	sprite.visible = true
	sprite.modulate = Color(1, 1, 1, 1)
	_is_faded_in = true
	z_index = _InteractableRegistry.CHARACTER_PRESENCE_Z_INDEX


func hide_presence() -> void:
	_is_faded_in = false
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	var sprite := get_texture_rect()
	if sprite == null:
		return
	sprite.visible = false
	sprite.modulate = Color(1, 1, 1, 0)


func _apply_runtime_texture() -> void:
	var sprite := get_texture_rect()
	if sprite == null:
		return
	var map_id := _resolve_map_id()
	var path := _CharacterRegistry.resolve_map_presence_texture(map_id, overlay_key)
	if path.is_empty():
		return
	var texture := load(path) as Texture2D
	if texture:
		sprite.texture = texture


func _resolve_map_id() -> String:
	var layer := get_parent()
	if layer and layer.get("map_id"):
		return str(layer.get("map_id"))
	return "hall_papers"


func _apply_editor_preview() -> void:
	if not show_in_editor or _sprite == null:
		return
	var path := _preview_texture_path()
	if path.is_empty():
		return
	var texture := load(path) as Texture2D
	if texture:
		_sprite.texture = texture
	_sprite.visible = true
	_sprite.modulate = Color(1, 1, 1, 0.9)


func _preview_texture_path() -> String:
	return _CharacterRegistry.resolve_portrait_path("Chase", editor_preview_mood)


func _notification(what: int) -> void:
	if Engine.is_editor_hint() and what == NOTIFICATION_EDITOR_PRE_SAVE:
		_apply_editor_preview()
