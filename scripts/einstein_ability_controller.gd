extends Node
class_name EinsteinAbilityController
## Albert's gravity meter and Big Bang charge/release state machine.

signal state_changed(new_state: State)
signal gravity_updated(value: float, maximum: float)
signal cooldown_updated(remaining: float, duration: float)

enum State { IDLE, PUNCH, KICK, ULTIMATE_CHARGE, ULTIMATE_RELEASE, RECOVERY }

const MAX_GRAVITY := 100.0
const ULTIMATE_COOLDOWN := 12.0
const RECOVERY_TIME := 0.42

var current_state: State = State.IDLE
var gravity_meter := 0.0
var cooldown_remaining := 0.0
var _state_remaining := 0.0


func _process(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
		cooldown_updated.emit(cooldown_remaining, ULTIMATE_COOLDOWN)
	if _state_remaining > 0.0:
		_state_remaining = maxf(0.0, _state_remaining - delta)
		if _state_remaining == 0.0 and current_state in [State.PUNCH, State.KICK, State.ULTIMATE_RELEASE, State.RECOVERY]:
			_change_state(State.IDLE)


func record_successful_hit(move: Dictionary) -> void:
	if current_state == State.ULTIMATE_CHARGE or current_state == State.ULTIMATE_RELEASE:
		return
	var attack_type := str(move.get("attack_type", ""))
	var is_kick := attack_type == "kick" or str(move.get("animation", "")) in ["kick", "aerial_kick"]
	add_gravity(15.0 if is_kick else 10.0)
	_change_state(State.KICK if is_kick else State.PUNCH)
	_state_remaining = 0.3


func add_gravity(amount: float) -> void:
	var previous := gravity_meter
	gravity_meter = clampf(gravity_meter + amount, 0.0, MAX_GRAVITY)
	if not is_equal_approx(previous, gravity_meter):
		gravity_updated.emit(gravity_meter, MAX_GRAVITY)


func begin_ultimate_charge() -> bool:
	if gravity_meter < MAX_GRAVITY or cooldown_remaining > 0.0:
		return false
	_change_state(State.ULTIMATE_CHARGE)
	return true


func release_ultimate() -> bool:
	if current_state != State.ULTIMATE_CHARGE or gravity_meter < MAX_GRAVITY or cooldown_remaining > 0.0:
		return false
	gravity_meter = 0.0
	gravity_updated.emit(gravity_meter, MAX_GRAVITY)
	cooldown_remaining = ULTIMATE_COOLDOWN
	cooldown_updated.emit(cooldown_remaining, ULTIMATE_COOLDOWN)
	_change_state(State.ULTIMATE_RELEASE)
	_state_remaining = 0.8
	return true


func cancel_charge() -> void:
	if current_state == State.ULTIMATE_CHARGE:
		_change_state(State.IDLE)


func _change_state(next_state: State) -> void:
	if current_state == next_state:
		return
	current_state = next_state
	state_changed.emit(current_state)
