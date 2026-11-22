#!/usr/bin/env python3
"""Validate the 11-language foundation CSV and optional font coverage."""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "localization" / "strings.csv"
FONT_DIR = ROOT / "assets" / "fonts"
LOCALES = ["es_VE", "es_ES", "en", "pt_PT", "pt_BR", "it", "fr", "de", "ru", "zh_CN", "ja"]
PLACEHOLDER_RE = re.compile(r"\{[A-Za-z0-9_]+\}|%\d+\$?[sd]|%[sd]")
FORBIDDEN_GLYPHS = {"\u25a1": "□"}


def load_rows() -> tuple[list[dict[str, str]], list[str]]:
    errors: list[str] = []
    if not CSV_PATH.exists():
        return [], [f"No existe {CSV_PATH.relative_to(ROOT)}"]
    with CSV_PATH.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        fieldnames = reader.fieldnames or []
    expected = ["key", *LOCALES]
    if fieldnames != expected:
        errors.append(f"Columnas esperadas {expected}; encontradas {fieldnames}")
    return rows, errors


def font_files() -> list[Path]:
    if not FONT_DIR.exists():
        return []
    return sorted(
        [path for path in FONT_DIR.rglob("*") if path.suffix.lower() in {".ttf", ".otf"} and path.is_file()]
    )


def validate(require_fonts: bool = False) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    rows, load_errors = load_rows()
    errors.extend(load_errors)
    if load_errors and not rows:
        return errors, warnings

    seen: set[str] = set()
    for line_number, row in enumerate(rows, start=2):
        key = (row.get("key") or "").strip()
        if not key:
            errors.append(f"Línea {line_number}: clave vacía")
            continue
        if not re.fullmatch(r"[A-Z0-9_]+", key):
            errors.append(f"Línea {line_number}: clave inválida {key}")
        if key in seen:
            errors.append(f"Línea {line_number}: clave duplicada {key}")
        seen.add(key)

        placeholders_by_locale: dict[str, list[str]] = {}
        for locale in LOCALES:
            value = row.get(locale)
            if value is None or not value.strip():
                errors.append(f"{key}: traducción vacía en {locale}")
                continue
            if any(glyph in value for glyph in FORBIDDEN_GLYPHS):
                errors.append(f"{key}: glifo de tofu detectado en {locale}")
            placeholders_by_locale[locale] = sorted(PLACEHOLDER_RE.findall(value))
        if placeholders_by_locale:
            reference = placeholders_by_locale.get("es_VE")
            for locale, placeholders in placeholders_by_locale.items():
                if locale != "es_VE" and placeholders != reference:
                    errors.append(
                        f"{key}: placeholders distintos en {locale}: {placeholders} != {reference}"
                    )

    fonts = font_files()
    if not fonts:
        message = (
            "No hay fuentes locales en assets/fonts; la validación visual de cirílico, "
            "chino y japonés queda pendiente para F8.4."
        )
        if require_fonts:
            errors.append(message)
        else:
            warnings.append(message)
    else:
        from fontTools.ttLib import TTFont

        samples = {
            "ru": "Продолжить",
            "zh_CN": "继续",
            "ja": "続ける",
        }
        for locale, sample in samples.items():
            covered = False
            for font_path in fonts:
                try:
                    font = TTFont(str(font_path), fontNumber=0, lazy=True)
                    cmap = font.getBestCmap() or {}
                    if all(ord(char) in cmap for char in sample):
                        covered = True
                        break
                except Exception:  # noqa: BLE001
                    continue
            if not covered:
                errors.append(f"Ninguna fuente cubre los glifos de muestra para {locale}: {sample}")

    if len(seen) == 0:
        errors.append("El CSV no contiene claves.")
    return errors, warnings


def main() -> int:
    parser = argparse.ArgumentParser(description="Valida las 11 traducciones base.")
    parser.add_argument("--require-fonts", action="store_true")
    args = parser.parse_args()
    errors, warnings = validate(args.require_fonts)
    for warning in warnings:
        print(f"[WARN] {warning}")
    for error in errors:
        print(f"[ERROR] {error}")
    if errors:
        print(f"\n[FAIL] {len(errors)} errores de localización.")
        return 1
    print(f"[OK] Localización base válida para {len(LOCALES)} idiomas. {len(warnings)} advertencias.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
