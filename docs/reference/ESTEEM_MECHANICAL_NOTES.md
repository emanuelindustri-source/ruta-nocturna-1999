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

## Datos provisionales del contrato

Los siguientes valores viven en `data/schemas/vehicle_components.json` y están
marcados como provisionales:

| Dato | Valor preliminar | Estado |
|---|---:|---|
| Cilindrada | 1.590 cc | A confirmar con ficha |
| Cilindros | 4, SOHC 16V | A confirmar con ficha |
| Potencia | 95 hp | Solo concepto; no verificado |
| Caja | Automática de 4 marchas con Overdrive | A confirmar por versión |
| Combustible | 50 litros | A confirmar |
| Altura de admisión de agua | 0,68 m | **No definitivo** |
| Profundidad segura de vadeo | 0,30 m | Valor de diseño |
| Velocidad segura de cruce | 12 km/h | Valor de diseño |
| Grúa base | Bs. 9.000 | Balance del juego |

La ficha técnica extraída identifica motores **1.3L y 1.6L de 4 cilindros** para
1999–2000. El manual de servicio cubre sistemas de dirección, frenos, suspensión,
motor y transmisión automática. La extracción es de solo lectura y permanece en
`build/reference/extracted/`, fuera de Git.

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

- Altura física real de la toma de aire del modelo elegido.
- Tipo y presión de neumáticos.
- Capacidad y tipo de aceite de motor y ATF.
- Capacidad de refrigerante.
- Diagrama exacto de fusibles y relés del ventilador.
- Procedimiento de gato y puntos de elevación.
- Cotas principales: distancia entre ejes, ancho, alto y voladizos.
- Pesos y distribución para la simulación.
- Procedimiento seguro de vadeo y secado de admisión.
- Verificación de que la versión automática y el equipamiento de la referencia
  corresponden con la unidad del juego.

## Regla de investigación

Antes de modificar las especificaciones del vehículo se debe actualizar este
documento, citar la página del manual o la fuente y cambiar el estado del dato.
No se aceptan números “porque suenan bien”.
