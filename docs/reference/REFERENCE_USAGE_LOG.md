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

## Próxima revisión

- Revisión rápida: inicio y cierre de cada subfase.
- Revisión completa: **2026-12-06**, o antes de la subfase de modelado/UI que
  corresponda (obligatoria antes de F3.1 y F3.2).
