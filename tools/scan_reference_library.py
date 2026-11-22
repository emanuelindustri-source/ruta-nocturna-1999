#!/usr/bin/env python3
"""Read-only inventory and review helper for the external reference library.

The source directory is never modified. The committed catalog contains only
metadata and hashes; extracted text and contact sheets stay under build/ and are
ignored by Git.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:  # pragma: no cover - handled with a clear message
    Image = None
    ImageDraw = None
    ImageFont = None

try:
    from pypdf import PdfReader
except ImportError:  # pragma: no cover
    PdfReader = None

try:
    from docx import Document
except ImportError:  # pragma: no cover
    Document = None


ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "tools" / "reference_library.json"
IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp"}
TEXT_EXTENSIONS = {".pdf", ".docx"}
VIDEO_EXTENSIONS = {".mp4"}


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def safe_name(name: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9._-]+", "_", name)
    return cleaned[:120].strip("._") or "reference"


def classify(path: Path) -> tuple[str, str, list[str], list[str]]:
    name = path.name.lower()
    ext = path.suffix.lower()

    if ext in IMAGE_EXTENSIONS:
        if "gemini_generated_image" in name:
            return (
                "concept_art",
                "ai_generated_concept",
                ["ui", "scene", "art_direction"],
                ["F1.1", "F3.3", "F3.4", "F4.3", "F9.2"],
            )
        if any(token in name for token in ("motor", "caja", "correa", "filtro", "bomba", "base", "manguito", "eje", "arrancador")):
            return (
                "vehicle_technical_photo",
                "mechanical_reference",
                ["vehicle", "mechanics", "visual_reference"],
                ["F1.1", "F2.2", "F3.1", "F3.2", "F5.1", "F5.3"],
            )
        return (
            "vehicle_photo",
            "exterior_or_interior_reference",
            ["vehicle", "visual_reference"],
            ["F1.1", "F2.2", "F3.1", "F3.2"],
        )

    if ext == ".pdf":
        return (
            "technical_document",
            "manual_or_specification",
            ["manual", "technical", "esteem"],
            ["F1.1", "F2.1", "F3.1", "F3.2", "F5.1", "F5.4"],
        )
    if ext == ".docx":
        return (
            "folklore_document",
            "legend_collection",
            ["folklore", "narrative", "venezuela"],
            ["F1.1", "F6.1", "F7.1", "F7.3"],
        )
    if ext in VIDEO_EXTENSIONS:
        return (
            "concept_video",
            "motion_reference",
            ["ui", "motion", "art_direction"],
            ["F1.1", "F9.2", "F10.2"],
        )
    return ("unknown", "unknown", [], ["F1.1"])


def image_metadata(path: Path) -> dict[str, Any]:
    if Image is None:
        return {"metadata_status": "Pillow not installed"}
    try:
        with Image.open(path) as image:
            return {
                "width": image.width,
                "height": image.height,
                "mode": image.mode,
                "format": image.format,
            }
    except Exception as exc:  # noqa: BLE001 - metadata must not stop the scan
        return {"metadata_status": f"unreadable: {exc}"}


def pdf_metadata(path: Path) -> dict[str, Any]:
    if PdfReader is None:
        return {"metadata_status": "pypdf not installed"}
    try:
        reader = PdfReader(str(path))
        return {"pages": len(reader.pages)}
    except Exception as exc:  # noqa: BLE001
        return {"metadata_status": f"unreadable: {exc}"}


def docx_metadata(path: Path) -> dict[str, Any]:
    if Document is None:
        return {"metadata_status": "python-docx not installed"}
    try:
        document = Document(str(path))
        return {
            "paragraphs": len(document.paragraphs),
            "tables": len(document.tables),
        }
    except Exception as exc:  # noqa: BLE001
        return {"metadata_status": f"unreadable: {exc}"}


def file_metadata(path: Path) -> dict[str, Any]:
    ext = path.suffix.lower()
    if ext in IMAGE_EXTENSIONS:
        return image_metadata(path)
    if ext == ".pdf":
        return pdf_metadata(path)
    if ext == ".docx":
        return docx_metadata(path)
    if ext in VIDEO_EXTENSIONS:
        return {
            "metadata_status": "video duration pending optional ffprobe/VLC review",
        }
    return {}


def build_file_entry(path: Path, root: Path, config: dict[str, Any]) -> dict[str, Any]:
    rel = path.relative_to(root).as_posix()
    digest = sha256_file(path)
    category, kind, tags, phases = classify(path)
    stat = path.stat()
    entry = {
        "id": "REF-" + digest[:10].upper(),
        "name": path.name,
        "relative_path": rel,
        "extension": path.suffix.lower(),
        "size_bytes": stat.st_size,
        "modified_utc": datetime.fromtimestamp(stat.st_mtime, timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "sha256": digest,
        "category": category,
        "kind": kind,
        "tags": tags,
        "relevant_phases": phases,
        "license_status": "reference_only_unverified",
        "review_status": "pending_full_visual_review",
        "duplicate_of": None,
        "media": file_metadata(path),
        "notes": "",
        "review_policy": config.get("license_notice", ""),
    }
    return entry


def find_files(root: Path, allowed: set[str]) -> list[Path]:
    files: list[Path] = []
    for path in sorted(root.rglob("*"), key=lambda item: item.as_posix().lower()):
        if path.is_file() and path.suffix.lower() in allowed:
            files.append(path)
    return files


def make_contact_sheets(files: list[dict[str, Any]], root: Path, out_dir: Path) -> list[str]:
    if Image is None or ImageDraw is None or ImageFont is None:
        return []

    out_dir.mkdir(parents=True, exist_ok=True)
    groups: dict[str, list[dict[str, Any]]] = {
        "generated_concepts": [],
        "vehicle_references": [],
        "all_images": [],
    }
    for entry in files:
        path = root / entry["relative_path"]
        if path.suffix.lower() not in IMAGE_EXTENSIONS:
            continue
        groups["all_images"].append(entry)
        if entry["category"] == "concept_art":
            groups["generated_concepts"].append(entry)
        elif entry["category"] in {"vehicle_photo", "vehicle_technical_photo"}:
            groups["vehicle_references"].append(entry)

    try:
        font = ImageFont.truetype("arial.ttf", 16)
    except Exception:  # noqa: BLE001
        font = ImageFont.load_default()

    generated: list[str] = []
    for group_name, entries in groups.items():
        if not entries:
            continue
        columns = 4 if len(entries) > 12 else 3
        tile_w, tile_h = (360, 230) if group_name != "vehicle_references" else (300, 240)
        label_h = 40
        cell_w, cell_h = tile_w + 12, tile_h + label_h + 12
        rows = math.ceil(len(entries) / columns)
        sheet = Image.new("RGB", (columns * cell_w, rows * cell_h), (9, 14, 20))
        draw = ImageDraw.Draw(sheet)
        for index, entry in enumerate(entries):
            path = root / entry["relative_path"]
            try:
                with Image.open(path) as source:
                    source = source.convert("RGB")
                    source.thumbnail((tile_w, tile_h))
                    x = (index % columns) * cell_w + (cell_w - source.width) // 2
                    row = index // columns
                    y = row * cell_h + 6
                    sheet.paste(source, (x, y))
            except Exception:  # noqa: BLE001
                row = index // columns
                draw.text(
                    ((index % columns) * cell_w + 8, row * cell_h + 8),
                    "UNREADABLE",
                    fill=(230, 120, 110),
                    font=font,
                )
            label = f"{index + 1:02d} · {entry['relative_path']}"
            label = label[:55]
            draw.text(
                ((index % columns) * cell_w + 8, (index // columns) * cell_h + tile_h + 12),
                label,
                fill=(228, 206, 139),
                font=font,
            )
        target = out_dir / f"{group_name}.jpg"
        sheet.save(target, quality=86)
        generated.append(str(target))
    return generated


def extract_text(files: list[dict[str, Any]], root: Path, out_dir: Path) -> dict[str, Any]:
    out_dir.mkdir(parents=True, exist_ok=True)
    manifest: dict[str, Any] = {"generated_utc": utc_now(), "documents": []}
    for entry in files:
        ext = entry["extension"]
        source = root / entry["relative_path"]
        target_name = safe_name(source.stem) + ".txt"
        target = out_dir / target_name
        text = ""
        if ext == ".pdf" and PdfReader is not None:
            try:
                reader = PdfReader(str(source))
                chunks: list[str] = []
                for page_number, page in enumerate(reader.pages, start=1):
                    chunks.append(f"\n\n--- PAGE {page_number} ---\n")
                    chunks.append(page.extract_text() or "")
                text = "".join(chunks)
            except Exception as exc:  # noqa: BLE001
                text = f"[EXTRACTION ERROR] {exc}\n"
        elif ext == ".docx" and Document is not None:
            try:
                document = Document(str(source))
                text = "\n".join(paragraph.text for paragraph in document.paragraphs)
            except Exception as exc:  # noqa: BLE001
                text = f"[EXTRACTION ERROR] {exc}\n"
        elif ext in {".pdf", ".docx"}:
            text = "[EXTRACTION ERROR] Required Python package is not installed.\n"
        else:
            continue
        target.write_text(text, encoding="utf-8")
        manifest["documents"].append(
            {
                "reference_id": entry["id"],
                "source": entry["relative_path"],
                "extracted_chars": len(text),
                "extracted_path": target.relative_to(ROOT).as_posix(),
            }
        )
    (out_dir / "extraction_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return manifest


def compare_quick(catalog: dict[str, Any], files: list[Path], root: Path) -> list[str]:
    known = {entry["relative_path"]: entry for entry in catalog.get("files", [])}
    changes: list[str] = []
    current: dict[str, Path] = {path.relative_to(root).as_posix(): path for path in files}
    for rel, path in current.items():
        old = known.get(rel)
        if old is None:
            changes.append(f"NEW {rel}")
            continue
        stat = path.stat()
        if old.get("size_bytes") != stat.st_size:
            changes.append(f"MODIFIED(size) {rel}")
    for rel in sorted(set(known) - set(current)):
        changes.append(f"MISSING {rel}")
    return changes


def main() -> int:
    parser = argparse.ArgumentParser(description="Cataloga la biblioteca externa de referencias.")
    parser.add_argument("--config", default=str(CONFIG_PATH))
    parser.add_argument("--quick", action="store_true", help="Compara metadatos con el catálogo sin reescribirlo.")
    parser.add_argument("--full", action="store_true", help="Recalcula hashes, catálogo y hojas de contacto.")
    parser.add_argument("--extract-text", action="store_true", help="Extrae texto de PDFs y DOCX a build/reference/extracted.")
    parser.add_argument("--no-contact-sheets", action="store_true")
    args = parser.parse_args()

    config = load_json(Path(args.config))
    root = Path(config["root"])
    catalog_path = ROOT / config["catalog"]
    build_dir = ROOT / config["build_dir"]

    if not root.exists():
        print(f"[FAIL] No existe la biblioteca externa: {root}")
        return 2

    allowed = set(config.get("allowed_extensions", []))
    files = find_files(root, allowed)
    if not files:
        print(f"[FAIL] La biblioteca no contiene extensiones admitidas en {root}")
        return 2

    if args.quick:
        if not catalog_path.exists():
            print("[INFO] Catálogo ausente. Ejecutar --full.")
            return 0
        catalog = load_json(catalog_path)
        changes = compare_quick(catalog, files, root)
        if changes:
            print(f"[INFO] Cambios detectados: {len(changes)}")
            for change in changes[:30]:
                print("  " + change)
            if len(changes) > 30:
                print(f"  ... y {len(changes) - 30} más")
        else:
            print(f"[OK] Sin cambios en la biblioteca externa ({len(files)} archivos).")
        return 0

    if not args.full:
        print("[INFO] Usando escaneo completo por defecto. Use --quick para comparar.")
        args.full = True

    entries = [build_file_entry(path, root, config) for path in files]
    by_hash: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for entry in entries:
        by_hash[entry["sha256"]].append(entry)
    for digest, copies in by_hash.items():
        if len(copies) > 1:
            canonical = copies[0]["name"]
            for copy in copies[1:]:
                copy["duplicate_of"] = canonical

    total_size = sum(entry["size_bytes"] for entry in entries)
    duplicates = [
        {"sha256": digest, "files": [entry["relative_path"] for entry in copies]}
        for digest, copies in by_hash.items()
        if len(copies) > 1
    ]
    catalog = {
        "schema_version": 1,
        "generated_by": "tools/scan_reference_library.py",
        "root": root.as_posix(),
        "read_only": True,
        "scan_type": "full",
        "last_full_scan_utc": utc_now(),
        "review_interval_days": config.get("review_interval_days", 14),
        "review_gates": config.get("review_gates", []),
        "license_notice": config.get("license_notice", ""),
        "file_count": len(entries),
        "total_size_bytes": total_size,
        "duplicate_groups": duplicates,
        "files": entries,
    }

    catalog_path.parent.mkdir(parents=True, exist_ok=True)
    catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    sheets: list[str] = []
    if not args.no_contact_sheets:
        sheets = make_contact_sheets(entries, root, build_dir / "contact_sheets")
    extraction = None
    if args.extract_text:
        extraction = extract_text(entries, root, build_dir / "extracted")

    print(f"[OK] Catálogo: {catalog_path.relative_to(ROOT)}")
    print(f"     Archivos: {len(entries)} · {total_size / (1024 * 1024):.2f} MB")
    print(f"     Duplicados exactos: {len(duplicates)}")
    if sheets:
        print(f"     Hojas de contacto: {len(sheets)} en {build_dir.relative_to(ROOT)}/contact_sheets")
    if extraction is not None:
        extracted = len(extraction.get("documents", []))
        print(f"     Texto extraído: {extracted} documentos en {build_dir.relative_to(ROOT)}/extracted")
    print("     Originales intactos; no se copiaron al repositorio.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
