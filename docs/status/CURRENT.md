# Estado actual

**Subfase:** 2.3 — Interacción contextual “mirar/tocar”  
**Versión:** `v0.2.2`  
**Modelo de la subfase:** DS-R  
**Fecha:** 2026-11-22  
**Estado:** completada y publicada.

## Enlaces

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Acciones: https://github.com/emanuelindustri-source/ruta-nocturna-1999/actions

## Validación ejecutada

| Prueba | Resultado |
|---|---|
| Contratos JSON + Schemas | 7 contratos válidos, 0 errores, 1 advertencia de claves de contenido |
| Localización | 11 idiomas, 0 errores; 30 claves nuevas; fuentes CJK pendientes de F8.4 |
| Roadmap | 7/45 subfases completadas (15,6%), JSON sincronizado |
| Assets generados | 2 manifiestos válidos (bloqueo + cabina), 0 errores |
| Cabina LOD0/LOD1/LOD2 | 1584 / 704 / 480 triángulos, sin cambios en F2.3 |
| Pruebas de la cabina | 46/46 comprobaciones, exit 0 |
| Pruebas del tren motriz | 125/125 comprobaciones, exit 0 |
| Pruebas de interacción | 180/180 comprobaciones, exit 0 |
| Smoke test | 155/155 comprobaciones, exit 0 |
| Godot import headless | exit 0; sin marcadores críticos |
| Health check de cierre | 18 OK, 3 advertencias esperadas, 0 errores |
| Dispositivo ADB | Redmi 22101316G autorizado (`obojropz89mbwgpn`) |
| Espacio libre | 79,83 GB en `C:` |
| Referencias | 95 archivos; escaneo rápido sin cambios y revisión de interior F2.3 registrada |
| Git | Rama `main`, commit y tag `v0.2.2` publicados |

Advertencias conocidas:

- 202 claves de contenido aún no están en el CSV de localización. Se completarán
  en F8.4; la UI base y F2.3 ya están cubiertas.
- Las fuentes CJK/cirílicas se empaquetan y validan visualmente en F8.4.
- Las traducciones nuevas de F2.3 son provisionales y no tienen revisión nativa.
- Todas las cotas de interior de la cabina siguen siendo provisionales
  (`provisional_design_value` / `photo_observed_provisional`): el manual
  disponible no incluye cotas de cabina. Se derivan de las anclas `anchor_*` del
  bloqueo y de proporciones observadas en fotos. Verificar antes de F3.2/F5.
- El volante sigue la nota documentada de tres radios; algunas fotos podrían
  leerse como cuatro radios. Marcado para verificación en F3.2.
- El bloqueo de F2.2 colocó el volante, la palanca, la radio y la guantera dentro
  de las cajas sólidas del tablero/consola. F2.3 aplica `visual_offsets` y
  `interaction_position_m` para llevar los mandos a la cara del conductor; es un
  ajuste funcional provisional, no la geometría final.
- Los vidrios, la antena, los testigos, los botones y las manos son primitivas de
  código (`visual_proxies`), no arte final ni assets de la fábrica. El arte final
  es F3.1/F3.2.
- El seguro central, el mando de luces y el interruptor de antena no se
  distinguen con claridad en las fotos revisadas: son proxies provisionales.
- No hay espejos, HUD, gamepad ni guardado: son F2.4.
- La cabina no introduce física de conducción (sin `VehicleBody3D`); el volante
  solo cambia la pose IK. La integración con el chasis es F2.4/F3.
- No se generó una APK nueva en 2.3. La APK debug de la Fase 1.4 sigue siendo la
  referencia de build; su prueba de rendimiento no cubre la cabina ni la
  interacción.

## Completado

- Contrato `data/schemas/cabin_interaction.json` y JSON Schema con retículo/tacto,
  poses IK de 2/1/0 manos, puertas y seguros, vidrios, luces, antena, radio,
  guantera, palanca P-R-N-D-2-L con Overdrive y freno de mano.
- Controlador de interacción con foco por retículo (7°), tacto de 44 dp,
  arrastre de la palanca, feedback contextual y delegación en el tren motriz.
- Estado de cabina: puertas/seguros, vidrios en ambos sentidos, luces
  off/posición/carretera, antena con efecto en la señal, radio procedural AM/FM,
  guantera, palanca y freno de mano.
- IK de 2/1/0 manos con cadena de dos huesos por brazo, transiciones y proxies de
  mano visibles. El volante no mueve la dirección ni el chasis.
- La palanca y el Overdrive usan `VehiclePowertrain` (`set_selector`,
  `toggle_overdrive`); el freno de mano termina en `brakes.parking`.
- Escena `scenes/vehicle/CabinInteraction.tscn`, acceso `Ver cabina` desde Boot y
  prompt contextual localizado en once idiomas.
- `tests/vehicle/InteractionTest.tscn` (180 comprobaciones) y
  `tools/dev/interaction_test.cmd`, integrados en `health_check.py`.
- Revisión de referencias de interior F2.3 registrada en
  `REFERENCE_USAGE_LOG.md`; sin copiar archivos de la biblioteca externa.
- Capturas de trabajo en `build/logs/interaction/` (no versionadas) para
  verificar retículo, volante, palanca, radio y puerta.

## Siguiente

Fase **2.4 con MiMo Flash**: espejos `SubViewport`, HUD mínimo, gamepad/D-Pad,
save v0.2.0, QA de reparaciones y ADB. No se inicia en este chat.
