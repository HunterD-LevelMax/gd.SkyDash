extends StaticBody3D

signal platform_destroyed

const COLOR_A = Color(0.6, 0.8, 1)    # Светло-голубой
const COLOR_B = Color(1, 0.8, 0.6)    # Светло-оранжевый

var is_blinking = false

func _ready():
	pass

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.name == "Player" and not is_blinking:
		is_blinking = true
		blink_and_destroy()

func blink_and_destroy() -> void:
	var blink_time := 5.0
	var interval := 0.5
	var t := 0.0
	var color_toggle := false

	while t < blink_time:
		await get_tree().create_timer(interval).timeout
		t += interval
	
	emit_signal("platform_destroyed")  # Сигнал о разрушении
	
	# Вместо queue_free(), скрываем платформу и возвращаем её в пул
	hide_platform()
	
func hide_platform() -> void:
	visible = false  # Скрываем платформу
	is_blinking = false  # Сбрасываем состояние мигания
	queue_free_parent()  # Убираем платформу из текущей сцены (не удаляем!)

func queue_free_parent() -> void:
	if get_parent():
		get_parent().remove_child(self)  # Удаляем платформу из родительской сцены
