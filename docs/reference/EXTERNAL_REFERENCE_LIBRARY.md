# Biblioteca externa de referencias

**Ruta:** `C:\Dev\fotos de ejemplo`  
**Naturaleza:** material privado de referencia, **no** banco de assets.  
**Acceso:** solo lectura, nunca se modifica ni se versiona.

## Inventario actual

Inventario completo al **2026-11-22**:

| Tipo | Cantidad |
|---|---:|
| Fotografías y páginas de vehículo | 49 |
| Conceptos de arte/UI generados con Gemini | 39 |
| PDF técnico / manual / contexto | 3 |
| Documento de leyendas | 1 |
| Videos conceptuales | 2 |
| **Total** | **94** |
| Tamaño | **≈306.9 MB** |

El inventario creció durante la Fase 1.1 con nuevos archivos aportados por el
director entre las 13:54 y 13:59 del 22 de noviembre de 2026. Todos fueron
detectados por el scanner y entraron en el catálogo.

Duplicados exactos detectados:

- `Gemini_Generated_Image_rc0h8yrc0h8yrc0h (1).png` = versión original.
- `images (12).jpg` = `INTERIOR ESTEEM.jpg`.

## Qué contiene

- Interior beige, telas, tablero, consola, palanca automática y volante.
- Fotos del motor, caja automática, correa, bomba de freno, filtro de aceite,
  convertidor de par, arrancadores y soportes.
- Páginas de manual de servicio y fichas técnicas del motor 1.3L/1.6L.
- 39 ideas visuales del juego: menús, rutas, garaje, inventario, bestiario,
  modo foto, gasolinera, motel, páramo, fauna y cabina.
- Dos videos de 10 segundos y 1280×720.
- Un DOCX con 18 leyendas venezolanas.

## Reglas

1. El escaneo se ejecuta al inicio y cierre de cada subfase:

   ```powershell
   .\.venv\Scripts\python.exe tools\scan_reference_library.py --quick
   ```

2. Revisión visual completa cada **14 días** o antes de una subfase de modelado,
   arte o UI. Las hojas de contacto se generan en `build/reference/contact_sheets/`.
3. El texto extraído de manuales va a `build/reference/extracted/`; no se commitea.
4. El catálogo versionado solo contiene metadatos y hashes:
   `docs/reference/reference_catalog.json`.
5. Cada uso relevante se anota en `REFERENCE_USAGE_LOG.md`.
6. No se usan imágenes en el juego, la web, las tiendas ni el build sin licencia
   compatible y manifiesto.
7. No se copian logos Chevrolet, PDV u otras marcas.
8. Las fotos y manuales tienen licencia desconocida o propietaria: **reference only**.
9. `clean_workspace.ps1` excluye esta carpeta.
10. Si el material se agota o no es legible, se informa; no se inventan detalles.

## Prioridad de fuentes

1. Manual de servicio y fichas técnicas verificables.
2. Fotografías reales del vehículo.
3. Fuentes históricas o técnicas citadas.
4. Conceptos visuales y arte de IA.

Las imágenes generadas por IA son **ideas**, no canon técnico. Los conceptos con
muchos botones táctiles quedan anulados por el nuevo diseño contextual. No se
copiarán “roguelike”, monetización, cinco noches ni entidades no aprobadas.

## Hitos de revisión

- F1.1: inventario, catálogo, hojas de contacto, extracción inicial.
- F2.2: interior, palanca, consola, tablero y volante.
- F3.1–3.4: proporciones, materiales, lluvia y visuales.
- F4.3: biomas, gasolinera, motel, páramo, selva y Delta.
- F5.1/5.3: motor, refrigeración, transmisión, herramientas y piezas.
- F7.1/7.3: leyendas y personajes.
- F9.2: dirección de UI, respetando la interacción contextual.
- F10.2: solo inspiración para material promocional original.

La próxima revisión completa vence el **2026-12-06**.
