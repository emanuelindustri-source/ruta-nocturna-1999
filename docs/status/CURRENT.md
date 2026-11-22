# Estado actual

**Subfase:** 1.2 — Autoloads base, CrashReporter y CreatorQAMenu inicial  
**Versión:** `v0.1.1`  
**Modelo de la subfase:** DS-R  
**Fecha:** 2026-11-22  
**Estado:** completada y publicada.

## Enlaces

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Acciones: https://github.com/emanuelindustri-source/ruta-nocturna-1999/actions

## Validación ejecutada

| Prueba | Resultado |
|---|---|
| Contratos JSON + Schemas | 5 contratos válidos, 0 errores, 1 advertencia de claves de contenido |
| Referencias cruzadas | Herramientas, items, entidades y diálogos válidos |
| Autoloads | 11 declarados en `project.godot`, orden topológico verificado |
| Localización | 11 idiomas, 59 claves, 0 errores; fuentes CJK pendientes de F8.4 |
| Roadmap | 2/45 subfases completadas (4.4%), JSON sincronizado |
| Godot import headless | exit 0, sin errores de parseo ni escenas |
| Boot headless | exit 0, 11/11 servicios activos, versión 0.1.1 |
| Smoke test | 87/87 comprobaciones, exit 0 |
| Caja negra | Reporte local y marcador de sesión verificados |
| Captura de error GDScript | Un warning no genera reporte; un error sí |
| Cierre anormal previo | Marcador simulado; reporte emitido al arrancar |
| Panel QA | Apertura/cierre y once servicios verificados en debug |
| Referencias | 94 archivos, escaneo rápido sin cambios |
| Health check | 10 OK, 3 advertencias esperadas, 0 errores |

Advertencias conocidas:

- 202 claves de contenido aún no están en el CSV de localización. Se completarán
  en F8.4; la UI base ya está cubierta.
- Las fuentes CJK/cirílicas se empaquetan y validan visualmente en F8.4.
- El preset de export de la Fase 1.4 debe incluir `localization/strings.csv`;
  todavía no existe pipeline de export.
- No se probó un cierre nativo real: no hay APK todavía. La prueba Android/ADB
  corresponde a la Fase 1.4.

## Completado

- `EventBus` con señales tipadas para ciclo de vida, ajustes, guardado, estado,
  clima, audio, actualizaciones, diagnóstico y QA.
- Once autoloads base en orden topológico: EventBus, HardwareProfiler,
  SettingsManager, LocalizationManager, GameState, SaveManager, AudioDirector,
  WeatherManager, UpdateChecker, CrashReporter y SceneRouter.
- `CrashReporter` con logger nativo, búfer de 200 líneas, contexto por servicios,
  reporte local en `user://ultimo_reporte_error.txt` y marcador de sesión para
  cierres anormales.
- `SaveManager` base con snapshot versionado, checksum canónico, escritura
  atómica, backup y rechazo de versiones futuras.
- `CreatorQAMenu` inicial con F12, cinco toques, estado, clima, modo de prueba,
  reporte y copia al portapapeles. Oculto en tienda salvo bandera explícita.
- Boot de Fase 1.2 con verificación de servicios y aviso de cierre anormal previo.
- Smoke test reproducible y wrapper `tools/dev/smoke_test.cmd`.
- `health_check.py` valida autoloads y ejecuta el smoke test.

## Siguiente

Fase **1.3 con MiMo Pro**: fábrica Blender headless, manifiestos reproducibles,
bloqueo del Esteem, LOD0/1/2 y ancla de rig. Sin conducción todavía.
