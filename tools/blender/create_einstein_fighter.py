"""Build the Einstein time-scientist fighter in Blender and export it for Godot.

Run from the Godot project root:
  blender -b --python tools/blender/create_einstein_fighter.py

The existing animated Quaternius fighter rig is retained. Costume pieces are
created as low-poly meshes and bone-parented so all existing combat clips work.
"""

from __future__ import annotations

import math
import os
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/characters/fighter_ual2.glb"
OUTPUT_BLEND = ROOT / "tools/blender/albert_einstein_chrono.blend"
OUTPUT_GLB = ROOT / "assets/characters/albert_einstein_chrono.glb"
PREVIEW = ROOT / "tools/blender/albert_einstein_chrono_preview.png"


def material(name, color, metallic=0.0, roughness=0.65, emission=None, emission_strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


MAT = {}


def make_materials():
    MAT.update({
        "coat": material("Einstein | midnight teal coat", (0.025, 0.085, 0.105), 0.22, 0.48),
        "coat_inner": material("Einstein | coat lining", (0.10, 0.20, 0.22), 0.12, 0.62),
        "shirt": material("Einstein | ivory shirt", (0.82, 0.78, 0.66), 0.0, 0.76),
        "gold": material("Einstein | aged brass", (0.62, 0.36, 0.10), 0.72, 0.33),
        "gold_light": material("Einstein | bright brass", (0.93, 0.68, 0.24), 0.7, 0.28),
        "leather": material("Einstein | dark leather", (0.075, 0.045, 0.035), 0.06, 0.8),
        "trousers": material("Einstein | charcoal trousers", (0.11, 0.13, 0.17), 0.0, 0.88),
        "hair": material("Einstein | silver hair", (0.70, 0.73, 0.73), 0.03, 0.8),
        "hair_shadow": material("Einstein | hair shadow", (0.37, 0.42, 0.45), 0.0, 0.88),
        "skin": material("Einstein | warm skin", (0.59, 0.34, 0.23), 0.0, 0.82),
        "mustache": material("Einstein | white mustache", (0.78, 0.79, 0.74), 0.0, 0.88),
        "lens": material("Einstein | clockglass cyan", (0.12, 0.73, 0.83), 0.22, 0.24, (0.05, 0.42, 0.8), 2.4),
        "rune": material("Einstein | glowing runes", (0.10, 0.70, 0.86), 0.22, 0.29, (0.04, 0.52, 0.95), 2.0),
        "eye": material("Einstein | eyes", (0.07, 0.045, 0.03), 0.0, 0.35),
        "brass_dark": material("Einstein | oxidized brass", (0.25, 0.16, 0.08), 0.76, 0.48),
        "fabric": material("Einstein | weathered coat fabric", (0.045, 0.055, 0.065), 0.0, 0.92),
    })


def tint_base_mannequin_as_skin(rig):
    # Recolor the skinned mannequin by bone region so outfit gaps do not expose
    # skin-colored torso and limbs. Keep only the face, neck, and hands as skin.
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        if "Mannequin" not in obj.name:
            continue
        obj.data.materials.clear()
        material_index = {}
        for key in ("skin", "coat", "trousers", "leather"):
            material_index[key] = len(obj.data.materials)
            obj.data.materials.append(MAT[key])
        groups = {group.index: group.name.lower() for group in obj.vertex_groups}
        for polygon in obj.data.polygons:
            scores = {}
            for vertex_index in polygon.vertices:
                for assignment in obj.data.vertices[vertex_index].groups:
                    name = groups.get(assignment.group, "")
                    scores[name] = scores.get(name, 0.0) + assignment.weight
            dominant = max(scores, key=scores.get) if scores else ""
            if dominant == "head" or dominant.startswith((
                "hand_", "index_", "middle_", "ring_", "pinky_", "thumb_"
            )):
                region = "skin"
            elif dominant.startswith(("calf_", "foot_", "ball_")):
                region = "leather"
            elif dominant.startswith("thigh_") or dominant == "pelvis":
                region = "trousers"
            else:
                region = "coat"
            polygon.material_index = material_index[region]


def attach_to_bone(obj, rig, bone_name):
    """Parent while preserving the object world transform at the rest pose."""
    world = obj.matrix_world.copy()
    obj.parent = rig
    obj.parent_type = "BONE"
    obj.parent_bone = bone_name
    bone_world = rig.matrix_world @ rig.pose.bones[bone_name].matrix
    obj.matrix_parent_inverse = bone_world.inverted()
    obj.matrix_world = world
    return obj


def finish_mesh(obj, name, mat, rig, bone, bevel=0.0):
    obj.name = name
    if mat:
        obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("Soft tailored edges", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
        for poly in obj.data.polygons:
            poly.use_smooth = True
    attach_to_bone(obj, rig, bone)
    return obj


def uv_sphere(name, loc, scale, mat, rig, bone, segments=16, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1.0, location=loc)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for face in obj.data.polygons:
        face.use_smooth = True
    return finish_mesh(obj, name, mat, rig, bone)


def cube(name, loc, scale, mat, rig, bone, bevel=0.035):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish_mesh(obj, name, mat, rig, bone, bevel)


def cylinder(name, loc, radius, depth, mat, rig, bone, rotation=(0, 0, 0), vertices=20):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rotation)
    obj = bpy.context.object
    for face in obj.data.polygons:
        face.use_smooth = True
    return finish_mesh(obj, name, mat, rig, bone, 0.008)


def torus(name, loc, major, minor, mat, rig, bone, rotation=(math.pi / 2, 0, 0), major_segments=24, minor_segments=8):
    bpy.ops.mesh.primitive_torus_add(major_segments=major_segments, minor_segments=minor_segments,
                                     major_radius=major, minor_radius=minor, location=loc, rotation=rotation)
    return finish_mesh(bpy.context.object, name, mat, rig, bone)


def curve_line(name, points, radius, mat, rig, bone, cyclic=False, resolution=2):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 1
    curve.bevel_depth = radius
    curve.bevel_resolution = resolution
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, co in zip(spline.points, points):
        point.co = (*co, 1.0)
    spline.use_cyclic_u = cyclic
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.object
    obj.select_set(False)
    return finish_mesh(obj, name, mat, rig, bone)


def prism(name, vertices, faces, mat, rig, bone, bevel=0.012):
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(mat)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish_mesh(obj, name, mat, rig, bone, bevel)


def tailored_torso(name, rings, mat, rig, bone, sides=24):
    """Build a softly contoured, low-poly tailored torso from elliptical rings."""
    vertices = []
    for z, width, depth in rings:
        for index in range(sides):
            angle = math.tau * index / sides
            vertices.append((math.cos(angle) * width, math.sin(angle) * depth, z))
    faces = []
    for ring in range(len(rings) - 1):
        for index in range(sides):
            current = ring * sides + index
            next_index = ring * sides + (index + 1) % sides
            faces.append((current, next_index, next_index + sides, current + sides))
    faces.append(tuple(range(sides - 1, -1, -1)))
    top_start = (len(rings) - 1) * sides
    faces.append(tuple(top_start + index for index in range(sides)))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(mat)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    obj.parent = rig
    pelvis = obj.vertex_groups.new(name="pelvis")
    spine_01 = obj.vertex_groups.new(name="spine_01")
    spine_02 = obj.vertex_groups.new(name="spine_02")
    for ring_index, (z, _width, _depth) in enumerate(rings):
        indices = list(range(ring_index * sides, (ring_index + 1) * sides))
        if z <= 1.0:
            pelvis.add(indices, 1.0, "REPLACE")
        elif z <= 1.12:
            blend = (z - 1.0) / 0.12
            pelvis.add(indices, 1.0 - blend, "REPLACE")
            spine_01.add(indices, blend, "REPLACE")
        elif z <= 1.28:
            blend = (z - 1.12) / 0.16
            spine_01.add(indices, 1.0 - blend, "REPLACE")
            spine_02.add(indices, blend, "REPLACE")
        else:
            spine_02.add(indices, 1.0, "REPLACE")
    modifier = obj.modifiers.new("Einstein tailored torso rig", "ARMATURE")
    modifier.object = rig
    return obj


def make_weighted_sleeve(rig, side, suffix):
    """Create a continuous cloth sleeve skinned to the upper and lower arm bones."""
    upper = rig.data.bones["upperarm_" + suffix]
    lower = rig.data.bones["lowerarm_" + suffix]
    upper_start = upper.head_local.copy()
    elbow = upper.tail_local.copy()
    wrist = lower.tail_local.copy()
    axis = (elbow - upper_start).normalized()
    basis_a = axis.cross(Vector((0.0, 0.0, 1.0))).normalized()
    basis_b = axis.cross(basis_a).normalized()
    if basis_a.length_squared < 0.5:
        basis_a = Vector((0.0, 1.0, 0.0))
        basis_b = axis.cross(basis_a).normalized()

    rings = [
        (upper_start.lerp(elbow, 0.02), 0.072, (1.0, 0.0)),
        (upper_start.lerp(elbow, 0.48), 0.084, (1.0, 0.0)),
        (elbow, 0.079, (0.55, 0.45)),
        (elbow.lerp(wrist, 0.50), 0.067, (0.12, 0.88)),
        (wrist, 0.057, (0.0, 1.0)),
    ]
    sides = 16
    vertices = []
    for center, radius, _weights in rings:
        for index in range(sides):
            angle = math.tau * index / sides
            point = center + radius * (basis_a * math.cos(angle) + basis_b * math.sin(angle))
            vertices.append(tuple(point))
    faces = []
    for ring in range(len(rings) - 1):
        for index in range(sides):
            a = ring * sides + index
            b = ring * sides + (index + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    faces.extend([tuple(range(sides - 1, -1, -1)),
                  tuple((len(rings) - 1) * sides + index for index in range(sides))])
    mesh = bpy.data.meshes.new("Einstein sleeve " + suffix + " mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(MAT["coat"])
    mesh.update()
    obj = bpy.data.objects.new("Einstein | articulated cloth sleeve " + suffix, mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = rig
    upper_group = obj.vertex_groups.new(name=upper.name)
    lower_group = obj.vertex_groups.new(name=lower.name)
    for ring_index, (_center, _radius, weights) in enumerate(rings):
        indices = list(range(ring_index * sides, (ring_index + 1) * sides))
        if weights[0] > 0.0:
            upper_group.add(indices, weights[0], "REPLACE")
        if weights[1] > 0.0:
            lower_group.add(indices, weights[1], "REPLACE")
    armature = obj.modifiers.new("Einstein armature", "ARMATURE")
    armature.object = rig
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    return obj


def make_weighted_gauntlet(rig, suffix):
    """Add a wrist cuff as skinned geometry, so it follows elbow animations."""
    bone = rig.data.bones["lowerarm_" + suffix]
    start, end = bone.head_local.copy(), bone.tail_local.copy()
    axis = (end - start).normalized()
    basis_a = axis.cross(Vector((0.0, 0.0, 1.0))).normalized()
    if basis_a.length_squared < 0.5:
        basis_a = axis.cross(Vector((0.0, 1.0, 0.0))).normalized()
    basis_b = axis.cross(basis_a).normalized()
    center = start.lerp(end, 0.84)
    sides = 20
    vertices = []
    for along, radius in ((-0.055, .068), (-0.045,.076), (.035,.076), (.045,.068)):
        ring_center = center + axis * along
        for index in range(sides):
            angle = math.tau * index / sides
            vertices.append(tuple(ring_center + radius * (basis_a*math.cos(angle) + basis_b*math.sin(angle))))
    faces = []
    for ring in range(3):
        for index in range(sides):
            a = ring*sides+index
            b = ring*sides+(index+1)%sides
            faces.append((a,b,b+sides,a+sides))
    mesh = bpy.data.meshes.new("Einstein gauntlet cuff " + suffix)
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(MAT["leather"])
    mesh.update()
    cuff = bpy.data.objects.new("Einstein | articulated gauntlet cuff " + suffix, mesh)
    bpy.context.collection.objects.link(cuff)
    cuff.parent = rig
    group = cuff.vertex_groups.new(name=bone.name)
    group.add(list(range(len(vertices))), 1.0, "REPLACE")
    modifier = cuff.modifiers.new("Einstein gauntlet armature", "ARMATURE")
    modifier.object = rig
    for polygon in mesh.polygons:
        polygon.use_smooth = True

    # Raised cyan glass plate on the front of the cuff, weighted to the same bone.
    front = Vector((0.0, -1.0, 0.0))
    front = (front - axis * front.dot(axis)).normalized()
    pad_center = center + front * .068
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=1.0, location=pad_center)
    pad = bpy.context.object
    pad.name = "Einstein | gauntlet chronoglass " + suffix
    pad.scale = (.038,.012,.045)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    pad.data.materials.append(MAT["lens"])
    pad.parent = rig
    pad_group = pad.vertex_groups.new(name=bone.name)
    pad_group.add(list(range(len(pad.data.vertices))), 1.0, "REPLACE")
    pad_modifier = pad.modifiers.new("Einstein glass armature", "ARMATURE")
    pad_modifier.object = rig


def build_clock(rig, center, bone="spine_02", scale=1.0, name="Pocket Chronometer"):
    x, y, z = center
    r = 0.125 * scale
    torus(name + " | bezel", center, r, 0.018 * scale, MAT["gold_light"], rig, bone)
    cylinder(name + " | dial", (x, y + 0.011 * scale, z), r * 0.91, 0.018 * scale,
             MAT["leather"], rig, bone, rotation=(math.pi / 2, 0, 0))
    torus(name + " | cyan inner ring", (x, y - 0.002 * scale, z), r * 0.70, 0.006 * scale,
          MAT["lens"], rig, bone)
    for i in range(12):
        angle = math.tau * i / 12.0
        px = x + math.sin(angle) * r * 0.76
        pz = z + math.cos(angle) * r * 0.76
        uv_sphere(name + " | hour %02d" % i, (px, y - 0.014 * scale, pz),
                  (0.008 * scale, 0.005 * scale, 0.008 * scale), MAT["gold_light"], rig, bone, 8, 4)
    curve_line(name + " | minute hand", [
        (x, y - 0.021 * scale, z),
        (x - 0.012 * scale, y - 0.021 * scale, z + 0.068 * scale),
    ], 0.004 * scale, MAT["gold_light"], rig, bone)
    curve_line(name + " | hour hand", [
        (x, y - 0.024 * scale, z),
        (x + 0.048 * scale, y - 0.024 * scale, z - 0.025 * scale),
    ], 0.006 * scale, MAT["lens"], rig, bone)
    uv_sphere(name + " | pivot", (x, y - 0.03 * scale, z), (0.012 * scale,) * 3,
              MAT["gold_light"], rig, bone, 10, 6)


def make_costume(rig):
    # Core outfit, matched to the base mesh's 1.65 m rest-pose proportions.
    tailored_torso("Einstein | fitted long coat", [
        (0.94, 0.19, 0.125), (1.00, 0.218, 0.145), (1.12, 0.215, 0.14),
        (1.28, 0.205, 0.125), (1.39, 0.205, 0.12), (1.52, 0.17, 0.105),
    ], MAT["coat"], rig, "spine_02")
    # Narrow shirt inset and overlapping tailored lapels give the torso a
    # recognisable human silhouette instead of a single featureless capsule.
    uv_sphere("Einstein | shirt inset", (0, -0.133, 1.39),
              (0.062, 0.014, 0.105), MAT["shirt"], rig, "spine_02", 20, 12)
    for side in (-1, 1):
        prism("Einstein | layered coat lapel", [
            (side * .15, -.124, 1.49), (side * .075, -.153, 1.40),
            (side * .105, -.155, 1.29), (side * .19, -.11, 1.39),
            (side * .15, -.105, 1.49), (side * .075, -.134, 1.40),
            (side * .105, -.136, 1.29), (side * .19, -.09, 1.39),
        ], [(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],
           MAT["leather"], rig, "spine_02", .008)
        # Small articulated shoulder pauldrons, stepped like stitched leather.
        x = side * .215
        uv_sphere("Einstein | shoulder pauldron", (x, -.09, 1.455), (.082,.042,.052), MAT["leather"], rig, "spine_02", 20, 12)
        for step in range(3):
            curve_line("Einstein | pauldron brass seam", [
                (side*(.16 + step*.025), -.126, 1.49-step*.025),
                (side*(.25 + step*.012), -.116, 1.49-step*.025)], .004, MAT["gold"], rig, "spine_02")
    # Chest-mounted atomic chronometer: bezel, glass, nucleus and orbit paths.
    core = (0, -.151, 1.385)
    cylinder("Einstein | chest core housing", (0, -.145, 1.385), .084, .035, MAT["brass_dark"], rig, "spine_02", rotation=(math.pi/2,0,0), vertices=32)
    torus("Einstein | chest core rim", (0, -.168, 1.385), .078, .012, MAT["gold_light"], rig, "spine_02")
    cylinder("Einstein | cyan core glass", (0, -.168, 1.385), .063, .012, MAT["leather"], rig, "spine_02", rotation=(math.pi/2,0,0), vertices=32)
    uv_sphere("Einstein | atomic nucleus", (0, -.18, 1.385), (.018,.008,.018), MAT["lens"], rig, "spine_02", 12, 8)
    for angle in (0, math.pi/3, -math.pi/3):
        orbit = torus("Einstein | atomic orbit", (0, -.184, 1.385), .041, .0035, MAT["rune"], rig, "spine_02", rotation=(math.pi/2, angle, 0), major_segments=32, minor_segments=6)
        orbit.scale.x = 1.0
    # Brass stitching/buttons down the coat front, visible around the chest core.
    for z in (1.26, 1.20, 1.14, 1.08):
        uv_sphere("Einstein | brass coat stud", (0, -.145, z), (.009,.006,.009), MAT["gold_light"], rig, "spine_02", 10, 6)
    # Belt and hanging gear.
    torus("Einstein | waist belt", (0, 0, 0.94), 0.205, 0.014, MAT["leather"], rig, "pelvis",
          rotation=(0, 0, 0), major_segments=24, minor_segments=8)
    cube("Einstein | belt clasp", (0, -0.207, 0.94), (0.07, 0.022, 0.055), MAT["gold"], rig, "pelvis", 0.012)
    torus("Einstein | clasp core", (0, -0.222, 0.94), 0.018, 0.004, MAT["lens"], rig, "pelvis")
    # Four overlapping cloth panels form a split, knee-length coat.
    for side in (-1, 1):
        x0, x1 = side*.035, side*.245
        for front_y, mat_key in ((-.135, "coat"), (.105, "fabric")):
            verts = [(x0,front_y,.99),(x1,front_y,.98),(side*.285,front_y+.055,.62),(side*.06,front_y+.035,.64),
                     (x0,front_y+.035,.99),(x1,front_y+.035,.98),(side*.285,front_y+.09,.62),(side*.06,front_y+.07,.64)]
            prism("Einstein | split coat skirt panel", verts,
                  [(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],
                  MAT[mat_key], rig, "pelvis", .012)
        curve_line("Einstein | skirt brass hem", [(side*.07,-.147,.65),(side*.15,-.147,.64),(side*.24,-.14,.63)],
                   .004, MAT["gold"], rig, "pelvis")
        # Subtle rune embroidery, kept on the coat surface.
        curve_line("Einstein | coat rune", [
            (side * 0.12, -0.151, .88), (side * 0.17, -0.153, .84),
            (side * 0.13, -0.151, .80), (side * 0.18, -0.15, .76),
        ], 0.004, MAT["rune"], rig, "pelvis")
    build_clock(rig, (0.17, -0.205, 1.00), "pelvis", 0.48, "Belt Pocket Watch")
    # Back-mounted chrono engine with round brass housing and cyan side cells.
    cube("Einstein | chrono engine frame", (0,.155,1.35), (.34,.19,.36), MAT["leather"], rig, "spine_02", .035)
    cylinder("Einstein | chrono engine dial", (0,.26,1.39), .115, .045, MAT["brass_dark"], rig, "spine_02", rotation=(math.pi/2,0,0), vertices=32)
    torus("Einstein | chrono engine brass bezel", (0,.287,1.39), .105, .015, MAT["gold_light"], rig, "spine_02")
    cylinder("Einstein | chrono engine lens", (0,.286,1.39), .078, .018, MAT["leather"], rig, "spine_02", rotation=(math.pi/2,0,0), vertices=32)
    torus("Einstein | chrono engine cyan ring", (0,.30,1.39), .052, .008, MAT["lens"], rig, "spine_02")
    for side in (-1,1):
        cylinder("Einstein | engine pressure cell", (side*.155,.17,1.39), .043,.28,MAT["gold"],rig,"spine_02",vertices=16)
        cylinder("Einstein | glowing pressure glass", (side*.155,.17,1.39), .029,.235,MAT["lens"],rig,"spine_02",vertices=16)
    cylinder("Einstein | engine lower coil", (0,.17,1.17), .055,.29,MAT["gold"],rig,"spine_02",rotation=(0,math.pi/2,0),vertices=20)
    # Utility pouches and holster on the belt.
    for side in (-1,1):
        cube("Einstein | belt utility pouch", (side*.235,-.015,.94), (.085,.095,.12), MAT["leather"],rig,"pelvis",.014)
        cube("Einstein | pouch brass clasp", (side*.235,-.068,.96), (.035,.012,.025), MAT["gold"],rig,"pelvis",.005)
    # Fully skinned sleeves bend with the elbows instead of floating as hard props.
    for side, suffix in ((-1, "r"), (1, "l")):
        make_weighted_sleeve(rig, side, suffix)
        hip = "thigh_" + suffix
        calf = "calf_" + suffix
        # Trouser panels and shin guards retain the same joint pivots as the rig.
        uv_sphere("Einstein | tailored trouser thigh", (side * 0.105, 0.015, 0.72),
                  (0.13, 0.145, 0.23), MAT["trousers"], rig, hip)
        uv_sphere("Einstein | leather gaiter", (side * 0.105, -0.012, 0.32),
                  (0.115, 0.13, 0.20), MAT["leather"], rig, calf)
        uv_sphere("Einstein | leather shin guard", (side * 0.105, -0.145, 0.34),
                  (0.09, 0.025, 0.16), MAT["leather"], rig, calf)
        # Knee caps and articulated greaves add the reference's layered armor.
        uv_sphere("Einstein | knee armor", (side*.105,-.125,.535),(.105,.045,.082),MAT["leather"],rig,hip)
        torus("Einstein | knee brass rim", (side*.105,-.16,.535),.073,.006,MAT["gold"],rig,hip)
        for band_z in (.23,.39):
            torus("Einstein | greave strap", (side*.105,-.01,band_z),.106,.009,MAT["gold"],rig,calf,rotation=(0,0,0))
        for z in (0.25, 0.34, 0.43):
            curve_line("Einstein | shin engraving", [(side * 0.05, -0.18, z),
                       (side * 0.16, -0.18, z + 0.025)], 0.006, MAT["lens"], rig, calf)
        uv_sphere("Einstein | adventurer boot", (side * 0.105, -0.045, 0.085),
                  (0.13, 0.21, 0.085), MAT["leather"], rig, "foot_" + suffix)
        torus("Einstein | boot cuff", (side * 0.105, -0.018, 0.15), 0.10, 0.012,
              MAT["gold"], rig, calf, rotation=(0, 0, 0))
    # Forearm bracers are bone-attached so they follow the existing clips.
    for suffix in ("r", "l"):
        make_weighted_gauntlet(rig, suffix)


def make_head(rig):
    # Silver swept-back hair in overlapping tapered locks, not separate ball shapes.
    uv_sphere("Einstein | silver hair cap", (0, 0.01, 1.685), (0.145, 0.125, 0.092), MAT["hair"], rig, "Head", 32, 20)
    locks = [
        (-0.15, 0.005, 1.72, 0.058), (-0.11, 0.015, 1.78, 0.053),
        (-0.045, 0.02, 1.81, 0.052), (0.035, 0.018, 1.81, 0.052),
        (0.11, 0.012, 1.78, 0.054), (0.16, 0.0, 1.72, 0.058),
        (-0.17, 0.035, 1.64, 0.045), (0.17, 0.035, 1.65, 0.045),
        (-0.08, 0.12, 1.76, 0.053), (0.07, 0.12, 1.75, 0.053),
    ]
    for i, (x, y, z, size) in enumerate(locks):
        x *= .78
        y = .01 + (y - .01) * .82
        z = 1.685 + (z - 1.685) * .82
        size *= .78
        lock = uv_sphere("Einstein | swept silver lock %02d" % i, (x, y, z),
                         (size * 1.25, size * 0.68, size * 0.68), MAT["hair"] if i % 4 else MAT["hair_shadow"],
                         rig, "Head", 12, 8)
        lock.rotation_euler[1] = (-1 if x < 0 else 1) * 0.42
    # Nose bridge and a softly swept split mustache.
    uv_sphere("Einstein | nose", (0, -0.151, 1.635), (0.027, 0.038, 0.041), MAT["skin"], rig, "Head", 16, 10)
    for side in (-1, 1):
        moustache = uv_sphere("Einstein | swept mustache", (side * 0.045, -0.164, 1.594),
                              (0.052, 0.022, 0.018), MAT["mustache"], rig, "Head", 20, 10)
        moustache.rotation_euler[1] = side * -0.2
        uv_sphere("Einstein | eyebrow", (side * 0.067, -0.151, 1.672), (0.043, 0.012, 0.009),
                  MAT["hair_shadow"], rig, "Head", 12, 6)
        uv_sphere("Einstein | eye", (side * 0.066, -0.161, 1.647), (0.012, 0.007, 0.009),
                  MAT["eye"], rig, "Head", 10, 6)
    # Distinct round spectacles with a bridge and short side arms.
    for side in (-1, 1):
        torus("Einstein | round spectacle", (side * 0.066, -0.165, 1.65), 0.044, 0.006,
              MAT["gold_light"], rig, "Head", major_segments=20, minor_segments=6)
    curve_line("Einstein | spectacles bridge", [(-0.022, -0.169, 1.65), (0.022, -0.169, 1.65)],
               0.004, MAT["gold_light"], rig, "Head")


def join_costume_meshes(rig):
    """Reduce draw calls while retaining one animated object per rig bone."""
    groups = {}
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH" and obj.parent == rig and obj.parent_type == "BONE":
            groups.setdefault(obj.parent_bone, []).append(obj)
    for bone_name, objects in groups.items():
        if len(objects) < 2:
            continue
        # Joining bone-parented objects directly makes Blender apply each
        # different parent inverse twice. First bake their current world
        # transforms, join in world space, then attach the merged mesh once.
        for obj in objects:
            world = obj.matrix_world.copy()
            obj.parent = None
            obj.parent_type = "OBJECT"
            obj.parent_bone = ""
            obj.matrix_world = world
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        merged = bpy.context.object
        merged.name = "Einstein Outfit | " + bone_name
        attach_to_bone(merged, rig, bone_name)


def keep_game_actions():
    # The source GLB includes dozens of unrelated farming/prop clips. Retain the
    # ten clips the fighter currently plays so Blender can export the character
    # animation library quickly and keep the game asset compact.
    required = {"idle", "walk", "jump", "jab", "cross", "hook", "uppercut",
                "special_move", "hit_react", "victory"}
    for action in list(bpy.data.actions):
        if action.name not in required:
            bpy.data.actions.remove(action, do_unlink=True)


def make_kick_action(rig, action_name, poses, frame_rate=30):
    """Author a compact, readable fighting-game kick on this rig's real bones."""
    old_action = bpy.data.actions.get(action_name)
    if old_action:
        bpy.data.actions.remove(old_action, do_unlink=True)
    action = bpy.data.actions.new(action_name)
    rig.animation_data_create()
    rig.animation_data.action = action
    for frame, pose in poses:
        for bone_name, rotation in pose.items():
            bone = rig.pose.bones.get(bone_name)
            if bone is None:
                raise RuntimeError(f"Kick animation bone is missing: {bone_name}")
            bone.rotation_mode = "XYZ"
            bone.rotation_euler = tuple(math.radians(value) for value in rotation)
            bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone_name)
    action.use_fake_user = True
    return action


def make_combat_kicks(rig):
    # The stock model has no kick clip. These restrained chamber, extension,
    # contact, and recovery poses use the exported fighter rig's actual joints.
    neutral = {
        "thigh_r": (0, 0, 0), "calf_r": (0, 0, 0), "foot_r": (0, 0, 0),
        "thigh_l": (-8, 0, 0), "calf_l": (12, 0, 0), "foot_l": (0, 0, 0),
        "spine_02": (0, 0, 0), "upperarm_l": (-10, 0, -48), "lowerarm_l": (0, 0, 0),
        "upperarm_r": (-10, 0, 48), "lowerarm_r": (0, 0, 0),
    }
    make_kick_action(rig, "kick_front", [
        (0, neutral),
        (4, {**neutral, "thigh_r": (-28, 0, 0), "calf_r": (-58, 0, 0), "spine_02": (4, 0, 0)}),
        (9, {**neutral, "thigh_r": (-66, 0, 0), "calf_r": (-5, 0, 0), "spine_02": (10, 0, 0)}),
        (12, {**neutral, "thigh_r": (-78, 0, 0), "calf_r": (5, 0, 0), "spine_02": (12, 0, 0)}),
        (16, {**neutral, "thigh_r": (-32, 0, 0), "calf_r": (-42, 0, 0), "spine_02": (3, 0, 0)}),
        (22, neutral),
    ])
    make_kick_action(rig, "kick_round", [
        (0, neutral),
        (4, {**neutral, "thigh_r": (-24, 0, 22), "calf_r": (-48, 0, 0), "spine_02": (0, 0, -8)}),
        (9, {**neutral, "thigh_r": (-42, 0, 58), "calf_r": (-12, 0, 0), "spine_02": (0, 0, -18)}),
        (12, {**neutral, "thigh_r": (-48, 0, 72), "calf_r": (-4, 0, 0), "spine_02": (0, 0, -22)}),
        (16, {**neutral, "thigh_r": (-24, 0, 35), "calf_r": (-40, 0, 0), "spine_02": (0, 0, -8)}),
        (22, neutral),
    ])
    rig.animation_data.action = bpy.data.actions.get("idle")


def configure_preview(rig):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.studio_light = "paint.sl"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.render.resolution_x = 960
    scene.render.resolution_y = 960
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("Einstein preview world")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.025, 0.035, 0.055, 1.0)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.35
    # Blender may fall back to Standard when its bundled OCIO config is newer
    # than the available OpenColorIO library (for example in constrained CI).
    try:
        scene.view_settings.view_transform = "AgX"
    except TypeError:
        scene.view_settings.view_transform = "Standard"

    # Face the camera toward the fighter's -Y front.
    bpy.ops.object.camera_add(location=(2.5, -5.0, 2.25))
    camera = bpy.context.object
    camera.name = "Einstein preview camera"
    direction = Vector((0.0, -0.02, 0.94)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 2.65
    scene.camera = camera
    for name, loc, energy, size, color in [
        ("Key softbox", (2.0, -3.0, 4.0), 420, 4.0, (0.72, 0.86, 1.0)),
        ("Warm fill", (-3.0, -1.2, 2.4), 260, 3.2, (1.0, 0.62, 0.32)),
        ("Clock rim", (0.0, 2.0, 3.2), 500, 2.5, (0.12, 0.52, 1.0)),
    ]:
        bpy.ops.object.light_add(type="AREA", location=loc)
        light = bpy.context.object
        light.name = name
        light.data.energy = energy
        light.data.shape = "DISK"
        light.data.size = size
        light.data.color = color
        light.rotation_euler = (Vector((0, 0, 1.0)) - light.location).to_track_quat("-Z", "Y").to_euler()
    # Neutral ground and a subtle teal backdrop for the preview only.
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -0.025))
    floor = bpy.context.object
    floor.name = "Preview floor (not exported)"
    floor.data.materials.append(material("Preview | charcoal", (0.018, 0.028, 0.042), 0.15, 0.9))
    scene.render.filepath = str(PREVIEW)
    scene.camera.data.lens = 50
    return camera, floor


def main():
    if not SOURCE.exists():
        raise FileNotFoundError(f"Animated base fighter not found: {SOURCE}")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    make_materials()
    rig = next((obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"), None)
    if rig is None:
        raise RuntimeError("The imported fighter GLB has no armature")
    tint_base_mannequin_as_skin(rig)
    # Keep the source rig object name "Armature". The exported combat clips
    # and Godot's generated fighter actions both address Armature/Skeleton3D.
    keep_game_actions()
    make_combat_kicks(rig)
    # The source GLB contains one armature and a skinned base mesh. Keep its
    # animation actions, then add the costume and face as bone-attached meshes.
    make_costume(rig)
    make_head(rig)
    # Keep attached objects separate. Joining bone-parented meshes bakes the
    # bone transform into the geometry in Blender 5.x, visibly offsetting gear
    # from hands and shoulders in both the preview and exported GLB.
    bpy.context.scene.frame_set(0)
    camera, floor = configure_preview(rig)

    OUTPUT_BLEND.parent.mkdir(parents=True, exist_ok=True)
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_BLEND))

    # Exclude studio lighting and ground from the game model; the scene keeps
    # them only to make the saved .blend immediately useful for review.
    camera.hide_viewport = True
    camera.hide_render = False
    floor.hide_viewport = True
    floor.hide_render = True
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj != camera and obj.type not in {"LIGHT", "CAMERA"} and obj.name != floor.name:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=str(OUTPUT_GLB),
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_skins=True,
        export_apply=True,
        export_extras=True,
        export_nla_strips=False,
        export_force_sampling=True,
        export_yup=True,
    )

    # Keep the editable Blender project in a clean rest pose for inspection.
    # The GLB has already received all animation clips at this point.
    for action in bpy.data.actions:
        action.use_fake_user = True
    rig.animation_data.action = None
    for pose_bone in rig.pose.bones:
        pose_bone.rotation_mode = "XYZ"
        pose_bone.location = (0.0, 0.0, 0.0)
        pose_bone.rotation_euler = (0.0, 0.0, 0.0)
        pose_bone.scale = (1.0, 1.0, 1.0)
    bpy.context.scene.frame_set(1)
    floor.hide_render = False
    for obj in bpy.context.scene.objects:
        if obj.type == "LIGHT":
            obj.hide_viewport = True
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_BLEND))
    bpy.ops.render.render(write_still=True)

    print("Created Blender project:", OUTPUT_BLEND)
    print("Created Godot character:", OUTPUT_GLB)
    print("Render the preview with: blender -b", OUTPUT_BLEND, "-o", PREVIEW.with_suffix(""), "-f 1")
    print("Rig bones:", len(rig.data.bones), "actions:", len(bpy.data.actions))


if __name__ == "__main__":
    main()
