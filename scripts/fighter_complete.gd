extends Node3D

@onready var player = get_node("Player")
@onready var enemy = get_node("Enemy")
@onready var camera = get_node("Camera3D")

var moves: Dictionary = {}

func _ready() -> void:
	_create_moves()
	_setup_fighter(player, true)
	_setup_fighter(enemy, false)
	_connect_fighters()

func _create_moves() -> void:
	var move_data_script = preload("res://scripts/move_data.gd")
	
	# Jab - basic, fast
	var jab = move_data_script.new()
	jab.id = &"jab"
	jab.display_name = "Jab"
	jab.tier = move_data_script.Tier.BASIC
	jab.mp_cost = 5.0
	jab.damage = 20.0
	jab.stun_damage = 15.0
	jab.startup = 0.1
	jab.active_time = 0.1
	jab.recovery = 0.2
	jab.animation = &"Punch_Jab"
	moves["jab"] = jab
	
	# Cross - basic, more damage
	var cross = move_data_script.new()
	cross.id = &"cross"
	cross.display_name = "Cross"
	cross.tier = move_data_script.Tier.BASIC
	cross.mp_cost = 8.0
	cross.damage = 30.0
	cross.stun_damage = 20.0
	cross.startup = 0.15
	cross.active_time = 0.1
	cross.recovery = 0.25
	cross.animation = &"Punch_Cross"
	moves["cross"] = cross
	
	# Kick - medium
	var kick = move_data_script.new()
	kick.id = &"kick"
	kick.display_name = "Kick"
	kick.tier = move_data_script.Tier.MEDIUM
	kick.mp_cost = 15.0
	kick.damage = 45.0
	kick.stun_damage = 30.0
	kick.startup = 0.2
	kick.active_time = 0.15
	kick.recovery = 0.3
	kick.animation = &"Melee_Hook"
	moves["kick"] = kick
	
	# Heavy - uppercut/launcher
	var heavy = move_data_script.new()
	heavy.id = &"heavy"
	heavy.display_name = "Heavy"
	heavy.tier = move_data_script.Tier.MEDIUM
	heavy.mp_cost = 20.0
	heavy.damage = 60.0
	heavy.stun_damage = 40.0
	heavy.startup = 0.25
	heavy.active_time = 0.2
	heavy.recovery = 0.4
	heavy.animation = &"Sword_Attack"
	moves["heavy"] = heavy
	
	# Ultimate - big damage
	var ultimate = move_data_script.new()
	ultimate.id = &"ultimate"
	ultimate.display_name = "Ultimate"
	ultimate.tier = move_data_script.Tier.ULTIMATE
	ultimate.mp_cost = 50.0
	ultimate.damage = 150.0
	ultimate.stun_damage = 80.0
	ultimate.startup = 0.5
	ultimate.active_time = 0.3
	ultimate.recovery = 0.6
	ultimate.animation = &"Sword_Heavy_Combo"
	ultimate.percent_max_hp_damage = 0.2
	moves["ultimate"] = ultimate
	
	# Block - defensive
	var block = move_data_script.new()
	block.id = &"block"
	block.display_name = "Block"
	block.tier = move_data_script.Tier.BASIC
	block.mp_cost = 0.0
	block.damage = 0.0
	block.stun_damage = 0.0
	block.startup = 0.0
	block.active_time = 999.0
	block.recovery = 0.1
	block.animation = &"Idle_Shield_Loop"
	moves["block"] = block
	
	# Dodge - movement
	var dodge = move_data_script.new()
	dodge.id = &"dodge"
	dodge.display_name = "Dodge"
	dodge.tier = move_data_script.Tier.BASIC
	dodge.mp_cost = 10.0
	dodge.damage = 0.0
	dodge.stun_damage = 0.0
	dodge.startup = 0.05
	dodge.active_time = 0.3
	dodge.recovery = 0.2
	dodge.animation = &"Slide_Start"
	dodge.grants_invincibility = true
	moves["dodge"] = dodge

func _setup_fighter(fighter: CharacterBody3D, is_player: bool) -> void:
	var model = fighter.get_node("Model")
	var combat = fighter.get_node("Combat")
	var animator = fighter.get_node("Animator")
	
	# Wait a frame for model to instantiate
	call_deferred("_setup_fighter_deferred", fighter, model, combat, animator, is_player)

func _setup_fighter_deferred(fighter: CharacterBody3D, model: Node3D, combat: Node, animator: Node, is_player: bool) -> void:
	# Find AnimationPlayer in model
	var anim_player = _find_animation_player(model)
	if not anim_player:
		push_error("No AnimationPlayer found in model for " + fighter.name)
		return
	
	print("%s: Found AnimationPlayer with %d animations" % [fighter.name, anim_player.get_animation_list().size()])
	
	# Setup FighterCombat
	if combat:
		var hitbox = TestHitbox.new()
		var hurtbox = TestHurtbox.new()
		fighter.add_child(hitbox)
		fighter.add_child(hurtbox)
		hitbox.name = "Hitbox"
		hurtbox.name = "Hurtbox"
		combat.hitbox = hitbox
		combat.hurtbox = hurtbox
		(hitbox as TestHitbox).target = hurtbox as TestHurtbox
	
	# Setup FighterAnimator
	if animator and anim_player:
		animator.combat = combat
		var anim_tree = AnimationTree.new()
		fighter.add_child(anim_tree)
		anim_tree.anim_player = anim_player
		animator.animation_tree = anim_tree
		animator.body = fighter
		
		# Set animation names (from UAL2 library)
		animator.anim_idle = &"Idle_Loop"
		animator.anim_run = &"Walk_Loop"
		animator.anim_block = &"Idle_Shield_Loop"
		animator.anim_charge = &"Spell_Simple_Idle_Loop"
		animator.anim_stun = &"Hit_Chest"
		animator.anim_knockdown = &"Death01"
		animator.anim_hit_light = &"Hit_Chest"
		animator.anim_hit_heavy = &"Hit_Knockback"

func _connect_fighters() -> void:
	var player_combat = player.get_node("Combat")
	var enemy_combat = enemy.get_node("Combat")
	var player_hitbox = player_combat.hitbox
	var enemy_hitbox = enemy_combat.hitbox
	var player_hurtbox = player_combat.hurtbox
	var enemy_hurtbox = enemy_combat.hurtbox
	
	if player_hitbox and enemy_hurtbox:
		(player_hitbox as TestHitbox).target = enemy_hurtbox as TestHurtbox
	if enemy_hitbox and player_hurtbox:
		(enemy_hitbox as TestHitbox).target = player_hurtbox as TestHurtbox

func _find_animation_player(root: Node) -> AnimationPlayer:
	if root.get_class() == "AnimationPlayer":
		return root as AnimationPlayer
	for child in root.get_children():
		var found = _find_animation_player(child)
		if found:
			return found
	return null

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	
	match event.keycode:
		KEY_1: _try_play(player, "jab")
		KEY_2: _try_play(player, "cross")
		KEY_3: _try_play(player, "kick")
		KEY_4: _try_play(player, "heavy")
		KEY_5: _try_play(player, "ultimate")
		KEY_Q: _toggle_block(player, true)
		KEY_A: _toggle_block(player, false)
		KEY_E: _try_play(player, "dodge")
		KEY_7: _try_play(enemy, "jab")
		KEY_8: _try_play(enemy, "cross")
		KEY_9: _try_play(enemy, "kick")
		KEY_0: _try_play(enemy, "heavy")
		KEY_U: _toggle_block(enemy, true)
		KEY_J: _toggle_block(enemy, false)
		KEY_I: _try_play(enemy, "dodge")
		KEY_R: get_tree().reload_current_scene()

func _try_play(fighter: CharacterBody3D, move_key: String) -> void:
	var combat = fighter.get_node("Combat")
	if combat and moves.has(move_key):
		if not combat.play_move(moves[move_key]):
			print("%s cannot play %s" % [fighter.name, moves[move_key].display_name])

func _toggle_block(fighter: CharacterBody3D, enable: bool) -> void:
	var combat = fighter.get_node("Combat")
	if combat:
		combat.is_blocking = enable
		if enable:
			combat.block_level = 2
		else:
			combat.block_level = 1

func _process(delta: float) -> void:
	# Simple UI
	var player_combat = player.get_node("Combat")
	var enemy_combat = enemy.get_node("Combat")
	if player_combat and enemy_combat:
		print("P: HP=%d MP=%d Stun=%d | E: HP=%d MP=%d Stun=%d" % [
			player_combat.hp, player_combat.mp, player_combat.stun,
			enemy_combat.hp, enemy_combat.mp, enemy_combat.stun
		])