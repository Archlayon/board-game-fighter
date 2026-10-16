# build_fight_animations.py
# Authors fighting-game animation clips for the Stickman_Rig in Blender.
# Run via tools/blender/build.py (headless) or inside Blender with stickman.glb imported.
#
# Pose conventions (armature axes, character faces -Y, +X is the character's LEFT):
#   each bone entry is (fwd, out, yaw) in degrees, RELATIVE TO ITS PARENT.
#   fwd  : swing forward (limbs) / lean forward (spine). Negative = back.
#   out  : swing away from the body (limbs) / tilt toward the character's left (spine, neck).
#   yaw  : twist about the vertical axis, positive = turn toward the character's left.
#   "loc": hips offset (side-to-left, forward, up) in metres.
import bpy, math
from mathutils import Matrix, Vector

RAD = math.radians
arm = bpy.data.objects["Stickman_Rig"]
bones = {b.name: b for b in arm.data.bones}
R_REST = {n: b.matrix_local.to_3x3() for n, b in bones.items()}
ALL = list(bones.keys())


def side_of(name):
    if name.startswith("Left"):
        return 1
    if name.startswith("Right"):
        return -1
    return -1   # centre bones: positive 'out' tilts toward the character's left


def rel_rot(name, fwd, out, yaw):
    rx = Matrix.Rotation(-RAD(fwd), 3, 'X')
    ry = Matrix.Rotation(-RAD(out) * side_of(name), 3, 'Y')
    rz = Matrix.Rotation(RAD(yaw), 3, 'Z')
    return rz @ ry @ rx


# ---------------------------------------------------------------- base guard stance
S = {
    "Hips": (0, 0, 0), "loc": (0, 0, -0.06),
    "Spine": (6, 0, 0), "Chest": (5, 0, 0), "Neck": (-6, 0, 0), "Head": (-4, 0, 0),
    "LeftUpperArm": (45, 10, 0), "LeftLowerArm": (100, 0, 0), "LeftHand": (0, 0, 0),
    "RightUpperArm": (35, 12, 0), "RightLowerArm": (105, 0, 0), "RightHand": (0, 0, 0),
    "LeftUpperLeg": (22, 8, 0), "LeftLowerLeg": (-32, 0, 0), "LeftFoot": (10, 0, 0),
    "RightUpperLeg": (-10, 10, 0), "RightLowerLeg": (-24, 0, 0), "RightFoot": (28, 0, 0),
}


def P(base=None, **o):
    d = dict(base or S)
    d.update(o)
    return d


GUARD = P(Chest=(10, 0, 0), Spine=(10, 0, 0), Neck=(-10, 0, 0), Head=(-8, 0, 0), loc=(0, -0.03, -0.1),
          LeftUpperArm=(70, -5, 0), LeftLowerArm=(120, 0, 0), RightUpperArm=(65, -8, 0), RightLowerArm=(125, 0, 0))


def K(f, pose, ease=None, interp=None, **extra):
    k = dict(pose)
    k["f"] = f
    k["ease"] = ease
    k["interp"] = interp
    k.update(extra)
    return k


SNAP = ("EXPO", "EASE_OUT")      # fast launch, soft arrival: for strikes
SOFT = ("SINE", "EASE_IN_OUT")


# ---------------------------------------------------------------- action builder
def fcurves_of(act):
    try:
        fc = act.fcurves
        if fc is not None:
            return list(fc)
    except Exception:
        pass
    res = []
    for layer in act.layers:
        for strip in layer.strips:
            for slot in act.slots:
                cb = strip.channelbag(slot)
                if cb:
                    res += list(cb.fcurves)
    return res


def make_action(name, keys):
    old = bpy.data.actions.get(name)
    if old:
        old.use_fake_user = False
        old.name = name + "_old"
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    ad = arm.animation_data or arm.animation_data_create()
    ad.action = act
    prev = {}
    marks = {}
    for k in keys:
        f = k["f"]
        hips_yaw = k["Hips"][2]
        for n in ALL:
            fwd, out, yaw = k[n]
            if n.endswith("UpperLeg"):
                c = k.get("cancelL" if n.startswith("Left") else "cancelR", 1.0)
                yaw = yaw - c * hips_yaw
            q = (R_REST[n].transposed() @ rel_rot(n, fwd, out, yaw) @ R_REST[n]).to_quaternion()
            if n in prev and q.dot(prev[n]) < 0:
                q.negate()
            prev[n] = q.copy()
            pb = arm.pose.bones[n]
            pb.rotation_mode = 'QUATERNION'
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=f, group=n)
        sx, fw, up = k["loc"]
        pbh = arm.pose.bones["Hips"]
        pbh.location = R_REST["Hips"].transposed() @ Vector((sx, -fw, up))
        pbh.keyframe_insert("location", frame=f, group="Hips")
        marks[f] = (k.get("interp"), k.get("ease"))
    for fc in fcurves_of(act):
        for kp in fc.keyframe_points:
            interp, ease = marks.get(round(kp.co[0]), (None, None))
            if interp:
                kp.interpolation = interp
            elif ease:
                kp.interpolation = ease[0]
                kp.easing = ease[1]
            else:
                kp.interpolation = 'BEZIER'
    ad.action = None
    return act


# ================================================================= CLIPS
A = {}

# --- locomotion / stance
A["idle"] = [
    K(0, S),
    K(12, P(loc=(0.008, 0, -0.082), Chest=(8, 0, 0), LeftUpperArm=(48, 10, 0), RightUpperArm=(38, 12, 0), Head=(-3, 0, 0))),
    K(24, P(loc=(0.014, 0, -0.06))),
    K(36, P(loc=(0.004, 0, -0.082), Chest=(8, 0, 0), LeftUpperArm=(48, 10, 0), RightUpperArm=(38, 12, 0), Head=(-3, 0, 0))),
    K(48, S),
]
A["block"] = [
    K(0, GUARD),
    K(12, P(GUARD, loc=(0, -0.03, -0.12), Chest=(12, 0, 0))),
    K(24, GUARD),
]

CH = P(
    loc=(0, 0, -0.14), Chest=(-4, 0, 0), Neck=(8, 0, 0), Head=(6, 0, 0),
    LeftUpperArm=(-8, 35, 0), LeftLowerArm=(85, 0, 0), RightUpperArm=(-8, 38, 0), RightLowerArm=(85, 0, 0),
    LeftUpperLeg=(14, 25, 0), LeftLowerLeg=(-26, 0, 0), LeftFoot=(12, 0, 0),
    RightUpperLeg=(-12, 25, 0), RightLowerLeg=(-24, 0, 0), RightFoot=(14, 0, 0))
CH_PULSE = P(CH, Chest=(-9, 0, 0), loc=(0, 0, -0.12), LeftUpperArm=(-4, 38, 0), RightUpperArm=(-4, 41, 0), Hips=(0, 0, 1.5))
A["charge"] = [
    K(0, CH), K(8, CH_PULSE),
    K(16, P(CH, loc=(0, 0, -0.16), Chest=(-1, 0, 0), Hips=(0, 0, -1.5))),
    K(24, CH_PULSE), K(32, CH)]

# --- punches
JAB_OUT = P(LeftUpperArm=(88, 3, 0), LeftLowerArm=(6, 0, 0), LeftHand=(-10, 0, 0), Chest=(7, 0, -14), Spine=(6, 0, -6),
            Hips=(0, 0, -8), loc=(0, 0.1, -0.07), LeftUpperLeg=(28, 8, 0))
A["jab"] = [
    K(0, S),
    K(2, P(LeftUpperArm=(35, 8, 0), LeftLowerArm=(115, 0, 0), Chest=(5, 0, 8), loc=(0, -0.02, -0.08)), ease=SNAP),
    K(4, JAB_OUT),
    K(6, JAB_OUT, ease=SOFT),
    K(9, P(LeftUpperArm=(62, 6, 0), LeftLowerArm=(60, 0, 0), Chest=(6, 0, -6), loc=(0, 0.04, -0.07))),
    K(14, S),
]
CR_OUT = P(Hips=(0, 0, 28), Chest=(6, 0, 22), Spine=(6, 0, 8), RightUpperArm=(92, -6, 0), RightLowerArm=(4, 0, 0), RightHand=(-8, 0, 0),
           LeftUpperArm=(50, 15, 0), LeftLowerArm=(115, 0, 0), RightUpperLeg=(-6, 10, 0), loc=(0, 0.14, -0.07))
A["cross"] = [
    K(0, S),
    K(3, P(Hips=(0, 0, -12), Chest=(5, 0, -10), RightUpperArm=(25, 10, 0), RightLowerArm=(120, 0, 0), loc=(0, -0.03, -0.1)), ease=SNAP, cancelR=0.4),
    K(6, CR_OUT, cancelR=0.4),
    K(9, CR_OUT, ease=SOFT, cancelR=0.4),
    K(13, P(Hips=(0, 0, 12), Chest=(6, 0, 10), RightUpperArm=(60, 8, 0), RightLowerArm=(70, 0, 0), loc=(0, 0.06, -0.07)), cancelR=0.6),
    K(18, S),
]
HK_OUT = P(Hips=(0, 0, 22), Chest=(6, 0, 28), LeftUpperArm=(75, 38, 0), LeftLowerArm=(100, 0, 0), loc=(-0.02, 0.1, -0.08))
A["hook"] = [
    K(0, S),
    K(4, P(Hips=(0, 0, -20), Chest=(5, 0, -22), LeftUpperArm=(30, 75, 0), LeftLowerArm=(100, 0, 0), loc=(0.03, -0.02, -0.12)), ease=SNAP, cancelR=0.5),
    K(7, HK_OUT, cancelR=0.5),
    K(10, HK_OUT, ease=SOFT, cancelR=0.5),
    K(20, S),
]
UP_OUT = P(loc=(0, 0.04, -0.02), Chest=(-8, 0, 20), Spine=(-4, 0, 6), RightUpperArm=(80, 5, 0), RightLowerArm=(110, 0, 0),
           LeftUpperLeg=(18, 8, 0), LeftLowerLeg=(-20, 0, 0), RightUpperLeg=(-12, 10, 0), RightLowerLeg=(-10, 0, 0), RightFoot=(20, 0, 0))
A["uppercut"] = [
    K(0, S),
    K(5, P(loc=(0, 0, -0.2), Chest=(14, 0, -12), RightUpperArm=(-5, 15, 0), RightLowerArm=(80, 0, 0),
           LeftUpperLeg=(35, 8, 0), LeftLowerLeg=(-55, 0, 0), LeftFoot=(20, 0, 0),
           RightUpperLeg=(-15, 10, 0), RightLowerLeg=(-45, 0, 0), RightFoot=(55, 0, 0)), ease=SNAP),
    K(9, UP_OUT, cancelR=0.5),
    K(12, UP_OUT, ease=SOFT, cancelR=0.5),
    K(22, S),
]
A["punch_basic"] = A["jab"]

# --- kicks
CHAMBER = P(Chest=(-8, 0, 0), Spine=(-4, 0, 0), loc=(0, -0.02, -0.04),
            LeftUpperLeg=(14, 8, 0), LeftLowerLeg=(-20, 0, 0), LeftFoot=(6, 0, 0),
            RightUpperLeg=(80, 6, 0), RightLowerLeg=(-105, 0, 0), RightFoot=(60, 0, 0),
            LeftUpperArm=(55, 18, 0), RightUpperArm=(30, 20, 0))
KICKOUT = P(CHAMBER, Chest=(-14, 0, 0), Spine=(-6, 0, 0), loc=(0, 0.05, -0.03),
            RightUpperLeg=(88, 6, 0), RightLowerLeg=(-5, 0, 0), RightFoot=(45, 0, 0))
A["kick_front"] = [
    K(0, S), K(4, CHAMBER, ease=SNAP), K(7, KICKOUT), K(11, KICKOUT, ease=SOFT), K(15, CHAMBER), K(22, S)]

RC_CH = P(Hips=(0, 0, 10), Chest=(-4, 0, 6), loc=(0, -0.02, -0.05),
          RightUpperLeg=(50, 70, 0), RightLowerLeg=(-120, 0, 0), RightFoot=(40, 0, 0),
          LeftUpperLeg=(10, 6, 0), LeftLowerLeg=(-16, 0, 0), LeftFoot=(5, 0, 0),
          LeftUpperArm=(30, 50, 0), LeftLowerArm=(60, 0, 0), RightUpperArm=(60, 45, 0), RightLowerArm=(40, 0, 0))
RC_HIT = P(Hips=(0, 0, 55), Chest=(-2, 0, 35), Spine=(0, 15, 0), loc=(0, 0.02, -0.02),
           RightUpperLeg=(85, 25, 0), RightLowerLeg=(-5, 0, 0), RightFoot=(30, 0, 0),
           LeftUpperLeg=(8, 6, 0), LeftLowerLeg=(-12, 0, 0), LeftFoot=(4, 0, 0),
           LeftUpperArm=(30, 50, 0), LeftLowerArm=(60, 0, 0), RightUpperArm=(60, 45, 0), RightLowerArm=(40, 0, 0))
A["kick_round"] = [
    K(0, S), K(5, RC_CH, ease=SNAP, cancelL=0.5, cancelR=0.2), K(9, RC_HIT, cancelL=0.4, cancelR=0.0),
    K(13, RC_HIT, ease=SOFT, cancelL=0.4, cancelR=0.0), K(19, RC_CH, cancelL=0.5, cancelR=0.2), K(26, S)]

SW_LOW = P(loc=(0, 0, -0.45), Chest=(28, 0, 0), Spine=(14, 0, 0), Neck=(-20, 0, 0),
           LeftUpperLeg=(70, 20, 0), LeftLowerLeg=(-120, 0, 0), LeftFoot=(30, 0, 0),
           LeftUpperArm=(20, 40, 0), LeftLowerArm=(60, 0, 0), RightUpperArm=(40, 30, 0), RightLowerArm=(40, 0, 0))
SW_A = P(SW_LOW, Hips=(0, 0, -35), RightUpperLeg=(-10, 85, 0), RightLowerLeg=(-5, 0, 0), RightFoot=(5, 0, 0))
SW_B = P(SW_LOW, Hips=(0, 0, 45), RightUpperLeg=(80, 15, 0), RightLowerLeg=(-5, 0, 0), RightFoot=(5, 0, 0))
A["sweep"] = [
    K(0, S),
    K(5, SW_A, ease=SNAP, cancelL=1.0, cancelR=0.0),
    K(9, SW_B, cancelL=1.0, cancelR=0.0),
    K(13, SW_B, ease=SOFT, cancelL=1.0, cancelR=0.0),
    K(19, P(S, loc=(0, 0, -0.25), Chest=(18, 0, 0), LeftUpperLeg=(50, 10, 0), LeftLowerLeg=(-80, 0, 0), LeftFoot=(20, 0, 0))),
    K(26, S)]

FK_TUCK = dict(LeftUpperLeg=(55, 8, 0), LeftLowerLeg=(-95, 0, 0), LeftFoot=(20, 0, 0))
FK_KICK = P(loc=(0, 0.25, 0.4), Chest=(-25, 0, 0), Spine=(-10, 0, 0), RightUpperLeg=(80, 5, 0), RightLowerLeg=(0, 0, 0), RightFoot=(40, 0, 0),
            LeftUpperArm=(30, 50, 0), LeftLowerArm=(50, 0, 0), RightUpperArm=(40, 55, 0), RightLowerArm=(40, 0, 0), **FK_TUCK)
A["kick_flying"] = [
    K(0, S),
    K(4, P(loc=(0, 0, -0.2), Chest=(20, 0, 0), LeftUpperLeg=(40, 8, 0), LeftLowerLeg=(-60, 0, 0), RightUpperLeg=(-15, 10, 0), RightLowerLeg=(-50, 0, 0),
           LeftUpperArm=(-30, 20, 0), LeftLowerArm=(40, 0, 0), RightUpperArm=(-30, 20, 0), RightLowerArm=(40, 0, 0)), ease=SNAP),
    K(8, P(loc=(0, 0.05, 0.35), Chest=(-20, 0, 0), Spine=(-8, 0, 0), LeftUpperLeg=(60, 8, 0), LeftLowerLeg=(-100, 0, 0),
           RightUpperLeg=(30, 10, 0), RightLowerLeg=(-40, 0, 0), LeftUpperArm=(120, 40, 0), LeftLowerArm=(20, 0, 0),
           RightUpperArm=(110, 40, 0), RightLowerArm=(20, 0, 0))),
    K(11, FK_KICK),
    K(15, P(FK_KICK, loc=(0, 0.3, 0.36)), ease=SOFT),
    K(19, P(loc=(0, 0.1, -0.22), Chest=(18, 0, 0), LeftUpperLeg=(40, 8, 0), LeftLowerLeg=(-60, 0, 0), RightUpperLeg=(-15, 10, 0), RightLowerLeg=(-50, 0, 0))),
    K(27, S)]

# --- specials
HK_CHARGE = P(loc=(0, 0, -0.12), Hips=(0, 0, 0), Chest=(6, 0, -25), Spine=(6, 0, -8),
              LeftUpperArm=(30, -20, 0), LeftLowerArm=(80, 0, 0), RightUpperArm=(20, 15, 0), RightLowerArm=(85, 0, 0),
              LeftUpperLeg=(24, 15, 0), LeftLowerLeg=(-34, 0, 0), RightUpperLeg=(-15, 18, 0), RightLowerLeg=(-28, 0, 0))
HK_FIRE = P(loc=(0, 0.16, -0.1), Hips=(0, 0, 12), Chest=(8, 0, 15), LeftUpperArm=(92, -5, 0), LeftLowerArm=(5, 0, 0), LeftHand=(-10, 0, 0),
            RightUpperArm=(92, -5, 0), RightLowerArm=(5, 0, 0), RightHand=(-10, 0, 0),
            LeftUpperLeg=(35, 8, 0), LeftLowerLeg=(-50, 0, 0), LeftFoot=(15, 0, 0), RightUpperLeg=(-28, 10, 0), RightLowerLeg=(-12, 0, 0), RightFoot=(35, 0, 0))
A["hadoken"] = [K(0, S), K(6, HK_CHARGE, ease=SNAP), K(10, HK_FIRE), K(22, HK_FIRE, ease=SOFT), K(32, S)]

SR_LOW = P(loc=(0, 0, -0.28), Chest=(20, 0, -10), RightUpperArm=(-5, 20, 0), RightLowerArm=(90, 0, 0),
           LeftUpperLeg=(35, 10, 0), LeftLowerLeg=(-60, 0, 0), LeftFoot=(25, 0, 0), RightUpperLeg=(-18, 12, 0), RightLowerLeg=(-48, 0, 0), RightFoot=(55, 0, 0))
SR_UP = dict(RightUpperArm=(172, 8, 0), RightLowerArm=(5, 0, 0), Chest=(-10, 0, 15), Spine=(-5, 0, 0), LeftUpperArm=(45, 15, 0), LeftLowerArm=(100, 0, 0),
             RightUpperLeg=(70, 8, 0), RightLowerLeg=(-95, 0, 0), RightFoot=(30, 0, 0), LeftUpperLeg=(30, 8, 0), LeftLowerLeg=(-40, 0, 0), LeftFoot=(10, 0, 0))
A["shoryuken"] = [
    K(0, S), K(4, SR_LOW, ease=SNAP),
    K(8, P(loc=(0, 0.12, 0.18), **SR_UP)),
    K(12, P(loc=(0, 0.14, 0.32), **dict(SR_UP, Chest=(-14, 0, 15)))),
    K(16, P(loc=(0, 0.1, 0.15), **dict(SR_UP, RightUpperArm=(150, 8, 0), RightUpperLeg=(20, 8, 0), RightLowerLeg=(-30, 0, 0), LeftUpperLeg=(18, 8, 0)))),
    K(22, P(loc=(0, 0, -0.2), Chest=(18, 0, 0), LeftUpperLeg=(38, 8, 0), LeftLowerLeg=(-62, 0, 0), RightUpperLeg=(-15, 10, 0), RightLowerLeg=(-45, 0, 0))),
    K(30, S)]

TAT = dict(LeftUpperArm=(80, -20, 0), LeftLowerArm=(100, 0, 0), RightUpperArm=(80, -20, 0), RightLowerArm=(100, 0, 0),
           RightUpperLeg=(15, 80, 0), RightLowerLeg=(-5, 0, 0), RightFoot=(5, 0, 0),
           LeftUpperLeg=(70, 10, 0), LeftLowerLeg=(-100, 0, 0), LeftFoot=(15, 0, 0), Chest=(0, 0, 0), Spine=(0, 10, 0), Neck=(0, 0, 0), Head=(0, 0, 0))
tat_keys = [K(0, S, cancelL=0, cancelR=0),
            K(2, P(loc=(0, 0, 0.05), Hips=(0, 0, 0), **TAT), ease=SNAP, cancelL=0, cancelR=0)]
for i in range(1, 13):
    tat_keys.append(K(2 + i * 2, P(loc=(0, 0, 0.15), Hips=(0, 0, 60 * i), **TAT), interp="LINEAR", cancelL=0, cancelR=0))
tat_keys += [K(32, P(S, loc=(0, 0, -0.1), Hips=(0, 0, 720), Chest=(10, 0, 0), LeftUpperLeg=(30, 8, 0), LeftLowerLeg=(-40, 0, 0)), cancelL=0, cancelR=0),
             K(40, P(S, Hips=(0, 0, 720)), cancelL=0, cancelR=0)]
A["tatsumaki"] = tat_keys

GRAB_CL = dict(loc=(0, 0.15, -0.14), Chest=(14, 0, 0), LeftUpperArm=(80, -15, 0), LeftLowerArm=(15, 0, 0), RightUpperArm=(80, -15, 0), RightLowerArm=(15, 0, 0),
               LeftUpperLeg=(40, 10, 0), LeftLowerLeg=(-60, 0, 0), LeftFoot=(20, 0, 0), RightUpperLeg=(-20, 10, 0), RightLowerLeg=(-30, 0, 0), RightFoot=(45, 0, 0))
A["grab"] = [
    K(0, S),
    K(5, P(loc=(0, 0.18, -0.12), Chest=(14, 0, 0), LeftUpperArm=(85, 15, 0), LeftLowerArm=(10, 0, 0), LeftHand=(20, 0, 0),
           RightUpperArm=(85, 15, 0), RightLowerArm=(10, 0, 0), RightHand=(20, 0, 0), LeftUpperLeg=(40, 10, 0), LeftLowerLeg=(-60, 0, 0),
           LeftFoot=(20, 0, 0), RightUpperLeg=(-20, 10, 0), RightLowerLeg=(-30, 0, 0), RightFoot=(45, 0, 0)), ease=SNAP),
    K(9, P(**dict(GRAB_CL, LeftLowerArm=(8, 0, 0), RightLowerArm=(8, 0, 0)))),
    K(14, P(**GRAB_CL)), K(20, P(**GRAB_CL))]
THROW_END = P(**dict(GRAB_CL, Chest=(24, 0, 28), loc=(0, 0.2, -0.2), LeftUpperArm=(45, 5, 0), RightUpperArm=(45, 5, 0), LeftLowerArm=(10, 0, 0), RightLowerArm=(10, 0, 0)))
A["throw"] = [
    K(0, P(**GRAB_CL)),
    K(5, P(**dict(GRAB_CL, Chest=(-22, 0, 0), loc=(0, 0.05, -0.04), LeftUpperArm=(140, -10, 0), RightUpperArm=(140, -10, 0)))),
    K(10, P(**dict(GRAB_CL, Chest=(-12, 0, -25), loc=(0, 0.0, -0.04), LeftUpperArm=(150, -15, 0), RightUpperArm=(150, -15, 0), LeftLowerArm=(30, 0, 0), RightLowerArm=(30, 0, 0))), ease=SNAP),
    K(15, THROW_END),
    K(19, THROW_END, ease=SOFT),
    K(27, S)]

# --- defence and reactions
A["dodge"] = [
    K(0, S),
    K(3, P(loc=(0, -0.45, -0.12), Chest=(-14, 0, 0), LeftUpperLeg=(35, 8, 0), LeftLowerLeg=(-50, 0, 0), RightUpperLeg=(10, 10, 0), RightLowerLeg=(-40, 0, 0),
           LeftUpperArm=(30, 30, 0), RightUpperArm=(30, 30, 0)), ease=SNAP),
    K(7, P(loc=(0, -0.5, -0.05), Chest=(-8, 0, 0), LeftUpperLeg=(20, 8, 0), LeftLowerLeg=(-25, 0, 0))),
    K(12, P(loc=(0, -0.5, -0.12), Chest=(10, 0, 0))), K(18, S)]
A["hit_light"] = [
    K(0, S),
    K(2, P(Chest=(-16, 0, -6), Spine=(-6, 0, 0), Neck=(-14, 0, 0), Head=(-12, 0, 10), loc=(0, -0.05, -0.04), LeftUpperArm=(30, 22, 0), RightUpperArm=(22, 25, 0)), ease=SNAP),
    K(6, P(Chest=(-6, 0, -2), Head=(-6, 0, 4), loc=(0, -0.02, -0.05))), K(10, S)]
A["hit"] = A["hit_light"]
A["hit_heavy"] = [
    K(0, S),
    K(3, P(Hips=(0, 0, -12), Chest=(-32, 0, -14), Spine=(-14, 0, 0), Neck=(-25, 0, 0), Head=(-20, 0, 14), loc=(0, -0.2, -0.1),
           LeftUpperArm=(10, 60, 0), LeftLowerArm=(30, 0, 0), RightUpperArm=(-5, 65, 0), RightLowerArm=(25, 0, 0),
           LeftUpperLeg=(35, 15, 0), LeftLowerLeg=(-50, 0, 0), RightUpperLeg=(-35, 15, 0), RightLowerLeg=(-20, 0, 0)), ease=SNAP, cancelL=0.6, cancelR=0.6),
    K(8, P(Chest=(-20, 0, -8), Spine=(-8, 0, 0), Neck=(-16, 0, 0), Head=(-12, 0, 8), loc=(0, -0.24, -0.12),
           LeftUpperArm=(25, 40, 0), LeftLowerArm=(50, 0, 0), RightUpperArm=(15, 42, 0), RightLowerArm=(45, 0, 0))),
    K(14, P(Chest=(-6, 0, -2), loc=(0, -0.12, -0.08))), K(22, S)]
A["block_hit"] = [
    K(0, GUARD),
    K(2, P(GUARD, Chest=(4, 0, 0), loc=(0, -0.08, -0.1), LeftUpperArm=(58, -5, 0), RightUpperArm=(54, -8, 0)), ease=SNAP),
    K(6, P(GUARD, loc=(0, -0.04, -0.1))), K(12, GUARD)]

ST = dict(LeftUpperArm=(12, 18, 0), LeftLowerArm=(30, 0, 0), RightUpperArm=(10, 20, 0), RightLowerArm=(28, 0, 0),
          LeftUpperLeg=(14, 10, 0), LeftLowerLeg=(-22, 0, 0), LeftFoot=(8, 0, 0), RightUpperLeg=(-8, 10, 0), RightLowerLeg=(-18, 0, 0), RightFoot=(20, 0, 0))
ST_L = P(**dict(ST, loc=(0.03, 0, -0.1), Chest=(14, 8, 0), Spine=(10, 10, 0), Neck=(12, 0, 0), Head=(14, 20, 0)))
ST_C = P(**dict(ST, loc=(0, 0, -0.12), Chest=(16, 0, 0), Spine=(10, 0, 0), Neck=(14, 0, 0), Head=(24, 0, 0)))
ST_R = P(**dict(ST, loc=(-0.03, 0, -0.1), Chest=(14, -8, 0), Spine=(10, -10, 0), Neck=(12, 0, 0), Head=(14, -20, 0)))
A["stun"] = [K(0, ST_L), K(9, ST_C), K(18, ST_R), K(27, ST_C), K(36, ST_L)]

LYING = P(Hips=(90, 0, 0), loc=(0, -0.55, -0.83), Spine=(0, 0, 0), Chest=(0, 0, 0), Neck=(8, 0, 0), Head=(0, 0, 0),
          LeftUpperArm=(0, 18, 0), LeftLowerArm=(10, 0, 0), RightUpperArm=(0, 20, 0), RightLowerArm=(8, 0, 0),
          LeftUpperLeg=(0, 10, 0), LeftLowerLeg=(0, 0, 0), LeftFoot=(10, 0, 0), RightUpperLeg=(0, 12, 0), RightLowerLeg=(0, 0, 0), RightFoot=(10, 0, 0))


def fall_keys(end):
    return [K(0, S, cancelL=0, cancelR=0),
            K(4, P(Hips=(40, 0, 0), loc=(0, -0.3, 0.15), Chest=(-10, 0, 0), Neck=(-10, 0, 0), LeftUpperArm=(20, 60, 0), LeftLowerArm=(20, 0, 0),
                   RightUpperArm=(10, 65, 0), RightLowerArm=(20, 0, 0), LeftUpperLeg=(40, 15, 0), LeftLowerLeg=(-40, 0, 0), RightUpperLeg=(25, 15, 0),
                   RightLowerLeg=(-25, 0, 0)), ease=SNAP, cancelL=0, cancelR=0),
            K(9, P(LYING, Hips=(88, 0, 0), loc=(0, -0.55, -0.8)), cancelL=0, cancelR=0),
            K(13, P(LYING, Hips=(80, 0, 0), loc=(0, -0.5, -0.7)), cancelL=0, cancelR=0),
            K(18, LYING, cancelL=0, cancelR=0), K(end, LYING, cancelL=0, cancelR=0)]


A["knockdown"] = fall_keys(30)
A["ko"] = fall_keys(44)
A["getup"] = [
    K(0, LYING, cancelL=0, cancelR=0),
    K(6, P(LYING, Hips=(70, 0, 0), loc=(0, -0.5, -0.7), LeftUpperLeg=(80, 10, 0), LeftLowerLeg=(-100, 0, 0), RightUpperLeg=(70, 12, 0), RightLowerLeg=(-95, 0, 0),
           Chest=(25, 0, 0)), ease=SNAP, cancelL=0, cancelR=0),
    K(12, P(Hips=(20, 0, 0), loc=(0, -0.3, -0.5), Chest=(30, 0, 0), Spine=(15, 0, 0), LeftUpperLeg=(60, 10, 0), LeftLowerLeg=(-100, 0, 0),
            RightUpperLeg=(50, 12, 0), RightLowerLeg=(-90, 0, 0), LeftUpperArm=(40, 20, 0), LeftLowerArm=(60, 0, 0), RightUpperArm=(40, 20, 0),
            RightLowerArm=(60, 0, 0)), cancelL=0, cancelR=0),
    K(18, P(loc=(0, 0, -0.22), Chest=(18, 0, 0), LeftUpperLeg=(40, 10, 0), LeftLowerLeg=(-62, 0, 0), RightUpperLeg=(-14, 10, 0), RightLowerLeg=(-40, 0, 0))),
    K(26, S)]

VIC_UP = P(loc=(0, 0, -0.02), Chest=(-8, 0, 0), Head=(-12, 0, 0), RightUpperArm=(172, 12, 0), RightLowerArm=(4, 0, 0),
           LeftUpperArm=(8, 20, 0), LeftLowerArm=(35, 0, 0), LeftUpperLeg=(8, 8, 0), LeftLowerLeg=(-12, 0, 0), RightUpperLeg=(-6, 10, 0),
           RightLowerLeg=(-10, 0, 0), RightFoot=(14, 0, 0))
A["victory"] = [
    K(0, S),
    K(6, P(loc=(0, 0, -0.12), Chest=(14, 0, 0), RightUpperArm=(10, 20, 0), RightLowerArm=(60, 0, 0)), ease=SNAP),
    K(12, VIC_UP),
    K(18, P(VIC_UP, loc=(0, 0, -0.06), Chest=(-6, 0, 0), Head=(-10, 0, 0), RightUpperArm=(160, 14, 0), RightLowerArm=(10, 0, 0))),
    K(28, VIC_UP),
    K(36, VIC_UP)]

# ---------------------------------------------------------------- build everything
if arm.animation_data:
    for t in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(t)
built = {}
for _name, _keys in A.items():
    built[_name] = make_action(_name, _keys)
for _old in [a for a in bpy.data.actions if a.name.endswith("_old")]:
    bpy.data.actions.remove(_old)
if arm.animation_data:
    arm.animation_data.action = None
FIGHT_BUILT = sorted(built.keys())
