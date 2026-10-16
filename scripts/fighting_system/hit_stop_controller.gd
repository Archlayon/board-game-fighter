# hit_stop_controller.gd
# Simulating fighter "impact freeze" via time scale
extends Node

# Hit-stop adds "juice" and impact feel: the whole fight freezes for a few frames when a hit lands.
# A token makes overlapping freezes safe - the newest one decides when time resumes, so an older
# timer can never un-freeze the game early.
var _token: int = 0

func apply_hit_stop(duration: float = 0.1) -> void:
	_token += 1
	var token := _token
	Engine.time_scale = 0.0
	# Process during pause and ignore time scale, otherwise this timer would never fire.
	await get_tree().create_timer(maxf(duration, 0.0), true, false, true).timeout
	if token == _token:
		Engine.time_scale = 1.0

func _exit_tree() -> void:
	Engine.time_scale = 1.0
