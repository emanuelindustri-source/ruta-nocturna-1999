# Changelog

Todas las fechas usan ISO 8601. Las versiones siguen SemVer.

## [Unreleased]

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
