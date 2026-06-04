extends Node

## Central sound-effect player. Call `SoundManager.play("<id>")` from anywhere.
##
## Audio files live in res://assets/Sound effects/. They are loaded lazily and
## null-checked, so a missing/not-yet-imported file simply stays silent instead
## of crashing. A small player pool lets overlapping effects play together.

const SFX := {
	"keypad_beep": "res://assets/Sound effects/Keypad beep.mp3",
	"door_opening": "res://assets/Sound effects/Door opening.mp3",
	"memory_unlocked": "res://assets/Sound effects/Memory unlocked.mp3",
	"paper_rustle": "res://assets/Sound effects/Paper rustle.mp3",
	"metal_stair": "res://assets/Sound effects/Metal stair.mp3",
	# The grille coming loose when the security-room vent is removed.
	"vent_open": "res://assets/Sound effects/vent rattle.mp3",
	# Placeholder: the wandering anomaly Chase hears past the Tesla gate. Drop the
	# file at this path (or tell me the real name) and it plays automatically.
	"anomaly": "res://assets/Sound effects/Anomaly.mp3",
	# --- Hunt sequence placeholders (drop the real files in to activate) -------
	# Looping bed that ramps up as the hunt timer drains.
	"hunt_loop": "res://assets/Sound effects/Hunt loop.mp3",
	# The MC's own running footsteps during the uncontrolled escape cinematic.
	"footsteps_run": "res://assets/Sound effects/Footsteps run.mp3",
}

const POOL_SIZE := 6

## A dedicated looping channel, separate from the one-shot pool, for hunt/ambience
## beds whose volume we tween over time. Looping streams are cached separately so
## we never flip the `loop` flag on the shared one-shot copies.
var _loop_streams: Dictionary = {}
var _loop_player: AudioStreamPlayer
var _loop_tween: Tween

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0

## A dedicated one-shot channel for effects we may need to cut short (e.g. the
## vent rattle that should only run for the duration of the interaction).
var _cuttable_player: AudioStreamPlayer


func _ready() -> void:
	for _i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)
	_loop_player = AudioStreamPlayer.new()
	_loop_player.bus = "Master"
	add_child(_loop_player)
	_cuttable_player = AudioStreamPlayer.new()
	_cuttable_player.bus = "Master"
	add_child(_cuttable_player)
	for id in SFX.keys():
		_resolve_stream(id)


## Play a one-shot on the dedicated cuttable channel so stop_cuttable() can end it
## early (used for timed interactions). Replaces any sound already on that channel.
func play_cuttable(id: String, volume_db: float = 0.0) -> void:
	var stream := _resolve_stream(id)
	if stream == null:
		return
	_cuttable_player.stream = stream
	_cuttable_player.volume_db = volume_db
	_cuttable_player.play()


func stop_cuttable() -> void:
	if _cuttable_player and _cuttable_player.playing:
		_cuttable_player.stop()


## Start (or restart) the looping channel with the given sound id at a volume.
func start_loop(id: String, volume_db: float = -24.0) -> void:
	var stream := _resolve_loop_stream(id)
	if _loop_tween and _loop_tween.is_valid():
		_loop_tween.kill()
	if stream == null:
		# Keep a record of intended volume so a later ramp still behaves sanely.
		_loop_player.volume_db = volume_db
		return
	_loop_player.stream = stream
	_loop_player.volume_db = volume_db
	_loop_player.play()


## Tween the looping channel's volume (e.g. ramp the hunt bed up as time runs out).
func ramp_loop_volume(to_db: float, secs: float) -> void:
	if _loop_tween and _loop_tween.is_valid():
		_loop_tween.kill()
	if secs <= 0.0:
		_loop_player.volume_db = to_db
		return
	_loop_tween = create_tween()
	_loop_tween.tween_property(_loop_player, "volume_db", to_db, secs)


func set_loop_volume(db: float) -> void:
	if _loop_tween and _loop_tween.is_valid():
		_loop_tween.kill()
	_loop_player.volume_db = db


func stop_loop(fade_secs: float = 0.0) -> void:
	if _loop_tween and _loop_tween.is_valid():
		_loop_tween.kill()
	if fade_secs <= 0.0 or not _loop_player.playing:
		_loop_player.stop()
		return
	_loop_tween = create_tween()
	_loop_tween.tween_property(_loop_player, "volume_db", -60.0, fade_secs)
	_loop_tween.tween_callback(_loop_player.stop)


func play(id: String, volume_db: float = 0.0) -> void:
	var stream := _resolve_stream(id)
	if stream == null:
		return
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func _resolve_stream(id: String) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var path: String = SFX.get(id, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	if stream == null:
		return null
	# Sound effects are one-shots; never let an import default loop them forever.
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = false
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false
	_streams[id] = stream
	return stream


## Like _resolve_stream but forces looping on a private copy for the loop channel.
func _resolve_loop_stream(id: String) -> AudioStream:
	if _loop_streams.has(id):
		return _loop_streams[id]
	var path: String = SFX.get(id, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	if stream == null:
		return null
	# Use a unique copy so flipping `loop` doesn't affect any one-shot use.
	stream = stream.duplicate() as AudioStream
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_loop_streams[id] = stream
	return stream
