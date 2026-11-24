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

## 2026-11-22 - Fase 2.4 - espejos, HUD, gamepad y guardado

**Alcance:** revisión de metadatos del catálogo (95 entradas) para espejos,
instrumental/HUD, gamepad y guardado, más una sola copia de trabajo ya derivada
en F2.2 (`build/reference/review_f22/images_(10)_review.jpg`). **No se cargaron
las 40 imágenes en contexto** y **no se copió ningún archivo** de
`C:\Dev\fotos de ejemplo` al repositorio. La biblioteca externa quedó intacta
(escaneo rápido: sin cambios).

### Referencias utilizadas

| Referencia | Uso | Resultado |
|---|---|---|
| Metadatos de `reference_catalog.json` (95 fichas) | Buscar fotos de espejos, instrumental, gamepad y guardado | No hay entradas dedicadas a gamepad, HUD digital ni guardado; las fotos de cabina están marcadas `F2.2/F3.2` |
| `images_(10)_review.jpg` (copia de trabajo de F2.2, tablero completo) | Confirmar instrumental y zona superior del parabrisas | Instrumental con velocímetro central y testigos laterales detrás del volante; cabecera de parabrisas superior visible (zona del espejo retrovisor); consola con palanca, freno de mano y mando de cristaleras |
| Fichas de conceptos Gemini (`ui`, `art_direction`) | Dirección de HUD y navegación | Solo inspiración de paleta; los mockups de 25 botones siguen anulados por la interacción contextual |
| `ESTEEM_MECHANICAL_NOTES.md` | Lo ya documentado | Confirma instrumental convencional y ausencia de datos de espejos en el manual disponible |

### Decisiones (F2.4)

- El HUD es un **overlay mínimo** (velocidad, marcha, combustible y avisos)
  alimentado por `VehiclePowertrain.get_telemetry()`. No replica el instrumental
  del modelo ni añade botones táctiles; el arte final del instrumental es F3.2.
- Los espejos se implementan como **primitivas de código** con `SubViewport`
  (interior + dos laterales) sobre las anclas `anchor_mirror_left` /
  `anchor_mirror_right` de `blockout_spec.json`. Las cotas y el ángulo son
  provisionales; el espejo definitivo es F3.1 y cuentan en el presupuesto móvil
  de triángulos.
- La biblioteca **no contiene referencias de gamepad ni de guardado**: se usa la
  API estándar de Godot (`InputMap`, acciones `ui_*`) sin inventar referencias.
- El HUD y los avisos usan claves de localización en once idiomas; las
  traducciones son provisionales hasta la revisión nativa de F8.4.

### Descartado

- Copiar imágenes, recortes o texturas de la biblioteca externa.
- Presentar los conceptos de IA como canon o como capturas de tienda.
- Replicar el mockup de HUD con parrilla de botones.
- Tomar fotos como fuente de cotas de espejos o de ángulos de visión.

## 2026-11-22 - Fase 3.1 - exterior definitivo (revisión visual completa de exterior)

**Alcance:** revisión visual completa obligatoria antes de F3.1 (`AGENTS.md`,
sección 10). Se usó el catálogo `docs/reference/reference_catalog.json` (95
fichas) y **hojas de contacto generadas a `build/reference/contact_sheets/`**
(`exterior_f31_review.jpg`, 48 referencias de vehículo; y
`exterior_f31_detail.jpg`, mosaico de detalle). **No se cargaron las 40
imágenes en contexto** y **no se copió ningún archivo** de
`C:\Dev\fotos de ejemplo` al repositorio. Solo se abrieron a tamaño real
**seis** fotografías clave de exterior, como copias de trabajo ampliadas ×2 en
`build/reference/review_f31/` (ignoradas por Git; originales intactos).

### Referencias utilizadas

| Referencia | Uso | Resultado |
|---|---|---|
| Hoja de contacto de exterior (48 fotos de vehículo/técnicas) | Inventario visual de exterior, piezas y despieces | Identificadas las fotos de exterior (frente, trasera, perfil, tres cuartos) frente a interiores, mecánica y piezas sueltas |
| `D_NQ_NP_992627-MLV113346707105_062026-O.webp` (Esteem rojo, tres cuartos delantera) | Faros, parrilla, capó y parachoques delantero | Faros horizontales alargados con indicador ámbar en la esquina externa; parrilla de listones horizontales con emblema central; parachoques integrado con boca de aire inferior y entradas laterales; espejo color carrocería |
| `RT_PU_92a67511c7434a42bbdec44622d73a0b.webp` (Esteem plata, tres cuartos delantera der.) | Faros, antena, molduras y llantas | Antena delgada sobre el guardabarros delantero derecho; moldura lateral oscura a media altura; llantas de acero (con/sin tapacubos según ejemplar) |
| `images (15).jpg` (Esteem plata, trasera pura) | Pilotos traseros, maletero y parachoques trasero | Pilotos verticales/rectangulares en las esquinas con franjas roja-ámbar-roja/blanca; matrícula central sobre la tapa; parachoques con moldura; salida de escape a la derecha; **tapa de combustible redonda en el guardabarros trasero izquierdo** |
| `images (14).jpg` (Esteem plata, tres cuartos trasera der.) | Envoltura de pilotos, tapacubos y caída de maletero | Los pilotos envuelven ligeramente la esquina; tapacubos plateados sobre llanta de acero; caída de maletero corta con borde superior liso |
| `images (16).jpg` (Esteem blanco, perfil lateral puro) | Proporciones globales y caídas | Sedán de tres cajas: capó corto, cabina retrasada, maletero corto; cuatro puertas con manijas tipo tirador; montante B oscuro |
| `esteem-16.webp` (despiece de parachoques, página de manual) | Separación de piezas del exterior | Confirma parachoques delantero/trasero como piezas desmontables con refuerzo/absorbedor interior; base para el reparto de piezas separadas del exterior |
| Hoja de contacto + fichas del catálogo (piezas sueltas `images (8/9).jpg`, `D_Q_NP_*`) | Manijas y herrajes | Manijas tipo tirador con botón; llaves/cilindros como referencia de herrajes (no se modelan en F3.1) |
| `ESTEEM_MECHANICAL_NOTES.md` | Confirmar lo ya documentado | Cotas de carrocería siguen sin constar en el manual disponible; se mantienen como provisionales |

### Decisiones de modelado (F3.1)

- El exterior se genera como **piezas separadas** en un spec declarativo nuevo
  (`data/vehicle/exterior_spec.json`): carrocería base, capó, tapa de
  maletero, cuatro puertas, parachoques delantero/trasero, molduras,
  parrilla, faros, pilotos traseros, espejos, llantas, antena, tapa de
  combustible y limpiaparabrisas. Todo con scripts `bpy` reproducibles; nada
  de `.blend` editados a mano.
- Se conserva la silueta de tres cajas del bloqueo de F1.3 (mismas cotas
  globales provisionales de `blockout_spec.json`): capó corto, cabina
  retrasada, maletero corto con caída marcada.
- Los faros son unidades horizontales con **piloto ámbar en la esquina
  externa**; los pilotos traseros son unidades verticales con franjas
  roja/ámbar/rojo-blancas. Son geometría y materiales propios: **sin texto,
  sin emblemas y sin marcas** (Chevrolet, PDV, Suzuki u otras): la parrilla se
  modela neutra y los lugares de emblemas quedan lisos.
- La **tapa de combustible** se coloca en el guardabarros trasero izquierdo
  (observado en las fotos), no en el derecho.
- **Antena** delgada sobre el guardabarros delantero derecho (coherente con
  `body.antenna` de `vehicle_components.json`, `front_right_fender`).
- Llantas: neumático + llanta de acero + tapacubo, con LODs propios; las
  posiciones siguen `track_m`/`wheelbase_m`/`wheel_radius_m` de
  `blockout_spec.json`.
- Los espejos laterales del exterior se modelan como carcasa + superficie
  reflectante en las anclas `anchor_mirror_left/right`; **los espejos
  funcionales de F2.4 (`cabin_mirrors.gd`) siguen siendo los únicos que
  reflejan** y respetan `mirrors.budget` de `cabin_interaction.json` v2.
- Materiales PBR **originales del proyecto** (pintura, vidrio, plástico,
  goma, cromo, lente, reflector): ninguna textura ni color procede de la
  biblioteca externa. Las cotas de exterior siguen siendo provisionales y no
  se publican como especificación oficial.

### Descartado

- Copiar imágenes, recortes o texturas de la biblioteca externa al repositorio.
- Reproducir emblemas, logos o texto de marca (Chevrolet, PDV, Suzuki u otros),
  incluidos los letreros de la tapa de maletero observados en las fotos.
- Tomar cotas de las fotos como medidas del manual.
- Usar las fotos como capturas de tienda o assets del juego.
- Implementar el interior definitivo (F3.2) o la física de conducción.

## 2026-11-22 - Fase 3.2 - interior definitivo (revisión visual completa de interior)

**Alcance:** revisión visual completa obligatoria antes de F3.2 (`AGENTS.md`,
sección 10). Se usó el catálogo `docs/reference/reference_catalog.json` (95
fichas) y **hojas de contacto generadas a `build/reference/contact_sheets/`**
(`interior_f32_review.jpg`, 49 fotos de vehículo/técnicas; y
`interior_f32_detail.jpg`, mosaico de detalle de interior). **No se cargaron
las 40 imágenes en contexto** y **no se copió ningún archivo** de
`C:\Dev\fotos de ejemplo` al repositorio. Solo se abrieron a tamaño real
**seis** fotografías clave de interior, como copias de trabajo ampliadas ×2 en
`build/reference/review_f32/` (ignoradas por Git; originales intactos).

### Referencias utilizadas

| Referencia | Uso | Resultado |
|---|---|---|
| Hoja de contacto de interior (49 fotos de vehículo/técnicas) | Inventario visual: tablero, consola, asientos, telas, maletero, piezas y despieces | Identificadas las fotos de cabina, banqueta, maletero e instrumental frente a exteriores, mecánica y piezas sueltas |
| `adentro esteem.jpg` (tablero completo desde el lado del acompañante, ampliada ×2) | Distribución del tablero, consola y tapicería | Tablero bitono (gris oscuro arriba, beige abajo), bandeja superior del acompañante, guantera con tapa y cierre, consola central con dobles salidas de aire, reloj digital, botón de emergencias rojo, radio cassette, clima con deslizadores y franja azul/roja, encendedor/tapacenicero, palanca tipo T/pistón con guía P-R-N-D-2-L, freno de mano sobre el túnel; **telas con patrón geométrico tipo greca** en centros de asientos, respaldos y paneles de puerta |
| `images (10).jpg` (cabina completa desde atrás, ampliada ×2) | Volumen global de cabina | Volante con tres radios y cubo amplio, instrumental con tres básculas, tablero de lado a lado, butacas delanteras con apoyos laterales lisos y centros patrónados, banqueta trasera visible |
| `images (1).jpg` (asientos lado conductor, ampliada ×2) | Butacas, alfombrado y panel de puerta | Butacas altas con reposacabezas independiente sobre postes, palanca de reclinado, tapa de raíles, cinturón con hebilla; alfombra oscura; panel de puerta con inserto de tela, apoyabrazos y tirador |
| `images (12).jpg` (= `INTERIOR ESTEEM.jpg`, consola ampliada ×2) | Palanca y clima a tamaño real | Confirma palanca tipo T/pistón con botón lateral de Overdrive, guía de posiciones con panel de indicación (sin texto legible) y clima con deslizadores |
| `images (6).jpg` (banqueta trasera, ampliada ×2) | Banqueta y respaldos | Banqueta con centros patrónados y apoyos lisos, dos reposacabezas traseros, bolsillos en respaldos delanteros |
| `esteem00int.png` (colage: maletero abierto + instrumental, ampliada ×2) | Maletero y básculas | Maletero amplio y llano con moqueta, aletas de rueda intrusivas y tapa con bisagras; instrumental de tres básculas redondas (tacómetro, velocímetro central 0-200 km/h, reloj de temperatura+combustible) con carátulas oscuras y agujas ámbar |
| `images (8/9).jpg` (piezas de cristaleras), `D_Q_NP_*` (manijas, cerraduras y llaves) | Herrajes y mandos de puerta | Referencia de mandos de cristaleras, tiradores y cerraduras; las llaves/cilindros son herrajes, no se modelan con texto ni marca |
| `ESTEEM_MECHANICAL_NOTES.md` | Confirmar lo ya documentado | Volante de tres radios confirmado; radio cassette doble DIN; cotas de interior siguen sin constar en el manual |

### Decisiones de modelado (F3.2)

- El interior final se genera como **piezas separadas** en un spec declarativo
  nuevo (`data/vehicle/interior_spec.json`, `vehicle.esteem.interior`):
  tablero bitono, instrumental de tres básculas, consola central, radio
  cassette, clima con deslizadores, salidas de aire, guantera con cierre,
  palanca P-R-N-D-2-L con botón de Overdrive, freno de mano, butacas
  delanteras y banqueta trasera, paneles de puerta con inserto de tela,
  alfombrado, techo, maletero y herramientas. Todo con scripts `bpy`
  reproducibles; nada de `.blend` editados a mano.
- Las **telas** se representan con materiales PBR propios de dos tonos (centro
  patrónado simulado con tono de inserto y apoyos lisos): ninguna textura,
  malla o color procede de las fotografías. El pulido fino del tejido y las
  costuras queda para F3.5/F10.1 (mismo criterio que el exterior).
- Las **básculas del instrumental** son geometría sin texto (carátula oscura,
  bisel y aguja ámbar): la señalética visible usa claves de localización.
- **Manos definitivas**: malla propia (palma, cuatro dedos y pulgar) en las
  posiciones de bind de `esteem_hand_rig`, sustituyendo los proxies de caja de
  F2.3 sin tocar `cabin_interaction.json` (v2) ni el rig ni las poses IK.
- **Herramientas del maletero** como objetos reales nombrados con los IDs de
  `inventory_tools.json` (`tool.jack`, `tool.wheel_wrench`, `tool.spare_tire`,
  `tool.boards`, `tool.flashlight`, `tool.screwdriver_set`, `tool.pliers`,
  `tool.adjustable_wrench`, `tool.socket_set`, `tool.jumper_cables`):
  referencia para el inventario de F5.1, sin mecánicas nuevas.
- Sin marcas ni emblemas (Chevrolet, PDV, Suzuki u otras) ni texto visible en
  la malla (alfombrados, guía P-R-N-D-2-L y carátulas sin leyendas; los
  logotipos observados en fotos se omiten).
- Cotas de interior provisionales (`provisional_design_value` /
  `photo_observed_provisional`): no publicar como especificación oficial.

### Descartado

- Copiar imágenes, recortes o texturas de la biblioteca externa al repositorio.
- Reproducir patrones de tela, alfombrados con logotipo ("CHEVROLET" visible en
  `images (1).jpg`), textos de guía de palanca, números de carátula ni
  emblemas de volante.
- Tomar cotas de las fotos como medidas del manual.
- Implementar mecánicas de inventario, reparación o física (F5.1).

## 2026-11-22/23 — Fase 3.3 — lluvia, humedad, limpiaparabrisas y charcos

**Alcance:** revisión visual completa obligatoria antes de F3.3 (`AGENTS.md`,
sección 10). Se usó el catálogo `docs/reference/reference_catalog.json` (95
fichas) y las **hojas de contacto ya existentes** `all_images.jpg` (95 fichas),
`generated_concepts.jpg` (40 conceptos), `exterior_f31_review.jpg`,
`exterior_f31_detail.jpg`, `interior_f32_review.jpg` e `interior_f32_detail.jpg`.
Se generó una hoja de detalle nueva en
`build/reference/contact_sheets/rain_f33_detail.jpg` (12 recortes de parabrisas,
luneta, tablero y conceptos nocturnos; no versionada). **No se cargaron las 40
imágenes en contexto** y **no se copió ningún archivo** de
`C:\Dev\fotos de ejemplo` al repositorio. La biblioteca externa quedó intacta
(escaneo rápido: 95 archivos, sin cambios).

### Referencias utilizadas

| Referencia | Uso | Resultado |
|---|---|---|
| Catálogo de 95 fichas | Buscar fotos dedicadas de lluvia, gotas, charcos, vidrio mojado o limpiaparabrisas | No hay entradas dedicadas; las fotos del Esteem son de exterior/interior seco y las piezas técnicas no muestran agua |
| `all_images.jpg` (hoja de 95 fichas) | Inventario visual completo y descarte de candidatos | Confirmado que no hay una serie de lluvia; los conceptos nocturnos son la única referencia de atmósfera mojada |
| `generated_concepts.jpg` (40 conceptos) | Inspiración de noche, asfalto mojado, reflejos, lluvia en cabina y charcos | Se observan reflejos alargados de faros y letreros, superficies oscuras con brillo y lluvia sobre el parabrisas; **no son canon ni fuente de cotas** |
| `exterior_f31_review.jpg` y `exterior_f31_detail.jpg` | Parabrisas, luneta, base de limpiaparabrisas y paneles | Dos escobillas negras apoyadas en la base del parabrisas; luneta sin limpiaparabrisas; superficie del vidrio lisa y sin marco grueso |
| `interior_f32_review.jpg` e `interior_f32_detail.jpg` | Cabecera del parabrisas, tablero y visibilidad desde la cabina | Confirma la zona de barrido frente al conductor y el espejo interior; el tablero no muestra mandos de limpiaparabrisas identificables en las fotos |
| `rain_f33_detail.jpg` (nueva, no versionada) | Detalle de parabrisas/luneta, tablero y conceptos de lluvia | Base visual para el contrato; no se usó ninguna textura, color o forma de las fotos |
| `images (16).jpg`, `RT_PU_92a67511c7434a42bbdec44622d73a0b.webp`, `D_NQ_NP_992627-MLV113346707105_062026-O.webp`, `images (14/15).jpg`, `images (10).jpg`, `adentro esteem.jpg` | Geometría observada de cristales y limpias | Coherente con las cajas `wiper_left`/`wiper_right` y el panel `windshield` ya declarados en `exterior_spec.json` (F3.1) |
| `ESTEEM_MECHANICAL_NOTES.md` | Confirmar lo ya documentado | El manual disponible no incluye cotas de cristales, ángulos de barrido ni curvas de secado; siguen siendo valores provisionales |

### Decisiones (F3.3)

- No se modela ni texturiza nada: la lluvia de F3.3 es **matemática y contrato**.
  La geometría de parabrisas y escobillas se toma de `exterior_spec.json`; no se
  modifica la malla, el material ni el manifiesto de F3.1.
- El barrido se declara con pivotes en el extremo interior de las cajas de F3.1,
  longitud de 0,46 m, barrido de ±100° y modos off/intermitente/lento/rápido.
  Los ángulos, tiempos y desgaste son `design_value`, no datos del manual.
- La humedad, las gotas y los charcos son valores de diseño calibrables. Las
  fotos reales están secas y los conceptos nocturnos solo inspiran la atmósfera;
  no se derivan cotas ni curvas de ellas.
- Los conceptos de lluvia se usan solo como referencia de **reflejos alargados,
  superficies oscuras y lluvia sobre vidrio**; no se copian colores, texturas ni
  composiciones.
- La zona limpia del parabrisas se modela por sector geométrico con eficiencia
  de goma nueva/gastada; la fusión visual de gotas y el barrido GLSL son F3.4.
- Los charcos se declaran por arquetipos (corona, hundimiento, bache, hombro y
  vado) y el vadeo se enlaza con `vehicle_components.json#specs.water`; la
  mecánica es F5.1.

### Descartado

- Copiar imágenes, recortes o texturas de la biblioteca externa al repositorio.
- Inventar fotos de lluvia o presentar los conceptos de IA como canon.
- Tomar ángulos de barrido, curvas de secado o profundidades de charco de las
  fotos como si fueran medidas.
- Implementar shaders, VFX, arte, pérdida de agarre o vadeo en F3.3.
- Añadir un mando de limpiaparabrisas a `cabin_interaction.json` v2 o reabrir
  F2.3/F2.4.

### Próxima revisión

- Revisión rápida: inicio y cierre de cada subfase.
- Revisión completa: **2026-12-07**, o antes de la subfase de modelado/UI que
  corresponda (obligatoria antes de F3.4/F3.5).

## 2026-11-23 — Fase 3.4 — GLSL de lluvia, gotas, barrido, charcos y VFX

**Alcance:** revisión visual completa obligatoria antes de F3.4 (`AGENTS.md`,
sección 10). Se usó el catálogo `docs/reference/reference_catalog.json` (95
fichas) y las **hojas de contacto** `all_images.jpg` (95 fichas),
`generated_concepts.jpg` (40 conceptos), `rain_f33_detail.jpg`,
`exterior_f31_detail.jpg` e `interior_f32_detail.jpg`. Se generó una hoja de
detalle nueva en `build/reference/contact_sheets/rain_f34_detail.jpg` (12
recortes: cristales/pintura/escobillas reales y conceptos nocturnos de asfalto
mojado, lluvia en cabina y charcos; no versionada). **No se cargaron las 40
imágenes en contexto** y **no se copió ningún archivo** de
`C:\Dev\fotos de ejemplo` al repositorio. La biblioteca externa quedó intacta
(escaneo rápido: 95 archivos, sin cambios).

### Referencias utilizadas

| Referencia | Uso | Resultado |
|---|---|---|
| Catálogo de 95 fichas | Buscar fotos dedicadas de lluvia, gotas sobre pintura, escurrido, charcos o asfalto mojado | Sigue sin haber entradas dedicadas; las fotos reales del Esteem están secas y las piezas técnicas no muestran agua |
| `all_images.jpg` (hoja de 95 fichas) | Inventario visual completo para lookdev de F3.4 | Confirmado el mismo inventario que en F3.3; sin series de lluvia ni superficies mojadas fotografiadas |
| `generated_concepts.jpg` (40 conceptos) | Inspiración de reflejos de faros/neón sobre asfalto mojado, lluvia sobre vidrio y charcos nocturnos | Los reflejos son alargados y estrechos en la dirección de la vista, el asfalto mojado oscurece y brilla, los charcos reflejan fuentes puntuales; **no son canon ni fuente de cotas ni de texturas** |
| `rain_f34_detail.jpg` (nueva, no versionada) | Recortes de cristales, brillo de pintura y conceptos mojados para el lookdev de gotas/película/charcos | Base de aspecto para los shaders: el brillo de la pintura se conserva y la humedad se aporta con película + gotas; no se extrajo ninguna textura ni color |
| `exterior_f31_detail.jpg` | Brillo de pintura, cristales y escobillas apoyadas en la base del parabrisas | La pintura del coche real es lisa con highlight suave; las escobillas son dos brazos negros en reposo en la base, coherentes con `wiper_left`/`wiper_right` de `exterior_spec.json` |
| `interior_f32_detail.jpg` | Base del parabrisas desde la cabina y zona de barrido | La zona limpia visible desde el conductor se corresponde con el sector de barrido de `rain_surface_fx.json` (pivotes UV 0,37/0,63) |
| `ESTEEM_MECHANICAL_NOTES.md` | Confirmar límites de fuente | Sin datos de mojado, ángulo de contacto ni reflectancia del asfalto: los valores del contrato siguen siendo `design_value` |

### Decisiones (F3.4)

- El GLSL **consume** la matemática de F3.3 (`SurfaceWetnessModel`,
  `DropletFlowModel`, `WiperKinematics`, `PuddleModel`): los shaders reciben
  instancias/uniformes ya calculados y no reimplementan simulación.
- La fusión visual de gotas vecinas se hace en el shader (ruido determinista de
  celdas), sin comparaciones O(n²) en CPU, tal como anticipa el contrato.
- El aspecto mojado se logra oscureciendo la albedo con la película y subiendo la
  especular/reflejo; no se pintan texturas nuevas ni se copian de las fotos.
- El barrido renderizado usa la cinemática `smoothstep` de F3.3 y la eficiencia
  de goma gastada deja estela; sin mando nuevo en `cabin_interaction.json` v2.
- Los charcos visibles se limitan a los arquetipos del contrato con
  `visible_depth_mm`; hidroplaneo y vadeo siguen reservados a F5.1.
- El presupuesto GPU del contrato (`budgets.*.gpu`) se mide con render real en
  esta subfase (draw calls, overdraw, fill rate, frame time) y se documenta.

### Descartado

- Copiar imágenes, recortes o texturas de la biblioteca externa al repositorio.
- Extraer mapas de normal/roughness de las fotos o de los conceptos de IA.
- Presentar los conceptos nocturnos como canon o tomar de ellos valores de
  reflectancia, profundidad de charco o intensidad de lluvia.
- Implementar pérdida de agarre, daño, vadeo o anti-atasco (F5.1).
- Reabrir F2.1–F3.2 ni duplicar la simulación de F3.3 en el shader.

### Próxima revisión

- Revisión rápida: inicio y cierre de cada subfase.
- Revisión completa: **2026-12-07**, o antes de la subfase de modelado/UI que
  corresponda (obligatoria antes de F4.3/F5.1).

## 2026-11-23 - Fase 3.5 - medicion y capturas (sin uso de referencias)

**Alcance:** integracion, compresion, warm-up, rendimiento y capturas de
referencia visual. Subfase de medicion: no se consulta la biblioteca externa.

### Referencias utilizadas

| Familia | Uso | Resultado |
|---|---|---|
| Ninguna | - | Revision rapida scan_reference_library.py --quick al inicio y al cierre: 95 archivos, sin cambios; no se cargo ninguna imagen en contexto |

### Decisiones

- Las capturas de la subfase (uild/logs/render/f35_*.png y las de ADB) son
  del juego real, se generan con la prueba de render/ruta y no se copia nada de
  C:\Dev\fotos de ejemplo.
- La medicion de fill/overdraw se hace con una sonda aditiva calibrada sobre
  el render real, sin extraer texturas ni valores de las fotos.
- Los presupuestos se contrastan con udgets.*.gpu del contrato; los
  resultados se documentan en CURRENT.md y RAIN_AND_SURFACE_FX.md.

### Descartado

- Usar capturas de la biblioteca externa como evidencia o capturas de tienda.
- Ajustar el lookdev de la lluvia a partir de fotos (sigue siendo design_value
  hasta F4.4/F5.1).

### Proxima revision

- Revision rapida: inicio y cierre de cada subfase.
- Revision completa: **2026-12-07**, o antes de la subfase de modelado/UI
  que corresponda (obligatoria antes de F4.3/F5.1).

## 2026-11-24 — Fase 4.1 — red de rutas OSM/DEM

**Alcance:** pipeline de datos OSM/Overpass, DEM, grafo, rutas alternativas,
caché y atribución ODbL. No es una subfase de modelado ni de UI: no se consultó
ninguna imagen de la biblioteca externa.

### Referencias utilizadas

| Familia | Uso | Resultado |
|---|---|---|
| Catálogo externo (`reference_catalog.json`) | Revisión rápida de relevancia para F4.1 | 95 entradas; las imágenes de paisajes/conceptos están marcadas para F4.3, no para esta fase. Se revisaron solo metadatos. |
| OpenStreetMap / Overpass | Base vial real de Venezuela | Extracción `2026-11-24T04:23:03Z`: 17.756 ways troncales/primarias + 9.638 secundarias; red comprimida de 329 nodos/413 aristas; atribución ODbL. |
| Mapzen Terrain Tiles / SRTM / GMTED2010 / ETOPO1 | Elevación de la red | 155 teselas Terrarium z10; elevación por nodo/arista; atribución en `CREDITS.md` y en el artefacto. |
| Conceptos de paisajes (Gemini) | Dirección visual de biomas | **No usados en F4.1**; quedan para F4.3. |

### Decisiones

- No se copió ninguna imagen ni PDF de `C:\Dev\fotos de ejemplo`. Las respuestas
  OSM y las teselas DEM viven en `build/` y no se versionan.
- La red es una base de datos derivada de OSM bajo ODbL 1.0; se añadió el texto
  de licencia y la atribución visible en Boot, `CREDITS.md` y la web.
- La elevación se usa como referencia de pendientes y de F4.2, no como DEM de
  precisión ni para navegación.
- Las rutas alternativas son caminos reales de la misma base OSM; no se
  dibujaron a mano ni se inspiraron en los conceptos de IA.
- El escaneo rápido detectó tres vídeos nuevos del Esteem (2009/2021/2023);
  son referencias del vehículo y no se usan en esta subfase.

### Descartado

- Usar las fotos de paisajes o los conceptos Gemini como datos de ruta.
- Introducir nombres visibles de vías o marcas en el artefacto (solo `ref`).
- Versionar teselas DEM, respuestas Overpass o la vista previa de build.

### Próxima revisión

- Revisión completa obligatoria antes de **F4.3** (kits de biomas) o el
  **2026-12-06**, lo que ocurra primero.

## 2026-11-24 — Fase 4.2 — terreno, sectores de 800 m y streaming

**Alcance:** subfase de terreno/streaming. No es una subfase de modelado ni de
UI: no se abrió ninguna imagen de la biblioteca externa. Se revisaron solo los
metadatos del catálogo y el artefacto OSM/DEM de F4.1. **No se cargaron las 95
fichas en contexto** y **no se copió ningún archivo** de
`C:\Dev\fotos de ejemplo` al repositorio. La biblioteca externa quedó intacta;
el escaneo rápido detectó 3 vídeos nuevos del Esteem (2009/2021/2023) que no se
usan en esta subfase.

### Referencias utilizadas

| Familia | Uso | Resultado |
|---|---|---|
| Catálogo externo (`reference_catalog.json`, 95 fichas) | Revisión rápida de relevancia para F4.2 | Ninguna ficha está marcada para F4.2; las de paisajes/biomas son F4.3 y las del vehículo F1–F3/F5. Se revisaron solo metadatos. |
| Red OSM/DEM de F4.1 (`route_network.json`, manifiesto) | Base del terreno, la vía, la elevación y la atribución | 329 nodos/413 aristas; 454 sectores horneados; ODbL 1.0; sin teselas ni respuestas crudas versionadas. |
| Conceptos de paisajes (Gemini) | Dirección visual de biomas | **No usados en F4.2**; quedan para la revisión completa de F4.3. No se derivaron colores, texturas ni formas. |
| 3 vídeos nuevos del Esteem | Inventario | Catalogados como referencia de vehículo; no se usan en terreno/streaming. La revisión completa queda para F4.3/F5.1. |

### Decisiones

- El terreno es **procedural y greybox**, generado desde la red y la DEM de
  F4.1; no se usan texturas, fotografías ni conceptos de IA como asset.
- No se incorpora el addon nativo Terrain3D: se usa `ArrayMesh` propio (MIT) por
  compatibilidad, empaquetado y control del presupuesto. La decisión y la
  licencia están en `WORLD_STREAMING.md`.
- La paleta nocturna (verde petróleo, ámbar, hueso) se mantiene de F1.1; el
  terreno/vía no introduce una dirección de arte nueva ni marcas.
- La atribución ODbL se conserva en el cielo/overlay (`CREDITS_OSM`), en
  `CREDITS.md`, en la web y en el manifiesto de sectores.
- Los 3 vídeos nuevos se dejan para la revisión visual completa; no se extraen
  fotogramas en F4.2.

### Descartado

- Copiar imágenes, texturas, recortes o fotogramas de la biblioteca externa.
- Usar los conceptos de IA como canon o como capturas de tienda.
- Presentar el terreno greybox como arte final o como dato topográfico.
- Tomar cotas, colores o materiales de las fotos para el terreno/vía.

### Próxima revisión

- Revisión completa **obligatoria antes de F4.3** (kits de biomas) o el
  **2026-12-06**, lo que ocurra primero. Incluye los 3 vídeos nuevos, los
  conceptos de paisajes y las fichas de biomas/POIs.
- Revisión rápida: inicio y cierre de cada subfase.
