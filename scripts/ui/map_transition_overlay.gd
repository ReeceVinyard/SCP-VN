extends ColorRect

## Full-screen fade to black and back — used when moving between map scenes.

signal fade_to_black_finished
signal fade_from_black_finished


func _ready() -> void:
	add_to_group("map_transition")
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(0, 0, 0, 1)
	modulate = Color(1, 1, 1, 0)


func fade_to_black(duration_sec: float = 0.75, hold_sec: float = 0.15) -> void:
	modulate = Color(1, 1, 1, 0)
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "modulate:a", 1.0, maxf(0.05, duration_sec))
	if hold_sec > 0.0:
		tween.tween_interval(hold_sec)
	await tween.finished
	fade_to_black_finished.emit()


func fade_from_black(duration_sec: float = 0.9) -> void:
	modulate = Color(1, 1, 1, 1)
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "modulate:a", 0.0, maxf(0.05, duration_sec))
	await tween.finished
	_force_release_input()


func _force_release_input() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 0
	hide()
	fade_from_black_finished.emit()
