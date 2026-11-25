#!/usr/bin/env python3
"""World POI / road furniture kit factory (F4.3, bpy headless).

Builds one kit family from `data/world/kits_spec.json` and exports LOD0/LOD1/LOD2
plus the root anchor as GLB files. Run through `tools/blender/build_assets.py`:

    blender --background --factory-startup --python tools/blender/world_kits.py -- \
        --spec data/world/kits_spec.json --output-dir assets/generated/world \
        --report build/logs/blender/<kit>_report.json --anchor-mode empties \
        --kit poi.kit_gasolinera

Rules honored by this generator:

- No real brands, no burned-in text, no external textures: panels are blank
  geometry and materials are procedural Principled BSDF colors.
- Every part is declared in the spec; the script only parametrizes LOD detail
  (bevel/cylinder segments and which parts are present per LOD).
- A part with `lod_min = N` is present in LOD0..LODN (higher LOD index = lower
  detail), so triangle counts strictly decrease along the chain.
- The script only writes to the output directory and the report path.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import bpy


def parse_args() -> argparse.Namespace:
    argv = sys.argv
    args = argv[argv.index("--") + 1 :] if "--" in argv else []
    parser = argparse.ArgumentParser(description="World kit factory")
    parser.add_argument("--spec", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--anchor-mode", default="empties", choices=["armature", "empties"])
    parser.add_argument("--kit", required=True, help="kit_id del kits_spec.json")
    return parser.parse_args(args)


def to_blender(position: tuple[float, float, float]) -> tuple[float, float, float]:
    """Engine (x right, y up, z rear) to Blender (x, -z, y); export_yup maps back."""
    x, y, z = position
    return (x, -z, y)


def clear_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def get_material(name: str, spec: dict):
    entry = spec["materials"][name]
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    color = entry["base_color"]
    bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    bsdf.inputs["Roughness"].default_value = float(entry.get("roughness", 0.8))
    bsdf.inputs["Metallic"].default_value = float(entry.get("metallic", 0.0))
    if "emission" in entry:
        emission = entry["emission"]
        bsdf.inputs["Emission Color"].default_value = (emission[0], emission[1], emission[2], 1.0)
        bsdf.inputs["Emission Strength"].default_value = float(entry.get("emission_energy", 1.0))
    return material


def add_box(name: str, min_m, max_m, material, bevel_segments: int):
    center = tuple((min_m[i] + max_m[i]) / 2.0 for i in range(3))
    half = tuple((max_m[i] - min_m[i]) / 2.0 for i in range(3))
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=to_blender(center))
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (half[0] * 2.0, half[2] * 2.0, half[1] * 2.0)
    bpy.ops.object.transform_apply(scale=True)
    if bevel_segments > 0:
        modifier = obj.modifiers.new("bevel", "BEVEL")
        modifier.width = 0.02
        modifier.segments = bevel_segments
        modifier.limit_method = "ANGLE"
    obj.data.materials.append(material)
    return obj


def add_cylinder(name: str, center_m, radius_m: float, height_m: float, material, segments: int):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=max(3, segments),
        radius=radius_m,
        depth=height_m,
        location=to_blender(tuple(center_m)),
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(material)
    return obj


def mesh_stats(objects) -> tuple[int, int]:
    triangles = 0
    vertices = 0
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in objects:
        if obj.type != "MESH":
            continue
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        triangles += len(mesh.loop_triangles)
        vertices += len(mesh.vertices)
        evaluated.to_mesh_clear()
    return triangles, vertices


def build_mesh_lod(kit: dict, spec: dict, lod: dict):
    clear_scene()
    bevel_segments = int(lod.get("bevel_segments", 0))
    segments = int(lod.get("segments", 8))
    lod_index = int(lod["id"].replace("lod", ""))
    objects = []
    materials = {}
    for part in kit["parts"]:
        if int(part.get("lod_min", 0)) < lod_index:
            continue
        material_name = part["material"]
        if material_name not in materials:
            materials[material_name] = get_material(material_name, spec)
        material = materials[material_name]
        if part["kind"] == "box":
            objects.append(
                add_box(part["name"], part["min_m"], part["max_m"], material, bevel_segments)
            )
        elif part["kind"] == "cylinder":
            objects.append(
                add_cylinder(
                    part["name"],
                    part["center_m"],
                    float(part["radius_m"]),
                    float(part["height_m"]),
                    material,
                    segments,
                )
            )
        else:
            raise ValueError(f"Tipo de pieza desconocido: {part['kind']}")
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

    kit = next((entry for entry in spec["kits"] if entry["kit_id"] == args.kit), None)
    if kit is None:
        raise SystemExit(f"[FAIL] kit desconocido: {args.kit}")

    bpy.ops.wm.read_factory_settings(use_empty=True)

    outputs = []
    for lod in kit["lods"]:
        objects = build_mesh_lod(kit, spec, lod)
        triangles, vertices = mesh_stats(objects)
        if triangles > int(lod["max_triangles"]):
            raise SystemExit(
                f"[FAIL] {kit['kit_id']} {lod['id']}: {triangles} triángulos superan el máximo {lod['max_triangles']}"
            )
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
    anchor_path = output_dir / Path(kit["anchor_output"]).name
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
        "asset_id": kit["asset_id"],
        "kit_id": kit["kit_id"],
        "spec_file": str(spec_path),
        "blender_version": bpy.app.version_string,
        "anchor_mode": args.anchor_mode,
        "outputs": outputs,
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"[FACTORY] Reporte escrito en {report_path}")
    for output in outputs:
        print(f"[FACTORY] {output['file']}: {output.get('triangles', 0)} triangulos")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
