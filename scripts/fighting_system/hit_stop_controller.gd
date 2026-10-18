# hit_stop_controller.gd
# Simulating fighter "impact freeze" via time scale
extends Node

# Hit-stop adds impact feel by nearly freezing the fight for a few frames.
# Use a tiny non-zero scale (not 0.0): zero stalls AnimationPlayers, physics, and
# any delta-based systems so hits look like a hard freeze / dropped frame.
# A token makes overlapping freezes safe — only the newest restore may resume time.
const HIT_STOP_SCALE := 0.05
var _token: int = 0

func apply_hit_stop(duration: float = 0.1) -> void:
	_token += 1
	var token := _token
	Engine.time_scale = HIT_STOP_SCALE
	# Process during pause and ignore time scale, otherwise this timer would never fire.
	await get_tree().create_timer(maxf(duration, 0.0), true, false, true).timeout
	if token == _token:
		Engine.time_scale = 1.0

func force_restore() -> void:
	_token += 1
	Engine.time_scale = 1.0

func _exit_tree() -> void:
	Engine.time_scale = 1.0
