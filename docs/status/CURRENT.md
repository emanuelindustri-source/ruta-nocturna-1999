# Estado actual

**Subfase:** 3.3 — Matemática de humedad, gotas, limpiaparabrisas, charcos y presupuesto  
**Versión:** `v0.3.2`  
**Modelo de la subfase:** DS-R (`opencode-go/deepseek-v4.1-flash#max`)  
**Fecha:** 2026-11-23  
**Estado:** completada y publicada.

## Enlaces

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Acciones: https://github.com/emanuelindustri-source/ruta-nocturna-1999/actions

## Validación ejecutada

| Prueba | Resultado |
|---|---|
| Contratos JSON + Schemas | **8 contratos válidos**, 0 errores, 1 advertencia conocida (202 claves de datos → F8.4) |
| Localización | 11 idiomas, 0 errores; `BOOT_KICKER` actualizado a Fase 3.3; fuentes CJK pendientes de F8.4 |
| Assets generados | 4 manifiestos válidos (bloqueo + cabina + exterior + interior), 0 errores; F3.3 no genera ni modifica assets |
| Contrato de lluvia (F3.3) | `rain_surface_fx.json` v1 + JSON Schema; 6 clases de superficie, 9 paneles del vehículo, 3 superficies de vía, 2 perfiles de gotas, 2 escobillas, 5 arquetipos de charco y presupuestos PC/móvil |
| Validación cruzada F3.3 | Área del parabrisas y pivotes/longitudes de escobillas contra `exterior_spec.json`; admisión (0,68 m) y profundidad segura (0,30 m) contra `vehicle_components.json`; suma de gotas 4.096 y orden de presupuestos |
| Prueba de lluvia | **126/126 comprobaciones**, exit 0: humedad, determinismo de gotas, barrido, desgaste, charcos, hidroplaneo, vadeo y CPU |
| Presupuesto CPU medido | PC **~0,21 ms** media / **~0,28 ms** p95 (4.096 gotas, 24 charcos, 60 Hz); móvil **~0,17 ms** media / **~0,21 ms** p95 (1.536 gotas, 12 charcos, 30 Hz). Límites declarados: 1,0/1,6 ms y 1,5/2,4 ms |
| Smoke test | **270/270 comprobaciones**, exit 0 (sin cambios de conteo; versión 0.3.2) |
| Tren motriz | **125/125 comprobaciones**, exit 0 (sin cambios) |
| Cabina y rig de manos | **46/46 comprobaciones**, exit 0 (sin cambios) |
| Interacción contextual | **257/257 comprobaciones**, exit 0 (sin cambios) |
| Godot import headless | exit 0; clases `RainSurfaceSpec`, `SurfaceWetnessModel`, `DropletFlowModel`, `WiperKinematics` y `PuddleModel` registradas sin errores |
| Presets de export | Windows y Android válidos; `0.3.2`, Android `version/code=109` |
| Build Windows exportada | `build/exports/windows/RutaNocturna1999.exe`, 103.070.208 bytes, SHA-256 `7E3065D5109EAC05CA97CD6A955F880C97C53E6C0771BC1BE266D1FC0681FE93` |
| Prueba de juego (render real) | Boot (`BOOT_READY version=0.3.2`), rebanada vertical (`VERTICAL_SLICE_READY version=0.3.2`) y cabina con interior definitivo y 3 espejos `SubViewport`, todas en Vulkan Forward+ sin errores; build exportada ejecutada 20 s y cerrada limpia (exit 0, sin marcador de sesión residual) |
| Referencias | Revisión visual completa del hito F3.3 con catálogo de 95 fichas, hojas de contacto existentes y hoja de detalle nueva; registro en `REFERENCE_USAGE_LOG.md`; biblioteca externa sin cambios (95 archivos) |
| Espacio libre | 79,8 GB en `C:` (mínimo 20 GB) |
| Dispositivo ADB | Redmi 22101316G autorizado (`obojropz89mbwgpn`) |
| Git | Rama `main`, commit y tag `v0.3.2` publicados |

Advertencias conocidas:

- 202 claves de contenido aún no están en el CSV de localización (F8.4).
- Las fuentes CJK/cirílicas se empaquetan y validan visualmente en F8.4.
- Las cotas de carrocería/interior siguen siendo `provisional_design_value`:
  verificar contra manual o medición antes de Fase 5
  (`ESTEEM_MECHANICAL_NOTES.md`).
- Los valores de humedad, gotas, barrido y charcos de F3.3 son `design_value`
  provisionales. La biblioteca externa no contiene fotos dedicadas de lluvia,
  gotas o charcos: las fotos reales del Esteem están secas y los conceptos
  nocturnos solo inspiran atmósfera (no canon, sin cotas).
- El GLSL de producción, los VFX, la fusión visual de gotas, el barrido
  renderizado, el asfalto mojado y los charcos visibles son F3.4. El warm-up de
  shaders, el overdraw, el fill rate, el PSS en ruta y las capturas visuales son
  F3.5/F10.1.
- No se añadió un mando de limpiaparabrisas a `cabin_interaction.json` v2: el
  contrato declara `control_source: future_cabin_stalk_or_automatic`. La
  integración de entrada se decide en F3.4/F3.5 sin reabrir F2.3/F2.4.
- La prueba de lluvia mide CPU headless de escritorio; no es una medición GPU ni
  de dispositivo. El Redmi se mide en F3.5/F10.2.
- No hay conducción real: el chasis `VehicleBody3D` y la física son F5; la
  rebanada sigue sin cuerpos de física.
- La build de Windows exportada es debug de referencia, no versionada, en
  `build/exports/`.
- La prueba ADB completa (`test_android_adb.ps1`) no se repite en F3.3 (no es
  hito Android); el dispositivo sigue autorizado y la APK nueva llega en
  F3.5/F10.2.

## Completado

- **Revisión visual completa de referencias** (hito obligatorio de F3.3):
  catálogo (95 fichas), hojas `all_images.jpg`, `generated_concepts.jpg`,
  `exterior_f31_review.jpg`, `exterior_f31_detail.jpg`,
  `interior_f32_review.jpg` e `interior_f32_detail.jpg`, más una hoja de detalle
  nueva `build/reference/contact_sheets/rain_f33_detail.jpg`; uso registrado en
  `docs/reference/REFERENCE_USAGE_LOG.md`. Sin copiar archivos de
  `C:\Dev\fotos de ejemplo` y sin cargar las 40 imágenes en contexto.
- `data/schemas/rain_surface_fx.json` (`schema_version: 1`,
  `vehicle.esteem.rain_surface_fx`): contrato declarativo de humedad de
  superficies, gotas, limpiaparabrisas, charcos y presupuestos, con
  `source_status`/`source_note`, ecuaciones y `schema_history`.
- `data/schemas/json/rain_surface_fx.schema.json` y validación ampliada en
  `tools/validate_schemas.py` (8 contratos, referencias cruzadas con
  `exterior_spec.json` y `vehicle_components.json`).
- `src/weather/rain_surface_spec.gd`: cargador runtime del contrato.
- `src/weather/surface_wetness_model.gd`: película, drenaje, evaporación,
  infiltración, histéresis y estados `dry/damp/wet/soaked`.
- `src/weather/droplet_flow_model.gd`: nucleación determinista, crecimiento,
  radio crítico, desliz por gravedad/viento, evaporación, escurrido y búfer de
  instancias de 6 floats para F3.4.
- `src/weather/wiper_kinematics.gd`: barrido smoothstep, modos
  off/intermitente/lento/rápido, pausas, desgaste y limpieza de sector del
  parabrisas; sin controles nuevos de cabina.
- `src/weather/puddle_model.gd`: arquetipos corona/hundimiento/bache/hombro/vado,
  profundidad, drenaje, hidroplaneo informativo y estados de vadeo.
- `tests/weather/RainFxTest.tscn` + `rain_fx_test.gd`: 126 comprobaciones
  headless; `tools/dev/rain_test.cmd` y `rain_test.ps1`; `health_check.py`
  ejecuta `rain_tests` y la CI la ejecuta en Linux.
- `docs/architecture/RAIN_AND_SURFACE_FX.md` con ecuaciones, integración
  F3.4/F4.4/F5.1, presupuestos medidos y límites; secciones nuevas en
  `DATA_CONTRACTS.md`, `SYSTEM_ARCHITECTURE.md`, `STATE_MACHINES.md`,
  `QA_AND_RECOVERY.md` y `BUILD_AND_RELEASE.md`.
- Versión `0.3.2` en `VERSION`, `project.godot`, `export_presets.cfg`
  (`version/code=109`), `EXPECTED_VERSION` del smoke test, `PHASE` de Boot y
  `BOOT_KICKER` en once idiomas.

## Siguiente

Fase **3.4 con MiMo Pro**: GLSL de producción, gotas, barrido, escurrido,
charcos, asfalto mojado y VFX (tag `v0.3.3`). No se inicia en este chat. El
prompt completo está en `docs/status/HANDOFF.md`.
