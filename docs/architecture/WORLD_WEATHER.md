# Clima, rayos y mapa de papel (Fase 4.4)

**Estado:** implementado y validado en `v0.4.3`.
**Contrato:** `data/schemas/world_weather.json` (`world.weather` v1).
**Esquema:** `data/schemas/json/world_weather.schema.json`.
**Autoload:** `src/core/weather_manager.gd` (`WeatherManager`).
**Servicios de escena:** `LightningDirector`, `WeatherBridge`, `PaperMap`.
**Prueba:** `tests/weather/WeatherRegionsTest.tscn` / `tools/dev/weather_regions_test.cmd`.

## 1. Alcance

F4.4 convierte el clima base de F1.2 en un sistema real que consume F4.3 sin
reabrir sus contratos:

- perfiles de clima por los **seis biomas/regiones** de `world.biomes`;
- transiciones suaves de humedad, lluvia, viento, niebla y temperatura;
- humedad de superficie y lluvia normalizada que alimentan `rain_surface_fx`;
- **rayos y truenos** procedurales (VFX + audio sintetizado, sin samples);
- **mapa de papel** sobre la red comprimida de F4.1, sin datos OSM nuevos;
- corrección de **H1**: las gotas de cámara viven en la geometría real del
  parabrisas y ya no cubren el habitáculo.

No incluye pérdida de agarre, hidroplaneo, vadeo ni anti-atasco (F5.1), ni decide
misiones. El clima nunca bloquea la ruta ni daña el vehículo.

## 2. Flujo

```text
world.biomes (region -> bioma, presets agua/polvo/nieve)
        │
        ▼
world_weather.json (presets + perfiles + transiciones + rayos)
        │
        ▼
WeatherManager (autoload) ── EventBus.weather_changed ──► UI / RainFx / QA
        │                    └ EventBus.weather_lightning ─► LightningDirector
        │
        ├─► WeatherBridge ─► RainFxController.set_weather()
        │                        └─ SurfaceWetness / Droplets / Puddles (F3.3)
        └─► WorldDirector ─► biome_for_position() ─► set_biome()
                                  └─ PaperMap (red de F4.1, sin OSM nuevo)
```

`AudioDirector` y `WeatherManager` no se llaman entre sí. `LightningDirector`
solo escucha `EventBus.weather_lightning` y reproduce su propio trueno; no crea
un bus ni un autoload nuevo.

## 3. Contrato `world.weather` v1

| Sección | Contenido |
|---|---|
| `presets` | Nueve estados (`clear`, `overcast`, `drizzle`, `rain`, `storm`, `fog`, `sandstorm`, `snow`, `swamp_mist`) con humedad, lluvia, viento, niebla, temperatura, humedad objetivo y rayos |
| `biome_profiles` | Un perfil por bioma con región, preset base, presets ponderados, sesgos de temperatura/humedad/viento y enlaces a polvo/nieve |
| `transition` | Velocidad de mezcla, humedad, histéresis, autoavance de 45–120 s y cambio de región acelerado |
| `lightning` | Intervalo, doble destello, distancia, retardo del trueno, tope por minuto, energía, flash de pantalla y síntesis del trueno |
| `camera_mask` | Máscara/geometría del parabrisas para H1 |
| `rain_coupling` | Lluvia normalizada → mm/h, idéntica a `rain_surface_fx` |
| `budgets` | ≤0,25 ms de CPU (PC) / ≤0,4 ms (móvil), una luz y una llamada de dibujo |
| `attribution` / `anti_softlock` / `states` / `qa` | ODbL, no bloqueo, estados y comandos |

Validación cruzada en `tools/validate_schemas.py`: cubre exactamente los seis
biomas, los pesos suman 1, los presets referenciados existen, las temperaturas y
la humedad quedan en rango, los enlaces `dust_link`/`snow_link` coinciden con
`world.biomes`, `rain_intensity_to_mm_h` coincide con `rain_surface_fx` y las
claves de localización de los presets existen.

## 4. WeatherManager

- `set_region(region)` resuelve el bioma con `world.biomes.region_biome_map`;
  `set_biome(biome)` aplica el perfil y elige un preset ponderado determinista.
- `set_preset(preset, immediate)` conserva la API de F1.2/QA.
- `step(delta)` es el paso público determinista (60 Hz en juego, pruebas
  headless); `_process` solo lo llama.
- La humedad de superficie (`wetness`) es propiedad de `rain_surface_fx`; el
  clima publica `wetness_target` y `WeatherBridge` inyecta lluvia/humedad/viento/
  temperatura en `RainFxController.set_weather()`.
- El autoavance cambia de preset cada 45–120 s. Al cruzar de bioma, el cambio de
  región acelera la mezcla para no arrastrar un clima incoherente.
- Los rayos solo se programan con `storm`; `force_lightning()` es para QA y
  pruebas y respeta el tope por minuto.
- `get_state()` publica `preset`, `region`, `biome`, `humidity`, `rain`, `wind`,
  `wind_mps`, `fog`, `temperature`, `temperature_c`, `wetness`, `lightning`,
  `transition`, `next_change_in_s` y `wind_direction_rad`.

## 5. Rayos y truenos

`LightningDirector` (servicio de escena, instanciado en rebanada, cabina y mundo):

- Un `DirectionalLight3D` sin sombras y un `ColorRect` de flash; una sola luz y
  una llamada de dibujo adicional.
- Doble destello opcional y caída lineal de energía.
- Trueno sintetizado una vez en `AudioStreamWAV` (PCM 16 bits, ruido filtrado +
  graves + crack inicial) con retardo por distancia (`2,9 s/km`). Sin samples,
  sin APIs de audio de pago y sin archivos externos.
- `SettingsManager.accessibility.reduce_flashes` reduce el flash de pantalla
  (la opción completa de accesibilidad es F9.1).
- Publica `EventBus.accessibility_cue("lightning", …)` con límite de cadencia.

## 6. H1: gotas de cámara en el parabrisas

F3.4 montaba un quad de gotas pegado a la cámara y a pantalla completa; parecía
llover dentro del habitáculo y también al mirar a la puerta.

F4.4 lo sustituye por una **malla de dos triángulos con las cuatro esquinas
reales del panel `windshield` de `exterior_spec.json`**, colocada en el marco del
vehículo con `depth_test` activo. El salpicadero, el volante y los pilares la
ocluyen, y al girar la vista la malla sale del encuadre como la ventanilla real.
El shader conserva la máscara de pantalla (`mask_points`) como respaldo para el
quad antiguo, pero la cabina usa la malla. La sonda de render bajó el fill de
fragmentos de **90,17 % a 6,44 %** y el fill visual al **0,25 %** con la misma
lluvia.

## 7. Mapa de papel

`PaperMap` (`src/world/paper_map.gd`) es un `Control` creado por `WorldDirector`:

- dibuja las 413 aristas y las seis rutas principales de `route_network.json`
  (F4.1), con hubs de región, ruta activa y marcador de posición;
- **norte arriba**: la proyección usa el eje `z` de `route_network`
  (`z = -(latitud - origen)`), de modo que Falcón queda al norte y Amazonas al
  sur; la prueba verifica la orientación norte/este con los hubs reales;
- silueta esquemática y original de Venezuela (~57 puntos lat/lon) bajo la red,
  con relleno de tierra y contorno de costa; no es un dato OSM, es contexto de
  presentación proyectado con la misma escala 1:20;
- rosa de los vientos mínima, rejilla, borde y leyenda (ruta activa, principal y
  red secundaria);
- no descarga, no hornea y no versiona datos OSM nuevos; conserva la atribución
  `CREDITS_OSM` y la licencia ODbL 1.0;
- se abre con el botón «Mapa» o la tecla `M`, y se cierra igual;
- sin `load()` en runtime y sin consultas a Overpass.

## 8. Presupuestos y medición

| Objetivo | Valor | Verificación |
|---|---|---|
| CPU de clima | ≤ 0,25 ms PC / ≤ 0,4 ms móvil | `WeatherRegionsTest` (1.000 pasos) |
| Luces de rayo | 1 | `LightningDirector` |
| Draw calls añadidas | 1 (flash de pantalla) | sonda de render |
| Triángulos añadidos | 0 | malla de gotas ya existente en F3.4 |
| Gotas de cámara | 2 triángulos en el parabrisas | H1 + `WeatherRegionsTest` |
| PSS / triángulos visibles | sin cambios de F4.3 | ruta ADB `slice,cabin,world` |
| Mapa | solo CPU de UI | `PaperMap` sin recursos cargados |

Los resultados medidos de `v0.4.3` se registran en `docs/status/CURRENT.md` y en
`build/logs/gameplay/REPORT_F44.md`.

## 9. Licencia

La red y los sectores siguen siendo una base derivada de OpenStreetMap bajo
**ODbL 1.0**; la atribución y el share-alike se conservan. El clima, los truenos
y el mapa son código y arte propio del proyecto; no se copió ninguna imagen ni
sonido de la biblioteca externa.
