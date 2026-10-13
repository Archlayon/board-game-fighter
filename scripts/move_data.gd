class_name MoveData
extends Resource
## One move card. Create one .tres per move in the Godot editor.
## Every style (chess, ludo, cards, checkers, scrabble) uses this same resource,
## so the combat code never needs to know which board game a move came from.

enum Style { CHESS, LUDO, CARDS, CHECKERS, SCRABBLE }
enum Tier { BASIC, MEDIUM, ULTIMATE }
enum UltimateRole { ATTACK, DEFENSE, SPEED }

@export var id: StringName
@export var display_name := ""
@export var style: Style = Style.CHESS
@export var tier: Tier = Tier.BASIC
@export var ultimate_role: UltimateRole = UltimateRole.ATTACK

@export_group("Animation and timing (seconds)")
@export var animation: StringName
@export var startup := 0.15      # before the hitbox turns on
@export var active_time := 0.10  # hitbox is on
@export var recovery := 0.20     # before the next move can start

@export_group("Cost and effect")
@export var mp_cost := 0.0
@export var damage := 10.0
## 0.4 = 40% of the target's max HP (signature ultimates like Big Bang, Black Hole)
@export_range(0.0, 1.0) var percent_max_hp_damage := 0.0
@export var stun_damage := 10.0
## 0 = normal. A Ludo double could be 1: bypasses a normal block (level 1),
## but is still stopped by a strong block (level 2).
@export var block_break_level := 0
@export var grants_invincibility := false

@export_group("Ultimate challenge")
## Mini-challenge shown before an ultimate fires (Scrabble word, chess puzzle, etc.)
@export var challenge_scene: PackedScene


func to_hit_data() -> Dictionary:
	# This dictionary gets merged into the hit info the defender receives.
	return {
		"move_id": id,
		"style": style,
		"tier": tier,
		"damage": damage,
		"percent_max_hp_damage": percent_max_hp_damage,
		"stun_damage": stun_damage,
		"block_break_level": block_break_level,
	}