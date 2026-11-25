# Kits de biomas, POIs y mobiliario vial (Fase 4.3)

**Estado:** implementado y validado en `v0.4.2`.  
**Contrato:** `data/schemas/world_biomes.json` (`world.biomes` v1).  
**Especificación de kits:** `data/world/kits_spec.json`.  
**Biblioteca runtime:** `src/world/world_kit_library.gd` (`WorldKitLibrary`).  
**Decorado procedural:** `src/world/biome_decor_builder.gd` (`BiomeDecorBuilder`).  
**POIs de ruta:** `src/world/poi_manager.gd` (`PoiManager`).  
**Prueba:** `tests/world/WorldBiomesTest.tscn` / `tools/dev/world_biomes_test.cmd`.

## 1. Alcance

F4.3 añade la capa visual de presentación del mundo sobre F4.2 sin rehacerla:

- **kits de bioma** para las seis regiones (costa, montaña, llanos, selva, delta
  y eje industrial): paleta de terreno, vegetación, rocas, suelo y detalles de
  borde de vía;
- **POIs y mobiliario vial**: gasolineras, moteles, peajes, cruces, señalización,
  postes, vallas y guarda-falsos;
- **presets visuales de superficie**: agua, polvo y nieve por bioma;
- **integración** con el streaming de sectores de 800 m sin romper la carga
  threaded, el máximo de dos solicitudes, la construcción de una malla por frame
  ni la prohibición de `load()` síncrono.

No incluye clima simulado, humedad real ni lluvia (`WeatherManager`, F4.4);
tampoco conducción, agarre, vadeo ni anti-atasco (F5.1). Los presets de
superficie son **visuales/materiales** y se consumirán desde F4.4/F5.1.

## 2. Flujo

```text
data/world/kits_spec.json (paramétrico)
        │
        ▼
tools/blender/world_kits.py (bpy headless, por familia)
        │
        ▼
assets/generated/world/kit_*_lod{0,1,2}.glb + kit_*_anchor.glb
        + assets/manifests/kit_*.manifest.json
        │
        ▼
WorldKitLibrary ── load_threaded_request() (máx. 2, 0 síncrono)
        │                 │
        │                 └──► PoiManager: POIs de ruta con LOD por distancia
        ▼
WorldSectorBuilder.build_sector_decor: mobiliario + vegetación + agua
        (una construcción por frame, presupuesto ≤ 620 triángulos)
```

## 3. Contrato `world.biomes` v1

Aditivo: **no modifica** `world_routes` v1 ni `world_streaming` v1; los consume.

| Sección | Contenido |
|---|---|
| `region_biome_map` / `biome_selection` | Bioma por hub de región más cercano (determinista) |
| `biomes` | Paleta de terreno, variación de relieve, decorado, mobiliario y presets `water`/`dust`/`snow` por bioma |
| `props` | Ocho props procedurales (palma, árbol, arbusto, pasto, roca, frailejón, mojón, guarda-falso) con LOD0/1/2 y presupuestos |
| `pois` | Cuatro POIs de ruta (gasolinera, motel, peaje, cruce) y tres de mobiliario (señal, poste, valla) con LOD0/1/2, `range_m`, colisión y `brands_forbidden` |
| `surface_presets` | Agua (shader propio), polvo y nieve como presets visuales; enlaces a F4.4/F5.1 |
| `budgets` | 3.000 triángulos/sector (2.048 terreno + ≤328 vía + ≤620 decor), 2 solicitudes de kits, 1 construcción/frame, 72 POIs/ruta, PSS 1.228,8 MB |
| `placement_rules` | Nunca sobre la vía, despeje ≥ 5,6 m, corredor de reaparición protegido, pendiente máxima para POIs |
| `attribution` | ODbL 1.0 conservado + licencia de kits CC BY-NC-SA 4.0 |
| `anti_softlock` | El decorado no bloquea la vía ni la reaparición de F4.2 |

Validación cruzada en `tools/validate_schemas.py`: biomas ↔ regiones de
`world_routes`, cadenas LOD estrictamente decrecientes, despejes de vía,
presupuestos frente a `world_streaming`, atribución idéntica, familias de kit
generadas y manifiestos presentes.

## 4. Kits bpy (POIs y mobiliario)

`tools/blender/world_kits.py` genera cada familia desde `kits_spec.json`:
primitivas declaradas (cajas/cilindros), materiales PBR propios, sin marcas
reales, sin texto en las mallas (paneles en blanco) y sin texturas externas.

| Familia | Uso | LOD0/1/2 (triángulos) |
|---|---|---|
| `poi.kit_gasolinera` | Marquesina, islas, surtidores y tienda | 1.944 / 792 / 132 |
| `poi.kit_motel` | Edificio, porche, puertas y rótulo neutro | 1.620 / 660 / 60 |
| `poi.kit_peaje` | Isla, marquesina, caseta y barrera | 1.080 / 440 / 96 |
| `poi.kit_cruce` | Postes, paneles, bolardos y lámpara | 500 / 244 / 64 |
| `road.kit_sign` | Poste direccional con paneles en blanco | 176 / 80 / 32 |
| `road.kit_pole` | Poste de alumbrado/tendido | 264 / 120 / 32 |
| `road.kit_billboard` | Valla sin marca sobre patas | 264 / 104 / 52 |

Cada familia exporta además `kit_*_anchor.glb` (`anchor_root` en el suelo, usado
por `PoiManager` para alinear el kit con el borde de vía). Los manifiestos
`assets/manifests/kit_*.manifest.json` registran comando, hashes de script/spec
y salidas, autor, licencia y fecha; `tools/validate_assets.py` los valida con
la misma política LOD0/LOD1/LOD2 que el vehículo.

Regeneración:

```powershell
.\.venv\Scripts\python.exe tools\blender\build_assets.py --target world.poi.kit_gasolinera
# … uno por familia; o la fábrica completa de targets world.*
```

## 5. Decorado procedural de sector

`BiomeDecorBuilder` construye los props como `ArrayMesh` deterministas (sin
cargas de recursos) con tres LODs cuyo coste real está declarado en el contrato
(validado en runtime por `WorldBiomesTest`). `WorldSectorBuilder.build_sector_decor`
los coloca por sector:

1. **Mobiliario vial** primero (postes, señales, vallas, mojones, guarda-falsos):
   densidad derivada de `every_n_km` (km reales convertidos a metros de juego
   con la proyección 1:20 de F4.1) y topes `max_instances`.
2. **Vegetación y rocas** como `MultiMeshInstance3D` por prop, con escala/rotación
   aleatoria determinista.
3. **Agua visual** en biomas con `water.enabled`: un quad por sector a
   `height_min_m + level_bias_m` con `shaders/world_water.gdshader` (oleaje
   suave, sin física).

Colocación determinista: candidatos derivados de los triángulos de la cinta de
vía de `WorldSectorData`, desplazados lateralmente fuera del pavimento
(semiancho real de la cinta + `min_lateral_m`), con altura por interpolación
bilineal de la rejilla y filtro de pendiente. El **presupuesto de 620
triángulos** (compartido con el mobiliario, con subpresupuesto de 300) se
respeta por construcción: el empaquetador detiene la adición de instancias
cuando se agota. La colisión de terreno/vía de F4.2 no se toca; el decorado es
`StaticBody`-free salvo los POIs de ruta.

El LOD de decorado por sector se elige por distancia a la ventana de streaming
(sector actual ±1 → LOD0; ±3 → LOD1; resto → LOD2).

## 6. POIs de ruta

`PoiManager` coloca POIs por intervalo de distancia sobre la ruta activa
(`every_n_km` ± jitter determinista por `route_id|kind|index`), filtrados por
bioma, con lateral alternante y ≥ 9 m del centro de la vía. Cada POI instancia
tres variantes de kit (LOD0/1/2) con `visibility_range` por distancia y, si
declara colisión, un `StaticBody3D` con caja derivada del LOD0.

- Máximo **72 nodos por ruta** (`llanos_amazonas`, la más larga, usa 54).
- Los POIs nunca caen sobre la vía ni el corredor de reaparición:
  `WorldDirector.safe_respawn_point()` sigue proyectando sobre la red.
- Sin marcas reales: la validación exige `brands_forbidden` en todos los POIs.

## 7. Presets de superficie (agua, polvo, nieve)

| Preset | Aplicación en F4.3 | Consumo futuro |
|---|---|---|
| `water` | Quad visual por sector + shader de oleaje | Vadeo F5.1; clima/humedad F4.4 |
| `dust` | Tinte cálido sutil del terreno en biomas secos | Partículas de conducción F5.1; enlace a clima F4.4 |
| `snow` | Aclaramiento del terreno por encima de `snow_line_m` (solo montaña) | Acumulación y clima F4.4 |

Ninguno duplica `rain_surface_fx` (contrato del vehículo) ni simula clima.

## 8. Presupuestos y medición

| Presupuesto | Valor | Verificación |
|---|---|---|
| Triángulos por sector | ≤ 3.000 (2.048 + ≤328 + ≤620) | `WorldBiomesTest` (decorado sintético y sectores cargados) |
| Solicitudes de kits | ≤ 2 simultáneas, 0 `load()` síncrono | `WorldKitLibrary.stats()` en la prueba |
| Construcciones por frame | 1 | heredado de `world_streaming` v1 |
| POIs por ruta | ≤ 72 | `WorldBiomesTest` |
| LOD de props | 3 niveles decrecientes dentro de presupuesto | `WorldBiomesTest` (conteos reales) |
| LOD de kits | 3 niveles decrecientes (manifiestos + runtime) | `validate_assets.py` + `WorldBiomesTest` |
| Triángulos visibles | ≤ 120.000 Android / ≤ 450.000 PC | ruta de rendimiento (ADB + sonda PC) |
| PSS Android | ≤ 1.228,8 MB | `dumpsys meminfo` en la ruta `slice,cabin,world` |

Los resultados medidos de `v0.4.2` están en `docs/status/CURRENT.md` y en los
informes `build/logs/gameplay/REPORT_F43.md` / `build/logs/android-smoke/`.

## 9. Licencia y atribución

- La red y los sectores siguen siendo base derivada de OSM bajo **ODbL 1.0**;
  la atribución `CREDITS_OSM`, `licenses/ODbL-1.0.txt` y el share-alike se
  conservan sin cambios.
- Los kits y el decorado son arte propio del proyecto (**CC BY-NC-SA 4.0**,
  `ASSET_LICENSE.md`), generados por `bpy` o por código procedural, sin marcas
  reales y sin ninguna imagen, textura o malla de `C:\Dev\fotos de ejemplo`.
- La revisión de referencias de F4.3 quedó registrada en
  `docs/reference/REFERENCE_USAGE_LOG.md` (2026-11-24).

## 10. Limitaciones conocidas

- Los kits son de una sola escala y sin variantes estéticas por región; las
  variaciones son de color/material por bioma.
- El agua es un plano por sector (relleno de cotas bajas): no modela ríos,
  caños ni mareas. La hidrología real es F5.1/F4.4.
- La nieve es un tinte de altura sin acumulación; solo en el bioma de montaña.
- La señalización lleva paneles en blanco (sin texto quemado en la malla); la
  señalética localizada llegará con la UI de F9.1/F4.4 si se aprueba.
- Los cruces peatonales no pintan la vía (las marcas del sector son las horneadas
  en F4.2); el kit aporta postes, paneles y bolardos.
- El mobiliario no tiene física de choque con el vehículo (F5.1); la colisión de
  POIs evita atravesarlos a pie/rueda pero el comportamiento de conducción es
  futuro.
