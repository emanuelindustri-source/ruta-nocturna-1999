#!/usr/bin/env python3
"""Generate or verify the v0.2.0 save fixture (Fase 2.4).

El envelope guardado de Ruta Nocturna usa un JSON canonico (claves ordenadas,
sin espacios) sobre el bloque `data` y un SHA-256 de ese canonico como
`checksum`. SaveManager (src/core/save_manager.gd, `_canonical_json`) es la
fuente de verdad; este script replica exactamente esas reglas para producir un
fixture versionado que sirve de linea base de migraciones desde v0.2.0
(AGENTS.md, seccion 14) y que las pruebas cargan en una ranura real.

Uso:
  .\\.venv\\Scripts\\python.exe tools\\make_save_fixture.py          # genera
  .\\.venv\\Scripts\\python.exe tools\\make_save_fixture.py --check  # verifica
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "tests" / "fixtures" / "save_v0_2_0.json"

# Snapshot de la linea base v0.2.0 (save_version 1). Solo enteros, strings y
# booleanos: evita cualquier ambiguedad de formato de flotantes entre Python y
# GDScript en el JSON canonico.
BASELINE_DATA: dict[str, Any] = {
    "snapshot_version": 1,
    "mode": "playing",
    "chapter": 1,
    "region": "carabobo",
    "mission_id": "act1_intro",
    "mission_stage": "stage_a",
    "flags": {
        "tutorial_done": True,
        "first_night": True,
    },
    "trust": {
        "pasajero_base": 55,
    },
    "humanity": 61,
    "play_time_seconds": 1450,
    "is_test_save": False,
    "rng_seed": 1999,
}


def canonical(value: Any) -> str:
    """Réplica exacta de SaveManager._canonical_json()."""
    if isinstance(value, dict):
        parts = [
            json.dumps(str(key), ensure_ascii=False) + ":" + canonical(value[key])
            for key in sorted(value.keys())
        ]
        return "{" + ",".join(parts) + "}"
    if isinstance(value, list):
        return "[" + ",".join(canonical(item) for item in value) + "]"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        if value == int(value) and abs(value) < 1.0e15:
            return str(int(value))
        return json.dumps(value)
    return json.dumps(value, ensure_ascii=False)


def checksum(data: dict[str, Any]) -> str:
    return hashlib.sha256(canonical(data).encode("utf-8")).hexdigest()


def build_envelope() -> dict[str, Any]:
    return {
        "save_version": 1,
        "game_version": "0.2.0",
        "checksum": checksum(BASELINE_DATA),
        "timestamp_utc": "2026-11-22T12:00:00Z",
        "rng_seed": int(BASELINE_DATA["rng_seed"]),
        "data": BASELINE_DATA,
    }


def write_fixture() -> int:
    FIXTURE.parent.mkdir(parents=True, exist_ok=True)
    envelope = build_envelope()
    FIXTURE.write_text(json.dumps(envelope, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"[OK] Fixture escrito: {FIXTURE.relative_to(ROOT)} checksum={envelope['checksum']}")
    return 0


def check_fixture() -> int:
    if not FIXTURE.exists():
        print(f"[FAIL] Falta {FIXTURE.relative_to(ROOT)}")
        return 1
    envelope = json.loads(FIXTURE.read_text(encoding="utf-8"))
    errors: list[str] = []
    if int(envelope.get("save_version", 0)) != 1:
        errors.append("save_version debe ser 1 (linea base v0.2.0)")
    if str(envelope.get("game_version", "")) != "0.2.0":
        errors.append("game_version debe ser 0.2.0")
    for key in ("save_version", "game_version", "checksum", "timestamp_utc", "rng_seed", "data"):
        if key not in envelope:
            errors.append(f"falta el campo {key}")
    if not errors:
        expected = checksum(envelope["data"])
        if str(envelope.get("checksum", "")) != expected:
            errors.append(f"checksum inválido: {envelope.get('checksum')} != {expected}")
    if not errors and envelope["data"] != BASELINE_DATA:
        errors.append("el bloque data difiere del snapshot documentado de v0.2.0")
    if errors:
        for error in errors:
            print(f"[FAIL] {error}")
        return 1
    print(f"[OK] Fixture v0.2.0 verificado: {envelope['checksum']}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Fixture de guardado v0.2.0.")
    parser.add_argument("--check", action="store_true", help="Solo verifica el fixture existente.")
    args = parser.parse_args()
    return check_fixture() if args.check else write_fixture()


if __name__ == "__main__":
    sys.exit(main())
