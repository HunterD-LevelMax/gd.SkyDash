extends Node3D

# Настройки вращения
@export var mouse_sensitivity: float = 0.005
@export_range(-90.0, 0.0, 0.1, "radians_as_degrees") 
var min_vertical_angle: float = deg_to_rad(-60)
@export_range(0.0, 90.0, 0.1, "radians_as_degrees") 
var max_vertical_angle: float = deg_to_rad(60)
@export var gamepad_sensitivity: float = 3.0  # Чувствительность геймпада
@export var touch_sensitivity: float = 0.005  # Чувствительность сенсора
@export var rotation_smoothing: float = 15.0  # Скорость сглаживания поворота

# Настройки зума
@export var zoom_speed: float = 1.0
@export var min_spring_length: float = 1.0
@export var max_spring_length: float = 5.0
@export var zoom_interpolation_speed: float = 5.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
var player: CharacterBody3D
var target_rotation: Vector3 = Vector3.ZERO  # Целевая ориентация для сглаживания
var touch_active: bool = false  # Флаг активности сенсорного ввода
var last_touch_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	player = get_parent() if get_parent() is CharacterBody3D else null
	# Установите начальный вид сзади
	target_rotation = Vector3(deg_to_rad(-15), PI, 0)  # Немного вниз и разворот на 180°
	
	rotation = target_rotation
	player = get_parent() if get_parent() is CharacterBody3D else null
	if not player:
		print("Ошибка: Игрок не найден в родительском узле")

func _input(event: InputEvent) -> void:
	# Вращение камеры мышью
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		target_rotation.y -= event.relative.x * mouse_sensitivity
		target_rotation.x -= event.relative.y * mouse_sensitivity
		get_viewport().set_input_as_handled()

	# Сенсорное вращение камеры
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_active = true
			last_touch_position = event.position
			get_viewport().set_input_as_handled()
		elif not event.pressed:
			touch_active = false
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and touch_active:
		var delta = (event.position - last_touch_position) * touch_sensitivity
		target_rotation.y -= delta.x
		target_rotation.x -= delta.y
		last_touch_position = event.position
		get_viewport().set_input_as_handled()

	# Зум
	if event.is_action_pressed("wheel_up"):
		spring_arm.spring_length = clamp(spring_arm.spring_length - zoom_speed, min_spring_length, max_spring_length)
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("wheel_down"):
		spring_arm.spring_length = clamp(spring_arm.spring_length + zoom_speed, min_spring_length, max_spring_length)
		get_viewport().set_input_as_handled()

	# Переключение режима мыши
	if event.is_action_pressed("toggle_mouse_captured"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	# Вращение камеры геймпадом
	if player and Input.get_connected_joypads().size() > 0:
		var camera_input: Vector2 = Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
		if camera_input.length():
			target_rotation.y -= camera_input.x * gamepad_sensitivity * delta
			target_rotation.x -= camera_input.y * gamepad_sensitivity * delta

	# Сглаживание поворота
	rotation.y = lerp_angle(rotation.y, target_rotation.y, rotation_smoothing * delta)
	rotation.x = clamp(lerp(rotation.x, target_rotation.x, rotation_smoothing * delta), min_vertical_angle, max_vertical_angle)

	# Плавное обновление зума
	spring_arm.spring_length = lerp(
		spring_arm.spring_length,
		clamp(spring_arm.spring_length, min_spring_length, max_spring_length),
		zoom_interpolation_speed * delta
	)
