extends Control

## Security desk terminal: login screen -> desktop -> folder -> document viewer.
## The password is currently hard-coded to "Admin" for testing; later it will be
## discovered in-world among documents.

signal closed

const PASSWORD := "Admin"

## Teletype reveal: ~old-computer speed, but always finishes within TYPE_MAX_SEC.
const TYPE_PER_CHAR_SEC := 0.012
const TYPE_MAX_SEC := 8.0

const TEX_LOGIN := preload("res://assets/Security computer bits/computer screen.png")
const TEX_DESKTOP := preload("res://assets/Security computer bits/desktop.png")

## Access-control elevator rows. White-text overlays tinted red (off) / green (on).
const TEX_OFFICE_OFF := preload("res://assets/Security computer bits/ACCESS_OFFICE-OFF.png")
const TEX_OFFICE_ON := preload("res://assets/Security computer bits/ACCESS_OFFICE-ON.png")
const TEX_LAB_OFF := preload("res://assets/Security computer bits/ACCESS_LAB-OFF.png")
const TEX_LAB_ON := preload("res://assets/Security computer bits/ACCESS_LAB-ON.png")
const TEX_MAIN_OFF := preload("res://assets/Security computer bits/ACCESS_MAIN-OFF.png")
const TEX_MAIN_ON := preload("res://assets/Security computer bits/ACCESS_MAIN-ON.png")
const COLOR_ON := Color(0.18, 0.78, 0.30)
const COLOR_OFF := Color(0.86, 0.18, 0.18)

enum State { LOGIN, DESKTOP, FOLDER, DOCUMENT, ACCESS }

## Desktop folders -> their files. Each file points at a rich-text (.rtf) source
## that is parsed and printed into the folder window. Empty folders show a notice.
const FOLDERS := {
	"personnel": {
		"title": "Personnel Records",
		"files": [
			{
				"name": "Nany Woods — Personnel File",
				"path": "res://assets/Security computer bits/Personnel files/NanyWoods.rtf",
			},
		],
	},
	"access": {"title": "Access Control", "files": []},
	"incident": {"title": "Incident Logs", "files": []},
	"containment": {"title": "Containment Protocols", "files": []},
}

@onready var _screen_bg: TextureRect = %ScreenBg
@onready var _login_field: LineEdit = %LoginField
@onready var _login_error: Label = %LoginError
@onready var _desktop_icons: Control = %DesktopIcons
@onready var _personnel_button: Button = %PersonnelButton
@onready var _access_button: Button = %AccessButton
@onready var _incident_button: Button = %IncidentButton
@onready var _containment_button: Button = %ContainmentButton
@onready var _hi_personnel: TextureRect = %HiPersonnel
@onready var _hi_access: TextureRect = %HiAccess
@onready var _hi_incident: TextureRect = %HiIncident
@onready var _hi_containment: TextureRect = %HiContainment
@onready var _folder_window: TextureRect = %FolderWindow
@onready var _window_close: Button = %WindowClose
@onready var _window_title: Label = %WindowTitle
@onready var _file_list: VBoxContainer = %FileList
@onready var _doc_text: RichTextLabel = %DocText
@onready var _access_window: TextureRect = %AccessWindow
@onready var _row_office: TextureRect = %RowOffice
@onready var _row_lab: TextureRect = %RowLab
@onready var _row_maint: TextureRect = %RowMaint
@onready var _access_close: Button = %AccessClose
@onready var _access_close_hi: TextureRect = %AccessCloseHi
@onready var _row_office_btn: Button = %RowOfficeBtn
@onready var _row_lab_btn: Button = %RowLabBtn
@onready var _row_maint_btn: Button = %RowMaintBtn

var _state: int = State.LOGIN
var _exploration_was_enabled: bool = false
var _type_tween: Tween


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_login_field()
	_login_field.text_submitted.connect(func(_t: String) -> void: _try_login())
	_login_field.text_changed.connect(func(_t: String) -> void: _login_error.text = "")
	_personnel_button.pressed.connect(func() -> void: _open_folder("personnel"))
	_access_button.pressed.connect(_open_access)
	_incident_button.pressed.connect(func() -> void: _open_folder("incident"))
	_containment_button.pressed.connect(func() -> void: _open_folder("containment"))
	_window_close.pressed.connect(_close_window)
	_wire_hover(_personnel_button, _hi_personnel)
	_wire_hover(_access_button, _hi_access)
	_wire_hover(_incident_button, _hi_incident)
	_wire_hover(_containment_button, _hi_containment)
	_access_close.pressed.connect(_close_window)
	_wire_hover(_access_close, _access_close_hi)
	_row_office_btn.pressed.connect(func() -> void: _toggle_elevator("elevator_office"))
	_row_lab_btn.pressed.connect(func() -> void: _toggle_elevator("elevator_lab"))
	_row_maint_btn.pressed.connect(func() -> void: _toggle_elevator("elevator_maintenance"))


## The password row in the login art is a light box; make the field transparent
## with dark masked text so it reads against the artwork.
func _style_login_field() -> void:
	_login_field.secret = true
	_login_field.secret_character = "●"
	var empty := StyleBoxEmpty.new()
	for style_name in ["normal", "focus", "read_only"]:
		_login_field.add_theme_stylebox_override(style_name, empty)
	_login_field.add_theme_color_override("font_color", Color(0.12, 0.14, 0.2))
	_login_field.add_theme_color_override("font_placeholder_color", Color(0.3, 0.34, 0.42, 0.55))
	_login_field.add_theme_color_override("caret_color", Color(0.12, 0.14, 0.2))


func open() -> void:
	if visible:
		return
	_exploration_was_enabled = GameState.exploration_enabled
	GameState.disable_exploration()
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	if GameState.has_flag("computer_unlocked"):
		_set_state(State.DESKTOP)
	else:
		_set_state(State.LOGIN)


func close() -> void:
	if not visible:
		return
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_login_field.release_focus()
	if _exploration_was_enabled:
		GameState.enable_exploration()
	else:
		GameState.disable_exploration()
	closed.emit()


func _set_state(state: int) -> void:
	# Leaving (or re-entering) any screen cancels an in-progress teletype reveal.
	_kill_type_tween()
	_state = state
	var login := state == State.LOGIN
	var desktop_or_more := state != State.LOGIN
	var window_open := state == State.FOLDER or state == State.DOCUMENT
	_login_field.visible = login
	_login_error.visible = login
	_desktop_icons.visible = desktop_or_more
	_folder_window.visible = window_open
	_access_window.visible = state == State.ACCESS
	match state:
		State.LOGIN:
			_screen_bg.texture = TEX_LOGIN
			_login_field.text = ""
			_login_error.text = ""
			_login_field.grab_focus()
		State.DESKTOP:
			_screen_bg.texture = TEX_DESKTOP
			_login_field.release_focus()
		State.FOLDER:
			_file_list.visible = true
			_doc_text.visible = false
		State.DOCUMENT:
			_file_list.visible = false
			_doc_text.visible = true
		State.ACCESS:
			_refresh_access_rows()


func _try_login() -> void:
	var entered := _login_field.text.strip_edges()
	if entered.to_lower() == PASSWORD.to_lower():
		GameState.set_flag("computer_unlocked")
		_set_state(State.DESKTOP)
	else:
		_login_error.text = "ACCESS DENIED — incorrect password."
		_login_field.text = ""
		_login_field.grab_focus()


func _open_folder(folder_id: String) -> void:
	var folder: Dictionary = FOLDERS.get(folder_id, {})
	_window_title.text = str(folder.get("title", "Folder"))
	for child in _file_list.get_children():
		child.queue_free()
	var files: Array = folder.get("files", [])
	if files.is_empty():
		_file_list.add_child(_make_notice("This folder contains no accessible files."))
	else:
		for file in files:
			_file_list.add_child(_make_file_entry(str(file.get("name", "Untitled")), str(file.get("path", ""))))
	_set_state(State.FOLDER)


## Access control: a board of elevator gates. Each row is red when its access is
## off and green when on; clicking a row toggles it.
func _open_access() -> void:
	_set_state(State.ACCESS)


func _toggle_elevator(flag: String) -> void:
	GameState.set_flag(flag, not GameState.has_flag(flag))
	_refresh_access_rows()


func _refresh_access_rows() -> void:
	_apply_row(_row_office, GameState.has_flag("elevator_office"), TEX_OFFICE_ON, TEX_OFFICE_OFF)
	_apply_row(_row_lab, GameState.has_flag("elevator_lab"), TEX_LAB_ON, TEX_LAB_OFF)
	_apply_row(_row_maint, GameState.has_flag("elevator_maintenance"), TEX_MAIN_ON, TEX_MAIN_OFF)


func _apply_row(row: TextureRect, on: bool, on_tex: Texture2D, off_tex: Texture2D) -> void:
	row.texture = on_tex if on else off_tex
	row.modulate = COLOR_ON if on else COLOR_OFF


func _open_file(file_path: String, display_name: String) -> void:
	_window_title.text = display_name
	_doc_text.text = _load_rich_text(file_path)
	_doc_text.scroll_to_line(0)
	_set_state(State.DOCUMENT)
	_start_typewriter()


## Reveal the document character-by-character (fast, capped at TYPE_MAX_SEC).
func _start_typewriter() -> void:
	_kill_type_tween()
	var total := _doc_text.get_total_character_count()
	if total <= 0:
		_doc_text.visible_ratio = 1.0
		return
	_doc_text.visible_ratio = 0.0
	var duration: float = minf(TYPE_MAX_SEC, float(total) * TYPE_PER_CHAR_SEC)
	_type_tween = create_tween()
	_type_tween.set_trans(Tween.TRANS_LINEAR)
	_type_tween.tween_property(_doc_text, "visible_ratio", 1.0, duration)


func _is_typing() -> bool:
	return _type_tween != null and _type_tween.is_valid()


func _finish_typewriter() -> void:
	_kill_type_tween()
	_doc_text.visible_ratio = 1.0


func _kill_type_tween() -> void:
	if _type_tween and _type_tween.is_valid():
		_type_tween.kill()
	_type_tween = null


## Back out one level: document -> folder list -> desktop -> close terminal.
func _close_window() -> void:
	match _state:
		State.DOCUMENT:
			# Return to the folder listing this file lives in.
			_set_state(State.FOLDER)
		State.FOLDER, State.ACCESS:
			_set_state(State.DESKTOP)
		_:
			close()


func _go_back() -> void:
	match _state:
		State.DOCUMENT:
			_set_state(State.FOLDER)
		State.FOLDER, State.ACCESS:
			_set_state(State.DESKTOP)
		_:
			close()


func _make_file_entry(display_name: String, file_path: String) -> Button:
	var btn := Button.new()
	btn.text = "▸  " + display_name
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_color_override("font_color", Color(0.1, 0.13, 0.2))
	btn.add_theme_color_override("font_hover_color", Color(0.05, 0.25, 0.55))
	btn.add_theme_color_override("font_pressed_color", Color(0.05, 0.25, 0.55))
	btn.add_theme_font_size_override("font_size", 26)
	btn.pressed.connect(func() -> void: _open_file(file_path, display_name))
	return btn


func _make_notice(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.35, 0.4, 0.5))
	label.add_theme_font_size_override("font_size", 24)
	return label


func _wire_hover(button: Button, highlight: TextureRect) -> void:
	button.mouse_entered.connect(func() -> void: _fade_highlight(highlight, 1.0))
	button.mouse_exited.connect(func() -> void: _fade_highlight(highlight, 0.0))


func _fade_highlight(highlight: TextureRect, target_a: float) -> void:
	var tween := create_tween()
	tween.tween_property(highlight, "modulate:a", target_a, 0.12)


## Read a .rtf file and convert it into readable plain text for the viewer.
func _load_rich_text(file_path: String) -> String:
	if not FileAccess.file_exists(file_path):
		push_warning("Terminal document missing: %s" % file_path)
		return "[ File not found ]"
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return "[ Unable to open file ]"
	var raw := file.get_as_text()
	file.close()
	if file_path.to_lower().ends_with(".rtf"):
		return _rtf_to_text(raw)
	return raw


## Minimal RTF -> plain text converter: enough to faithfully print simple
## TextEdit/Cocoa dossiers (paragraphs, line breaks, bullets, dashes, quotes).
func _rtf_to_text(rtf: String) -> String:
	var out := ""
	var i := 0
	var n := rtf.length()
	var ignore_stack: Array[bool] = [false]
	var uc_stack: Array[int] = [1]
	while i < n:
		var c := rtf[i]
		if c == "{":
			ignore_stack.push_back(ignore_stack[-1])
			uc_stack.push_back(uc_stack[-1])
			i += 1
		elif c == "}":
			if ignore_stack.size() > 1:
				ignore_stack.pop_back()
				uc_stack.pop_back()
			i += 1
		elif c == "\\":
			if i + 1 >= n:
				i += 1
				continue
			var nxt := rtf[i + 1]
			if nxt == "'":
				var hex := rtf.substr(i + 2, 2)
				i += 4
				if not ignore_stack[-1]:
					out += _cp1252(hex.hex_to_int())
			elif nxt == "\\" or nxt == "{" or nxt == "}":
				i += 2
				if not ignore_stack[-1]:
					out += nxt
			elif nxt == "\n" or nxt == "\r":
				i += 2
				if not ignore_stack[-1]:
					out += "\n"
			elif nxt == "~":
				i += 2
				if not ignore_stack[-1]:
					out += " "
			elif nxt == "*":
				ignore_stack[-1] = true
				i += 2
			elif _is_alpha(nxt):
				var j := i + 1
				while j < n and _is_alpha(rtf[j]):
					j += 1
				var word := rtf.substr(i + 1, j - (i + 1))
				var num := ""
				if j < n and (rtf[j] == "-" or _is_digit(rtf[j])):
					var k := j
					if rtf[k] == "-":
						k += 1
					while k < n and _is_digit(rtf[k]):
						k += 1
					num = rtf.substr(j, k - j)
					j = k
				if j < n and rtf[j] == " ":
					j += 1
				i = j
				var res := _apply_control_word(word, num, ignore_stack, uc_stack, rtf, i)
				out += str(res["text"])
				i = int(res["idx"])
			else:
				i += 2
		else:
			if c == "\n" or c == "\r":
				i += 1
			else:
				if not ignore_stack[-1]:
					out += c
				i += 1
	# Tidy excess whitespace/newlines.
	var re := RegEx.new()
	re.compile("[ \\t]+")
	out = re.sub(out, " ", true)
	var re2 := RegEx.new()
	re2.compile("\\n{3,}")
	out = re2.sub(out, "\n\n", true)
	return out.strip_edges()


## Handle one control word. Returns {"text": <to append>, "idx": <new scan index>}.
## The ignore/uc stacks are Arrays (passed by reference) so they mutate in place.
func _apply_control_word(word: String, num: String, ignore_stack: Array, uc_stack: Array, rtf: String, idx: int) -> Dictionary:
	var ignoring: bool = ignore_stack[-1]
	var add := ""
	match word:
		"par", "line", "sect":
			if not ignoring:
				add = "\n"
		"tab":
			if not ignoring:
				add = "\t"
		"uc":
			uc_stack[-1] = int(num) if not num.is_empty() else 1
		"bullet":
			if not ignoring:
				add = "\u2022"
		"emdash":
			if not ignoring:
				add = "\u2014"
		"endash":
			if not ignoring:
				add = "\u2013"
		"u":
			if not ignoring and not num.is_empty():
				var code := int(num)
				if code < 0:
					code += 65536
				add = char(code)
			# Skip the unicode fallback characters that follow.
			var skip: int = uc_stack[-1]
			var new_idx := idx
			while skip > 0 and new_idx < rtf.length():
				if rtf[new_idx] == "\\" and new_idx + 1 < rtf.length() and rtf[new_idx + 1] == "'":
					new_idx += 4
				else:
					new_idx += 1
				skip -= 1
			return {"text": add, "idx": new_idx}
		"fonttbl", "colortbl", "stylesheet", "listtable", "listoverridetable", "expandedcolortbl", "filetbl", "info", "pict", "object", "themedata", "datastore":
			ignore_stack[-1] = true
		_:
			pass
	return {"text": add, "idx": idx}


func _is_alpha(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z")


func _is_digit(c: String) -> bool:
	return c >= "0" and c <= "9"


## Map CP1252 high bytes (smart quotes, dashes, ellipsis) to proper Unicode.
func _cp1252(code: int) -> String:
	match code:
		0x91: return "\u2018"
		0x92: return "\u2019"
		0x93: return "\u201C"
		0x94: return "\u201D"
		0x95: return "\u2022"
		0x96: return "\u2013"
		0x97: return "\u2014"
		0x85: return "\u2026"
		0x99: return "\u2122"
		_: return char(code)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()
		return
	# While a document is teletyping, any keypress/click skips to the full text.
	if _state == State.DOCUMENT and _is_typing():
		var key_press: bool = event is InputEventKey and event.pressed and not event.echo
		var click: bool = event is InputEventMouseButton and event.pressed
		if key_press or click:
			_finish_typewriter()
			get_viewport().set_input_as_handled()
