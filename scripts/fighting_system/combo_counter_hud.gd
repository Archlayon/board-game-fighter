extends Control
class_name ComboCounterHUD
## Large, quick combo callout with a scale hit and an inactivity reset.

@export var reset_after_seconds: float = 1.25
@export var base_font_size: int = 34
@export var accent_color: Color = Color("#ffd45c")

var _label: Label
var _reset_timer: Timer
var _active_tween: Tween
var _combo_count: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.name = "ComboLabel"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.add_theme_font_size_override("font_size", base_font_size)
	_label.add_theme_color_override("font_color", accent_color)
	_label.add_theme_color_override("font_shadow_color", Color(0.05, 0.03, 0.02, 0.9))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 3)
	_label.visible = false
	add_child(_label)
	_reset_timer = Timer.new()
	_reset_timer.one_shot = true
	_reset_timer.timeout.connect(reset_combo)
	add_child(_reset_timer)


func show_combo(hit_count: int, is_player: bool = true) -> void:
	_combo_count = maxi(hit_count, 0)
	if _combo_count < 2:
		reset_combo()
		return
	_label.text = "%d HIT COMBO!" % _combo_count
	_label.pivot_offset = _label.size * 0.5
	_label.add_theme_color_override("font_color", accent_color if is_player else Color("#ff7f75"))
	_label.visible = true
	_label.modulate.a = 1.0
	_label.scale = Vector2(0.72, 0.72)
	if _active_tween and _active_tween.is_running():
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.tween_property(_label, "scale", Vector2(1.18, 1.18), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_label, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_reset_timer.start(reset_after_seconds)


func reset_combo() -> void:
	_combo_count = 0
	if not is_instance_valid(_label):
		return
	if _active_tween and _active_tween.is_running():
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.tween_property(_label, "modulate:a", 0.0, 0.18)
	_active_tween.tween_callback(func() -> void: _label.visible = false)
