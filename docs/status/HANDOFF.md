# Handoff — Fase 3.3

## Estado de partida

La Fase 3.2 quedó completada, validada y publicada. El Esteem ya tiene su
**interior definitivo** generado por script `bpy` reproducible, con piezas
separadas, LOD0/LOD1/LOD2 decrecientes, materiales PBR propios (telas de dos
tonos, vinilos, alfombrado), manos definitivas con malla propia sobre el rig de
F2.2 y herramientas del maletero enlazadas con `inventory_tools.json`.

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Versión: `v0.3.1` (Android `version/code=108`, Windows `0.3.1.0`)
- Spec del interior: `data/vehicle/interior_spec.json` (`schema_version: 1`).
- Script: `tools/blender/esteem_interior.py` (target `vehicle.esteem.interior`).
- Salidas: `esteem_interior_lod0.glb` (7.408 tri, máx. 18.000),
  `esteem_interior_lod1.glb` (1.564, máx. 8.000), `esteem_interior_lod2.glb`
  (712, máx. 3.000) y `esteem_interior_rig_anchor.glb` (9 anclas idénticas al
  bloqueo).
- Manifiesto: `assets/manifests/esteem_interior.manifest.json`.
- Escena: `scenes/vehicle/EsteemInterior.tscn`; `CabinInteraction.tscn` la
  instancia en lugar del greybox de F2.2 (el greybox `EsteemCabin.tscn` y sus
  tests de `cabin_test` se conservan intactos).
- Manos: `hand_left`/`hand_right` con malla propia; `cabin_visual_proxies.gd`
  las reubica con la IK de F2.2 (misma API que los proxies de caja, que siguen
  como fallback). `cabin_interaction.json` (v2) **no se tocó**.
- Herramientas del maletero con `inventory_id` de `inventory_tools.json`
  (`tool.jack`, `tool.wheel_wrench`, `tool.boards`, `tool.spare_tire`,
  `tool.flashlight`, `tool.screwdriver_set`, `tool.pliers`,
  `tool.adjustable_wrench`, `tool.socket_set`, `tool.jumper_cables`):
  referencia para el inventario de F5.1, sin mecánicas.
- Pruebas: `tools/dev/smoke_test.cmd` **270**, `powertrain_test.cmd` **125**,
  `cabin_test.cmd` **46**, `interaction_test.cmd` **257**; todas exit 0.
- Render real: Boot, rebanada vertical y cabina en Vulkan Forward+ sin
  errores; build Windows exportada ejecutada 20 s y cerrada limpia. ADB:
  dispositivo `obojropz89mbwgpn` autorizado (sin build Android nueva en esta
  subfase).
- Health de cierre: 20 OK, 2 advertencias esperadas, 0 errores.
- Revisión visual completa del hito F3.2 registrada en
  `docs/reference/REFERENCE_USAGE_LOG.md`; biblioteca externa sin cambios.

## Qué debe hacer F3.3

Alcance exclusivo de **DS-R** (tag `v0.3.2`), según `ROADMAP.md`:

1. **Matemática de humedad**: contrato del estado de humedad de superficies
   (secado, saturación, drenaje) y su enlace con `WeatherManager` (F4.4 la
   consumirá; sin autoloads nuevos sin contrato).
2. **Flujo de gotas**: modelo matemático de nucleación, crecimiento, desliz
   y escurrido sobre carrocería y cristales (parámetros declarativos; el GLSL
   de producción es F3.4).
3. **Limpiaparabrisas**: cinemática del barrido, zona limpia, velocidad y
   desgaste de la goma, con contrato de datos.
4. **Charcos**: formación, evaporación y profundidad por zonas (enlace futuro
   con vadeo de F5.1), con presupuestos declarados.
5. **Presupuestos**: medición y declaración de coste de la lluvia física
   (objetivos de frame para PC/móvil; sin implementar shaders todavía).

Reglas:

- Es una subfase de **matemática y contratos**, no de arte ni shaders: no se
  generan assets, no se toca la fábrica Blender y no se rompe ningún test.
- **Revisión visual completa de referencias obligatoria antes de F3.3**
  (`AGENTS.md`, sección 10): usar el catálogo y hojas de contacto; no cargar
  las 40 imágenes en contexto; registrar el uso en
  `docs/reference/REFERENCE_USAGE_LOG.md`; no copiar archivos de
  `C:\Dev\fotos de ejemplo`.
- Todo contrato nuevo o ampliado respeta `data-first`: `schema_version`,
  condiciones declarativas, validación en `tools/validate_schemas.py` y notas
  de fuente. Implementar mecánicas solo después de que el contrato valide.
- No rehacer F2.1–F3.2: tren motriz, cabina funcional, interacción, espejos,
  HUD, gamepad, guardado, exterior e interior están cerrados y con pruebas.
- No avanzar a F3.4 ni a ninguna otra subfase en ese chat.

Antes de implementar, revisa solo las referencias del catálogo relevantes para
la lluvia (gotas sobre pintura/vidrio, limpiaparabrisas, charcos y asfalto
mojado) y registra su uso. No cargues las 40 imágenes en contexto ni copies
archivos de `C:\Dev\fotos de ejemplo` al repositorio.

## Prompt para el siguiente chat

```text
[RN1999 · Subfase 3.3]
CWD: C:\Dev\RutaNocturna1999
Modelo asignado: DS-R (opencode-go/deepseek-v4.1-flash#max)

Lee completos:
- AGENTS.md
- ROADMAP.md
- docs/status/CURRENT.md
- docs/status/HANDOFF.md
- docs/architecture/SYSTEM_ARCHITECTURE.md
- docs/architecture/DATA_CONTRACTS.md
- docs/architecture/QA_AND_RECOVERY.md
- data/schemas/vehicle_powertrain.json
- data/schemas/cabin_interaction.json

Ejecuta únicamente la Subfase 3.3 (tag v0.3.2): matemática de humedad, flujo
de gotas, limpiaparabrisas, charcos y presupuestos. Subfase de matemática y
contratos declarativos: sin assets nuevos, sin shaders GLSL (eso es F3.4) y sin
mecánicas antes de que sus contratos validen. No avances a F3.4 ni a ninguna
otra subfase.

Antes de implementar es OBLIGATORIA la revisión visual completa de referencias
(hitos de AGENTS.md sección 10): usa el catálogo y las hojas de contacto, no
cargues las 40 imágenes en contexto, no copies archivos de
C:\Dev\fotos de ejemplo al repositorio y registra el uso en
docs/reference/REFERENCE_USAGE_LOG.md.

La Fase 3.2 ya cerró: interior definitivo (interior_spec.json,
esteem_interior.py, LOD0 7.408/LOD1 1.564/LOD2 712 tri), manos definitivas
sobre el rig de F2.2 (cabin_interaction.json v2 intacto), herramientas del
maletero enlazadas con inventory_tools.json, rebanada/cabina/boot probadas con
render real y smoke test en 270 comprobaciones. No rehagas tren motriz,
cabina, interacción, espejos, HUD, gamepad, guardado, exterior ni interior.

Al iniciar:
  python tools/health_check.py --start
  python tools/scan_reference_library.py --quick

Al cerrar:
- valida esquemas, localización, manifiestos, roadmap y presets de export
- importa el proyecto en Godot headless
- ejecuta tools/dev/smoke_test.cmd, tools/dev/powertrain_test.cmd,
  tools/dev/cabin_test.cmd y tools/dev/interaction_test.cmd
- prueba la versión del juego con render real (rebanada, cabina y boot) y la
  build de Windows exportada
- comprueba espacio en disco y dispositivo ADB autorizado
- ejecuta health_check --end
- actualiza ROADMAP.md, docs/roadmap-data.json, CHANGELOG.md, CURRENT.md y HANDOFF
- haz commit, tag v0.3.2 y push solo si todo pasa
- entrega el prompt del siguiente /new

No avances a la Fase 3.4.
```

## Recordatorios

- La biblioteca de referencias externa sigue fuera del repositorio; la revisión
  completa de F3.3 es obligatoria antes de escribir los contratos de lluvia.
- La ExecutionPolicy de PowerShell está restringida: usar wrappers `.cmd`.
- El export se hace con `tools\dev\export.cmd`; los binarios van a `build/` y
  nunca a Git.
- Los presupuestos móviles siguen vigentes: ≤120.000 triángulos visibles
  (incluidos los tres viewports de espejo), RAM ≤1.2 GB PSS (medido: 379,8 MB).
- Los tests deben seguir pasando sin relajarse: smoke (270), tren motriz (125),
  cabina (46) e interacción (257). Al cambiar `EXPECTED_VERSION` del smoke
  test, actualizar también `VERSION`, `project.godot`, `export_presets.cfg`
  (`version/name` y `version/code`) y `PHASE` de `Boot.gd`.
- El interior definitivo de F3.2 sustituyó al greybox de F2.2 en
  `CabinInteraction.tscn`; los `visual_offsets` de `cabin_interaction.json` v2
  siguen aplicándose sobre las piezas de mando (posiciones de bind de
  `cabin_spec.json`); su retirada se decide con la geometría de F3.5/F10.1.
- Los contratos de lluvia de F3.3 serán consumidos por F3.4 (GLSL), F4.4
  (`WeatherManager`) y F5.1 (vadeo/charcos): mantener IDs estables.
- No se sube ningún token, keystore, APK o AAB a Git.
- Las cotas de carrocería/interior siguen siendo provisionales hasta verificar
  el manual o medir el vehículo real.

## Seguridad

El inicio de sesión usado para publicar debe rotarse o revocarse después de la
publicación si el token fue compartido por un canal no seguro. La configuración
local de Git no contiene el token.
