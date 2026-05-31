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
}

const POOL_SIZE := 6

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0


func _ready() -> void:
	for _i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)
	for id in SFX.keys():
		_resolve_stream(id)


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
