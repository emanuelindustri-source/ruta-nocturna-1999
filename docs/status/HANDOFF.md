# Handoff — Fase 1.4

## Estado de partida

La Fase 1.3 quedó completada, validada y publicada.

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Versión: `v0.1.2`
- La fábrica Blender headless genera el bloqueo del Esteem de forma reproducible:
  LOD0 1.192 triángulos, LOD1 440, LOD2 184 (presupuestos 8.000/4.000/1.500).
- El ancla de rig importa en Godot como `Skeleton3D` con 17 huesos `anchor_*`.
- `tools/validate_assets.py` vigila manifiestos, hashes y política de LOD dentro
  de `health_check.py`.
- El smoke test pasa con 118/118 comprobaciones.
- No hay conducción ni física todavía: el bloqueo es geometría estática con
  cotas provisionales verificables en `data/vehicle/blockout_spec.json`.

## Prompt para el siguiente chat

```text
[RN1999 · Subfase 1.4]
CWD: C:\Dev\RutaNocturna1999
Modelo asignado: DS-S (opencode-go/deepseek-v4.1-flash#low)

Lee completos:
- AGENTS.md
- ROADMAP.md
- docs/status/CURRENT.md
- docs/status/HANDOFF.md
- docs/architecture/SYSTEM_ARCHITECTURE.md
- docs/architecture/DATA_CONTRACTS.md
- docs/architecture/QA_AND_RECOVERY.md

Ejecuta únicamente la Subfase 1.4 (tag v0.1.3):
CI (GitHub Actions), test Android/ADB, export Windows/APK, health check completo,
Pages y tag de vertical slice. Sin mecánicas de conducción.

Al iniciar:
  python tools/health_check.py --start
  python tools/scan_reference_library.py --quick

Revisa solo las referencias del catálogo relevantes para esta subfase y registra
su uso. No copies archivos de C:\Dev\fotos de ejemplo al repositorio.

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

No avances a la Fase 2.1.
```

## Recordatorios

- La biblioteca de referencias externa sigue fuera del repositorio.
- La ExecutionPolicy de PowerShell está restringida: usar wrappers `.cmd`.
- Todo modelo 3D sale de scripts `bpy` reproducibles con manifiesto; la fábrica
  está documentada en `docs/architecture/ASSET_FACTORY.md`.
- Ningún modelo entra sin LOD0/LOD1/LOD2; el validador falla si un manifiesto
  queda obsoleto (regenerar con `tools\blender\build_assets.cmd`).
- Las cotas del bloqueo son provisionales: verificar antes de Fase 2/Fase 5.
- El smoke test cubre servicios base y el bloqueo; no sustituye la revisión
  visual del Esteem ni las pruebas de dispositivo.
- No se sube ningún token, keystore, APK o AAB a Git; los binarios van a Releases.
- El export debe incluir `localization/strings.csv` (pendiente desde F1.2).
- `tools/test_android_adb.ps1` es obligatorio para el hito Android de la 1.4.

## Seguridad

El inicio de sesión usado para publicar debe rotarse o revocarse después de la
publicación si el token fue compartido por un canal no seguro. La configuración
local de Git no contiene el token.
