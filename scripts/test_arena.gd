extends Node
## Combat test arena. No models or animations needed.
##
## Setup: new scene with a plain Node as root, attach this script, press F6.
## Needs move_data.gd, fighter_combat.gd, test_hitbox.gd and test_hurtbox.gd in the project.
##
## Controls (A attacks B unless stated):
##   1 jab (basic)            2 kick (medium)         3 big ultimate (40% max HP)
##   4 pierce move (breaks normal blocks, gives A invincibility while it plays)
##   5 toggle A charging      6 ultimate WITH a challenge, V completes A's challenge
##   7 B jabs A               8 B kicks A
##   Z toggle B normal block  X toggle B strong block     R reset

var a: FighterCombat
var b: FighterCombat
var moves := {}

var _status: Label
var _log_label: Label
var _log_lines: Array[String] = []


func _ready() -> void:
	_make_moves()
	a = _make_fighter("A")
	b = _make_fighter("B")
	(a.hitbox as TestHitbox).target = b.hurtbox as TestHurtbox
	(b.hitbox as TestHitbox).target = a.hurtbox as TestHurtbox
	_make_ui()


func _process(_delta: float) -> void:
	_status.text = "%s\n%s" % [_describe(a), _describe(b)]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_1: _play(a, "jab")
		KEY_2: _play(a, "kick")
		KEY_3: _play(a, "big_bang")
		KEY_4: _play(a, "pierce")
		KEY_5: a.set_charging(not a.is_charging)
		KEY_6: _play(a, "challenge_ult")
		KEY_V: a.complete_challenge(true)
		KEY_7: _play(b, "jab")
		KEY_8: _play(b, "kick")
		KEY_Z:
			b.block_level = 1
			b.is_blocking = not b.is_blocking
		KEY_X:
			b.block_level = 2
			b.is_blocking = not b.is_blocking
		KEY_R: get_tree().reload_current_scene()


# ---------- setup ----------

func _make_moves() -> void:
	moves["jab"] = _move(&"jab", "Jab", MoveData.Tier.BASIC, 5.0, 20.0, 15.0)
	moves["kick"] = _move(&"kick", "Kick", MoveData.Tier.MEDIUM, 15.0, 45.0, 30.0)

	var big := _move(&"big_bang", "Big Bang", MoveData.Tier.ULTIMATE, 60.0, 0.0, 50.0)
	big.percent_max_hp_damage = 0.4
	moves["big_bang"] = big

	var pierce := _move(&"pierce", "Pierce", MoveData.Tier.MEDIUM, 25.0, 60.0, 20.0)
	pierce.block_break_level = 1
	pierce.grants_invincibility = true
	moves["pierce"] = pierce

	# Has a (empty) challenge scene so it waits for complete_challenge() before firing.
	var challenge := _move(&"challenge_ult", "Challenge Ultimate", MoveData.Tier.ULTIMATE, 60.0, 100.0, 40.0)
	var scene := PackedScene.new()
	scene.pack(Node.new())
	challenge.challenge_scene = scene
	moves["challenge_ult"] = challenge


func _move(id: StringName, display: String, tier: MoveData.Tier, mp: float, dmg: float, stun: float) -> MoveData:
	var m := MoveData.new()
	m.id = id
	m.display_name = display
	m.tier = tier
	m.mp_cost = mp
	m.damage = dmg
	m.stun_damage = stun
	m.startup = 0.1
	m.active_time = 0.1
	m.recovery = 0.2
	return m


func _make_fighter(label: String) -> FighterCombat:
	var f := FighterCombat.new()
	f.name = label
	var hb := TestHitbox.new()
	var hu := TestHurtbox.new()
	f.hitbox = hb
	f.hurtbox = hu
	f.add_child(hb)
	f.add_child(hu)
	add_child(f)  # FighterCombat._ready runs here, after hitbox/hurtbox exist

	f.move_started.connect(func(m: MoveData): _log("%s plays %s" % [label, m.display_name]))
	f.hit_received.connect(func(d: Dictionary): _log("%s was hit by %s" % [label, d.get("move_id", "?")]))
	f.stunned.connect(func(): _log("%s is STUNNED" % label))
	f.defeated.connect(func(): _log("%s is DEFEATED" % label))
	f.challenge_requested.connect(func(m: MoveData): _log("%s challenge opened: %s" % [label, m.display_name]))
	f.challenge_restarted.connect(func(m: MoveData): _log("%s challenge RESTARTED: %s" % [label, m.display_name]))
	return f


func _make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var help := Label.new()
	help.position = Vector2(20, 10)
	help.text = "1 jab  2 kick  3 big ultimate  4 pierce  5 charge  6 challenge ultimate  V complete challenge\n7 B jab  8 B kick  Z B block  X B strong block  R reset"
	layer.add_child(help)

	_status = Label.new()
	_status.position = Vector2(20, 70)
	layer.add_child(_status)

	_log_label = Label.new()
	_log_label.position = Vector2(20, 150)
	layer.add_child(_log_label)


# ---------- helpers ----------

func _play(f: FighterCombat, key: String) -> void:
	if not f.play_move(moves[key]):
		_log("%s can't play %s (busy, stunned, challenge open, or not enough MP)" % [f.name, moves[key].display_name])


func _describe(f: FighterCombat) -> String:
	var flags: Array[String] = []
	if f.is_stunned: flags.append("STUNNED")
	if f.is_blocking: flags.append("blocking L%d" % f.block_level)
	if f.is_charging: flags.append("charging")
	if f.invincible: flags.append("invincible")
	return "%s   HP %d/%d   MP %d/%d   Stun %d/%d   %s" % [
		f.name, f.hp, f.max_hp, f.mp, f.max_mp, f.stun, f.max_stun, ", ".join(flags)]


func _log(line: String) -> void:
	_log_lines.append(line)
	if _log_lines.size() > 14:
		_log_lines.pop_front()
	_log_label.text = "\n".join(_log_lines)
