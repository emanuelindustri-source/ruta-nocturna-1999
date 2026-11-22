# AGENTS.md — Reglas maestras de Ruta Nocturna: 1999

Este archivo es obligatorio para cualquier agente que trabaje en el proyecto. Se lee
antes de tocar código, modelos, datos, audio, documentación o Git.

## 1. Identidad y contrato con el director

- Proyecto: **Ruta Nocturna: 1999**.
- Director y propietario: **Khristyan Hidalgo** (`emanuelindustri-source`).
- Khristyan **no programa ni modela en 3D**. El agente es responsable de código,
  modelado paramétrico, texturas, shaders, audio, pruebas, compilación y publicación.
- El idioma de comunicación con Khristyan es **español**.
- Los identificadores de código, nombres de archivos y APIs van en inglés.
- Nunca se pide al director editar código, Blender, shaders, JSON o configuraciones a mano.
- Si una acción requiere una cuenta, autorización o firma de Khristyan, se le explica
  en pasos breves y se detiene la acción correspondiente hasta recibir autorización.

## 2. Lectura obligatoria y orden de trabajo

Al comenzar cada chat, leer completos:

1. `AGENTS.md`.
2. `ROADMAP.md`.
3. `docs/status/CURRENT.md`.
4. `docs/status/HANDOFF.md`.
5. Los documentos de arquitectura y contratos relevantes a la subfase.

Después:

1. Verificar que el modelo seleccionado coincide con la subfase.
2. Ejecutar `python tools/health_check.py --start`.
3. Ejecutar `python tools/scan_reference_library.py --quick`.
4. Revisar solo las referencias del catálogo relevantes para la subfase.
5. Ejecutar exclusivamente la subfase asignada.
6. No avanzar ni empezar otra subfase.

## 3. Enrutamiento de modelos

Los nombres comerciales y los selectores exactos de OpenCode son:

| Alias | Modelo | Selector |
|---|---|---|
| **DS-R** | DeepSeek V4.1 Flash 1017 — Razonamiento | `opencode-go/deepseek-v4.1-flash#max` |
| **DS-S** | DeepSeek V4.1 Flash 1017 — Estándar | `opencode-go/deepseek-v4.1-flash#low` |
| **MiMo Pro** | MiMo-V2.6-Pro | `opencode-go/mimo-v2.6-pro` |
| **MiMo Flash** | MiMo-V2.6-Flash | `opencode-go/mimo-v2.6-flash` |

Responsabilidades:

- **DS-R:** arquitectura, física del vehículo, Vadeo, anti-atasco, IK, C++/NDK,
  perfilador, IA, árboles de diálogo/finales, rutas OSM, matemática de shaders.
- **DS-S:** GDScript de sistemas, menús, guardado, localización, economía, OTA,
  GitHub Actions, validadores, documentación de estado.
- **MiMo Pro:** Blender headless, mallas, UV, rigging, PBR, gotas/charcos,
  niebla, criaturas, biomas, pasajeros y assets visuales complejos.
- **MiMo Flash:** prototipado rápido, UI, audio procedural, builds, ADB, corrección
  de compilación, integración y pruebas de dispositivo.

La asignación por subfase está en `ROADMAP.md`. Si el chat se abre con otro modelo:

1. No modificar archivos.
2. Informar al director del modelo requerido.
3. Pedir que abra el chat correcto o cambie de modelo.
4. No intentar “compensar” con otro modelo.

## 4. Protocolo de contexto y cambio de chat

- Se abre un chat nuevo al final de **cada subfase**.
- También es obligatorio cambiar de chat si el contexto supera ~60 % o si fallan
  dos intentos de la misma validación.
- Nunca se usa `/compact` como sustituto del cambio de chat.
- No se comienza la subfase siguiente en el mismo chat.
- En subfases largas de contenido se permite un checkpoint interno al 50 %, con
  actualización de `CURRENT.md` y el mismo modelo; nunca se salta de subfase.

### Handoff obligatorio

Al cerrar una subfase:

1. Ejecutar todas las validaciones.
2. Actualizar `ROADMAP.md`, `docs/roadmap-data.json`, `CHANGELOG.md`,
   `docs/status/CURRENT.md` y `docs/status/HANDOFF.md`.
3. Registrar referencias usadas, decisiones, pruebas y riesgos.
4. Hacer commit convencional.
5. Crear el tag semver y hacer push **solo si la validación y la autenticación lo permiten**.
6. Entregar el prompt del siguiente chat con el modelo exacto.

Si falla algo:

- No marcar la subfase como completada.
- No crear tag.
- No afirmar que “casi funciona”.
- Documentar el error, los logs y el siguiente intento.

## 5. Restricciones absolutas

- **Prohibido Tripo AI** y cualquier generador 3D de pago o con suscripción.
- Prohibidas APIs de voz o audio de pago en el juego.
- Prohibido usar assets de licencia desconocida en el build.
- Prohibido copiar imágenes de la biblioteca de referencias al juego o a la web.
- Prohibido editar manualmente `.blend`; todo se genera con scripts `bpy`.
- Prohibido introducir dependencias circulares entre autoloads.
- Prohibido publicar un tag con `health_check.py` fallando.
- Prohibido afirmar que se probó algo sin logs, capturas o resultados.
- Prohibido eliminar trabajo del director sin autorización.
- Prohibido guardar tokens, keystores o contraseñas en Git.
- Prohibido subir APK/AAB intermedios al repositorio.
- Prohibido generar assets de tienda falsos o capturas que no representen el juego.
- Prohibido implementar mecánicas antes de que exista su contrato de datos.
- Prohibido dejar una partida irrecuperable por atascos, volcaduras o agua.

## 6. Herramientas y rutas de confianza

Usar rutas absolutas o los wrappers del proyecto. Si una herramienta no responde,
fallar de forma visible y no fingir éxito.

| Herramienta | Ruta |
|---|---|
| Godot 4.7.2 | `C:\Dev\Godot\Godot_v4.7.2-stable_win64_console.exe` |
| Wrapper Godot | `.\tools\dev\godot.ps1` |
| Blender 4.5.16 | `C:\Program Files\Blender Foundation\Blender 4.5\blender.exe` |
| ADB | `C:\Android\platform-tools\adb.exe` |
| Android SDK | `C:\Android` |
| Java 17 | `C:\Program Files\Eclipse Adoptium\jdk-17.0.21.10002-hotspot` |
| Debug keystore | `C:\Android\debug.keystore` |
| Python 3.14 | `C:\Users\Sr_Hidalgo\AppData\Local\Programs\Python\Python314\python.exe` |
| Entorno del proyecto | `.venv\Scripts\python.exe` |
| GitHub CLI | `C:\Program Files\GitHub CLI\gh.exe` |
| Redmi de pruebas | dispositivo ADB conectado / verificar `adb devices -l` |

Antes de build o release:

- Comprobar versiones.
- Comprobar espacio libre (mínimo 20 GB; bloquear por debajo de 10 GB).
- Comprobar que el dispositivo ADB está autorizado.
- Comprobar que el proyecto no tiene secretos versionados.
- Comprobar que el Godot CLI funciona sin elevación.

## 7. Datos primero: contratos y máquinas de estados

Los sistemas de juego se implementan solo después de que existan y validen:

- `data/schemas/vehicle_components.json`
- `data/schemas/folklore_entities.json`
- `data/schemas/dialogue_and_endings.json`
- `data/schemas/inventory_tools.json`
- `data/schemas/autoload_dependencies.json`
- JSON Schemas en `data/schemas/json/`
- Diagramas y dependencias en `docs/architecture/`

Reglas:

- IDs únicos y estables.
- Claves de localización, nunca texto visible dentro de la lógica.
- Condiciones declarativas; nada de scripts arbitrarios dentro del JSON.
- Referencias cruzadas validadas con `tools/validate_schemas.py`.
- El JSON es la fuente de verdad; el contenido runtime se generará con un pipeline
  validado y tipos estables.
- Cambiar un contrato requiere incrementar su `schema_version` y documentar migración.
- Los autoloads se inicializan por orden topológico.
- Un ciclo de dependencias es un error bloqueante.

## 8. Autoloads y comunicación

Los autoloads oficiales son:

- `EventBus`
- `HardwareProfiler`
- `SettingsManager`
- `LocalizationManager`
- `GameState`
- `SaveManager`
- `AudioDirector`
- `WeatherManager`
- `UpdateChecker`
- `CrashReporter`

Los directores de mundo, entidades, tráfico y narrativa serán servicios de escena.
La UI emite comandos y escucha señales; no contiene lógica de juego.
`GameState` no llama a `SaveManager`; publica `save_requested`.
`SaveManager` lee un snapshot y nunca modifica directamente el mundo.
`AudioDirector` y `WeatherManager` consumen eventos, no se referencian entre sí.

## 9. Presupuestos de rendimiento obligatorios

| Presupuesto | Valor |
|---|---|
| FPS mínimo Android baja/TV | 30 estables |
| FPS objetivo Redmi/media | 60 |
| FPS objetivo PC | 60 |
| Triángulos visibles Android | ≤ 120.000 |
| Triángulos visibles PC | ≤ 450.000 |
| RAM Android | ≤ 1.2 GB PSS |
| Sector de streaming | 800 m |
| LODs por malla | LOD0 / LOD1 / LOD2 |
| Carga de sector | asíncrona |
| Warm-up de shaders | antes del gameplay |
| FSR | PC Forward+; móvil usa resolución dinámica |
| Niebla volumétrica real | solo PC Forward+ |
| Espejos | cuentan dentro del presupuesto de triángulos |

- El conteo móvil incluye cámara principal y todos los retrovisores activos.
- La RAM se mide con `adb shell dumpsys meminfo` sobre el proceso real.
- Los sectores de 800 m usan `ResourceLoader.load_threaded_request()`.
- Máximo dos solicitudes asíncronas simultáneas.
- Prohibido `load()` síncrono durante la conducción.
- Ningún modelo entra si carece de LOD0/LOD1/LOD2.
- Ninguna build se publica si el warm-up de shaders se ejecuta dentro de gameplay.
- No se aceptan “optimizaciones” sin medición.
- Las pruebas de rendimiento se hacen en la ruta de referencia, no en un menú vacío.

## 10. Biblioteca externa de referencias

Ruta:

```text
C:\Dev\fotos de ejemplo
```

Es una biblioteca **externa, privada y de solo lectura**. Contiene fotografías,
manuales, conceptos de UI, leyendas y videos de referencia. No es un banco de assets.

Reglas:

1. No copiar, mover, renombrar ni borrar originales.
2. No versionar las imágenes ni los PDFs en el repositorio.
3. El catálogo `docs/reference/reference_catalog.json` guarda solo metadatos y hashes.
4. Escaneo rápido al inicio y cierre de cada subfase:
   `python tools/scan_reference_library.py --quick`.
5. Revisión visual completa cada **14 días** o antes de una subfase de modelado/UI.
6. Revisión obligatoria antes de F2.2, F3.1, F3.2, F3.3, F3.4, F4.3, F5.1,
   F5.3, F7.3, F9.2 y F10.2.
7. Registrar cada uso en `docs/reference/REFERENCE_USAGE_LOG.md`.
8. No cargar las 40 imágenes en contexto: usar el catálogo y las hojas de contacto.
9. Las hojas de contacto van a `build/reference/` y no se commitean.
10. La carpeta está excluida de `clean_workspace.ps1`.
11. Si no existe o cambió, informar; no inventar referencias.
12. Licencias inciertas significan `reference_only_unverified`.

Prioridad de fuentes:

1. Manual de servicio y especificaciones verificadas.
2. Fotografías reales del vehículo.
3. Fuentes técnicas e históricas citadas.
4. Conceptos visuales y arte de IA: solo inspiración.

Los conceptos de Gemini no son canon. No introducir “roguelike”, monetización,
cinco noches, entidades adicionales ni botones flotantes sin aprobación explícita.
Los mockups con interfaz táctil de 25 botones quedan anulados por el sistema de
interacción contextual.

## 11. Arte 3D, audio y licencias

- Todo modelo procede de un script `bpy` reproducible.
- Todo asset generado tiene manifiesto: comando, hash, autor, licencia y fecha.
- Nada de texturas tomadas de las fotos de referencia.
- Las marcas Chevrolet, PDV y otras se omiten o se sustituyen hasta tener permiso.
- La música se sintetiza desde cero; no se usan samples de bancos no libres.
- `edge-tts` es solo una herramienta de build. El juego debe funcionar offline.
- Antes de distribución comercial de las voces se revisan sus términos de uso.
- El fallback de voz es grabación consentida o TTS local con licencia compatible.
- No se clona la voz de una persona real sin consentimiento escrito.
- Las imágenes de referencia no se usan como capturas de tienda.

## 12. Vehículo, anti-atasco y vadeo

- La simulación del Esteem se calibra con manual y mediciones del modelo, no con
  ocurrencias de una imagen.
- La altura de la toma de aire es un dato versionado y verificable.
- El vadeo modela profundidad, velocidad, oleaje, inclinación y entrada de agua.
- Cruzar rápido puede calar el motor; nunca destruye la partida irreversiblemente.
- El anti-atasco se activa por volcadura, falta de tracción, fuera de mundo, agua
  profunda o daño crítico.
- Debe existir una recuperación incluso sin dinero ni herramientas.
- La grúa/retorno consume tiempo o genera una deuda narrativa.
- Validar el punto de reaparición sobre la red vial y con colisión.
- Guardar automáticamente después del rescate.
- Las herramientas del maletero deben ser objetos reales del inventario.

## 13. Interacción, accesibilidad e idiomas

- La cabina se manipula con retículo/tacto contextual y mano IK.
- Máximo siete botones táctiles persistentes.
- Ningún control de cabina se duplica en la UI táctil.
- Gamepad y D-Pad de Android TV deben navegar todos los menús.
- Zonas táctiles mínimas de 44 dp.
- No depender solo del color o del audio.
- Indicadores visuales direccionales para sonidos críticos.
- Reducción de sustos, destellos y movimiento de cámara.
- Fuente apta para dislexia y alto contraste.
- Once locales obligatorios: `es_VE`, `es_ES`, `en`, `pt_PT`, `pt_BR`, `it`,
  `fr`, `de`, `ru`, `zh_CN`, `ja`.
- Validar claves y glifos con `tools/validate_localization.py`.
- Verificar visualmente cirílico, chino y japonés.
- No afirmar que una traducción está revisada sin revisión nativa.

## 14. Guardado, OTA y seguridad

- Todo guardado, manual o automático, incluye `save_version`, versión de juego,
  checksum y timestamp.
- Migraciones encadenadas y probadas con fixtures desde `v0.2.0`.
- Escritura atómica y backup antes de migrar.
- Nunca se pierde una partida por actualizar.
- OTA de GitHub solo para la build GitHub.
- La build de Google Play abre la tienda; no autoinstala APKs.
- Verificación SHA-256 y HTTPS para actualizaciones.
- 16 KB de alineación de páginas en librerías nativas.
- Target API Android 36 o el mínimo vigente de Google Play.
- Sin telemetría ni cuentas. El álbum y los guardados son locales.
- No subir datos personales.

## 15. Caja negra, QA y salud

- `CrashReporter` escribe `user://ultimo_reporte_error.txt`.
- Captura versión, plataforma, región, clima, estado del coche, últimas acciones,
  logs y stack cuando esté disponible.
- Un fallo nativo no puede capturarse dentro del proceso; se usa marcador de sesión
  y el reporte se emite en el siguiente arranque.
- No se sube automáticamente ningún reporte.
- `CreatorQAMenu` se abre con cinco toques en la pausa o F12.
- Sus acciones usan APIs del juego y no editan archivos directamente.
- Build de Play sin panel QA salvo bandera explícita.
- `tools/health_check.py` se ejecuta al inicio y cierre de cada subfase.
- `tools/test_android_adb.ps1` es obligatorio para hitos Android.
- El menú QA y la caja negra se prueban antes de release.

## 16. Git, versiones y limpieza

- Repositorio remoto previsto: `emanuelindustri-source/ruta-nocturna-1999`.
- `main` debe quedar desplegable.
- Commits convencionales: `feat`, `fix`, `docs`, `test`, `build`, `chore`, `perf`.
- Tags semver: `v0.1.0`, `v0.1.1`, etc.
- Sin force-push.
- Sin secretos ni keystores.
- Sin APK/AAB en Git; van a Releases.
- `.gitattributes` mantiene binarios correctos.
- No Git LFS por defecto; evaluar umbrales de 50 MB y cuotas gratuitas.
- `clean_workspace.ps1` es DryRun por defecto.
- No borrar assets fuente, documentación, `.git`, releases ni guardados.
- Las cachés globales de Gradle solo con `-IncludeGlobalCaches` y confirmación.
- La carpeta de referencias está excluida siempre.
- Comprobar espacio antes de builds.

## 17. Definition of Done de una subfase

Una subfase solo se marca completada si:

1. Los archivos y sistemas del alcance existen.
2. `health_check.py --end` pasa.
3. Los contratos JSON y JSON Schemas validan.
4. La localización base no tiene claves faltantes.
5. El proyecto importa en Godot headless sin errores.
6. Los tests aplicables pasan.
7. La build de referencia compila si la subfase lo exige.
8. El rendimiento no rompe los presupuestos.
9. Se revisaron las referencias relevantes y se registró su uso.
10. Se actualizaron ROADMAP, JSON del roadmap, CHANGELOG y estado.
11. Se hizo commit y tag (o se documentó un bloqueo de autenticación).
12. Se entregó el prompt del siguiente chat.

## 18. Respuesta ante errores

- Reportar el bloqueo real y el comando que falló.
- Adjuntar el mensaje completo o la ruta del log.
- Distinguir error del proyecto, del entorno o de credenciales.
- No inventar resultados.
- No pedir a Khristyan que depure.
- Proponer la corrección más pequeña y segura.
- Si el fallo requiere una cuenta, pedir autorización explícita.

## 19. Comandos de referencia

```powershell
# Entorno
.\.venv\Scripts\python.exe tools\health_check.py --start
.\.venv\Scripts\python.exe tools\scan_reference_library.py --quick

# Contratos y localización
.\.venv\Scripts\python.exe tools\validate_schemas.py
.\.venv\Scripts\python.exe tools\validate_localization.py

# Roadmap y web
.\.venv\Scripts\python.exe tools\release\sync_roadmap.py --check

# Godot (usar wrappers .cmd por la ExecutionPolicy restringida)
.\tools\dev\godot.cmd --headless --path . --editor --quit
.\tools\dev\godot.cmd --headless --path . --quit

# Android (cuando exista build)
.\tools\test_android_adb.ps1

# Cierre
.\.venv\Scripts\python.exe tools\health_check.py --end
git status --short
```

## 20. Prompt de continuidad

```text
[RN1999 · Subfase <N.M>]
CWD: C:\Dev\RutaNocturna1999
Lee completos AGENTS.md, ROADMAP.md, docs/status/CURRENT.md y STATE_MACHINES.md.
Modelo asignado: <DS-R | DS-S | MiMo Pro | MiMo Flash>.
Ejecuta únicamente la Subfase <N.M> con tag <vX.Y.Z>. No avances.

Al iniciar ejecuta:
  python tools/health_check.py --start
  python tools/scan_reference_library.py --quick

Revisa solo las referencias del catálogo relevantes para esta subfase y registra su uso.
No copies archivos de C:\Dev\fotos de ejemplo al repositorio.
Respeta presupuestos, contratos, licencias y el anti-softlock.

Al cerrar valida tests, import, export, ADB, localización, migraciones y health --end.
Si algo falla, no marques completada ni crees tag. Actualiza estado y entrega el
prompt del siguiente /new.
```
