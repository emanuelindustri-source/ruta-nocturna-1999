# Estado actual

**Subfase:** 3.1 — Exterior definitivo del Esteem  
**Versión:** `v0.3.0`  
**Modelo de la subfase:** MiMo Pro  
**Fecha:** 2026-11-22  
**Estado:** completada y publicada.

## Enlaces

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Acciones: https://github.com/emanuelindustri-source/ruta-nocturna-1999/actions

## Validación ejecutada

| Prueba | Resultado |
|---|---|
| Contratos JSON + Schemas | 7 contratos válidos, 0 errores, 1 advertencia conocida (202 claves de datos → F8.4) |
| Localización | 11 idiomas, 0 errores; `BOOT_KICKER` a Fase 3.1; fuentes CJK pendientes de F8.4 |
| Assets generados | 3 manifiestos válidos (bloqueo + cabina + exterior), 0 errores |
| Exterior (F3.1) | LOD0 6.024 tri (máx. 20.000), LOD1 2.044 (máx. 9.000), LOD2 408 (máx. 4.000); decrecientes; rig anchor con 17 anclas |
| Validación de exterior | Coherencia de cotas/ruedas con `blockout_spec.json`; carcasas de espejo envuelven `anchor_mirror_left/right`; presupuestos decrecientes |
| Smoke test | 232/232 comprobaciones, exit 0 (eran 198; +34 del exterior) |
| Tren motriz | 125/125 comprobaciones, exit 0 (sin cambios) |
| Cabina y rig de manos | 46/46 comprobaciones, exit 0 (sin cambios) |
| Interacción contextual | 257/257 comprobaciones, exit 0 (sin cambios; espejos 6/12 tri, 3 pasos) |
| Godot import headless | exit 0; 4 `.glb` del exterior importados sin errores |
| Presets de export | Windows y Android válidos; `0.3.0`, Android `version/code=107` |
| Build Windows exportada | `build/exports/windows/RutaNocturna1999.exe`, 103.070.208 bytes, SHA-256 `EF01E36751AA009D9F4ABDC3A8EB4BF7C0084356DE97AB085FBD129B54090330` |
| Prueba de juego (render real) | Rebanada vertical con el exterior renderizada en Vulkan Forward+ (`VERTICAL_SLICE_READY version=0.3.0`), cabina con los 3 espejos `SubViewport` sin errores y Boot (`BOOT_READY version=0.3.0`); build exportada ejecutada 20 s y cerrada limpia (sin marcador de sesión residual) |
| Referencias | Revisión visual completa del hito F3.1 con hojas de contacto y 6 copias de trabajo; registro en `REFERENCE_USAGE_LOG.md`; biblioteca externa sin cambios (95 archivos) |
| Espacio libre | 79,8 GB en `C:` (mínimo 20 GB) |
| Dispositivo ADB | Redmi 22101316G autorizado (`obojropz89mbwgpn`) |
| Git | Rama `main`, commit y tag `v0.3.0` publicados |

Advertencias conocidas:

- 202 claves de contenido aún no están en el CSV de localización (F8.4).
- Las fuentes CJK/cirílicas se empaquetan y validan visualmente en F8.4.
- Las cotas de carrocería siguen siendo `provisional_design_value`: verificar
  contra manual o medición antes de Fase 5 (`ESTEEM_MECHANICAL_NOTES.md`).
- El exterior es arte paramétrico de la fábrica (lofts de secciones y piezas
  biseladas): la silueta, los faros, los pilotos, las llantas y los espejos
  corresponden a la revisión visual de F3.1, pero el pulido fino de paneles,
  juntas y materiales queda para F3.5/F10.1. Los renders QA de verificación
  están en `build/reference/exterior_qa/` (no versionados).
- Los espejos funcionales (F2.4) siguen siendo las superficies `QuadMesh` +
  `SubViewport` de `cabin_mirrors.gd`, ancladas a `anchor_mirror_left/right`;
  el exterior aporta carcasa, brazo y vidrio visual en las mismas posiciones.
  `mirrors.budget` de `cabin_interaction.json` (v2) se respeta: 6/12
  triángulos de superficie y 3 pasos de render. La medición de pasos reales en
  ruta es F3.5/F10.1.
- No hay conducción real: el chasis `VehicleBody3D` y la física son F2+/F5
  según el gate correspondiente; la rebanada sigue sin cuerpos de física.
- La build de Windows exportada es debug de referencia, no versionada, en
  `build/exports/`.
- La prueba ADB completa (`test_android_adb.ps1`) no se repite en F3.1 (no es
  hito Android); el dispositivo sigue autorizado y la APK nueva llega en
  F3.5/F10.2.

## Completado

- **Revisión visual completa de referencias** (hito obligatorio de F3.1):
  catálogo (95 fichas), hoja de contacto de exterior (48 referencias),
  mosaico de detalle frente/trasera/perfil/despiece y seis copias de trabajo
  ampliadas; uso registrado en `docs/reference/REFERENCE_USAGE_LOG.md`. Sin
  copiar archivos de `C:\Dev\fotos de ejemplo` y sin cargar las 40 imágenes.
- `data/vehicle/exterior_spec.json` con el exterior definitivo en **piezas
  separadas**: bañera e invernadero por secciones transversales, capó, tapa de
  maletero, cuatro puertas con manijas tipo tirador, parachoques con boca de
  aire, parrilla neutra sin emblema, faros con piloto ámbar en la esquina
  externa, pilotos traseros de tres franjas (roja/ámbar/roja), carcasas de
  espejo sobre `anchor_mirror_*`, antena en el guardabarros delantero derecho,
  **tapa de combustible en el guardabarros trasero izquierdo** (observado en
  fotos), limpiaparabrisas, molduras laterales, seis paneles de vidrio y
  matrícula neutra sin texto.
- Materiales **PBR propios** (pintura metalizada beige, vidrio con
  transmisión, plástico, goma, cromo, acero y lentes con emisión tenue):
  ninguna textura ni color de la biblioteca externa; sin marcas Chevrolet,
  PDV, Suzuki ni emblemas.
- Llantas: neumático + llanta de acero + tapacubo con radios (solo LOD0),
  posiciones derivadas de `track_m`/`wheelbase_m`/`wheel_radius_m` del bloqueo.
- `tools/blender/esteem_exterior.py` + target `vehicle.esteem.exterior` en la
  fábrica; manifiesto reproducible con comando, hashes de script/spec/salidas,
  autor, licencia y fecha.
- `tools/validate_assets.py` ampliado con la validación del spec de exterior.
- `scenes/vehicle/EsteemExterior.tscn` y rebanada vertical con el exterior
  definitivo (solo LOD0 visible, sin física).
- Smoke test ampliado a 232 comprobaciones con la verificación del exterior y
  del anclaje de los espejos de F2.4 sobre el nuevo modelo.
- Versión `0.3.0` en `VERSION`, `project.godot`, `export_presets.cfg`
  (`version/code=107`), `EXPECTED_VERSION` del smoke test, `PHASE` de Boot y
  `BOOT_KICKER` en once idiomas.

## Siguiente

Fase **3.2 con MiMo Pro**: interior final, tablero, telas, asientos,
herramientas, maletero y manos (tag `v0.3.1`). Revisión visual completa de
referencias obligatoria antes de empezar (hito F3.2). No se inicia en este
chat.
