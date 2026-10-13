extends Node

const SOUNDS: Dictionary = {
	"ui_click": preload("res://assets/audio/kenney/ui_click.ogg"),
	"ui_confirm": preload("res://assets/audio/kenney/ui_confirm.ogg"),
	"ui_error": preload("res://assets/audio/kenney/ui_error.ogg"),
	"attack_swing": preload("res://assets/audio/kenney/attack_swing.ogg"),
	"hit_medium": preload("res://assets/audio/kenney/hit_medium.ogg"),
	"hit_heavy": preload("res://assets/audio/kenney/hit_heavy.ogg"),
	"hit_soft": preload("res://assets/audio/kenney/hit_soft.ogg"),
	"tile_drop": preload("res://assets/audio/kenney/tile_drop.ogg"),
	"board_move": preload("res://assets/audio/kenney/board_move.ogg"),
	"board_capture": preload("res://assets/audio/kenney/board_capture.ogg")
}

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func has_sound(sound_name: String) -> bool:
	return SOUNDS.has(sound_name) and SOUNDS[sound_name] is AudioStream

func play_sfx(sound_name: String, volume_db := -8.0, pitch_variation := 0.0) -> void:
	if not has_sound(sound_name):
		push_error("Unknown or unavailable sound effect: %s" % sound_name)
		return
	var player := AudioStreamPlayer.new()
	player.stream = SOUNDS[sound_name]
	player.volume_db = volume_db
	if pitch_variation > 0.0:
		player.pitch_scale = rng.randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
