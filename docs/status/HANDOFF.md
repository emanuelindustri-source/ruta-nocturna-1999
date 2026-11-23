# Handoff — Fase 3.2

## Estado de partida

La Fase 3.1 quedó completada, validada y publicada. El Esteem ya tiene su
**exterior definitivo** generado por script `bpy` reproducible, con piezas
separadas, LOD0/LOD1/LOD2 decrecientes, materiales PBR propios, llantas con
tapacubo, faros con piloto ámbar, pilotos traseros de tres franjas y espejos
sobre las anclas de F2.4.

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Versión: `v0.3.0` (Android `version/code=107`, Windows `0.3.0.0`)
- Spec del exterior: `data/vehicle/exterior_spec.json` (`schema_version: 1`).
- Script: `tools/blender/esteem_exterior.py` (target `vehicle.esteem.exterior`).
- Salidas: `esteem_exterior_lod0.glb` (6.024 tri, máx. 20.000),
  `esteem_exterior_lod1.glb` (2.044, máx. 9.000), `esteem_exterior_lod2.glb`
  (408, máx. 4.000) y `esteem_exterior_rig_anchor.glb` (17 anclas).
- Manifiesto: `assets/manifests/esteem_exterior.manifest.json`.
- Escena: `scenes/vehicle/EsteemExterior.tscn`; la rebanada vertical ya la
  instancia (`VerticalSlice.tscn`, solo LOD0 visible).
- Espejos F2.4 intactos: `cabin_mirrors.gd` sigue anclado a
  `anchor_mirror_left/right` (las carcasas del exterior envuelven esas anclas)
  y respeta `mirrors.budget` de `cabin_interaction.json` v2 (6/12 triángulos,
  3 pasos). Verificado en el smoke test y en `interaction_test`.
- Pruebas: `tools/dev/smoke_test.cmd` **232**, `powertrain_test.cmd` **125**,
  `cabin_test.cmd` **46**, `interaction_test.cmd` **257**; todas exit 0.
- Build Windows debug exportada y probada (arranque, render Vulkan, cierre
  limpio). ADB: dispositivo `obojropz89mbwgpn` autorizado (sin build Android
  nueva en esta subfase).
- Health de cierre: 20 OK, 2 advertencias esperadas, 0 errores.
- Revisión visual completa del hito F3.1 registrada en
  `docs/reference/REFERENCE_USAGE_LOG.md`; biblioteca externa sin cambios.

## Qué debe hacer F3.2

Alcance exclusivo de **MiMo Pro** (tag `v0.3.1`), según `ROADMAP.md`:

1. **Interior final**: tablero, instrumentales, consola, telas y tapicería,
   asientos, alfombrado y acabados, generados con scripts `bpy` reproducibles;
   nada de `.blend` editados a mano.
2. **Herramientas y maletero**: objetos del maletero como piezas reales
   (referencia para el inventario de F5.1; sin mecánicas nuevas).
3. **Manos definitivas**: sustituir los proxies de manos de F2.3 por manos con
   malla propia, manteniendo el rig y las poses IK de F2.2 (`esteem_hand_rig`
   o extensión del contrato con `schema_version` si cambia la estructura).
4. **Materiales PBR** propios (telas, plásticos, vinilos) y LOD0/LOD1/LOD2
   decrecientes para todo asset nuevo; manifiesto con comando, hashes, autor,
   licencia y fecha.
5. Actualizar `data/vehicle/cabin_spec.json` (o un spec nuevo de interior) con
   `schema_version` si cambia la estructura, regenerar manifiestos y pasar
   `tools/validate_assets.py`, los cuatro tests y `health_check.py --end`.

Reglas:

- **Revisión visual completa de referencias obligatoria antes de F3.2**
  (`AGENTS.md` sección 10): usar el catálogo y hojas de contacto; no cargar
  las 40 imágenes en contexto; registrar el uso en
  `docs/reference/REFERENCE_USAGE_LOG.md`; no copiar archivos de
  `C:\Dev\fotos de ejemplo`.
- Las cotas siguen siendo provisionales: verificar contra manual o medición
  antes de publicarlas (ver `ESTEEM_MECHANICAL_NOTES.md`).
- No reproducir marcas Chevrolet, PDV, Suzuki ni emblemas; sin texto visible
  en la malla (la señalética usa claves de localización).
- No rehacer F2.1–F3.1: tren motriz, cabina funcional, interacción, espejos,
  HUD, gamepad, guardado y exterior están cerrados y con pruebas. El interior
  definitivo sustituye al greybox de F2.2 sin tocar `cabin_interaction.json`
  (v2) ni sus tests salvo que el contrato exija una extensión aditiva
  documentada.
- Los espejos funcionales deben seguir funcionando y respetando
  `mirrors.budget`; no duplicar superficies de espejo.
- No avanzar a F3.3–F3.5 ni a ninguna otra subfase en ese chat.

Antes de implementar, revisa solo las referencias del catálogo relevantes para
el interior (tablero, telas, asientos, maletero y herramientas) y registra su
uso. No cargues las 40 imágenes en contexto ni copies archivos de
`C:\Dev\fotos de ejemplo` al repositorio.

## Prompt para el siguiente chat

```text
[RN1999 · Subfase 3.2]
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
- data/vehicle/cabin_spec.json
- data/vehicle/exterior_spec.json
- data/schemas/cabin_interaction.json

Ejecuta únicamente la Subfase 3.2 (tag v0.3.1): interior final del Esteem
(tablero, telas, asientos, herramientas, maletero y manos), piezas separadas,
LOD0/LOD1/LOD2 y materiales PBR. No avances a F3.3 ni a ninguna otra subfase.

Antes de implementar es OBLIGATORIA la revisión visual completa de referencias
(hitos de AGENTS.md sección 10): usa el catálogo y las hojas de contacto, no
cargues las 40 imágenes en contexto, no copies archivos de
C:\Dev\fotos de ejemplo al repositorio y registra el uso en
docs/reference/REFERENCE_USAGE_LOG.md.

Todo modelo procede de un script bpy reproducible con manifiesto (comando,
hashes, autor, licencia, fecha); prohibido editar .blend a mano. Ningún modelo
entra sin LOD0/LOD1/LOD2 decrecientes. No reproduzcas marcas Chevrolet/PDV/
Suzuki ni texto visible en la malla.

La Fase 3.1 ya cerró: exterior definitivo (exterior_spec.json,
esteem_exterior.py, LOD0 6.024/LOD1 2.044/LOD2 408 tri), espejos F2.4
funcionales sobre anchor_mirror_* (mirrors.budget respetado), rebanada vertical
con el exterior y smoke test en 232 comprobaciones. No rehagas tren motriz,
exterior, interacción, espejos, HUD, gamepad ni guardado.

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
- haz commit, tag v0.3.1 y push solo si todo pasa
- entrega el prompt del siguiente /new

No avances a la Fase 3.3.
```

## Recordatorios

- La biblioteca de referencias externa sigue fuera del repositorio; la revisión
  completa de F3.2 es obligatoria antes de modelar.
- La ExecutionPolicy de PowerShell está restringida: usar wrappers `.cmd`.
- El export se hace con `tools\dev\export.cmd`; los binarios van a `build/` y
  nunca a Git.
- Los presupuestos móviles siguen vigentes: ≤120.000 triángulos visibles
  (incluidos los tres viewports de espejo), RAM ≤1.2 GB PSS (medido: 379,8 MB).
- Los tests deben seguir pasando sin relajarse: smoke (232), tren motriz (125),
  cabina (46) e interacción (257). Al cambiar `EXPECTED_VERSION` del smoke
  test, actualizar también `VERSION`, `project.godot`, `export_presets.cfg`
  (`version/name` y `version/code`) y `PHASE` de `Boot.gd`.
- El interior definitivo de F3.2 sustituye al greybox de F2.2; las posiciones
  de mandos y las poses IK siguen apoyándose en las anclas `anchor_*` del
  bloqueo y en `cabin_interaction.json` v2 (extensión aditiva si hiciera falta,
  con `schema_history`).
- No se sube ningún token, keystore, APK o AAB a Git.
- Las cotas de carrocería/interior siguen siendo provisionales hasta verificar
  el manual o medir el vehículo real.

## Seguridad

El inicio de sesión usado para publicar debe rotarse o revocarse después de la
publicación si el token fue compartido por un canal no seguro. La configuración
local de Git no contiene el token.
