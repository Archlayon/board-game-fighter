extends Node
class_name GameplayLogger
## Persistent, low-volume event log for development playtests.

signal event_recorded(line: String)

const LOG_PATH: String = "user://logs/gameplay.jsonl"
const BACKUP_PATH: String = "user://logs/gameplay.previous.jsonl"
const MAX_LOG_BYTES: int = 4 * 1024 * 1024
const MEMORY_EVENT_LIMIT: int = 1200

var enabled: bool = OS.is_debug_build()
var persistence_available: bool = false
var match_id: int = 0
var _events: Array[String] = []
var _volatile_events: Array[String] = []
var _file: FileAccess
var _write_warning_shown: bool = false


func begin_match(details: Dictionary = {}) -> void:
	match_id += 1
	record("match_start", details)


func record(event_name: String, details: Dictionary = {}) -> void:
	if not enabled:
		return
	var event: Dictionary = {
		"timestamp": Time.get_datetime_string_from_system(),
		"elapsed_ms": Time.get_ticks_msec(),
		"frame": Engine.get_process_frames(),
		"match": match_id,
		"event": event_name,
	}
	for key in details:
		event[key] = details[key]
	var line: String = JSON.stringify(event)
	_events.append(line)
	while _events.size() > MEMORY_EVENT_LIMIT:
		_events.pop_front()
	if not _append_line(line):
		_volatile_events.append(line)
		while _volatile_events.size() > MEMORY_EVENT_LIMIT:
			_volatile_events.pop_front()
	event_recorded.emit(line)


func recent_text(max_lines: int = 700) -> String:
	var lines: Array[String] = []
	for path in [BACKUP_PATH, LOG_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		while not file.eof_reached():
			var line: String = file.get_line()
			if not line.is_empty():
				lines.append(line)
		file.close()
	if lines.is_empty():
		lines.assign(_events)
	elif not _volatile_events.is_empty():
		lines.append_array(_volatile_events)
	var first_line: int = maxi(0, lines.size() - maxi(max_lines, 1))
	return "\n".join(lines.slice(first_line))


func log_path_absolute() -> String:
	return ProjectSettings.globalize_path(LOG_PATH)


func _append_line(line: String) -> bool:
	var directory: String = ProjectSettings.globalize_path("user://logs")
	var make_dir_error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if make_dir_error != OK and make_dir_error != ERR_ALREADY_EXISTS:
		_warn_write_failure("cannot create log directory: %s" % error_string(make_dir_error))
		return false
	if FileAccess.file_exists(LOG_PATH):
		var size_file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.READ)
		if size_file != null:
			var exceeds_limit: bool = size_file.get_length() >= MAX_LOG_BYTES
			size_file.close()
			if exceeds_limit:
				if FileAccess.file_exists(BACKUP_PATH):
					var remove_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
					if remove_error != OK:
						_warn_write_failure("cannot rotate previous log: %s" % error_string(remove_error))
						return false
				var rotate_error: Error = DirAccess.rename_absolute(
					ProjectSettings.globalize_path(LOG_PATH), ProjectSettings.globalize_path(BACKUP_PATH))
				if rotate_error != OK:
					_warn_write_failure("cannot rotate gameplay log: %s" % error_string(rotate_error))
					return false
	var mode: FileAccess.ModeFlags = FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE
	_file = FileAccess.open(LOG_PATH, mode)
	if _file == null:
		_warn_write_failure("cannot open gameplay log: %s" % error_string(FileAccess.get_open_error()))
		return false
	_file.seek_end()
	_file.store_line(line)
	_file.flush()
	_file.close()
	_file = null
	persistence_available = true
	return true


func _warn_write_failure(message: String) -> void:
	persistence_available = false
	if _write_warning_shown:
		return
	_write_warning_shown = true
	push_warning("Gameplay log remains available in memory, but %s" % message)
