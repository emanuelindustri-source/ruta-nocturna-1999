#!/usr/bin/env python3
"""Validate the Godot export presets for Ruta Nocturna: 1999.

Phase 1.4 requires a reproducible Windows/Android export. This validator checks
the declarative preset file without launching Godot, so it can run in CI on any
platform.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
PRESETS = ROOT / "export_presets.cfg"
PROJECT = ROOT / "project.godot"
VERSION = ROOT / "VERSION"


def parse_presets(text: str) -> dict[str, dict[str, Any]]:
    """Parse the Godot export preset format into {preset section: {key: value}}."""
    sections: dict[str, dict[str, Any]] = {}
    current = ""
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";"):
            continue
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1]
            sections.setdefault(current, {})
            continue
        if not current or "=" not in line:
            continue
        key, value = line.split("=", 1)
        sections[current][key.strip()] = value.strip().strip('"')
    return sections


def validate() -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    if not PRESETS.exists():
        return ["Falta export_presets.cfg"], warnings
    if not PROJECT.exists():
        return ["Falta project.godot"], warnings
    if not VERSION.exists():
        return ["Falta VERSION"], warnings

    version = VERSION.read_text(encoding="utf-8").strip()
    text = PRESETS.read_text(encoding="utf-8")
    sections = parse_presets(text)

    presets: dict[str, dict[str, Any]] = {}
    for name, values in sections.items():
        if not re.fullmatch(r"preset\.\d+", name):
            continue
        if "platform" in values:
            presets[values["platform"]] = values
    if not presets:
        return ["No hay presets declarados en export_presets.cfg"], warnings

    names = {values.get("name", "") for values in presets.values()}
    for required in ("Windows Desktop", "Android"):
        if required not in names:
            errors.append(f"Falta el preset '{required}'")

    for platform in ("Windows Desktop", "Android"):
        preset = presets.get(platform)
        if preset is None:
            continue
        label = f"{platform}"
        export_path = preset.get("export_path", "")
        if not export_path.startswith("build/exports/"):
            errors.append(f"{label}: export_path debe vivir bajo build/exports/ ({export_path or 'vacío'})")
        if "include_filter" not in preset or "localization/*.csv" not in preset["include_filter"]:
            errors.append(f"{label}: include_filter debe incluir localization/*.csv")
        if "tests/*" not in preset.get("exclude_filter", ""):
            warnings.append(f"{label}: exclude_filter no excluye tests/*")
        if "tools/*" not in preset.get("exclude_filter", ""):
            warnings.append(f"{label}: exclude_filter no excluye tools/*")
        if "data/content/world/sectors/*.res" not in preset.get("include_filter", ""):
            errors.append(f"{label}: include_filter debe incluir los sectores de 800 m")

    windows = presets.get("Windows Desktop")
    if windows is not None:
        if not windows.get("export_path", "").endswith(".exe"):
            errors.append("Windows Desktop: export_path debe terminar en .exe")
        options = sections.get(_section_for(sections, "Windows Desktop"), {})
        if options.get("binary_format/architecture", "x86_64") != "x86_64":
            errors.append("Windows Desktop: arquitectura esperada x86_64")
        expected_file_version = f"{version}.0"
        if options.get("application/file_version", "") != expected_file_version:
            errors.append(
                f"Windows Desktop: application/file_version '{options.get('application/file_version', '')}' "
                f"no coincide con VERSION '{expected_file_version}'"
            )
        if options.get("application/product_version", "") != expected_file_version:
            errors.append(
                f"Windows Desktop: application/product_version '{options.get('application/product_version', '')}' "
                f"no coincide con VERSION '{expected_file_version}'"
            )

    android = presets.get("Android")
    if android is not None:
        if not android.get("export_path", "").endswith(".apk"):
            errors.append("Android: export_path debe terminar en .apk")
        options = sections.get(_section_for(sections, "Android"), {})
        if options.get("architectures/arm64-v8a") != "true":
            errors.append("Android: arquitecturas/arm64-v8a debe estar activo")
        if options.get("architectures/armeabi-v7a") != "false":
            errors.append("Android: armeabi-v7a debe quedar desactivado en la rebanada vertical")
        if options.get("package/signed") != "true":
            errors.append("Android: package/signed debe estar activo para la APK de prueba")
        package = options.get("package/unique_name", "")
        if not re.fullmatch(r"[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+", package):
            errors.append(f"Android: package/unique_name inválido ('{package}')")
        if options.get("version/name", "") != version:
            errors.append(
                f"Android: version/name '{options.get('version/name', '')}' no coincide con VERSION '{version}'"
            )
        if not options.get("version/code", "").isdigit() or int(options.get("version/code", "0")) <= 0:
            errors.append("Android: version/code debe ser un entero positivo")
        if options.get("gradle_build/use_gradle_build") not in (None, "false"):
            warnings.append("Android: se está usando Gradle build; la rebanada vertical usa la plantilla precompilada")

    lowered = text.lower()
    for forbidden in ("keystore_pass", "keystore_password", "storepass", "keypass", "export_credentials"):
        if forbidden in lowered:
            errors.append(f"export_presets.cfg contiene material sensible: {forbidden}")

    project_text = PROJECT.read_text(encoding="utf-8")
    if "textures/vram_compression/import_etc2_astc=true" not in project_text:
        errors.append("project.godot debe activar textures/vram_compression/import_etc2_astc")
    if f'config/version="{version}"' not in project_text:
        errors.append("project.godot no coincide con VERSION")

    for script in (
        ROOT / "tools" / "dev" / "export.ps1",
        ROOT / "tools" / "dev" / "export.cmd",
        ROOT / "tools" / "test_android_adb.ps1",
    ):
        if not script.exists():
            errors.append(f"Falta la herramienta {script.relative_to(ROOT).as_posix()}")

    return errors, warnings


def _section_for(sections: dict[str, dict[str, Any]], platform: str) -> str:
    for name, values in sections.items():
        if re.fullmatch(r"preset\.\d+", name) and values.get("platform") == platform:
            return f"{name}.options"
    return ""


def main() -> int:
    parser = argparse.ArgumentParser(description="Valida los presets de exportación.")
    parser.parse_args()
    errors, warnings = validate()
    for warning in warnings:
        print(f"[WARN] {warning}")
    for error in errors:
        print(f"[FAIL] {error}")
    if errors:
        return 1
    print(f"[OK] Presets de exportación válidos; {len(warnings)} advertencias.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
