# Créditos y procedencia

## Proyecto

**Ruta Nocturna: 1999**  
Dirección y concepto: **Khristyan Hidalgo** (`emanuelindustri-source`)  
Arquitectura, código, modelado procedural, audio, pruebas y publicación: **OpenCode**

## Estado de assets

Esta fase no incluye todavía modelos, texturas, voces ni música finales. Los assets
se añadirán con manifiesto de procedencia, licencia, hash y comando de generación.

## Bibliotecas y datos previstos

| Recurso | Licencia | Uso |
|---|---|---|
| Godot Engine 4.7.2 | MIT | Motor |
| Blender 4.5.16 LTS | GPL-2.0-or-later (herramienta) | Generación de arte 3D |
| Terreno procedural propio (F4.2) | MIT del proyecto; sin addon nativo | Terreno, vía y streaming de sectores |
| OpenStreetMap / Overpass | ODbL 1.0 | Datos viales |
| Fuentes Noto | SIL OFL 1.1 | Interfaz multilingüe |
| Python, numpy, scipy, Pillow, pypdf | Licencias permisivas respectivas | Herramientas de producción |

## Biblioteca externa de referencias

`C:\Dev\fotos de ejemplo` contiene fotografías y conceptos aportados por el director.
Se usa exclusivamente como referencia visual y técnica. No se redistribuye.

- Las fotografías y capturas tienen licencia desconocida: **solo referencia**.
- Las imágenes generadas con Gemini son **ideas de arte**, no assets canónicos.
- El manual de servicio se usa para consultar datos técnicos, no se redistribuye.
- Las leyendas se contrastarán con fuentes adicionales; el DOCX no se copiará al juego.

## Marcas

Chevrolet, Esteem, PDV y cualquier otra marca mencionada pertenecen a sus titulares.
El proyecto no reclama patrocinio ni afiliación. Los emblemas y marcas se omitirán o
sustituirán hasta que exista una autorización explícita.

## Atribución OSM

Cualquier build que use datos derivados de OpenStreetMap deberá mostrar:

> © OpenStreetMap contributors — ODbL 1.0  
> https://www.openstreetmap.org/copyright

### Red de rutas (Fase 4.1)

La red de rutas de `data/content/world/route_network.json` es una **base de
datos derivada** de OpenStreetMap, calculada con `tools/osm/build_world_routes.py`.
Se distribuye bajo **Open Database License (ODbL) 1.0**; el texto completo está
en `licenses/ODbL-1.0.txt`.

- Copyright de los datos: **© OpenStreetMap contributors**.
- Licencia: **ODbL 1.0** — https://opendatacommons.org/licenses/odbl/1-0/
- Copyright y atribución: https://www.openstreetmap.org/copyright
- Atribución en el juego: clave `CREDITS_OSM` en los once idiomas.
- Fecha de la base OSM y hashes de las consultas: manifiesto
  `data/content/world/route_network.manifest.json`.
- La red comprimida se ofrece bajo la misma licencia; los cambios y la
  simplificación están documentados en `docs/architecture/WORLD_ROUTES.md`.
- Los **sectores de terreno de 800 m** de F4.2
  (`data/content/world/sectors/*.res`) son una base derivada de esa red y se
  distribuyen bajo ODbL 1.0 con la misma atribución. El terreno y la vía se
  generan con código MIT del proyecto; no se usa el addon Terrain3D ni ninguna
  textura de la biblioteca externa.

### Elevación (DEM)

- Teselas Terrarium de **Mapzen/Tilezen** (`elevation-tiles-prod`).
- **SRTM** y **GMTED2010** cortesía del **U.S. Geological Survey**.
- **ETOPO1** cortesía de **NOAA** (National Centers for Environmental Information).
- Atribución completa: https://github.com/tilezen/joerd/blob/master/docs/attribution.md
- La elevación se muestrea solo en el pipeline de build; el juego no consulta
  teselas ni servicios en runtime. Los datos no son aptos para navegación.

La atribución se muestra en la pantalla de arranque, en este archivo y en la web
del proyecto. No se usa ninguna imagen de la biblioteca externa como asset ni
como captura de tienda.
