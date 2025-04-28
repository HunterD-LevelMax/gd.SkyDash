extends Area3D

@export var jump_boost: float = 1.25  # На 25% увеличиваем прыжок
@export var boost_duration: float = 10.0  # Длительность бонуса в секундах
@export var rotation_speed: float = 2.0  # Скорость вращения в радианах/секунду

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	# Вращаем бонус вокруг оси Y
	rotation.y += rotation_speed * delta

func _on_body_entered(body: Node) -> void:
	if body.name == "Player":
		var player = body as CharacterBody3D
		if player and player.has_method("apply_jump_bonus"):
			# Применяем бонус через метод игрока
			player.apply_jump_bonus(jump_boost, boost_duration)
			
			# Скрываем бонус перед удалением
			visible = false
			# Отключаем коллизию
			set_deferred("monitoring", false)
			set_deferred("monitorable", false)
			# Удаляем бонус
			queue_free()
