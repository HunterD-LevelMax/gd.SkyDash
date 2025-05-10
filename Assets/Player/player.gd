extends CharacterBody3D

# Настройки движения
@export var speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 6
@export var gravity: float = 9.5
@export var rotation_speed: float = 10.0
@export var sprint_stamina_max: float = 100.0
@export var stamina_drain_rate: float = 20.0
@export var stamina_regen_rate: float = 15.0
@export var sprint_jump_multiplier: float = 1.08
@export var jump_buffer_time: float = 0.1  # Время буферизации ввода прыжка
@export var coyote_time: float = 0.2  # Время койот-тайма для прыжка после покидания платформы
@export var air_control_factor: float = 1.0  # Коэффициент управления в воздухе

# Настройки анимаций
@export var run_animation: String = "Running/mixamo_com"
@export var idle_animation: String = "Idle/mixamo_com"
@export var jump_animation: String = "Jump/mixamo_com"
@export var fall_animation: String = "Falling/mixamo_com"
@export var dance_animation: String = "Samba_dancing/mixamo_com"

# Ноды
@onready var camera: Camera3D = $SpringArmPivot/Camera
@onready var skin: Node3D = $Skin

@onready var animation_player = $Skin/AnimationPlayer

@onready var stamina_bar: ProgressBar = $"../UI/Control/StaminaContainer/StaminaBar"

# Состояния
var _is_sprinting: bool = false
var _current_speed: float = speed
var _sprint_stamina: float = sprint_stamina_max
var _score: int = 0
var _is_god_mode: bool = false
var _is_jump_bonus_active: bool = false
var _original_jump_velocity: float = jump_velocity
var _jump_bonus_timer: SceneTreeTimer = null
var _jump_buffer_timer: float = 0.0  # Таймер для буферизации прыжка
var _coyote_timer: float = 0.0  # Таймер для койот-тайма
var _was_sprinting: bool = false  # Сохраняем состояние спринта для койот-тайма

# Константы
const GOD_MODE_SPEED: float = 10.0
const AIR_DAMPING: float = 0.5  # Скорость затухания горизонтальной скорости в воздухе

# Скин персонажа


func _ready() -> void:
	# Подключение сигнала завершения анимации
	animation_player.animation_finished.connect(_on_animation_finished)
	# Инициализация оригинальной высоты прыжка
	_original_jump_velocity = jump_velocity
	
func _physics_process(delta: float) -> void:
	# Обновление буфера прыжка
	if Input.is_action_just_pressed("ui_accept"):
		_jump_buffer_timer = jump_buffer_time
	_jump_buffer_timer -= delta
	if _jump_buffer_timer < 0:
		_jump_buffer_timer = 0.0

	# Обновление койот-тайма
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer -= delta
	if _coyote_timer < 0:
		_coyote_timer = 0.0

	# Обработка движения
	if _is_god_mode:
		_handle_god_mode_movement()
	else:
		_handle_normal_movement(delta)
	move_and_slide()

func _input(event: InputEvent) -> void:
	# Переключение режима бога
	if event.is_action_pressed("toggle_god_mode"):
		_toggle_god_mode()

func _handle_normal_movement(delta: float) -> void:
	# Применение гравитации
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	# Обработка спринта (до прыжка, чтобы сохранить состояние)
	_handle_sprint(delta)
	_was_sprinting = _is_sprinting  # Сохраняем состояние спринта для койот-тайма

	# Обработка прыжка
	if _jump_buffer_timer > 0 and _coyote_timer > 0:
		velocity.y = jump_velocity * (sprint_jump_multiplier if _was_sprinting else 1.0)
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_is_sprinting = false  # Сбрасываем спринт при прыжке
		_current_speed = speed  # Возвращаем базовую скорость
		animation_player.play(jump_animation)

	# Получение направления движения
	var input_dir: Vector2 = Input.get_vector("left", "right", "down", "up")
	var direction: Vector3 = _get_camera_relative_direction(input_dir)

	# Управление движением и вращением
	if direction.length() > 0:
		var target_angle: float = atan2(direction.x, direction.z)
		skin.rotation.y = lerp_angle(skin.rotation.y, target_angle, rotation_speed * delta)
		var control_factor: float = air_control_factor if not is_on_floor() else 1.0
		var target_speed: float = speed if not is_on_floor() else _current_speed
		velocity.x = lerp(velocity.x, direction.x * target_speed, control_factor * delta * rotation_speed)
		velocity.z = lerp(velocity.z, direction.z * target_speed, control_factor * delta * rotation_speed)
	else:
		# Затухание горизонтальной скорости
		if not is_on_floor():
			velocity.x = move_toward(velocity.x, 0, AIR_DAMPING * delta)
			velocity.z = move_toward(velocity.z, 0, AIR_DAMPING * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, _current_speed)
			velocity.z = move_toward(velocity.z, 0, _current_speed)

	# Обновление анимаций
	_update_animations()

func _handle_god_mode_movement() -> void:
	# Получение направления движения
	var input_dir: Vector2 = Input.get_vector("left", "right", "down", "up")
	var direction: Vector3 = _get_camera_relative_direction(input_dir)

	# Движение в горизонтальной плоскости
	velocity.x = direction.x * GOD_MODE_SPEED
	velocity.z = direction.z * GOD_MODE_SPEED

	# Управление высотой
	velocity.y = 0.0
	if Input.is_action_pressed("move_up"):
		velocity.y = GOD_MODE_SPEED
	elif Input.is_action_pressed("move_down"):
		velocity.y = -GOD_MODE_SPEED

func _get_camera_relative_direction(input_dir: Vector2) -> Vector3:
	# Получение направления относительно камеры
	if not camera:
		return Vector3.ZERO
	var forward: Vector3 = -camera.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	var right: Vector3 = camera.global_transform.basis.x
	right.y = 0
	right = right.normalized()
	return (forward * input_dir.y + right * input_dir.x).normalized()

func _handle_sprint(delta: float) -> void:
	# Проверка возможности спринта
	var can_sprint: bool = (
		Input.is_action_pressed("sprint") and
		is_on_floor() and
		_sprint_stamina > 0 and
		Input.get_vector("left", "right", "down", "up").length() > 0
	)

	# Применение спринта
	if can_sprint:
		_is_sprinting = true
		_current_speed = sprint_speed
		_sprint_stamina = max(0, _sprint_stamina - stamina_drain_rate * delta)
		animation_player.speed_scale = 1.5
	else:
		_is_sprinting = false
		_current_speed = speed
		_sprint_stamina = min(sprint_stamina_max, _sprint_stamina + stamina_regen_rate * delta)
		animation_player.speed_scale = 1.0

	# Обновление полоски стамины
	if stamina_bar:
		stamina_bar.value = _sprint_stamina

func _update_animations() -> void:
	# Управление анимациями
	if animation_player.current_animation == dance_animation:
		return
	if animation_player.current_animation == jump_animation:
		return
	if not is_on_floor() and velocity.y < 0:
		animation_player.play(fall_animation)
	elif is_on_floor() and (_is_sprinting or Input.get_vector("left", "right", "down", "up").length() > 0):
		animation_player.play(run_animation)
	else:
		animation_player.play(idle_animation)

func _on_animation_finished(anim_name: String) -> void:
	# Сброс состояния после завершения анимации прыжка
	if anim_name == jump_animation:
		_update_animations()

func _toggle_god_mode() -> void:
	# Переключение режима бога
	_is_god_mode = not _is_god_mode
	velocity = Vector3.ZERO
	print("Режим бога %s" % ("включен" if _is_god_mode else "выключен"))

func add_score() -> void:
	# Увеличение счета игрока
	_score += 1

func apply_jump_bonus(boost_multiplier: float, duration: float) -> void:
	# Применение бонуса прыжка
	if _is_jump_bonus_active:
		_end_jump_bonus()
	_is_jump_bonus_active = true
	jump_velocity = _original_jump_velocity * boost_multiplier
	_jump_bonus_timer = get_tree().create_timer(duration)
	_jump_bonus_timer.timeout.connect(_end_jump_bonus)

func _end_jump_bonus() -> void:
	# Завершение бонуса прыжка
	if _is_jump_bonus_active:
		jump_velocity = _original_jump_velocity
		_is_jump_bonus_active = false
		_jump_bonus_timer = null

func _on_floor_entered(body: Node) -> void:
	# Обработка падения игрока
	if body.name == "Player":
		get_tree().call_group("level", "player_fell")
		
func _dance_play()-> void:
	animation_player.play(dance_animation)
