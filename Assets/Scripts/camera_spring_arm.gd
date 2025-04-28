extends Node3D

# Настройки вращения
@export var mouse_sensitivity: float = 0.005
@export_range(-90.0, 0.0, 0.1, "radians_as_degrees") 
var min_vertical_angle: float = deg_to_rad(-60)  # Ограничение угла вниз
@export_range(0.0, 90.0, 0.1, "radians_as_degrees") 
var max_vertical_angle: float = deg_to_rad(60)    # Ограничение угла вверх

# Настройки зума
@export var zoom_speed: float = 1.0
@export var min_spring_length: float = 1.0
@export var max_spring_length: float = 10.0
@export var zoom_interpolation_speed: float = 5.0  # Плавность зума

@onready var spring_arm: SpringArm3D = $SpringArm3D

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	# Вращение камеры
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x * mouse_sensitivity
		rotation.y = wrapf(rotation.y, -TAU, TAU)  # Нормализация угла
		
		rotation.x -= event.relative.y * mouse_sensitivity
		rotation.x = clamp(rotation.x, min_vertical_angle, max_vertical_angle)
	
	# Зум колесиком мыши
	if event.is_action_pressed("wheel_up"):
		spring_arm.spring_length = clamp(
			spring_arm.spring_length - zoom_speed, 
			min_spring_length, 
			max_spring_length
		)
	if event.is_action_pressed("wheel_down"):
		spring_arm.spring_length = clamp(
			spring_arm.spring_length + zoom_speed, 
			min_spring_length, 
			max_spring_length
		)
	
	# Переключение режима мыши
	if event.is_action_pressed("toggle_mouse_captured"):
		match Input.mouse_mode:
			Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			_:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Плавное обновление зума (если нужно)
func _process(delta: float) -> void:
	spring_arm.spring_length = lerp(
		spring_arm.spring_length,
		clamp(spring_arm.spring_length, min_spring_length, max_spring_length),
		zoom_interpolation_speed * delta
	)
