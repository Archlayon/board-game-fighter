"""Headless build: blender -b --python tools/blender/build.py -- <stickman_in.glb> <stickman_out.glb> [bones.json]

Imports the stickman, authors every fight clip (build_fight_animations.py) and exports a new GLB.
"""
import sys, os, json, bpy

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
src, dst = argv[0], argv[1]
dump = argv[2] if len(argv) > 2 else None
here = os.path.dirname(os.path.abspath(__file__))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
arm = bpy.data.objects["Stickman_Rig"]

# the importer also creates helper objects (bone shapes); keep only rig + mesh for export
for o in list(bpy.data.objects):
    if o.type not in {"ARMATURE"} and o.name != "Stickman_Mesh":
        bpy.data.objects.remove(o, do_unlink=True)
if arm.animation_data:
    for t in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(t)
# some Blender versions suffix imported actions with the armature name
for a in bpy.data.actions:
    if a.name.endswith("_Stickman_Rig"):
        a.name = a.name[:-len("_Stickman_Rig")]
    a.use_fake_user = True

code = open(os.path.join(here, "build_fight_animations.py")).read()
g = {"__name__": "fight_build"}
exec(compile(code, "build_fight_animations.py", "exec"), g)
print("BUILT", g["FIGHT_BUILT"])

if dump:
    out = {}
    sc = bpy.context.scene
    for act in bpy.data.actions:
        ad = arm.animation_data
        ad.action = act
        frames = sorted({int(round(kp.co[0])) for fc in g["fcurves_of"](act) for kp in fc.keyframe_points})
        rng = {}
        for f in frames:
            sc.frame_set(f)
            bpy.context.view_layer.update()
            rng[f] = {pb.name: [list(pb.head), list(pb.tail)] for pb in arm.pose.bones}
        out[act.name] = rng
    ad.action = None
    json.dump(out, open(dump, "w"))

for o in bpy.data.objects:
    o.select_set(o.type == "ARMATURE" or o.name == "Stickman_Mesh")
bpy.context.view_layer.objects.active = arm
for a in bpy.data.actions:
    a.use_fake_user = True
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", use_selection=True, export_animations=True,
                          export_animation_mode="ACTIONS", export_force_sampling=True, export_yup=True)
print("EXPORTED", dst)
