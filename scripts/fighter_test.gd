extends Node3D

@onready var player = get_node("Player")
@onready var enemy = get_node("Enemy")
@onready var camera = get_node("Camera3D")

func _ready() -> void:
	print("=== Player Model Structure ===")
	_print_tree(player.get_node("Model"), 0)
	
	print("\n=== Enemy Model Structure ===")
	_print_tree(enemy.get_node("Model"), 0)
	
	# Setup player
	_setup_fighter(player, true)
	_setup_fighter(enemy, false)

func _setup_fighter(fighter: CharacterBody3D, is_player: bool) -> void:
	var model = fighter.get_node("Model")
	var combat = fighter.get_node("Combat")
	var animator = fighter.get_node("Animator")
	
	# Find skeleton and animation player in model
	var skeleton = _find_node(model, "Skeleton3D")
	var anim_player = _find_node(model, "AnimationPlayer")
	
	if not anim_player:
		# AnimationPlayer might be on the root of imported scene
		anim_player = model.get_node_or_null("AnimationPlayer")
	
	if anim_player:
		print("\n=== %s Animations ===" % fighter.name)
		for anim_name in anim_player.get_animation_list():
			var anim = anim_player.get_animation(anim_name)
			print("  %s: %.2fs" % [anim_name, anim.length])
	
	# Setup FighterCombat
	if combat:
		combat.hitbox = TestHitbox.new()
		combat.hurtbox = TestHurtbox.new()
		fighter.add_child(combat.hitbox)
		fighter.add_child(combat.hurtbox)
		combat.hitbox.name = "Hitbox"
		combat.hurtbox.name = "Hurtbox"
		(combat.hitbox as TestHitbox).target = combat.hurtbox as TestHurtbox
	
	# Setup FighterAnimator
	if animator and anim_player:
		animator.combat = combat
		animator.animation_tree = AnimationTree.new()
		fighter.add_child(animator.animation_tree)
		animator.animation_tree.anim_player = anim_player
		animator.body = fighter
		
		# Set animation names based on UAL library
		animator.anim_idle = &"Idle_Loop"
		animator.anim_run = &"Walk_Loop"
		animator.anim_block = &"Idle_Shield_Loop"
		animator.anim_charge = &"Spell_Simple_Idle_Loop"
		animator.anim_stun = &"Hit_Chest"
		animator.anim_knockdown = &"Death01"
		animator.anim_hit_light = &"Hit_Chest"
		animator.anim_hit_heavy = &"Hit_Knockback"

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