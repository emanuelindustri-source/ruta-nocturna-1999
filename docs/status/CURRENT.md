# Estado actual

**Subfase:** 3.5 — Integración, compresión, warm-up, rendimiento y capturas de referencia visual
**Versión:** `v0.3.4`
**Modelo de la subfase:** MiMo Flash (`opencode-go/mimo-v2.6-flash`)
**Fecha:** 2026-11-23
**Estado:** completada y publicada.

## Enlaces

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Acciones: https://github.com/emanuelindustri-source/ruta-nocturna-1999/actions

## Validación ejecutada

| Prueba | Resultado |
|---|---|
| Contratos JSON + Schemas | **8 contratos válidos**, 0 errores, 1 advertencia conocida (202 claves de datos → F8.4); `rain_surface_fx.json` v1 **sin cambios** |
| Localización | 11 idiomas, 0 errores; `BOOT_KICKER` actualizado a Fase 3.5; fuentes CJK pendientes de F8.4 |
| Assets generados | 4 manifiestos válidos, 0 errores; F3.5 no genera ni modifica assets |
| Roadmap | `ROADMAP.md` + `docs/roadmap-data.json` sincronizados (**13/45 completadas, 28,9 %**) |
| Smoke test | **270/270**, exit 0 (versión 0.3.4) |
| Tren motriz | **125/125**, exit 0 |
| Cabina y rig | **46/46**, exit 0 |
| Interacción contextual | **257/257**, exit 0 |
| Prueba de lluvia | **206/206**, exit 0 |
| Godot import headless | exit 0; sin `SCRIPT ERROR`/`Parse Error`/`Failed to load` |
| Presets de export | Windows y Android válidos; `0.3.4`, Android `version/code=111` |
| Prueba de render real (ventana, Vulkan Forward+) | **RENDER_OK** con sonda GPU; capturas `build/logs/render/f35_*.png` + evidencia `*_visual_off/on/diff.png` |
| Build Windows exportada | `build/exports/windows/RutaNocturna1999.exe`, 103.070.208 bytes + pck 1.516.108 bytes; ejecutada **21,5 s**, exit 0, sin stderr |
| Compresión (`asset_compression_report.py`) | **OK**: `import_etc2_astc` activo, S3TC en Windows; 1 textura (19.060 B) y 16 mallas (761.672 B) importados; `.godot/imported` = 780.732 B |
| Prueba ADB completa en el Redmi | **exit 0**: APK `553F9128B4E09E7C6D6C9952A42934AC7BF34552D25882F40078978CFE59ABAF` (29.557.514 B), install Success, arranque **0,8 s**, logcat 15 s sin `FATAL EXCEPTION` ni errores Godot/Vulkan, ruta de rendimiento `done=true` sin errores |
| Presupuestos en dispositivo | PSS **415,6 / 535,3 / 614,7 MB** (boot/rebanada/cabina) ≤ 1.228,8; rebanada **15.874 triángulos** ≤ 120.000, frame **12,76 ms media / 16,96 p95** ≤ 33,333; cabina **7.435 triángulos**, frame **10,14 / 16,83 ms**; warm-up hecho antes del gameplay en ambas (1.924 y 2.018 ms) |
| Frame pacing en dispositivo | Rebanada: 1 jank > 33 ms y 0 > 100 ms en 300 frames (máx. 39,9 ms); cabina: 0 jank (máx. 19,6 ms) |
| Carga en dispositivo | Rebanada **8.765 ms**, cabina **4.525 ms** (presupuesto QA 15.000 ms) |
| Prueba de juego en PC (build exportado) | Sesión completa con input sintético: boot/rebanada/cabina/QA; seguro central con LED verde→rojo, manos al volante, retículo con3 estados, panel QA con clima `Tormenta · 95 %/90 %`. Informe: `build/logs/gameplay/REPORT.md` (no versionado) |
| Espacio libre | 77,5 GB en `C:` (mínimo 20 GB) |
| Dispositivo ADB | Redmi 22101316G autorizado (`obojropz89mbwgpn`) |
| Git | Rama `main`, commit y tag `v0.3.4` publicados |

Advertencias conocidas:

- **H1 (→ F4.4):** las gotas de cámara (`camera_drops`) cubren pantalla
  completa y parecen caer **dentro** del habitáculo; en el exterior la lluvia
  cae bien. Hay que recortar la máscara al parabrisas; toca el shader de F3.4
  y **no se modifica en F3.5**.
- **H2 (→ F5.1/F9.1):** la palanca de cambio **no responde con ratón,
  teclado ni gamepad**: `drag_focused()` solo escucha
  `InputEventScreenDrag` (táctil). Verificado en vivo (foco en la palanca +
  arrastre → HUD sigue en Marcha P). El motor funciona (257 lo cubre por
  API). Falta decidir la ruta de input de conducción.
- **H3 (→ F9.1):** el radio ejecuta la presión pero no muestra feedback
  visual (sin clave de feedback ni LED observable en cabina).
- Quad de fill de cabina a **91,80 % de fragmentos** (sin `discard`): el fill
  visual real es2,78 %; la optimización queda para F10.1 junto con H1.
- `budgets.*.gpu.status` sigue en `pending_f34_f35`: **el contrato no se
  modificó en F3.5**; F10.1/F10.2 lo cierran con medición fina en dispositivo.
- 202 claves de contenido aún no están en el CSV de localización (F8.4).
- Las fuentes CJK/cirílicas se empaquetan y validan visualmente en F8.4.
- Las cotas de carrocería/interior siguen siendo `provisional_design_value`
  (`ESTEEM_MECHANICAL_NOTES.md`).
- Los valores de humedad, gotas, barrido y charcos siguen siendo
  `design_value` provisionales de F3.3.
- La lluvia de las escenas es **lookdev** (`demo_*`): F4.4 inyecta la lluvia
  real con `RainFxController.set_weather()`.
- No hay pérdida de agarre, daño, vadeo ni anti-atasco: eso es F5.1; no hay
  conducción real (chasis `VehicleBody3D`: F5).
- La prueba ADB del PC (gamepad físico) no se ejecutó: sin mando conectado;
  el flujo D-Pad/A/B está cubierto por `interaction_test` con eventos
  sintéticos.
- Las builds exportadas son debug de referencia, no versionadas, en
  `build/exports/`.

## Completado

- **`DevicePerfProbe`** (`src/debug/device_perf_probe.gd`): servicio de escena
  en Boot/Rebanada/Cabina, inerte sin marcador; con
  `tools/test_android_adb.ps1` navega `slice,cabin`, pre-simula90 s, mide
  carga/warm-up/frame pacing/triángulos/draw calls y escribe
  `perf_report.json`. Sin nuevos autoloads.
- **Sonda GPU real** en la prueba de render: fill visual, fill de fragmentos
  y capas (sonda aditiva calibrada de1/2 capas), coste de frame con vsync
  off y delta de draw calls, contrastados con `budgets.pc.gpu` (≤8/≤5/≤6 % →
  todos cumplidos).
- **Frame pacing y tiempos de carga** en PC (`[RENDER][PACING]`/`[LOAD]`) y
  en el Redmi (300 frames por escena).
- **Compresión**: `tools/asset_compression_report.py` + revisión ETC2/ASTC,
  tamaño de APK/exe/pck dentro de lo esperado.
- **Prueba de juego en PC** sobre el build exportado con
  `tools/dev/gameplay_input.ps1` + `gameplay_diff.py` (informe y capturas en
  `build/logs/gameplay/`).
- **Capturas de referencia visual**: `f35_boot.png`,
  `f35_vertical_slice.png`, `f35_vertical_slice_detail.png`, `f35_cabin.png`,
  `f35_cabin_debug.png` + evidencia `*_visual_*` y capturas del Redmi
  (`screenshot.png`, `screenshot_slice.png`, `screenshot_cabin.png`).
- **APK nueva probada en el Redmi** con la ruta de rendimiento completa
  (exit 0) y **build Windows** exportada, ejecutada y cerrada limpia.
- Versión `0.3.4` en `VERSION`, `project.godot`, `export_presets.cfg`
  (`version/code=111`), `EXPECTED_VERSION` del smoke y la lluvia, `PHASE` de
  Boot y `BOOT_KICKER` en once idiomas.
- Referencias: revisión rápida al inicio y al cierre (95 archivos, sin
  cambios); F3.5 no usa imágenes de la biblioteca externa (registrado en
  `REFERENCE_USAGE_LOG.md`).

## Siguiente

Fase **4.1 con DS-R**: pipeline OSM/Overpass, DEM, grafo, rutas
alternativas, caché y atribución ODbL (tag `v0.4.0`). No se inicia en este
chat. El prompt completo está en `docs/status/HANDOFF.md`.
