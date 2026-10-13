class_name TestHitbox
extends Node
## Test stand-in for a GoHitHurt hitbox. It has the same two things FighterCombat uses:
## a `hit_data` dictionary and an `enabled` flag. Turning `enabled` on delivers the hit
## to `target` once. There is no range or collision here, the hit always lands.

var hit_data: Dictionary = {}
var target: TestHurtbox

var enabled := false:
	set(value):
		enabled = value
		if value and target != null:
			var data := hit_data.duplicate()
			data["source"] = self
			target.hit_detected.emit(data)
