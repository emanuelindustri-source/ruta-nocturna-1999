# Lluvia, humedad y superficies (Fase 3.3 → 3.4)

**Contrato:** `data/schemas/rain_surface_fx.json` (`schema_version: 1`).  
**Esquema:** `data/schemas/json/rain_surface_fx.schema.json`.  
**Pruebas:** `tests/weather/RainFxTest.tscn` y `tools/dev/rain_test.cmd`.  
**Render:** `tests/render/RainFxRenderTest.tscn` y `tools/dev/render_test.cmd`.  
**Estado:** matemática y contratos de F3.3 + GLSL de producción y VFX de F3.4.
Sin pérdida de agarre, vadeo ni clima real: F4.4 conecta `WeatherManager` y
F5.1 consume charcos/vadeo. La medición GPU completa en ruta y dispositivo es
F3.5/F10.1.

## 1. Alcance

La Fase 3.3 declara y prueba la matemática que consumirán las fases siguientes:

| Sistema | Este documento / contrato | Consumidor |
|---|---|---|
| Humedad de superficies | Entrada de lluvia, drenaje, evaporación, infiltración y estados | F3.4 (shader), F4.4 (`WeatherManager`) |
| Gotas | Nucleación, crecimiento, desliz, evaporación y escurrido | F3.4 (instancias/uniforms y GLSL) |
| Limpiaparabrisas | Barrido, zona limpia, modos, intermitencia y desgaste | F3.4/F3.5 (animación y VFX), F5.1 (sustitución) |
| Charcos | Formación, drenaje, profundidad, hidroplaneo y vadeo | F4.3/F4.4 (vía y clima), F5.1 (agarre y vadeo) |
| Presupuestos | Límites CPU, instancias, zonas y objetivos GPU | F3.4/F3.5/F10.1 |

No se ha modificado ningún asset, malla, material, manifiesto, escena de vehículo
ni contrato cerrado de F2.1–F3.2. `cabin_interaction.json` v2, `vehicle_powertrain.json`,
`exterior_spec.json` y `interior_spec.json` quedan intactos.

## 2. Fuente de lluvia y unidades

`WeatherManager` publica `rain` normalizado de 0 a 1, `humidity`, `wind` en m/s y
`temperature` en °C. El contrato convierte la lluvia:

```text
rain_mm_h = rain_intensity * 45.0
```

45 mm/h a intensidad 1.0 es un valor de diseño para una tormenta tropical fuerte
de diciembre de 1999. Se recalibrará al conectar el clima en F4.4.

Las superficies de gotas usan coordenadas 2D locales en milímetros. El eje X va a
la derecha y el eje Y hacia arriba en el plano de la superficie. `flow_dir`
[0, -1] escurre hacia abajo en un vidrio; [0, 1] escurre hacia atrás en capó y
techo.

## 3. Humedad de superficies

Cada panel del vehículo y cada superficie de vía declara una clase (`paint`,
`glass`, `asphalt`, `dirt`, `chrome`, `plastic_rubber`) y una exposición. La
película se integra con:

```text
input_mm_s = rain_mm_h / 3600 * rain_capture * exposure
drainage_mm_s = drainage_rate_per_s * max(0, film_mm - retention_mm)
evaporation_mm_s = evaporation_rate_per_s * film_mm
                 * pow(max(0.05, 1 - humidity), humidity_exponent)
                 * (1 + min(wind, max_wind) * wind_drying_gain)
                 * (1 + max(0, temperature - 10) * temperature_drying_gain)
infiltration_mm_s = infiltration_rate_per_s * film_mm
film_step_mm = clamp(film + (input - drainage - evaporation - infiltration) * dt, 0, max_film_mm)
wetness = film_mm / max_film_mm
```

El delta se acota a `precipitation.max_step_s` (0,25 s). Los estados internos son
`dry`, `damp`, `wet` y `soaked`, con histéresis de 0,03 para evitar parpadeo.
`SurfaceWetnessModel` expone `get_wetness()`, `get_film_mm()`, `get_state()`,
`get_runoff()` y `get_absorber_runoff()`.

Decisiones:

- El vidrio se moja y drena antes que la pintura.
- La pintura retiene gotas visibles desde wetness 0,28.
- El asfalto retiene una película absoluta mayor, pero su infiltración lo seca
  antes que un charco profundo.
- La carrocería nunca se seca instantáneamente: el estado es una función de la
  película, no un temporizador de gameplay.

## 4. Gotas

`DropletFlowModel` mantiene un campo determinista de gotas independientes por
superficie. Cada perfil (`glass`, `paint`) declara capacidad, radio inicial,
nucleación, crecimiento, radio crítico, velocidad terminal y evaporación.

```text
spawn_rate = nucleation_per_m2_s * area_m2 * rain
           * clamp((wetness - nucleation_wetness) / (1 - nucleation_wetness), 0, 1)
growth = growth_mm_per_s * clamp((wetness - growth_wetness) / (1 - growth_wetness), 0, 1)
critical_radius = critical_radius_mm * (1 - slide_wetness_gain * wetness)
sliding_speed = move_toward(velocity, terminal_speed, accel * dt)
```

- La semilla es fija por perfil. Dos campos con la misma semilla producen la
  misma cantidad y posición inicial; la prueba lo verifica.
- Cuando una gota sale del rectángulo de la superficie, suma su volumen
  aproximado al escurrido (`get_runoff_ml()`).
- La fusión visual de gotas vecinas es del shader de F3.4. El modelo de F3.3 no
  hace comparaciones O(n²) para mantener el coste CPU medible.
- `get_instances()` devuelve un `PackedFloat32Array` con 6 floats por gota:
  `x_mm`, `y_mm`, `radius_mm`, `velocity_x_mps`, `velocity_y_mps`, `state`.
  F3.4 lo convertirá en uniforms/instancias; F3.4 decide el layout GPU final.
- Los estados son `nucleated`, `growing`, `sliding`, `evaporating` y `removed`.

## 5. Limpiaparabrisas

La geometría de referencia sale de `exterior_spec.json` (F3.1): las cajas
`wiper_left` y `wiper_right` miden 0,46 m y sus extremos interiores definen los
pivotes. El contrato no cambia esa malla; solo declara la cinemática.

| Parámetro | Valor | Fuente |
|---|---|---|
| Pivotes | `[-0.16, 1.06, -0.705]` y `[0.16, 1.06, -0.705]` | Extremo interior de las cajas de F3.1 |
| Longitud de escoba | 0,46 m | Longitud de las cajas de F3.1 |
| Barrido | -100° izquierda / +100° derecha | Valor de diseño |
| Modos | off, intermittente, lento (45 ciclos/min), rápido (70 ciclos/min) | Valor de diseño |
| Intermitencia | 2,0 / 4,0 / 7,0 s | Valor de diseño |
| Desgaste | 0,015 por 1.000 ciclos | Valor de diseño |
| Eficiencia nueva / gastada | 0,94 / 0,62 | Valor de diseño |

El barrido usa `smoothstep` y limpia gotas en el sector barrido del parabrisas.
La eficiencia de limpieza baja con el desgaste; la estela residual sube. El
desgaste **no bloquea la conducción** ni los controles: es una degradación
reversible y la sustitución de la goma es una reparación futura de F5.1.

No se añadió un mando nuevo a la cabina. `control_source` queda como
`future_cabin_stalk_or_automatic`; la integración visual y de entrada se decide
en F3.4/F3.5 sin reabrir `cabin_interaction.json` v2.

## 6. Charcos

`PuddleModel` instancia arquetipos por zona. La profundidad se integra con
lluvia directa, escorrentía de la vía, drenaje, infiltración y evaporación:

```text
direct_inflow = rain_mm_h / 3600 * rain_capture * exposure
runoff_inflow = runoff_mm_s * upstream_runoff_gain
outflow = (drainage + infiltration + evaporation * drying_factor) * depth_mm
depth = clamp(depth + (direct_inflow + runoff_inflow - outflow) * dt, 0, capacity_mm)
```

Arquetipos declarados:

| Zona | Capacidad | Uso |
|---|---|---|
| `asphalt_crown` | 0,8 mm | Corona de asfalto, película delgada |
| `asphalt_low_spot` | 8 mm | Hundimiento somero, caso común de hidroplaneo |
| `pothole` | 35 mm | Bache profundo y pequeño |
| `dirt_shoulder` | 18 mm | Hombro de tierra, infiltra rápido |
| `ford_crossing` | 1.200 mm | Vado de río para F5.1 |

El riesgo de hidroplaneo es informativo:

```text
depth_factor = clamp((depth - hydroplane_depth) / (capacity - hydroplane_depth), 0, 1)
speed_factor = clamp((speed_kph - 45) / (90 - 45), 0, 1)
risk = depth_factor * speed_factor
```

La pérdida de agarre, el daño, el anti-atasco y el vadeo son F5.1. La altura de
admisión (0,68 m) y la profundidad segura (0,30 m) se copian de
`vehicle_components.json#specs.water` y el validador exige coincidencia exacta.

## 7. Presupuestos

| Objetivo | PC | Móvil Redmi/baja |
|---|---|---|
| FPS | 60 | 60 objetivo / 30 mínimo |
| Presupuesto de frame | 16,667 ms | 33,333 ms |
| CPU media de lluvia | ≤ 1,0 ms | ≤ 1,5 ms |
| CPU p95 de lluvia | ≤ 1,6 ms | ≤ 2,4 ms |
| Gotas activas | 4.096 | 1.536 |
| Zonas de charco | 24 | 12 |
| Frecuencia de simulación | 60 Hz | 30 Hz |
| Triángulos/draw calls nuevos en F3.3 | 0 / 0 | 0 / 0 |
| GPU | Pendiente F3.4/F3.5 | Pendiente F3.4/F3.5 |

Medición headless de F3.3 (`RainFxTest`, 300 pasos tras 120 de warm-up, con los
campos llenos a su capacidad):

| Perfil | Media | p95 | Máximo observado | Presupuesto |
|---|---|---|---|---|
| PC (4.096 gotas, 24 charcos, 2 escobillas) | **~0,21 ms** | **~0,28 ms** | 3,3 ms | 1,0 / 1,6 ms |
| Móvil (1.536 gotas, 12 charcos, 2 escobillas) | **~0,17 ms** | **~0,21 ms** | 1,823 ms | 1,5 / 2,4 ms |

La media y el p95 quedan muy por debajo del presupuesto. El máximo incluye
picos de depuración/medición y no se usa como criterio de frame; F3.4/F3.5
medirán el coste GPU y el warm-up de shaders en la ruta real. No se declara
ninguna optimización sin medición.

## 8. Integración futura

- **F3.4:** shader de película, gotas, estela del barrido, asfalto mojado y
  charcos. Debe respetar `instance_stride`, `budgets.*.gpu` y el warm-up.
- **F4.4:** `WeatherManager` inyecta lluvia, humedad, viento y temperatura. No
  se crean autoloads nuevos; `SurfaceWetnessModel` es un servicio de escena.
- **F5.1:** consume `PuddleModel` para agarre, hidroplaneo, vadeo y anti-atasco;
  la reparación/sustitución de la goma del limpiaparabrisas se enlaza con el
  inventario existente.
- **F3.5/F10.1:** medición de triángulos, overdraw, fill rate, PSS y warm-up en
  la ruta de referencia con tormenta.

## 9. Pruebas

```powershell
.\tools\dev\rain_test.cmd
```

La prueba `tests/weather/RainFxTest.tscn` ejecuta **126 comprobaciones**:
contrato, 8 contratos válidos, humedad, determinismo de gotas, barrido,
desgaste, charcos, hidroplaneo, vadeo y presupuestos. El log queda en
`build/logs/rain/latest.log` (ignorado por Git).

## 10. Referencias y límites

La revisión visual completa de F3.3 usó el catálogo de 95 fichas y las hojas de
contacto existentes (`all_images.jpg`, `generated_concepts.jpg`,
`exterior_f31_review.jpg`, `exterior_f31_detail.jpg`, `interior_f32_review.jpg`,
`interior_f32_detail.jpg`) más una hoja de detalle nueva
`build/reference/contact_sheets/rain_f33_detail.jpg`. No hay fotos dedicadas de
lluvia, gotas o charcos en la biblioteca externa; las fotos reales del Esteem
están secas y los conceptos nocturnos solo inspiran atmósfera. No se copió
ningún archivo de `C:\Dev\fotos de ejemplo`.

Límites conocidos:

- Valores de humedad, gotas, barrido y charcos son `design_value`; no son
  especificación oficial del vehículo.
- No hay shader todavía: la forma, el reflejo y el overdraw se validan en F3.4.
- No hay pérdida de agarre ni vadeo: eso es F5.1.
- La medición CPU es headless y de escritorio; el Redmi se mide en F3.5/F10.2.

## 11. GLSL de producción y VFX (Fase 3.4)

Los shaders viven en `shaders/` y **consumen** el estado de los modelos de
F3.3: ningún shader integra la simulación de humedad, gotas, barrido o
charcos. El servicio de escena `RainFxController`
(`src/weather/rain_fx_controller.gd`) hace de puente: ejecuta los modelos y
proyecta su estado a uniforms cada frame. `RainVFX` monta las partículas y
`RainFxWarmup` compila las pipelines antes del gameplay.

| Shader | Uso | Estado consumido (F3.3) |
|---|---|---|
| `rain_fx_common.gdshaderinc` | Campo procedural de gotas con fusión visual de vecinas, estelas de escurrido, sector de barrido y ondas de charco | Parámetros derivados; sin simulación |
| `wet_paint.gdshader` | Pintura, plástico y cromo mojados | `SurfaceWetnessModel` (wetness, film) y `DropletFlowModel` (densidad, radio, desliz, escurrido) |
| `wet_glass.gdshader` | Cristales: gotas, refracción, sector barrido y estela de goma | `SurfaceWetnessModel`, `DropletFlowModel` y `WiperKinematics` (ángulos, desgaste, eficiencia) |
| `wet_road.gdshader` | Asfalto mojado, película, ondas de lluvia y charcos visibles | `SurfaceWetnessModel` (vía) y `PuddleModel` (profundidad normalizada por zona) |
| `rain_streaks.gdshader` | Estrellas de lluvia (GPUParticles3D) | Intensidad de lluvia (lookdev/F4.4) |
| `splash_ring.gdshader` | Salpicaduras de impacto en la vía | Intensidad de lluvia |
| `camera_drops.gdshader` | Gotas sobre la lente/parabrisas desde la cabina | `DropletFlowModel` y `WiperKinematics` |

Reglas de la capa visual:

- La fusión visual de gotas vecinas es procedural (celdas + estela), como
  anticipa `droplets.coalescence_note`; no hay comparaciones O(n²) en CPU.
- El marco de cada superficie se deriva de la malla (u = derecha, v = arriba,
  o atrás en capó/techo según `flow_dir`) y el flujo es la proyección de
  gravedad + deriva de viento, coherente con `droplets.equations.wind_drift`.
- El barrido renderizado usa los ángulos de `WiperKinematics` en la convención
  del contrato (0° = +X, izquierda 180° → 80°, derecha 0° → 100°). Las mallas
  `wiper_left`/`wiper_right` de F3.1 giran sobre los pivotes de
  `wiper.wipers[].pivot_m` sin modificar el GLB.
- La goma gastada deja estela (`wear.streak_gain_at_full_wear`) y el sector
  barrido se limpia con la eficiencia del modelo; no se añade ningún mando a
  `cabin_interaction.json` v2.
- Los charcos visibles se colocan en el mundo desde `puddle_zones` del servicio
  (colocación visual de F3.4) y toman su profundidad de `PuddleModel`. El
  hidroplaneo y el vadeo siguen siendo F5.1.
- Los valores de lluvia de las escenas son **lookdev** (`demo_*` en la escena);
  F4.4 inyecta los reales con `RainFxController.set_weather()`.

### Llamadas de dibujo y presupuestos GPU

Los materiales mojados sustituyen a los `StandardMaterial3D` existentes
(`material_override`): **0 llamadas nuevas** por carrocería, cristales y vía.
El coste añadido son los VFX:

| Elemento | Draw calls | Overdraw (capas) | Fill estimado |
|---|---|---|---|
| Estrellas de lluvia (rebanada) | 1 | 1 | ~2 % |
| Salpicaduras (rebanada) | 1 | 1 | ~1 % |
| Gotas sobre cámara (cabina) | 1 | 1 | ~3 % |
| **Total peor caso** | **3** | **3** | **~6 %** |

Dentro de `budgets.*.gpu` (PC 8/5/6 %, móvil 4/3/10 %). El overdraw y el fill
son estimaciones del diseño de VFX; la medición GPU real (RenderDoc/Adreno
Profiler) es F3.5/F10.1.

### Warm-up

`RainFxWarmup.run()` dibuja cada shader una vez en un `SubViewport` mínimo con
`RenderingServer.force_draw()` y lo destruye. Se ejecuta en `Boot._ready`
(antes de abrir cualquier gameplay) y de nuevo en cada escena con FX
(`[RAINFX] WARMUP_DONE` antes de `VERTICAL_SLICE_READY`/`CABIN`); los FX solo
se activan tras el warm-up (`fx_active`). En headless se omite con
`[RAINFX] WARMUP_SKIP reason=headless` sin fingir compilación.

## 12. Medición F3.4 (evidencia)

La prueba `tests/render/RainFxRenderTest.tscn` (ventana, Vulkan Forward+)
carga boot, rebanada y cabina con los shaders/VFX, captura
`build/logs/render/f34_*.png` y publica `[RENDER][PERF]` con frame time
medio/p95, draw calls y primitivas reales, más overdraw y fill proyectados.
Las cifras medidas de esta subfase y la comparación con `budgets.*.gpu` se
registran en `docs/status/CURRENT.md`.

## 13. Medición F3.5 (evidencia)

F3.5 completó la medición que F3.4 dejó pendiente. La misma prueba de render
(`tools/dev/render_test.cmd`, Intel UHD, Vulkan Forward+, 1280x720, vsync
60 Hz) añade **tiempos de carga**, **frame pacing** y una **sonda GPU real**
(`[RENDER][GPU]`) además de las capturas de referencia `f35_*.png`.

### Carga y warm-up (PC)

| Escena | Carga `load()` | Instanciación | Warm-up `RainFxWarmup` |
|---|---|---|---|
| Boot | 140,74 ms | 5,06 ms | 135,35 ms (primera compilación de 6 variantes) |
| Rebanada | 77,51 ms | 24,25 ms | 47,96 ms |
| Cabina | 214,47 ms | 2,29 ms | 112,34 ms |

El warm-up termina antes de `BOOT_READY`/`VERTICAL_SLICE_READY` y los FX
quedan inactivos hasta que `fx_active=true` (comprobado por la prueba).

### Frame pacing (90 frames por escena, vsync 60 Hz)

| Escena | media | p95 | máximo | jank > 25 ms | jank > 100 ms | draw calls | primitivas |
|---|---|---|---|---|---|---|---|
| Boot | 16,662 ms | 17,265 ms | 17,927 ms | 0 | 0 | 12 | 548 |
| Rebanada (tormenta 90 s) | 16,666 ms | 17,093 ms | 17,576 ms | 0 | 0 | 228 | 15.874 |
| Cabina (gotas + 3 espejos) | 16,671 ms | 17,482 ms | 17,804 ms | 0 | 0 | 195,5 | 9.227 |

Sin frames perdidos ni estancamientos; todas las medias dentro de
`budgets.pc.frame_budget_ms` (16,667 ms con tolerancia de vsync).

### Sonda GPU real (F3.5)

Cuatro mediciones por escena con lluvia activa, contrastadas con
`budgets.pc.gpu` (8 draw calls / 5 capas / 6 % de fill):

1. **Delta exacto de draw calls** (`Performance`, FX off vs on): rebanada
   **2,00**; cabina **2,40** (ruido del monitor; el FX real de cabina es 1:
   solo el quad de gotas de cámara, `enable_vfx=false`). Ambos ≤ 8.
2. **Fill visual real** (píxeles que cambian >6/255 con los FX visibles,
   materiales reales, menos el piso de ruido por la animación con `TIME`):
   rebanada **0,02 %** (ruido 0,00), cabina **2,78 %** (ruido 0,00). Evidencia
   en `f35_*_visual_off/on/diff.png`. Ambos ≤ 6 %.
3. **Fill de fragmentos y capas de overdraw** (sonda aditiva de 1/255 lineal
   sobre los materiales de los FX, calibrada con un quad a pantalla completa
   de 1 y 2 capas; sin asumir sRGB/gamma/tonemap): rebanada **3,64 %** de
   fragmentos, cabina **91,80 %**; capas máximas **1,0** en ambas (ruido de
   fondo 0,05 / 0,00 capas; píxeles excluidos 0,5 % / 4,3 %). Capas ≤ 5.
   - `fill_fragments` de cabina es **pantalla completa**: el quad de
     `camera_drops.gdshader` no tiene `discard`, así que la GPU procesa todos
     los píxeles aunque solo el 2,78 % sea visualmente distinto. Es
     diagnóstico, no una violación del presupuesto de fill (F3.4 definió el
     fill como cobertura visual); la optimización con `discard` queda
     anotada para F10.1 y **no** se toca el shader de F3.4 en esta subfase.
4. **Coste real de frame** (vsync desactivado, FX off vs on): rebanada
   **+1,164 ms**; cabina **+2,328 ms** (aprox. 7 % y 14 % del presupuesto de
   frame). Este método es inmune a la saturación por vsync.

`budgets.*.gpu.status` sigue en `pending_f34_f35` porque **el contrato no se
modifica en F3.5** (la prueba de lluvia lo exige); F10.1/F10.2 lo cierran con
la medición fina en dispositivo (RenderDoc/Adreno).

### Dispositivo (F3.5)

La prueba ADB ejecuta la **ruta de rendimiento** en el Redmi
(`DevicePerfProbe` + `tools/test_android_adb.ps1`): frame pacing, triángulos,
carga de escena, warm-up y PSS en rebanada y cabina. Los resultados se
registran en `docs/status/CURRENT.md` y en
`build/logs/android-smoke/perf_report.json`.
