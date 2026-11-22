# Notas mecánicas del Esteem 1999

**Estado:** notas de referencia para Fase 2 y Fase 5. No son el manual final.  
**Regla:** ningún dato marcado como provisional se usa como verdad histórica ni
se publica como especificación oficial.

## Apariencia y cabina

Observado en fotografías:

- Interior beige claro con telas grises de patrón geométrico.
- Volante de tres radios, tablero con velocímetro central y testigos laterales.
- Consola central con radio cassette de doble DIN, controles de clima, encendedor
  y palanca automática.
- La palanca automática visible tiene botón lateral de **Overdrive**.
- Guantería del lado del acompañante con cierre.
- Panel de puerta con apoyabrazos; las fotos muestran ventanas eléctricas en la
  versión de referencia, pero la variante de juego exige controles individuales.
- Espejo retrovisor central, salidas de aire laterales y una moldura beige.

La disposición exacta se ajustará al modelo paramétrico. El diseño final no copiará
los emblemas de la marca sin licencia.

## Vano motor y mecánica observada

Las referencias incluyen:

- Motor transversal de 4 cilindros.
- Batería en el vano motor con cables y soporte.
- Depósitos de refrigerante/limpiaparabrisas.
- Filtro de aceite, correa de accesorios y soportes de motor.
- Arrancadores.
- Bomba de freno y cilindro maestro.
- Caja automática desarmada y convertidor de par.
- Juntas homocinéticas, filtro de aceite y cartucho de filtro.
- Páginas de mantenimiento, dirección, frenos, suspensión y transmisión del
  manual de servicio.

## Datos verificados en el manual (Fase 2.1)

Extraídos del manual de servicio Mitchell 1999-2000 1.3L/1.6L 4-Cylinder,
`ENGINE SPECIFICATIONS` y `ENGINE OILING`. La extracción de solo lectura vive en
`build/reference/extracted/` y no se versiona.

| Dato | Valor | Fuente |
|---|---:|---|
| Cilindrada 1.6L | 97.0 cu in (1.6L); 1.590 cc calculados con diámetro y carrera | Mitchell, ENGINE SPECIFICATIONS |
| Diámetro | 75,0 mm (2.95 in) | Mitchell, ENGINE SPECIFICATIONS |
| Carrera | 90,0 mm (3.54 in) | Mitchell, ENGINE SPECIFICATIONS |
| Relación de compresión | 9,5:1 | Mitchell, ENGINE SPECIFICATIONS |
| Alimentación 1.6L | SFI | Mitchell, ENGINE SPECIFICATIONS |
| Presión de compresión | 199 psi (14 kg/cm²) estándar; límite 156 psi (11 kg/cm²) | Mitchell, ENGINE SPECIFICATIONS |
| Aceite de motor con filtro | 3,3 L (3.5 qts) para Esteem/Swift | Mitchell, ENGINE OILING |
| Presión de aceite | 3,3–4,3 kg/cm² (324–422 kPa) a 4000 rpm | Mitchell, ENGINE OILING |
| Par de bujía | 20–30 N·m (15–22 ft-lb) | Mitchell, TORQUE SPECIFICATIONS |

La ficha técnica identifica motores **1.3L y 1.6L de 4 cilindros** para 1999–2000.
El manual cubre dirección, frenos, suspensión, motor y transmisión automática. La
tabla de relaciones de la caja automática no aparece en la extracción disponible;
por eso las relaciones siguen marcadas como provisionales.

## Valores de simulación (Fase 2.1, provisionales)

Viven en `data/schemas/vehicle_powertrain.json`, cada sección con su
`source_status` y `source_note`. **No son especificación oficial** hasta
calibrarlos con manual, dinamómetro o medición.

| Dato | Valor preliminar | Estado |
|---|---:|---|
| Par máximo | 135 N·m a 2500 rpm (curva de diseño) | `design_value_pending_manual_and_dyno_calibration` |
| Potencia | 95 hp (contrato de componentes) | Provisional; no verificado |
| Ralentí | 800 rpm | Valor de diseño |
| Corte de inyección | 6800 rpm | Valor de diseño |
| Relaciones | 2,81 / 1,55 / 1,00 / 0,71 | Valor de diseño; manual pendiente |
| Relación final | 4,10 | Valor de diseño |
| Convertidor | stall 2200 rpm, multiplicación 2,0 | Valor de diseño |
| Masa en orden de marcha | 1080 kg | Valor de diseño |
| CdA | 0,64 m² | Valor de diseño |
| Termostato | abre 82 °C, pleno 88 °C | Valor de diseño |
| Ventilador | baja 98 °C, alta 104 °C | Valor de diseño |
| Aviso / modo seguro / agarrotamiento | 110 / 115 / 125 °C | Valor de diseño |
| Fuerza de frenos | 9000 N de servicio, 3500 N de estacionamiento | Valor de diseño |
| Combustible | 50 L | `game_balance` del contrato de componentes |
| Altura de admisión de agua | 0,68 m | **No definitivo** |
| Profundidad segura de vadeo | 0,30 m | Valor de diseño |
| Velocidad segura de cruce | 12 km/h | Valor de diseño |
| Grúa base | Bs. 9.000 | Balance del juego |

## Cotas del bloqueo (Fase 1.3, provisionales)

El bloqueo paramétrico (`data/vehicle/blockout_spec.json`) usa valores de diseño
estimados desde las proporciones de las fotografías del vehículo (perfil lateral y
tres cuartos). La búsqueda en el manual de servicio disponible **no** encontró
cotas de carrocería; por tanto, ninguna cifra de esta tabla es un dato del manual:

| Dato | Valor preliminar | Estado |
|---|---:|---|
| Largo | 4,37 m | Valor de diseño (proporciones fotográficas) |
| Ancho | 1,69 m | Valor de diseño |
| Alto | 1,40 m | Valor de diseño |
| Distancia entre ejes | 2,48 m | Valor de diseño |
| Voladizo delantero | 0,945 m | Valor de diseño |
| Voladizo trasero | 0,945 m | Valor de diseño |
| Vía | 1,44 m | Valor de diseño |
| Radio de rueda | 0,30 m | Valor de diseño |
| Ancho de neumático | 0,19 m | Valor de diseño |

Fuente y registro: `docs/reference/REFERENCE_USAGE_LOG.md` (Fase 1.3). Verificar
contra manual o medición antes de Fase 2/Fase 5. No publicar como especificación
oficial del vehículo.

## Datos pendientes antes de Fase 2/5

- Altura física real de la toma de aire del modelo elegido y cota del filtro.
- Tipo y presión de neumáticos.
- Tipo de aceite de motor y capacidad/tipo de ATF.
- Capacidad de refrigerante y temperatura exacta del termostato.
- Diagrama exacto de fusibles y relés del ventilador.
- Relaciones de la caja automática, relación final y curva de par reales.
- Procedimiento de gato y puntos de elevación.
- Cotas principales: distancia entre ejes, ancho, alto y voladizos.
- Pesos y distribución para la simulación.
- Procedimiento seguro de vadeo y secado de admisión.
- Verificación de que la versión automática y el equipamiento de la referencia
  corresponden con la unidad del juego.
- Confirmar si la caja es de cuatro marchas con Overdrive en la unidad de 1999.

## Regla de investigación

Antes de modificar las especificaciones del vehículo se debe actualizar este
documento, citar la página del manual o la fuente y cambiar el estado del dato.
No se aceptan números “porque suenan bien”.
