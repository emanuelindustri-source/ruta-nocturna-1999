#!/usr/bin/env python3
"""Compara capturas de la sesion de juego de PC (F3.5).

Uso:
    .venv/Scripts/python.exe tools/dev/gameplay_diff.py A.png B.png
        [--region x,y,w,h] [--crop x,y,w,h out.png]

Imprime el porcentaje de pixeles cambiados, el bounding box de los cambios y
( opcional ) recorta una region para inspeccion visual. Sirve para verificar
efectos de interaccion (puerta, ventana, HUD, panel QA) sin depender del orden
en que se revisan las imagenes.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[2]


def parse_region(text: str) -> tuple[int, int, int, int]:
    parts = [int(p) for p in text.split(",")]
    if len(parts) != 4:
        raise argparse.ArgumentTypeError("region debe ser x,y,w,h")
    return parts[0], parts[1], parts[2], parts[3]


def main() -> int:
    parser = argparse.ArgumentParser(description="Compara dos capturas de juego.")
    parser.add_argument("a")
    parser.add_argument("b")
    parser.add_argument("--region", type=parse_region, default=None)
    parser.add_argument("--crop", type=parse_region, default=None)
    parser.add_argument("--out", default=None, help="destino del recorte")
    parser.add_argument("--threshold", type=int, default=8, help="delta por canal para contar cambio")
    args = parser.parse_args()

    path_a = Path(args.a)
    path_b = Path(args.b)
    if not path_a.is_absolute():
        path_a = ROOT / path_a
    if not path_b.is_absolute():
        path_b = ROOT / path_b
    if not path_a.exists() or not path_b.exists():
        print(f"[FAIL] falta archivo: {path_a if not path_a.exists() else path_b}")
        return 1

    img_a = Image.open(path_a).convert("RGB")
    img_b = Image.open(path_b).convert("RGB")
    if img_a.size != img_b.size:
        print(f"[FAIL] tamanos distintos: {img_a.size} vs {img_b.size}")
        return 1

    if args.crop:
        x, y, w, h = args.crop
        img_a.crop((x, y, x + w, y + h)).save(path_a.with_suffix(".crop.png"))
        img_b.crop((x, y, x + w, y + h)).save(path_b.with_suffix(".crop.png"))
        print(f"[OK] recortes: {path_a.with_suffix('.crop.png')} / {path_b.with_suffix('.crop.png')}")

    if args.region:
        x, y, w, h = args.region
        img_a = img_a.crop((x, y, x + w, y + h))
        img_b = img_b.crop((x, y, x + w, y + h))

    diff = ImageChops.difference(img_a, img_b)
    gray = diff.convert("L")
    bw = gray.point(lambda v: 255 if v > args.threshold else 0)
    total = img_a.size[0] * img_a.size[1]
    changed = sum(1 for p in bw.getdata() if p)
    percent = 100.0 * changed / total
    bbox = bw.getbbox()
    print(
        f"[DIFF] {path_a.name} vs {path_b.name}: {changed} px ({percent:.3f}%) "
        f"bbox={bbox} region={'custom' if args.region else 'full'}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
