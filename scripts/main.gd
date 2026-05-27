extends Control

@onready var _exploration: Control = %ExplorationMap
@onready var _dialogue_box: PanelContainer = %DialogueBox
@onready var _inventory: PanelContainer = %InventoryPanel
@onready var _name_modal: PanelContainer = %NameEntryModal
@onready var _inventory_button: Button = %InventoryButton
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	_inventory_button.pressed.connect(_inventory.toggle)
	_dialogue_box.advance_requested.connect(DialogueManager.advance)
	_exploration.naming_required.connect(_name_modal.show_modal)
	_name_modal.name_confirmed.connect(_on_name_confirmed)
	GameState.player_name_changed.connect(_update_status)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	_exploration.load_map(GameState.current_map_id)
	_update_status()
	DialogueManager.start_knot("archives_intro")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_inventory"):
		_inventory.toggle()
		get_viewport().set_input_as_handled()


func _on_name_confirmed(_name: String) -> void:
	_update_status()
	DialogueManager.start_knot("archives_tutorial")


func _on_dialogue_ended() -> void:
	_update_status()
	if GameState.current_map_id == "hall_papers" and not GameState.has_flag("hall_intro_seen"):
		GameState.set_flag("hall_intro_seen")
		DialogueManager.start_knot("hall_enter")


func _update_status() -> void:
	var parts: PackedStringArray = []
	parts.append("Playing as: %s" % GameState.display_name())
	if GameState.has_flag("missing_researcher_id"):
		parts.append("(no ID — SCPs may name you later)")
	if GameState.has_flag("scp1_befriended"):
		parts.append("SCP-?: friendly")
	elif GameState.has_flag("scp1_hostile"):
		parts.append("SCP-?: hostile")
	_status_label.text = " | ".join(parts)
