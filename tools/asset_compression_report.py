#!/usr/bin/env python3
"""Reporte de compresion de assets y tamano de build (F3.5).

Revisa las banderas de compresion del proyecto y de los presets, inventaria
las texturas y mallas importadas con su configuracion, y resume el tamano de
los artefactos exportados. Escribe `build/logs/compression/latest.json`.

Uso:
    .venv/Scripts/python.exe tools/asset_compression_report.py
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
REPORT_DIR = ROOT / "build" / "logs" / "compression"
TEXTURE_SUFFIXES = {".svg", ".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tga"}
MESH_SUFFIXES = {".glb", ".gltf", ".obj"}
IMPORT_MODES = {
    "0": "lossless",
    "1": "lossy",
    "2": "vram",
    "3": "basis_universal",
}


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def parse_ini(path: Path) -> dict[str, dict[str, str]]:
    """Parseo minimo del formato .import/.cfg de Godot."""
    sections: dict[str, dict[str, str]] = {}
    current = ""
    if not path.exists():
        return sections
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith(";"):
            continue
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1]
            sections.setdefault(current, {})
            continue
        if "=" in line and current:
            key, value = line.split("=", 1)
            value = value.strip()
            if len(value) >= 2 and value.startswith('"') and value.endswith('"'):
                value = value[1:-1]
            sections[current][key.strip()] = value
    return sections


def read_project_flags() -> dict[str, Any]:
    text = (ROOT / "project.godot").read_text(encoding="utf-8")
    return {
        "import_etc2_astc": "textures/vram_compression/import_etc2_astc=true" in text,
    }


def read_preset_flags() -> dict[str, Any]:
    sections = parse_ini(ROOT / "export_presets.cfg")
    result: dict[str, Any] = {}
    for name, values in sections.items():
        if not re.fullmatch(r"preset\.\d+", name) or "platform" not in values:
            continue
        options = sections.get(f"{name}.options", {})
        result[values["platform"]] = {
            "s3tc_bptc": options.get("texture_format/s3tc_bptc"),
            "etc2_astc": options.get("texture_format/etc2_astc"),
        }
    return result


def scan_assets() -> dict[str, Any]:
    textures: list[dict[str, Any]] = []
    meshes: list[dict[str, Any]] = []
    missing_imports: list[str] = []
    for source in sorted((ROOT / "assets").rglob("*")):
        if not source.is_file() or source.suffix.lower() not in TEXTURE_SUFFIXES | MESH_SUFFIXES:
            continue
        rel = source.relative_to(ROOT).as_posix()
        import_path = Path(str(source) + ".import")
        entry: dict[str, Any] = {
            "path": rel,
            "source_bytes": source.stat().st_size,
            "has_import": import_path.exists(),
        }
        if not import_path.exists():
            missing_imports.append(rel)
            (textures if source.suffix.lower() in TEXTURE_SUFFIXES else meshes).append(entry)
            continue
        params = parse_ini(import_path).get("params", {})
        deps = parse_ini(import_path).get("deps", {})
        imported_bytes = 0
        for dest in re.findall(r'"([^"]+)"', deps.get("dest_files", "[]")):
            dest_path = ROOT / dest.removeprefix("res://")
            if dest_path.exists():
                imported_bytes += dest_path.stat().st_size
        entry["imported_bytes"] = imported_bytes
        if source.suffix.lower() in TEXTURE_SUFFIXES:
            entry["compress_mode"] = IMPORT_MODES.get(
                params.get("compress/mode", ""), params.get("compress/mode", "")
            )
            entry["compress_to_3d"] = params.get("detect_3d/compress_to", "")
            textures.append(entry)
        else:
            entry["generate_lods"] = params.get("meshes/generate_lods", "")
            entry["mesh_compression_disabled"] = params.get(
                "meshes/force_disable_compression", ""
            )
            meshes.append(entry)
    return {
        "textures": textures,
        "meshes": meshes,
        "missing_imports": missing_imports,
    }


def imported_totals() -> dict[str, Any]:
    imported_dir = ROOT / ".godot" / "imported"
    totals: dict[str, dict[str, int]] = {}
    if not imported_dir.exists():
        return {"by_suffix": {}, "total_bytes": 0}
    total = 0
    for item in imported_dir.rglob("*"):
        if not item.is_file() or item.suffix == ".md5":
            continue
        bucket = totals.setdefault(item.suffix, {"count": 0, "bytes": 0})
        bucket["count"] += 1
        bucket["bytes"] += item.stat().st_size
        total += item.stat().st_size
    return {
        "by_suffix": {
            suffix: {"count": data["count"], "bytes": data["bytes"]}
            for suffix, data in sorted(totals.items())
        },
        "total_bytes": total,
    }


def export_artifacts() -> dict[str, Any]:
    artifacts = []
    exports_dir = ROOT / "build" / "exports"
    if exports_dir.exists():
        for item in sorted(exports_dir.rglob("*")):
            if item.is_file():
                artifacts.append({
                    "path": item.relative_to(ROOT).as_posix(),
                    "bytes": item.stat().st_size,
                })
    manifest_path = ROOT / "build" / "logs" / "export" / "latest.json"
    manifest = None
    if manifest_path.exists():
        try:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            manifest = {"error": "manifest_invalid"}
    return {"artifacts": artifacts, "export_manifest": manifest}


def validate(flags: dict[str, Any], assets: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if not flags["project"]["import_etc2_astc"]:
        errors.append("project.godot: textures/vram_compression/import_etc2_astc debe ser true")
    windows = flags["presets"].get("Windows Desktop", {})
    android = flags["presets"].get("Android", {})
    if windows.get("s3tc_bptc") != "true":
        errors.append("preset Windows: texture_format/s3tc_bptc debe ser true")
    if android.get("etc2_astc") not in (None, "true"):
        errors.append("preset Android: texture_format/etc2_astc debe ser true")
    for missing in assets["missing_imports"]:
        errors.append(f"asset sin .import: {missing}")
    for mesh in assets["meshes"]:
        if mesh.get("generate_lods") != "true":
            errors.append(f"malla sin meshes/generate_lods: {mesh['path']}")
        if mesh.get("mesh_compression_disabled") == "true":
            errors.append(f"malla con compresion desactivada: {mesh['path']}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Reporte de compresion de assets y build.")
    parser.parse_args()

    flags = {"project": read_project_flags(), "presets": read_preset_flags()}
    assets = scan_assets()
    imported = imported_totals()
    artifacts = export_artifacts()
    errors = validate(flags, assets)

    texture_bytes = sum(entry.get("imported_bytes", 0) for entry in assets["textures"])
    mesh_bytes = sum(entry.get("imported_bytes", 0) for entry in assets["meshes"])
    report = {
        "generated_utc": utc_now(),
        "flags": flags,
        "assets": assets,
        "imported": imported,
        "totals": {
            "texture_sources": len(assets["textures"]),
            "texture_imported_bytes": texture_bytes,
            "mesh_sources": len(assets["meshes"]),
            "mesh_imported_bytes": mesh_bytes,
            "imported_total_bytes": imported["total_bytes"],
        },
        "artifacts": artifacts,
        "errors": errors,
        "success": not errors,
    }

    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    (REPORT_DIR / "latest.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    print("[COMPRESSION] etc2_astc_import=%s windows_s3tc=%s android_etc2=%s" % (
        flags["project"]["import_etc2_astc"],
        flags["presets"].get("Windows Desktop", {}).get("s3tc_bptc"),
        flags["presets"].get("Android", {}).get("etc2_astc"),
    ))
    print(
        "[COMPRESSION] texturas=%d (%d B importadas) mallas=%d (%d B importadas) .godot/imported=%d B"
        % (
            len(assets["textures"]), texture_bytes, len(assets["meshes"]), mesh_bytes,
            imported["total_bytes"],
        )
    )
    for suffix, data in imported["by_suffix"].items():
        print("[COMPRESSION]   %s: %d archivos, %d B" % (suffix, data["count"], data["bytes"]))
    for artifact in artifacts["artifacts"]:
        print("[COMPRESSION] artefacto %s: %d bytes" % (artifact["path"], artifact["bytes"]))
    if not artifacts["artifacts"]:
        print("[COMPRESSION] sin artefactos exportados (ejecuta tools/dev/export.cmd primero)")
    for error in errors:
        print("[COMPRESSION][FAIL] %s" % error)
    if errors:
        print("[COMPRESSION] FAIL (%d errores)" % len(errors))
        return 1
    print("[COMPRESSION] OK; informe en build/logs/compression/latest.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
