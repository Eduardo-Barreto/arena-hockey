import bpy
import bmesh
import math
import os

RINK_LENGTH = 3.0
RINK_WIDTH = 1.5
CORNER_RADIUS = 0.15
WALL_HEIGHT = 0.18
WALL_THICKNESS = 0.02
WALL_SINK = 0.05
FLOOR_THICKNESS = 0.01
GOAL_WIDTH = 0.52
GOAL_DEPTH = 0.18
CORNER_SEGMENTS = 16


def scene_collection():
    return bpy.data.scenes[0].collection


def link(obj):
    scene_collection().objects.link(obj)


def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)
    for mat in list(bpy.data.materials):
        bpy.data.materials.remove(mat)


def make_mesh(name, bm):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    link(obj)
    return obj


def build_profile(half_l, half_w, radius, goal_half):
    """Rounded rect with explicit vertices at goal openings.
    Returns (verts, goal_segment_indices)."""
    verts = []
    goal_segs = set()

    def add_corner(cx, cy, start_angle):
        for i in range(CORNER_SEGMENTS):
            angle = start_angle + (math.pi / 2) * i / CORNER_SEGMENTS
            verts.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))

    add_corner(half_l - radius, half_w - radius, 0)
    add_corner(-half_l + radius, half_w - radius, math.pi / 2)

    idx = len(verts)
    verts.append((-half_l, goal_half))
    goal_segs.add(idx)
    verts.append((-half_l, -goal_half))

    add_corner(-half_l + radius, -half_w + radius, math.pi)
    add_corner(half_l - radius, -half_w + radius, 3 * math.pi / 2)

    idx = len(verts)
    verts.append((half_l, -goal_half))
    goal_segs.add(idx)
    verts.append((half_l, goal_half))

    return verts, goal_segs


def create_floor():
    half_l = RINK_LENGTH / 2
    half_w = RINK_WIDTH / 2
    profile = []

    def add_corner(cx, cy, start_angle):
        for i in range(CORNER_SEGMENTS):
            angle = start_angle + (math.pi / 2) * i / CORNER_SEGMENTS
            profile.append((
                cx + CORNER_RADIUS * math.cos(angle),
                cy + CORNER_RADIUS * math.sin(angle),
            ))

    add_corner(half_l - CORNER_RADIUS, half_w - CORNER_RADIUS, 0)
    add_corner(-half_l + CORNER_RADIUS, half_w - CORNER_RADIUS, math.pi / 2)
    add_corner(-half_l + CORNER_RADIUS, -half_w + CORNER_RADIUS, math.pi)
    add_corner(half_l - CORNER_RADIUS, -half_w + CORNER_RADIUS, 3 * math.pi / 2)

    bm = bmesh.new()
    bottom = [bm.verts.new((x, y, -FLOOR_THICKNESS)) for x, y in profile]
    top = [bm.verts.new((x, y, 0)) for x, y in profile]

    bm.faces.new(bottom)
    bm.faces.new(list(reversed(top)))

    n = len(profile)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new([bottom[i], bottom[j], top[j], top[i]])

    return make_mesh("Floor", bm)


def create_walls():
    half_l = RINK_LENGTH / 2
    half_w = RINK_WIDTH / 2
    goal_half = GOAL_WIDTH / 2

    outer, goal_segs = build_profile(half_l, half_w, CORNER_RADIUS, goal_half)

    inner_r = max(CORNER_RADIUS - WALL_THICKNESS, 0.001)
    inner, _ = build_profile(
        half_l - WALL_THICKNESS, half_w - WALL_THICKNESS, inner_r, goal_half
    )

    n = len(outer)
    bm = bmesh.new()

    ob = [bm.verts.new((x, y, -WALL_SINK)) for x, y in outer]
    ot = [bm.verts.new((x, y, WALL_HEIGHT)) for x, y in outer]
    ib = [bm.verts.new((x, y, -WALL_SINK)) for x, y in inner]
    it = [bm.verts.new((x, y, WALL_HEIGHT)) for x, y in inner]

    for i in range(n):
        j = (i + 1) % n

        if i in goal_segs:
            bm.faces.new([ob[i], ib[i], it[i], ot[i]])
            bm.faces.new([ib[j], ob[j], ot[j], it[j]])
            continue

        bm.faces.new([ob[i], ob[j], ot[j], ot[i]])
        bm.faces.new([ib[j], ib[i], it[i], it[j]])
        bm.faces.new([ot[i], ot[j], it[j], it[i]])
        bm.faces.new([ob[j], ob[i], ib[i], ib[j]])

    return make_mesh("Walls-col", bm)


def create_box(name, x1, x2, y1, y2, z1, z2):
    xa, xb = min(x1, x2), max(x1, x2)
    ya, yb = min(y1, y2), max(y1, y2)
    za, zb = min(z1, z2), max(z1, z2)

    bm = bmesh.new()
    v = [
        bm.verts.new((xa, ya, za)),
        bm.verts.new((xb, ya, za)),
        bm.verts.new((xb, yb, za)),
        bm.verts.new((xa, yb, za)),
        bm.verts.new((xa, ya, zb)),
        bm.verts.new((xb, ya, zb)),
        bm.verts.new((xb, yb, zb)),
        bm.verts.new((xa, yb, zb)),
    ]
    bm.faces.new([v[0], v[3], v[2], v[1]])
    bm.faces.new([v[4], v[5], v[6], v[7]])
    bm.faces.new([v[0], v[1], v[5], v[4]])
    bm.faces.new([v[2], v[3], v[7], v[6]])
    bm.faces.new([v[0], v[4], v[7], v[3]])
    bm.faces.new([v[1], v[2], v[6], v[5]])

    return make_mesh(name, bm)


def create_goal(side):
    sign = 1 if side == "right" else -1
    half_l = RINK_LENGTH / 2
    gh = GOAL_WIDTH / 2
    wt = WALL_THICKNESS

    x_front = sign * half_l
    x_back = sign * (half_l + GOAL_DEPTH)
    x_min, x_max = min(x_front, x_back), max(x_front, x_back)

    suffix = "R" if side == "right" else "L"

    back_outer = x_back + sign * wt
    create_box(f"Goal{suffix}Back-convcol", x_back, back_outer, -gh, gh, -WALL_SINK, WALL_HEIGHT)
    create_box(f"Goal{suffix}SideL-convcol", x_min, x_max, -gh - wt, -gh, -WALL_SINK, WALL_HEIGHT)
    create_box(f"Goal{suffix}SideR-convcol", x_min, x_max, gh, gh + wt, -WALL_SINK, WALL_HEIGHT)


def create_line_markings():
    line_w = 0.01
    z = 0.001
    half_w = RINK_WIDTH / 2 - WALL_THICKNESS

    bm = bmesh.new()
    v = [
        bm.verts.new((-line_w / 2, -half_w, z)),
        bm.verts.new((line_w / 2, -half_w, z)),
        bm.verts.new((line_w / 2, half_w, z)),
        bm.verts.new((-line_w / 2, half_w, z)),
    ]
    bm.faces.new(v)
    make_mesh("CenterLine", bm)

    bm = bmesh.new()
    segs = 64
    r = 0.20
    for i in range(segs):
        a1 = 2 * math.pi * i / segs
        a2 = 2 * math.pi * (i + 1) / segs
        ri = r - line_w / 2
        ro = r + line_w / 2
        v1 = bm.verts.new((ri * math.cos(a1), ri * math.sin(a1), z))
        v2 = bm.verts.new((ro * math.cos(a1), ro * math.sin(a1), z))
        v3 = bm.verts.new((ro * math.cos(a2), ro * math.sin(a2), z))
        v4 = bm.verts.new((ri * math.cos(a2), ri * math.sin(a2), z))
        bm.faces.new([v1, v2, v3, v4])
    make_mesh("CenterCircle", bm)


def assign_materials():
    mats = {
        "FloorMaterial": ((0.9, 0.9, 0.9, 1), 0.8),
        "WallMaterial": ((0.95, 0.95, 0.95, 1), 0.6),
        "LineMaterial": ((0.1, 0.1, 0.1, 1), 0.5),
        "GoalMaterial": ((0.8, 0.2, 0.2, 1), 0.5),
    }

    created = {}
    for name, (color, roughness) in mats.items():
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = roughness
        created[name] = mat

    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        if "Floor" in obj.name:
            obj.data.materials.append(created["FloorMaterial"])
        elif "Wall" in obj.name:
            obj.data.materials.append(created["WallMaterial"])
        elif "Goal" in obj.name:
            obj.data.materials.append(created["GoalMaterial"])
        elif "Line" in obj.name or "Circle" in obj.name:
            obj.data.materials.append(created["LineMaterial"])


def export_glb(filepath):
    bpy.ops.export_scene.gltf(
        filepath=filepath,
        export_format="GLB",
        export_apply=True,
    )


def main():
    clear_scene()
    create_floor()
    create_walls()
    create_goal("right")
    create_goal("left")
    create_line_markings()
    print("Meshes:", [o.name for o in bpy.data.objects if o.type == "MESH"])
    assign_materials()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)
    output_path = os.path.join(project_dir, "models", "Rink.glb")
    export_glb(output_path)
    print(f"Exported to {output_path}")


if __name__ == "__main__":
    main()
