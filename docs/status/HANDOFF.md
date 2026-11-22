# Handoff — Fase 1.2

## Estado de partida

La Fase 1.1 quedó completada, validada y publicada.

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Versión: `v0.1.0`
- La base local importa y arranca en Godot 4.7.2 headless.
- No hay todavía coche jugable; eso empieza en la Fase 1.2/2.1.

## Prompt para el siguiente chat

```text
[RN1999 · Subfase 1.2]
CWD: C:\Dev\RutaNocturna1999
Modelo asignado: DS-R (opencode-go/deepseek-v4.1-flash#max)

Lee completos:
- AGENTS.md
- ROADMAP.md
- docs/status/CURRENT.md
- docs/status/HANDOFF.md
- docs/architecture/SYSTEM_ARCHITECTURE.md
- docs/architecture/STATE_MACHINES.md

Ejecuta únicamente la Subfase 1.2 (tag v0.1.1):
EventBus, autoloads base, CrashReporter, CreatorQAMenu inicial y smoke test
sin mecánicas de conducción.

Al iniciar:
  python tools/health_check.py --start
  python tools/scan_reference_library.py --quick

Revisa solo las referencias relevantes para esta subfase y registra su uso.
No copies archivos de C:\Dev\fotos de ejemplo al repositorio.
No avances a la Fase 1.3.

Al cerrar:
- valida esquemas, localización y roadmap
- importa el proyecto en Godot headless
- ejecuta health_check --end
- actualiza ROADMAP.md y docs/roadmap-data.json
- actualiza CHANGELOG.md, CURRENT.md y este HANDOFF
- haz commit, tag y push solo si todo pasa
- entrega el prompt del siguiente /new
```

## Recordatorios

- La biblioteca de referencias externa sigue fuera del repositorio.
- La ExecutionPolicy de PowerShell está restringida: usar wrappers `.cmd`.
- El health check detecta schemas, autoloads y localización.
- La UI web debe regenerarse con `tools/release/sync_roadmap.py` cuando cambie el ROADMAP.
- No se sube ningún token, keystore, APK o AAB.
- El APK todavía no tiene pipeline de export; se construye en la Fase 1.4.
- Android 36 se instalará en la fase Android/Play correspondiente.

## Seguridad

El inicio de sesión usado para publicar debe rotarse o revocarse después de la
publicación si el token fue compartido por un canal no seguro. La configuración
local de Git no contiene el token.
