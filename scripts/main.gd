extends Control

@onready var _exploration: Control = %ExplorationMap
@onready var _map_host: Control = %MapHost
@onready var _dialogue_box: PanelContainer = %DialogueBox
@onready var _inventory: Control = %InventoryPanel
@onready var _memories: Control = %MemoryPanel
@onready var _name_modal: Control = %NameEntryModal
@onready var _item_found_modal: Control = %ItemFoundModal
@onready var _document_reader: Control = %DocumentReaderModal
@onready var _npc_reaction: Control = %NpcReactionOverlay
@onready var _screen_shake: Node = %ScreenShakeController
@onready var _inventory_button: Button = %InventoryButton
@onready var _memories_button: Button = %MemoriesButton
@onready var _status_label: Label = %StatusLabel
@onready var _eye_overlay: ColorRect = %EyeOpenOverlay
@onready var _hud: HBoxContainer = %HUD
@onready var _save_button: Button = %SaveButton
@onready var _load_button: Button = %LoadButton
@onready var _save_status_label: Label = %SaveStatusLabel

var _status_flash_tween: Tween


func _ready() -> void:
	# Root must not steal clicks from WorldLayer / map hotspots (default is STOP).
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inventory_button.pressed.connect(_inventory.toggle)
	_memories_button.pressed.connect(_memories.toggle)
	_save_button.pressed.connect(_on_save_pressed)
	_load_button.pressed.connect(_on_load_pressed)
	_dialogue_box.advance_requested.connect(DialogueManager.advance)
	_exploration.naming_required.connect(_name_modal.show_modal)
	_name_modal.name_confirmed.connect(_on_name_confirmed)
	GameState.item_acquired.connect(_on_item_acquired)
	_item_found_modal.confirmed.connect(_exploration.complete_pending_pickup)
	_exploration.document_requested.connect(_on_document_requested)
	_inventory.read_document_requested.connect(_on_inventory_read_document)
	_document_reader.closed.connect(_on_document_closed)
	DialogueManager.post_choice_reaction.connect(_on_post_choice_reaction)
	_npc_reaction.finished.connect(_on_npc_reaction_finished)
	GameState.player_name_changed.connect(_update_status)
	_exploration.map_changed.connect(_on_map_changed)
	DialogueManager.map_character_mood_changed.connect(_on_map_character_mood_changed)
	DialogueManager.character_presence_fade_in.connect(_on_character_presence_fade_in)
	DialogueManager.screen_shake_requested.connect(_on_screen_shake_requested)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	SaveManager.save_finished.connect(_on_save_finished)
	SaveManager.load_finished.connect(_on_load_finished)
	_exploration.load_map(GameState.current_map_id)
	_update_status()
	_refresh_save_buttons()
	if GameState.opening_cinematic_done:
		_show_game_after_load()
	else:
		_start_opening_sequence()


func _start_opening_sequence() -> void:
	if not _ensure_opening_fade_targets():
		GameState.mark_opening_cinematic_done()
		GameState.enable_exploration()
		DialogueManager.start_knot("archives_intro")
		return
	_exploration.modulate.a = 0.0
	_map_host.modulate.a = 0.0
	_hud.modulate.a = 0.0
	await _eye_overlay.play()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(_exploration, "modulate:a", 1.0, 1.2)
	tween.tween_property(_map_host, "modulate:a", 1.0, 1.2)
	tween.tween_property(_hud, "modulate:a", 1.0, 1.2)
	await tween.finished
	GameState.mark_opening_cinematic_done()
	GameState.enable_exploration()
	DialogueManager.start_knot("archives_intro")


func _on_item_acquired(item_id: String) -> void:
	if ItemRegistry.is_readable_document(item_id):
		SoundManager.play("paper_rustle")
		_document_reader.show_document(item_id, false)
	else:
		_item_found_modal.show_item(item_id)


func _on_document_requested(item_id: String, grant_item_on_close: bool) -> void:
	_inventory.close()
	_document_reader.show_document(item_id, grant_item_on_close)


func _on_inventory_read_document(item_id: String) -> void:
	_document_reader.show_document(item_id, false)


func _on_post_choice_reaction(reaction: Dictionary) -> void:
	_npc_reaction.show_reaction(reaction)


func _on_npc_reaction_finished() -> void:
	DialogueManager.continue_after_reaction()


func _on_document_closed(item_id: String, grant_item_on_close: bool) -> void:
	if grant_item_on_close and not GameState.has_item(item_id):
		if ItemRegistry.is_readable_document(item_id):
			SoundManager.play("paper_rustle")
		GameState.add_item(item_id, false)
	if item_id == "eh_14":
		GameState.set_flag("eh_14_read")
		if grant_item_on_close and not GameState.has_flag("chase_sequence_started"):
			_exploration.begin_chase_sequence()


func _unhandled_input(event: InputEvent) -> void:
	if _item_found_modal.visible or _document_reader.visible or _npc_reaction.visible or _name_modal.visible:
		return
	if _inventory.visible or _memories.visible:
		return
	if _exploration.try_handle_map_click(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_memories"):
		_memories.toggle()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("quick_save"):
		_perform_save()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("quick_load"):
		_perform_load()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_inventory"):
		_inventory.toggle()
		get_viewport().set_input_as_handled()


func _on_save_pressed() -> void:
	_perform_save()


func _on_load_pressed() -> void:
	_perform_load()


func _perform_save() -> void:
	if SaveManager.save_game(SaveManager.SLOT_QUICK):
		_flash_save_status("Game saved.")
	else:
		_flash_save_status("Save failed.")


func _perform_load() -> void:
	if not SaveManager.has_save(SaveManager.SLOT_QUICK):
		_flash_save_status("No save file yet.")
		return
	if SaveManager.load_game(SaveManager.SLOT_QUICK):
		_apply_loaded_game()
		_flash_save_status("Game loaded.")
	else:
		_flash_save_status("Load failed.")


func _ensure_opening_fade_targets() -> bool:
	if _exploration == null or _map_host == null or _hud == null:
		push_error(
			"Opening fade targets missing — use %ExplorationMap, %MapHost, %HUD in main.gd"
		)
		return false
	return true


func _apply_loaded_game() -> void:
	_item_found_modal.hide()
	_document_reader.hide()
	_npc_reaction.hide()
	_name_modal.hide()
	_inventory.hide()
	_memories.hide()
	if _ensure_opening_fade_targets():
		_exploration.modulate.a = 1.0
		_map_host.modulate.a = 1.0
		_hud.modulate.a = 1.0
	_eye_overlay.hide()
	_show_game_after_load()
	_update_status()
	_refresh_save_buttons()


func _show_game_after_load() -> void:
	GameState.mark_opening_cinematic_done()
	_exploration.stabilize_playback_state()


func _on_save_finished(_slot: int, success: bool) -> void:
	_refresh_save_buttons()
	if not success:
		_flash_save_status("Save failed.")


func _on_load_finished(_slot: int, success: bool) -> void:
	_refresh_save_buttons()


func _refresh_save_buttons() -> void:
	_load_button.disabled = not SaveManager.has_save(SaveManager.SLOT_QUICK)


func _flash_save_status(message: String) -> void:
	_save_status_label.text = message
	if _status_flash_tween and _status_flash_tween.is_valid():
		_status_flash_tween.kill()
	_status_flash_tween = create_tween()
	_status_flash_tween.tween_interval(2.5)
	_status_flash_tween.tween_callback(func() -> void:
		if SaveManager.has_save(SaveManager.SLOT_QUICK):
			var summary := SaveManager.get_slot_summary(SaveManager.SLOT_QUICK)
			var when := int(summary.get("saved_at_unix", 0))
			if when > 0:
				_save_status_label.text = "Save ready — %s" % Time.get_datetime_string_from_unix_time(when)
			else:
				_save_status_label.text = "Save ready"
		else:
			_save_status_label.text = "F6 save · F9 load"
	)


func _on_name_confirmed(_chosen_name: String) -> void:
	_update_status()
	DialogueManager.start_knot("archives_tutorial")


func _on_map_changed(map_id: String) -> void:
	if map_id == "hall_papers" and not GameState.has_flag("hall_intro_seen"):
		GameState.set_flag("hall_intro_seen")
		call_deferred("_start_hall_intro")


func _on_map_character_mood_changed(_character: String, _mood: String) -> void:
	_exploration.refresh_map_overlays()


func _on_character_presence_fade_in(_overlay_key: String, _duration_sec: float) -> void:
	_exploration.refresh_map_overlays()


func _on_screen_shake_requested(strength: String) -> void:
	if _screen_shake and _screen_shake.has_method("play"):
		_screen_shake.play(strength)


func _start_hall_intro() -> void:
	await get_tree().process_frame
	if DialogueManager.is_active:
		await DialogueManager.dialogue_ended
	DialogueManager.start_knot("hall_enter")


func _on_dialogue_ended(_ended_knot: String = "") -> void:
	_update_status()


func _update_status() -> void:
	var parts: PackedStringArray = []
	parts.append("Playing as: %s" % GameState.display_name())
	if GameState.has_flag("missing_researcher_id"):
		parts.append("(no ID — something may name you later)")
	if GameState.has_flag("chase_told_amnesia"):
		parts.append("Chase: trusts you")
	elif GameState.has_flag("chase_lied_keycard"):
		parts.append("Chase: irritated")
	if GameState.has_flag("scp1_befriended"):
		parts.append("Subject: friendly")
	elif GameState.has_flag("scp1_hostile"):
		parts.append("Subject: hostile")
	_status_label.text = " | ".join(parts)
