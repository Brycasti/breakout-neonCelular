# 🕹️ BREAKOUT NEON

Juego tipo *Breakout* en **Godot 4** conectado a una **base de datos SQLite**, con
**clasificación (leaderboard)** y una **interfaz web local** para consultar todo lo
que hace el jugador.

> **Práctica 4 — Conexión a una base de datos** · **Práctica 6 — Controles táctiles (móvil)**
> Alumno: *José Luis David Bonilla Carranza*

---

## 🎯 Qué hace el proyecto

| Requisito de la práctica | Cómo se cumple |
|---|---|
| **Conectar el juego con una base de datos** | El juego (Godot) envía cada partida y cada evento del jugador por **HTTP + JSON** a un servidor local en Python, que los guarda en una base de datos **SQLite** (`servidor/ranking.db`). |
| **Guardar todo lo que hace el jugador** | Tabla `partidas` con el resultado completo (puntos, nivel, racha, ladrillos, coleccionables, vidas, modo, **duración/tiempo**, skins) y tabla `eventos` con el detalle momento a momento (nivel iniciado/superado, power-up recogido, ladrillo especial, bola perdida, pausa…). |
| **Crear un leaderboard** | Pantalla **RÉCORDS** dentro del juego (lee del servidor) y pestaña **Clasificación** en la web. |
| **Interfaz para consultar la información en un sistema web local** | Panel web servido en `http://127.0.0.1:8000` con 5 pestañas: Clasificación, Jugadores, Partidas, Actividad y Estadísticas. |

### Requisitos de la Práctica 6 (controles táctiles)

| Requisito de la práctica | Cómo se cumple |
|---|---|
| **Joystick virtual (o botones direccionales) con zona muerta ajustable** | `scripts/virtual_joystick.gd`: joystick analógico abajo a la izquierda. La zona muerta se configura desde **AJUSTES** (0.05–0.45; por defecto **0.20**). |
| **Botones de acción grandes, de tamaño de pulgar** | Botón **LANZAR** de **220 px** y botones **PAUSA/REINICIAR** de **106 px** (el mínimo pedido es 96 px). Se escalan con el ajuste *Tamaño* (0.7–1.5×). |
| **Multitáctil** | El joystick guarda el índice del dedo que lo toca (`InputEventScreenTouch.index`) y los botones atienden cualquier dedo, así que se puede mover **y** pulsar LANZAR/PAUSA a la vez. (Los nodos `Button` de Godot solo reaccionan a un toque, por eso la capa táctil lee los toques directamente en `_input`.) |
| **Capa de entrada unificada** | El juego **solo lee acciones del Input Map** (`move_left`, `move_right`, `launch`, `pause`, `restart`). El joystick y los botones usan `Input.action_press/release`, así que teclado, gamepad y táctil conviven sin código duplicado. |
| **Controles solo si hay pantalla táctil (+ modo depuración en PC)** | Se muestran si `DisplayServer.is_touchscreen_available()` o si en **AJUSTES** se elige *Mostrar controles: Siempre*. Con *Automático* en un PC no aparece nada. |
| **Adaptación de pantalla: horizontal, escalado, anclas y *safe area*** | Orientación **horizontal**, estirado `canvas_items` + `expand`. Los controles se anclan a las esquinas con 30 px de margen y se desplazan con `DisplayServer.get_display_safe_area()` para no quedar bajo el *notch*. |
| **Game feel: *input buffering* y *coyote time* con botones táctiles** | Ya existían y siguen funcionando porque leen **acciones**, no teclas. Además se corrigió el buffer de lanzamiento para que sobreviva al cambio de nivel. |
| **Vibración háptica (opcional) en eventos clave** | `Input.vibrate_handheld()` al recibir daño (70 ms), recoger power-up (40 ms) y terminar la partida (140 ms), con interruptor en AJUSTES. |
| **Ajustes guardados en el archivo de progreso/configuración** | Todo se guarda en `user://breakout_neon.cfg` (sección `[controles]`), junto al progreso del jugador. |
| **Colocación ergonómica (pulgares en las esquinas)** | Joystick abajo-izquierda y LANZAR abajo-derecha, para los dos pulgares; los botones de sistema (PAUSA/REINICIAR) van arriba-derecha, donde no estorban. |
| **Documentar los parámetros en el README** | Tabla de parámetros con los valores usados y los rangos recomendados, en la sección *Controles táctiles*. |

---

## 🚀 Cómo se arranca

### 1. El servidor (necesario para guardar datos)

```bash
cd servidor
python servidor.py
```

No hay que instalar **nada**: usa solo la librería estándar de Python 3.8+.
Al arrancar crea la base de datos `servidor/ranking.db` si no existe.

### 2. El juego

Abre el proyecto con **Godot 4** y pulsa **F5** (la escena principal es
`scenes/menu.tscn`). Jugar una partida y, al terminar, escribir el nombre:
la partida se guarda en la base de datos.

> Si el servidor está apagado el juego funciona igual: los resultados se
> guardan en `user://envios_pendientes.json` y se envían solos la próxima vez.

En **móvil** el juego muestra solo los controles táctiles (joystick + botones); en
**PC** no aparece ningún control en pantalla y se juega con teclado/gamepad como
siempre. Para probarlos en el PC: **AJUSTES → Mostrar controles: Siempre**.

### 3. La interfaz web

Con el servidor corriendo, abre en el navegador:

```
http://127.0.0.1:8000
```

También puedes verlo desde el móvil (misma red WiFi) usando la IP de tu PC,
por ejemplo `http://192.168.1.50:8000`.

---

## 🧱 Arquitectura

```
┌──────────────────┐   HTTP + JSON   ┌────────────────────┐   SQL   ┌──────────────┐
│  GODOT (el juego)│ ──────────────► │  servidor.py       │ ──────► │  SQLite      │
│  autoload        │                 │  API REST +        │         │  ranking.db  │
│  "Leaderboard"   │ ◄────────────── │  sirve la web      │ ◄────── └──────────────┘
└──────────────────┘   clasificación └─────────┬──────────┘
                                               │ HTML/CSS/JS
                                               ▼
                                     ┌────────────────────┐
                                     │ navegador          │
                                     │ localhost:8000     │
                                     └────────────────────┘
```

El juego **nunca** toca la base de datos directamente: habla con el servidor.
Así la web y el juego leen y escriben lo mismo sin pelearse por el archivo.

---

## 🗂️ Estructura del proyecto

```
├── project.godot
├── scenes/
│   ├── menu.tscn          # portada: JUGAR, MODO INFINITO, NIVELES, ARMARIO, RÉCORDS
│   ├── main.tscn          # la partida (incluye el panel de nombre al terminar)
│   └── ...
├── scripts/
│   ├── leaderboard.gd     # ★ autoload: cliente HTTP de la base de datos
│   ├── main.gd            # ★ registra eventos y envía la partida
│   ├── menu.gd            # ★ pantalla RÉCORDS (lee del servidor)
│   ├── game_data.gd       # progreso local + nombre del jugador
│   └── ...
└── servidor/
    ├── servidor.py        # ★ API REST + base de datos + sirve la web
    ├── ranking.db         # base de datos SQLite (se crea sola)
    └── web/
        ├── index.html     # ★ interfaz web
        └── static/
            ├── style.css
            └── app.js
```

---

## 🗄️ Base de datos

Dos tablas en `ranking.db`:

**`partidas`** — una fila por partida terminada

| Columna | Significado |
|---|---|
| `jugador` | Nombre que escribe el jugador al terminar |
| `puntos` | Puntuación final |
| `nivel` | Nivel máximo alcanzado |
| `racha` | Mejor racha (ladrillos seguidos) |
| `ladrillos` | Ladrillos rotos |
| `powerups` | **Coleccionables** recogidos |
| `vidas` | Vidas restantes |
| `modo` | `normal` o `infinito` |
| `duracion_s` | **Tiempo** jugado (segundos) |
| `skin_bola`, `skin_pala` | Skins equipadas |
| `sesion` | Identificador de la partida (sirve para atribuir los eventos) |
| `fecha` | Fecha y hora local |

**`eventos`** — el registro de lo que hace el jugador

| Columna | Significado |
|---|---|
| `tipo` | `nivel_iniciado`, `nivel_superado`, `powerup`, `brick_especial`, `bola_perdida`, `multibola`, `escudo`, `pausa`, `juego_terminado`, `juego_completado`, `skin_equipada` |
| `detalle` | Texto libre (por ejemplo el power-up concreto) |
| `valor` | Número asociado (puntos, segundos, vidas…) |
| `nivel` | Nivel en el que ocurrió |

---

## 🔌 API REST

| Método | Ruta | Qué hace |
|---|---|---|
| `POST` | `/api/partidas` | Guarda una partida. Devuelve el **puesto** en la clasificación |
| `POST` | `/api/eventos` | Guarda uno o varios eventos (acepta lista) |
| `GET` | `/api/ranking?limite=10&modo=` | Mejor puntuación de cada jugador |
| `GET` | `/api/jugadores` | Todos los jugadores con sus totales |
| `GET` | `/api/jugadores/<nombre>` | Ficha completa de un jugador |
| `GET` | `/api/partidas?limite=50&jugador=&modo=` | Partidas guardadas |
| `GET` | `/api/eventos?limite=100&jugador=&tipo=` | Actividad registrada |
| `GET` | `/api/estadisticas` | Totales, eventos por tipo, partidas por día |
| `GET` | `/api/export.csv` | Exporta todas las partidas a CSV |
| `POST` | `/api/limpiar` | Vacía la base de datos (para pruebas) |

Prueba rápida sin abrir el juego:

```bash
curl "http://127.0.0.1:8000/api/estadisticas"
curl -X POST http://127.0.0.1:8000/api/partidas -H "Content-Type: application/json" ^
     -d "{\"jugador\":\"Prueba\",\"puntos\":9000,\"nivel\":10,\"racha\":25,\"ladrillos\":90,\"powerups\":6,\"duracion_s\":180,\"modo\":\"normal\"}"
```

---

## 🖥️ La interfaz web

Cinco pestañas que se actualizan solas cada 5 segundos:

1. **🏆 Clasificación** — podio + tabla con el mejor resultado de cada jugador.
2. **👤 Jugadores** — todo lo acumulado por persona (puntos, ladrillos, coleccionables, tiempo…). Se puede buscar y pinchar para ver su ficha.
3. **🕹️ Partidas** — cada partida con duración, vidas, skins y fecha. Filtros + **exportar CSV**.
4. **📋 Actividad** — el registro de eventos, filtrable por jugador y tipo.
5. **📊 Estadísticas** — tarjetas de totales, gráficos de barras (partidas por día, eventos por tipo) y rendimiento por nivel.

---

## 📱 Controles táctiles (Práctica 6)

El juego funciona igual en **PC** (teclado/gamepad) y en **móvil** (táctil): no hay
dos modos de juego, hay **una sola capa de entrada**.

### La capa de entrada unificada

```
joystick virtual ──┐
botones táctiles ──┤──→ Input.action_press / release ──┐
teclado / gamepad ─┴──────────────────────────────────┴──→ Input Map ──→ pala / lanzar / pausa
```

- El **joystick** convierte el desplazamiento del dedo en `move_left` / `move_right`
  con **fuerza analógica (0.0–1.0)**: cuanto más lejos del centro, más rápido se
  mueve la pala. Lo que queda dentro de la zona muerta se ignora.
- Los **botones táctiles** hacen un pulso corto (`action_press` y `action_release`
  60 ms después) con anti-rebote de 180 ms, para que un toque no se cuente dos veces.
- Como `Input.action_press` **no genera un `InputEvent`**, el lanzar/pausar/reiniciar
  se leen por *polling* (`Input.is_action_just_pressed`) y no en `_unhandled_input`.
  El mismo código responde así al teclado, al gamepad y al táctil.
- El **rescate al límite** (coyote time) usa la posición de la pala, así que funciona
  igual con joystick que con teclado.

### Archivos de esta práctica

| Archivo | Qué hace |
|---|---|
| `scripts/virtual_joystick.gd` | Joystick analógico multitáctil (clase `JoystickVirtual`). |
| `scripts/touch_controls.gd` | Construye la capa táctil (joystick + 3 botones), aplica los ajustes, libera los dedos al ocultarse y calcula la *safe area*. Nodo `TouchControls` de `scenes/main.tscn`. |
| `scripts/main.gd` | Lee las acciones cada fotograma (`_leer_acciones`), buffer de lanzamiento y vibración. |
| `scenes/menu.tscn` + `scripts/menu.gd` | Página **AJUSTES** del menú. |
| `scripts/game_data.gd` | Guarda y lee los ajustes en `user://breakout_neon.cfg`. |

### Parámetros y valores recomendados

| Parámetro | Valor usado en el juego | Rango recomendado |
|---|---|---|
| Radio del joystick | **90 px** (× el ajuste de tamaño) | 80–120 px |
| Zona muerta | **0.20** | 0.15–0.25 |
| Botón de acción (LANZAR) | **220 px** de diámetro | ≥ 96 px |
| Botones de sistema (PAUSA / REINICIAR) | **106 px** de diámetro | ≥ 96 px |
| Opacidad de los controles | **0.55** | 0.4–0.7 |
| **Vibración (daño / recoger / fin) | **70 / 40 / 140 ms** | 30–80 ms |
| **Input buffering & coyote time** | **Ya existían y siguen funcionando porque leen acciones del Input Map, así que funcionan igual con **táctil** que con teclado/gamepad. No se perdieron al cambiar de nivel.** | — |
| **Orientación** | **Landscape** (`display/window/handheld/orientation = 0`) | Landscape |
| Estirado de pantalla | **canvas_items + expand** | canvas_items + expand |
| Anclas y margen | esquinas, **30 px** de margen | esquinas inferiores |
| *Safe area* (notch) | `DisplayServer.get_display_safe_area()` (como máximo 25 % del borde) | — |
| Anti-rebote de los botones | **180 ms** (pulso de 60 ms) | 100–250 ms |
Buffer de lanzamiento | **0.2 s** (window de coyote) | 0.1–0.3 s |
| **Screenshake intensidad** | **Varía por evento**: 2.0-12.0 px, 0.1-0.4s duración | 1.0–5.0 px, 0.1–1.0s |
| **Feedback visual** | Popups, bursts, pulsatrices de cámara | — |
| **Feedback sonoro** | Sfx para cada acción: launch, brick_break, powerup, lose, level_clear, etc. | — |
| **Feedback de interfaz** | HUD actualizado, labels, message_label, popup labels | — |

### 📝 Notas sobre los fixes recientes

- **Bolita invisible al perder vida**: Arreglado en `scripts/ball.gd` añadiendo `visible = true` después de emitir `ball_lost`. La bola reaparece visible tras perder una vida y activar el escudo; la física continúa normalemente (los bloques se rompen igual).

- **Ícono personalizado para APK**: Configurado en `export_presets.cfg` con `application/icon="res://assets/icons/app_icon.png"`. Al exportar e instalar el APK, aparecerá el logo neon magenta/cian en lugar del ícono por defecto de Godot.

- **Vibración háptica con táctiles**: `Input.vibrate_handheld()` funciona en dispositivos Android en eventos de daño (70 ms), recolección (40 ms) y fin de partida (140 ms). En PC el comando se ignora silenciosamente.

### Ajustes (página AJUSTES del menú)

Se guardan solos, en la sección `[controles]` de `user://breakout_neon.cfg`:

| Ajuste | Opciones |
|---|---|
| Mostrar controles | Automático (solo si hay táctil) / Siempre / Nunca |
| Opacidad | 0.2 – 1.0 |
| Tamaño | 0.7 – 1.5× |
| Zona muerta | 0.05 – 0.45 |
| Vibración | Sí / No |
| Servidor | URL de la base de datos (en el móvil, la IP del PC) |

### Probar los controles en PC

Dos formas:

1. **AJUSTES → Mostrar controles: Siempre** (es lo que se usó para las capturas y
   para las pruebas). Se pueden pulsar con el ratón.
2. *Proyecto → Configuración del proyecto → Dispositivos de entrada → Punteros →
   **"Emulate Touch From Mouse"***. Viene **desactivado** a propósito: si se activa,
   el ratón genera eventos táctiles *y* de ratón a la vez y el joystick puede
   recibir el dedo duplicado. Como la emulación no siempre está disponible en todas
   las versiones de Godot, la opción 1 es la recomendada.

### Exportar a Android (APK)

1. *Editor → Gestionar plantillas de exportación…* (descargar las plantillas) y
   tener el **Android SDK + JDK** configurados en *Editor → Configuración*.
2. *Proyecto → Exportar…*: **ya hay un preset `Android` preparado** en
   `export_presets.cfg` (APK arm64-v8a, pantalla completa, permisos puestos).
   Solo hay que configurar el SDK y pulsar *Exportar proyecto*. Si el preset no
   apareciera, se añade con *Add… → Android*.
3. Los permisos que necesita el juego ya están activados en ese preset:
   - `INTERNET` → necesario para enviar los datos con `HTTPRequest`.
   - `VIBRATE` → necesario para `Input.vibrate_handheld()`.
4. **HTTP sin cifrar:** el servidor es `http://` local, así que si Android lo
   bloquea hay que permitir el tráfico *cleartext* (pestaña *Gráficos*) o usar HTTPS.
5. *Pantalla*: **Edge to Edge / Immersive Mode** para que la *safe area* funcione.
6. En el juego: **AJUSTES → Servidor** → `http://IP-DE-TU-PC:8000`
   (en el móvil `127.0.0.1` es el propio teléfono, no el PC).
7. Exportar el **APK** y, si se quiere, subirlo a **Releases** del repositorio.

### Limitaciones en móvil (documentadas)

- **El panel web local no está pensado para el móvil:** funciona, pero las tablas
  se desplazan en horizontal y se ve mucho mejor en el PC. Se le añadieron reglas
  `@media` para que al menos sea usable en pantallas pequeñas.
- **La vibración solo existe en móvil:** en PC `Input.vibrate_handheld()` no hace
  nada (el ajuste se ignora sin dar error).
- **El servidor debe estar en la misma red WiFi** que el móvil y con la IP del PC;
  el móvil no ve `127.0.0.1`.
- **Android puede exigir permitir HTTP sin cifrar** para hablar con el servidor local.
- **El joystick no tiene equivalente "a media marcha" con el teclado:** en PC se
  juega con izquierda/derecha a velocidad completa, como antes; la fuerza analógica
  es un extra del táctil.
- **La base de datos y el leaderboard no cambian:** el juego envía los mismos
  eventos y partidas desde el móvil que desde el PC (lo único que cambia es la
  dirección del servidor).

---

## 🔒 Notas de diseño

- **Validación en el servidor:** el juego no es de fiar (cualquiera puede modificarlo), así que el servidor recorta y valida todo: nombre de 16 caracteres máximo, puntos dentro de rango, tipos de evento permitidos, modo `normal`/`infinito`…
- **Sin inyección de HTML:** la web pinta los nombres con `textContent`, nunca `innerHTML`.
- **Sin pantallas bloqueadas:** si el servidor no responde, las peticiones tienen *timeout* de 5 segundos, el juego sigue y los envíos se reintentan después.
- **Sin librerías externas:** ni en Python (solo la librería estándar) ni en la web (nada de CDN).

> ⚠️ Al ser un sistema **local**, la clasificación no es a prueba de trampas: quien
> quiera podría enviar una puntuación falsa con `curl`. Para una práctica local es
> aceptable; blindarlo requeriría validar la partida en el servidor o firmar los
> resultados.

---

## 📦 Subir a GitHub (entrega)

```bash
git init
git add .
git commit -m "Práctica 4: Breakout Neon con base de datos, leaderboard y panel web"
git branch -M main
git remote add origin https://github.com/TU-USUARIO/breakout-neon-practica4.git
git push -u origin main

# Práctica 6: la rama y la etiqueta que pide el enunciado
git checkout -b practica-6
git add .
git commit -m "Práctica 6: controles táctiles, ajustes de mando y documentación móvil"
git push -u origin practica-6
git tag practica-6
git push origin practica-6
```

Antes de entregar, juega **un par de partidas** con el servidor encendido para que
`servidor/ranking.db` tenga datos y el profesor los vea al instante en la web.

El archivo `.gitignore` ya excluye la carpeta `.godot/` (caché del editor) y los
`.exe` exportados, que no hacen falta en el repositorio.