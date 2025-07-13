extends CharacterBody3D

# Настройки движения
@export var speed: float = 5.0
@export var sprint_speed: float = 6.0
@export var jump_velocity: float = 6.9
@export var gravity: float = 9.8
@export var rotation_speed: float = 10.0
@export var sprint_stamina_max: float = 100.0
@export var stamina_drain_rate: float = 15.0
@export var stamina_regen_rate: float = 12.0
@export var sprint_jump_multiplier: float = 1.10
@export var jump_buffer_time: float = 0.3
@export var coyote_time: float = 0.3
@export var air_control_factor: float = 1.0

# Настройки анимаций
@export var run_animation: String = "running/mixamo_com"
@export var idle_animation: String = "idle/mixamo_com"
@export var jump_animation: String = "jump/mixamo_com"
@export var fall_animation: String = "falling/mixamo_com"
@export var dance_animation: String = "dancing/mixamo_com"

# Ноды
@onready var camera: Camera3D = $SpringArmPivot/Camera
@onready var text3d: Label3D = $TextLabel3D
@onready var jump_audio: AudioStreamPlayer = $JumpAudio
@onready var stamina_bar: ProgressBar = $"../UI/Control/StaminaContainer/StaminaBar"

var skin: Node = null
var animation_player: AnimationPlayer

# Состояния
var _is_sprinting: bool = false
var _current_speed: float = speed
var _sprint_stamina: float = sprint_stamina_max
var _score: int = 0
var _is_god_mode: bool = false
var _is_jump_bonus_active: bool = false
var _original_jump_velocity: float = jump_velocity
var _jump_bonus_timer: SceneTreeTimer = null
var _jump_buffer_timer: float = 0.0
var _coyote_timer: float = 0.0
var _was_sprinting: bool = false

var auto_run_speed: float = 6.0
var is_auto_running: bool = false

# Константы
const GOD_MODE_SPEED: float = 30.0
const AIR_DAMPING: float = 0.4

func _ready() -> void:
	_load_skin(Global.current_skin)
	_original_jump_velocity = jump_velocity

func _physics_process(delta: float) -> void:
	# Обновление буфера прыжка
	if Input.is_action_just_pressed("jump"):
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
	elif is_auto_running:
		_handle_auto_run_movement(delta)
	else:
		_handle_normal_movement(delta)
		
	move_and_slide()
	
func _handle_auto_run_movement(delta: float) -> void:
	$"Joystick/Virtual Joystick".visible = false
	# Применение гравитации
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
	
	# Автоматическое движение строго вперед по оси Z (без поворотов)
	velocity.x = 0.0  # Обнуляем боковое движение
	velocity.z = auto_run_speed
	
	# Автоматический поворот в сторону движения камеры (если нужно)
	if camera:
		var camera_forward = -camera.global_transform.basis.z
		camera_forward.y = 0
		var target_angle = atan2(camera_forward.x, camera_forward.z)
		skin.rotation.y = lerp_angle(skin.rotation.y, target_angle, rotation_speed * delta)
	
	# Обработка прыжка
	if _jump_buffer_timer > 0 and _coyote_timer > 0:
		_perform_auto_run_jump()
		
	# Принудительно включаем анимацию бега
	if is_on_floor() and animation_player.current_animation != jump_animation:
		animation_player.play(run_animation)
		animation_player.speed_scale = 1.0

func _perform_auto_run_jump() -> void:
	velocity.y = jump_velocity - 1.0
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	jump_audio.play()
	animation_player.play(jump_animation)
		
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_god_mode"):
		_toggle_god_mode()

func _handle_normal_movement(delta: float) -> void:
	# Применение гравитации
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	# Обработка спринта
	_handle_sprint(delta)
	_was_sprinting = _is_sprinting

	# Обработка прыжка
	if _jump_buffer_timer > 0 and _coyote_timer > 0:
		velocity.y = jump_velocity * (sprint_jump_multiplier if _was_sprinting else 1.0)
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_is_sprinting = false
		_current_speed = speed
		jump_audio.play()
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
	var input_dir: Vector2 = Input.get_vector("left", "right", "down", "up")
	var direction: Vector3 = _get_camera_relative_direction(input_dir)
	velocity.x = direction.x * GOD_MODE_SPEED
	velocity.z = direction.z * GOD_MODE_SPEED
	velocity.y = 0.0
	if Input.is_action_pressed("move_up"):
		velocity.y = GOD_MODE_SPEED
	elif Input.is_action_pressed("move_down"):
		velocity.y = -GOD_MODE_SPEED

func _get_camera_relative_direction(input_dir: Vector2) -> Vector3:
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
	var can_sprint: bool = (
		is_on_floor() and
		_sprint_stamina > 0 and
		Input.get_vector("left", "right", "down", "up").length() > 0
	)

	if can_sprint:
		_is_sprinting = true
		_current_speed = sprint_speed
		_sprint_stamina = max(0, _sprint_stamina - stamina_drain_rate * delta)
		animation_player.speed_scale = 1.5
	else:
		_is_sprinting = false
		_current_speed = speed
		if is_on_floor():
			_sprint_stamina = min(sprint_stamina_max, _sprint_stamina + stamina_regen_rate * delta)
		animation_player.speed_scale = 1.0

	if stamina_bar:
		stamina_bar.value = _sprint_stamina

func _update_animations() -> void:
	if is_on_floor() and is_auto_running == true:
		animation_player.play(run_animation)
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
	if anim_name == jump_animation:
		_update_animations()

func _toggle_god_mode() -> void:
	_is_god_mode = not _is_god_mode
	velocity = Vector3.ZERO
	print("Режим бога %s" % ("включен" if _is_god_mode else "выключен"))

func add_score() -> void:
	_score += 1

func apply_jump_bonus(boost_multiplier: float, duration: float) -> void:
	show_floating_text("I became stronger!", 1.0)
	if _is_jump_bonus_active:
		_end_jump_bonus()
	_is_jump_bonus_active = true
	jump_velocity = _original_jump_velocity * boost_multiplier
	_jump_bonus_timer = get_tree().create_timer(duration)
	_jump_bonus_timer.timeout.connect(_end_jump_bonus)

func _end_jump_bonus() -> void:
	if _is_jump_bonus_active:
		jump_velocity = _original_jump_velocity
		_is_jump_bonus_active = false
		_jump_bonus_timer = null

func change_skin(new_skin_path: String) -> void:
	Global.set_skin(new_skin_path)
	_load_skin(new_skin_path)

func _load_skin(new_skin: String) -> void:
	if skin != null:
		remove_child(skin)
		skin.queue_free()
		skin = null

	var skin_scene: PackedScene = load(new_skin)
	if skin_scene:
		skin = skin_scene.instantiate()
		add_child(skin)
		skin.position = Vector3.ZERO
		animation_player = skin.get_node("AnimationPlayer")
		if animation_player:
			animation_player.animation_finished.connect(_on_animation_finished)
		else:
			print("Ошибка: AnimationPlayer не найден в скине!")

func _dance_play() -> void:
	animation_player.play(dance_animation)

func show_floating_text(text: String, duration: float = 2.0) -> void:
	text3d.text = text
	text3d.position = Vector3(0, 2.0, 0)
	text3d.visible = true
	var tween = create_tween().set_parallel(true)
	tween.tween_property(text3d, "position:y", text3d.position.y + 1.0, duration)
	tween.tween_callback(func(): text3d.visible = false).set_delay(duration)

func _on_touch_screen_button_pressed() -> void:
	Input.action_press("jump")
	await get_tree().create_timer(0.1).timeout
	Input.action_release("jump")
