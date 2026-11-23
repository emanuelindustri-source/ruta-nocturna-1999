#!/usr/bin/env python3
"""Project health check for Ruta Nocturna: 1999.

Run at the start and end of every subphase. The check must never claim success
without inspecting the actual files, schemas and Godot import.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import re
import shutil
import subprocess
import sys
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
GODOT = Path(r"C:\Dev\Godot\Godot_v4.7.2-stable_win64_console.exe")
BLENDER = Path(r"C:\Program Files\Blender Foundation\Blender 4.5\blender.exe")
ADB = Path(r"C:\Android\platform-tools\adb.exe")
GH = Path(r"C:\Program Files\GitHub CLI\gh.exe")
KEYSTORE = Path(r"C:\Android\debug.keystore")
JAVA = Path(r"C:\Program Files\Eclipse Adoptium\jdk-17.0.21.10002-hotspot\bin\java.exe")
ANDROID_SDK = Path(r"C:\Android")
EXPORT_TEMPLATES = Path.home() / "AppData" / "Roaming" / "Godot" / "export_templates" / "4.7.2.stable"
REPORT_DIR = ROOT / "build" / "logs" / "health"

REQUIRED_FILES = [
    "AGENTS.md",
    "ROADMAP.md",
    "VERSION",
    "README.md",
    "LICENSE",
    "ASSET_LICENSE.md",
    "CREDITS.md",
    "project.godot",
    ".gitignore",
    ".gitattributes",
    "docs/index.html",
    "docs/style.css",
    "docs/app.js",
    "docs/privacy.html",
    "docs/roadmap-data.json",
    "docs/status/CURRENT.md",
    "docs/status/HANDOFF.md",
    "docs/reference/reference_catalog.json",
    "docs/reference/EXTERNAL_REFERENCE_LIBRARY.md",
    "docs/reference/REFERENCE_USAGE_LOG.md",
    "docs/architecture/SYSTEM_ARCHITECTURE.md",
    "docs/architecture/STATE_MACHINES.md",
    "docs/architecture/DATA_CONTRACTS.md",
    "docs/architecture/QA_AND_RECOVERY.md",
    "docs/architecture/BUILD_AND_RELEASE.md",
    "data/schemas/vehicle_components.json",
    "data/schemas/vehicle_powertrain.json",
    "data/schemas/folklore_entities.json",
    "data/schemas/dialogue_and_endings.json",
    "data/schemas/inventory_tools.json",
    "data/schemas/autoload_dependencies.json",
    "data/schemas/json/vehicle_components.schema.json",
    "data/schemas/json/vehicle_powertrain.schema.json",
    "data/schemas/json/folklore_entities.schema.json",
    "data/schemas/json/dialogue_and_endings.schema.json",
    "data/schemas/json/inventory_tools.schema.json",
    "data/schemas/json/autoload_dependencies.schema.json",
    "localization/strings.csv",
    "src/core/event_bus.gd",
    "src/core/Boot.gd",
    "src/core/hardware_profiler.gd",
    "src/core/settings_manager.gd",
    "src/core/localization_manager.gd",
    "src/core/game_state.gd",
    "src/core/save_manager.gd",
    "src/core/crash_reporter.gd",
    "src/core/crash_logger.gd",
    "src/core/audio_director.gd",
    "src/core/weather_manager.gd",
    "src/core/update_checker.gd",
    "src/core/scene_router.gd",
    "src/ui/creator_qa_menu.gd",
    "scenes/ui/CreatorQAMenu.tscn",
    "tests/smoke/SmokeTest.tscn",
    "tests/smoke/smoke_test.gd",
    "tests/vehicle/PowertrainTest.tscn",
    "tests/vehicle/powertrain_test.gd",
    "tools/dev/smoke_test.cmd",
    "tools/dev/smoke_test.ps1",
    "tools/dev/powertrain_test.cmd",
    "tools/dev/powertrain_test.ps1",
    "src/vehicle/vehicle_powertrain_spec.gd",
    "src/vehicle/engine_model.gd",
    "src/vehicle/automatic_transmission.gd",
    "src/vehicle/brake_system.gd",
    "src/vehicle/fuel_system.gd",
    "src/vehicle/cooling_system.gd",
    "src/vehicle/vehicle_powertrain.gd",
    "docs/architecture/EVENT_BUS.md",
    "tools/validate_schemas.py",
    "tools/validate_localization.py",
    "tools/validate_assets.py",
    "tools/validate_export.py",
    "tools/release/sync_roadmap.py",
    "tools/scan_reference_library.py",
    "tools/reference_library.json",
    "tools/dev/export.ps1",
    "tools/dev/export.cmd",
    "tools/test_android_adb.ps1",
    "export_presets.cfg",
    "scenes/boot/Boot.tscn",
    "scenes/vertical_slice/VerticalSlice.tscn",
    "src/world/vertical_slice.gd",
    "data/vehicle/blockout_spec.json",
    "data/vehicle/cabin_spec.json",
    "data/vehicle/exterior_spec.json",
    "tools/blender/build_assets.py",
    "tools/blender/build_assets.cmd",
    "tools/blender/esteem_blockout.py",
    "tools/blender/esteem_cabin.py",
    "tools/blender/esteem_exterior.py",
    "assets/manifests/esteem_blockout.manifest.json",
    "assets/manifests/esteem_cabin.manifest.json",
    "assets/manifests/esteem_exterior.manifest.json",
    "scenes/vehicle/EsteemBlockout.tscn",
    "scenes/vehicle/EsteemCabin.tscn",
    "scenes/vehicle/EsteemExterior.tscn",
    "tests/vehicle/CabinTest.tscn",
    "tests/vehicle/cabin_test.gd",
    "tools/dev/cabin_test.cmd",
    "tools/dev/cabin_test.ps1",
    "data/schemas/cabin_interaction.json",
    "data/schemas/json/cabin_interaction.schema.json",
    "src/vehicle/cabin_interaction_spec.gd",
    "src/vehicle/cabin_controls.gd",
    "src/vehicle/hand_ik_driver.gd",
    "src/vehicle/cabin_visual_proxies.gd",
    "src/vehicle/cabin_interaction_controller.gd",
    "src/vehicle/cabin_interaction_ui.gd",
    "src/vehicle/cabin_reticle.gd",
    "src/vehicle/radio_unit.gd",
    "src/vehicle/cabin_mirrors.gd",
    "src/vehicle/cabin_hud.gd",
    "src/vehicle/cabin_gamepad_adapter.gd",
    "scenes/vehicle/CabinInteraction.tscn",
    "tests/vehicle/InteractionTest.tscn",
    "tests/vehicle/interaction_test.gd",
    "tools/dev/interaction_test.cmd",
    "tools/dev/interaction_test.ps1",
    "tests/fixtures/save_v0_2_0.json",
    "tools/make_save_fixture.py",
]

REQUIRED_REPO_BINARIES = {".apk", ".aab", ".keystore", ".jks", ".p12", ".pfx"}


@dataclass
class Check:
    name: str
    status: str
    message: str = ""
    details: dict[str, Any] = field(default_factory=dict)


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def load_module(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise ImportError(f"No se pudo cargar {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def result(checks: list[Check], name: str, ok: bool, message: str = "", details: dict[str, Any] | None = None, warn: bool = False) -> None:
    checks.append(Check(name=name, status="warning" if warn else ("ok" if ok else "error"), message=message, details=details or {}))


def run_command(command: list[str], timeout: int = 120) -> tuple[int, str]:
    try:
        completed = subprocess.run(
            command,
            cwd=ROOT,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
            check=False,
        )
        return completed.returncode, (completed.stdout or "") + (completed.stderr or "")
    except Exception as exc:  # noqa: BLE001
        return 127, str(exc)


def check_required_files(checks: list[Check]) -> None:
    missing = [item for item in REQUIRED_FILES if not (ROOT / item).exists()]
    result(checks, "required_files", not missing, f"Faltan {len(missing)} archivos" if missing else "Archivos base presentes", {"missing": missing})


def check_version(checks: list[Check]) -> None:
    errors: list[str] = []
    version = (ROOT / "VERSION").read_text(encoding="utf-8").strip() if (ROOT / "VERSION").exists() else ""
    if not version:
        errors.append("VERSION vacío o ausente")
    project = (ROOT / "project.godot").read_text(encoding="utf-8") if (ROOT / "project.godot").exists() else ""
    if f'config/version="{version}"' not in project:
        errors.append("project.godot no coincide con VERSION")
    roadmap = (ROOT / "ROADMAP.md").read_text(encoding="utf-8") if (ROOT / "ROADMAP.md").exists() else ""
    if f"**Versión actual:** `v{version}`" not in roadmap:
        errors.append("ROADMAP.md no coincide con VERSION")
    result(checks, "version_consistency", not errors, "; ".join(errors) if errors else f"Versión {version}", {"version": version})


def check_schemas(checks: list[Check]) -> None:
    try:
        module = load_module(TOOLS / "validate_schemas.py", "rn1999_validate_schemas")
        errors, warnings = module.validate()
        result(
            checks,
            "json_contracts",
            not errors,
            f"{len(errors)} errores, {len(warnings)} advertencias",
            {"errors": errors, "warnings": warnings},
            warn=bool(warnings) and not errors,
        )
    except Exception as exc:  # noqa: BLE001
        result(checks, "json_contracts", False, f"No se pudo ejecutar la validación: {exc}")


def check_localization(checks: list[Check]) -> None:
    try:
        module = load_module(TOOLS / "validate_localization.py", "rn1999_validate_localization")
        errors, warnings = module.validate(require_fonts=False)
        result(
            checks,
            "localization",
            not errors,
            f"{len(errors)} errores, {len(warnings)} advertencias",
            {"errors": errors, "warnings": warnings},
            warn=bool(warnings) and not errors,
        )
    except Exception as exc:  # noqa: BLE001
        result(checks, "localization", False, f"No se pudo ejecutar la validación: {exc}")


def check_roadmap(checks: list[Check]) -> None:
    sync_script = ROOT / "tools" / "release" / "sync_roadmap.py"
    code, output = run_command([sys.executable, str(sync_script), "--check"], timeout=30)
    result(checks, "roadmap_sync", code == 0, output.strip() or "Sin salida", {"exit_code": code})


def check_generated_assets(checks: list[Check]) -> None:
    try:
        module = load_module(TOOLS / "validate_assets.py", "rn1999_validate_assets")
        errors, warnings = module.validate()
        result(
            checks,
            "generated_assets",
            not errors,
            f"{len(errors)} errores, {len(warnings)} advertencias",
            {"errors": errors, "warnings": warnings},
            warn=bool(warnings) and not errors,
        )
    except Exception as exc:  # noqa: BLE001
        result(checks, "generated_assets", False, f"No se pudo ejecutar la validación: {exc}")


def check_export_presets(checks: list[Check]) -> None:
    try:
        module = load_module(TOOLS / "validate_export.py", "rn1999_validate_export")
        errors, warnings = module.validate()
        result(
            checks,
            "export_presets",
            not errors,
            f"{len(errors)} errores, {len(warnings)} advertencias" if errors or warnings else "Presets de Windows y Android válidos",
            {"errors": errors, "warnings": warnings},
            warn=bool(warnings) and not errors,
        )
    except Exception as exc:  # noqa: BLE001
        result(checks, "export_presets", False, f"No se pudo validar: {exc}")


def check_build_toolchain(checks: list[Check]) -> None:
    details = {
        "java": str(JAVA) if JAVA.exists() else None,
        "android_sdk": str(ANDROID_SDK) if ANDROID_SDK.exists() else None,
        "export_templates": str(EXPORT_TEMPLATES) if EXPORT_TEMPLATES.exists() else None,
        "android_template": str(EXPORT_TEMPLATES / "android_debug.apk") if (EXPORT_TEMPLATES / "android_debug.apk").exists() else None,
        "windows_template": str(EXPORT_TEMPLATES / "windows_release_x86_64.exe") if (EXPORT_TEMPLATES / "windows_release_x86_64.exe").exists() else None,
    }
    missing = [name for name, value in details.items() if value is None]
    result(
        checks,
        "build_toolchain",
        not missing,
        "Java, SDK y plantillas de export presentes" if not missing else f"Faltan: {', '.join(missing)}",
        details,
        warn=bool(missing),
    )


def check_android_device(checks: list[Check]) -> None:
    if not ADB.exists():
        result(checks, "android_device", False, "adb no está instalado", warn=True)
        return
    code, output = run_command([str(ADB), "devices", "-l"], timeout=30)
    authorized = [
        line.split()[0]
        for line in output.splitlines()
        if len(line.split()) >= 2 and line.split()[1] == "device"
    ]
    if code != 0:
        result(checks, "android_device", False, f"adb devices falló: {output.strip()[:160]}", warn=True)
        return
    result(
        checks,
        "android_device",
        bool(authorized),
        f"Dispositivo autorizado: {', '.join(authorized)}" if authorized else "Sin dispositivo ADB autorizado",
        {"devices": authorized},
        warn=not authorized,
    )


def check_tracked_secrets(checks: list[Check]) -> None:
    code, output = run_command(["git", "ls-files"], timeout=20)
    if code != 0:
        result(checks, "tracked_secrets", False, "No se pudo listar el índice de Git", warn=True)
        return
    tracked = [line for line in output.splitlines() if line.strip()]
    suspicious = [
        path
        for path in tracked
        if path.lower().endswith((".keystore", ".jks", ".p12", ".pfx", ".apk", ".aab"))
        or path.lower() in {"export_credentials.cfg", ".env"}
    ]
    result(
        checks,
        "tracked_secrets",
        not suspicious,
        f"{len(suspicious)} archivos sensibles versionados" if suspicious else f"{len(tracked)} archivos versionados sin secretos ni binarios",
        {"suspicious": suspicious},
    )


def check_reference_library(checks: list[Check]) -> None:
    config_path = ROOT / "tools" / "reference_library.json"
    if not config_path.exists():
        result(checks, "reference_library", False, "Falta tools/reference_library.json")
        return
    try:
        config = json.loads(config_path.read_text(encoding="utf-8"))
        root = Path(config["root"])
        catalog_path = ROOT / config["catalog"]
        if not root.exists():
            result(checks, "reference_library", False, f"Biblioteca externa ausente: {root}")
            return
        if not catalog_path.exists():
            result(checks, "reference_library", False, "Catálogo de referencias ausente")
            return
        catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
        missing_catalog_entries = []
        stale_files = []
        for entry in catalog.get("files", []):
            source = root / entry["relative_path"]
            if not source.exists():
                missing_catalog_entries.append(entry["relative_path"])
            elif source.stat().st_size != entry.get("size_bytes"):
                stale_files.append(entry["relative_path"])
        last_scan = catalog.get("last_full_scan_utc", "")
        age_days: float | None = None
        if last_scan:
            try:
                scanned = datetime.fromisoformat(last_scan.replace("Z", "+00:00"))
                age_days = (datetime.now(timezone.utc) - scanned).total_seconds() / 86400
            except ValueError:
                age_days = None
        warning = bool(missing_catalog_entries or stale_files or (age_days is not None and age_days > config.get("review_interval_days", 14)))
        message = f"{catalog.get('file_count', 0)} referencias catalogadas"
        if missing_catalog_entries:
            message += f"; {len(missing_catalog_entries)} ausentes"
        if stale_files:
            message += f"; {len(stale_files)} modificadas"
        if age_days is not None:
            message += f"; última revisión hace {age_days:.1f} días"
        result(
            checks,
            "reference_library",
            not warning,
            message,
            {"missing": missing_catalog_entries, "modified": stale_files, "review_age_days": age_days},
            warn=warning,
        )
    except Exception as exc:  # noqa: BLE001
        result(checks, "reference_library", False, f"Error leyendo la biblioteca: {exc}")


def check_git(checks: list[Check]) -> None:
    if not (ROOT / ".git").exists():
        result(checks, "git", False, "No es un repositorio Git")
        return
    code, status = run_command(["git", "status", "--short"], timeout=20)
    branch_code, branch = run_command(["git", "branch", "--show-current"], timeout=20)
    code_tags, tags = run_command(["git", "tag", "--list"], timeout=20)
    details = {"branch": branch.strip(), "dirty": status.strip().splitlines(), "tags": tags.strip().splitlines()}
    message = f"Rama {branch.strip() or '(vacía)'}; {len(details['dirty'])} cambios locales"
    result(checks, "git", code == 0 and branch_code == 0 and code_tags == 0, message, details, warn=bool(details["dirty"]))


def check_disk(checks: list[Check]) -> None:
    usage = shutil.disk_usage("C:\\")
    free_gb = usage.free / (1024 ** 3)
    status = "ok" if free_gb >= 20 else ("warning" if free_gb >= 10 else "error")
    checks.append(Check("disk_space", status, f"{free_gb:.2f} GB libres en C:", {"free_gb": round(free_gb, 2)}))


def check_toolchain(checks: list[Check]) -> None:
    tool_status: dict[str, Any] = {}
    tool_status["godot"] = str(GODOT) if GODOT.exists() else None
    tool_status["blender"] = str(BLENDER) if BLENDER.exists() else None
    tool_status["adb"] = str(ADB) if ADB.exists() else None
    tool_status["gh"] = str(GH) if GH.exists() else None
    tool_status["debug_keystore"] = str(KEYSTORE) if KEYSTORE.exists() else None
    missing = [name for name in ("godot",) if tool_status[name] is None]
    warnings = [name for name in ("blender", "adb", "gh", "debug_keystore") if tool_status[name] is None]
    message = "Godot disponible"
    if warnings:
        message += f"; opcionales no disponibles: {', '.join(warnings)}"
    result(checks, "toolchain", not missing, message, tool_status, warn=bool(warnings) and not missing)


def check_forbidden_binaries(checks: list[Check]) -> None:
    offenders: list[str] = []
    ignored_dirs = {".git", ".venv", ".godot", "build"}
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        if any(part in ignored_dirs for part in path.parts):
            continue
        if path.suffix.lower() in REQUIRED_REPO_BINARIES:
            offenders.append(path.relative_to(ROOT).as_posix())
    result(checks, "forbidden_binaries", not offenders, f"{len(offenders)} binarios prohibidos en el árbol" if offenders else "Sin APK/AAB/keystores en el árbol", {"offenders": offenders})


def check_autoloads(checks: list[Check]) -> None:
    contract_path = ROOT / "data" / "schemas" / "autoload_dependencies.json"
    project_path = ROOT / "project.godot"
    try:
        contract = json.loads(contract_path.read_text(encoding="utf-8"))
        entries = contract["autoloads"]
        text = project_path.read_text(encoding="utf-8")
        section = ""
        declared: list[tuple[str, str]] = []
        for raw_line in text.splitlines():
            line = raw_line.strip()
            if line.startswith("[") and line.endswith("]"):
                section = line[1:-1]
                continue
            if section != "autoload":
                continue
            match = re.match(r'^([A-Za-z0-9_]+)="\*?(res://[^"]+)"$', line)
            if match:
                declared.append((match.group(1), match.group(2)))
        expected = [(entry["name"], entry["path"]) for entry in entries]
        errors: list[str] = []
        if declared != expected:
            errors.append("project.godot no coincide con autoload_dependencies.json")
        positions = {name: index for index, (name, _path) in enumerate(declared)}
        for entry in entries:
            path = ROOT / entry["path"].removeprefix("res://")
            if not path.exists():
                errors.append(f"falta el script de {entry['name']}: {entry['path']}")
            for dependency in entry["depends_on"]:
                if dependency in positions and positions[dependency] > positions[entry["name"]]:
                    errors.append(f"{entry['name']} se inicializa antes que {dependency}")
        message = (
            f"{len(declared)} autoloads declarados y ordenados"
            if not errors
            else "; ".join(errors[:6])
        )
        result(
            checks,
            "autoloads",
            not errors,
            message,
            {"declared": declared, "expected": expected, "errors": errors},
        )
    except Exception as exc:  # noqa: BLE001
        result(checks, "autoloads", False, f"No se pudo validar: {exc}")


def check_smoke_test(checks: list[Check], skip_smoke: bool) -> None:
    if skip_smoke:
        result(checks, "smoke_test", True, "Omitido por --skip-godot/--skip-smoke", warn=True)
        return
    if not GODOT.exists():
        result(checks, "smoke_test", False, "Godot no está instalado en la ruta esperada")
        return
    code, output = run_command(
        [str(GODOT), "--headless", "--path", str(ROOT), "res://tests/smoke/SmokeTest.tscn"],
        timeout=180,
    )
    ok = code == 0 and "[SMOKE] OK" in output
    result(
        checks,
        "smoke_test",
        ok,
        f"Exit {code}; {'smoke test superado' if ok else 'sin marca de éxito'}",
        {"exit_code": code, "tail": "\n".join(output.splitlines()[-30:])},
    )


def check_powertrain_test(checks: list[Check], skip_smoke: bool) -> None:
    if skip_smoke:
        result(checks, "powertrain_tests", True, "Omitido por --skip-godot/--skip-smoke", warn=True)
        return
    if not GODOT.exists():
        result(checks, "powertrain_tests", False, "Godot no está instalado en la ruta esperada")
        return
    code, output = run_command(
        [str(GODOT), "--headless", "--path", str(ROOT), "res://tests/vehicle/PowertrainTest.tscn"],
        timeout=180,
    )
    ok = code == 0 and "[POWERTRAIN] OK" in output
    result(
        checks,
        "powertrain_tests",
        ok,
        f"Exit {code}; {'tren motriz superado' if ok else 'sin marca de éxito'}",
        {"exit_code": code, "tail": "\n".join(output.splitlines()[-30:])},
    )


def check_cabin_test(checks: list[Check], skip_smoke: bool) -> None:
    if skip_smoke:
        result(checks, "cabin_tests", True, "Omitido por --skip-godot/--skip-smoke", warn=True)
        return
    if not GODOT.exists():
        result(checks, "cabin_tests", False, "Godot no está instalado en la ruta esperada")
        return
    code, output = run_command(
        [str(GODOT), "--headless", "--path", str(ROOT), "res://tests/vehicle/CabinTest.tscn"],
        timeout=180,
    )
    ok = code == 0 and "[CABIN] OK" in output
    result(
        checks,
        "cabin_tests",
        ok,
        f"Exit {code}; {'cabina y rig de manos superados' if ok else 'sin marca de éxito'}",
        {"exit_code": code, "tail": "\n".join(output.splitlines()[-30:])},
    )


def check_interaction_test(checks: list[Check], skip_smoke: bool) -> None:
    if skip_smoke:
        result(checks, "interaction_tests", True, "Omitido por --skip-godot/--skip-smoke", warn=True)
        return
    if not GODOT.exists():
        result(checks, "interaction_tests", False, "Godot no está instalado en la ruta esperada")
        return
    code, output = run_command(
        [str(GODOT), "--headless", "--path", str(ROOT), "res://tests/vehicle/InteractionTest.tscn"],
        timeout=180,
    )
    ok = code == 0 and "[INTERACTION] OK" in output
    result(
        checks,
        "interaction_tests",
        ok,
        f"Exit {code}; {'interaccion contextual superada' if ok else 'sin marca de éxito'}",
        {"exit_code": code, "tail": "\n".join(output.splitlines()[-30:])},
    )


def check_godot_import(checks: list[Check], skip_import: bool) -> None:
    if skip_import:
        result(checks, "godot_import", True, "Omitido por --skip-godot", warn=True)
        return
    if not GODOT.exists():
        result(checks, "godot_import", False, "Godot no está instalado en la ruta esperada")
        return
    code, output = run_command([str(GODOT), "--headless", "--path", str(ROOT), "--editor", "--quit"], timeout=180)
    lowered = output.lower()
    critical_markers = ["parse error", "script error", "failed to load", "cannot open file"]
    errors = [marker for marker in critical_markers if marker in lowered]
    ok = code == 0 and not errors
    result(
        checks,
        "godot_import",
        ok,
        f"Exit {code}; marcadores: {errors or 'ninguno'}",
        {"exit_code": code, "tail": "\n".join(output.splitlines()[-20:]), "markers": errors},
    )


def check_save_fixture(checks: list[Check]) -> None:
    try:
        module = load_module(TOOLS / "make_save_fixture.py", "rn1999_make_save_fixture")
        code = module.check_fixture()
        result(
            checks,
            "save_fixture",
            code == 0,
            "Fixture v0.2.0 verificado" if code == 0 else "Fixture v0.2.0 inválido",
            {"exit_code": code},
        )
    except Exception as exc:  # noqa: BLE001
        result(checks, "save_fixture", False, f"No se pudo verificar el fixture: {exc}")


def build_report(checks: list[Check], mode: str) -> dict[str, Any]:
    counts = {"ok": 0, "warning": 0, "error": 0}
    for check in checks:
        counts[check.status] = counts.get(check.status, 0) + 1
    return {
        "project": "Ruta Nocturna: 1999",
        "mode": mode,
        "timestamp_utc": utc_now(),
        "root": str(ROOT),
        "counts": counts,
        "checks": [asdict(check) for check in checks],
        "success": counts["error"] == 0,
    }


def print_summary(report: dict[str, Any]) -> None:
    for check in report["checks"]:
        prefix = {"ok": "[OK]", "warning": "[WARN]", "error": "[FAIL]"}[check["status"]]
        print(f"{prefix} {check['name']}: {check['message']}")
    counts = report["counts"]
    print(
        f"\nResumen: {counts['ok']} OK · {counts['warning']} advertencias · "
        f"{counts['error']} errores · modo {report['mode']}"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Chequeo de salud del proyecto.")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--start", action="store_true", help="Chequeo de inicio de subfase.")
    group.add_argument("--end", action="store_true", help="Chequeo previo al commit/cierre.")
    parser.add_argument("--skip-godot", action="store_true", help="Omitir importación de Godot.")
    parser.add_argument("--skip-smoke", action="store_true", help="Omitir el smoke test runtime.")
    args = parser.parse_args()
    mode = "start" if args.start else ("end" if args.end else "manual")

    checks: list[Check] = []
    check_required_files(checks)
    check_version(checks)
    check_schemas(checks)
    check_localization(checks)
    check_roadmap(checks)
    check_reference_library(checks)
    check_git(checks)
    check_disk(checks)
    check_toolchain(checks)
    check_forbidden_binaries(checks)
    check_autoloads(checks)
    check_generated_assets(checks)
    check_save_fixture(checks)
    check_export_presets(checks)
    check_build_toolchain(checks)
    check_android_device(checks)
    check_tracked_secrets(checks)
    check_godot_import(checks, args.skip_godot)
    check_smoke_test(checks, args.skip_godot or args.skip_smoke)
    check_powertrain_test(checks, args.skip_godot or args.skip_smoke)
    check_cabin_test(checks, args.skip_godot or args.skip_smoke)
    check_interaction_test(checks, args.skip_godot or args.skip_smoke)

    report = build_report(checks, mode)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    (REPORT_DIR / f"{stamp}.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (REPORT_DIR / "latest.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print_summary(report)
    print(f"Informe: {(REPORT_DIR / 'latest.json').relative_to(ROOT)}")
    return 0 if report["success"] else 1


if __name__ == "__main__":
    sys.exit(main())
