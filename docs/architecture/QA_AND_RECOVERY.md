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
