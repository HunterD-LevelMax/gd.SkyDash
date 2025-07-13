extends Node3D

signal add_coin

@export var rotation_speed: float = 2.0  # Скорость вращения в радианах/секунду
@export var jump_height: float = 1.2  # Высота подпрыгивания монеты
@export var jump_duration: float = 0.2  # Время подпрыгивания

@onready var coin_audio: AudioStreamPlayer = $CoinAudio  # Звук сбора монеты
@onready var coin_area: Area3D = $CoinArea  # Зона столкновения монеты

var collected: bool = false  # Флаг, указывающий, собрана ли монета
var original_position: Vector3  # Исходная позиция монеты

# Инициализация монеты
func _ready() -> void:
	original_position = position
	coin_audio.finished.connect(_on_coin_audio_finished)
	add_to_group("coins")
	
# Обработка вращения монеты
func _process(delta: float) -> void:
	if not collected:
		rotate_y(rotation_speed * delta)

# Обработка столкновения с игроком
func _on_coin_area_body_entered(body: Node3D) -> void:
	if collected or body.name != "Player":
		return
	collected = true
	emit_signal("add_coin")
	print("Коснулись монеты")
	
	# Отключаем столкновения
	coin_area.set_deferred("monitoring", false)
	coin_area.set_deferred("monitorable", false)
	
	# Останавливаем вращение
	set_process(false)
	
	# Анимация подпрыгивания и исчезновения
	var jump_up: Vector3 = original_position + Vector3(0, jump_height, 0)
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", jump_up, jump_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		
		visible = false
		if coin_audio.stream:  # Проверка наличия звука
			coin_audio.play()
		else:
			_on_coin_audio_finished()  # Удаляем, если звука нет
	)
# Удаление монеты после окончания звука
func _on_coin_audio_finished() -> void:
	queue_free()
