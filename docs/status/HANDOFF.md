# Handoff — después de Fase 1.1

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
No copies archivos externos al repositorio.
Respeta el protocolo de contexto: no avances a la Fase 1.3.

Al cerrar:
- valida esquemas, localización y roadmap
- importa el proyecto en Godot headless
- ejecuta health_check --end
- actualiza ROADMAP.md y docs/roadmap-data.json
- actualiza CHANGELOG.md, CURRENT.md y este HANDOFF
- haz commit y tag solo si todo pasa
- entrega el prompt del siguiente /new
```

## Notas para la siguiente sesión

- Godot headless ya funciona.
- El debug keystore existe en `C:\Android\debug.keystore`.
- `gh` está instalado, pero sin autenticación.
- El repositorio remoto aún no ha sido creado.
- El catálogo de referencias tiene 94 archivos y crecerá; revisar `--quick`.
- La web carga datos desde `docs/roadmap-data.json`; hay que mantenerla sincronizada.
- Fase 1.2 no debe implementar física de vehículo ni arte final.

## Bloqueo pendiente del director

Para completar la publicación de Fase 1.1, Khristyan debe iniciar sesión una vez:

```powershell
gh auth login
```

Después se podrá crear el repositorio
`emanuelindustri-source/ruta-nocturna-1999`, hacer el primer push y activar Pages.
