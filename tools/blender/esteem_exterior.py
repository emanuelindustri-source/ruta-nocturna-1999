"""Esteem exterior factory script for Blender (headless).

Reproducible parametric exterior of the Esteem 1999: separated body pieces
(hood, trunk lid, doors, bumpers, moldings, grille), headlights with amber
indicators, tail lights, mirrors, steel wheels with hubcaps, antenna, fuel
door, wipers and dark glass panels, with PBR materials and LOD0/LOD1/LOD2.
It is executed by `tools/blender/build_assets.py` inside Blender:

    blender.exe --background --factory-startup --python tools/blender/esteem_exterior.py -- \
        --spec <spec.json> --output-dir <dir> --report <report.json> [--anchor-mode armature|empties]

Rules:
- Everything is generated from `data/vehicle/exterior_spec.json`. No manual
  `.blend` editing, no external meshes, no reference textures.
- Coordinates in the spec are engine coordinates (Godot: Y up, forward -Z,
  right +X). They are converted to Blender coordinates (Z up, front +Y) here
  and exported with the standard +Y-up glTF conversion.
- No brand emblems, badges or visible text: grille, plates and panels stay
  plain. Nothing is copied from the external reference library.
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
    parser = argparse.ArgumentParser(description="Esteem exterior factory")
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


def rotation_to_blender(rotation_deg: tuple[float, float, float]) -> tuple[float, float, float]:
    """Engine rotation (about X, Y, Z) -> Blender rotation (about X, Y, Z).

    The axis mapping (x, y, z) -> (x, -z, y) is a +90 degree rotation about X,
    so X rotations keep their angle, Y->Z keeps its angle and Z->Y flips it.
    """
    rx, ry, rz = rotation_deg
    return (math.radians(rx), math.radians(-rz), math.radians(ry))


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


def add_box(piece: dict, material, bevel_width: float, bevel_segments: int):
    """Engine-space AABB box, optionally rotated about its own center."""
    min_m = tuple(piece["min_m"])
    max_m = tuple(piece["max_m"])
    center_e = tuple((min_m[i] + max_m[i]) / 2.0 for i in range(3))
    half_e = tuple(abs(max_m[i] - min_m[i]) / 2.0 for i in range(3))
    center = to_blender(center_e)
    # Engine X and Blender X share the axis, so half extents map as (x, z, y).
    half = (half_e[0], half_e[2], half_e[1])
    rotation = rotation_to_blender(tuple(piece.get("rotation_deg", (0.0, 0.0, 0.0))))
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=center, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = piece["id"]
    obj.scale = half
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if bevel_width > 0.0 and bevel_segments > 0:
        modifier = obj.modifiers.new("Bevel", "BEVEL")
        modifier.width = bevel_width
        modifier.segments = bevel_segments
        modifier.limit_method = "ANGLE"
        modifier.angle_limit = math.radians(40.0)
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.append(material)
    return obj


def add_loft(name: str, rings_engine, material):
    """Closed loft from engine-space rings (equal point counts), capped."""
    rings = [[to_blender(tuple(point)) for point in ring] for ring in rings_engine]
    verts = [point for ring in rings for point in ring]
    count = len(rings[0])
    faces = []
    for s in range(len(rings) - 1):
        base = s * count
        nxt = (s + 1) * count
        for i in range(count):
            j = (i + 1) % count
            faces.append((base + i, base + j, nxt + j, nxt + i))
    faces.append(tuple(reversed(range(0, count))))
    last = (len(rings) - 1) * count
    faces.append(tuple(last + i for i in range(count)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(material)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    try:
        bpy.ops.object.shade_auto_smooth(angle=math.radians(38.0))
    except Exception:  # noqa: BLE001
        bpy.ops.object.shade_smooth()
    obj.select_set(False)
    return obj


def add_panel(panel: dict, material):
    """Thin closed prism from four engine-space corners and a thickness."""
    corners = [to_blender(tuple(point)) for point in panel["corners_m"]]
    a, b, c, d = corners
    # Outward normal from the corner winding (base-left -> base-right -> top-right -> top-left).
    ux, uy, uz = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
    vx, vy, vz = (d[0] - a[0], d[1] - a[1], d[2] - a[2])
    nx, ny, nz = (uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx)
    length = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
    t = float(panel.get("thickness_m", 0.01)) / 2.0
    offset = (nx / length * t, ny / length * t, nz / length * t)
    front = [a, b, c, d]
    back = [(p[0] - offset[0], p[1] - offset[1], p[2] - offset[2]) for p in front]
    front = [(p[0] + offset[0], p[1] + offset[1], p[2] + offset[2]) for p in front]
    verts = front + back
    faces = [
        (0, 1, 2, 3),
        (7, 6, 5, 4),
        (0, 4, 5, 1),
        (1, 5, 6, 2),
        (2, 6, 7, 3),
        (3, 7, 4, 0),
    ]
    mesh = bpy.data.meshes.new(panel["id"])
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(panel["id"], mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(material)
    return obj


def add_wheel(wheel_id: str, center_engine, radius: float, width: float, segments: int,
              materials: dict, hubcap: bool, spokes: int, outer_sign: float):
    center = to_blender(tuple(center_engine))
    made = []
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=segments,
        radius=radius,
        depth=width,
        location=center,
        rotation=(0.0, math.pi / 2.0, 0.0),
    )
    tire = bpy.context.active_object
    tire.name = wheel_id + "_tire"
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    tire.data.materials.append(materials["tire"])
    made.append(tire)

    bpy.ops.mesh.primitive_cylinder_add(
        vertices=max(8, segments // 2),
        radius=radius * 0.68,
        depth=width * 1.02,
        location=center,
        rotation=(0.0, math.pi / 2.0, 0.0),
    )
    rim = bpy.context.active_object
    rim.name = wheel_id + "_rim"
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    rim.data.materials.append(materials["rim"])
    made.append(rim)

    if hubcap:
        cap_center = (
            center[0] + outer_sign * width * 0.30,
            center[1],
            center[2],
        )
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=max(8, segments // 2),
            radius=radius * 0.55,
            depth=width * 0.22,
            location=cap_center,
            rotation=(0.0, math.pi / 2.0, 0.0),
        )
        cap = bpy.context.active_object
        cap.name = wheel_id + "_hubcap"
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
        cap.data.materials.append(materials["hubcap"])
        made.append(cap)

        for spoke in range(max(0, spokes)):
            angle = 2.0 * math.pi * spoke / max(1, spokes)
            bpy.ops.mesh.primitive_cube_add(
                size=1.0,
                location=(
                    cap_center[0] + outer_sign * width * 0.12,
                    center[1] + math.cos(angle) * radius * 0.30,
                    center[2] + math.sin(angle) * radius * 0.30,
                ),
                rotation=(angle, 0.0, 0.0),
            )
            spoke_obj = bpy.context.active_object
            spoke_obj.name = "%s_spoke%d" % (wheel_id, spoke)
            spoke_obj.scale = (width * 0.10, radius * 0.10, radius * 0.42)
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
            spoke_obj.data.materials.append(materials["hubcap"])
            made.append(spoke_obj)
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

def body_rings(sections: list[dict], step: int) -> list[list[tuple[float, float, float]]]:
    selected = sections[:: max(1, step)]
    if selected[-1] is not sections[-1]:
        selected.append(sections[-1])
    rings = []
    for section in selected:
        z = float(section["z_m"])
        w = float(section["half_width_m"])
        bottom = float(section["bottom_m"])
        shoulder = float(section["shoulder_m"])
        crown = float(section["crown_m"])
        ring = [
            (-w, bottom, z),
            (-w, shoulder, z),
            (-w * 0.94, crown, z),
            (w * 0.94, crown, z),
            (w, shoulder, z),
            (w, bottom, z),
        ]
        rings.append(ring)
    return rings


def canopy_rings(sections: list[dict], step: int) -> list[list[tuple[float, float, float]]]:
    selected = sections[:: max(1, step)]
    if selected[-1] is not sections[-1]:
        selected.append(sections[-1])
    rings = []
    for section in selected:
        z = float(section["z_m"])
        w = float(section["half_width_m"])
        sill = float(section["sill_m"])
        top = float(section["top_m"])
        ring = [
            (-w, sill, z),
            (-w * 0.86, top, z),
            (w * 0.86, top, z),
            (w, sill, z),
        ]
        rings.append(ring)
    return rings


def build_mesh_lod(spec: dict, lod: dict):
    clear_scene()
    wanted = set(lod.get("features", []))
    full_detail = str(lod.get("detail", "")) == "full"
    bevel_width = float(lod["bevel_width_m"])
    bevel_segments = int(lod["bevel_segments"])
    objects = []

    body = spec["body_shell"]
    objects.append(add_loft("body_shell", body_rings(body["sections"], int(lod["section_step"])), get_material(body["material"], spec)))
    canopy = spec["canopy"]
    objects.append(add_loft("canopy", canopy_rings(canopy["sections"], int(lod["section_step"])), get_material(canopy["material"], spec)))

    for piece in spec["pieces"]:
        if not any(feature in wanted for feature in piece.get("features", [])):
            continue
        material = get_material(piece["material"], spec)
        objects.append(add_box(piece, material, bevel_width, bevel_segments))
        if piece.get("slats") and full_detail:
            for slat in range(int(piece["slats"])):
                slat_piece = {
                    "id": "%s_slat%d" % (piece["id"], slat),
                    "min_m": [
                        piece["min_m"][0] + 0.01,
                        piece["min_m"][1] + 0.03 + slat * 0.045,
                        piece["min_m"][2] - 0.012,
                    ],
                    "max_m": [
                        piece["max_m"][0] - 0.01,
                        piece["min_m"][1] + 0.052 + slat * 0.045,
                        piece["max_m"][2] + 0.012,
                    ],
                }
                objects.append(add_box(slat_piece, material, 0.0, 0))

    if "glass_panels" in wanted:
        for panel in spec["glass_panels"]:
            if not any(feature in wanted for feature in panel.get("features", [])):
                continue
            objects.append(add_panel(panel, get_material(panel["material"], spec)))

    dims = spec["base_dimensions"]
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
    wheel_materials = {
        key: get_material(name, spec) for key, name in spec["wheels"]["materials"].items()
    }
    for wheel_id in spec["wheels"]["ids"]:
        center_engine = wheel_positions[wheel_id]
        objects.extend(
            add_wheel(
                wheel_id,
                center_engine,
                radius,
                width,
                int(lod["wheel_segments"]),
                wheel_materials,
                "hubcaps" in wanted,
                int(spec["wheels"].get("hubcap_spokes", 0)) if "spokes" in wanted else 0,
                1.0 if center_engine[0] > 0 else -1.0,
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
