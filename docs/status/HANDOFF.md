# Handoff — Fase 3.4

## Estado de partida

La Fase 3.3 quedó completada, validada y publicada. La lluvia física ya tiene
**contrato declarativo y matemática probada**; no hay todavía shaders GLSL ni
VFX. El Esteem conserva intactos el tren motriz, la cabina, la interacción, los
espejos, el HUD, el gamepad, el guardado, el exterior (F3.1) y el interior (F3.2).

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Versión: `v0.3.2` (Android `version/code=109`, Windows `0.3.2.0`)
- Contrato: `data/schemas/rain_surface_fx.json` (`schema_version: 1`,
  `contract_id: vehicle.esteem.rain_surface_fx`).
- Esquema: `data/schemas/json/rain_surface_fx.schema.json`.
- Arquitectura: `docs/architecture/RAIN_AND_SURFACE_FX.md`.
- Modelos: `src/weather/rain_surface_spec.gd`,
  `surface_wetness_model.gd`, `droplet_flow_model.gd`,
  `wiper_kinematics.gd` y `puddle_model.gd`.
- Pruebas: `tests/weather/RainFxTest.tscn` + `tools/dev/rain_test.cmd`
  (**126** comprobaciones).
- Presupuesto CPU medido: PC ~0,21 ms media / ~0,28 ms p95 (4.096 gotas,
  24 charcos, 60 Hz); móvil ~0,17 ms media / ~0,21 ms p95 (1.536 gotas,
  12 charcos, 30 Hz). Límites del contrato: 1,0/1,6 ms y 1,5/2,4 ms.
- Pruebas existentes: smoke **270**, tren motriz **125**, cabina **46**,
  interacción **257**; todas exit 0.
- Render real: Boot y rebanada en Vulkan Forward+ sin errores; build Windows
  exportada ejecutada 20 s y cerrada limpia. ADB: `obojropz89mbwgpn`
  autorizado (sin build Android nueva en esta subfase).
- Health de cierre: 21 OK, 2 advertencias esperadas, 0 errores.
- Revisión visual completa de F3.3 registrada en
  `docs/reference/REFERENCE_USAGE_LOG.md`; biblioteca externa sin cambios.

## Qué debe hacer F3.4

Alcance exclusivo de **MiMo Pro** (tag `v0.3.3`), según `ROADMAP.md`:
**GLSL de producción, gotas, barrido, escurrido, charcos, asfalto mojado y VFX.**

1. **Shader de humedad y gotas**: material/shader para pintura y vidrio que
   consuma `SurfaceWetnessModel` y `DropletFlowModel`; gotas con forma,
   coalescencia visual y estela de escurrido coherentes con las ecuaciones de
   F3.3. Sin duplicar la simulación de F3.3 en el shader.
2. **Barrido del limpiaparabrisas**: animación visual del barrido y zona limpia
   usando `WiperKinematics`; la goma gastada deja estela. No añadir un mando
   nuevo a `cabin_interaction.json` v2 sin contrato y aprobación.
3. **Asfalto mojado y charcos**: material de vía con reflejos, película y
   charcos; consumir `PuddleModel` para profundidad/zonas. El hidroplaneo y el
   vadeo siguen siendo F5.1.
4. **VFX**: salpicaduras, gotas sobre cámara si aplica, niebla/bruma de lluvia
   solo si respeta los presupuestos; sin partículas descontroladas.
5. **Presupuesto y warm-up**: respetar `budgets.*.gpu` del contrato; incluir
   warm-up de shaders antes del gameplay; medir draw calls, overdraw, fill rate
   y frame time. La medición completa en ruta y dispositivo es F3.5/F10.1, pero
   F3.4 debe dejar evidencia de renders reales y del coste.

Reglas:

- No rehacer F2.1–F3.2. `cabin_interaction.json` v2, `vehicle_powertrain.json`,
  `exterior_spec.json` e `interior_spec.json` no se tocan sin contrato.
- No crear autoloads nuevos. `WeatherManager` sigue siendo el único autoload de
  clima; F4.4 conectará la lluvia real. F3.4 puede usar un servicio de escena
  para el material/VFX, sin dependencias circulares.
- La fusión visual de gotas, el barrido renderizado y los charcos visibles son
  de esta subfase; no se implementan pérdida de agarre, daño, vadeo ni
  anti-atasco (F5.1).
- **Revisión visual completa de referencias obligatoria antes de F3.4**
  (`AGENTS.md`, sección 10): usar el catálogo y las hojas de contacto; no cargar
  las 40 imágenes en contexto; registrar el uso en
  `docs/reference/REFERENCE_USAGE_LOG.md`; no copiar archivos de
  `C:\Dev\fotos de ejemplo`.
- Si un shader o VFX cambia el presupuesto, medir y documentar; no se aceptan
  “optimizaciones” sin medición.
- No avanzar a F3.5 ni a ninguna otra subfase en ese chat.

Antes de implementar, revisa solo las referencias del catálogo relevantes para
lluvia, gotas sobre pintura/vidrio, limpiaparabrisas, charcos y asfalto mojado y
registra su uso. La biblioteca no tiene fotos dedicadas de lluvia; las fotos
reales están secas y los conceptos nocturnos son solo inspiración. No cargues
las 40 imágenes en contexto ni copies archivos externos.

## Prompt para el siguiente chat

```text
[RN1999 · Subfase 3.4]
CWD: C:\Dev\RutaNocturna1999
Modelo asignado: MiMo Pro (opencode-go/mimo-v2.6-pro)

Lee completos:
- AGENTS.md
- ROADMAP.md
- docs/status/CURRENT.md
- docs/status/HANDOFF.md
- docs/architecture/SYSTEM_ARCHITECTURE.md
- docs/architecture/DATA_CONTRACTS.md
- docs/architecture/RAIN_AND_SURFACE_FX.md
- data/schemas/rain_surface_fx.json
- data/schemas/vehicle_powertrain.json
- data/schemas/cabin_interaction.json

Ejecuta únicamente la Subfase 3.4 (tag v0.3.3): GLSL de producción, gotas,
barrido, escurrido, charcos, asfalto mojado y VFX. Consume la matemática y los
contratos de F3.3; no dupliques la simulación ni reabras F2.1–F3.2. No avances a
F3.5 ni a ninguna otra subfase.

Antes de implementar es OBLIGATORIA la revisión visual completa de referencias
(AGENTS.md sección 10): usa el catálogo y las hojas de contacto, no cargues las
40 imágenes en contexto, no copies archivos de C:\Dev\fotos de ejemplo y
registra el uso en docs/reference/REFERENCE_USAGE_LOG.md.

La Fase 3.3 ya cerró:
- Contrato rain_surface_fx.json v1 con humedad, gotas, limpiaparabrisas,
  charcos y presupuestos.
- src/weather/{rain_surface_spec,surface_wetness_model,droplet_flow_model,
  wiper_kinematics,puddle_model}.gd.
- Prueba de lluvia 126/126; smoke 270, tren motriz 125, cabina 46,
  interacción 257; todas exit 0.
- CPU medida: PC ~0,21/~0,28 ms (media/p95) y móvil ~0,17/~0,21 ms.
- Render real de boot, rebanada y cabina en Vulkan Forward+ y build Windows
  exportada ejecutada 20 s y cerrada limpia.
No rehagas tren motriz, cabina, interacción, espejos, HUD, gamepad, guardado,
exterior ni interior.

Al iniciar:
  python tools/health_check.py --start
  python tools/scan_reference_library.py --quick

Al cerrar:
- valida esquemas, localización, manifiestos, roadmap y presets de export
- importa el proyecto en Godot headless
- ejecuta tools/dev/smoke_test.cmd, tools/dev/powertrain_test.cmd,
  tools/dev/cabin_test.cmd, tools/dev/interaction_test.cmd y
  tools/dev/rain_test.cmd
- prueba render real (boot, rebanada y cabina) con los shaders/VFX nuevos y la
  build de Windows exportada
- mide draw calls, overdraw, fill rate y frame time; verifica el warm-up antes
  del gameplay y los presupuestos del contrato
- comprueba espacio en disco y dispositivo ADB autorizado
- ejecuta health_check --end
- actualiza ROADMAP.md, docs/roadmap-data.json, CHANGELOG.md, CURRENT.md y
  HANDOFF
- haz commit, tag v0.3.3 y push solo si todo pasa
- entrega el prompt del siguiente /new

No avances a la Fase 3.5.
```

## Recordatorios

- La biblioteca de referencias externa sigue fuera del repositorio; la revisión
  completa de F3.4 es obligatoria antes de tocar shaders/VFX.
- La ExecutionPolicy de PowerShell está restringida: usar wrappers `.cmd`.
- El export se hace con `tools\dev\export.cmd`; los binarios van a `build/` y
  nunca a Git.
- Los presupuestos móviles siguen vigentes: ≤120.000 triángulos visibles
  (incluidos los tres viewports de espejo), RAM ≤1.2 GB PSS.
- Los tests deben seguir pasando sin relajarse: smoke (270), tren motriz (125),
  cabina (46), interacción (257) y lluvia (126). Al cambiar `EXPECTED_VERSION`
  del smoke test, actualizar también `VERSION`, `project.godot`,
  `export_presets.cfg` (`version/name` y `version/code`) y `PHASE` de `Boot.gd`.
- El contrato de F3.3 es la fuente de verdad: no mover valores de humedad,
  gotas, barrido o charcos al shader ni a la UI.
- El warm-up de shaders debe ejecutarse antes del gameplay; no se publica una
  build si el warm-up ocurre dentro de gameplay.
- No se sube ningún token, keystore, APK o AAB a Git.
- Las cotas de carrocería/interior siguen siendo provisionales hasta verificar
  el manual o medir el vehículo real.
- La fusión visual de gotas y el barrido GLSL son F3.4; la pérdida de agarre,
  el vadeo y el anti-atasco son F5.1.

## Seguridad

El inicio de sesión usado para publicar debe rotarse o revocarse después de la
publicación si el token fue compartido por un canal no seguro. La configuración
local de Git no contiene el token.
