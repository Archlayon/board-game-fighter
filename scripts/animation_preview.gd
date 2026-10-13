extends Node3D

@onready var ual1_model: Node3D = get_node("UAL1_Model")
@onready var ual2_model: Node3D = get_node("UAL2_Model")
@onready var library_select: OptionButton = get_node("CanvasLayer/UI_Panel/VBoxContainer/LibrarySelect")
@onready var animation_list: ItemList = get_node("CanvasLayer/UI_Panel/VBoxContainer/AnimationList")
@onready var play_button: Button = get_node("CanvasLayer/UI_Panel/VBoxContainer/PlayButton")
@onready var loop_check: CheckButton = get_node("CanvasLayer/UI_Panel/VBoxContainer/LoopCheck")
@onready var speed_slider: HSlider = get_node("CanvasLayer/UI_Panel/VBoxContainer/SpeedSlider")
@onready var speed_label: Label = get_node("CanvasLayer/UI_Panel/VBoxContainer/SpeedLabel")
@onready var anim_info: Label = get_node("CanvasLayer/UI_Panel/VBoxContainer/AnimInfo")

var current_player: AnimationPlayer
var current_model: Node3D
var animations_cache: Dictionary = {}

func _ready() -> void:
	_cache_animations()
	library_select.item_selected.connect(_on_library_changed)
	animation_list.item_selected.connect(_on_anim_selected)
	play_button.pressed.connect(_play_animation)
	loop_check.toggled.connect(_on_loop_changed)
	speed_slider.value_changed.connect(_on_speed_changed)
	_on_library_changed(0)

func _cache_animations() -> void:
	var ual1_player = ual1_model.get_node_or_null("AnimationPlayer")
	var ual2_player = ual2_model.get_node_or_null("AnimationPlayer")
	
	if ual1_player:
		animations_cache["UAL1"] = _get_anim_list(ual1_player)
	if ual2_player:
		animations_cache["UAL2"] = _get_anim_list(ual2_player)

func _get_anim_list(player: AnimationPlayer) -> Array[String]:
	var list = []
	for anim_name in player.get_animation_list():
		var anim = player.get_animation(anim_name)
		list.append("%s (%.2fs)" % [anim_name, anim.length])
	return list

func _on_library_changed(index: int) -> void:
	animation_list.clear()
	var lib_name = "UAL1" if index == 0 else "UAL2"
	current_model = ual1_model if index == 0 else ual2_model
	current_player = current_model.get_node_or_null("AnimationPlayer")
	
	if current_player and animations_cache.has(lib_name):
		for anim in animations_cache[lib_name]:
			animation_list.add_item(anim)
	
	play_button.disabled = true
	anim_info.text = "Select an animation from %s (%d animations)" % [lib_name, animation_list.get_item_count()]

func _on_anim_selected(index: int) -> void:
	play_button.disabled = false
	if current_player:
		var anim_name = _get_clean_name(animation_list.get_item_text(index))
		var anim = current_player.get_animation(anim_name)
		anim_info.text = "Length: %.2fs\nLoops: %s\nTracks: %d" % [
			anim.length, "Yes" if anim.loop_mode != Animation.LOOP_NONE else "No", anim.get_track_count()
		]

func _get_clean_name(display_text: String) -> String:
	return display_text.get_slice(" (", 0)

func _play_animation() -> void:
	if not current_player:
		return
	var index = animation_list.get_selected_items()
	if index.is_empty():
		return
	var anim_name = _get_clean_name(animation_list.get_item_text(index[0]))
	current_player.play(anim_name)
	current_player.playback_speed = speed_slider.value
	if loop_check.pressed:
		current_player.autoplay = anim_name
	else:
		current_player.autoplay = &""

func _on_loop_changed(pressed: bool) -> void:
	if current_player:
		if pressed:
			current_player.autoplay = current_player.get_current_animation()
		else:
			current_player.autoplay = &""

func _on_speed_changed(value: float) -> void:
	speed_label.text = "Speed: %.1fx" % value
	if current_player and current_player.is_playing():
		current_player.playback_speed = value

func _process(delta: float) -> void:
	if current_player and current_player.is_playing():
		var anim = current_player.get_current_animation()
		if anim:
			var pos = current_player.get_current_animation_position()
			anim_info.text = "%s\nPos: %.2f / %.2fs" % [anim, pos, current_player.get_animation(anim).length]