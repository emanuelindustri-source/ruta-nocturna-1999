# Estado actual

**Subfase:** 1.1 — Fundación técnica, contratos y web base  
**Versión:** `v0.1.0`  
**Modelo de la subfase:** DS-S  
**Fecha:** 2026-11-22  
**Estado:** validación local superada; publicación remota pendiente de autenticación.

## Validación ejecutada

| Prueba | Resultado |
|---|---|
| Contratos JSON + Schemas | 5 contratos válidos, 0 errores |
| Referencias cruzadas del vehículo | Herramientas e items válidos |
| Autoloads | Grafo acíclico y 11 servicios obligatorios |
| Folclore | 7 entidades obligatorias presentes |
| Diálogos | Nodos, elecciones y finales sin referencias rotas |
| Localización | 11 idiomas, 0 errores |
| Roadmap | 10 fases, 45 subfases, JSON sincronizado |
| Godot import headless | exit 0, sin errores de escena |
| Boot headless | exit 0, imprime versión y repo |
| Web | 10 tarjetas de fase, 45 subfases, sin errores de consola |
| Lighthouse | Accesibilidad 100, Best Practices 100, SEO 100 |
| Bootstrap | 0 fallos críticos, 2 advertencias esperadas (auth GitHub, Android 36) |
| Health check | 0 errores |
| Limpieza | Dry run correcto, 4.01 MB recuperables en artefactos |
| ADB | Redmi 22101316G conectado y autorizado |
| Referencias | 94 archivos, 2 duplicados exactos, textos extraídos |

Advertencias conocidas:

- 202 claves de contenido aún no están en el CSV de localización. Se completarán
  en F8.4; la UI base ya está cubierta.
- Las fuentes CJK/cirílicas se empaquetan y validan visualmente en F8.4.
- Android 36 no está instalado; requisito de Play a partir de agosto de 2026.
- La sesión de `gh` no está iniciada.

## Completado

- Estructura del proyecto y repositorio Git local.
- `AGENTS.md`, `ROADMAP.md`, licencias y créditos.
- Cinco contratos canónicos y JSON Schemas.
- Arquitectura de autoloads, máquinas de estados, datos y QA.
- Web de GitHub Pages y roadmap interactivo sincronizado.
- Localización base para 11 idiomas.
- Validador de esquemas, validador de localización, sincronizador de roadmap,
  health check, bootstrap, wrapper de Godot y limpieza segura.
- Catálogo de 94 referencias externas, hojas de contacto y extracción de textos.
- Corrección del flag RUNASADMIN de Godot.
- Generación de `C:\Android\debug.keystore`.
- Primer commit local: `223d4f2`.

## Bloqueo para cerrar la subfase

La creación del repositorio remoto, el push del tag y la activación de GitHub
Pages requieren que Khristyan autorice una vez la cuenta con:

```powershell
gh auth login
```

Después se ejecuta:

```powershell
.\tools\release\publish_github.cmd
```

No se guardan tokens ni contraseñas en el repositorio.

## Siguiente después del cierre remoto

Fase **1.2 con DS-R**: EventBus, autoloads base, CrashReporter, CreatorQAMenu
inicial, pruebas de error y smoke test del boot.
