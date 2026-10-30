extends CanvasLayer
## Capa de controles táctiles (Práctica 6).
##
## Se muestra SOLO si hay pantalla táctil (o si el modo es "siempre", para
## depurarla en PC). Construye todo por código para no ensuciar la escena:
##   - Joystick virtual abajo a la izquierda  → acciones move_left / move_right
##   - LANZAR (botón grande) abajo a la derecha → acción launch
##   - PAUSA / REINICIAR arriba a la derecha    → acciones pause / restart
##
## Los botones no llaman a ninguna función del juego: pulsan ACCIONES del Input
## Map, igual que el teclado. Así hay una única capa de entrada.

const RADIO_JOYSTICK: float = 90.0      # parámetro de la práctica: 80–120 px
const DIAMETRO_LANZAR: float = 220.0    # mínimo de la práctica: ≥ 96 px
const DIAMETRO_PEQUENO: float = 106.0   # pausa y reiniciar
const MARGEN: float = 30.0
const PULSO_MS: int = 60                # lo que dura "pulsada" una acción
const ANTI_REBOTE_MS: int = 180         # ignora dobles toques seguidos

var joystick: JoystickVirtual = null

var _raiz: Control = null
var _botones: Dictionary = {}            # acción -> Button
var _ultimo_pulso: Dictionary = {}       # acción -> milisegundos
var _ultimo_tamano: Vector2 = Vector2.ZERO
var _recalcular_frames: int = 5


func _ready() -> void:
	layer = 20
	_construir()
	get_viewport().size_changed.connect(actualizar_ajustes)
	actualizar_ajustes()


## Al arrancar (y al girar el móvil) el tamaño del viewport puede cambiar
## después del _ready, así que se recoloca todo cuando eso pasa. Durante los
## primeros fotogramas se recalcula siempre, para no quedarse con un tamaño
## antiguo (por ejemplo con la ventana del editor todavía ajustándose).
func _process(_delta: float) -> void:
	var vista: Vector2 = get_viewport().get_visible_rect().size
	if vista != _ultimo_tamano or _recalcular_frames > 0:
		_recalcular_frames -= 1
		_ultimo_tamano = vista
		actualizar_ajustes()


func _notification(que: int) -> void:
	# Al salir de la escena hay que soltarlo todo, si no la pala seguiría
	# moviéndose sola. (Para ocultarla, el juego llama a soltar_todo().)
	if que == NOTIFICATION_EXIT_TREE:
		soltar_todo()


func _construir() -> void:
	_raiz = Control.new()
	_raiz.name = "Raiz"
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE   # el hueco no come toques
	add_child(_raiz)

	joystick = JoystickVirtual.new()
	joystick.name = "Joystick"
	_raiz.add_child(joystick)

	_botones["launch"] = _crear_boton("launch", "LANZAR", DIAMETRO_LANZAR,
		Color(0.35, 0.9, 1.0), 46)
	_botones["pause"] = _crear_boton("pause", "PAUSA", DIAMETRO_PEQUENO,
		Color(1.0, 0.84, 0.3), 24)
	_botones["restart"] = _crear_boton("restart", "REINICIAR", DIAMETRO_PEQUENO,
		Color(1.0, 0.5, 0.8), 17)


func _crear_boton(accion: String, texto: String, diametro: float, color: Color,
		fuente: int) -> Button:
	var boton: Button = Button.new()
	boton.name = "Boton" + accion.capitalize()
	boton.text = texto
	boton.set_meta("accion", accion)
	boton.custom_minimum_size = Vector2(diametro, diametro)
	boton.size = Vector2(diametro, diametro)
	boton.focus_mode = Control.FOCUS_NONE
	boton.add_theme_font_size_override("font_size", fuente)
	boton.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0))
	boton.add_theme_color_override("font_hover_color", Color.WHITE)
	boton.add_theme_color_override("font_pressed_color", Color.WHITE)
	boton.add_theme_stylebox_override("normal",
		_estilo_circulo(color, 0.30, diametro))
	boton.add_theme_stylebox_override("hover",
		_estilo_circulo(color, 0.45, diametro))
	boton.add_theme_stylebox_override("pressed",
		_estilo_circulo(color, 0.68, diametro))
	boton.add_theme_stylebox_override("focus",
		_estilo_circulo(color, 0.0, diametro))
	boton.button_down.connect(_al_pulsar.bind(boton))
	_raiz.add_child(boton)
	return boton


func _estilo_circulo(color: Color, alfa: float, diametro: float) -> StyleBoxFlat:
	var estilo: StyleBoxFlat = StyleBoxFlat.new()
	estilo.bg_color = Color(color.r, color.g, color.b, alfa)
	estilo.border_color = Color(color.r, color.g, color.b, 0.9)
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(int(diametro * 0.5))
	return estilo


# --- Pulsar acciones del Input Map ---------------------------------------

func _al_pulsar(boton: Button) -> void:
	var accion: String = String(boton.get_meta("accion", ""))
	if accion == "":
		return
	var ahora: int = Time.get_ticks_msec()
	if ahora - int(_ultimo_pulso.get(accion, -99999)) < ANTI_REBOTE_MS:
		return                                   # doble toque ignorado
	_ultimo_pulso[accion] = ahora
	pulsar_accion(accion)


## Multitáctil explícito para los botones.
##
## Un nodo Button de Godot solo reacciona a un toque a la vez (el ratón emulado
## sigue a un único dedo) y el enunciado pide poder moverse y pulsar a la vez.
## Aquí se atienden TODOS los dedos por su índice, así que se puede llevar la
## pala con el pulgar izquierdo y pulsar LANZAR / PAUSA con el derecho.
## (El anti-rebote de _al_pulsar evita que un toque cuente dos veces cuando
## Godot además genera el ratón emulado.)
func _input(evento: InputEvent) -> void:
	if not visible:
		return
	if evento is InputEventScreenTouch and evento.pressed:
		var boton: Button = _boton_en(evento.position)
		if boton != null:
			_al_pulsar(boton)


## Devuelve el botón táctil que contiene ese punto (o null).
func _boton_en(punto: Vector2) -> Button:
	for accion: String in _botones:
		var boton: Button = _botones[accion]
		if boton.visible and boton.get_global_rect().has_point(punto):
			return boton
	return null


## Mantiene la acción pulsada el tiempo suficiente para que el juego la vea
## (el juego la lee por sondeo, así funciona igual que el teclado).
func pulsar_accion(accion: String) -> void:
	Input.action_press(accion, 1.0)
	await get_tree().create_timer(float(PULSO_MS) / 1000.0).timeout
	Input.action_release(accion)


## Suelta todas las acciones táctiles (al ocultar la capa o cerrar la escena).
func soltar_todo() -> void:
	for accion: String in _botones.keys():
		Input.action_release(accion)
	if joystick != null:
		joystick.soltar()


# --- Ajustes, zona segura y colocación -----------------------------------

## Aplica opacidad, tamaño, zona muerta y recoloca los controles.
func actualizar_ajustes() -> void:
	var radio: float = RADIO_JOYSTICK * GameData.touch_size
	var opacidad: float = GameData.touch_opacity

	if joystick != null:
		joystick.configurar(radio, GameData.touch_deadzone)
		joystick.modulate.a = opacidad
	for boton: Button in _botones.values():
		boton.modulate.a = opacidad

	_colocar(radio)
	visible = debe_mostrarse()


## Controles solo en móvil, con modo de depuración para PC ("siempre").
func debe_mostrarse() -> bool:
	match GameData.touch_mode:
		"siempre":
			return true
		"nunca":
			return false
		_:
			return DisplayServer.is_touchscreen_available()


func _colocar(radio_joystick: float) -> void:
	var zona: Vector4 = zona_segura()          # izquierda, arriba, derecha, abajo
	var vista: Vector2 = get_viewport().get_visible_rect().size
	var ancho: float = vista.x - zona.x - zona.z
	var alto: float = vista.y - zona.y - zona.w

	# Joystick: esquina inferior IZQUIERDA (pulgar izquierdo)
	if joystick != null:
		joystick.size = Vector2(radio_joystick * 2.0, radio_joystick * 2.0)
		joystick.position = Vector2(
			zona.x + MARGEN,
			zona.y + alto - MARGEN - radio_joystick * 2.0)

	# LANZAR: esquina inferior DERECHA (pulgar derecho), sin tapar la acción
	var d_lanzar: Vector2 = _botones["launch"].size
	_botones["launch"].position = Vector2(
		zona.x + ancho - MARGEN - d_lanzar.x,
		zona.y + alto - MARGEN - d_lanzar.y)

	# PAUSA y REINICIAR: arriba a la derecha, lejos de los pulgares
	var d_pausa: Vector2 = _botones["pause"].size
	_botones["pause"].position = Vector2(
		zona.x + ancho - MARGEN - d_pausa.x, zona.y + MARGEN)
	var d_reinicio: Vector2 = _botones["restart"].size
	_botones["restart"].position = Vector2(
		zona.x + ancho - MARGEN - d_reinicio.x,
		zona.y + MARGEN + d_pausa.y + 12.0)


## Área segura de la pantalla (notch, bordes redondeados, barra de gestos)
## expresada en unidades del diseño (1280x720 con stretch canvas_items).
func zona_segura() -> Vector4:
	var ventana: Vector2i = DisplayServer.window_get_size()
	var segura: Rect2i = DisplayServer.get_display_safe_area()
	var vista: Vector2 = get_viewport().get_visible_rect().size
	if ventana.x <= 0 or ventana.y <= 0 or vista.x <= 0.0 or vista.y <= 0.0:
		return Vector4.ZERO
	if segura.size.x <= 0 or segura.size.y <= 0:
		return Vector4.ZERO

	var escala: Vector2 = Vector2(ventana) / vista
	if escala.x <= 0.0 or escala.y <= 0.0:
		return Vector4.ZERO

	var izquierda: float = maxf(0.0, float(segura.position.x) / escala.x)
	var arriba: float = maxf(0.0, float(segura.position.y) / escala.y)
	var derecha: float = maxf(0.0, float(ventana.x - segura.end.x) / escala.x)
	var abajo: float = maxf(0.0, float(ventana.y - segura.end.y) / escala.y)

	# En escritorio la "zona segura" suele ser toda la pantalla y estos valores
	# salen 0; además se limita para que nunca se coma más de un cuarto.
	var tope: Vector2 = vista * 0.25
	return Vector4(
		minf(izquierda, tope.x), minf(arriba, tope.y),
		minf(derecha, tope.x), minf(abajo, tope.y))