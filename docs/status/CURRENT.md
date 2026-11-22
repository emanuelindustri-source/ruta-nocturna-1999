# Estado actual

**Subfase:** 1.4 — CI, Android/ADB, export y rebanada vertical  
**Versión:** `v0.1.3`  
**Modelo de la subfase:** DS-S  
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
| Localización | 11 idiomas, 62 claves, 0 errores; fuentes CJK pendientes de F8.4 |
| Roadmap | 4/45 subfases completadas (8,9%), JSON sincronizado |
| Presets de export | Windows Desktop x86_64 y Android arm64-v8a válidos, 0 advertencias |
| Export Windows | `.exe` + `.pck` generados; arranque headless con 11/11 servicios y 11 locales |
| Export Android | APK debug firmada con keystore local, 28,5 MB |
| Android/ADB | Instalación, arranque, 15 s de logcat, captura y PSS 376,5 MB (presupuesto 1.228,8 MB) |
| Rebanada vertical en Android | Captura real en `build/logs/android-smoke/vertical-slice.png`; navegación por teclado hasta el botón |
| Godot import headless | exit 0; sin marcadores críticos |
| Smoke test | 138/138 comprobaciones, exit 0 |
| Dispositivo ADB | Redmi 22101316G autorizado (`obojropz89mbwgpn`) |
| Espacio libre | 78 GB en `C:` |
| Referencias | 94 archivos, escaneo rápido sin cambios |
| Health check | 15 OK, 3 advertencias esperadas, 0 errores |

Advertencias conocidas:

- 202 claves de contenido aún no están en el CSV de localización. Se completarán
  en F8.4; la UI base ya está cubierta.
- Las fuentes CJK/cirílicas se empaquetan y validan visualmente en F8.4.
- Las cotas del bloqueo del Esteem (`data/vehicle/blockout_spec.json`) siguen
  siendo valores provisionales; verificación obligatoria antes de Fase 2/Fase 5.
- La rebanada vertical no es una prueba de rendimiento de gameplay: solo valida
  arranque, memoria base y que el greybox se ve sobre la carretera.
- La APK es una build debug de referencia, no una build de tienda ni una release
  firmada para distribución.
- MIUI/HyperOS exige el permiso "Instalar vía USB" para el paquete; sin él,
  `adb install` devuelve `INSTALL_FAILED_USER_RESTRICTED`.

## Completado

- Rebanada vertical estática: coche gris, carretera gris, terreno, marcas de
  carril, cámara, niebla y panel informativo; sin física ni conducción.
- Botón localizado en Boot para abrir la rebanada y botón de retorno; tres claves
  nuevas en los once locales.
- `export_presets.cfg` con Windows Desktop y Android, inclusión del CSV de
  localización y exclusión de tests/tools/docs.
- `tools/dev/export.ps1` + `.cmd` con importación previa, verificación de tamaño,
  log y manifiesto SHA-256.
- `tools/test_android_adb.ps1` con dispositivo autorizado, instalación `-r`,
  marcador `BOOT_READY`, logcat, captura, PSS y resumen JSON.
- `tools/validate_export.py` y cuatro chequeos nuevos en `health_check.py`.
- Workflow de CI con validación de presets y trabajo Godot headless (import +
  smoke test + detección de errores de script).
- `LocalizationManager` corregido para cargar `.translation` importados en builds
  exportadas; el CSV sigue siendo la fuente de verdad.
- Documentación `docs/architecture/BUILD_AND_RELEASE.md` y actualizaciones de
  arquitectura, contratos, QA y registro de referencias.
- Web de Pages actualizada con la bitácora de 1.2/1.3 y el siguiente gate 2.1.

## Siguiente

Fase **2.1 con DS-R**: motor, caja automática P-R-N-D-2-L, O/D, frenos,
combustible, térmica, electroventilador y tests. No se inicia en este chat.
