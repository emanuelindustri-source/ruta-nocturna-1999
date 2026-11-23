# Estado actual

**Subfase:** 2.4 — Espejos, HUD mínimo, gamepad/D-Pad y guardado  
**Versión:** `v0.2.3`  
**Modelo de la subfase:** MiMo Flash  
**Fecha:** 2026-11-22  
**Estado:** completada y publicada.

## Enlaces

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Acciones: https://github.com/emanuelindustri-source/ruta-nocturna-1999/actions

## Validación ejecutada

| Prueba | Resultado |
|---|---|
| Contratos JSON + Schemas | 7 contratos válidos, 0 errores, 1 advertencia conocida; `cabin_interaction` v2 con `mirrors`/`hud`/`gamepad` y validaciones cruzadas |
| Localización | 11 idiomas, 0 errores; 29 claves nuevas de F2.4; fuentes CJK pendientes de F8.4 |
| Roadmap | 8/45 subfases completadas (17,8%), JSON sincronizado |
| Assets generados | 2 manifiestos válidos (bloqueo + cabina), 0 errores; F2.4 sin `.glb` nuevos |
| Fixture de guardado v0.2.0 | `tools/make_save_fixture.py --check` OK (checksum `49b091e7…`) y carga real en el smoke test |
| Smoke test | 198/198 comprobaciones, exit 0 |
| Tren motriz | 125/125 comprobaciones, exit 0 (sin cambios) |
| Cabina y rig de manos | 46/46 comprobaciones, exit 0 (sin cambios) |
| Interacción contextual | 257/257 comprobaciones, exit 0 (eran 180) |
| Godot import headless | exit 0; sin marcadores críticos |
| Presets de export | Windows y Android válidos; `0.2.3`, Android `version/code=106` |
| Health check de cierre | 19 OK, 3 advertencias esperadas, 0 errores |
| APK Android debug | 28.827.443 bytes, SHA-256 `E587066CB6BF5F3428FFFCCBB860B452DE525523B98EE231F53ADC71DD7C4489` |
| Dispositivo ADB | Redmi 22101316G autorizado (`obojropz89mbwgpn`); `test_android_adb.ps1` superado |
| PSS Android | 379,8 MB de un presupuesto de 1.228,8 MB |
| logcat 15 s | Sin `FATAL EXCEPTION`, sin errores Godot ni Vulkan |
| Espacio libre | 79,81 GB en `C:` |
| Referencias | 95 archivos; escaneo rápido sin cambios; uso de F2.4 registrado en `REFERENCE_USAGE_LOG.md` |
| Git | Rama `main`, commit y tag `v0.2.3` publicados |

Advertencias conocidas:

- 202 claves de contenido aún no están en el CSV de localización. Se completarán
  en F8.4; la UI base y F2.4 ya están cubiertas.
- Las fuentes CJK/cirílicas se empaquetan y validan visualmente en F8.4.
- Las traducciones nuevas de F2.4 (HUD, avisos y QA) son provisionales y no
  tienen revisión nativa.
- Los espejos son funcionales y provisionales: posiciones y ángulos derivados
  de `anchor_mirror_left/right` y de la cabecera de parabrisas observada en
  fotos; el arte definitivo del espejo es F3.1. Las cámaras comparten el
  `World3D` y los tres pasos de render cuentan en el presupuesto móvil; la
  medición en ruta real es F3.5/F10.1.
- El HUD es un overlay mínimo de código; el arte del instrumental final es
  F3.2. No replica el velocímetro del modelo.
- El gamepad se verificó con eventos sintéticos y con el mapeo `InputMap`
  (D-Pad, stick y A/B); la prueba con mando físico en dispositivo es F9.2.
- El guardado quedó en la línea base `save_version: 1` / `game_version:
  0.2.0`. Las migraciones encadenadas y los slots completos son F9.4.
- No hay conducción real: la cabina sigue sin `VehicleBody3D`; el chasis y la
  física de conducción son F3+ según el gate correspondiente.
- La APK de F2.4 es debug de referencia, no versionada, en `build/exports/`.
- La cabina sigue sin LODs por distancia (F3.5/F10) y con cotas provisionales
  (`provisional_design_value` / `photo_observed_provisional`).

## Completado

- Contrato `data/schemas/cabin_interaction.json` **v2** con `schema_history`
  (v1 → v2 aditivo), secciones `mirrors`, `hud` y `gamepad`, JSON Schema y
  validaciones cruzadas en `tools/validate_schemas.py` (anclas de espejo,
  presupuesto de triángulos, avisos del tren motriz y claves en el CSV).
- `src/vehicle/cabin_mirrors.gd`: espejo interior y dos laterales con
  `SubViewport` (320×96 y 128×96), `Camera3D` propia por espejo, superficies
  `QuadMesh` sin sombras, cadencia `update_hz` rearmada con `UPDATE_ONCE` y
  `set_viewports_enabled()` para el perfil bajo.
- `src/vehicle/cabin_hud.gd`: velocidad, marcha, combustible y avisos leídos
  de `VehiclePowertrain.get_telemetry()` a 10 Hz, con claves `HUD_*` y los
  ocho `HUD_WARN_*` en once idiomas, sin botones y con texto además de color.
- `src/vehicle/cabin_gamepad_adapter.gd`: D-Pad cicla el foco contextual con
  ciclo cerrado, A pulsa, B suelta y limpia, stick derecho rota la cámara con
  los límites de F2.3 y zona muerta; suspendido con el panel QA abierto.
- `project.godot`: `[input]` para `ui_accept` (Enter, KP Enter, Space, A) y
  `ui_cancel` (Esc, B); los `ui_up/down/left/right` conservan D-Pad y stick.
  Boot y rebanada toman foco inicial en el primer evento de gamepad; B en el
  menú raíz no cierra la aplicación.
- Guardado v0.2.0: fixture `tests/fixtures/save_v0_2_0.json` +
  `tools/make_save_fixture.py` (checksum canónico equivalente a `SaveManager`),
  chequeo `save_fixture` en `health_check.py`, y pruebas de carga, backup,
  escritura atómica y rechazo de versiones futuras.
- Panel QA: sección de vehículo con seis reparaciones/daños sobre
  `VehiclePowertrain` (grupo `vehicle_powertrain`) y acciones de guardar/cargar
  en la ranura QA; panel instanciado también en la escena de cabina (F12).
- Corrección: `SaveManager` usaba rutas relativas en `DirAccess.copy()` para
  el backup; ahora absolutas. Lo destapó la nueva prueba de backup.
- Prueba ADB completa en el Redmi: APK debug compilada, instalada, arrancada,
  15 s de logcat limpios, captura y PSS de 379,8 MB.
- 29 claves de localización nuevas en once idiomas; `BOOT_KICKER` a Fase 2.4.
- Documentación: `SYSTEM_ARCHITECTURE` §12, `DATA_CONTRACTS` §9.1/§15.1,
  `STATE_MACHINES` §10, `ASSET_FACTORY` §11, `QA_AND_RECOVERY` §14 y registro
  de referencias F2.4.

## Siguiente

Fase **3.1 con MiMo Pro**: exterior definitivo del Esteem, piezas separadas,
LODs, PBR, llantas, faros y espejos (tag `v0.3.0`). Revisión visual completa de
referencias obligatoria antes de empezar. No se inicia en este chat.
