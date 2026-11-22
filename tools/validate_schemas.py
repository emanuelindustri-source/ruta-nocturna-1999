#!/usr/bin/env python3
"""Validate canonical JSON contracts and cross-file invariants."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[1]
SCHEMA_DIR = ROOT / "data" / "schemas"
JSON_SCHEMA_DIR = SCHEMA_DIR / "json"
LOCALIZATION_CSV = ROOT / "localization" / "strings.csv"

PAIRS = {
    "vehicle_components": "vehicle_components",
    "inventory_tools": "inventory_tools",
    "folklore_entities": "folklore_entities",
    "dialogue_and_endings": "dialogue_and_endings",
    "autoload_dependencies": "autoload_dependencies",
}

REQUIRED_AUTOLOADS = {
    "EventBus",
    "HardwareProfiler",
    "SettingsManager",
    "LocalizationManager",
    "GameState",
    "SaveManager",
    "AudioDirector",
    "WeatherManager",
    "UpdateChecker",
    "CrashReporter",
    "SceneRouter",
}

REQUIRED_ENTITIES = {
    "silbon",
    "llorona",
    "sayona",
    "momoyes",
    "mapurangui",
    "serpiente_siete_cabezas",
    "enano_catedral",
}

REGIONS = {"carabobo", "falcon", "merida", "llanos", "amazonas", "delta"}


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def duplicate_values(values: list[str]) -> list[str]:
    seen: set[str] = set()
    duplicates: list[str] = []
    for value in values:
        if value in seen and value not in duplicates:
            duplicates.append(value)
        seen.add(value)
    return duplicates


def localization_keys() -> set[str]:
    if not LOCALIZATION_CSV.exists():
        return set()
    import csv

    with LOCALIZATION_CSV.open("r", encoding="utf-8-sig", newline="") as handle:
        return {row["key"] for row in csv.DictReader(handle) if row.get("key")}


def collect_loc_keys(value: Any, path: str = "") -> list[tuple[str, str]]:
    found: list[tuple[str, str]] = []
    loc_fields = {
        "name_key",
        "description_key",
        "title_key",
        "text_key",
        "summary_key",
        "role_key",
        "arc_key",
        "scene_key",
    }
    if isinstance(value, dict):
        for key, child in value.items():
            child_path = f"{path}.{key}" if path else key
            if key in loc_fields and isinstance(child, str):
                found.append((child_path, child))
            else:
                found.extend(collect_loc_keys(child, child_path))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            found.extend(collect_loc_keys(child, f"{path}[{index}]"))
    return found


def cycle_nodes(graph: dict[str, list[str]]) -> list[str]:
    visiting: set[str] = set()
    visited: set[str] = set()
    stack: list[str] = []

    def visit(node: str) -> list[str] | None:
        if node in visiting:
            return stack[stack.index(node):] + [node]
        if node in visited:
            return None
        visiting.add(node)
        stack.append(node)
        for dependency in graph.get(node, []):
            if dependency not in graph:
                continue
            found = visit(dependency)
            if found:
                return found
        stack.pop()
        visiting.remove(node)
        visited.add(node)
        return None

    for name in graph:
        found = visit(name)
        if found:
            return found
    return []


def validate() -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []

    data: dict[str, Any] = {}
    for data_name in PAIRS:
        data_path = SCHEMA_DIR / f"{data_name}.json"
        schema_path = JSON_SCHEMA_DIR / f"{data_name}.schema.json"
        if not data_path.exists():
            errors.append(f"Falta el contrato: {data_path.relative_to(ROOT)}")
            continue
        if not schema_path.exists():
            errors.append(f"Falta el JSON Schema: {schema_path.relative_to(ROOT)}")
            continue
        try:
            document = load_json(data_path)
            schema = load_json(schema_path)
        except Exception as exc:  # noqa: BLE001
            errors.append(f"JSON inválido en {data_name}: {exc}")
            continue
        data[data_name] = document
        validator = Draft202012Validator(schema)
        for issue in sorted(validator.iter_errors(document), key=lambda item: list(item.path)):
            location = "/".join(str(part) for part in issue.path) or "<root>"
            errors.append(f"{data_name}: {location}: {issue.message}")

    if errors:
        return errors, warnings

    inventory = data["inventory_tools"]
    vehicle = data["vehicle_components"]
    folklore = data["folklore_entities"]
    dialogue = data["dialogue_and_endings"]
    autoloads = data["autoload_dependencies"]

    item_ids = [item["id"] for item in inventory["items"]]
    for duplicate in duplicate_values(item_ids):
        errors.append(f"inventory_tools: ID repetido {duplicate}")
    item_id_set = set(item_ids)
    for item in inventory["items"]:
        if not item["stackable"] and item["max_stack"] != 1:
            errors.append(f"inventory_tools: {item['id']} no es apilable pero max_stack es {item['max_stack']}")

    component_ids = [component["id"] for component in vehicle["components"]]
    for duplicate in duplicate_values(component_ids):
        errors.append(f"vehicle_components: ID repetido {duplicate}")
    for component in vehicle["components"]:
        for tool_id in component["required_tools"]:
            if tool_id not in item_id_set:
                errors.append(f"vehicle_components: {component['id']} requiere herramienta inexistente {tool_id}")
        for item_id in component["required_items"]:
            if item_id not in item_id_set:
                errors.append(f"vehicle_components: {component['id']} requiere item inexistente {item_id}")
    for tire in ("tires.fl", "tires.fr", "tires.rl", "tires.rr"):
        if tire not in component_ids:
            errors.append(f"vehicle_components: falta la pieza obligatoria {tire}")
    water = vehicle.get("specs", {}).get("water", {})
    if not isinstance(water.get("air_intake_height_m"), (int, float)) or water["air_intake_height_m"] <= 0:
        errors.append("vehicle_components: air_intake_height_m debe ser un número positivo")

    entity_ids = [entity["id"] for entity in folklore["entities"]]
    for duplicate in duplicate_values(entity_ids):
        errors.append(f"folklore_entities: ID repetido {duplicate}")
    missing_entities = REQUIRED_ENTITIES - set(entity_ids)
    if missing_entities:
        errors.append(f"folklore_entities: faltan entidades obligatorias {sorted(missing_entities)}")
    for entity in folklore["entities"]:
        unknown_regions = set(entity["regions"]) - REGIONS
        if unknown_regions:
            errors.append(f"folklore_entities: {entity['id']} usa regiones inválidas {sorted(unknown_regions)}")
        state_ids = [state["id"] for state in entity["states"]]
        for duplicate in duplicate_values(state_ids):
            errors.append(f"folklore_entities: {entity['id']} estado repetido {duplicate}")
        for state in entity["states"]:
            unknown = set(state["next"]) - set(state_ids)
            if unknown:
                errors.append(f"folklore_entities: {entity['id']} transición a estados inexistentes {sorted(unknown)}")
        for action in entity.get("combat", []):
            unknown_items = set(action.get("item_ids", [])) - item_id_set
            if unknown_items:
                errors.append(f"folklore_entities: {entity['id']} usa items inexistentes {sorted(unknown_items)}")
        if entity["audio"].get("mode") == "inverted_distance":
            params = entity["audio"].get("params", {})
            if params.get("real_near_m", 0) >= params.get("real_far_m", 0):
                errors.append(f"folklore_entities: {entity['id']} tiene distancias invertidas inválidas")

    passenger_ids = [passenger["id"] for passenger in dialogue["passengers"]]
    for duplicate in duplicate_values(passenger_ids):
        errors.append(f"dialogue_and_endings: pasajero repetido {duplicate}")
    node_ids = [node["id"] for node in dialogue["nodes"]]
    for duplicate in duplicate_values(node_ids):
        errors.append(f"dialogue_and_endings: nodo repetido {duplicate}")
    node_id_set = set(node_ids)
    if dialogue["entry_node"] not in node_id_set:
        errors.append("dialogue_and_endings: entry_node no existe")
    for node in dialogue["nodes"]:
        if node["next"] is not None and node["next"] not in node_id_set:
            errors.append(f"dialogue_and_endings: nodo {node['id']} apunta a next inexistente {node['next']}")
        for choice in node.get("choices", []):
            if choice["next"] is not None and choice["next"] not in node_id_set:
                errors.append(f"dialogue_and_endings: elección {node['id']}/{choice['id']} apunta a {choice['next']} inexistente")
    ending_ids = [ending["id"] for ending in dialogue["endings"]]
    for duplicate in duplicate_values(ending_ids):
        errors.append(f"dialogue_and_endings: final repetido {duplicate}")
    fallback = dialogue["ending_evaluator"].get("fallback_ending")
    if fallback not in set(ending_ids):
        errors.append(f"dialogue_and_endings: fallback_ending inexistente {fallback}")
    for passenger in dialogue["passengers"]:
        unknown_regions = set(passenger["join_regions"]) - REGIONS
        if unknown_regions:
            errors.append(f"dialogue_and_endings: {passenger['id']} usa regiones inválidas {sorted(unknown_regions)}")

    autoload_names = [entry["name"] for entry in autoloads["autoloads"]]
    for duplicate in duplicate_values(autoload_names):
        errors.append(f"autoload_dependencies: autoload repetido {duplicate}")
    missing_autoloads = REQUIRED_AUTOLOADS - set(autoload_names)
    if missing_autoloads:
        errors.append(f"autoload_dependencies: faltan autoloads {sorted(missing_autoloads)}")
    graph: dict[str, list[str]] = {}
    for entry in autoloads["autoloads"]:
        graph[entry["name"]] = list(entry["depends_on"])
        for dependency in entry["depends_on"]:
            if dependency not in autoload_names:
                errors.append(f"autoload_dependencies: {entry['name']} depende de autoload inexistente {dependency}")
    cycle = cycle_nodes(graph)
    if cycle:
        errors.append("autoload_dependencies: ciclo detectado " + " -> ".join(cycle))

    known_services = set(autoload_names)
    for service in autoloads["scene_services"]:
        if service["name"] in known_services:
            errors.append(f"autoload_dependencies: nombre de servicio duplicado {service['name']}")
        known_services.add(service["name"])
    for service in autoloads["scene_services"]:
        for dependency in service["depends_on"]:
            if dependency not in known_services:
                errors.append(f"autoload_dependencies: {service['name']} depende de servicio desconocido {dependency}")

    known_loc = localization_keys()
    all_loc_uses: list[tuple[str, str]] = []
    for name, document in data.items():
        all_loc_uses.extend(collect_loc_keys(document, name))
    missing_loc = sorted({(path, key) for path, key in all_loc_uses if key not in known_loc})
    if missing_loc:
        warnings.append(
            f"Localización: {len(missing_loc)} claves de datos todavía no están en el CSV base. "
            "Se completarán en F8.4; la UI base usa las claves existentes."
        )

    return errors, warnings


def main() -> int:
    parser = argparse.ArgumentParser(description="Valida los contratos JSON de Ruta Nocturna 1999.")
    parser.add_argument("--warnings-as-errors", action="store_true")
    args = parser.parse_args()
    errors, warnings = validate()
    for warning in warnings:
        print(f"[WARN] {warning}")
    for error in errors:
        print(f"[ERROR] {error}")
    if errors or (args.warnings_as_errors and warnings):
        print(f"\n[FAIL] {len(errors)} errores, {len(warnings)} advertencias.")
        return 1
    print(f"[OK] Contratos válidos: {len(PAIRS)} archivos. {len(warnings)} advertencias.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
