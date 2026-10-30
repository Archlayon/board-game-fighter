"""Rename a Mixamo armature and export the active character as embedded GLB.

Run in Blender background mode:
  blender -b character.blend --python export_godot_humanoid.py -- --output character.glb

The script uses Blender's active armature and includes its child meshes.
Materials are cleared by default; pass --keep-materials to preserve them.
"""
import argparse
import os
import sys

import bpy


MIXAMO_TO_GODOT = {
    "Hips": "Hips", "Spine": "Spine", "Spine1": "Chest",
    "Spine2": "UpperChest", "Neck": "Neck", "Head": "Head",
    "LeftShoulder": "LeftShoulder", "LeftArm": "LeftUpperArm",
    "LeftForeArm": "LeftLowerArm", "LeftHand": "LeftHand",
    "RightShoulder": "RightShoulder", "RightArm": "RightUpperArm",
    "RightForeArm": "RightLowerArm", "RightHand": "RightHand",
    "LeftUpLeg": "LeftUpperLeg", "LeftLeg": "LeftLowerLeg",
    "LeftFoot": "LeftFoot", "LeftToeBase": "LeftToes",
    "RightUpLeg": "RightUpperLeg", "RightLeg": "RightLowerLeg",
    "RightFoot": "RightFoot", "RightToeBase": "RightToes",
    "LeftHandThumb1": "LeftThumbMetacarpal", "LeftHandThumb2": "LeftThumbProximal",
    "LeftHandThumb3": "LeftThumbDistal", "LeftHandIndex1": "LeftIndexProximal",
    "LeftHandIndex2": "LeftIndexIntermediate", "LeftHandIndex3": "LeftIndexDistal",
    "LeftHandMiddle1": "LeftMiddleProximal", "LeftHandMiddle2": "LeftMiddleIntermediate",
    "LeftHandMiddle3": "LeftMiddleDistal", "LeftHandRing1": "LeftRingProximal",
    "LeftHandRing2": "LeftRingIntermediate", "LeftHandRing3": "LeftRingDistal",
    "LeftHandPinky1": "LeftLittleProximal", "LeftHandPinky2": "LeftLittleIntermediate",
    "LeftHandPinky3": "LeftLittleDistal",
    "RightHandThumb1": "RightThumbMetacarpal", "RightHandThumb2": "RightThumbProximal",
    "RightHandThumb3": "RightThumbDistal", "RightHandIndex1": "RightIndexProximal",
    "RightHandIndex2": "RightIndexIntermediate", "RightHandIndex3": "RightIndexDistal",
    "RightHandMiddle1": "RightMiddleProximal", "RightHandMiddle2": "RightMiddleIntermediate",
    "RightHandMiddle3": "RightMiddleDistal", "RightHandRing1": "RightRingProximal",
    "RightHandRing2": "RightRingIntermediate", "RightHandRing3": "RightRingDistal",
    "RightHandPinky1": "RightLittleProximal", "RightHandPinky2": "RightLittleIntermediate",
    "RightHandPinky3": "RightLittleDistal",
}


def arguments():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="character.glb")
    parser.add_argument("--keep-materials", action="store_true")
    return parser.parse_args(argv)


def main():
    args = arguments()
    armature = bpy.context.view_layer.objects.active
    if armature is None or armature.type != "ARMATURE":
        raise RuntimeError("Select and activate the character armature before running export.")

    previous_mode = armature.mode
    if previous_mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode="EDIT")
    renamed = {}
    for bone in armature.data.edit_bones:
        raw = bone.name
        normalized = raw.removeprefix("mixamorig:").removeprefix("mixamorig_")
        target = MIXAMO_TO_GODOT.get(normalized)
        if target and target != raw:
            renamed[raw] = target
            bone.name = target
    bpy.ops.object.mode_set(mode="OBJECT")

    character_objects = [armature] + list(armature.children_recursive)
    meshes = [obj for obj in character_objects if obj.type == "MESH"]
    if not args.keep_materials:
        for mesh in meshes:
            mesh.data.materials.clear()

    bpy.ops.object.select_all(action="DESELECT")
    for obj in character_objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = armature
    output = os.path.abspath(args.output)
    os.makedirs(os.path.dirname(output), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=output,
        export_format="GLB",
        use_selection=True,
        export_skins=True,
        export_animations=True,
        export_materials="EXPORT",
        export_apply=False,
    )
    print("Exported %s (%d mesh objects, %d renamed bones)" % (output, len(meshes), len(renamed)))


if __name__ == "__main__":
    main()
