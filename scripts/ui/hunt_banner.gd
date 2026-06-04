extends Control

## Big centered warning that flashes in at the start of a hunt beat ("THE HUNT IS
## ON") and fades itself out after a few seconds. Purely informational — it never
## blocks input, so the player can act the instant it appears.

@onready var _label: Label = %HuntBannerLabel

const HOLD_SEC := 3.0
const FADE_IN_SEC := 0.35
const FADE_OUT_SEC := 0.7

var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false
	if not HuntManager.beat_started.is_connected(_on_beat_started):
		HuntManager.beat_started.connect(_on_beat_started)


func _on_beat_started(_beat_id: String, banner_text: String) -> void:
	if banner_text.is_empty():
		return
	show_banner(banner_text)


func show_banner(text: String, hold_sec: float = HOLD_SEC) -> void:
	if _label:
		_label.text = text
	visible = true
	if _tween and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_SEC)
	_tween.tween_interval(hold_sec)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_SEC)
	_tween.tween_callback(func() -> void: visible = false)
