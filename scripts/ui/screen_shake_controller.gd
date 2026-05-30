extends Node

## Shakes the map view by offsetting anchored Controls (position tweens do not move full-screen UI).

const INTENSITY := {
	"light": 10.0,
	"medium": 18.0,
	"heavy": 28.0,
}

@export var shake_targets: Array[NodePath] = []

var _targets: Array[Dictionary] = []
var _active_tween: Tween


func _ready() -> void:
	_collect_targets()


func _collect_targets() -> void:
	_targets.clear()
	for path in shake_targets:
		var node := get_node_or_null(path)
		if node is Control:
			var ctrl := node as Control
			_targets.append({
				"control": ctrl,
				"left": ctrl.offset_left,
				"top": ctrl.offset_top,
				"right": ctrl.offset_right,
				"bottom": ctrl.offset_bottom,
			})


func play(strength: String = "medium", duration_sec: float = 0.55) -> void:
	if _targets.is_empty():
		_collect_targets()
	if _targets.is_empty():
		push_warning("ScreenShakeController: no shake targets configured")
		return
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		_reset_offsets()
	var intensity: float = float(INTENSITY.get(strength, INTENSITY["medium"]))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_active_tween = create_tween()
	var step := 0.035
	var steps := maxi(1, int(duration_sec / step))
	for i in steps:
		var falloff := 1.0 - float(i) / float(steps)
		var ox := rng.randf_range(-intensity, intensity) * falloff
		var oy := rng.randf_range(-intensity, intensity) * falloff
		_active_tween.tween_callback(_apply_offset.bind(ox, oy))
		_active_tween.tween_interval(step)
	_active_tween.tween_callback(_reset_offsets)


func _apply_offset(ox: float, oy: float) -> void:
	for entry in _targets:
		var ctrl: Control = entry["control"]
		if not is_instance_valid(ctrl):
			continue
		ctrl.offset_left = entry["left"] + ox
		ctrl.offset_top = entry["top"] + oy
		ctrl.offset_right = entry["right"] + ox
		ctrl.offset_bottom = entry["bottom"] + oy


func _reset_offsets() -> void:
	for entry in _targets:
		var ctrl: Control = entry["control"]
		if not is_instance_valid(ctrl):
			continue
		ctrl.offset_left = entry["left"]
		ctrl.offset_top = entry["top"]
		ctrl.offset_right = entry["right"]
		ctrl.offset_bottom = entry["bottom"]
