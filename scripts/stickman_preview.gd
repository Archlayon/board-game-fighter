extends Node3D

## Small standalone preview for the imported stickman and its animation clips.

func _ready() -> void:
	var player := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		push_error("The imported stickman scene has no AnimationPlayer.")
		return

	var idle_name := _find_animation(player, "idle")
	if idle_name.is_empty():
		push_error("No idle animation was found. Available clips: %s" % [player.get_animation_list()])
		return

	var looping_clips := ["idle", "walk", "run", "charge", "fly_idle", "fly_forward", "fly_up", "fly_down", "crouch_walk"]
	for animation_name in player.get_animation_list():
		if String(animation_name).to_lower() in looping_clips:
			player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
	player.play(idle_name)
	print("Stickman preview playing '%s' (%d imported clips)." % [idle_name, player.get_animation_list().size()])


func _find_animation(player: AnimationPlayer, clip: String) -> StringName:
	for animation_name in player.get_animation_list():
		var name := String(animation_name).to_lower()
		if name == clip or name.ends_with("/" + clip):
			return animation_name
	return StringName()
