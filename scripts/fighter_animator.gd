class_name FighterAnimator
extends Node
## Drives a fighter's AnimationTree from FighterCombat. Builds the tree in code, so
## there is nothing to wire up in the AnimationTree editor.
##
## Tree layout:
##   Base (state machine: idle, run, block, charge, stun, knockdown)
##     -> MoveShot (one-shot, plays the animation of whichever move card was played)
##     -> HitShot  (one-shot, hit reaction, also aborts the move in progress)
##
## Scene setup:
##   1. Add an AnimationPlayer holding your animations, plus an AnimationTree node.
##   2. In the AnimationTree, set `Anim Player` to that AnimationPlayer. Leave Tree Root empty.
##   3. Fill in the exports below. Animation names must match the AnimationPlayer exactly,
##      including any library prefix (e.g. "UAL1/Idle" if they sit in a named library).
##   4. Idle, run, block, charge and stun animations must be set to loop in the importer.
##
## Requires FighterCombat with the `hit_received` signal (added in the updated
## fighter_combat.gd).

@export var combat: FighterCombat:
	set(value):
		combat = value
		if combat and not _initialized:
			_initialize()

@export var animation_tree: AnimationTree
## Optional. Used to detect running. Leave empty for a static test dummy.
@export var body: CharacterBody3D

var _initialized := false

func _ready() -> void:
	# Don't initialize here, wait for combat to be set
	pass

func _initialize() -> void:
	if _initialized or not combat or not animation_tree:
		return
	_initialize_tree()
	_initialized = true
	combat.move_started.connect(_on_move_started)
	combat.hit_received.connect(_on_hit_received)
func _initialize_tree() -> void:
	_build_tree()
	_playback = animation_tree.get("parameters/Base/playback")
	_playback.start(IDLE)
	_current = IDLE

@export_group("Animation names")
@export var anim_idle: StringName = &"Idle"
@export var anim_run: StringName = &"Run"
@export var anim_block: StringName = &"Block"
@export var anim_charge: StringName = &"Charge"
@export var anim_stun: StringName = &"Stun"
@export var anim_knockdown: StringName = &"Knockdown"
@export var anim_hit_light: StringName = &"HitLight"
@export var anim_hit_heavy: StringName = &"HitHeavy"

@export_group("Blending")
@export var state_blend := 0.12
@export var run_speed_threshold := 0.5

const IDLE := &"Idle"
const RUN := &"Run"
const BLOCK := &"Block"
const CHARGE := &"Charge"
const STUN := &"Stun"
const KNOCKDOWN := &"Knockdown"

var _move_anim: AnimationNodeAnimation
var _hit_anim: AnimationNodeAnimation
var _playback: AnimationNodeStateMachinePlayback
var _current: StringName = &""


func _physics_process(_delta: float) -> void:
	if not combat:
		return
	# Priority order: down > stunned > charging > blocking > running > idle.
	if combat.hp <= 0.0:
		_go(KNOCKDOWN)
	elif combat.is_stunned:
		_go(STUN)
	elif combat.is_charging:
		_go(CHARGE)
	elif combat.is_blocking:
		_go(BLOCK)
	elif body != null and Vector2(body.velocity.x, body.velocity.z).length() > run_speed_threshold:
		_go(RUN)
	else:
		_go(IDLE)


func _go(state: StringName) -> void:
	if state == _current:
		return
	_current = state
	_playback.travel(state)


func _on_move_started(move: MoveData) -> void:
	if move.animation == &"":
		return
	_move_anim.animation = move.animation
	animation_tree.set("parameters/MoveShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _on_hit_received(data: Dictionary) -> void:
	# A landed hit interrupts the move in progress.
	animation_tree.set("parameters/MoveShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	var heavy: bool = int(data.get("tier", MoveData.Tier.BASIC)) != MoveData.Tier.BASIC
	_hit_anim.animation = anim_hit_heavy if heavy else anim_hit_light
	animation_tree.set("parameters/HitShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


# ---------- tree construction ----------

func _build_tree() -> void:
	var root := AnimationNodeBlendTree.new()

	# Base layer: a state machine where every state can go to every other state.
	var base := AnimationNodeStateMachine.new()
	var states := {
		IDLE: anim_idle, RUN: anim_run, BLOCK: anim_block,
		CHARGE: anim_charge, STUN: anim_stun, KNOCKDOWN: anim_knockdown,
	}
	var i := 0
	for state in states:
		var node := AnimationNodeAnimation.new()
		node.animation = states[state]
		base.add_node(state, node, Vector2(200 * i, 0))
		i += 1
	for from_state in states:
		for to_state in states:
			if from_state != to_state:
				var t := AnimationNodeStateMachineTransition.new()
				t.xfade_time = state_blend
				base.add_transition(from_state, to_state, t)

	# Move and hit layers.
	_move_anim = AnimationNodeAnimation.new()
	_hit_anim = AnimationNodeAnimation.new()
	var move_shot := AnimationNodeOneShot.new()
	move_shot.fadein_time = 0.08
	move_shot.fadeout_time = 0.12
	var hit_shot := AnimationNodeOneShot.new()
	hit_shot.fadein_time = 0.04
	hit_shot.fadeout_time = 0.12

	root.add_node(&"Base", base, Vector2(0, 0))
	root.add_node(&"MoveAnim", _move_anim, Vector2(0, 200))
	root.add_node(&"MoveShot", move_shot, Vector2(300, 0))
	root.add_node(&"HitAnim", _hit_anim, Vector2(300, 200))
	root.add_node(&"HitShot", hit_shot, Vector2(600, 0))

	root.connect_node(&"MoveShot", 0, &"Base")
	root.connect_node(&"MoveShot", 1, &"MoveAnim")
	root.connect_node(&"HitShot", 0, &"MoveShot")
	root.connect_node(&"HitShot", 1, &"HitAnim")
	root.connect_node(&"output", 0, &"HitShot")

	animation_tree.tree_root = root
	animation_tree.active = true
