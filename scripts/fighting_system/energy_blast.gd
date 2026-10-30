extends Area3D
class_name EnergyBlast
## Fast, single-hit projectile. Configure `damage_data` before calling launch().

signal impacted(target: Node3D, data: Dictionary)

@export var speed: float = 22.0
@export var lifetime: float = 2.2
@export var push_strength: float = 6.0

var direction: Vector3 = Vector3.FORWARD
var owner_fighter: Node3D
var damage_data: Dictionary = {}
var _age: float = 0.0
var _spent: bool = false
var _hit_instance_ids: Dictionary = {}


func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func launch(origin: Vector3, travel_direction: Vector3, owner: Node3D, hit_data: Dictionary) -> void:
	global_position = origin
	direction = travel_direction.normalized() if travel_direction.length_squared() > 0.0001 else Vector3.FORWARD
	owner_fighter = owner
	damage_data = hit_data.duplicate(true)
	_age = 0.0
	_spent = false
	look_at(global_position + direction, Vector3.UP)


func _physics_process(delta: float) -> void:
	if _spent:
		return
	_age += delta
	global_position += direction * speed * delta
	if _age >= lifetime:
		_despawn()


func _on_body_entered(body: Node3D) -> void:
	_try_impact(body)


func _on_area_entered(area: Area3D) -> void:
	var target := area.get_parent() as Node3D
	if is_instance_valid(target):
		_try_impact(target)


func _try_impact(target: Node3D) -> void:
	if _spent or not is_instance_valid(target) or target == owner_fighter:
		return
	var target_id := target.get_instance_id()
	if _hit_instance_ids.has(target_id):
		return
	_hit_instance_ids[target_id] = true
	var hit := damage_data.duplicate(true)
	hit["source"] = owner_fighter
	hit["projectile"] = self
	if target.has_method("receive_projectile_hit"):
		target.call("receive_projectile_hit", hit)
	elif target.has_method("apply_hit"):
		target.call("apply_hit", hit)
	if target is CharacterBody3D:
		var body := target as CharacterBody3D
		body.velocity += direction * push_strength
	impacted.emit(target, hit)
	_despawn()


func _despawn() -> void:
	if _spent:
		return
	_spent = true
	set_deferred("monitoring", false)
	queue_free()
