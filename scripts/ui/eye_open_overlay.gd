extends ColorRect

## Full-screen black fade-out, like slowly opening your eyes.


func play(duration: float = 2.8) -> void:
	modulate = Color(1, 1, 1, 1)
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "modulate:a", 0.0, duration)
	await tween.finished
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
