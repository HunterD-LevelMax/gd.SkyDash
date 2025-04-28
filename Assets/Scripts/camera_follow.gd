extends Camera3D

@export var spring_arm: Node3D
@export var follow_speed: float = 5.0  # Скорость следования
@export var rotation_follow_speed: float = 8.0  # Скорость поворота

func _physics_process(delta: float) -> void:
	if not spring_arm:
		return
	
	# Плавное следование позиции
	global_position = global_position.lerp(
		spring_arm.global_position, 
		follow_speed * delta
	)
	
	# Плавный поворот (если нужно)
	global_rotation = global_rotation.lerp(
		spring_arm.global_rotation,
		rotation_follow_speed * delta
	)
