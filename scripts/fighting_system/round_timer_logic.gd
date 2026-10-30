extends Node
class_name RoundTimerLogic
## Frame-counted round clock; stable with pause/resume and variable render rate.

signal time_changed(seconds_remaining: int, frames_remaining: int)
signal timed_out

@export_range(1.0, 600.0, 1.0) var round_duration_seconds: float = 60.0
@export var frames_per_second: int = 60

var frames_remaining: int = 3600
var running: bool = false
var _frame_accumulator: float = 0.0
var _timeout_emitted: bool = false


func _ready() -> void:
	reset_round()


func _process(delta: float) -> void:
	if not running:
		return
	_frame_accumulator += delta * float(frames_per_second)
	var elapsed_frames := floori(_frame_accumulator)
	if elapsed_frames <= 0:
		return
	_frame_accumulator -= float(elapsed_frames)
	frames_remaining = maxi(0, frames_remaining - elapsed_frames)
	time_changed.emit(ceili(float(frames_remaining) / float(frames_per_second)), frames_remaining)
	if frames_remaining == 0 and not _timeout_emitted:
		_timeout_emitted = true
		running = false
		timed_out.emit()


func start_round(duration_seconds: float = -1.0) -> void:
	if duration_seconds > 0.0:
		round_duration_seconds = duration_seconds
	reset_round()
	running = true


func pause_round() -> void:
	running = false


func resume_round() -> void:
	if frames_remaining > 0:
		running = true


func reset_round() -> void:
	frames_remaining = roundi(round_duration_seconds * float(frames_per_second))
	_frame_accumulator = 0.0
	_timeout_emitted = false
	time_changed.emit(ceili(float(frames_remaining) / float(frames_per_second)), frames_remaining)
