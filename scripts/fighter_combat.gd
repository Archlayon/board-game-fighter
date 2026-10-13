class_name FighterCombat
extends Node
## Attach to each fighter. Holds HP / MP / stun and runs move cards.
##
## ASSUMPTIONS ABOUT GoHitHurt (check against the addon's README, I only know its
## description): the hitbox has a `hit_data` dictionary and an `enabled` flag, and
## the hurtbox emits `hit_detected(data: Dictionary)` with hit_data merged in plus a
## "source" key pointing at the hitbox. Rename things below if the real API differs.

signal hp_changed(hp: float, max_hp: float)
signal mp_changed(mp: float, max_mp: float)
signal stun_changed(value: float, max_value: float)
signal move_started(move: MoveData)
signal challenge_requested(move: MoveData)  # UI shows the mini-challenge
signal challenge_restarted(move: MoveData)  # hit while the challenge was open
signal stunned
signal defeated
signal hit_received(data: Dictionary)  # a hit actually landed (not blocked, not i-framed)

@export var max_hp := 1000.0
@export var max_mp := 100.0
@export var max_stun := 100.0
@export var mp_regen_per_sec := 0.0            # no passive MP regeneration
@export var charge_mp_per_sec := 0.0           # the match controller owns MP gains
@export var stun_duration := 2.0
@export var block_level := 1                  # normal block 1, strong block 2

@export var hitbox: Node = null

@export var hurtbox: Node = null:
	set(value):
		if hurtbox and hurtbox.has_signal("hit_detected"):
			var callback := Callable(self, "_on_hit_received")
			if hurtbox.hit_detected.is_connected(callback):
				hurtbox.hit_detected.disconnect(callback)
		hurtbox = value
		if hurtbox and hurtbox.has_signal("hit_detected"):
			var callback := Callable(self, "_on_hit_received")
			if not hurtbox.hit_detected.is_connected(callback):
				hurtbox.hit_detected.connect(callback)

@export var animation_player: AnimationPlayer

var hp: float
var mp: float
var stun: float
var is_stunned := false
var is_blocking := false
var is_charging := false
var invincible := false

var _busy := false                 # a move is playing
var _pending_ultimate: MoveData    # waiting on its mini-challenge


func _ready() -> void:
	hp = max_hp
	mp = max_mp
	stun = max_stun
	if hurtbox and hurtbox.has_signal("hit_detected"):
		var callback := Callable(self, "_on_hit_received")
		if not hurtbox.hit_detected.is_connected(callback):
			hurtbox.hit_detected.connect(callback)


func _process(delta: float) -> void:
	# MP only changes while charging. Hits and card moves are handled by the match controller.
	if is_charging:
		_set_mp(mp + charge_mp_per_sec * delta)


# ---------- playing moves ----------

func can_act() -> bool:
	return not is_stunned and not _busy and _pending_ultimate == null and hp > 0.0


func play_move(move: MoveData) -> bool:
	if not can_act() or mp < move.mp_cost:
		return false
	is_charging = false
	# Combos have no fixed cap: MP is the only limit on chaining moves.
	_set_mp(mp - move.mp_cost)
	if move.tier == MoveData.Tier.ULTIMATE and move.challenge_scene != null:
		_pending_ultimate = move
		challenge_requested.emit(move)  # no time limit; the opponent hitting you restarts it
		return true
	_execute(move)
	return true


## Your challenge UI calls this when the player clears (or abandons) the challenge.
func complete_challenge(success: bool) -> void:
	var move := _pending_ultimate
	_pending_ultimate = null
	if move != null and success:
		_execute(move)


func _execute(move: MoveData) -> void:
	_busy = true
	move_started.emit(move)
	# The animation itself is played by FighterAnimator, which listens to move_started.
	if not is_instance_valid(hitbox):
		push_warning("FighterCombat has no hitbox; move will play without applying damage.")
		await get_tree().create_timer(move.startup + move.active_time + move.recovery).timeout
		_busy = false
		return
	var hit_data := move.to_hit_data()
	hit_data["attacker"] = self
	if _has_property(hitbox, &"hit_data"):
		hitbox.set("hit_data", hit_data)
	elif _has_property(hitbox, &"actions"):
		# The game's Area3D hitboxes use HealthAction dictionaries rather than the
		# lightweight hit_data/enabled pair used by test hitboxes.
		hitbox.set("actions", [{
			"affect": 1,
			"type": 1,
			"amount": roundi(move.damage),
			"incrementer": 0,
			"multiplier": 1.0,
		}])
	if move.grants_invincibility:
		invincible = true

	await get_tree().create_timer(move.startup).timeout
	_set_hitbox_active(true)
	await get_tree().create_timer(move.active_time).timeout
	_set_hitbox_active(false)
	await get_tree().create_timer(move.recovery).timeout

	if move.grants_invincibility:
		invincible = false
	_busy = false


func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if StringName(property.name) == property_name:
			return true
	return false


func _set_hitbox_active(active: bool) -> void:
	if not is_instance_valid(hitbox):
		return
	if _has_property(hitbox, &"enabled"):
		hitbox.set("enabled", active)
	elif _has_property(hitbox, &"monitoring"):
		hitbox.set("monitoring", active)


# ---------- charge move (restores MP only, can be hit, cannot block) ----------

func set_charging(value: bool) -> void:
	if value and not can_act():
		return
	is_charging = value
	if value:
		is_blocking = false


# ---------- receiving hits ----------

func _on_hit_received(data: Dictionary) -> void:
	if data.get("source") == hitbox or invincible or hp <= 0.0:
		return  # own hitbox, i-frames, or already down

	# Blocking: a block only stops hits whose break level is below the block level.
	if is_blocking and not is_charging and block_level > int(data.get("block_break_level", 0)):
		return

	var dmg: float = data.get("damage", 0.0)
	dmg += float(data.get("percent_max_hp_damage", 0.0)) * max_hp
	_set_hp(hp - dmg)
	hit_received.emit(data)

	# Getting hit while an ultimate challenge is open restarts it from the beginning.
	if _pending_ultimate != null:
		challenge_restarted.emit(_pending_ultimate)

	# Stun meter only goes down, drops after every hit. At zero you are stunned.
	_set_stun(stun - float(data.get("stun_damage", 0.0)))
	if stun <= 0.0 and not is_stunned:
		_enter_stun()


func _enter_stun() -> void:
	is_stunned = true
	is_charging = false
	is_blocking = false
	stunned.emit()
	await get_tree().create_timer(stun_duration).timeout
	is_stunned = false
	_set_stun(max_stun)  # refills to full after a stun


# ---------- helpers ----------

func _set_hp(value: float) -> void:
	hp = clampf(value, 0.0, max_hp)
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		defeated.emit()


func _set_mp(value: float) -> void:
	var new_mp := clampf(value, 0.0, max_mp)
	if new_mp != mp:
		mp = new_mp
		mp_changed.emit(mp, max_mp)


func _set_stun(value: float) -> void:
	stun = clampf(value, 0.0, max_stun)
	stun_changed.emit(stun, max_stun)
