#!/usr/bin/env python3
"""Validación compartida del contrato world_routes y de la red generada.

El pipeline `tools/osm/build_world_routes.py` y `tools/validate_schemas.py`
usan este módulo para que la red no pueda publicarse con IDs duplicados,
aristas rotas, nodos huérfanos, rutas discontinuas, alternativas falsas,
elevación ausente, atribución ODbL incompleta o presupuestos excedidos.
"""

from __future__ import annotations

import csv
import hashlib
import json
import math
from collections import Counter
from pathlib import Path
from typing import Any

REQUIRED_REGIONS = {"carabobo", "falcon", "merida", "llanos", "amazonas", "delta"}
REQUIRED_NETWORK_STATES = {"unloaded", "loading", "loaded", "degraded", "failed"}
REQUIRED_ROUTE_STATES = {"planned", "active", "replanned", "completed", "abandoned"}
REQUIRED_HIGHWAY_CLASSES = {"motorway", "trunk", "primary", "secondary"}
EARTH_RADIUS_M = 6371000.0


def hav_m(a: list[float] | tuple[float, ...], b: list[float] | tuple[float, ...]) -> float:
    lat1, lon1 = float(a[0]), float(a[1])
    lat2, lon2 = float(b[0]), float(b[1])
    p1 = math.radians(lat1)
    p2 = math.radians(lat2)
    dp = p2 - p1
    dl = math.radians(lon2 - lon1)
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return EARTH_RADIUS_M * 2 * math.asin(min(1.0, math.sqrt(h)))


def shape_distance_m(shape: list[list[float]]) -> float:
    total = 0.0
    for index in range(len(shape) - 1):
        total += hav_m(shape[index], shape[index + 1])
    return total


def project_geo(geo: list[float], projection: dict[str, Any]) -> list[float]:
    origin_lat, origin_lon = projection["origin"]
    scale = float(projection["world_scale"])
    x = (float(geo[1]) - float(origin_lon)) * float(projection["meters_per_degree_lon"]) * scale
    z = -(float(geo[0]) - float(origin_lat)) * float(projection["meters_per_degree_lat"]) * scale
    return [x, z]


def localization_keys(root: Path) -> set[str]:
    path = root / "localization" / "strings.csv"
    if not path.exists():
        return set()
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return {row["key"] for row in csv.DictReader(handle) if row.get("key")}


def duplicate_values(values: list[str]) -> list[str]:
    seen: set[str] = set()
    duplicates: list[str] = []
    for value in values:
        if value in seen and value not in duplicates:
            duplicates.append(value)
        seen.add(value)
    return duplicates


def build_adjacency(nodes: dict[str, dict[str, Any]], edges: list[dict[str, Any]]) -> dict[str, set[str]]:
    adjacency: dict[str, set[str]] = {node_id: set() for node_id in nodes}
    for edge in edges:
        adjacency.setdefault(edge["from"], set()).add(edge["to"])
        adjacency.setdefault(edge["to"], set()).add(edge["from"])
    return adjacency


def reachable_from(adjacency: dict[str, set[str]], start: str) -> set[str]:
    seen = {start}
    stack = [start]
    while stack:
        node = stack.pop()
        for neighbor in adjacency.get(node, set()):
            if neighbor not in seen:
                seen.add(neighbor)
                stack.append(neighbor)
    return seen


def validate_contract(
    root: Path,
    contract: dict[str, Any],
    check_files: bool = True,
) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []

    if contract.get("schema_version") != 1:
        errors.append("world_routes: schema_version debe ser 1")
    if contract.get("contract_id") != "world.routes":
        errors.append("world_routes: contract_id inválido")
    if contract.get("world_id") != "venezuela.1999":
        errors.append("world_routes: world_id inválido")

    bounds = contract.get("world_bounds", {})
    try:
        if not (bounds["min_lat"] < bounds["max_lat"] and bounds["min_lon"] < bounds["max_lon"]):
            errors.append("world_routes: world_bounds debe cumplir min < max")
    except KeyError:
        errors.append("world_routes: world_bounds incompleto")

    projection = contract.get("projection", {})
    origin = projection.get("origin", [0, 0])
    if bounds and not (
        bounds.get("min_lat", 99) <= origin[0] <= bounds.get("max_lat", -99)
        and bounds.get("min_lon", 999) <= origin[1] <= bounds.get("max_lon", -999)
    ):
        errors.append("world_routes: el origen de proyección queda fuera de world_bounds")

    regions = contract.get("regions", [])
    region_ids = [region.get("id", "") for region in regions]
    if set(region_ids) != REQUIRED_REGIONS:
        errors.append(f"world_routes: regiones {sorted(set(region_ids))} != {sorted(REQUIRED_REGIONS)}")
    for duplicate in duplicate_values(region_ids):
        errors.append(f"world_routes: región repetida {duplicate}")
    hubs: dict[str, str] = {}
    for region in regions:
        region_id = region.get("id", "?")
        hub = str(region.get("hub_node", ""))
        if not hub.startswith("hub_"):
            errors.append(f"world_routes: hub inválido en {region_id}: {hub}")
        if hub in hubs.values():
            errors.append(f"world_routes: hub repetido {hub}")
        hubs[region_id] = hub
        expected = region.get("elevation_expected_m", [])
        if len(expected) != 2 or expected[0] > expected[1]:
            errors.append(f"world_routes: rango de elevación inválido en {region_id}")
        if float(region.get("radius_km", 0)) <= 0:
            errors.append(f"world_routes: radius_km inválido en {region_id}")

    classes = contract.get("highway_classes", {})
    if set(classes) != REQUIRED_HIGHWAY_CLASSES:
        errors.append("world_routes: highway_classes debe cubrir motorway/trunk/primary/secondary")
    speeds: dict[str, float] = {}
    for name, entry in classes.items():
        speed = float(entry.get("design_speed_kph", 0))
        if speed <= 0 or speed > 200:
            errors.append(f"world_routes: velocidad de diseño inválida en {name}")
        speeds[name] = speed
    priorities = [int(entry.get("priority", 0)) for entry in classes.values()]
    if len(set(priorities)) != len(priorities):
        errors.append("world_routes: prioridades de clase repetidas")

    routes = contract.get("routes", [])
    route_ids = [route.get("id", "") for route in routes]
    if len(routes) != 6:
        errors.append(f"world_routes: se esperan 6 rutas, hay {len(routes)}")
    for duplicate in duplicate_values(route_ids):
        errors.append(f"world_routes: ruta repetida {duplicate}")
    route_pairs: set[tuple[str, str]] = set()
    for route in routes:
        route_id = route.get("id", "?")
        from_region = route.get("from_region")
        to_region = route.get("to_region")
        if from_region not in REQUIRED_REGIONS or to_region not in REQUIRED_REGIONS:
            errors.append(f"world_routes: regiones inválidas en {route_id}")
            continue
        if from_region == to_region:
            errors.append(f"world_routes: {route_id} conecta la misma región")
        if route.get("from") != hubs.get(from_region):
            errors.append(f"world_routes: {route_id} from no coincide con el hub de {from_region}")
        if route.get("to") != hubs.get(to_region):
            errors.append(f"world_routes: {route_id} to no coincide con el hub de {to_region}")
        pair = tuple(sorted((from_region, to_region)))
        if pair in route_pairs:
            errors.append(f"world_routes: par de regiones repetido {pair}")
        route_pairs.add(pair)
        if int(route.get("min_alternatives", 0)) < 0:
            errors.append(f"world_routes: min_alternatives inválido en {route_id}")
        if int(route.get("max_alternatives", 0)) < int(route.get("min_alternatives", 0)):
            errors.append(f"world_routes: max_alternatives menor que min_alternatives en {route_id}")
        if float(route.get("max_detour_ratio", 0)) < 1.0:
            errors.append(f"world_routes: max_detour_ratio inválido en {route_id}")
        if not (0.0 < float(route.get("max_overlap_ratio", -1)) <= 1.0):
            errors.append(f"world_routes: max_overlap_ratio inválido en {route_id}")
        if float(route.get("max_distance_km", 0)) <= 0:
            errors.append(f"world_routes: max_distance_km inválido en {route_id}")

    budgets = contract.get("budgets", {})
    for route in routes:
        if int(route.get("max_alternatives", 0)) > int(budgets.get("max_alternatives_per_route", 0)):
            errors.append(f"world_routes: la ruta {route.get('id')} excede el presupuesto de alternativas")

    states = contract.get("states", {})
    for state_group, required in (
        ("network", REQUIRED_NETWORK_STATES),
        ("route", REQUIRED_ROUTE_STATES),
    ):
        entries = states.get(state_group, [])
        ids = [entry.get("id", "") for entry in entries]
        if set(ids) != required:
            errors.append(f"world_routes: estados {state_group} {sorted(set(ids))} != {sorted(required)}")
        for duplicate in duplicate_values(ids):
            errors.append(f"world_routes: estado {state_group} repetido {duplicate}")
        for entry in entries:
            for target in entry.get("next", []):
                if target not in ids:
                    errors.append(
                        f"world_routes: estado {state_group}.{entry.get('id')} apunta a {target} inexistente"
                    )

    attribution = contract.get("attribution", {})
    if attribution.get("license") != "ODbL 1.0":
        errors.append("world_routes: la licencia de datos debe ser ODbL 1.0")
    if attribution.get("dataset") != "OpenStreetMap":
        errors.append("world_routes: el dataset debe ser OpenStreetMap")
    if "openstreetmap.org/copyright" not in str(attribution.get("copyright_url", "")):
        errors.append("world_routes: falta el enlace de copyright de OSM")
    if not str(attribution.get("notice_es", "")).strip() or not str(attribution.get("notice_en", "")).strip():
        errors.append("world_routes: faltan los avisos de atribución")
    if not attribution.get("share_alike"):
        errors.append("world_routes: la atribución debe declarar share_alike")
    key = str(attribution.get("in_game_key", ""))
    keys = localization_keys(root)
    if key and key not in keys:
        errors.append(f"world_routes: la clave de atribución {key} no existe en localization/strings.csv")
    credits = root / str(attribution.get("credits_file", "CREDITS.md"))
    credits_text = credits.read_text(encoding="utf-8") if credits.exists() else ""
    if check_files and ("OpenStreetMap" not in credits_text or "ODbL" not in credits_text):
        errors.append("world_routes: CREDITS.md no contiene la atribución OSM/ODbL")
    license_file = root / str(attribution.get("data_license_file", ""))
    if check_files and not license_file.exists():
        errors.append(f"world_routes: falta el texto de licencia {license_file.relative_to(root)}")
    elif license_file.exists():
        license_text = license_file.read_text(encoding="utf-8", errors="replace")
        if "Open Database License" not in license_text and "ODbL" not in license_text:
            errors.append("world_routes: el archivo de licencia no parece ser ODbL")

    data_files = contract.get("data_files", {})
    for field in ("network", "manifest", "network_schema"):
        path = root / str(data_files.get(field, ""))
        if check_files and not path.exists():
            errors.append(f"world_routes: falta data_files.{field} ({path.relative_to(root)})")

    cache = contract.get("cache", {})
    if not str(cache.get("raw_dir", "")).startswith("build/"):
        errors.append("world_routes: raw_dir debe vivir en build/")
    if not str(cache.get("dem_dir", "")).startswith("build/"):
        errors.append("world_routes: dem_dir debe vivir en build/")
    committed = set(cache.get("committed_artifacts", []))
    if data_files.get("network") not in committed:
        errors.append("world_routes: la red generada debe estar en committed_artifacts")

    qa = contract.get("qa", {})
    if check_files and not (root / str(qa.get("test_scene", ""))).exists():
        errors.append("world_routes: falta la escena de prueba de rutas")
    if check_files and not (root / str(qa.get("test_command", ""))).exists():
        errors.append("world_routes: falta el comando de prueba de rutas")

    dem = contract.get("dem", {})
    if not (1 <= int(dem.get("zoom", 0)) <= 15):
        errors.append("world_routes: zoom DEM inválido")
    if float(dem.get("sample_interval_m", 0)) <= 0:
        errors.append("world_routes: sample_interval_m inválido")
    if not str(dem.get("attribution", "")).strip():
        errors.append("world_routes: falta la atribución DEM")

    return errors, warnings


def validate_manifest(
    root: Path,
    contract: dict[str, Any],
    network: dict[str, Any],
    manifest: dict[str, Any],
    artifact_bytes: bytes | None,
    contract_bytes: bytes | None,
) -> list[str]:
    errors: list[str] = []
    if manifest.get("schema_version") != 1:
        errors.append("world_route_manifest: schema_version debe ser 1")
    if manifest.get("contract_id") != contract.get("contract_id"):
        errors.append("world_route_manifest: contract_id no coincide")
    if manifest.get("world_id") != contract.get("world_id"):
        errors.append("world_route_manifest: world_id no coincide")
    if manifest.get("license") != "ODbL-1.0":
        errors.append("world_route_manifest: license debe ser ODbL-1.0")
    if not str(manifest.get("author", "")).strip():
        errors.append("world_route_manifest: falta autor")
    if not str(manifest.get("command", "")).strip():
        errors.append("world_route_manifest: falta comando reproducible")
    if not str(manifest.get("generated_utc", "")).strip():
        errors.append("world_route_manifest: falta generated_utc")

    network_path = contract.get("data_files", {}).get("network")
    artifacts = {entry.get("path"): entry for entry in manifest.get("artifacts", [])}
    artifact_entry = artifacts.get(network_path)
    if not artifact_entry:
        errors.append(f"world_route_manifest: no registra el artefacto {network_path}")
    else:
        if artifact_bytes is not None:
            digest = hashlib.sha256(artifact_bytes).hexdigest()
            if artifact_entry.get("sha256") != digest:
                errors.append("world_route_manifest: sha256 del artefacto no coincide")
            if int(artifact_entry.get("bytes", -1)) != len(artifact_bytes):
                errors.append("world_route_manifest: bytes del artefacto no coinciden")
        if not str(artifact_entry.get("sha256", "")).strip():
            errors.append("world_route_manifest: el artefacto no tiene sha256")

    contract_entry = manifest.get("contract", {})
    if contract_entry.get("path") != "data/schemas/world_routes.json":
        errors.append("world_route_manifest: ruta del contrato inválida")
    if contract_bytes is not None:
        digest = hashlib.sha256(contract_bytes).hexdigest()
        if contract_entry.get("sha256") != digest:
            errors.append("world_route_manifest: sha256 del contrato no coincide")
        if int(contract_entry.get("bytes", -1)) != len(contract_bytes):
            errors.append("world_route_manifest: bytes del contrato no coinciden")

    source_queries = {entry.get("id"): entry for entry in manifest.get("sources", [])}
    artifact_queries = {entry.get("id"): entry for entry in network.get("source", {}).get("queries", [])}
    for query_id, query in artifact_queries.items():
        source = source_queries.get(query_id)
        if not source:
            errors.append(f"world_route_manifest: falta la fuente OSM {query_id}")
            continue
        if source.get("sha256") != query.get("sha256"):
            errors.append(f"world_route_manifest: sha256 de la fuente {query_id} no coincide")
        if int(source.get("bytes", -1)) != int(query.get("bytes", -2)):
            errors.append(f"world_route_manifest: bytes de la fuente {query_id} no coinciden")
    for query_id in source_queries:
        if query_id not in artifact_queries:
            errors.append(f"world_route_manifest: fuente {query_id} no declarada en el artefacto")

    dem = manifest.get("dem", {})
    for field in ("source", "zoom", "tile_count", "bytes", "keys_sha256"):
        if field not in dem:
            errors.append(f"world_route_manifest: falta dem.{field}")
    if int(dem.get("tile_count", 0)) <= 0:
        errors.append("world_route_manifest: no se registraron teselas DEM")

    return errors


def validate_network(
    root: Path,
    contract: dict[str, Any],
    network: dict[str, Any],
    manifest: dict[str, Any],
    artifact_bytes: bytes | None = None,
    contract_bytes: bytes | None = None,
    check_files: bool = True,
) -> tuple[list[str], list[str]]:
    errors, warnings = validate_contract(root, contract, check_files)
    errors.extend(validate_manifest(root, contract, network, manifest, artifact_bytes, contract_bytes))
    if errors:
        # Con errores estructurales no tiene sentido seguir con referencias cruzadas.
        return errors, warnings

    projection = contract["projection"]
    network_projection = network.get("projection", {})
    for field in ("mode", "origin", "meters_per_degree_lat", "meters_per_degree_lon", "world_scale"):
        if network_projection.get(field) != projection.get(field):
            errors.append(f"world_route_network: projection.{field} no coincide con el contrato")

    if network.get("schema_version") != 1 or network.get("artifact_version") != 1:
        errors.append("world_route_network: versión de artefacto inválida")
    if network.get("contract_id") != contract.get("contract_id"):
        errors.append("world_route_network: contract_id no coincide")
    if network.get("world_id") != contract.get("world_id"):
        errors.append("world_route_network: world_id no coincide")
    if network.get("coordinate_system") != "WGS84":
        errors.append("world_route_network: coordinate_system debe ser WGS84")
    if network.get("elevation_unit") != "m":
        errors.append("world_route_network: elevation_unit debe ser m")

    source = network.get("source", {})
    if source.get("license") != "ODbL 1.0":
        errors.append("world_route_network: la fuente debe declarar ODbL 1.0")
    if "OpenStreetMap" not in str(source.get("copyright", "")):
        errors.append("world_route_network: falta el copyright de OpenStreetMap")
    contract_queries = {entry.get("id"): entry for entry in contract["extract"]["queries"]}
    for query in source.get("queries", []):
        expected = contract_queries.get(query.get("id"))
        if not expected:
            errors.append(f"world_route_network: consulta OSM desconocida {query.get('id')}")
            continue
        if query.get("highway_regex") != expected.get("highway_regex"):
            errors.append(f"world_route_network: regex distinta en {query.get('id')}")
        if not str(query.get("osm_base_timestamp", "")).strip():
            errors.append(f"world_route_network: falta timestamp OSM en {query.get('id')}")

    attribution = network.get("attribution", {})
    for field in ("dataset", "copyright", "license", "license_url", "copyright_url", "notice_es", "notice_en", "in_game_key", "dem_attribution", "share_alike"):
        if field not in attribution:
            errors.append(f"world_route_network: attribution.{field} ausente")
    if attribution.get("license") != "ODbL 1.0" or attribution.get("dataset") != "OpenStreetMap":
        errors.append("world_route_network: atribución ODbL/OSM inválida")
    if attribution.get("share_alike") is not True:
        errors.append("world_route_network: share_alike debe ser true")

    bounds = contract["world_bounds"]
    nodes = {node.get("id"): node for node in network.get("nodes", [])}
    edges = {edge.get("id"): edge for edge in network.get("edges", [])}
    if duplicate_values([node.get("id", "") for node in network.get("nodes", [])]):
        errors.append("world_route_network: IDs de nodo repetidos")
    if duplicate_values([edge.get("id", "") for edge in network.get("edges", [])]):
        errors.append("world_route_network: IDs de arista repetidos")

    budgets = contract["budgets"]
    if len(nodes) > int(budgets["max_nodes"]):
        errors.append(f"world_route_network: {len(nodes)} nodos exceden {budgets['max_nodes']}")
    if len(edges) > int(budgets["max_edges"]):
        errors.append(f"world_route_network: {len(edges)} aristas exceden {budgets['max_edges']}")
    if artifact_bytes is not None and len(artifact_bytes) > int(budgets["max_file_bytes"]):
        errors.append(
            f"world_route_network: {len(artifact_bytes)} bytes exceden {budgets['max_file_bytes']}"
        )

    graph_edges: list[dict[str, Any]] = []
    for node_id, node in nodes.items():
        geo = node.get("geo", [0, 0])
        if not (
            bounds["min_lat"] <= geo[0] <= bounds["max_lat"]
            and bounds["min_lon"] <= geo[1] <= bounds["max_lon"]
        ):
            errors.append(f"world_route_network: nodo {node_id} fuera de world_bounds")
        if not (-50 <= float(node.get("elevation_m", -999)) <= 5000):
            errors.append(f"world_route_network: elevación inválida en {node_id}")
        if node.get("kind") == "hub" and not str(node_id).startswith("hub_"):
            errors.append(f"world_route_network: hub con ID inválido {node_id}")
        expected_game = project_geo(geo, projection)
        actual_game = node.get("game_m", [0, 0])
        if abs(expected_game[0] - actual_game[0]) > 2.0 or abs(expected_game[1] - actual_game[1]) > 2.0:
            errors.append(f"world_route_network: proyección inconsistente en {node_id}")

    for edge_id, edge in edges.items():
        if edge["from"] not in nodes or edge["to"] not in nodes:
            errors.append(f"world_route_network: arista {edge_id} apunta a nodo inexistente")
            continue
        if edge["from"] == edge["to"]:
            errors.append(f"world_route_network: arista {edge_id} es un bucle")
        shape = edge.get("shape", [])
        if len(shape) < 2:
            errors.append(f"world_route_network: arista {edge_id} sin forma")
            continue
        measured = shape_distance_m(shape)
        declared = float(edge.get("distance_m", 0))
        if measured <= 0 or abs(measured - declared) > max(2.0, declared * 0.02):
            errors.append(f"world_route_network: distancia de {edge_id} no coincide con su forma")
        if declared > float(contract["graph_rules"]["max_edge_length_m"]):
            errors.append(f"world_route_network: arista {edge_id} excede la longitud máxima")
        speed = float(contract["highway_classes"][edge["road_class"]]["design_speed_kph"])
        expected_time = declared / (speed / 3.6)
        if abs(float(edge.get("travel_time_s", 0)) - expected_time) > max(1.0, expected_time * 0.05):
            errors.append(f"world_route_network: travel_time_s incoherente en {edge_id}")
        if abs(float(edge.get("cost", 0)) - float(edge.get("travel_time_s", 0))) > 0.5:
            errors.append(f"world_route_network: cost debe ser el tiempo de viaje en {edge_id}")
        elevations = [float(point[2]) for point in shape]
        if min(elevations) < -50 or max(elevations) > 5000:
            errors.append(f"world_route_network: elevación fuera de rango en {edge_id}")
        if abs(min(elevations) - float(edge.get("min_elevation_m", 0))) > 1.0:
            errors.append(f"world_route_network: min_elevation_m incoherente en {edge_id}")
        if abs(max(elevations) - float(edge.get("max_elevation_m", 0))) > 1.0:
            errors.append(f"world_route_network: max_elevation_m incoherente en {edge_id}")
        if float(edge.get("max_grade_pct", 0)) > float(contract["graph_rules"]["max_grade_pct"]) + 0.5:
            errors.append(f"world_route_network: pendiente excesiva en {edge_id}")
        if float(edge.get("ascent_m", -1)) < 0 or float(edge.get("descent_m", -1)) < 0:
            errors.append(f"world_route_network: ascenso/descenso inválido en {edge_id}")
        regions = edge.get("regions", [])
        if len(set(regions)) != len(regions):
            errors.append(f"world_route_network: regiones repetidas en {edge_id}")
        graph_edges.append(edge)

    adjacency = build_adjacency(nodes, graph_edges)
    degree_count: Counter[str] = Counter()
    for edge in graph_edges:
        degree_count[edge["from"]] += 1
        degree_count[edge["to"]] += 1
    for node_id, neighbors in adjacency.items():
        if degree_count[node_id] < int(contract["graph_rules"]["min_used_degree"]):
            errors.append(f"world_route_network: nodo huérfano o de grado bajo {node_id}")
        if degree_count[node_id] == 1 and nodes[node_id].get("kind") != "hub":
            errors.append(f"world_route_network: nodo terminal que no es hub {node_id}")
        if int(nodes[node_id].get("degree", -1)) != degree_count[node_id]:
            errors.append(f"world_route_network: degree incoherente en {node_id}")

    network_regions = {entry.get("id"): entry for entry in network.get("regions", [])}
    if set(network_regions) != REQUIRED_REGIONS:
        errors.append("world_route_network: el artefacto debe resumir las seis regiones")
    for region in contract["regions"]:
        summary = network_regions.get(region["id"])
        if not summary:
            continue
        if summary.get("hub_node") != region["hub_node"]:
            errors.append(f"world_route_network: hub distinto en la región {region['id']}")
        hub = nodes.get(region["hub_node"])
        if not hub:
            errors.append(f"world_route_network: falta el hub {region['hub_node']}")
            continue
        if hub.get("kind") != "hub":
            errors.append(f"world_route_network: {region['hub_node']} no está marcado como hub")
        if abs(float(summary.get("elevation_m", -999)) - float(hub.get("elevation_m", -998))) > 1.0:
            errors.append(f"world_route_network: elevación del hub {region['id']} incoherente")
        expected = region["elevation_expected_m"]
        within = expected[0] <= float(hub["elevation_m"]) <= expected[1]
        if bool(summary.get("within_expected")) != within:
            errors.append(f"world_route_network: within_expected incoherente en {region['id']}")
        if not within:
            errors.append(
                f"world_route_network: elevación {hub['elevation_m']} fuera de {expected} en {region['id']}"
            )
        if float(summary.get("snap_offset_m", -1)) < 0:
            errors.append(f"world_route_network: snap_offset_m inválido en {region['id']}")
        if float(summary.get("snap_offset_m", 0)) > float(contract["graph_rules"]["snap_max_offset_m"]):
            errors.append(f"world_route_network: snap demasiado lejos en {region['id']}")

    fallback = contract["anti_softlock"]["fallback_hub"]
    if fallback not in nodes:
        errors.append(f"world_route_network: fallback_hub inexistente {fallback}")
    else:
        reachable = reachable_from(adjacency, fallback)
        if len(reachable) != len(nodes):
            errors.append(
                f"world_route_network: la red no es conexa ({len(reachable)}/{len(nodes)} nodos alcanzables)"
            )
        for region in contract["regions"]:
            if region["hub_node"] not in reachable:
                errors.append(f"world_route_network: el hub {region['hub_node']} no es alcanzable")

    route_by_key: dict[tuple[str, int], dict[str, Any]] = {}
    for route in network.get("routes", []):
        key = (str(route.get("id")), int(route.get("alternative_index", -1)))
        if key in route_by_key:
            errors.append(f"world_route_network: ruta repetida {key}")
        route_by_key[key] = route

    total_main = 0.0
    total_network = 0.0
    for requirement in contract["routes"]:
        route_id = requirement["id"]
        mains = [
            route
            for route in network.get("routes", [])
            if route.get("id") == route_id and route.get("kind") == "main"
        ]
        if len(mains) != 1:
            errors.append(f"world_route_network: {route_id} debe tener exactamente un camino principal")
            continue
        main = mains[0]
        alternatives = [
            route
            for route in network.get("routes", [])
            if route.get("id") == route_id and route.get("kind") == "alternative"
        ]
        if main.get("from") != requirement["from"] or main.get("to") != requirement["to"]:
            errors.append(f"world_route_network: extremos del camino principal {route_id} no coinciden")
        if main.get("alternative_index") != 0:
            errors.append(f"world_route_network: el camino principal {route_id} debe tener índice 0")
        if len(alternatives) < int(requirement["min_alternatives"]):
            errors.append(
                f"world_route_network: {route_id} tiene {len(alternatives)} alternativas; "
                f"mínimo {requirement['min_alternatives']}"
            )
        if len(alternatives) > int(requirement["max_alternatives"]):
            errors.append(f"world_route_network: {route_id} excede sus alternativas máximas")
        if float(main.get("distance_m", 0)) > float(requirement["max_distance_km"]) * 1000.0:
            errors.append(f"world_route_network: {route_id} excede max_distance_km")

        for route in [main, *alternatives]:
            index = int(route.get("alternative_index", -1))
            edge_ids = route.get("edge_ids", [])
            node_ids = route.get("node_ids", [])
            if not edge_ids or len(node_ids) != len(edge_ids) + 1:
                errors.append(f"world_route_network: {route_id}/{index} tiene nodos/aristas incoherentes")
                continue
            if len(edge_ids) > int(budgets["max_route_edge_refs"]):
                errors.append(f"world_route_network: {route_id}/{index} excede max_route_edge_refs")
            previous = node_ids[0]
            distance = 0.0
            for edge_id, next_node in zip(edge_ids, node_ids[1:]):
                edge = edges.get(edge_id)
                if not edge:
                    errors.append(f"world_route_network: {route_id}/{index} usa arista inexistente {edge_id}")
                    break
                if edge["from"] == previous and edge["to"] == next_node:
                    pass
                elif edge["to"] == previous and edge["from"] == next_node:
                    pass
                else:
                    errors.append(
                        f"world_route_network: {route_id}/{index} rompe continuidad en {edge_id}"
                    )
                distance += float(edge.get("distance_m", 0))
                previous = next_node
            if abs(distance - float(route.get("distance_m", 0))) > max(2.0, distance * 0.02):
                errors.append(f"world_route_network: distancia declarada incoherente en {route_id}/{index}")
            if route.get("from") != node_ids[0] or route.get("to") != node_ids[-1]:
                errors.append(f"world_route_network: extremos incoherentes en {route_id}/{index}")
            regions_sequence = route.get("region_sequence", [])
            if not regions_sequence:
                errors.append(f"world_route_network: {route_id}/{index} sin secuencia de regiones")
            else:
                if regions_sequence[0] != requirement["from_region"]:
                    errors.append(f"world_route_network: {route_id}/{index} no empieza en su región")
                if regions_sequence[-1] != requirement["to_region"]:
                    errors.append(f"world_route_network: {route_id}/{index} no termina en su región")
            if route.get("kind") == "alternative":
                overlap = float(route.get("overlap_ratio_vs_main", 1.0))
                if overlap > float(requirement["max_overlap_ratio"]) + 0.02:
                    errors.append(f"world_route_network: {route_id}/{index} solapa demasiado con el principal")
                detour = float(route.get("distance_m", 0)) / max(1.0, float(main["distance_m"]))
                if detour > float(requirement["max_detour_ratio"]) + 0.02:
                    errors.append(f"world_route_network: {route_id}/{index} desvía demasiado")
                if abs(detour - float(route.get("detour_ratio_vs_main", 0))) > 0.02:
                    errors.append(f"world_route_network: detour_ratio incoherente en {route_id}/{index}")

        main_edges = {edge_id for edge_id in main.get("edge_ids", [])}
        for alternative in alternatives:
            shared = sum(
                float(edges[edge_id]["distance_m"])
                for edge_id in set(alternative.get("edge_ids", []))
                if edge_id in main_edges and edge_id in edges
            )
            total_alt = sum(
                float(edges[edge_id]["distance_m"])
                for edge_id in set(alternative.get("edge_ids", []))
                if edge_id in edges
            )
            measured_overlap = shared / total_alt if total_alt else 1.0
            if abs(measured_overlap - float(alternative.get("overlap_ratio_vs_main", -1))) > 0.03:
                errors.append(
                    f"world_route_network: overlap_ratio incoherente en "
                    f"{route_id}/{alternative.get('alternative_index')}"
                )
        total_main += float(main.get("distance_m", 0))
        total_network += sum(float(route.get("distance_m", 0)) for route in [main, *alternatives])

    stats = network.get("stats", {})
    if int(stats.get("node_count", -1)) != len(nodes):
        errors.append("world_route_network: stats.node_count no coincide")
    if int(stats.get("edge_count", -1)) != len(edges):
        errors.append("world_route_network: stats.edge_count no coincide")
    if int(stats.get("route_count", -1)) != len(network.get("routes", [])):
        errors.append("world_route_network: stats.route_count no coincide")
    main_count = sum(1 for route in network.get("routes", []) if route.get("kind") == "main")
    alternative_count = sum(1 for route in network.get("routes", []) if route.get("kind") == "alternative")
    if int(stats.get("main_route_count", -1)) != main_count:
        errors.append("world_route_network: stats.main_route_count no coincide")
    if int(stats.get("alternative_count", -1)) != alternative_count:
        errors.append("world_route_network: stats.alternative_count no coincide")
    if int(stats.get("hub_count", -1)) != 6:
        errors.append("world_route_network: stats.hub_count debe ser 6")
    if abs(float(stats.get("total_main_distance_km", 0)) - total_main / 1000.0) > 0.5:
        errors.append("world_route_network: stats.total_main_distance_km no coincide")
    if abs(float(stats.get("total_network_distance_km", 0)) - total_network / 1000.0) > 0.5:
        errors.append("world_route_network: stats.total_network_distance_km no coincide")
    elevations = [float(node["elevation_m"]) for node in nodes.values()]
    if abs(float(stats.get("min_elevation_m", 0)) - min(elevations)) > 1.0:
        errors.append("world_route_network: stats.min_elevation_m no coincide")
    if abs(float(stats.get("max_elevation_m", 0)) - max(elevations)) > 1.0:
        errors.append("world_route_network: stats.max_elevation_m no coincide")

    return errors, warnings


def load_and_validate(root: Path) -> tuple[list[str], list[str]]:
    """Carga los archivos versionados y ejecuta la validación completa."""
    contract_path = root / "data" / "schemas" / "world_routes.json"
    contract_bytes = contract_path.read_bytes()
    contract = json.loads(contract_bytes.decode("utf-8"))
    network_path = root / contract["data_files"]["network"]
    artifact_bytes = network_path.read_bytes()
    network = json.loads(artifact_bytes.decode("utf-8"))
    manifest_path = root / contract["data_files"]["manifest"]
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    return validate_network(root, contract, network, manifest, artifact_bytes, contract_bytes)
