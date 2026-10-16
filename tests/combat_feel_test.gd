extends SceneTree
## Drives real attacks through the game to check the combat-feel systems:
## clip-driven hitbox timing, cancel windows, hit-stop, knockback and corner pushback.
## Run with:  godot --headless --fixed-fps 60 --script res://tests/combat_feel_test.gd

var failures := 0

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok   - ", message)
	else:
		failures += 1
		push_error("FAIL - " + message)
		print("  FAIL - ", message)

func _frames(count: int) -> void:
	for i in range(count):
		await process_frame

func _initialize() -> void:
	call_deferred("_run")

func _setup(game: Node, player_x: float, enemy_x: float) -> void:
	game.player_node.position = Vector3(player_x, 0.0, 0.0)
	game.enemy_node.position = Vector3(enemy_x, 0.0, 0.0)
	game.player_node.set_meta("attack_count", 0)
	game.enemy_node.set_meta("attack_count", 0)
	game.enemy_hp = 100.0
	game.enemy_stun = 100.0
	game.enemy_recovery = 0.0
	game.player_recovery = 0.0
	game.enemy_stun_lock = 9999.0   # a stunned AI neither walks nor attacks, so the test is deterministic
	game.player_stun_lock = 0.0
	game.ai_clock = 9999.0
	game._update_fighter_facing()

func _run() -> void:
	# ---------- authored timing table
	print("Clip table")
	var fighter_scene := load("res://stickman.glb") as PackedScene
	var probe := fighter_scene.instantiate()
	root.add_child(probe)
	var probe_player := probe.get_node("AnimationPlayer") as AnimationPlayer
	for clip in ClipFrameData.DATA:
		var fd := ClipFrameData.frame_data(clip)
		_check(probe_player.has_animation(clip), "%s exists as an animation clip" % clip)
		_check(fd.startup_frames >= 1 and fd.startup_frames < fd.total_frames and fd.cancel_end_frame <= fd.total_frames,
			"%s timing is sane (startup %d / active %d / recovery %d)" % [clip, fd.startup_frames, fd.active_frames, fd.recovery_frames])
		var clip_len := probe_player.get_animation(clip).length
		_check(absf(clip_len - float(ClipFrameData.DATA[clip].clip_frames) / 24.0) < 0.03, "%s table length matches the Blender clip (%.2fs)" % [clip, clip_len])
	probe.queue_free()

	# ---------- boot a fight
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game: Node = scene.instantiate()
	root.add_child(game)
	await _frames(3)
	game._start_match()
	game.main_menu_open = false
	game.pause_menu_open = false
	await _frames(3)
	_setup(game, -0.5, 0.5)
	game.enemy_node.set_meta("test_dummy", true)

	# ---------- punch string: jab then cancel into cross
	print("Cancel windows")
	var hp_before: float = game.enemy_hp
	game._on_basic_attack("punch")
	await _frames(1)
	var state: Dictionary = game.player_node.get_meta("attack_state", {})
	_check(str(state.get("clip", "")) == "jab", "first punch plays the jab clip")
	_check(bool(game.player_node.get_meta("attack_active", false)), "the attack is active")
	var fd_jab: Dictionary = state.get("frame_data", {})
	_check(fd_jab.get("total_frames", 0) == 20, "jab lasts 20 game frames")

	# wait for the hit to connect
	var guard := 0
	while not bool(game.player_node.get_meta("attack_connected", false)) and guard < 90:
		await process_frame
		guard += 1
	_check(bool(game.player_node.get_meta("attack_connected", false)), "the jab connects (took %d frames)" % guard)
	var progress: float = game._attack_progress_frames(game.player_node, game.player_node.get_meta("attack_state", {}))
	_check(progress >= float(fd_jab.startup_frames) - 0.01, "the hit landed on or after the clip's impact frame (frame %.1f, impact %d)" % [progress, fd_jab.startup_frames])
	_check(game.enemy_hp < hp_before, "the jab damaged the enemy")
	_check(Engine.time_scale == 0.0 or Engine.time_scale == 1.0, "time scale is frozen or normal during hit-stop")

	# input during the cancel window goes straight into the next move
	var cross_move: Dictionary = {"name": "Punch Combo", "kind": "attack", "damage": 10, "stun": 10, "cost": 0, "animation": "punch", "attack_type": "punch"}
	var can_cancel: bool = game._can_cancel_attack(game.player_node, cross_move)
	print("       can cancel now: ", can_cancel, " at frame ", progress)
	game._on_basic_attack("punch")
	await _frames(2)
	var state2: Dictionary = game.player_node.get_meta("attack_state", {})
	var clip_after := str(state2.get("clip", ""))
	_check(clip_after == "cross" or game.player_node.has_meta("pending_attack_move"), "a punch pressed after the hit becomes the cross (clip=%s)" % clip_after)

	# a kick (rank 2) after a jab (rank 1) is allowed, a jab after an uppercut (rank 3) is not
	var kick_move: Dictionary = {"animation": "kick", "attack_type": "kick", "kind": "attack"}
	_check(game._move_cancel_rank(kick_move) == 2, "kicks rank above light punches")
	_check(game._move_cancel_rank({"animation": "rising_rush", "launcher": true, "kind": "attack"}) == 3, "launchers rank 3")
	_check(game._move_cancel_rank({"animation": "hadoken", "projectile": true, "kind": "ultimate"}) == 4, "specials rank 4")

	# let everything settle
	await _frames(120)
	_check(Engine.time_scale == 1.0, "hit-stop always hands time back (time_scale=%.2f)" % Engine.time_scale)
	_check(not bool(game.player_node.get_meta("attack_active", false)), "the attack finishes and clears")

	# ---------- knockback
	print("Knockback")
	_setup(game, -0.5, 0.5)
	await _frames(2)
	var enemy_x_before: float = game.enemy_node.position.x
	game._on_basic_attack("kick")
	await _frames(100)
	var pushed: float = game.enemy_node.position.x - enemy_x_before
	_check(pushed > 0.25, "a kick pushes the defender back (%.2f m)" % pushed)

	# ---------- corner pushback: the wall's share lands on the attacker
	print("Corner pushback")
	_setup(game, 8.3, 8.9)
	await _frames(2)
	var player_x_before: float = game.player_node.position.x
	game._on_basic_attack("kick")
	await _frames(100)
	_check(game.enemy_node.position.x <= 9.0 + 0.001, "the defender stays inside the arena (x=%.2f)" % game.enemy_node.position.x)
	_check(game.player_node.position.x < player_x_before - 0.05, "the attacker is pushed off the cornered defender (%.2f -> %.2f)" % [player_x_before, game.player_node.position.x])

	_check(Engine.time_scale == 1.0, "time scale is back to normal at the end")
	print("")
	print("Combat feel test %s (%d failure(s))" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures > 0 else 0)
