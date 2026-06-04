extends Control

## The uncontrolled "MC sprints away" beat after Chase falls: a couple of blurry
## running frames, running-footsteps audio, and a light camera shake. The player
## has no control during it. Art isn't in yet, so with no frames supplied it shows
## a dark motion-pulse placeholder — drop frame paths into play_run() later.

signal run_finished

@onready var _frame: TextureRect = %RunFrame

const SHAKE_INTERVAL_SEC := 0.45
const DEFAULT_FRAME_SEC := 1.0


func _ready() -> void:
	add_to_group("run_cinematic")
	mouse_filter = Control.MOUSE_FILTER_STOP  # swallow input — no control during the run
	visible = false
	modulate.a = 0.0


## Play the run. `frame_paths` are shown in order (blurry running stills); pass an
## empty array to use the placeholder. Returns when the sequence is done.
func play_run(frame_paths: PackedStringArray = PackedStringArray(), frame_sec: float = DEFAULT_FRAME_SEC) -> void:
	visible = true
	modulate.a = 1.0
	SoundManager.start_loop("footsteps_run", -4.0)

	var frames: Array[Texture2D] = []
	for path in frame_paths:
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex:
				frames.append(tex)

	var frame_count := maxi(frames.size(), 2)  # at least two "frames" of running
	var shake_accum := 0.0
	for i in frame_count:
		if i < frames.size() and _frame:
			_frame.texture = frames[i]
			_frame.self_modulate = Color.WHITE
		elif _frame:
			# Placeholder: dark frame with a subtle brightness pulse to imply motion.
			_frame.texture = null
			_frame.self_modulate = Color(0.06, 0.06, 0.08, 1.0) if i % 2 == 0 else Color(0.1, 0.1, 0.13, 1.0)
		var elapsed := 0.0
		while elapsed < frame_sec:
			var step := minf(SHAKE_INTERVAL_SEC, frame_sec - elapsed)
			await get_tree().create_timer(step).timeout
			if not is_inside_tree():
				return
			DialogueManager.screen_shake_requested.emit("light")
			shake_accum += step
			elapsed += step

	SoundManager.stop_loop(0.3)
	visible = false
	modulate.a = 0.0
	run_finished.emit()
