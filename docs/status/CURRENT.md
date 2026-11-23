# Estado actual

**Subfase:** 3.4 — GLSL de producción, gotas, barrido, escurrido, charcos, asfalto mojado y VFX  
**Versión:** `v0.3.3`  
**Modelo de la subfase:** MiMo Pro (`opencode-go/mimo-v2.6-pro`)  
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
| Localización | 11 idiomas, 0 errores; `BOOT_KICKER` actualizado a Fase 3.4; fuentes CJK pendientes de F8.4 |
| Assets generados | 4 manifiestos válidos, 0 errores; F3.4 no genera ni modifica assets |
| Contrato de lluvia | `rain_surface_fx.json` v1 **sin cambios**: F3.4 solo consume humedad, gotas, barrido y charcos por uniforms |
| Prueba de lluvia | **206/206 comprobaciones**, exit 0 (126 de F3.3 + 80 nuevas de shaders, controlador, uniforms, VFX y presupuestos GPU) |
| Smoke test | **270/270 comprobaciones**, exit 0 (sin cambios de conteo; versión 0.3.3) |
| Tren motriz | **125/125 comprobaciones**, exit 0 (sin cambios) |
| Cabina y rig de manos | **46/46 comprobaciones**, exit 0 (sin cambios) |
| Interacción contextual | **257/257 comprobaciones**, exit 0 (sin cambios) |
| Godot import headless | exit 0; clases `RainFxController`, `RainVFX` y `RainFxWarmup` registradas sin errores |
| Presets de export | Windows y Android válidos; `0.3.3`, Android `version/code=110` |
| Prueba de render real (ventana, Vulkan Forward+) | `tests/render/RainFxRenderTest.tscn` con los shaders/VFX nuevos: **RENDER_OK** en boot, rebanada y cabina; capturas `build/logs/render/f34_*.png` |
| Warm-up de shaders | `[RAINFX] WARMUP_DONE` **antes** de `BOOT_READY`/`VERTICAL_SLICE_READY` en las tres escenas; primera compilación ~3,4 s (Intel UHD), ~0,04 s con caché; FX inactivos hasta que termina |
| Frame time medido | boot **16,666/17,1 ms** (media/p95); rebanada con tormenta de 90 s **16,670/16,9 ms**; cabina **16,664/17,1 ms** — 60 fps con vsync dentro del `frame_budget_ms` del contrato (tolerancia de vsync) |
| Draw calls y primitivas | boot 12 / 548; rebanada **227** / ~15.900 (con VFX activos); cabina **195,5** / 9.227 (con gotas de cámara y 3 espejos) |
| Presupuesto GPU (`budgets.*.gpu`) | materiales mojados con `material_override` (**0 draw calls nuevos**); VFX añaden 2 (rebanada) y 1 (cabina); peor caso proyectado **3 draw calls / 3 capas de overdraw / ~6 % de fill** contra PC 8/5/6 % y móvil 4/3/10 % |
| Build Windows exportada | `build/exports/windows/RutaNocturna1999.exe`, 103.070.208 bytes, SHA-256 `881D5FE8E76099F94D33EB9C4D30EFB9ECE9E1F3794920876225A2037A65F1E0` |
| Build exportada ejecutada | 20 s (`--quit-after 1200`), **exit 0** y sin marcador de sesión residual |
| Referencias | Revisión visual completa del hito F3.4 con catálogo de 95 fichas, hojas de contacto y hoja de detalle nueva `rain_f34_detail.jpg`; registro en `REFERENCE_USAGE_LOG.md`; biblioteca externa sin cambios (95 archivos) |
| Espacio libre | 78,4 GB en `C:` (mínimo 20 GB) |
| Dispositivo ADB | Redmi 22101316G autorizado (`obojropz89mbwgpn`) |
| Git | Rama `main`, commit y tag `v0.3.3` publicados |

Advertencias conocidas:

- 202 claves de contenido aún no están en el CSV de localización (F8.4).
- Las fuentes CJK/cirílicas se empaquetan y validan visualmente en F8.4.
- Las cotas de carrocería/interior siguen siendo `provisional_design_value`:
  verificar contra manual o medición antes de Fase 5
  (`ESTEEM_MECHANICAL_NOTES.md`).
- Los valores de humedad, gotas, barrido y charcos siguen siendo `design_value`
  provisionales de F3.3; la biblioteca externa no contiene fotos dedicadas de
  lluvia, gotas ni charcos (revisión F3.4 registrada en
  `REFERENCE_USAGE_LOG.md`).
- La lluvia de las escenas es **lookdev** (`demo_*`): F4.4 inyecta la lluvia
  real con `RainFxController.set_weather()`. El warm-up completo en ruta y la
  medición GPU en dispositivo (RenderDoc/Adreno, PSS) son F3.5/F10.1/F10.2.
- El overdraw y el fill del contrato se contrastan con la proyección del
  diseño de VFX (2+1 llamadas); la medición GPU real es F3.5/F10.1.
- No se añadió un mando de limpiaparabrisas a `cabin_interaction.json` v2:
  el barrido se anima con `WiperKinematics` sin controles nuevos.
- No hay pérdida de agarre, daño, vadeo ni anti-atasco: eso es F5.1.
- No hay conducción real: el chasis `VehicleBody3D` y la física son F5.
- La build de Windows exportada es debug de referencia, no versionada, en
  `build/exports/`.
- La prueba ADB completa (`test_android_adb.ps1`) no se repite en F3.4 (no es
  hito Android); el dispositivo sigue autorizado y la APK nueva llega en
  F3.5/F10.2.

## Completado

- **Revisión visual completa de referencias** (hito obligatorio de F3.4):
  catálogo (95 fichas), hojas `all_images.jpg`, `generated_concepts.jpg`,
  `rain_f33_detail.jpg`, `exterior_f31_detail.jpg` e `interior_f32_detail.jpg`,
  más una hoja de detalle nueva
  `build/reference/contact_sheets/rain_f34_detail.jpg` (recortes de
  cristales/pintura/escobillas y conceptos mojados; no versionada); uso
  registrado en `docs/reference/REFERENCE_USAGE_LOG.md`. Sin copiar archivos
  de `C:\Dev\fotos de ejemplo` y sin cargar las 40 imágenes en contexto.
- **GLSL de producción** en `shaders/`: `rain_fx_common.gdshaderinc` (campo de
  gotas con fusión visual, estelas, sector de barrido, ondas de charco),
  `wet_paint.gdshader`, `wet_glass.gdshader` (gotas, refracción, zona limpia y
  estela de goma), `wet_road.gdshader` (película, asfalto mojado y charcos de
  `PuddleModel`), `rain_streaks.gdshader`, `splash_ring.gdshader` y
  `camera_drops.gdshader`.
- `src/weather/rain_fx_controller.gd` (`RainFxController`, servicio de escena):
  consume los cinco modelos de F3.3 por uniforms, aplica `material_override`
  mojado a 24 piezas del exterior y a la vía, anima las escobillas de F3.1
  sobre los pivotes del contrato y expone `set_weather()` para F4.4.
- `src/weather/rain_vfx.gd` (estrellas y salpicaduras con `draw_pass_1`) y
  `src/weather/rain_fx_warmup.gd` (warm-up antes del gameplay en Boot y en
  cada escena con FX).
- Integración en `VerticalSlice.tscn` (tormenta lookdev con charcos visibles)
  y `CabinInteraction.tscn` (gotas sobre cámara con barrido), sin tocar los
  assets ni contratos de F2.1–F3.2.
- `tests/render/RainFxRenderTest.tscn` + `tools/dev/render_test.cmd`: render
  real con capturas, frame time, draw calls, primitivas y verificación de
  warm-up; `RainFxProbe.tscn` como sonda de diagnóstico de lookdev.
- Prueba de lluvia ampliada a **206 comprobaciones** y documentación F3.4 en
  `RAIN_AND_SURFACE_FX.md`, `SYSTEM_ARCHITECTURE.md`, `DATA_CONTRACTS.md`,
  `STATE_MACHINES.md` y `QA_AND_RECOVERY.md`.
- Versión `0.3.3` en `VERSION`, `project.godot`, `export_presets.cfg`
  (`version/code=110`), `EXPECTED_VERSION` del smoke y la lluvia, `PHASE` de
  Boot y `BOOT_KICKER` en once idiomas.

## Siguiente

Fase **3.5 con MiMo Flash**: integración, compresión, warm-up, rendimiento y
capturas de referencia visual (tag `v0.3.4`). No se inicia en este chat. El
prompt completo está en `docs/status/HANDOFF.md`.
