"""Esteem blockout factory script for Blender (headless).

Reproducible parametric greybox of the Esteem 1999: mass volumes, wheels,
LOD0/LOD1/LOD2 meshes and the vehicle rig anchor armature. It is executed by
`tools/blender/build_assets.py` inside Blender:

    blender.exe --background --factory-startup --python tools/blender/esteem_blockout.py -- \
        --spec <spec.json> --output-dir <dir> --report <report.json> [--anchor-mode armature|empties]

Rules:
- Everything is generated from `data/vehicle/blockout_spec.json`. No manual
  `.blend` editing, no external meshes, no reference textures.
- Coordinates in the spec are engine coordinates (Godot: Y up, forward -Z,
  right +X). They are converted to Blender coordinates (Z up, front +Y) here
  and exported with the standard +Y-up glTF conversion.
- The script only writes to the output directory and the report path.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import bpy  # noqa: E402  (only importable inside Blender)


# ---------------------------------------------------------------------------
# Argument parsing (everything after the standalone `--`)
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    argv = sys.argv
    args = argv[argv.index("--") + 1 :] if "--" in argv else []
    parser = argparse.ArgumentParser(description="Esteem blockout factory")
    parser.add_argument("--spec", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--anchor-mode", default="armature", choices=["armature", "empties"])
    return parser.parse_args(args)


# ---------------------------------------------------------------------------
# Coordinate conversion: engine (x right, y up, z rear) -> Blender (x, z_fwd, y)
# ---------------------------------------------------------------------------

def to_blender(position: tuple[float, float, float]) -> tuple[float, float, float]:
    x, y, z = position
    return (x, -z, y)


def box_from_engine_bounds(min_m, max_m):
    """Return Blender-space center and half-extents for an engine-space AABB."""
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
    materials = spec["materials"]
    definition = materials[name]
    material = bpy.data.materials.get(name)
    if material is None:
        material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    if bsdf is not None:
        bsdf.inputs["Base Color"].default_value = tuple(definition["base_color"])
        bsdf.inputs["Roughness"].default_value = float(definition["roughness"])
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = 0.0
    return material


def add_box(name: str, center, half, material, bevel_width: float, bevel_segments: int):
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=center)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = half
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel_width > 0.0 and bevel_segments > 0:
        modifier = obj.modifiers.new("Bevel", "BEVEL")
        modifier.width = bevel_width
        modifier.segments = bevel_segments
        modifier.limit_method = "ANGLE"
        modifier.angle_limit = math.radians(40.0)
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.append(material)
    return obj


def add_wheel(name: str, center_engine, radius: float, width: float, segments: int,
              material, add_hub: bool):
    center = to_blender(tuple(center_engine))
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=segments,
        radius=radius,
        depth=width,
        location=center,
        rotation=(0.0, math.pi / 2.0, 0.0),
    )
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    obj.data.materials.append(material)
    made = [obj]
    if add_hub:
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=max(8, segments // 2),
            radius=radius * 0.55,
            depth=width * 1.12,
            location=center,
            rotation=(0.0, math.pi / 2.0, 0.0),
        )
        hub = bpy.context.active_object
        hub.name = name + "_hub"
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
        hub.data.materials.append(material)
        made.append(hub)
    return made


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
# Builders
# ---------------------------------------------------------------------------

def build_mesh_lod(spec: dict, lod: dict):
    clear_scene()
    bevel_width = float(lod["bevel_width_m"])
    bevel_segments = int(lod["bevel_segments"])
    objects = []
    for mass in spec["masses"]:
        center, half = box_from_engine_bounds(mass["min_m"], mass["max_m"])
        material = get_material(mass["material"], spec)
        objects.append(
            add_box(mass["id"], center, half, material, bevel_width, bevel_segments)
        )

    dims = spec["dimensions"]
    half_track = float(dims["track_m"]) / 2.0
    half_wheelbase = float(dims["wheelbase_m"]) / 2.0
    radius = float(dims["wheel_radius_m"])
    width = float(dims["wheel_width_m"])
    wheel_positions = {
        "wheel_fl": (-half_track, radius, -half_wheelbase),
        "wheel_fr": (half_track, radius, -half_wheelbase),
        "wheel_rl": (-half_track, radius, half_wheelbase),
        "wheel_rr": (half_track, radius, half_wheelbase),
    }
    wheel_material = get_material(spec["wheels"]["material"], spec)
    for wheel_id in spec["wheels"]["ids"]:
        objects.extend(
            add_wheel(
                wheel_id,
                wheel_positions[wheel_id],
                radius,
                width,
                int(lod["wheel_segments"]),
                wheel_material,
                bool(lod["hub"]),
            )
        )
    return objects


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

    bpy.ops.wm.read_factory_settings(use_empty=True)

    outputs = []
    for lod in spec["lods"]:
        objects = build_mesh_lod(spec, lod)
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
