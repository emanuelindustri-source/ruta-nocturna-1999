# Handoff — Fase 3.1

## Estado de partida

La Fase 2.4 quedó completada, validada y publicada. La cabina del Esteem ya
tiene espejos con `SubViewport`, HUD mínimo, navegación gamepad/D-Pad y la
línea base de guardado `v0.2.0`, además de la interacción contextual de F2.3.

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Versión: `v0.2.3` (Android `version/code=106`, Windows `0.2.3.0`)
- Contrato de cabina: `data/schemas/cabin_interaction.json` (**`schema_version:
  2`** con `mirrors`, `hud`, `gamepad` y `schema_history`).
- Espejos: `src/vehicle/cabin_mirrors.gd` en `scenes/vehicle/CabinInteraction.tscn`.
- HUD: `src/vehicle/cabin_hud.gd` (lee `VehiclePowertrain.get_telemetry()`).
- Gamepad: `src/vehicle/cabin_gamepad_adapter.gd` + `[input]` en `project.godot`.
- Guardado: `src/core/save_manager.gd` (backup con rutas absolutas corregidas),
  fixture `tests/fixtures/save_v0_2_0.json` y `tools/make_save_fixture.py`.
- Panel QA: `src/ui/creator_qa_menu.gd` con sección de vehículo y ranura QA;
  instanciado en Boot y en la cabina.
- Pruebas: `tools/dev/smoke_test.cmd` **198**, `powertrain_test.cmd` **125**,
  `cabin_test.cmd` **46**, `interaction_test.cmd` **257**; todas exit 0.
- ADB: `tools/test_android_adb.ps1` superado en el Redmi
  (`obojropz89mbwgpn`), PSS 379,8 MB, logcat limpio; APK debug en
  `build/exports/` (no versionada).
- Health de cierre: 19 OK, 3 advertencias esperadas, 0 errores.

## Qué debe hacer F3.1

Alcance exclusivo de **MiMo Pro** (tag `v0.3.0`), según `ROADMAP.md`:

1. **Exterior definitivo del Esteem**: carrocería con piezas separadas
   (puertas, capó, maletero, parachoques, molduras, retrovisores) generada con
   scripts `bpy` reproducibles; nada de `.blend` editados a mano.
2. **LODs**: LOD0/LOD1/LOD2 estrictamente decrecientes y dentro de
   presupuesto; ningún modelo entra sin los tres niveles.
3. **Materiales PBR** propios (sin texturas de la biblioteca externa) y
   manifiesto con comando, hashes, autor, licencia y fecha.
4. **Llantas, faros y espejos** como piezas del exterior; los espejos de F2.4
   son funcionales (cámaras `SubViewport`) y deberán integrarse con el nuevo
   modelo sin romper `cabin_interaction.json` ni su presupuesto.
5. Actualizar `data/vehicle/blockout_spec.json`/nuevo spec de exterior con
   `schema_version` si cambia la estructura, regenerar manifiestos y pasar
   `tools/validate_assets.py`, los cuatro tests y `health_check.py --end`.

Reglas:

- **Revisión visual completa de referencias obligatoria antes de F3.1**
  (`AGENTS.md` sección 10, hito de revisión): usar el catálogo y hojas de
  contacto; no cargar las 40 imágenes en contexto; registrar el uso en
  `docs/reference/REFERENCE_USAGE_LOG.md`; no copiar archivos de
  `C:\Dev\fotos de ejemplo`.
- Las cotas del bloqueo siguen siendo provisionales: verificar contra manual o
  medición antes de publicarlas (ver `ESTEEM_MECHANICAL_NOTES.md`).
- No reproducir marcas Chevrolet, PDV ni emblemas.
- No rehacer F2.1–F2.4: tren motriz, cabina, interacción, espejos, HUD,
  gamepad y guardado están cerrados y con pruebas; la interacción y el HUD
  solo cambian si el nuevo exterior lo exige, manteniendo contratos y tests.
- No introducir física de conducción sin contrato; no avanzar a F3.2–F3.5 en
  este chat.

Antes de implementar, revisa solo las referencias del catálogo relevantes para
el exterior, las llantas, los faros y los espejos, y registra su uso en
`docs/reference/REFERENCE_USAGE_LOG.md`. No cargues las 40 imágenes en
contexto ni copies archivos de `C:\Dev\fotos de ejemplo` al repositorio.

## Prompt para el siguiente chat

```text
[RN1999 · Subfase 3.1]
CWD: C:\Dev\RutaNocturna1999
Modelo asignado: MiMo Pro (opencode-go/mimo-v2.6-pro)

Lee completos:
- AGENTS.md
- ROADMAP.md
- docs/status/CURRENT.md
- docs/status/HANDOFF.md
- docs/architecture/SYSTEM_ARCHITECTURE.md
- docs/architecture/DATA_CONTRACTS.md
- docs/architecture/ASSET_FACTORY.md
- docs/architecture/QA_AND_RECOVERY.md
- data/vehicle/blockout_spec.json
- data/schemas/vehicle_components.json

Ejecuta únicamente la Subfase 3.1 (tag v0.3.0): exterior definitivo del Esteem,
piezas separadas, LOD0/LOD1/LOD2, materiales PBR, llantas, faros y espejos.
No avances a F3.2 ni a ninguna otra subfase.

Antes de implementar es OBLIGATORIA la revisión visual completa de referencias
(hitos de AGENTS.md sección 10): usa el catálogo y las hojas de contacto, no
cargues las 40 imágenes en contexto, no copies archivos de
C:\Dev\fotos de ejemplo al repositorio y registra el uso en
docs/reference/REFERENCE_USAGE_LOG.md.

Todo modelo procede de un script bpy reproducible con manifiesto (comando,
hashes, autor, licencia, fecha); prohibido editar .blend a mano. Ningún modelo
entra sin LOD0/LOD1/LOD2 decrecientes. No reproduzcas marcas Chevrolet/PDV.

La Fase 2.4 ya cerró: espejos SubViewport (cabin_mirrors.gd), HUD mínimo
(cabin_hud.gd), gamepad/D-Pad (cabin_gamepad_adapter.gd), save v0.2.0 con
fixture, QA de reparaciones y ADB. No rehagas tren motriz, cabina, interacción
ni guardado; los espejos funcionales deben seguir funcionando con el nuevo
exterior y respetar mirrors.budget en cabin_interaction.json (schema_version 2).

Al iniciar:
  python tools/health_check.py --start
  python tools/scan_reference_library.py --quick

Al cerrar:
- valida esquemas, localización, manifiestos, roadmap y presets de export
- importa el proyecto en Godot headless
- ejecuta tools/dev/smoke_test.cmd, tools/dev/powertrain_test.cmd,
  tools/dev/cabin_test.cmd y tools/dev/interaction_test.cmd
- comprueba espacio en disco y dispositivo ADB autorizado
- ejecuta health_check --end
- actualiza ROADMAP.md, docs/roadmap-data.json, CHANGELOG.md, CURRENT.md y HANDOFF
- haz commit, tag v0.3.0 y push solo si todo pasa
- entrega el prompt del siguiente /new

No avances a la Fase 3.2.
```

## Recordatorios

- La biblioteca de referencias externa sigue fuera del repositorio; la revisión
  completa de F3.1 es obligatoria antes de modelar.
- La ExecutionPolicy de PowerShell está restringida: usar wrappers `.cmd`.
- El export se hace con `tools\dev\export.cmd`; los binarios van a `build/` y
  nunca a Git.
- Los presupuestos móviles siguen vigentes: ≤120.000 triángulos visibles
  (incluidos los tres viewports de espejo), RAM ≤1.2 GB PSS (medido: 379,8 MB).
- El smoke test (198), el test del tren motriz (125), el test de la cabina (46)
  y el test de interacción (257) deben seguir pasando; no se relajan.
- Al cambiar `EXPECTED_VERSION` del smoke test, actualizar también `VERSION`,
  `project.godot` y `export_presets.cfg` (`version/name` y `version/code`).
- No se sube ningún token, keystore, APK o AAB a Git.
- Los `visual_offsets`, proxies y cotas de cabina siguen siendo provisionales;
  el arte de cabina/manos es F3.2.

## Seguridad

El inicio de sesión usado para publicar debe rotarse o revocarse después de la
publicación si el token fue compartido por un canal no seguro. La configuración
local de Git no contiene el token.
