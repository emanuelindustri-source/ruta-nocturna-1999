"""Esteem cabin factory script for Blender (headless).

Reproducible parametric interior blockout of the Esteem 1999 plus the hand rig
with IK poses. Executed by `tools/blender/build_assets.py` inside Blender:

    blender.exe --background --factory-startup --python tools/blender/esteem_cabin.py -- \
        --spec <cabin_spec.json> --output-dir <dir> --report <report.json> [--anchor-mode armature|empties]

Rules:
- Everything is generated from `data/vehicle/cabin_spec.json`. No manual `.blend`
  editing, no external meshes, no reference textures, no brand emblems.
- Coordinates in the spec are engine coordinates (Godot: Y up, forward -Z,
  right +X). They are converted to Blender coordinates (Z up, front +Y) here and
  exported with the standard +Y-up glTF conversion, matching esteem_blockout.py.
- Interior dimensions are provisional (the service manual has no cabin dims).
- The hand rig bones reuse the blockout `anchor_*` control anchors so IK poses
  stay compatible with the vehicle rig anchor.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import bpy  # noqa: E402  (only importable inside Blender)
from mathutils import Matrix, Vector  # noqa: E402


# ---------------------------------------------------------------------------
# Argument parsing (everything after the standalone `--`)
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    argv = sys.argv
    args = argv[argv.index("--") + 1 :] if "--" in argv else []
    parser = argparse.ArgumentParser(description="Esteem cabin factory")
    parser.add_argument("--spec", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--anchor-mode", default="armature", choices=["armature", "empties"])
    return parser.parse_args(args)


# ---------------------------------------------------------------------------
# Coordinate conversion: engine (x right, y up, z rear) -> Blender (x, z_fwd, y)
# ---------------------------------------------------------------------------

def to_blender(position) -> tuple[float, float, float]:
    x, y, z = position
    return (x, -z, y)


def box_from_engine_bounds(min_m, max_m):
    bx0, by0, bz0 = to_blender(tuple(min_m))
    bx1, by1, bz1 = to_blender(tuple(max_m))
    center = ((bx0 + bx1) / 2.0, (by0 + by1) / 2.0, (bz0 + bz1) / 2.0)
    half = (abs(bx1 - bx0) / 2.0, (abs(by1 - by0)) / 2.0, abs(bz1 - bz0) / 2.0)
    return center, half


# ---------------------------------------------------------------------------
# Scene helpers
# ---------------------------------------------------------------------------

def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block_list in (bpy.data.meshes, bpy.data.materials, bpy.data.armatures):
        for block in list(block_list):
            if block.users == 0:
                block_list.remove(block)


def get_material(name: str, spec: dict):
    definition = spec["materials"][name]
    material = bpy.data.materials.get(name)
    if material is None:
        material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    if bsdf is not None:
        bsdf.inputs["Base Color"].default_value = tuple(definition["base_color"])
        bsdf.inputs["Roughness"].default_value = float(definition["roughness"])
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = float(definition.get("metallic", 0.0))
    return material


def apply_bevel(obj, width: float, segments: int) -> None:
    if width > 0.0 and segments > 0:
        modifier = obj.modifiers.new("Bevel", "BEVEL")
        modifier.width = width
        modifier.segments = segments
        modifier.limit_method = "ANGLE"
        modifier.angle_limit = math.radians(40.0)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)


def add_box(name, center, half, material, bevel_width=0.0, bevel_segments=0):
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=center)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = half
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    apply_bevel(obj, bevel_width, bevel_segments)
    obj.data.materials.append(material)
    return obj


def add_oriented_box(name, world_center, half, rotation_matrix, material, bevel_width=0.0, bevel_segments=0):
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=world_center)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = half
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = rotation_matrix.to_quaternion()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    apply_bevel(obj, bevel_width, bevel_segments)
    obj.data.materials.append(material)
    return obj


def add_cylinder(name, world_center, radius, depth, rotation_euler, material, segments=16):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=segments, radius=radius, depth=depth,
        location=world_center, rotation=rotation_euler,
    )
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    obj.data.materials.append(material)
    return obj


def add_torus(name, world_center, major_radius, minor_radius, rotation_euler, material, major_segments=24, minor_segments=10):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_radius, minor_radius=minor_radius,
        major_segments=major_segments, minor_segments=minor_segments,
        location=world_center, rotation=rotation_euler,
    )
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    obj.data.materials.append(material)
    return obj


def mesh_stats(objects) -> tuple[int, int]:
    triangles = 0
    vertices = 0
    for obj in objects:
        if obj.type != "MESH":
            continue
        mesh = obj.data
        mesh.calc_loop_triangles()
        triangles += len(mesh.loop_triangles)
        vertices += len(mesh.vertices)
    return triangles, vertices


# ---------------------------------------------------------------------------
# Component builders (engine-space params, Blender-space geometry)
# ---------------------------------------------------------------------------

def _mat(spec, key):
    return get_material(spec["components"][key].get("material", "cabin_plastic_dark"), spec)


def build_steering_wheel(spec, lod, objects):
    comp = spec["components"]["steering_wheel"]
    center = to_blender(tuple(spec["hand_rig_anchors"]["anchor_steering_wheel"]))
    tilt = math.radians(comp["rotation_blender_deg"][0])
    segments = int(lod["wheel_segments"])
    features = lod.get("features", [])
    material = get_material(comp["material"], spec)

    rim_r = comp["rim_outer_radius_m"] - comp["rim_thickness_m"] / 2.0
    minor = comp["rim_thickness_m"] / 2.0
    objects.append(add_torus("steering_rim", center, rim_r, minor, (tilt, 0.0, 0.0), material,
                             major_segments=segments, minor_segments=max(6, segments // 3)))

    hub_r = comp["hub_radius_m"]
    objects.append(add_cylinder("steering_hub", center, hub_r, comp["rim_thickness_m"] * 1.3,
                                (tilt, 0.0, 0.0), material, segments=max(10, segments // 2)))

    if "spokes" in features:
        spokes = int(comp["spokes"])
        hub_to_rim = (hub_r + rim_r) / 2.0
        spoke_len = (rim_r - hub_r) * 0.9
        for i in range(spokes):
            theta = math.pi / 2.0 + i * (2.0 * math.pi / spokes)
            radial = Vector((math.cos(theta), math.sin(theta), 0.0))
            rot = Matrix.Rotation(tilt, 3, "X") @ Matrix.Rotation(theta, 3, "Z")
            world_dir = Matrix.Rotation(tilt, 3, "X") @ radial
            world_center = Vector(center) + world_dir * hub_to_rim
            half = (spoke_len / 2.0, comp["rim_thickness_m"] * 0.35, comp["rim_thickness_m"] * 0.5)
            objects.append(add_oriented_box(f"steering_spoke_{i}", world_center, half, rot, material,
                                            bevel_width=0.004, bevel_segments=1))
    return objects


def build_gear_lever(spec, lod, objects):
    comp = spec["components"]["gear_lever"]
    anchor = to_blender(tuple(spec["hand_rig_anchors"]["anchor_gear_lever"]))
    features = lod.get("features", [])
    material = get_material(comp["material"], spec)

    # In Blender space +Z is up. The knob sits at the anchor height and the shaft
    # drops toward the console (lower Z).
    knob_half = tuple(v / 2.0 for v in comp["knob_size_m"])
    knob_center = (anchor[0], anchor[1], anchor[2] + knob_half[2] * 0.35)
    objects.append(add_box("gear_knob", knob_center, knob_half, material,
                           bevel_width=0.012, bevel_segments=int(lod["bevel_segments"]) or 1))

    shaft_len = comp["shaft_length_m"]
    shaft_center = (anchor[0], anchor[1], anchor[2] - shaft_len / 2.0)
    objects.append(add_cylinder("gear_shaft", shaft_center, comp["shaft_radius_m"], shaft_len,
                                (0.0, 0.0, 0.0), material, segments=int(lod["wheel_segments"])))

    if "buttons" in features and comp.get("od_button"):
        b = comp["od_button_size_m"]
        btn_half = (b[0] / 2.0, b[1] / 2.0, b[2] / 2.0)
        # Overdrive thumb button on the driver's-left (-X) face of the T-handle.
        btn_center = (anchor[0] - knob_half[0] - btn_half[0] * 0.55, knob_center[1], knob_center[2])
        objects.append(add_box("gear_od_button", btn_center, btn_half, material))
    return objects


def build_handbrake(spec, lod, objects):
    comp = spec["components"]["handbrake"]
    anchor = to_blender(tuple(spec["hand_rig_anchors"]["anchor_handbrake"]))
    tilt = math.radians(comp["tilt_blender_deg"][0])
    material = get_material(comp["material"], spec)

    length = comp["lever_length_m"]
    # lever rises toward +Z (rear) and up, tilted about X
    direction = Matrix.Rotation(tilt, 3, "X") @ Vector((0.0, 0.0, 1.0))
    base = Vector(anchor)
    center = base + direction * (length / 2.0)
    objects.append(add_cylinder("handbrake_lever", center, comp["lever_radius_m"], length,
                                (tilt, 0.0, 0.0), material, segments=int(lod["wheel_segments"])))

    grip = comp["grip_size_m"]
    grip_half = (grip[0] / 2.0, grip[1] / 2.0, grip[2] / 2.0)
    grip_center = base + direction * (length * 0.82)
    objects.append(add_oriented_box("handbrake_grip", grip_center, grip_half,
                                    Matrix.Rotation(tilt, 3, "X"), material,
                                    bevel_width=0.008, bevel_segments=1))
    return objects


def build_component_box(spec, lod, key, objects):
    comp = spec["components"][key]
    center, half = box_from_engine_bounds(comp["min_m"], comp["max_m"])
    material = get_material(comp["material"], spec)
    bevel = float(lod["bevel_width_m"])
    segs = int(lod["bevel_segments"])
    objects.append(add_box(key, center, half, material, bevel_width=bevel, bevel_segments=segs))

    features = lod.get("features", [])
    if key == "radio_double_din" and "radio_slot" in features:
        # Horizontal cassette slot on the radio's front face (faces the driver, -Y).
        slot_half = (half[0] * 0.8, half[1] * 1.02, half[2] * 0.13)
        slot_center = (center[0], center[1], center[2] + half[2] * 0.42)
        objects.append(add_box(key + "_slot", slot_center, slot_half, material))
    if key == "gear_gate_plate" and "gate_notches" in features:
        for i in range(6):
            z = comp["min_m"][2] + (comp["max_m"][2] - comp["min_m"][2]) * (i + 0.5) / 6.0
            n_center, n_half = box_from_engine_bounds(
                [comp["min_m"][0], comp["max_m"][1], z - 0.012],
                [comp["max_m"][0], comp["max_m"][1] + 0.012, z + 0.012],
            )
            objects.append(add_box(f"{key}_notch_{i}", n_center, n_half, material))
    if comp.get("latch") and "latch" in features:
        latch_center = (center[0] + half[0] * 0.5, center[1], center[2] - half[2])
        latch_half = (half[0] * 0.25, half[1] * 0.12, 0.012)
        objects.append(add_box(key + "_latch", latch_center, latch_half, material))
    if comp.get("armrest"):
        arm_center = (center[0] + (0.02 if center[0] > 0 else -0.02), center[1] - half[1] * 0.25, center[2])
        arm_half = (0.035, half[1] * 0.18, half[2] * 0.6)
        objects.append(add_box(key + "_armrest", arm_center, arm_half, material))
    if comp.get("handle"):
        h_center = (center[0] + (0.02 if center[0] > 0 else -0.02), center[1] + half[1] * 0.35, center[2] + half[2] * 0.4)
        h_half = (0.025, 0.02, half[2] * 0.22)
        objects.append(add_box(key + "_handle", h_center, h_half, material))
    if comp.get("window_switch") and "window_switch" in features:
        w_center = (center[0] + (0.03 if center[0] > 0 else -0.03), center[1] - half[1] * 0.25, center[2] + half[2] * 0.55)
        w_half = (0.012, 0.02, 0.05)
        objects.append(add_box(key + "_win_switch", w_center, w_half, material))
    return objects


BOX_COMPONENTS = [
    "instrument_cluster", "dashboard", "dashboard_passenger_tray", "center_stack",
    "air_vent_left", "air_vent_right", "radio_double_din", "climate_controls",
    "console", "gear_gate_plate", "glovebox", "door_panel_driver", "door_panel_passenger",
]


def build_cabin_lod(spec: dict, lod: dict):
    clear_scene()
    objects = []
    for key in BOX_COMPONENTS:
        build_component_box(spec, lod, key, objects)
    build_steering_wheel(spec, lod, objects)
    build_gear_lever(spec, lod, objects)
    build_handbrake(spec, lod, objects)
    return objects


# ---------------------------------------------------------------------------
# Hand rig (rig_anchor) with IK poses
# ---------------------------------------------------------------------------

def build_hand_rig(spec: dict, anchor_mode: str, report: dict):
    clear_scene()
    rig = spec["rig_anchor"]
    anchors = rig["anchors"]
    root_name = rig["root_bone"]
    names = [a["id"] for a in anchors]

    armature_obj = None
    if anchor_mode == "armature":
        armature = bpy.data.armatures.new(rig["armature_name"])
        armature_obj = bpy.data.objects.new(rig["armature_name"], armature)
        bpy.context.collection.objects.link(armature_obj)
        bpy.context.view_layer.objects.active = armature_obj
        bpy.ops.object.mode_set(mode="EDIT")
        edit_bones = armature.edit_bones
        for anchor in anchors:
            bone = edit_bones.new(anchor["id"])
            head = to_blender(tuple(anchor["position_m"]))
            bone.head = head
            bone.tail = (head[0], head[1], head[2] + 0.05)
            bone.align_roll((0.0, 0.0, 1.0))
            if anchor["id"] != root_name:
                bone.parent = edit_bones.get(root_name)
        bpy.ops.object.mode_set(mode="OBJECT")
    else:
        root = bpy.data.objects.new(rig["armature_name"], None)
        root.empty_display_type = "PLAIN_AXES"
        bpy.context.collection.objects.link(root)
        for anchor in anchors:
            if anchor["id"] == root_name:
                continue
            empty = bpy.data.objects.new(anchor["id"], None)
            empty.empty_display_type = "PLAIN_AXES"
            empty.location = to_blender(tuple(anchor["position_m"]))
            empty.parent = root
            bpy.context.collection.objects.link(empty)

    # Bake named IK poses as pose actions (best-effort; poses also live in the spec).
    pose_names = [pose["id"] for pose in rig.get("ik_poses", [])]
    if anchor_mode == "armature" and armature_obj is not None:
        bind = {a["id"]: to_blender(tuple(a["position_m"])) for a in anchors}
        try:
            bpy.context.view_layer.objects.active = armature_obj
            bpy.ops.object.mode_set(mode="POSE")
            for pose in rig.get("ik_poses", []):
                action = bpy.data.actions.new(pose["id"])
                armature_obj.animation_data_create()
                armature_obj.animation_data.action = action
                for bone_id, target in pose.get("hand_targets_m", {}).items():
                    pb = armature_obj.pose.bones.get(bone_id)
                    if pb is None:
                        continue
                    tb = to_blender(tuple(target))
                    pb.location = Vector(tb) - Vector(bind[bone_id])
                    pb.keyframe_insert(data_path="location", frame=1)
            bpy.ops.object.mode_set(mode="OBJECT")
        except Exception as exc:  # noqa: BLE001 - poses remain in spec if baking fails
            print(f"[FACTORY][WARN] No se pudieron hornear las poses IK: {exc}")
            try:
                bpy.ops.object.mode_set(mode="OBJECT")
            except Exception:  # noqa: BLE001
                pass

    report["hand_rig_poses"] = pose_names
    return names


# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------

def export_glb(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=False,
        export_apply=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
        export_animations=True,
    )


def main() -> int:
    args = parse_args()
    spec_path = Path(args.spec).resolve()
    output_dir = Path(args.output_dir).resolve()
    report_path = Path(args.report).resolve()
    spec = json.loads(spec_path.read_text(encoding="utf-8"))

    # convenience map: anchor id -> engine position for component placement
    spec["hand_rig_anchors"] = {a["id"]: a["position_m"] for a in spec["rig_anchor"]["anchors"]}

    bpy.ops.wm.read_factory_settings(use_empty=True)

    outputs = []
    report: dict = {}
    for lod in spec["lods"]:
        objects = build_cabin_lod(spec, lod)
        triangles, vertices = mesh_stats(objects)
        out_path = output_dir / Path(lod["output"]).name
        export_glb(out_path)
        outputs.append(
            {
                "file": out_path.name,
                "kind": "mesh_lod",
                "lod": int(lod["id"].replace("lod", "")),
                "triangles": triangles,
                "vertices": vertices,
                "max_triangles": int(lod["max_triangles"]),
                "objects": sorted(obj.name for obj in objects),
            }
        )

    anchor_names = build_hand_rig(spec, args.anchor_mode, report)
    anchor_path = output_dir / Path(spec["rig_anchor"]["output"]).name
    export_glb(anchor_path)
    outputs.append(
        {
            "file": anchor_path.name,
            "kind": "rig_anchor",
            "anchor_mode": args.anchor_mode,
            "anchors": anchor_names,
            "ik_poses": report.get("hand_rig_poses", []),
            "triangles": 0,
            "vertices": 0,
        }
    )

    report_out = {
        "asset_id": spec["asset_id"],
        "spec_file": str(spec_path),
        "blender_version": bpy.app.version_string,
        "anchor_mode": args.anchor_mode,
        "outputs": outputs,
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report_out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"[FACTORY] Reporte escrito en {report_path}")
    for output in outputs:
        if output["kind"] == "mesh_lod":
            print(f"[FACTORY] {output['file']}: {output['triangles']} triangulos, {output['vertices']} vertices")
        else:
            print(f"[FACTORY] {output['file']}: {len(output['anchors'])} anclas, {len(output.get('ik_poses', []))} poses IK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
