#!/usr/bin/env python3
"""Validate the baked 800 m world sectors and their manifest (F4.2)."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
STREAMING_CONTRACT = ROOT / "data" / "schemas" / "world_streaming.json"
ROUTES_CONTRACT = ROOT / "data" / "schemas" / "world_routes.json"
NETWORK = ROOT / "data" / "content" / "world" / "route_network.json"
MANIFEST = ROOT / "data" / "content" / "world" / "sectors.manifest.json"
SECTORS_DIR = ROOT / "data" / "content" / "world" / "sectors"
ODBL = ROOT / "licenses" / "ODbL-1.0.txt"


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def projected(points: list[list[float]], projection: dict[str, Any]) -> list[tuple[float, float, float]]:
    origin = projection["origin"]
    scale = float(projection["world_scale"])
    meters_lat = float(projection["meters_per_degree_lat"])
    meters_lon = float(projection["meters_per_degree_lon"])
    result = []
    for point in points:
        lat, lon, elevation = float(point[0]), float(point[1]), float(point[2])
        x = (lon - float(origin[1])) * meters_lon * scale
        z = -(lat - float(origin[0])) * meters_lat * scale
        result.append((x, z, elevation * float(projection["vertical_scale"])))
    return result


def expected_sector_keys(
    network: dict[str, Any],
    projection: dict[str, Any],
    sector_size: float,
    road_half_width: float,
) -> set[str]:
    keys: set[str] = set()
    for edge in network.get("edges", []):
        points = projected(edge.get("shape", []), projection)
        for x, z, _ in points:
            keys.add(f"{math.floor(x / sector_size)}_{math.floor(z / sector_size)}")
        for index in range(len(points) - 1):
            x0, z0, _ = points[index]
            x1, z1, _ = points[index + 1]
            min_x = min(x0, x1) - road_half_width
            max_x = max(x0, x1) + road_half_width
            min_z = min(z0, z1) - road_half_width
            max_z = max(z0, z1) + road_half_width
            for sx in range(math.floor(min_x / sector_size), math.floor(max_x / sector_size) + 1):
                for sz in range(math.floor(min_z / sector_size), math.floor(max_z / sector_size) + 1):
                    keys.add(f"{sx}_{sz}")
    return keys


def load_and_validate(root: Path = ROOT) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    streaming_path = root / "data" / "schemas" / "world_streaming.json"
    routes_path = root / "data" / "schemas" / "world_routes.json"
    network_path = root / "data" / "content" / "world" / "route_network.json"
    manifest_path = root / "data" / "content" / "world" / "sectors.manifest.json"
    sectors_dir = root / "data" / "content" / "world" / "sectors"
    odbl_path = root / "licenses" / "ODbL-1.0.txt"

    for path in (streaming_path, routes_path, network_path, manifest_path):
        if not path.exists():
            errors.append(f"world_streaming: falta {path.relative_to(root).as_posix()}")
    if errors:
        return errors, warnings
    if not sectors_dir.exists():
        errors.append("world_streaming: falta el directorio de sectores")
        return errors, warnings
    if not odbl_path.exists():
        errors.append("world_streaming: falta licenses/ODbL-1.0.txt")
        return errors, warnings

    streaming = load_json(streaming_path)
    routes = load_json(routes_path)
    network = load_json(network_path)
    manifest = load_json(manifest_path)

    terrain = streaming.get("terrain", {})
    stream = streaming.get("streaming", {})
    budgets = streaming.get("budgets", {})
    qa = streaming.get("qa", {})
    sector_size = float(terrain.get("sector_size_m", 0))
    road_half_width = float(terrain.get("road", {}).get("width_m", 0)) * 0.5
    projection = routes.get("projection", {})

    if streaming.get("contract_id") != "world.streaming":
        errors.append("world_streaming: contract_id inválido")
    if streaming.get("world_id") != network.get("world_id"):
        errors.append("world_streaming: world_id distinto de la red")
    if int(streaming.get("schema_version", 0)) != 1:
        errors.append("world_streaming: schema_version debe ser 1")
    if sector_size != 800.0 or float(stream.get("sector_size_m", 0)) != 800.0:
        errors.append("world_streaming: el sector debe medir 800 m")
    if int(stream.get("max_concurrent_requests", 0)) != 2:
        errors.append("world_streaming: max_concurrent_requests debe ser 2")
    if not bool(stream.get("sync_load_forbidden", False)):
        errors.append("world_streaming: debe prohibir load() síncrono")
    if "load_threaded_request" not in str(stream.get("loader_api", "")):
        errors.append("world_streaming: loader_api debe declarar load_threaded_request")
    if int(budgets.get("max_total_visible_triangles_mobile", 0)) != 120000:
        errors.append("world_streaming: presupuesto móvil de triángulos debe ser 120000")
    if int(budgets.get("max_total_visible_triangles_pc", 0)) != 450000:
        errors.append("world_streaming: presupuesto PC de triángulos debe ser 450000")
    if abs(float(budgets.get("max_pss_mb", 0)) - 1228.8) > 0.01:
        errors.append("world_streaming: presupuesto PSS debe ser 1228.8 MB")
    if float(budgets.get("runtime_load_budget_ms", 0)) != 250.0:
        errors.append("world_streaming: runtime_load_budget_ms debe ser 250 ms")
    if "odbl" not in odbl_path.read_text(encoding="utf-8").lower():
        errors.append("world_streaming: licenses/ODbL-1.0.txt no contiene ODbL")
    for key, path in (
        ("scene", qa.get("scene")),
        ("test_scene", qa.get("test_scene")),
        ("test_command", qa.get("test_command")),
        ("bake_scene", qa.get("bake_scene")),
        ("bake_command", qa.get("bake_command")),
        ("validate_command", qa.get("validate_command")),
    ):
        if not path or not (root / str(path)).exists():
            errors.append(f"world_streaming: qa.{key} no existe ({path})")

    if manifest.get("contract_id") != "world.streaming":
        errors.append("world_streaming: manifiesto de sectores con contract_id inválido")
    if int(manifest.get("sector_count", 0)) != len(manifest.get("sectors", [])):
        errors.append("world_streaming: sector_count del manifiesto no coincide con la lista")
    if int(manifest.get("grid_resolution", 0)) != int(terrain.get("grid_resolution", -1)):
        errors.append("world_streaming: grid_resolution del manifiesto no coincide con el contrato")
    if float(manifest.get("sector_size_m", 0)) != sector_size:
        errors.append("world_streaming: sector_size_m del manifiesto no coincide")
    if int(manifest.get("grid_resolution", 0)) < 17:
        errors.append("world_streaming: grid_resolution demasiado bajo")
    expected_count = int(qa.get("expected_sector_count", 0))
    if expected_count != len(manifest.get("sectors", [])):
        errors.append(
            f"world_streaming: expected_sector_count {expected_count} != {len(manifest.get('sectors', []))}"
        )
    if len(manifest.get("sectors", [])) > int(budgets.get("max_sector_resources", 0)):
        errors.append("world_streaming: demasiados recursos de sector")
    if int(manifest.get("total_bytes", 0)) > int(budgets.get("max_sector_bytes", 0)):
        errors.append("world_streaming: bytes de sectores por encima del presupuesto")

    source = manifest.get("source", {})
    if source.get("license") != "ODbL 1.0":
        errors.append("world_streaming: manifiesto sin licencia ODbL 1.0")
    if "OpenStreetMap" not in str(source.get("copyright", "")):
        errors.append("world_streaming: manifiesto sin copyright de OpenStreetMap")
    if source.get("route_network_sha256") != hashlib.sha256(network_path.read_bytes()).hexdigest():
        errors.append("world_streaming: hash de la red no coincide con el manifiesto")

    expected = expected_sector_keys(network, projection, sector_size, road_half_width)
    actual: set[str] = set()
    total_bytes = 0
    for entry in manifest.get("sectors", []):
        sector_id = str(entry.get("id", ""))
        actual.add(sector_id)
        path = root / str(entry.get("path", ""))
        if not path.exists():
            errors.append(f"world_streaming: falta el sector {path.relative_to(root).as_posix()}")
            continue
        payload = path.read_bytes()
        total_bytes += len(payload)
        if len(payload) != int(entry.get("bytes", -1)):
            errors.append(f"world_streaming: tamaño distinto en {sector_id}")
        if hashlib.sha256(payload).hexdigest() != str(entry.get("sha256", "")):
            errors.append(f"world_streaming: hash distinto en {sector_id}")
        if int(entry.get("terrain_triangles", 0)) <= 0:
            errors.append(f"world_streaming: {sector_id} sin triángulos de terreno")

    if actual != expected:
        missing = sorted(expected - actual)
        extra = sorted(actual - expected)
        if missing:
            errors.append(f"world_streaming: faltan {len(missing)} sectores de la red: {missing[:6]}")
        if extra:
            errors.append(f"world_streaming: {len(extra)} sectores fuera de la red: {extra[:6]}")
    if total_bytes != int(manifest.get("total_bytes", -1)):
        errors.append("world_streaming: total_bytes del manifiesto no coincide con los archivos")

    expected_terrain = len(actual) * (int(manifest.get("grid_resolution", 33)) - 1) ** 2 * 2
    if int(manifest.get("total_terrain_triangles", 0)) != expected_terrain:
        errors.append("world_streaming: total_terrain_triangles no coincide con la rejilla")
    if int(manifest.get("total_terrain_triangles", 0)) // max(1, len(actual)) > int(
        budgets.get("max_triangles_per_sector", 0)
    ):
        errors.append("world_streaming: triángulos por sector por encima del presupuesto")

    # Cobertura de las seis rutas principales: cada punto de cada arista debe
    # pertenecer a un sector horneado.
    for route in network.get("routes", []):
        for edge_id in route.get("edge_ids", []):
            edge = next((item for item in network.get("edges", []) if item.get("id") == edge_id), None)
            if edge is None:
                errors.append(f"world_streaming: arista de ruta inexistente {edge_id}")
                continue
            for lat, lon, _ in edge.get("shape", []):
                origin = projection["origin"]
                x = (float(lon) - float(origin[1])) * float(projection["meters_per_degree_lon"]) * float(
                    projection["world_scale"]
                )
                z = -(float(lat) - float(origin[0])) * float(projection["meters_per_degree_lat"]) * float(
                    projection["world_scale"]
                )
                key = f"{math.floor(x / sector_size)}_{math.floor(z / sector_size)}"
                if key not in actual:
                    errors.append(f"world_streaming: ruta sin sector horneado {key}")
                    break

    if not sectors_dir.exists():
        warnings.append("world_streaming: directorio de sectores ausente")
    return errors, warnings


def main() -> int:
    errors, warnings = load_and_validate(ROOT)
    for warning in warnings:
        print(f"[WARN] {warning}")
    for error in errors:
        print(f"[ERROR] {error}")
    if errors:
        print(f"\n[FAIL] {len(errors)} errores de sectores.")
        return 1
    manifest = load_json(MANIFEST)
    print(
        f"[OK] Sectores de 800 m válidos: {manifest.get('sector_count')} recursos, "
        f"{manifest.get('total_bytes')} bytes, {manifest.get('total_terrain_triangles')} triángulos de terreno."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
