extends Node3D

@onready var ual1 = get_node("UAL1")
@onready var ual2 = get_node("UAL2")

func _ready() -> void:
	print("=== UAL1 Structure ===")
	_print_tree(ual1, 0)
	
	print("\n=== UAL2 Structure ===")
	_print_tree(ual2, 0)
	
	# Find AnimationPlayer
	var ap1 = _find_node(ual1, "AnimationPlayer")
	var ap2 = _find_node(ual2, "AnimationPlayer")
	
	if ap1:
		print("\n=== UAL1 Animations ===")
		for anim_name in ap1.get_animation_list():
			var anim = ap1.get_animation(anim_name)
			print("  %s: %.2fs" % [anim_name, anim.length])
	
	if ap2:
		print("\n=== UAL2 Animations ===")
		for anim_name in ap2.get_animation_list():
			var anim = ap2.get_animation(anim_name)
			print("  %s: %.2fs" % [anim_name, anim.length])
	
	# Find Skeleton3D
	var sk1 = _find_node(ual1, "Skeleton3D")
	var sk2 = _find_node(ual2, "Skeleton3D")
	if sk1:
		print("\nUAL1 Skeleton3D found, bones: %d" % sk1.get_bone_count())
	if sk2:
		print("UAL2 Skeleton3D found, bones: %d" % sk2.get_bone_count())

func _print_tree(node: Node, depth: int) -> void:
	var indent = ""
	for i in range(depth):
		indent += "  "
	print("%s%s (%s)" % [indent, node.name, node.get_class()])
	for child in node.get_children():
		_print_tree(child, depth + 1)

func _find_node(root: Node, type_name: String) -> Node:
	if root.get_class() == type_name:
		return root
	for child in root.get_children():
		var found = _find_node(child, type_name)
		if found:
			return found
	return null