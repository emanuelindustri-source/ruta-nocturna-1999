# Changelog

Todas las fechas usan ISO 8601. Las versiones siguen SemVer.

## [Unreleased]

## [0.2.1] — 2026-11-22

### Añadido

- Contrato declarativo `data/vehicle/cabin_spec.json`: cabina funcional del Esteem
  (volante de tres radios, columna, tablero, instrumental, consola central, radio
  cassette doble DIN con ranura, clima, guantera con bandeja/cierre, paneles de
  puerta con apoyabrazos/tirador/cristaleras y consola) y el rig de manos con
  poses IK. Cotas de interior provisionales derivadas de las anclas `anchor_*` del
  bloqueo y de las fotos; no son especificación oficial.
- `tools/blender/esteem_cabin.py`: script `bpy` reproducible que genera las mallas
  LOD0/LOD1/LOD2 de la cabina y el armazón `EsteemHandRig` con huesos de mano,
  huesos de control alineados con `anchor_*` y poses IK (botón de Overdrive,
  palanca tipo T, freno de mano).
- Target `vehicle.esteem.cabin` en `tools/blender/build_assets.py`.
- Assets generados `esteem_cabin_lod0/1/2.glb` y `esteem_hand_rig.glb` con
  manifiesto `assets/manifests/esteem_cabin.manifest.json` (comando, hashes,
  autor, licencia CC BY-NC-SA 4.0, fecha).
- Escena `scenes/vehicle/EsteemCabin.tscn` (LOD0 visible, LOD1/2 ocultos, rig).
- `tests/vehicle/CabinTest.tscn` y `cabin_test.gd`: 46 comprobaciones headless
  (manifiesto y hashes, LODs decrecientes y coincidentes, rig de manos con
  `anchor_root`, compatibilidad de posiciones de anclas con el bloqueo, poses IK
  y ausencia de física de conducción).
- `tools/dev/cabin_test.cmd` y `.ps1`; chequeo `cabin_tests` en `health_check.py`.
- Revisión visual completa de referencias de interior para F2.2 registrada en
  `REFERENCE_USAGE_LOG.md` (hoja de contacto + 3 fotos a tamaño real; sin copiar
  archivos de la biblioteca externa).

### Cambiado

- Versión del proyecto a `0.2.1` (`VERSION`, `project.godot`, `export_presets.cfg`,
  `EXPECTED_VERSION` del smoke test).
- `export_presets.cfg`: `version/name` de Android a `0.2.1`, `version/code` a 104
  y versiones de Windows a `0.2.1.0`.
- `validate_assets.py` cubre el nuevo manifiesto de cabina (mismo contrato de
  LOD0/1/2 y `rig_anchor`).
- `ASSET_FACTORY.md`, `DATA_CONTRACTS.md`, `ESTEEM_MECHANICAL_NOTES.md`,
  `REFERENCE_USAGE_LOG.md` y `REFERENCE_REVIEW.md` actualizados con el alcance de
  2.2.

### Validación

- 6 contratos JSON válidos; advertencia previa de claves de contenido para F8.4.
- Localización de 11 idiomas sin errores; fuentes CJK pendientes de F8.4.
- Roadmap 6/45 subfases completadas (13,3%), JSON sincronizado con la web.
- Importación de Godot 4.7.2 headless con exit 0; sin marcadores críticos.
- Smoke test: 155/155 comprobaciones, exit 0 (sin cambios).
- Pruebas del tren motriz: 125/125, exit 0 (sin cambios).
- Pruebas de la cabina: 46/46, exit 0 (nuevo).
- Assets generados: 2 manifiestos válidos, 0 errores (LOD0 1584 / LOD1 704 /
  LOD2 480 triángulos, estrictamente decrecientes y dentro de presupuesto).
- `health_check.py --end`: 17 OK, 3 advertencias esperadas, 0 errores.
- Dispositivo ADB autorizado (Redmi 22101316G) y 79,86 GB libres en `C:`.
- Referencias: 95 archivos; escaneo rápido sin cambios; revisión de interior
  completada y registrada.

### Publicación

- Commit convencional, tag `v0.2.1` y push a `origin/main`.

### Estado

- Fase 2.2 completada: cabina funcional bloqueo (volante, palanca P-R-N-D-2-L con
  Overdrive, freno de mano, radio doble DIN, guantera, paneles y consola) y rig de
  manos con poses IK compatibles con `anchor_*`. Sin interacción (F2.3), espejos,
  HUD, gamepad ni guardado (F2.4).
- Siguiente: Fase 2.3 con DS-R (interacción contextual "mirar/tocar", IK manos,
  puertas, seguros, vidrios, luces, antena y radio).

## [0.2.0] — 2026-11-22

### Añadido

- Contrato `data/schemas/vehicle_powertrain.json` y su JSON Schema
  `data/schemas/json/vehicle_powertrain.schema.json`: motor, transmisión,
  combustible, frenos, refrigeración y parámetros longitudinales del vehículo,
  con `source_status`/`source_note` por sección.
- Simulación del tren motriz en `src/vehicle/`:
  - `engine_model.gd`: arranque, ralentí, curva de par, corte de inyección,
    fricción, retención, calado, ahogo, secado, modo seguro y agarrotamiento.
  - `automatic_transmission.gd`: P-R-N-D-2-L, Overdrive, convertidor de par,
    bloqueo en crucero, calendario de cambios y rechazo de cambios inválidos.
  - `brake_system.gd`: frenos de servicio y estacionamiento, fade térmico,
    desgaste de pastillas y nivel de líquido.
  - `fuel_system.gd`: tanque de 50 L, consumo, reserva y calado por vacío.
  - `cooling_system.gd`: termostato, radiador, electroventilador de dos
    velocidades, fallos de fusible/relé/motor y protecciones térmicas.
  - `vehicle_powertrain.gd`: orquestador longitudinal con señales locales y
    telemetría; sin UI, cabina ni `VehicleBody3D`.
- `tests/vehicle/PowertrainTest.tscn` y `powertrain_test.gd`: 125 comprobaciones
  headless del contrato y de todos los subsistemas.
- `tools/dev/powertrain_test.cmd` y `.ps1`: importación headless, ejecución y
  log en `build/logs/powertrain/latest.log`.
- Chequeo `powertrain_tests` en `health_check.py` y paso nuevo en CI.
- Integración del tren motriz en el smoke test (155 comprobaciones).

### Cambiado

- Versión del proyecto a `0.2.0` (`VERSION`, `project.godot`, presets, README).
- `validate_schemas.py` valida seis contratos y comprueba la coherencia del tren
  motriz con `vehicle_components.json` y `blockout_spec.json`.
- `ESTEEM_MECHANICAL_NOTES.md` separa los datos verificados del manual de los
  valores de simulación provisionales.
- `REFERENCE_USAGE_LOG.md`, `REFERENCE_REVIEW.md`, arquitectura y QA actualizados
  con el alcance de 2.1.
- Catálogo de referencias a 95 archivos; el nuevo video conceptual queda
  catalogado sin usarse en mecánica.

### Validación

- 6 contratos JSON válidos; advertencia previa de claves de contenido para F8.4.
- Localización de 11 idiomas sin errores; fuentes CJK pendientes de F8.4.
- Roadmap 5/45 subfases completadas (11,1%), JSON sincronizado con la web.
- Importación de Godot 4.7.2 headless con exit 0.
- Pruebas del tren motriz: 125/125, exit 0.
- Smoke test: 155/155 comprobaciones, exit 0.
- `health_check.py --end`: sin errores; advertencias esperadas documentadas.
- Dispositivo ADB autorizado y espacio en disco comprobados.
- Referencias: 95 archivos; escaneo rápido sin cambios pendientes.

### Publicación

- Commit convencional, tag `v0.2.0` y push a `origin/main`.

### Estado

- Fase 2.1 completada: tren motriz data-driven con pruebas; sin cabina, IK,
  espejos ni conducción narrativa.
- Siguiente: Fase 2.2 con MiMo Pro (cabina funcional, rig de manos y poses IK).

## [0.1.3] — 2026-11-22

### Añadido

- Rebanada vertical estática `scenes/vertical_slice/VerticalSlice.tscn`: bloqueo
  gris del Esteem sobre una carretera gris con terreno, marcas de carril, cámara,
  niebla y panel informativo. Sin física, tráfico ni conducción.
- Acceso localizado desde el boot con el botón `UI_VIEW_SLICE` y retorno con
  `UI_BACK`; claves nuevas `SLICE_TITLE` y `SLICE_SUBTITLE` en los once idiomas.
- `export_presets.cfg` con presets `Windows Desktop` (x86_64) y `Android`
  (arm64-v8a, APK debug firmada, paquete
  `com.emanuelindustri.rutanoucturna1999`).
- `tools/dev/export.ps1` y `tools/dev/export.cmd`: importación headless, export
  de Windows/Android, log y manifiesto con tamaños y SHA-256 en
  `build/logs/export/`.
- `tools/test_android_adb.ps1`: instalación `adb install -r`, arranque con
  `monkey`, marcador `BOOT_READY`, 15 s de `logcat`, captura, PSS y logs en
  `build/logs/android-smoke/`.
- `tools/validate_export.py`: valida presets, rutas, arquitectura, paquete,
  versión, inclusión del CSV y ausencia de secretos; integrado en
  `health_check.py` y en CI.
- Chequeos nuevos de salud: `export_presets`, `build_toolchain`,
  `android_device` y `tracked_secrets`.
- Workflow de CI con trabajo `godot` (descarga Godot 4.7.2 Linux, import headless,
  smoke test y detección de errores de script) y validación de presets.
- `docs/architecture/BUILD_AND_RELEASE.md` con el pipeline de build, ADB y CI.

### Cambiado

- Versión del proyecto a `0.1.3`.
- `project.godot` activa `textures/vram_compression/import_etc2_astc` para que el
  export Android genere la APK.
- `LocalizationManager` carga los `.translation` importados cuando el CSV no está
  presente en una build exportada; el CSV sigue siendo la fuente de verdad.
- Boot imprime el marcador estable `[RN1999] BOOT_READY` para las pruebas ADB.
- Smoke test ampliado a 138 comprobaciones: rebanada vertical, presupuesto móvil,
  ausencia de cuerpos de física, presets de export y versión.
- README, web de Pages y documentación de arquitectura actualizados a `v0.1.3`.

### Validación

- 5 contratos JSON válidos; advertencia previa de claves de contenido para F8.4.
- Localización de 11 idiomas y 62 claves sin errores; fuentes CJK pendientes de F8.4.
- Roadmap 4/45 subfases completadas (8,9%), JSON sincronizado con la web.
- Importación de Godot 4.7.2 headless con exit 0.
- Smoke test con 138/138 comprobaciones y exit 0.
- Export Windows debug verificado; el ejecutable arranca headless con 11/11
  servicios y localización en los 11 idiomas.
- APK Android debug compilada y firmada; instalada en el Redmi 22101316G y
  arrancada por ADB. Sin errores fatales en 15 s de logcat, PSS 376,5 MB y
  captura de la rebanada vertical en `build/logs/android-smoke/`.
- En MIUI/HyperOS fue necesario conceder "Instalar vía USB" al paquete; el
  intento inicial falló con `INSTALL_FAILED_USER_RESTRICTED`.
- `health_check.py --end`: 15 OK, 3 advertencias esperadas, 0 errores.
- Escaneo rápido de 94 referencias sin cambios.

### Publicación

- Commit convencional, tag `v0.1.3` y push a `origin/main`.

### Estado

- Fase 1 completada: vertical slice gris con build PC/APK, CI y Pages, sin
  mecánicas de conducción.
- Siguiente: Fase 2.1 con DS-R (motor, caja automática y tests).

## [0.1.2] — 2026-11-22

### Añadido

- Fábrica de assets Blender 4.5.16 headless: orquestador
  `tools/blender/build_assets.py`, generador paramétrico `bpy`
  `tools/blender/esteem_blockout.py` y wrapper `tools/blender/build_assets.cmd`.
- Contrato declarativo `data/vehicle/blockout_spec.json` con cotas provisionales
  del vehículo, masas de greybox, materiales, presupuestos de LOD y anclas de rig.
- Bloqueo del Esteem generado proceduralmente en `assets/generated/vehicle/`:
  `esteem_blockout_lod0.glb` (1.192 triángulos, máx. 8.000),
  `esteem_blockout_lod1.glb` (440, máx. 4.000) y
  `esteem_blockout_lod2.glb` (184, máx. 1.500); decrecientes y sin texturas de
  terceros.
- Ancla de rig `esteem_rig_anchor.glb`: armazón `EsteemRigAnchor` con
  `Skeleton3D` de 17 huesos `anchor_*` (ruedas, asientos, volante, palanca,
  freno de mano, cámaras, capó, maletero, espejos y techo) para el rig futuro.
- Manifiesto reproducible `assets/manifests/esteem_blockout.manifest.json` con
  comando exacto de Blender, hashes SHA-256 de entradas y salidas, autor,
  licencia CC BY-NC-SA 4.0 y fecha UTC.
- Validador `tools/validate_assets.py` (manifiestos, hashes, política de
  LOD0/LOD1/LOD2 y coherencia de anclas) integrado en `health_check.py`.
- Escena `scenes/vehicle/EsteemBlockout.tscn` con los tres LODs (solo LOD0
  visible) y el ancla de rig.
- Documentación del pipeline en `docs/architecture/ASSET_FACTORY.md` y sección 11
  de `docs/architecture/DATA_CONTRACTS.md`.
- Smoke test ampliado con 31 comprobaciones del bloqueo: manifiesto, hashes
  SHA-256, LODs, conteo de triángulos y los 17 huesos del ancla.

### Cambiado

- Versión del proyecto a `0.1.2`.
- `tools/dev/smoke_test.ps1` ejecuta la importación headless de Godot antes de la
  escena; el smoke test es autosuficiente en un clon limpio.
- `docs/reference/ESTEEM_MECHANICAL_NOTES.md` registra las cotas del bloqueo como
  valores de diseño provisionales pendientes de verificación.
- `docs/reference/REFERENCE_USAGE_LOG.md` registra la revisión de referencias del
  vehículo para el bloqueo (hoja de contacto, perfil lateral y manual Mitchell).

### Validación

- 5 contratos JSON validados; 1 advertencia previa de claves de contenido (F8.4).
- Localización de 11 idiomas sin errores; fuentes CJK pendientes de F8.4.
- Manifiestos de assets válidos: 4 salidas, hashes verificados, LOD0/1/2 con
  triángulos decrecientes y 17 anclas coincidentes con el spec.
- Roadmap 3/45 subfases (6,7%), JSON sincronizado con la web.
- Importación de Godot 4.7.2 headless con exit 0 (4 GLB importados sin errores).
- Smoke test con 118/118 comprobaciones y exit 0.
- `health_check.py --end`: 11 OK, 3 advertencias esperadas, 0 errores.
- Escaneo rápido de 94 referencias sin cambios.

### Publicación

- Commit convencional, tag `v0.1.2` y push a `origin/main`.

### Estado

- Fase 1.3 completada. Sin mecánicas de conducción. Las cotas del bloqueo son
  provisionales hasta verificarlas en Fase 2/Fase 5.
- Siguiente: Fase 1.4, CI, test Android/ADB, export Windows/APK y tag de
  vertical slice.

## [0.1.1] — 2026-11-22

### Añadido

- `EventBus` con señales tipadas y catálogo en `docs/architecture/EVENT_BUS.md`.
- Once autoloads base en orden topológico: `EventBus`, `HardwareProfiler`,
  `SettingsManager`, `LocalizationManager`, `GameState`, `SaveManager`,
  `AudioDirector`, `WeatherManager`, `UpdateChecker`, `CrashReporter` y
  `SceneRouter`.
- `CrashReporter` con logger nativo, búfer de log, contexto por servicios,
  reporte local y marcador de sesión para cierres anormales.
- `SaveManager` base con snapshot versionado, checksum canónico, escritura
  atómica, backup y rechazo de versiones futuras.
- `CreatorQAMenu` inicial con F12, cinco toques, estado, clima, modo de prueba,
  reporte local y copia al portapapeles.
- Boot de Fase 1.2 con verificación de servicios y aviso de cierre anormal previo.
- Smoke test de servicios base y wrapper `tools/dev/smoke_test.cmd`.
- Validación de autoloads y ejecución del smoke test dentro de `health_check.py`.

### Cambiado

- Versión del proyecto a `0.1.1`.
- Localización ampliada a 59 claves en los once idiomas.
- Las traducciones se cargan en runtime desde `localization/strings.csv`, sin
  depender de artefactos de importación.
- El orden de autoloads coincide exactamente con
  `data/schemas/autoload_dependencies.json`.

### Validación

- 5 contratos JSON validados; 1 advertencia de claves de contenido para F8.4.
- Localización de 11 idiomas y 59 claves sin errores; fuente CJK pendiente.
- 11 autoloads declarados y verificado el orden topológico.
- Importación de Godot 4.7.2 headless con exit 0.
- Boot headless con 11/11 servicios y exit 0.
- Smoke test con 87/87 comprobaciones y exit 0.
- Reporte local, marcador de sesión y panel QA verificados.
- Un warning no genera reporte de error; un error de GDScript sí.
- Un marcador de sesión simulado produjo el reporte de cierre anormal al arrancar.
- `health_check.py --end`: 10 OK, 3 advertencias esperadas, 0 errores.
- Escaneo rápido de 94 referencias sin cambios.

### Publicación

- Commit convencional, tag `v0.1.1` y push a `origin/main`.

### Estado

- Fase 1.2 completada. Sin mecánicas de conducción.
- Siguiente: Fase 1.3, fábrica Blender headless y bloqueo del Esteem.

## [0.1.0] — 2026-11-22

### Añadido

- Estructura base de Ruta Nocturna 1999.
- Reglas de ejecución, modelos, presupuestos y protocolo de contexto en `AGENTS.md`.
- Roadmap de 45 subfases y web inicial de GitHub Pages.
- Contratos canónicos para vehículo, herramientas, folclore, diálogos y autoloads.
- Arquitectura de autoloads y máquinas de estados.
- Herramientas de validación, sincronización del roadmap y escaneo de referencias.
- Localización base para los once idiomas.
- Inventario inicial de la biblioteca externa de referencias.
- Corrección de la marca RUNASADMIN de Godot y generación del debug keystore.

### Validación

- 5 contratos JSON y sus esquemas validados sin errores.
- Localización base de 11 idiomas sin errores de claves ni placeholders.
- Roadmap de 10 fases y 45 subfases sincronizado con la web.
- Importación y boot de Godot 4.7.2 en headless correctos.
- Web validada en navegador; Lighthouse 100 en accesibilidad, buenas prácticas y SEO.
- 94 referencias inventariadas, con dos duplicados exactos detectados.
- Bootstrap sin fallos críticos; advertencias: autenticación de GitHub y Android 36.
- ADB reconoce el Redmi 22101316G.

### Publicación

- Repositorio público creado en `emanuelindustri-source/ruta-nocturna-1999`.
- `main`, workflows y tag `v0.1.0` publicados.
- GitHub Pages configurado para publicar desde GitHub Actions.
- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/

### Estado

- Fase 1.1 completada. Sin mecánicas jugables todavía.
- Siguiente: Fase 1.2, autoloads base, CrashReporter y CreatorQAMenu inicial.
