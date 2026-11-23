# Handoff — Fase 3.5

## Estado de partida

La Fase 3.4 quedó completada, validada y publicada. La lluvia de producción ya
tiene **GLSL, VFX, warm-up y medición de render real**; la simulación sigue
siendo únicamente la de F3.3 (contrato `rain_surface_fx.json` v1 sin cambios).
El Esteem conserva intactos el tren motriz, la cabina, la interacción, los
espejos, el HUD, el gamepad, el guardado, el exterior (F3.1) y el interior
(F3.2).

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Versión: `v0.3.3` (Android `version/code=110`, Windows `0.3.3.0`)
- Contrato: `data/schemas/rain_surface_fx.json` (`schema_version: 1`,
  `contract_id: vehicle.esteem.rain_surface_fx`) **sin cambios en F3.4**.
- Shaders: `shaders/rain_fx_common.gdshaderinc`, `wet_paint.gdshader`,
  `wet_glass.gdshader`, `wet_road.gdshader`, `rain_streaks.gdshader`,
  `splash_ring.gdshader` y `camera_drops.gdshader`.
- Runtime: `src/weather/rain_fx_controller.gd` (`RainFxController`, servicio de
  escena), `rain_vfx.gd` (`RainVFX`) y `rain_fx_warmup.gd` (`RainFxWarmup`).
- Pruebas: `tests/weather/RainFxTest.tscn` + `tools/dev/rain_test.cmd`
  (**206** comprobaciones) y `tests/render/RainFxRenderTest.tscn` +
  `tools/dev/render_test.cmd` (render real en ventana).
- Pruebas existentes: smoke **270**, tren motriz **125**, cabina **46**,
  interacción **257**; todas exit 0.
- Medición de render (Intel UHD, Vulkan Forward+, 720p, vsync 60 Hz): frame
  **16,67 ms** en las tres escenas; rebanada 227 draw calls / ~15.900
  primitivas con tormenta de 90 s; cabina 195,5 / 9.227 con gotas de cámara y
  3 espejos. Materiales mojados con `material_override` (0 draw calls
  nuevos); VFX añaden 2 (rebanada) y 1 (cabina); peor caso proyectado
  3 draw calls / 3 capas / ~6 % de fill contra `budgets.*.gpu`.
- Warm-up verificado antes del gameplay (`[RAINFX] WARMUP_DONE` antes de
  `BOOT_READY`/`VERTICAL_SLICE_READY`); primera compilación ~3,4 s en Intel
  UHD y ~0,04 s con caché de pipelines.
- Build Windows exportada ejecutada 20 s y cerrada limpia (exit 0, sin
  marcador de sesión residual). ADB: `obojropz89mbwgpn` autorizado (sin build
  Android nueva en esta subfase).
- Health de cierre: 21 OK, 2 advertencias esperadas, 0 errores.
- Revisión visual completa de F3.4 registrada en
  `docs/reference/REFERENCE_USAGE_LOG.md`; biblioteca externa sin cambios.

## Qué debe hacer F3.5

Alcance exclusivo de **MiMo Flash** (tag `v0.3.4`), según `ROADMAP.md`:
**integración, compresión, warm-up, rendimiento y capturas de referencia
visual.**

1. **Integración y estabilidad**: pasar la prueba ADB completa
   (`tools/test_android_adb.ps1`) con APK nueva, validar la rebanada y la
   cabina en el Redmi y corregir lo que aparezca sin reabrir F2.1–F3.4.
2. **Compresión de assets**: revisar texturas/meshes importados, ETC2/ASTC,
   tamaño de la build y tiempos de carga dentro de los presupuestos
   (RAM ≤ 1,2 GB PSS, triángulos ≤ 120.000 móviles).
3. **Warm-up y rendimiento**: completar la medición que F3.4 dejó pendiente
   (overdraw/fill reales, PSS en ruta, frame pacing) y documentar; la medición
   GPU fina en dispositivo es compartida con F10.1/F10.2.
4. **Capturas de referencia visual**: screenshots representativos del juego
   real (boot, rebanada, cabina con lluvia) para seguimiento interno; nunca
   como assets de tienda ni copiando la biblioteca externa.

Reglas:

- No rehacer F2.1–F3.4. `rain_surface_fx.json` v1, `cabin_interaction.json` v2,
  `vehicle_powertrain.json`, `exterior_spec.json` e `interior_spec.json` no se
  tocan sin contrato.
- No crear autoloads nuevos. `WeatherManager` sigue siendo el único autoload de
  clima; F4.4 conecta la lluvia real con `RainFxController.set_weather()`.
- La pérdida de agarre, el hidroplaneo, el vadeo y el anti-atasco siguen
  siendo F5.1.
- Los shaders tienen reglas duras de Godot 4 ya resueltas (ver CHANGELOG
  0.3.3): no usar doc-comments `##`, usar `&&`/`||`, `#include` después de
  `render_mode`, billboard manual con `POSITION` explícito y malla de
  partículas por `draw_pass_1`.
- No avanzar a F3.6 (no existe) ni a F4.1 en ese chat: F3.5 cierra la Fase 3.

Al iniciar:

  python tools/health_check.py --start
  python tools/scan_reference_library.py --quick

## Prompt para el siguiente chat

```text
[RN1999 · Subfase 3.5]
CWD: C:\Dev\RutaNocturna1999
Modelo asignado: MiMo Flash (opencode-go/mimo-v2.6-flash)

Lee completos:
- AGENTS.md
- ROADMAP.md
- docs/status/CURRENT.md
- docs/status/HANDOFF.md
- docs/architecture/SYSTEM_ARCHITECTURE.md
- docs/architecture/BUILD_AND_RELEASE.md
- docs/architecture/RAIN_AND_SURFACE_FX.md
- data/schemas/rain_surface_fx.json

Ejecuta únicamente la Subfase 3.5 (tag v0.3.4): integración, compresión,
warm-up, rendimiento y capturas de referencia visual. No rehagas F2.1–F3.4 ni
cambies contratos. No avances a F4.1 ni a ninguna otra subfase.

La Fase 3.4 ya cerró:
- Shaders GLSL de producción (wet_paint/wet_glass/wet_road, gotas, barrido,
  escurrido, charcos, estrellas, salpicaduras y gotas de cámara) que consumen
  los modelos de F3.3 por uniforms.
- RainFxController (servicio de escena), RainVFX y RainFxWarmup; warm-up
  verificado antes del gameplay.
- Prueba de lluvia 206/206; smoke 270, tren motriz 125, cabina 46,
  interacción 257; todas exit 0.
- Render real (boot, rebanada, cabina) en Vulkan Forward+ con capturas
  f34_*.png, frame 16,67 ms, y peor caso GPU proyectado 3 draw calls / 3
  capas / ~6 % de fill dentro de budgets.*.gpu.
- Build Windows exportada ejecutada 20 s y cerrada limpia.
No rehagas tren motriz, cabina, interacción, espejos, HUD, gamepad, guardado,
exterior, interior ni los shaders de F3.4.

Al iniciar:
  python tools/health_check.py --start
  python tools/scan_reference_library.py --quick

Al cerrar:
- valida esquemas, localización, manifiestos, roadmap y presets de export
- importa el proyecto en Godot headless
- ejecuta tools/dev/smoke_test.cmd, tools/dev/powertrain_test.cmd,
  tools/dev/cabin_test.cmd, tools/dev/interaction_test.cmd,
  tools/dev/rain_test.cmd y tools/dev/render_test.cmd
- ejecuta tools/test_android_adb.ps1 con la APK nueva en el Redmi
- mide RAM PSS, triángulos, tiempos de carga y frame pacing en dispositivo
- comprueba espacio en disco y dispositivo ADB autorizado
- ejecuta health_check --end
- actualiza ROADMAP.md, docs/roadmap-data.json, CHANGELOG.md, CURRENT.md y
  HANDOFF
- haz commit, tag v0.3.4 y push solo si todo pasa
- entrega el prompt del siguiente /new (Fase 4.1 con DS-R)

No avances a la Fase 4.
```

## Recordatorios

- La biblioteca de referencias externa sigue fuera del repositorio; la
  revisión completa siguiente toca antes de F4.3 (o a los 14 días).
- La ExecutionPolicy de PowerShell está restringida: usar wrappers `.cmd`.
- El export se hace con `tools\dev\export.cmd`; los binarios van a `build/` y
  nunca a Git.
- Los presupuestos móviles siguen vigentes: ≤120.000 triángulos visibles
  (incluidos los tres viewports de espejo), RAM ≤1.2 GB PSS.
- Los tests deben seguir pasando sin relajarse: smoke (270), tren motriz (125),
  cabina (46), interacción (257), lluvia (206) y render (`RENDER_OK`). Al
  cambiar `EXPECTED_VERSION`, actualizar también `VERSION`, `project.godot`,
  `export_presets.cfg` (`version/name` y `version/code`) y `PHASE` de `Boot.gd`.
- El contrato de F3.3 es la fuente de verdad: no mover valores de humedad,
  gotas, barrido o charcos al shader ni a la UI.
- El warm-up de shaders debe seguir ejecutándose antes del gameplay; no se
  publica una build si el warm-up ocurre dentro de gameplay.
- No se sube ningún token, keystore, APK o AAB a Git.
- Las cotas de carrocería/interior siguen siendo provisionales hasta verificar
  el manual o medir el vehículo real.
- La pérdida de agarre, el vadeo y el anti-atasco son F5.1; la lluvia real con
  `WeatherManager` es F4.4.

## Seguridad

El inicio de sesión usado para publicar debe rotarse o revocarse después de la
publicación si el token fue compartido por un canal no seguro. La configuración
local de Git no contiene el token.
