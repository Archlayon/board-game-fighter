extends Control

signal versus_ai_requested
signal board_games_requested
signal pvp_requested
signal story_requested
signal combo_lab_requested
signal settings_requested
signal settings_changed(master_volume: float, fullscreen: bool, difficulty: String)
signal quit_requested
signal resume_requested
signal return_to_menu_requested

const PANEL_COLOR := Color("#12201f")
const PANEL_BORDER := Color("#d8b75d")
const TEXT_COLOR := Color("#eee9d8")
const MUTED_COLOR := Color("#aab6a8")

var content: VBoxContainer
var status_label: Label
var master_volume := 1.0
var fullscreen := false
var difficulty := "Normal"

func _ready() -> void:
	# Pause UI must still receive input while SceneTree.paused is true.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_shell()
	show_home()

func _build_shell() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.027, 0.035, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var panel := PanelContainer.new()
	panel.name = "MenuCard"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -390
	panel.offset_right = 390
	panel.offset_top = -300
	panel.offset_bottom = 300
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL_COLOR
	panel_style.border_color = PANEL_BORDER
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 28
	panel_style.content_margin_right = 28
	panel_style.content_margin_top = 24
	panel_style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)

func show_home() -> void:
	_clear_content()
	var eyebrow := _make_label("BOARD GAME FIGHTER", 14, PANEL_BORDER)
	content.add_child(eyebrow)
	var title := _make_label("CHOOSE YOUR MODE", 34, TEXT_COLOR)
	content.add_child(title)
	var subtitle := _make_label("Step into the arena, challenge the AI, or take a break with board games.", 15, MUTED_COLOR)
	content.add_child(subtitle)
	var separator := HSeparator.new()
	content.add_child(separator)

	var modes := GridContainer.new()
	modes.columns = 2
	modes.add_theme_constant_override("h_separation", 12)
	modes.add_theme_constant_override("v_separation", 10)
	content.add_child(modes)
	_add_mode_button(modes, "VERSUS AI", "Start a fresh fighter match", Color("#337d65"), _on_versus_ai_pressed)
	_add_mode_button(modes, "BOARD GAMES", "Chess, Checkers, Ludo, Cards, Scrabble", Color("#72519a"), _on_board_games_pressed)
	_add_mode_button(modes, "STORY", "Continue the original campaign", Color("#277a91"), _on_story_pressed)
	_add_mode_button(modes, "COMBO LAB", "Practice and save combo routes", Color("#3b7251"), _on_combo_lab_pressed)
	_add_mode_button(modes, "PVP", "Online matches are not ready yet", Color("#655f50"), _on_pvp_pressed)
	_add_mode_button(modes, "SETTINGS", "Audio and display options", Color("#4e6578"), _on_settings_pressed)

	status_label = _make_label("Choose a mode to begin.", 13, MUTED_COLOR)
	status_label.name = "MenuStatus"
	status_label.custom_minimum_size.y = 22
	content.add_child(status_label)
	var footer := HBoxContainer.new()
	var hint := _make_label("TOUCH CONTROLS · MOVE WITH THE STICK · TAP ACTIONS", 11, MUTED_COLOR)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(hint)
	var quit := _make_button("QUIT", Color("#633b3a"))
	quit.custom_minimum_size = Vector2(110, 38)
	quit.pressed.connect(_on_quit_pressed)
	footer.add_child(quit)
	content.add_child(footer)

func show_settings(volume: float, use_fullscreen: bool, ai_difficulty: String, paused := false) -> void:
	master_volume = clampf(volume, 0.0, 1.0)
	fullscreen = use_fullscreen
	difficulty = ai_difficulty
	_clear_content()
	var title := _make_label("PAUSED · SETTINGS" if paused else "SETTINGS", 30, TEXT_COLOR)
	content.add_child(title)
	content.add_child(_make_label("Adjust audio, display, and AI challenge.", 15, MUTED_COLOR))

	var volume_label := _make_label("MASTER VOLUME  ·  %d%%" % roundi(master_volume * 100.0), 15, TEXT_COLOR)
	content.add_child(volume_label)
	var volume_slider := HSlider.new()
	volume_slider.name = "MasterVolume"
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.01
	volume_slider.value = master_volume
	volume_slider.custom_minimum_size.y = 28
	content.add_child(volume_slider)
	volume_slider.value_changed.connect(func(value: float) -> void:
		master_volume = value
		volume_label.text = "MASTER VOLUME  ·  %d%%" % roundi(value * 100.0)
		settings_changed.emit(master_volume, fullscreen, difficulty)
	)

	content.add_child(_make_label("AI DIFFICULTY", 15, TEXT_COLOR))
	var difficulty_select := OptionButton.new()
	difficulty_select.name = "AIDifficulty"
	for option in ["Easy", "Normal", "Hard"]:
		difficulty_select.add_item(option)
	difficulty_select.select(["Easy", "Normal", "Hard"].find(difficulty))
	difficulty_select.custom_minimum_size.y = 38
	content.add_child(difficulty_select)
	difficulty_select.item_selected.connect(func(index: int) -> void:
		difficulty = difficulty_select.get_item_text(index)
		settings_changed.emit(master_volume, fullscreen, difficulty)
	)

	var fullscreen_toggle := CheckButton.new()
	fullscreen_toggle.name = "Fullscreen"
	fullscreen_toggle.text = "Fullscreen"
	fullscreen_toggle.button_pressed = fullscreen
	fullscreen_toggle.add_theme_color_override("font_color", TEXT_COLOR)
	content.add_child(fullscreen_toggle)
	fullscreen_toggle.toggled.connect(func(enabled: bool) -> void:
		fullscreen = enabled
		settings_changed.emit(master_volume, fullscreen, difficulty)
	)

	var back := _make_button("RESUME FIGHT" if paused else "BACK TO MENU", Color("#337d65"))
	back.custom_minimum_size.y = 44
	if paused:
		back.pressed.connect(_on_resume_pressed)
	else:
		back.pressed.connect(show_home)
	content.add_child(back)
	if paused:
		var quit_to_menu := _make_button("QUIT TO MAIN MENU", Color("#633b3a"))
		quit_to_menu.custom_minimum_size.y = 44
		quit_to_menu.pressed.connect(_on_return_to_menu_pressed)
		content.add_child(quit_to_menu)
	status_label = _make_label("Changes are saved automatically.", 13, MUTED_COLOR)
	status_label.name = "MenuStatus"
	content.add_child(status_label)

func show_pause(volume: float, use_fullscreen: bool, ai_difficulty: String) -> void:
	show_settings(volume, use_fullscreen, ai_difficulty, true)

func show_notice(message: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = message

func _clear_content() -> void:
	for child in content.get_children():
		child.queue_free()
	status_label = null

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _add_mode_button(
	parent: GridContainer,
	title: String,
	description: String,
	color: Color,
	callback: Callable
) -> void:
	var button := _make_button("%s\n%s" % [title, description], color)
	button.custom_minimum_size = Vector2(330, 74)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)

func _make_button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 15)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.16)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	return button

func _on_versus_ai_pressed() -> void:
	versus_ai_requested.emit()

func _on_board_games_pressed() -> void:
	board_games_requested.emit()

func _on_pvp_pressed() -> void:
	pvp_requested.emit()

func _on_story_pressed() -> void:
	story_requested.emit()

func _on_combo_lab_pressed() -> void:
	combo_lab_requested.emit()

func _on_settings_pressed() -> void:
	settings_requested.emit()

func _on_quit_pressed() -> void:
	quit_requested.emit()

func _on_resume_pressed() -> void:
	resume_requested.emit()

func _on_return_to_menu_pressed() -> void:
	return_to_menu_requested.emit()
