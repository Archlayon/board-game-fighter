# Fight animation pipeline (Blender -> Godot)

`build_fight_animations.py` holds every fighter clip as keyframed poses on the `Stickman_Rig`
(see the comment at the top for the pose conventions). `build.py` runs it headless and exports the GLB.

    blender -b --python tools/blender/build.py -- <stickman_in.glb> stickman.glb
    cp stickman.glb assets/characters/stickman.glb

Use the ORIGINAL stickman.glb (7 clips) as the input the first time. To tweak a pose, edit the
numbers in `build_fight_animations.py` and re-run; the clip names below are what `main.gd` plays.

Clips: idle, walk, block, block_hit, charge, jab, cross, hook, uppercut, punch_basic, kick_front,
kick_round, sweep, kick_flying, hadoken, shoryuken, tatsumaki, grab, throw, dodge, hit, hit_light,
hit_heavy, stun, knockdown, ko, getup, victory.
