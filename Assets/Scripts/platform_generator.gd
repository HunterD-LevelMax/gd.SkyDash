extends Node
class_name PlatformGenerator

# Предзагруженные сцены
var _platform_scene: PackedScene = preload("res://Assets/Platform/standart_platform.tscn")
var _win_platform_scene: PackedScene = preload("res://Assets/Platform/win_platform.tscn")
var _jump_bonus_scene: PackedScene = preload("res://Assets/Items/Jump_bonus.tscn")
var _coin_scene: PackedScene = preload("res://Assets/Items/coin.tscn")

# Конфигурация пула платформ
const POOL_SIZE: int = 50
var _platform_pool: Array[Node] = []
var _active_platforms: Array[Node] = []

# Свойства плоскости
var _plane_size: Vector2
var _plane_position: Vector3
var _last_platform_position: Vector3 = Vector3.ZERO

# Значения плоскости по умолчанию
const DEFAULT_PLANE_SIZE: Vector2 = Vector2(50.0, 50.0)
const DEFAULT_PLANE_POSITION: Vector3 = Vector3.ZERO

func _ready() -> void:
	# Инициализация пула платформ
	_initialize_platform_pool()

func initialize_plane(plane: Node3D) -> void:
	# Инициализация размеров и позиции плоскости
	if not plane:
		_plane_size = DEFAULT_PLANE_SIZE
		_plane_position = DEFAULT_PLANE_POSITION
		push_warning("Плоскость не найдена, используются значения по умолчанию")
		return

	var collision_shape: CollisionShape3D = _find_collision_shape(plane)
	if collision_shape and collision_shape.shape is BoxShape3D:
		var extents: Vector3 = collision_shape.shape.extents
		var plane_scale: Vector3 = plane.scale
		_plane_size = Vector2(extents.x * 2 * plane_scale.x, extents.z * 2 * plane_scale.z)
		_plane_position = plane.global_position + Vector3(0, extents.y * plane_scale.y, 0)
	else:
		_plane_size = DEFAULT_PLANE_SIZE
		_plane_position = DEFAULT_PLANE_POSITION
		push_warning("Недопустимая форма коллизии плоскости, используются значения по умолчанию")

func spawn_base_grid(params: Dictionary) -> void:
	# Создание базовой сетки платформ
	var spacing: float = params.get("spacing", 6.0)
	var offset: float = params.get("offset", 2.0)
	var scale: Vector3 = params.get("scale", Vector3.ONE)

	var platforms_x: int = int(_plane_size.x / spacing)
	var platforms_z: int = int(_plane_size.y / spacing)
	var half_x: float = _plane_size.x / 2.0
	var half_z: float = _plane_size.y / 2.0

	for i in range(platforms_x):
		for j in range(platforms_z):
			var pos_x: float = _plane_position.x - half_x + (i + 0.5) * spacing + randf_range(-offset, offset)
			var pos_z: float = _plane_position.z - half_z + (j + 0.5) * spacing + randf_range(-offset, offset)
			var pos_y: float = _plane_position.y
			await _spawn_platform_with_delay(Vector3(pos_x, pos_y, pos_z), scale, 0.1)

func spawn_clustered_path(params: Dictionary) -> void:
	# Создание кластерного пути из платформ
	var layer_count: int = params.get("layer_count", 5)
	var cluster_size: int = params.get("cluster_size", 6)
	var horizontal_spacing: float = params.get("horizontal_spacing", 3.0)
	var vertical_spacing: float = params.get("vertical_spacing", 2.0)
	var chaos: float = params.get("chaos", 0.5)
	var difficulty: float = params.get("difficulty", 1.0)
	var scale: Vector3 = params.get("scale", Vector3(4.0, 0.5, 3.0))

	var last_cluster_center: Vector3 = _plane_position

	for layer in range(layer_count):
		var cluster_center: Vector3 = last_cluster_center + Vector3(
			randf_range(-horizontal_spacing, horizontal_spacing),
			vertical_spacing,
			randf_range(-horizontal_spacing, horizontal_spacing)
		)

		for i in range(cluster_size):
			var offset: Vector3 = Vector3(
				randf_range(-1.0, 1.0) * horizontal_spacing * (1.0 + chaos),
				0.0,
				randf_range(-1.0, 1.0) * horizontal_spacing * (1.0 + chaos)
			)
			var position: Vector3 = cluster_center + offset * difficulty
			await _spawn_platform_with_delay(position, scale, 0.1)

		last_cluster_center = cluster_center

func spawn_win_platform(callback: Callable) -> void:
	# Создание платформы победы
	var win_platform: Node = _win_platform_scene.instantiate()
	win_platform.position = _last_platform_position + Vector3(2.0, 1.0, 2.0)
	get_parent().add_child(win_platform)
	_active_platforms.append(win_platform)
	if win_platform.has_signal("platform_win"):
		win_platform.platform_win.connect(callback)

func _initialize_platform_pool() -> void:
	# Создание пула платформ для оптимизации
	for i in range(POOL_SIZE):
		var platform_instance: Node = _platform_scene.instantiate()
		platform_instance.visible = false
		add_child(platform_instance)
		_platform_pool.append(platform_instance)

func _find_collision_shape(plane: Node3D) -> CollisionShape3D:
	# Поиск компонента коллизии плоскости
	for child in plane.get_children():
		if child is CollisionShape3D:
			return child
	return null

func _spawn_platform(position: Vector3, scale: Vector3) -> Node:
	# Создание платформы из пула
	var platform_instance: Node = _get_platform_from_pool()
	platform_instance.position = position
	platform_instance.scale = scale
	platform_instance.visible = true
	get_parent().add_child(platform_instance)
	_active_platforms.append(platform_instance)
	_last_platform_position = position

	# Создание бонусов на платформе
	if randf() < 0.02: # 2% шанс появления бонуса прыжка
		_spawn_bonus(_jump_bonus_scene, position + Vector3(0, 1, 0))
	if randf() < 0.12: # 12% шанс появления монеты
		_spawn_bonus(_coin_scene, position + Vector3(0, 1, 0))

	return platform_instance

func _spawn_platform_with_delay(position: Vector3, scale: Vector3, delay: float) -> void:
	# Создание платформы с задержкой
	await get_tree().create_timer(delay).timeout
	_spawn_platform(position, scale)

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
