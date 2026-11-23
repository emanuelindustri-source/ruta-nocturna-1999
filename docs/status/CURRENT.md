# Estado actual

**Subfase:** 3.2 — Interior definitivo del Esteem  
**Versión:** `v0.3.1`  
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
| Localización | 11 idiomas, 0 errores; `BOOT_KICKER` a Fase 3.2; fuentes CJK pendientes de F8.4 |
| Assets generados | 4 manifiestos válidos (bloqueo + cabina + exterior + interior), 0 errores |
| Interior (F3.2) | LOD0 7.408 tri (máx. 18.000), LOD1 1.564 (máx. 8.000), LOD2 712 (máx. 3.000); decrecientes; rig anchor con 9 anclas idénticas al bloqueo |
| Validación de interior | Cotas/anclas coherentes con `blockout_spec.json`; manos en `hand_l_palm`/`hand_r_palm` de `cabin_spec.json`; herramientas enlazadas con `inventory_tools.json` (gato, llave de cruz, tablas y repuesto presentes); 33 nodos interactivos de `cabin_visual_proxies.gd` declarados |
| Smoke test | 270/270 comprobaciones, exit 0 (eran 232; +38 del interior) |
| Tren motriz | 125/125 comprobaciones, exit 0 (sin cambios) |
| Cabina y rig de manos | 46/46 comprobaciones, exit 0 (sin cambios) |
| Interacción contextual | 257/257 comprobaciones, exit 0 (sin cambios; la escena ahora instancia el interior definitivo y las manos con malla propia siguen la IK) |
| Godot import headless | exit 0; 4 `.glb` del interior importados sin errores |
| Presets de export | Windows y Android válidos; `0.3.1`, Android `version/code=108` |
| Build Windows exportada | `build/exports/windows/RutaNocturna1999.exe`, 103.070.208 bytes, SHA-256 `5B776A111EAE1E60269F63C25294FD6CCE55435FFE51A90C6F1ED85C0BB197DB` |
| Prueba de juego (render real) | Boot (`BOOT_READY version=0.3.1`), rebanada vertical con el exterior (`VERTICAL_SLICE_READY version=0.3.1`) y cabina con el interior definitivo y los 3 espejos `SubViewport`, todas en Vulkan Forward+ sin errores; build exportada ejecutada 20 s y cerrada limpia (exit 0, sin marcador de sesión residual) |
| Referencias | Revisión visual completa del hito F3.2 con hojas de contacto de interior y 6 copias de trabajo; registro en `REFERENCE_USAGE_LOG.md`; biblioteca externa sin cambios (95 archivos) |
| Espacio libre | 79,8 GB en `C:` (mínimo 20 GB) |
| Dispositivo ADB | Redmi 22101316G autorizado (`obojropz89mbwgpn`) |
| Git | Rama `main`, commit y tag `v0.3.1` publicados |

Advertencias conocidas:

- 202 claves de contenido aún no están en el CSV de localización (F8.4).
- Las fuentes CJK/cirílicas se empaquetan y validan visualmente en F8.4.
- Las cotas de carrocería/interior siguen siendo `provisional_design_value`:
  verificar contra manual o medición antes de Fase 5
  (`ESTEEM_MECHANICAL_NOTES.md`).
- El interior es arte paramétrico de la fábrica (piezas biseladas, telas de dos
  tonos y herramientas del maletero): la disposición, las telas, el
  instrumental sin texto, las manos y las herramientas corresponden a la
  revisión visual de F3.2, pero el pulido fino del tejido, costuras, juntas y
  materiales queda para F3.5/F10.1. Los renders QA de verificación están en
  `build/reference/interior_qa/` (no versionados).
- Las piezas de mando del interior se modelan en las posiciones de bind de
  `cabin_spec.json` y la capa de interacción de F2.3 aplica los
  `visual_offsets` de `cabin_interaction.json` v2 a la cara del tablero (igual
  que con el greybox); el resto del interior se diseñó en el espacio final para
  que el conjunto monte en la escena de interacción (`assembly_note` del spec).
  La retirada definitiva de esos offsets provisionales se decide junto con la
  geometría de F3.5/F10.1.
- Las manos definitivas (`hand_left`/`hand_right`) sustituyen los proxies de
  caja de F2.3 al instanciar la escena; la API
  `get_hand_proxy_position/visible` y las poses IK de F2.2 no cambian.
- Los espejos funcionales (F2.4) siguen siendo las superficies `QuadMesh` +
  `SubViewport` de `cabin_mirrors.gd`, ancladas a `anchor_mirror_left/right`;
  `mirrors.budget` de `cabin_interaction.json` (v2) se respeta: 6/12
  triángulos de superficie y 3 pasos de render. El retrovisor interior del
  interior es solo carcasa (sin superficie reflectante duplicada). La medición
  de pasos reales en ruta es F3.5/F10.1.
- No hay conducción real: el chasis `VehicleBody3D` y la física son F2+/F5
  según el gate correspondiente; la rebanada sigue sin cuerpos de física.
- La build de Windows exportada es debug de referencia, no versionada, en
  `build/exports/`.
- La prueba ADB completa (`test_android_adb.ps1`) no se repite en F3.2 (no es
  hito Android); el dispositivo sigue autorizado y la APK nueva llega en
  F3.5/F10.2. `tools/dev/export.cmd` generó APK debug de referencia en
  `build/exports/` (no versionada).

## Completado

- **Revisión visual completa de referencias** (hito obligatorio de F3.2):
  catálogo (95 fichas), hoja de contacto de interior (49 referencias),
  mosaico de detalle de tablero/telas/maletero y seis copias de trabajo
  ampliadas ×2; uso registrado en `docs/reference/REFERENCE_USAGE_LOG.md`. Sin
  copiar archivos de `C:\Dev\fotos de ejemplo` y sin cargar las 40 imágenes.
- `data/vehicle/interior_spec.json` con el interior definitivo en **piezas
  separadas**: tablero bitono con bandeja del acompañante, instrumental de tres
  básculas con agujas ámbar y carátulas sin texto, consola central con radio
  cassette doble DIN y clima con deslizadores, guantera con cierre, palanca
  P-R-N-D-2-L con botón de Overdrive, freno de mano, butacas delanteras y
  banqueta trasera con telas de dos tonos, cuatro tarjetas de puerta con
  inserto de tela, alfombrado, techo con pilares y visores, maletero con
  moqueta y **herramientas reales del inventario** (gato, llave de cruz,
  repuesto, tablas, linterna, destornilladores, alicates, llave ajustable,
  carracas y cables) y **manos definitivas** con malla propia.
- Materiales **PBR propios** (vinilos, plásticos, telas, alfombrado, moqueta,
  cinturones, metal, carátulas, agujas con emisión, cristal, acero, madera,
  goma y piel): ninguna textura ni color de la biblioteca externa; sin marcas
  Chevrolet, PDV, Suzuki ni emblemas; sin texto visible en la malla.
- `tools/blender/esteem_interior.py` + target `vehicle.esteem.interior` en la
  fábrica; manifiesto reproducible con comando, hashes de script/spec/salidas,
  autor, licencia y fecha.
- `tools/validate_assets.py` ampliado con la validación del spec de interior
  (bloqueo, rig de manos, inventario y nodos interactivos).
- `scenes/vehicle/EsteemInterior.tscn`; `CabinInteraction.tscn` instancia el
  interior definitivo en lugar del greybox de F2.2 (el greybox y sus tests se
  conservan intactos).
- `cabin_visual_proxies.gd`: las manos con malla propia sustituyen los proxies
  de caja en runtime, sin cambios en `cabin_interaction.json` (v2) ni en la API.
- Smoke test ampliado a 270 comprobaciones con la verificación del interior,
  las manos, las herramientas del maletero y las anclas.
- Versión `0.3.1` en `VERSION`, `project.godot`, `export_presets.cfg`
  (`version/code=108`), `EXPECTED_VERSION` del smoke test, `PHASE` de Boot y
  `BOOT_KICKER` en once idiomas.

## Siguiente

Fase **3.3 con DS-R**: matemática de humedad, flujo de gotas,
limpiaparabrisas, charcos y presupuesto (tag `v0.3.2`). No se inicia en este
chat. El prompt completo está en `docs/status/HANDOFF.md`.
