# Changelog

Todas las fechas usan ISO 8601. Las versiones siguen SemVer.

## [Unreleased]

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
