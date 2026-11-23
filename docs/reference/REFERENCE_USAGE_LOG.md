# Registro de uso de referencias

Este registro indica qué se consultó, qué se aprendió y qué se descartó. No copia
las imágenes ni el texto propietario.

## 2026-11-22 — Fase 1.1 — revisión inicial

**Alcance:** inventario completo de 94 archivos, revisión de una muestra de fotos
reales y de las hojas de contacto generadas, extracción de los cuatro documentos
de texto.

### Referencias utilizadas

| Familia | Uso | Resultado |
|---|---|---|
| Fotos de interior (`INTERIOR ESTEEM.jpg`, `adentro esteem.jpg`, `images (10–17).jpg`, `images (2).jpg`, etc.) | Forma y distribución de cabina | Confirmado interior beige, telas con patrón, consola, radio, palanca automática y volante |
| Fotos de motor y piezas | Estructura del vano motor y piezas reparables | Referencia para modelado del 1.6L, batería, filtros, correas, soportes y frenos |
| PDF de servicio y ficha técnica | Datos técnicos y alcance de mantenimiento | Usado para notas derivadas; el PDF no se redistribuye |
| DOCX de leyendas | Tono narrativo y corpus cultural | El Silbón confirma la inversión del silbido; faltan fuentes adicionales para varias entidades |
| Conceptos Gemini | Dirección de arte, UI y escenas | Se adopta la paleta y el lenguaje visual; se rechazan botones táctiles, marcas y mecánicas no aprobadas |
| Videos conceptuales | Revisión de movimiento y ritmo | Pendiente de extracción de fotogramas; se revisarán antes de F9.2 |

### Decisiones

- La cabina final no usará una parrilla de 25 botones; se aplicará interacción
  contextual con retículo/toque y mano IK.
- La paleta de referencia es verde petróleo, ámbar, hueso y óxido, con textura CRT.
- Los menús podrán usar navegación lateral, siempre que D-Pad y gamepad funcionen.
- El HUD táctil no copiará los mockups; se limita a siete controles esenciales.
- El nombre “Troncal 5” y la geografía pueden inspirar el mapa, pero no todas las
  cifras o rutas del concepto son canon.
- Los logos Chevrolet/PDV/Google Play no se reproducen.
- El arte generado no se usa como captura de tienda.
- La altura de admisión de aire y las capacidades se medirán/verificarán antes de
  convertirlas en datos definitivos.

### Descartado

- Estética de “Google Play Games” dentro del juego.
- Texto “LibGDX / OpenGL ES 3.2” de los mockups.
- Mecánicas de roguelike, monetización o cinco noches no aprobadas.
- Entidades adicionales no incluidas en el alcance actual.
- Uso directo de fotografías o PDFs como assets del juego.

## 2026-11-22 — Fase 1.2 — UI de boot y panel QA

**Alcance:** revisión de `UI_ART_DIRECTION_NOTES.md` y de la paleta ya catalogada
para la pantalla de arranque y el panel de creador. No se abrieron nuevas imágenes,
no se copiaron archivos y la biblioteca externa permaneció intacta.

### Decisiones

- El boot y el panel QA usan verde petróleo, ámbar, hueso y cian apagado, sin
  imitar los mockups de 25 botones.
- El panel QA es una herramienta de desarrollo: no se muestra en build de tienda
  salvo bandera explícita.
- Los textos visibles nuevos pasan por las 11 claves de localización; la revisión
  nativa y de glifos CJK sigue pendiente para F8.4.
- No se usaron capturas ni imágenes de referencia como assets del juego.

## 2026-11-22 — Fase 1.3 — bloqueo del Esteem y fábrica Blender

**Alcance:** revisión de las referencias del vehículo necesarias para el bloqueo
paramétrico. Se usó la hoja de contacto `vehicle_references.jpg` y las fichas de
metadatos del catálogo (sin cargar las 40 imágenes en contexto); se abrieron a
tamaño real solo `images (16).jpg` (perfil lateral) y `images.jpg` (vano motor).
No se copió ningún archivo de la biblioteca externa.

### Referencias utilizadas

| Referencia | Uso | Resultado |
|---|---|---|
| Hoja de contacto de vehículos (49 entradas) | Inventario visual de siluetas, interiores y mecánica | Confirmada la silueta sedán "3 cajas" de cuatro puertas para el bloqueo |
| `images (16).jpg` (perfil lateral) | Proporciones de masa del bloqueo | Cabina retrasada respecto al centro, voladizos similares, caídas de capó y maletero cortas |
| `images.jpg` (vano motor) | Orientación transversal del motor y disposición del vano | El bloqueo reserva el vano motor; su contenido interno es F2.1/F3.2 |
| Manual de servicio Mitchell 1999-2000 1.3L/1.6L (extracción en `build/reference/extracted/`) | Búsqueda de cotas de carrocería para el bloqueo | El manual cubre motor, dirección, frenos, suspensión y transmisión; **no** incluye cotas de carrocería |
| Ficha técnica y catálogo de fotos | Confirmación de variantes y equipamiento | Las cotas del bloqueo quedan marcadas como provisionales |

### Decisiones

- Las cotas del bloqueo (largo, ancho, alto, distancia entre ejes, voladizos,
  radio de rueda) son **valores de diseño provisionales** estimados desde las
  proporciones fotográficas; se documentan en `data/vehicle/blockout_spec.json`
  con `source_status: provisional_design_value` y se verificarán contra manual o
  mediciones antes de Fase 2/Fase 5, como exige `ESTEEM_MECHANICAL_NOTES.md`.
- El bloqueo es una greybox de masas: no representa detalles de carrocería,
  emblemas ni interior; esos corresponden a F3.1/F3.2.
- La disposición del vano motor solo se reserva como volumen; las piezas
  internas se modelan con los contratos de componentes ya existentes.
- No se usó ninguna textura, malla ni color tomado de las fotografías.

### Descartado

- Uso de la extracción del manual como fuente de cotas de carrocería (no las
  contiene).
- Cualquier emblema, marca o logotipo visible (Chevrolet, PDV y otros).
- Copia de imágenes o PDFs al repositorio.

## 2026-11-22 — Fase 1.4 — CI, export y rebanada vertical

**Alcance:** subfase de infraestructura. No se modeló ni texturizó nada nuevo. Se
consultaron solo las fichas de metadatos del catálogo (`ai_generated_concept` y
`motion_reference`) y `UI_ART_DIRECTION_NOTES.md` para confirmar que la pantalla de
boot, el panel QA y la nueva escena estática siguen la paleta aprobada. No se abrió
ninguna imagen a tamaño real y no se copió ningún archivo de la biblioteca externa.

### Referencias utilizadas

| Referencia | Uso | Resultado |
|---|---|---|
| Fichas del catálogo de conceptos de UI (`ui`, `art_direction`) | Confirmar que la rebanada vertical no introduce una dirección de arte nueva | Se mantienen verde petróleo, ámbar, hueso y gris de greybox; sin botones flotantes ni HUD adicional |
| `UI_ART_DIRECTION_NOTES.md` | Revisar contraste y tamaño mínimo del botón de retorno (48 px) | Botón de 48 px de alto y texto localizado; sin duplicar controles de cabina porque aún no existen |
| Metadatos del catálogo de vehículo (sin abrir imágenes) | Confirmar que la rebanada usa el bloqueo ya generado y no una foto | La escena instancia `EsteemBlockout.tscn`; no hay texturas ni colores derivados de fotografías |

### Decisiones

- La rebanada vertical es una escena estática: coche gris, carretera gris, cámara y
  un panel informativo. No contiene `VehicleBody3D`, física, tráfico ni entidades.
- Los artefactos de export viven en `build/exports/` (ignorados por Git); nunca se
  versionan APK, EXE, PCK ni capturas intermedias.
- La APK de prueba es una build debug firmada con el keystore de depuración local;
  no se publica en el repositorio.
- No se añadió ninguna captura de la biblioteca externa a la web ni a la galería.

### Descartado

- Usar imágenes de referencia como capturas de la rebanada vertical.
- Presentar la rebanada como gameplay o como build jugable.
- Añadir una captura de tienda en esta fase.

## 2026-11-22 — Fase 2.1 — tren motriz del Esteem

**Alcance:** revisión de las referencias del catálogo relevantes para motor, caja
automática, frenos y refrigeración. Se abrieron a tamaño real seis fotografías
técnicas y se consultó el texto extraído de dos manuales. No se cargaron las 40
imágenes en contexto, no se copió ningún archivo y la biblioteca externa quedó
intacta.

### Referencias utilizadas

| Referencia | Uso | Resultado |
|---|---|---|
| `esteem motor.jpg` (vano motor) | Distribución del vano, motor transversal, batería, caja de aire y bomba de freno | Confirmada la disposición transversal y la posición de batería, filtro de aire y cilindro maestro |
| `motor esteem.jpg` (motor de cerca) | Identificación de tapa de válvulas, bujías, cables y soportes | Referencia de servicio; no se modeló ninguna pieza en esta subfase |
| `caja automatica.jpg` (caja desarmada) | Campana, convertidor y carcasa de la transmisión automática | Confirmada la forma de campana y convertidor para el contrato de simulación |
| `turbina-convertidor-de-torque.jpg` (despiece) | Componentes del convertidor y conjunto de transmisión | Referencia de nomenclatura; sin cotas utilizables |
| `BOMBA DE FRENO DE ESTEEM.webp` | Cilindro maestro, depósito y conexiones | Referencia visual para el contrato de frenos; sin medidas |
| `correa del carro esteem.jpg` | Zona de distribución y correa | Referencia de mantenimiento; no se usa para valores de simulación |
| Manual Mitchell 1999-2000 1.3L/1.6L (extracción en `build/reference/extracted/`) | Cilindrada, diámetro, carrera, compresión, alimentación, aceite y presión | Valores marcados como `manual_verified` en `vehicle_powertrain.json` |
| Manual de servicio en español (extracción en `build/reference/extracted/`) | Secciones de transmisión automática, frenos y mantenimiento | Confirmada la existencia de caja automática y procedimientos; **no** se encontró tabla de relaciones |
| `VID_20261122_115121.mp4` (nuevo) | Inventario | Catalogado como video conceptual; no se usa en mecánica |

### Decisiones

- La cilindrada, diámetro, carrera, compresión, alimentación y datos de aceite
  pasan al contrato como verificados en el manual, con su nota de fuente.
- Relaciones de caja, convertidor, curva de par, masas, umbrales térmicos y
  fuerzas de freno quedan como `design_value` provisionales. No se presentan como
  datos del manual.
- El tanque de 50 L sigue siendo `game_balance` heredado del contrato de
  componentes.
- La simulación es longitudinal y no crea cabina, IK, espejos ni conducción
  narrativa. Esas piezas son F2.2–F2.4/F3.
- Los avisos son códigos internos; la UI y la localización llegan en F2.4/F9.1.
- El nuevo video se cataloga solo con metadatos; no se extraen fotogramas en esta
  subfase porque no aporta datos mecánicos.

### Descartado

- Tomar cotas de las fotografías como si fueran medidas del manual.
- Inventar relaciones de caja o temperaturas y presentarlas como verificadas.
- Copiar imágenes, PDFs o fotogramas al repositorio.
- Modelar piezas de motor, caja o frenos en esta subfase.

## 2026-11-22 — Fase 2.2 — cabina funcional y rig de manos (revisión visual completa de interior)

**Alcance:** revisión visual completa de las referencias de interior que exige
`AGENTS.md` para F2.2 (hitos de revisión obligatoria). Se usó el catálogo
`docs/reference/reference_catalog.json` y una **hoja de contacto de interior**
generada a `build/reference/contact_sheets/interior_f22_review.jpg` (37 fotos de
vehículo, no versionada). **No se cargaron las 40 imágenes en contexto** y **no
se copió ningún archivo** de `C:\Dev\fotos de ejemplo` al repositorio. Solo se
abrieron a tamaño real **tres** fotografías clave de cabina para confirmar
detalles de modelado; las copias de trabajo derivadas quedan en
`build/reference/review_f22/` (ignoradas por Git, originales intactos).

### Referencias utilizadas

| Referencia | Uso | Resultado |
|---|---|---|
| Hoja de contacto de interior (37 fotos de vehículo) | Inventario visual de cabina: tablero, consola, volante, palanca, guantera, puertas, asientos | Identificadas las fotos de cabina frente a exteriores, mecánica y piezas |
| `images (10).jpg` (tablero completo, 500×400, ampliada ×2) | Distribución global del tablero y la consola central | Volante con radios y cubo central, instrumental con velocímetro central, consola con radio/cassette, clima, palanca automática, freno de mano sobre el túnel y guantera con bandeja superior |
| `INTERIOR ESTEEM.jpg` (= `images (12).jpg`, 640×480) | Consola central a tamaño real: palanca, radio, clima | Palanca automática tipo T/pistón con **botón lateral “OVER DRIVE”** en el mango, clima con deslizantes, encendedor 12V, guantera y panel de cristaleras |
| `images (7).jpg` (lado acompañante, 507×394, ampliada ×2) | Guantera, consola y panel de puerta del acompañante | Guantera con puerta y cierre, consola central, panel de puerta con apoyabrazos |
| `images (1).jpg`, `images (11).jpg`, `images (17).jpg`, `images (2).jpg`, `images (6).jpg`, `images (12).jpg` (vistas de tablero, volante, asientos y puertas) | Volante, instrumental, asientos de tela con patrón geométrico y paneles | Confirmada la disposición de cabina y el patrón de tapicería; sin cotas utilizables |
| `ESTEEM_MECHANICAL_NOTES.md` (sección Apariencia y cabina) | Notas ya derivadas de las fotos | Interior beige/telas grises, volante de tres radios, radio cassette doble DIN, palanca con botón de Overdrive, guantera con cierre, paneles con apoyabrazos |

### Decisiones de modelado (F2.2)

- La cabina de F2.2 es un **bloqueo funcional** (greybox) del interior: volante,
  columna, tablero/consola, palanca P-R-N-D-2-L con botón de Overdrive, freno de
  mano, radio cassette doble DIN, guantera, paneles de puerta y consola. El
  interior final (telas, materiales PBR) es F3.2.
- La palanca se modela como empuñadura tipo T/pistón con **botón lateral de
  Overdrive**, coherente con `transmission.overdrive` y
  `transmission.selector_modes` de `vehicle_powertrain.json`. No se implementa la
  interacción (es F2.3).
- El volante sigue la nota documentada de **tres radios** de
  `ESTEEM_MECHANICAL_NOTES.md`. Se deja constancia de que algunas fotos
  (`images (10)`) podrían leerse como cuatro radios; se marca para verificación
  en F3.2 y se usa la determinación ya documentada (no se inventa).
- La radio es **cassette de doble DIN** según la nota documentada; la posición y
  el alto son provisionales (el manual no da cotas de interior).
- Todas las cotas de interior son **provisionales** (`provisional_design_value` /
  `photo_observed_provisional`): se derivan de las anclas `anchor_*` del bloqueo y
  de proporciones observadas en fotos, no del manual. No se publican como
  especificación oficial.
- Materiales: grises y beige **originales del proyecto** (greybox); ninguna
  textura, malla ni color procede de las fotografías.
- Sin emblemas ni marcas (Chevrolet, PDV ni otras). Sin texto visible: la
  señalética P-R-N-D-2-L se representa solo por posición de la guía, no por texto
  (la localización llega en F2.4/F9.1).

### Descartado

- Copiar imágenes, recortes o texturas de la biblioteca externa al repositorio.
- Tomar cotas de interior de las fotos como medidas del manual.
- Reproducir emblemas, logos o texto de marca.
- Implementar interacción “mirar/tocar”, espejos, HUD, gamepad o guardado (F2.3/F2.4).
- Usar las fotos como capturas de tienda o assets del juego.

## 2026-11-22 — Fase 2.3 — interacción contextual y mandos de cabina

**Alcance:** revisión de las referencias de interior necesarias para la
interacción "mirar/tocar" y para los mandos de puertas, vidrios, luces, antena y
radio. Se usaron el catálogo y **tres copias de trabajo ya derivadas en F2.2**
(`build/reference/review_f22/INTERIOR_ESTEEM_review.jpg`,
`images_(10)_review.jpg` e `images_(7)_review.jpg`), no los originales. **No se
cargaron las 40 imágenes en contexto** y **no se copió ningún archivo** de
`C:\Dev\fotos de ejemplo` al repositorio.

### Referencias utilizadas

| Referencia | Uso | Resultado |
|---|---|---|
| `INTERIOR_ESTEEM_review.jpg` (copia de trabajo de `INTERIOR ESTEEM.jpg`) | Palanca automática y consola | Palanca tipo T/pistón con botón lateral **OVER DRIVE** en la cara izquierda del pomo; clima con deslizantes sobre la consola; freno de mano en el túnel |
| `images_(10)_review.jpg` (tablero completo) | Distribución de radio, clima, palanca y freno de mano | Radio cassette sobre el clima; guía de palanca en el túnel; freno de mano a la izquierda de la guía; volante de tres radios |
| `images_(7)_review.jpg` (lado acompañante) | Panel de puerta y guantera | Panel con apoyabrazos y mando de cristaleras; guantera con puerta y cierre; consola central |
| `ESTEEM_MECHANICAL_NOTES.md` (Apariencia y cabina) | Confirmar lo ya documentado | Ventanas eléctricas, volante de tres radios, radio doble DIN, palanca con Overdrive y guantera con cierre |

### Decisiones de interacción (F2.3)

- El modo de interacción es **retículo/tacto contextual** con mano IK; no se
  usa una parrilla de botones ni se duplican controles de cabina en la UI.
- El radio táctil se fija en **44 dp** y el foco por retículo usa un ángulo
  máximo de 7°. El prompt es texto localizado, no solo color.
- Las poses IK cubren **2/1/0 manos en el volante**: volante (2), palanca,
  freno de mano, radio, luces y ventanas (1), puertas y guantera (0).
- La palanca P-R-N-D-2-L y el botón de Overdrive se delegan en
  `vehicle_powertrain.json`; el freno de mano se delega en `brakes.parking`. No
  se duplican relaciones, curva de par, fuerzas de freno ni física de
  conducción.
- El seguro central, el mando de luces y el interruptor de antena **no se
  distinguen con claridad** en las fotos revisadas. Se implementan como
  proxies funcionales provisionales en posiciones derivadas de las anclas y de
  la consola; no se presentan como hechos históricos.
- El bloqueo de F2.2 tenía el volante, la palanca, la radio y la guantera dentro
  de las cajas sólidas del tablero y la consola. F2.3 aplica un
  **desplazamiento funcional** a la cara del conductor para que los mandos sean
  visibles y alcanzables. Es provisional; la geometría definitiva es F3.2 y no
  altera los assets ni las anclas del contrato de F2.2.
- Los vidrios, la antena, los testigos, los botones y las manos son primitivas
  de código para dar retorno visual; no son arte final ni se copian de la
  biblioteca externa.

### Descartado

- Copiar imágenes, recortes o texturas de la biblioteca externa al repositorio.
- Inventar la posición exacta de mandos que no se ven en las fotos y
  presentarla como dato histórico.
- Duplicar la caja automática, el Overdrive o los frenos fuera de sus contratos.
- Implementar espejos, HUD, gamepad o guardado (F2.4).
- Usar las fotos como capturas de tienda o assets del juego.

## Próxima revisión

- Revisión rápida: inicio y cierre de cada subfase.
- Revisión completa: **2026-12-06**, o antes de la subfase de modelado/UI que
  corresponda (obligatoria antes de F3.1 y F3.2).
