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

## Einstein time-scientist fighter

`create_einstein_fighter.py` rebuilds Albert Einstein from the game's animated fighter rig, using
the supplied design sheets for his layered chrono-coat, atom core, backpack engine, gear, silver
hair and spectacles. It exports `assets/characters/albert_einstein_chrono.glb` for Godot and saves
the editable `albert_einstein_chrono.blend` plus a preview in this folder.

The export also authors `kick_front` and `kick_round` on the actual fighter skeleton. Godot routes
Einstein's ground and aerial kick actions to these clips instead of the old procedural kick pose
that targeted a different rig.

From the Godot project root, run:

    blender -b --python tools/blender/create_einstein_fighter.py

The folder's `.gdignore` keeps Blender source files out of Godot's asset importer.
