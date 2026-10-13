class_name DoubleFlickDodge
extends Node
## Detects a quick double flick on the movement joystick and emits `dodged`.
##
## ASSUMPTION: the joystick node is MarcoFazioRandom's Virtual-Joystick-Godot, which
## exposes `output` (Vector2) and `is_pressed` (bool) in its README example. If you use
## a different joystick addon, only the two lines in _process need changing.

signal dodged(direction: Vector2)  # joystick-space direction, y is "down" on screen

@export var joystick: Control
## Stick strength needed to count as a flick, and how far it must fall back before the
## next flick can register (stops one long push counting twice).
@export_range(0.1, 1.0) var push_threshold := 0.7
@export_range(0.0, 0.9) var release_threshold := 0.3
## Max time (seconds) between the two flicks.
@export var window := 0.3
## How closely the two flicks must point the same way (1 = identical, 0.7 ~ 45 degrees).
@export_range(0.0, 1.0) var same_direction_min := 0.7

var _pushed := false
var _last_dir := Vector2.ZERO
var _last_time := 0.0


func _process(_delta: float) -> void:
	var out: Vector2 = joystick.output if joystick.is_pressed else Vector2.ZERO
	var strength := out.length()

	if not _pushed and strength >= push_threshold:
		_pushed = true
		_register_flick(out.normalized())
	elif _pushed and strength <= release_threshold:
		_pushed = false


func _register_flick(dir: Vector2) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var is_second := (
		_last_dir != Vector2.ZERO
		and now - _last_time <= window
		and _last_dir.dot(dir) >= same_direction_min
	)
	if is_second:
		_last_dir = Vector2.ZERO  # reset so a third flick starts a new pair
		dodged.emit(dir)
	else:
		_last_dir = dir
		_last_time = now