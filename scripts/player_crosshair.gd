## PlayerCrosshair — handles aiming and shooting for one player
extends Node2D

signal shot_fired(player_id: int, aim_position: Vector2)
signal ui_shot_fired(player_id: int, aim_position: Vector2)

@export var player_id: int = 0  # 0 = P1, 1 = P2
@export var crosshair_color: Color = Color.CYAN
@export var crosshair_size: float = 24.0
@export var aim_speed: float = 800.0  # For keyboard-controlled P2

var aim_position: Vector2 = Vector2(960, 540)
var _fire_cooldown: float = 0.0
const FIRE_RATE: float = 0.15  # Seconds between shots

## Joystick device index for this player (P1=0, P2=1)
var _joy_device: int = -1
## Whether this player has an active joystick (Sinden Lightgun)
var _has_joystick: bool = false


func _ready() -> void:
	# Set initial position based on player
	var viewport_size = get_viewport_rect().size
	if player_id == 0:
		aim_position = viewport_size * 0.4
	else:
		aim_position = viewport_size * 0.6
	z_index = 100  # Always on top
	# Hide default mouse cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	# Check for connected joysticks
	_joy_device = player_id  # P1 = device 0, P2 = device 1
	_check_joystick()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _check_joystick() -> void:
	var connected = Input.get_connected_joypads()
	_has_joystick = _joy_device in connected
	if _has_joystick:
		var joy_name = Input.get_joy_name(_joy_device)
		print("Player %d: Joystick detected — %s (device %d)" % [player_id + 1, joy_name, _joy_device])


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if device == _joy_device:
		_has_joystick = connected
		if connected:
			var joy_name = Input.get_joy_name(device)
			print("Player %d: Joystick connected — %s" % [player_id + 1, joy_name])
		else:
			print("Player %d: Joystick disconnected" % [player_id + 1])


func _process(delta: float) -> void:
	_fire_cooldown = max(_fire_cooldown - delta, 0.0)

	# Aiming priority: Joystick > Mouse (P1) / Keyboard (P2)
	if _has_joystick:
		_handle_joystick_input()
	elif player_id == 0:
		_handle_mouse_input()
	else:
		_handle_keyboard_input(delta)

	position = aim_position
	queue_redraw()

	# Fire
	var fire_action = "p1_fire" if player_id == 0 else "p2_fire"
	if Input.is_action_pressed(fire_action) and _fire_cooldown <= 0.0:
		_fire_cooldown = FIRE_RATE
		var is_gameplay = (GameManager.current_state == GameManager.GameState.PLAYING or
			GameManager.current_state == GameManager.GameState.SUDDEN_DEATH)
		if is_gameplay:
			SoundManager.play_sfx("shoot")
			shot_fired.emit(player_id, aim_position)
		else:
			SoundManager.play_sfx("button_click")
			# UI shooting — for pressing buttons on Attract/HowToPlay screens
			ui_shot_fired.emit(player_id, aim_position)


func _handle_joystick_input() -> void:
	## Sinden Lightgun in joystick mode sends absolute position via axes 0 (X) and 1 (Y)
	## Axis range: -1.0 to 1.0 → map to screen coordinates
	var joy_x = Input.get_joy_axis(_joy_device, JOY_AXIS_LEFT_X)
	var joy_y = Input.get_joy_axis(_joy_device, JOY_AXIS_LEFT_Y)

	var vp = get_viewport_rect().size
	# Map axis (-1..1) to screen (0..viewport_width/height)
	aim_position.x = (joy_x + 1.0) * 0.5 * vp.x
	aim_position.y = (joy_y + 1.0) * 0.5 * vp.y
	# Clamp to viewport
	aim_position.x = clampf(aim_position.x, 0, vp.x)
	aim_position.y = clampf(aim_position.y, 0, vp.y)


func _handle_mouse_input() -> void:
	aim_position = get_global_mouse_position()


func _handle_keyboard_input(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("p2_aim_up"):
		dir.y -= 1
	if Input.is_action_pressed("p2_aim_down"):
		dir.y += 1
	if Input.is_action_pressed("p2_aim_left"):
		dir.x -= 1
	if Input.is_action_pressed("p2_aim_right"):
		dir.x += 1

	if dir.length() > 0:
		dir = dir.normalized()
		aim_position += dir * aim_speed * delta

	# Clamp to viewport
	var vp = get_viewport_rect().size
	aim_position.x = clampf(aim_position.x, 0, vp.x)
	aim_position.y = clampf(aim_position.y, 0, vp.y)


func _draw() -> void:
	# Draw crosshair
	var s = crosshair_size
	var thickness = 3.0
	# Outer ring
	draw_arc(Vector2.ZERO, s, 0, TAU, 32, crosshair_color, thickness)
	# Cross lines
	draw_line(Vector2(-s * 1.4, 0), Vector2(-s * 0.6, 0), crosshair_color, thickness)
	draw_line(Vector2(s * 0.6, 0), Vector2(s * 1.4, 0), crosshair_color, thickness)
	draw_line(Vector2(0, -s * 1.4), Vector2(0, -s * 0.6), crosshair_color, thickness)
	draw_line(Vector2(0, s * 0.6), Vector2(0, s * 1.4), crosshair_color, thickness)
	# Center dot
	draw_circle(Vector2.ZERO, 3.0, crosshair_color)
	# Player indicator
	var label = "P1" if player_id == 0 else "P2"
	draw_string(ThemeDB.fallback_font, Vector2(s + 5, -s), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, crosshair_color)
