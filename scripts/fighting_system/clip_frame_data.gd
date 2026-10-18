class_name ClipFrameData
extends RefCounted
## Authored combat timing for every fighter clip.
##
## All "clip" numbers are frames of the Blender clip (24 fps) taken straight from
## tools/blender/build_fight_animations.py, so the hitbox follows the pose the animator drew:
##   impact      - first frame the strike is extended (hitbox turns on)
##   active_end  - last frame the strike is still extended (hitbox turns off)
##   cancel_end  - last frame a follow-up move may cancel the recovery
## "game_frames" is how long the whole move lasts at 60 fps. The game stretches the clip over that
## time, so startup / active / recovery are the clip fractions scaled to game frames and always
## line up with the animation.
##   rank        - 1 light punch, 2 kick / medium, 3 heavy / launcher, 4 special (cannot be cancelled)
##   hitstop     - freeze frames (60 fps) when the hit lands
##   knockback   - metres the target slides back
##   react       - clip the defender plays when hit

const DATA := {
	# cancel_end is intentionally generous so buffered follow-ups land during recovery.
	"jab": {"clip_frames": 14, "impact": 4, "active_end": 6, "game_frames": 20, "cancel_end": 16, "rank": 1, "hitstop": 3, "knockback": 0.28, "react": "hit_light"},
	"cross": {"clip_frames": 18, "impact": 6, "active_end": 9, "game_frames": 26, "cancel_end": 20, "rank": 1, "hitstop": 4, "knockback": 0.38, "react": "hit_light"},
	"hook": {"clip_frames": 20, "impact": 7, "active_end": 10, "game_frames": 30, "cancel_end": 22, "rank": 2, "hitstop": 5, "knockback": 0.52, "react": "hit_heavy"},
	"uppercut": {"clip_frames": 22, "impact": 9, "active_end": 12, "game_frames": 32, "cancel_end": 20, "rank": 3, "hitstop": 7, "knockback": 0.48, "react": "hit_heavy"},
	"kick_front": {"clip_frames": 22, "impact": 7, "active_end": 11, "game_frames": 30, "cancel_end": 22, "rank": 2, "hitstop": 5, "knockback": 0.48, "react": "hit_light"},
	"kick_round": {"clip_frames": 26, "impact": 9, "active_end": 13, "game_frames": 36, "cancel_end": 26, "rank": 3, "hitstop": 7, "knockback": 0.68, "react": "hit_heavy"},
	"sweep": {"clip_frames": 26, "impact": 9, "active_end": 13, "game_frames": 38, "cancel_end": 26, "rank": 3, "hitstop": 6, "knockback": 0.42, "react": "hit_heavy"},
	"kick_flying": {"clip_frames": 27, "impact": 11, "active_end": 15, "game_frames": 40, "cancel_end": 28, "rank": 3, "hitstop": 7, "knockback": 0.62, "react": "hit_heavy"},
	"shoryuken": {"clip_frames": 30, "impact": 8, "active_end": 14, "game_frames": 44, "cancel_end": 10, "rank": 4, "hitstop": 9, "knockback": 0.58, "react": "hit_heavy"},
	"tatsumaki": {"clip_frames": 40, "impact": 6, "active_end": 32, "game_frames": 56, "cancel_end": 8, "rank": 4, "hitstop": 6, "knockback": 0.52, "react": "hit_heavy"},
}

## Projectile clips: the energy ball leaves the hands on the "fire" frame instead of at frame 0.
const PROJECTILES := {
	"hadoken": {"clip_frames": 32, "fire": 10, "hitstop": 6, "knockback": 0.70, "react": "hit_heavy"},
}

const ULTIMATE_HITSTOP_FRAMES := 14.0
const KO_HITSTOP_FRAMES := 20.0
const DEFAULT_HITSTOP_FRAMES := 5.0


static func has(clip: String) -> bool:
	return DATA.has(clip)


static func is_projectile_clip(clip: String) -> bool:
	return PROJECTILES.has(clip)


## Startup / active / recovery / total in game frames (60 fps) plus the cancel window.
static func frame_data(clip: String) -> Dictionary:
	var d: Dictionary = DATA[clip]
	var scale := float(d.game_frames) / float(d.clip_frames)
	var startup := maxi(1, roundi(float(d.impact) * scale))
	var active_end := maxi(startup + 1, roundi(float(d.active_end) * scale))
	var total := int(d.game_frames)
	return {
		"startup_frames": startup,
		"active_frames": active_end - startup,
		"recovery_frames": total - active_end,
		"total_frames": total,
		"cancel_start_frame": startup,
		"cancel_end_frame": clampi(roundi(float(d.cancel_end) * scale), startup, total),
		"rank": int(d.rank),
	}


## Game frame (60 fps) of the release pose of a projectile clip, scaled to the move's total length.
static func fire_frame(clip: String, total_frames: int) -> float:
	if not PROJECTILES.has(clip):
		return 0.0
	var d: Dictionary = PROJECTILES[clip]
	return float(d.fire) / float(d.clip_frames) * float(total_frames)


static func hitstop_frames(clip: String) -> float:
	if DATA.has(clip):
		return float(DATA[clip].hitstop)
	if PROJECTILES.has(clip):
		return float(PROJECTILES[clip].hitstop)
	return DEFAULT_HITSTOP_FRAMES


static func knockback(clip: String, fallback: float) -> float:
	if DATA.has(clip):
		return float(DATA[clip].knockback)
	if PROJECTILES.has(clip):
		return float(PROJECTILES[clip].knockback)
	return fallback


static func react_clip(clip: String, fallback: String) -> String:
	if DATA.has(clip):
		return str(DATA[clip].react)
	if PROJECTILES.has(clip):
		return str(PROJECTILES[clip].react)
	return fallback


static func rank(clip: String) -> int:
	return int(DATA[clip].rank) if DATA.has(clip) else 4
