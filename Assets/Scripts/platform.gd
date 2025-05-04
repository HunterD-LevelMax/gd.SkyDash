extends StaticBody3D

signal add_coin
signal platform_destroyed

const SIZE_A = Vector3(1.2, 0.4, 1.9)
const SIZE_B = Vector3(1.0, 0.4, 1.7)   

var is_blinking = false
var blink_time_total = 5.0  # Общее время пульсации
var blink_timer = 0.0  # Текущее время
var pulse_speed = 2.0  # Скорость пульсации (циклы в секунду)

func _ready():
	pass

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.name == "Player" and not is_blinking:
		is_blinking = true
		blink_timer = 0.0
		set_process(true)  # Включаем обработку кадров

func _process(delta: float) -> void:
	if is_blinking:
		blink_timer += delta
		
		# Пульсация: интерполяция между SIZE_A и SIZE_B с использованием синусоиды
		var pulse_factor = (sin(blink_timer * PI * pulse_speed) + 1) / 2  # Значение от 0 до 1
		var target_size = SIZE_A.lerp(SIZE_B, pulse_factor)
		scale = target_size
		
		# Проверка завершения времени пульсации
		if blink_timer >= blink_time_total:
			set_process(false)  # Отключаем обработку
			emit_signal("platform_destroyed")  # Сигнал о разрушении
			hide_platform()  # Скрываем платформу

func hide_platform() -> void:
	visible = false  # Скрываем платформу
	is_blinking = false  # Сбрасываем состояние
	scale = SIZE_A  # Сбрасываем масштаб до начального
	queue_free_parent()  # Убираем платформу из сцены

func queue_free_parent() -> void:
	if get_parent():
		get_parent().remove_child(self)  # Удаляем платформу из родительской сцены
