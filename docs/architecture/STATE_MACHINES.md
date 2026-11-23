# Máquinas de estados

**Estado:** blueprint de Fase 1.1. Las transiciones se implementan en fases posteriores.  
Los umbrales numéricos pertenecen a los contratos JSON y deben probarse; no se
codifican en la UI.

## 1. Vehículo

### Motor

```mermaid
stateDiagram-v2
    [*] --> Off
    Off --> Cranking: llave / encendido
    Cranking --> Idle: arranque exitoso
    Cranking --> Flooded: intentos y combustible
    Idle --> Running: acelerador / marcha
    Running --> Idle: detenido
    Running --> Stalled: agua / combustible / fallo
    Idle --> Stalled: calado
    Stalled --> Cranking: reintento seguro
    Flooded --> Drying: bujías mojadas
    Drying --> Cranking: secado completado
    Running --> OverheatedSafe: temperatura crítica
    OverheatedSafe --> Running: enfriamiento
    OverheatedSafe --> Seized: daño irreparable
```

Regla anti-atasco: un motor `Seized` nunca deja una partida irrecuperable. El
sistema de rescate puede remolcar o recuperar el último punto seguro.

### Transmisión

```mermaid
stateDiagram-v2
    [*] --> Park
    Park --> Reverse: palanca
    Park --> Neutral: palanca
    Park --> Drive: palanca
    Neutral --> Park: palanca
    Neutral --> Reverse: palanca
    Neutral --> Drive: palanca
    Reverse --> Park: palanca
    Reverse --> Neutral: palanca
    Drive --> Second: palanca
    Drive --> Low: palanca
    Second --> Drive: palanca
    Low --> Drive: palanca
    Drive --> OverdriveOff: botón O/D
    OverdriveOff --> Drive: botón O/D
```

`P-R-N-D-2-L` no se cambia por UI flotante; se manipula la palanca física con la
mano IK y el modo contextual. Cambios inválidos se rechazan con feedback físico.

### Electroventilador

```mermaid
stateDiagram-v2
    [*] --> Off
    Off --> Low: temperatura alta
    Low --> High: temperatura crítica
    High --> Low: temperatura estable
    Low --> FaultOpen: relé / fusible / motor
    High --> FaultOpen: sobrecorriente
    FaultOpen --> Off: reparación
```

Los síntomas distinguen fusible, relé y motor. No se puede diagnosticar solo con
“temperatura alta”: el jugador debe observar el comportamiento y revisar el panel.

## 2. Clima

```mermaid
stateDiagram-v2
    [*] --> Clear
    Clear --> Overcast: humedad
    Overcast --> Drizzle: lluvia ligera
    Drizzle --> Rain: intensificación
    Rain --> Storm: tormenta
    Storm --> Rain: descenso
    Rain --> Fog: enfriamiento
    Fog --> Overcast: viento
    Clear --> Sandstorm: región árida
    Sandstorm --> Clear: viento
    Overcast --> Snow: páramo
    Snow --> Overcast: deshielo
    Rain --> SwampMist: Delta / Amazonas
    SwampMist --> Rain: nueva lluvia
```

Las transiciones tienen duración, intensidad y probabilidad. El trueno se
retrasa según la distancia del rayo; la humedad alimenta gotas, limpiaparabrisas
y charcos.

## 3. Entidad del folclore

```mermaid
stateDiagram-v2
    [*] --> Dormant
    Dormant --> Observe: condición de aparición
    Observe --> Stalk: interés
    Observe --> Withdraw: luz / distancia
    Stalk --> Manifest: tensión alta
    Manifest --> Chase: ruptura de distancia
    Chase --> Attack: contacto
    Chase --> Withdraw: evasión exitosa
    Attack --> Chase: el jugador escapa
    Manifest --> Banished: sal / reliquia
    Chase --> Banished: ritual
    Withdraw --> Dormant: cooldown
    Banished --> [*]
```

`data/schemas/folklore_entities.json` decide las condiciones, los radios y los
objetos válidos. La IA no inventa excepciones fuera del contrato.

## 4. Silbón: distancia invertida

La dirección se conserva. La **distancia percibida** se invierte:

```text
real_near_m = 15
real_far_m  = 80
```

```mermaid
flowchart LR
    R[Distancia real al Silbón] --> M[Función invertida]
    M --> P[Distancia percibida del silbido]
    P --> A[Audio espacial]
    R --> V[Comportamiento real: acecho]
    V --> D[Peligro]
    A --> D
```

Casos de prueba obligatorios:

1. Entidad a 12 m → el silbido se percibe lejano; peligro real alto.
2. Entidad a 85 m → el silbido se percibe cercano; peligro real bajo.
3. La dirección del altavoz corresponde a la posición real.
4. Apagar motor, luces y radio reduce el riesgo.
5. El indicador visual direccional sigue funcionando para jugadores sordos.

## 5. Rescate y anti-atasco

```mermaid
stateDiagram-v2
    [*] --> Driving
    Driving --> StuckCheck: sin tracción / volcado / agua / fuera de mundo
    StuckCheck --> Driving: recupera control
    StuckCheck --> SelfRecovery: herramientas disponibles
    StuckCheck --> TowOffer: sin tracción prolongada
    SelfRecovery --> Driving: coche reubicado
    SelfRecovery --> TowOffer: intento fallido
    TowOffer --> Towing: aceptar / deuda
    TowOffer --> SafeReturn: sin dinero y espera
    Towing --> Driving: grúa devuelve al camino
    SafeReturn --> Driving: último punto seguro
```

La oferta de rescate aparece después de un tiempo prudencial, no castiga al
jugador por explorar y no puede activarse desde la UI para saltarse la física sin
pasar por la validación de recuperación.

## 6. Vadeo

```mermaid
stateDiagram-v2
    [*] --> Dry
    Dry --> EnteringWater: profundidad mojada
    EnteringWater --> SafeCrossing: profundidad bajo admisión y velocidad baja
    EnteringWater --> BowWave: velocidad alta
    BowWave --> WaterIngress: ola sobre la admisión
    EnteringWater --> WaterIngress: profundidad sobre admisión
    SafeCrossing --> Dry: salida
    WaterIngress --> StalledWet: motor calado
    StalledWet --> Drying: abrir capó y secar
    Drying --> Dry: bujías / filtro secos
    StalledWet --> TowOffer: daño grave
```

- La altura de la admisión es `specs.water.air_intake_height_m`.
- La velocidad y la profundidad se calculan con la física real del vehículo.
- El secado requiere filtro/bujías, rags and flashlight.
- La recuperación por grúa sigue disponible.

## 7. Guardado y migración

Un guardado no es una máquina de estados de gameplay, pero sí tiene estados:

```text
Snapshot → Validate → Migrate → Backup → Temp Write → Verify → Rename → Notify
```

Cualquier fallo deja el archivo anterior intacto y un reporte legible.

## 8. Implementación de la Fase 2.1

Los diagramas de motor, transmisión y electroventilador ya tienen una
implementación ejecutable en `src/vehicle/`. Los umbrales concretos están en
`data/schemas/vehicle_powertrain.json`; no se duplican en la UI.

### Motor

Estados implementados:

| Estado | Condición de entrada | Salida |
|---|---|---|
| `off` | Igníción apagada o motor detenido | Arranque en P/N |
| `cranking` | Comando de arranque con combustible | `idle` tras 0,9 s o `flooded`/`stalled` |
| `idle` | Motor en marcha sin carga | `running` con acelerador o carga |
| `running` | Acelerador o velocidad de entrada | `idle` al soltar |
| `stalled` | Sin combustible o giro insuficiente | Reintento seguro |
| `flooded` | Bujías mojadas | `drying` con `dry_engine()` |
| `drying` | Secado en curso | `off` tras 20 s |
| `overheated_safe` | Refrigerante ≥ 115 °C | `running`/`idle` al bajar de 108 °C |
| `seized` | Refrigerante ≥ 125 °C durante 8 s | Reparación explícita |

El arranque solo se permite en `P` o `N`. La marcha se libera automáticamente al
encender. El corte de inyección y la retención se calculan con la curva de par y
el régimen; no son valores fijos en la UI.

### Transmisión

- `P`: bloqueo de salida (park pawl); el vehículo no se mueve.
- `R`: relación de reversa; se rechaza con avance superior a 1 km/h.
- `N`: sin par; permite arranque y remolque.
- `D`: 1–4 según calendario y Overdrive.
- `2`: máximo segunda; si se selecciona a alta velocidad, espera a que la
  velocidad sea segura para bajar.
- `L`: máximo primera, con la misma protección.
- Overdrive: apagarlo desde cuarta fuerza tercera; encenderlo permite cuarta.
- El convertidor multiplica par hasta 2,0 en parado y bloquea en crucero por
  encima de 65 km/h con acelerador bajo.
- `P` y `R` se rechazan en movimiento; `D` se rechaza en reversa. El rechazo se
  expone como `last_rejection` para que la mano IK dé feedback en F2.3.

### Electroventilador

- Velocidad baja a 98 °C, alta a 104 °C; apagado con histéresis a 94/100 °C.
- Fusible, relé y motor son fallos independientes. El relé puede ser
  intermitente; el fusible y el motor dejan el ventilador sin servicio.
- El fallo se repara con `repair_component()` usando los IDs de
  `vehicle_components.json`.
- La temperatura alta sostenida activa aviso (110 °C), modo seguro (115 °C) y
  agarrotamiento (125 °C durante 8 s).
- La recuperación anti-atasco completa no está en esta subfase: el motor
  agarrotado se puede reparar por API/QA, pero la grúa y el punto seguro llegan
  en F5.1.

## 9. Interacción contextual de cabina (Fase 2.3)

El contrato `data/schemas/cabin_interaction.json` define el foco, los gestos, las
poses IK y los estados de los mandos. La UI solo muestra el retículo y el prompt;
la lógica vive en `src/vehicle/cabin_interaction_controller.gd`,
`cabin_controls.gd` y `hand_ik_driver.gd`.

### Foco y gesto

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> FocusAvailable: retículo/tacto sobre control
    Idle --> FocusBlocked: control requiere puerta/estacionario/radio/D
    FocusAvailable --> Acting: pulsar
    FocusBlocked --> Acting: pulsar (feedback)
    Acting --> FocusAvailable: soltar / volver al foco
    FocusAvailable --> Idle: mirar fuera o tocar vacío
    FocusBlocked --> Idle: mirar fuera o tocar vacío
```

- El foco por retículo usa un ángulo máximo de 7° y una distancia máxima de
  1,2 m. El tacto usa un radio mínimo de 44 dp y proyecta los controles a
  pantalla.
- Si el control no está disponible, se puede pulsar para recibir feedback
  físico/textual, pero la acción se rechaza.

### Manos IK

```mermaid
stateDiagram-v2
    [*] --> TwoHands: volante
    TwoHands --> OneHand: palanca, freno de mano, radio, luces, ventanas
    OneHand --> ZeroHands: puertas, guantera
    ZeroHands --> OneHand: control de conducción
    OneHand --> TwoHands: volante
    ZeroHands --> TwoHands: volante
```

- Cada pose declara los destinos de mano izquierda/derecha. El conductor IK
  resuelve hombro-codo-muñeca-palma-agarre con dos huesos por brazo y un
  desplazamiento de inclinación máximo de 0,22 m.
- Las mallas de manos son proxies de código hasta F3.2; el esqueleto es el rig
  `EsteemHandRig` de F2.2.
- El volante no modifica la dirección ni el chasis: solo cambia la pose.

### Puertas y seguros

```mermaid
stateDiagram-v2
    [*] --> ClosedUnlocked
    ClosedUnlocked --> Open: tirador (estacionario)
    Open --> ClosedUnlocked: tirador
    ClosedUnlocked --> ClosedLocked: seguro central
    ClosedLocked --> ClosedUnlocked: seguro central
    ClosedLocked --> ClosedLocked: tirador (feedback locked)
    Open --> OpenLocked: seguro central (estado visual)
```

- El seguro central bloquea los tiradores; una puerta abierta no impide volver a
  bloquear/desbloquear. Abrir una puerta exige vehículo detenido.
- La apertura es reversible y no deja la partida bloqueada.

### Vidrios

```mermaid
stateDiagram-v2
    [*] --> Closed
    Closed --> Opening: mantener bajar
    Opening --> Open: tope inferior
    Open --> Closing: mantener subir
    Closing --> Closed: tope superior
    Opening --> Closed: soltar y subir
    Closing --> Open: soltar y bajar
```

- La posición es 0 (cerrado) a 1 (abierto), con recorrido de 2,4 s.
- Los topes emiten `window_limit`; el vidrio se puede mover en ambos sentidos.

### Luces, antena y radio

```mermaid
stateDiagram-v2
    [*] --> Off
    Off --> Parking: ciclo de luces
    Parking --> Headlights: ciclo de luces
    Headlights --> Off: ciclo de luces
```

- La antena se extiende/recoge en 0,8 s. Extendida mejora la señal de la radio;
  recogida aumenta el estático.
- La radio tiene encendido, bandas AM/FM, búsqueda con envolvente y volumen de 0
  a 8 pasos. El audio es un tono/ruido procedural con `AudioStreamGenerator`; no
  usa samples de terceros. La música definitiva es F8.
- Con la radio apagada, los controles de banda/búsqueda/volumen responden con
  `radio_off` y no cambian el estado.

### Palanca y freno de mano

```mermaid
stateDiagram-v2
    [*] --> P
    P --> R: arrastre / nudge
    R --> N: arrastre / nudge
    N --> D: arrastre / nudge
    D --> Two: arrastre / nudge
    Two --> L: arrastre / nudge
    L --> Two: arrastre / nudge
    P --> D: salto aceptado
    D --> P: aceptado si detenido
    R --> D: rechazado en avance
```

- La palanca no cambia la velocidad ni la física: llama a
  `VehiclePowertrain.set_selector()`. Un rechazo (`moving`, `forward_motion`,
  `reverse_motion`) devuelve el pomo y emite feedback.
- El Overdrive llama a `VehiclePowertrain.toggle_overdrive()`; solo se acepta en
  `D`.
- El freno de mano llama a `VehiclePowertrain.set_parking_brake()` y el
  orquestador propaga el estado a `brakes.parking`.

### Anti-atasco de la interacción

Ningún control deja la partida irrecuperable: la palanca puede volver a `P` con
el vehículo detenido, el freno de mano se libera, las puertas se desbloquean y
los vidrios se mueven en ambos sentidos. No hay espejos, HUD, gamepad ni guardado
en esta subfase.
