extends Control

signal fight_requested(opponent_index: int, opponent_style: String, chapter_index: int)
signal exit_requested

const CHAPTERS: Array[Dictionary] = [
	{
		"title": "THE ARENA STUTTERS",
		"opponent": 8,
		"style": "Chess",
		"intro": "A match ends, then the arena repeats the last second. The Engineer finds the fault: someone is feeding impossible moves into the combat grid.\n\nENGINEER: “This is not a glitch. It is a challenge.”",
		"outro": "The replay signal breaks. Beneath it, a second pulse answers from somewhere outside the arena."
	},
	{
		"title": "THE GRAVITY WELL",
		"opponent": 1,
		"style": "Cards",
		"intro": "The pulse bends the arena floor toward its source. The Gravity Scientist steps forward, trying to contain the distortion.\n\nGRAVITY SCIENTIST: “If I lose focus, the whole ring folds in.”",
		"outro": "The distortion releases. A clean, deliberate countdown remains in the arena's logs."
	},
	{
		"title": "ONE FINAL SECOND",
		"opponent": 0,
		"style": "Scrabble",
		"intro": "The Time Scientist traces the countdown to a loop locked around the arena. There is only one way to break it: finish a match on your own terms.\n\nTIME SCIENTIST: “No more resets. Make this one count.”",
		"outro": "The countdown stops. The arena settles, and every fighter remembers the match that finally moved forward."
	}
]

var chapter_index := 0
var campaign_progress := 0
var screen_mode := "intro"
var shade: ColorRect
var title_label: Label
var chapter_label: Label
var story_label: Label
var primary_button: Button
var exit_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()

func _build_ui() -> void:
	shade = ColorRect.new()
	shade.color = Color(0.008, 0.02, 0.035, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -300
	panel.offset_top = -220
	panel.offset_right = 300
	panel.offset_bottom = 220
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#101f2a")
	panel_style.border_color = Color("#70d9e8")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_top = 22
	panel_style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)

	title_label = Label.new()
	title_label.text = "THE FRACTURED ARENA"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", Color("#70d9e8"))
	content.add_child(title_label)

	chapter_label = Label.new()
	chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chapter_label.add_theme_color_override("font_color", Color("#f4bf4e"))
	chapter_label.add_theme_font_size_override("font_size", 16)
	content.add_child(chapter_label)

	story_label = Label.new()
	story_label.custom_minimum_size = Vector2(540, 225)
	story_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	story_label.add_theme_font_size_override("font_size", 16)
	story_label.add_theme_color_override("font_color", Color("#e9e6d8"))
	content.add_child(story_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 14)
	content.add_child(actions)

	primary_button = Button.new()
	primary_button.custom_minimum_size = Vector2(230, 46)
	primary_button.add_theme_font_size_override("font_size", 16)
	primary_button.pressed.connect(_on_primary_pressed)
	actions.add_child(primary_button)

	exit_button = Button.new()
	exit_button.text = "BACK TO FIGHT"
	exit_button.custom_minimum_size = Vector2(170, 46)
	exit_button.pressed.connect(_on_exit_pressed)
	actions.add_child(exit_button)

func open_campaign(progress: int) -> void:
	campaign_progress = clampi(progress, 0, CHAPTERS.size())
	visible = true
	if campaign_progress >= CHAPTERS.size():
		_show_completed()
	else:
		_show_intro(campaign_progress)

func show_result(index: int, player_won: bool, progress: int) -> void:
	chapter_index = clampi(index, 0, CHAPTERS.size() - 1)
	campaign_progress = clampi(progress, 0, CHAPTERS.size())
	visible = true
	screen_mode = "result"
	var chapter: Dictionary = CHAPTERS[chapter_index]
	chapter_label.text = str(chapter.title)
	if not player_won:
		title_label.text = "RETRY THE CHAPTER"
		story_label.text = "The arena resets to the start of the encounter.\n\n%s" % chapter.intro
		primary_button.text = "RETRY CHAPTER"
	elif chapter_index == CHAPTERS.size() - 1:
		title_label.text = "CAMPAIGN COMPLETE"
		story_label.text = str(chapter.outro)
		primary_button.text = "REPLAY CAMPAIGN"
	else:
		title_label.text = "CHAPTER COMPLETE"
		story_label.text = str(chapter.outro)
		primary_button.text = "NEXT CHAPTER"

func _show_intro(index: int) -> void:
	chapter_index = clampi(index, 0, CHAPTERS.size() - 1)
	screen_mode = "intro"
	var chapter: Dictionary = CHAPTERS[chapter_index]
	title_label.text = "THE FRACTURED ARENA"
	chapter_label.text = "CHAPTER %d OF %d  ·  %s" % [chapter_index + 1, CHAPTERS.size(), chapter.title]
	story_label.text = str(chapter.intro)
	primary_button.text = "ENTER ARENA"

func _show_completed() -> void:
	chapter_index = 0
	screen_mode = "completed"
	title_label.text = "CAMPAIGN COMPLETE"
	chapter_label.text = "ALL CHAPTERS CLEARED"
	story_label.text = str(CHAPTERS.back().outro)
	primary_button.text = "REPLAY CAMPAIGN"

func _on_primary_pressed() -> void:
	if screen_mode == "intro":
		_start_chapter(chapter_index)
	elif screen_mode == "result":
		if chapter_index < CHAPTERS.size() - 1 and campaign_progress > chapter_index:
			_show_intro(chapter_index + 1)
		elif chapter_index == CHAPTERS.size() - 1 and campaign_progress >= CHAPTERS.size():
			_show_intro(0)
		else:
			_start_chapter(chapter_index)
	elif screen_mode == "completed":
		campaign_progress = 0
		_show_intro(0)

func _start_chapter(index: int) -> void:
	var chapter: Dictionary = CHAPTERS[index]
	visible = false
	fight_requested.emit(int(chapter.opponent), str(chapter.style), index)

func _on_exit_pressed() -> void:
	visible = false
	exit_requested.emit()
