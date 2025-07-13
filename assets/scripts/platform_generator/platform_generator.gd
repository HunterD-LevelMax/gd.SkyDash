extends Node
class_name PlatformGenerator

# Предзагруженные сцены
var _platform_scene: PackedScene = preload("res://assets/platforms/standart_platform/standart_platform.tscn")
var _win_platform_scene: PackedScene = preload("res://assets/platforms/win_platform/win_platform.tscn")
var _jump_bonus_scene: PackedScene = preload("res://assets/items/jump_bonus/Jump_bonus.tscn")
var _coin_scene: PackedScene = preload("res://assets/items/coin/coin.tscn")

# Конфигурация пула платформ
const POOL_SIZE: int = 50
var _platform_pool: Array[Node] = []
var _active_platforms: Array[Node] = []

# Свойства плоскости
var _plane_size: Vector2
var _plane_position: Vector3  # Центр плоскости
var _plane_surface_y: float  # Высота верхней поверхности плоскости
var _last_platform_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	# Инициализация пула платформ
	_initialize_platform_pool()

func initialize_plane(plane: Node3D) -> void:
	var plane_scale: Vector3 = plane.scale
	_plane_size = Vector2(plane_scale.x, plane_scale.z)
	_plane_position = plane.position

func spawn_base_grid(params: Dictionary) -> void:
	# Создание равномерной сетки платформ по всей площади Plane
	var spacing: float = params.get("spacing", 6.0)
	var platforms_x: int = int(_plane_size.x / spacing) + 1  # Количество платформ вдоль оси X
	var platforms_z: int = int(_plane_size.y / spacing) + 1  # Количество платформ вдоль оси Z
	var start_x: float = _plane_position.x - _plane_size.x / 2.0  # Начальная позиция по X
	var start_z: float = _plane_position.z - _plane_size.y / 2.0  # Начальная позиция по Z

	for i in range(platforms_x):
		for j in range(platforms_z):
			var pos_x: float = start_x + i * (_plane_size.x / (platforms_x - 1)) if platforms_x > 1 else _plane_position.x
			var pos_z: float = start_z + j * (_plane_size.y / (platforms_z - 1)) if platforms_z > 1 else _plane_position.z
			# Спавним платформы чуть выше поверхности плоскости
			var pos_y: float = _plane_surface_y + 0.5
			await _spawn_platform_with_animation(Vector3(pos_x, pos_y, pos_z), 0.1, 0.5)

func spawn_clustered_path(params: Dictionary) -> void:
	# Создание спирального пути платформ с постепенным подъёмом
	var turns_count: int = params.get("turns_count", 5)         # Количество витков спирали
	var platforms_per_turn: int = params.get("platforms_per_turn", 10) # Платформ на виток
	var spiral_step: float = params.get("spiral_step", 5.0)    # Увеличение радиуса на виток
	var vertical_step: float = params.get("vertical_step", 2.0) # Увеличение высоты на виток
	var cluster_radius: float = params.get("cluster_radius", 2.0) # Радиус кластера
	var difficulty: float = params.get("difficulty", 0.9)       # Модификатор плотности

	var max_radius: float = min(_plane_size.x, _plane_size.y) / 2.0 - cluster_radius
	var current_height: float = _plane_surface_y + 0.5

	for turn in range(turns_count):
		var radius_step: float = (spiral_step * difficulty) * (turn + 1) / turns_count
		radius_step = min(radius_step, max_radius)
		for i in range(platforms_per_turn):
			if not is_inside_tree():  # Проверяем, находится ли узел в дереве сцены
				return
			var angle: float = (i * 2.0 * PI / platforms_per_turn) + (turn * 2.0 * PI / platforms_per_turn)
			var pos_x: float = _plane_position.x + cos(angle) * radius_step
			var pos_z: float = _plane_position.z + sin(angle) * radius_step
			# Ограничиваем платформы границами Plane
			pos_x = clamp(pos_x, _plane_position.x - _plane_size.x / 2.0, _plane_position.x + _plane_size.x / 2.0)
			pos_z = clamp(pos_z, _plane_position.z - _plane_size.y / 2.0, _plane_position.z + _plane_size.y / 2.0)
			var pos_y: float = current_height + (turn * vertical_step * difficulty)
			# Добавляем небольшую вариацию внутри кластера
			var cluster_offset_x: float = randf_range(-cluster_radius, cluster_radius) * difficulty
			var cluster_offset_z: float = randf_range(-cluster_radius, cluster_radius) * difficulty
			pos_x += cluster_offset_x
			pos_z += cluster_offset_z
			await _spawn_platform_with_animation(Vector3(pos_x, pos_y, pos_z), 0.1, 0.5)
		current_height += vertical_step * difficulty

func spawn_win_platform(callback: Callable) -> void:
	# Создание платформы победы
	var win_platform: Node = _win_platform_scene.instantiate()
	# Спавним платформу победы в центре плоскости на высоте последней платформы + смещение
	var win_platform_y: float = _last_platform_position.y + 1.0
	if win_platform_y < _plane_surface_y + 0.5:
		win_platform_y = _plane_surface_y + 0.5
	win_platform.position = Vector3(_plane_position.x, win_platform_y, _plane_position.z)
	get_parent().add_child(win_platform)
	_active_platforms.append(win_platform)
	if win_platform.has_signal("platform_win"):
		win_platform.platform_win.connect(callback)
	
	# Анимация появления платформы победы
	win_platform.scale = Vector3.ZERO
	var tween = create_tween()
	tween.tween_property(win_platform, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _initialize_platform_pool() -> void:
	# Создание пула платформ для оптимизации
	for i in range(POOL_SIZE):
		var platform_instance: Node = _platform_scene.instantiate()
		platform_instance.visible = false
		add_child(platform_instance)
		_platform_pool.append(platform_instance)

func _spawn_platform(position: Vector3) -> Node:
	# Создание платформы из пула
	var platform_instance: Node = _get_platform_from_pool()
	platform_instance.position = position
	platform_instance.visible = true
	_active_platforms.append(platform_instance)
	_last_platform_position = position

	# Создание только одного бонуса на платформе
	var rand: float = randf()
	var bonus_position: Vector3 = position + Vector3(0, 1.0, 0)
	if rand < 0.02: # 2% шанс появления бонуса прыжка
		_spawn_bonus(_jump_bonus_scene, bonus_position)
	elif rand < 0.14: # 12% шанс появления монеты (0.02 + 0.12)
		_spawn_bonus(_coin_scene, bonus_position)

	return platform_instance

func _spawn_platform_with_animation(position: Vector3, delay: float, anim_duration: float) -> void:
	if not is_inside_tree():  # Проверяем, находится ли узел в дереве сцены
		return
	await get_tree().create_timer(delay).timeout
	if not is_inside_tree():  # Проверяем снова после задержки
		return
	var platform_instance: Node = _spawn_platform(position)
	platform_instance.scale = Vector3.ZERO
	var tween = create_tween()
	tween.tween_property(platform_instance, "scale", Vector3.ONE, anim_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _spawn_bonus(bonus_scene: PackedScene, position: Vector3) -> void:
	# Создание бонуса (монета или бонус прыжка)
	var bonus: Node = bonus_scene.instantiate()
	bonus.position = position
	get_parent().add_child(bonus)
	if bonus_scene == _coin_scene and bonus.has_signal("add_coin"):
		bonus.add_coin.connect(_on_coin_collected)
	elif bonus_scene == _jump_bonus_scene and bonus.has_signal("add_jump_boost"):
		bonus.add_jump_boost.connect(_on_jump_boost_collected)

func _get_platform_from_pool() -> Node:
	# Получение платформы из пула или создание новой
	for platform in _platform_pool:
		if not platform.visible:	
			return platform
	var new_platform: Node = _platform_scene.instantiate()
	add_child(new_platform)
	_platform_pool.append(new_platform)
	return new_platform

func _on_coin_collected() -> void:
	# Обработка сбора монеты
	get_parent()._on_coin_collected()

func _on_jump_boost_collected() -> void:
	# Заглушка для обработки бонуса прыжка
	pass
	
func clear_platforms() -> void:
	for platform in _active_platforms:
		if is_instance_valid(platform):
			platform.visible = false
	_active_platforms.clear()
