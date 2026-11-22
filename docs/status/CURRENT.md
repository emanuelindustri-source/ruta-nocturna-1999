# Estado actual

**Subfase:** 2.2 — Cabina funcional y rig de manos  
**Versión:** `v0.2.1`  
**Modelo de la subfase:** MiMo Pro  
**Fecha:** 2026-11-22  
**Estado:** completada y publicada.

## Enlaces

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Acciones: https://github.com/emanuelindustri-source/ruta-nocturna-1999/actions

## Validación ejecutada

| Prueba | Resultado |
|---|---|
| Contratos JSON + Schemas | 6 contratos válidos, 0 errores, 1 advertencia de claves de contenido |
| Localización | 11 idiomas, 0 errores; fuentes CJK pendientes de F8.4 |
| Roadmap | 6/45 subfases completadas (13,3%), JSON sincronizado |
| Assets generados | 2 manifiestos válidos (bloqueo + cabina), 0 errores |
| Cabina LOD0/LOD1/LOD2 | 1584 / 704 / 480 triángulos, estrictamente decrecientes, dentro de presupuesto |
| Pruebas de la cabina | 46/46 comprobaciones, exit 0 |
| Pruebas del tren motriz | 125/125 comprobaciones, exit 0 |
| Smoke test | 155/155 comprobaciones, exit 0 |
| Godot import headless | exit 0; sin marcadores críticos |
| Health check de cierre | 17 OK, 3 advertencias esperadas, 0 errores |
| Dispositivo ADB | Redmi 22101316G autorizado (`obojropz89mbwgpn`) |
| Espacio libre | 79,86 GB en `C:` |
| Referencias | 95 archivos; revisión visual completa de interior registrada |
| Git | Rama `main`, commit y tag `v0.2.1` publicados |

Advertencias conocidas:

- 202 claves de contenido aún no están en el CSV de localización. Se completarán
  en F8.4; la UI base ya está cubierta.
- Las fuentes CJK/cirílicas se empaquetan y validan visualmente en F8.4.
- Todas las cotas de interior de la cabina son provisionales
  (`provisional_design_value` / `photo_observed_provisional`): el manual disponible
  no incluye cotas de cabina. Se derivan de las anclas `anchor_*` del bloqueo y de
  proporciones observadas en fotos. Verificar contra manual o medición antes de
  F3.2/F5.
- El volante sigue la nota documentada de tres radios; algunas fotos podrían
  leerse como cuatro radios. Marcado para verificación en F3.2.
- La cabina es un bloqueo funcional (greybox), no el interior final: telas,
  materiales PBR y detalle son F3.2.
- No hay interacción "mirar/tocar", espejos, HUD, gamepad ni guardado: son F2.3/F2.4.
- La cabina no introduce física de conducción (sin `VehicleBody3D`); la integración
  con el chasis es F2.4/F3.
- No se generó una APK nueva en 2.2. La APK debug de la Fase 1.4 sigue siendo la
  referencia de build; su prueba de rendimiento no cubre la cabina.

## Completado

- Contrato `data/vehicle/cabin_spec.json` con cabina funcional y rig de manos
  (poses IK), cotas provisionales y compatibilidad con las anclas `anchor_*`.
- `tools/blender/esteem_cabin.py`: generación `bpy` reproducible de la cabina
  (volante de tres radios, columna, tablero, instrumental, consola, radio cassette
  doble DIN con ranura, clima, guantera con cierre, paneles de puerta con
  apoyabrazos/tirador/cristaleras, consola y guía de palanca P-R-N-D-2-L) y del
  armazón `EsteemHandRig` con botón de Overdrive, palanca tipo T y freno de mano.
- Mallas LOD0/LOD1/LOD2 y rig de manos exportados a glTF con manifiesto
  reproducible (comando, hashes, autor, licencia CC BY-NC-SA 4.0, fecha).
- Rig de manos con 15 huesos: `anchor_root`, anclas de control iguales a las del
  bloqueo (`anchor_driver_seat`, `anchor_steering_wheel`, `anchor_gear_lever`,
  `anchor_handbrake`), huesos de mano y destinos IK.
- Cuatro poses IK nombradas (reposo, volante, palanca, freno de mano) que alcanzan
  los controles; verificadas contra las anclas del bloqueo.
- Escena `EsteemCabin.tscn` y `tests/vehicle/CabinTest.tscn` (46 comprobaciones),
  integradas en `health_check.py`.
- Revisión visual completa de referencias de interior (hoja de contacto + 3 fotos
  clave) registrada en `REFERENCE_USAGE_LOG.md`.

## Siguiente

Fase **2.3 con DS-R**: interacción contextual "mirar/tocar", IK 2/1/0 manos,
puertas, seguros, vidrios, luces, antena y radio. No se inicia en este chat.
