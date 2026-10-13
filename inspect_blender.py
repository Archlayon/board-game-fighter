import bpy
import sys

def inspect_glb(filepath, label):
    print(f"\n=== {label}: {filepath} ===")
    
    # Clear scene
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    
    # Import GLB
    bpy.ops.import_scene.gltf(filepath=filepath)
    
    # List all objects
    print("Objects:")
    for obj in bpy.data.objects:
        print(f"  {obj.name} (type: {obj.type})")
        if obj.type == 'ARMATURE':
            print(f"    Bones: {len(obj.data.bones)}")
            for bone in obj.data.bones:
                print(f"      {bone.name}")
    
    # List actions (animations)
    print("Actions (Animations):")
    for action in bpy.data.actions:
        print(f"  {action.name} (frames: {action.frame_range[1] - action.frame_range[0]:.0f})")
    
    # List armatures
    for obj in bpy.data.objects:
        if obj.type == 'ARMATURE':
            print(f"\nArmature: {obj.name}")
            print(f"  Bone count: {len(obj.data.bones)}")
            print(f"  Bone names:")
            for bone in obj.data.bones:
                print(f"    {bone.name}")

if __name__ == "__main__":
    # Get file paths from command line args after --
    argv = sys.argv
    if "--" in argv:
        idx = argv.index("--")
        files = argv[idx+1:]
    else:
        files = []
    
    if len(files) >= 2:
        inspect_glb(files[0], "UAL1")
        inspect_glb(files[1], "UAL2")
    else:
        print("Usage: blender --background --python inspect_blender.py -- <ual1.glb> <ual2.glb>")