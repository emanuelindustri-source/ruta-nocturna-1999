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
    "inventory_tools": "inventory_tools",
    "folklore_entities": "folklore_entities",
    "dialogue_and_endings": "dialogue_and_endings",
    "autoload_dependencies": "autoload_dependencies",
}

BLOCKOUT_SPEC = ROOT / "data" / "vehicle" / "blockout_spec.json"
CABIN_SPEC = ROOT / "data" / "vehicle" / "cabin_spec.json"

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
