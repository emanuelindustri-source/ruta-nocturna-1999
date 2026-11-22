#!/usr/bin/env python3
"""Headless Blender asset factory for Ruta Nocturna: 1999.

Runs the parametric `bpy` generators inside Blender (background mode) and
writes a reproducible manifest for every generated asset family:

- exact command line used to build the asset,
- SHA-256 of the generator script, the spec and every output,
- author, license and UTC timestamp,
- measured triangle/vertex counts and LOD coverage.

Usage (project venv):

    .venv/Scripts/python.exe tools/blender/build_assets.py
    tools/blender/build_assets.cmd

The factory never copies anything from the external reference library and
never edits `.blend` files by hand.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
BLENDER = Path(r"C:\Program Files\Blender Foundation\Blender 4.5\blender.exe")
MANIFEST_DIR = ROOT / "assets" / "manifests"
REPORT_DIR = ROOT / "build" / "logs" / "blender"

AUTHOR = "Ruta Nocturna 1999 - asset factory (modelado parametrico, MiMo-V2.6-Pro)"
LICENSE = "CC BY-NC-SA 4.0 (arte 3D propio del proyecto). Ver ASSET_LICENSE.md. Sin texturas ni mallas de terceros."

TARGETS = [
    {
        "asset_id": "vehicle.esteem.blockout",
        "script": "tools/blender/esteem_blockout.py",
        "spec": "data/vehicle/blockout_spec.json",
        "manifest": "assets/manifests/esteem_blockout.manifest.json",
        "anchor_mode": "armature",
    },
]


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def build_target(target: dict[str, Any], blender: Path) -> dict[str, Any]:
    script_path = ROOT / target["script"]
    spec_path = ROOT / target["spec"]
    output_dir = ROOT / "assets" / "generated" / "vehicle"
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    report_path = REPORT_DIR / f"{target['asset_id'].replace('.', '_')}_report.json"

    command = [
        str(blender),
        "--background",
        "--factory-startup",
        "--python",
        str(script_path),
        "--",
        "--spec",
        str(spec_path),
        "--output-dir",
        str(output_dir),
        "--report",
        str(report_path),
        "--anchor-mode",
        target.get("anchor_mode", "armature"),
    ]
    print(f"[FACTORY] Ejecutando: {' '.join(command)}")
    completed = subprocess.run(
        command,
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=600,
        check=False,
    )
    if completed.returncode != 0:
        sys.stderr.write(completed.stdout)
        sys.stderr.write(completed.stderr)
        raise RuntimeError(f"Blender devolvio exit {completed.returncode} para {target['asset_id']}")
    if not report_path.exists():
        raise RuntimeError(f"Blender no escribio el reporte {report_path}")
    report = json.loads(report_path.read_text(encoding="utf-8"))

    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    outputs = []
    for entry in report["outputs"]:
        out_path = output_dir / entry["file"]
        if not out_path.exists():
            raise RuntimeError(f"No se genero la salida {out_path}")
        record = dict(entry)
        record["file"] = f"assets/generated/vehicle/{entry['file']}"
        record["size_bytes"] = out_path.stat().st_size
        record["sha256"] = sha256_file(out_path)
        outputs.append(record)

    manifest = {
        "manifest_version": 1,
        "asset_id": target["asset_id"],
        "content_status": spec.get("content_status", "generated"),
        "author": AUTHOR,
        "license": LICENSE,
        "created_utc": utc_now(),
        "generator": {
            "tool": "tools/blender/build_assets.py",
            "script": target["script"],
            "script_sha256": sha256_file(script_path),
            "spec": target["spec"],
            "spec_sha256": sha256_file(spec_path),
            "blender_version": report.get("blender_version", ""),
            "blender_path": str(blender),
            "command": " ".join(command),
            "reproducible": True,
        },
        "reference_notes": spec.get("reference_notes", []),
        "outputs": outputs,
    }
    manifest_path = ROOT / target["manifest"]
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"[FACTORY] Manifiesto escrito en {manifest_path.relative_to(ROOT)}")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description="Fábrica de assets Blender headless.")
    parser.add_argument("--blender", default=str(BLENDER), help="Ruta de blender.exe.")
    parser.add_argument("--target", default="", help="asset_id concreto; por defecto todos.")
    args = parser.parse_args()

    blender = Path(args.blender)
    if not blender.exists():
        print(f"[FAIL] Blender no disponible en {blender}")
        return 2

    selected = [t for t in TARGETS if not args.target or t["asset_id"] == args.target]
    if not selected:
        print(f"[FAIL] Objetivo desconocido: {args.target}")
        return 2

    version = subprocess.run(
        [str(blender), "--version"], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=60
    )
    first_line = (version.stdout or "").splitlines()[0] if version.stdout else ""
    print(f"[FACTORY] {first_line}")

    for target in selected:
        try:
            manifest = build_target(target, blender)
        except Exception as exc:  # noqa: BLE001
            print(f"[FAIL] {target['asset_id']}: {exc}")
            return 1
        for output in manifest["outputs"]:
            kind = output["kind"]
            detail = (
                f"{output['triangles']} triangulos (max {output.get('max_triangles', '-')})"
                if kind == "mesh_lod"
                else f"{len(output.get('anchors', []))} anclas"
            )
            print(f"[FACTORY]   {output['file']} [{kind}] {detail}")

    print("[OK] Fábrica completada.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
