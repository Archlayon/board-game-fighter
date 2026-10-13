# direct_hitbox_query_3d.gd
# Bypassing Area3D for frame-perfect intersection tests (3D version)
extends Node3D

# EXPERT NOTE: For precision, query the PhysicsServer directly. 
# Area3D overlaps are only updated once per physics frame.

func check_hitbox_3d(query_pos: Vector3, radius: float, collision_mask: int = 0, exclude: Array[RID] = []) -> Array:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	
	var shape = SphereShape3D.new()
	shape.radius = radius
	query.shape_rid = shape.get_rid()
	query.transform = Transform3D(Basis.IDENTITY, query_pos)
	query.collision_mask = collision_mask if collision_mask != 0 else 0xFFFFFFFF
	query.exclude = exclude
	
	return space_state.intersect_shape(query)

# For directional hitboxes (capsules/boxes)
func check_hitbox_shape_3d(shape: Shape3D, transform: Transform3D, collision_mask: int = 0, exclude: Array[RID] = []) -> Array:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape_rid = shape.get_rid()
	query.transform = transform
	query.collision_mask = collision_mask if collision_mask != 0 else 0xFFFFFFFF
	query.exclude = exclude
	
	return space_state.intersect_shape(query)
