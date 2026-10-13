extends Node3D

@onready var ual1 = get_node("UAL1_Instance")
@onready var ual2 = get_node("UAL2_Instance")

func _ready() -> void:
	print("=== UAL1 Structure ===")
	_print_tree(ual1, 0)
	print("\n=== UAL2 Structure ===")
	_print_tree(ual2, 0)
	
	# Find AnimationPlayers
	var ap1 = _find_node(ual1, "AnimationPlayer")
	var ap2 = _find_node(ual2, "AnimationPlayer")
	
	if ap1:
		print("\n=== UAL1 Animations ===")
		for anim_name in ap1.get_animation_list():
			var anim = ap1.get_animation(anim_name)
			print("  %s: %.2fs, loops=%s, tracks=%d" % [anim_name, anim.length, anim.loop_mode != Animation.LOOP_NONE, anim.get_track_count()])
	
	if ap2:
		print("\n=== UAL2 Animations ===")
		for anim_name in ap2.get_animation_list():
			var anim = ap2.get_animation(anim_name)
			print("  %s: %.2fs, loops=%s, tracks=%d" % [anim_name, anim.length, anim.loop_mode != Animation.LOOP_NONE, anim.get_track_count()])
	
	# Also check for AnimationLibrary
	var al1 = _find_node(ual1, "AnimationLibrary")
	var al2 = _find_node(ual2, "AnimationLibrary")
	if al1:
		print("\n=== UAL1 AnimationLibrary ===")
		print("  Type: %s" % al1.get_class())
	if al2:
		print("\n=== UAL2 AnimationLibrary ===")
		print("  Type: %s" % al2.get_class())

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