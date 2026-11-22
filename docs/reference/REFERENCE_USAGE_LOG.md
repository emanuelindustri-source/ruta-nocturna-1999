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

## Próxima revisión

- Revisión rápida: inicio y cierre de cada subfase.
- Revisión completa: **2026-12-06**, o antes de la subfase de modelado/UI que
  corresponda.
