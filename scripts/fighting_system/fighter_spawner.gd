extends Node3D
class_name FighterSpawner
## Creates a configured local-player or AI fighter from a roster scene.

signal fighter_spawned(fighter: Node3D, is_local_player: bool)

@export var spawn_parent: Node3D


func spawn_fighter(
		fighter_scene: PackedScene,
		spawn_position: Vector3,
		selection: FighterSelectionData,
		is_local_player: bool) -> Node3D:
	if fighter_scene == null:
		push_error("FighterSpawner needs a PackedScene.")
		return null
	var fighter := fighter_scene.instantiate() as Node3D
	if not is_instance_valid(fighter):
		push_error("The fighter scene root must inherit Node3D.")
		return null
	var parent := spawn_parent if is_instance_valid(spawn_parent) else self
	parent.add_child(fighter)
	fighter.global_position = spawn_position
	fighter.set_meta("is_local_player", is_local_player)
	if selection != null:
		fighter.set_meta("fighter_selection", selection.to_character_dictionary())
		fighter.set_meta("character_archetype", str(selection.archetype))
	fighter_spawned.emit(fighter, is_local_player)
	return fighter
