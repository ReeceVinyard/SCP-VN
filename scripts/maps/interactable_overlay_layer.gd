extends Control

const _InteractableRegistry = preload("res://scripts/data/interactable_registry.gd")

## Full-screen interactable art that glows on hotspot hover.

const GLOW_COLOR := Color(1.18, 1.14, 1.05, 1.0)
const HIDDEN_COLOR := Color(1, 1, 1, 0)

@export var map_id: String = "archives"

var _overlays: Dictionary = {}
var _secondary_overlays: Dictionary = {}
var _active_id: String = ""
var _tween: Tween
var _secondary_tweens: Array[Tween] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	call_deferred("_setup_overlays")
	call_deferred("_connect_hotspots")
	if not GameState.inventory_changed.is_connected(_on_inventory_changed):
		GameState.inventory_changed.connect(_on_inventory_changed)
	if not GameState.flags_changed.is_connected(_on_flags_changed):
		GameState.flags_changed.connect(_on_flags_changed)
	if not DialogueManager.map_character_mood_changed.is_connected(_on_map_character_mood_changed):
		DialogueManager.map_character_mood_changed.connect(_on_map_character_mood_changed)


func _setup_overlays() -> void:
	_register_scene_overlays()
	_build_overlays()


func _register_scene_overlays() -> void:
	for child in get_children():
		if child is CharacterPresenceZone:
			var zone := child as CharacterPresenceZone
			var rect := zone.get_texture_rect()
			if rect != null:
				_overlays[zone.overlay_key] = rect


func _scene_overlay_keys() -> Dictionary:
	var keys := {}
	for child in get_children():
		if child is CharacterPresenceZone:
			keys[(child as CharacterPresenceZone).overlay_key] = true
	return keys


func _build_overlays() -> void:
	for child in get_children():
		if child.name.begins_with("Overlay_"):
			child.queue_free()
	var scene_keys := _scene_overlay_keys()
	var preserved: Dictionary = {}
	for key in scene_keys:
		if _overlays.has(key):
			preserved[key] = _overlays[key]
	_overlays = preserved
	_secondary_overlays.clear()
	var paths: Dictionary = _InteractableRegistry.get_overlay_paths(map_id)
	var secondary_keys: Dictionary = _InteractableRegistry.SECONDARY_OVERLAY_KEYS.get(map_id, {})
	var registered_secondary: Dictionary = {}
	for hotspot_id in paths.keys():
		if scene_keys.has(hotspot_id):
			continue
		if hotspot_id.ends_with("_unlocked") or hotspot_id.ends_with("_keypad_unlocked"):
			continue
		if hotspot_id in _InteractableRegistry.OVERLAY_ART_ALIASES:
			continue
		var path: String = paths[hotspot_id]
		if path.is_empty():
			continue
		var rect := _make_overlay_rect("Overlay_%s" % hotspot_id, path, hotspot_id)
		if rect == null:
			continue
		add_child(rect)
		_overlays[hotspot_id] = rect
		for sec_key in secondary_keys.get(hotspot_id, []):
			if registered_secondary.has(sec_key):
				continue
			var sec_path: String = paths.get(sec_key, "")
			if sec_path.is_empty():
				continue
			var sec_rect := _make_overlay_rect("Overlay_%s_%s" % [hotspot_id, sec_key], sec_path, sec_key)
			if sec_rect == null:
				continue
			add_child(sec_rect)
			registered_secondary[sec_key] = true
			if not _secondary_overlays.has(hotspot_id):
				_secondary_overlays[hotspot_id] = []
			_secondary_overlays[hotspot_id].append(sec_rect)
	_sync_persistent_overlays()
	_raise_character_presences()


func refresh_state() -> void:
	_sync_persistent_overlays()
	if not _active_id.is_empty() and _can_show(_active_id):
		_show_overlay(_active_id)


func _sync_persistent_overlays() -> void:
	var show_flags: Dictionary = _InteractableRegistry.OVERLAY_SHOW_WHILE_FLAG.get(map_id, {})
	for overlay_key in show_flags.keys():
		if _character_presence_zone_for(overlay_key) != null:
			_sync_character_presence_visibility(overlay_key, str(show_flags[overlay_key]))
			continue
		var rect: TextureRect = _overlays.get(overlay_key, null)
		if rect == null:
			continue
		var flag_name: String = str(show_flags[overlay_key])
		if not GameState.has_flag(flag_name):
			if overlay_key != _active_id:
				rect.visible = false
				rect.modulate = HIDDEN_COLOR
			continue
		var path := _InteractableRegistry.resolve_texture_path(map_id, overlay_key)
		if path.is_empty():
			continue
		var texture: Texture2D = load(path) as Texture2D
		if texture == null:
			# Art for this state isn't in yet — don't fall back to a stale texture.
			rect.texture = null
			rect.visible = false
			rect.modulate = HIDDEN_COLOR
			continue
		rect.texture = texture
		rect.visible = true
		rect.modulate = Color(1, 1, 1, 1)
		if overlay_key == "door_r_far":
			rect.z_index = _InteractableRegistry.OVERLAY_Z_DOOR_OPEN
	_raise_character_presences()


func _character_presence_zone_for(overlay_key: String) -> CharacterPresenceZone:
	for child in get_children():
		if child is CharacterPresenceZone and (child as CharacterPresenceZone).overlay_key == overlay_key:
			return child as CharacterPresenceZone
	return null


func _sync_character_presence_visibility(overlay_key: String, flag_name: String) -> void:
	var zone := _character_presence_zone_for(overlay_key)
	if zone == null:
		return
	if not GameState.has_flag(flag_name):
		zone.hide_presence()
	else:
		zone.sync_presence_from_flags()


func _raise_character_presences() -> void:
	for child in get_children():
		if child is CharacterPresenceZone:
			var zone := child as CharacterPresenceZone
			zone.z_index = _InteractableRegistry.CHARACTER_PRESENCE_Z_INDEX
			var sprite := zone.get_texture_rect()
			if sprite:
				sprite.z_index = 1
			move_child(zone, -1)


func _make_overlay_rect(node_name: String, texture_path: String, overlay_key: String) -> TextureRect:
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		push_warning("Missing interactable texture: %s" % texture_path)
		return null
	var rect := TextureRect.new()
	rect.name = node_name
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.offset_left = 0
	rect.offset_top = 0
	rect.offset_right = 0
	rect.offset_bottom = 0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate = HIDDEN_COLOR
	rect.visible = false
	rect.z_index = _InteractableRegistry.overlay_z_index_for(map_id, overlay_key)
	return rect


func _connect_hotspots() -> void:
	var root := get_parent()
	if root == null:
		return
	for zone in _find_hotspot_zones(root):
		if zone.hover_started.is_connected(_on_hover_started):
			continue
		zone.hover_started.connect(_on_hover_started)
		zone.hover_ended.connect(_on_hover_ended)


func _find_hotspot_zones(node: Node) -> Array:
	var found: Array = []
	if node is HotspotZone:
		found.append(node)
	for child in node.get_children():
		found.append_array(_find_hotspot_zones(child))
	return found


func _on_hover_started(zone: HotspotZone) -> void:
	if not _can_show(zone.hotspot_id):
		return
	_show_overlay(zone.hotspot_id)


func _on_hover_ended(zone: HotspotZone) -> void:
	if zone.hotspot_id == _active_id:
		_hide_overlay()


func _can_show(hotspot_id: String) -> bool:
	if hotspot_id.is_empty():
		return false
	if GameState.is_hotspot_consumed(map_id, hotspot_id):
		return false
	return _InteractableRegistry.can_show_overlay(map_id, hotspot_id)


func _show_overlay(hotspot_id: String) -> void:
	var path := _InteractableRegistry.resolve_texture_path(map_id, hotspot_id)
	if path.is_empty():
		return
	var rect: TextureRect = _overlays.get(hotspot_id, null)
	if rect == null:
		return
	var texture: Texture2D = load(path) as Texture2D
	if texture:
		rect.texture = texture
	_active_id = hotspot_id
	_kill_tween()
	rect.visible = true
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.tween_property(rect, "modulate", GLOW_COLOR, 0.12)
	_show_secondary_overlays(hotspot_id)


func _show_secondary_overlays(hotspot_id: String) -> void:
	_kill_secondary_tweens()
	var rects: Array = _secondary_overlays.get(hotspot_id, [])
	var paths: Array[String] = _InteractableRegistry.resolve_secondary_overlay_paths(map_id, hotspot_id)
	for i in rects.size():
		var sec_rect: TextureRect = rects[i]
		if i >= paths.size():
			sec_rect.visible = false
			sec_rect.modulate = HIDDEN_COLOR
			continue
		var tex: Texture2D = load(paths[i]) as Texture2D
		if tex:
			sec_rect.texture = tex
		sec_rect.visible = true
		sec_rect.modulate = HIDDEN_COLOR
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_SINE)
		tween.tween_property(sec_rect, "modulate", GLOW_COLOR, 0.12)
		_secondary_tweens.append(tween)


func _hide_overlay() -> void:
	if _active_id.is_empty():
		return
	var hotspot_id := _active_id
	var rect: TextureRect = _overlays.get(hotspot_id, null)
	_active_id = ""
	_kill_tween()
	_kill_secondary_tweens()
	if rect != null:
		var persist_flag := _InteractableRegistry.persistent_overlay_flag(map_id, hotspot_id)
		var keep_visible: bool = not persist_flag.is_empty() and GameState.has_flag(persist_flag)
		if keep_visible:
			rect.modulate = Color(1, 1, 1, 1)
			rect.visible = true
		else:
			_tween = create_tween()
			_tween.set_ease(Tween.EASE_IN)
			_tween.set_trans(Tween.TRANS_SINE)
			_tween.tween_property(rect, "modulate", HIDDEN_COLOR, 0.1)
			_tween.tween_callback(func() -> void: rect.visible = false)
	_hide_secondary_overlays(hotspot_id)


func _hide_secondary_overlays(hotspot_id: String) -> void:
	var rects: Array = _secondary_overlays.get(hotspot_id, [])
	for sec_rect in rects:
		var tween := create_tween()
		tween.set_ease(Tween.EASE_IN)
		tween.set_trans(Tween.TRANS_SINE)
		tween.tween_property(sec_rect, "modulate", HIDDEN_COLOR, 0.1)
		tween.tween_callback(func() -> void: sec_rect.visible = false)
		_secondary_tweens.append(tween)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


func _kill_secondary_tweens() -> void:
	for tween in _secondary_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_secondary_tweens.clear()


func _on_inventory_changed() -> void:
	if _active_id == "door":
		_show_overlay("door")


func _on_map_character_mood_changed(_character: String, _mood: String) -> void:
	_sync_persistent_overlays()


func _on_flags_changed() -> void:
	_sync_persistent_overlays()
	if not _active_id.is_empty() and not _can_show(_active_id):
		_hide_overlay()
