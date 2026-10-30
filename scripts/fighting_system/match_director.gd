extends Node
class_name MatchDirector
## Round clock and bounded AI rubber-banding based on the current health gap.

signal round_started(round_number: int, round_seconds: int)
signal round_finished(round_number: int, winner: int)
signal match_finished(winner: int)
signal clock_changed(seconds_remaining: int)

@export_range(1, 9, 2) var rounds_to_win: int = 2
@export_range(1, 600, 1) var round_duration_seconds: int = 99
@export_range(1.0, 60.0, 1.0) var clock_update_interval: float = 0.1
@export_range(0.0, 0.5, 0.01) var max_reaction_adjustment: float = 0.2

var round_number: int = 0
var player_round_wins: int = 0
var enemy_round_wins: int = 0
var seconds_remaining: float = 0.0
var round_active: bool = false
var _clock_emit_accumulator: float = 0.0


func _process(delta: float) -> void:
	if not round_active:
		return
	seconds_remaining = maxf(0.0, seconds_remaining - delta)
	_clock_emit_accumulator += delta
	if _clock_emit_accumulator >= clock_update_interval:
		_clock_emit_accumulator = 0.0
		clock_changed.emit(ceili(seconds_remaining))
	if seconds_remaining <= 0.0:
		finish_round(0)


func start_next_round() -> void:
	if player_round_wins >= rounds_to_win or enemy_round_wins >= rounds_to_win:
		match_finished.emit(1 if player_round_wins > enemy_round_wins else -1)
		return
	round_number += 1
	seconds_remaining = float(round_duration_seconds)
	_clock_emit_accumulator = 0.0
	round_active = true
	round_started.emit(round_number, round_duration_seconds)
	clock_changed.emit(round_duration_seconds)


func finish_round(winner: int) -> void:
	if not round_active:
		return
	round_active = false
	if winner > 0:
		player_round_wins += 1
	elif winner < 0:
		enemy_round_wins += 1
	round_finished.emit(round_number, signi(winner))
	if player_round_wins >= rounds_to_win or enemy_round_wins >= rounds_to_win:
		match_finished.emit(1 if player_round_wins > enemy_round_wins else -1)


func ai_reaction_time(base_seconds: float, player_health: float, player_max_health: float,
		enemy_health: float, enemy_max_health: float) -> float:
	var player_ratio := clampf(player_health / maxf(player_max_health, 1.0), 0.0, 1.0)
	var enemy_ratio := clampf(enemy_health / maxf(enemy_max_health, 1.0), 0.0, 1.0)
	# When the AI is behind, shorten reaction delay; when ahead, lengthen it.
	var disadvantage := player_ratio - enemy_ratio
	var adjustment := clampf(disadvantage * max_reaction_adjustment, -max_reaction_adjustment, max_reaction_adjustment)
	return maxf(0.04, base_seconds - adjustment)
