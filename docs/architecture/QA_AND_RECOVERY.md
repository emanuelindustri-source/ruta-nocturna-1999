# QA, caja negra y recuperación

**Estado:** contratos definidos en Fase 1.1; caja negra y panel QA inicial implementados en Fase 1.2.

## 1. Regla principal

Khristyan no depura código. Cada fallo debe producir información suficiente para
que un agente lo reproduzca y lo corrija sin interrogatorios técnicos.

## 2. Chequeo de salud

Comando:

```powershell
.\.venv\Scripts\python.exe tools\health_check.py --start
.\.venv\Scripts\python.exe tools\health_check.py --end
```

El chequeo inspecciona:

- Archivos base y versión.
- JSON Schemas y referencias cruzadas.
- Claves de localización y glifos de tofu.
- Sincronización del roadmap y de la web.
- Biblioteca externa de referencias y frescura de la revisión.
- Git, rama y cambios locales.
- Espacio libre en `C:`.
- Rutas de Godot, Blender, ADB, gh y keystore.
- Ausencia de APK/AAB/keystores en el árbol.
- Importación de Godot en headless.

Informes: `build/logs/health/latest.json`, ignorado por Git.

Un error bloquea la subfase. Una advertencia requiere una decisión documentada.

## 3. Caja negra de errores

### Implementación

- Autoload `CrashReporter`.
- Logger personalizado con `OS.add_logger()`.
- Contexto periódico de versión, región, clima, estado del vehículo, hora y
  últimas acciones.
- Últimas 200 líneas de log.
- Detección de shader o recurso fallido.
- Detección de caída de FPS sostenida.
- Marcador de sesión para cierres nativos.

### Archivo

```text
user://ultimo_reporte_error.txt
```

### Lo que sí puede capturar

- Errores de GDScript con stack cuando el motor lo expone.
- Errores de carga de recursos y compilación de shaders.
- FPS por debajo del umbral durante una ventana de tiempo.
- Cierres inesperados detectados en el siguiente arranque.

### Lo que no puede capturar

- Un segfault nativo dentro del mismo proceso.
- Un proceso matado a la fuerza sin dejar contexto.
- Un fallo del sistema operativo o del driver.

En esos casos se conserva el último contexto y el reporte se genera al abrir de
nuevo. En Android QA se complementa con `logcat`; en una build de Google Play, con
los informes de Play Console.

### Reporte mínimo

```text
RUTA NOCTURNA 1999 - REPORTE
versión:
plataforma:
región:
clima:
hora:
estado del vehículo:
última acción:
tipo de fallo:
stack disponible:
últimas líneas:
```

No se sube automáticamente. El jugador puede copiar el texto en el panel.

## 4. Panel secreto CreatorQA

- Activación: cinco toques rápidos en la esquina superior izquierda de la pausa.
- Activación PC: `F12`.
- Activación gamepad/TV: combinación documentada en Fase 9.2.
- No se muestra en build Play salvo una bandera de compilación explícita.
- Las acciones usan APIs del juego, no edición directa de archivos.
- Se avisa si se trabaja sobre una ranura QA.

Funciones:

- Teleport a las seis regiones y rutas alternativas.
- Forzar clima y hora.
- Invocar o despachar entidades y fauna.
- Reparar, dañar, llenar gasolina o sumar bolívares.
- Reset de vehículo a punto seguro.
- Resumen de flags, confianza, humanidad y misión.
- Copiar reporte QA.

## 5. Anti-atasco

La partida nunca queda irrecuperable.

Disparadores:

- Volcado durante 3 segundos.
- Sin contacto de ruedas con acelerador, sin progreso.
- Atasco prolongado en barro o arena.
- Fuera de la superficie o del sector.
- Agua por encima del umbral.
- Daño crítico sin posibilidad de movimiento.

Salidas:

1. Autorrescate con gato, tablas y llave de cruz.
2. Grúa o auxilio vial con costo y paso de tiempo.
3. Deuda narrativa si no hay dinero.
4. Retorno al último punto seguro si la geometría falla.

Después del rescate se valida el punto sobre la red vial y se guarda.

## 6. Vadeo

- Profundidad, inclinación y velocidad se calculan en la simulación.
- La admisión tiene una altura versionada en el vehículo.
- El oleaje eleva la probabilidad de entrada de agua.
- El motor puede calarse; secar filtro y bujías exige linterna y herramientas.
- La grúa siempre está disponible como salida.
- Los parámetros no se ajustan desde la UI sin pasar por tuning documentado.

## 7. Android y ADB

Cuando exista build:

```powershell
.\tools\test_android_adb.ps1
```

Debe:

1. Verificar dispositivo autorizado.
2. Compilar APK debug.
3. Instalar con `adb install -r`.
4. Abrir el juego.
5. Esperar el primer frame (timeout 90 s).
6. Monitorear 15 s de `logcat`.
7. Buscar `FATAL EXCEPTION`, errores Godot y errores Vulkan.
8. Tomar captura.
9. Recoger PSS con `dumpsys meminfo`.
10. Guardar logs en `build/logs/android-smoke/`.

Un APK que no supera el smoke test no se etiqueta.

## 8. Rendimiento

| Presupuesto | Meta |
|---|---|
| Android baja/TV | 30 FPS estables |
| Redmi/media | 60 FPS |
| PC | 60 FPS |
| Triángulos visibles Android | ≤ 120.000 |
| Triángulos visibles PC | ≤ 450.000 |
| PSS Android | ≤ 1.2 GB |
| Sector | 800 m |
| Carga | Threaded, máximo 2 solicitudes |
| LODs | 0, 1 y 2 obligatorios |
| Shaders | Warm-up antes de gameplay |

El conteo móvil incluye espejos activos. Las pruebas se hacen en ruta real y con
tormenta. FSR es opción PC Forward+; en móvil se usa resolución dinámica.

## 9. Material de tienda

- Iconos y banners se generan con Blender/Pillow y se validan.
- Capturas de tienda salen de la build real.
- No se usan imágenes de referencia sin licencia.
- No se presentan renders como si fueran gameplay.
- La versión vertical solo se etiqueta como captura si la app soporta esa vista.

## 10. Criterio de cierre

Una subfase no termina porque “se ve bien”. Termina cuando el health check, los
tests, el import y las pruebas aplicables dan evidencia, y el estado quedó
documentado.

## 11. Implementación de la Fase 1.2

- `CrashReporter` instala un `Logger` nativo con `OS.add_logger()`.
- Conserva las últimas 200 líneas y las últimas 40 acciones.
- Escribe `user://ultimo_reporte_error.txt` bajo demanda, en errores de GDScript
  y al detectar un cierre anormal previo.
- Usa `user://sesion_activa.json` como marcador; se elimina en una salida limpia.
- El reporte incluye versión, plataforma, idioma, clima, estado de juego, acciones,
  contexto por servicio y log reciente. Nunca se sube automáticamente.
- `CreatorQAMenu` se abre con F12 o cinco toques en la esquina superior izquierda.
  En build de tienda solo se habilita con `ruta_nocturna/qa/allow_in_release` o
  con `--qa` en la línea de comandos.
- Acciones actuales del panel: consultar estado, forzar clima, escribir/copiar el
  reporte, alternar modo de prueba y limpiar banderas.
- El smoke test comprueba el reporte y el marcador de sesión. La ruta de cierre
  anormal se probó simulando un marcador huérfano: el reporte se emitió en el
  siguiente arranque. Un warning no escribe reporte; un error de GDScript sí.
  La detección de un cierre nativo real se probará con una build Android en la
  Fase 1.4.

## 12. Implementación de la Fase 1.4

- `tools/test_android_adb.ps1` implementa el protocolo de la sección 7: dispositivo
  autorizado, APK debug, `adb install -r`, `pm clear`, arranque con `monkey`,
  marcador de sesión local/`BOOT_READY`, 15 s de `logcat`, captura, PSS y logs.
- Godot 4.7.2 no publica `print()` en `logcat` en esta build Android; el script
  acepta el marcador `files/sesion_activa.json` (vía `run-as`) como evidencia de
  arranque y complementa con proceso vivo, captura y ausencia de errores fatales.
- En MIUI/HyperOS el paquete necesita el permiso "Instalar vía USB"; sin él,
  `adb install` falla con `INSTALL_FAILED_USER_RESTRICTED`.
- La APK de referencia es debug y se firma con el keystore de depuración local; no
  se versiona. Los artefactos viven en `build/exports/` y `build/logs/`.
- El presupuesto de PSS se comprueba con `dumpsys meminfo` contra 1,2 GB. La
  rebanada vertical no es una prueba de rendimiento de gameplay, solo un control
  de arranque y memoria base.
- `health_check.py --end` añade validación de presets, toolchain de build,
  dispositivo ADB y secretos/binarios en el índice de Git.
- Detalle operativo en `docs/architecture/BUILD_AND_RELEASE.md`.

## 14. Espejos, HUD, gamepad, guardado y ADB (Fase 2.4)

### QA de reparaciones

- `CreatorQAMenu` añade la sección **Vehículo** con seis acciones que usan
  `VehiclePowertrain` localizado por el grupo de escena `vehicle_powertrain`:
  reparar motor (`engine.seized`), reparar refrigeración (fusible, relé,
  motor y termostato), reparar frenos (pastillas y cilindro maestro), llenar
  el tanque, fijar combustible bajo y dañar el fusible del ventilador.
- Sin tren motriz en la escena, los botones quedan deshabilitados y el estado
  muestra `QA_STATUS_NO_VEHICLE`. Tras cada acción se da un paso corto de
  `simulate()` para refrescar los avisos (el cabina no simula en automático).
- El panel QA también se instancia en `scenes/vehicle/CabinInteraction.tscn`
  (F12 en cabina). Las acciones de F1.2 siguen intactas.

### Guardado QA

- Guardar/cargar desde el panel usa `SaveManager.save_slot/load_slot(0, …, 1)`:
  siempre en `user://saves/qa/`, nunca sobre una partida real.
- Pruebas del smoke test: fixture `tests/fixtures/save_v0_2_0.json` cargado con
  verificación de checksum y aplicación del estado; backup `.bak` antes de
  sobrescribir; sin `.tmp` residuales; `save_version: 99` rechazado en carga y
  guardado sin alterar el archivo.
- Corrección derivada: `DirAccess.copy()` con rutas relativas fallaba al abrir
  el origen (se resuelve contra el proceso, no contra el `DirAccess`); ahora
  el backup usa rutas absolutas.

### Gamepad y D-Pad

- `project.godot` declara `[input]` para `ui_accept` (Enter, KP Enter, Space,
  A) y `ui_cancel` (Esc, B); `ui_up/down/left/right` conservan los defaults con
  D-Pad (11–14) y stick izquierdo. Lo comprueba el smoke test por evento.
- En cabina, `CabinGamepadAdapter` maneja solo `InputEventJoypad*`: D-Pad
  cicla el foco contextual, A pulsa, B suelta y limpia, stick derecho rota la
  cámara dentro de los límites de F2.3. Tacto y ratón no cambian.
- Con el panel QA abierto el adaptador se suspende (grupo `creator_qa_menu`).

### Prueba ADB en el Redmi (2026-11-22)

```powershell
.\tools\test_android_adb.ps1
```

| Paso | Resultado |
|---|---|
| Dispositivo | `obojropz89mbwgpn` (Redmi 22101316G) autorizado |
| APK debug | 28.827.443 bytes, SHA-256 `E587066C…C4489`, export OK |
| Instalación | `adb install -r` incremental: Success |
| Arranque | `monkey` + marcador de sesión; primer frame dentro del timeout |
| logcat 15 s | Sin `FATAL EXCEPTION`, sin errores Godot ni Vulkan |
| Captura | `build/logs/android-smoke/` (no versionada) |
| PSS | **379,8 MB** (presupuesto 1.228,8 MB) |

La APK de F2.4 es debug y no se versiona; vive en `build/exports/` y va a
Releases si se publica. El presupuesto de PSS se cumple, pero esta prueba es de
arranque y memoria base: el rendimiento en ruta real con espejos activos se
mide en F3.5/F10.1.

## 13. Tren motriz (Fase 2.1)

### Pruebas

```powershell
.\tools\dev\powertrain_test.cmd
```

- `tests/vehicle/PowertrainTest.tscn` ejecuta 125 comprobaciones headless:
  contrato, arranque, ralentí, P-R-N-D-2-L, Overdrive, convertidor, frenos,
  combustible, térmica, electroventilador, fallos, ahogo/secado y retención.
- El log queda en `build/logs/powertrain/latest.log` (ignorado por Git).
- `tools/dev/smoke_test.cmd` incluye una prueba de integración del tren motriz
  además de los servicios base y el bloqueo.
- `health_check.py` ejecuta `powertrain_tests` como chequeo independiente y el
  smoke test como hasta ahora. `--skip-godot`/`--skip-smoke` omiten ambos.

### Criterios

- El contrato debe cargar sin errores y coincidir con `vehicle_components.json`.
- El motor no arranca en `D`/`R`; solo en `P`/`N`.
- La caja no permite `P`/`R` en movimiento ni `D` en reversa.
- La frenada de 100 km/h debe quedar por debajo de 60 m en el modelo.
- El tanque no supera 50 L; el motor se cala por debajo del umbral de vacío.
- El ventilador debe pasar por baja y alta; un fusible abierto debe provocar
  sobrecalentamiento y modo seguro.
- Un motor agarrotado se repara por API y vuelve a arrancar; la recuperación
  completa anti-atasco sigue siendo F5.1.

### Límites

- Es una simulación longitudinal, no una prueba de `VehicleBody3D`, suspensión,
  neumáticos ni colisión.
- Las pruebas se ejecutan con temperatura ambiente fija; la integración con
  `WeatherManager` es F4.4.
- Los valores de relaciones, curva de par, umbrales térmicos y masas son
  provisionales y están marcados en el contrato. No se presentan como datos
  oficiales del manual.
- No sustituye la prueba Android/ADB de un hito de build. En 2.1 se comprueba que
  el dispositivo siga autorizado, pero no se publica una APK nueva.

## 15. Lluvia, humedad y presupuestos (Fase 3.3)

### Pruebas

```powershell
.\tools\dev\rain_test.cmd
```

- `tests/weather/RainFxTest.tscn` ejecuta **126 comprobaciones** headless:
  contrato, humedad, determinismo de gotas, barrido, desgaste, charcos,
  hidroplaneo, vadeo y presupuesto CPU.
- El log queda en `build/logs/rain/latest.log` (ignorado por Git).
- `health_check.py` ejecuta la prueba como chequeo independiente
  (`rain_tests`). `--skip-godot`/`--skip-smoke` la omiten con el resto.
- La CI ejecuta la prueba en Linux después del import.

### Presupuesto medido (2026-11-23)

| Perfil | Configuración | Media | p95 | Presupuesto |
|---|---|---|---|---|
| PC | 4.096 gotas, 24 charcos, 2 escobillas, 60 Hz | ~0,21 ms | ~0,28 ms | 1,0 / 1,6 ms |
| Móvil | 1.536 gotas, 12 charcos, 2 escobillas, 30 Hz | ~0,17 ms | ~0,21 ms | 1,5 / 2,4 ms |

La prueba llena los campos a su capacidad y mide 300 pasos tras 120 de warm-up.
El máximo observado (3,3 ms PC / 1,8 ms móvil) incluye picos de depuración y no
se usa como criterio de frame. El coste GPU, el overdraw, el warm-up de shaders
y el PSS en ruta se miden en F3.4/F3.5/F10.1; no se declaran optimizaciones sin
medición.

### Criterios

- El contrato debe validar y coincidir con `exterior_spec.json` (parabrisas y
  escobillas) y `vehicle_components.json` (admisión y profundidad segura).
- La humedad nunca sale de 0..1; la película nunca es negativa.
- Las gotas no superan la capacidad, no salen de bounds sin contabilizarse y no
  producen NaN.
- El limpiaparabrisas completa ciclos, respeta la intermitencia y degrada la
  limpieza con el desgaste sin bloquear controles.
- Los charcos no superan su capacidad, drenan al dejar de llover y el riesgo de
  hidroplaneo crece con profundidad y velocidad.
- La media y el p95 de CPU deben quedar dentro del contrato en PC y móvil.

### Límites

- F3.3 no implementa shaders, VFX, arte, pérdida de agarre ni vadeo.
- La medición es de escritorio y headless; el Redmi se mide en F3.5/F10.2.

## 16. GLSL de producción, VFX y render real (Fase 3.4)

### Pruebas

```powershell
.\tools\dev\rain_test.cmd          # headless: contratos, modelos y uniforms
.\tools\dev\render_test.cmd        # ventana Vulkan Forward+: render real y GPU
```

- La prueba de lluvia amplía sus comprobaciones con los shaders (carga,
  uniforms, include común), el `RainFxController` (enlace de materiales,
  uniforms que siguen a los modelos, pivotes de escobilla, charcos visibles y
  gotas de cámara) y los presupuestos GPU proyectados contra
  `budgets.*.gpu`.
- `tests/render/RainFxRenderTest.tscn` carga boot, rebanada y cabina en
  ventana, captura `build/logs/render/f34_*.png`, mide frame time medio/p95,
  draw calls y primitivas reales, y comprueba que el warm-up termina antes de
  activar los FX (`[RAINFX] WARMUP_*` antes de `VERTICAL_SLICE_READY`).
- La build de Windows exportada se ejecuta 20 s y debe cerrar limpia (exit 0,
  sin marcador de sesión residual).

### Presupuesto GPU proyectado (peor caso)

| Elemento | Draw calls | Overdraw | Fill estimado | Presupuesto móvil |
|---|---|---|---|---|
| Estrellas + salpicaduras + gotas de cámara | 3 | 3 capas | ~6 % | 4 / 3 / 10 % |

Los materiales mojados sustituyen a los materiales existentes con
`material_override` y no añaden llamadas de dibujo. El overdraw y el fill son
estimaciones del diseño de VFX; la medición GPU real es F3.5/F10.1.

### Criterios

- Ningún shader contiene valores de balance: todo llega por uniform desde los
  modelos de F3.3.
- El warm-up se ejecuta antes del gameplay y los FX no se activan hasta que
  termina.
- Las llamadas de dibujo añadidas, el overdraw y el fill estimado se mantienen
  dentro de `budgets.*.gpu` en PC y móvil.
- El frame time medio con lluvia activa se mantiene dentro del presupuesto de
  frame del contrato (con tolerancia de vsync a 60 Hz).

### Límites

- No hay pérdida de agarre, daño, vadeo ni anti-atasco: eso es F5.1.
- La lluvia de las escenas es lookdev; la real llega con `WeatherManager` en
  F4.4.
- La medición GPU en ruta y dispositivo (RenderDoc, Adreno Profiler, PSS) es
  F3.5/F10.1/F10.2.
