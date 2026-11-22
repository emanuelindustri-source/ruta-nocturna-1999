#!/usr/bin/env python3
"""Validate generated asset manifests and their outputs.

Checks, for every manifest in `assets/manifests/`:

1. Required manifest metadata: command, script/spec hashes, author, license,
   UTC timestamp and Blender version.
2. Reproducibility: the stored script and spec hashes match the files on disk,
   so a stale manifest (generator changed without rebuilding) is an error.
3. Integrity: every output exists and its SHA-256 matches the manifest.
4. LOD policy: every mesh family ships LOD0/LOD1/LOD2 exactly once, triangle
   counts are strictly decreasing and each level respects its budget.
5. Rig anchor: the anchor list matches `data/vehicle/blockout_spec.json`.

Run directly or through `tools/health_check.py`:

    .venv/Scripts/python.exe tools/validate_assets.py
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_DIR = ROOT / "assets" / "manifests"
REQUIRED_FIELDS = ["manifest_version", "asset_id", "author", "license", "created_utc", "generator", "outputs"]
REQUIRED_GENERATOR_FIELDS = ["tool", "script", "script_sha256", "spec", "spec_sha256", "blender_version", "command"]


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def validate_manifest(path: Path, errors: list[str], warnings: list[str]) -> None:
    name = path.relative_to(ROOT).as_posix()
    try:
        manifest = load_json(path)
    except Exception as exc:  # noqa: BLE001
        errors.append(f"{name}: JSON inválido: {exc}")
        return

    for field in REQUIRED_FIELDS:
        if field not in manifest:
            errors.append(f"{name}: falta el campo {field}")
    if errors:
        return
    generator = manifest["generator"]
    for field in REQUIRED_GENERATOR_FIELDS:
        if not generator.get(field):
            errors.append(f"{name}: falta generator.{field}")

    # 2. Reproducibilidad: los hashes del generador y del spec deben coincidir.
    script_path = ROOT / generator.get("script", "")
    spec_path = ROOT / generator.get("spec", "")
    if not script_path.exists():
        errors.append(f"{name}: no existe el script generador {generator.get('script')}")
    elif sha256_file(script_path) != generator.get("script_sha256"):
        errors.append(f"{name}: el script generador cambió desde la compilación; regenera con tools/blender/build_assets.cmd")
    if not spec_path.exists():
        errors.append(f"{name}: no existe la especificación {generator.get('spec')}")
    elif sha256_file(spec_path) != generator.get("spec_sha256"):
        errors.append(f"{name}: la especificación cambió desde la compilación; regenera con tools/blender/build_assets.cmd")

    outputs = manifest.get("outputs", [])
    if not outputs:
        errors.append(f"{name}: sin outputs")
        return

    # 3. Integridad de salidas.
    by_kind: dict[str, list[dict[str, Any]]] = {}
    for output in outputs:
        for field in ("file", "kind", "sha256"):
            if not output.get(field):
                errors.append(f"{name}: output sin campo {field}")
        out_path = ROOT / output.get("file", "")
        if not out_path.exists():
            errors.append(f"{name}: falta la salida {output.get('file')}")
            continue
        if sha256_file(out_path) != output.get("sha256"):
            errors.append(f"{name}: hash distinto en {output.get('file')}; regenera con tools/blender/build_assets.cmd")
        by_kind.setdefault(output["kind"], []).append(output)

    # 4. Política de LOD.
    lods = by_kind.get("mesh_lod", [])
    lod_ids = sorted(output.get("lod") for output in lods)
    if lod_ids != [0, 1, 2]:
        errors.append(f"{name}: se exigen LOD0/LOD1/LOD2; hay {lod_ids}")
    else:
        ordered = sorted(lods, key=lambda item: item["lod"])
        triangles = [output.get("triangles", 0) for output in ordered]
        if not all(triangles[i] > triangles[i + 1] for i in range(len(triangles) - 1)):
            errors.append(f"{name}: los triángulos no decrecen entre LODs: {triangles}")
        for output in ordered:
            budget = output.get("max_triangles")
            if isinstance(budget, int) and output.get("triangles", 0) > budget:
                errors.append(
                    f"{name}: LOD{output['lod']} con {output['triangles']} triángulos supera el máximo {budget}"
                )
        for output in ordered:
            if not output.get("objects"):
                errors.append(f"{name}: LOD{output['lod']} sin lista de objetos")

    # 5. Ancla de rig.
    anchors_outputs = by_kind.get("rig_anchor", [])
    if not anchors_outputs:
        errors.append(f"{name}: falta la salida de tipo rig_anchor")
    for output in anchors_outputs:
        anchor_names = output.get("anchors", [])
        if "anchor_root" not in anchor_names:
            errors.append(f"{name}: el ancla de rig no contiene anchor_root")
        if len(anchor_names) != len(set(anchor_names)):
            errors.append(f"{name}: anclas duplicadas en rig_anchor")
        if output.get("anchor_mode") not in ("armature", "empties"):
            errors.append(f"{name}: anchor_mode inválido: {output.get('anchor_mode')}")
        if spec_path.exists():
            spec = load_json(spec_path)
            expected = [anchor["id"] for anchor in spec.get("rig_anchor", {}).get("anchors", [])]
            if sorted(anchor_names) != sorted(expected):
                missing = sorted(set(expected) - set(anchor_names))
                extra = sorted(set(anchor_names) - set(expected))
                errors.append(f"{name}: anclas que no coinciden con el spec; faltan {missing}, sobran {extra}")


def validate_spec(spec_path: Path, errors: list[str]) -> None:
    """Invariantes del bloqueo independientes de los manifiestos."""
    if not spec_path.exists():
        errors.append(f"Falta {spec_path.relative_to(ROOT)}")
        return
    spec = load_json(spec_path)
    dims = spec["dimensions"]
    tolerance = float(spec.get("validation_rules", {}).get("tolerance_m", 0.02))
    total = dims["wheelbase_m"] + dims["front_overhang_m"] + dims["rear_overhang_m"]
    if abs(total - dims["length_m"]) > tolerance:
        errors.append(
            f"blockout_spec: batalla + voladizos ({total}) no coincide con el largo ({dims['length_m']})"
        )
    bounds_x = dims["width_m"] / 2.0
    for mass in spec["masses"]:
        min_m, max_m = mass["min_m"], mass["max_m"]
        if min_m[0] < -bounds_x - tolerance or max_m[0] > bounds_x + tolerance:
            errors.append(f"blockout_spec: la masa {mass['id']} excede el ancho")
        if min_m[1] < 0.0 or max_m[1] > dims["height_m"] + tolerance:
            errors.append(f"blockout_spec: la masa {mass['id']} excede la altura")
        if min_m[2] < -dims["length_m"] / 2.0 - tolerance or max_m[2] > dims["length_m"] / 2.0 + tolerance:
            errors.append(f"blockout_spec: la masa {mass['id']} excede el largo")
        if min_m[0] >= max_m[0] or min_m[1] >= max_m[1] or min_m[2] >= max_m[2]:
            errors.append(f"blockout_spec: la masa {mass['id']} tiene bounds invertidos")

    anchor_ids = [anchor["id"] for anchor in spec["rig_anchor"]["anchors"]]
    if len(anchor_ids) != len(set(anchor_ids)):
        errors.append("blockout_spec: IDs de ancla duplicados")
    for anchor in spec["rig_anchor"]["anchors"]:
        if not anchor["id"].startswith("anchor_"):
            errors.append(f"blockout_spec: ancla sin prefijo anchor_: {anchor['id']}")
        x, y, z = anchor["position_m"]
        bounds = spec["validation_rules"]["anchor_bounds_m"]
        if abs(x) > bounds["x"] or not (bounds["y_min"] <= y <= bounds["y_max"]) or abs(z) > bounds["z"]:
            errors.append(f"blockout_spec: posición de ancla fuera de rango: {anchor['id']}")
    if spec["rig_anchor"]["root_bone"] not in anchor_ids:
        errors.append("blockout_spec: root_bone no está entre las anclas")

    lods = spec["lods"]
    lod_numbers = [int(lod["id"].replace("lod", "")) for lod in lods]
    if sorted(lod_numbers) != [0, 1, 2]:
        errors.append(f"blockout_spec: el spec debe declarar LOD0/LOD1/LOD2; hay {lod_numbers}")
    budgets = [lod["max_triangles"] for lod in sorted(lods, key=lambda item: item["id"])]
    if not all(budgets[i] > budgets[i + 1] for i in range(len(budgets) - 1)):
        errors.append(f"blockout_spec: presupuestos de LOD no decrecientes: {budgets}")


def validate() -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    validate_spec(ROOT / "data" / "vehicle" / "blockout_spec.json", errors)
    if not MANIFEST_DIR.exists():
        errors.append("Falta assets/manifests/")
        return errors, warnings
    manifests = sorted(MANIFEST_DIR.glob("*.manifest.json"))
    if not manifests:
        errors.append("No hay manifiestos de assets generados")
    for manifest in manifests:
        validate_manifest(manifest, errors, warnings)
    return errors, warnings


def main() -> int:
    parser = argparse.ArgumentParser(description="Valida manifiestos de assets generados.")
    parser.parse_args()
    errors, warnings = validate()
    for warning in warnings:
        print(f"[WARN] {warning}")
    for error in errors:
        print(f"[FAIL] {error}")
    if errors:
        print(f"\n[FAIL] {len(errors)} errores en los assets generados.")
        return 1
    print("[OK] Manifiestos de assets válidos.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
