# ROADMAP — Ruta Nocturna: 1999

**Versión actual:** `v0.2.2`  
**Subfase actual:** **2.4 — Espejos, HUD mínimo, gamepad/D-Pad y guardado**  
**Estado global:** Fase 1 completada; 2.1, 2.2 y 2.3 completadas; siguiente gate 2.4  
**Última fuente:** cierre de Fase 2.3 en GitHub

Esta es la fuente de verdad del desarrollo. Cada fila es un gate cerrado: no se
avanza sin validación, actualización de estado, commit, tag y cambio de chat.

## Cómo leer este roadmap

- **DS-R:** DeepSeek V4.1 Flash 1017 `#max` (razonamiento).
- **DS-S:** DeepSeek V4.1 Flash 1017 `#low` (estándar).
- **MiMo Pro:** MiMo-V2.6-Pro.
- **MiMo Flash:** MiMo-V2.6-Flash.
- **Gate de chat:** después de cada subfase se abre `/new`, se selecciona el modelo
  de la siguiente fila y se pega el prompt de continuidad de `AGENTS.md`.
- **Definición de terminado:** `AGENTS.md`, sección 17.
- **Revisión de referencias:** al inicio de cada subfase y en los hitos indicados;
  revisión completa cada 14 días. La biblioteca externa no se versiona.

## Hitos de referencia

| Hito | Versión | Significado |
|---|---|---|
| Vertical slice | `v0.1.3` | Coche gris, carretera gris, build PC/APK, CI |
| Vehículo funcional | `v0.2.3` | Física, cabina, manos IK, espejos |
| Arte del vehículo | `v0.3.4` | Modelo definitivo y shaders de lluvia |
| Mundo Venezuela | `v0.4.3` | OSM/DEM, biomas, clima y mapa |
| Supervivencia | `v0.5.4` | Economía, fauna, a pie, anti-atasco y vadeo |
| Folclore | `v0.6.3` | Entidades, sigilo, defensa y cámara |
| Campaña | `v0.7.5` | Actos, seis finales y contenido |
| Audio e idiomas | `v0.8.3` | Banda sonora, voces y 11 idiomas |
| Producto completo | `v0.9.4` | Menús, accesibilidad, OTA y web |
| Lanzamiento | `v1.0.0` | QA final, builds firmadas y release |

---

## Fase 1 — Fundación, contratos y vertical slice

**Versiones:** `v0.1.0` → `v0.1.3`  
**Objetivo:** dejar reglas, datos, repositorio, web y una base ejecutable antes de
invertir en arte o mecánicas complejas.

| Subfase | Versión | Modelo | Entregable | Estado |
|---|---|---|---|---|
| **1.1** | `v0.1.0` | **DS-S** | Proyecto, AGENTS, ROADMAP, contratos JSON, arquitectura, web Pages, herramientas de salud, referencias y bootstrap. Validado y publicado. | Completada |
| **1.2** | `v0.1.1` | **DS-R** | EventBus, once autoloads base, CrashReporter, CreatorQAMenu inicial, boot y smoke test sin mecánicas. Validado y publicado. | Completada |
| **1.3** | `v0.1.2` | **MiMo Pro** | Fábrica Blender headless, manifiestos, bloqueo del Esteem, LOD0/1/2 y ancla de rig. Validado y publicado. | Completada |
| **1.4** | `v0.1.3` | **DS-S** | CI, test Android/ADB, export Windows/APK, health check completo, Pages y tag de vertical slice. Validado y publicado. | Completada |

**Cierre:** `/new` después de cada subfase; cambio de modelo en 1.2, 1.3 y 1.4.

---

## Fase 2 — Física del vehículo, cabina e IK

**Versiones:** `v0.2.0` → `v0.2.3`  
**Objetivo:** un Esteem funcional, con manos y controles físicos, antes del arte final.

| Subfase | Versión | Modelo | Entregable | Estado |
|---|---|---|---|---|
| **2.1** | `v0.2.0` | **DS-R** | Motor, caja automática P-R-N-D-2-L, O/D, frenos, combustible, térmica, electroventilador y tests. Validado y publicado. | Completada |
| **2.2** | `v0.2.1` | **MiMo Pro** | Cabina funcional, volante, palanca, freno de mano, radio, guantera, paneles, rig de manos y poses IK. Validado y publicado. | Completada |
| **2.3** | `v0.2.2` | **DS-R** | Interacción contextual “mirar/tocar”, IK 2/1/0 manos, puertas, seguros, vidrios, luces, antena y radio. Validado y publicado. | Completada |
| **2.4** | `v0.2.3` | **MiMo Flash** | Espejos `SubViewport`, HUD mínimo, gamepad/D-Pad, save v0.2.0, QA de reparaciones y ADB. | Pendiente |

**Cierre:** revisar fotos reales de interior y mecánica antes de 2.2; `/new` tras cada fila.

---

## Fase 3 — Arte definitivo del Esteem y shaders de agua

**Versiones:** `v0.3.0` → `v0.3.4`  
**Objetivo:** coche exterior/interior de calidad, materiales PBR y lluvia física 1999.

| Subfase | Versión | Modelo | Entregable | Estado |
|---|---|---|---|---|
| **3.1** | `v0.3.0` | **MiMo Pro** | Exterior final, piezas separadas, LODs, PBR, llantas, faros y espejos. | Pendiente |
| **3.2** | `v0.3.1` | **MiMo Pro** | Interior final, tablero, telas, asientos, herramientas, maletero y manos. | Pendiente |
| **3.3** | `v0.3.2` | **DS-R** | Matemática de humedad, flujo de gotas, limpiaparabrisas, charcos y presupuesto. | Pendiente |
| **3.4** | `v0.3.3` | **MiMo Pro** | GLSL de producción, gotas, barrido, escurrido, charcos, asfalto mojado y VFX. | Pendiente |
| **3.5** | `v0.3.4` | **MiMo Flash** | Integración, compresión, warm-up, rendimiento y capturas de referencia visual. | Pendiente |

**Cierre:** revisión de fotos y conceptos antes de 3.1/3.2; `/new` tras cada fila.

---

## Fase 4 — Venezuela, OSM/DEM, biomas y clima

**Versiones:** `v0.4.0` → `v0.4.3`  
**Objetivo:** seis regiones conectadas, con rutas reales comprimidas, clima dinámico y mapa de papel.

| Subfase | Versión | Modelo | Entregable | Estado |
|---|---|---|---|---|
| **4.1** | `v0.4.0` | **DS-R** | Pipeline OSM/Overpass, DEM, grafo, rutas alternativas, caché y atribución ODbL. | Pendiente |
| **4.2** | `v0.4.1` | **DS-R** | Terrain3D, streaming de sectores de 800 m, colisión, carga asíncrona y PSS ≤ 1.2 GB. | Pendiente |
| **4.3** | `v0.4.2` | **MiMo Pro** | Kits de biomas, gasolineras, moteles, peajes, señalización, agua, polvo y nieve. | Pendiente |
| **4.4** | `v0.4.3` | **DS-S** | WeatherManager, transiciones, rayos/truenos, humedad, QA de regiones/clima y mapa de papel. | Pendiente |

**Cierre:** revisar referencias de paisajes; `/new` tras cada fila.

---

## Fase 5 — Supervivencia, anti-atasco, vadeo y exploración a pie

**Versiones:** `v0.5.0` → `v0.5.4`  
**Objetivo:** que el coche y la carretera importen; que ninguna partida quede bloqueada.

| Subfase | Versión | Modelo | Entregable | Estado |
|---|---|---|---|---|
| **5.1** | `v0.5.0` | **DS-R** | Desgaste, reparaciones, combustible, anti-atasco, grúa, vadeo, hidrobloqueo y retorno seguro. | Pendiente |
| **5.2** | `v0.5.1` | **DS-R** | Tráfico, fauna, cruces de animales, evitación, spawn y niveles de simulación. | Pendiente |
| **5.3** | `v0.5.2` | **MiMo Pro** | Fauna, ganado, aves, caimán, herramientas, tablas, gato, gasolineras y moteles. | Pendiente |
| **5.4** | `v0.5.3` | **DS-S** | Caminar, correr, estamina, linterna, agacharse, escondites, entrada/salida y secado de motor. | Pendiente |
| **5.5** | `v0.5.4` | **MiMo Flash** | Integración, pruebas de vadeo/volcadura, HUD a pie, ADB, rendimiento y bugs. | Pendiente |

**Cierre:** revisar manual, motor y herramientas antes de 5.1/5.3; `/new` tras cada fila.

---

## Fase 6 — Folclore, sigilo, combate y cámara

**Versiones:** `v0.6.0` → `v0.6.3`  
**Objetivo:** las entidades se sienten, se escuchan y se pueden sobrevivir.

| Subfase | Versión | Modelo | Entregable | Estado |
|---|---|---|---|---|
| **6.1** | `v0.6.0` | **DS-R** | IA de las siete entidades, percepción, audio invertido del Silbón, navmesh y director de tensión. | Pendiente |
| **6.2** | `v0.6.1` | **MiMo Pro** | Modelos, rigs, animaciones, siluetas, VFX y LODs de las entidades. | Pendiente |
| **6.3** | `v0.6.2` | **DS-S** | Sigilo, escondites, defensa, herramientas, miedo/sanidad, cámara y álbum. | Pendiente |
| **6.4** | `v0.6.3` | **MiMo Flash** | Integración de VFX/audio, QA de entidades, accesibilidad y pruebas en dispositivo. | Pendiente |

**Cierre:** revisar leyendas; `/new` tras cada fila.

---

## Fase 7 — Pasajeros, campaña, diálogos y finales

**Versiones:** `v0.7.0` → `v0.7.5`  
**Objetivo:** campaña de tres actos con pasajeros, confianza y seis finales.

| Subfase | Versión | Modelo | Entregable | Estado |
|---|---|---|---|---|
| **7.1** | `v0.7.0` | **DS-R** | Motor de diálogo, confianza, humanidad, condiciones, finales y validador de ramas. | Pendiente |
| **7.2** | `v0.7.1` | **DS-S** | Director de campaña, eventos, pasajeros, encomiendas, checkpoints y autoguardado. | Pendiente |
| **7.3** | `v0.7.2` | **MiMo Pro** | Pasajeros, ropa de época, rostros, rigs, animaciones y cámaras. | Pendiente |
| **7.4** | `v0.7.3` | **MiMo Flash** | Integración del Acto I–II, misiones, subtítulos, ritmo y bugs. | Pendiente |
| **7.5** | `v0.7.4` | **MiMo Flash** | Acto III, conexión de los seis finales, continuidad y pruebas narrativas. | Pendiente |
| **7.6** | `v0.7.5` | **DS-S** | Bloqueo de contenido, duración real, banderas y primera medición de las 10 horas. | Pendiente |

**Cierre:** chat nuevo después de cada acto; revisar leyendas y personajes.

---

## Fase 8 — Audio, música, voces e idiomas

**Versiones:** `v0.8.0` → `v0.8.3`  
**Objetivo:** audio Hi-Fi 3D, música venezolana propia y once idiomas.

| Subfase | Versión | Modelo | Entregable | Estado |
|---|---|---|---|---|
| **8.1** | `v0.8.0` | **DS-S** | Buses, 3D, oclusión, reverb, prioridad, radio, eventos accesibles y sonido del Silbón. | Pendiente |
| **8.2** | `v0.8.1` | **MiMo Flash** | Síntesis de cuatro, arpa, bandola, maracas, tambor, ambientes y SFX en OGG. | Pendiente |
| **8.3** | `v0.8.2` | **MiMo Flash** | `edge-tts` en build, es-VE, filtros AM, susurros, ecos, caché y puerta de licencia. | Pendiente |
| **8.4** | `v0.8.3` | **DS-S** | Once locales, subtítulos, validación de claves, fuentes CJK/cirílicas y glifos. | Pendiente |

**Cierre:** sin audio de pago; `/new` tras cada fila.

---

## Fase 9 — Menús, accesibilidad, guardado, perfilador y OTA

**Versiones:** `v0.9.0` → `v0.9.4`  
**Objetivo:** producto completo, configurable y actualizable.

| Subfase | Versión | Modelo | Entregable | Estado |
|---|---|---|---|---|
| **9.1** | `v0.9.0` | **DS-S** | Menús completos, gráficos, audio, subtítulos, accesibilidad, input y D-Pad. | Pendiente |
| **9.2** | `v0.9.1` | **MiMo Flash** | Integración visual 1999, panel QA final, foco de menús y corrección de UI. | Pendiente |
| **9.3** | `v0.9.2` | **DS-R** | HardwareProfiler C++/NDK, cinco perfiles, presupuestos, FSR PC y resolución móvil. | Pendiente |
| **9.4** | `v0.9.3` | **DS-S** | Guardado manual/autoguardado, slots, backups y migraciones desde v0.2.0. | Pendiente |
| **9.5** | `v0.9.4` | **DS-S** | OTA GitHub, variante Play, AAB base, privacidad, web y release automation. | Pendiente |

**Cierre:** `/new` tras cada fila.

---

## Fase 10 — Optimización, QA y lanzamiento

**Versiones:** `v0.10.0` → `v1.0.0`  
**Objetivo:** cerrar sin deuda crítica y publicar.

| Subfase | Versión | Modelo | Entregable | Estado |
|---|---|---|---|---|
| **10.1** | `v0.10.0` | **DS-R** | Optimización CPU/GPU/RAM, streaming, warm-up, shaders, carga y frame pacing. | Pendiente |
| **10.2** | `v0.10.1` | **MiMo Flash** | ADB, Android 10–17, TV Box, Windows/Linux, AAB, 16 KB, store assets e ICO. | Pendiente |
| **10.3** | `v0.10.2` | **DS-S** | QA integral: campaña, finales, guardados, idiomas, accesibilidad, cámara y OTA. | Pendiente |
| **10.4** | `v1.0.0` | **DS-S** | Release Candidate, limpieza, firma, artifacts, GitHub Release, Pages, tag final. | Pendiente |

**Cierre:** solo con QA aprobado; `/new` tras 10.1–10.3. El cierre de `v1.0.0`
incluye el informe final y el prompt de mantenimiento.

---

## Condiciones globales de cierre

1. `python tools/health_check.py --end` pasa.
2. `ROADMAP.md`, `docs/roadmap-data.json` y `CHANGELOG.md` coinciden.
3. `docs/status/CURRENT.md` y `HANDOFF.md` reflejan el estado real.
4. Las referencias relevantes fueron revisadas y registradas.
5. No se rompió ningún presupuesto de rendimiento.
6. No hay secretos, binarios intermedios ni assets sin licencia en Git.
7. Se abrió `/new` con el siguiente modelo antes de continuar.
