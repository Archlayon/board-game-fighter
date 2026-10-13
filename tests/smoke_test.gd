extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var progress_path := ProjectSettings.globalize_path("user://progress.cfg")
	var had_progress := FileAccess.file_exists(progress_path)
	var previous_progress: PackedByteArray = FileAccess.get_file_as_bytes(progress_path) if had_progress else PackedByteArray()
	var settings_path := ProjectSettings.globalize_path("user://settings.cfg")
	var had_settings := FileAccess.file_exists(settings_path)
	var previous_settings: PackedByteArray = FileAccess.get_file_as_bytes(settings_path) if had_settings else PackedByteArray()
	var saved_combo_library_path := ProjectSettings.globalize_path("user://combo_library.json")
	var had_combo_library := FileAccess.file_exists(saved_combo_library_path)
	var previous_combo_library: PackedByteArray = FileAccess.get_file_as_bytes(saved_combo_library_path) if had_combo_library else PackedByteArray()
	var saved_combo_backup_path := ProjectSettings.globalize_path("user://combo_library.backup.json")
	var had_combo_backup := FileAccess.file_exists(saved_combo_backup_path)
	var previous_combo_backup: PackedByteArray = FileAccess.get_file_as_bytes(saved_combo_backup_path) if had_combo_backup else PackedByteArray()
	_check(GameData.CHARACTERS.size() == 12, "The roster should contain twelve characters.")
	_check(GameData.STYLE_MOVES.size() == 5, "The game should contain five styles.")
	for action in ["move_left", "move_right", "move_forward", "move_back", "attack_punch", "attack_kick", "attack_grab", "action_jump", "action_block", "action_charge", "action_sprint"]:
		var has_joypad_binding := false
		for input_event in InputMap.action_get_events(action):
			if input_event is InputEventJoypadButton or input_event is InputEventJoypadMotion:
				has_joypad_binding = true
				break
		_check(has_joypad_binding, "%s should have a gamepad binding." % action)
	var game_audio := root.get_node_or_null("GameAudio")
	_check(game_audio != null, "The shared audio manager should load as an autoload.")
	if game_audio != null:
		_check(game_audio.call("has_sound", "attack_swing") and game_audio.call("has_sound", "hit_medium") and game_audio.call("has_sound", "hit_heavy"), "Combat sound effects should be available.")
		_check(game_audio.call("has_sound", "board_move") and game_audio.call("has_sound", "board_capture") and game_audio.call("has_sound", "tile_drop"), "Board-game sound effects should be available.")
		var audio_players_before: int = game_audio.get_child_count()
		game_audio.call("play_sfx", "ui_click", -16.0)
		_check(game_audio.get_child_count() == audio_players_before + 1, "Playing a sound effect should create an audio player.")
	var animation_scene := load("res://assets/animations/quaternius/AnimationLibrary_Godot_Standard.gltf") as PackedScene
	_check(animation_scene != null, "The downloaded humanoid animation library should import as a Godot scene.")
	if animation_scene != null:
		var animation_instance := animation_scene.instantiate()
		root.add_child(animation_instance)
		var imported_player := animation_instance.get_node_or_null("AnimationPlayer") as AnimationPlayer
		_check(is_instance_valid(imported_player), "The animation library should provide an AnimationPlayer.")
		if is_instance_valid(imported_player):
			for clip_name in ["Idle", "Walk", "Jog_Fwd", "Sprint", "Punch_Jab", "Punch_Cross", "Hit_Chest", "Hit_Head", "Jump", "Roll", "Dance", "Death01"]:
				_check(imported_player.has_animation(clip_name), "The imported library should contain the %s clip." % clip_name)
		animation_instance.queue_free()
	for style in GameData.ULTIMATE_NAMES:
		var puzzles: Array = GameData.ULTIMATE_PUZZLES[style]
		_check(puzzles.size() == 6, "%s should have six ultimate challenges." % style)
		for puzzle in puzzles:
			_check(puzzle.answers.has(puzzle.correct), "%s puzzle answers should include the solution." % style)
	for character in GameData.CHARACTERS:
		var has_signature := false
		for style in GameData.STYLE_MOVES:
			for move in GameData.moves_for_style(style, 6, character.signature):
				if move.get("kind") == "ultimate" and move.get("signature", false):
					has_signature = true
		_check(has_signature, "%s should have a signature ultimate." % character.name)

	var scene: PackedScene = load("res://scenes/main.tscn")
	var game: Node = scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	_check(is_instance_valid(game.main_menu) and game.main_menu.visible, "Launching the game should open the main menu.")
	_check(game.main_menu_open and not game.hud.visible, "The main menu should pause combat and hide the fighter HUD.")
	game._on_menu_board_games_requested()
	await process_frame
	_check(is_instance_valid(game.games_hub) and game.main_menu_open, "The main menu should open board games without advancing combat.")
	_check(not game.hud.visible, "The board-games menu should not expose the fighter HUD.")
	game._close_games_hub()
	await process_frame
	_check(game.main_menu.visible and game.main_menu_open, "Leaving board games launched from the menu should return to the main menu.")
	game.main_menu.call("show_settings", 1.0, false, "Normal")
	_check(game.main_menu.find_child("MasterVolume", true, false) != null, "Settings should expose a master-volume control.")
	var difficulty_select := game.main_menu.find_child("AIDifficulty", true, false) as OptionButton
	_check(is_instance_valid(difficulty_select) and difficulty_select.item_count == 3, "Settings should offer Easy, Normal, and Hard AI difficulty.")
	game.main_menu.call("show_home")
	game._on_menu_pvp_requested()
	_check(game.main_menu.status_label.text.contains("NOT AVAILABLE YET"), "The PvP option should clearly explain online matches are not ready.")
	game._on_menu_versus_ai_requested()
	_check(not game.main_menu_open and game.hud.visible, "Choosing Versus AI should enter the fighter match.")
	_check(is_instance_valid(game.pause_button), "The fight HUD should expose a pause button.")
	game._on_settings_changed(game.master_volume, game.fullscreen_enabled, "Hard")
	_check(game.ai_difficulty == "Hard" and game._ai_profile().decision_interval < 0.5, "Hard AI should make decisions substantially faster.")
	game._open_pause_menu()
	_check(game.pause_menu_open and game.get_tree().paused and game.main_menu.visible, "The pause button should pause the match and open pause settings.")
	_check(game.main_menu.find_child("AIDifficulty", true, false) != null, "Pause settings should allow changing AI difficulty.")
	game._on_pause_resume_requested()
	_check(not game.pause_menu_open and not game.get_tree().paused and game.hud.visible, "Resume should unpause the match and restore the fighter HUD.")
	game._open_pause_menu()
	game._on_pause_return_to_menu_requested()
	_check(game.main_menu_open and not game.get_tree().paused and game.main_menu.visible, "Quit to Main Menu should safely unpause and return to mode selection.")
	game._on_menu_versus_ai_requested()
	_check(is_instance_valid(game.player_node), "The player fighter should spawn.")
	_check(is_instance_valid(game.enemy_node), "The AI fighter should spawn.")
	game._start_match()
	game.ai_difficulty = "Hard"
	game.player_node.position = Vector3(-0.7, 0.0, 0.0)
	game.enemy_node.position = Vector3(0.7, 0.0, 0.0)
	game._update_fighter_facing()
	game._on_basic_attack("punch")
	game._update_ai(0.016)
	_check(game.enemy_guard > 0.0 and game.enemy_node.get_meta("anim_action") == "block", "Hard AI should read and block an incoming strike.")
	game._start_match()
	game.ai_clock = 0.0
	game.player_node.position = Vector3(-0.65, 0.0, 0.0)
	game.enemy_node.position = Vector3(0.65, 0.0, 0.0)
	game._update_fighter_facing()
	game._update_ai(0.016)
	_check(game.enemy_node.get_meta("attack_active"), "AI should launch an attack when the fighters are in range.")
	game.ai_difficulty = "Easy"
	_check(game._ai_profile().decision_interval > 1.4 and game._ai_profile().chase_speed < 0.7, "Easy AI should react and approach more slowly.")
	game.ai_difficulty = "Normal"
	game._start_match()
	_check(is_instance_valid(game.loadout_button), "The fighter HUD should expose the loadout manager.")
	_check(is_instance_valid(game.combo_lab_button) and is_instance_valid(game.combo_lab), "The fighter HUD should expose the combo companion.")
	_check(is_instance_valid(game.story_button) and is_instance_valid(game.story_campaign), "The fighter HUD should expose the story campaign.")
	_check(game.story_campaign.CHAPTERS.size() == 3, "The original story campaign should contain three chapters.")
	var selected_story_character: int = game.player_character_index
	game._toggle_story_campaign()
	_check(game.challenge_active and game.story_campaign.visible, "Opening the story campaign should pause the duel and display its chapter.")
	game.story_campaign.call("_start_chapter", 0)
	_check(game.story_mode_active and game.story_stage_index == 0, "Entering a story chapter should start story mode at chapter one.")
	_check(game.player_character_index == selected_story_character and game.opponent_character_index == 8 and game.opponent_style == "Chess", "A story fight should keep the selected player and use its configured rival.")
	game._end_match(true)
	_check(game.story_progress == 1, "Winning a story fight should save the next chapter as unlocked.")
	_check(game.story_campaign.primary_button.text == "NEXT CHAPTER", "A story victory should offer the next chapter.")
	game.story_campaign.call("_on_primary_pressed")
	_check(game.story_campaign.chapter_label.text.contains("THE GRAVITY WELL"), "Continuing should present the next original chapter.")
	game.story_campaign.call("show_result", 1, false, 1)
	_check(game.story_campaign.primary_button.text == "RETRY CHAPTER", "A story defeat should offer a retry.")
	game.story_campaign.call("_on_primary_pressed")
	_check(game.story_stage_index == 1 and game.opponent_character_index == 1 and game.opponent_style == "Cards", "Retrying should restart the same story encounter.")
	game._on_story_exit_requested()
	var regular_opponent := 1 if selected_story_character != 1 else 0
	_check(not game.story_mode_active and game.opponent_character_index == regular_opponent, "Leaving story mode should restore the regular opponent.")
	var combo_lab_script: Script = load("res://scripts/combo_lab.gd")
	var combo_lab := Control.new()
	combo_lab.set_script(combo_lab_script)
	var combo_library_path := "user://smoke_test_combos.json"
	for path in [combo_library_path, combo_library_path + ".backup"]:
		if FileAccess.file_exists(path):
			_check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "Could not clear stale combo test data.")
	combo_lab.library_path = combo_library_path
	root.add_child(combo_lab)
	await process_frame
	var parsed_combo: Dictionary = combo_lab.call("_parse_notation", "P > JK > Diamond Pierce")
	_check(parsed_combo.ok and parsed_combo.steps == ["Punch", "Jump Kick", "Diamond Pierce"], "The combo notation translator should resolve standard and style-move notation.")
	_check(not combo_lab.call("_parse_notation", "P > made-up-move").ok, "Unknown combo notation should be rejected clearly.")
	combo_lab.selected_index = 0
	combo_lab.combos[0] = {
		"name": "Round Trip",
		"style": "Any",
		"notation": "P > K",
		"notes": "Smoke-test export",
		"steps": ["Punch", "Kick"],
		"successes": 0
	}
	var round_trip_combo: Dictionary = combo_lab.combos[0].duplicate(true)
	combo_lab.combos.clear()
	combo_lab.combos.append(round_trip_combo)
	var combo_export: String = combo_lab.call("export_selected")
	combo_lab.combos.clear()
	combo_lab.selected_index = -1
	var import_result: Dictionary = combo_lab.call("import_text", combo_export)
	_check(import_result.ok and import_result.count == 1, "A combo should export and import in a local round trip.")
	var duplicate_import: Dictionary = combo_lab.call("import_text", combo_export)
	_check(not duplicate_import.ok, "The combo library should reject duplicate imported entries.")
	combo_lab.practice_index = 0
	combo_lab.practice_step = 0
	combo_lab.practicing = true
	combo_lab.call("record_successful_move", "Punch")
	combo_lab.call("record_successful_move", "Kick")
	_check(not combo_lab.practicing and int(combo_lab.combos[0].successes) == 1, "A confirmed combo sequence should stop practice and track a success.")
	for path in [combo_library_path, combo_library_path + ".backup"]:
		if FileAccess.file_exists(path):
			_check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "Could not clean temporary combo test data.")
	combo_lab.queue_free()
	game.combo_lab.library_path = combo_library_path
	game.combo_lab.combos.clear()
	var combat_practice_combo := {
		"name": "Connected Strike Test",
		"style": "Any",
		"notation": "P > K",
		"notes": "Verify real combat impacts advance practice.",
		"steps": ["Punch", "Kick"],
		"successes": 0
	}
	game.combo_lab.combos.append(combat_practice_combo)
	game.combo_lab.selected_index = 0
	game._start_match()
	game.player_node.position = Vector3(-0.5, 0.0, 0.0)
	game.enemy_node.position = Vector3(0.5, 0.0, 0.0)
	game._update_fighter_facing()
	game.combo_lab.practicing = true
	game.combo_lab.practice_index = 0
	game.combo_lab.practice_step = 0
	game._on_combo_practice_changed(true, combat_practice_combo)
	var practice_enemy_hp: float = game.enemy_hp
	game._on_basic_attack("punch")
	await create_timer(0.1).timeout
	_check(game.combo_lab.practice_step == 1, "A landed player punch should advance combo practice.")
	_check(is_equal_approx(game.enemy_hp, practice_enemy_hp), "Combo practice should register hits without damaging its dummy.")
	game._on_basic_attack("kick")
	await create_timer(0.65).timeout
	_check(not game.combo_lab_active and int(game.combo_lab.combos[0].successes) == 1, "Connected buffered attacks should complete and record a combo practice success.")
	_check(is_equal_approx(game.enemy_hp, practice_enemy_hp), "Even the final practice hit should not damage the dummy.")
	_check(is_equal_approx(game.enemy_node.position.x, 0.5), "Combo practice hits should not knock the dummy away.")
	for path in [combo_library_path, combo_library_path + ".backup"]:
		if FileAccess.file_exists(path):
			_check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "Could not clean combat combo test data.")
	_check(game.player_node.get_node_or_null("Rig/Skeleton3D/GlowEyes") != null, "The player avatar should have glowing eyes.")
	_check(game.player_node.get_node_or_null("Aura") == null and game.enemy_node.get_node_or_null("Aura") == null, "Fighters should not have glowing rings around their feet.")
	_check(is_instance_valid(game.player_ultimate_bar) and is_instance_valid(game.enemy_ultimate_bar), "Both fighters should have visible ultimate readiness meters.")
	_check(game.player_ultimate_bar.max_value == 4.0 and game.enemy_ultimate_bar.max_value == 4.0, "Ultimate meters should fill to the four-MP ultimate cost.")
	_check(game.player_node.get_node_or_null("Rig/Skeleton3D/Mannequin") != null and game.enemy_node.get_node_or_null("Rig/Skeleton3D/Mannequin") != null, "Both fighters should use the imported humanoid mesh.")
	_check(game.player_node.get_node_or_null("AnimationPlayer") != null and game.enemy_node.get_node_or_null("AnimationPlayer") != null, "Both fighters should have animation players.")
	var player_forward: Vector3 = game.player_node.global_transform.basis.z.normalized()
	var player_toward_enemy: Vector3 = (game.enemy_node.global_position - game.player_node.global_position).normalized()
	var enemy_forward: Vector3 = game.enemy_node.global_transform.basis.z.normalized()
	var enemy_toward_player: Vector3 = (game.player_node.global_position - game.enemy_node.global_position).normalized()
	_check(player_forward.dot(player_toward_enemy) > 0.99, "The player should face the AI opponent.")
	_check(enemy_forward.dot(enemy_toward_player) > 0.99, "The AI opponent should face the player.")
	var player_material := (game.player_node.get_node("Rig/Skeleton3D/Mannequin") as MeshInstance3D).material_override as ShaderMaterial
	var enemy_material := (game.enemy_node.get_node("Rig/Skeleton3D/Mannequin") as MeshInstance3D).material_override as ShaderMaterial
	_check(player_material.get_shader_parameter("base_color") != enemy_material.get_shader_parameter("base_color"), "The human and AI fighters should have contrasting palettes.")
	_check(player_material.shader.code.contains("diffuse_toon") and player_material.next_pass is ShaderMaterial, "Fighters should render with toon shading and a dark outline pass.")
	var outline_material := player_material.next_pass as ShaderMaterial
	_check(outline_material.shader.code.contains("VIEWPORT_SIZE") and is_equal_approx(float(outline_material.get_shader_parameter("outline_width_pixels")), 2.5), "Fighter outlines should use a consistent screen-space thickness.")
	var fighter_animation_player := game.player_node.get_node("AnimationPlayer") as AnimationPlayer
	_check(fighter_animation_player.has_animation("Fighter/Kick") and fighter_animation_player.has_animation("Fighter/AerialKick") and fighter_animation_player.has_animation("Fighter/Grab") and fighter_animation_player.has_animation("Fighter/Block") and fighter_animation_player.has_animation("Fighter/Charge"), "Procedural fallback clips should provide moves absent from the downloaded library.")
	var kick_clip := fighter_animation_player.get_animation("Fighter/Kick")
	var kick_shin_track := kick_clip.find_track(NodePath("Rig/Skeleton3D:DEF-shin.R"), Animation.TYPE_ROTATION_3D)
	_check(kick_shin_track >= 0 and kick_clip.track_get_key_count(kick_shin_track) == 7, "A ground kick should have chamber, contact, follow-through, and recovery poses.")
	if kick_shin_track >= 0:
		_check(is_equal_approx(kick_clip.track_get_key_time(kick_shin_track, 3), kick_clip.length * 7.0 / 22.0), "The kick's fully extended contact pose should align with its active attack frame.")
	var grab_clip := fighter_animation_player.get_animation("Fighter/Grab")
	var grab_arm_track := grab_clip.find_track(NodePath("Rig/Skeleton3D:DEF-upper_arm.L"), Animation.TYPE_ROTATION_3D)
	_check(grab_arm_track >= 0 and is_equal_approx(grab_clip.track_get_key_time(grab_arm_track, 2), grab_clip.length * 5.0 / 18.0), "The grab's reach pose should align with its contact frame.")
	_check(game.cards_grid.get_child_count() >= 12, "The move deck should show style moves and ultimates.")
	_check(fighter_animation_player.current_animation == "Idle", "Fighters should start in the imported idle animation.")
	var original_character: int = game.player_character_index
	var original_style: String = game.player_style
	var smoke_profile: Array[Dictionary] = [{"name": "Smoke Preset", "character": 2, "style": "Ludo"}]
	game.loadout_profiles = smoke_profile
	game._open_loadouts()
	_check(game.loadout_dialog.visible and game.loadout_option.item_count == 1, "The loadout window should show saved presets.")
	game._apply_selected_loadout()
	_check(game.player_character_index == 2 and game.player_style == "Ludo", "Applying a preset should restore its character and style.")
	game.loadout_dialog.hide()
	game.player_character_index = original_character
	game.player_style = original_style
	game.player_data = GameData.CHARACTERS[original_character]
	game.character_option.select(original_character)
	game.style_option.select(GameData.STYLE_MOVES.keys().find(original_style))
	game._start_match()
	game._rebuild_move_cards()
	fighter_animation_player = game.player_node.get_node("AnimationPlayer") as AnimationPlayer

	var smoke_loadouts_path := "user://smoke_test_loadouts.json"
	var smoke_backup_path := "user://smoke_test_loadouts.backup.json"
	for path in [smoke_loadouts_path, smoke_backup_path]:
		if FileAccess.file_exists(path):
			_check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "Could not clear a stale loadout smoke-test file.")
	var saved_profiles: Array[Dictionary] = [{"name": "Saved Preset", "character": 1, "style": "Chess"}]
	var changed_profiles: Array[Dictionary] = [{"name": "Changed Preset", "character": 4, "style": "Cards"}]
	game.loadout_profiles = saved_profiles
	game._backup_loadouts(smoke_loadouts_path, smoke_backup_path)
	var manual_backup: Dictionary = game._read_loadouts_file(smoke_backup_path)
	_check(manual_backup.ok and manual_backup.profiles == saved_profiles, "Manual backup should preserve the current presets.")
	_check(game._write_loadouts_file(smoke_loadouts_path, saved_profiles) == OK, "A valid loadout file should save.")
	_check(game._write_loadouts_file(smoke_loadouts_path, changed_profiles, smoke_backup_path) == OK, "Updating loadouts should create a backup of the previous file.")
	var backup_profiles: Dictionary = game._read_loadouts_file(smoke_backup_path)
	_check(backup_profiles.ok and backup_profiles.profiles == saved_profiles, "The automatic backup should preserve the prior presets.")
	game.loadout_profiles = changed_profiles
	game._restore_loadouts(smoke_loadouts_path, smoke_backup_path)
	_check(game.loadout_profiles == saved_profiles, "Restoring a backup should return the saved presets.")
	for path in [smoke_loadouts_path, smoke_backup_path]:
		if FileAccess.file_exists(path):
			_check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "Could not clean a loadout smoke-test file.")

	game._play_fighter_action(game.player_node, "victory", 100000.0)
	_check(fighter_animation_player.current_animation == "Dance", "A match winner should use the imported victory animation.")
	game._play_fighter_action(game.player_node, "knockout", 100000.0)
	_check(fighter_animation_player.current_animation == "Death01", "A defeated fighter should use the imported knockout animation.")
	game._start_match()
	fighter_animation_player = game.player_node.get_node("AnimationPlayer") as AnimationPlayer
	_check(is_equal_approx(game.player_hp, 300.0) and is_equal_approx(game.enemy_hp_bar.max_value, 300.0), "Fighters should start with 300 HP and matching health meters.")
	game.player_node.position = Vector3(-1.0, 0.0, 0.0)
	game.enemy_node.position = Vector3(1.0, 0.0, 0.0)
	game.joystick_vector = Vector2(0.0, -1.0)
	game._update_player_movement(0.2)
	_check(game.player_node.position.z < 0.0, "Forward input should consistently move toward the far side of the arena.")
	game.player_node.position = Vector3(-1.2, 0.0, 0.0)
	game.enemy_node.position = Vector3.ZERO
	game._move_fighter(game.player_node, game.enemy_node, Vector3(0.3, 0.0, 0.3))
	_check(game.player_node.position.z > 0.0, "Fighters should be able to slide around one another.")
	_check(game.player_node.position.distance_to(game.enemy_node.position) >= 1.19, "Fighters should maintain personal space while moving.")
	game.joystick_vector = Vector2.ZERO
	game.player_node.position = Vector3(-1.0, 0.0, 0.0)
	game.enemy_node.position = Vector3(1.0, 0.0, 0.0)
	game._update_fighter_facing()
	var distant_punch_hp: float = game.enemy_hp
	game._on_basic_attack("punch")
	_check(is_equal_approx(game.enemy_hp, distant_punch_hp), "A punch outside physical reach should whiff instead of damaging the opponent.")
	await create_timer(0.4).timeout
	game.player_node.position = Vector3(1.0, 0.0, 0.0)
	game.enemy_node.position = Vector3(-0.2, 0.0, 0.0)
	game._update_fighter_facing()
	game.player_node.rotation.y += PI
	var facing_miss_hp: float = game.enemy_hp
	game._on_basic_attack("punch")
	_check(is_equal_approx(game.enemy_hp, facing_miss_hp), "A punch facing away from the opponent should whiff.")
	await create_timer(0.05).timeout
	game.player_node.position = Vector3(-0.5, 0.0, 0.0)
	game.enemy_node.position = Vector3(0.5, 0.0, 0.0)
	game._update_fighter_facing()
	var initial_enemy_hp: float = game.enemy_hp
	game._on_basic_attack("punch")
	_check(is_equal_approx(game.enemy_hp, initial_enemy_hp), "A strike should not deal damage before its active animation frames.")
	var punch_frame_data: Dictionary = game.player_node.get_meta("attack_state").frame_data
	_check(punch_frame_data.startup_frames == 4 and punch_frame_data.active_frames == 2 and punch_frame_data.recovery_frames == 10, "Punches should use explicit startup, active, and recovery frame data.")
	game._on_basic_attack("kick")
	_check(game.player_node.has_meta("pending_attack_move"), "A fast follow-up should be buffered rather than cutting off the first strike.")
	await create_timer(0.09).timeout
	_check(game.enemy_hp < initial_enemy_hp, "The punch should connect on its animation's active frame.")
	_check(initial_enemy_hp - game.enemy_hp < 36.0, "A normal hit should remove only a small fraction of the expanded health pool.")
	_check(is_zero_approx((game.enemy_node.get_node("AnimationPlayer") as AnimationPlayer).speed_scale), "A connected hit should have a brief impact pause.")
	_check(game.camera_shake_strength > 0.0 and game.arena_root.get_node_or_null("ImpactFlash") != null, "A connected combo should add camera impact and a visible hit flash.")
	await create_timer(0.05).timeout
	_check((game.enemy_node.get_node("AnimationPlayer") as AnimationPlayer).speed_scale > 0.0, "The impact pause should end quickly and allow hit reactions to continue.")
	_check(game.enemy_hp_bar.value > game.enemy_hp, "The HP bar should drain gradually instead of snapping down.")
	_check(game.hp_bar_tweens.enemy.is_running(), "The HP drain animation should remain active after a hit.")
	_check(game.enemy_node.get_meta("anim_action") == "hit_react", "A connected punch should trigger the opponent's hit reaction.")
	await create_timer(0.16).timeout
	_check(fighter_animation_player.current_animation == "Fighter/Kick", "A buffered kick should start as the punch animation recovers.")
	_check(game.player_node.has_meta("attack_state") and game.player_node.get_meta("attack_state").frame_data.startup_frames == 7, "The follow-up kick should use its own slower active-frame timing.")
	game.challenge_active = true
	await create_timer(0.15).timeout
	_check(game.enemy_node.position.x > 0.8, "A successful kick should knock the opponent back.")
	_check(initial_enemy_hp - game.enemy_hp <= 25.0, "A short punch-kick combo should not remove excessive health.")

	game._start_match()
	fighter_animation_player = game.player_node.get_node("AnimationPlayer") as AnimationPlayer
	game.player_node.position = Vector3(-0.8, 0.0, 0.0)
	game.enemy_node.position = Vector3(0.8, 0.0, 0.0)
	game._update_fighter_facing()
	var fighter_skeleton := game.player_node.get_node("Rig/Skeleton3D") as Skeleton3D
	var right_thigh := fighter_skeleton.find_bone("DEF-thigh.R")
	var right_foot := fighter_skeleton.find_bone("DEF-foot.R")
	var idle_foot_height := fighter_skeleton.to_global(fighter_skeleton.get_bone_global_pose(right_foot).origin).y
	var kick_pose_before := fighter_skeleton.get_bone_pose_rotation(right_thigh)
	var initial_kick_hp: float = game.enemy_hp
	game._on_basic_attack("kick")
	game.challenge_active = true
	await create_timer(0.15).timeout
	_check(game.enemy_hp < initial_kick_hp, "A kick from just outside contact should connect within a few frames.")
	var kicking_rig := game.player_node.get_node("Rig") as Node3D
	_check(kicking_rig.position.y > 0.03, "The ground kick should lift the kicking rig clear of the arena floor during extension.")
	await create_timer(0.1).timeout
	_check(game.player_node.get_meta("anim_action") == "kick" and fighter_animation_player.current_animation == "Fighter/Kick", "A kick should play its procedural skeleton animation.")
	_check(kick_pose_before.angle_to(fighter_skeleton.get_bone_pose_rotation(right_thigh)) > 0.05, "The procedural kick clip should animate the humanoid skeleton.")
	var min_kick_foot_height := INF
	for sample in range(30):
		await create_timer(0.02).timeout
		var foot_height := fighter_skeleton.to_global(fighter_skeleton.get_bone_global_pose(right_foot).origin).y
		min_kick_foot_height = minf(min_kick_foot_height, foot_height)
	_check(min_kick_foot_height >= idle_foot_height - 0.05, "A kick should keep the kicking foot above the arena floor throughout the motion.")
	_check(game.enemy_node.position.x > 1.0, "A successful kick should knock the opponent back.")

	game._start_match()
	fighter_animation_player = game.player_node.get_node("AnimationPlayer") as AnimationPlayer
	game.player_node.position = Vector3(-0.65, 0.0, 0.0)
	game.enemy_node.position = Vector3(0.65, 0.0, 0.0)
	game._update_fighter_facing()
	var pre_grab_enemy_hp: float = game.enemy_hp
	game._on_basic_attack("grab")
	await create_timer(0.16).timeout
	_check(game.grapple_holder == game.player_node and game.grapple_victim == game.enemy_node, "A successful grab should hold the opponent.")
	_check(game.player_node.get_meta("anim_action") == "grab_hold" and fighter_animation_player.current_animation == "Fighter/GrabHold", "A grab should play its procedural hold animation.")
	_check(game.enemy_node.get_meta("anim_action") == "grabbed", "A held target should use a restrained pose.")
	_check(is_equal_approx(game.enemy_hp, pre_grab_enemy_hp), "Starting a grapple should not apply the follow-up damage early.")
	game._on_basic_attack("kick")
	_check(game.grapple_holder == null and game.enemy_hp < pre_grab_enemy_hp, "A kick follow-up should throw the held opponent and deal damage.")
	_check(game.enemy_node.position.x > 0.8, "A grapple throw should send the opponent away from the holder.")

	game._start_match()
	game.player_node.position = Vector3(-0.65, 0.0, 0.0)
	game.enemy_node.position = Vector3(0.65, 0.0, 0.0)
	game._update_fighter_facing()
	var pre_grapple_punch_hp: float = game.enemy_hp
	game._on_basic_attack("grab")
	await create_timer(0.16).timeout
	game._on_basic_attack("punch")
	_check(game.grapple_holder == null and game.enemy_hp < pre_grapple_punch_hp, "A punch follow-up should damage and release a held opponent.")

	game._start_match()
	var pre_escape_player_hp: float = game.player_hp
	game._start_grapple(false, game.enemy_node, game.player_node)
	game._on_basic_attack("punch")
	game._on_basic_attack("kick")
	game._on_basic_attack("punch")
	_check(game.grapple_victim == null and game.player_hp == pre_escape_player_hp, "Repeated attacks should break a grapple without taking follow-up damage.")

	game._start_match()
	game.player_node.position = Vector3(-0.65, 0.0, 0.0)
	game.enemy_node.position = Vector3(0.65, 0.0, 0.0)
	game._update_fighter_facing()
	var pre_timeout_throw_hp: float = game.enemy_hp
	game._on_basic_attack("grab")
	await create_timer(0.16).timeout
	game.grapple_timer = 0.01
	game._update_grapple(0.02)
	_check(game.grapple_holder == null and game.enemy_hp < pre_timeout_throw_hp, "A grapple should automatically throw its target if they do not escape in time.")

	game._start_match()
	fighter_animation_player = game.player_node.get_node("AnimationPlayer") as AnimationPlayer
	game._on_block()
	game.challenge_active = true
	await create_timer(0.12).timeout
	_check(game.player_node.get_meta("anim_action") == "block" and fighter_animation_player.current_animation == "Fighter/Block", "Block should play its procedural skeleton animation.")
	game.challenge_active = false
	game._on_jump()
	game.challenge_active = true
	await create_timer(0.12).timeout
	_check(game.player_node.get_meta("anim_action") == "jump" and fighter_animation_player.current_animation == "Jump" and game.player_node.position.y > 0.3, "Jump should play its imported animation and lift the fighter.")
	await create_timer(0.85).timeout
	_check(is_zero_approx(game.player_node.position.y), "A jump animation should land back on the arena floor.")

	game._start_match()
	fighter_animation_player = game.player_node.get_node("AnimationPlayer") as AnimationPlayer
	game.player_node.position = Vector3(-1.0, 0.0, 0.0)
	game.enemy_node.position = Vector3(1.0, 0.0, 0.0)
	var pre_jump_kick_hp: float = game.enemy_hp
	game._on_jump()
	game._on_basic_attack("kick")
	_check(bool(game.player_node.get_meta("airborne")), "A player should be able to attack during a jump.")
	_check(game.player_node.get_meta("anim_action") == "aerial_kick" and fighter_animation_player.current_animation == "Fighter/AerialKick", "An airborne kick should use its dedicated tucked-and-extended animation.")
	await create_timer(0.16).timeout
	_check(game.enemy_hp < pre_jump_kick_hp, "A jump kick should damage the opponent after it connects.")
	await create_timer(0.15).timeout
	_check(game.player_node.position.y > 0.5, "A jump attack should preserve the rising-and-falling jump arc.")
	await create_timer(0.85).timeout
	_check(not bool(game.player_node.get_meta("airborne")) and is_zero_approx(game.player_node.position.y), "A jump attack should still land naturally.")

	game._start_match()
	game.player_node.position = Vector3(-1.0, 0.0, 0.0)
	game.enemy_node.position = Vector3(1.0, 0.0, 0.0)
	var pre_jump_punch_hp: float = game.enemy_hp
	game._on_jump()
	game._on_basic_attack("punch")
	_check(bool(game.player_node.get_meta("airborne")), "A player should be able to punch during a jump.")
	await create_timer(0.16).timeout
	_check(game.enemy_hp < pre_jump_punch_hp, "A jump punch should damage the opponent after it connects.")

	game._start_match()
	fighter_animation_player = game.player_node.get_node("AnimationPlayer") as AnimationPlayer
	game._apply_move(true, {"name": "Test Guard", "kind": "block", "guard": 8, "cost": 0}, 2.0)
	_check(game.player_node.get_meta("anim_action") == "block", "Style block moves should use the guard animation.")
	game._apply_move(true, {"name": "Test Charge", "kind": "charge", "charge": 1, "cost": 0}, 2.0)
	_check(game.player_node.get_meta("anim_action") == "charge", "Style charge moves should use the energy-gathering animation.")
	game._apply_move(true, {"name": "Test Dodge", "kind": "dodge", "cost": 0}, 2.0)
	_check(game.player_node.get_meta("anim_action") == "dodge", "Style dodge moves should use an evasive animation.")

	game._start_match()
	fighter_animation_player = game.player_node.get_node("AnimationPlayer") as AnimationPlayer
	game.joystick_vector = Vector2(0.0, -0.5)
	game._update_player_movement(0.1)
	_check(float(game.player_node.get_meta("locomotion_speed")) > 0.0 and float(game.player_node.get_meta("locomotion_speed")) < 1.0, "Partial joystick input should animate a walk.")
	game._on_sprint_toggled(true)
	game._update_player_movement(0.1)
	_check(is_equal_approx(float(game.player_node.get_meta("locomotion_speed")), 1.0), "The run control should switch movement to a running gait.")
	game.joystick_vector = Vector2.ZERO

	game._toggle_training()
	_check(game.training_mode and game.challenge_active, "Training should open its challenge.")
	var initial_level: int = game.player_level
	var initial_xp: int = game.player_xp
	game._submit_training("wrong", "correct")
	_check(game.challenge_active and game.player_xp == initial_xp, "A failed answer should allow a retry.")
	game._submit_training("correct", "correct")
	_check(not game.challenge_active and (game.player_level > initial_level or game.player_xp > initial_xp), "A correct answer should clear training and award XP.")

	var hub_script: Script = load("res://scripts/games_hub.gd")
	var hub := Control.new()
	hub.set_script(hub_script)
	root.add_child(hub)
	await process_frame
	hub.call("_start_chess")
	var chess: Dictionary = hub.get("game_state")
	_check(chess.board.size() == 64 and hub.call("_all_chess_moves", 1).size() == 20, "Chess should start with the standard setup and twenty legal opening moves.")
	hub.call("_on_chess_square", 52)
	hub.call("_on_chess_square", 36)
	chess = hub.get("game_state")
	_check(chess.ply == 2 and chess.turn == 1, "Chess should accept a legal human move and allow the AI reply.")

	hub.call("_start_checkers")
	var checkers: Dictionary = hub.get("game_state")
	var player_pieces := 0
	var enemy_pieces := 0
	for piece in checkers.board:
		if piece > 0:
			player_pieces += 1
		elif piece < 0:
			enemy_pieces += 1
	_check(player_pieces == 12 and enemy_pieces == 12, "Checkers should start with twelve pieces per side.")
	checkers.board.fill(0)
	checkers.board[34] = 1
	checkers.board[25] = -1
	checkers.board[41] = 1
	checkers.forced = -1
	_check(hub.call("_checkers_all_moves", 1).size() == 1 and hub.call("_checkers_all_moves", 1)[0].to == 16, "Checkers should force a capture when one is available.")

	hub.call("_start_ludo")
	var ludo: Dictionary = hub.get("game_state")
	_check(ludo.tokens.size() == 4 and ludo.tokens[0].size() == 4, "Ludo should provide four colors with four tokens each.")
	ludo.tokens[0][0] = 1
	ludo.tokens[1][0] = 43
	ludo.tokens[1][1] = 43
	_check(not hub.call("_ludo_can_move", 0, 0, 4), "Ludo pieces should not pass an opponent blockade.")
	ludo.tokens[1][1] = -1
	ludo.tokens[0][0] = 5
	ludo.tokens[1][0] = 43
	hub.call("_ludo_apply_move", 1, 0, 1)
	_check(ludo.tokens[0][0] == -1, "Ludo AI tokens should be able to capture the human on an unprotected square.")
	hub.call("_start_ludo")
	ludo = hub.get("game_state")
	ludo.dice = 6
	ludo.roll_pending = false
	hub.call("_ludo_move_token", 0)
	ludo = hub.get("game_state")
	_check(ludo.tokens[0][0] == 0, "A six should bring a Ludo token out of its yard.")

	hub.call("_start_cards")
	var cards: Dictionary = hub.get("game_state")
	_check(cards.hands[0].size() == 7 and cards.hands[1].size() == 7, "Crazy Eights should deal seven cards to each player.")
	_check(cards.deck.size() + cards.discard.size() + cards.hands[0].size() + cards.hands[1].size() == 52, "Crazy Eights should use a complete 52-card deck.")
	cards.deck.clear()
	cards.discard = [cards.discard.back()]
	hub.call("_cards_draw")
	cards = hub.get("game_state")
	_check(cards.over and cards.winner == -1, "Crazy Eights should end in a draw instead of leaving players stuck when no cards remain.")

	hub.call("_start_scrabble")
	var scrabble: Dictionary = hub.get("game_state")
	scrabble.racks[0] = ["C", "A", "T", "R", "E", "S", "N"]
	var pending: Dictionary = hub.get("pending_tiles")
	pending[111] = {"tile": "C", "rack_index": 0, "blank": false}
	pending[112] = {"tile": "A", "rack_index": 1, "blank": false}
	pending[113] = {"tile": "T", "rack_index": 2, "blank": false}
	var word_result: Dictionary = hub.call("_scrabble_validate_pending")
	_check(word_result.ok and word_result.score > 0, "Scrabble should validate a word through the center and score it.")
	hub.call("_scrabble_play")
	scrabble = hub.get("game_state")
	_check(scrabble.scores[0] > 0 and scrabble.board[112] == "A", "Scrabble should commit valid tiles and award points.")
	scrabble.scores = [100, 90]
	scrabble.bag.clear()
	scrabble.racks[0] = []
	scrabble.racks[1] = ["A", "Z"]
	_check(hub.call("_scrabble_finish_if_needed"), "Scrabble should finish when a player empties their rack after the bag runs out.")
	_check(scrabble.scores[0] == 111 and scrabble.scores[1] == 79, "Scrabble should transfer the losing rack's tile values to the player who went out.")

	hub.queue_free()

	if had_progress:
		var progress_file := FileAccess.open(progress_path, FileAccess.WRITE)
		if progress_file:
			progress_file.store_buffer(previous_progress)
			progress_file.close()
		else:
			_check(false, "Could not restore the existing progress save.")
	else:
		_check(DirAccess.remove_absolute(progress_path) == OK, "Could not remove the test progress save.")
	if had_settings:
		_restore_test_file(settings_path, previous_settings)
	else:
		_check(not FileAccess.file_exists(settings_path) or DirAccess.remove_absolute(settings_path) == OK, "Could not remove the test settings save.")
	if had_combo_library:
		_restore_test_file(saved_combo_library_path, previous_combo_library)
	else:
		_check(not FileAccess.file_exists(saved_combo_library_path) or DirAccess.remove_absolute(saved_combo_library_path) == OK, "Could not remove the test combo library.")
	if had_combo_backup:
		_restore_test_file(saved_combo_backup_path, previous_combo_backup)
	else:
		_check(not FileAccess.file_exists(saved_combo_backup_path) or DirAccess.remove_absolute(saved_combo_backup_path) == OK, "Could not remove the test combo backup.")
	if failures == 0:
		print("Godot smoke test passed: fighter combat, combo companion, chess, checkers, Ludo, Crazy Eights, and Scrabble.")
	else:
		print("Godot smoke test failed: %d check(s)." % failures)
	quit(1 if failures > 0 else 0)

func _restore_test_file(path: String, contents: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_buffer(contents)
		file.close()
	else:
		_check(false, "Could not restore test data at %s." % path)
