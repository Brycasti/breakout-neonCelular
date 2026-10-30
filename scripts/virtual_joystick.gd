class_name JoystickVirtual
extends Control
## Joystick virtual para pantalla táctil (Práctica 6).
##
## No mueve nada directamente: convierte el desplazamiento del dedo en las
## acciones del Input Map (`move_left` / `move_right`) con su fuerza, así el
## resto del juego no sabe si el input viene del teclado, de un mando o del dedo.
##
## Soporta MULTITOUCH: cada toque tiene su índice, y solo se atiende el dedo que
## empezó dentro del joystick. El otro pulgar puede pulsar botones a la vez.

const ACCION_IZQUIERDA: String = "move_left"
const ACCION_DERECHA: String = "move_right"

const ID_LIBRE: int = -9999

## Radio de la base en píxeles (80–120 según la práctica; se ajusta en AJUSTES).
var radio: float = 90.0
## Zona muerta: por debajo de esto no se mueve nada (0.15–0.25 recomendado).
var zona_muerta: float = 0.20
var color: Color = Color(0.35, 0.9, 1.0)

var _id_activo: int = ID_LIBRE       # índice del dedo que está usando el joystick
var _emular_raton: bool = false      # ¿"Emulate Touch From Mouse" está activo?
var _base: Panel = null
var _perilla: Panel = null
var _centro: Vector2 = Vector2.ZERO
var _centro_perilla: Vector2 = Vector2.ZERO
var _fuerza_actual: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_emular_raton = bool(ProjectSettings.get_setting(
		"input_devices/pointing/emulate_touch_from_mouse", false))

	_base = Panel.new()
	_base.name = "Base"
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_base)

	_perilla = Panel.new()
	_perilla.name = "Perilla"
	_perilla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_perilla)

	aplicar_tamano()


func _notification(que: int) -> void:
	# Si el joystick desaparece mientras se arrastra, hay que soltar las acciones
	# (si no, la pala se quedaría moviéndose sola para siempre).
	if que == NOTIFICATION_VISIBILITY_CHANGED or que == NOTIFICATION_EXIT_TREE:
		soltar()


## Aplica radio y zona muerta (se llama desde AJUSTES).
func configurar(radio_nuevo: float, zona_nueva: float) -> void:
	radio = clampf(radio_nuevo, 50.0, 200.0)
	zona_muerta = clampf(zona_nueva, 0.05, 0.45)
	aplicar_tamano()


func aplicar_tamano() -> void:
	size = Vector2(radio * 2.0, radio * 2.0)
	_centro = size * 0.5

	if _base != null:
		_base.position = Vector2.ZERO
		_base.size = size
		_base.add_theme_stylebox_override("panel",
			_estilo_circulo(Color(color.r, color.g, color.b, 0.10), 3, radio))

	if _perilla != null:
		var diametro: float = radio * 0.85
		_perilla.size = Vector2(diametro, diametro)
		_centro_perilla = _centro - Vector2(diametro, diametro) * 0.5
		_perilla.position = _centro_perilla
		_perilla.add_theme_stylebox_override("panel",
			_estilo_circulo(Color(color.r, color.g, color.b, 0.35), 3, diametro * 0.5))


func _estilo_circulo(relleno: Color, grosor: int, radio_esquina: float) -> StyleBoxFlat:
	var estilo: StyleBoxFlat = StyleBoxFlat.new()
	estilo.bg_color = relleno
	estilo.border_color = Color(color.r, color.g, color.b, 0.85)
	estilo.set_border_width_all(grosor)
	estilo.set_corner_radius_all(int(maxf(1.0, radio_esquina)))
	return estilo


func _gui_input(evento: InputEvent) -> void:
	# --- táctil (y ratón emulado como toque) ---
	if evento is InputEventScreenTouch:
		if evento.pressed:
			if _id_activo == ID_LIBRE:
				_id_activo = evento.index
				_empezar(evento.position)
		elif evento.index == _id_activo:
			soltar()
		accept_event()
		return

	if evento is InputEventScreenDrag and evento.index == _id_activo:
		_mover(evento.position - _centro)
		accept_event()
		return

	# --- ratón de verdad (para probar en PC con la emulación desactivada) ---
	if _emular_raton:
		return
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
		if evento.pressed:
			if _id_activo == ID_LIBRE:
				_id_activo = -1
				_empezar(evento.position)
		elif _id_activo == -1:
			soltar()
		accept_event()
		return

	if evento is InputEventMouseMotion and _id_activo == -1:
		_mover(evento.position - _centro)
		accept_event()


func _empezar(posicion: Vector2) -> void:
	_mover(posicion - _centro)


## Traduce el desplazamiento del dedo a las acciones de movimiento.
func _mover(desplazamiento: Vector2) -> void:
	var distancia: float = desplazamiento.length()
	var direccion: Vector2 = desplazamiento / maxf(distancia, 0.001)

	# La perilla nunca sale del radio
	if _perilla != null:
		_perilla.position = _centro_perilla + direccion * minf(distancia, radio)

	# Zona muerta: se remapea el recorrido útil a 0..1 (así el control es fino
	# al principio y llega a tope justo en el borde).
	var recorrido: float = clampf(distancia / maxf(radio, 1.0), 0.0, 1.0)
	var util: float = maxf(1.0 - zona_muerta, 0.001)
	_fuerza_actual = clampf((recorrido - zona_muerta) / util, 0.0, 1.0)

	_aplicar(direccion.x * _fuerza_actual)


## Marca las acciones del Input Map según el eje horizontal (-1..1).
func _aplicar(eje: float) -> void:
	if eje > 0.05:
		Input.action_release(ACCION_IZQUIERDA)
		Input.action_press(ACCION_DERECHA, clampf(eje, 0.0, 1.0))
	elif eje < -0.05:
		Input.action_release(ACCION_DERECHA)
		Input.action_press(ACCION_IZQUIERDA, clampf(-eje, 0.0, 1.0))
	else:
		Input.action_release(ACCION_IZQUIERDA)
		Input.action_release(ACCION_DERECHA)


## Suelta el joystick y sus acciones (al levantar el dedo o al ocultarse).
func soltar() -> void:
	_id_activo = ID_LIBRE
	_fuerza_actual = 0.0
	if _perilla != null:
		_perilla.position = _centro_perilla
	_aplicar(0.0)


func fuerza() -> float:
	return _fuerza_actual