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
    "vehicle_powertrain": "vehicle_powertrain",
    "cabin_interaction": "cabin_interaction",
    "rain_surface_fx": "rain_surface_fx",
    "inventory_tools": "inventory_tools",
    "folklore_entities": "folklore_entities",
    "dialogue_and_endings": "dialogue_and_endings",
    "autoload_dependencies": "autoload_dependencies",
    "world_routes": "world_routes",
    "world_streaming": "world_streaming",
    "world_biomes": "world_biomes",
    "world_weather": "world_weather",
}

BLOCKOUT_SPEC = ROOT / "data" / "vehicle" / "blockout_spec.json"
CABIN_SPEC = ROOT / "data" / "vehicle" / "cabin_spec.json"
EXTERIOR_SPEC = ROOT / "data" / "vehicle" / "exterior_spec.json"

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


def polygon_area_3d(points: list[list[float]]) -> float:
    """Area of a planar polygon given as 3D vertices in order."""
    if len(points) < 3:
        return 0.0
    origin = points[0]
    total = 0.0
    for index in range(1, len(points) - 1):
        ax = points[index][0] - origin[0]
        ay = points[index][1] - origin[1]
        az = points[index][2] - origin[2]
        bx = points[index + 1][0] - origin[0]
        by = points[index + 1][1] - origin[1]
        bz = points[index + 1][2] - origin[2]
        cx = ay * bz - az * by
        cy = az * bx - ax * bz
        cz = ax * by - ay * bx
        total += (cx * cx + cy * cy + cz * cz) ** 0.5 * 0.5
    return total


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
        "label_key",
        "hint_key",
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
    powertrain = data["vehicle_powertrain"]
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

    # Contrato de simulación del tren motriz: coherencia con el vehículo, la
    # caja declarada y el bloqueo paramétrico. Los valores de simulación siguen
    # marcados como provisionales en el propio contrato.
    if powertrain.get("vehicle_id") != vehicle.get("vehicle_id"):
        errors.append("vehicle_powertrain: vehicle_id no coincide con vehicle_components")
    engine_spec = vehicle.get("specs", {}).get("engine", {})
    powertrain_engine = powertrain.get("engine", {})
    if int(powertrain_engine.get("displacement_cc", -1)) != int(engine_spec.get("displacement_cc", -2)):
        errors.append("vehicle_powertrain: cilindrada distinta de vehicle_components")
    transmission_spec = vehicle.get("specs", {}).get("transmission", {})
    powertrain_transmission = powertrain.get("transmission", {})
    if powertrain_transmission.get("selector_modes") != transmission_spec.get("selector_modes"):
        errors.append("vehicle_powertrain: selector_modes distinto de vehicle_components")
    if bool(powertrain_transmission.get("overdrive")) != bool(transmission_spec.get("overdrive")):
        errors.append("vehicle_powertrain: overdrive distinto de vehicle_components")
    if int(powertrain_transmission.get("gears", 0)) != int(transmission_spec.get("gears", -1)):
        errors.append("vehicle_powertrain: número de marchas distinto de vehicle_components")
    if float(powertrain.get("fuel", {}).get("tank_capacity_l", -1)) != float(vehicle.get("specs", {}).get("fuel", {}).get("tank_liters", -2)):
        errors.append("vehicle_powertrain: capacidad de combustible distinta de vehicle_components")
    fan_components = powertrain.get("cooling", {}).get("fan_components", {})
    for role, component_id in fan_components.items():
        if component_id not in component_ids:
            errors.append(f"vehicle_powertrain: fan_components.{role} apunta a componente inexistente {component_id}")
    torque_curve = powertrain_engine.get("torque_curve_nm", [])
    previous_rpm = -1.0
    for point in torque_curve:
        if not isinstance(point, list) or len(point) != 2:
            errors.append("vehicle_powertrain: punto de torque_curve_nm inválido")
            continue
        rpm, _torque = float(point[0]), float(point[1])
        if rpm <= previous_rpm:
            errors.append("vehicle_powertrain: torque_curve_nm debe tener RPM crecientes")
        previous_rpm = rpm
    gear_ratios = powertrain_transmission.get("gear_ratios", [])
    if len(gear_ratios) != int(powertrain_transmission.get("gears", 0)):
        errors.append("vehicle_powertrain: gear_ratios no coincide con gears")
    if int(powertrain_transmission.get("low_max_gear", 0)) > int(powertrain_transmission.get("second_max_gear", 0)):
        errors.append("vehicle_powertrain: low_max_gear no puede superar second_max_gear")
    for gear in range(1, int(powertrain_transmission.get("gears", 0))):
        if str(gear) not in powertrain_transmission.get("upshift_kph", {}):
            errors.append(f"vehicle_powertrain: falta upshift_kph para la marcha {gear}")
    for gear in range(2, int(powertrain_transmission.get("gears", 0)) + 1):
        if str(gear) not in powertrain_transmission.get("downshift_kph", {}):
            errors.append(f"vehicle_powertrain: falta downshift_kph para la marcha {gear}")
    cooling = powertrain.get("cooling", {})
    if not (float(cooling.get("thermostat_open_c", 0)) < float(cooling.get("thermostat_full_open_c", 0))):
        errors.append("vehicle_powertrain: thermostat_open_c debe ser menor que thermostat_full_open_c")
    if not (float(cooling.get("fan_low_on_c", 0)) < float(cooling.get("fan_high_on_c", 0))):
        errors.append("vehicle_powertrain: fan_low_on_c debe ser menor que fan_high_on_c")
    if not (float(cooling.get("overheat_warning_c", 0)) < float(cooling.get("safe_mode_c", 0)) < float(cooling.get("seize_c", 0))):
        errors.append("vehicle_powertrain: umbrales térmicos fuera de orden")
    brakes = powertrain.get("brakes", {})
    if not (float(brakes.get("fade_start_c", 0)) < float(brakes.get("fade_full_c", 0))):
        errors.append("vehicle_powertrain: fade_start_c debe ser menor que fade_full_c")
    fuel = powertrain.get("fuel", {})
    if not (float(fuel.get("empty_threshold_l", 0)) < float(fuel.get("low_warning_l", 0)) < float(fuel.get("tank_capacity_l", 0))):
        errors.append("vehicle_powertrain: umbrales de combustible fuera de orden")
    if BLOCKOUT_SPEC.exists():
        blockout = load_json(BLOCKOUT_SPEC)
        blockout_radius = float(blockout.get("dimensions", {}).get("wheel_radius_m", -1))
        if abs(float(powertrain.get("vehicle", {}).get("wheel_radius_m", -2)) - blockout_radius) > 0.001:
            errors.append("vehicle_powertrain: wheel_radius_m no coincide con blockout_spec.json")
    else:
        errors.append("vehicle_powertrain: falta data/vehicle/blockout_spec.json para la comprobación del radio de rueda")

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

    # Contrato de interaccion contextual de la cabina: delega la palanca y el
    # Overdrive en vehicle_powertrain.json y el freno de mano en brakes.parking.
    # No define fisica de conduccion ni guardado. Desde la version 2 (F2.4)
    # declara espejos SubViewport, HUD minimo y gamepad/D-Pad.
    interaction = data["cabin_interaction"]
    if interaction.get("vehicle_id") != vehicle.get("vehicle_id"):
        errors.append("cabin_interaction: vehicle_id no coincide con vehicle_components")
    interaction_loc = localization_keys()
    controls = interaction.get("controls", [])
    control_ids = [str(control.get("id", "")) for control in controls]
    for duplicate in duplicate_values(control_ids):
        errors.append(f"cabin_interaction: control repetido {duplicate}")
    control_id_set = set(control_ids)
    required_controls = {
        "steering_wheel",
        "gear_lever",
        "overdrive_button",
        "handbrake",
        "door_driver",
        "door_passenger",
        "central_lock",
        "window_driver_up",
        "window_driver_down",
        "window_passenger_up",
        "window_passenger_down",
        "lights",
        "antenna",
        "radio_power",
        "radio_band",
        "radio_seek",
        "radio_volume_up",
        "radio_volume_down",
        "glovebox",
    }
    missing_controls = sorted(required_controls - control_id_set)
    if missing_controls:
        errors.append(f"cabin_interaction: faltan controles {missing_controls}")

    poses = interaction.get("hands", {}).get("poses", [])
    pose_ids = [str(pose.get("id", "")) for pose in poses]
    for duplicate in duplicate_values(pose_ids):
        errors.append(f"cabin_interaction: pose IK repetida {duplicate}")
    pose_id_set = set(pose_ids)
    if len(poses) < 3:
        errors.append("cabin_interaction: se requieren al menos tres poses IK")

    if CABIN_SPEC.exists():
        cabin = load_json(CABIN_SPEC)
        if cabin.get("vehicle_id") != vehicle.get("vehicle_id"):
            errors.append("cabin_interaction: vehicle_id no coincide con cabin_spec.json")
        anchors = {
            str(anchor.get("id", "")): anchor
            for anchor in cabin.get("rig_anchor", {}).get("anchors", [])
        }
        wheel_anchors = {
            str(interaction.get("hands", {}).get("wheel", {}).get("left_anchor", "")),
            str(interaction.get("hands", {}).get("wheel", {}).get("right_anchor", "")),
        }
        hand_counts: set[int] = set()
        for pose in poses:
            on_wheel = 0
            for side in ("left", "right"):
                target = pose.get(side, {})
                kind = str(target.get("kind", ""))
                target_id = str(target.get("id", ""))
                if kind == "anchor":
                    if target_id not in anchors:
                        errors.append(
                            f"cabin_interaction: pose {pose.get('id')} usa ancla inexistente {target_id}"
                        )
                    if target_id in wheel_anchors:
                        on_wheel += 1
                elif kind == "control":
                    if target_id not in control_id_set:
                        errors.append(
                            f"cabin_interaction: pose {pose.get('id')} usa control inexistente {target_id}"
                        )
                elif kind != "rest":
                    errors.append(
                        f"cabin_interaction: pose {pose.get('id')} tiene destino IK invalido {kind}"
                    )
            hand_counts.add(on_wheel)
        if hand_counts != {0, 1, 2}:
            errors.append(
                f"cabin_interaction: las poses no cubren 2/1/0 manos en el volante ({sorted(hand_counts)})"
            )
        for pose_id in ("pose_rest", "pose_steering", "pose_gear", "pose_handbrake"):
            if pose_id not in pose_id_set:
                errors.append(f"cabin_interaction: falta la pose obligatoria {pose_id}")
        gate = cabin.get("components", {}).get("gear_gate_plate", {})
        gate_min_z = float(gate.get("min_m", [0, 0, -999])[2])
        gate_max_z = float(gate.get("max_m", [0, 0, 999])[2])
        for detent in interaction.get("gear_gate", {}).get("detents", []):
            detent_z = float(detent.get("position_m", [0, 0, 0])[2])
            if not (gate_min_z <= detent_z <= gate_max_z):
                errors.append(
                    f"cabin_interaction: detente {detent.get('mode')} fuera de la guia de palanca"
                )
        min_touch = float(interaction.get("interaction", {}).get("touch_radius_dp", 0))
        if min_touch < 44:
            errors.append("cabin_interaction: touch_radius_dp debe ser al menos 44")
        width = float(cabin.get("validation_rules", {}).get("controls_within_cabin_width_m", 0.75))
        height = cabin.get("validation_rules", {}).get("controls_within_height_m", {})
        y_min = float(height.get("min", 0.4))
        y_max = float(height.get("max", 1.25))
        for control in controls:
            for field in ("position_m", "interaction_position_m"):
                if field not in control:
                    if field == "position_m":
                        errors.append(f"cabin_interaction: {control.get('id')} sin posicion 3D")
                    continue
                position = control.get(field, [])
                if len(position) != 3:
                    errors.append(f"cabin_interaction: {control.get('id')} {field} invalida")
                    continue
                x, y, z = (float(value) for value in position)
                if abs(x) > width or not (y_min <= y <= y_max) or not (-1.0 <= z <= 0.5):
                    errors.append(
                        f"cabin_interaction: {control.get('id')} {field} fuera de los limites de cabina"
                    )
            if control.get("pose") not in pose_id_set:
                errors.append(
                    f"cabin_interaction: {control.get('id')} usa pose inexistente {control.get('pose')}"
                )
            for key in ("label_key", "hint_key"):
                loc_key = str(control.get(key, ""))
                if loc_key not in interaction_loc:
                    errors.append(f"cabin_interaction: {control.get('id')} usa clave ausente {loc_key}")
        for code, loc_key in interaction.get("feedback", {}).items():
            if loc_key not in interaction_loc:
                errors.append(f"cabin_interaction: feedback {code} usa clave ausente {loc_key}")
    else:
        errors.append("cabin_interaction: falta data/vehicle/cabin_spec.json")

    expected_links = {
        "gear_lever": "transmission.selector",
        "overdrive_button": "transmission.overdrive",
        "handbrake": "brakes.parking",
    }
    for control in controls:
        expected = expected_links.get(str(control.get("id", "")))
        if expected is not None and control.get("powertrain_link") != expected:
            errors.append(
                f"cabin_interaction: {control.get('id')} debe delegar en {expected}"
            )
        if control.get("id") == "steering_wheel" and control.get("powertrain_link") != "none":
            errors.append("cabin_interaction: steering_wheel no debe duplicar fisica de direccion")

    gear_modes = interaction.get("gear_gate", {}).get("modes", [])
    if gear_modes != powertrain_transmission.get("selector_modes"):
        errors.append("cabin_interaction: gear_gate.modes no coincide con vehicle_powertrain")
    detent_modes = [str(detent.get("mode", "")) for detent in interaction.get("gear_gate", {}).get("detents", [])]
    if detent_modes != gear_modes:
        errors.append("cabin_interaction: los detentes no siguen el orden P-R-N-D-2-L")
    if interaction.get("doors", {}).get("ids") != ["driver", "passenger"]:
        errors.append("cabin_interaction: doors.ids debe ser driver/passenger")
    if interaction.get("windows", {}).get("ids") != ["driver", "passenger"]:
        errors.append("cabin_interaction: windows.ids debe ser driver/passenger")
    if interaction.get("lights", {}).get("states") != ["off", "parking", "headlights"]:
        errors.append("cabin_interaction: estados de luces invalidos")
    if interaction.get("radio", {}).get("bands") != ["AM", "FM"]:
        errors.append("cabin_interaction: bandas de radio invalidas")

    # --- F2.4: espejos, HUD y gamepad (cabin_interaction v2) -------------------
    if int(interaction.get("schema_version", 0)) != 2:
        errors.append("cabin_interaction: schema_version debe ser 2 desde F2.4")
    history_versions = [
        int(entry.get("version", 0)) for entry in interaction.get("schema_history", []) if isinstance(entry, dict)
    ]
    if history_versions != [1, 2]:
        errors.append("cabin_interaction: schema_history debe documentar v1 -> v2")

    mirrors = interaction.get("mirrors", {})
    mirror_ids = [str(entry.get("id", "")) for entry in mirrors.get("entries", []) if isinstance(entry, dict)]
    if mirror_ids != list(mirrors.get("ids", [])):
        errors.append("cabin_interaction: mirrors.entries no coincide con mirrors.ids")
    if sorted(mirror_ids) != ["left", "rearview", "right"]:
        errors.append("cabin_interaction: se esperan los espejos rearview/left/right")
    mirror_budget = mirrors.get("budget", {})
    if int(mirror_budget.get("scene_passes", -1)) != len(mirror_ids):
        errors.append("cabin_interaction: mirrors.budget.scene_passes debe ser igual al numero de espejos")
    surface_triangles = 2 * len(mirror_ids)
    if surface_triangles > int(mirror_budget.get("surface_max_triangles_total", 0)):
        errors.append("cabin_interaction: superficies de espejo superan su presupuesto de triangulos")
    if mirror_budget.get("counted_in_mobile_budget") is not True:
        errors.append("cabin_interaction: los espejos deben contar en el presupuesto movil")
    if BLOCKOUT_SPEC.exists():
        blockout_doc = load_json(BLOCKOUT_SPEC)
        blockout_anchors = {
            str(anchor.get("id", "")): anchor.get("position_m", [])
            for anchor in blockout_doc.get("rig_anchor", {}).get("anchors", [])
        }
        for entry in mirrors.get("entries", []):
            if not isinstance(entry, dict):
                continue
            mirror_id = str(entry.get("id", ""))
            anchor = str(entry.get("anchor", ""))
            position = entry.get("position_m", [])
            if len(position) != 3:
                errors.append(f"cabin_interaction: espejo {mirror_id} sin posicion 3D")
                continue
            x, y, z = (float(value) for value in position)
            if abs(x) > 1.0 or not (0.5 <= y <= 1.45) or not (-1.1 <= z <= 0.5):
                errors.append(f"cabin_interaction: espejo {mirror_id} fuera de los limites de cabina")
            if str(entry.get("kind", "")) == "side":
                if not anchor:
                    errors.append(f"cabin_interaction: espejo lateral {mirror_id} sin ancla")
                elif anchor not in blockout_anchors:
                    errors.append(f"cabin_interaction: espejo {mirror_id} usa ancla inexistente {anchor}")
                else:
                    anchor_position = blockout_anchors[anchor]
                    if len(anchor_position) == 3 and any(
                        abs(float(anchor_position[index]) - position[index]) > 0.01 for index in range(3)
                    ):
                        errors.append(f"cabin_interaction: espejo {mirror_id} no coincide con {anchor}")
            elif anchor:
                errors.append(f"cabin_interaction: espejo interior {mirror_id} no debe declarar ancla")

    hud = interaction.get("hud", {})
    if str(hud.get("source", "")) != "VehiclePowertrain.get_telemetry":
        errors.append("cabin_interaction: hud.source debe ser VehiclePowertrain.get_telemetry")
    if int(hud.get("max_persistent_buttons", -1)) != 0:
        errors.append("cabin_interaction: el HUD no declara botones tactiles persistentes")
    if hud.get("text_not_only_color") is not True:
        errors.append("cabin_interaction: el HUD debe informar con texto, no solo con color")
    expected_warning_codes = {
        "fuel_low",
        "overheat",
        "fan_fault",
        "brake_fade",
        "parking_brake",
        "safe_mode",
        "brake_fluid_low",
        "engine_seized",
    }
    hud_warning_keys = hud.get("warning_keys", {})
    if set(hud_warning_keys) != expected_warning_codes:
        errors.append("cabin_interaction: hud.warning_keys debe cubrir los avisos del tren motriz")
    hud_loc_keys: list[str] = [str(value) for value in hud.get("label_keys", {}).values() if isinstance(value, str)]
    hud_loc_keys.extend(str(value) for value in hud_warning_keys.values() if isinstance(value, str))
    for loc_key in hud_loc_keys:
        if loc_key not in interaction_loc:
            errors.append(f"cabin_interaction: clave de HUD ausente en el CSV {loc_key}")

    gamepad = interaction.get("gamepad", {})
    if float(gamepad.get("min_target_dp", 0)) < 44:
        errors.append("cabin_interaction: gamepad.min_target_dp debe ser al menos 44")
    if gamepad.get("tv_navigation_required") is not True:
        errors.append("cabin_interaction: la navegacion D-Pad/TV es obligatoria")
    cabin_input = gamepad.get("cabin", {})
    next_buttons = set(cabin_input.get("focus_next_buttons", []))
    previous_buttons = set(cabin_input.get("focus_previous_buttons", []))
    if not next_buttons or not previous_buttons:
        errors.append("cabin_interaction: gamepad.cabin requiere botones de foco")
    if next_buttons & previous_buttons:
        errors.append("cabin_interaction: botones de foco solapados en gamepad.cabin")

    # --- F3.3: lluvia fisica, humedad, gotas, limpiaparabrisas y charcos -----
    rain = data["rain_surface_fx"]
    if rain.get("vehicle_id") != vehicle.get("vehicle_id"):
        errors.append("rain_surface_fx: vehicle_id no coincide con vehicle_components")
    if int(rain.get("schema_version", 0)) != 1:
        errors.append("rain_surface_fx: schema_version debe ser 1")
    rain_history = [
        int(entry.get("version", 0)) for entry in rain.get("schema_history", []) if isinstance(entry, dict)
    ]
    if rain_history != [1]:
        errors.append("rain_surface_fx: schema_history debe documentar v1")

    surfaces = rain.get("surfaces", {})
    surface_classes = surfaces.get("classes", [])
    class_ids = [str(item.get("id", "")) for item in surface_classes if isinstance(item, dict)]
    for duplicate in duplicate_values(class_ids):
        errors.append(f"rain_surface_fx: clase de superficie repetida {duplicate}")
    for item in surface_classes:
        if not isinstance(item, dict):
            continue
        class_id = str(item.get("id", ""))
        if float(item.get("nucleation_wetness", 1.0)) > float(item.get("saturation_wetness", 0.0)):
            errors.append(f"rain_surface_fx: {class_id} nucleation_wetness supera saturation_wetness")
        if float(item.get("retention_mm", 0.0)) >= float(item.get("max_film_mm", 0.0)):
            errors.append(f"rain_surface_fx: {class_id} retention_mm debe ser menor que max_film_mm")

    panels = surfaces.get("vehicle_panels", [])
    panel_ids = [str(item.get("id", "")) for item in panels if isinstance(item, dict)]
    for duplicate in duplicate_values(panel_ids):
        errors.append(f"rain_surface_fx: panel de vehiculo repetido {duplicate}")
    panels_by_id = {str(item.get("id", "")): item for item in panels if isinstance(item, dict)}
    for required_panel in ("windshield", "rear_window", "hood", "roof", "trunk_lid", "side_glass"):
        if required_panel not in panels_by_id:
            errors.append(f"rain_surface_fx: falta el panel obligatorio {required_panel}")
    for panel in panels:
        if not isinstance(panel, dict):
            continue
        panel_id = str(panel.get("id", ""))
        if str(panel.get("surface_class", "")) not in class_ids:
            errors.append(f"rain_surface_fx: panel {panel_id} usa clase inexistente {panel.get('surface_class')}")
        if str(panel.get("droplet_profile", "")) not in {"glass", "paint"}:
            errors.append(f"rain_surface_fx: panel {panel_id} usa perfil de gotas desconocido")
        size = panel.get("surface_size_m", [])
        if len(size) != 2 or any(float(value) <= 0 for value in size):
            errors.append(f"rain_surface_fx: panel {panel_id} tiene surface_size_m invalido")
        flow = panel.get("flow_dir", [])
        if len(flow) != 2 or (float(flow[0]) == 0.0 and float(flow[1]) == 0.0):
            errors.append(f"rain_surface_fx: panel {panel_id} tiene flow_dir invalido")
    if panels_by_id.get("windshield", {}).get("wiper_zone") != "windshield":
        errors.append("rain_surface_fx: el parabrisas debe declarar wiper_zone windshield")
    for panel_id, panel in panels_by_id.items():
        if panel_id != "windshield" and panel.get("wiper_zone") != "none":
            errors.append(f"rain_surface_fx: el panel {panel_id} no debe declarar limpiaparabrisas")

    road_surfaces = surfaces.get("road_surfaces", [])
    road_ids = [str(item.get("id", "")) for item in road_surfaces if isinstance(item, dict)]
    for duplicate in duplicate_values(road_ids):
        errors.append(f"rain_surface_fx: superficie de via repetida {duplicate}")
    for road in road_surfaces:
        if not isinstance(road, dict):
            continue
        if str(road.get("surface_class", "")) not in class_ids:
            errors.append(
                f"rain_surface_fx: superficie de via {road.get('id')} usa clase inexistente {road.get('surface_class')}"
            )

    wetness = rain.get("wetness", {})
    wet_thresholds = wetness.get("state_thresholds", {})
    wet_values = [float(wet_thresholds.get(name, -1)) for name in ("dry", "damp", "wet", "soaked")]
    if not all(0.0 <= value <= 1.0 for value in wet_values) or wet_values != sorted(wet_values) or len(set(wet_values)) != 4:
        errors.append("rain_surface_fx: wetness.state_thresholds debe ser creciente y estar en 0..1")
    if int(wetness.get("pc_update_hz", 0)) < int(wetness.get("mobile_update_hz", 0)):
        errors.append("rain_surface_fx: la actualizacion PC no puede ser menor que la movil")

    droplets = rain.get("droplets", {})
    profiles = droplets.get("profiles", [])
    profile_ids = [str(item.get("id", "")) for item in profiles if isinstance(item, dict)]
    for duplicate in duplicate_values(profile_ids):
        errors.append(f"rain_surface_fx: perfil de gotas repetido {duplicate}")
    for required_profile in ("glass", "paint"):
        if required_profile not in profile_ids:
            errors.append(f"rain_surface_fx: falta el perfil de gotas {required_profile}")
    for profile in profiles:
        if not isinstance(profile, dict):
            continue
        profile_id = str(profile.get("id", ""))
        if float(profile.get("min_radius_mm", 0)) >= float(profile.get("max_radius_mm", 0)):
            errors.append(f"rain_surface_fx: {profile_id} tiene radios de gota fuera de orden")
        if float(profile.get("initial_radius_mm", 0)) < float(profile.get("min_radius_mm", 0)):
            errors.append(f"rain_surface_fx: {profile_id} initial_radius_mm menor que min_radius_mm")
        if float(profile.get("nucleation_wetness", 1)) > float(profile.get("growth_wetness", 0)):
            errors.append(f"rain_surface_fx: {profile_id} nucleation_wetness supera growth_wetness")
        bounds = profile.get("bounds_m", [])
        if len(bounds) != 2 or any(float(value) <= 0 for value in bounds):
            errors.append(f"rain_surface_fx: {profile_id} tiene bounds_m invalido")
    stride = int(droplets.get("instance_stride", 0))
    if stride != len(droplets.get("instance_layout", [])):
        errors.append("rain_surface_fx: instance_stride no coincide con instance_layout")

    wiper = rain.get("wiper", {})
    if wiper.get("vehicle_id") != vehicle.get("vehicle_id"):
        errors.append("rain_surface_fx: wiper.vehicle_id no coincide con vehicle_components")
    wipers = wiper.get("wipers", [])
    wiper_ids = [str(item.get("id", "")) for item in wipers if isinstance(item, dict)]
    if wiper_ids != ["left", "right"]:
        errors.append("rain_surface_fx: se esperan los limpiaparabrisas left/right en orden")
    if int(wiper.get("wiper_count", 0)) != len(wipers):
        errors.append("rain_surface_fx: wiper_count no coincide con wipers")
    wipers_by_id = {str(item.get("id", "")): item for item in wipers if isinstance(item, dict)}
    for wiper_entry in wipers:
        if not isinstance(wiper_entry, dict):
            continue
        wiper_id = str(wiper_entry.get("id", ""))
        if abs(float(wiper_entry.get("rest_angle_deg", 0)) - float(wiper_entry.get("park_angle_deg", 0))) > 0.01:
            errors.append(f"rain_surface_fx: {wiper_id} rest_angle_deg debe coincidir con park_angle_deg")
        if abs(float(wiper_entry.get("sweep_delta_deg", 0))) < 10:
            errors.append(f"rain_surface_fx: {wiper_id} tiene un barrido demasiado pequeno")
        if float(wiper_entry.get("clearing_efficiency_worn", 1)) >= float(
            wiper_entry.get("clearing_efficiency_new", 0)
        ):
            errors.append(f"rain_surface_fx: {wiper_id} la goma gastada no puede limpiar igual que la nueva")
    if "left" in wipers_by_id and "right" in wipers_by_id:
        left_sweep = float(wipers_by_id["left"].get("sweep_delta_deg", 0))
        right_sweep = float(wipers_by_id["right"].get("sweep_delta_deg", 0))
        if left_sweep * right_sweep >= 0:
            errors.append("rain_surface_fx: los barridos left/right deben ser espejo")
    modes = wiper.get("modes", {})
    low_cycles = float(modes.get("low", {}).get("cycles_per_min", 0))
    high_cycles = float(modes.get("high", {}).get("cycles_per_min", 0))
    if not (0 < low_cycles < high_cycles):
        errors.append("rain_surface_fx: las velocidades low/high de limpiaparabrisas estan fuera de orden")
    if float(modes.get("off", {}).get("cycles_per_min", -1)) != 0:
        errors.append("rain_surface_fx: el modo off debe detener el limpiaparabrisas")
    intermittent = modes.get("intermittent", {})
    delays = [float(value) for value in intermittent.get("delays_s", [])]
    if len(delays) < 2 or delays != sorted(delays) or len(set(delays)) != len(delays):
        errors.append("rain_surface_fx: los retardos intermitentes deben ser crecientes")
    default_index = int(intermittent.get("default_index", -1))
    if default_index < 0 or default_index >= len(delays):
        errors.append("rain_surface_fx: intermittent.default_index fuera de rango")
    if wiper.get("anti_softlock", {}).get("wear_blocks_driving") is not False:
        errors.append("rain_surface_fx: el desgaste del limpiaparabrisas no puede bloquear la conduccion")
    if wiper.get("anti_softlock", {}).get("failure_blocks_controls") is not False:
        errors.append("rain_surface_fx: el fallo del limpiaparabrisas no puede bloquear los controles")

    if EXTERIOR_SPEC.exists():
        exterior = load_json(EXTERIOR_SPEC)
        windshield = next(
            (
                item
                for item in exterior.get("glass_panels", [])
                if isinstance(item, dict) and item.get("id") == "windshield"
            ),
            None,
        )
        if windshield is None:
            errors.append("rain_surface_fx: exterior_spec.json no declara el panel windshield")
        else:
            corners = windshield.get("corners_m", [])
            computed_area = polygon_area_3d(corners) if isinstance(corners, list) else 0.0
            declared_area = float(panels_by_id.get("windshield", {}).get("area_m2", 0))
            if computed_area <= 0:
                errors.append("rain_surface_fx: no se pudo calcular el area del parabrisas")
            elif abs(declared_area - computed_area) > max(0.08 * computed_area, 0.01):
                errors.append(
                    "rain_surface_fx: el area del parabrisas no coincide con exterior_spec.json "
                    f"({declared_area:.3f} vs {computed_area:.3f} m2)"
                )
        pieces = {
            str(item.get("id", "")): item for item in exterior.get("pieces", []) if isinstance(item, dict)
        }
        for side, piece_id in (("left", "wiper_left"), ("right", "wiper_right")):
            piece = pieces.get(piece_id)
            entry = wipers_by_id.get(side)
            if piece is None or entry is None:
                errors.append(f"rain_surface_fx: falta {piece_id} en exterior_spec.json o en el contrato")
                continue
            minimum = [float(value) for value in piece.get("min_m", [0, 0, 0])]
            maximum = [float(value) for value in piece.get("max_m", [0, 0, 0])]
            box_length = maximum[0] - minimum[0]
            declared_length = float(entry.get("blade_length_m", 0))
            if abs(box_length - declared_length) > 0.02:
                errors.append(
                    f"rain_surface_fx: {side}.blade_length_m no coincide con {piece_id} "
                    f"({declared_length:.3f} vs {box_length:.3f} m)"
                )
            pivot = [float(value) for value in entry.get("pivot_m", [0, 0, 0])]
            inner_x = maximum[0] if side == "left" else minimum[0]
            center_y = (minimum[1] + maximum[1]) * 0.5
            center_z = (minimum[2] + maximum[2]) * 0.5
            if abs(inner_x - pivot[0]) > 0.02 or abs(center_y - pivot[1]) > 0.06 or abs(center_z - pivot[2]) > 0.06:
                errors.append(f"rain_surface_fx: {side}.pivot_m no coincide con el extremo interior de {piece_id}")
    else:
        errors.append("rain_surface_fx: falta data/vehicle/exterior_spec.json")

    puddles = rain.get("puddles", {})
    zones = puddles.get("zone_archetypes", [])
    zone_ids = [str(item.get("id", "")) for item in zones if isinstance(item, dict)]
    for duplicate in duplicate_values(zone_ids):
        errors.append(f"rain_surface_fx: arquetipo de charco repetido {duplicate}")
    for required_zone in ("asphalt_crown", "asphalt_low_spot", "pothole", "dirt_shoulder", "ford_crossing"):
        if required_zone not in zone_ids:
            errors.append(f"rain_surface_fx: falta el arquetipo de charco {required_zone}")
    for zone in zones:
        if not isinstance(zone, dict):
            continue
        zone_id = str(zone.get("id", ""))
        capacity = float(zone.get("capacity_mm", 0))
        hydroplane_depth = float(zone.get("hydroplane_depth_mm", 0))
        visible_depth = float(zone.get("visible_depth_mm", 0))
        if not (0 <= visible_depth < capacity):
            errors.append(f"rain_surface_fx: {zone_id} visible_depth_mm debe quedar dentro de capacity_mm")
        if not (0 <= hydroplane_depth < capacity):
            errors.append(f"rain_surface_fx: {zone_id} hydroplane_depth_mm debe quedar dentro de capacity_mm")
    water = vehicle.get("specs", {}).get("water", {})
    link = puddles.get("vehicle_water_link", {})
    if abs(float(link.get("air_intake_height_m", -1)) - float(water.get("air_intake_height_m", -2))) > 0.001:
        errors.append("rain_surface_fx: air_intake_height_m no coincide con vehicle_components")
    if abs(float(link.get("safe_wading_depth_m", -1)) - float(water.get("safe_wading_depth_m", -2))) > 0.001:
        errors.append("rain_surface_fx: safe_wading_depth_m no coincide con vehicle_components")
    puddle_thresholds = puddles.get("state_thresholds", {})
    puddle_values = [float(puddle_thresholds.get(name, -1)) for name in ("dry", "damp", "standing", "deep")]
    if not all(0.0 <= value <= 1.0 for value in puddle_values) or puddle_values != sorted(puddle_values) or len(set(puddle_values)) != 4:
        errors.append("rain_surface_fx: puddles.state_thresholds debe ser creciente y estar en 0..1")
    if puddles.get("wading_states") != ["safe", "caution", "danger"]:
        errors.append("rain_surface_fx: wading_states debe declarar safe/caution/danger")
    if not (float(puddles.get("hydroplane", {}).get("min_speed_kph", 0)) < float(
        puddles.get("hydroplane", {}).get("full_speed_kph", 0)
    )):
        errors.append("rain_surface_fx: hydroplane min_speed_kph debe ser menor que full_speed_kph")

    budgets = rain.get("budgets", {})
    pc = budgets.get("pc", {})
    mobile = budgets.get("mobile", {})
    if int(mobile.get("max_droplets_total", 0)) > int(pc.get("max_droplets_total", 0)):
        errors.append("rain_surface_fx: el presupuesto movil de gotas no puede superar al de PC")
    if int(mobile.get("max_puddle_zones", 0)) > int(pc.get("max_puddle_zones", 0)):
        errors.append("rain_surface_fx: el presupuesto movil de charcos no puede superar al de PC")
    if int(mobile.get("simulation_hz", 0)) > int(pc.get("simulation_hz", 0)):
        errors.append("rain_surface_fx: la simulacion movil no puede superar la frecuencia de PC")
    for profile_name, profile in (("pc", pc), ("mobile", mobile)):
        frame_budget = float(profile.get("frame_budget_ms", 0))
        cpu_budget = float(profile.get("rain_cpu_budget_ms", 0))
        p95_budget = float(profile.get("rain_cpu_p95_budget_ms", 0))
        if not (0 < cpu_budget <= frame_budget * 0.1):
            errors.append(f"rain_surface_fx: budgets.{profile_name}.rain_cpu_budget_ms debe ser <= 10 % del frame")
        if not (cpu_budget <= p95_budget <= frame_budget * 0.15):
            errors.append(f"rain_surface_fx: budgets.{profile_name}.rain_cpu_p95_budget_ms fuera de rango")
        if int(profile.get("added_triangles", -1)) != 0 or int(profile.get("added_draw_calls", -1)) != 0:
            errors.append(f"rain_surface_fx: budgets.{profile_name} debe declarar cero triangulos/draw calls en F3.3")
    total_profile_droplets = sum(int(item.get("max_droplets", 0)) for item in profiles if isinstance(item, dict))
    if total_profile_droplets != int(pc.get("max_droplets_total", -1)):
        errors.append(
            "rain_surface_fx: la suma de max_droplets de los perfiles debe igualar budgets.pc.max_droplets_total"
        )
    expected_states = {
        "surface": ["dry", "damp", "wet", "soaked"],
        "droplet": ["nucleated", "growing", "sliding", "evaporating", "removed"],
        "wiper": ["off", "intermittent_wait", "sweeping", "parked"],
        "puddle": ["dry", "damp", "standing", "deep"],
    }
    states = rain.get("states", {})
    for key, expected in expected_states.items():
        if states.get(key) != expected:
            errors.append(f"rain_surface_fx: states.{key} no coincide con el contrato")

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

    # Red de rutas del mundo (F4.1): contrato, artefacto generado, manifiesto,
    # conectividad, alternativas, elevación y atribución ODbL.
    world_tools = ROOT / "tools" / "osm"
    if str(world_tools) not in sys.path:
        sys.path.insert(0, str(world_tools))
    try:
        from route_graph_validation import load_and_validate as validate_world_routes

        world_errors, world_warnings = validate_world_routes(ROOT)
        errors.extend(world_errors)
        warnings.extend(world_warnings)
    except Exception as exc:  # noqa: BLE001
        errors.append(f"world_routes: no se pudo ejecutar la validación de la red: {exc}")

    # Terreno y streaming de sectores de 800 m (F4.2). El módulo verifica el
    # manifiesto, los hashes de los recursos, la cobertura de la red y los
    # presupuestos de terreno.
    world_streaming = data.get("world_streaming", {})
    if world_streaming:
        streaming = world_streaming.get("streaming", {})
        terrain = world_streaming.get("terrain", {})
        collision = world_streaming.get("collision", {})
        budgets = world_streaming.get("budgets", {})
        qa = world_streaming.get("qa", {})
        if float(terrain.get("sector_size_m", 0)) != 800.0:
            errors.append("world_streaming: terrain.sector_size_m debe ser 800")
        if float(streaming.get("sector_size_m", 0)) != 800.0:
            errors.append("world_streaming: streaming.sector_size_m debe ser 800")
        if abs(
            float(terrain.get("grid_spacing_m", 0))
            - float(terrain.get("sector_size_m", 0)) / max(1.0, float(terrain.get("grid_resolution", 1) - 1))
        ) > 0.01:
            errors.append("world_streaming: grid_spacing_m no coincide con sector_size_m / (grid_resolution - 1)")
        if int(streaming.get("ahead_sectors", 0)) + int(streaming.get("behind_sectors", 0)) + 1 > int(
            budgets.get("max_loaded_sectors", 0)
        ):
            errors.append("world_streaming: la ventana de streaming excede max_loaded_sectors")
        if int(budgets.get("max_pending_requests", 0)) != int(streaming.get("max_concurrent_requests", -1)):
            errors.append("world_streaming: max_pending_requests debe coincidir con max_concurrent_requests")
        if int(budgets.get("max_triangles_per_sector", 0)) < 2048:
            errors.append("world_streaming: max_triangles_per_sector es demasiado bajo para la rejilla")
        if collision.get("terrain_shape") != "ConcavePolygonShape3D":
            errors.append("world_streaming: la colisión del terreno debe ser ConcavePolygonShape3D")
        if collision.get("road_shape") != "ConcavePolygonShape3D":
            errors.append("world_streaming: la colisión de la vía debe ser ConcavePolygonShape3D")
        if int(collision.get("terrain_stride", 0)) < 1 or int(collision.get("terrain_stride", 0)) > 4:
            errors.append("world_streaming: terrain_stride debe estar entre 1 y 4")
        if qa.get("android_route") != "slice,cabin,world":
            errors.append("world_streaming: qa.android_route debe incluir world")
        if not str(world_streaming.get("attribution", {}).get("in_game_key", "")) == "CREDITS_OSM":
            errors.append("world_streaming: la atribución debe usar CREDITS_OSM")

        world_tools = ROOT / "tools" / "world"
        if str(world_tools) not in sys.path:
            sys.path.insert(0, str(world_tools))
        try:
            from validate_world_sectors import load_and_validate as validate_world_sectors

            sector_errors, sector_warnings = validate_world_sectors(ROOT)
            errors.extend(sector_errors)
            warnings.extend(sector_warnings)
        except Exception as exc:  # noqa: BLE001
            errors.append(f"world_streaming: no se pudo validar los sectores: {exc}")

    # Kits de biomas, POIs y mobiliario vial (F4.3): mapa de regiones, política
    # de LOD, presupuestos frente a world.streaming, claridad de la vía
    # (anti-softlock), familias de kits generados y claves de localización.
    world_biomes = data.get("world_biomes", {})
    if world_biomes:
        biome_ids = [biome["id"] for biome in world_biomes["biomes"]]
        for duplicate in duplicate_values(biome_ids):
            errors.append(f"world_biomes: ID de bioma repetido {duplicate}")
        expected_biomes = {
            "biome.costa",
            "biome.montana",
            "biome.llanos",
            "biome.selva",
            "biome.delta",
            "biome.industrial",
        }
        if set(biome_ids) != expected_biomes:
            errors.append(f"world_biomes: los biomas deben ser exactamente {sorted(expected_biomes)}")

        region_map = world_biomes["region_biome_map"]
        routes_regions = {region["id"] for region in data["world_routes"]["regions"]}
        if set(region_map) != routes_regions:
            errors.append("world_biomes: region_biome_map no cubre exactamente las regiones de world_routes")
        for region, biome_id in region_map.items():
            if biome_id not in biome_ids:
                errors.append(f"world_biomes: la región {region} apunta a un bioma inexistente {biome_id}")
        for biome in world_biomes["biomes"]:
            if region_map.get(biome["region"]) != biome["id"]:
                errors.append(
                    f"world_biomes: el bioma {biome['id']} no coincide con region_biome_map[{biome['region']}]"
                )

        prop_ids = {prop["id"] for prop in world_biomes["props"]}
        kit_ids = {poi["kit_id"] for poi in world_biomes["pois"]} | prop_ids
        min_clear = float(world_biomes["placement_rules"]["min_clear_road_m"])
        for biome in world_biomes["biomes"]:
            for entry in biome["decor"]:
                if entry["prop"] not in prop_ids:
                    errors.append(f"world_biomes: decor usa un prop inexistente {entry['prop']}")
                if float(entry["min_lateral_m"]) < min_clear:
                    errors.append(f"world_biomes: {biome['id']} decor {entry['prop']} invade la vía")
            for entry in biome["roadside"]:
                if entry["kit"] not in kit_ids:
                    errors.append(f"world_biomes: roadside usa un kit inexistente {entry['kit']}")
                if float(entry["min_lateral_m"]) < min_clear:
                    errors.append(f"world_biomes: {biome['id']} roadside {entry['kit']} invade la vía")
            for preset_name in ("water", "dust", "snow"):
                if preset_name not in biome.get("surface_presets", {}):
                    errors.append(f"world_biomes: {biome['id']} falta el preset {preset_name}")

        for prop in world_biomes["props"]:
            lods = [lod["id"] for lod in prop["lods"]]
            if lods != ["lod0", "lod1", "lod2"]:
                errors.append(f"world_biomes: {prop['id']} debe declarar LOD0/LOD1/LOD2; hay {lods}")
            budgets_chain = [int(lod["max_triangles"]) for lod in prop["lods"]]
            if not all(budgets_chain[i] > budgets_chain[i + 1] for i in range(len(budgets_chain) - 1)):
                errors.append(f"world_biomes: presupuestos de LOD no decrecientes en {prop['id']}: {budgets_chain}")

        poi_ids = [poi["id"] for poi in world_biomes["pois"]]
        for duplicate in duplicate_values(poi_ids):
            errors.append(f"world_biomes: ID de POI repetido {duplicate}")
        for poi in world_biomes["pois"]:
            lods = [lod["id"] for lod in poi["lods"]]
            if lods != ["lod0", "lod1", "lod2"]:
                errors.append(f"world_biomes: {poi['id']} debe declarar LOD0/LOD1/LOD2; hay {lods}")
            budgets_chain = [int(lod["max_triangles"]) for lod in poi["lods"]]
            if not all(budgets_chain[i] > budgets_chain[i + 1] for i in range(len(budgets_chain) - 1)):
                errors.append(f"world_biomes: presupuestos de LOD no decrecientes en {poi['id']}: {budgets_chain}")
            placement = poi["placement"]
            if float(placement["min_clear_road_m"]) < min_clear:
                errors.append(f"world_biomes: {poi['id']} puede invadir la vía")
            if placement["mode"] == "route_interval" and float(placement.get("lateral_m", 0.0)) < min_clear:
                errors.append(f"world_biomes: {poi['id']} se coloca demasiado cerca de la vía")
            for biome_id in poi["biomes"]:
                if biome_id not in biome_ids:
                    errors.append(f"world_biomes: {poi['id']} referencia un bioma inexistente {biome_id}")
            if not poi["brands_forbidden"]:
                errors.append(f"world_biomes: {poi['id']} debe declarar brands_forbidden")

        biome_budgets = world_biomes["budgets"]
        streaming_budgets = data["world_streaming"]["budgets"]
        terrain_triangles = int(biome_budgets["terrain_triangles_per_sector"])
        road_observed = int(biome_budgets.get("road_triangles_per_sector_observed_f42", 328))
        decor_triangles = int(biome_budgets["max_decor_triangles_per_sector"])
        if terrain_triangles + road_observed + decor_triangles > int(biome_budgets["max_sector_triangles_total"]):
            errors.append("world_biomes: terreno + vía + decor superan max_sector_triangles_total")
        if int(biome_budgets["max_sector_triangles_total"]) > int(streaming_budgets.get("max_triangles_per_sector", 0)):
            errors.append("world_biomes: max_sector_triangles_total excede el contrato world_streaming")
        if int(biome_budgets.get("max_road_furniture_triangles_per_sector", 0)) > decor_triangles:
            errors.append("world_biomes: el mobiliario vial excede el presupuesto de decor por sector")
        if int(biome_budgets["max_kit_concurrent_load_requests"]) > int(
            streaming_budgets.get("max_pending_requests", 2)
        ):
            errors.append("world_biomes: la carga de kits excede las 2 solicitudes simultáneas de world_streaming")
        if int(biome_budgets.get("max_sector_builds_per_frame", 0)) != int(
            streaming_budgets.get("max_sector_builds_per_frame", 1)
        ):
            errors.append("world_biomes: max_sector_builds_per_frame debe coincidir con world_streaming")

        attribution = world_biomes["attribution"]
        streaming_attribution = data["world_streaming"].get("attribution", {})
        for field in ("dataset", "license", "copyright", "in_game_key", "license_file", "share_alike"):
            if attribution.get(field) != streaming_attribution.get(field):
                errors.append(f"world_biomes: la atribución {field} no coincide con world_streaming")

        kits_spec_path = ROOT / str(world_biomes["data_files"].get("kits_spec", ""))
        if not kits_spec_path.exists():
            errors.append("world_biomes: falta la especificación de kits")
        else:
            kits_spec = load_json(kits_spec_path)
            declared_kits = {poi["kit_id"] for poi in world_biomes["pois"] if poi["kind"] != "procedural"}
            spec_kits = {kit["kit_id"] for kit in kits_spec.get("kits", [])}
            for poi in world_biomes["pois"]:
                if poi["kind"] in ("poi", "furniture") and poi["kit_id"] not in spec_kits:
                    errors.append(f"world_biomes: {poi['id']} sin familia de kit en kits_spec ({poi['kit_id']})")
            if len(spec_kits) != int(world_biomes["qa"].get("expected_kit_families", 0)):
                errors.append("world_biomes: el número de familias de kits no coincide con qa.expected_kit_families")
            for kit in kits_spec.get("kits", []):
                chain = [int(lod["max_triangles"]) for lod in kit["lods"]]
                if len(chain) != 3 or not all(chain[i] > chain[i + 1] for i in range(len(chain) - 1)):
                    errors.append(f"world_biomes: kits_spec {kit['kit_id']} sin cadena LOD decreciente")

        manifest_dir = ROOT / "assets" / "manifests"
        kit_manifests = sorted(manifest_dir.glob("kit_*.manifest.json"))
        if len(kit_manifests) != int(world_biomes["qa"].get("expected_kit_families", 0)):
            errors.append(
                f"world_biomes: se esperaban {world_biomes['qa'].get('expected_kit_families')} manifiestos "
                f"de kits y hay {len(kit_manifests)}"
            )

    world_weather = data.get("world_weather", {})
    if world_weather and world_biomes:
        weather_presets = world_weather["presets"]
        weather_profiles = world_weather["biome_profiles"]
        biome_ids = {biome["id"] for biome in world_biomes["biomes"]}
        region_map = world_biomes["region_biome_map"]
        if set(weather_profiles) != biome_ids:
            errors.append(
                "world_weather: biome_profiles debe cubrir exactamente los seis biomas de world_biomes"
            )
        declared_weather_states = set(world_weather["states"]["weather"])
        if set(weather_presets) != declared_weather_states:
            errors.append("world_weather: states.weather no coincide con los presets declarados")
        if len(weather_presets) != int(world_weather["qa"].get("expected_presets", 0)):
            errors.append("world_weather: expected_presets no coincide con los presets declarados")
        if len(weather_profiles) != int(world_weather["qa"].get("expected_biomes", 0)):
            errors.append("world_weather: expected_biomes no coincide con los perfiles declarados")
        used_presets: set[str] = set()
        for biome_id, profile in weather_profiles.items():
            region = str(profile.get("region", ""))
            if region_map.get(region) != biome_id:
                errors.append(
                    f"world_weather: {biome_id} no coincide con region_biome_map[{region}]"
                )
            base = str(profile.get("base", ""))
            if base not in weather_presets:
                errors.append(f"world_weather: {biome_id} usa un preset base inexistente {base}")
            weight_total = 0.0
            for entry in profile["presets"]:
                preset_id = str(entry.get("id", ""))
                weight_total += float(entry.get("weight", 0.0))
                used_presets.add(preset_id)
                if preset_id not in weather_presets:
                    errors.append(
                        f"world_weather: {biome_id} referencia el preset inexistente {preset_id}"
                    )
                    continue
                preset = weather_presets[preset_id]
                temperature = float(preset["temperature_c"]) + float(profile["temperature_bias_c"])
                if temperature < -10.0 or temperature > 45.0:
                    errors.append(
                        f"world_weather: {biome_id}/{preset_id} sale del rango de temperatura del contrato"
                    )
                humidity = float(preset["humidity"]) + float(profile["humidity_bias"])
                if humidity < 0.0 or humidity > 1.0:
                    errors.append(
                        f"world_weather: {biome_id}/{preset_id} sale del rango de humedad del contrato"
                    )
                wind = float(preset["wind_mps"]) + float(profile["wind_bias_mps"])
                if wind < 0.0 or wind > 25.0:
                    errors.append(
                        f"world_weather: {biome_id}/{preset_id} sale del viento máximo de rain_surface_fx"
                    )
            if abs(weight_total - 1.0) > 0.001:
                errors.append(
                    f"world_weather: los pesos de {biome_id} suman {weight_total:.3f}, se esperaba 1.0"
                )
            biome_entry = next(
                (biome for biome in world_biomes["biomes"] if biome["id"] == biome_id), None
            )
            if biome_entry is not None:
                surface = biome_entry.get("surface_presets", {})
                dust_enabled = bool(surface.get("dust", {}).get("enabled", False))
                snow_enabled = bool(surface.get("snow", {}).get("enabled", False))
                if bool(profile["dust_link"]) != dust_enabled:
                    errors.append(
                        f"world_weather: {biome_id} dust_link no coincide con world.biomes"
                    )
                if bool(profile["snow_link"]) != snow_enabled:
                    errors.append(
                        f"world_weather: {biome_id} snow_link no coincide con world.biomes"
                    )
        if used_presets != set(weather_presets):
            missing = sorted(set(weather_presets) - used_presets)
            errors.append(f"world_weather: presets declarados sin uso por bioma: {missing}")

        lightning = world_weather["lightning"]
        required_preset = str(lightning.get("requires_preset", ""))
        if required_preset not in weather_presets:
            errors.append("world_weather: lightning.requires_preset no existe")
        elif not bool(weather_presets[required_preset].get("lightning", False)):
            errors.append("world_weather: el preset de rayos no declara lightning=true")
        interval_min = float(lightning["interval_s"][0])
        interval_max = float(lightning["interval_s"][1])
        if interval_min > interval_max:
            errors.append("world_weather: lightning.interval_s invertido")
        if int(lightning["max_strikes_per_minute"]) > int(60.0 / max(0.001, interval_min)) + 1:
            errors.append("world_weather: max_strikes_per_minute excede la cadencia mínima")
        distance = lightning["distance_km"]
        if float(distance[0]) > float(distance[1]):
            errors.append("world_weather: lightning.distance_km invertido")
        thunder = lightning["thunder"]
        if float(thunder["duration_s"]) <= 0.0:
            errors.append("world_weather: thunder.duration_s debe ser positivo")

        rain_mm_h = float(
            data["rain_surface_fx"]["precipitation"].get("rain_intensity_to_mm_h", 0.0)
        )
        if abs(float(world_weather["rain_coupling"]["rain_intensity_to_mm_h"]) - rain_mm_h) > 0.001:
            errors.append(
                "world_weather: rain_coupling.rain_intensity_to_mm_h no coincide con rain_surface_fx"
            )
        if bool(world_weather["attribution"]["no_new_osm_data"]) is not True:
            errors.append("world_weather: el mapa de papel no debe introducir datos OSM nuevos")
        if str(world_weather["attribution"]["network_license"]) != "ODbL-1.0":
            errors.append("world_weather: la red del mapa debe seguir bajo ODbL-1.0")
        if int(world_weather["camera_mask"]["max_points"]) > 8:
            errors.append("world_weather: camera_mask.max_points no puede superar los 8 del shader")
        loc_keys = localization_keys()
        for preset_id, preset in weather_presets.items():
            key = str(preset["name_key"])
            if key not in loc_keys:
                errors.append(f"world_weather: falta la clave de localización {key} ({preset_id})")

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
