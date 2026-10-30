extends CharacterBody3D
class_name FightEngineEntity
## Reusable character controller for the separate CharacterBody3D arena path.
## The current main.gd fighters remain Node3D-driven; this controller is for
## new fighter scenes and tests that need authoritative CharacterBody physics.

signal state_changed(previous: State, current: State)
signal buffered_move_requested(move: Dictionary)
signal attack_started(move: Dictionary)
signal attack_window_changed(active: bool)
signal observed_attack(timestamp_usec: int)

enum State { IDLE, MOVING, ATTACKING, FLYING, HITSTUN, BLOCKING }

@export_group("Movement")
@export var walk_speed: float = 5.0
@export var acceleration: float = 24.0
@export var ground_friction: float = 28.0
@export var jump_speed: float = 7.5
@export var gravity_strength: float = 22.0
@export var flight_speed: float = 8.0
@export var flight_response: float = 12.0

@export_group("Combat")
@export var input_buffer_seconds: float = 0.18
@export var hitstun_seconds: float = 0.45
@export var attack_hitboxes: Array[Area3D] = []
@export var animation_player: AnimationPlayer

var current_state: State = State.IDLE
var opponent: Node3D
var health: float = 100.0
var max_health: float = 100.0
var invulnerable: bool = false
var _buffered_inputs: Array[Dictionary] = []
var _recent_attack_times: Array[int] = []
var _state_generation: int = 0
var _hitstun_left: float = 0.0
var _flight_input: Vector3 = Vector3.ZERO
var _move_input: Vector2 = Vector2.ZERO
var _ai_block_probability: float = 0.0


func _physics_process(delta: float) -> void:
	_prune_input_buffer()
	if current_state == State.HITSTUN:
		_hitstun_left = maxf(0.0, _hitstun_left - delta)
		if _hitstun_left == 0.0:
			_transition_to(State.IDLE)
	if current_state == State.FLYING:
		velocity = velocity.lerp(_flight_input * flight_speed, 1.0 - exp(-flight_response * delta))
	else:
		if not is_on_floor():
			velocity.y -= gravity_strength * delta
		else:
			velocity.y = maxf(velocity.y, 0.0)
		if current_state in [State.IDLE, State.MOVING]:
			var direction := Vector3(_move_input.x, 0.0, _move_input.y)
			if direction.length_squared() > 1.0:
				direction = direction.normalized()
			var target := direction * walk_speed
			var planar := Vector3(velocity.x, 0.0, velocity.z)
			var rate := acceleration if direction.length_squared() > 0.001 else ground_friction
			planar = planar.move_toward(target, rate * delta)
			velocity.x = planar.x
			velocity.z = planar.z
			_transition_to(State.MOVING if direction.length_squared() > 0.001 else State.IDLE)
	move_and_slide()
	if current_state in [State.IDLE, State.MOVING] and not _buffered_inputs.is_empty():
		var input_record := _buffered_inputs.pop_front()
		buffered_move_requested.emit(input_record.get("move", {}))


func set_move_input(input_vector: Vector2) -> void:
	_move_input = input_vector if current_state in [State.IDLE, State.MOVING] else Vector2.ZERO


func jump() -> void:
	if current_state in [State.IDLE, State.MOVING] and is_on_floor():
		velocity.y = jump_speed


func set_flight_input(input_vector: Vector3, enabled: bool) -> void:
	_flight_input = input_vector.normalized() if input_vector.length_squared() > 1.0 else input_vector
	if enabled:
		_transition_to(State.FLYING)
	elif current_state == State.FLYING:
		_transition_to(State.IDLE)


func buffer_attack(move: Dictionary) -> void:
	_buffered_inputs.append({"move": move.duplicate(true), "timestamp_usec": Time.get_ticks_usec()})
	while _buffered_inputs.size() > 8:
		_buffered_inputs.pop_front()


func begin_attack(move: Dictionary, startup_seconds: float, active_seconds: float, recovery_seconds: float) -> void:
	if current_state in [State.HITSTUN, State.BLOCKING, State.FLYING]:
		buffer_attack(move)
		return
	_state_generation += 1
	var generation := _state_generation
	_transition_to(State.ATTACKING)
	attack_started.emit(move)
	await get_tree().create_timer(maxf(startup_seconds, 0.0)).timeout
	if generation != _state_generation or not is_inside_tree():
		return
	_set_attack_hitboxes(true)
	attack_window_changed.emit(true)
	await get_tree().create_timer(maxf(active_seconds, 0.01)).timeout
	if generation != _state_generation or not is_inside_tree():
		return
	_set_attack_hitboxes(false)
	attack_window_changed.emit(false)
	await get_tree().create_timer(maxf(recovery_seconds, 0.0)).timeout
	if generation == _state_generation and is_inside_tree():
		_transition_to(State.IDLE)


func enter_hitstun(duration: float = -1.0) -> void:
	_state_generation += 1
	_set_attack_hitboxes(false)
	_hitstun_left = hitstun_seconds if duration < 0.0 else maxf(duration, 0.0)
	_transition_to(State.HITSTUN)


func set_blocking(enabled: bool) -> void:
	if enabled and current_state not in [State.ATTACKING, State.HITSTUN, State.FLYING]:
		_transition_to(State.BLOCKING)
	elif not enabled and current_state == State.BLOCKING:
		_transition_to(State.IDLE)


func record_player_attack(timestamp_usec: int = -1) -> void:
	var stamp := timestamp_usec if timestamp_usec >= 0 else Time.get_ticks_usec()
	_recent_attack_times.append(stamp)
	while _recent_attack_times.size() > 5:
		_recent_attack_times.pop_front()
	observed_attack.emit(stamp)


func predict_attack_time_usec() -> int:
	if _recent_attack_times.size() < 2:
		return -1
	var intervals: Array[int] = []
	for index in range(1, _recent_attack_times.size()):
		intervals.append(_recent_attack_times[index] - _recent_attack_times[index - 1])
	intervals.sort()
	return _recent_attack_times.back() + intervals[intervals.size() / 2]


func should_predictive_block(now_usec: int = -1) -> bool:
	if _recent_attack_times.size() < 3 or randf() > _ai_block_probability:
		return false
	var predicted := predict_attack_time_usec()
	var now := now_usec if now_usec >= 0 else Time.get_ticks_usec()
	return predicted >= now and predicted - now <= 180000


func set_ai_block_probability(probability: float) -> void:
	_ai_block_probability = clampf(probability, 0.0, 1.0)


func punish_whiff_if_close(player_is_recovering: bool, punish_move: Dictionary, max_distance: float = 2.4) -> bool:
	if not player_is_recovering or not is_instance_valid(opponent):
		return false
	if global_position.distance_to(opponent.global_position) > max_distance:
		return false
	begin_attack(punish_move, 0.08, 0.12, 0.24)
	return true


func _set_attack_hitboxes(active: bool) -> void:
	for hitbox in attack_hitboxes:
		if is_instance_valid(hitbox):
			hitbox.monitoring = active
			hitbox.monitorable = active


func _transition_to(next_state: State) -> void:
	if current_state == next_state:
		return
	var previous := current_state
	current_state = next_state
	state_changed.emit(previous, next_state)


func _prune_input_buffer() -> void:
	var cutoff := Time.get_ticks_usec() - roundi(input_buffer_seconds * 1000000.0)
	while not _buffered_inputs.is_empty() and int(_buffered_inputs[0].get("timestamp_usec", 0)) < cutoff:
		_buffered_inputs.pop_front()
