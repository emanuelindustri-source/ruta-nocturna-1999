# Ruta Nocturna: 1999

Terror psicológico, conducción de supervivencia y exploración en una Venezuela
nocturna de diciembre de 1999. El protagonista cruza el país en un sedán beige
de 1999, con su mecánica, su radio y sus carreteras como sistema de supervivencia.

> **Estado actual:** Fase 4.1 completada (pipeline de rutas OSM/Overpass, DEM, grafo y alternativas).  
> **Versión:** `0.4.0`  
> **Web:** https://emanuelindustri-source.github.io/ruta-nocturna-1999/  
> **Repositorio:** https://github.com/emanuelindustri-source/ruta-nocturna-1999  
> **No hay todavía una build jugable.** Las fases 2.1–2.4 implementan motor, caja
> automática, frenos, combustible, térmica, cabina, manos IK, interacción,
> espejos, HUD, gamepad y guardado. F3.1/F3.2 añadieron el exterior y el interior
> definitivos; F3.3–F3.5 la lluvia física, el GLSL, los VFX y la medición en
> dispositivo. F4.1 añade la red de rutas reales comprimidas de Venezuela, con
> elevación DEM, atribución ODbL y alternativas. El terreno, el streaming de
> sectores de 800 m y los biomas llegan en F4.2/F4.3.

## Objetivo técnico

- Godot 4.7.2 stable.
- Windows y Linux con Forward+.
- Android 10–17 con renderer Mobile y una variante de compatibilidad si las
  pruebas de TV Box la justifican.
- Arte 3D generado de forma reproducible con Blender 4.5.16 headless.
- Audio y voces producidos por scripts locales; sin APIs de pago en el juego.
- Mundo inspirado en datos abiertos de OpenStreetMap y elevación DEM.
- Once idiomas, accesibilidad, guardado versionado y actualizador GitHub.

## Herramientas locales verificadas

| Herramienta | Ruta |
|---|---|
| Godot | `C:\Dev\Godot\godot.cmd` |
| Blender | `C:\Program Files\Blender Foundation\Blender 4.5\blender.exe` |
| Android SDK | `C:\Android` |
| Java 17 | `C:\Program Files\Eclipse Adoptium\jdk-17.0.21.10002-hotspot` |
| Python del sistema | `C:\Users\Sr_Hidalgo\AppData\Local\Programs\Python\Python314\python.exe` |
| Entorno Python del proyecto | `.venv\Scripts\python.exe` |
| Dispositivo de prueba | Redmi Note 12 Pro 5G por ADB |

Godot tenía una marca de compatibilidad “Ejecutar como administrador” que impedía
`--headless`. Fue retirada en la preparación de esta fase y la versión
`4.7.2.stable.official.ed1daf0bf` responde correctamente.

## Comandos de trabajo

```powershell
# Comprobar el entorno (los .cmd evitan problemas de ExecutionPolicy).
.\tools\dev\bootstrap.cmd

# Importar el proyecto y comprobar que las escenas cargan.
.\tools\dev\godot.cmd --headless --path . --editor --quit

# Ejecutar el chequeo de salud.
.\.venv\Scripts\python.exe tools\health_check.py --start

# Smoke test de los servicios base y del tren motriz.
.\tools\dev\smoke_test.cmd

# Pruebas profundas del tren motriz (motor, caja, frenos, térmica).
.\tools\dev\powertrain_test.cmd

# Pruebas de lluvia, humedad, limpiaparabrisas y charcos.
.\tools\dev\rain_test.cmd

# Pruebas de la red de rutas OSM, DEM, grafo y alternativas.
.\tools\dev\world_routes_test.cmd

# Regenerar la red de rutas (Overpass + DEM; escribe data/content/world/).
.\.venv\Scripts\python.exe tools\osm\build_world_routes.py

# Export de referencia (Windows y Android) a build/exports/.
.\tools\dev\export.cmd -Target all

# Prueba Android en el dispositivo autorizado por ADB.
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test_android_adb.ps1

# Validar todo lo anterior.
.\tools\dev\validate.cmd

# Sincronizar el roadmap de la web.
.\.venv\Scripts\python.exe tools\release\sync_roadmap.py

# Abrir la web local.
.\.venv\Scripts\python.exe -m http.server 8000 --directory docs
```

La política de ejecución de PowerShell está restringida en este equipo. Por eso
los wrappers `.cmd` invocan los scripts con `-ExecutionPolicy Bypass` sin cambiar
la configuración del sistema. Para automatizaciones directas:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\dev\bootstrap.ps1
```

## Estructura

```text
AGENTS.md                 reglas de ejecución y validación
ROADMAP.md                fases, versiones, modelos y gates de chat
data/schemas/             contratos canónicos y JSON Schemas
data/content/world/       red de rutas OSM comprimida y manifiesto (F4.1)
src/vehicle/              simulación del tren motriz y la cabina (F2)
src/weather/              humedad, gotas, limpiaparabrisas y charcos (F3.3)
src/world/                cargador de la red de rutas y rebanada vertical
tests/vehicle/            pruebas headless del vehículo
tests/weather/            pruebas headless de lluvia y superficies
tests/world/              pruebas headless de rutas, DEM y ODbL
docs/                     web de GitHub Pages, arquitectura y estado
localization/             claves base para los once idiomas
tools/                    validación, referencias y automatización
tools/osm/                pipeline Overpass/DEM y validador de rutas
assets/                   arte generado y manifiestos
scenes/ y src/            proyecto Godot
```

## Estado de la web

La web de `docs/` es una base estática sin imágenes de terceros. Presenta el
roadmap sincronizado con `ROADMAP.md`, el estado y los enlaces de privacidad.
Las capturas reales se incorporarán cuando exista una build visual.

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999

El script `tools/release/publish_github.cmd` documenta y automatiza la creación
del repositorio, el push y la configuración de Pages. No guarda tokens en Git.

## Biblioteca de referencias

El director mantiene material de referencia en
`C:\Dev\fotos de ejemplo`. Esa carpeta es **externa, de solo lectura y no se
versiona**. El proceso de consulta periódica está descrito en
`AGENTS.md` y `docs/reference/EXTERNAL_REFERENCE_LIBRARY.md`.

## Licencias

Código: MIT. Contenido original: CC BY-NC-SA 4.0. Datos OSM: ODbL. Las
dependencias y material de terceros conservan sus licencias. Ver `LICENSE`,
`ASSET_LICENSE.md` y `CREDITS.md`.
