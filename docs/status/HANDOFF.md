# Handoff — Fase 2.4

## Estado de partida

La Fase 2.3 quedó completada, validada y publicada. La cabina del Esteem ya se
puede manipular con retículo/tacto, mano IK y controles contextuales; la palanca
P-R-N-D-2-L y el Overdrive se delegan en el tren motriz de F2.1 y el freno de mano
termina en `brakes.parking`.

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Versión: `v0.2.2`
- Contrato de interacción: `data/schemas/cabin_interaction.json`.
- Escena: `scenes/vehicle/CabinInteraction.tscn` (acceso `Ver cabina` en Boot).
- Controlador: `src/vehicle/cabin_interaction_controller.gd`.
- Estado de mandos: `src/vehicle/cabin_controls.gd`.
- IK: `src/vehicle/hand_ik_driver.gd`.
- Radio: `src/vehicle/radio_unit.gd`.
- Proxies visuales: `src/vehicle/cabin_visual_proxies.gd`.
- Pruebas: `tests/vehicle/InteractionTest.tscn` (180 comprobaciones) y
  `tools/dev/interaction_test.cmd`.
- Tren motriz de 2.1 intacto: `data/schemas/vehicle_powertrain.json`,
  `src/vehicle/`, `tests/vehicle/PowertrainTest.tscn` (125 comprobaciones).
- Cabina de 2.2 intacta: `data/vehicle/cabin_spec.json`, `EsteemCabin.tscn`,
  `tests/vehicle/CabinTest.tscn` (46 comprobaciones).
- Smoke test: 155/155; health check de cierre 18 OK, 3 advertencias, 0 errores.

## Qué debe hacer F2.4

Alcance exclusivo de **MiMo Flash**:

1. Espejos retrovisores con `SubViewport` (interior y laterales según el alcance
   que fije el roadmap), dentro del presupuesto de triángulos y con el conteo
   móvil de F2.4/F3.5.
2. HUD mínimo (velocidad, marcha, combustible/avisos) alimentado por
   `VehiclePowertrain`; sin duplicar lógica ni crear una UI de 25 botones.
3. Gamepad y D-Pad para navegar menús y, si corresponde, para la cámara de
   cabina. No romper el retículo/tacto de F2.3.
4. Guardado base `save_version` de `v0.2.0`: snapshot real, escritura atómica,
   checksum y backup; sin migraciones encadenadas completas (F9.4).
5. QA de reparaciones y prueba ADB en el Redmi; build de referencia si el
   alcance lo exige.

Reglas:

- No rehacer la interacción de F2.3 ni duplicar la palanca, el Overdrive o los
  frenos fuera de `vehicle_powertrain.json`.
- Los `visual_offsets` y los proxies de F2.3 son provisionales; si F2.4 cambia
  la cámara o el HUD, mantener las claves de localización y las pruebas.
- No introducir física de conducción nueva sin contrato; el chasis real sigue
  siendo F3.
- No avanzar a la Fase 3.

Antes de implementar, revisar solo las referencias del catálogo relevantes para
espejos, HUD, gamepad y guardado, y registrar su uso en
`docs/reference/REFERENCE_USAGE_LOG.md`. No se cargan las 40 imágenes en
contexto ni se copian archivos de `C:\Dev\fotos de ejemplo` al repositorio.

## Prompt para el siguiente chat

```text
[RN1999 · Subfase 2.4]
CWD: C:\Dev\RutaNocturna1999
Modelo asignado: MiMo Flash (opencode-go/mimo-v2.6-flash)

Lee completos:
- AGENTS.md
- ROADMAP.md
- docs/status/CURRENT.md
- docs/status/HANDOFF.md
- docs/architecture/SYSTEM_ARCHITECTURE.md
- docs/architecture/DATA_CONTRACTS.md
- docs/architecture/STATE_MACHINES.md
- docs/architecture/ASSET_FACTORY.md
- docs/architecture/QA_AND_RECOVERY.md
- data/schemas/vehicle_powertrain.json
- data/schemas/cabin_interaction.json
- data/vehicle/cabin_spec.json
- data/vehicle/blockout_spec.json

Ejecuta únicamente la Subfase 2.4 (tag v0.2.3): espejos SubViewport, HUD mínimo,
gamepad/D-Pad, save v0.2.0, QA de reparaciones y ADB. No avances a la Fase 3.

La interacción de F2.3 ya existe en scenes/vehicle/CabinInteraction.tscn:
retículo/tacto, IK 2/1/0 manos, puertas/seguros, vidrios, luces, antena, radio,
guantera, palanca P-R-N-D-2-L con Overdrive y freno de mano. No la rehagas ni
dupliques el tren motriz; la palanca usa VehiclePowertrain.set_selector(), el
Overdrive usa toggle_overdrive() y el freno de mano termina en brakes.parking.

Antes de implementar, revisa solo las referencias del catálogo relevantes para
esta subfase y registra su uso en docs/reference/REFERENCE_USAGE_LOG.md. No
cargues las 40 imágenes en contexto ni copies archivos de C:\Dev\fotos de ejemplo
al repositorio.

Al iniciar:
  python tools/health_check.py --start
  python tools/scan_reference_library.py --quick

Al cerrar:
- valida esquemas, localización, roadmap y presets de export
- importa el proyecto en Godot headless
- ejecuta tools/dev/smoke_test.cmd, tools/dev/powertrain_test.cmd,
  tools/dev/cabin_test.cmd y tools/dev/interaction_test.cmd
- comprueba espacio en disco y dispositivo ADB autorizado
- ejecuta health_check --end
- actualiza ROADMAP.md, docs/roadmap-data.json, CHANGELOG.md, CURRENT.md y HANDOFF
- haz commit, tag v0.2.3 y push solo si todo pasa
- entrega el prompt del siguiente /new

No avances a la Fase 3.
```

## Recordatorios

- La biblioteca de referencias externa sigue fuera del repositorio.
- La ExecutionPolicy de PowerShell está restringida: usar wrappers `.cmd`.
- El export se hace con `tools\dev\export.cmd`; los binarios van a `build/` y
  nunca a Git.
- Ningún modelo entra sin LOD0/LOD1/LOD2. Los espejos cuentan en el presupuesto
  de triángulos móvil.
- El smoke test (155), el test del tren motriz (125), el test de la cabina (46) y
  el test de interacción (180) deben seguir pasando; no se relajan para acomodar
  F2.4.
- Al cambiar `EXPECTED_VERSION` del smoke test, actualizar también `VERSION`,
  `project.godot` y `export_presets.cfg` (`version/name` y `version/code`).
- No se sube ningún token, keystore, APK o AAB a Git.
- Los proxies y offsets de F2.3 son funcionales y provisionales; el arte final de
  cabina/manos es F3.2.

## Seguridad

El inicio de sesión usado para publicar debe rotarse o revocarse después de la
publicación si el token fue compartido por un canal no seguro. La configuración
local de Git no contiene el token.
