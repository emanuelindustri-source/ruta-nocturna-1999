# Handoff — Fase 1.3

## Estado de partida

La Fase 1.2 quedó completada, validada y publicada.

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Versión: `v0.1.1`
- Los once autoloads base importan y arrancan en Godot 4.7.2 headless.
- El smoke test de 87 comprobaciones pasa.
- No hay coche jugable todavía; el bloqueo del Esteem empieza en la Fase 1.3.

## Prompt para el siguiente chat

```text
[RN1999 · Subfase 1.3]
CWD: C:\Dev\RutaNocturna1999
Modelo asignado: MiMo Pro (opencode-go/mimo-v2.6-pro)

Lee completos:
- AGENTS.md
- ROADMAP.md
- docs/status/CURRENT.md
- docs/status/HANDOFF.md
- docs/architecture/SYSTEM_ARCHITECTURE.md
- docs/architecture/DATA_CONTRACTS.md
- docs/reference/ESTEEM_MECHANICAL_NOTES.md

Ejecuta únicamente la Subfase 1.3 (tag v0.1.2):
fábrica Blender headless, manifiestos reproducibles, bloqueo del Esteem,
LOD0/LOD1/LOD2 y ancla de rig. Sin mecánicas de conducción.

Al iniciar:
  python tools/health_check.py --start
  python tools/scan_reference_library.py --quick

Revisa las referencias del vehículo relevantes para esta subfase y registra su
uso. No copies archivos de C:\Dev\fotos de ejemplo al repositorio.

Al cerrar:
- valida esquemas, localización y roadmap
- importa el proyecto en Godot headless
- ejecuta tools/dev/smoke_test.cmd
- ejecuta health_check --end
- actualiza ROADMAP.md y docs/roadmap-data.json
- actualiza CHANGELOG.md, CURRENT.md y este HANDOFF
- haz commit, tag y push solo si todo pasa
- entrega el prompt del siguiente /new

No avances a la Fase 1.4.
```

## Recordatorios

- La biblioteca de referencias externa sigue fuera del repositorio.
- La ExecutionPolicy de PowerShell está restringida: usar wrappers `.cmd`.
- Todos los modelos 3D deben salir de scripts `bpy` reproducibles y manifiesto.
- Ningún modelo entra sin LOD0/LOD1/LOD2.
- El smoke test actual cubre servicios base; no sustituye la revisión visual del
  modelo del Esteem.
- No se sube ningún token, keystore, APK o AAB.
- El APK todavía no tiene pipeline de export; se construye en la Fase 1.4.

## Seguridad

El inicio de sesión usado para publicar debe rotarse o revocarse después de la
publicación si el token fue compartido por un canal no seguro. La configuración
local de Git no contiene el token.
