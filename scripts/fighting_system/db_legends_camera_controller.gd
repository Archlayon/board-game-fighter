extends Node3D
class_name DBLegendsCameraController
## Gimbal-style camera for the game's face-to-face arena.

@export var camera: Camera3D
@export var tracking_smoothing: float = 7.0
@export var melee_distance: float = 3.2
@export var normal_distance: float = 8.5
@export var minimum_distance: float = 6.0
@export var maximum_distance: float = 13.0
@export var low_angle_height: float = 2.6

var player: Node3D
var opponent: Node3D
var melee_profile_enabled: bool = false
var shake_strength: float = 0.0
var shake_decay: float = 3.5
var _shake_phase: float = 0.0
var _target_fov: float = 45.0
var _fov_punch: float = 0.0


func set_targets(player_target: Node3D, opponent_target: Node3D) -> void:
	player = player_target
	opponent = opponent_target


func set_melee_profile(active: bool) -> void:
	melee_profile_enabled = active


func set_impact_shake(strength: float, decay: float = 3.5) -> void:
	shake_strength = maxf(shake_strength, maxf(strength, 0.0))
	shake_decay = maxf(decay, 0.1)


func punch_fov(amount: float) -> void:
	_fov_punch = maxf(_fov_punch, clampf(amount, 0.0, 0.6))


func update_camera(delta: float, movement_speed: float = 0.0, dashing: bool = false) -> void:
	if not is_instance_valid(camera) or not is_instance_valid(player) or not is_instance_valid(opponent):
		return
	var center := (player.global_position + opponent.global_position) * 0.5
	var span := player.global_position.distance_to(opponent.global_position)
	var vertical_span := absf(player.global_position.y - opponent.global_position.y)
	var melee := melee_profile_enabled and span <= melee_distance
	var distance := clampf(normal_distance + span * 0.35 + vertical_span * 0.2, minimum_distance, maximum_distance)
	var side_sign := -1.0 if player.global_position.x < opponent.global_position.x else 1.0
	var shoulder_offset := Vector3(side_sign * 1.1, low_angle_height, distance)
	var side_offset := Vector3(0.0, low_angle_height * 0.78, clampf(span * 1.8, 6.0, 10.0))
	var desired_position := center + (side_offset if melee else shoulder_offset)
	_shake_phase += delta * 58.0
	shake_strength = move_toward(shake_strength, 0.0, shake_decay * delta)
	var shake := Vector3(
		sin(_shake_phase) * shake_strength,
		cos(_shake_phase * 1.73) * shake_strength * 0.35,
		0.0
	)
	var desired_transform := Transform3D(Basis(), desired_position + shake)
	var desired_look := center + Vector3.UP * 0.85
	var look_basis := Basis.looking_at(desired_look - desired_position - shake, Vector3.UP)
	desired_transform.basis = look_basis
	var blend := 1.0 - exp(-tracking_smoothing * delta)
	camera.global_transform = camera.global_transform.interpolate_with(desired_transform, blend)
	var speed_factor := clampf(movement_speed / 5.5, 0.0, 1.8)
	if dashing:
		speed_factor = maxf(speed_factor, 1.5)
	_target_fov = lerpf(45.0, 66.0, clampf(speed_factor * 0.45, 0.0, 1.0))
	_fov_punch = move_toward(_fov_punch, 0.0, delta * 3.8)
	camera.fov = lerpf(camera.fov, _target_fov - _fov_punch * 30.0, blend)
