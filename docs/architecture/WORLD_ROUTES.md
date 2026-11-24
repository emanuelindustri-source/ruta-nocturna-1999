# Rutas del mundo: OSM, DEM y grafo (Fase 4.1)

**Estado:** contrato `world.routes` v1 y red generada, cerrados en `v0.4.0`.  
**Contrato:** `data/schemas/world_routes.json`  
**Red:** `data/content/world/route_network.json`  
**Manifiesto:** `data/content/world/route_network.manifest.json`  
**Herramienta:** `tools/osm/build_world_routes.py`  
**Prueba:** `tests/world/WorldRoutesTest.tscn` / `tools/dev/world_routes_test.cmd`

## 1. Alcance

F4.1 construye la **base de datos vial** del mundo y sus rutas principales y
alternativas. No genera terreno, sectores de 800 m, colisión, biomas, POIs,
clima ni tráfico: eso corresponde a F4.2, F4.3 y F4.4.

La red es una base de datos derivada de **OpenStreetMap** y se distribuye bajo
**ODbL 1.0**. La elevación se muestrea de teselas **Terrarium** (Mapzen/Tilezen)
en tiempo de build. El juego no consulta OSM, Overpass ni DEM en runtime.

## 2. Contrato `world.routes` v1

Secciones:

| Sección | Contenido |
|---|---|
| `world_bounds` / `projection` | Límites WGS84 y proyección equirectangular local 1:20 |
| `regions` | Seis regiones, centro, hub, radio de influencia y elevación esperada |
| `extract` | Fuente OSM, endpoints Overpass, dos consultas, licencia y caché |
| `dem` | Terrarium z10, muestreo por distancia, suavizado y atribución |
| `graph_rules` | IDs, snap máximo, separación de muestras, longitud máxima, grado y pendiente |
| `highway_classes` | Autopista, troncal, primaria y secundaria con velocidad de diseño |
| `routes` | Seis pares obligatorios del anillo de campaña, alternativas y topes |
| `alternatives` | Método de camino más corto penalizado y selección |
| `cache` | Rutas de caché, artefactos versionados y comandos de regeneración |
| `budgets` | Nodos, aristas, bytes, referencias por ruta y carga runtime pendiente F4.2 |
| `attribution` | ODbL, copyright, avisos, clave `CREDITS_OSM` y archivo de licencia |
| `anti_softlock` | Hub de recuperación, conectividad y recálculo de ruta |
| `states` | Estados de carga de red y de ruta |
| `qa` | Comprobaciones, escena y comando de prueba |

Los contratos de F1–F3.5 **no se modificaron**. `world_routes` es un contrato
nuevo y aditivo.

## 3. Pipeline

```text
Overpass (2 consultas) → grafo nacional OSM → snap de hubs → Dijkstra
      → alternativas penalizadas → grafo comprimido → muestreo por distancia
      → DEM Terrarium → rutas y estadísticas → validación → artefacto + manifiesto
```

Pasos:

1. **Fuentes OSM.** Se consultan dos extractos de Venezuela con `out tags geom`:
   - `ve_trunk_primary`: `motorway|trunk|primary` (17.756 ways).
   - `ve_secondary`: `secondary` (9.638 ways).
   - Caja: `0.6,-73.5,12.5,-59.8`; base OSM del extracto:
     `2026-11-24T04:23:03Z`.
2. **Grafo nacional.** Nodos por coordenada OSM redondeada a 7 decimales; aristas
   con distancia haversine y clase. En aristas paralelas se conserva la clase más
   rápida y, a igualdad, la más corta.
3. **Hubs.** Cada región se engancha al nodo OSM más cercano (máximo 5 km). Los
   seis quedan entre 59 m y 1.069 m de su centro.
4. **Rutas principales.** Dijkstra con coste de **tiempo de viaje** según la clase
   de vía, para preferir autopistas/troncales.
5. **Alternativas.** Se recalcula el camino con las aristas del principal
   penalizadas ×3 y se aceptan solo si cumplen desvío y solapamiento del
   contrato. No se dibujan rutas a mano.
6. **Compresión.** Se unen los caminos elegidos, se marcan hubs, intersecciones,
   cambios de clase/uso y cortes cada 40 km, y se generan aristas entre nodos
   importantes. El grafo final tiene **329 nodos y 413 aristas**.
7. **Geometría y DEM.** Cada arista se muestrea cada **500 m de recorrido** (no
   por cercanía espacial), se consulta Terrarium z10 y se aplica limpieza de
   picos y media móvil de 3 puntos. La pendiente se calcula con la distancia de
   recorrido, no con la cuerda entre muestras.
8. **Validación.** El pipeline ejecuta las mismas comprobaciones que
   `tools/validate_schemas.py`: IDs, extremos, conectividad, rutas continuas,
   alternativas, elevación, pendiente, ODbL, presupuestos y hash del manifiesto.
   Si algo falla, **no escribe** los artefactos.

### Comandos

```powershell
# Regenerar con red (descarga OSM/DEM y escribe artefactos)
.\.venv\Scripts\python.exe tools\osm\build_world_routes.py

# Forzar de nuevo todas las fuentes y teselas
.\.venv\Scripts\python.exe tools\osm\build_world_routes.py --refresh

# Regenerar solo con la caché local (sin red)
.\.venv\Scripts\python.exe tools\osm\build_world_routes.py --offline

# Validar lo versionado sin regenerar
.\.venv\Scripts\python.exe tools\osm\build_world_routes.py --check
```

La evidencia de build queda en `build/logs/osm/route_network_preview.png` y
`build/logs/osm/report.json` (no versionados).

## 4. Grafo y rutas

Los IDs son estables:

- Hub: `hub_<region>`.
- Nodo: `node_<sha1-8>` de la coordenada redondeada.
- Arista: `edge_<sha1-8>` de extremos y primeros puntos de la cadena.

Reglas:

- Grado mínimo 1; los nodos terminales solo pueden ser hubs.
- Aristas de hasta 40 km para que F4.2 pueda subdividir por sectores de 800 m.
- Sin nodos huérfanos: la red es conexa desde `hub_carabobo`.
- Cada arista guarda clase, `ref` (sin nombres visibles), distancia, tiempo,
  ascenso/descenso, elevación mínima/máxima, pendiente máxima y forma
  `[lat, lon, elevación]`.
- Las rutas guardan la secuencia de nodos/aristas, distancia, tiempo, desnivel,
  elevación, regiones y el solapamiento/desvío frente al principal.

### Anillo de campaña

| Ruta | Principal | Alternativas | Km principal | Horas a velocidad de diseño |
|---|---|---|---|---|
| `route.carabobo_falcon` | Carabobo → Falcón | 2 | 542,9 | 6,27 |
| `route.carabobo_merida` | Carabobo → Mérida | 2 | 486,9 | 5,77 |
| `route.merida_llanos` | Mérida → Llanos | 2 | 144,4 | 1,61 |
| `route.llanos_amazonas` | Llanos → Amazonas | 2 | 1.593,8 | 18,09 |
| `route.amazonas_delta` | Amazonas → Delta | 2 | 1.087,0 | 12,40 |
| `route.delta_carabobo` | Delta → Carabobo | 2 | 896,7 | 10,25 |

Total principal: **4.751,7 km**. Total con alternativas: **16.265,7 km**.
Elevación mínima/máxima de la red: **2,9 / 3.459,6 m**. Las distancias son las
de la geometría comprimida que conduce el jugador; la pendiente usa la distancia
real de recorrido del extracto OSM.

La alternativa de `merida_llanos` con mayor solapamiento (0,828) es un bucle
paralelo real de la misma base OSM; se conserva porque permite rodear un bloqueo
sin salir de la región. El resto de alternativas tiene solapamientos entre 0,095
y 0,744.

## 5. DEM

- Fuente: **Mapzen Terrain Tiles (Terrarium)**, teselas `{z}/{x}/{y}.png` de
  `elevation-tiles-prod`, zoom 10.
- Datos de origen: **SRTM** y **GMTED2010** (USGS) y **ETOPO1** (NOAA), según la
  cobertura. Atribución completa:
  https://github.com/tilezen/joerd/blob/master/docs/attribution.md
- Muestreo: cada 500 m de recorrido, interpolación bilineal, limpieza de picos
  aislados y media móvil de 3 puntos.
- Precisión: suficiente para pendientes y referencia de F4.2; **no es un DEM
  topográfico de precisión ni sirve para navegación**.
- Caché: `build/cache/dem/` (155 teselas, ~7,5 MB). No se versiona.

## 6. Proyección

`projection` define una proyección equirectangular local:

- Origen: `[8.5, -66.5]`.
- `meters_per_degree_lat`: 110.574; `meters_per_degree_lon`: 110.097.
- `world_scale`: 0,05 (1:20).
- `vertical_scale`: 0,05 (geométricamente similar; las pendientes de ruta son
  reales).

Cada nodo guarda `game_m: [x, z]` para que F4.2 no tenga que duplicar la
proyección. `RouteNetwork.project_geo()` y `unproject_game()` permiten ida y
vuelta con error menor a 0,0002°.

## 7. Caché y reproducibilidad

| Elemento | Ubicación | ¿Versionado? |
|---|---|---|
| Respuestas Overpass | `build/cache/osm/<consulta>_<hash>.json` | No |
| Teselas DEM | `build/cache/dem/10_x_y.png` | No |
| Vista previa e informe | `build/logs/osm/` | No |
| Red comprimida | `data/content/world/route_network.json` | Sí |
| Manifiesto | `data/content/world/route_network.manifest.json` | Sí |

El manifiesto registra:

- SHA-256 y tamaño del contrato y del artefacto.
- SHA-256, tamaño, endpoint y timestamp de cada consulta OSM.
- Número de teselas DEM, bytes y hash del conjunto de claves/hashes.
- Comando reproducible, autor, fecha y licencia.

`data/content/world/route_network.json` es el artefacto de datos; las respuestas
crudas y las teselas se pueden borrar y regenerar con `--refresh`.

## 8. Atribución ODbL

La red es una **Derivative Database** de OpenStreetMap. Se distribuye bajo
**ODbL 1.0**:

- Copyright: **© OpenStreetMap contributors**.
- Licencia: https://opendatacommons.org/licenses/odbl/1-0/
- Copyright: https://www.openstreetmap.org/copyright
- Texto completo: `licenses/ODbL-1.0.txt`.
- Atribución en el juego: clave `CREDITS_OSM` (once idiomas), visible en la
  pantalla de arranque; F9.1 la llevará al menú definitivo.
- Atribución web: pie de `docs/index.html` y `CREDITS.md`.
- Share-alike: cualquier redistribución de la red derivada debe mantenerse bajo
  ODbL 1.0 y conservar esta atribución.

La elevación se atribuye a Mapzen/Tilezen, USGS (SRTM/GMTED2010) y NOAA (ETOPO1)
en `CREDITS.md` y en el manifiesto.

## 9. Validación y pruebas

`tools/validate_schemas.py` valida el contrato contra su JSON Schema y ejecuta
`tools/osm/route_graph_validation.py`, que comprueba:

- IDs únicos, extremos existentes, sin bucles y grado coherente.
- Conectividad completa desde el hub de recuperación.
- Continuidad y distancia de cada ruta y alternativa.
- Solapamiento y desvío de alternativas.
- Elevación por nodo/arista, pendiente máxima y longitud máxima.
- Presupuestos de nodos, aristas, bytes y referencias.
- Atribución ODbL, `CREDITS_OSM` en el CSV y archivo de licencia.
- SHA-256 del artefacto y del contrato contra el manifiesto.
- Estados de red y de ruta declarados y sin transiciones rotas.

Prueba Godot:

```powershell
.\tools\dev\world_routes_test.cmd
```

La prueba carga el contrato y el artefacto, verifica el hash, el grafo, las seis
rutas y sus alternativas, la proyección, la atribución y el enrutado A* runtime.
Resultado de cierre: **143 comprobaciones OK**.

## 10. Runtime y handoff a F4.2

`src/world/route_network.gd` (`RouteNetwork`) es un `RefCounted`, **no un
autoload**:

- `load_all()` carga contrato, red y manifiesto; valida hash, IDs, grados,
  conectividad, rutas y atribución.
- `find_path()` implementa A* sobre el grafo comprimido; `find_alternatives()`
  reproduce el cálculo penalizado para QA.
- `project_geo()` / `unproject_game()` / `node_game_position()` preparan el
  espacio de juego.
- `edge_world_points()` devuelve la polilínea 3D para el futuro generador de
  terreno.

F4.2 debe:

1. Instanciar `RouteNetwork` en el `WorldDirector` de escena.
2. Construir Terrain3D y los sectores de 800 m a partir de nodos/aristas.
3. Usar `ResourceLoader.load_threaded_request()` y máximo dos solicitudes
   simultáneas.
4. Medir la carga del grafo contra `budgets.runtime_load_budget_ms` (250 ms,
   pendiente de medición real).
5. No modificar la red ni el contrato sin subir `schema_version` y documentar la
   migración.

## 11. Limitaciones conocidas

- La geometría se comprime a 1:20 y se muestrea cada 500 m; las horquillas
  locales y el viario urbano no están incluidos. F4.2/F4.3 añadirán detalle
  local.
- La DEM z10 (~150 m/píxel) no resuelve puentes, túneles ni cortes de ladera;
  la limpieza de picos evita valores absurdos, pero la elevación es de referencia.
- El `route.merida_llanos` conserva una alternativa con solapamiento alto (bucle
  paralelo); sigue siendo una ruta OSM real y válida para rodear un bloqueo.
- La red no es navegable ni apta para uso real; es contenido de juego.
- La carga runtime, el terreno, la colisión y el streaming son F4.2.

## 12. Evidencia de cierre

- `build/logs/osm/route_network_preview.png`: mapa de la red, regiones y
  elevaciones (no versionado).
- `build/logs/osm/report.json`: tabla de rutas, estadísticas y DEM.
- `build/logs/world/latest.log`: prueba Godot.
- `tools/validate_schemas.py`: 9 contratos válidos, 1 advertencia conocida de
  localización (202 claves de contenido → F8.4).
