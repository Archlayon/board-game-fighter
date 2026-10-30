extends Node
class_name RollbackStateSerializer
## Captures compact authoritative fighter snapshots for rollback/replay tools.

@export_range(2, 600, 1) var history_capacity: int = 180

var _history: Dictionary = {}
var _frame_order: Array[int] = []


func save_state(frame: int, fighters: Array[Node3D]) -> PackedByteArray:
	var records: Array[Dictionary] = []
	for fighter in fighters:
		if not is_instance_valid(fighter):
			continue
		var record: Dictionary = {
			"instance_id": fighter.get_instance_id(),
			"position": fighter.global_position,
			"rotation": fighter.global_rotation,
			"scale": fighter.scale,
			"health": float(fighter.get_meta("health", -1.0)),
			"state": int(fighter.get_meta("state", 0)),
		}
		if fighter is CharacterBody3D:
			record["velocity"] = (fighter as CharacterBody3D).velocity
		records.append(record)
	var snapshot: Dictionary = {"frame": frame, "fighters": records}
	var bytes := var_to_bytes(snapshot)
	_history[frame] = bytes
	_frame_order.append(frame)
	while _frame_order.size() > history_capacity:
		var expired := _frame_order.pop_front()
		_history.erase(expired)
	return bytes


func state_at(frame: int) -> PackedByteArray:
	return _history.get(frame, PackedByteArray())


func restore_state(snapshot_bytes: PackedByteArray, fighters: Array[Node3D]) -> int:
	if snapshot_bytes.is_empty():
		return -1
	var decoded: Variant = bytes_to_var(snapshot_bytes)
	if not decoded is Dictionary:
		return -1
	var snapshot: Dictionary = decoded
	var records: Array = snapshot.get("fighters", [])
	var by_id: Dictionary = {}
	for fighter in fighters:
		if is_instance_valid(fighter):
			by_id[fighter.get_instance_id()] = fighter
	for value in records:
		if not value is Dictionary:
			continue
		var record: Dictionary = value
		var fighter: Node3D = by_id.get(int(record.get("instance_id", -1)))
		if not is_instance_valid(fighter):
			continue
		fighter.global_position = record.get("position", fighter.global_position)
		fighter.global_rotation = record.get("rotation", fighter.global_rotation)
		fighter.scale = record.get("scale", fighter.scale)
		if fighter is CharacterBody3D and record.has("velocity"):
			(fighter as CharacterBody3D).velocity = record["velocity"]
		fighter.set_meta("health", record.get("health", -1.0))
		fighter.set_meta("state", record.get("state", 0))
	return int(snapshot.get("frame", -1))


func clear_history() -> void:
	_history.clear()
	_frame_order.clear()
