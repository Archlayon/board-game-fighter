import bpy
import sys
import os

def convert_glb_to_blend(glb_path, blend_path):
    print(f"Converting {glb_path} -> {blend_path}")
    
    # Clear scene
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    
    # Import GLB
    bpy.ops.import_scene.gltf(filepath=glb_path)
    
    # Save as .blend
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    print(f"Saved to {blend_path}")

if __name__ == "__main__":
    argv = sys.argv
    if "--" in argv:
        idx = argv.index("--")
        args = argv[idx+1:]
    else:
        args = []
    
    if len(args) >= 2:
        convert_glb_to_blend(args[0], args[1])
    else:
        print("Usage: blender --background --python convert.py -- <input.glb> <output.blend>")