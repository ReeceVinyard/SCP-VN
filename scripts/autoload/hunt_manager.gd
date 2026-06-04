extends Node

## Drives the "hunt" beats after Chase dies: a hidden per-beat countdown plus a
## hunt-audio bed that ramps louder as the clock drains. The player never sees a
## timer — only the rising sound and a one-off on-screen warning banner.
##
## A "beat" is one timed decision window (e.g. the staircase door choice, then the
## security room). Call start_beat() when the player gains control for that beat,
## survive_beat() when they clear it in time, and fail() for an instant loss
## (wrong door, skipped the cameras, etc.). The timer running out fails as "timer".
##
## UI/flow are decoupled: this node only emits signals. main.gd shows the banner
## and the death overlay; exploration_map decides what survive/fail means per map.

signal beat_started(beat_id: String, banner_text: String)
signal beat_survived(beat_id: String)
signal caught(cause: String)
signal beat_tick(remaining: float, total: float)

## Hunt bed volume floor (beat start) and ceiling (the instant before capture).
const HUNT_DB_START := -24.0
const HUNT_DB_END := 0.0

var _active := false
var _beat_id := ""
var _remaining := 0.0
var _total := 0.0
var _paused := false


func _ready() -> void:
	set_process(false)


func is_active() -> bool:
	return _active


func current_beat() -> String:
	return _beat_id


## Begin a timed beat. `banner_text` (if set) is forwarded for the on-screen warning.
func start_beat(beat_id: String, duration: float, banner_text: String = "") -> void:
	_beat_id = beat_id
	_total = maxf(duration, 0.01)
	_remaining = _total
	_active = true
	_paused = false
	SoundManager.start_loop("hunt_loop", HUNT_DB_START)
	set_process(true)
	beat_started.emit(beat_id, banner_text)


func pause() -> void:
	_paused = true


func resume() -> void:
	_paused = false


## The player cleared this beat in time. Stops the clock and eases the bed out.
func survive_beat() -> void:
	if not _active:
		return
	_active = false
	set_process(false)
	SoundManager.stop_loop(0.6)
	beat_survived.emit(_beat_id)


## Instant loss during an active beat (e.g. wrong door while the clock is running).
func fail(cause: String) -> void:
	if not _active:
		return
	_finish_caught(cause)


## Instant loss that is NOT tied to a running timer — a state-based death such as
## leaving the (timer-free) security room without having checked the cameras.
func kill(cause: String) -> void:
	_finish_caught(cause)


## Cancel the hunt entirely without a win or loss (e.g. loading a save mid-beat).
func abort() -> void:
	_active = false
	_paused = false
	set_process(false)
	SoundManager.stop_loop(0.0)


func _process(delta: float) -> void:
	if not _active or _paused:
		return
	_remaining = maxf(_remaining - delta, 0.0)
	var drained := 1.0 - clampf(_remaining / _total, 0.0, 1.0)
	SoundManager.set_loop_volume(lerpf(HUNT_DB_START, HUNT_DB_END, drained))
	beat_tick.emit(_remaining, _total)
	if _remaining <= 0.0:
		_finish_caught("timer")


func _finish_caught(cause: String) -> void:
	_active = false
	_paused = false
	set_process(false)
	SoundManager.stop_loop(0.0)
	caught.emit(cause)
