# Handoff — Fase 2.3

## Estado de partida

La Fase 2.2 quedó completada, validada y publicada. La cabina funcional del
Esteem existe como bloqueo (greybox) generado por `bpy`, con volante de tres
radios, palanca P-R-N-D-2-L con botón de Overdrive, freno de mano, radio cassette
doble DIN, guantera, paneles de puerta y consola, además del rig de manos con
poses IK compatibles con las anclas `anchor_*` del bloqueo.

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Versión: `v0.2.1`
- Contrato de la cabina: `data/vehicle/cabin_spec.json`.
- Generador: `tools/blender/esteem_cabin.py` (target `vehicle.esteem.cabin`).
- Assets: `assets/generated/vehicle/esteem_cabin_lod0/1/2.glb` y
  `esteem_hand_rig.glb`; manifiesto `assets/manifests/esteem_cabin.manifest.json`.
- Escena: `scenes/vehicle/EsteemCabin.tscn`.
- Pruebas: `tests/vehicle/CabinTest.tscn` (46 comprobaciones) y
  `tools/dev/cabin_test.cmd`.
- Tren motriz de 2.1 intacto: `data/schemas/vehicle_powertrain.json`,
  `src/vehicle/`, `tests/vehicle/PowertrainTest.tscn` (125 comprobaciones).
- Smoke test: 155/155; health check de cierre sin errores.

## Qué debe hacer F2.3

Alcance exclusivo de **DS-R** (interacción e IK):

1. Interacción contextual "mirar/tocar" con retículo/tacto y mano IK sobre los
   controles ya modelados (volante, palanca, freno de mano, radio, guantera).
2. IK de 2/1/0 manos: poses y transiciones de las manos hacia los controles.
3. Puertas y seguros, vidrios (subir/bajar), luces, antena y radio (funcionamiento,
   no solo geometría).
4. Conectar la manipulación de la palanca con los estados reales de
   `vehicle_powertrain.json` (P-R-N-D-2-L y Overdrive) y el freno de mano con
   `brakes.parking`, sin duplicar mecánicas fuera de contrato.
5. Todo sigue saliendo de scripts `bpy`/código reproducible, respetando anclas y
   presupuestos; sin romper los tests de 2.1/2.2.
6. No se implementan espejos, HUD, gamepad ni guardado: son F2.4. No se avanza a
   F2.4 ni a la Fase 3.

Antes de implementar interacción, revisar solo las referencias del catálogo
relevantes y registrar su uso en `docs/reference/REFERENCE_USAGE_LOG.md`. No se
cargan las 40 imágenes en contexto ni se copian archivos de
`C:\Dev\fotos de ejemplo` al repositorio.

## Prompt para el siguiente chat

```text
[RN1999 · Subfase 2.3]
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
- docs/architecture/ASSET_FACTORY.md
- data/schemas/vehicle_powertrain.json
- data/vehicle/cabin_spec.json
- data/vehicle/blockout_spec.json

Ejecuta únicamente la Subfase 2.3 (tag v0.2.2): interacción contextual
"mirar/tocar" con retículo/tacto y mano IK, IK de 2/1/0 manos, puertas y
seguros, vidrios, luces, antena y radio. Sin espejos, HUD, gamepad ni guardado
(F2.4). No avances a la Fase 2.4 ni a la Fase 3.

Conecta la manipulación de la palanca P-R-N-D-2-L y el Overdrive con los estados
de vehicle_powertrain.json y el freno de mano con brakes.parking. No dupliques
mecánicas fuera de contrato ni introduzcas física de conducción nueva: el tren
motriz sigue siendo longitudinal y la cabina es un bloqueo funcional.

Antes de implementar, revisa solo las referencias del catálogo relevantes para
esta subfase y registra su uso en docs/reference/REFERENCE_USAGE_LOG.md. No
cargues las 40 imágenes en contexto ni copies archivos de C:\Dev\fotos de ejemplo
al repositorio.

Al iniciar:
  python tools/health_check.py --start
  python tools/scan_reference_library.py --quick

Al cerrar:
- valida esquemas, localización y roadmap
- importa el proyecto en Godot headless
- ejecuta tools/dev/smoke_test.cmd, tools/dev/powertrain_test.cmd y
  tools/dev/cabin_test.cmd
- comprueba espacio en disco y dispositivo ADB autorizado
- ejecuta health_check --end
- actualiza ROADMAP.md, docs/roadmap-data.json, CHANGELOG.md, CURRENT.md y HANDOFF
- haz commit, tag v0.2.2 y push solo si todo pasa
- entrega el prompt del siguiente /new

No avances a la Fase 2.4.
```

## Recordatorios

- La biblioteca de referencias externa sigue fuera del repositorio.
- La ExecutionPolicy de PowerShell está restringida: usar wrappers `.cmd`.
- El export se hace con `tools\dev\export.cmd`; los binarios van a `build/` y
  nunca a Git.
- Ningún modelo entra sin LOD0/LOD1/LOD2; el rig de manos se rige por el contrato
  `rig_anchor` (mismo patrón que el bloqueo).
- El tren motriz de 2.1 y la cabina de 2.2 no crean `VehicleBody3D`; la interacción
  de 2.3 tampoco debe introducir física de conducción por su cuenta.
- El smoke test (155), el test del tren motriz (125) y el test de la cabina (46)
  deben seguir pasando; no se relajan para acomodar la interacción.
- Las cotas de interior, las del bloqueo y los valores de simulación siguen siendo
  provisionales. Al cambiar `EXPECTED_VERSION` del smoke test, actualizar también
  `VERSION`, `project.godot` y `export_presets.cfg` (`version/name` y
  `version/code`).
- No se sube ningún token, keystore, APK o AAB a Git.

## Seguridad

El inicio de sesión usado para publicar debe rotarse o revocarse después de la
publicación si el token fue compartido por un canal no seguro. La configuración
local de Git no contiene el token.
