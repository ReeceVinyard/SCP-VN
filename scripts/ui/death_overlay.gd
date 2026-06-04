extends Control

## "YOU DIED" screen shown when the hunt catches the player. Fades in over a black
## dim, shows a cause-specific subtitle, and offers a Retry that restarts from the
## checkpoint set when the hunt began. Blocks all input while visible.

signal retry_pressed

@onready var _dim: ColorRect = %DeathDim
@onready var _title: Label = %DeathTitle
@onready var _subtitle: Label = %DeathSubtitle
@onready var _retry_button: Button = %DeathRetryButton

const FADE_IN_SEC := 1.2

## Cause id -> flavor line under the big "YOU DIED".
const CAUSE_TEXT := {
	"timer": "It found you in the dark.",
	"wrong_door": "Wrong door. It was already on you.",
	"no_cameras": "You never saw it coming. SCP-14 was waiting.",
	"door_blind": "You never checked the feeds. It was waiting on the other side of the door.",
	"left_anyway": "You knew what was out there. It knew you were coming.",
	"": "The Archives became your tomb.",
}

var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	modulate.a = 0.0
	if _retry_button and not _retry_button.pressed.is_connected(_on_retry):
		_retry_button.pressed.connect(_on_retry)


func show_death(cause: String = "") -> void:
	if _subtitle:
		_subtitle.text = str(CAUSE_TEXT.get(cause, CAUSE_TEXT.get("", "")))
	if _retry_button:
		var can_retry := SaveManager.has_checkpoint()
		if not can_retry:
			# Mid-hunt deaths should always have a staircase checkpoint; this covers
			# edge cases where deferred setup raced ahead of the player.
			can_retry = GameState.has_flag("reached_staircase") and not GameState.has_flag(
				"reached_storage_room"
			)
		_retry_button.disabled = not can_retry
	visible = true
	if _tween and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_SEC)
	if _retry_button:
		_retry_button.grab_focus()


func hide_death() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0
	visible = false


func _on_retry() -> void:
	retry_pressed.emit()
