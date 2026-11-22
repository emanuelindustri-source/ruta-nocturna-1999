# Handoff — Fase 2.1

## Estado de partida

La Fase 1.4 quedó completada, validada y publicada. La Fase 1 está cerrada.

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Versión: `v0.1.3`
- Rebanada vertical: Boot abre `VerticalSlice.tscn` con el bloqueo gris del Esteem
  sobre una carretera gris, sin física ni conducción.
- Export: `build/exports/windows/RutaNocturna1999.exe` y
  `build/exports/android/RutaNocturna1999.apk` (debug, no versionados).
- Android: APK instalada y arrancada por ADB; logs, captura y PSS en
  `build/logs/android-smoke/`.
- Smoke test: 138/138 comprobaciones; health check de cierre sin errores.
- La localización exportada carga los `.translation` importados; el CSV sigue
  siendo la fuente de verdad.

## Prompt para el siguiente chat

```text
[RN1999 · Subfase 2.1]
CWD: C:\Dev\RutaNocturna1999
Modelo asignado: DS-R (opencode-go/deepseek-v4.1-flash#max)

Lee completos:
- AGENTS.md
- ROADMAP.md
- docs/status/CURRENT.md
- docs/status/HANDOFF.md
- docs/architecture/SYSTEM_ARCHITECTURE.md
- docs/architecture/DATA_CONTRACTS.md
- docs/architecture/STATE_MACHINES.md
- docs/architecture/QA_AND_RECOVERY.md
- data/schemas/vehicle_components.json

Ejecuta únicamente la Subfase 2.1 (tag v0.2.0):
motor, caja automática P-R-N-D-2-L, O/D, frenos, combustible, térmica,
electroventilador y tests. Sin cabina, IK, espejos ni conducción narrativa.

Al iniciar:
  python tools/health_check.py --start
  python tools/scan_reference_library.py --quick

Revisa solo las referencias del catálogo relevantes para la mecánica del Esteem y
registra su uso. No copies archivos de C:\Dev\fotos de ejemplo al repositorio.
No inventes cotas ni valores: usa el manual y marca lo provisional.

Al cerrar:
- valida esquemas, localización y roadmap
- importa el proyecto en Godot headless
- ejecuta tools/dev/smoke_test.cmd
- comprueba espacio en disco y dispositivo ADB autorizado
- ejecuta health_check --end
- actualiza ROADMAP.md y docs/roadmap-data.json
- actualiza CHANGELOG.md, CURRENT.md y este HANDOFF
- haz commit, tag y push solo si todo pasa
- entrega el prompt del siguiente /new

No avances a la Fase 2.2.
```

## Recordatorios

- La biblioteca de referencias externa sigue fuera del repositorio.
- La ExecutionPolicy de PowerShell está restringida: usar wrappers `.cmd`.
- El export se hace con `tools\dev\export.cmd`; los binarios van a `build/` y
  nunca a Git.
- Todo modelo 3D sale de scripts `bpy` reproducibles con manifiesto.
- Ningún modelo entra sin LOD0/LOD1/LOD2.
- El smoke test cubre servicios, bloqueo, rebanada vertical y presets; no
  sustituye la revisión visual ni las pruebas de dispositivo.
- La APK de referencia es debug y usa el keystore local; no es una build de tienda.
- Las cotas del bloqueo son provisionales: verificar antes de Fase 2/Fase 5.
- No se sube ningún token, keystore, APK o AAB a Git.

## Seguridad

El inicio de sesión usado para publicar debe rotarse o revocarse después de la
publicación si el token fue compartido por un canal no seguro. La configuración
local de Git no contiene el token.
