extends Control

@onready var _exploration: Control = %ExplorationMap
@onready var _map_host: Control = %MapHost
@onready var _dialogue_box: PanelContainer = %DialogueBox
@onready var _inventory: PanelContainer = %InventoryPanel
@onready var _name_modal: Control = %NameEntryModal
@onready var _item_found_modal: PanelContainer = %ItemFoundModal
@onready var _inventory_button: Button = %InventoryButton
@onready var _status_label: Label = %StatusLabel
@onready var _eye_overlay: ColorRect = %EyeOpenOverlay
@onready var _hud: HBoxContainer = $HUD


func _ready() -> void:
	_inventory_button.pressed.connect(_inventory.toggle)
	_dialogue_box.advance_requested.connect(DialogueManager.advance)
	_exploration.naming_required.connect(_name_modal.show_modal)
	_name_modal.name_confirmed.connect(_on_name_confirmed)
	GameState.item_acquired.connect(_item_found_modal.show_item)
	_item_found_modal.confirmed.connect(_exploration.complete_pending_pickup)
	GameState.player_name_changed.connect(_update_status)
	_exploration.map_changed.connect(_on_map_changed)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	_exploration.load_map(GameState.current_map_id)
	_update_status()
	_start_opening_sequence()


func _start_opening_sequence() -> void:
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
	GameState.enable_exploration()
	DialogueManager.start_knot("archives_intro")


func _unhandled_input(event: InputEvent) -> void:
	if _item_found_modal.visible:
		return
	if event.is_action_pressed("ui_inventory"):
		_inventory.toggle()
		get_viewport().set_input_as_handled()


func _on_name_confirmed(_chosen_name: String) -> void:
	_update_status()
	DialogueManager.start_knot("archives_tutorial")


func _on_map_changed(map_id: String) -> void:
	if map_id == "hall_papers" and not GameState.has_flag("hall_intro_seen"):
		GameState.set_flag("hall_intro_seen")
		call_deferred("_start_hall_intro")


func _start_hall_intro() -> void:
	await get_tree().process_frame
	if DialogueManager.is_active:
		await DialogueManager.dialogue_ended
	DialogueManager.start_knot("hall_enter")


func _on_dialogue_ended() -> void:
	_update_status()


func _update_status() -> void:
	var parts: PackedStringArray = []
	parts.append("Playing as: %s" % GameState.display_name())
	if GameState.has_flag("missing_researcher_id"):
		parts.append("(no ID — something may name you later)")
	if GameState.has_flag("scp1_befriended"):
		parts.append("Subject: friendly")
	elif GameState.has_flag("scp1_hostile"):
		parts.append("Subject: hostile")
	_status_label.text = " | ".join(parts)
