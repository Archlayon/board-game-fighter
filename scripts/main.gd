extends Node3D

const JoystickScript = preload("res://scripts/joystick.gd")
const GamesHubScript = preload("res://scripts/games_hub.gd")
const ComboLabScript = preload("res://scripts/combo_lab.gd")
const StoryCampaignScript = preload("res://scripts/story_campaign.gd")
const MainMenuScript = preload("res://scripts/main_menu.gd")
const FIGHTER_SCENE: PackedScene = preload("res://assets/characters/fighter_ual2.glb")
# New combat system components
const MoveDataScript = preload("res://scripts/move_data.gd")
const FighterCombatScript = preload("res://scripts/fighter_combat.gd")
const DoubleFlickDodgeScript = preload("res://scripts/double_flick_dodge.gd")
# Fighting system components
const FightingInputBufferScript = preload("res://scripts/fighting_system/fighting_input_buffer.gd")
const ComboTrackerScript = preload("res://scripts/fighting_system/combo_tracker.gd")
const FighterStateMachineScript = preload("res://scripts/fighting_system/fighter_state_machine.gd")
const HitStopControllerScript = preload("res://scripts/fighting_system/hit_stop_controller.gd")
const AttackResourceScript = preload("res://scripts/fighting_system/attack_resource.gd")
const DirectHitboxQuery3DScript = preload("res://scripts/fighting_system/direct_hitbox_query_3d.gd")
const BitwiseStateFlagsScript = preload("res://scripts/fighting_system/bitwise_state_flags.gd")
const MoveSetLoaderScript = preload("res://scripts/fighting_system/move_set_loader.gd")
const MAX_HP := 300.0
const NORMAL_DAMAGE_SCALE := 0.75
const MAX_MP := 6.0
const MAX_STUN := 100.0
const PLAYER_SPEED := 5.5

# Simple inline Health component
class SimpleHealth extends Node:
	var current: int = MAX_HP
	var max: int = MAX_HP
	var damageable: bool = true
	var healable: bool = true
	var killable: bool = true
	var revivable: bool = false
	var entity: Node
	var verbose_debug: bool = false
	
	signal damaged(entity, type, amount, incrementer, multiplier, applied)
	signal died(entity)
	signal healed(entity, type, amount, incrementer, multiplier, applied)
	signal revived(entity)
	signal action_applied(action, applied)
	signal first_hit(entity)
	signal not_damageable(entity)
	signal already_dead(entity)
	signal not_killable(entity)
	signal not_healable(entity)
	signal already_full(entity)
	signal not_revivable(entity)
	signal full(entity)
	
	func is_dead() -> bool:
		return current == 0 and killable
	
	func is_alive() -> bool:
		return not is_dead()
	
	func is_full() -> bool:
		return current == max
	
	func percent() -> float:
		return clampf(float(current) / float(max), 0.0, 1.0)
	
	func damage(amount: int, incrementer: int = 0, multiplier: float = 1.0, type: int = 1) -> void:
		if not damageable:
			not_damageable.emit(entity)
			return
		if is_dead():
			already_dead.emit(entity)
			return
		var applied := clampi(roundi((amount + incrementer) * multiplier), 0, current)
		if applied == current and not killable:
			not_killable.emit(entity)
			return
		var is_first_hit := is_full() and applied > 0
		current -= applied
		damaged.emit(entity, type, amount, incrementer, multiplier, applied)
		action_applied.emit(null, applied)
		if is_first_hit:
			first_hit.emit(entity)
		if is_dead():
			died.emit(entity)
	
	func heal(amount: int, incrementer: int = 0, multiplier: float = 1.0, type: int = 1) -> void:
		if not healable:
			not_healable.emit(entity)
			return
		if is_full():
			already_full.emit(entity)
			return
		if is_dead() and not revivable:
			not_revivable.emit(entity)
			return
		var notify_revived := is_dead() and amount > 0
		var applied := clampi(roundi((amount + incrementer) * multiplier), 0, max - current)
		current += applied
		healed.emit(entity, type, amount, incrementer, multiplier, applied)
		action_applied.emit(null, applied)
		if current == max and applied > 0:
			full.emit(entity)
		if notify_revived:
			revived.emit(entity)

# Simple inline HurtBox3D
class SimpleHurtBox3D extends Area3D:
	var health: SimpleHealth = null
	var modifiers: Dictionary = {}
	
	func apply_all_actions(actions: Array) -> void:
		if not health:
			push_error("%s is missing a 'Health' component" % self)
			return
		for action in actions:
			health.call("damage", action.amount, action.incrementer, action.multiplier, action.type)

# Simple inline HitBox3D
class SimpleHitBox3D extends Area3D:
	var ignore_collisions: bool = false
	var actions: Array = []
	signal hurt_box_entered(hurt_box)
	signal action_applied(hurt_box)
	
	func _ready() -> void:
		area_entered.connect(_on_area_entered)
	
	func _on_area_entered(area: Area3D) -> void:
		if ignore_collisions:
			return
		if area is SimpleHitBox3D:
			return
		if area is not SimpleHurtBox3D:
			return
		var hurt_box: SimpleHurtBox3D = area
		hurt_box_entered.emit(hurt_box)
		action_applied.emit(hurt_box)
const WALK_SPEED := 3.0
const ARENA_LIMIT := 9.0
const FIGHTER_CLEARANCE := 1.2
const GRAPPLE_DURATION := 1.6
const GRAPPLE_ESCAPE_THRESHOLD := 1.0
const JUMP_DURATION := 0.9
const JUMP_HEIGHT := 1.25
const AIR_GRAVITY := 18.0
const HP_BAR_DRAIN_DURATION := 1.2
const ULTIMATE_MP_COST := 4.0
const ATTACK_CONTACT_DISTANCE := 1.15
const STRIKE_LUNGE_SPEED := 24.0
const ATTACK_MP_GAIN := 0.75
const MAX_VANISH := 100.0
const VANISH_DODGE_COST := 50.0

# High-speed dash / flash-step
const DASH_SPEED := 42.0
const DASH_DURATION := 0.18
const DASH_COOLDOWN := 0.5
const AIR_DASH_SPEED := 30.0
const SLAM_SPEED := 28.0
const SLAM_SHOCKWAVE_RADIUS := 4.0

var rng := RandomNumberGenerator.new()
var player_data: Dictionary = {}
var opponent_data: Dictionary = {}
var player_style := "Chess"
var opponent_style := "Cards"
var player_level := 1
var player_xp := 0
var wins := 0
var rank_index := 0
var unlocked_ultimates := 1
var story_progress := 0
var player_hp := MAX_HP
var player_mp := 3.0
var player_stun := MAX_STUN
var player_stun_lock := 0.0
var enemy_hp := MAX_HP
var enemy_mp := 3.0
var enemy_stun := MAX_STUN
var enemy_stun_lock := 0.0
var player_vanish := MAX_VANISH
var enemy_vanish := MAX_VANISH
var player_vanish_regen_delay := 0.0
var enemy_vanish_regen_delay := 0.0
var player_powerup_timer := 0.0
var enemy_powerup_timer := 0.0
var player_guard := 0.0
var player_is_blocking := false
var enemy_guard := 0.0
var grapple_holder: Node3D
var grapple_victim: Node3D
var grapple_holder_is_player := false
var grapple_timer := 0.0
var grapple_escape_progress := 0.0
var joystick_vector := Vector2.ZERO
var player_flight_velocity := Vector3.ZERO
var player_ground_velocity := Vector3.ZERO
var mobile_next_strike := "punch"
var mobile_strike_pressed_at := 0
var player_combo := 0
var enemy_combo := 0
var player_recovery := 0.0
var enemy_recovery := 0.0
var stun_lock := 0.0
var ai_clock := 1.0
var mp_clash_cooldown := 0.0
var mp_clash_clock := 0.0
var mp_clash_active := false
var challenge_active := false
var main_menu_open := true
var return_to_menu_after_hub := false
var master_volume := 1.0
var fullscreen_enabled := false

# Dash state
var player_dash_timer := 0.0
var player_dash_cooldown := 0.0
var player_is_dashing := false
var player_dash_direction := Vector3.ZERO
var ai_difficulty := "Normal"
var pause_menu_open := false
var ai_defense_clock := 0.0
var enemy_guard_timer := 0.0
var combo_lab_active := false
var story_mode_active := false
var story_stage_index := 0
var challenge_cost := 0.0
var match_over := false
var is_charging := false
var sprint_enabled := false
var crouch_enabled := false
var flight_enabled := false
var training_mode := false
var enemy_is_training := false
var combo_lab_previous_challenge_state := false
var show_hitboxes := false
var player_character_index := 0
var opponent_character_index := 1
var player_last_punch_limb := "left"
var player_last_kick_limb := "left"
var player_basic_combo_last_action := ""
var player_basic_combo_clock := 0.0
var enemy_last_punch_limb := "left"
var enemy_last_kick_limb := "left"
var player_node: Node3D
var enemy_node: Node3D
var arena_root: Node3D
var camera: Camera3D
var hud: Control
var player_hp_bar: ProgressBar
var player_mp_bar: ProgressBar
var ultimate_button: Button
var player_stun_bar: ProgressBar
var player_ultimate_bar: ProgressBar
var player_vanish_bar: ProgressBar
var enemy_hp_bar: ProgressBar
var enemy_mp_bar: ProgressBar
var enemy_stun_bar: ProgressBar
var enemy_ultimate_bar: ProgressBar
var enemy_vanish_bar: ProgressBar

# Fighting system components
var fighting_input_buffer: Object
var combo_tracker: Object
var hit_stop_controller: Object
var hitbox_query: Object
var player_state_machine: Object
var enemy_state_machine: Object

# New combat system
var player_combat: Object
var enemy_combat: Object
var player_dodge: Object
var enemy_dodge: Object
var hp_bar_tweens: Dictionary = {}
var feedback_label: Label
var training_prompt_label: Label
var player_title_label: Label
var enemy_title_label: Label
var cards_grid: GridContainer
var equipped_grid: GridContainer
var challenge_layer: ColorRect
var clash_button: Button
var training_button: Button
var sprint_button: Button
var crouch_button: Button
var flight_button: Button
var flight_up_button: Button
var flight_down_button: Button
var touch_flight_up := false
var touch_flight_down := false
var enemy_flight_decision_clock := 4.0
var enemy_flight_time_left := 0.0

# 🧠 HYBRID FSM + UTILITY AI BRAIN state
enum AIState { IDLE, DASH, ATTACK, AIR_COMBO, BLOCK, STUN, RETREAT }
var ai_state := AIState.IDLE
var ai_state_timer := 0.0
var ai_decision_timer := 0.0
var games_button: Button
var combo_lab_button: Button
var story_button: Button
var pause_button: Button
var combo_lab: Control
var story_campaign: Control
var games_hub: Control
var main_menu: Control
var character_option: OptionButton
var style_option: OptionButton
var loadout_button: Button
var loadout_dialog: Window
var loadout_option: OptionButton
var loadout_name_input: LineEdit
var loadout_status: Label
var loadout_confirm_dialog: ConfirmationDialog
var loadout_profile_actions: HBoxContainer
var loadout_backup_actions: HBoxContainer
var loadout_profiles: Array[Dictionary] = []
var arena_size := Vector2(1280, 720)
var camera_shake_strength := 0.0
var camera_shake_phase := 0.0
var water_shader_material: ShaderMaterial
var camera_fov_target := 45.0
var camera_fov_current := 45.0

func _ready() -> void:
	# Mobile / low-end device optimizations
	var is_mobile := OS.get_name() == "Android" or OS.get_name() == "iOS"
	Engine.time_scale = 1.0
	if is_mobile:
		ProjectSettings.set_setting("display/window/vsync/vsync_mode", 0)
		ProjectSettings.set_setting("rendering/quality/driver/low_end_device_safemode", true)
		ProjectSettings.set_setting("rendering/quality/default/texture_filter_default_filter", 0)
		ProjectSettings.set_setting("rendering/quality/default/multi_sample", 0)
		_show_feedback("MOBILE MODE · 30 FPS · LOW-END SAFE")

	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	_load_progress()
	_load_settings()
	_load_loadouts()
	_build_world()
	_build_hud()
	_init_fighting_systems()
	_start_match()
	_rebuild_move_cards()
	_open_main_menu()
	get_viewport().size_changed.connect(_on_viewport_resized)

func _play_sfx(sound_name: String, volume_db := -8.0, pitch_variation := 0.0) -> void:
	get_node("/root/GameAudio").call("play_sfx", sound_name, volume_db, pitch_variation)

func _process(delta: float) -> void:
	if main_menu_open or pause_menu_open:
		_handle_debug_input()
		return
	_handle_debug_input()
	_update_fighter_animations(delta)
	_advance_attack_states()
	_update_fighter_state_machines(delta)
	if mp_clash_active:
		mp_clash_clock -= delta
		if mp_clash_clock <= 0.0:
			_resolve_clash(false)
		return
	if combo_lab_active:
		_update_player_movement(delta)
		_update_fighter_facing(delta)
		_update_camera(delta)
		_update_hud()
		return
	if match_over:
		return
	_update_grapple(delta)
	enemy_guard_timer = maxf(0.0, enemy_guard_timer - delta)
	if enemy_guard_timer <= 0.0:
		enemy_guard = 0.0

	mp_clash_cooldown = maxf(0.0, mp_clash_cooldown - delta)
	player_vanish_regen_delay = maxf(0.0, player_vanish_regen_delay - delta)
	enemy_vanish_regen_delay = maxf(0.0, enemy_vanish_regen_delay - delta)
	if player_vanish_regen_delay <= 0.0:
		player_vanish = minf(MAX_VANISH, player_vanish + delta * 18.0)
	if enemy_vanish_regen_delay <= 0.0:
		enemy_vanish = minf(MAX_VANISH, enemy_vanish + delta * 16.0)
	player_powerup_timer = maxf(0.0, player_powerup_timer - delta)
	enemy_powerup_timer = maxf(0.0, enemy_powerup_timer - delta)
	player_basic_combo_clock = maxf(0.0, player_basic_combo_clock - delta)
	if player_basic_combo_clock <= 0.0:
		player_basic_combo_last_action = ""
	player_recovery = maxf(0.0, player_recovery - delta)
	enemy_recovery = maxf(0.0, enemy_recovery - delta)
	stun_lock = maxf(0.0, stun_lock - delta)
	player_stun_lock = maxf(0.0, player_stun_lock - delta)
	enemy_stun_lock = maxf(0.0, enemy_stun_lock - delta)
	if player_stun_lock == 0.0 and player_stun <= 0.0:
		player_stun = MAX_STUN
	if enemy_stun_lock == 0.0 and enemy_stun <= 0.0:
		enemy_stun = MAX_STUN

	if is_charging:
		var charge_rate := 0.72
		if player_character_index == 6:
			charge_rate = 1.05
		player_mp = minf(MAX_MP, player_mp + delta * charge_rate)
		_update_hud()

	_update_player_movement(delta)
	_update_ai(delta)
	_update_fighter_facing(delta)
	_update_camera(delta)
	_update_hud()

func _handle_debug_input() -> void:
	if Input.is_action_just_pressed("ui_debug"):
		show_hitboxes = not show_hitboxes
		_set_hitbox_visibility(show_hitboxes)
		_show_feedback("HITBOX DEBUG: %s" % ("ON" if show_hitboxes else "OFF"))
	if Input.is_action_just_pressed("ui_frame_step"):
		_show_feedback("FRAME STEP NOT IMPLEMENTED")

func _set_hitbox_visibility(visible: bool) -> void:
	for fighter in [player_node, enemy_node]:
		if not is_instance_valid(fighter):
			continue
		var hurtbox_container := fighter.get_node_or_null("Hurtboxes") as Node3D
		if is_instance_valid(hurtbox_container):
			for child in hurtbox_container.get_children():
				if child is BoneAttachment3D:
					var area := child.get_child(0) as Area3D
					if is_instance_valid(area):
						var col := area.get_node_or_null("CollisionShape3D") as CollisionShape3D
						if is_instance_valid(col):
							col.visible = visible
							var dbg := area.get_node_or_null("DebugMesh") as MeshInstance3D
							if not is_instance_valid(dbg) and visible:
								dbg = MeshInstance3D.new()
								dbg.name = "DebugMesh"
								var sphere := SphereMesh.new()
								sphere.radius = (col.shape as SphereShape3D).radius
								dbg.mesh = sphere
								var mat := StandardMaterial3D.new()
								mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
								mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
								mat.albedo_color = Color("#ff4444")
								mat.albedo_color.a = 0.3
								dbg.material_override = mat
								area.add_child(dbg)
							if is_instance_valid(dbg):
								dbg.visible = visible
		var hitbox_container := fighter.get_node_or_null("Hitboxes") as Node3D
		if is_instance_valid(hitbox_container):
			for child in hitbox_container.get_children():
				if child is BoneAttachment3D:
					var area := child.get_child(0) as Area3D
					if is_instance_valid(area):
						var col := area.get_node_or_null("CollisionShape3D") as CollisionShape3D
						if is_instance_valid(col):
							col.visible = visible
							var dbg := area.get_node_or_null("DebugMesh") as MeshInstance3D
							if not is_instance_valid(dbg) and visible:
								dbg = MeshInstance3D.new()
								dbg.name = "DebugMesh"
								var sphere := SphereMesh.new()
								sphere.radius = (col.shape as SphereShape3D).radius
								dbg.mesh = sphere
								var mat := StandardMaterial3D.new()
								mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
								mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
								mat.albedo_color = Color("#44ff44")
								mat.albedo_color.a = 0.3
								dbg.material_override = mat
								area.add_child(dbg)
							if is_instance_valid(dbg):
								dbg.visible = visible

func _pause_fighter_animation(fighter: Node3D, duration: float) -> void:
	var animation_player := fighter.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if not is_instance_valid(animation_player) or is_zero_approx(animation_player.speed_scale):
		return
	var generation := int(fighter.get_meta("action_generation", 0))
	var previous_speed := animation_player.speed_scale
	animation_player.speed_scale = 0.0
	get_tree().create_timer(duration, true, false, true).timeout.connect(
		_resume_fighter_animation.bind(fighter, generation, previous_speed),
		CONNECT_ONE_SHOT
	)

func _resume_fighter_animation(fighter: Node3D, generation: int, previous_speed: float) -> void:
	if not is_instance_valid(fighter) or int(fighter.get_meta("action_generation", -1)) != generation:
		return
	var animation_player := fighter.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if is_instance_valid(animation_player) and is_zero_approx(animation_player.speed_scale):
		animation_player.speed_scale = previous_speed

func _spawn_impact_flash(position: Vector3, accent: Color, blocked: bool) -> void:
	var flash := Node3D.new()
	flash.name = "ImpactFlash"
	arena_root.add_child(flash)
	flash.global_position = position + Vector3.UP * 1.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color("#fff6d8") if blocked else accent
	material.emission_enabled = true
	material.emission = Color("#fff6d8") if blocked else accent
	material.emission_energy_multiplier = 3.0
	var flash_color := material.albedo_color
	var streak_count := 3 if blocked else 5
	for index in range(streak_count):
		var streak := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.055, 0.055, 0.48 if not blocked else 0.34)
		streak.mesh = mesh
		streak.rotation.z = PI * float(index) / float(streak_count)
		streak.material_override = material
		streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flash.add_child(streak)
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.12
	core_mesh.height = 0.24
	core.mesh = core_mesh
	core.material_override = material
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.add_child(core)
	var light := OmniLight3D.new()
	light.light_color = flash_color
	light.light_energy = 1.6 if not blocked else 0.8
	light.omni_range = 2.4
	light.shadow_enabled = false
	flash.add_child(light)
	flash.scale = Vector3.ONE * 0.35
	var effect := create_tween()
	effect.set_parallel()
	effect.tween_property(flash, "scale", Vector3.ONE * 1.35, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	effect.tween_property(material, "albedo_color:a", 0.0, 0.14)
	effect.tween_property(light, "light_energy", 0.0, 0.14)
	effect.chain().tween_callback(flash.queue_free)

func _spawn_damage_number(target: Node3D, damage: float, is_counter: bool, blocked: bool) -> void:
	var label := Label3D.new()
	label.name = "DamageNumber"
	label.text = str(int(damage))
	label.font_size = 28
	label.outline_size = 4
	if is_counter:
		label.modulate = Color("#ffd700")
	elif blocked:
		label.modulate = Color("#88ccff")
	else:
		label.modulate = Color("#ff6b4a")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(rng.randf_range(-0.2, 0.2), 2.5 + rng.randf_range(0.0, 0.3), rng.randf_range(-0.2, 0.2))
	target.add_child(label)
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(label, "position:y", label.position.y + 1.2, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(label.queue_free)

func _spawn_hit_particles(position: Vector3, accent: Color, blocked: bool, is_counter: bool) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "HitParticles"
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 12 if blocked else (20 if is_counter else 15)
	particles.lifetime = 0.5
	particles.explosiveness = 1.0
	particles.local_coords = false
	var pmat := ParticleProcessMaterial.new()
	pmat.gravity = Vector3(0.0, -2.0, 0.0)
	pmat.initial_velocity_min = 2.0
	pmat.initial_velocity_max = 4.0
	pmat.spread = 144.0
	pmat.scale_min = 0.2
	pmat.scale_max = 0.4
	particles.process_material = pmat
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.08, 0.08, 0.08)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color("#fff6d8") if blocked else (Color("#ffd700") if is_counter else accent)
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 2.0
	mesh.material = material
	particles.draw_pass_1 = mesh
	arena_root.add_child(particles)
	particles.global_position = position
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free.bind(), CONNECT_ONE_SHOT)

# ⚡ LIGHTNING EFFECT (7 steps: squiggle, jagged shape, thickness variation, glow layers, accents, final zap)
func _spawn_lightning_bolt(source_pos: Vector3, target_pos: Vector3, color: Color, segment_count: int = 8, duration: float = 0.18) -> void:
	var bolt := Node3D.new()
	bolt.name = "LightningBolt"
	arena_root.add_child(bolt)
	bolt.global_position = source_pos

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 4.0

	var current := source_pos
	var direction := (target_pos - source_pos).normalized()
	var total_distance := source_pos.distance_to(target_pos)
	var segment_len := total_distance / float(segment_count)

	for i in range(segment_count):
		var jitter := Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25))
		var next_pos := current + direction * segment_len + jitter
		if i == segment_count - 1:
			next_pos = target_pos

		var seg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = rng.randf_range(0.03, 0.08)
		cyl.bottom_radius = rng.randf_range(0.03, 0.08)
		cyl.height = current.distance_to(next_pos)
		seg.mesh = cyl
		seg.material_override = material

		var seg_dir := (next_pos - current).normalized()
		var up := Vector3.UP
		if absf(seg_dir.dot(up)) > 0.99:
			up = Vector3.RIGHT
		seg.look_at(next_pos, up)
		seg.translate(Vector3(0.0, -cyl.height * 0.5, 0.0))
		bolt.add_child(seg)

		current = next_pos

	# Core bright white line down the center
	var core := MeshInstance3D.new()
	var core_cyl := CylinderMesh.new()
	core_cyl.top_radius = 0.02
	core_cyl.bottom_radius = 0.02
	core_cyl.height = total_distance
	core.mesh = core_cyl
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color("#ffffff")
	core_mat.emission_enabled = true
	core_mat.emission = Color("#ffffff")
	core_mat.emission_energy_multiplier = 6.0
	core.material_override = core_mat
	core.look_at(target_pos, Vector3.UP)
	core.translate(Vector3(0.0, -total_distance * 0.5, 0.0))
	bolt.add_child(core)

	# Glow light
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 6.0
	light.omni_range = 3.0
	light.shadow_enabled = false
	bolt.add_child(light)

	# Animate: flicker then fade
	var tween := create_tween()
	tween.tween_property(material, "emission_energy_multiplier", 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(core_mat, "emission_energy_multiplier", 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(light, "light_energy", 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(bolt.queue_free)

# 💥 ANIME BURST LINES (comic-style impact lines radiating from hit point)
func _spawn_anime_burst_lines(position: Vector3, color: Color, line_count: int = 12, duration: float = 0.25) -> void:
	var lines := Node3D.new()
	lines.name = "AnimeBurstLines"
	arena_root.add_child(lines)
	lines.global_position = position

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.5

	for i in range(line_count):
		var angle := TAU * float(i) / float(line_count)
		var dir := Vector3(sin(angle), 0.0, cos(angle))
		var seg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.02
		cyl.bottom_radius = 0.0
		cyl.height = rng.randf_range(0.6, 1.2)
		seg.mesh = cyl
		seg.material_override = material
		seg.look_at(position + dir * cyl.height, Vector3.UP)
		seg.translate(Vector3(0.0, -cyl.height * 0.5, 0.0))
		lines.add_child(seg)

	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 4.0
	light.omni_range = 3.0
	light.shadow_enabled = false
	lines.add_child(light)

	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(material, "albedo_color:a", 0.0, duration)
	tween.tween_property(material, "emission_energy_multiplier", 0.0, duration)
	tween.tween_property(light, "light_energy", 0.0, duration)
	tween.chain().tween_callback(lines.queue_free)

# 📹 ANIME CAMERA PUNCH-IN (rapid FOV snap on heavy/counter hits)
func _trigger_camera_punch_in(hit_position: Vector3, strength: float = 0.35, duration: float = 0.12) -> void:
	var cam := get_viewport().get_camera_3d()
	if not is_instance_valid(cam):
		return
	var original_fov := cam.fov
	cam.fov = clampf(original_fov - strength * 30.0, 20.0, 90.0)

	var target_pos := cam.global_position.lerp(hit_position, 0.35)
	var tween := create_tween()
	tween.tween_property(cam, "fov", original_fov, duration * 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(cam, "global_position", target_pos, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# 🎭 NEGATIVE / SILHOUETTE FLASH (screen invert for heavy/counter hits)
var _negative_flash_active := false
func _trigger_negative_flash(duration: float = 0.06) -> void:
	if _negative_flash_active:
		return
	_negative_flash_active = true
	var invert := ColorRect.new()
	invert.name = "NegativeFlash"
	invert.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	invert.modulate = Color(1.0, 1.0, 1.0, 0.0)
	invert.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if is_instance_valid(hud):
		hud.add_child(invert)
	else:
		get_tree().get_root().add_child(invert)
	var tween := create_tween()
	tween.tween_property(invert, "modulate:a", 0.0, duration * 0.5).set_trans(Tween.TRANS_LINEAR)
	tween.chained().tween_callback(func(): _negative_flash_active = false)
	tween.chain().tween_callback(invert.queue_free)

# 🗡️ FULL ANIME HIT SEQUENCE (hit-stop + burst lines + camera punch-in + negative flash)
func _trigger_anime_hit(hit_position: Vector3, accent: Color, is_heavy: bool = false, is_counter: bool = false) -> void:
	_spawn_anime_burst_lines(hit_position, accent, 14 if is_heavy else 10, 0.2 if is_heavy else 0.15)
	_trigger_camera_punch_in(hit_position, 0.4 if is_heavy else 0.25, 0.1 if is_heavy else 0.08)
	if is_counter or is_heavy:
		_trigger_negative_flash(0.05 if is_counter else 0.04)

# 🎨 ANIME SILHOUETTE (high-contrast black base for heavy hits)
func _trigger_silhouette_flash(target: Node3D, duration: float = 0.06) -> void:
	var mesh: MeshInstance3D
	for child in target.get_children():
		if child is MeshInstance3D:
			mesh = child as MeshInstance3D
			break
	if not is_instance_valid(mesh):
		return
	var original_mat := mesh.material_override
	var silhouette := StandardMaterial3D.new()
	silhouette.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	silhouette.albedo_color = Color("#000000")
	silhouette.emission_enabled = false
	mesh.material_override = silhouette
	var tween := create_tween()
	tween.tween_property(mesh, "material_override", original_mat, duration).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func(): mesh.material_override = original_mat)

# 🩸 BLOOD SPLATTER (particles on hit)
func _spawn_blood_splatter(position: Vector3, count: int = 8) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "BloodSplatter"
	particles.emitting = true
	particles.one_shot = true
	particles.amount = count
	particles.lifetime = 0.8
	particles.explosiveness = 1.0
	particles.local_coords = false
	var pmat := ParticleProcessMaterial.new()
	pmat.gravity = Vector3(0.0, -9.8, 0.0)
	pmat.initial_velocity_min = 3.0
	pmat.initial_velocity_max = 6.0
	pmat.spread = 90.0
	pmat.scale_min = 0.05
	pmat.scale_max = 0.15
	particles.process_material = pmat
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color("#4a0000")
	material.emission_enabled = true
	material.emission = Color("#4a0000")
	material.emission_energy_multiplier = 2.0
	mesh.material = material
	particles.draw_pass_1 = mesh
	arena_root.add_child(particles)
	particles.global_position = position
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free.bind(), CONNECT_ONE_SHOT)

# 🔴 SHELL CASINGS (leave debris on floor)
func _spawn_shell_casing(position: Vector3, direction: Vector3, count: int = 2) -> void:
	for i in range(count):
		var shell := MeshInstance3D.new()
		shell.name = "ShellCasing"
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.025
		cyl.bottom_radius = 0.025
		cyl.height = 0.05
		shell.mesh = cyl
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("#d4af37")
		shell.material_override = material
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arena_root.add_child(shell)
		var jitter := Vector3(rng.randf_range(-0.3, 0.3), 0.5, rng.randf_range(-0.3, 0.3))
		shell.global_position = position + jitter
		shell.rotate_object_local(Vector3.RIGHT, rng.randf_range(0.0, TAU))
		var slide := direction * rng.randf_range(0.3, 0.8)
		var tween := create_tween()
		tween.tween_property(shell, "global_position", position + jitter + slide, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		get_tree().create_timer(5.0).timeout.connect(shell.queue_free.bind(), CONNECT_ONE_SHOT)

# 💀 KILL / FINAL BLOW SEQUENCE (extended freeze, throw body backward, ash burn)
func _trigger_kill_sequence(target: Node3D, source: Node3D, push_direction: Vector3, accent: Color) -> void:
	# Extended hit-stop
	if hit_stop_controller:
		hit_stop_controller.apply_hit_stop(0.25)
	# Throw body backward hard
	var throw_tween := create_tween()
	throw_tween.set_parallel()
	throw_tween.tween_property(target, "global_position", target.global_position + push_direction * 3.0 + Vector3.UP * 1.5, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	throw_tween.tween_property(target, "scale", Vector3(0.95, 1.15, 0.95), 0.12)
	throw_tween.chain().tween_property(target, "scale", Vector3(0.7, 0.7, 0.7), 0.3)
	# Ash burn effect at target position
	_spawn_ash_burn(target.global_position, accent)
	# Silhouette flash on killer
	_trigger_silhouette_flash(source, 0.04)

# 🔥 ASH BURN (disintegration effect on defeat)
func _spawn_ash_burn(position: Vector3, color: Color) -> void:
	var burn := Node3D.new()
	burn.name = "AshBurn"
	arena_root.add_child(burn)
	burn.global_position = position
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	var ring := MeshInstance3D.new()
	var ring_mesh := CapsuleMesh.new()
	ring_mesh.radius = 0.5
	ring_mesh.height = 0.02
	ring.mesh = ring_mesh
	ring.material_override = material
	ring.rotation.x = PI / 2.0
	burn.add_child(ring)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 4.0
	light.omni_range = 2.5
	light.shadow_enabled = false
	burn.add_child(light)
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(material, "albedo_color:a", 0.0, 1.2)
	tween.tween_property(material, "emission_energy_multiplier", 0.0, 1.2)
	tween.tween_property(light, "light_energy", 0.0, 1.2)
	tween.chain().tween_callback(burn.queue_free)

# 💥 ULTIMATE 1: MEGA ENERGY BEAM (Kamehameha / Finisher)
# Charge aura -> beam release -> shockwave rings -> scorched ground mark
func _trigger_mega_beam(source: Node3D, target: Node3D, move: Dictionary, accent: Color) -> void:
	var start_pos := source.global_position + Vector3.UP * 1.2
	var direction := (target.global_position - start_pos).normalized()
	var beam_range := float(move.get("projectile_range", 12.0))
	var end_pos := start_pos + direction * beam_range

	# Charge wind-up: inward-converging energy wisps
	var charge := Node3D.new()
	charge.name = "BeamCharge"
	arena_root.add_child(charge)
	charge.global_position = start_pos
	var cmat := StandardMaterial3D.new()
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cmat.albedo_color = accent
	cmat.emission_enabled = true
	cmat.emission = accent
	cmat.emission_energy_multiplier = 5.0
	var sphere := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.5
	sphere.mesh = sph
	sphere.material_override = cmat
	charge.add_child(sphere)
	var clight := OmniLight3D.new()
	clight.light_color = accent
	clight.light_energy = 6.0
	clight.omni_range = 3.0
	clight.shadow_enabled = false
	charge.add_child(clight)
	var ctween := create_tween()
	ctween.tween_property(sphere, "scale", Vector3.ZERO, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	ctween.chain().tween_callback(charge.queue_free)

	# Camera zoom-in on character core during charge
	_trigger_camera_punch_in(start_pos, 0.5, 0.5)

	# Beam release after wind-up
	get_tree().create_timer(0.5).timeout.connect(func():
		_spawn_mega_beam_bolt(start_pos, end_pos, direction, beam_range, accent, move, source, target)
	, CONNECT_ONE_SHOT)

func _spawn_mega_beam_bolt(start_pos: Vector3, end_pos: Vector3, direction: Vector3, beam_range: float, color: Color, move: Dictionary, source: Node3D, target: Node3D) -> void:
	var beam := Node3D.new()
	beam.name = "MegaBeam"
	arena_root.add_child(beam)
	beam.global_position = start_pos

	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.albedo_color = color
	beam_mat.emission_enabled = true
	beam_mat.emission = color
	beam_mat.emission_energy_multiplier = 6.0

	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 0.6
	cyl.height = start_pos.distance_to(end_pos)
	var beam_mesh := MeshInstance3D.new()
	beam_mesh.mesh = cyl
	beam_mesh.material_override = beam_mat
	beam_mesh.look_at(end_pos, Vector3.UP)
	beam_mesh.translate(Vector3(0.0, -cyl.height * 0.5, 0.0))
	beam.add_child(beam_mesh)

	var inner := MeshInstance3D.new()
	var inner_cyl := CylinderMesh.new()
	inner_cyl.top_radius = 0.25
	inner_cyl.bottom_radius = 0.25
	inner_cyl.height = start_pos.distance_to(end_pos)
	var inner_mesh := MeshInstance3D.new()
	inner_mesh.mesh = inner_cyl
	var imat := StandardMaterial3D.new()
	imat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	imat.albedo_color = Color("#ffffff")
	imat.emission_enabled = true
	imat.emission = Color("#ffffff")
	imat.emission_energy_multiplier = 8.0
	inner_mesh.material_override = imat
	inner_mesh.look_at(end_pos, Vector3.UP)
	inner_mesh.translate(Vector3(0.0, -inner_cyl.height * 0.5, 0.0))
	beam.add_child(inner_mesh)

	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 8.0
	light.omni_range = 4.0
	light.shadow_enabled = false
	beam.add_child(light)

	# Lens flare flash on launch
	var flare := ColorRect.new()
	flare.name = "BeamFlare"
	flare.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flare.modulate = Color(1.0, 1.0, 1.0, 0.0)
	if is_instance_valid(hud):
		hud.add_child(flare)
	else:
		get_tree().get_root().add_child(flare)
	var ftween := create_tween()
	ftween.tween_property(flare, "modulate:a", 1.0, 0.05)
	ftween.chain().tween_property(flare, "modulate:a", 0.0, 0.1)
	ftween.chain().tween_callback(flare.queue_free)

	# Continuous damage tick along beam path
	var damage := float(move.get("damage", MAX_HP * 0.12))
	var stun_dmg := float(move.get("stun", 25))
	var is_player := source == player_node
	var target_was_guarding := bool(source.get_meta("attack_state", {}).get("target_was_guarding", false))
	var tick_time := 0.0
	var beam_duration := 1.2

	var beam_tween := create_tween()
	beam_tween.tween_property(beam_mat, "emission_energy_multiplier", 0.0, beam_duration)
	beam_tween.tween_property(imat, "emission_energy_multiplier", 0.0, beam_duration)
	beam_tween.tween_property(light, "light_energy", 0.0, beam_duration)

	# Damage tick every 0.15s during beam
	var tick_conn := get_tree().create_timer(0.15, true, false, true)
	var tick_count := 0
	var beam_tick_func := func():
		tick_count += 1
		if tick_count > beam_duration / 0.15:
			return
		# Raycast along beam for damage
		var space_state := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.new()
		query.from = start_pos
		query.to = end_pos
		query.collide_with_areas = true
		query.collide_with_bodies = true
		var result := space_state.intersect_ray(query)
		if result.has("collider"):
			var col := result["collider"] as Node3D
			if col is Node3D and col == target and is_instance_valid(target):
				_resolve_attack_impact(source, target, move, target_was_guarding, damage * 0.3, stun_dmg * 0.3, is_player, "ultimate", color, start_pos)
		# Shockwave rings along beam path
		var ring_pos := start_pos + direction * (tick_count * 1.5)
		if ring_pos.distance_to(start_pos) < beam_range:
			_spawn_shockwave_ring(ring_pos, color)
	tick_conn.timeout.connect(beam_tick_func, CONNECT_ONE_SHOT)

	# Scorched ground mark after beam ends
	var scorch_func := func():
		_spawn_scorch_mark(start_pos, end_pos, color)
		beam.queue_free()
	get_tree().create_timer(beam_duration).timeout.connect(scorch_func, CONNECT_ONE_SHOT)

# ⚡ ULTIMATE 2: DARK VOID / LIGHTNING SINGULARITY (AOE Vortex)
# Rune emblem -> shockwave ring -> black hole sphere -> vortex pull + lightning arcs -> AOE ticks -> final burst
func _trigger_void_vortex(source: Node3D, target: Node3D, move: Dictionary, accent: Color) -> void:
	var center := target.global_position
	center.y = 0.0

	# Rune emblem on floor
	var rune := MeshInstance3D.new()
	rune.name = "VoidRune"
	arena_root.add_child(rune)
	rune.global_position = center
	var rune_mesh := CapsuleMesh.new()
	rune_mesh.radius = 1.2
	rune_mesh.height = 0.05
	rune.mesh = rune_mesh
	var rune_mat := StandardMaterial3D.new()
	rune_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rune_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rune_mat.albedo_color = accent
	rune_mat.emission_enabled = true
	rune_mat.emission = accent
	rune_mat.emission_energy_multiplier = 3.0
	rune.material_override = rune_mat
	rune.rotation.x = PI / 2.0

	# Expanding shockwave ring
	_spawn_shockwave_ring(center, accent, 3.0, 0.6)

	# Black hole sphere
	var sphere := Node3D.new()
	sphere.name = "BlackHole"
	arena_root.add_child(sphere)
	sphere.global_position = center + Vector3.UP * 1.0
	var bh_mat := StandardMaterial3D.new()
	bh_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bh_mat.albedo_color = Color("#0a0a1a")
	bh_mat.emission_enabled = true
	bh_mat.emission = accent
	bh_mat.emission_energy_multiplier = 4.0
	var bh_mesh := MeshInstance3D.new()
	var bh := SphereMesh.new()
	bh.radius = 0.1
	bh_mesh.mesh = bh
	bh_mesh.material_override = bh_mat
	sphere.add_child(bh_mesh)
	var blight := OmniLight3D.new()
	blight.light_color = accent
	blight.light_energy = 5.0
	blight.omni_range = 3.0
	blight.shadow_enabled = false
	sphere.add_child(blight)

	var grow := create_tween()
	grow.tween_property(bh, "scale", Vector3.ONE * 2.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	grow.chain().tween_callback(func():
		# Vortex pull + lightning arcs for duration
		var pull_time := 0.0
		var pull_conn := get_tree().create_timer(0.1, true, false, true)
		var damage_applied := []
		var pull_func := func():
			pull_time += 0.1
			if pull_time > 2.0:
				return
			# Pull nearby enemies
			var space_state := get_world_3d().direct_space_state
			var query := PhysicsShapeQueryParameters3D.new()
			var shape := SphereShape3D.new()
			shape.radius = 3.0
			query.shape = shape
			query.transform = Transform3D(Transform3D.IDENTITY.basis, center + Vector3.UP * 1.0)
			query.collide_with_areas = true
			query.collide_with_bodies = true
			var results := space_state.intersect_shape(query)
			for res in results:
				var col := res["collider"] as Node3D
				if col is Node3D and col != source and is_instance_valid(col):
					var dir := (center - col.global_position).normalized()
					var dist := center.distance_to(col.global_position)
					if dist > 0.1 and dist < 3.0:
						var pull_force := dir * (8.0 / maxf(dist, 0.5))
						if col == target or col == player_node or col == enemy_node:
							var move_tween := create_tween()
							move_tween.tween_property(col, "global_position", col.global_position + pull_force * 0.1, 0.1)
						# Lightning arcs on perimeter
						if rng.randf() < 0.3:
							_spawn_lightning_bolt(center + Vector3.UP * 1.0, col.global_position, accent, 6, 0.15)
			# AOE damage tick every 0.2s
			if fposmod(pull_time * 10.0, 2.0) == 0.0:
				var dmg := float(move.get("damage", 20)) * 0.5
				var stun_d := float(move.get("stun", 15)) * 0.5
				var is_player := source == player_node
				var twg := bool(source.get_meta("attack_state", {}).get("target_was_guarding", false))
				_resolve_attack_impact(source, target, move, twg, dmg, stun_d, is_player, "ultimate", accent, center)
		pull_conn.timeout.connect(pull_func, CONNECT_ONE_SHOT)
		# Final collapse burst
		var collapse_func := func():
			_spawn_impact_flash(center, accent, false)
			_trigger_anime_hit(center, accent, true, false)
			rune.queue_free()
			sphere.queue_free()
		get_tree().create_timer(2.2).timeout.connect(collapse_func, CONNECT_ONE_SHOT)
	)

# ⚙️ ULTIMATE 3: CELESTIAL CLOCKWORK LIGHT PILLAR (Holy / Chrono Strike)
# Clockwork glyph -> golden pillar drop -> spark burst + rotating gears -> knockup -> fading aftermath
func _trigger_clockwork_pillar(source: Node3D, target: Node3D, move: Dictionary, accent: Color) -> void:
	var center := target.global_position
	center.y = 0.0

	# Clockwork floor glyph (rotating gears)
	var glyph := MeshInstance3D.new()
	glyph.name = "ClockworkGlyph"
	arena_root.add_child(glyph)
	glyph.global_position = center
	var glyph_mesh := CapsuleMesh.new()
	glyph_mesh.radius = 2.0
	glyph_mesh.height = 0.04
	glyph.mesh = glyph_mesh
	var glyph_mat := StandardMaterial3D.new()
	glyph_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glyph_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glyph_mat.albedo_color = Color("#ffd700")
	glyph_mat.emission_enabled = true
	glyph_mat.emission = Color("#ffd700")
	glyph_mat.emission_energy_multiplier = 2.0
	glyph.material_override = glyph_mat
	glyph.rotation.x = PI / 2.0

	# Rotating inner rings
	var ring1 := MeshInstance3D.new()
	var ring_mesh1 := CapsuleMesh.new()
	ring_mesh1.radius = 1.4
	ring_mesh1.height = 0.02
	ring1.mesh = ring_mesh1
	ring1.material_override = glyph_mat
	ring1.rotation.x = PI / 2.0
	glyph.add_child(ring1)
	var ring2 := MeshInstance3D.new()
	var ring_mesh2 := CapsuleMesh.new()
	ring_mesh2.radius = 0.8
	ring_mesh2.height = 0.02
	ring2.mesh = ring_mesh2
	ring2.material_override = glyph_mat
	ring2.rotation.x = PI / 2.0
	glyph.add_child(ring2)
	var gtween := create_tween()
	gtween.set_loops(0)
	gtween.tween_property(ring1, "rotation_degrees", Vector3(0, 0, 360), 2.0)
	gtween.tween_property(ring2, "rotation_degrees", Vector3(0, 0, -360), 1.5)

	# Pillar drop from high altitude
	var pillar_start := center + Vector3.UP * 15.0
	var pillar := MeshInstance3D.new()
	pillar.name = "LightPillar"
	arena_root.add_child(pillar)
	pillar.global_position = pillar_start
	var pillar_mesh := CylinderMesh.new()
	pillar_mesh.top_radius = 1.0
	pillar_mesh.bottom_radius = 1.0
	pillar_mesh.height = 0.5
	pillar.mesh = pillar_mesh
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = Color("#ffffff")
	pmat.emission_enabled = true
	pmat.emission = Color("#ffffff")
	pmat.emission_energy_multiplier = 8.0
	pillar.material_override = pmat
	var plight := OmniLight3D.new()
	plight.light_color = Color("#ffffff")
	plight.light_energy = 6.0
	plight.omni_range = 4.0
	plight.shadow_enabled = false
	pillar.add_child(plight)

	# Spark burst at impact
	get_tree().create_timer(0.8).timeout.connect(func():
		_spawn_impact_flash(center, accent, false)
		_spawn_hit_particles(center, accent, false, true)
		_trigger_anime_hit(center, accent, true, false)
		# Knockup all targets in ring
		var space_state := get_world_3d().direct_space_state
		var query := PhysicsShapeQueryParameters3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 2.0
		query.shape = shape
		query.transform = Transform3D(Transform3D.IDENTITY.basis, center + Vector3.UP * 1.0)
		query.collide_with_bodies = true
		var results := space_state.intersect_shape(query)
		for res in results:
			var col := res["collider"] as Node3D
			if col is Node3D and (col == target or col == player_node or col == enemy_node) and col != source:
				var launch := create_tween()
				launch.tween_property(col, "global_position", col.global_position + Vector3.UP * 6.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				col.set_meta("airborne", true)
				col.set_meta("launch_velocity", 10.0)
				col.set_meta("air_duration", 1.8)
		# Damage
		var is_player := source == player_node
		var twg := bool(source.get_meta("attack_state", {}).get("target_was_guarding", false))
		_resolve_attack_impact(source, target, move, twg, float(move.get("damage", 26)), float(move.get("stun", 20)), is_player, "ultimate", accent, center)
	, CONNECT_ONE_SHOT)

	# Pillar descends
	var fall := create_tween()
	fall.tween_property(pillar, "global_position", center + Vector3.UP * 1.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.chain().tween_property(pillar, "scale", Vector3.ONE * 1.5, 0.2)
	fall.chain().tween_property(pmat, "emission_energy_multiplier", 0.0, 1.0)
	fall.chain().tween_callback(pillar.queue_free)

	# Glyph fades slowly
	get_tree().create_timer(2.0).timeout.connect(func():
		var ft := create_tween()
		ft.tween_property(glyph_mat, "emission_energy_multiplier", 0.0, 1.5)
		ft.chain().tween_callback(glyph.queue_free)
	, CONNECT_ONE_SHOT)

# 🌋 ULTIMATE 4: GROUND FISSURE LINE & ERUPTION (Dark / Fire Slash)
# Raycast ground -> sequential explosions along line -> crack decals + directional knockback
func _trigger_fissure_eruption(source: Node3D, target: Node3D, move: Dictionary, accent: Color) -> void:
	var start := source.global_position
	start.y = 0.0
	var direction := (target.global_position - start).normalized()
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		direction = -source.global_basis.z
	var line_length := 8.0
	var segment_count := 6
	var segment_len := line_length / float(segment_count)

	for i in range(segment_count):
		var seg_start := start + direction * (segment_len * float(i))
		var seg_end := start + direction * (segment_len * float(i + 1))
		var delay := float(i) * 0.06
		get_tree().create_timer(delay).timeout.connect(func(s: Vector3, e: Vector3):
			# Raycast down to ground
			var space_state := get_world_3d().direct_space_state
			var query := PhysicsRayQueryParameters3D.new()
			query.from = s + Vector3.UP * 2.0
			query.to = s - Vector3.UP * 2.0
			query.collide_with_bodies = true
			var result := space_state.intersect_ray(query)
			var ground_y := s.y
			if result.has("collider"):
				ground_y = result["position"].y
			var crack_pos := Vector3(s.x, ground_y + 0.01, s.z)
			# Ground crack decal
			_spawn_ground_crack(crack_pos, accent, segment_len)
			# Upward explosion
			_spawn_fissure_explosion(crack_pos, accent)
			# Damage Area3D along segment
			var dmg_area := Area3D.new()
			var col_shape := SphereShape3D.new()
			col_shape.radius = segment_len * 0.6
			var col := CollisionShape3D.new()
			col.shape = col_shape
			dmg_area.add_child(col)
			dmg_area.global_position = crack_pos
			arena_root.add_child(dmg_area)
			get_tree().create_timer(0.3).timeout.connect(func():
				var overlap_query := PhysicsShapeQueryParameters3D.new()
				overlap_query.shape = col_shape
				overlap_query.transform = Transform3D(Transform3D.IDENTITY.basis, crack_pos)
				overlap_query.collide_with_bodies = true
				var results := space_state.intersect_shape(overlap_query)
				# Apply knockback away from line
				var is_player := source == player_node
				var twg := bool(source.get_meta("attack_state", {}).get("target_was_guarding", false))
				_resolve_attack_impact(source, target, move, twg, float(move.get("damage", 22)) * 0.6, float(move.get("stun", 16)) * 0.6, is_player, "ultimate", accent, crack_pos)
				dmg_area.queue_free()
			, CONNECT_ONE_SHOT)
		, CONNECT_ONE_SHOT)

	# Directional knockback push away from line
	var push_dir := direction
	get_tree().create_timer(0.4).timeout.connect(func():
		var tween := create_tween()
		tween.tween_property(target, "global_position", target.global_position + push_dir * 4.0 + Vector3.UP * 2.0, 0.4)
		target.set_meta("airborne", true)
		target.set_meta("launch_velocity", 6.0)
		target.set_meta("air_duration", 1.2)
	, CONNECT_ONE_SHOT)

# 🔥 GROUND CRACK DECAL
func _spawn_ground_crack(position: Vector3, color: Color, width: float) -> void:
	var crack := MeshInstance3D.new()
	crack.name = "GroundCrack"
	arena_root.add_child(crack)
	crack.global_position = position
	var plane := PlaneMesh.new()
	plane.size = Vector2(width, 0.4)
	crack.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	crack.material_override = mat
	crack.rotation.x = PI / 2.0
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 3.0)
	tween.chain().tween_callback(crack.queue_free)

# 💥 FISSURE EXPLOSION
func _spawn_fissure_explosion(position: Vector3, color: Color) -> void:
	var exp := Node3D.new()
	exp.name = "FissureExplosion"
	arena_root.add_child(exp)
	exp.global_position = position + Vector3.UP * 0.5
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 5.0
	var sphere := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.3
	sphere.mesh = sph
	sphere.material_override = mat
	exp.add_child(sphere)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 6.0
	light.omni_range = 3.0
	light.shadow_enabled = false
	exp.add_child(light)
	var tween := create_tween()
	tween.tween_property(sphere, "scale", Vector3.ONE * 2.5, 0.3)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tween.tween_property(light, "light_energy", 0.0, 0.3)
	tween.chain().tween_callback(exp.queue_free)

# 🎵 ULTIMATE 5: SONIC DOMAIN / MUSICAL BARRIER (Rhythm / Sound Field)
# Central orb -> expanding dome -> rhythmic ripples + musical notes -> sustained field with status ticks
var _sonic_domains := []
func _trigger_sonic_domain(source: Node3D, target: Node3D, move: Dictionary, accent: Color) -> void:
	var center := target.global_position
	center.y = 0.0

	# Central hovering orb
	var orb := Node3D.new()
	orb.name = "SonicOrb"
	arena_root.add_child(orb)
	orb.global_position = center + Vector3.UP * 2.0
	var omat := StandardMaterial3D.new()
	omat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	omat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	omat.albedo_color = accent
	omat.emission_enabled = true
	omat.emission = accent
	omat.emission_energy_multiplier = 4.0
	var osphere := MeshInstance3D.new()
	var osph := SphereMesh.new()
	osph.radius = 0.3
	osphere.mesh = osph
	osphere.material_override = omat
	orb.add_child(osphere)

	# Expanding dome
	var dome := MeshInstance3D.new()
	dome.name = "SonicDome"
	arena_root.add_child(dome)
	dome.global_position = center + Vector3.UP * 0.5
	var dmesh := SphereMesh.new()
	dmesh.radius = 0.1
	dmesh.height = 0.1
	dome.mesh = dmesh
	var dmat := StandardMaterial3D.new()
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.albedo_color = Color(accent.r, accent.g, accent.b, 0.4)
	dmat.emission_enabled = true
	dmat.emission = accent
	dmat.emission_energy_multiplier = 2.0
	dome.material_override = dmat

	var duration := float(move.get("duration", 4.0))
	var max_radius := 5.0

	var dtween := create_tween()
	dtween.tween_property(dome, "scale", Vector3.ONE * max_radius, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	dtween.chained().tween_callback(func():
		# Sustained field: periodic status ticks
		var tick_time := 0.0
		var tick_conn := get_tree().create_timer(0.5, true, false, true)
		var domain_data := {"dome": dome, "orb": orb, "center": center, "radius": max_radius, "tick_conn": tick_conn}
		_sonic_domains.append(domain_data)
		tick_conn.timeout.connect(func():
			tick_time += 0.5
			if tick_time > duration:
				return
			# Rhythmic ripples
			var ripple := MeshInstance3D.new()
			var rmesh := CapsuleMesh.new()
			rmesh.radius = 0.02
			rmesh.height = max_radius * 2.0
			ripple.mesh = rmesh
			var rmat := StandardMaterial3D.new()
			rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			rmat.albedo_color = accent
			rmat.emission_enabled = true
			rmat.emission = accent
			ripple.material_override = rmat
			ripple.rotation.x = PI / 2.0
			ripple.global_position = center + Vector3.UP * 0.5
			arena_root.add_child(ripple)
			var rt := create_tween()
			rt.tween_property(rmesh, "radius", max_radius * 1.1, 0.4)
			rt.tween_property(rmat, "albedo_color:a", 0.0, 0.4)
			rt.tween_property(rmat, "emission_energy_multiplier", 0.0, 0.4)
			rt.chain().tween_callback(ripple.queue_free)
			# Status effect: buff player / debuff enemy
			var is_player := source == player_node
			var twg := bool(source.get_meta("attack_state", {}).get("target_was_guarding", false))
			if is_player:
				# Damage enemy in domain
				var dmg := float(move.get("damage", 8)) * 0.4
				var stun_d := float(move.get("stun", 10)) * 0.4
				_resolve_attack_impact(source, target, move, twg, dmg, stun_d, is_player, "ultimate", accent, center)
			else:
				var dmg := float(move.get("damage", 8)) * 0.4
				var stun_d := float(move.get("stun", 10)) * 0.4
				_resolve_attack_impact(source, target, move, twg, dmg, stun_d, is_player, "ultimate", accent, center)
		, CONNECT_ONE_SHOT)
		# Initial damage
		var is_player := source == player_node
		var twg := bool(source.get_meta("attack_state", {}).get("target_was_guarding", false))
		_resolve_attack_impact(source, target, move, twg, float(move.get("damage", 12)), float(move.get("stun", 10)), is_player, "ultimate", accent, center)
	)
	# Dome fades after duration
	get_tree().create_timer(duration).timeout.connect(func():
		var ft := create_tween()
		ft.tween_property(dmat, "albedo_color:a", 0.0, 0.8)
		ft.tween_property(dmat, "emission_energy_multiplier", 0.0, 0.8)
		ft.tween_property(omat, "emission_energy_multiplier", 0.0, 0.8)
		ft.chain().tween_callback(dome.queue_free)
		ft.chain().tween_callback(orb.queue_free)
	, CONNECT_ONE_SHOT)

# ⚡ SHOCKWAVE RING (shared helper)
func _spawn_shockwave_ring(position: Vector3, color: Color, radius: float = 2.0, duration: float = 0.5) -> void:
	var ring := Node3D.new()
	ring.name = "ShockwaveRing"
	arena_root.add_child(ring)
	ring.global_position = position + Vector3.UP * 0.05
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.03
	capsule.height = radius * 2.0
	mesh.mesh = capsule
	mesh.material_override = mat
	mesh.rotation.x = PI / 2.0
	ring.add_child(mesh)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 4.0
	light.omni_range = radius
	light.shadow_enabled = false
	ring.add_child(light)
	var tween := create_tween()
	tween.tween_property(capsule, "radius", radius * 1.5, duration)
	tween.tween_property(mat, "albedo_color:a", 0.0, duration)
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, duration)
	tween.tween_property(light, "light_energy", 0.0, duration)
	tween.chain().tween_callback(ring.queue_free)

# 🔥 SCORCHED GROUND MARK (beam aftermath)
func _spawn_scorch_mark(start_pos: Vector3, end_pos: Vector3, color: Color) -> void:
	var mark := MeshInstance3D.new()
	mark.name = "ScorchMark"
	arena_root.add_child(mark)
	var dir := (end_pos - start_pos).normalized()
	dir.y = 0.0
	var dist := start_pos.distance_to(end_pos)
	var mid := start_pos + dir * dist * 0.5
	mark.global_position = mid + Vector3.UP * 0.02
	var plane := PlaneMesh.new()
	plane.size = Vector2(dist, 1.0)
	mark.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color("#1a0a0a")
	mat.emission_enabled = true
	mat.emission = Color("#3a1a0a")
	mat.emission_energy_multiplier = 1.5
	mark.material_override = mat
	mark.rotation.x = PI / 2.0
	mark.look_at(mid + dir, Vector3.UP)
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 4.0)
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, 4.0)
	tween.chain().tween_callback(mark.queue_free)



func _activate_hitboxes(fighter: Node3D, hit_type: String, active: bool, limb: String = "") -> void:
	for hitbox_node in fighter.find_children("*", "Area3D", true, false):
		var hitbox := hitbox_node as Area3D
		if not is_instance_valid(hitbox) or not hitbox.name.begins_with("Hitbox_"):
			continue
		var htype := str(hitbox.get_meta("hit_type", ""))
		var hitbox_name := hitbox.name
		if htype == hit_type or hit_type == "all":
			if limb.is_empty():
				hitbox.monitoring = active
			else:
				if limb == "left" and hitbox_name.ends_with("_L"):
					hitbox.monitoring = active
				elif limb == "right" and hitbox_name.ends_with("_R"):
					hitbox.monitoring = active

func _update_combo_ui(count: int, is_player: bool) -> void:
	if not is_instance_valid(hud):
		return
	var combo_label := hud.get_node_or_null("ModeInfo/ComboLabel") as Label
	if not is_instance_valid(combo_label):
		combo_label = Label.new()
		combo_label.name = "ComboLabel"
		combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		combo_label.add_theme_font_size_override("font_size", 24)
		combo_label.add_theme_color_override("font_color", Color("#f4bf4e"))
		combo_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		combo_label.offset_top = 60
		combo_label.offset_bottom = 100
		hud.add_child(combo_label)
	combo_label.text = "%d HIT COMBO!" % count
	combo_label.visible = count > 1
	if count <= 1:
		return
	var tween := create_tween()
	tween.tween_property(combo_label, "modulate:a", 1.0, 0.1)
	tween.tween_interval(0.8)
	tween.tween_property(combo_label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func() -> void: combo_label.visible = false)

func _build_world() -> void:
	arena_root = Node3D.new()
	arena_root.name = "Arena"
	add_child(arena_root)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#263e62")
	sky_material.sky_horizon_color = Color("#e4bd7c")
	sky_material.ground_bottom_color = Color("#332d27")
	sky_material.ground_horizon_color = Color("#817052")
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#ded4ba")
	env.ambient_light_energy = 0.8
	environment.environment = env
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)

	var floor := MeshInstance3D.new()
	floor.name = "ForestArenaFloor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(24.0, 24.0)
	floor.mesh = plane
	floor.position.y = -0.08
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#8c7755")
	floor_material.roughness = 0.9
	floor.material_override = floor_material
	arena_root.add_child(floor)
	_add_arena_grid()
	_add_forest()

	# Water environment setup: flat plane with vertex shader wave animation
	var water := MeshInstance3D.new()
	water.name = "WaterSurface"
	var water_plane := PlaneMesh.new()
	water_plane.size = Vector2(30.0, 30.0)
	water_plane.subdivide_depth = 32
	water_plane.subdivide_width = 32
	water.mesh = water_plane
	water.position.y = -0.04
	var water_shader := ShaderMaterial.new()
	water_shader.shader = Shader.new()
	water_shader.shader.code = """
shader_type spatial;
render_mode depth_draw_opaque, cull_disabled;
uniform float time : hint_range(0.0, 1000.0);
uniform vec4 water_color = vec4(0.15, 0.35, 0.6, 1.0);
uniform vec4 foam_color = vec4(0.9, 0.95, 1.0, 1.0);
varying float wave_height;
void vertex() {
    float wave1 = sin(VERTEX.x + TIME * 1.5);
    float wave2 = sin(VERTEX.z - TIME * 1.2);
    VERTEX.y += (wave1 + wave2) * 0.15;
    wave_height = (wave1 + wave2) * 0.5 + 0.5;
}
void fragment() {
    ALBEDO = mix(water_color.rgb, foam_color.rgb, wave_height * 0.3);
    ALPHA = water_color.a;
}
"""
	water.material_override = water_shader
	water_shader.set_shader_parameter("time", 0.0)
	water_shader_material = water_shader
	arena_root.add_child(water)

	camera = Camera3D.new()
	camera.name = "BattleCamera"
	camera.position = Vector3(0.0, 4.6, 9.0)
	camera.fov = 45.0
	camera.current = true
	arena_root.add_child(camera)

func _add_arena_grid() -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for index in range(-12, 13):
		var color := Color(0.72, 0.88, 0.77, 0.22)
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(Vector3(float(index), 0.005, -12.0))
		mesh.surface_add_vertex(Vector3(float(index), 0.005, 12.0))
		mesh.surface_add_vertex(Vector3(-12.0, 0.005, float(index)))
		mesh.surface_add_vertex(Vector3(12.0, 0.005, float(index)))
	mesh.surface_end()
	var grid := MeshInstance3D.new()
	grid.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("#9cc9ad")
	grid.material_override = material
	arena_root.add_child(grid)

func _add_forest() -> void:
	# A layered rocky plateau gives the fight a readable horizon without placing
	# collision or tall scenery in the play space.
	var rock_colors := [Color("#8d6845"), Color("#a77b4d"), Color("#6f614b"), Color("#b18b5b")]
	for side in [-1.0, 1.0]:
		for index in range(8):
			var x: float = float(side) * (8.0 + rng.randf_range(0.0, 3.0))
			var z := -8.5 - float(index % 3) * 1.35
			var mesa := MeshInstance3D.new()
			var shape := SphereMesh.new()
			shape.radius = rng.randf_range(1.4, 2.8)
			shape.height = shape.radius * rng.randf_range(1.0, 1.7)
			mesa.mesh = shape
			mesa.position = Vector3(x, shape.height * 0.18, z)
			mesa.scale = Vector3(rng.randf_range(0.9, 1.4), rng.randf_range(1.3, 2.3), rng.randf_range(0.65, 1.0))
			mesa.material_override = _make_material(rock_colors[rng.randi_range(0, rock_colors.size() - 1)], 1.0)
			arena_root.add_child(mesa)
	for index in range(24):
		var boulder := MeshInstance3D.new()
		var rock := SphereMesh.new()
		rock.radius = rng.randf_range(0.22, 0.75)
		rock.height = rock.radius * rng.randf_range(0.7, 1.25)
		boulder.mesh = rock
		var side := -1.0 if index % 2 == 0 else 1.0
		boulder.position = Vector3(side * rng.randf_range(7.2, 11.0), rock.radius * 0.25, rng.randf_range(-7.5, 5.0))
		boulder.scale = Vector3(rng.randf_range(0.8, 1.5), rng.randf_range(0.7, 1.2), rng.randf_range(0.8, 1.4))
		boulder.material_override = _make_material(rock_colors[rng.randi_range(0, rock_colors.size() - 1)], 1.0)
		arena_root.add_child(boulder)

func _add_tree(origin: Vector3, height: float) -> void:
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.14
	trunk_mesh.bottom_radius = 0.24
	trunk_mesh.height = height * 0.34
	trunk.mesh = trunk_mesh
	trunk.position = origin + Vector3(0.0, trunk_mesh.height * 0.5, 0.0)
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color("#493a2e")
	trunk.material_override = bark
	arena_root.add_child(trunk)

	for level in range(3):
		var foliage := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = height * (0.29 - level * 0.045)
		cone.height = height * 0.46
		foliage.mesh = cone
		foliage.position = origin + Vector3(0.0, height * (0.43 + level * 0.17), 0.0)
		var leaves := StandardMaterial3D.new()
		leaves.albedo_color = [Color("#173b2a"), Color("#205039"), Color("#2c6545")][level]
		leaves.roughness = 0.95
		foliage.material_override = leaves
		arena_root.add_child(foliage)

func _make_material(color: Color, roughness := 0.7) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _create_fighter(name: String, accent: Color, shirt_color: Color) -> Node3D:
	var root := FIGHTER_SCENE.instantiate() as Node3D
	if not is_instance_valid(root):
		push_error("The selected stickman scene could not be instantiated.")
		return Node3D.new()
	root.name = name
	root.scale = Vector3.ONE
	var skeletons := root.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		push_error("The selected fighter model has no Skeleton3D.")
		return root
	var skeleton := skeletons[0] as Skeleton3D
	var toon_shader := load("res://shaders/fighter_toon.gdshader") as Shader
	var outline_shader := load("res://shaders/fighter_outline.gdshader") as Shader
	if toon_shader == null or outline_shader == null:
		push_error("Fighter toon shaders could not be loaded.")
		return root
	var body_material := ShaderMaterial.new()
	body_material.shader = toon_shader
	body_material.set_shader_parameter("base_color", shirt_color)
	body_material.set_shader_parameter("rim_color", accent)
	var outline_material := ShaderMaterial.new()
	outline_material.shader = outline_shader
	outline_material.set_shader_parameter("outline_color", Color("#17151d"))
	outline_material.set_shader_parameter("outline_width_pixels", 1.2 if OS.get_name() == "Android" or OS.get_name() == "iOS" else 2.5)
	body_material.next_pass = outline_material
	for body_mesh in root.find_children("*", "MeshInstance3D", true, false):
		(body_mesh as MeshInstance3D).material_override = body_material
	_add_fighter_costume(skeleton, accent, shirt_color)

	var eye_attachment := BoneAttachment3D.new()
	eye_attachment.name = "GlowEyes"
	eye_attachment.bone_name = "Head"
	skeleton.add_child(eye_attachment)
	var glow_material := StandardMaterial3D.new()
	glow_material.albedo_color = Color("#fff2b0")
	glow_material.emission_enabled = true
	glow_material.emission = accent
	glow_material.emission_energy_multiplier = 2.0
	for eye_x in [-0.09, 0.09]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.045
		eye_mesh.height = 0.035
		eye.mesh = eye_mesh
		eye.position = Vector3(eye_x, 0.015, 0.0)
		eye.scale = Vector3(1.5, 0.7, 0.55)
		eye.material_override = glow_material
		eye_attachment.add_child(eye)

	# Add Health component from addon
	var health = _create_health_component(root)
	root.set_meta("health_component", health)

	# Add FighterCombat component
	var combat = FighterCombatScript.new()
	combat.name = "FighterCombat"
	combat.max_hp = MAX_HP
	combat.max_mp = MAX_MP
	combat.max_stun = MAX_STUN
	combat.mp_regen_per_sec = 0.0
	combat.charge_mp_per_sec = 0.0 # MP is managed by the match combat loop.
	combat.stun_duration = 2.0
	root.add_child(combat)
	root.set_meta("fighter_combat", combat)

	_add_hurtboxes(root, skeleton, health)
	_add_hitbox_system(root, skeleton)

	# Set up combat component references to hitbox/hurtbox
	# We'll use the first hitbox and hurtbox as primary for the combat system
	combat.hitbox = _find_child_with_prefix(root, "Hitbox_")
	combat.hurtbox = _find_child_with_prefix(root, "Hurtbox_")
	combat.animation_player = root.get_node_or_null("AnimationPlayer") as AnimationPlayer

	# Connect combat signals
	combat.hp_changed.connect(_on_combat_hp_changed)
	combat.mp_changed.connect(_on_combat_mp_changed)
	combat.stun_changed.connect(_on_combat_stun_changed)
	combat.move_started.connect(_on_combat_move_started.bind(root))
	combat.challenge_requested.connect(_on_combat_challenge_requested)
	combat.challenge_restarted.connect(_on_combat_challenge_restarted.bind(root))
	combat.stunned.connect(_on_combat_stunned.bind(root))
	combat.defeated.connect(_on_combat_defeated.bind(root))

	var animation_player := root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if not is_instance_valid(animation_player):
		push_error("The selected fighter model has no AnimationPlayer.")
		return root
	for looping_animation in ["idle", "walk", "charge", "block", "stun"]:
		var animation := animation_player.get_animation(looping_animation) if animation_player.has_animation(looping_animation) else null
		if animation != null:
			animation.loop_mode = Animation.LOOP_LINEAR
	if skeleton.find_bone("DEF-upper_arm.L") >= 0:
		_add_fighter_procedural_animations(animation_player)
	root.set_meta("anim_action", "idle")
	root.set_meta("anim_elapsed", 0.0)
	root.set_meta("anim_duration", 0.0)
	root.set_meta("attack_count", 0)
	root.set_meta("locomotion_speed", 0.0)
	root.set_meta("combo_count", 0)
	root.set_meta("juggle_decay", 0.0)
	var rig := root.get_node_or_null("Stickman_Rig") as Node3D
	root.set_meta("kick_rig_base_y", rig.position.y if is_instance_valid(rig) else 0.0)
	root.set_meta("fighter_skeleton_path", root.get_path_to(skeleton))
	return root

func _add_fighter_costume(skeleton: Skeleton3D, accent: Color, shirt_color: Color) -> void:
	# Lightweight bone-attached shapes add a readable martial-artist silhouette
	# while leaving the imported skeleton, hitboxes, and animation clips in place.
	var cloth := _make_material(shirt_color, 0.72)
	var trim := _make_material(accent, 0.48)
	var dark := _make_material(Color("#292d3b"), 0.78)
	_add_bone_gear(skeleton, "Chest", "GiTop", SphereMesh.new(), Vector3(0.31, 0.37, 0.2), Vector3(0.0, 0.0, 0.0), cloth)
	_add_bone_gear(skeleton, "Spine", "WaistWrap", CylinderMesh.new(), Vector3(0.23, 0.12, 0.23), Vector3(0.0, -0.12, 0.0), trim)
	_add_bone_gear(skeleton, "Hips", "GiPants", SphereMesh.new(), Vector3(0.28, 0.2, 0.2), Vector3(0.0, -0.08, 0.0), cloth)
	_add_bone_gear(skeleton, "Head", "AnimeHair", SphereMesh.new(), Vector3(0.26, 0.29, 0.24), Vector3(0.0, 0.18, 0.0), dark)
	for spike_index in range(5):
		var spike := _add_bone_gear(skeleton, "Head", "HairSpike%d" % spike_index, CylinderMesh.new(), Vector3(0.085, 0.31, 0.085), Vector3((spike_index - 2) * 0.09, 0.36 + (1.0 - absf(spike_index - 2) * 0.24), 0.0), dark)
		if is_instance_valid(spike):
			spike.rotation_degrees.z = float(spike_index - 2) * -18.0
	for bone in ["LeftHand", "RightHand"]:
		_add_bone_gear(skeleton, bone, bone + "Glove", SphereMesh.new(), Vector3(0.14, 0.12, 0.13), Vector3.ZERO, trim)
	for bone in ["LeftFoot", "RightFoot"]:
		_add_bone_gear(skeleton, bone, bone + "Boot", SphereMesh.new(), Vector3(0.14, 0.11, 0.2), Vector3(0.0, 0.0, -0.045), trim)
	for bone in ["LeftUpperArm", "RightUpperArm"]:
		_add_bone_gear(skeleton, bone, bone + "Sleeve", SphereMesh.new(), Vector3(0.13, 0.18, 0.13), Vector3(0.0, -0.08, 0.0), cloth)
	for bone in ["LeftUpperLeg", "RightUpperLeg"]:
		_add_bone_gear(skeleton, bone, bone + "TrouserLeg", SphereMesh.new(), Vector3(0.15, 0.24, 0.15), Vector3(0.0, -0.09, 0.0), cloth)
	for bone in ["LeftLowerLeg", "RightLowerLeg"]:
		_add_bone_gear(skeleton, bone, bone + "ShinWrap", SphereMesh.new(), Vector3(0.12, 0.2, 0.13), Vector3(0.0, -0.08, 0.0), trim)
	_add_bone_gear(skeleton, "Neck", "NeckScarf", CylinderMesh.new(), Vector3(0.13, 0.07, 0.13), Vector3.ZERO, trim)

func _add_bone_gear(skeleton: Skeleton3D, bone: String, gear_name: String, mesh_resource: PrimitiveMesh, dimensions: Vector3, local_offset: Vector3, material: Material) -> MeshInstance3D:
	if skeleton.find_bone(bone) < 0:
		return null
	var attachment := BoneAttachment3D.new()
	attachment.name = gear_name + "Attachment"
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	var gear := MeshInstance3D.new()
	gear.name = gear_name
	if mesh_resource is CylinderMesh:
		var cylinder := mesh_resource as CylinderMesh
		cylinder.top_radius = 0.0 if gear_name.begins_with("HairSpike") else 0.22
		cylinder.bottom_radius = 0.18 if gear_name.begins_with("HairSpike") else 0.3
		cylinder.height = 1.0
	gear.mesh = mesh_resource
	gear.scale = dimensions
	gear.position = local_offset
	gear.material_override = material
	attachment.add_child(gear)
	return gear

func _find_child_with_prefix(root: Node, prefix: String) -> Node:
	for child in root.find_children("*", "Area3D", true, false):
		if child.name.begins_with(prefix):
			return child
	return null

func _create_health_component(entity: Node) -> Object:
	var health = SimpleHealth.new()
	health.entity = entity
	health.max = int(MAX_HP)
	health.current = int(MAX_HP)
	health.damageable = true
	health.healable = true
	health.killable = true
	health.revivable = false
	health.verbose_debug = false
	entity.add_child(health)
	return health

func _add_hurtboxes(fighter: Node3D, skeleton: Skeleton3D, health) -> void:
	var hurtbox_data: Array[Dictionary] = [
		{"bone": "Head", "radius": 0.2, "offset": Vector3.ZERO, "damage_mult": 1.5},
		{"bone": "Chest", "radius": 0.28, "offset": Vector3.ZERO, "damage_mult": 1.0},
		{"bone": "Spine", "radius": 0.24, "offset": Vector3.ZERO, "damage_mult": 1.0},
		{"bone": "Hips", "radius": 0.22, "offset": Vector3.ZERO, "damage_mult": 1.0},
		{"bone": "LeftUpperLeg", "radius": 0.14, "offset": Vector3.ZERO, "damage_mult": 0.8},
		{"bone": "RightUpperLeg", "radius": 0.14, "offset": Vector3.ZERO, "damage_mult": 0.8},
		{"bone": "LeftLowerLeg", "radius": 0.11, "offset": Vector3.ZERO, "damage_mult": 0.7},
		{"bone": "RightLowerLeg", "radius": 0.11, "offset": Vector3.ZERO, "damage_mult": 0.7},
		{"bone": "LeftUpperArm", "radius": 0.12, "offset": Vector3.ZERO, "damage_mult": 0.9},
		{"bone": "RightUpperArm", "radius": 0.12, "offset": Vector3.ZERO, "damage_mult": 0.9},
		{"bone": "LeftLowerArm", "radius": 0.1, "offset": Vector3.ZERO, "damage_mult": 0.8},
		{"bone": "RightLowerArm", "radius": 0.1, "offset": Vector3.ZERO, "damage_mult": 0.8},
	]
	# Hurtboxes are parented to BoneAttachment3D in _create_hurtbox, no container needed
	for data in hurtbox_data:
		_create_hurtbox(fighter, skeleton, health, data)

func _create_hurtbox(fighter: Node3D, skeleton: Skeleton3D, health: Object, data: Dictionary) -> Object:
	if skeleton.find_bone(str(data.bone)) < 0:
		return null
	var hurtbox = SimpleHurtBox3D.new()
	hurtbox.name = "Hurtbox_" + data.bone
	hurtbox.collision_layer = 2
	hurtbox.collision_mask = 4
	hurtbox.health = health
	# Store damage multiplier in modifiers dict (using 1 as KINETIC type)
	hurtbox.modifiers[1] = {"multiplier": data.damage_mult}
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = data.radius
	col.shape = shape
	hurtbox.add_child(col)
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = data.bone
	attachment.position = data.offset
	skeleton.add_child(attachment)
	attachment.add_child(hurtbox)
	return hurtbox

func _add_hitbox_system(fighter: Node3D, skeleton: Skeleton3D) -> void:
	# Hitboxes are parented to BoneAttachment3D in _create_hitbox, no container needed
	var hitbox_defs: Array[Dictionary] = [
		{"name": "Hitbox_Punch_L", "bone": "LeftHand", "radius": 0.14, "offset": Vector3(0.0, 0.0, 0.08), "hit_type": "punch"},
		{"name": "Hitbox_Punch_R", "bone": "RightHand", "radius": 0.14, "offset": Vector3(0.0, 0.0, 0.08), "hit_type": "punch"},
		{"name": "Hitbox_Kick_L", "bone": "LeftFoot", "radius": 0.16, "offset": Vector3(0.0, 0.0, 0.1), "hit_type": "kick"},
		{"name": "Hitbox_Kick_R", "bone": "RightFoot", "radius": 0.16, "offset": Vector3(0.0, 0.0, 0.1), "hit_type": "kick"},
		{"name": "Hitbox_Grab_L", "bone": "LeftHand", "radius": 0.2, "offset": Vector3.ZERO, "hit_type": "grab"},
		{"name": "Hitbox_Grab_R", "bone": "RightHand", "radius": 0.2, "offset": Vector3.ZERO, "hit_type": "grab"},
	]
	for def in hitbox_defs:
		_create_hitbox(fighter, skeleton, def)

func _create_hitbox(fighter: Node3D, skeleton: Skeleton3D, def: Dictionary) -> Object:
	if skeleton.find_bone(str(def.bone)) < 0:
		return null
	var hitbox = SimpleHitBox3D.new()
	hitbox.name = def.name
	hitbox.collision_layer = 4
	hitbox.collision_mask = 2
	hitbox.monitoring = false
	# Configure hitbox actions for damage
	var action = {
		"affect": 1,  # DAMAGE
		"type": 1,    # KINETIC
		"amount": 10,
		"incrementer": 0,
		"multiplier": 1.0
	}
	hitbox.actions.append(action)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = def.radius
	col.shape = shape
	hitbox.add_child(col)
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = def.bone
	attachment.position = def.offset
	skeleton.add_child(attachment)
	attachment.add_child(hitbox)
	hitbox.set_meta("hit_type", def.hit_type)
	hitbox.hurt_box_entered.connect(_on_hitbox_hurtbox_entered.bind(fighter))
	return hitbox

func _on_hitbox_hurtbox_entered(source_fighter: Node3D, hurt_box: Object) -> void:
	var attacker: Node3D = source_fighter
	var target: Node3D
	if hurt_box is SimpleHurtBox3D and hurt_box.health != null and hurt_box.health.entity is Node3D:
		target = hurt_box.health.entity
	else:
		target = hurt_box.get_parent().get_parent() as Node3D
	if not is_instance_valid(target) or target == attacker:
		return
	if not attacker.has_meta("attack_active") or not bool(attacker.get_meta("attack_active")):
		return
	var attack_state: Dictionary = attacker.get_meta("attack_state", {})
	if attack_state.is_empty() or bool(attack_state.get("impact_resolved", false)):
		return
	var damage_mult := float(hurt_box.modifiers[1].multiplier if hurt_box.modifiers.has(1) else 1.0)
	attack_state["hitbox_hit"] = true
	attack_state["hit_damage_mult"] = damage_mult
	attack_state["hit_bone"] = hurt_box.name
	attacker.set_meta("attack_state", attack_state)
	
	# Also emit hit_detected for FighterCombat (simulating GoHitHurt API)
	# Damage and stun are applied once by the resolved attack path. The old bridge
	# sent this event to the attacker (and caused the attacker to receive its own hit).

# Legacy functions kept for compatibility (no longer used with addon system)
func _on_hurtbox_entered(area: Area3D) -> void:
	pass

func _on_hitbox_entered(area: Area3D) -> void:
	pass

# FighterCombat signal handlers
func _on_combat_hp_changed(hp: float, max_hp: float) -> void:
	_update_hp_bars()

func _on_combat_mp_changed(mp: float, max_mp: float) -> void:
	_update_mp_bars()

func _on_combat_stun_changed(value: float, max_value: float) -> void:
	_update_stun_bars()

func _on_combat_move_started(fighter: Node3D, move: Object) -> void:
	fighter.set_meta("attack_active", true)
	fighter.set_meta("current_move", move)
	_show_feedback("%s · %s" % [fighter.name, move.display_name])

func _on_combat_challenge_requested(move: Object) -> void:
	_show_feedback("ULTIMATE: %s · COMPLETE CHALLENGE" % move.display_name)
	# TODO: Show challenge UI (Scrabble word, chess puzzle, etc.)

func _on_combat_challenge_restarted(fighter: Node3D, move: Object) -> void:
	_show_feedback("CHALLENGE INTERRUPTED · RESTARTING")
	# TODO: Restart challenge UI

func _on_combat_stunned(fighter: Node3D) -> void:
	_show_feedback("%s STUNNED!" % fighter.name)
	fighter.set_meta("attack_active", false)
	_play_fighter_action(fighter, "stun", 2.0)

func _on_combat_defeated(fighter: Node3D) -> void:
	_show_feedback("%s DEFEATED!" % fighter.name)
	_end_match(fighter == player_node)

# Double-flick dodge handlers
func _on_player_dodged(direction: Vector2) -> void:
	if not is_instance_valid(player_node):
		return
	var combat: Object = player_node.get_meta("fighter_combat", null)
	if not combat or combat.is_stunned or combat.is_charging or combat._busy or combat.invincible or bool(player_node.get_meta("attack_active", false)):
		return
	if player_vanish < VANISH_DODGE_COST:
		_show_feedback("VANISH STEP NEEDS 50% · WAIT FOR THE GAUGE")
		return
	player_vanish -= VANISH_DODGE_COST
	player_vanish_regen_delay = 1.4
	# Convert screen-space direction to world-space relative to camera
	var cam := get_viewport().get_camera_3d()
	if cam:
		var forward = -cam.global_transform.basis.z.normalized()
		forward.y = 0
		forward = forward.normalized()
		var right = forward.cross(Vector3.UP)
		# The virtual stick uses positive Y for down, while camera-forward points up-screen.
		var world_dir = (direction.x * right - direction.y * forward).normalized()
		# Apply dodge: quick movement + brief invincibility
		_spawn_vanish_burst(player_node, GameData.CHARACTERS[player_character_index].accent)
		_move_fighter(player_node, enemy_node, world_dir * 3.0)
		combat.invincible = true
		_play_fighter_action(player_node, "dodge", 0.42)
		_show_feedback("DODGE!")
		await get_tree().create_timer(0.25).timeout
		if is_instance_valid(combat):
			combat.invincible = false

func _clear_dodge_invulnerability(combat: Object) -> void:
	if is_instance_valid(combat):
		combat.invincible = false

func _spawn_vanish_burst(fighter: Node3D, accent: Color) -> void:
	if not is_instance_valid(fighter) or not is_instance_valid(arena_root):
		return
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.32
	ring_mesh.outer_radius = 0.55
	ring.mesh = ring_mesh
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.albedo_color = Color(accent.r, accent.g, accent.b, 0.8)
	ring_material.emission_enabled = true
	ring_material.emission = accent
	ring_material.emission_energy_multiplier = 2.0
	ring.material_override = ring_material
	arena_root.add_child(ring)
	ring.global_position = fighter.global_position + Vector3.UP * 0.08
	var vanish_tween := create_tween()
	vanish_tween.set_parallel(true)
	vanish_tween.tween_property(ring, "scale", Vector3(1.8, 1.8, 1.8), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	vanish_tween.tween_property(ring, "transparency", 1.0, 0.28)
	vanish_tween.chain().tween_callback(ring.queue_free)

func _add_fighter_procedural_animations(animation_player: AnimationPlayer) -> void:
	var library := AnimationLibrary.new()
	var kick_key_ratios: Array[float] = [0.0, 0.08, 0.18, 7.0 / 22.0, 0.52, 0.76, 1.0]
	_add_bone_pose_animation(library, "Kick", 0.48, {
		"DEF-thigh.R": [Vector3.ZERO, Vector3(-0.2, 0.0, -0.1), Vector3(-0.8, 0.0, -0.25), Vector3(-1.25, 0.1, -0.3), Vector3(-1.0, 0.1, -0.15), Vector3(-0.3, 0.02, 0.0), Vector3.ZERO],
		"DEF-shin.R": [Vector3.ZERO, Vector3(0.2, 0.0, 0.0), Vector3(0.95, 0.0, 0.0), Vector3(1.45, 0.0, 0.0), Vector3(0.65, 0.0, 0.0), Vector3(0.2, 0.0, 0.0), Vector3.ZERO],
		"DEF-foot.R": [Vector3.ZERO, Vector3(0.0, 0.0, 0.0), Vector3(-0.15, 0.0, 0.0), Vector3(-0.35, 0.0, 0.0), Vector3(-0.25, 0.0, 0.0), Vector3(-0.08, 0.0, 0.0), Vector3.ZERO],
		"DEF-thigh.L": [Vector3.ZERO, Vector3(-0.08, 0.0, 0.0), Vector3(-0.2, 0.0, 0.0), Vector3(-0.3, 0.0, 0.0), Vector3(-0.2, 0.0, 0.0), Vector3(-0.05, 0.0, 0.0), Vector3.ZERO],
		"DEF-shin.L": [Vector3.ZERO, Vector3(0.08, 0.0, 0.0), Vector3(0.3, 0.0, 0.0), Vector3(0.4, 0.0, 0.0), Vector3(0.25, 0.0, 0.0), Vector3(0.05, 0.0, 0.0), Vector3.ZERO],
		"DEF-upper_arm.L": [Vector3.ZERO, Vector3(-0.15, 0.0, -0.15), Vector3(-0.4, 0.0, -0.3), Vector3(-0.6, 0.0, -0.35), Vector3(-0.4, 0.0, -0.25), Vector3(-0.1, 0.0, -0.1), Vector3.ZERO],
		"DEF-upper_arm.R": [Vector3.ZERO, Vector3(-0.15, 0.0, 0.15), Vector3(-0.25, 0.0, 0.25), Vector3(-0.35, 0.0, 0.3), Vector3(-0.25, 0.0, 0.22), Vector3(-0.12, 0.0, 0.1), Vector3.ZERO],
		"DEF-forearm.L": [Vector3.ZERO, Vector3(0.0, 0.0, 0.0), Vector3(0.1, 0.0, 0.05), Vector3(0.2, 0.0, 0.1), Vector3(0.12, 0.0, 0.06), Vector3(0.02, 0.0, 0.01), Vector3.ZERO],
		"DEF-forearm.R": [Vector3.ZERO, Vector3(0.0, 0.0, 0.0), Vector3(-0.05, 0.0, -0.03), Vector3(-0.12, 0.0, -0.08), Vector3(-0.06, 0.0, -0.04), Vector3(-0.02, 0.0, -0.01), Vector3.ZERO],
		"DEF-spine.001": [Vector3.ZERO, Vector3(0.02, -0.04, 0.0), Vector3(0.06, -0.1, 0.0), Vector3(0.1, -0.15, 0.0), Vector3(0.05, -0.06, 0.0), Vector3(-0.01, 0.01, 0.0), Vector3.ZERO],
		"DEF-spine.002": [Vector3.ZERO, Vector3(0.02, 0.0, 0.0), Vector3(0.08, 0.0, 0.0), Vector3(0.18, 0.0, 0.0), Vector3(0.1, 0.0, 0.0), Vector3(0.02, 0.0, 0.0), Vector3.ZERO]
	}, kick_key_ratios)
	var aerial_kick_ratios: Array[float] = [0.0, 0.06, 0.14, 0.28, 0.42, 0.58, 0.74, 1.0]
	_add_bone_pose_animation(library, "AerialKick", 0.36, {
		"DEF-thigh.R": [Vector3.ZERO, Vector3(-0.18, 0.0, 0.0), Vector3(-0.62, 0.0, 0.0), Vector3(-0.98, 0.0, 0.0), Vector3(-0.94, 0.0, 0.0), Vector3(-0.5, 0.0, 0.0), Vector3(-0.2, 0.0, 0.0), Vector3.ZERO],
		"DEF-shin.R": [Vector3.ZERO, Vector3(0.28, 0.0, 0.0), Vector3(0.96, 0.0, 0.0), Vector3(0.08, 0.0, 0.0), Vector3(0.06, 0.0, 0.0), Vector3(0.78, 0.0, 0.0), Vector3(0.3, 0.0, 0.0), Vector3.ZERO],
		"DEF-foot.R": [Vector3.ZERO, Vector3(0.0, 0.0, 0.0), Vector3(-0.1, 0.0, 0.0), Vector3(-0.15, 0.0, 0.0), Vector3(-0.14, 0.0, 0.0), Vector3(-0.06, 0.0, 0.0), Vector3(-0.03, 0.0, 0.0), Vector3.ZERO],
		"DEF-thigh.L": [Vector3.ZERO, Vector3(-0.1, 0.0, 0.0), Vector3(-0.3, 0.0, 0.0), Vector3(-0.4, 0.0, 0.0), Vector3(-0.34, 0.0, 0.0), Vector3(-0.14, 0.0, 0.0), Vector3(-0.05, 0.0, 0.0), Vector3.ZERO],
		"DEF-shin.L": [Vector3.ZERO, Vector3(0.18, 0.0, 0.0), Vector3(0.52, 0.0, 0.0), Vector3(0.58, 0.0, 0.0), Vector3(0.5, 0.0, 0.0), Vector3(0.16, 0.0, 0.0), Vector3(0.05, 0.0, 0.0), Vector3.ZERO],
		"DEF-upper_arm.L": [Vector3.ZERO, Vector3(-0.06, 0.0, -0.12), Vector3(-0.22, 0.0, -0.3), Vector3(-0.32, 0.0, -0.4), Vector3(-0.28, 0.0, -0.36), Vector3(-0.12, 0.0, -0.22), Vector3(-0.05, 0.0, -0.1), Vector3.ZERO],
		"DEF-upper_arm.R": [Vector3.ZERO, Vector3(-0.06, 0.0, 0.12), Vector3(-0.22, 0.0, 0.3), Vector3(-0.32, 0.0, 0.4), Vector3(-0.28, 0.0, 0.36), Vector3(-0.12, 0.0, 0.22), Vector3(-0.05, 0.0, 0.1), Vector3.ZERO],
		"DEF-spine.001": [Vector3.ZERO, Vector3(-0.04, -0.03, 0.0), Vector3(-0.1, -0.06, 0.0), Vector3(-0.12, -0.08, 0.0), Vector3(-0.08, -0.04, 0.0), Vector3(0.02, 0.03, 0.0), Vector3(0.0, 0.02, 0.0), Vector3.ZERO],
		"DEF-spine.002": [Vector3.ZERO, Vector3(-0.04, 0.0, 0.0), Vector3(-0.08, 0.0, 0.0), Vector3(-0.12, 0.0, 0.0), Vector3(-0.08, 0.0, 0.0), Vector3(0.02, 0.0, 0.0), Vector3(0.0, 0.0, 0.0), Vector3.ZERO]
	}, aerial_kick_ratios)
	var punch_key_ratios: Array[float] = [0.0, 0.1, 0.25, 0.45, 0.65, 0.85, 1.0]
	_add_bone_pose_animation(library, "Punch_Left", 0.35, {
		"DEF-upper_arm.L": [Vector3.ZERO, Vector3(-0.3, 0.0, -0.15), Vector3(-1.2, 0.0, -0.1), Vector3(-1.4, 0.05, 0.0), Vector3(-1.1, 0.02, 0.05), Vector3(-0.4, 0.0, -0.05), Vector3.ZERO],
		"DEF-forearm.L": [Vector3.ZERO, Vector3(0.1, 0.0, 0.0), Vector3(0.8, 0.0, 0.0), Vector3(1.1, 0.0, 0.0), Vector3(0.9, 0.0, 0.0), Vector3(0.3, 0.0, 0.0), Vector3.ZERO],
		"DEF-hand.L": [Vector3.ZERO, Vector3(0.0, 0.0, 0.0), Vector3(-0.1, 0.0, 0.0), Vector3(-0.15, 0.0, 0.0), Vector3(-0.1, 0.0, 0.0), Vector3(-0.05, 0.0, 0.0), Vector3.ZERO],
		"DEF-upper_arm.R": [Vector3.ZERO, Vector3(-0.15, 0.0, 0.1), Vector3(-0.3, 0.0, 0.2), Vector3(-0.35, 0.0, 0.25), Vector3(-0.3, 0.0, 0.2), Vector3(-0.15, 0.0, 0.12), Vector3.ZERO],
		"DEF-forearm.R": [Vector3.ZERO, Vector3(0.0, 0.0, 0.0), Vector3(-0.1, 0.0, 0.0), Vector3(-0.2, 0.0, 0.0), Vector3(-0.15, 0.0, 0.0), Vector3(-0.05, 0.0, 0.0), Vector3.ZERO],
		"DEF-spine.001": [Vector3.ZERO, Vector3(0.03, -0.02, 0.0), Vector3(0.08, -0.06, 0.0), Vector3(0.12, -0.08, 0.0), Vector3(0.08, -0.05, 0.0), Vector3(0.03, -0.02, 0.0), Vector3.ZERO],
		"DEF-spine.002": [Vector3.ZERO, Vector3(0.05, 0.0, 0.0), Vector3(0.15, 0.0, 0.0), Vector3(0.2, 0.0, 0.0), Vector3(0.15, 0.0, 0.0), Vector3(0.05, 0.0, 0.0), Vector3.ZERO],
		"DEF-thigh.L": [Vector3.ZERO, Vector3(-0.05, 0.0, 0.0), Vector3(-0.12, 0.0, 0.0), Vector3(-0.15, 0.0, 0.0), Vector3(-0.12, 0.0, 0.0), Vector3(-0.05, 0.0, 0.0), Vector3.ZERO],
		"DEF-thigh.R": [Vector3.ZERO, Vector3(0.05, 0.0, 0.0), Vector3(0.12, 0.0, 0.0), Vector3(0.15, 0.0, 0.0), Vector3(0.12, 0.0, 0.0), Vector3(0.05, 0.0, 0.0), Vector3.ZERO]
	}, punch_key_ratios)
	_add_bone_pose_animation(library, "Punch_Right", 0.35, {
		"DEF-upper_arm.R": [Vector3.ZERO, Vector3(-0.3, 0.0, 0.15), Vector3(-1.2, 0.0, 0.1), Vector3(-1.4, -0.05, 0.0), Vector3(-1.1, -0.02, -0.05), Vector3(-0.4, 0.0, 0.05), Vector3.ZERO],
		"DEF-forearm.R": [Vector3.ZERO, Vector3(0.1, 0.0, 0.0), Vector3(0.8, 0.0, 0.0), Vector3(1.1, 0.0, 0.0), Vector3(0.9, 0.0, 0.0), Vector3(0.3, 0.0, 0.0), Vector3.ZERO],
		"DEF-hand.R": [Vector3.ZERO, Vector3(0.0, 0.0, 0.0), Vector3(-0.1, 0.0, 0.0), Vector3(-0.15, 0.0, 0.0), Vector3(-0.1, 0.0, 0.0), Vector3(-0.05, 0.0, 0.0), Vector3.ZERO],
		"DEF-upper_arm.L": [Vector3.ZERO, Vector3(-0.15, 0.0, -0.1), Vector3(-0.3, 0.0, -0.2), Vector3(-0.35, 0.0, -0.25), Vector3(-0.3, 0.0, -0.2), Vector3(-0.15, 0.0, -0.12), Vector3.ZERO],
		"DEF-forearm.L": [Vector3.ZERO, Vector3(0.0, 0.0, 0.0), Vector3(-0.1, 0.0, 0.0), Vector3(-0.2, 0.0, 0.0), Vector3(-0.15, 0.0, 0.0), Vector3(-0.05, 0.0, 0.0), Vector3.ZERO],
		"DEF-spine.001": [Vector3.ZERO, Vector3(0.03, -0.02, 0.0), Vector3(0.08, -0.06, 0.0), Vector3(0.12, -0.08, 0.0), Vector3(0.08, -0.05, 0.0), Vector3(0.03, -0.02, 0.0), Vector3.ZERO],
		"DEF-spine.002": [Vector3.ZERO, Vector3(0.05, 0.0, 0.0), Vector3(0.15, 0.0, 0.0), Vector3(0.2, 0.0, 0.0), Vector3(0.15, 0.0, 0.0), Vector3(0.05, 0.0, 0.0), Vector3.ZERO],
		"DEF-thigh.L": [Vector3.ZERO, Vector3(-0.05, 0.0, 0.0), Vector3(-0.12, 0.0, 0.0), Vector3(-0.15, 0.0, 0.0), Vector3(-0.12, 0.0, 0.0), Vector3(-0.05, 0.0, 0.0), Vector3.ZERO],
		"DEF-thigh.R": [Vector3.ZERO, Vector3(0.05, 0.0, 0.0), Vector3(0.12, 0.0, 0.0), Vector3(0.15, 0.0, 0.0), Vector3(0.12, 0.0, 0.0), Vector3(0.05, 0.0, 0.0), Vector3.ZERO]
	}, punch_key_ratios)
	library.add_animation("Kick_Left", library.get_animation("Kick"))
	library.add_animation("Kick_Right", library.get_animation("Kick"))
	library.add_animation("AerialKick_Left", library.get_animation("AerialKick"))
	library.add_animation("AerialKick_Right", library.get_animation("AerialKick"))
	_add_bone_pose_animation(library, "Grab", 0.52, {
		"DEF-upper_arm.L": [Vector3.ZERO, Vector3(-0.18, 0.0, -0.1), Vector3(-0.85, 0.0, -0.2), Vector3(-0.72, 0.0, -0.18), Vector3.ZERO],
		"DEF-upper_arm.R": [Vector3.ZERO, Vector3(-0.18, 0.0, 0.1), Vector3(-0.85, 0.0, 0.2), Vector3(-0.72, 0.0, 0.18), Vector3.ZERO],
		"DEF-forearm.L": [Vector3.ZERO, Vector3(-0.12, 0.0, -0.06), Vector3(-0.5, 0.0, -0.1), Vector3(-0.38, 0.0, -0.08), Vector3.ZERO],
		"DEF-forearm.R": [Vector3.ZERO, Vector3(-0.12, 0.0, 0.06), Vector3(-0.5, 0.0, 0.1), Vector3(-0.38, 0.0, 0.08), Vector3.ZERO],
		"DEF-spine.002": [Vector3.ZERO, Vector3(-0.06, 0.0, 0.0), Vector3(-0.18, 0.0, 0.0), Vector3(-0.1, 0.0, 0.0), Vector3.ZERO]
	}, [0.0, 0.14, 5.0 / 18.0, 0.5, 1.0])
	_add_bone_pose_animation(library, "GrabHold", 0.7, {
		"DEF-upper_arm.L": [Vector3(-0.65, 0.0, -0.35), Vector3(-0.65, 0.0, -0.35), Vector3(-0.65, 0.0, -0.35), Vector3(-0.65, 0.0, -0.35)],
		"DEF-upper_arm.R": [Vector3(-0.65, 0.0, 0.35), Vector3(-0.65, 0.0, 0.35), Vector3(-0.65, 0.0, 0.35), Vector3(-0.65, 0.0, 0.35)],
		"DEF-forearm.L": [Vector3(-0.25, 0.0, -0.1), Vector3(-0.25, 0.0, -0.1), Vector3(-0.25, 0.0, -0.1), Vector3(-0.25, 0.0, -0.1)],
		"DEF-forearm.R": [Vector3(-0.25, 0.0, 0.1), Vector3(-0.25, 0.0, 0.1), Vector3(-0.25, 0.0, 0.1), Vector3(-0.25, 0.0, 0.1)]
	})
	library.get_animation("GrabHold").loop_mode = Animation.LOOP_LINEAR
	_add_bone_pose_animation(library, "Grabbed", 0.7, {
		"DEF-upper_arm.L": [Vector3(-0.35, 0.0, -0.25), Vector3(-0.35, 0.0, -0.25), Vector3(-0.35, 0.0, -0.25), Vector3(-0.35, 0.0, -0.25)],
		"DEF-upper_arm.R": [Vector3(-0.35, 0.0, 0.25), Vector3(-0.35, 0.0, 0.25), Vector3(-0.35, 0.0, 0.25), Vector3(-0.35, 0.0, 0.25)],
		"DEF-forearm.L": [Vector3(-0.45, 0.0, 0.0), Vector3(-0.45, 0.0, 0.0), Vector3(-0.45, 0.0, 0.0), Vector3(-0.45, 0.0, 0.0)],
		"DEF-forearm.R": [Vector3(-0.45, 0.0, 0.0), Vector3(-0.45, 0.0, 0.0), Vector3(-0.45, 0.0, 0.0), Vector3(-0.45, 0.0, 0.0)],
		"DEF-spine.002": [Vector3(0.08, 0.0, 0.0), Vector3(0.08, 0.0, 0.0), Vector3(0.08, 0.0, 0.0), Vector3(0.08, 0.0, 0.0)]
	})
	library.get_animation("Grabbed").loop_mode = Animation.LOOP_LINEAR
	_add_bone_pose_animation(library, "Throw", 0.5, {
		"DEF-upper_arm.L": [Vector3(-0.2, 0.0, -0.3), Vector3(-0.85, 0.0, -0.5), Vector3(-1.1, 0.0, -0.7), Vector3.ZERO],
		"DEF-upper_arm.R": [Vector3(-0.2, 0.0, 0.3), Vector3(-0.85, 0.0, 0.5), Vector3(-1.1, 0.0, 0.7), Vector3.ZERO],
		"DEF-spine.002": [Vector3.ZERO, Vector3(-0.18, 0.0, 0.0), Vector3(0.2, 0.0, 0.0), Vector3.ZERO],
		"DEF-thigh.L": [Vector3.ZERO, Vector3(-0.25, 0.0, -0.1), Vector3(0.15, 0.0, 0.0), Vector3.ZERO],
		"DEF-thigh.R": [Vector3.ZERO, Vector3(-0.25, 0.0, 0.1), Vector3(0.15, 0.0, 0.0), Vector3.ZERO]
	})
	_add_bone_pose_animation(library, "Block", 0.9, {
		"DEF-upper_arm.L": [Vector3.ZERO, Vector3(-0.9, 0.0, -0.5), Vector3(-0.9, 0.0, -0.5), Vector3.ZERO],
		"DEF-upper_arm.R": [Vector3.ZERO, Vector3(-0.9, 0.0, 0.5), Vector3(-0.9, 0.0, 0.5), Vector3.ZERO],
		"DEF-forearm.L": [Vector3.ZERO, Vector3(-0.75, 0.0, 0.0), Vector3(-0.75, 0.0, 0.0), Vector3.ZERO],
		"DEF-forearm.R": [Vector3.ZERO, Vector3(-0.75, 0.0, 0.0), Vector3(-0.75, 0.0, 0.0), Vector3.ZERO],
		"DEF-spine.002": [Vector3.ZERO, Vector3(0.15, 0.0, 0.0), Vector3(0.15, 0.0, 0.0), Vector3.ZERO],
		"DEF-spine.001": [Vector3.ZERO, Vector3(0.05, -0.03, 0.0), Vector3(0.05, -0.03, 0.0), Vector3.ZERO],
		"DEF-thigh.L": [Vector3.ZERO, Vector3(-0.08, 0.0, 0.0), Vector3(-0.08, 0.0, 0.0), Vector3.ZERO],
		"DEF-thigh.R": [Vector3.ZERO, Vector3(-0.08, 0.0, 0.0), Vector3(-0.08, 0.0, 0.0), Vector3.ZERO],
		"DEF-shin.L": [Vector3.ZERO, Vector3(0.08, 0.0, 0.0), Vector3(0.08, 0.0, 0.0), Vector3.ZERO],
		"DEF-shin.R": [Vector3.ZERO, Vector3(0.08, 0.0, 0.0), Vector3(0.08, 0.0, 0.0), Vector3.ZERO]
	})
	_add_bone_pose_animation(library, "block_hit", 0.35, {
		"DEF-upper_arm.L": [Vector3(-0.8, 0.0, -0.45), Vector3(-0.6, 0.0, -0.3), Vector3(-0.8, 0.0, -0.45), Vector3.ZERO],
		"DEF-upper_arm.R": [Vector3(-0.8, 0.0, 0.45), Vector3(-0.6, 0.0, 0.3), Vector3(-0.8, 0.0, 0.45), Vector3.ZERO],
		"DEF-forearm.L": [Vector3(-0.65, 0.0, 0.0), Vector3(-0.4, 0.0, 0.1), Vector3(-0.65, 0.0, 0.0), Vector3.ZERO],
		"DEF-forearm.R": [Vector3(-0.65, 0.0, 0.0), Vector3(-0.4, 0.0, -0.1), Vector3(-0.65, 0.0, 0.0), Vector3.ZERO],
		"DEF-spine.002": [Vector3(0.12, 0.0, 0.0), Vector3(0.2, 0.0, 0.0), Vector3(0.12, 0.0, 0.0), Vector3.ZERO],
		"DEF-spine.001": [Vector3.ZERO, Vector3(0.0, 0.05, 0.0), Vector3(0.0, 0.0, 0.0), Vector3.ZERO]
	})
	_add_bone_pose_animation(library, "Charge", 0.65, {
		"DEF-upper_arm.L": [Vector3.ZERO, Vector3(-0.65, 0.0, -0.3), Vector3(-0.65, 0.0, -0.3), Vector3.ZERO],
		"DEF-upper_arm.R": [Vector3.ZERO, Vector3(-0.65, 0.0, 0.3), Vector3(-0.65, 0.0, 0.3), Vector3.ZERO],
		"DEF-spine.002": [Vector3.ZERO, Vector3(-0.12, 0.0, 0.0), Vector3(-0.12, 0.0, 0.0), Vector3.ZERO]
	})
	_add_bone_pose_animation(library, "Dodge", 0.42, {
		"DEF-spine.001": [Vector3.ZERO, Vector3(0.0, -0.2, 0.0), Vector3(0.0, -0.35, 0.0), Vector3(0.0, -0.2, 0.0), Vector3.ZERO],
		"DEF-spine.002": [Vector3.ZERO, Vector3(0.0, -0.15, 0.0), Vector3(0.0, -0.25, 0.0), Vector3(0.0, -0.15, 0.0), Vector3.ZERO],
		"DEF-thigh.L": [Vector3.ZERO, Vector3(0.3, 0.0, 0.0), Vector3(0.5, 0.0, 0.0), Vector3(0.3, 0.0, 0.0), Vector3.ZERO],
		"DEF-thigh.R": [Vector3.ZERO, Vector3(-0.3, 0.0, 0.0), Vector3(-0.5, 0.0, 0.0), Vector3(-0.3, 0.0, 0.0), Vector3.ZERO],
		"DEF-shin.L": [Vector3.ZERO, Vector3(-0.2, 0.0, 0.0), Vector3(-0.4, 0.0, 0.0), Vector3(-0.2, 0.0, 0.0), Vector3.ZERO],
		"DEF-shin.R": [Vector3.ZERO, Vector3(0.2, 0.0, 0.0), Vector3(0.4, 0.0, 0.0), Vector3(0.2, 0.0, 0.0), Vector3.ZERO],
		"DEF-upper_arm.L": [Vector3.ZERO, Vector3(-0.4, 0.0, -0.3), Vector3(-0.5, 0.0, -0.4), Vector3(-0.4, 0.0, -0.3), Vector3.ZERO],
		"DEF-upper_arm.R": [Vector3.ZERO, Vector3(-0.4, 0.0, 0.3), Vector3(-0.5, 0.0, 0.4), Vector3(-0.4, 0.0, 0.3), Vector3.ZERO]
	}, [0.0, 0.2, 0.5, 0.8, 1.0])
	if animation_player.has_animation_library("Fighter"):
		animation_player.remove_animation_library("Fighter")
	var error := animation_player.add_animation_library("Fighter", library)
	if error != OK:
		push_error("Unable to add procedural fighter animations: %s" % error_string(error))

func _add_bone_pose_animation(library: AnimationLibrary, name: String, duration: float, poses: Dictionary, key_time_ratios: Array[float] = []) -> void:
	if poses.is_empty():
		push_error("Unable to add procedural animation %s without bone poses." % name)
		return
	var key_count: int = poses.values()[0].size()
	if key_count < 2:
		push_error("Unable to add procedural animation %s with fewer than two poses." % name)
		return
	if key_time_ratios.is_empty():
		for key_index in range(key_count):
			key_time_ratios.append(float(key_index) / float(key_count - 1))
	if key_time_ratios.size() != key_count:
		push_error("Unable to add procedural animation %s: pose and timing counts differ." % name)
		return
	var animation := Animation.new()
	animation.length = duration
	animation.loop_mode = Animation.LOOP_NONE
	for bone_name in poses:
		var key_rotations: Array = poses[bone_name]
		if key_rotations.size() != key_count:
			push_error("Unable to add procedural animation %s: pose count differs for %s." % [name, bone_name])
			return
		var track := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, NodePath("Rig/Skeleton3D:" + str(bone_name)))
		for key_index in range(key_count):
			animation.track_insert_key(track, duration * key_time_ratios[key_index], Quaternion.from_euler(key_rotations[key_index]))
	var error := library.add_animation(name, animation)
	if error != OK:
		push_error("Unable to add procedural animation %s: %s" % [name, error_string(error)])

func _build_fighters() -> void:
	if is_instance_valid(player_node):
		player_node.queue_free()
	if is_instance_valid(enemy_node):
		enemy_node.queue_free()
	var player: Dictionary = GameData.CHARACTERS[player_character_index]
	var enemy: Dictionary = GameData.CHARACTERS[opponent_character_index]
	player_node = _create_fighter("PlayerFighter", player.accent, Color("#b97720"))
	enemy_node = _create_fighter("AIFighter", enemy.accent, Color("#38151d"))
	player_data = player
	opponent_data = enemy
	arena_root.add_child(player_node)
	arena_root.add_child(enemy_node)
	player_node.position = Vector3(-2.0, 0.0, 0.0)
	enemy_node.position = Vector3(2.0, 0.0, -0.25)
	_update_fighter_facing()

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "GameUI"
	add_child(layer)
	hud = Control.new()
	hud.name = "HUD"
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	_build_top_hud()
	_build_move_panel()
	_build_action_buttons()
	_build_joystick()
	_build_bottom_info()
	_build_challenge_layer()
	_build_combo_lab()
	_build_story_campaign()
	_on_viewport_resized()

func _init_fighting_systems() -> void:
	# Initialize Fighting Input Buffer (5-10 frame buffer for lenient inputs)
	var input_buffer := FightingInputBufferScript.new()
	input_buffer.name = "FightingInputBuffer"
	add_child(input_buffer)
	fighting_input_buffer = input_buffer
	input_buffer.special_move_detected.connect(_on_special_move_detected)
	
	# Initialize Combo Tracker with 10% damage scaling per hit
	var combo_tracker := ComboTrackerScript.new()
	combo_tracker.name = "ComboTracker"
	add_child(combo_tracker)
	self.combo_tracker = combo_tracker
	
	# Initialize Hit Stop Controller for impact feel
	var hit_stop := HitStopControllerScript.new()
	hit_stop.name = "HitStopController"
	add_child(hit_stop)
	hit_stop_controller = hit_stop
	
	# Initialize Direct Hitbox Query for frame-perfect collision
	var hitbox_query := DirectHitboxQuery3DScript.new()
	hitbox_query.name = "DirectHitboxQuery3D"
	add_child(hitbox_query)
	self.hitbox_query = hitbox_query
	
	# Initialize Fighter State Machines
	player_state_machine = FighterStateMachineScript.new()
	player_state_machine.name = "PlayerStateMachine"
	add_child(player_state_machine)
	
	enemy_state_machine = FighterStateMachineScript.new()
	enemy_state_machine.name = "EnemyStateMachine"
	add_child(enemy_state_machine)
	
	# Initialize new FighterCombat components (will be attached to fighters in _create_fighter)
	# Initialize DoubleFlickDodge for player
	# Note: joystick will be connected after _build_fighters creates the joystick
	
	print("Fighting systems initialized")

func _on_special_move_detected(move_name: String, button: int) -> void:
	if match_over or challenge_active or not is_instance_valid(player_node):
		return
	if bool(player_node.get_meta("attack_active", false)):
		return
	if bool(player_node.get_meta("airborne", false)):
		return
	if player_recovery > 0.0:
		return
	
	var move: Dictionary
	match move_name:
		"hadoken":
			move = {"name": "Hadoken", "kind": "ultimate", "damage": 28, "stun": 20, "cost": 2, "animation": "hadoken", "projectile": true}
		"tatsumaki":
			move = {"name": "Tatsumaki", "kind": "ultimate", "damage": 24, "stun": 18, "cost": 2, "animation": "tatsumaki", "multi_hit": 3}
		"shoryuken":
			move = {"name": "Shoryuken", "kind": "ultimate", "damage": 32, "stun": 25, "cost": 3, "animation": "shoryuken", "invincible_startup": true}
		"hadoken_kick":
			move = {"name": "Hadoken Kick", "kind": "ultimate", "damage": 26, "stun": 18, "cost": 2, "animation": "hadoken_kick", "projectile": true}
		_:
			return
	
	_apply_move(true, move, player_node.global_position.distance_to(enemy_node.global_position))

func _update_fighter_state_machines(delta: float) -> void:
	if not is_instance_valid(player_node) or not is_instance_valid(enemy_node):
		return
	
	# Update player state machine
	var player_attacking := bool(player_node.get_meta("attack_active", false))
	var player_airborne := bool(player_node.get_meta("airborne", false)) or bool(player_node.get_meta("flying", false))
	var player_hitstun := player_recovery > 0.0
	var player_blockstun := player_guard > 0.0
	
	if player_attacking:
		player_state_machine.transition_to(player_state_machine.FighterState.ATTACKING)
	elif player_hitstun:
		player_state_machine.transition_to(player_state_machine.FighterState.HITSTUN)
	elif player_blockstun:
		player_state_machine.transition_to(player_state_machine.FighterState.BLOCKSTUN)
	elif player_airborne:
		player_state_machine.transition_to(player_state_machine.FighterState.JUMPING)
	elif player_node.get_meta("locomotion_speed", 0.0) > 0.1:
		player_state_machine.transition_to(player_state_machine.FighterState.WALKING)
	else:
		player_state_machine.transition_to(player_state_machine.FighterState.IDLE)
	
	# Update enemy state machine
	var enemy_attacking := bool(enemy_node.get_meta("attack_active", false))
	var enemy_hitstun := enemy_recovery > 0.0
	var enemy_blockstun := enemy_guard > 0.0
	
	if enemy_attacking:
		enemy_state_machine.transition_to(enemy_state_machine.FighterState.ATTACKING)
	elif enemy_hitstun:
		enemy_state_machine.transition_to(enemy_state_machine.FighterState.HITSTUN)
	elif enemy_blockstun:
		enemy_state_machine.transition_to(enemy_state_machine.FighterState.BLOCKSTUN)
	elif enemy_node.get_meta("locomotion_speed", 0.0) > 0.1:
		enemy_state_machine.transition_to(enemy_state_machine.FighterState.WALKING)
	else:
		enemy_state_machine.transition_to(enemy_state_machine.FighterState.IDLE)

func _build_combo_lab() -> void:
	combo_lab = Control.new()
	combo_lab.name = "ComboLab"
	combo_lab.set_script(ComboLabScript)
	combo_lab.practice_active_changed.connect(_on_combo_practice_changed)
	combo_lab.practice_progress_changed.connect(_show_feedback)
	combo_lab.panel_opened.connect(_on_combo_lab_panel_opened)
	get_node("GameUI").add_child(combo_lab)

func _build_story_campaign() -> void:
	story_campaign = Control.new()
	story_campaign.name = "StoryCampaign"
	story_campaign.set_script(StoryCampaignScript)
	story_campaign.fight_requested.connect(_on_story_fight_requested)
	story_campaign.exit_requested.connect(_on_story_exit_requested)
	get_node("GameUI").add_child(story_campaign)

func _toggle_story_campaign() -> void:
	if not is_instance_valid(story_campaign) or story_mode_active:
		return
	challenge_active = true
	story_campaign.call("open_campaign", story_progress)

func _on_story_fight_requested(enemy_index: int, enemy_style: String, chapter_index: int) -> void:
	story_mode_active = true
	story_stage_index = chapter_index
	opponent_character_index = clampi(enemy_index, 0, GameData.CHARACTERS.size() - 1)
	opponent_style = enemy_style
	training_mode = false
	challenge_active = false
	_start_match()
	_rebuild_move_cards()
	_show_feedback("STORY CHAPTER %d · DEFEAT %s" % [chapter_index + 1, GameData.CHARACTERS[opponent_character_index].name.to_upper()])

func _on_story_exit_requested() -> void:
	story_mode_active = false
	story_stage_index = 0
	challenge_active = false
	opponent_character_index = 1 if player_character_index != 1 else 0
	opponent_style = "Cards" if player_style != "Cards" else "Chess"
	_start_match()
	_rebuild_move_cards()

func _on_combo_lab_panel_opened(opened: bool) -> void:
	if opened:
		combo_lab_previous_challenge_state = challenge_active
		challenge_active = true
	else:
		challenge_active = combo_lab_previous_challenge_state and not combo_lab_active
	_update_hud()

func _toggle_combo_lab() -> void:
	if is_instance_valid(combo_lab):
		combo_lab.call("toggle_panel")

func _open_main_menu() -> void:
	if not is_instance_valid(main_menu):
		main_menu = Control.new()
		main_menu.name = "MainMenu"
		main_menu.set_script(MainMenuScript)
		main_menu.connect("versus_ai_requested", _on_menu_versus_ai_requested)
		main_menu.connect("board_games_requested", _on_menu_board_games_requested)
		main_menu.connect("pvp_requested", _on_menu_pvp_requested)
		main_menu.connect("story_requested", _on_menu_story_requested)
		main_menu.connect("combo_lab_requested", _on_menu_combo_lab_requested)
		main_menu.connect("settings_requested", _on_menu_settings_requested)
		main_menu.connect("settings_changed", _on_settings_changed)
		main_menu.connect("quit_requested", _on_menu_quit_requested)
		main_menu.connect("resume_requested", _on_pause_resume_requested)
		main_menu.connect("return_to_menu_requested", _on_pause_return_to_menu_requested)
		get_node("GameUI").add_child(main_menu)
	main_menu.visible = true
	hud.visible = false
	pause_menu_open = false
	get_tree().paused = false
	main_menu_open = true

func _close_main_menu() -> void:
	if is_instance_valid(main_menu):
		main_menu.visible = false
	hud.visible = true
	main_menu_open = false

func _on_menu_versus_ai_requested() -> void:
	_close_main_menu()
	training_mode = false
	enemy_is_training = false
	story_mode_active = false
	opponent_character_index = 1 if player_character_index != 1 else 0
	opponent_style = "Cards" if player_style != "Cards" else "Chess"
	_start_match()
	_rebuild_move_cards()

func _on_menu_board_games_requested() -> void:
	if is_instance_valid(main_menu):
		main_menu.visible = false
	hud.visible = false
	main_menu_open = true
	return_to_menu_after_hub = true
	_open_games_hub()

func _on_menu_pvp_requested() -> void:
	main_menu.call(
		"show_notice",
		"ONLINE PVP IS NOT AVAILABLE YET. MATCHMAKING AND ROLLBACK INPUT SYNC ARE STILL IN DEVELOPMENT."
	)

func _on_menu_story_requested() -> void:
	_close_main_menu()
	_toggle_story_campaign()

func _on_menu_combo_lab_requested() -> void:
	_close_main_menu()
	_toggle_combo_lab()

func _on_menu_settings_requested() -> void:
	main_menu.call("show_settings", master_volume, fullscreen_enabled, ai_difficulty)

func _on_settings_changed(volume: float, use_fullscreen: bool, difficulty: String) -> void:
	master_volume = clampf(volume, 0.0, 1.0)
	fullscreen_enabled = use_fullscreen
	ai_difficulty = difficulty if difficulty in ["Easy", "Normal", "Hard"] else "Normal"
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus < 0:
		push_error("Unable to apply settings: the Master audio bus does not exist.")
	else:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(master_volume, 0.0001)))
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen_enabled else DisplayServer.WINDOW_MODE_WINDOWED
	)
	_save_settings()

func _open_pause_menu() -> void:
	if main_menu_open or pause_menu_open or challenge_active or not is_instance_valid(main_menu):
		return
	pause_menu_open = true
	main_menu_open = false
	main_menu.visible = true
	main_menu.call("show_pause", master_volume, fullscreen_enabled, ai_difficulty)
	get_tree().paused = true

func _close_pause_menu() -> void:
	pause_menu_open = false
	get_tree().paused = false
	if is_instance_valid(main_menu):
		main_menu.visible = false
	hud.visible = true

func _on_pause_resume_requested() -> void:
	_close_pause_menu()

func _on_pause_return_to_menu_requested() -> void:
	pause_menu_open = false
	get_tree().paused = false
	_open_main_menu()

func _on_menu_quit_requested() -> void:
	get_tree().quit()

func _on_combo_practice_changed(active: bool, _combo: Dictionary) -> void:
	if active and (
		bool(player_node.get_meta("attack_active", false))
		or bool(enemy_node.get_meta("attack_active", false))
		or is_instance_valid(grapple_holder)
	):
		combo_lab.call("stop_practice")
		_show_feedback("WAIT UNTIL THE CURRENT ATTACK OR GRAPPLE ENDS")
		return
	combo_lab_active = active
	if is_instance_valid(combo_lab_button):
		combo_lab_button.text = "STOP COMBO" if active else "COMBO LAB"
	if active and is_instance_valid(player_node) and is_instance_valid(enemy_node):
		player_recovery = 0.0
		enemy_recovery = 0.0
		stun_lock = 0.0
		player_stun = MAX_STUN
		var toward := enemy_node.global_position - player_node.global_position
		toward.y = 0.0
		if toward.length_squared() < 0.001:
			toward = Vector3.RIGHT
		enemy_node.global_position = player_node.global_position + toward.normalized() * 1.0
		enemy_node.position.x = clampf(enemy_node.position.x, -ARENA_LIMIT, ARENA_LIMIT)
		enemy_node.position.z = clampf(enemy_node.position.z, -ARENA_LIMIT, ARENA_LIMIT)
		enemy_hp = MAX_HP
		enemy_stun = MAX_STUN
		enemy_guard = 0.0
		enemy_recovery = 0.0
		_update_fighter_facing()

func _record_combo_move(move_name: String) -> void:
	if combo_lab_active and is_instance_valid(combo_lab):
		combo_lab.call("record_successful_move", move_name)

func _combo_step_name(move: Dictionary) -> String:
	if bool(move.get("grab", false)):
		return "Grab"
	if bool(move.get("aerial", false)):
		return "Jump Kick" if _attack_animation(move) == "kick" else "Jump Punch"
	return str(move.get("name", ""))

func _panel_style(color := Color(0.025, 0.055, 0.075, 0.82), border := Color(0.7, 0.86, 0.95, 0.32)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _build_top_hud() -> void:
	var row := HBoxContainer.new()
	row.name = "TopHUD"
	row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	row.offset_left = 12
	row.offset_top = 10
	row.offset_right = -12
	row.offset_bottom = 90
	row.add_theme_constant_override("separation", 12)
	hud.add_child(row)

	var player_panel := _make_fighter_hud("YOU", true)
	var versus := Label.new()
	versus.text = "VS"
	versus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	versus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	versus.custom_minimum_size.x = 44
	versus.add_theme_font_size_override("font_size", 23)
	versus.add_theme_color_override("font_color", Color("#f5c45d"))
	var enemy_panel := _make_fighter_hud("AI RIVAL", false)
	row.add_child(player_panel)
	row.add_child(versus)
	row.add_child(enemy_panel)
	player_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _make_fighter_hud(side_name: String, is_player: bool) -> Control:
	var panel := PanelContainer.new()
	panel.name = "PlayerPanel" if is_player else "EnemyPanel"
	panel.add_theme_stylebox_override("panel", _panel_style())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var headline := HBoxContainer.new()
	var title := Label.new()
	title.text = side_name
	title.add_theme_font_size_override("font_size", 13)
	headline.add_child(title)
	var description := Label.new()
	description.name = "FighterTitle"
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	headline.add_child(description)
	if is_player:
		player_title_label = description
	else:
		enemy_title_label = description
	box.add_child(headline)
	var health := ProgressBar.new()
	health.name = "Health"
	health.min_value = 0
	health.max_value = MAX_HP
	health.value = MAX_HP
	health.set_meta("target_value", MAX_HP)
	health.show_percentage = false
	health.tooltip_text = "HP · reduced by damage"
	_add_labeled_meter(box, "HP", health)
	var mana := ProgressBar.new()
	mana.name = "Mana"
	mana.min_value = 0
	mana.max_value = MAX_MP
	mana.show_percentage = false
	mana.tooltip_text = "KI · charge restores this meter only"
	_add_labeled_meter(box, "KI", mana)
	var ultimate := ProgressBar.new()
	ultimate.name = "Ultimate"
	ultimate.min_value = 0
	ultimate.max_value = ULTIMATE_MP_COST
	ultimate.show_percentage = false
	ultimate.tooltip_text = "Ultimate readiness · requires 4 MP"
	ultimate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ultimate_row := HBoxContainer.new()
	var ultimate_label := Label.new()
	ultimate_label.text = "ULT"
	ultimate_label.custom_minimum_size.x = 28
	ultimate_label.add_theme_font_size_override("font_size", 10)
	ultimate_row.add_child(ultimate_label)
	ultimate_row.add_child(ultimate)
	box.add_child(ultimate_row)
	var stun := ProgressBar.new()
	stun.name = "Stun"
	stun.min_value = 0
	stun.max_value = MAX_STUN
	stun.show_percentage = false
	stun.tooltip_text = "STUN · affected by hits, not ki charging"
	_add_labeled_meter(box, "STUN", stun)
	var vanish := ProgressBar.new()
	vanish.name = "Vanish"
	vanish.min_value = 0
	vanish.max_value = MAX_VANISH
	vanish.value = MAX_VANISH
	vanish.show_percentage = false
	vanish.tooltip_text = "Vanishing Step · dodges cost 50%"
	_add_labeled_meter(box, "VANISH", vanish)
	if is_player:
		player_hp_bar = health
		player_mp_bar = mana
		player_ultimate_bar = ultimate
		player_stun_bar = stun
		player_vanish_bar = vanish
	else:
		enemy_hp_bar = health
		enemy_mp_bar = mana
		enemy_ultimate_bar = ultimate
		enemy_stun_bar = stun
		enemy_vanish_bar = vanish
	return panel

func _add_labeled_meter(parent: VBoxContainer, short_label: String, meter: ProgressBar) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	var label := Label.new()
	label.text = short_label
	label.custom_minimum_size.x = 40.0 if short_label == "VANISH" else 34.0
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color("#d8dfe8"))
	row.add_child(label)
	meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(meter)
	parent.add_child(row)

func _build_move_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "MoveDeck"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.anchor_left = 0.18
	panel.anchor_right = 0.82
	panel.offset_left = 0
	panel.offset_right = 0
	panel.offset_top = -210
	panel.offset_bottom = -10
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.055, 0.065, 0.58)))
	hud.add_child(panel)
	var vertical := VBoxContainer.new()
	vertical.add_theme_constant_override("separation", 3)
	panel.add_child(vertical)
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "ARTS DECK"
	title.add_theme_font_size_override("font_size", 12)
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	character_option = OptionButton.new()
	character_option.custom_minimum_size.x = 128
	for character in GameData.CHARACTERS:
		character_option.add_item(character.name)
	character_option.item_selected.connect(_on_character_selected)
	header.add_child(character_option)

	style_option = OptionButton.new()
	style_option.custom_minimum_size.x = 90
	for style in GameData.STYLE_MOVES.keys():
		style_option.add_item(style)
	style_option.item_selected.connect(_on_style_selected)
	header.add_child(style_option)
	loadout_button = Button.new()
	loadout_button.text = "LOADOUTS"
	loadout_button.tooltip_text = "Save, apply, and back up fighter and style presets"
	loadout_button.pressed.connect(_open_loadouts)
	header.add_child(loadout_button)
	vertical.add_child(header)
	var equipped_title := Label.new()
	equipped_title.text = "EQUIPPED ARTS  ·  BASIC"
	equipped_title.add_theme_font_size_override("font_size", 10)
	equipped_title.add_theme_color_override("font_color", Color("#a9dff0"))
	vertical.add_child(equipped_title)
	equipped_grid = GridContainer.new()
	equipped_grid.name = "EquippedArts"
	equipped_grid.columns = 3
	equipped_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipped_grid.add_theme_constant_override("h_separation", 4)
	equipped_grid.add_theme_constant_override("v_separation", 3)
	vertical.add_child(equipped_grid)
	var scroll_title := Label.new()
	scroll_title.text = "MEDIUM · SPECIAL · ULTIMATE  ·  SCROLL"
	scroll_title.add_theme_font_size_override("font_size", 9)
	scroll_title.add_theme_color_override("font_color", Color("#d7c58b"))
	vertical.add_child(scroll_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical.add_child(scroll)
	cards_grid = GridContainer.new()
	cards_grid.columns = 3
	cards_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_grid.add_theme_constant_override("h_separation", 5)
	cards_grid.add_theme_constant_override("v_separation", 5)
	scroll.add_child(cards_grid)

func _build_action_buttons() -> void:
	var column := VBoxContainer.new()
	column.name = "CombatActions"
	column.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	column.anchor_left = 1.0
	column.anchor_right = 1.0
	column.offset_left = -162
	column.offset_right = -8
	column.offset_top = -465
	column.offset_bottom = -9
	column.add_theme_constant_override("separation", 5)
	column.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(column)

	var strike := _make_action_button("STRIKE · TAP / GRAB · HOLD", Color("#347cba"))
	strike.name = "MobileStrikeButton"
	strike.tooltip_text = "Tap for punch/kick combo · flick joystick up for uppercut · hold for grab"
	strike.button_down.connect(_on_mobile_strike_down)
	strike.button_up.connect(_on_mobile_strike_up)
	strike.mouse_exited.connect(_on_mobile_strike_up)
	column.add_child(strike)
	var jump := _make_action_button("JUMP", Color("#547b91"))
	jump.pressed.connect(_on_jump)
	column.add_child(jump)
	flight_button = _make_action_button("FLIGHT · TAP / HOLD RISE", Color("#7e59b5"))
	flight_button.custom_minimum_size.y = 34
	flight_button.button_down.connect(_on_flight_button_down)
	flight_button.button_up.connect(_on_flight_button_up)
	flight_button.mouse_exited.connect(_on_flight_button_up)
	column.add_child(flight_button)
	flight_down_button = _make_action_button("DESCEND / LAND", Color("#6b63a8"))
	flight_down_button.custom_minimum_size.y = 34
	flight_down_button.disabled = true
	flight_down_button.button_down.connect(_set_flight_vertical_input.bind(false, true))
	flight_down_button.button_up.connect(_set_flight_vertical_input.bind(false, false))
	flight_down_button.mouse_exited.connect(_set_flight_vertical_input.bind(false, false))
	column.add_child(flight_down_button)
	var block := _make_action_button("BLOCK · HOLD", Color("#547b91"))
	block.button_down.connect(_on_block)
	block.button_up.connect(_on_block_released)
	block.mouse_exited.connect(_on_block_released)
	column.add_child(block)
	var charge := _make_action_button("CHARGE KI · HOLD", Color("#a77b29"))
	charge.name = "ChargeKiButton"
	charge.button_down.connect(_set_charging.bind(true))
	charge.button_up.connect(_set_charging.bind(false))
	charge.mouse_exited.connect(_set_charging.bind(false))
	column.add_child(charge)
	ultimate_button = _make_action_button("ULTIMATE  ·  0/4", Color("#b44c3e"))
	ultimate_button.name = "UltimateButton"
	ultimate_button.pressed.connect(_use_equipped_ultimate)
	column.add_child(ultimate_button)
	clash_button = _make_action_button("MP CLASH", Color("#7e59b5"))
	clash_button.pressed.connect(_start_mp_clash)
	clash_button.tooltip_text = "Spend low MP to challenge the AI in a timing clash."
	clash_button.visible = true
	column.add_child(clash_button)

func _make_action_button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(148, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := _panel_style(Color(color.r, color.g, color.b, 0.78), Color(color.r, color.g, color.b, 0.9))
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_font_size_override("font_size", 11)
	return button

func _build_joystick() -> void:
	var joystick := Control.new()
	joystick.name = "JoystickTouchArea"
	joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.offset_left = 12
	joystick.offset_top = -156
	joystick.offset_right = 148
	joystick.offset_bottom = -12
	joystick.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(joystick)
	var virtual_stick := Control.new()
	virtual_stick.set_script(JoystickScript)
	virtual_stick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	joystick.add_child(virtual_stick)
	virtual_stick.vector_changed.connect(_on_joystick_changed)
	virtual_stick.tooltip_text = "Double-flick in a direction to dodge that way."
	
	# Set up double-flick dodge for player
	var player_dodge_node := DoubleFlickDodgeScript.new()
	player_dodge_node.name = "PlayerDodge"
	player_dodge_node.joystick = virtual_stick
	add_child(player_dodge_node)
	player_dodge = player_dodge_node
	player_dodge_node.dodged.connect(_on_player_dodged)
	
	var label := Label.new()
	label.text = "MOVE · FLICK TO DODGE"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = -18
	label.offset_bottom = 0
	label.add_theme_font_size_override("font_size", 10)
	joystick.add_child(label)

func _build_bottom_info() -> void:
	var info := HBoxContainer.new()
	info.name = "ModeInfo"
	info.set_anchors_preset(Control.PRESET_TOP_WIDE)
	info.offset_left = 14
	info.offset_top = 100
	info.offset_right = -14
	info.offset_bottom = 128
	hud.add_child(info)
	feedback_label = Label.new()
	feedback_label.text = "MOVE IN WITH THE JOYSTICK · STRIKE WHEN CLOSE"
	feedback_label.add_theme_color_override("font_color", Color("#e9e6d8"))
	feedback_label.add_theme_font_size_override("font_size", 13)
	info.add_child(feedback_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(spacer)
	training_button = _make_action_button("TRAINING", Color("#3a7957"))
	training_button.custom_minimum_size = Vector2(120, 30)
	training_button.pressed.connect(_toggle_training)
	info.add_child(training_button)
	combo_lab_button = _make_action_button("COMBO LAB", Color("#3a7957"))
	combo_lab_button.custom_minimum_size = Vector2(112, 30)
	combo_lab_button.pressed.connect(_toggle_combo_lab)
	info.add_child(combo_lab_button)
	story_button = _make_action_button("STORY", Color("#277a91"))
	story_button.custom_minimum_size = Vector2(86, 30)
	story_button.pressed.connect(_toggle_story_campaign)
	info.add_child(story_button)
	var stats := Label.new()
	stats.name = "ProgressInfo"
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats.custom_minimum_size.x = 180
	stats.add_theme_font_size_override("font_size", 12)
	info.add_child(stats)
	games_button = _make_action_button("BOARD GAMES", Color("#986bba"))
	games_button.custom_minimum_size = Vector2(132, 30)
	games_button.pressed.connect(_open_games_hub)
	info.add_child(games_button)
	pause_button = _make_action_button("PAUSE", Color("#8b6540"))
	pause_button.custom_minimum_size = Vector2(78, 30)
	pause_button.pressed.connect(_open_pause_menu)
	info.add_child(pause_button)

func _build_challenge_layer() -> void:
	challenge_layer = ColorRect.new()
	challenge_layer.name = "ChallengeOverlay"
	challenge_layer.color = Color(0.02, 0.035, 0.05, 0.93)
	challenge_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	challenge_layer.visible = false
	challenge_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(challenge_layer)

func _rebuild_move_cards() -> void:
	if not is_instance_valid(cards_grid):
		return
	for child in cards_grid.get_children():
		child.queue_free()
	for child in equipped_grid.get_children():
		child.queue_free()
	var signature: String = GameData.CHARACTERS[player_character_index].signature
	var moves := GameData.legends_arts(signature, unlocked_ultimates, player_style)
	var equipped_count := 0
	for move in moves:
		var button := Button.new()
		button.custom_minimum_size = Vector2(125, 54)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cost := int(move.get("cost", 0))
		var disabled := bool(move.get("locked", false))
		var details := ""
		if disabled:
			details = "LOCKED · LV %d" % int(move.unlock_level + 1)
		elif move.kind == "block":
			details = "%d GUARD · %d MP" % [int(move.guard), cost]
		elif move.kind == "charge":
			details = "CHARGE · %d MP" % cost
		elif move.kind == "dodge":
			details = "VANISH · 50 GAUGE" 
		elif move.kind == "buff":
			details = "DAMAGE UP · %ds · %d MP" % [roundi(float(move.get("duration", 4.0))), cost]
		else:
			var displayed_damage := float(move.get("damage", 0))
			if move.kind == "ultimate":
				displayed_damage = MAX_HP * 0.12 if bool(move.get("signature", false)) else displayed_damage * 0.65
			else:
				displayed_damage *= NORMAL_DAMAGE_SCALE
			details = "~%d DMG · %d MP" % [roundi(displayed_damage), cost]
		button.text = "%s\n%s · %s" % [move.name, move.get("tier", str(move.kind).to_upper()), details]
		button.disabled = disabled
		button.add_theme_font_size_override("font_size", 11)
		button.add_theme_stylebox_override("normal", _panel_style(Color(0.04, 0.1, 0.13, 0.7)))
		button.add_theme_stylebox_override("hover", _panel_style(Color(0.08, 0.18, 0.2, 0.9)))
		button.pressed.connect(_use_move.bind(move))
		if equipped_count < 3:
			equipped_grid.add_child(button)
			equipped_count += 1
		else:
			cards_grid.add_child(button)

func _start_match() -> void:
	if combo_lab_active and is_instance_valid(combo_lab):
		combo_lab.call("stop_practice")
	match_over = false
	Engine.time_scale = 1.0
	mp_clash_active = false
	challenge_active = false
	is_charging = false
	player_flight_velocity = Vector3.ZERO
	player_ground_velocity = Vector3.ZERO
	mobile_next_strike = "punch"
	_clear_grapple()
	flight_enabled = false
	touch_flight_up = false
	touch_flight_down = false
	enemy_flight_decision_clock = rng.randf_range(3.0, 6.0)
	enemy_flight_time_left = 0.0
	crouch_enabled = false
	if is_instance_valid(flight_button):
		flight_button.set_pressed_no_signal(false)
		flight_button.text = "FLIGHT · TAP / HOLD RISE"
	if is_instance_valid(crouch_button):
		crouch_button.set_pressed_no_signal(false)
		crouch_button.text = "CROUCH · C"
	player_hp = MAX_HP
	enemy_hp = MAX_HP
	player_mp = 3.0
	enemy_mp = 3.0
	player_stun = MAX_STUN
	player_stun_lock = 0.0
	enemy_stun = MAX_STUN
	enemy_stun_lock = 0.0
	player_vanish = MAX_VANISH
	enemy_vanish = MAX_VANISH
	player_vanish_regen_delay = 0.0
	enemy_vanish_regen_delay = 0.0
	player_powerup_timer = 0.0
	enemy_powerup_timer = 0.0
	player_combo = 0
	enemy_combo = 0
	player_guard = 0.0
	player_is_blocking = false
	enemy_guard = 0.0
	player_recovery = 0.0
	enemy_recovery = 0.0
	joystick_vector = Vector2.ZERO
	stun_lock = 0.0
	challenge_cost = 0.0
	ai_clock = float(_ai_profile().decision_interval)
	ai_defense_clock = 0.0
	enemy_guard_timer = 0.0
	mp_clash_cooldown = 0.0
	_build_fighters()
	_set_locomotion(player_node, 0.0)
	_set_locomotion(enemy_node, 0.0)
	sprint_enabled = false
	if is_instance_valid(sprint_button):
		sprint_button.set_pressed_no_signal(false)
		sprint_button.text = "RUN  ·  SHIFT"
	if is_instance_valid(challenge_layer):
		_clear_challenge_overlay()
	_update_hud()

func _update_player_movement(delta: float) -> void:
	if not is_instance_valid(player_node) or stun_lock > 0.0 or challenge_active:
		player_ground_velocity = Vector3.ZERO
		return
	var keyboard := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var input_vector := joystick_vector
	if keyboard.length() > 0.1:
		input_vector = keyboard
	if grapple_victim == player_node:
		if input_vector.length() > 0.2:
			_attempt_grapple_escape(delta * minf(input_vector.length(), 1.0) * 0.9)
		_set_locomotion(player_node, 0.0)
		player_ground_velocity = Vector3.ZERO
		return
	if is_instance_valid(grapple_holder) and grapple_holder == player_node:
		_set_locomotion(player_node, 0.0)
		player_ground_velocity = Vector3.ZERO
		return
	# Dash input: double-tap or dedicated dash action
	if player_dash_cooldown > 0.0:
		player_dash_cooldown -= delta
	if player_is_dashing:
		player_dash_timer -= delta
		if player_dash_timer <= 0.0:
			_end_dash()
		else:
			var dash_move := player_dash_direction * (AIR_DASH_SPEED if bool(player_node.get_meta("airborne", false)) else DASH_SPEED) * delta
			_move_fighter(player_node, enemy_node, dash_move)
			_set_locomotion(player_node, 1.0)
			return
	if Input.is_action_just_pressed("action_dash") or (joystick_vector.length() > 0.9 and Input.is_action_just_pressed("action_dash")):
		var dash_dir := Vector3(joystick_vector.x, 0.0, joystick_vector.y)
		if dash_dir.length_squared() < 0.01:
			dash_dir = (enemy_node.global_position - player_node.global_position)
			dash_dir.y = 0.0
			if dash_dir.length_squared() < 0.0001:
				dash_dir = -player_node.global_basis.z
		if bool(player_node.get_meta("airborne", false)):
			_perform_air_dash(dash_dir)
		else:
			_perform_dash(dash_dir)
		return
	if bool(player_node.get_meta("attack_active", false)):
		if flight_enabled:
			_update_flight_movement(input_vector, delta, false)
		else:
			player_ground_velocity = player_ground_velocity.move_toward(Vector3.ZERO, delta * 30.0)
			_move_fighter(player_node, enemy_node, player_ground_velocity * delta)
			_set_locomotion(player_node, player_ground_velocity.length() / PLAYER_SPEED)
		return
	if flight_enabled:
		player_ground_velocity = Vector3.ZERO
		_update_flight_movement(input_vector, delta)
		return
	var input_strength := clampf(input_vector.length(), 0.0, 1.0)
	var is_running := sprint_enabled or Input.is_action_pressed("action_sprint") or (keyboard.length() <= 0.1 and input_strength >= 0.9)
	var move_speed := PLAYER_SPEED if is_running else WALK_SPEED
	if crouch_enabled:
		move_speed = WALK_SPEED * 0.45
	var desired_velocity := Vector3.ZERO
	if input_strength >= 0.05:
		desired_velocity = Vector3(input_vector.x, 0.0, input_vector.y).normalized() * move_speed * (1.0 if keyboard.length() > 0.1 else input_strength)
	var acceleration := 34.0 if desired_velocity.length_squared() < player_ground_velocity.length_squared() else 22.0
	player_ground_velocity = player_ground_velocity.move_toward(desired_velocity, acceleration * delta)
	_move_fighter(player_node, enemy_node, player_ground_velocity * delta)
	_set_locomotion(player_node, player_ground_velocity.length() / PLAYER_SPEED)

func _update_flight_movement(input_vector: Vector2, delta: float, play_animation := true) -> void:
	var vertical := Input.get_axis("action_fly_down", "action_fly_up")
	if touch_flight_up != touch_flight_down:
		vertical = 1.0 if touch_flight_up else -1.0
	var planar_input := Vector3(input_vector.x, 0.0, input_vector.y).limit_length(1.0)
	var desired_velocity := planar_input * PLAYER_SPEED * 1.35
	desired_velocity.y = vertical * PLAYER_SPEED * 0.9
	player_flight_velocity = player_flight_velocity.move_toward(desired_velocity, PLAYER_SPEED * 4.0 * delta)
	_move_fighter(player_node, enemy_node, Vector3(player_flight_velocity.x, 0.0, player_flight_velocity.z) * delta)
	player_node.position.y = clampf(player_node.position.y + player_flight_velocity.y * delta, 0.0, 7.0)
	if player_node.position.y <= 0.0 or player_node.position.y >= 7.0:
		player_flight_velocity.y = 0.0
	if vertical < 0.0 and player_node.position.y <= 0.01:
		player_node.position.y = 0.0
		_on_flight_toggled(false)
		return
	var clip := "fly_idle"
	if vertical > 0.1:
		clip = "fly_up"
	elif vertical < -0.1:
		clip = "fly_down"
	elif planar_input.length() > 0.1 or Vector2(player_flight_velocity.x, player_flight_velocity.z).length() > 0.35:
		clip = "fly_forward"
	if play_animation:
		_play_flight_animation(player_node, clip)

func _play_flight_animation(fighter: Node3D, clip_name: String) -> void:
	var player := fighter.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if not is_instance_valid(player) or not player.has_animation(clip_name):
		return
	fighter.set_meta("anim_action", "flight")
	if player.current_animation != clip_name:
		player.speed_scale = 1.0
		player.play(clip_name, 0.15)

func _set_flight_vertical_input(ascending: bool, pressed: bool) -> void:
	if ascending:
		touch_flight_up = pressed
	else:
		touch_flight_down = pressed

func _on_crouch_toggled(enabled: bool) -> void:
	crouch_enabled = enabled and not flight_enabled
	if is_instance_valid(crouch_button):
		crouch_button.set_pressed_no_signal(crouch_enabled)
		crouch_button.text = "CROUCH · ON" if crouch_enabled else "CROUCH · C"
	_set_locomotion(player_node, 0.0)

func _on_flight_toggled(enabled: bool) -> void:
	flight_enabled = enabled
	if not enabled:
		touch_flight_up = false
		touch_flight_down = false
		player_flight_velocity = Vector3.ZERO
	if flight_enabled:
		enemy_flight_decision_clock = minf(enemy_flight_decision_clock, 0.6)
		crouch_enabled = false
		if is_instance_valid(crouch_button):
			crouch_button.set_pressed_no_signal(false)
			crouch_button.text = "CROUCH · C"
		player_node.set_meta("flying", true)
		player_node.set_meta("airborne", false)
		_play_flight_animation(player_node, "flight_start")
		_show_feedback("FLIGHT ACTIVE · MOVE WITH THE STICK · HOLD FLIGHT TO RISE")
	else:
		player_node.set_meta("flying", false)
		if player_node.position.y > 0.05:
			player_node.set_meta("airborne", true)
			player_node.set_meta("air_elapsed", 0.0)
			player_node.set_meta("air_gravity", 6.0)
			player_node.set_meta("launch_velocity", -0.8)
			player_node.set_meta("air_duration", 1.4)
		_play_fighter_action(player_node, "flight_stop", 0.45)
	if is_instance_valid(flight_button):
		flight_button.text = "HOVER · HOLD TO RISE" if flight_enabled else "FLIGHT · TAP / HOLD RISE"
	if is_instance_valid(flight_up_button):
		flight_up_button.disabled = not flight_enabled
	if is_instance_valid(flight_down_button):
		flight_down_button.disabled = not flight_enabled
		flight_down_button.text = "DESCEND / LAND" if flight_enabled else "LAND"

func _on_flight_button_down() -> void:
	if not flight_enabled:
		_on_flight_toggled(true)
	_set_flight_vertical_input(true, true)

func _on_flight_button_up() -> void:
	_set_flight_vertical_input(true, false)

# ⚡ LOW-STANCE DASH / FLASH STEP
func _perform_dash(direction: Vector3) -> void:
	if player_is_dashing or player_dash_cooldown > 0.0 or stun_lock > 0.0 or challenge_active:
		return
	if bool(player_node.get_meta("attack_active", false)) and not bool(player_node.get_meta("airborne", false)):
		return
	player_is_dashing = true
	player_dash_timer = DASH_DURATION
	player_dash_cooldown = DASH_COOLDOWN
	player_dash_direction = direction.normalized()
	var is_air := bool(player_node.get_meta("airborne", false)) or bool(player_node.get_meta("flying", false))
	var dash_speed := AIR_DASH_SPEED if is_air else DASH_SPEED
	var dash_distance := dash_speed * DASH_DURATION
	var end_pos := player_node.global_position + player_dash_direction * dash_distance
	end_pos.x = clampf(end_pos.x, -ARENA_LIMIT, ARENA_LIMIT)
	end_pos.z = clampf(end_pos.z, -ARENA_LIMIT, ARENA_LIMIT)
	if is_air:
		end_pos.y = clampf(end_pos.y, 0.0, 6.0)
	else:
		end_pos.y = player_node.position.y
	# Speed lines / wind trail
	_spawn_speed_lines(player_node.global_position, end_pos, GameData.CHARACTERS[player_character_index].accent)
	# Low stance / silhouette trail
	_play_fighter_action(player_node, "dash", DASH_DURATION)
	var tween := create_tween()
	tween.tween_property(player_node, "global_position", end_pos, DASH_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func(): _end_dash())

func _end_dash() -> void:
	player_is_dashing = false
	player_dash_timer = 0.0

# ⚡ SPEED LINES / WIND TRAIL (radiates past camera during high speed)
func _spawn_speed_lines(start_pos: Vector3, end_pos: Vector3, color: Color) -> void:
	var lines := Node3D.new()
	lines.name = "SpeedLines"
	arena_root.add_child(lines)
	var dir := (end_pos - start_pos).normalized()
	var distance := start_pos.distance_to(end_pos)
	var mid := start_pos + dir * distance * 0.5
	lines.global_position = mid
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	for i in range(6):
		var seg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.02
		cyl.bottom_radius = 0.0
		cyl.height = rng.randf_range(0.6, 1.4)
		seg.mesh = cyl
		seg.material_override = material
		var angle := TAU * float(i) / 6.0
		var side := Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(0.4, 1.0)
		seg.global_position = mid + side
		seg.look_at(mid + dir * 2.0, Vector3.UP)
		seg.rotate_object_local(Vector3.RIGHT, PI / 2.0)
		lines.add_child(seg)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 3.0
	light.omni_range = 3.0
	light.shadow_enabled = false
	lines.add_child(light)
	var tween := create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.25)
	tween.tween_property(material, "emission_energy_multiplier", 0.0, 0.25)
	tween.tween_property(light, "light_energy", 0.0, 0.25)
	tween.chain().tween_callback(lines.queue_free)

# 🗡️ WEAPON SLASH TRAIL (crescent arc following blade tip)
var _slash_trail_active := false
func _spawn_weapon_trail(start_pos: Vector3, end_pos: Vector3, color: Color, arc_height: float = 0.8) -> void:
	if _slash_trail_active:
		return
	_slash_trail_active = true
	var trail := Node3D.new()
	trail.name = "WeaponTrail"
	arena_root.add_child(trail)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 4.0
	var mid := start_pos + (end_pos - start_pos) * 0.5 + Vector3.UP * arc_height
	var seg1 := MeshInstance3D.new()
	var cyl1 := CylinderMesh.new()
	cyl1.top_radius = 0.06
	cyl1.bottom_radius = 0.02
	cyl1.height = start_pos.distance_to(mid)
	seg1.mesh = cyl1
	seg1.material_override = material
	seg1.look_at(mid, Vector3.UP)
	seg1.translate(Vector3(0.0, -cyl1.height * 0.5, 0.0))
	trail.add_child(seg1)
	var seg2 := MeshInstance3D.new()
	var cyl2 := CylinderMesh.new()
	cyl2.top_radius = 0.02
	cyl2.bottom_radius = 0.06
	cyl2.height = mid.distance_to(end_pos)
	seg2.mesh = cyl2
	seg2.material_override = material
	seg2.look_at(end_pos, Vector3.UP)
	seg2.translate(Vector3(0.0, -cyl2.height * 0.5, 0.0))
	trail.add_child(seg2)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 4.0
	light.omni_range = 2.5
	light.shadow_enabled = false
	trail.add_child(light)
	var tween := create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.15)
	tween.tween_property(material, "emission_energy_multiplier", 0.0, 0.15)
	tween.tween_property(light, "light_energy", 0.0, 0.15)
	tween.chained().tween_callback(func(): _slash_trail_active = false)
	tween.chain().tween_callback(trail.queue_free)

# 💥 DIRECTIONAL IMPACT SPARKS (from collision contact point)
func _spawn_impact_sparks(position: Vector3, normal: Vector3, color: Color, count: int = 12) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "ImpactSparks"
	particles.emitting = true
	particles.one_shot = true
	particles.amount = count
	particles.lifetime = 0.5
	particles.explosiveness = 1.0
	particles.local_coords = false
	var pmat := ParticleProcessMaterial.new()
	pmat.gravity = Vector3(0.0, -8.0, 0.0)
	pmat.initial_velocity_min = 4.0
	pmat.initial_velocity_max = 8.0
	pmat.velocity_dir = normal
	pmat.spread = 45.0
	pmat.scale_min = 0.04
	pmat.scale_max = 0.12
	particles.process_material = pmat
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, 0.06)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	mesh.material = material
	particles.draw_pass_1 = mesh
	arena_root.add_child(particles)
	particles.global_position = position
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free.bind(), CONNECT_ONE_SHOT)

# 🏃‍♂️ AIR DASH / LAUNCHER CHASE (dash after airborne enemy)
func _perform_air_dash(direction: Vector3) -> void:
	if player_is_dashing or player_dash_cooldown > 0.0 or stun_lock > 0.0:
		return
	if not bool(player_node.get_meta("airborne", false)):
		return
	player_is_dashing = true
	player_dash_timer = DASH_DURATION
	player_dash_cooldown = DASH_COOLDOWN
	player_dash_direction = direction.normalized()
	var end_pos := player_node.global_position + player_dash_direction * (AIR_DASH_SPEED * DASH_DURATION)
	end_pos.x = clampf(end_pos.x, -ARENA_LIMIT, ARENA_LIMIT)
	end_pos.z = clampf(end_pos.z, -ARENA_LIMIT, ARENA_LIMIT)
	end_pos.y = clampf(end_pos.y, 0.0, 6.0)
	_spawn_speed_lines(player_node.global_position, end_pos, GameData.CHARACTERS[player_character_index].accent)
	_play_fighter_action(player_node, "dash", DASH_DURATION)
	var tween := create_tween()
	tween.tween_property(player_node, "global_position", end_pos, DASH_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func(): _end_dash())

# 💥 DOWNWARD SLAM FINISHER (ground impact shockwave)
func _perform_downward_slam(target: Node3D, source: Node3D, accent: Color) -> void:
	var slam_pos := target.global_position
	slam_pos.y = 0.0
	# Throw target downward fast
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(target, "global_position", slam_pos, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(target, "scale", Vector3(1.1, 0.7, 1.1), 0.12)
	tween.chain().tween_property(target, "scale", Vector3.ONE, 0.2)
	# Ground impact shockwave / dust burst
	_spawn_ground_shockwave(slam_pos, accent)
	_camera_punch_in(slam_pos, 0.5, 0.15)
	_show_feedback("GROUND SLAM · IMPACT")

func _spawn_ground_shockwave(position: Vector3, color: Color) -> void:
	var wave := Node3D.new()
	wave.name = "GroundShockwave"
	arena_root.add_child(wave)
	wave.global_position = position
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	var ring := MeshInstance3D.new()
	var ring_mesh := CapsuleMesh.new()
	ring_mesh.radius = 0.02
	ring_mesh.height = SLAM_SHOCKWAVE_RADIUS * 2.0
	ring.mesh = ring_mesh
	ring.material_override = material
	ring.rotation.x = PI / 2.0
	wave.add_child(ring)
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(ring_mesh, "radius", SLAM_SHOCKWAVE_RADIUS, 0.4)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.4)
	tween.tween_property(material, "emission_energy_multiplier", 0.0, 0.4)
	tween.chain().tween_callback(wave.queue_free)

# 🧱 WALL BOUNCE
func _apply_wall_bounce(fighter: Node3D, hit_normal: Vector3, bounce_strength: float = 12.0) -> void:
	var pos := fighter.global_position
	if absf(pos.x) >= ARENA_LIMIT - 0.5:
		pos.x = clampf(pos.x, -ARENA_LIMIT, ARENA_LIMIT)
		var vel := float(fighter.get_meta("launch_velocity", 0.0))
		fighter.set_meta("launch_velocity", vel * -0.5)
		fighter.set_meta("air_gravity", AIR_GRAVITY * 1.5)
	if absf(pos.z) >= ARENA_LIMIT - 0.5:
		pos.z = clampf(pos.z, -ARENA_LIMIT, ARENA_LIMIT)
		var vel := float(fighter.get_meta("launch_velocity", 0.0))
		fighter.set_meta("launch_velocity", vel * -0.5)
		fighter.set_meta("air_gravity", AIR_GRAVITY * 1.5)
	fighter.global_position = pos

# 📹 CAMERA PUNCH-IN (rapid FOV snap on heavy hits)
func _camera_punch_in(hit_position: Vector3, strength: float = 0.35, duration: float = 0.12) -> void:
	if not is_instance_valid(camera):
		return
	camera_fov_target = clampf(45.0 - strength * 30.0, 20.0, 90.0)
	var cam_pos := camera.global_position
	var target_pos := cam_pos.lerp(hit_position, 0.35)
	var tween := create_tween()
	tween.tween_property(camera, "fov", 45.0, duration * 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "global_position", target_pos, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _move_fighter(fighter: Node3D, other: Node3D, displacement: Vector3) -> void:
	var target := fighter.position + displacement
	target.x = clampf(target.x, -ARENA_LIMIT, ARENA_LIMIT)
	target.z = clampf(target.z, -ARENA_LIMIT, ARENA_LIMIT)
	var separation := Vector2(target.x - other.position.x, target.z - other.position.z)
	if separation.length() < FIGHTER_CLEARANCE and absf(target.y - other.position.y) < 1.4:
		if separation.length_squared() < 0.0001:
			separation = Vector2(fighter.position.x - other.position.x, fighter.position.z - other.position.z)
		if separation.length_squared() < 0.0001:
			separation = Vector2.RIGHT if fighter == player_node else Vector2.LEFT
		separation = separation.normalized() * FIGHTER_CLEARANCE
		target.x = clampf(other.position.x + separation.x, -ARENA_LIMIT, ARENA_LIMIT)
		target.z = clampf(other.position.z + separation.y, -ARENA_LIMIT, ARENA_LIMIT)
	fighter.position = target

func _update_fighter_facing(delta := 0.0) -> void:
	if is_instance_valid(player_node) and is_instance_valid(enemy_node):
		_face_fighter(player_node, enemy_node, delta)
		_face_fighter(enemy_node, player_node, delta)

func _face_fighter(fighter: Node3D, target: Node3D, delta := 0.0) -> void:
	var target_position := target.global_position
	target_position.y = fighter.global_position.y
	if fighter.global_position.distance_squared_to(target_position) > 0.0001:
		var target_basis := Basis.looking_at(target_position - fighter.global_position, Vector3.UP, true).orthonormalized()
		var turn_blend := 1.0 if delta <= 0.0 else 1.0 - exp(-delta * 24.0)
		fighter.global_basis = fighter.global_basis.orthonormalized().slerp(target_basis, turn_blend)

func _update_ai(delta: float) -> void:
	if not is_instance_valid(enemy_node) or challenge_active or match_over:
		return
	var player_is_flying := bool(player_node.get_meta("flying", false))
	if bool(enemy_node.get_meta("flying", false)):
		enemy_flight_time_left = maxf(0.0, enemy_flight_time_left - delta)
		if enemy_flight_time_left <= 0.0:
			enemy_node.set_meta("flying", false)
			if enemy_node.position.y > 0.05:
				enemy_node.set_meta("airborne", true)
				enemy_node.set_meta("air_elapsed", 0.0)
				enemy_node.set_meta("air_gravity", AIR_GRAVITY)
				enemy_node.set_meta("launch_velocity", 0.0)
				enemy_node.set_meta("air_duration", JUMP_DURATION)
			_play_fighter_action(enemy_node, "flight_stop", 0.45)
			enemy_flight_decision_clock = rng.randf_range(4.0, 7.0)
		else:
			var player_is_airborne := bool(player_node.get_meta("airborne", false))
			var desired_altitude := clampf(player_node.position.y if player_is_flying or player_is_airborne else 1.2, 0.8, 6.0)
			enemy_node.position.y = move_toward(enemy_node.position.y, desired_altitude, delta * 4.5)
			var air_delta := Vector2(player_node.position.x - enemy_node.position.x, player_node.position.z - enemy_node.position.z)
			if air_delta.length() > 1.65 and not bool(enemy_node.get_meta("attack_active", false)):
				var air_step := minf(air_delta.length() - 1.65, delta * PLAYER_SPEED * 0.95)
				_move_fighter(enemy_node, player_node, Vector3(air_delta.x, 0.0, air_delta.y).normalized() * air_step)
			if not bool(enemy_node.get_meta("attack_active", false)):
				var flight_pose := "fly_up" if enemy_node.position.y < desired_altitude - 0.15 else "fly_down" if enemy_node.position.y > desired_altitude + 0.15 else "fly_forward" if air_delta.length() > 1.9 else "fly_idle"
				_play_flight_animation(enemy_node, flight_pose)
	else:
		enemy_flight_decision_clock = maxf(0.0, enemy_flight_decision_clock - delta)
		if enemy_flight_decision_clock <= 0.0 and not bool(enemy_node.get_meta("airborne", false)) and not bool(enemy_node.get_meta("attack_active", false)):
			var player_is_airborne := bool(player_node.get_meta("airborne", false))
			var chooses_flight := rng.randf() < (0.78 if player_is_flying or player_is_airborne else 0.16)
			if chooses_flight:
				enemy_node.set_meta("flying", true)
				enemy_node.set_meta("airborne", false)
				enemy_flight_time_left = rng.randf_range(2.5, 4.5)
				_play_flight_animation(enemy_node, "flight_start")
			enemy_flight_decision_clock = rng.randf_range(4.0, 7.0)
	if combo_lab_active:
		_set_locomotion(enemy_node, 0.0)
		return
	if enemy_stun_lock > 0.0:
		_set_locomotion(enemy_node, 0.0)
		ai_state = AIState.STUN
		ai_state_timer = 0.0
		return
	if grapple_victim == enemy_node or grapple_holder == enemy_node:
		_set_locomotion(enemy_node, 0.0)
		return
	if bool(enemy_node.get_meta("attack_active", false)):
		_set_locomotion(enemy_node, 0.0)
		return
	if enemy_guard_timer > 0.0:
		_set_locomotion(enemy_node, 0.0)
		return

	# Update state machine timer
	if ai_state_timer > 0.0:
		ai_state_timer -= delta
		if ai_state_timer <= 0.0:
			ai_state = AIState.IDLE

	# Utility AI decision loop - recalculates every reaction_cooldown
	ai_decision_timer -= delta
	if ai_decision_timer <= 0.0:
		ai_decision_timer = float(_ai_profile().decision_interval)
		_ai_make_decision()

# 🧠 UTILITY AI SCORING (0.0-1.0 dynamic scores based on distance, frame advantage, health, player actions)
func _ai_utility_score(action: String, dist: float, profile: Dictionary, player_airborne: bool, player_attacking: bool, player_recovering: bool, player_blocking: bool, low_health: bool) -> float:
	var score := 0.0
	var reaction := float(profile.reaction_time)

	match action:
		"FLASH_STEP":
			# High utility if distance > 4m and AI health is high
			if not low_health and dist > 4.0:
				score = clamp((dist - 3.0) / 10.0, 0.0, 1.0)
		"PUNISH":
			# High utility if close and player recovering from whiff
			if dist <= 2.5 and player_recovering:
				score = 0.9
		"AIR_LAUNCHER":
			# Max utility if player airborne
			if player_airborne and dist <= 3.0:
				score = 1.0
		"PERFECT_BLOCK":
			# High utility if player attacking and close; apply human reaction delay
			if player_attacking and dist <= 2.0:
				score = 0.85
				if reaction > 0.15:
					score *= 0.6
		"RETREAT":
			# High utility if low health and player close
			if low_health and dist < 2.5:
				score = 0.8
		"ULTIMATE":
			# High utility if meter full and optimal distance
			if enemy_mp >= 4.0:
				score = 0.7 if dist > 3.0 else 0.4
		"GROUND_COMBO":
			# Standard close-range attack
			if dist <= 2.2 and not player_attacking and not player_blocking:
				score = 0.6
		"CHARGE":
			# Charge meter when far and low meter
			if enemy_mp < 1.5 and dist > 1.65:
				score = 0.3
		"IDLE":
			score = 0.1

	return score

# 🏁 FSM EXECUTOR - runs the chosen action and locks into the matching combat state
func _ai_execute_action(action: String, dist: float, profile: Dictionary) -> void:
	match action:
		"FLASH_STEP":
			var dir := (player_node.global_position - enemy_node.global_position)
			dir.y = 0.0
			if dir.length_squared() < 0.0001:
				dir = -enemy_node.global_basis.z
			else:
				dir = dir.normalized()
			_perform_dash(dir)
			ai_state = AIState.DASH
			ai_state_timer = DASH_DURATION
		"PUNISH":
			var punish_move := _ai_select_punish_move(dist)
			if punish_move:
				_apply_move(false, punish_move, dist)
				ai_state = AIState.ATTACK
				ai_state_timer = 0.5
		"AIR_LAUNCHER":
			_apply_move(false, {"name": "Anti-Air", "kind": "attack", "damage": 18, "stun": 16, "cost": 0, "animation": "kick", "aerial": true}, dist)
			ai_state = AIState.AIR_COMBO
			ai_state_timer = 0.8
		"PERFECT_BLOCK":
			_apply_move(false, {"name": "Read and Guard", "kind": "block", "guard": 18, "cost": 0}, dist)
			enemy_guard_timer = float(profile.block_duration)
			enemy_recovery = maxf(enemy_recovery, float(profile.block_duration))
			ai_state = AIState.BLOCK
			ai_state_timer = float(profile.block_duration)
		"RETREAT":
			var away := (enemy_node.global_position - player_node.global_position)
			away.y = 0.0
			if away.length_squared() < 0.0001:
				away = enemy_node.global_basis.z
			else:
				away = away.normalized()
			_perform_dash(away)
			ai_state = AIState.RETREAT
			ai_state_timer = DASH_DURATION
		"ULTIMATE":
			var options := GameData.legends_arts(opponent_data.get("signature", ""), unlocked_ultimates, opponent_style)
			var ultimates: Array[Dictionary] = []
			for move in options:
				if move.get("kind") == "ultimate" and not bool(move.get("locked", false)) and int(move.get("cost", 0)) <= int(enemy_mp):
					ultimates.append(move)
			if not ultimates.is_empty():
				var ultimate_move := ultimates[rng.randi_range(0, ultimates.size() - 1)]
				_apply_move(false, ultimate_move, dist)
				ai_state = AIState.ATTACK
				ai_state_timer = 1.0
		"GROUND_COMBO":
			var options := GameData.legends_arts(opponent_data.get("signature", ""), unlocked_ultimates, opponent_style)
			var attacks: Array[Dictionary] = []
			for move in options:
				if move.get("locked", false) or move.get("kind") not in ["attack", "trap"] or int(move.get("cost", 0)) > int(enemy_mp):
					continue
				attacks.append(move)
			if not attacks.is_empty():
				var basic_move := attacks[rng.randi_range(0, attacks.size() - 1)]
				_apply_move(false, basic_move, dist)
				ai_state = AIState.ATTACK
				ai_state_timer = 0.6
		"CHARGE":
			_apply_move(false, {"name": "Focus", "kind": "charge", "charge": 1.5, "cost": 0, "cue": "FOCUS"}, dist)
			ai_state = AIState.IDLE
			ai_state_timer = 0.8
		"IDLE":
			ai_state = AIState.IDLE
			ai_state_timer = 0.3

# 🎯 UTILITY AI DECISION - picks highest-scoring action every decision_interval
func _ai_make_decision() -> void:
	if not is_instance_valid(enemy_node) or not is_instance_valid(player_node):
		return
	var profile := _ai_profile()
	var dist := enemy_node.global_position.distance_to(player_node.global_position)
	var player_airborne := bool(player_node.get_meta("airborne", false)) or bool(player_node.get_meta("flying", false))
	var player_attacking := bool(player_node.get_meta("attack_active", false))
	var player_recovering := player_recovery > 0.0
	var player_blocking := player_guard > 0.0
	var low_health := enemy_hp <= MAX_HP * 0.35

	# Compute utility scores for each action
	var best_action := "IDLE"
	var max_score := 0.05

	var actions := ["FLASH_STEP", "PUNISH", "AIR_LAUNCHER", "PERFECT_BLOCK", "RETREAT", "ULTIMATE", "GROUND_COMBO", "CHARGE"]
	for action in actions:
		var score := _ai_utility_score(action, dist, profile, player_airborne, player_attacking, player_recovering, player_blocking, low_health)
		# Difficulty modifier
		if ai_difficulty == "Easy":
			score *= rng.randf_range(0.5, 0.8)
		elif ai_difficulty == "Normal":
			score *= rng.randf_range(0.8, 1.0)
		# Hard AI keeps raw scores
		if score > max_score:
			max_score = score
			best_action = action

	_ai_execute_action(best_action, dist, profile)

func _ai_profile() -> Dictionary:
	match ai_difficulty:
		"Easy":
			return {"decision_interval": 0.4, "chase_speed": 0.55, "reaction_time": 0.4, "block_duration": 0.5, "medium_chance": 0.08, "grab_chance": 0.03, "dodge_chance": 0.12, "defense_dodge_rate": 0.22, "ultimate_chance": 0.0, "block_threshold": 0.35, "antiair_chance": 0.05, "whiff_punish_chance": 0.1, "okizeme_chance": 0.05}
		"Hard":
			return {"decision_interval": 0.08, "chase_speed": 1.1, "reaction_time": 0.08, "block_duration": 0.7, "medium_chance": 0.65, "grab_chance": 0.25, "dodge_chance": 0.35, "defense_dodge_rate": 0.48, "ultimate_chance": 0.18, "block_threshold": 0.2, "antiair_chance": 0.4, "whiff_punish_chance": 0.6, "okizeme_chance": 0.5}
		_:
			return {"decision_interval": 0.2, "chase_speed": 0.85, "reaction_time": 0.2, "block_duration": 0.6, "medium_chance": 0.4, "grab_chance": 0.12, "dodge_chance": 0.22, "defense_dodge_rate": 0.34, "ultimate_chance": 0.08, "block_threshold": 0.3, "antiair_chance": 0.2, "whiff_punish_chance": 0.3, "okizeme_chance": 0.2}

func _ai_select_punish_move(distance: float) -> Dictionary:
	var options := GameData.legends_arts(opponent_data.get("signature", ""), unlocked_ultimates, opponent_style)
	var best_move: Dictionary
	var best_range := 0.0
	for move in options:
		if move.get("locked", false) or move.get("kind") not in ["attack", "trap"] or int(move.get("cost", 0)) > int(enemy_mp):
			continue
		var range := _attack_contact_range(move)
		if range <= distance + 0.5 and range > best_range:
			best_range = range
			best_move = move
	if best_move:
		return best_move
	if distance <= 1.5:
		return {"name": "Punish Punch", "kind": "attack", "damage": 14, "stun": 12, "cost": 0, "animation": "punch"}
	elif distance <= 2.0:
		return {"name": "Punish Kick", "kind": "attack", "damage": 18, "stun": 16, "cost": 0, "animation": "kick"}
	return {}


func _apply_move(is_player: bool, move: Dictionary, distance: float) -> void:
	if is_player and (match_over or challenge_active):
		return
	if (is_player and player_stun_lock > 0.0) or (not is_player and enemy_stun_lock > 0.0):
		return
	var source := player_node if is_player else enemy_node
	var target := enemy_node if is_player else player_node
	if grapple_holder == source:
		_resolve_grapple_followup(is_player, str(move.get("grapple_followup", "punch")))
		return
	if grapple_victim == source:
		_attempt_grapple_escape(0.34)
		return
	if is_instance_valid(grapple_holder):
		return
	var character_index := player_character_index if is_player else opponent_character_index
	var character: Dictionary = GameData.CHARACTERS[character_index]
	var source_mp := player_mp if is_player else enemy_mp
	var target_was_guarding := false
	var cost := int(move.get("cost", 0))
	var kind: String = move.get("kind", "attack")
	if is_player and is_charging and kind in ["attack", "trap", "ultimate", "buff"]:
		_set_charging(false)
	if kind in ["attack", "trap", "ultimate"] and (
		bool(source.get_meta("flying", false)) or bool(source.get_meta("airborne", false))
	) and not bool(move.get("aerial", false)):
		move = move.duplicate(true)
		move["aerial"] = true
		move["name"] = "Air " + str(move.get("name", "Attack"))
	if is_player and bool(source.get_meta("attack_active", false)) and kind in ["attack", "trap", "ultimate"]:
		if _can_cancel_attack(source, move):
			source.remove_meta("pending_attack_move")
			_cancel_attack(source)
		else:
			if not source.has_meta("pending_attack_move"):
				source.set_meta("pending_attack_move", move.duplicate(true))
			return
	if is_player and kind == "attack":
		var basic_type := str(move.get("attack_type", ""))
		if basic_type in ["punch", "kick"] and player_basic_combo_clock > 0.0 and player_basic_combo_last_action != basic_type:
			var combo_name := "PUNCH → KICK COMBO" if player_basic_combo_last_action == "punch" else "KICK → PUNCH COMBO"
			move = move.duplicate(true)
			move["name"] = combo_name
			move["damage"] = roundi(float(move.get("damage", 10)) * 1.4)
			move["stun"] = float(move.get("stun", 10)) + 8.0
			move["animation"] = "special_move"
			move["cue"] = combo_name
			move["combo_followup"] = true
			player_basic_combo_last_action = ""
			player_basic_combo_clock = 0.0
			_show_feedback(combo_name)
	if is_player and player_recovery > 0.0 and kind not in ["attack", "trap", "ultimate"]:
		_show_feedback("RECOVERING · WAIT FOR YOUR NEXT MOVE")
		return
	if source_mp < cost:
		_show_feedback("NOT ENOUGH MP · CHARGE OR USE A BASIC MOVE")
		return
	if kind == "dodge" and ((is_player and player_vanish < VANISH_DODGE_COST) or (not is_player and enemy_vanish < VANISH_DODGE_COST)):
		if is_player:
			_show_feedback("VANISH STEP NEEDS 50% · WAIT FOR THE GAUGE")
		return
	if is_player and kind in ["attack", "trap", "ultimate"] and player_is_blocking:
		player_is_blocking = false
		player_guard = 0.0
	var attack_range := _attack_contact_range(move)
	if kind in ["attack", "trap", "ultimate"] and not _has_attack_contact(source, target, move, attack_range):
		_play_fighter_action(source, _attack_animation(move), 0.38)
		_show_feedback("WHIFF · GET CLOSER AND FACE YOUR OPPONENT")
		return

	if is_player:
		player_mp -= cost
		player_combo += 1
	else:
		enemy_mp -= cost
		enemy_combo += 1

	if kind == "charge":
		var gain := float(move.get("charge", 2))
		if is_player:
			player_mp = minf(MAX_MP, player_mp + gain)
		else:
			enemy_mp = minf(MAX_MP, enemy_mp + gain)
		_play_fighter_action(source, "charge", 0.65)
	elif kind == "buff":
		if is_player:
			player_powerup_timer = float(move.get("duration", 4.0))
		else:
			enemy_powerup_timer = float(move.get("duration", 4.0))
		_play_fighter_action(source, "charge", 0.65)
		_show_feedback("POWER SURGE · DAMAGE UP")
		_play_sfx("attack_swing", -16.0, 0.18)
	elif kind == "block":
		if is_player:
			player_guard = float(move.get("guard", 8)) + (6.0 if player_character_index == 8 else 0.0)
		else:
			enemy_guard = float(move.get("guard", 8)) + (6.0 if opponent_character_index == 8 else 0.0)
		_play_fighter_action(source, "block", 0.9)
	elif kind == "dodge":
		if is_player:
			player_vanish -= VANISH_DODGE_COST
			player_vanish_regen_delay = 1.4
		else:
			enemy_vanish -= VANISH_DODGE_COST
			enemy_vanish_regen_delay = 1.4
		var away: Vector3
		if is_player:
			away = (player_node.position - enemy_node.position).normalized()
			_spawn_vanish_burst(source, character.accent)
			_move_fighter(player_node, enemy_node, away * 2.2)
		else:
			away = (enemy_node.position - player_node.position).normalized()
			_spawn_vanish_burst(source, character.accent)
			_move_fighter(enemy_node, player_node, away * 2.2)
		var dodge_combat: Object = source.get_meta("fighter_combat", null)
		if dodge_combat != null:
			dodge_combat.invincible = true
			get_tree().create_timer(0.25).timeout.connect(_clear_dodge_invulnerability.bind(dodge_combat))
		_play_fighter_action(source, "dodge", 0.42)
	elif kind in ["attack", "trap", "ultimate"]:
		if bool(move.get("grab", false)):
			if is_player:
				player_recovery = 0.0
			else:
				enemy_recovery = 0.0
			_animate_attack(source, target, move, false, 0.0, 0.0, is_player, kind, character.accent)
			_update_hud()
			return
		var animation := _attack_animation(move)
		if animation == "punch":
			if is_player:
				player_last_punch_limb = "right" if player_last_punch_limb == "left" else "left"
			else:
				enemy_last_punch_limb = "right" if enemy_last_punch_limb == "left" else "left"
		elif animation == "kick" or animation == "aerial_kick":
			if is_player:
				player_last_kick_limb = "right" if player_last_kick_limb == "left" else "left"
			else:
				enemy_last_kick_limb = "right" if enemy_last_kick_limb == "left" else "left"
		var attack_damage := float(move.get("damage", 8))
		var powerup_active := player_powerup_timer > 0.0 if is_player else enemy_powerup_timer > 0.0
		attack_damage += float(character.bonus_damage)
		var combo_count := player_combo if is_player else enemy_combo
		if character_index == 10 and combo_count == 1:
			attack_damage += 8.0
		if character_index == 9 and str(move.get("tier", "")).to_lower() == "medium":
			attack_damage += 4.0
		if bool(move.get("aerial", false)):
			attack_damage += 4.0
		if kind == "ultimate":
			if bool(move.get("signature", false)):
				attack_damage = MAX_HP * 0.12
			else:
				attack_damage += 8.0 if character_index == 5 else float(character.bonus_damage)
		if bool(move.get("random_damage", false)):
			var roll_a := rng.randi_range(1, 6)
			var roll_b := rng.randi_range(1, 6)
			attack_damage = float(roll_a + roll_b + 4)
			if is_player:
				_show_feedback("LUDo ROLLED %d + %d" % [roll_a, roll_b])
		if kind == "ultimate":
			attack_damage *= 0.65
			if bool(move.get("signature", false)):
				attack_damage = MAX_HP * 0.12
		else:
			attack_damage *= NORMAL_DAMAGE_SCALE
		if powerup_active:
			attack_damage *= 1.25
		var guarded := enemy_guard if is_player else player_guard
		target_was_guarding = guarded > 0.0
		if bool(move.get("grab", false)):
			guarded = 0.0
		if character_index == 11:
			guarded = 0.0
		var damage := maxf(1.0, attack_damage - guarded)
		var stunned: bool = (enemy_stun <= 0.0 if is_player else player_stun <= 0.0)
		if stunned:
			damage += 8.0
		var stun_damage := float(move.get("stun", 10)) + float(character.bonus_stun)
		if character_index == 0 and combo_count == 1:
			stun_damage += 8.0
		if character_index == 9 and str(move.get("tier", "")).to_lower() == "medium":
			stun_damage += 8.0
		if not is_player and player_character_index == 7 and player_guard > 0.0:
			stun_damage *= 0.6
		source.set_meta("attack_active", true)
		player_recovery = 0.0 if is_player else player_recovery
		enemy_recovery = 0.48 if not is_player else enemy_recovery

		# Ultimate special attacks - cinematic, bypass normal animation
		var ultimate_type := str(move.get("ultimate_type", ""))
		if kind == "ultimate" and not ultimate_type.is_empty():
			source.set_meta("attack_state", {
				"target": target,
				"move": move.duplicate(true),
				"target_was_guarding": target_was_guarding,
				"damage": damage,
				"stun_damage": stun_damage,
				"is_player": is_player,
				"kind": kind,
				"accent": character.accent,
				"lunge_start": source.global_position,
				"lunge_complete": true,
				"impact_resolved": false,
				"hitboxes_active": false
			})
			if ultimate_type == "mega_beam":
				_trigger_mega_beam(source, target, move, character.accent)
			elif ultimate_type == "void_vortex":
				_trigger_void_vortex(source, target, move, character.accent)
			elif ultimate_type == "clockwork_pillar":
				_trigger_clockwork_pillar(source, target, move, character.accent)
			elif ultimate_type == "fissure_eruption":
				_trigger_fissure_eruption(source, target, move, character.accent)
			elif ultimate_type == "sonic_domain":
				_trigger_sonic_domain(source, target, move, character.accent)
			_update_hud()
			return

		_animate_attack(source, target, move, target_was_guarding, damage, stun_damage, is_player, kind, character.accent)
	_update_hud()

func _set_locomotion(fighter: Node3D, speed: float) -> void:
	if not is_instance_valid(fighter):
		return
	fighter.set_meta("locomotion_speed", clampf(speed, 0.0, 1.0))
	if str(fighter.get_meta("anim_action", "idle")) != "idle":
		return
	var animation_name := "idle"
	if crouch_enabled and fighter == player_node:
		animation_name = "idle"
	elif speed >= 0.86:
		animation_name = "walk"
	elif speed > 0.05:
		animation_name = "walk"
	var animation_player := fighter.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if is_instance_valid(animation_player) and animation_player.current_animation != animation_name:
		animation_player.speed_scale = 1.0
		animation_player.play(animation_name, 0.18)

func _start_grapple(is_player: bool, holder: Node3D, victim: Node3D) -> void:
	_play_sfx("hit_soft", -8.0, 0.04)
	grapple_holder = holder
	grapple_victim = victim
	grapple_holder_is_player = is_player
	grapple_timer = GRAPPLE_DURATION
	grapple_escape_progress = 0.0
	_update_grapple(0.0)
	_play_fighter_action(holder, "grab_hold", GRAPPLE_DURATION + 0.2)
	_play_fighter_action(victim, "grabbed", GRAPPLE_DURATION + 0.2)
	_show_feedback("GRAPPLE · PUNCH OR KICK TO THROW · MOVE OR MASH ATTACK TO BREAK FREE")
	# _show_move_cue(victim, "GRABBED", Color("#ffcf70"))

func _update_grapple(delta: float) -> void:
	if not is_instance_valid(grapple_holder) or not is_instance_valid(grapple_victim):
		_clear_grapple()
		return
	grapple_timer -= delta
	var forward := grapple_holder.global_basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.0001:
		forward = forward.normalized()
		grapple_victim.global_position = grapple_holder.global_position + forward * 0.82
		_face_fighter(grapple_victim, grapple_holder, delta)
	if grapple_timer <= 0.0:
		_resolve_grapple_followup(grapple_holder_is_player, "throw")

func _attempt_grapple_escape(progress: float) -> void:
	if grapple_victim != player_node:
		return
	grapple_escape_progress += progress
	_show_feedback("BREAK FREE · %d%%" % int(minf(grapple_escape_progress / GRAPPLE_ESCAPE_THRESHOLD, 1.0) * 100.0))
	if grapple_escape_progress >= GRAPPLE_ESCAPE_THRESHOLD:
		var holder := grapple_holder
		_clear_grapple()
		_play_fighter_action(player_node, "dodge", 0.42)
		if is_instance_valid(holder):
			_play_fighter_action(holder, "hit_react", 0.38)
		player_recovery = 0.0
		enemy_recovery = 0.35
		_show_feedback("GRAPPLE BROKEN · YOU ESCAPED")

func _resolve_grapple_followup(is_player: bool, action: String) -> void:
	if not is_instance_valid(grapple_holder) or not is_instance_valid(grapple_victim):
		_clear_grapple()
		return
	if (grapple_holder == player_node) != is_player:
		return
	var holder := grapple_holder
	var victim := grapple_victim
	var did_throw := action == "throw"
	if is_player:
		_record_combo_move("Throw" if did_throw else "Grapple Punch")
	var damage := MAX_HP * (0.08 if did_throw else 0.04)
	if did_throw:
		var away := victim.position - holder.position
		away.y = 0.0
		if away.length_squared() < 0.0001:
			away = Vector3.RIGHT if holder == player_node else Vector3.LEFT
		_move_fighter(victim, holder, away.normalized() * 2.0)
	_clear_grapple()
	if did_throw:
		_play_sfx("hit_heavy", -6.0, 0.04)
		_play_fighter_action(holder, "throw", 0.5)
		_play_fighter_action(victim, "hit_react", 0.55)
		_show_feedback("THROW · %d DAMAGE" % int(damage))
	else:
		_play_sfx("hit_medium", -7.0, 0.04)
		_play_fighter_action(holder, "punch", 0.42)
		_play_fighter_action(victim, "hit_react", 0.38)
		_show_feedback("GRAPPLE PUNCH · %d DAMAGE" % int(damage))
	if is_player:
		enemy_hp = maxf(0.0, enemy_hp - damage)
		enemy_stun = maxf(0.0, enemy_stun - (18.0 if did_throw else 12.0))
		enemy_recovery = 0.85
		player_recovery = 0.55
		if enemy_hp <= 0.0:
			_end_match(true)
	else:
		player_hp = maxf(0.0, player_hp - damage)
		player_stun = maxf(0.0, player_stun - (18.0 if did_throw else 12.0))
		player_recovery = 0.85
		enemy_recovery = 0.55
		if player_hp <= 0.0:
			_end_match(false)
	_update_hp_bars()
	_update_hud()

func _clear_grapple() -> void:
	grapple_holder = null
	grapple_victim = null
	grapple_holder_is_player = false
	grapple_timer = 0.0
	grapple_escape_progress = 0.0

func _resolve_clip_name(fighter: Node3D, action: String) -> String:
	var animation_player := fighter.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if not is_instance_valid(animation_player):
		return "idle"
	var clip_name := ""
	var is_player_fighter := fighter == player_node
	match action:
		"idle":
			clip_name = "idle"
		"punch":
			var attack_count := int(fighter.get_meta("attack_count", 0))
			var punch_clips: Array[String] = ["jab", "cross", "hook", "uppercut"]
			clip_name = punch_clips[posmod(attack_count - 1, punch_clips.size())]
		"kick":
			var kick_clips: Array[String] = ["kick_front", "kick_round", "sweep", "kick_flying"]
			clip_name = kick_clips[posmod(int(fighter.get_meta("attack_count", 1)) - 1, kick_clips.size())]
		"aerial_kick":
			clip_name = "kick_flying"
		"aerial_punch":
			clip_name = "cross"
		"back_kick":
			clip_name = "kick_round"
		"grab":
			clip_name = "grab"
		"grab_hold":
			clip_name = "grab"
		"grabbed":
			clip_name = "hit_heavy"
		"throw":
			clip_name = "throw"
		"block":
			clip_name = "block"
		"block_hit":
			clip_name = "block_hit"
		"charge":
			clip_name = "charge"
		"dodge":
			clip_name = "dodge"
		"jump":
			clip_name = "jump"
		"flight_start":
			clip_name = "flight_start"
		"flight_stop":
			clip_name = "flight_stop"
		"hit_react":
			clip_name = "hit_light"
		"victory":
			clip_name = "victory"
		"knockout":
			clip_name = "ko"
		_:
			clip_name = action.to_lower()
	if not animation_player.has_animation(clip_name):
		var fallbacks := {
			"punch": "jab", "light_combo_1": "jab", "light_combo_2": "cross", "light_combo": "jab",
			"aerial_attack": "kick_flying", "vanish_step": "dodge", "dash_back": "dodge",
			"awakened_arts": "victory", "special_move": "kick_round", "ki_blast": "hadoken", "beam": "hadoken",
			"beam_fire": "hadoken", "hadoken_kick": "hadoken", "strike_arts": "kick_round", "rising_rush": "uppercut",
			"kick": "kick_front", "heavy_attack": "hook", "hit": "hit_light", "knockback": "hit_heavy",
		}
		clip_name = str(fallbacks.get(clip_name, "idle"))
		if not animation_player.has_animation(clip_name):
			clip_name = "idle"
	return clip_name

func _play_fighter_action(fighter: Node3D, action: String, duration: float) -> void:
	if not is_instance_valid(fighter):
		return
	var animation_player := fighter.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if not is_instance_valid(animation_player):
		push_error("Fighter animation player is missing for %s." % fighter.name)
		return
	var clip_name := _resolve_clip_name(fighter, action)
	var clip := animation_player.get_animation(clip_name)
	var action_duration := maxf(duration, 0.05)
	var action_generation := int(fighter.get_meta("action_generation", 0)) + 1
	fighter.set_meta("action_generation", action_generation)
	fighter.set_meta("anim_action", action)
	fighter.set_meta("anim_elapsed", 0.0)
	fighter.set_meta("anim_duration", action_duration)
	animation_player.speed_scale = clip.length / action_duration if action not in ["victory", "knockout", "flight"] else 1.0
	if action in ["grab_hold", "grabbed", "flight"]:
		animation_player.speed_scale = 1.0
	animation_player.play(clip_name, 0.0 if action in ["punch", "kick", "grab"] else 0.1)

func _update_fighter_animations(delta: float) -> void:
	for fighter in [player_node, enemy_node]:
		if not is_instance_valid(fighter):
			continue
		if fighter == player_node and is_charging:
			var charge_aura := fighter.get_node_or_null("KiChargeAura") as Node3D
			if is_instance_valid(charge_aura):
				charge_aura.rotation.y += delta * 2.8
				var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.06
				charge_aura.scale = Vector3.ONE * pulse
		var action := str(fighter.get_meta("anim_action", "idle"))
		var flying := bool(fighter.get_meta("flying", false))
		if flying and action == "flight":
			continue
		if not flying and not bool(fighter.get_meta("airborne", false)) and absf(fighter.position.y) > 0.001:
			fighter.position.y = 0.0
		if action in ["idle", "victory", "knockout"]:
			if not bool(fighter.get_meta("airborne", false)) and not flying:
				continue
		var airborne := bool(fighter.get_meta("airborne", false))
		var remaining_air_time := 0.0
		if airborne:
			var air_elapsed := float(fighter.get_meta("air_elapsed", 0.0)) + delta
			var air_duration := float(fighter.get_meta("air_duration", JUMP_DURATION))
			fighter.set_meta("air_elapsed", air_elapsed)
			var gravity := float(fighter.get_meta("air_gravity", AIR_GRAVITY))
			if fighter == player_node and Input.is_action_pressed("move_back"):
				gravity *= 2.6
			var vertical_speed := float(fighter.get_meta("launch_velocity", 0.0)) - gravity * delta
			var next_height: float = fighter.position.y + vertical_speed * delta
			fighter.set_meta("launch_velocity", vertical_speed)
			remaining_air_time = maxf(0.0, air_duration - air_elapsed)
			# Wall bounce
			_apply_wall_bounce(fighter, Vector3.ZERO)
			if next_height <= 0.0 and vertical_speed <= 0.0:
				fighter.position.y = 0.0
				fighter.set_meta("airborne", false)
				fighter.set_meta("launch_velocity", 0.0)
				fighter.set_meta("air_elapsed", 0.0)
				airborne = false
				remaining_air_time = 0.0
				if action == "jump":
					_play_fighter_action(fighter, "recovery", 0.28)
					continue
			else:
				fighter.position.y = maxf(0.0, next_height)
		var elapsed := float(fighter.get_meta("anim_elapsed", 0.0)) + delta
		var duration := float(fighter.get_meta("anim_duration", 0.0))
		var rig := fighter.get_node_or_null("Stickman_Rig") as Node3D
		if is_instance_valid(rig):
			var base_y := float(fighter.get_meta("kick_rig_base_y", rig.position.y))
			if action == "kick" and duration > 0.0:
				var kick_progress := clampf(elapsed / duration, 0.0, 1.0)
				if kick_progress < 0.6:
					rig.position.y = base_y + 0.06 * sin(PI * kick_progress / 0.6)
				else:
					rig.position.y = base_y
			else:
				rig.position.y = base_y
		if action == "grab_hold" or action == "grabbed":
			fighter.set_meta("anim_elapsed", fmod(elapsed, maxf(duration, 0.05)))
			continue
		if action == "block":
			fighter.set_meta("anim_elapsed", elapsed)
			var block_player := fighter.get_node_or_null("AnimationPlayer") as AnimationPlayer
			if is_instance_valid(block_player) and not block_player.is_playing():
				block_player.play(block_player.current_animation)
			continue
		if elapsed >= duration:
			if airborne and remaining_air_time > 0.0:
				_play_fighter_action(fighter, "jump", remaining_air_time)
				continue
			fighter.set_meta("anim_action", "idle")
			fighter.set_meta("anim_elapsed", 0.0)
			var animation_player := fighter.get_node_or_null("AnimationPlayer") as AnimationPlayer
			if is_instance_valid(animation_player):
				animation_player.speed_scale = 1.0
			_set_locomotion(fighter, float(fighter.get_meta("locomotion_speed", 0.0)))
		else:
			fighter.set_meta("anim_elapsed", elapsed)

func _animate_attack(source: Node3D, target: Node3D, move: Dictionary, target_was_guarding: bool, damage: float, stun_damage: float, is_player: bool, kind: String, accent: Color) -> void:
	var animation := _attack_animation(move)
	_play_sfx("attack_swing", -13.0, 0.08)
	source.set_meta("attack_count", int(source.get_meta("attack_count", 0)) + 1)
	var action := "aerial_kick" if animation == "kick" and bool(move.get("aerial", false)) else ("aerial_punch" if animation == "punch" and bool(move.get("aerial", false)) else ("back_kick" if animation == "kick" and bool(move.get("back_kick", false)) else animation))
	var attack_clip := _resolve_clip_name(source, action)
	var frame_data := _attack_frame_data(animation, move, attack_clip)
	var duration := float(frame_data.total_frames) / 60.0
	_play_fighter_action(source, action, duration)
	source.set_meta("attack_active", true)
	source.set_meta("attack_connected", false)
	var direction := target.global_position - source.global_position
	direction.y = 0.0
	var distance := direction.length()
	if distance < 0.001:
		direction = source.global_basis.z
		direction.y = 0.0
	direction = direction.normalized()
	var desired_lunge := maxf(0.0, distance - (ATTACK_CONTACT_DISTANCE - 0.04))
	var max_lunge := 1.8 if bool(move.get("aerial", false)) else 1.35
	var lunge_distance := minf(desired_lunge, max_lunge)
	if bool(move.get("projectile", false)):
		lunge_distance = 0.0
	var lunge_start := source.global_position
	var generation := int(source.get_meta("action_generation", 0))
	var is_player_fighter := source == player_node
	var hit_type := "punch"
	var attack_limb := ""
	if str(move.get("attack_type", "")) == "kick" or animation in ["kick", "aerial_kick"]:
		hit_type = "kick"
		attack_limb = player_last_kick_limb if is_player_fighter else enemy_last_kick_limb
	elif bool(move.get("grab", false)):
		hit_type = "grab"
	else:
		hit_type = "punch"
		attack_limb = player_last_punch_limb if is_player_fighter else enemy_last_punch_limb
	source.set_meta("attack_state", {
		"target": target,
		"move": move.duplicate(true),
		"target_was_guarding": target_was_guarding,
		"damage": damage,
		"stun_damage": stun_damage,
		"is_player": is_player,
		"kind": kind,
		"accent": accent,
		"lunge_start": lunge_start,
		"frame_data": frame_data,
		"clip": attack_clip,
		"lunge_complete": lunge_distance <= 0.04,
		"impact_resolved": false,
		"hit_type": hit_type,
		"attack_limb": attack_limb,
		"hitboxes_active": false
	})
	if bool(move.get("projectile", false)):
		var projectile_start := source.global_position + Vector3.UP * (1.05 if not bool(move.get("signature", false)) else 1.2) + direction * 0.42
		var projectile_end := target.global_position + Vector3.UP * (1.05 if not bool(move.get("signature", false)) else 1.2)
		var orb := MeshInstance3D.new()
		orb.name = "EnergyProjectile"
		var sphere := SphereMesh.new()
		sphere.radius = 0.22 if not bool(move.get("signature", false)) else 0.42
		sphere.height = sphere.radius * 2.0
		orb.mesh = sphere
		var projectile_color := accent
		var move_name := str(move.get("name", "")).to_lower()
		if move_name.contains("kamehameha"):
			projectile_color = Color("#68caff")
		elif move_name.contains("final flash"):
			projectile_color = Color("#ffe56d")
		var energy_material := StandardMaterial3D.new()
		energy_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		energy_material.albedo_color = projectile_color
		energy_material.emission_enabled = true
		energy_material.emission = projectile_color
		energy_material.emission_energy_multiplier = 2.8 if not bool(move.get("signature", false)) else 4.5
		orb.material_override = energy_material
		var streak := MeshInstance3D.new()
		var streak_mesh := CylinderMesh.new()
		streak_mesh.top_radius = 0.08 if not bool(move.get("signature", false)) else 0.12
		streak_mesh.bottom_radius = 0.13 if not bool(move.get("signature", false)) else 0.22
		streak_mesh.height = 0.65 if not bool(move.get("signature", false)) else 1.6
		streak.mesh = streak_mesh
		streak.material_override = energy_material
		streak.rotation.x = PI / 2.0
		orb.add_child(streak)
		var orb_light := OmniLight3D.new()
		orb_light.light_color = projectile_color
		orb_light.light_energy = 2.0 if not bool(move.get("signature", false)) else 4.0
		orb_light.omni_range = 2.2 if not bool(move.get("signature", false)) else 4.0
		orb_light.shadow_enabled = false
		orb.add_child(orb_light)
		arena_root.add_child(orb)
		orb.global_position = projectile_start
		orb.look_at(projectile_end, Vector3.UP)
		var fire_delay := float(frame_data.get("fire_frame", 0.0)) / 60.0
		if fire_delay > 0.0:
			orb.visible = false
		var travel_time := clampf(projectile_start.distance_to(projectile_end) / (22.0 if not bool(move.get("signature", false)) else 27.0), 0.16, 0.58)
		var projectile_tween := create_tween()
		if fire_delay > 0.0:
			projectile_tween.tween_interval(fire_delay)
			projectile_tween.tween_callback(orb.show)
		projectile_tween.tween_property(orb, "global_position", projectile_end, travel_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		projectile_tween.tween_callback(_on_energy_projectile_arrived.bind(orb, source, target, move.duplicate(true), target_was_guarding, damage, stun_damage, is_player, kind, accent, lunge_start, projectile_end, generation))
		return
	if lunge_distance <= 0.04:
		return
	var lunge_duration := minf(float(frame_data.startup_frames) / 60.0, lunge_distance / STRIKE_LUNGE_SPEED)
	var lunge_end := lunge_start + direction * lunge_distance
	var motion_tween := create_tween()
	motion_tween.tween_property(source, "global_position", lunge_end, lunge_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	motion_tween.tween_callback(_mark_attack_lunge_complete.bind(source, generation))

func _attack_frame_data(animation: String, move: Dictionary, clip: String = "") -> Dictionary:
	if not bool(move.get("projectile", false)) and ClipFrameData.has(clip):
		return ClipFrameData.frame_data(clip)
	var startup_frames := 4
	var active_frames := 2
	var recovery_frames := 10
	match animation:
		"hadoken", "ki_blast", "beam", "beam_fire":
			startup_frames = 8
			active_frames = 52
			recovery_frames = 12
		"kick":
			startup_frames = 7
			active_frames = 3
			recovery_frames = 12
		"rising_rush":
			startup_frames = 5
			active_frames = 3
			recovery_frames = 15
		"grab":
			startup_frames = 5
			active_frames = 2
			recovery_frames = 11
		_:
			if str(move.get("kind", "attack")) in ["trap", "ultimate"]:
				startup_frames = 7
				active_frames = 3
				recovery_frames = 14
	var total_frames := startup_frames + active_frames + recovery_frames
	return {
		"startup_frames": startup_frames,
		"active_frames": active_frames,
		"recovery_frames": recovery_frames,
		"total_frames": total_frames,
		"fire_frame": ClipFrameData.fire_frame(clip, total_frames) if bool(move.get("projectile", false)) else 0.0
	}

func _mark_attack_lunge_complete(source: Variant, generation: int) -> void:
	if not is_instance_valid(source) or int(source.get_meta("action_generation", -1)) != generation:
		return
	var state: Dictionary = source.get_meta("attack_state", {})
	if state.is_empty():
		return
	state["lunge_complete"] = true
	source.set_meta("attack_state", state)

func _on_energy_projectile_arrived(orb: Variant, source: Variant, target: Variant, move: Dictionary, target_was_guarding: bool, damage: float, stun_damage: float, is_player: bool, kind: String, accent: Color, lunge_start: Vector3, aimed_position: Vector3, generation: int) -> void:
	if is_instance_valid(orb):
		orb.queue_free()
	if not is_instance_valid(source) or not is_instance_valid(target) or int(source.get_meta("action_generation", -1)) != generation:
		return
	var state: Dictionary = source.get_meta("attack_state", {})
	if state.is_empty():
		return
	var target_combat: Object = target.get_meta("fighter_combat", null)
	var evaded: bool = target.global_position.distance_to(aimed_position) > 1.15
	if target_combat != null:
		evaded = evaded or bool(target_combat.invincible)
	if evaded:
		state["impact_resolved"] = true
		state["previous_frame"] = float(state.frame_data.total_frames)
		source.set_meta("attack_state", state)
		_show_feedback("VANISH STEP · EVADED")
		return
	state["projectile_hit"] = true
	state["impact_resolved"] = true
	state["previous_frame"] = float(state.frame_data.total_frames)
	source.set_meta("attack_state", state)
	_spawn_lightning_bolt(orb.global_position, target.global_position, accent, 10, 0.2)
	_spawn_shell_casing(orb.global_position, -orb.global_basis.z, 2)
	_resolve_attack_impact(source, target, move, target_was_guarding, damage, stun_damage, is_player, kind, accent, lunge_start)

func _advance_attack_states() -> void:
	for fighter in [player_node, enemy_node]:
		if not is_instance_valid(fighter) or not bool(fighter.get_meta("attack_active", false)):
			continue
		var state: Dictionary = fighter.get_meta("attack_state", {})
		if state.is_empty():
			continue
		var frame_data: Dictionary = state.frame_data
		var frame := _attack_progress_frames(fighter, state)
		var impact_frame := float(frame_data.startup_frames)
		var active_end_frame := impact_frame + float(frame_data.active_frames)
		var previous_frame := float(state.get("previous_frame", 0.0))
		var hitboxes_active := bool(state.get("hitboxes_active", false))
		var is_projectile: bool = bool(state.get("move", {}).get("projectile", false))
		if not is_projectile and not hitboxes_active and frame >= impact_frame:
			_activate_hitboxes(fighter, str(state.get("hit_type", "punch")), true, str(state.get("attack_limb", "")))
			state["hitboxes_active"] = true
			fighter.set_meta("attack_state", state)
		elif not is_projectile and hitboxes_active and frame > active_end_frame:
			_activate_hitboxes(fighter, "all", false)
			state["hitboxes_active"] = false
			fighter.set_meta("attack_state", state)
		if not is_projectile and not bool(state.impact_resolved) and frame >= impact_frame and previous_frame <= active_end_frame and bool(state.lunge_complete):
			state["impact_resolved"] = true
			state["previous_frame"] = frame
			fighter.set_meta("attack_state", state)
			_resolve_attack_impact(
				fighter,
				state.target,
				state.move,
				state.target_was_guarding,
				state.damage,
				state.stun_damage,
				state.is_player,
				state.kind,
				state.accent,
				state.lunge_start
			)
			state = fighter.get_meta("attack_state", {})
		if not is_instance_valid(fighter):
			continue
		if not state.is_empty():
			state["previous_frame"] = frame
			fighter.set_meta("attack_state", state)
		var queued_cancel: Dictionary = fighter.get_meta("pending_attack_move", {})
		if fighter == player_node and not queued_cancel.is_empty() and _can_cancel_attack(fighter, queued_cancel):
			fighter.remove_meta("pending_attack_move")
			_cancel_attack(fighter)
			call_deferred("_start_buffered_player_move", queued_cancel)
			continue
		var action_finished := str(fighter.get_meta("anim_action", "idle")) == "idle"
		if action_finished or frame >= float(frame_data.total_frames):
			_activate_hitboxes(fighter, "all", false)
			fighter.set_meta("attack_active", false)
			fighter.set_meta("attack_state", {})
			if fighter == player_node:
				var queued_move: Dictionary = fighter.get_meta("pending_attack_move", {})
				fighter.remove_meta("pending_attack_move")
				if not queued_move.is_empty():
					call_deferred("_start_buffered_player_move", queued_move)

## Current position inside the attack, in game frames (60 fps). Read from the clip's own playhead so
## hitboxes, hit-stop freezes and cancels always stay in step with what the player sees.
func _attack_progress_frames(fighter: Node3D, state: Dictionary) -> float:
	var frame_data: Dictionary = state.get("frame_data", {})
	var total := float(frame_data.get("total_frames", 1))
	var animation_player := fighter.get_node_or_null("AnimationPlayer") as AnimationPlayer
	var clip_name := str(state.get("clip", ""))
	if is_instance_valid(animation_player) and not clip_name.is_empty() \
			and animation_player.current_animation == clip_name and animation_player.current_animation_length > 0.0:
		return animation_player.current_animation_position / animation_player.current_animation_length * total
	return float(fighter.get_meta("anim_elapsed", 0.0)) * 60.0

## 1 light punch, 2 kick, 3 launcher / heavy, 4 special or ultimate.
func _move_cancel_rank(move: Dictionary) -> int:
	if bool(move.get("projectile", false)) or str(move.get("kind", "attack")) in ["ultimate", "trap"] or bool(move.get("multi_hit", false)):
		return 4
	if bool(move.get("launcher", false)) or str(move.get("animation", "")) == "rising_rush":
		return 3
	var attack_type := str(move.get("attack_type", ""))
	if attack_type == "punch":
		return 1
	return 2

## A connected normal can be cancelled into the same or a stronger move while its cancel window is open.
func _can_cancel_attack(fighter: Node3D, next_move: Dictionary) -> bool:
	if not bool(fighter.get_meta("attack_active", false)) or not bool(fighter.get_meta("attack_connected", false)):
		return false
	var state: Dictionary = fighter.get_meta("attack_state", {})
	if state.is_empty():
		return false
	var frame_data: Dictionary = state.get("frame_data", {})
	if not frame_data.has("cancel_end_frame"):
		return false
	var current_rank := int(frame_data.get("rank", 4))
	if current_rank >= 4 or _move_cancel_rank(next_move) < current_rank:
		return false
	var frame := _attack_progress_frames(fighter, state)
	return frame >= float(frame_data.cancel_start_frame) and frame <= float(frame_data.cancel_end_frame)

func _cancel_attack(fighter: Node3D) -> void:
	_activate_hitboxes(fighter, "all", false)
	fighter.set_meta("attack_active", false)
	fighter.set_meta("attack_state", {})
	# _show_move_cue(fighter, "CANCEL", Color("#ffd166"))

func _start_buffered_player_move(move: Dictionary) -> void:
	if match_over or challenge_active or not is_instance_valid(player_node) or not is_instance_valid(enemy_node):
		return
	_apply_move(true, move, player_node.global_position.distance_to(enemy_node.global_position))

func _resolve_attack_impact(source: Node3D, target: Node3D, move: Dictionary, target_was_guarding: bool, damage: float, stun_damage: float, is_player: bool, kind: String, accent: Color, lunge_start: Vector3) -> void:
	if not is_instance_valid(source) or not is_instance_valid(target):
		return
	var resolving_combo_practice := combo_lab_active and is_player
	var attack_state: Dictionary = source.get_meta("attack_state", {})
	var hitbox_hit := bool(attack_state.get("hitbox_hit", false))
	var hit_damage_mult := float(attack_state.get("hit_damage_mult", 1.0))
	if bool(move.get("projectile", false)) and not bool(attack_state.get("projectile_hit", false)):
		return
	if not bool(move.get("projectile", false)) and not hitbox_hit and not _has_attack_contact(source, target, move, ATTACK_CONTACT_DISTANCE + 0.08):
		source.set_meta("attack_active", false)
		source.set_meta("attack_state", {})
		var retreat := create_tween()
		retreat.tween_property(source, "global_position", lunge_start, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if is_player and is_instance_valid(combo_lab):
			combo_lab.call("record_missed_move")
		_show_feedback("WHIFF · THE ATTACK DID NOT CONNECT")
		return
	source.set_meta("attack_connected", true)
	if is_player:
		_record_combo_move(_combo_step_name(move))
	if is_player:
		var landed_basic_type := str(move.get("attack_type", ""))
		if landed_basic_type in ["punch", "kick"]:
			player_basic_combo_last_action = landed_basic_type
			player_basic_combo_clock = 1.0
		else:
			player_basic_combo_last_action = ""
			player_basic_combo_clock = 0.0
	if is_player:
		player_mp = minf(MAX_MP, player_mp + ATTACK_MP_GAIN)
	else:
		enemy_mp = minf(MAX_MP, enemy_mp + ATTACK_MP_GAIN)
	_update_hud()
	if bool(move.get("grab", false)):
		source.set_meta("attack_active", false)
		source.set_meta("attack_state", {})
		if is_player:
			player_recovery = 0.0
			enemy_recovery = 0.0
		else:
			enemy_recovery = 0.0
			player_recovery = 0.0
		_start_grapple(is_player, source, target)
		return

	var current_target_guard := player_guard if target == player_node else enemy_guard
	var attacker_character_index := player_character_index if source == player_node else opponent_character_index
	if current_target_guard > 0.0 and not target_was_guarding and attacker_character_index != 11:
		damage = maxf(1.0, damage - current_target_guard)
		target_was_guarding = true

	damage *= hit_damage_mult
	stun_damage *= hit_damage_mult

	var is_counter_hit := false
	if bool(target.get_meta("attack_active", false)) and not target_was_guarding:
		var target_state: Dictionary = target.get_meta("attack_state", {})
		var target_frame := float(target.get_meta("anim_elapsed", 0.0)) * 60.0
		var target_frame_data: Dictionary = target_state.get("frame_data", {})
		if not target_frame_data.is_empty() and target_frame < float(target_frame_data.startup_frames):
			is_counter_hit = true
			damage *= 1.25
			stun_damage *= 1.5
			_show_feedback("COUNTER HIT!")

	var hit_sound := "hit_heavy" if kind == "ultimate" else ("hit_soft" if target_was_guarding else "hit_medium")
	_play_sfx(hit_sound, -6.0, 0.06)
	var attack_clip := str(attack_state.get("clip", ""))
	var strong_hit := kind == "ultimate" or ClipFrameData.rank(attack_clip) >= 3 or damage >= 18.0
	var react_clip := "block_hit"
	if not target_was_guarding:
		react_clip = "hit_heavy" if kind == "ultimate" else ClipFrameData.react_clip(attack_clip, "hit_heavy" if strong_hit else "hit_light")
	_play_fighter_action(target, react_clip, 0.55 if react_clip == "hit_heavy" else 0.32)

	# Hit-stop: a short freeze that scales with how hard the move is. Heavier, countered and
	# killing blows freeze longer; blocked hits freeze less.
	var stop_frames := ClipFrameData.hitstop_frames(attack_clip)
	if kind == "ultimate":
		stop_frames = maxf(stop_frames, ClipFrameData.ULTIMATE_HITSTOP_FRAMES)
	if target_was_guarding:
		stop_frames *= 0.6
	if is_counter_hit:
		stop_frames *= 1.5
	var will_ko := (enemy_hp - damage <= 0.0) if is_player else (player_hp - damage <= 0.0)
	if will_ko and not resolving_combo_practice:
		stop_frames = maxf(stop_frames, ClipFrameData.KO_HITSTOP_FRAMES)
	var stop_seconds := stop_frames / 60.0
	if hit_stop_controller:
		hit_stop_controller.apply_hit_stop(stop_seconds)
	_hit_shake(target, stop_seconds, 0.015 if target_was_guarding else 0.035)

	var impact_position := source.global_position.lerp(target.global_position, 0.5)
	_spawn_impact_flash(impact_position, accent, target_was_guarding)
	camera_shake_strength = maxf(camera_shake_strength, 0.1 if target_was_guarding else (0.35 if is_counter_hit else 0.24))
	_spawn_damage_number(target, damage, is_counter_hit, target_was_guarding)
	_spawn_hit_particles(impact_position, accent, target_was_guarding, is_counter_hit)
	_spawn_weapon_trail(source.global_position, impact_position, accent, 0.8)
	_spawn_impact_sparks(impact_position, (target.global_position - source.global_position).normalized(), accent, 10 if is_counter_hit else 6)
	_trigger_anime_hit(impact_position, accent, kind == "ultimate" or damage >= 18.0, is_counter_hit)
	if is_counter_hit or (kind == "ultimate"):
		_trigger_silhouette_flash(target, 0.06)
		_spawn_blood_splatter(impact_position, 10 if is_counter_hit else 6)
	if is_player:
		if not resolving_combo_practice:
			enemy_hp = maxf(0.0, enemy_hp - damage)
			enemy_stun = maxf(0.0, enemy_stun - stun_damage)
		enemy_guard = 0.0
		enemy_recovery = (0.85 if kind == "trap" else 0.65) if not resolving_combo_practice else 0.0
		enemy_combo = 0
		if combo_tracker:
			combo_tracker.drop_combo()
		player_recovery = 0.0
		var combo_count := int(enemy_node.get_meta("combo_count", 0)) + 1
		enemy_node.set_meta("combo_count", combo_count)
		
		# Use ComboTracker for damage scaling
		if combo_tracker:
			if combo_count == 1:
				combo_tracker.start_combo()
			damage = combo_tracker.add_hit(int(damage))
		
		_update_combo_ui(combo_count, true)
		if enemy_stun <= 0.0 and enemy_stun_lock <= 0.0:
			enemy_stun_lock = 3.0
			enemy_recovery = maxf(enemy_recovery, 3.0)
			_show_feedback("OPPONENT BREAK · 3 SECONDS TO ATTACK")
	else:
		player_hp = maxf(0.0, player_hp - damage)
		player_stun = maxf(0.0, player_stun - stun_damage)
		player_guard = 12.0 + (6.0 if player_character_index == 8 else 0.0) if player_is_blocking else 0.0
		player_recovery = 0.65
		player_combo = 0
		if combo_tracker:
			combo_tracker.drop_combo()
		enemy_recovery = 0.35
		var combo_count := int(player_node.get_meta("combo_count", 0)) + 1
		player_node.set_meta("combo_count", combo_count)
		
		# Use ComboTracker for damage scaling
		if combo_tracker:
			if combo_count == 1:
				combo_tracker.start_combo()
			damage = combo_tracker.add_hit(int(damage))
		
		_update_combo_ui(combo_count, false)
		if player_stun <= 0.0 and player_stun_lock <= 0.0:
			player_stun_lock = 3.0
			player_recovery = maxf(player_recovery, 3.0)
			_show_feedback("STUN BREAK · 3 SECONDS TO RECOVER")
	_activate_hitboxes(source, "all", false)
	_update_hp_bars()
	# _show_move_cue(target, str(move.get("cue", move.get("name", "HIT"))), accent)
	_show_feedback("%s · %d DAMAGE" % [move.get("name", "HIT"), int(damage)])
	var away := target.global_position - source.global_position
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = -source.global_basis.z
	if resolving_combo_practice:
		_update_hud()
		return
	var attack_anim := _attack_animation(move)
	var is_launcher := bool(move.get("launcher", false)) or (attack_anim == "kick" and not target_was_guarding and damage > 20.0)
	var knockback := 0.12 if target_was_guarding else 0.28 + minf(float(move.get("damage", 8)) * 0.01, 0.42)
	var authored_knockback := ClipFrameData.knockback(attack_clip, -1.0)
	if authored_knockback >= 0.0:
		knockback = authored_knockback * (0.4 if target_was_guarding else 1.0)
	if is_counter_hit:
		knockback *= 1.25
	if kind == "ultimate":
		knockback *= 1.5
	var launch_velocity := 0.0
	if is_launcher and target.position.y <= 0.05:
		launch_velocity = 8.0 + damage * 0.08
		target.set_meta("airborne", true)
		target.set_meta("air_elapsed", 0.0)
		target.set_meta("air_gravity", AIR_GRAVITY)
		target.set_meta("air_duration", launch_velocity / AIR_GRAVITY * 2.0)
		target.set_meta("launch_velocity", launch_velocity)
		target.set_meta("juggle_decay", float(target.get_meta("juggle_decay", 0.0)) + 0.15)

	# Downward slam finisher: airborne attacker hits grounded target with heavy/kick
	var is_airborne_attacker := bool(source.get_meta("airborne", false)) or bool(source.get_meta("flying", false))
	var is_heavy_aerial := is_airborne_attacker and (attack_anim == "kick" or kind == "ultimate") and target.position.y <= 0.05 and not target_was_guarding
	if is_heavy_aerial and not resolving_combo_practice:
		_perform_downward_slam(target, source, accent)
		# Launch both slightly upward for aerial follow-up window
		source.set_meta("airborne", true)
		source.set_meta("air_elapsed", 0.0)
		source.set_meta("air_gravity", AIR_GRAVITY * 0.7)
		source.set_meta("launch_velocity", 6.0)
		source.set_meta("air_duration", 1.6)
		target.set_meta("airborne", true)
		target.set_meta("air_elapsed", 0.0)
		target.set_meta("air_gravity", AIR_GRAVITY)
		target.set_meta("launch_velocity", 4.0)
		target.set_meta("air_duration", 1.2)

	var push_direction := away.normalized()
	var wanted_destination := target.global_position + push_direction * knockback
	var destination := wanted_destination
	destination.x = clampf(destination.x, -ARENA_LIMIT, ARENA_LIMIT)
	destination.z = clampf(destination.z, -ARENA_LIMIT, ARENA_LIMIT)
	# Whatever the wall swallowed is pushed onto the attacker instead (corner pushback); a blocked
	# hit also nudges the attacker back a little.
	var attacker_push := (0.16 if target_was_guarding else 0.0) + wanted_destination.distance_to(destination) * 0.85
	var reaction := create_tween()
	reaction.set_parallel()
	reaction.tween_property(target, "global_position", destination, 0.16 + knockback * 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	reaction.tween_property(target, "scale", Vector3(1.12, 0.9, 1.12), 0.08)
	reaction.chain().tween_property(target, "scale", Vector3.ONE, 0.22)

	# Kill / final blow sequence: extended freeze, throw body backward, ash burn
	var will_ko_here := (enemy_hp - damage <= 0.0) if is_player else (player_hp - damage <= 0.0)
	if will_ko_here and not resolving_combo_practice:
		_trigger_kill_sequence(target, source, push_direction, accent)

	if attacker_push > 0.01 and is_instance_valid(source):
		var source_destination := source.global_position - push_direction * attacker_push
		source_destination.x = clampf(source_destination.x, -ARENA_LIMIT, ARENA_LIMIT)
		source_destination.z = clampf(source_destination.z, -ARENA_LIMIT, ARENA_LIMIT)
		var recoil := create_tween()
		recoil.set_parallel()
		recoil.tween_property(source, "global_position:x", source_destination.x, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		recoil.tween_property(source, "global_position:z", source_destination.z, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if player_hp <= 0.0 or enemy_hp <= 0.0:
		_end_match(enemy_hp <= 0.0)
	_update_hud()

## Tiny horizontal tremble on the fighter who was hit, running on real time so it plays during hit-stop.
func _hit_shake(fighter: Node3D, seconds: float, strength: float) -> void:
	var rig := fighter.get_node_or_null("Stickman_Rig") as Node3D
	if not is_instance_valid(rig) or seconds <= 0.0:
		return
	if not fighter.has_meta("rig_base_x"):
		fighter.set_meta("rig_base_x", rig.position.x)
	var base_x := float(fighter.get_meta("rig_base_x"))
	var steps := maxi(2, roundi(seconds / 0.02))
	var shake := create_tween()
	shake.set_ignore_time_scale(true)
	shake.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for step in range(steps):
		var fade := 1.0 - float(step) / float(steps)
		var offset := strength * fade * (1.0 if step % 2 == 0 else -1.0)
		shake.tween_property(rig, "position:x", base_x + offset, seconds / float(steps))
	shake.tween_property(rig, "position:x", base_x, 0.0)

func _attack_contact_range(move: Dictionary) -> float:
	if bool(move.get("projectile", false)):
		return float(move.get("projectile_range", 9.0))
	if bool(move.get("grab", false)):
		return 1.5
	if bool(move.get("aerial", false)):
		return 2.0
	var animation := str(move.get("animation", "")).to_lower()
	var move_name := str(move.get("name", "")).to_lower()
	if animation == "kick" or move_name.contains("kick") or move_name.contains("uppercut") or float(move.get("damage", 0)) >= 20.0:
		return 1.9
	return 1.55

func _attack_animation(move: Dictionary) -> String:
	var animation := str(move.get("animation", ""))
	if not animation.is_empty():
		return animation
	var move_name := str(move.get("name", "")).to_lower()
	if bool(move.get("grab", false)) or move_name.contains("grab"):
		return "grab"
	if move_name.contains("kick") or float(move.get("damage", 0)) >= 20.0:
		return "kick"
	return "punch"

func _has_attack_contact(source: Node3D, target: Node3D, move: Dictionary, reach: float) -> bool:
	var displacement := target.global_position - source.global_position
	var horizontal_displacement := Vector3(displacement.x, 0.0, displacement.z)
	if horizontal_displacement.length() > reach:
		return false
	var max_vertical_reach := 2.1 if bool(move.get("aerial", false)) else 1.35
	if bool(move.get("projectile", false)):
		max_vertical_reach = 7.0
	if absf(displacement.y) > max_vertical_reach:
		return false
	var forward := source.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001 or horizontal_displacement.length_squared() < 0.0001:
		return true
	return forward.normalized().dot(horizontal_displacement.normalized()) >= 0.35

func _use_equipped_ultimate() -> void:
	if player_mp < ULTIMATE_MP_COST:
		_show_feedback("ULTIMATE NEEDS 4 MP · HIT OR CHARGE TO FILL THE METER")
		return
	var signature: String = GameData.CHARACTERS[player_character_index].signature
	var moves := GameData.legends_arts(signature, unlocked_ultimates, player_style)
	var selected: Dictionary = {}
	for move in moves:
		if move.get("kind") == "ultimate" and not bool(move.get("locked", false)) and bool(move.get("signature", false)):
			selected = move
			break
	if selected.is_empty():
		for move in moves:
			if move.get("kind") == "ultimate" and not bool(move.get("locked", false)):
				selected = move
				break
	if selected.is_empty():
		_show_feedback("NO ULTIMATE UNLOCKED")
		return
	_use_move(selected)

func _use_move(move: Dictionary) -> void:
	if match_over or challenge_active:
		return
	if move.get("locked", false):
		_show_feedback("UNLOCK THIS ULTIMATE IN TRAINING")
		return
	if move.get("kind") == "ultimate":
		if player_mp < float(move.get("cost", 4)):
			_show_feedback("NOT ENOUGH MP")
			return
		if bool(move.get("signature", false)):
			var signature_move := move.duplicate(true)
			signature_move["projectile"] = true
			signature_move["projectile_range"] = 12.0
			signature_move["animation"] = "beam"
			_apply_move(true, signature_move, player_node.global_position.distance_to(enemy_node.global_position))
		else:
			if player_node.position.distance_to(enemy_node.position) > 2.6:
				_show_feedback("TOO FAR · MOVE CLOSER BEFORE YOUR ULTIMATE")
				return
			_open_challenge(move)
	else:
		var distance := player_node.position.distance_to(enemy_node.position)
		var selected_move := move
		if (bool(player_node.get_meta("airborne", false)) or bool(player_node.get_meta("flying", false))) and str(move.get("kind", "")) in ["attack", "trap"]:
			selected_move = move.duplicate()
			selected_move["aerial"] = true
			selected_move["name"] = "Jump " + str(move.get("name", "Attack"))
		_apply_move(true, selected_move, distance)

func _on_basic_attack(action: String) -> void:
	if challenge_active or match_over:
		return
	if grapple_victim == player_node:
		_attempt_grapple_escape(0.34)
		return
	if grapple_holder == player_node:
		_resolve_grapple_followup(true, "throw" if action == "kick" else "punch")
		return
	var attacks: Dictionary = {
		"punch": {"name": "Punch Combo", "kind": "attack", "damage": 10, "stun": 10, "cost": 0, "animation": "punch", "attack_type": "punch"},
		"kick": {"name": "Kick Combo", "kind": "attack", "damage": 14, "stun": 14, "cost": 0, "animation": "kick", "attack_type": "kick"},
		"uppercut": {"name": "Uppercut", "kind": "attack", "damage": 19, "stun": 24, "cost": 0, "animation": "rising_rush", "attack_type": "uppercut", "launcher": true},
		"grab": {"name": "Grab", "kind": "attack", "damage": 15, "stun": 18, "cost": 0, "grab": true, "animation": "grab"}
	}
	var move: Dictionary = attacks[action]
	if action == "kick" and not bool(player_node.get_meta("airborne", false)):
		var toward_opponent := enemy_node.global_position - player_node.global_position
		toward_opponent.y = 0.0
		var stick_move := Vector3(joystick_vector.x, 0.0, joystick_vector.y)
		if stick_move.length_squared() > 0.2 and stick_move.normalized().dot(toward_opponent.normalized()) < -0.45:
			move["back_kick"] = true
	if action in ["punch", "kick"] and (bool(player_node.get_meta("airborne", false)) or bool(player_node.get_meta("flying", false))):
		move = move.duplicate()
		move.name = "Jump " + str(move.name)
		move.damage = 18 if action == "kick" else 14
		move.stun = 18 if action == "kick" else 14
		move["aerial"] = true
	var distance := player_node.position.distance_to(enemy_node.position)
	if action == "grab" and distance > 1.8:
		_show_feedback("GRAB RANGE IS SHORT · MOVE CLOSER")
		return
	_apply_move(true, move, distance)

func _on_mobile_strike_down() -> void:
	mobile_strike_pressed_at = Time.get_ticks_msec()

func _on_mobile_strike_up() -> void:
	if mobile_strike_pressed_at <= 0:
		return
	var held_seconds := float(Time.get_ticks_msec() - mobile_strike_pressed_at) / 1000.0
	mobile_strike_pressed_at = 0
	if held_seconds >= 0.38:
		_on_basic_attack("grab")
	elif joystick_vector.y <= -0.68 and not bool(player_node.get_meta("airborne", false)):
		_on_basic_attack("uppercut")
	else:
		_on_basic_attack(mobile_next_strike)
		mobile_next_strike = "kick" if mobile_next_strike == "punch" else "punch"
	var strike_button := hud.get_node_or_null("CombatActions/MobileStrikeButton") as Button if is_instance_valid(hud) else null
	if is_instance_valid(strike_button):
		strike_button.text = "STRIKE · %s" % mobile_next_strike.to_upper()

func _on_mobile_dodge() -> void:
	if joystick_vector.length() > 0.18:
		_on_player_dodged(joystick_vector.normalized())
		return
	if not is_instance_valid(player_node) or not is_instance_valid(enemy_node):
		return
	var away := player_node.global_position - enemy_node.global_position
	away.y = 0.0
	if away.length_squared() < 0.001:
		away = Vector3.LEFT
	var camera_node := get_viewport().get_camera_3d()
	if not is_instance_valid(camera_node):
		_on_player_dodged(Vector2.LEFT)
		return
	var forward := -camera_node.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP)
	var screen_direction := Vector2(away.dot(right), -away.dot(forward)).normalized()
	_on_player_dodged(screen_direction)

func _on_jump() -> void:
	if challenge_active or match_over:
		return
	if flight_enabled:
		_on_flight_toggled(false)
		return
	if grapple_victim == player_node:
		_attempt_grapple_escape(0.34)
		return
	if is_instance_valid(grapple_holder):
		return
	if bool(player_node.get_meta("airborne", false)):
		_show_feedback("ALREADY AIRBORNE")
		return
	_show_feedback("JUMP · LEAP")
	var jump_direction := Vector3(joystick_vector.x, 0.0, joystick_vector.y)
	if jump_direction.length_squared() < 0.01:
		jump_direction = enemy_node.position - player_node.position
		jump_direction.y = 0.0
	_move_fighter(player_node, enemy_node, jump_direction.normalized() * 0.6)
	player_node.set_meta("airborne", true)
	player_node.set_meta("air_elapsed", 0.0)
	var jump_velocity := sqrt(2.0 * AIR_GRAVITY * JUMP_HEIGHT)
	player_node.set_meta("air_gravity", AIR_GRAVITY)
	player_node.set_meta("launch_velocity", jump_velocity)
	player_node.set_meta("air_duration", jump_velocity / AIR_GRAVITY * 2.0)
	enemy_flight_decision_clock = minf(enemy_flight_decision_clock, 1.0)
	_play_fighter_action(player_node, "jump", JUMP_DURATION)
	# _show_move_cue(player_node, "JUMP", GameData.CHARACTERS[player_character_index].accent)

func _on_block() -> void:
	if challenge_active or match_over or player_stun_lock > 0.0:
		return
	if grapple_victim == player_node:
		_attempt_grapple_escape(0.34)
		return
	if grapple_holder == player_node:
		_show_feedback("GRAPPLE · PUNCH OR KICK TO FINISH")
		return
	if is_charging:
		_show_feedback("STOP CHARGING BEFORE BLOCKING")
		return
	player_is_blocking = true
	player_guard = 12.0 + (6.0 if player_character_index == 8 else 0.0)
	_play_fighter_action(player_node, "block", 999.0)
	_show_feedback("BLOCKING · RELEASE TO LOWER GUARD")
	# _show_move_cue(player_node, "BLOCK", GameData.CHARACTERS[player_character_index].accent)

func _on_block_released() -> void:
	player_is_blocking = false
	if is_instance_valid(player_node) and player_guard > 0.0:
		player_guard = 0.0
		if not bool(player_node.get_meta("attack_active", false)):
			_play_fighter_action(player_node, "idle", 0.2)

func _on_sprint_toggled(enabled: bool) -> void:
	sprint_enabled = enabled
	if is_instance_valid(sprint_button):
		sprint_button.text = "RUN  ·  ON" if enabled else "RUN  ·  SHIFT"

func _set_charging(value: bool) -> void:
	var combat: Object = player_node.get_meta("fighter_combat", null) if is_instance_valid(player_node) else null
	var can_charge := not match_over and not challenge_active and player_stun_lock <= 0.0
	if combat and combat.has_method("can_act"):
		can_charge = can_charge and bool(combat.call("can_act"))
	is_charging = value and can_charge
	if combat and combat.has_method("set_charging"):
		combat.call("set_charging", is_charging)
	if is_charging:
		_play_fighter_action(player_node, "charge", 999.0)
		var animation_player := player_node.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if is_instance_valid(animation_player):
			animation_player.speed_scale = 1.0
		_set_charge_aura(true)
		_show_feedback("KI CHARGING · MP ONLY · HP / STUN UNCHANGED")
	else:
		_set_charge_aura(false)
		if is_instance_valid(player_node) and str(player_node.get_meta("anim_action", "")) == "charge":
			if flight_enabled:
				_play_flight_animation(player_node, "fly_idle")
			else:
				_play_fighter_action(player_node, "idle", 0.2)
	_update_hud()

func _set_charge_aura(enabled: bool) -> void:
	if not is_instance_valid(player_node):
		return
	var existing := player_node.get_node_or_null("KiChargeAura")
	if not enabled:
		if is_instance_valid(existing):
			existing.queue_free()
		return
	if is_instance_valid(existing):
		return
	var aura := Node3D.new()
	aura.name = "KiChargeAura"
	player_node.add_child(aura)
	var style_auras: Dictionary = {"Chess": Color("#72d5ff"), "Checkers": Color("#ff805f"), "Ludo": Color("#ffd45c"), "Cards": Color("#ce8cff"), "Scrabble": Color("#91e596")}
	var accent: Color = style_auras.get(player_style, GameData.CHARACTERS[player_character_index].accent)
	for ring_index in range(2):
		var ring := MeshInstance3D.new()
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 0.46 + float(ring_index) * 0.08
		ring_mesh.outer_radius = 0.55 + float(ring_index) * 0.08
		ring.mesh = ring_mesh
		ring.position.y = 0.38 + float(ring_index) * 0.62
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow.albedo_color = Color(accent.r, accent.g, accent.b, 0.65)
		glow.emission_enabled = true
		glow.emission = accent
		glow.emission_energy_multiplier = 2.4
		ring.material_override = glow
		aura.add_child(ring)

func _on_joystick_changed(value: Vector2) -> void:
	joystick_vector = value

func _update_camera(delta: float) -> void:
	if not is_instance_valid(camera) or not is_instance_valid(player_node) or not is_instance_valid(enemy_node):
		return
	var center := (player_node.position + enemy_node.position) * 0.5
	var fighter_span := Vector2(player_node.position.x - enemy_node.position.x, player_node.position.z - enemy_node.position.z).length()
	var vertical_span := absf(player_node.position.y - enemy_node.position.y)
	var camera_back := clampf(7.4 + fighter_span * 0.38 + vertical_span * 0.3, 7.4, 13.5)
	var camera_height := clampf(3.8 + fighter_span * 0.17 + vertical_span * 0.12, 3.8, 7.0)
	var desired_position := center + Vector3(0.0, camera_height, camera_back)
	camera_shake_phase += delta * 52.0
	camera_shake_strength = move_toward(camera_shake_strength, 0.0, delta * 1.8)

	# Animate water shader time
	if water_shader_material:
		water_shader_material.set_shader_parameter("time", Time.get_ticks_msec() / 1000.0)

	var shake := Vector3(
		sin(camera_shake_phase * 1.0) * camera_shake_strength,
		sin(camera_shake_phase * 1.7) * camera_shake_strength * 0.35,
		sin(camera_shake_phase * 1.3) * camera_shake_strength * 0.2
	)

	# Dynamic FOV expansion during dash / high speed
	var speed_factor := player_ground_velocity.length() / maxf(PLAYER_SPEED, 0.001)
	if player_is_dashing:
		speed_factor = maxf(speed_factor, 1.5)
	camera_fov_target = lerp(45.0, 70.0, clampf(speed_factor * 0.4, 0.0, 1.0))
	camera_fov_current = lerp(camera_fov_current, camera_fov_target, delta * 8.0)
	camera.fov = camera_fov_current

	var blend := 1.0 - exp(-delta * 5.0)
	camera.position = camera.position.lerp(desired_position + shake, blend)
	camera.look_at(center + Vector3(0.0, 0.8, 0.0), Vector3.UP)

func _update_hud() -> void:
	if not is_instance_valid(hud):
		return
	_update_hp_bars()
	player_mp_bar.value = player_mp
	player_ultimate_bar.value = minf(player_mp, ULTIMATE_MP_COST)
	player_stun_bar.value = player_stun
	player_vanish_bar.value = player_vanish
	enemy_ultimate_bar.value = minf(enemy_mp, ULTIMATE_MP_COST)
	enemy_mp_bar.value = enemy_mp
	enemy_stun_bar.value = enemy_stun
	enemy_vanish_bar.value = enemy_vanish
	var player_title: String = player_data.get("name", "")
	var enemy_title: String = opponent_data.get("name", "")
	if is_instance_valid(player_title_label):
		player_title_label.text = "%s  ·  LV %d  ·  %s" % [player_title, player_level, player_style]
		enemy_title_label.text = "%s  ·  %s" % [enemy_title, "TRAINING" if training_mode else "%s · %s" % [opponent_style, ai_difficulty.to_upper()]]
	var info := hud.get_node_or_null("ModeInfo/ProgressInfo") as Label
	if info:
		info.text = "%s  ·  LV %d  ·  %d XP  ·  %s  ·  W %d" % [player_style, player_level, player_xp, GameData.RANKS[rank_index], wins]
	if is_instance_valid(clash_button):
		clash_button.visible = not training_mode
		clash_button.disabled = training_mode or player_mp > MAX_MP * 0.2 or mp_clash_cooldown > 0.0 or match_over
		if player_mp > MAX_MP * 0.2:
			clash_button.text = "CLASH · LOW KI"
		elif mp_clash_cooldown > 0.0:
			clash_button.text = "CLASH · COOLDOWN"
		elif match_over:
			clash_button.text = "CLASH · MATCH OVER"
		else:
			clash_button.text = "MP CLASH · READY"
	if is_instance_valid(ultimate_button):
		ultimate_button.text = "ULTIMATE  ·  %d/4" % floori(minf(player_mp, ULTIMATE_MP_COST))
		ultimate_button.disabled = player_mp < ULTIMATE_MP_COST or match_over or challenge_active
	if is_instance_valid(training_button):
		training_button.text = "EXIT TRAINING" if training_mode else "TRAINING"
	if is_instance_valid(story_button):
		story_button.text = "STORY · %d/%d" % [min(story_progress, StoryCampaignScript.CHAPTERS.size()), StoryCampaignScript.CHAPTERS.size()]
		story_button.disabled = story_mode_active
	var mobile_strike := hud.get_node_or_null("CombatActions/MobileStrikeButton") as Button
	if is_instance_valid(mobile_strike):
		mobile_strike.text = "STRIKE · %s" % mobile_next_strike.to_upper()
	var punch_button := hud.get_node_or_null("CombatActions/PunchButton") as Button
	if is_instance_valid(punch_button):
		punch_button.text = "BREAK FREE" if grapple_victim == player_node else "JUMP PUNCH" if bool(player_node.get_meta("airborne", false)) else "PUNCH"
	var kick_button := hud.get_node_or_null("CombatActions/KickThrowButton") as Button
	if is_instance_valid(kick_button):
		kick_button.text = "THROW" if grapple_holder == player_node else "BREAK FREE" if grapple_victim == player_node else "JUMP KICK" if bool(player_node.get_meta("airborne", false)) else "KICK"

func _update_hp_bars() -> void:
	_sync_fighter_health(player_node, player_hp)
	_sync_fighter_health(enemy_node, enemy_hp)
	_animate_hp_bar(player_hp_bar, player_hp, "player")
	_animate_hp_bar(enemy_hp_bar, enemy_hp, "enemy")

func _sync_fighter_health(fighter: Node3D, value: float) -> void:
	if not is_instance_valid(fighter):
		return
	var health: Object = fighter.get_meta("health_component", null)
	if is_instance_valid(health) and health.get("current") != null:
		health.set("current", clampi(roundi(value), 0, roundi(MAX_HP)))
	var combat: Object = fighter.get_meta("fighter_combat", null)
	if is_instance_valid(combat) and not is_equal_approx(float(combat.hp), value):
		combat.hp = clampf(value, 0.0, float(combat.max_hp))
		combat.hp_changed.emit(combat.hp, combat.max_hp)

func _update_mp_bars() -> void:
	if is_instance_valid(player_mp_bar):
		player_mp_bar.value = player_mp
	if is_instance_valid(enemy_mp_bar):
		enemy_mp_bar.value = enemy_mp

func _update_stun_bars() -> void:
	if is_instance_valid(player_stun_bar):
		player_stun_bar.value = player_stun
	if is_instance_valid(enemy_stun_bar):
		enemy_stun_bar.value = enemy_stun

func _animate_hp_bar(bar: ProgressBar, target_value: float, key: String) -> void:
	if not is_instance_valid(bar) or is_equal_approx(float(bar.get_meta("target_value", target_value)), target_value):
		return
	bar.set_meta("target_value", target_value)
	var previous_tween: Tween = hp_bar_tweens.get(key)
	if is_instance_valid(previous_tween) and previous_tween.is_running():
		previous_tween.kill()
	var tween := create_tween()
	hp_bar_tweens[key] = tween
	tween.tween_property(bar, "value", target_value, HP_BAR_DRAIN_DURATION).set_trans(Tween.TRANS_LINEAR)

func _open_games_hub() -> void:
	if is_instance_valid(games_hub):
		return
	challenge_active = true
	games_hub = Control.new()
	games_hub.set_script(GamesHubScript)
	games_hub.closed.connect(_close_games_hub)
	get_node("GameUI").add_child(games_hub)

func _close_games_hub() -> void:
	challenge_active = false
	if is_instance_valid(games_hub):
		games_hub.queue_free()
	games_hub = null
	if is_instance_valid(cards_grid) and cards_grid.get_child_count() == 0:
		_rebuild_move_cards()
	if return_to_menu_after_hub:
		return_to_menu_after_hub = false
		_open_main_menu()
	else:
		hud.visible = true
		main_menu_open = false

func _show_feedback(text: String) -> void:
	if is_instance_valid(feedback_label):
		feedback_label.text = text

func _show_move_cue(target: Node3D, text: String, color: Color) -> void:
	var previous := target.get_node_or_null("MoveCue")
	if is_instance_valid(previous):
		previous.queue_free()
	var cue := Label3D.new()
	cue.name = "MoveCue"
	cue.text = text.to_upper()
	cue.font_size = 42
	cue.outline_size = 8
	cue.modulate = color
	cue.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cue.position = Vector3(0.0, 2.8, 0.0)
	target.add_child(cue)
	var tween := create_tween()
	tween.tween_property(cue, "position:y", 3.3, 0.3)
	tween.tween_interval(0.52)
	tween.tween_property(cue, "modulate:a", 0.0, 0.18)
	tween.tween_callback(cue.queue_free)

func _open_challenge(move: Dictionary) -> void:
	challenge_active = true
	challenge_cost = float(move.get("cost", 4))
	_clear_challenge_overlay()
	challenge_layer.visible = true
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -210
	panel.offset_right = 210
	panel.offset_top = -145
	panel.offset_bottom = 145
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.045, 0.07, 0.98), Color("#f4bf4e")))
	challenge_layer.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	var title := Label.new()
	title.text = "%s CHALLENGE" % move.name.to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	content.add_child(title)
	var move_names: Array = GameData.ULTIMATE_NAMES.get(player_style, GameData.ULTIMATE_NAMES["Chess"])
	var puzzle_index := move_names.find(move.get("name", ""))
	if puzzle_index < 0:
		puzzle_index = 0
	var puzzle := GameData.ultimate_puzzle(player_style, puzzle_index)
	var prompt := Label.new()
	prompt.text = puzzle.prompt
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(prompt)

	if player_style == "Scrabble":
		var word_input := LineEdit.new()
		word_input.placeholder_text = "Type your answer"
		word_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(word_input)
		var submit := Button.new()
		submit.text = "SOLVE"
		submit.pressed.connect(_submit_scrabble_ultimate.bind(move, word_input, str(puzzle.correct)))
		content.add_child(submit)
	else:
		var answers: Array = puzzle.answers
		for answer in answers:
			var answer_button := Button.new()
			answer_button.text = str(answer)
			answer_button.custom_minimum_size.y = 34
			answer_button.pressed.connect(_submit_ultimate_answer.bind(move, str(answer), str(puzzle.correct)))
			content.add_child(answer_button)
	var cancel := Button.new()
	cancel.text = "CANCEL · MP IS SPENT"
	cancel.pressed.connect(_cancel_challenge)
	content.add_child(cancel)
	_update_hud()

func _challenge_prompt(style: String) -> String:
	match style:
		"Chess":
			return "Puzzle: which piece moves diagonally any distance?"
		"Checkers":
			return "Puzzle: jump an opponent piece to capture it. Which action?"
		"Ludo":
			return "Puzzle: roll two dice. What is the highest total?"
		"Cards":
			return "Puzzle: which suit is red?"
		_:
			return "Type the word shown to prove your Scrabble move."

func _challenge_answers(style: String) -> Array[String]:
	match style:
		"Chess":
			return ["Bishop", "Rook", "Knight"]
		"Checkers":
			return ["Jump", "Castle", "Shuffle"]
		"Ludo":
			return ["12", "10", "6"]
		"Cards":
			return ["Hearts", "Spades", "Clubs"]
		_:
			return ["CHECKMATE", "CHECK", "MATE"]

func _submit_ultimate_answer(move: Dictionary, answer: String, correct: String) -> void:
	_finish_ultimate(move, answer == correct)

func _submit_scrabble_ultimate(move: Dictionary, word_input: LineEdit, correct: String) -> void:
	_finish_ultimate(move, word_input.text.strip_edges().to_upper() == correct.to_upper())

func _finish_ultimate(move: Dictionary, answer: Variant) -> void:
	if not challenge_active:
		return
	var correct := bool(answer) if answer is bool else str(answer).strip_edges().to_upper() == "CHECKMATE"
	_clear_challenge_overlay()
	challenge_active = false
	if correct:
		_apply_move(true, move, player_node.position.distance_to(enemy_node.position))
		challenge_cost = 0.0
		_show_feedback("%s · CHALLENGE CLEARED" % move.name.to_upper())
	else:
		player_mp = maxf(0.0, player_mp - challenge_cost)
		challenge_cost = 0.0
		_show_feedback("CHALLENGE FAILED · MP SPENT")
	_update_hud()

func _cancel_challenge() -> void:
	challenge_active = false
	player_mp = maxf(0.0, player_mp - challenge_cost)
	challenge_cost = 0.0
	_clear_challenge_overlay()
	_show_feedback("ULTIMATE CANCELLED · MP IS SPENT")
	_update_hud()

func _clear_challenge_overlay() -> void:
	if not is_instance_valid(challenge_layer):
		return
	for child in challenge_layer.get_children():
		child.queue_free()
	challenge_layer.visible = false

func _start_mp_clash() -> void:
	if training_mode or match_over or mp_clash_active or mp_clash_cooldown > 0.0:
		return
	mp_clash_active = true
	mp_clash_clock = 20.0
	challenge_active = true
	_show_clash_prompt()

func _show_clash_prompt() -> void:
	_clear_challenge_overlay()
	challenge_layer.visible = true
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -220
	panel.offset_right = 220
	panel.offset_top = -125
	panel.offset_bottom = 125
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.045, 0.07, 0.98), Color("#ba91ff")))
	challenge_layer.add_child(panel)
	var content := VBoxContainer.new()
	panel.add_child(content)
	var title := Label.new()
	title.text = "MP CLASH · %d SECONDS" % int(mp_clash_clock)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 23)
	content.add_child(title)
	var prompt := Label.new()
	prompt.text = _challenge_prompt(player_style)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(prompt)
	var answers := _challenge_answers(player_style)
	for answer in answers:
		var button := Button.new()
		button.text = str(answer)
		button.pressed.connect(_submit_clash.bind(str(answer), str(answers[0])))
		content.add_child(button)
	if player_style == "Scrabble":
		var word := LineEdit.new()
		word.placeholder_text = "Type CHECKMATE"
		content.add_child(word)
		var submit := Button.new()
		submit.text = "SOLVE"
		submit.pressed.connect(_submit_scrabble_clash.bind(word))
		content.add_child(submit)

func _submit_clash(answer: String, correct: String) -> void:
	_resolve_clash(answer == correct)

func _submit_scrabble_clash(word_input: LineEdit) -> void:
	_resolve_clash(word_input.text.strip_edges().to_upper() == "CHECKMATE")

func _resolve_clash(player_won: bool) -> void:
	if not mp_clash_active:
		return
	mp_clash_active = false
	challenge_active = false
	mp_clash_cooldown = 30.0
	player_stun = MAX_STUN
	enemy_stun = MAX_STUN
	if player_won:
		player_mp = minf(MAX_MP, player_mp + 3.0)
		enemy_mp = minf(MAX_MP, enemy_mp + 1.0)
		_show_feedback("YOU WON THE MP CLASH · +3 MP")
	else:
		enemy_mp = minf(MAX_MP, enemy_mp + 3.0)
		_show_feedback("AI WON THE MP CLASH · STUN RESET")
	_clear_challenge_overlay()
	_update_hud()

func _toggle_training() -> void:
	training_mode = not training_mode
	if training_mode:
		enemy_is_training = true
		opponent_style = player_style
		opponent_character_index = 2
		enemy_hp = MAX_HP
		_show_feedback("TRAINING · SOLVE YOUR STYLE PUZZLE TO EARN XP")
		_build_fighters()
		_offer_training_challenge()
	else:
		enemy_is_training = false
		opponent_character_index = 1 if player_character_index != 1 else 0
		opponent_style = "Cards" if player_style != "Cards" else "Chess"
		_start_match()
	_update_hud()

func _offer_training_challenge() -> void:
	challenge_active = true
	_clear_challenge_overlay()
	challenge_layer.visible = true
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -220
	panel.offset_right = 220
	panel.offset_top = -150
	panel.offset_bottom = 150
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.045, 0.07, 0.98), Color("#80dca2")))
	challenge_layer.add_child(panel)
	var content := VBoxContainer.new()
	panel.add_child(content)
	var title := Label.new()
	title.text = "%s TRAINING" % player_style.to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	content.add_child(title)
	var instruction := Label.new()
	instruction.text = "Solve the style challenge to earn XP and unlock a new ultimate."
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(instruction)
	var prompt := Label.new()
	prompt.text = _challenge_prompt(player_style)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	training_prompt_label = prompt
	content.add_child(prompt)
	var answers := _challenge_answers(player_style)
	for answer in answers:
		var button := Button.new()
		button.text = str(answer)
		button.pressed.connect(_submit_training.bind(str(answer), str(answers[0])))
		content.add_child(button)
	var leave := Button.new()
	leave.text = "BACK TO FIGHT"
	leave.pressed.connect(_leave_training_challenge)
	content.add_child(leave)

func _submit_training(answer: String, correct: String) -> void:
	if answer != correct:
		training_prompt_label.text = "Not quite — try another answer."
		training_prompt_label.add_theme_color_override("font_color", Color("#ff9a8d"))
		return
	challenge_active = false
	_clear_challenge_overlay()
	player_xp += 50
	var gained_level := false
	while player_xp >= player_level * 100 and player_level < 50:
		player_xp -= player_level * 100
		player_level += 1
		gained_level = true
	unlocked_ultimates = clampi(1 + int((player_level - 1) / 5), 1, 6)
	_save_progress()
	_rebuild_move_cards()
	_show_feedback("TRAINING CLEARED · +50 XP%s" % (" · LEVEL UP!" if gained_level else ""))
	_update_hud()

func _leave_training_challenge() -> void:
	challenge_active = false
	_clear_challenge_overlay()

func _end_match(player_won: bool) -> void:
	match_over = true
	Engine.time_scale = 1.0
	is_charging = false
	_clear_grapple()
	_play_fighter_action(enemy_node if player_won else player_node, "knockout", 100000.0)
	_play_fighter_action(player_node if player_won else enemy_node, "victory", 100000.0)
	if player_won and not training_mode:
		wins += 1
		rank_index = min(GameData.RANKS.size() - 1, rank_index + 1)
		player_xp += 25
		while player_xp >= player_level * 100 and player_level < 50:
			player_xp -= player_level * 100
			player_level += 1
		unlocked_ultimates = clampi(1 + int((player_level - 1) / 5), 1, 6)
		if story_mode_active:
			story_progress = max(story_progress, story_stage_index + 1)
		_save_progress()
	if story_mode_active:
		story_campaign.call("show_result", story_stage_index, player_won, story_progress)
	else:
		_show_result(player_won)

func _show_result(player_won: bool) -> void:
	_clear_challenge_overlay()
	challenge_layer.visible = true
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -190
	panel.offset_right = 190
	panel.offset_top = -105
	panel.offset_bottom = 105
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.04, 0.055, 0.98), Color("#f4bf4e")))
	challenge_layer.add_child(panel)
	var content := VBoxContainer.new()
	panel.add_child(content)
	var title := Label.new()
	title.text = "VICTORY!" if player_won else "DEFEAT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#f4bf4e"))
	content.add_child(title)
	var detail := Label.new()
	detail.text = "%s  ·  %d WINS  ·  %s RANK" % [player_data.name, wins, GameData.RANKS[rank_index]]
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(detail)
	var again := Button.new()
	again.text = "PLAY AGAIN"
	again.pressed.connect(_start_match)
	content.add_child(again)

func _on_character_selected(index: int) -> void:
	player_character_index = index
	player_data = GameData.CHARACTERS[index]
	if player_character_index == 1:
		opponent_character_index = 0
	else:
		opponent_character_index = 1
	if player_character_index == 0:
		opponent_character_index = 1
	_start_match()
	_rebuild_move_cards()
	_save_progress()

func _on_style_selected(index: int) -> void:
	player_style = style_option.get_item_text(index)
	opponent_style = "Cards" if player_style != "Cards" else "Chess"
	if training_mode:
		opponent_style = player_style
	_start_match()
	_rebuild_move_cards()
	_save_progress()

func _open_loadouts() -> void:
	if not is_instance_valid(loadout_dialog):
		_build_loadout_dialog()
	_refresh_loadout_options()
	loadout_dialog.popup_centered()

func _build_loadout_dialog() -> void:
	loadout_dialog = Window.new()
	loadout_dialog.title = "FIGHTER LOADOUTS"
	loadout_dialog.size = Vector2i(560, 330)
	loadout_dialog.min_size = Vector2i(480, 300)
	loadout_dialog.unresizable = true
	loadout_dialog.close_requested.connect(loadout_dialog.hide)
	hud.add_child(loadout_dialog)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	loadout_dialog.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var description := Label.new()
	description.text = "Save the current character and style move set as a reusable preset."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(description)

	loadout_option = OptionButton.new()
	loadout_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loadout_option.item_selected.connect(_on_loadout_selected)
	layout.add_child(loadout_option)
	loadout_name_input = LineEdit.new()
	loadout_name_input.placeholder_text = "Loadout name (up to 32 characters)"
	loadout_name_input.max_length = 32
	layout.add_child(loadout_name_input)

	loadout_profile_actions = HBoxContainer.new()
	loadout_profile_actions.add_theme_constant_override("separation", 6)
	layout.add_child(loadout_profile_actions)
	_add_loadout_button(loadout_profile_actions, "APPLY", _apply_selected_loadout)
	_add_loadout_button(loadout_profile_actions, "SAVE NEW", _save_new_loadout)
	_add_loadout_button(loadout_profile_actions, "UPDATE", _update_selected_loadout)
	_add_loadout_button(loadout_profile_actions, "DELETE", _confirm_delete_loadout)

	loadout_backup_actions = HBoxContainer.new()
	loadout_backup_actions.add_theme_constant_override("separation", 6)
	layout.add_child(loadout_backup_actions)
	_add_loadout_button(loadout_backup_actions, "BACK UP PRESETS", _backup_loadouts)
	_add_loadout_button(loadout_backup_actions, "RESTORE BACKUP", _confirm_restore_loadouts)

	loadout_status = Label.new()
	loadout_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loadout_status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(loadout_status)
	loadout_confirm_dialog = ConfirmationDialog.new()
	loadout_dialog.add_child(loadout_confirm_dialog)
	loadout_confirm_dialog.confirmed.connect(_on_loadout_confirmation)

func _add_loadout_button(row: HBoxContainer, title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	row.add_child(button)

func _refresh_loadout_options() -> void:
	if not is_instance_valid(loadout_option):
		return
	loadout_option.clear()
	for profile in loadout_profiles:
		loadout_option.add_item(str(profile.name))
	if loadout_profiles.is_empty():
		loadout_option.add_item("No saved presets")
		loadout_option.set_item_disabled(0, true)
		loadout_name_input.text = ""
	else:
		loadout_option.select(0)
		loadout_name_input.text = str(loadout_profiles[0].name)
	_update_loadout_action_states()

func _on_loadout_selected(index: int) -> void:
	if index >= 0 and index < loadout_profiles.size():
		loadout_name_input.text = str(loadout_profiles[index].name)
	_update_loadout_action_states()

func _update_loadout_action_states() -> void:
	if not is_instance_valid(loadout_option):
		return
	var has_profiles := not loadout_profiles.is_empty()
	for button in loadout_profile_actions.get_children():
		if button.text in ["APPLY", "UPDATE", "DELETE"]:
			button.disabled = not has_profiles

func _selected_loadout_index() -> int:
	if not is_instance_valid(loadout_option) or loadout_profiles.is_empty():
		return -1
	var index := loadout_option.selected
	return index if index >= 0 and index < loadout_profiles.size() else -1

func _on_loadout_confirmation() -> void:
	if loadout_confirm_dialog.get_meta("action", "") == "delete":
		_delete_selected_loadout()
	elif loadout_confirm_dialog.get_meta("action", "") == "restore":
		_restore_loadouts()

func _confirm_delete_loadout() -> void:
	var index := _selected_loadout_index()
	if index < 0:
		_set_loadout_status("Choose a saved preset to delete.")
		return
	loadout_confirm_dialog.title = "Delete preset?"
	loadout_confirm_dialog.dialog_text = "Delete “%s”? This cannot be undone except by restoring a backup." % loadout_profiles[index].name
	loadout_confirm_dialog.set_meta("action", "delete")
	loadout_confirm_dialog.popup_centered()

func _confirm_restore_loadouts() -> void:
	if not FileAccess.file_exists("user://loadout_profiles.backup.json"):
		_set_loadout_status("No backup exists yet. Use BACK UP PRESETS first.")
		return
	loadout_confirm_dialog.title = "Restore presets?"
	loadout_confirm_dialog.dialog_text = "Replace the current saved presets with the last backup?"
	loadout_confirm_dialog.set_meta("action", "restore")
	loadout_confirm_dialog.popup_centered()

func _apply_selected_loadout() -> void:
	var index := _selected_loadout_index()
	if index < 0:
		_set_loadout_status("Choose a saved preset to apply.")
		return
	var profile := loadout_profiles[index]
	player_character_index = int(profile.character)
	player_style = str(profile.style)
	player_data = GameData.CHARACTERS[player_character_index]
	opponent_character_index = 1 if player_character_index != 1 else 0
	if player_character_index == 0:
		opponent_character_index = 1
	opponent_data = GameData.CHARACTERS[opponent_character_index]
	opponent_style = "Cards" if player_style != "Cards" else "Chess"
	if training_mode:
		opponent_style = player_style
	character_option.select(player_character_index)
	style_option.select(GameData.STYLE_MOVES.keys().find(player_style))
	_start_match()
	_rebuild_move_cards()
	_save_progress()
	_set_loadout_status("Applied “%s”." % profile.name)

func _save_new_loadout() -> void:
	var name := loadout_name_input.text.strip_edges()
	if not _valid_loadout_name(name):
		_set_loadout_status("Enter a non-empty preset name of 32 characters or fewer.")
		return
	if _find_loadout(name) >= 0:
		_set_loadout_status("That preset name already exists. Choose another name or use UPDATE.")
		return
	loadout_profiles.append({
		"name": name,
		"character": player_character_index,
		"style": player_style
	})
	if _persist_loadouts():
		_refresh_loadout_options()
		loadout_option.select(loadout_profiles.size() - 1)
		loadout_name_input.text = name
		_set_loadout_status("Saved “%s”." % name)
	else:
		loadout_profiles.pop_back()

func _update_selected_loadout() -> void:
	var index := _selected_loadout_index()
	var name := loadout_name_input.text.strip_edges()
	if index < 0:
		_set_loadout_status("Choose a saved preset to update.")
		return
	if not _valid_loadout_name(name):
		_set_loadout_status("Enter a non-empty preset name of 32 characters or fewer.")
		return
	var duplicate_index := _find_loadout(name)
	if duplicate_index >= 0 and duplicate_index != index:
		_set_loadout_status("Another preset already uses that name.")
		return
	var previous := loadout_profiles[index].duplicate(true)
	loadout_profiles[index] = {
		"name": name,
		"character": player_character_index,
		"style": player_style
	}
	if _persist_loadouts():
		_refresh_loadout_options()
		loadout_option.select(index)
		loadout_name_input.text = name
		_set_loadout_status("Updated “%s”." % name)
	else:
		loadout_profiles[index] = previous
		_refresh_loadout_options()

func _delete_selected_loadout() -> void:
	var index := _selected_loadout_index()
	if index < 0:
		return
	var deleted := loadout_profiles[index]
	loadout_profiles.remove_at(index)
	if _persist_loadouts():
		_refresh_loadout_options()
		_set_loadout_status("Deleted “%s”." % deleted.name)
	else:
		loadout_profiles.insert(index, deleted)
		_refresh_loadout_options()

func _find_loadout(name: String) -> int:
	for index in range(loadout_profiles.size()):
		if str(loadout_profiles[index].name).to_lower() == name.to_lower():
			return index
	return -1

func _valid_loadout_name(name: String) -> bool:
	return not name.is_empty() and name.length() <= 32

func _set_loadout_status(message: String) -> void:
	if is_instance_valid(loadout_status):
		loadout_status.text = message

func _persist_loadouts() -> bool:
	var error := _write_loadouts_file("user://loadout_profiles.json", loadout_profiles, "user://loadout_profiles.backup.json")
	if error != OK:
		_set_loadout_status("Could not save presets: %s" % error_string(error))
		push_error("Unable to save fighter loadouts: %s" % error_string(error))
		return false
	return true

func _backup_loadouts(profiles_path := "user://loadout_profiles.json", backup_path := "user://loadout_profiles.backup.json") -> void:
	var error := _copy_file(profiles_path, backup_path) if FileAccess.file_exists(profiles_path) else _write_loadouts_file(backup_path, loadout_profiles)
	if error != OK:
		_set_loadout_status("Could not back up presets: %s" % error_string(error))
		push_error("Unable to back up fighter loadouts: %s" % error_string(error))
		return
	_set_loadout_status("Preset backup created.")

func _restore_loadouts(profiles_path := "user://loadout_profiles.json", backup_path := "user://loadout_profiles.backup.json") -> void:
	var loaded := _read_loadouts_file(backup_path)
	if not bool(loaded.ok):
		_set_loadout_status("Could not restore presets: %s" % loaded.error)
		push_error("Unable to restore fighter loadouts: %s" % loaded.error)
		return
	var restored: Array[Dictionary] = loaded.profiles
	var error := _write_loadouts_file(profiles_path, restored)
	if error != OK:
		_set_loadout_status("Could not restore presets: %s" % error_string(error))
		push_error("Unable to restore fighter loadouts: %s" % error_string(error))
		return
	loadout_profiles = restored
	_refresh_loadout_options()
	_set_loadout_status("Restored presets from the last backup.")

func _load_loadouts() -> void:
	var loaded := _read_loadouts_file("user://loadout_profiles.json")
	if not bool(loaded.ok):
		push_error("Unable to load fighter loadouts: %s" % loaded.error)
		return
	loadout_profiles = loaded.profiles

func _read_loadouts_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": true, "profiles": [] as Array[Dictionary], "error": ""}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "profiles": [] as Array[Dictionary], "error": error_string(FileAccess.get_open_error())}
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return {"ok": false, "profiles": [] as Array[Dictionary], "error": "invalid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()]}
	if not json.data is Dictionary or int(json.data.get("version", 0)) != 1 or not json.data.get("profiles", null) is Array:
		return {"ok": false, "profiles": [] as Array[Dictionary], "error": "unsupported preset file format"}
	var profiles: Array[Dictionary] = []
	var names: Dictionary = {}
	for value in json.data.profiles:
		if not value is Dictionary:
			return {"ok": false, "profiles": [] as Array[Dictionary], "error": "a preset entry is not an object"}
		var name := str(value.get("name", "")).strip_edges()
		var character: Variant = value.get("character", null)
		var style := str(value.get("style", ""))
		if not _valid_loadout_name(name) or names.has(name.to_lower()):
			return {"ok": false, "profiles": [] as Array[Dictionary], "error": "preset names must be unique and 1–32 characters"}
		var character_index := -1
		if typeof(character) == TYPE_INT:
			character_index = int(character)
		elif typeof(character) == TYPE_FLOAT:
			var character_number := float(character)
			if character_number >= 0.0 and character_number < GameData.CHARACTERS.size() and is_equal_approx(character_number, roundf(character_number)):
				character_index = int(character_number)
		if character_index < 0 or character_index >= GameData.CHARACTERS.size() or not GameData.STYLE_MOVES.has(style):
			return {"ok": false, "profiles": [] as Array[Dictionary], "error": "a preset contains an unknown character or style"}
		names[name.to_lower()] = true
		profiles.append({"name": name, "character": character_index, "style": style})
	return {"ok": true, "profiles": profiles, "error": ""}

func _write_loadouts_file(path: String, profiles: Array[Dictionary], backup_path := "") -> Error:
	if not backup_path.is_empty() and FileAccess.file_exists(path):
		var backup_error := _copy_file(path, backup_path)
		if backup_error != OK:
			return backup_error
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": 1, "profiles": profiles}, "\t"))
	var error := file.get_error()
	file.close()
	return error

func _copy_file(source_path: String, destination_path: String) -> Error:
	if not FileAccess.file_exists(source_path):
		return ERR_FILE_NOT_FOUND
	var bytes := FileAccess.get_file_as_bytes(source_path)
	var output := FileAccess.open(destination_path, FileAccess.WRITE)
	if output == null:
		return FileAccess.get_open_error()
	output.store_buffer(bytes)
	var error := output.get_error()
	output.close()
	return error

func _on_viewport_resized() -> void:
	if not is_instance_valid(hud):
		return
	arena_size = get_viewport().get_visible_rect().size
	var landscape := arena_size.x >= arena_size.y
	if not landscape:
		_show_feedback("ROTATE YOUR DEVICE TO LANDSCAPE")
	elif is_instance_valid(feedback_label) and feedback_label.text == "ROTATE YOUR DEVICE TO LANDSCAPE":
		feedback_label.text = "MOVE IN WITH THE JOYSTICK · STRIKE WHEN CLOSE"

func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "level", player_level)
	config.set_value("player", "xp", player_xp)
	config.set_value("player", "wins", wins)
	config.set_value("player", "rank", rank_index)
	config.set_value("player", "character", player_character_index)
	config.set_value("player", "style", player_style)
	config.set_value("player", "story_progress", story_progress)
	var error := config.save("user://progress.cfg")
	if error != OK:
		push_error("Unable to save game progress: %s" % error_string(error))

func _load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load("user://settings.cfg")
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_error("Unable to load game settings: %s" % error_string(error))
	master_volume = clampf(float(config.get_value("settings", "master_volume", 1.0)), 0.0, 1.0)
	fullscreen_enabled = bool(config.get_value("settings", "fullscreen", false))
	ai_difficulty = str(config.get_value("settings", "difficulty", "Normal"))
	if ai_difficulty not in ["Easy", "Normal", "Hard"]:
		ai_difficulty = "Normal"
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus < 0:
		push_error("Unable to apply settings: the Master audio bus does not exist.")
	else:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(master_volume, 0.0001)))
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen_enabled else DisplayServer.WINDOW_MODE_WINDOWED
	)

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("settings", "master_volume", master_volume)
	config.set_value("settings", "fullscreen", fullscreen_enabled)
	config.set_value("settings", "difficulty", ai_difficulty)
	var error := config.save("user://settings.cfg")
	if error != OK:
		push_error("Unable to save game settings: %s" % error_string(error))

func _load_progress() -> void:
	var config := ConfigFile.new()
	var error := config.load("user://progress.cfg")
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_error("Unable to load game progress: %s" % error_string(error))
	player_level = int(config.get_value("player", "level", 1))
	player_xp = int(config.get_value("player", "xp", 0))
	wins = int(config.get_value("player", "wins", 0))
	rank_index = clampi(int(config.get_value("player", "rank", 0)), 0, GameData.RANKS.size() - 1)
	player_character_index = clampi(int(config.get_value("player", "character", 0)), 0, GameData.CHARACTERS.size() - 1)
	player_style = str(config.get_value("player", "style", "Chess"))
	story_progress = clampi(int(config.get_value("player", "story_progress", 0)), 0, StoryCampaignScript.CHAPTERS.size())
	opponent_character_index = 1 if player_character_index != 1 else 0
	opponent_style = "Cards" if player_style != "Cards" else "Chess"
	unlocked_ultimates = clampi(1 + int((player_level - 1) / 5), 1, 6)
	player_data = GameData.CHARACTERS[player_character_index]
	opponent_data = GameData.CHARACTERS[opponent_character_index]

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if pause_menu_open:
			_close_pause_menu()
		elif not main_menu_open and not challenge_active:
			_open_pause_menu()
		return
	if main_menu_open:
		return
	if pause_menu_open:
		return
	if event.is_action_pressed("attack_punch"):
		_on_basic_attack("punch")
	elif event.is_action_pressed("attack_kick"):
		_on_basic_attack("kick")
	elif event.is_action_pressed("attack_uppercut"):
		_on_basic_attack("uppercut")
	elif event.is_action_pressed("attack_grab"):
		_on_basic_attack("grab")
	elif event.is_action_pressed("action_jump"):
		_on_jump()
	elif event.is_action_pressed("action_crouch"):
		_on_crouch_toggled(not crouch_enabled)
	elif event.is_action_pressed("action_fly_toggle"):
		_on_flight_toggled(not flight_enabled)
	elif event.is_action_pressed("action_block"):
		_on_block()
	elif event.is_action_released("action_block"):
		_on_block_released()
	elif event.is_action_pressed("action_charge"):
		_set_charging(true)
	elif event.is_action_released("action_charge"):
		_set_charging(false)
