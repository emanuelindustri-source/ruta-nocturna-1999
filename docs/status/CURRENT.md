# Estado actual

**Subfase:** 2.1 — Motor, caja automática y tests  
**Versión:** `v0.2.0`  
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
| Contratos JSON + Schemas | 6 contratos válidos, 0 errores, 1 advertencia de claves de contenido |
| Coherencia del tren motriz | Cilindrada, selector, marchas, Overdrive, tanque, ventilador y radio de rueda comprobados |
| Localización | 11 idiomas, 62 claves, 0 errores; fuentes CJK pendientes de F8.4 |
| Roadmap | 5/45 subfases completadas (11,1%), JSON sincronizado |
| Pruebas del tren motriz | 125/125 comprobaciones, exit 0 |
| Smoke test | 155/155 comprobaciones, exit 0 |
| Godot import headless | exit 0; sin marcadores críticos |
| Health check de cierre | 16 OK, 3 advertencias esperadas, 0 errores |
| Dispositivo ADB | Redmi 22101316G autorizado (`obojropz89mbwgpn`) |
| Espacio libre | 77 GB en `C:` |
| Referencias | 95 archivos, escaneo rápido sin cambios pendientes |
| Git | Rama `main`, commit y tag `v0.2.0` publicados |

Advertencias conocidas:

- 202 claves de contenido aún no están en el CSV de localización. Se completarán
  en F8.4; la UI base ya está cubierta.
- Las fuentes CJK/cirílicas se empaquetan y validan visualmente en F8.4.
- Los valores de simulación (relaciones, convertidor, curva de par, masas,
  umbrales térmicos y fuerzas de freno) son provisionales y están marcados en
  `vehicle_powertrain.json`. Los datos de cilindrada, diámetro, carrera,
  compresión, alimentación y aceite sí están verificados en el manual Mitchell.
- Las cotas del bloqueo del Esteem siguen siendo valores provisionales.
- No hay cabina, manos IK, espejos ni conducción narrativa: son F2.2–F2.4.
- El modelo térmico y de frenos es longitudinal y no sustituye una prueba de
  `VehicleBody3D`, suspensión, neumáticos o colisión.
- No se generó una APK nueva en 2.1. La APK debug de la Fase 1.4 sigue siendo la
  referencia de build; su prueba de rendimiento no cubre el tren motriz.
- MIUI/HyperOS exige el permiso "Instalar vía USB" para el paquete; sin él,
  `adb install` devuelve `INSTALL_FAILED_USER_RESTRICTED`.

## Completado

- Contrato `data/schemas/vehicle_powertrain.json` con `schema_version: 1`, JSON
  Schema propio y validación cruzada con `vehicle_components.json` y
  `blockout_spec.json`.
- Motor 1.6L SOHC 16V simulado: arranque, ralentí, curva de par, corte de
  inyección, fricción, retención, calado, ahogo, secado, modo seguro y
  agarrotamiento.
- Caja automática de cuatro marchas con P-R-N-D-2-L, Overdrive, convertidor de
  par, bloqueo en crucero, calendario de cambios y rechazo de maniobras
  inválidas.
- Frenos de servicio y estacionamiento con fade térmico, desgaste de pastillas y
  nivel de líquido.
- Combustible: tanque de 50 L, consumo por carga, reserva, aviso y calado por
  vacío.
- Térmica: termostato, radiador, electroventilador de dos velocidades, fallos de
  fusible/relé/motor, aviso de sobrecalentamiento, modo seguro y agarrotamiento.
- Orquestador `VehiclePowertrain` con señales locales y telemetría, sin UI ni
  autoloads nuevos.
- 125 pruebas headless del tren motriz, integración en smoke test y chequeo de
  salud `powertrain_tests`.
- Documentación de arquitectura, contratos, máquinas de estados, QA y referencias
  actualizada con el alcance real de 2.1.

## Siguiente

Fase **2.2 con MiMo Pro**: cabina funcional, volante, palanca, freno de mano,
radio, guantera, paneles, rig de manos y poses IK. Antes de abrir el chat se debe
hacer la revisión visual completa de las referencias de interior que exige
`AGENTS.md` para F2.2. No se inicia en este chat.
