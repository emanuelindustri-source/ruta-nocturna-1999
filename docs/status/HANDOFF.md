# Handoff — Fase 2.2

## Estado de partida

La Fase 2.1 quedó completada, validada y publicada. El tren motriz del Esteem ya
existe como simulación data-driven y probada; la cabina, las manos y los espejos
todavía no.

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Versión: `v0.2.0`
- Contrato del tren motriz: `data/schemas/vehicle_powertrain.json`.
- Código: `src/vehicle/` (`engine_model`, `automatic_transmission`, `brake_system`,
  `fuel_system`, `cooling_system`, `vehicle_powertrain`).
- Pruebas: `tests/vehicle/PowertrainTest.tscn` (125 comprobaciones) y
  `tools/dev/powertrain_test.cmd`.
- Smoke test: 155/155 comprobaciones; health check de cierre sin errores.
- Catálogo de referencias: 95 archivos.

## Qué debe hacer F2.2

Alcance exclusivo de **MiMo Pro**:

1. Cabina funcional del Esteem: volante, palanca automática P-R-N-D-2-L con botón
   de Overdrive, freno de mano, radio cassette de doble DIN, guantera, paneles de
   puerta y consola.
2. Rig de manos y poses IK compatibles con el ancla `anchor_*` del bloqueo.
3. Todo modelo sale de scripts `bpy` reproducibles con manifiesto y LOD0/LOD1/LOD2.
4. No se implementan espejos, HUD, gamepad ni guardado: son F2.4.
5. No se implementa conducción narrativa ni interacción contextual completa: la
   interacción “mirar/tocar” y las puertas/seguros son F2.3.
6. No se copian imágenes de `C:\Dev\fotos de ejemplo` al repositorio ni se usan
   como texturas.

Antes de empezar, `AGENTS.md` exige revisión visual completa de las referencias de
interior para F2.2. Debe hacerse con las hojas de contacto y el catálogo, sin
cargar las 40 imágenes en contexto, y registrarse en
`docs/reference/REFERENCE_USAGE_LOG.md`.

## Prompt para el siguiente chat

```text
[RN1999 · Subfase 2.2]
CWD: C:\Dev\RutaNocturna1999
Modelo asignado: MiMo Pro (opencode-go/mimo-v2.6-pro)

Lee completos:
- AGENTS.md
- ROADMAP.md
- docs/status/CURRENT.md
- docs/status/HANDOFF.md
- docs/architecture/SYSTEM_ARCHITECTURE.md
- docs/architecture/ASSET_FACTORY.md
- docs/architecture/DATA_CONTRACTS.md
- docs/architecture/STATE_MACHINES.md
- docs/reference/ESTEEM_MECHANICAL_NOTES.md
- data/vehicle/blockout_spec.json
- data/schemas/vehicle_powertrain.json

Ejecuta únicamente la Subfase 2.2 (tag v0.2.1): cabina funcional, volante,
palanca P-R-N-D-2-L con Overdrive, freno de mano, radio, guantera, paneles,
rig de manos y poses IK. Sin espejos, HUD, gamepad, guardado ni conducción
narrativa.

Antes de modelar, haz la revisión visual completa de las referencias de interior
que exige AGENTS.md para F2.2. Usa el catálogo y las hojas de contacto; no cargues
las 40 imágenes en contexto ni copies archivos de C:\Dev\fotos de ejemplo al
repositorio. Registra el uso en docs/reference/REFERENCE_USAGE_LOG.md.

Todo asset 3D debe salir de scripts bpy reproducibles, con manifiesto, licencia,
hash y LOD0/LOD1/LOD2. Respeta el ancla de rig y los presupuestos de triángulos.
No inventes cotas: usa el manual, las mediciones del modelo o marca provisional.

Al iniciar:
  python tools/health_check.py --start
  python tools/scan_reference_library.py --quick

Al cerrar:
- valida esquemas, localización y roadmap
- importa el proyecto en Godot headless
- ejecuta tools/dev/smoke_test.cmd y tools/dev/powertrain_test.cmd
- comprueba espacio en disco y dispositivo ADB autorizado
- ejecuta health_check --end
- actualiza ROADMAP.md, docs/roadmap-data.json, CHANGELOG.md, CURRENT.md y HANDOFF
- haz commit, tag v0.2.1 y push solo si todo pasa
- entrega el prompt del siguiente /new

No avances a la Fase 2.3.
```

## Recordatorios

- La biblioteca de referencias externa sigue fuera del repositorio.
- La ExecutionPolicy de PowerShell está restringida: usar wrappers `.cmd`.
- El export se hace con `tools\dev\export.cmd`; los binarios van a `build/` y
  nunca a Git.
- Ningún modelo entra sin LOD0/LOD1/LOD2.
- El tren motriz de 2.1 no crea `VehicleBody3D`; la cabina de 2.2 tampoco debe
  introducir física de conducción por su cuenta.
- El smoke test y el test del tren motriz deben seguir pasando; no se relajan
  para acomodar la cabina.
- Las cotas del bloqueo y los valores de simulación siguen siendo provisionales.
- No se sube ningún token, keystore, APK o AAB a Git.

## Seguridad

El inicio de sesión usado para publicar debe rotarse o revocarse después de la
publicación si el token fue compartido por un canal no seguro. La configuración
local de Git no contiene el token.
