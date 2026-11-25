# Terreno, sectores de 800 m y streaming (Fase 4.2)

**Estado:** implementado y validado en `v0.4.1`.  
**Contrato:** `data/schemas/world_streaming.json` (`world.streaming` v1).  
**Escena:** `scenes/world/WorldTerrain.tscn`.  
**Carga:** `src/world/sector_streamer.gd` (`WorldSectorStreamer`).  
**Prueba:** `tests/world/WorldStreamingTest.tscn` / `tools/dev/world_streaming_test.cmd`.

## 1. Alcance

F4.2 convierte la red OSM/DEM de F4.1 en un mundo jugable de presentación:

- terreno procedural de 800 m por sector, con vía, arcén, línea central y colisión;
- streaming por secuencia de ruta con `ResourceLoader.load_threaded_request()`;
- máximo **dos** solicitudes simultáneas y cero `load()` síncrono durante la conducción;
- punto de reaparición seguro sobre la red y con colisión;
- medición de carga, triángulos, frame pacing y PSS.

No incluye biomas, POIs, gasolineras, clima, lluvia real, tráfico, fauna,
conducción física ni anti-atasco completo. Esos sistemas son F4.3, F4.4, F5.1 y
F5.2.

## 2. Decisión: malla propia, no addon Terrain3D

`CREDITS.md` reservaba Terrain3D como candidato. En F4.2 se evaluó y **no se
incorporó**:

- Terrain3D es un addon nativo/GDExtension; exige una compilación compatible con
  la versión exacta del motor y un binario por plataforma. El proyecto usa Godot
  4.7.2 y builds Windows/Android sin Gradle.
- Introduce una dependencia nativa que debe cumplir alineación de páginas de
  16 KB en Android, empaquetado ABI y verificación de licencia MIT.
- La red de F4.1 ya entrega la elevación y la polilínea; un generador propio
  reproducible evita un binario opaco y permite controlar el presupuesto de
  triángulos por sector.

La implementación es **propia** (`ArrayMesh` + `ConcavePolygonShape3D`), con
licencia MIT del proyecto, sin texturas externas. El contrato declara
`third_party_addon: null` y la decisión queda registrada en este documento.

## 3. Flujo

```text
route_network.json (F4.1)
        │
        ▼
tools/world/bake_world_sectors.gd  ──►  data/content/world/sectors/*.res
        │                                      + sectors.manifest.json
        ▼
WorldDirector (servicio de escena)
        │  RouteNetwork + world_streaming.json + manifiesto
        ▼
WorldSectorStreamer ── ResourceLoader.load_threaded_request() (máx. 2)
        │  una construcción de malla/colisión por frame
        ▼
WorldSectorBuilder ── ArrayMesh (terreno + vía) + StaticBody3D
        │
        ▼
WorldTerrain.tscn: vehículo de presentación, cámara, overlay y sonda de rendimiento
```

`WorldDirector` no es autoload. `RouteNetwork` tampoco. No se añadieron
autoloads ni dependencias circulares.

## 4. Sectores de 800 m

Cada sector es una celda alineada de **800 × 800 m** en el espacio de juego
(proyección 1:20 de F4.1). Se hornean 454 sectores que cubren la red completa
(413 aristas y sus 18 rutas).

| Campo | Valor |
|---|---|
| Tamaño de sector | 800 m |
| Rejilla de altura | 33 × 33 vértices (25 m) |
| Triángulos de terreno | 2.048 por sector |
| Vía | 7,2 m de ancho, arcén de 2,2 m, línea central discontinua |
| Altura de vía | elevación DEM + 0,06 m |
| Terreno bajo la vía | elevación DEM − 0,18 m en un radio plano de 12 m |
| Relieve | ruido determinista (2 octavas, 420 m, ±18 m, tope ±28 m) |
| Colisión | `StaticBody3D` + `ConcavePolygonShape3D` de vía y de terreno (paso 2, 512 triángulos) |
| Atribución | © OpenStreetMap contributors · ODbL 1.0 |

La altura de cada vértice se calcula con el punto de ruta más cercano en una
rejilla espacial de 100 m. El resultado es determinista y continuo entre
sectores: los vértices de borde comparten coordenada y altura. Cuatro sectores
de borde solo contienen terreno (no centro de vía) porque la caja de la vía
toca su celda; se conservan para no dejar huecos y se declaran en el manifiesto.

### 4.1 Recurso `WorldSectorData`

`src/world/world_sector_data.gd` es un `Resource` con:

- `sector_x`, `sector_z`, `sector_size_m`, `grid_resolution`, `grid_spacing_m`;
- `heights` (`PackedFloat32Array`, 33×33);
- `road_vertices` y `marking_vertices` (sopa de triángulos);
- `road_edge_ids`, longitud, alturas mínima/máxima y contadores;
- atribución ODbL.

No contiene mallas ni colisión serializadas: `WorldSectorBuilder` las construye
en el hilo principal a partir de los datos. Así el recurso pesa unos kilobytes y
la carga threaded no bloquea por geometría.

### 4.2 Horneado reproducible

```powershell
.\tools\dev\bake_world_sectors.cmd
```

El comando importa el proyecto, lee el contrato y la red, limpia los `.res`
anteriores, hornea los 454 sectores y escribe `sectors.manifest.json` con
SHA-256, tamaño, triángulos y cobertura por arista. El manifiesto también
registra el hash de la red y del contrato. Los `.res` son binarios y están
marcados como tales en `.gitattributes`; no se editan a mano.

## 5. Streaming asíncrono

- La secuencia de sectores se deriva del orden real de cada ruta principal.
- Ventana: **3 sectores por delante**, **2 por detrás** y **2 de margen** para
  descarga; máximo 10 residentes.
- `WorldSectorStreamer` llama **solo** a
  `ResourceLoader.load_threaded_request()` para los sectores. No hay `load()`
  de sector en runtime.
- Se inician como máximo **2** solicitudes simultáneas; las demás esperan en una
  cola priorizada (actual, +1, −1, +2, −2, +3, −3).
- La malla y la colisión se construyen como máximo **una por frame** para evitar
  picos. La carga threaded puede terminar varias solicitudes en un frame; las
  pendientes se construyen en frames posteriores.
- `is_idle()` y `initial_ready` permiten a la escena ocultar el overlay de carga
  hasta tener la ventana inicial completa.
- Si un sector falta o falla, se registra en `sector_errors` y se emite
  `sector_failed`; no se congela el tour.

La primera carga de la escena incluye RouteNetwork (JSON), el manifiesto y las
solicitudes threaded. La carga del grafo se mide aparte
(`network_load_ms`) contra `budgets.runtime_load_budget_ms` (250 ms).

## 6. Colisión y reaparición segura

Cada sector añade:

- `StaticBody3D` (`collision_layer=1`, `mask=1`);
- `CollisionShape3D` con `ConcavePolygonShape3D` para terreno, con paso 2
  (17×17 vértices / 512 triángulos) para reducir el coste de construcción;
- `CollisionShape3D` con `ConcavePolygonShape3D` para la vía.

`WorldDirector.safe_respawn_point()` proyecta un punto sobre la ruta, lanza un
raycast descendente y acepta el punto si la pendiente es ≤ 20 %. Si no hay
colisión, prueba offsets de ±50/±120/±250 m y, como último recurso, el hub de
recuperación `hub_carabobo`. F4.2 valida el punto; la grúa, la deuda y el
anti-atasco completo son F5.1.

## 7. Escena de presentación

`WorldTerrain.tscn` muestra el terreno con el exterior del Esteem como vehículo
de presentación. El vehículo **no** tiene física de conducción: recorre la ruta
con una cámara de persecución y sirve para validar el streaming, la colisión y
el aspecto. El overlay muestra ruta, progreso, sectores cargados, triángulos,
FPS y tiempo de carga del grafo. Botones de 48 px permiten cambiar de ruta y
volver; el teclado usa `N` (siguiente ruta), `R` (reinicio), `Espacio`
(pausa), `RePág`/`AvPág` (±2 km para QA) y `Esc`.

El Boot ofrece `UI_VIEW_WORLD` y el tour arranca en `route.carabobo_falcon`.
La atribución ODbL (`CREDITS_OSM`) es visible en el overlay y en el Boot.

## 8. Presupuestos

| Presupuesto | Valor | Resultado F4.2 |
|---|---|---|
| Sector | 800 m | 800 m |
| Solicitudes simultáneas | 2 | 2 (pico medido en PC y Android) |
| `load()` síncrono en conducción | 0 | 0 |
| Sectores residentes | ≤ 10 | 8 de pico (PC y Android); 6–8 típicos |
| Triángulos por sector | ≤ 3.000 | 2.048 terreno + ≤ 328 vía |
| Triángulos visibles Android | ≤ 120.000 | **18.802** (mundo), 15.874 (rebanada), 7.404 (cabina) |
| Triángulos visibles PC | ≤ 450.000 | **15.952** (sonda) / 19.364 (captura manual) |
| PSS Android | ≤ 1.228,8 MB | **630,5 MB** mundo; 509,6 rebanada; 646,0 cabina |
| Carga del grafo | ≤ 250 ms | **44 ms** PC; **76 ms** Android |
| Carga inicial de escena | ≤ 20 s | **2771 ms** Android; 515 ms PC (medidos) |
| Frame Android | ≤ 33,333 ms | **8,52 ms** medio; **9,50 ms** p95; máx 24,5 ms |
| Frame PC | ≤ 16,667 ms objetivo | **16,66 ms** medio; 17,15 ms p95; máx 20,01 ms |
| Construcción de sector | ≤ 1 por frame | 3,76 ms medio en PC; 10,45 ms en Android |

La medición de dispositivo se hace con `tools/test_android_adb.ps1`, que ejecuta
la ruta `slice,cabin,world`, captura pantalla y PSS de cada escena y valida el
bloque `world` del reporte (sectores, solicitudes, errores y carga del grafo).
La medición de PC se hace con el mismo `DevicePerfProbe` sobre el build exportado
y capturas reales; los resultados se registran en
`build/logs/gameplay/REPORT_F42.md` (no versionado).

### 8.1 Resultados medidos (v0.4.1)

- **PC (build Windows, Forward+, ventana 1280×720):** mundo con 515 ms de carga,
  16,66 ms de frame medio (60 FPS), 15.952 primitivas, 113 draw calls, 8 sectores
  y 24.682 triángulos de streaming; grafo 44 ms; construcción media 3,76 ms;
  pico de 2 solicitudes; 0 `load()` síncrono; 0 errores. La captura manual a
  0,8 km mostró 19.364 triángulos y 60 FPS.
- **Redmi 22101316G (Android 13, renderer Mobile):** mundo con 2.771 ms de carga,
  8,52 ms de frame medio, 9,50 ms p95 y 24,5 ms máximo; 18.802 primitivas y 112
  draw calls; 7 sectores y 24.147 triángulos; grafo 76 ms; construcción media
  10,45 ms; pico de 2 solicitudes; 0 carga síncrona; 0 errores. PSS 630,5 MB.
- **Arranque Android:** 0,9 s; PSS de arranque 404,4 MB; sin `FATAL EXCEPTION`
  ni errores Godot/Vulkan en 15 s de logcat.
- **Toque manual:** Boot → «Ver mundo» abre la escena del mundo en el Redmi
  (`f42_android_world_touch2.png`). El dispositivo mantiene la orientación
  retrato con bandas negras (H4, preexistente); no afecta a los presupuestos ni
  al toque, pero se revisará en F9.1/F10.2.

## 9. Validación

```powershell
.\.venv\Scripts\python.exe tools\validate_schemas.py
.\.venv\Scripts\python.exe tools\world\validate_world_sectors.py
.\tools\dev\world_streaming_test.cmd
```

`validate_schemas.py` valida el contrato y el JSON Schema y ejecuta
`tools/world/validate_world_sectors.py`, que:

- recalcula los sectores esperados desde las 413 aristas de la red;
- verifica que no falte ninguno para las seis rutas principales;
- comprueba SHA-256 y tamaño de los 454 recursos;
- contrasta presupuestos, atribución ODbL y cobertura.

`WorldStreamingTest`:

- carga y valida los 454 recursos;
- instancia la escena real y espera `world_ready`;
- comprueba `network_load_ms ≤ 250`, la ventana inicial, los triángulos,
  `sync_load_calls == 0`, el pico de solicitudes ≤ 2 y los residentes ≤ 10;
- hace raycast sobre la vía y valida `safe_respawn_point`;
- avanza 12 km y comprueba descarga/carga de sectores;
- cambia de ruta y repite las comprobaciones;
- recorre las seis rutas al 10/50/90 % y comprueba que la ventana se recupera;
- cierra con **99 comprobaciones OK**.

## 10. Limitaciones conocidas

- La proyección sigue siendo 1:20 y la DEM Terrarium z10 (~150 m/píxel) es de
  referencia, no topográfica. No resuelve puentes, túneles ni cortes de ladera.
- El terreno es greybox de F4.2: sin biomas, materiales por región, vegetación
  ni POIs. Esos son F4.3.
- El relieve procedural no sustituye a la DEM en zonas alejadas de la red: solo
  se hornean sectores que tocan la red.
- La vía es una cinta de 7,2 m sin carriles detallados, señales, arcenes
  diferenciados ni cruces. F4.3 añade el kit vial y los POIs.
- No hay física de conducción ni vehículo `VehicleBody3D`: el coche de la escena
  es una presentación cinemática. La conducción es F5.
- La lluvia, la humedad real y el clima no están conectados: F4.4.
- Los sectores usan una sola resolución (no LOD0/1/2) porque son mallas
  procedimentales de terreno, no modelos de la fábrica. La política LOD se
  aplica a los assets 3D del vehículo y de F4.3.
- Cuatro sectores de borde no tienen centro de vía y solo aportan terreno; no
  son un error de cobertura.
- La red comprimida no resuelve cruces a distinto nivel: dos vías cercanas pueden
  dibujarse como cintas solapadas o puentes sin estructura. F4.3 puede añadir
  kits de puente/cruce; no se corrigió en F4.2 para no reabrir la red de F4.1.
- **H4 (→ F9.1/F10.2):** el juego se ejecuta en **retrato** en el Redmi y la
  vista 1280×720 queda con bandas negras arriba y abajo. Es una configuración
  preexistente (`window/handheld/orientation=1`), no un fallo de F4.2; el toque
  y los presupuestos funcionan. Se revisará la orientación/letterbox en la fase
  de menús y QA de dispositivo.

## 11. Licencia y atribución

Los sectores son una **base de datos derivada** de la red OSM de F4.1. Se
distribuyen bajo **ODbL 1.0**, conservan © OpenStreetMap contributors y el
share-alike. El texto completo está en `licenses/ODbL-1.0.txt`. La elevación se
atribuye a Mapzen/Tilezen, USGS (SRTM/GMTED2010) y NOAA (ETOPO1) en `CREDITS.md`
y en `route_network.manifest.json`.

El generador, los shaders de terreno/vía y la escena son código MIT del
proyecto. No se copió ninguna imagen, textura o fotograma de la biblioteca
externa.

## 12. Handoff a F4.3

**Consumido en F4.3 (`v0.4.2`)** con el contrato aditivo `world.biomes` v1 y la
nota de arquitectura `docs/architecture/WORLD_BIOMES.md`: los materiales
procedurales de terreno se tiñen por bioma, y el decorado, los POIs y el agua
visual se añaden dentro del presupuesto de 3.000 triángulos por sector, sin
cambiar este contrato ni la carga threaded.

F4.3 (MiMo Pro) puede:

- usar `WorldDirector` y `WorldSectorStreamer` como base para biomas y POIs;
- sustituir los materiales procedurales por kits de bioma sin cambiar el
  contrato `world.streaming` (si cambia la estructura, subir `schema_version`);
- añadir vegetación, gasolineras, moteles, peajes, señalización y agua como
  contenido de sector, respetando el presupuesto de 2.048 triángulos de terreno
  y ≤ 3.000 por sector;
- mantener la carga threaded, el máximo de dos solicitudes y la atribución ODbL.

No se debe reabrir F4.1 ni cambiar las rutas/artefacto sin pipeline y migración.
