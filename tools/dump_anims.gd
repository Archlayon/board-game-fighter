extends SceneTree
func _initialize():
	var s = load("res://stickman.glb") as PackedScene
	var n = s.instantiate()
	var ap = n.get_node("AnimationPlayer") as AnimationPlayer
	print("ANIMS:", ",".join(ap.get_animation_list()))
	quit()
