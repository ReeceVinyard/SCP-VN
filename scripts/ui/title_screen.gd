extends Control

## Rudimentary title screen. New Game starts a fresh run; Load resumes the quick
## save; Credits is a placeholder for now. The actual game lives in main.tscn — we
## just hand it a boot intent and switch scenes.

const GAME_SCENE := "res://scenes/main.tscn"

@onready var _new_game_button: Button = %NewGameButton
@onready var _load_button: Button = %LoadButton
@onready var _credits_button: Button = %CreditsButton
@onready var _credits_note: Label = %CreditsNote


func _ready() -> void:
	_new_game_button.pressed.connect(_on_new_game)
	_load_button.pressed.connect(_on_load)
	_credits_button.pressed.connect(_on_credits)
	_load_button.disabled = not SaveManager.has_save(SaveManager.SLOT_QUICK)
	_credits_note.visible = false
	_new_game_button.grab_focus()


func _on_new_game() -> void:
	GameState.reset_run()
	GameState.boot_request = "new"
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_load() -> void:
	if not SaveManager.has_save(SaveManager.SLOT_QUICK):
		return
	GameState.boot_request = "load"
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_credits() -> void:
	# Real credits later; for now just acknowledge the click.
	_credits_note.visible = true
