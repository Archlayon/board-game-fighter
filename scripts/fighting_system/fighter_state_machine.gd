# fighter_state_machine.gd
extends Node
class_name FighterStateMachine

enum FighterState {
    IDLE, WALKING, CROUCHING, JUMPING,
    ATTACKING, BLOCKING, HITSTUN, BLOCKSTUN,
    KNOCKDOWN, WAKEUP, THROW, THROWN
}

var current_state: FighterState = FighterState.IDLE
var state_frame: int = 0

func transition_to(new_state: FighterState) -> void:
	exit_state(current_state)
	current_state = new_state
	state_frame = 0
	enter_state(new_state)

func is_actionable() -> bool:
	return current_state in [
		FighterState.IDLE,
		FighterState.WALKING,
		FighterState.CROUCHING
	]

func enter_state(state: FighterState) -> void:
	pass  # Override in subclass or connect signals

func exit_state(state: FighterState) -> void:
	pass  # Override in subclass or connect signals

func _physics_process(_delta: float) -> void:
	if current_state != FighterState.IDLE:
		state_frame += 1