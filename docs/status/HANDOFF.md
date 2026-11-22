# Handoff — cierre de Fase 1.1

## Estado

La Fase 1.1 está implementada y validada en local. No se ha creado tag ni se ha
declarado completada porque el repositorio remoto y GitHub Pages aún no existen.

El bloqueo no es técnico: **falta autorizar `gh`**.

## Acción inmediata del director

Ejecutar una vez en una terminal:

```powershell
gh auth login
```

Después, en este mismo chat o en uno nuevo:

```text
[RN1999 · cierre remoto F1.1]
CWD: C:\Dev\RutaNocturna1999
Lee AGENTS.md, ROADMAP.md y docs/status/CURRENT.md.
La autenticación de gh ya está hecha.
Ejecuta .\tools\release\publish_github.cmd en modo seguro, crea el repositorio
público emanuelindustri-source/ruta-nocturna-1999, sube main y tags, y activa
GitHub Pages con GitHub Actions.
No avances a F1.2 ni modifiques el diseño del juego.
```

Si la autenticación se completa mientras este chat sigue abierto, el agente puede
hacer el cierre remoto sin abrir otro chat.

## Después del cierre remoto

- Verificar el workflow de Pages.
- Marcar 1.1 como completada en `ROADMAP.md`.
- Regenerar `docs/roadmap-data.json`.
- Crear y subir el tag `v0.1.0`.
- Abrir `/new` para la Fase 1.2 con **DS-R**.
- El nuevo chat debe leer `AGENTS.md`, el ROADMAP, el estado actual y el handoff.

## Prompt para Fase 1.2 (solo después de publicar F1.1)

```text
[RN1999 · Subfase 1.2]
CWD: C:\Dev\RutaNocturna1999
Modelo asignado: DS-R (opencode-go/deepseek-v4.1-flash#max)

Lee completos AGENTS.md, ROADMAP.md, docs/status/CURRENT.md,
docs/status/HANDOFF.md, SYSTEM_ARCHITECTURE.md y STATE_MACHINES.md.
Ejecuta únicamente la Subfase 1.2 (tag v0.1.1):
EventBus, autoloads base, CrashReporter, CreatorQAMenu inicial y smoke test
sin mecánicas de conducción.

Al iniciar ejecuta health_check --start y scan_reference_library --quick.
No copies referencias externas al repositorio.
No avances a la Fase 1.3.
Al cerrar valida, actualiza roadmap/estado y entrega el prompt del siguiente /new.
```

## Evidencia local

- Commit: `223d4f2`.
- Godot 4.7.2 headless: import y boot correctos.
- Web: Lighthouse 100/100/100 en accesibilidad, buenas prácticas y SEO.
- 94 referencias catalogadas.
- `gh` instalado, sin sesión.
- Redmi conectado por ADB.
