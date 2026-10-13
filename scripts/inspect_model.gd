extends Node3D

@onready var model = get_node("Model")

func _ready() -> void:
	print("=== Model Structure ===")
	_print_tree(model, 0)
	
	# Check for Skeleton3D
	var skeletons = _find_all_skeletons(model)
	print("\n=== All Skeleton3D found: %d ===" % skeletons.size())
	for s in skeletons:
		print("  %s - bones: %d" % [s.get_path(), s.get_bone_count()])
		for i in range(s.get_bone_count()):
			print("    Bone %d: %s" % [i, s.get_bone_name(i)])
	
	# Find all MeshInstance3D
	var meshes = _find_all_meshes(model)
	print("\n=== All MeshInstance3D found: %d ===" % meshes.size())
	for m in meshes:
		print("  %s - mesh: %s, material: %s" % [m.get_path(), m.mesh, m.material_override])

func _print_tree(node: Node, depth: int) -> void:
	var indent = ""
	for i in range(depth):
		indent += "  "
	var extra = ""
	if node is MeshInstance3D:
		extra = " [MESH: %s]" % node.mesh
	elif node is Skeleton3D:
		extra = " [SKELETON: %d bones]" % node.get_bone_count()
	print("%s%s (%s)%s" % [indent, node.name, node.get_class(), extra])
	for child in node.get_children():
		_print_tree(child, depth + 1)

func _find_all_meshes(root: Node) -> Array:
	var result = []
	if root is MeshInstance3D:
		result.append(root)
	for child in root.get_children():
		result.append_array(_find_all_meshes(child))
	return result

func _find_all_skeletons(root: Node) -> Array:
	var result = []
	if root is Skeleton3D:
		result.append(root)
	for child in root.get_children():
		result.append_array(_find_all_skeletons(child))
	return result