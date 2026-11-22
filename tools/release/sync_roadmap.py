#!/usr/bin/env python3
"""Generate docs/roadmap-data.json from the canonical ROADMAP.md tables."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from collections import Counter
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
ROADMAP = ROOT / "ROADMAP.md"
OUTPUT = ROOT / "docs" / "roadmap-data.json"
VERSION_FILE = ROOT / "VERSION"

PHASE_RE = re.compile(r"^## Fase (\d+) — (.+?)\s*$")
ROW_RE = re.compile(
    r"^\|\s*\*\*(\d+)\.(\d+)\*\*\s*\|\s*`(v[0-9]+\.[0-9]+\.[0-9]+)`\s*\|\s*\*\*(DS-R|DS-S|MiMo Pro|MiMo Flash)\*\*\s*\|\s*(.*?)\s*\|\s*(Pendiente|En curso|Completada)\s*\|\s*$"
)

STATUS_MAP = {
    "Pendiente": "pending",
    "En curso": "in_progress",
    "Completada": "completed",
}
MODEL_MAP = {
    "DS-R": "DeepSeek V4.1 Flash 1017 · Razonamiento",
    "DS-S": "DeepSeek V4.1 Flash 1017 · Estándar",
    "MiMo Pro": "MiMo-V2.6-Pro",
    "MiMo Flash": "MiMo-V2.6-Flash",
}


def parse_metadata(text: str) -> dict[str, str]:
    def find(pattern: str, default: str = "") -> str:
        match = re.search(pattern, text)
        return match.group(1).strip() if match else default

    return {
        "current_version": find(r"\*\*Versión actual:\*\*\s*`([^`]+)`"),
        "current_subphase": find(r"\*\*Subfase actual:\*\*\s*\*\*([0-9.]+)"),
        "global_status": find(r"\*\*Estado global:\*\*\s*([^\n]+)"),
    }


def parse_roadmap() -> dict[str, Any]:
    if not ROADMAP.exists():
        raise FileNotFoundError(ROADMAP)
    text = ROADMAP.read_text(encoding="utf-8")
    metadata = parse_metadata(text)
    phases: list[dict[str, Any]] = []
    current_phase: dict[str, Any] | None = None

    for line in text.splitlines():
        phase_match = PHASE_RE.match(line.strip())
        if phase_match:
            current_phase = {
                "id": int(phase_match.group(1)),
                "key": f"phase-{int(phase_match.group(1)):02d}",
                "title": phase_match.group(2).strip(),
                "subphases": [],
            }
            phases.append(current_phase)
            continue
        row_match = ROW_RE.match(line.strip())
        if row_match and current_phase is not None:
            phase_id, _sub_index, version, model, summary, status = row_match.groups()
            current_phase["subphases"].append(
                {
                    "id": f"{phase_id}.{_sub_index}",
                    "version": version,
                    "model": model,
                    "model_label": MODEL_MAP[model],
                    "summary": summary.strip(),
                    "status": STATUS_MAP[status],
                    "status_label": status,
                }
            )

    if not phases:
        raise ValueError("No se encontró ninguna fase en ROADMAP.md")
    if len(phases) != 10:
        raise ValueError(f"Se esperaban 10 fases; se encontraron {len(phases)}")

    all_subphases: list[dict[str, Any]] = []
    for phase in phases:
        if not phase["subphases"]:
            raise ValueError(f"La fase {phase['id']} no tiene subfases")
        phase["version_range"] = f"{phase['subphases'][0]['version']} → {phase['subphases'][-1]['version']}"
        counts = Counter(sub["status"] for sub in phase["subphases"])
        if counts.get("completed") == len(phase["subphases"]):
            phase_status = "completed"
        elif counts.get("in_progress", 0) > 0 or counts.get("completed", 0) > 0:
            phase_status = "in_progress"
        else:
            phase_status = "pending"
        phase["status"] = phase_status
        phase["status_label"] = {
            "completed": "Completada",
            "in_progress": "En curso",
            "pending": "Pendiente",
        }[phase_status]
        phase["progress"] = {
            "completed": counts.get("completed", 0),
            "in_progress": counts.get("in_progress", 0),
            "pending": counts.get("pending", 0),
            "total": len(phase["subphases"]),
        }
        all_subphases.extend(phase["subphases"])

    counts = Counter(sub["status"] for sub in all_subphases)
    total = len(all_subphases)
    version_from_file = VERSION_FILE.read_text(encoding="utf-8").strip() if VERSION_FILE.exists() else ""
    generated = {
        "project": "Ruta Nocturna: 1999",
        "repository": "emanuelindustri-source/ruta-nocturna-1999",
        "generated_from": "ROADMAP.md",
        "source_sha256": hashlib.sha256(text.encode("utf-8")).hexdigest(),
        "current_version": metadata["current_version"] or f"v{version_from_file}",
        "version_file": version_from_file,
        "current_subphase": metadata["current_subphase"],
        "global_status": metadata["global_status"],
        "models": MODEL_MAP,
        "summary": {
            "completed": counts.get("completed", 0),
            "in_progress": counts.get("in_progress", 0),
            "pending": counts.get("pending", 0),
            "total": total,
            "percent": round((counts.get("completed", 0) / total * 100) if total else 0, 1),
        },
        "phases": phases,
    }
    if total != 45:
        raise ValueError(f"Se esperaban 45 subfases; se encontraron {total}")
    return generated


def main() -> int:
    parser = argparse.ArgumentParser(description="Sincroniza ROADMAP.md con la web.")
    parser.add_argument("--check", action="store_true", help="Solo comprueba que el JSON está actualizado.")
    args = parser.parse_args()
    try:
        generated = parse_roadmap()
    except Exception as exc:  # noqa: BLE001
        print(f"[FAIL] No se pudo parsear ROADMAP.md: {exc}")
        return 2
    serialized = json.dumps(generated, ensure_ascii=False, indent=2) + "\n"
    if args.check:
        if not OUTPUT.exists():
            print(f"[FAIL] Falta {OUTPUT.relative_to(ROOT)}. Ejecuta sin --check.")
            return 1
        current = OUTPUT.read_text(encoding="utf-8")
        if current != serialized:
            print("[FAIL] docs/roadmap-data.json está desincronizado con ROADMAP.md.")
            return 1
        print("[OK] Roadmap sincronizado.")
        return 0
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(serialized, encoding="utf-8")
    summary = generated["summary"]
    print(
        f"[OK] {OUTPUT.relative_to(ROOT)} actualizado: "
        f"{summary['completed']}/{summary['total']} completadas ({summary['percent']}%)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
