extends Control

signal practice_active_changed(active: bool, combo: Dictionary)
signal practice_progress_changed(message: String)
signal practice_completed(combo_name: String, success: bool)
signal panel_opened(opened: bool)

const COMBO_FILE := "user://combo_library.json"
const BACKUP_FILE := "user://combo_library.backup.json"
const MAX_IMPORT_BYTES := 65536
const MAX_COMBOS := 100
const MAX_NAME_LENGTH := 48
const MAX_NOTES_LENGTH := 240
const MAX_STEPS := 12
const STYLE_NAMES: Array[String] = ["Any", "Chess", "Checkers", "Ludo", "Cards", "Scrabble"]
const STEP_ALIASES: Dictionary = {
	"P": "Punch",
	"K": "Kick",
	"G": "Grab",
	"JP": "Jump Punch",
	"JK": "Jump Kick",
	"GP": "Grapple Punch",
	"T": "Throw"
}
const BUILTIN_COMBOS: Array[Dictionary] = [
	{"name": "Starter Chain", "style": "Any", "notation": "P > K", "notes": "Land a punch, then connect a kick.", "steps": ["Punch", "Kick"], "successes": 0},
	{"name": "Air Follow-up", "style": "Any", "notation": "JP > JK", "notes": "Land a jump punch followed by a jump kick.", "steps": ["Jump Punch", "Jump Kick"], "successes": 0},
	{"name": "Grapple Finish", "style": "Any", "notation": "G > T", "notes": "Connect a grab and finish with a throw.", "steps": ["Grab", "Throw"], "successes": 0}
]

var combos: Array[Dictionary] = []
var visible_indices: Array[int] = []
var selected_index := -1
var practice_index := -1
var practice_step := 0
var practicing := false
var library_path := COMBO_FILE
var search_input: LineEdit
var combo_list: ItemList
var name_input: LineEdit
var style_option: OptionButton
var notation_input: LineEdit
var notes_input: TextEdit
var status_label: Label
var practice_button: Button
var confirm_dialog: ConfirmationDialog

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_load_library()
	_refresh_list()
	visible = false

func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.04, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -390
	panel.offset_right = 390
	panel.offset_top = -300
	panel.offset_bottom = 300
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 16)
	content_margin.add_theme_constant_override("margin_right", 16)
	content_margin.add_theme_constant_override("margin_top", 14)
	content_margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(content_margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	content_margin.add_child(layout)

	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var title := Label.new()
	title.text = "COMBO COMPANION"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#e5c879"))
	heading.add_child(title)
	var heading_spacer := Control.new()
	heading_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(heading_spacer)
	_add_button(heading, "CLOSE", _close)

	var description := Label.new()
	description.text = "Build a local combo notebook, translate button notation, and practice confirmed-hit sequences."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(description)

	search_input = LineEdit.new()
	search_input.placeholder_text = "Search names, styles, notation, or notes"
	search_input.text_changed.connect(_on_search_changed)
	layout.add_child(search_input)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 10)
	layout.add_child(columns)

	combo_list = ItemList.new()
	combo_list.custom_minimum_size = Vector2(220, 260)
	combo_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	combo_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	combo_list.item_selected.connect(_on_combo_selected)
	columns.add_child(combo_list)

	var editor := VBoxContainer.new()
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.add_theme_constant_override("separation", 6)
	columns.add_child(editor)
	name_input = LineEdit.new()
	name_input.placeholder_text = "Combo name"
	name_input.max_length = MAX_NAME_LENGTH
	editor.add_child(name_input)
	style_option = OptionButton.new()
	for style_name in STYLE_NAMES:
		style_option.add_item(style_name)
	editor.add_child(style_option)
	notation_input = LineEdit.new()
	notation_input.placeholder_text = "Notation: P > K > JP"
	editor.add_child(notation_input)
	var notation_hint := Label.new()
	notation_hint.text = "P punch · K kick · G grab · JP/JK jump attacks · GP grapple punch · T throw. You can also enter full style-move names."
	notation_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	editor.add_child(notation_hint)
	notes_input = TextEdit.new()
	notes_input.placeholder_text = "Practice notes"
	notes_input.custom_minimum_size.y = 72
	notes_input.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.add_child(notes_input)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 5)
	layout.add_child(actions)
	_add_button(actions, "NEW", _new_combo)
	_add_button(actions, "SAVE", _save_combo)
	_add_button(actions, "DELETE", _confirm_delete)
	practice_button = _add_button(actions, "PRACTICE", _start_practice)

	var sharing := HBoxContainer.new()
	sharing.add_theme_constant_override("separation", 5)
	layout.add_child(sharing)
	_add_button(sharing, "COPY / EXPORT", _export_selected)
	_add_button(sharing, "PASTE / IMPORT", _import_from_clipboard)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.y = 34
	layout.add_child(status_label)

	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "Delete combo?"
	confirm_dialog.dialog_text = "This combo will be removed from your local library."
	confirm_dialog.confirmed.connect(_delete_selected)
	add_child(confirm_dialog)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#14201e")
	style.border_color = Color("#e5c879")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	return style

func _add_button(row: HBoxContainer, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	row.add_child(button)
	return button

func toggle_panel() -> void:
	if practicing:
		stop_practice()
		return
	visible = not visible
	panel_opened.emit(visible)
	if visible:
		search_input.grab_focus()

func _close() -> void:
	visible = false
	panel_opened.emit(false)

func _on_search_changed(_text: String) -> void:
	_refresh_list()

func _refresh_list() -> void:
	if not is_instance_valid(combo_list):
		return
	combo_list.clear()
	visible_indices.clear()
	var query := search_input.text.strip_edges().to_lower() if is_instance_valid(search_input) else ""
	for index in range(combos.size()):
		var combo := combos[index]
		var searchable := "%s %s %s %s" % [combo.name, combo.style, combo.notation, combo.notes]
		if query.is_empty() or searchable.to_lower().contains(query):
			visible_indices.append(index)
			combo_list.add_item("%s  ·  %s" % [combo.name, combo.notation])
	if selected_index >= 0 and selected_index < combos.size():
		var visible_position := visible_indices.find(selected_index)
		if visible_position >= 0:
			combo_list.select(visible_position)
			_fill_editor(combos[selected_index])
	_update_controls()

func _on_combo_selected(visible_position: int) -> void:
	if visible_position < 0 or visible_position >= visible_indices.size():
		return
	selected_index = visible_indices[visible_position]
	_fill_editor(combos[selected_index])
	_set_status("")
	_update_controls()

func _fill_editor(combo: Dictionary) -> void:
	name_input.text = str(combo.name)
	style_option.select(STYLE_NAMES.find(str(combo.style)))
	notation_input.text = str(combo.notation)
	notes_input.text = str(combo.notes)

func _update_controls() -> void:
	if is_instance_valid(practice_button):
		practice_button.disabled = selected_index < 0 or selected_index >= combos.size()
		practice_button.text = "STOP PRACTICE" if practicing else "PRACTICE"

func _new_combo() -> void:
	selected_index = -1
	combo_list.deselect_all()
	name_input.text = ""
	style_option.select(0)
	notation_input.text = ""
	notes_input.text = ""
	_set_status("Enter a name, optional style, and a sequence such as P > K > JP.")
	_update_controls()

func _save_combo() -> void:
	var parsed := _parse_notation(notation_input.text)
	if not bool(parsed.ok):
		_set_status(str(parsed.error))
		return
	var entry := {
		"name": name_input.text.strip_edges(),
		"style": STYLE_NAMES[style_option.selected],
		"notation": parsed.notation,
		"notes": notes_input.text.strip_edges(),
		"steps": parsed.steps,
		"successes": int(combos[selected_index].successes) if selected_index >= 0 and selected_index < combos.size() else 0
	}
	var validated := _validate_combo(entry)
	if not bool(validated.ok):
		_set_status(str(validated.error))
		return
	var duplicate_index := _find_combo(str(entry.name), str(entry.style))
	if duplicate_index >= 0 and duplicate_index != selected_index:
		_set_status("A combo with that name and style already exists.")
		return
	var previous := combos.duplicate(true)
	if selected_index >= 0 and selected_index < combos.size():
		combos[selected_index] = validated.combo
	else:
		if combos.size() >= MAX_COMBOS:
			_set_status("The local library supports up to %d combos." % MAX_COMBOS)
			return
		combos.append(validated.combo)
		selected_index = combos.size() - 1
	if _save_library():
		_refresh_list()
		_set_status("Saved “%s”." % entry.name)
	else:
		combos = previous
		_refresh_list()

func _confirm_delete() -> void:
	if selected_index < 0 or selected_index >= combos.size():
		_set_status("Choose a combo to delete.")
		return
	confirm_dialog.popup_centered()

func _delete_selected() -> void:
	if selected_index < 0 or selected_index >= combos.size():
		return
	var previous := combos.duplicate(true)
	var deleted_name := str(combos[selected_index].name)
	combos.remove_at(selected_index)
	selected_index = -1
	if _save_library():
		_refresh_list()
		_new_combo()
		_set_status("Deleted “%s”." % deleted_name)
	else:
		combos = previous
		_refresh_list()

func _parse_notation(notation: String) -> Dictionary:
	var raw_steps := notation.split(">", false)
	if raw_steps.is_empty() or raw_steps.size() > MAX_STEPS:
		return {"ok": false, "error": "A combo must contain between 1 and %d steps, separated by >." % MAX_STEPS}
	var steps: Array[String] = []
	for raw_step in raw_steps:
		var token := str(raw_step).strip_edges()
		if token.is_empty():
			return {"ok": false, "error": "Combo steps cannot be empty. Separate each step with >."}
		var canonical := _canonical_step(token)
		if canonical.is_empty():
			return {"ok": false, "error": "Unknown step “%s”. Use P, K, G, JP, JK, GP, T, or a full move name." % token}
		steps.append(canonical)
	return {"ok": true, "steps": steps, "notation": " > ".join(steps), "error": ""}

func _canonical_step(token: String) -> String:
	var upper := token.to_upper()
	if STEP_ALIASES.has(upper):
		return str(STEP_ALIASES[upper])
	if token.to_lower() in ["punch", "kick", "grab", "jump punch", "jump kick", "grapple punch", "throw"]:
		for step in STEP_ALIASES.values():
			if str(step).to_lower() == token.to_lower():
				return str(step)
	for style in GameData.STYLE_MOVES:
		for move in GameData.STYLE_MOVES[style]:
			if str(move.get("kind", "")) in ["attack", "trap"] and str(move.name).to_lower() == token.to_lower():
				return str(move.name)
	return ""

func _validate_combo(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"ok": false, "error": "Combo data must be an object."}
	var name := str(value.get("name", "")).strip_edges()
	var style := str(value.get("style", "Any"))
	var notes := str(value.get("notes", "")).strip_edges()
	if name.is_empty() or name.length() > MAX_NAME_LENGTH:
		return {"ok": false, "error": "Enter a combo name of 1–%d characters." % MAX_NAME_LENGTH}
	if notes.length() > MAX_NOTES_LENGTH:
		return {"ok": false, "error": "Practice notes must be %d characters or fewer." % MAX_NOTES_LENGTH}
	if not STYLE_NAMES.has(style):
		return {"ok": false, "error": "This combo uses an unknown style."}
	var steps: Array[String] = []
	var raw_steps: Variant = value.get("steps", [])
	if not raw_steps is Array or raw_steps.is_empty() or raw_steps.size() > MAX_STEPS:
		return {"ok": false, "error": "Combo steps must contain between 1 and %d actions." % MAX_STEPS}
	for raw_step in raw_steps:
		if typeof(raw_step) != TYPE_STRING:
			return {"ok": false, "error": "A combo step must be text."}
		var canonical := _canonical_step(str(raw_step))
		if canonical.is_empty():
			return {"ok": false, "error": "Unknown combo step “%s”." % raw_step}
		steps.append(canonical)
	var successes_value: Variant = value.get("successes", 0)
	var successes := 0
	if typeof(successes_value) == TYPE_INT:
		successes = int(successes_value)
	elif typeof(successes_value) == TYPE_FLOAT and is_equal_approx(float(successes_value), roundf(float(successes_value))):
		successes = int(successes_value)
	if successes < 0:
		return {"ok": false, "error": "Combo success count cannot be negative."}
	return {
		"ok": true,
		"combo": {
			"name": name,
			"style": style,
			"notation": " > ".join(steps),
			"notes": notes,
			"steps": steps,
			"successes": successes
		},
		"error": ""
	}

func _find_combo(name: String, style: String) -> int:
	for index in range(combos.size()):
		if str(combos[index].name).to_lower() == name.to_lower() and str(combos[index].style) == style:
			return index
	return -1

func _start_practice() -> void:
	if practicing:
		stop_practice()
		return
	if selected_index < 0 or selected_index >= combos.size():
		_set_status("Choose a combo to practice.")
		return
	practice_index = selected_index
	practice_step = 0
	practicing = true
	var combo := combos[practice_index].duplicate(true)
	visible = false
	panel_opened.emit(false)
	_update_controls()
	_emit_progress("COMBO PRACTICE · %s · 0/%d" % [combo.name, combo.steps.size()])
	practice_active_changed.emit(true, combo)

func record_successful_move(move_name: String) -> void:
	if not practicing or practice_index < 0 or practice_index >= combos.size():
		return
	var combo: Dictionary = combos[practice_index]
	var steps: Array = combo.steps
	var attempted := _canonical_step(move_name)
	if attempted.is_empty():
		return
	if attempted == str(steps[practice_step]):
		practice_step += 1
	else:
		practice_step = 1 if attempted == str(steps[0]) else 0
	if practice_step >= steps.size():
		combo.successes = int(combo.successes) + 1
		combos[practice_index] = combo
		var combo_name := str(combo.name)
		practicing = false
		practice_index = -1
		var save_succeeded := _save_library()
		practice_active_changed.emit(false, {})
		var message := "COMBO COMPLETE · %s · %d SUCCESS%s" % [combo_name, combo.successes, "" if int(combo.successes) == 1 else "ES"]
		if not save_succeeded:
			message += " · SAVE FAILED"
		_emit_progress(message)
		practice_completed.emit(combo_name, true)
		_update_controls()
	else:
		_emit_progress("COMBO PRACTICE · %s · %d/%d · LANDED %s" % [combo.name, practice_step, steps.size(), attempted.to_upper()])

func record_missed_move() -> void:
	if practicing and practice_step > 0:
		practice_step = 0
		var combo: Dictionary = combos[practice_index]
		_emit_progress("COMBO RESET · %s · ATTACKS MUST CONNECT" % combo.name)

func stop_practice() -> void:
	if not practicing:
		return
	practicing = false
	practice_index = -1
	practice_step = 0
	practice_active_changed.emit(false, {})
	_emit_progress("COMBO PRACTICE STOPPED")
	practice_completed.emit("", false)
	_update_controls()

func _emit_progress(message: String) -> void:
	call_deferred("_emit_progress_now", message)

func _emit_progress_now(message: String) -> void:
	practice_progress_changed.emit(message)

func export_selected() -> String:
	if selected_index < 0 or selected_index >= combos.size():
		return ""
	return JSON.stringify({"version": 1, "combos": [combos[selected_index]]}, "\t")

func import_text(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_IMPORT_BYTES:
		return {"ok": false, "error": "Import is too large (maximum 64 KB)."}
	var json := JSON.new()
	var parse_error := json.parse(text)
	if parse_error != OK:
		return {"ok": false, "error": "Invalid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()]}
	if not json.data is Dictionary or int(json.data.get("version", 0)) != 1 or not json.data.get("combos", null) is Array:
		return {"ok": false, "error": "Unsupported combo export format."}
	var incoming: Array = json.data.combos
	if incoming.is_empty() or incoming.size() > MAX_COMBOS or combos.size() + incoming.size() > MAX_COMBOS:
		return {"ok": false, "error": "Import must contain 1–%d combos and fit the local library limit." % MAX_COMBOS}
	var validated_entries: Array[Dictionary] = []
	var import_names: Dictionary = {}
	for value in incoming:
		var validation := _validate_combo(value)
		if not bool(validation.ok):
			return {"ok": false, "error": str(validation.error)}
		var entry: Dictionary = validation.combo
		var key := "%s|%s" % [str(entry.name).to_lower(), entry.style]
		if import_names.has(key) or _find_combo(str(entry.name), str(entry.style)) >= 0:
			return {"ok": false, "error": "An imported combo duplicates an existing combo name and style."}
		import_names[key] = true
		validated_entries.append(entry)
	var previous := combos.duplicate(true)
	combos.append_array(validated_entries)
	if not _save_library():
		combos = previous
		return {"ok": false, "error": "Could not save imported combos."}
	selected_index = combos.size() - validated_entries.size()
	_refresh_list()
	return {"ok": true, "count": validated_entries.size(), "error": ""}

func _export_selected() -> void:
	var export_text := export_selected()
	if export_text.is_empty():
		_set_status("Choose a combo to export.")
		return
	DisplayServer.clipboard_set(export_text)
	_set_status("Combo JSON copied to the clipboard.")

func _import_from_clipboard() -> void:
	var result := import_text(DisplayServer.clipboard_get())
	_set_status("Imported %d combo%s." % [result.count, "" if result.count == 1 else "s"] if result.ok else str(result.error))

func _save_library(path := "") -> bool:
	if path.is_empty():
		path = library_path
	var error := _write_library(path, combos)
	if error != OK:
		push_error("Unable to save combo library: %s" % error_string(error))
		_set_status("Could not save combo library: %s" % error_string(error))
		return false
	return true

func _load_library(path := "") -> void:
	if path.is_empty():
		path = library_path
	if not FileAccess.file_exists(path):
		combos = BUILTIN_COMBOS.duplicate(true)
		if not _save_library(path):
			combos = BUILTIN_COMBOS.duplicate(true)
		return
	var result := _read_library(path)
	if not result.ok:
		push_error("Unable to load combo library: %s" % result.error)
		combos = BUILTIN_COMBOS.duplicate(true)
		_set_status("Combo library could not be loaded: %s" % result.error)
		return
	combos = result.combos

func _read_library(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "combos": [], "error": error_string(FileAccess.get_open_error())}
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return {"ok": false, "combos": [], "error": "invalid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()]}
	if not json.data is Dictionary or int(json.data.get("version", 0)) != 1 or not json.data.get("combos", null) is Array:
		return {"ok": false, "combos": [], "error": "unsupported combo library format"}
	var raw_combos: Array = json.data.combos
	if raw_combos.size() > MAX_COMBOS:
		return {"ok": false, "combos": [], "error": "combo library exceeds the %d-combo limit" % MAX_COMBOS}
	var loaded: Array[Dictionary] = []
	var names: Dictionary = {}
	for value in raw_combos:
		var validation := _validate_combo(value)
		if not bool(validation.ok):
			return {"ok": false, "combos": [], "error": str(validation.error)}
		var combo: Dictionary = validation.combo
		var key := "%s|%s" % [str(combo.name).to_lower(), combo.style]
		if names.has(key):
			return {"ok": false, "combos": [], "error": "combo names must be unique within each style"}
		names[key] = true
		loaded.append(combo)
	return {"ok": true, "combos": loaded, "error": ""}

func _write_library(path: String, values: Array[Dictionary]) -> Error:
	if FileAccess.file_exists(path):
		var backup_error := _copy_file(path, BACKUP_FILE if path == COMBO_FILE else path + ".backup")
		if backup_error != OK:
			return backup_error
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": 1, "combos": values}, "\t"))
	var error := file.get_error()
	file.close()
	return error

func _copy_file(source: String, destination: String) -> Error:
	var bytes := FileAccess.get_file_as_bytes(source)
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	var error := file.get_error()
	file.close()
	return error

func _set_status(message: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = message
