extends Control

signal vector_changed(value: Vector2)

var knob_value := Vector2.ZERO
var is_pressed := false

# Alias for compatibility with DoubleFlickDodge
var output: Vector2:
	get:
		return knob_value

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		is_pressed = event.pressed
		if is_pressed:
			_update_knob(event.position)
		else:
			knob_value = Vector2.ZERO
			vector_changed.emit(knob_value)
			queue_redraw()
	elif event is InputEventScreenDrag and is_pressed:
		_update_knob(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_pressed = event.pressed
		if is_pressed:
			_update_knob(event.position)
		else:
			knob_value = Vector2.ZERO
			vector_changed.emit(knob_value)
			queue_redraw()
	elif event is InputEventMouseMotion and is_pressed:
		_update_knob(event.position)

func _update_knob(position: Vector2) -> void:
	var radius := minf(size.x, size.y) * 0.34
	var center := size * 0.5
	knob_value = ((position - center) / maxf(radius, 1.0)).limit_length(1.0)
	vector_changed.emit(knob_value)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.46
	draw_circle(center, radius, Color(0.035, 0.07, 0.09, 0.55))
	draw_arc(center, radius, 0.0, TAU, 64, Color(0.8, 0.9, 1.0, 0.75), 2.0, true)
	draw_arc(center, radius * 0.55, 0.0, TAU, 48, Color(0.8, 0.9, 1.0, 0.45), 2.0, true)
	draw_circle(center + knob_value * radius * 0.65, radius * 0.28, Color(0.65, 0.84, 1.0, 0.92))
	draw_arc(center + knob_value * radius * 0.65, radius * 0.28, 0.0, TAU, 48, Color.WHITE, 2.0, true)
