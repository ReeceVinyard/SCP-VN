extends VideoStreamPlayer

## Full-screen cutscene video player (e.g. the West-wing Tesla gate). Plays a clip
## once or on a loop. Loaded lazily and null-checked so a missing/un-imported
## .ogv simply skips instead of crashing.

signal sequence_finished

var _loop := false
var _finished := true


func _ready() -> void:
	add_to_group("scene_video")
	expand = true
	# While visible this full-screen player swallows every hover/click so the
	# hidden map (doors, HUD) underneath can't be interacted with. Clicks are
	# turned into dialogue advances so cutscene text still progresses.
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	if not finished.is_connected(_on_finished):
		finished.connect(_on_finished)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if DialogueManager.is_active:
			DialogueManager.advance()
		accept_event()


func play_clip(path: String, loop: bool) -> void:
	await play_clip_when_ready(path, loop, false)


## Loads and plays a clip, but only becomes visible after the decoder has a frame
## so the map/dialogue underneath cannot flash through for one frame.
func play_clip_when_ready(path: String, loop: bool, keep_visible: bool = false) -> void:
	var clip := load(path) as VideoStream
	if clip == null:
		push_warning("scene_video: cannot load %s (open the editor to import it)" % path)
		_finished = true
		sequence_finished.emit()
		return
	_loop = loop
	_finished = false
	if not keep_visible:
		visible = false
	stream = clip
	play()
	await _wait_for_decoded_frame()
	visible = true


func _wait_for_decoded_frame() -> void:
	for _attempt in 90:
		if not is_inside_tree():
			return
		await get_tree().process_frame
		var tex := get_video_texture()
		if tex != null and tex.get_width() > 0 and tex.get_height() > 0:
			return
	await get_tree().create_timer(0.08).timeout


func is_finished() -> bool:
	return _finished


func stop_clip() -> void:
	stop()
	visible = false
	_loop = false
	_finished = true


func _on_finished() -> void:
	if _loop:
		play()
		return
	_finished = true
	sequence_finished.emit()
