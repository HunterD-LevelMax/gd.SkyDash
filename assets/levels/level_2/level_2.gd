extends Node3D

@onready var player = $Player
@onready var island_generator = $islandGenerator
@onready var coin_label: Label = $UI/Control/CoinContainer/CoinsLabel
@onready var reset_area = $ResetArea
@onready var clouds = $Cloud

@export var menu_scene_path: String = "res://assets/menu/menu_scene.tscn"
@export var win_dialog: PackedScene = preload("res://assets/ui/win_dialog.tscn")
@export var menu_dialog: PackedScene = preload("res://assets/levels/level_2/menu_2.tscn")
@export var island_scene: PackedScene = preload("res://assets/levels/level_2/island_generator.tscn")

@export var islands_to_spawn_ahead: int = 10
@export var islands_to_keep_ahead: int = 5
@export var min_island_spacing: float = 26.0
@export var max_island_spacing: float = 34.0
@export var difficulty_start_distance: float = 0.0
@export var difficulty_max_distance: float = 1200.0

var score = 0
var coin: int = 0
var menu_dialog_instance: CanvasLayer = null
var fade_rect: ColorRect = null
var spawned_islands = []
var last_island_position = Vector3.ZERO
var total_distance_traveled: float = 0.0

func _ready() -> void:
	_load_data()
	_create_fade_rect()
	# Инициализация игрока и генератора
	player.is_auto_running = true
	player.auto_run_speed = island_generator.min_player_speed
	player.show_floating_text("Let's go!", 2.0)
	island_generator.connect("add_coin", _on_coin_collected)
	
	for i in range(islands_to_spawn_ahead):
		spawn_island()

func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(island_generator):
		return
	
	if reset_area and player:
		var new_pos = reset_area.global_position
		new_pos.z = player.global_position.z
		reset_area.global_position = new_pos
	  
	if clouds and player:
		var clouds_pos = clouds.global_position
		clouds_pos.z = player.global_position.z
		clouds.global_position = clouds_pos
		
	total_distance_traveled += abs(player.velocity.z) * delta
	
	# Прогресс сложности
	var difficulty_progress = clamp(
		(total_distance_traveled - difficulty_start_distance) / 
		(difficulty_max_distance - difficulty_start_distance), 
		0.0, 1.0
	)
	
	# Обновляем скорость игрока
	player.auto_run_speed = lerp(island_generator.min_player_speed, island_generator.max_player_speed, difficulty_progress)
	
	# Обновляем расстояние между островами
	var current_spacing = lerp(min_island_spacing, max_island_spacing, difficulty_progress)
	
	# Управление островами
	manage_islands(current_spacing)

func spawn_island(spacing: float = min_island_spacing):
	var new_island = island_scene.instantiate()
	new_island.connect("add_coin", _on_coin_collected)
	add_child(new_island)
	new_island.global_position = last_island_position
	last_island_position.z += spacing
	spawned_islands.append(new_island)

func manage_islands(spacing: float):
	if spawned_islands.size() > 0:
		var first_island = spawned_islands[0]
		if player.global_position.z - first_island.global_position.z > spacing * islands_to_keep_ahead:
			first_island.queue_free()
			spawned_islands.remove_at(0)
			spawn_island(spacing)

func _on_coin_collected() -> void:
	coin += 1
	score += 10
	coin_label.text = "🟡: %d" % coin
	Global.add_coins(1)
	print("🟡: %d" % coin)
	
	if score > Global.load_level_score_2():
		Global.check_new_record_level_2(score)

func _create_fade_rect() -> void:
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.modulate.a = 0.0
	fade_rect.size = get_viewport().size
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	canvas_layer.add_child(fade_rect)
	add_child(canvas_layer)

func _load_data() -> void:
	var max_score = Global.load_level_score_2()
	if max_score != 0:
		score = max_score

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		_restart_level()
	if event.is_action_pressed("ui_cancel"):
		_toggle_menu_dialog()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		print("Получен запрос на выход (кнопка Назад)")
		_handle_back_button()
		get_viewport().set_input_as_handled()

func _handle_back_button() -> void:
	print("Обработка кнопки Назад")
	if not menu_dialog_instance:
		_show_menu_dialog()
	else:
		print("Диалог уже активен, пропускаем")

func _toggle_menu_dialog() -> void:
	if menu_dialog_instance:
		_close_menu_dialog()
	else:
		_show_menu_dialog()
	get_viewport().set_input_as_handled()

func _show_menu_dialog() -> void:
	if menu_dialog_instance:
		return
	menu_dialog_instance = menu_dialog.instantiate()
	if not menu_dialog_instance:
		return
	add_child(menu_dialog_instance)
	menu_dialog_instance.open_dialog()
	menu_dialog_instance.menu_confirmed.connect(_on_menu_confirmed)
	menu_dialog_instance.restart_confirmed.connect(_restart_level)
	menu_dialog_instance.exit_menu_cancelled.connect(_on_exit_cancelled)

func _close_menu_dialog() -> void:
	if menu_dialog_instance:
		menu_dialog_instance._on_cancel_pressed()
		menu_dialog_instance = null
	get_tree().paused = false
	get_viewport().set_input_as_handled()

func _on_menu_confirmed() -> void:
	if menu_dialog_instance:
		var tween = create_tween()
		tween.tween_property(menu_dialog_instance.get_node("Control"), "modulate:a", 0.0, 0.3)
		tween.tween_property(fade_rect, "modulate:a", 1.0, 0.5)
		tween.tween_callback(menu_dialog_instance.queue_free)
		tween.tween_callback(_load_menu_scene)
		menu_dialog_instance = null

func _load_menu_scene() -> void:
	var tree = get_tree()
	if tree:
		tree.call_deferred("change_scene_to_file", menu_scene_path)
	else:
		push_error("Дерево сцены null в _load_menu_scene")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_exit_cancelled() -> void:
	if menu_dialog_instance:
		menu_dialog_instance.queue_free()
		menu_dialog_instance = null
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_viewport().set_input_as_handled()

func _restart_level() -> void:
	if menu_dialog_instance:
		menu_dialog_instance.queue_free()
		menu_dialog_instance = null

	var tree = get_tree()
	if tree and tree.current_scene and tree.current_scene.scene_file_path:
		var current_scene_path = tree.current_scene.scene_file_path
		tree.call_deferred("change_scene_to_file", current_scene_path)
	else:
		push_error("Не удалось перезагрузить сцену: current_scene или путь отсутствует")
		if get_scene_file_path():
			tree.call_deferred("change_scene_to_file", get_scene_file_path())
		else:
			push_error("Не удалось определить путь к текущей сцене")

func _on_area_3d_body_entered() -> void:
	_restart_level()

func _on_reset_area_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		_restart_level()
