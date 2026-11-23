"""Esteem interior factory script for Blender (headless).

Reproducible parametric definitive interior of the Esteem 1999: two-tone
dashboard, three-pod instrument cluster (no text), center stack with cassette
radio and climate sliders, console with P-R-N-D-2-L gate and T-handle shifter,
handbrake, glovebox, front bucket seats and rear bench with fabric inserts,
door cards, carpets, headliner, trunk with real inventory tools and definitive
hand meshes. It is executed by `tools/blender/build_assets.py` inside Blender:

    blender.exe --background --factory-startup --python tools/blender/esteem_interior.py -- \
        --spec <interior_spec.json> --output-dir <dir> --report <report.json> [--anchor-mode armature|empties]

Rules:
- Everything is generated from `data/vehicle/interior_spec.json`. No manual
  `.blend` editing, no external meshes, no reference textures.
- Coordinates in the spec are engine coordinates (Godot: Y up, forward -Z,
  right +X). They are converted to Blender coordinates (Z up, front +Y) here
  and exported with the standard +Y-up glTF conversion.
- No brand emblems, badges or visible text: gauges, the gear gate and panels
  stay plain. Nothing is copied from the external reference library.
- Control pieces keep the F2.2 bind positions and node names so the F2.3
  interaction layer (`cabin_visual_proxies.gd`, `visual_offsets` of
  `cabin_interaction.json` v2) stays valid without contract changes.
- The script only writes to the output directory and the report path.
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
    parser = argparse.ArgumentParser(description="Esteem interior factory")
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


def rotation_to_blender(rotation_deg):
    """Engine rotation (about X, Y, Z) -> Blender rotation (about X, Y, Z)."""
    rx, ry, rz = rotation_deg
    return (math.radians(rx), math.radians(-rz), math.radians(ry))


def box_from_engine_bounds(min_m, max_m):
    bx0, by0, bz0 = to_blender(tuple(min_m))
    bx1, by1, bz1 = to_blender(tuple(max_m))
    center = ((bx0 + bx1) / 2.0, (by0 + by1) / 2.0, (bz0 + bz1) / 2.0)
    half = (abs(bx1 - bx0) / 2.0, abs(by1 - by0) / 2.0, abs(bz1 - bz0) / 2.0)
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
        bsdf.inputs["Roughness"].default_value = float(definition.get("roughness", 0.5))
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = float(definition.get("metallic", 0.0))
        if "Transmission Weight" in bsdf.inputs and "transmission" in definition:
            bsdf.inputs["Transmission Weight"].default_value = float(definition["transmission"])
        if "IOR" in bsdf.inputs and "ior" in definition:
            bsdf.inputs["IOR"].default_value = float(definition["ior"])
        if "emission_color" in definition and "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = tuple(definition["emission_color"])
        if "emission_strength" in definition and "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = float(definition["emission_strength"])
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


def add_box(name, piece, material, bevel_width=0.0, bevel_segments=0):
    """Engine-space AABB box, optionally rotated about its own center."""
    center, half = box_from_engine_bounds(piece["min_m"], piece["max_m"])
    rotation = rotation_to_blender(tuple(piece.get("rotation_deg", (0.0, 0.0, 0.0))))
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=center, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = half
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    apply_bevel(obj, bevel_width, bevel_segments)
    obj.data.materials.append(material)
    return obj


def add_box_bounds(name, min_m, max_m, material, bevel_width=0.0, bevel_segments=0, rotation_deg=(0.0, 0.0, 0.0)):
    piece = {"min_m": min_m, "max_m": max_m, "rotation_deg": rotation_deg}
    return add_box(name, piece, material, bevel_width, bevel_segments)


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


AXIS_ROTATION = {
    "y": (0.0, 0.0, 0.0),           # engine Y (up) -> Blender Z
    "z": (math.pi / 2.0, 0.0, 0.0),  # engine Z (rear) -> Blender -Y
    "x": (0.0, math.pi / 2.0, 0.0),  # engine X -> Blender X
}


def add_cylinder(name, piece, material, segments=16):
    center = to_blender(tuple(piece["center_m"]))
    if "rotation_deg" in piece:
        rotation = rotation_to_blender(tuple(piece["rotation_deg"]))
    else:
        rotation = AXIS_ROTATION.get(str(piece.get("axis", "y")), (0.0, 0.0, 0.0))
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=segments,
        radius=float(piece["radius_m"]),
        depth=float(piece["length_m"]),
        location=center,
        rotation=rotation,
    )
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    obj.data.materials.append(material)
    return obj


def add_torus(name, piece, material, major_segments=24, minor_segments=10):
    center = to_blender(tuple(piece["center_m"]))
    rotation = rotation_to_blender(tuple(piece.get("rotation_deg", (0.0, 0.0, 0.0))))
    bpy.ops.mesh.primitive_torus_add(
        major_radius=float(piece["major_radius_m"]),
        minor_radius=float(piece["minor_radius_m"]),
        major_segments=major_segments,
        minor_segments=minor_segments,
        location=center,
        rotation=rotation,
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
# Piece builders
# ---------------------------------------------------------------------------

def build_pieces(spec: dict, lod: dict, objects) -> None:
    wanted = set(lod.get("features", []))
    full_detail = str(lod.get("detail", "")) == "full"
    bevel_width = float(lod["bevel_width_m"])
    bevel_segments = int(lod["bevel_segments"])
    segments = int(lod["wheel_segments"])

    for piece in spec["pieces"]:
        if not any(feature in wanted for feature in piece.get("features", [])):
            continue
        material = get_material(piece["material"], spec)
        kind = piece.get("kind", "box")
        if kind == "box":
            objects.append(add_box(piece["id"], piece, material, bevel_width, bevel_segments))
            if piece.get("slats") and full_detail:
                slat_count = int(piece["slats"])
                y_lo = piece["min_m"][1] + 0.012
                y_span = (piece["max_m"][1] - piece["min_m"][1] - 0.024) / max(1, slat_count - 1)
                for slat in range(slat_count):
                    y0 = y_lo + slat * y_span
                    slat_piece = {
                        "min_m": [piece["min_m"][0] + 0.004, y0, piece["min_m"][2] - 0.006],
                        "max_m": [piece["max_m"][0] - 0.004, y0 + 0.014, piece["max_m"][2] + 0.006],
                    }
                    objects.append(add_box_bounds("%s_slat_%d" % (piece["id"], slat), slat_piece["min_m"], slat_piece["max_m"], material))
            if piece.get("slider_count") and full_detail:
                for slider in range(int(piece["slider_count"])):
                    cx = piece["min_m"][0] + (piece["max_m"][0] - piece["min_m"][0]) * (0.3 + 0.4 * slider)
                    slider_piece = {
                        "min_m": [cx - 0.018, piece["min_m"][1] + 0.035, piece["min_m"][2] - 0.008],
                        "max_m": [cx + 0.018, piece["min_m"][1] + 0.055, piece["max_m"][2] + 0.008],
                    }
                    objects.append(add_box_bounds("%s_slider_%d" % (piece["id"], slider), slider_piece["min_m"], slider_piece["max_m"], get_material("plastic_dark", spec)))
            if piece.get("notches") and "gate_notches" in wanted:
                count = int(piece["notches"])
                notch = [float(v) for v in piece.get("notch_size_m", [0.03, 0.006, 0.018])]
                z0 = piece["min_m"][2] + 0.03
                z1 = piece["max_m"][2] - 0.03
                for index in range(count):
                    t = index / max(1, count - 1)
                    z = z0 + (z1 - z0) * t
                    cx = (piece["min_m"][0] + piece["max_m"][0]) / 2.0
                    cy = piece["max_m"][1] + notch[1] * 0.3
                    notch_piece = {
                        "min_m": [cx - notch[0] / 2.0, cy, z - notch[2] / 2.0],
                        "max_m": [cx + notch[0] / 2.0, cy + notch[1], z + notch[2] / 2.0],
                    }
                    objects.append(add_box_bounds("%s_notch_%d" % (piece["id"], index), notch_piece["min_m"], notch_piece["max_m"], get_material("plastic_dark", spec)))
        elif kind == "cylinder":
            objects.append(add_cylinder(piece["id"], piece, material, segments=max(8, segments // 2)))
        elif kind == "torus":
            objects.append(add_torus(piece["id"], piece, material, major_segments=segments, minor_segments=max(6, segments // 3)))


def build_controls(spec: dict, lod: dict, objects) -> None:
    """Steering wheel / column / gear lever / handbrake (F2.2 bind geometry)."""
    controls = spec["controls_geometry"]
    features = set(lod.get("features", []))
    segments = int(lod["wheel_segments"])
    bevel_width = float(lod["bevel_width_m"])
    bevel_segments = int(lod["bevel_segments"])

    wheel = controls["steering_wheel"]
    anchor = spec["_anchor_positions"][wheel["anchor"]]
    center = to_blender(tuple(anchor))
    tilt = math.radians(wheel["rotation_blender_deg"][0])
    material = get_material(wheel["material"], spec)

    if "steering" in features:
        rim_r = wheel["rim_outer_radius_m"] - wheel["rim_thickness_m"] / 2.0
        minor = wheel["rim_thickness_m"] / 2.0
        objects.append(add_torus(
            "steering_rim",
            {"center_m": anchor, "major_radius_m": rim_r, "minor_radius_m": minor,
             "rotation_deg": wheel["rotation_blender_deg"]},
            material, major_segments=segments, minor_segments=max(6, segments // 3),
        ))
        hub_r = wheel["hub_radius_m"]
        objects.append(add_cylinder(
            "steering_hub",
            {"center_m": anchor, "radius_m": hub_r, "length_m": wheel["rim_thickness_m"] * 1.3, "axis": "y",
             "rotation_deg": wheel["rotation_blender_deg"]},
            material, segments=max(10, segments // 2),
        ))
        column = controls["steering_column"]
        offset = tuple(column["offset_m"])
        column_center = (anchor[0] + offset[0], anchor[1] + offset[1], anchor[2] + offset[2])
        objects.append(add_cylinder(
            "steering_column",
            {"center_m": column_center, "radius_m": column["radius_m"], "length_m": column["length_m"], "axis": "y",
             "rotation_deg": column["direction_blender_deg"]},
            material, segments=max(10, segments // 2),
        ))

    if "spokes" in features and "steering" in features:
        spokes = int(wheel["spokes"])
        hub_r = wheel["hub_radius_m"]
        rim_r = wheel["rim_outer_radius_m"] - wheel["rim_thickness_m"] / 2.0
        hub_to_rim = (hub_r + rim_r) / 2.0
        spoke_len = (rim_r - hub_r) * 0.9
        for i in range(spokes):
            theta = math.pi / 2.0 + i * (2.0 * math.pi / spokes)
            radial = Vector((math.cos(theta), math.sin(theta), 0.0))
            rot = Matrix.Rotation(tilt, 3, "X") @ Matrix.Rotation(theta, 3, "Z")
            world_dir = Matrix.Rotation(tilt, 3, "X") @ radial
            world_center = Vector(center) + world_dir * hub_to_rim
            half = (spoke_len / 2.0, wheel["rim_thickness_m"] * 0.35, wheel["rim_thickness_m"] * 0.5)
            objects.append(add_oriented_box("steering_spoke_%d" % i, world_center, half, rot, material,
                                            bevel_width=0.004, bevel_segments=1))

    gear = controls["gear_lever"]
    if "lever" in features:
        anchor = spec["_anchor_positions"][gear["anchor"]]
        material = get_material(gear["material"], spec)
        knob_half = tuple(v / 2.0 for v in gear["knob_size_m"])
        knob_center = (anchor[0], anchor[1], anchor[2] + knob_half[2] * 0.35)
        objects.append(add_box_bounds("gear_knob", (
            knob_center[0] - knob_half[0], knob_center[1] - knob_half[1], knob_center[2] - knob_half[2]), (
            knob_center[0] + knob_half[0], knob_center[1] + knob_half[1], knob_center[2] + knob_half[2]),
            material, bevel_width=0.012, bevel_segments=bevel_segments or 1))
        shaft_len = gear["shaft_length_m"]
        shaft_center = (anchor[0], anchor[1], anchor[2] - shaft_len / 2.0)
        objects.append(add_cylinder(
            "gear_shaft",
            {"center_m": shaft_center, "radius_m": gear["shaft_radius_m"], "length_m": shaft_len, "axis": "y"},
            material, segments=max(8, segments // 2)))
        if gear.get("od_button") and "buttons" in features:
            b = gear["od_button_size_m"]
            btn_half = (b[0] / 2.0, b[1] / 2.0, b[2] / 2.0)
            btn_center = (anchor[0] - knob_half[0] - btn_half[0] * 0.55, knob_center[1], knob_center[2])
            objects.append(add_box_bounds("gear_od_button", (
                btn_center[0] - btn_half[0], btn_center[1] - btn_half[1], btn_center[2] - btn_half[2]), (
                btn_center[0] + btn_half[0], btn_center[1] + btn_half[1], btn_center[2] + btn_half[2]),
                material))

    handbrake = controls["handbrake"]
    if "handbrake" in features:
        anchor = spec["_anchor_positions"][handbrake["anchor"]]
        material = get_material(handbrake["material"], spec)
        tilt = math.radians(handbrake["tilt_blender_deg"][0])
        length = handbrake["lever_length_m"]
        # Lever rises toward engine +Z (rear) and up, tilted about X.
        direction = Vector(to_blender((0.0, math.sin(tilt), math.cos(tilt))))
        center = Vector(to_blender(tuple(anchor))) + direction * (length / 2.0)
        rot = Matrix.Rotation(tilt, 3, "X")
        half = (handbrake["lever_radius_m"], handbrake["lever_radius_m"], length / 2.0)
        objects.append(add_oriented_box("handbrake_lever", center, half, rot, material,
                                        bevel_width=0.003, bevel_segments=1))
        grip = handbrake["grip_size_m"]
        grip_center = Vector(to_blender(tuple(anchor))) + direction * (length - grip[2] / 2.0 + 0.01)
        objects.append(add_oriented_box("handbrake_grip", grip_center,
                                        (grip[0] / 2.0, grip[1] / 2.0, grip[2] / 2.0), rot, material,
                                        bevel_width=0.008, bevel_segments=bevel_segments or 1))


def build_hands(spec: dict, lod: dict, objects) -> None:
    """Definitive hand meshes: palm + four fingers (+thumb), one joined object per hand."""
    hands = spec["hands"]
    features = set(lod.get("features", []))
    full_detail = str(lod.get("detail", "")) == "full"
    with_fingers = "hand_fingers" in features
    material = get_material(hands["material"], spec)
    bevel_width = 0.004 if full_detail else 0.0
    palm = hands["palm_size_m"]
    fingers = hands["fingers"]
    thumb = hands["thumb"]

    for hand_id in hands["ids"]:
        bind = hands["bind"][hand_id]
        center = tuple(bind["palm_center_m"])
        parts = []
        half = (palm[0] / 2.0, palm[1] / 2.0, palm[2] / 2.0)
        parts.append(add_box_bounds(hand_id + "_palm", (
            center[0] - half[0], center[1] - half[1], center[2] - half[2]), (
            center[0] + half[0], center[1] + half[1], center[2] + half[2]),
            material, bevel_width=bevel_width, bevel_segments=1))
        if with_fingers:
            count = int(fingers["count"])
            spread = float(fingers["spread_m"])
            width = float(fingers["width_m"])
            thick = float(fingers["thickness_m"])
            for index in range(count):
                x = center[0] + (index - (count - 1) / 2.0) * spread
                z_cursor = center[2] - palm[2] / 2.0
                for segment_index, length in enumerate(fingers["segment_lengths_m"]):
                    z0 = z_cursor - float(length)
                    parts.append(add_box_bounds("%s_finger_%d_%d" % (hand_id, index, segment_index), (
                        x - width / 2.0, center[1] - thick / 2.0, z0), (
                        x + width / 2.0, center[1] + thick / 2.0, z_cursor),
                        material, bevel_width=bevel_width, bevel_segments=1))
                    z_cursor = z0
            # Thumb: two segments, splayed toward the palm front in the
            # horizontal plane (engine yaw about Y == Blender yaw about Z).
            yaw_deg = abs(float(thumb.get("yaw_deg", -38.0)))
            s = 1.0 if bind.get("side") == "right" else -1.0
            t_off = thumb["offset_m"]
            base_engine = Vector((
                center[0] + t_off[0] * s,
                center[1] + t_off[1],
                center[2] + t_off[2],
            ))
            direction_engine = Vector((s * math.sin(math.radians(yaw_deg)), 0.0, -math.cos(math.radians(yaw_deg))))
            rot = Matrix.Rotation(math.radians(-s * yaw_deg), 3, "Z")
            cursor = base_engine
            for segment_index, length in enumerate(thumb["segment_lengths_m"]):
                step = direction_engine * float(length)
                mid_engine = cursor + step * 0.5
                half_t = (thumb["width_m"] / 2.0, float(length) / 2.0, thumb["thickness_m"] / 2.0)
                parts.append(add_oriented_box("%s_thumb_%d" % (hand_id, segment_index),
                                              Vector(to_blender(tuple(mid_engine))), half_t, rot, material,
                                              bevel_width=bevel_width, bevel_segments=1))
                cursor = cursor + step
        # Join every part into a single object per hand so the interaction layer
        # can rebind `hand_left` / `hand_right` as one mesh.
        bpy.ops.object.select_all(action="DESELECT")
        for part in parts:
            part.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]
        bpy.ops.object.join()
        joined = bpy.context.active_object
        joined.name = hand_id
        if joined not in objects:
            objects.append(joined)


# ---------------------------------------------------------------------------
# Rig anchor
# ---------------------------------------------------------------------------

def build_rig_anchor(spec: dict, anchor_mode: str):
    clear_scene()
    rig = spec["rig_anchor"]
    anchors = rig["anchors"]
    names = [anchor["id"] for anchor in anchors]
    root_name = rig["root_bone"]

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
    )


def main() -> int:
    args = parse_args()
    spec_path = Path(args.spec).resolve()
    output_dir = Path(args.output_dir).resolve()
    report_path = Path(args.report).resolve()
    spec = json.loads(spec_path.read_text(encoding="utf-8"))

    spec["_anchor_positions"] = {
        anchor["id"]: anchor["position_m"] for anchor in spec["rig_anchor"]["anchors"]
    }
    for anchor in spec.get("anchor_frame", {}).get("used_anchors", []):
        spec["_anchor_positions"].setdefault(anchor, [0.0, 0.0, 0.0])

    bpy.ops.wm.read_factory_settings(use_empty=True)

    outputs = []
    for lod in spec["lods"]:
        clear_scene()
        objects = []
        build_pieces(spec, lod, objects)
        build_controls(spec, lod, objects)
        build_hands(spec, lod, objects)
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

    anchor_names = build_rig_anchor(spec, args.anchor_mode)
    anchor_path = output_dir / Path(spec["rig_anchor"]["output"]).name
    export_glb(anchor_path)
    outputs.append(
        {
            "file": anchor_path.name,
            "kind": "rig_anchor",
            "anchor_mode": args.anchor_mode,
            "anchors": anchor_names,
            "triangles": 0,
            "vertices": 0,
        }
    )

    report = {
        "asset_id": spec["asset_id"],
        "spec_file": str(spec_path),
        "blender_version": bpy.app.version_string,
        "anchor_mode": args.anchor_mode,
        "outputs": outputs,
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"[FACTORY] Reporte escrito en {report_path}")
    for output in outputs:
        print(
            f"[FACTORY] {output['file']}: {output['triangles']} triangulos, "
            f"{output['vertices']} vertices"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
