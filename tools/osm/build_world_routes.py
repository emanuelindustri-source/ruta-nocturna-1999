#!/usr/bin/env python3
"""Pipeline de rutas del mundo (F4.1).

Descarga la red vial de Venezuela desde Overpass, construye el grafo, calcula
caminos principales y alternativos, muestrea elevación DEM y escribe una red
comprimida y reproducible en `data/content/world/`.

El artefacto versionado es pequeño (texto JSON); las respuestas crudas de
Overpass, las teselas DEM y las imágenes de evidencia viven en `build/` y no se
versionan. La red es una base de datos derivada de OpenStreetMap y se publica
bajo ODbL 1.0.

Comandos:
  .venv\\Scripts\\python.exe tools\\osm\\build_world_routes.py
  .venv\\Scripts\\python.exe tools\\osm\\build_world_routes.py --refresh
  .venv\\Scripts\\python.exe tools\\osm\\build_world_routes.py --offline
  .venv\\Scripts\\python.exe tools\\osm\\build_world_routes.py --check
"""

from __future__ import annotations

import argparse
import hashlib
import heapq
import io
import json
import math
import os
import sys
import time
import urllib.parse
import urllib.request
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from route_graph_validation import (  # noqa: E402
    build_adjacency,
    hav_m,
    load_and_validate,
    validate_network,
)

ROOT = Path(__file__).resolve().parents[2]
CONTRACT_PATH = ROOT / "data" / "schemas" / "world_routes.json"
TOOL_VERSION = "1.0.0"
USER_AGENT = "RutaNocturna1999/0.4.0 world-routes pipeline (+https://github.com/emanuelindustri-source/ruta-nocturna-1999)"
EARTH_RADIUS_M = 6371000.0
MAX_GRADE_WINDOW_M = 1000.0

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")


def log(message: str) -> None:
    print(f"[ROUTES] {message}", flush=True)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical_json(document: Any, indent: int = 1) -> bytes:
    return (
        json.dumps(document, ensure_ascii=False, indent=indent, separators=(",", ": "))
        + "\n"
    ).encode("utf-8")


def write_atomic(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_bytes(data)
    os.replace(temporary, path)


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def duplicate_values_local(values: list[str]) -> list[str]:
    seen: set[str] = set()
    duplicates: list[str] = []
    for value in values:
        if value in seen and value not in duplicates:
            duplicates.append(value)
        seen.add(value)
    return duplicates


def node_key(lat: float, lon: float, decimals: int = 7) -> tuple[float, float]:
    return (round(float(lat), decimals), round(float(lon), decimals))


def edge_key(a: tuple[float, float], b: tuple[float, float]) -> tuple[tuple[float, float], tuple[float, float]]:
    return (a, b) if a <= b else (b, a)


def fetch_url(url: str, data: bytes | None = None, timeout: int = 900, attempts: int = 3) -> bytes:
    last_error: Exception | None = None
    for attempt in range(1, attempts + 1):
        try:
            request = urllib.request.Request(
                url,
                data=data,
                headers={"User-Agent": USER_AGENT, "Accept": "*/*"},
            )
            started = time.time()
            with urllib.request.urlopen(request, timeout=timeout) as response:
                body = response.read()
            if not body:
                raise ValueError("respuesta vacía")
            log(f"HTTP {response.status} {len(body)} bytes en {time.time() - started:.1f}s: {url.split('?')[0]}")
            return body
        except Exception as exc:  # noqa: BLE001
            last_error = exc
            log(f"reintento {attempt}/{attempts} falló: {type(exc).__name__}: {str(exc)[:160]}")
            if attempt < attempts:
                time.sleep(2.0 * attempt)
    raise RuntimeError(f"No se pudo descargar {url}: {last_error}")


def overpass_query_text(query: dict[str, Any]) -> str:
    min_lat, min_lon, max_lat, max_lon = query["bbox"]
    return (
        f'[out:json][timeout:900];'
        f'way({min_lat},{min_lon},{max_lat},{max_lon})'
        f'[highway~"{query["highway_regex"]}"];'
        f'out tags geom;'
    )


def load_sources(
    contract: dict[str, Any],
    refresh: bool,
    offline: bool,
) -> list[dict[str, Any]]:
    cache_dir = ROOT / contract["extract"]["raw_cache_dir"]
    cache_dir.mkdir(parents=True, exist_ok=True)
    endpoints = list(contract["extract"]["endpoint_priority"])
    sources: list[dict[str, Any]] = []
    for query in contract["extract"]["queries"]:
        query_text = overpass_query_text(query)
        query_hash = sha256_bytes(query_text.encode("utf-8"))[:12]
        cache_path = cache_dir / f"{query['id']}_{query_hash}.json"
        if cache_path.exists() and not refresh:
            body = cache_path.read_bytes()
            endpoint = "cache"
            log(f"usando caché {cache_path.name} ({len(body)} bytes)")
        else:
            if offline:
                raise RuntimeError(
                    f"Modo offline: falta la caché {cache_path.relative_to(ROOT)}. "
                    "Ejecuta sin --offline o con --refresh en una máquina con red."
                )
            body = b""
            endpoint = ""
            for candidate in endpoints:
                try:
                    body = fetch_url(
                        candidate + "?data=" + urllib.parse.quote(query_text),
                        timeout=1000,
                        attempts=2,
                    )
                    endpoint = candidate
                    break
                except Exception as exc:  # noqa: BLE001
                    log(f"endpoint {candidate} falló: {str(exc)[:160]}")
            if not body:
                raise RuntimeError(f"No hay endpoint Overpass disponible para {query['id']}")
            write_atomic(cache_path, body)
        try:
            document = json.loads(body.decode("utf-8"))
        except Exception as exc:  # noqa: BLE001
            raise RuntimeError(f"JSON inválido en {query['id']}: {exc}") from exc
        elements = document.get("elements", [])
        way_count = sum(1 for element in elements if element.get("type") == "way")
        sources.append(
            {
                "id": query["id"],
                "query": query_text,
                "highway_regex": query["highway_regex"],
                "bbox": query["bbox"],
                "path": cache_path.relative_to(ROOT).as_posix(),
                "sha256": sha256_bytes(body),
                "bytes": len(body),
                "endpoint": endpoint,
                "osm_base_timestamp": document.get("osm3s", {}).get("timestamp_osm_base", ""),
                "way_count": way_count,
                "elements": elements,
            }
        )
        log(f"fuente {query['id']}: {way_count} ways, base {sources[-1]['osm_base_timestamp']}")
    return sources


def parse_graph(
    sources: list[dict[str, Any]],
    contract: dict[str, Any],
) -> tuple[
    dict[tuple[float, float], dict[tuple[float, float], dict[str, Any]]],
    int,
    int,
]:
    classes = contract["highway_classes"]
    speeds = {name: float(entry["design_speed_kph"]) for name, entry in classes.items()}
    adjacency: dict[tuple[float, float], dict[tuple[float, float], dict[str, Any]]] = {}
    way_count = 0
    raw_nodes: set[tuple[float, float]] = set()

    def better(candidate: dict[str, Any], current: dict[str, Any]) -> bool:
        candidate_speed = speeds[candidate["highway"]]
        current_speed = speeds[current["highway"]]
        if candidate_speed != current_speed:
            return candidate_speed > current_speed
        return candidate["dist"] < current["dist"]

    for source in sources:
        for element in source["elements"]:
            if element.get("type") != "way" or "geometry" not in element:
                continue
            tags = element.get("tags", {})
            highway = tags.get("highway")
            if highway not in classes:
                continue
            geometry = [
                node_key(point["lat"], point["lon"])
                for point in element.get("geometry", [])
                if point is not None
            ]
            if len(geometry) < 2:
                continue
            way_count += 1
            ref = tags.get("ref")
            for index in range(len(geometry) - 1):
                start = geometry[index]
                end = geometry[index + 1]
                if start == end:
                    continue
                raw_nodes.add(start)
                raw_nodes.add(end)
                distance = hav_m(start, end)
                if distance <= 0.0:
                    continue
                meta = {
                    "dist": distance,
                    "highway": highway,
                    "ref": ref,
                    "way_id": element.get("id"),
                    "source": source["id"],
                }
                neighbours = adjacency.setdefault(start, {})
                existing = neighbours.get(end)
                if existing is None or better(meta, existing):
                    neighbours[end] = meta
                    adjacency.setdefault(end, {})[start] = meta
    return adjacency, way_count, len(raw_nodes)


def build_spatial_grid(
    nodes: list[tuple[float, float]],
    cell_degrees: float = 0.05,
) -> dict[tuple[int, int], list[tuple[float, float]]]:
    grid: dict[tuple[int, int], list[tuple[float, float]]] = defaultdict(list)
    for node in nodes:
        grid[(int(math.floor(node[0] / cell_degrees)), int(math.floor(node[1] / cell_degrees)))].append(node)
    return grid


def snap_hubs(
    adjacency: dict[tuple[float, float], dict[tuple[float, float], dict[str, Any]]],
    contract: dict[str, Any],
) -> dict[str, tuple[tuple[float, float], float]]:
    keys = list(adjacency.keys())
    grid = build_spatial_grid(keys)
    cell = 0.05
    snapped: dict[str, tuple[tuple[float, float], float]] = {}
    for region in contract["regions"]:
        center = (float(region["center"][0]), float(region["center"][1]))
        best_node: tuple[float, float] | None = None
        best_distance = float("inf")
        center_cell = (int(math.floor(center[0] / cell)), int(math.floor(center[1] / cell)))
        for radius in range(0, 21):
            for dx in range(-radius, radius + 1):
                for dy in range(-radius, radius + 1):
                    if radius > 0 and max(abs(dx), abs(dy)) != radius:
                        continue
                    for node in grid.get((center_cell[0] + dx, center_cell[1] + dy), []):
                        distance = hav_m(node, center)
                        if distance < best_distance:
                            best_distance = distance
                            best_node = node
            if best_node is not None and best_distance <= 1000.0:
                break
        if best_node is None:
            raise RuntimeError(f"No hay nodo OSM cerca de {region['id']}")
        snapped[region["id"]] = (best_node, best_distance)
        log(
            f"hub {region['id']} -> {best_node[0]:.6f},{best_node[1]:.6f} "
            f"({best_distance:.0f} m)"
        )
        if best_distance > float(contract["graph_rules"]["snap_max_offset_m"]):
            raise RuntimeError(f"El hub {region['id']} queda a {best_distance:.0f} m de la red")
    return snapped


def dijkstra(
    adjacency: dict[tuple[float, float], dict[tuple[float, float], dict[str, Any]]],
    speeds: dict[str, float],
    start: tuple[float, float],
    goal: tuple[float, float],
    penalty: dict[tuple[tuple[float, float], tuple[float, float]], float] | None = None,
) -> dict[str, Any] | None:
    penalty = penalty or {}
    best: dict[tuple[float, float], float] = {start: 0.0}
    previous: dict[tuple[float, float], tuple[float, float]] = {}
    queue: list[tuple[float, tuple[float, float]]] = [(0.0, start)]
    visited: set[tuple[float, float]] = set()
    while queue:
        cost, current = heapq.heappop(queue)
        if current in visited:
            continue
        visited.add(current)
        if current == goal:
            break
        for neighbour, meta in adjacency.get(current, {}).items():
            base = meta["dist"] / (speeds[meta["highway"]] / 3.6)
            multiplier = penalty.get(edge_key(current, neighbour), 1.0)
            candidate = cost + base * multiplier
            if candidate < best.get(neighbour, float("inf")):
                best[neighbour] = candidate
                previous[neighbour] = current
                heapq.heappush(queue, (candidate, neighbour))
    if goal not in best:
        return None
    path = [goal]
    while path[-1] != start:
        path.append(previous[path[-1]])
    path.reverse()
    distance = 0.0
    travel_time = 0.0
    for index in range(len(path) - 1):
        meta = adjacency[path[index]][path[index + 1]]
        distance += meta["dist"]
        travel_time += meta["dist"] / (speeds[meta["highway"]] / 3.6)
    return {"path": path, "distance_m": distance, "travel_time_s": travel_time}


def path_edges(path: list[tuple[float, float]]) -> list[tuple[tuple[float, float], tuple[float, float], float]]:
    return [
        (path[index], path[index + 1], hav_m(path[index], path[index + 1]))
        for index in range(len(path) - 1)
    ]


def overlap_ratio(
    path: list[tuple[float, float]],
    reference: list[tuple[float, float]],
) -> float:
    reference_edges = {edge_key(a, b) for a, b, _ in path_edges(reference)}
    total = 0.0
    shared = 0.0
    for a, b, distance in path_edges(path):
        total += distance
        if edge_key(a, b) in reference_edges:
            shared += distance
    return shared / total if total else 1.0


def generate_routes(
    adjacency: dict[tuple[float, float], dict[tuple[float, float], dict[str, Any]]],
    speeds: dict[str, float],
    snapped: dict[str, tuple[tuple[float, float], float]],
    contract: dict[str, Any],
) -> list[dict[str, Any]]:
    penalty_factor = float(contract["alternatives"]["penalty_factor"])
    max_candidates = int(contract["alternatives"]["max_candidates"])
    results: list[dict[str, Any]] = []
    for requirement in contract["routes"]:
        route_id = requirement["id"]
        start = snapped[requirement["from_region"]][0]
        goal = snapped[requirement["to_region"]][0]
        log(f"ruta {route_id}: {requirement['from_region']} -> {requirement['to_region']}")
        main = dijkstra(adjacency, speeds, start, goal)
        if main is None:
            raise RuntimeError(f"No hay camino OSM para {route_id}")
        main_key = tuple(main["path"])
        log(f"  principal {main['distance_m'] / 1000:.1f} km, {len(main['path'])} puntos")
        penalty: dict[tuple[tuple[float, float], tuple[float, float]], float] = {}
        for a, b, _ in path_edges(main["path"]):
            penalty[edge_key(a, b)] = penalty_factor
        alternatives: list[dict[str, Any]] = []
        seen = {main_key}
        for attempt in range(max_candidates * 3):
            candidate = dijkstra(adjacency, speeds, start, goal, penalty)
            if candidate is None:
                break
            candidate_key = tuple(candidate["path"])
            if candidate_key in seen:
                for a, b, _ in path_edges(candidate["path"]):
                    penalty[edge_key(a, b)] = penalty.get(edge_key(a, b), 1.0) * penalty_factor
                continue
            seen.add(candidate_key)
            overlap = overlap_ratio(candidate["path"], main["path"])
            detour = candidate["distance_m"] / main["distance_m"]
            accepted = (
                overlap <= float(requirement["max_overlap_ratio"]) + 1e-6
                and detour <= float(requirement["max_detour_ratio"]) + 1e-6
            )
            if accepted:
                alternatives.append(
                    {
                        "path": candidate["path"],
                        "distance_m": candidate["distance_m"],
                        "travel_time_s": candidate["travel_time_s"],
                        "overlap_ratio_vs_main": overlap,
                        "detour_ratio_vs_main": detour,
                    }
                )
                log(
                    f"  alternativa {len(alternatives)}: {candidate['distance_m'] / 1000:.1f} km, "
                    f"desvío {detour:.2f}, solape {overlap:.2f}"
                )
            for a, b, _ in path_edges(candidate["path"]):
                penalty[edge_key(a, b)] = penalty.get(edge_key(a, b), 1.0) * penalty_factor
            if len(alternatives) >= int(requirement["max_alternatives"]):
                break
        alternatives.sort(key=lambda entry: (entry["detour_ratio_vs_main"], entry["overlap_ratio_vs_main"]))
        alternatives = alternatives[: int(requirement["max_alternatives"])]
        if len(alternatives) < int(requirement["min_alternatives"]):
            raise RuntimeError(
                f"{route_id} solo tiene {len(alternatives)} alternativas válidas; "
                f"mínimo {requirement['min_alternatives']}"
            )
        results.append(
            {
                "requirement": requirement,
                "main": {
                    "path": main["path"],
                    "distance_m": main["distance_m"],
                    "travel_time_s": main["travel_time_s"],
                    "overlap_ratio_vs_main": 0.0,
                    "detour_ratio_vs_main": 1.0,
                },
                "alternatives": alternatives,
            }
        )
    return results


def simplify_douglas_peucker(
    points: list[tuple[float, float]],
    tolerance_m: float,
) -> list[tuple[float, float]]:
    if len(points) <= 2:
        return list(points)
    origin = points[0]
    cos_lat = math.cos(math.radians(origin[0]))

    def project(point: tuple[float, float]) -> tuple[float, float]:
        x = math.radians(point[1] - origin[1]) * cos_lat * EARTH_RADIUS_M
        y = math.radians(point[0] - origin[0]) * EARTH_RADIUS_M
        return (x, y)

    projected = [project(point) for point in points]
    keep = [False] * len(points)
    keep[0] = True
    keep[-1] = True
    stack = [(0, len(points) - 1)]
    while stack:
        first, last = stack.pop()
        if last <= first + 1:
            continue
        ax, ay = projected[first]
        bx, by = projected[last]
        dx = bx - ax
        dy = by - ay
        length_sq = dx * dx + dy * dy
        farthest = -1
        farthest_distance = 0.0
        for index in range(first + 1, last):
            px, py = projected[index]
            if length_sq == 0.0:
                distance = math.hypot(px - ax, py - ay)
            else:
                t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / length_sq))
                distance = math.hypot(px - (ax + t * dx), py - (ay + t * dy))
            if distance > farthest_distance:
                farthest_distance = distance
                farthest = index
        if farthest_distance > tolerance_m:
            keep[farthest] = True
            stack.append((first, farthest))
            stack.append((farthest, last))
    return [point for index, point in enumerate(points) if keep[index]]


def resample_polyline(
    points: list[tuple[float, float]],
    spacing_m: float,
) -> list[tuple[float, float]]:
    if len(points) < 2:
        return list(points)
    result = [points[0]]
    for index in range(len(points) - 1):
        start = points[index]
        end = points[index + 1]
        segment = hav_m(start, end)
        if segment <= spacing_m:
            result.append(end)
            continue
        steps = int(math.ceil(segment / spacing_m))
        for step in range(1, steps + 1):
            ratio = step / steps
            lat = start[0] + (end[0] - start[0]) * ratio
            lon = start[1] + (end[1] - start[1]) * ratio
            result.append((lat, lon))
    # Elimina duplicados consecutivos.
    cleaned: list[tuple[float, float]] = []
    for point in result:
        if not cleaned or point != cleaned[-1]:
            cleaned.append(point)
    if cleaned[-1] != points[-1]:
        cleaned.append(points[-1])
    return cleaned


def resample_by_distance(
    points: list[tuple[float, float]],
    spacing_m: float,
) -> tuple[list[tuple[float, float]], list[float]]:
    """Muestrea la polilínea por distancia recorrida, no por cercanía espacial.

    Devuelve los puntos y la distancia de recorrido acumulada de cada muestra.
    Así una carretera de montaña con horquillas conserva un perfil de elevación
    coherente con la distancia real del recorrido y no con la distancia en línea
    recta entre dos puntos de la curva.
    """
    if len(points) < 2:
        return list(points), [0.0]
    cumulative = [0.0]
    for index in range(len(points) - 1):
        cumulative.append(cumulative[-1] + hav_m(points[index], points[index + 1]))
    total = cumulative[-1]
    if total <= 0:
        return list(points), [0.0]
    targets: list[float] = []
    distance = 0.0
    while distance < total:
        targets.append(distance)
        distance += spacing_m
    targets.append(total)
    result: list[tuple[float, float]] = []
    segment = 0
    for target in targets:
        while segment < len(points) - 2 and cumulative[segment + 1] < target:
            segment += 1
        start = points[segment]
        end = points[segment + 1]
        span = cumulative[segment + 1] - cumulative[segment]
        ratio = 0.0 if span <= 0 else max(0.0, min(1.0, (target - cumulative[segment]) / span))
        result.append(
            (
                start[0] + (end[0] - start[0]) * ratio,
                start[1] + (end[1] - start[1]) * ratio,
            )
        )
    return result, targets


def smooth_elevations(values: list[float]) -> list[float]:
    if len(values) < 3:
        return list(values)
    smoothed = [values[0]]
    for index in range(1, len(values) - 1):
        smoothed.append((values[index - 1] + values[index] + values[index + 1]) / 3.0)
    smoothed.append(values[-1])
    return smoothed


def sanitize_elevations(values: list[float]) -> list[float]:
    """Elimina picos aislados de DEM (huecos, teselas sin dato) sin aplanar el perfil."""
    cleaned = list(values)
    for index in range(1, len(values) - 1):
        previous_value = values[index - 1]
        current_value = values[index]
        next_value = values[index + 1]
        if current_value < -20.0 or current_value > 5000.0:
            cleaned[index] = (previous_value + next_value) / 2.0
        elif abs(current_value - previous_value) > 300.0 and abs(current_value - next_value) > 300.0:
            cleaned[index] = (previous_value + next_value) / 2.0
    return cleaned


def terrain_metrics(
    arc_distance_m: list[float],
    elevations: list[float],
) -> tuple[float, float, float]:
    ascent = 0.0
    descent = 0.0
    max_grade = 0.0
    for index in range(len(elevations) - 1):
        distance = arc_distance_m[index + 1] - arc_distance_m[index]
        if distance < 1.0:
            continue
        delta = elevations[index + 1] - elevations[index]
        if delta > 0.5:
            ascent += delta
        elif delta < -0.5:
            descent -= delta
        if distance >= 50.0:
            max_grade = max(max_grade, abs(delta) / distance * 100.0)
    return ascent, descent, max_grade


class DemSampler:
    def __init__(self, contract: dict[str, Any], refresh: bool, offline: bool) -> None:
        self.contract = contract
        self.zoom = int(contract["dem"]["zoom"])
        self.tile_url = contract["dem"]["tile_url"]
        self.cache_dir = ROOT / contract["dem"]["cache_dir"]
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.refresh = refresh
        self.offline = offline
        self.tiles: dict[tuple[int, int], Image.Image] = {}
        self.tile_info: dict[tuple[int, int], dict[str, Any]] = {}

    def tile_xy(self, lat: float, lon: float) -> tuple[int, int, float, float]:
        count = 2 ** self.zoom
        x = (lon + 180.0) / 360.0 * count
        lat_rad = math.radians(lat)
        y = (
            1.0
            - math.log(math.tan(lat_rad) + 1.0 / math.cos(lat_rad)) / math.pi
        ) / 2.0 * count
        tile_x = int(math.floor(x))
        tile_y = int(math.floor(y))
        return tile_x, tile_y, x - tile_x, y - tile_y

    def _load_tile(self, tile_x: int, tile_y: int) -> None:
        key = (tile_x, tile_y)
        if key in self.tiles:
            return
        path = self.cache_dir / f"{self.zoom}_{tile_x}_{tile_y}.png"
        if path.exists() and not self.refresh:
            body = path.read_bytes()
        else:
            if self.offline:
                raise RuntimeError(f"Modo offline: falta la tesela DEM {path.name}")
            url = self.tile_url.format(z=self.zoom, x=tile_x, y=tile_y)
            body = fetch_url(url, timeout=120, attempts=3)
            write_atomic(path, body)
        image = Image.open(io.BytesIO(body)).convert("RGB")
        self.tiles[key] = image
        self.tile_info[key] = {"sha256": sha256_bytes(body), "bytes": len(body)}

    def prefetch(self, points: list[tuple[float, float]]) -> None:
        needed: set[tuple[int, int]] = set()
        for lat, lon in points:
            tile_x, tile_y, _, _ = self.tile_xy(lat, lon)
            needed.add((tile_x, tile_y))
        missing = [
            key
            for key in needed
            if key not in self.tiles
            and (self.refresh or not (self.cache_dir / f"{self.zoom}_{key[0]}_{key[1]}.png").exists())
        ]
        log(f"teselas DEM: {len(needed)} necesarias, {len(missing)} por descargar")
        if missing and not self.offline:
            with ThreadPoolExecutor(max_workers=8) as executor:
                futures = {
                    executor.submit(self._load_tile, tile_x, tile_y): (tile_x, tile_y)
                    for tile_x, tile_y in sorted(missing)
                }
                for index, future in enumerate(as_completed(futures), start=1):
                    future.result()
                    if index % 50 == 0 or index == len(missing):
                        log(f"  teselas {index}/{len(missing)}")
        for tile_x, tile_y in sorted(needed):
            self._load_tile(tile_x, tile_y)

    def sample(self, lat: float, lon: float) -> float:
        tile_x, tile_y, fractional_x, fractional_y = self.tile_xy(lat, lon)
        image = self.tiles[(tile_x, tile_y)]
        width, height = image.size
        px = min(width - 1.0, max(0.0, fractional_x * width - 0.5))
        py = min(height - 1.0, max(0.0, fractional_y * height - 0.5))
        x0, y0 = int(px), int(py)
        x1, y1 = min(width - 1, x0 + 1), min(height - 1, y0 + 1)
        tx, ty = px - x0, py - y0

        def elevation(pixel: tuple[int, int, int]) -> float:
            red, green, blue = pixel
            return (red * 256.0 + green + blue / 256.0) - 32768.0

        top = elevation(image.getpixel((x0, y0))) * (1 - tx) + elevation(image.getpixel((x1, y0))) * tx
        bottom = elevation(image.getpixel((x0, y1))) * (1 - tx) + elevation(image.getpixel((x1, y1))) * tx
        return top * (1 - ty) + bottom * ty

    def summary(self) -> dict[str, Any]:
        lines = [
            f"{self.zoom}/{tile_x}/{tile_y}:{info['sha256']}"
            for (tile_x, tile_y), info in sorted(self.tile_info.items())
        ]
        return {
            "source": self.contract["dem"]["source"],
            "zoom": self.zoom,
            "tile_count": len(self.tile_info),
            "bytes": sum(info["bytes"] for info in self.tile_info.values()),
            "keys_sha256": sha256_bytes(("\n".join(lines) + "\n").encode("utf-8")),
            "attribution_url": self.contract["dem"]["attribution_url"],
        }


def build_union_graph(
    results: list[dict[str, Any]],
    adjacency: dict[tuple[float, float], dict[tuple[float, float], dict[str, Any]]],
) -> tuple[
    dict[tuple[float, float], dict[tuple[float, float], dict[str, Any]]],
    dict[tuple[tuple[float, float], tuple[float, float]], set[str]],
]:
    union: dict[tuple[float, float], dict[tuple[float, float], dict[str, Any]]] = {}
    usage: dict[tuple[tuple[float, float], tuple[float, float]], set[str]] = defaultdict(set)
    for result in results:
        route_id = result["requirement"]["id"]
        entries = [("main", 0, result["main"])]
        for index, alternative in enumerate(result["alternatives"], start=1):
            entries.append(("alternative", index, alternative))
        for kind, index, entry in entries:
            route_key = f"{route_id}#{kind}#{index}"
            path = entry["path"]
            for position in range(len(path) - 1):
                start = path[position]
                end = path[position + 1]
                usage[edge_key(start, end)].add(route_key)
                meta = adjacency[start][end]
                union.setdefault(start, {})[end] = meta
                union.setdefault(end, {})[start] = meta
    return union, usage


def collect_important_nodes(
    union: dict[tuple[float, float], dict[tuple[float, float], dict[str, Any]]],
    usage: dict[tuple[tuple[float, float], tuple[float, float]], set[str]],
    base: set[tuple[float, float]],
    max_edge_length_m: float,
) -> tuple[set[tuple[float, float]], set[tuple[float, float]]]:
    important = set(base)
    forced: set[tuple[float, float]] = set()
    for node, neighbours in union.items():
        if len(neighbours) != 2:
            important.add(node)
            continue
        classes = {neighbours[neighbour]["highway"] for neighbour in neighbours}
        usages = {frozenset(usage[edge_key(node, neighbour)]) for neighbour in neighbours}
        if len(classes) > 1 or len(usages) > 1:
            important.add(node)
    while True:
        changed = False
        visited: set[tuple[tuple[float, float], tuple[float, float]]] = set()
        for start in sorted(important):
            for neighbour in sorted(union.get(start, {})):
                key = edge_key(start, neighbour)
                if key in visited:
                    continue
                visited.add(key)
                previous, current = start, neighbour
                length = union[start][neighbour]["dist"]
                while current not in important:
                    if length >= max_edge_length_m:
                        important.add(current)
                        forced.add(current)
                        changed = True
                        break
                    candidates = [node for node in union[current] if node != previous]
                    if len(candidates) != 1:
                        important.add(current)
                        forced.add(current)
                        changed = True
                        break
                    next_node = candidates[0]
                    next_distance = union[current][next_node]["dist"]
                    if length + next_distance > max_edge_length_m:
                        important.add(current)
                        forced.add(current)
                        changed = True
                        break
                    next_key = edge_key(current, next_node)
                    if next_key in visited:
                        important.add(current)
                        forced.add(current)
                        changed = True
                        break
                    visited.add(next_key)
                    length += next_distance
                    previous, current = current, next_node
        if not changed:
            break
    return important, forced


def compress_graph(
    union: dict[tuple[float, float], dict[tuple[float, float], dict[str, Any]]],
    usage: dict[tuple[tuple[float, float], tuple[float, float]], set[str]],
    important: set[tuple[float, float]],
    forced: set[tuple[float, float]],
    hubs_by_key: dict[tuple[float, float], str],
    contract: dict[str, Any],
) -> tuple[
    dict[str, dict[str, Any]],
    list[dict[str, Any]],
    dict[tuple[tuple[float, float], tuple[float, float]], str],
    dict[tuple[float, float], str],
]:
    def node_id(key: tuple[float, float]) -> str:
        if key in hubs_by_key:
            return hubs_by_key[key]
        digest = hashlib.sha1(f"{key[0]:.6f},{key[1]:.6f}".encode("utf-8")).hexdigest()[:8]
        return f"node_{digest}"

    visited: set[tuple[tuple[float, float], tuple[float, float]]] = set()
    raw_edges: list[dict[str, Any]] = []
    edge_lookup: dict[tuple[tuple[float, float], tuple[float, float]], str] = {}
    node_ids: dict[tuple[float, float], str] = {}
    for key in important:
        node_ids[key] = node_id(key)

    for start in sorted(important):
        for neighbour in sorted(union.get(start, {})):
            key = edge_key(start, neighbour)
            if key in visited:
                continue
            visited.add(key)
            chain = [start, neighbour]
            previous, current = start, neighbour
            while current not in important:
                candidates = [node for node in union[current] if node != previous]
                if len(candidates) != 1:
                    raise RuntimeError(f"Cadena rota en {current}")
                next_node = candidates[0]
                visited.add(edge_key(current, next_node))
                chain.append(next_node)
                previous, current = current, next_node
            if current not in node_ids:
                node_ids[current] = node_id(current)
            classes = Counter()
            refs = Counter()
            for index in range(len(chain) - 1):
                meta = union[chain[index]][chain[index + 1]]
                classes[meta["highway"]] += meta["dist"]
                if meta.get("ref"):
                    refs[meta["ref"]] += meta["dist"]
            dominant_class = classes.most_common(1)[0][0]
            dominant_ref = refs.most_common(1)[0][0] if refs else None
            start_id = node_ids[start]
            end_id = node_ids[current]
            fingerprint = "|".join(
                f"{point[0]:.6f},{point[1]:.6f}" for point in chain[:3]
            )
            digest_source = (
                f"{sorted([start_id, end_id])[0]}|{sorted([start_id, end_id])[1]}|{fingerprint}"
            )
            edge_id = "edge_" + hashlib.sha1(digest_source.encode("utf-8")).hexdigest()[:8]
            raw_edges.append(
                {
                    "id": edge_id,
                    "from_key": start,
                    "to_key": current,
                    "from": start_id,
                    "to": end_id,
                    "chain": chain,
                    "road_class": dominant_class,
                    "ref": dominant_ref,
                }
            )
            for index in range(len(chain) - 1):
                edge_lookup[edge_key(chain[index], chain[index + 1])] = edge_id

    # Los IDs de arista deben ser únicos; si no, la geometría paralela necesita
    # una revisión explícita en vez de un sufijo silencioso.
    duplicate_edges = duplicate_values_local([edge["id"] for edge in raw_edges])
    if duplicate_edges:
        raise RuntimeError(f"IDs de arista duplicados: {duplicate_edges[:5]}")
    duplicate_nodes = duplicate_values_local(list(node_ids.values()))
    if duplicate_nodes:
        raise RuntimeError(f"IDs de nodo duplicados: {duplicate_nodes[:5]}")

    node_meta: dict[str, dict[str, Any]] = {}
    for key, nid in node_ids.items():
        node_meta[nid] = {
            "key": key,
            "kind": "hub" if key in hubs_by_key else ("waypoint" if key in forced else "junction"),
        }

    return node_meta, raw_edges, edge_lookup, node_ids


def nearest_region(
    geo: tuple[float, float],
    contract: dict[str, Any],
) -> str | None:
    best: str | None = None
    best_distance = float("inf")
    for region in contract["regions"]:
        distance = hav_m(geo, region["center"])
        if distance <= float(region["radius_km"]) * 1000.0 and distance < best_distance:
            best = region["id"]
            best_distance = distance
    return best


def edge_regions(
    shape: list[list[float]],
    contract: dict[str, Any],
) -> list[str]:
    seen: list[str] = []
    for point in shape:
        region = nearest_region((float(point[0]), float(point[1])), contract)
        if region and region not in seen:
            seen.append(region)
    return seen


def build_artifact(
    contract: dict[str, Any],
    sources: list[dict[str, Any]],
    adjacency: dict[tuple[float, float], dict[tuple[float, float], dict[str, Any]]],
    nodes: dict[str, dict[str, Any]],
    edges: list[dict[str, Any]],
    routes: list[dict[str, Any]],
    snapped: dict[str, tuple[tuple[float, float], float]],
) -> dict[str, Any]:
    projection = contract["projection"]
    query_bboxes = [query["bbox"] for query in contract["extract"]["queries"]]
    extract_bbox = [
        min(bbox[0] for bbox in query_bboxes),
        min(bbox[1] for bbox in query_bboxes),
        max(bbox[2] for bbox in query_bboxes),
        max(bbox[3] for bbox in query_bboxes),
    ]
    timestamps = [source["osm_base_timestamp"] for source in sources if source["osm_base_timestamp"]]
    osm_timestamp = max(timestamps) if timestamps else ""
    node_list: list[dict[str, Any]] = []
    for nid in sorted(nodes):
        entry = nodes[nid]
        node_list.append(
            {
                "id": nid,
                "kind": entry["kind"],
                "region": entry["region"],
                "geo": [round(entry["key"][0], 6), round(entry["key"][1], 6)],
                "elevation_m": round(entry["elevation_m"], 1),
                "game_m": [
                    round(entry["game_m"][0], 1),
                    round(entry["game_m"][1], 1),
                ],
                "degree": entry["degree"],
            }
        )

    edge_list: list[dict[str, Any]] = []
    for edge in sorted(edges, key=lambda item: item["id"]):
        edge_list.append(
            {
                "id": edge["id"],
                "from": edge["from"],
                "to": edge["to"],
                "road_class": edge["road_class"],
                "ref": edge["ref"],
                "distance_m": round(edge["distance_m"], 1),
                "travel_time_s": round(edge["travel_time_s"], 1),
                "cost": round(edge["travel_time_s"], 1),
                "ascent_m": round(edge["ascent_m"], 1),
                "descent_m": round(edge["descent_m"], 1),
                "min_elevation_m": round(edge["min_elevation_m"], 1),
                "max_elevation_m": round(edge["max_elevation_m"], 1),
                "max_grade_pct": round(edge["max_grade_pct"], 1),
                "regions": edge["regions"],
                "shape": [
                    [round(point[0], 6), round(point[1], 6), round(point[2], 1)]
                    for point in edge["shape"]
                ],
            }
        )

    route_list: list[dict[str, Any]] = []
    for route in sorted(routes, key=lambda item: (item["id"], item["alternative_index"])):
        route_list.append(
            {
                "id": route["id"],
                "from": route["from"],
                "to": route["to"],
                "kind": route["kind"],
                "alternative_index": route["alternative_index"],
                "distance_m": round(route["distance_m"], 1),
                "travel_time_s": round(route["travel_time_s"], 1),
                "ascent_m": round(route["ascent_m"], 1),
                "descent_m": round(route["descent_m"], 1),
                "min_elevation_m": round(route["min_elevation_m"], 1),
                "max_elevation_m": round(route["max_elevation_m"], 1),
                "node_ids": route["node_ids"],
                "edge_ids": route["edge_ids"],
                "overlap_ratio_vs_main": round(route["overlap_ratio_vs_main"], 4),
                "detour_ratio_vs_main": round(route["detour_ratio_vs_main"], 4),
                "region_sequence": route["region_sequence"],
            }
        )

    hubs = [node for node in nodes.values() if node["kind"] == "hub"]
    main_routes = [route for route in routes if route["kind"] == "main"]
    alternatives = [route for route in routes if route["kind"] == "alternative"]
    elevations = [entry["elevation_m"] for entry in nodes.values()]
    region_summaries: list[dict[str, Any]] = []
    for region in contract["regions"]:
        hub_id = region["hub_node"]
        hub = nodes[hub_id]
        expected = region["elevation_expected_m"]
        region_summaries.append(
            {
                "id": region["id"],
                "center": region["center"],
                "hub_node": hub_id,
                "elevation_m": round(hub["elevation_m"], 1),
                "elevation_expected_m": expected,
                "snap_offset_m": round(snapped[region["id"]][1], 1),
                "within_expected": expected[0] <= hub["elevation_m"] <= expected[1],
                "terrain_character": region["terrain_character"],
            }
        )

    artifact = {
        "schema_version": 1,
        "artifact_version": 1,
        "contract_id": contract["contract_id"],
        "world_id": contract["world_id"],
        "coordinate_system": "WGS84",
        "elevation_unit": "m",
        "source": {
            "osm_base_timestamp": osm_timestamp,
            "extract_bbox": extract_bbox,
            "queries": [
                {
                    "id": source["id"],
                    "highway_regex": source["highway_regex"],
                    "osm_base_timestamp": source["osm_base_timestamp"],
                    "sha256": source["sha256"],
                    "bytes": source["bytes"],
                    "way_count": source["way_count"],
                }
                for source in sources
            ],
            "way_count": sum(source["way_count"] for source in sources),
            "raw_node_count": len(adjacency),
            "license": "ODbL 1.0",
            "copyright": contract["attribution"]["copyright"],
        },
        "projection": {
            "mode": projection["mode"],
            "origin": projection["origin"],
            "meters_per_degree_lat": projection["meters_per_degree_lat"],
            "meters_per_degree_lon": projection["meters_per_degree_lon"],
            "world_scale": projection["world_scale"],
            "vertical_scale": projection["vertical_scale"],
        },
        "regions": region_summaries,
        "nodes": node_list,
        "edges": edge_list,
        "routes": route_list,
        "stats": {
            "node_count": len(node_list),
            "edge_count": len(edge_list),
            "route_count": len(route_list),
            "main_route_count": len(main_routes),
            "alternative_count": len(alternatives),
            "hub_count": len(hubs),
            "total_main_distance_km": round(sum(route["distance_m"] for route in main_routes) / 1000.0, 1),
            "total_network_distance_km": round(sum(route["distance_m"] for route in routes) / 1000.0, 1),
            "min_elevation_m": round(min(elevations), 1),
            "max_elevation_m": round(max(elevations), 1),
        },
        "attribution": {
            "dataset": "OpenStreetMap",
            "copyright": contract["attribution"]["copyright"],
            "license": "ODbL 1.0",
            "license_url": contract["attribution"]["license_url"],
            "copyright_url": contract["attribution"]["copyright_url"],
            "notice_es": contract["attribution"]["notice_es"],
            "notice_en": contract["attribution"]["notice_en"],
            "in_game_key": contract["attribution"]["in_game_key"],
            "dem_attribution": contract["dem"]["attribution"],
            "share_alike": True,
        },
    }
    return artifact


def draw_preview(
    contract: dict[str, Any],
    artifact: dict[str, Any],
    output: Path,
) -> None:
    width, height = 1600, 1100
    margin = 70
    canvas = Image.new("RGB", (width, height), (11, 20, 22))
    draw = ImageDraw.Draw(canvas)
    bounds = contract["world_bounds"]
    min_lat, min_lon = bounds["min_lat"], bounds["min_lon"]
    max_lat, max_lon = bounds["max_lat"], bounds["max_lon"]

    def project(lat: float, lon: float) -> tuple[float, float]:
        x = margin + (lon - min_lon) / (max_lon - min_lon) * (width - 2 * margin)
        y = height - margin - (lat - min_lat) / (max_lat - min_lat) * (height - 2 * margin)
        return x, y

    # Retícula cada grado.
    for lat in range(int(min_lat), int(max_lat) + 1):
        _, y = project(lat, min_lon)
        draw.line([(margin, y), (width - margin, y)], fill=(22, 38, 40), width=1)
    for lon in range(int(min_lon), int(max_lon) + 1):
        x, _ = project(min_lat, lon)
        draw.line([(x, margin), (x, height - margin)], fill=(22, 38, 40), width=1)

    colors = {
        "route.carabobo_falcon": (236, 190, 96),
        "route.carabobo_merida": (232, 128, 84),
        "route.merida_llanos": (158, 214, 126),
        "route.llanos_amazonas": (99, 196, 184),
        "route.amazonas_delta": (116, 156, 232),
        "route.delta_carabobo": (214, 138, 202),
    }
    edges = {edge["id"]: edge for edge in artifact["edges"]}
    for route in artifact["routes"]:
        color = colors.get(route["id"], (220, 220, 220))
        if route["kind"] == "alternative":
            color = tuple(max(20, channel - 55) for channel in color)
        for edge_id in route["edge_ids"]:
            edge = edges[edge_id]
            points = [project(point[0], point[1]) for point in edge["shape"]]
            if route["kind"] == "main":
                draw.line(points, fill=color, width=4, joint="curve")
            else:
                # Línea discontinua para alternativas.
                for index in range(0, len(points) - 1):
                    if index % 2 == 0:
                        draw.line([points[index], points[index + 1]], fill=color, width=2)

    for region in artifact["regions"]:
        x, y = project(region["center"][0], region["center"][1])
        draw.ellipse([x - 8, y - 8, x + 8, y + 8], fill=(245, 245, 230), outline=(10, 14, 16))
        draw.text((x + 12, y - 7), f"{region['id']} · {region['elevation_m']:.0f} m", fill=(235, 240, 232))

    draw.text((margin, 26), "RUTA NOCTURNA 1999 · F4.1 · RED DE RUTAS OSM", fill=(236, 200, 110))
    draw.text(
        (margin, 48),
        (
            f"{artifact['stats']['node_count']} nodos · {artifact['stats']['edge_count']} aristas · "
            f"{artifact['stats']['route_count']} caminos · "
            f"{artifact['stats']['total_network_distance_km']:.0f} km · "
            f"OSM {artifact['source']['osm_base_timestamp']}"
        ),
        fill=(150, 176, 172),
    )
    draw.text(
        (margin, height - 46),
        "Datos de rutas © OpenStreetMap contributors · ODbL 1.0 · "
        "Elevación: Mapzen/Tilezen (SRTM/GMTED2010/ETOPO1) · no para navegación",
        fill=(128, 150, 146),
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output)


def main() -> int:
    parser = argparse.ArgumentParser(description="Construye y valida la red de rutas de Ruta Nocturna 1999.")
    parser.add_argument("--refresh", action="store_true", help="Ignora la caché y vuelve a descargar OSM y DEM.")
    parser.add_argument("--offline", action="store_true", help="Usa solo la caché local; no hace red.")
    parser.add_argument("--check", action="store_true", help="Valida los artefactos versionados sin regenerar.")
    parser.add_argument("--no-preview", action="store_true", help="No genera la imagen de evidencia.")
    args = parser.parse_args()

    if args.check:
        errors, warnings = load_and_validate(ROOT)
        for warning in warnings:
            print(f"[WARN] {warning}")
        for error in errors:
            print(f"[ERROR] {error}")
        if errors:
            print(f"\n[FAIL] {len(errors)} errores de red de rutas.")
            return 1
        print(f"[OK] Red de rutas válida. {len(warnings)} advertencias.")
        return 0

    contract_bytes = CONTRACT_PATH.read_bytes()
    contract = json.loads(contract_bytes.decode("utf-8"))
    speeds = {
        name: float(entry["design_speed_kph"])
        for name, entry in contract["highway_classes"].items()
    }

    log("1/7 fuentes OSM")
    sources = load_sources(contract, args.refresh, args.offline)
    log("2/7 grafo nacional")
    adjacency, way_count, raw_node_count = parse_graph(sources, contract)
    log(f"grafo: {len(adjacency)} nodos, {way_count} ways, {raw_node_count} nodos OSM")
    if len(adjacency) < 1000:
        raise RuntimeError("El grafo OSM es demasiado pequeño; revisa la consulta o la caché")

    log("3/7 hubs y rutas")
    snapped = snap_hubs(adjacency, contract)
    results = generate_routes(adjacency, speeds, snapped, contract)

    log("4/7 grafo comprimido")
    union, usage = build_union_graph(results, adjacency)
    hubs_by_key = {snapped[region_id][0]: f"hub_{region_id}" for region_id in snapped}
    base_important = set(hubs_by_key)
    for result in results:
        base_important.add(result["main"]["path"][0])
        base_important.add(result["main"]["path"][-1])
        for alternative in result["alternatives"]:
            base_important.add(alternative["path"][0])
            base_important.add(alternative["path"][-1])
    important, forced = collect_important_nodes(
        union,
        usage,
        base_important,
        float(contract["graph_rules"]["max_edge_length_m"]),
    )
    node_meta, raw_edges, edge_lookup, node_ids = compress_graph(
        union, usage, important, forced, hubs_by_key, contract
    )
    log(f"red comprimida: {len(node_meta)} nodos, {len(raw_edges)} aristas")

    log("5/7 geometría y DEM")
    dem = DemSampler(contract, args.refresh, args.offline)
    shape_geo_by_edge: dict[str, list[tuple[float, float]]] = {}
    arc_by_edge: dict[str, list[float]] = {}
    all_points: set[tuple[float, float]] = set(node_meta[nid]["key"] for nid in node_meta)
    for edge in raw_edges:
        shape_geo, arc_distances = resample_by_distance(
            edge["chain"], float(contract["graph_rules"]["max_sample_spacing_m"])
        )
        if len(shape_geo) < 2:
            raise RuntimeError(f"Geometría inválida en {edge['id']}")
        shape_geo_by_edge[edge["id"]] = shape_geo
        arc_by_edge[edge["id"]] = arc_distances
        all_points.update(shape_geo)
    dem.prefetch(sorted(all_points))

    node_elevations = {nid: dem.sample(meta["key"][0], meta["key"][1]) for nid, meta in node_meta.items()}
    elevation_cache: dict[tuple[float, float], float] = {}

    def elevate(point: tuple[float, float]) -> float:
        if point not in elevation_cache:
            elevation_cache[point] = dem.sample(point[0], point[1])
        return elevation_cache[point]

    edges_output: list[dict[str, Any]] = []
    for edge in raw_edges:
        shape_geo = shape_geo_by_edge[edge["id"]]
        arc_distances = arc_by_edge[edge["id"]]
        shape_elevations = sanitize_elevations([elevate(point) for point in shape_geo])
        shape_elevations = smooth_elevations(shape_elevations)
        shape = [
            [shape_geo[index][0], shape_geo[index][1], shape_elevations[index]]
            for index in range(len(shape_geo))
        ]
        distance = sum(hav_m(shape_geo[index], shape_geo[index + 1]) for index in range(len(shape_geo) - 1))
        if distance <= 0:
            raise RuntimeError(f"Distancia cero en {edge['id']}")
        travel_time = distance / (speeds[edge["road_class"]] / 3.6)
        ascent, descent, max_grade = terrain_metrics(arc_distances, shape_elevations)
        minimum = min(shape_elevations)
        maximum = max(shape_elevations)
        edges_output.append(
            {
                "id": edge["id"],
                "from": edge["from"],
                "to": edge["to"],
                "road_class": edge["road_class"],
                "ref": edge["ref"],
                "distance_m": distance,
                "travel_time_s": travel_time,
                "ascent_m": ascent,
                "descent_m": descent,
                "min_elevation_m": minimum,
                "max_elevation_m": maximum,
                "max_grade_pct": max_grade,
                "regions": edge_regions(shape, contract),
                "shape": shape,
            }
        )
    edge_by_id = {edge["id"]: edge for edge in edges_output}

    log("6/7 rutas y estadísticas")
    routes_output: list[dict[str, Any]] = []
    for result in results:
        requirement = result["requirement"]
        entries = [("main", 0, result["main"])]
        for index, alternative in enumerate(result["alternatives"], start=1):
            entries.append(("alternative", index, alternative))
        main_edge_ids: list[str] = []
        for kind, index, entry in entries:
            path = entry["path"]
            edge_ids: list[str] = []
            for position in range(len(path) - 1):
                edge_id = edge_lookup.get(edge_key(path[position], path[position + 1]))
                if edge_id is None:
                    raise RuntimeError(f"Sin arista comprimida para {path[position]} -> {path[position + 1]}")
                if not edge_ids or edge_ids[-1] != edge_id:
                    edge_ids.append(edge_id)
            node_chain: list[str] = [node_ids[path[0]]]
            current = node_ids[path[0]]
            for edge_id in edge_ids:
                edge = edge_by_id[edge_id]
                if edge["from"] == current:
                    current = edge["to"]
                elif edge["to"] == current:
                    current = edge["from"]
                else:
                    raise RuntimeError(f"Continuidad rota en {edge_id}")
                node_chain.append(current)
            distance = sum(edge_by_id[edge_id]["distance_m"] for edge_id in edge_ids)
            travel_time = sum(edge_by_id[edge_id]["travel_time_s"] for edge_id in edge_ids)
            ascent = sum(edge_by_id[edge_id]["ascent_m"] for edge_id in edge_ids)
            descent = sum(edge_by_id[edge_id]["descent_m"] for edge_id in edge_ids)
            minimum = min(edge_by_id[edge_id]["min_elevation_m"] for edge_id in edge_ids)
            maximum = max(edge_by_id[edge_id]["max_elevation_m"] for edge_id in edge_ids)
            if kind == "main":
                main_edge_ids = edge_ids
                overlap = 0.0
                detour = 1.0
            else:
                main_set = set(main_edge_ids)
                shared = sum(
                    edge_by_id[edge_id]["distance_m"]
                    for edge_id in set(edge_ids)
                    if edge_id in main_set
                )
                total = sum(edge_by_id[edge_id]["distance_m"] for edge_id in set(edge_ids))
                overlap = shared / total if total else 1.0
                detour = distance / max(1.0, sum(edge_by_id[eid]["distance_m"] for eid in main_edge_ids))
            sequence: list[str] = []
            for node_id in node_chain:
                region = nearest_region(node_meta[node_id]["key"], contract)
                if region and (not sequence or sequence[-1] != region):
                    sequence.append(region)
            if not sequence or sequence[0] != requirement["from_region"]:
                sequence.insert(0, requirement["from_region"])
            if sequence[-1] != requirement["to_region"]:
                sequence.append(requirement["to_region"])
            routes_output.append(
                {
                    "id": requirement["id"],
                    "from": requirement["from"],
                    "to": requirement["to"],
                    "kind": kind,
                    "alternative_index": index,
                    "distance_m": distance,
                    "travel_time_s": travel_time,
                    "ascent_m": ascent,
                    "descent_m": descent,
                    "min_elevation_m": minimum,
                    "max_elevation_m": maximum,
                    "node_ids": node_chain,
                    "edge_ids": edge_ids,
                    "overlap_ratio_vs_main": overlap,
                    "detour_ratio_vs_main": detour,
                    "region_sequence": sequence,
                }
            )

    # Región y grado por nodo.
    degree: Counter[str] = Counter()
    for edge in edges_output:
        degree[edge["from"]] += 1
        degree[edge["to"]] += 1
    game_nodes: dict[str, dict[str, Any]] = {}
    for nid, meta in node_meta.items():
        key = meta["key"]
        game = [
            (key[1] - contract["projection"]["origin"][1])
            * contract["projection"]["meters_per_degree_lon"]
            * contract["projection"]["world_scale"],
            -(key[0] - contract["projection"]["origin"][0])
            * contract["projection"]["meters_per_degree_lat"]
            * contract["projection"]["world_scale"],
        ]
        game_nodes[nid] = {
            "key": key,
            "kind": "hub" if nid.startswith("hub_") else ("waypoint" if key in forced else "junction"),
            "region": nearest_region(key, contract),
            "elevation_m": node_elevations[nid],
            "game_m": game,
            "degree": degree[nid],
        }
    # Un nodo de grado 2 que separa usos o clases no es una intersección real.
    for nid, meta in game_nodes.items():
        if meta["kind"] == "junction" and meta["degree"] <= 2:
            meta["kind"] = "waypoint"

    artifact = build_artifact(
        contract,
        sources,
        adjacency,
        game_nodes,
        edges_output,
        routes_output,
        snapped,
    )
    artifact_bytes = canonical_json(artifact, indent=1)
    write_atomic(ROOT / "build" / "cache" / "osm" / "debug_network.json", artifact_bytes)
    longest = sorted(artifact["edges"], key=lambda edge: edge["distance_m"], reverse=True)[:8]
    log("aristas más largas: " + ", ".join(f"{edge['id']}={edge['distance_m']/1000:.1f}km" for edge in longest))
    steepest = sorted(artifact["edges"], key=lambda edge: edge["max_grade_pct"], reverse=True)[:8]
    log("pendientes máximas: " + ", ".join(f"{edge['id']}={edge['max_grade_pct']:.1f}%" for edge in steepest))

    manifest = {
        "schema_version": 1,
        "contract_id": contract["contract_id"],
        "world_id": contract["world_id"],
        "generated_utc": utc_now(),
        "tool": {"name": "tools/osm/build_world_routes.py", "version": TOOL_VERSION},
        "command": "python tools/osm/build_world_routes.py --refresh",
        "author": "OpenCode",
        "license": "ODbL-1.0",
        "artifacts": [
            {
                "path": contract["data_files"]["network"],
                "sha256": sha256_bytes(artifact_bytes),
                "bytes": len(artifact_bytes),
            }
        ],
        "contract": {
            "path": "data/schemas/world_routes.json",
            "sha256": sha256_bytes(contract_bytes),
            "bytes": len(contract_bytes),
        },
        "sources": [
            {
                "id": source["id"],
                "path": source["path"],
                "sha256": source["sha256"],
                "bytes": source["bytes"],
                "osm_base_timestamp": source["osm_base_timestamp"],
                "endpoint": source["endpoint"],
                "query": source["query"],
            }
            for source in sources
        ],
        "dem": dem.summary(),
        "notes": [
            "Red derivada de OpenStreetMap bajo ODbL 1.0; no para navegación.",
            "Las respuestas crudas de Overpass y las teselas DEM no se versionan.",
            "Los caminos alternativos son rutas reales calculadas con penalización del camino principal.",
        ],
    }
    manifest_bytes = canonical_json(manifest, indent=2)

    errors, warnings = validate_network(
        ROOT, contract, artifact, manifest, artifact_bytes, contract_bytes, check_files=False
    )
    for warning in warnings:
        print(f"[WARN] {warning}")
    for error in errors:
        print(f"[ERROR] {error}")
    if errors:
        print(f"\n[FAIL] La red generada no pasó la validación ({len(errors)} errores). No se escribió nada.")
        return 1

    network_path = ROOT / contract["data_files"]["network"]
    manifest_path = ROOT / contract["data_files"]["manifest"]
    write_atomic(network_path, artifact_bytes)
    write_atomic(manifest_path, manifest_bytes)
    log(f"escrito {network_path.relative_to(ROOT)} ({len(artifact_bytes)} bytes)")
    log(f"escrito {manifest_path.relative_to(ROOT)} ({len(manifest_bytes)} bytes)")

    if not args.no_preview:
        preview_path = ROOT / "build" / "logs" / "osm" / "route_network_preview.png"
        draw_preview(contract, artifact, preview_path)
        log(f"vista previa {preview_path.relative_to(ROOT)}")
        report = {
            "generated_utc": manifest["generated_utc"],
            "osm_base_timestamp": artifact["source"]["osm_base_timestamp"],
            "stats": artifact["stats"],
            "regions": artifact["regions"],
            "routes": [
                {
                    "id": route["id"],
                    "kind": route["kind"],
                    "alternative_index": route["alternative_index"],
                    "distance_km": round(route["distance_m"] / 1000.0, 1),
                    "hours_at_design_speed": round(route["travel_time_s"] / 3600.0, 2),
                    "ascent_m": route["ascent_m"],
                    "descent_m": route["descent_m"],
                    "max_elevation_m": route["max_elevation_m"],
                    "overlap_ratio_vs_main": route["overlap_ratio_vs_main"],
                    "detour_ratio_vs_main": route["detour_ratio_vs_main"],
                }
                for route in artifact["routes"]
            ],
            "dem": manifest["dem"],
            "validation_errors": errors,
        }
        report_path = ROOT / "build" / "logs" / "osm" / "report.json"
        write_atomic(report_path, canonical_json(report, indent=2))

    log(
        f"OK: {artifact['stats']['node_count']} nodos, {artifact['stats']['edge_count']} aristas, "
        f"{artifact['stats']['route_count']} caminos, {artifact['stats']['total_network_distance_km']} km"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
