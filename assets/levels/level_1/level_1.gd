extends Node3D

@export var menu_scene_path: String = "res://assets/menu/menu_scene.tscn"
@onready var player = $Player
@onready var score_label: Label = $UI/Control/CoinContainer/CoinsLabel
@onready var platform_generator: PlatformGenerator = PlatformGenerator.new()
@onready var win_dialog = preload("res://assets/ui/win_dialog.tscn")
@onready var menu_dialog = preload("res://assets/ui/menu_dialog.tscn")
@onready var plane = $island/Plane
@onready var spawn = $island/Spawn

var layer_count = Global.get_current_layer()
var menu_dialog_instance: CanvasLayer = null
var win_dialog_instance: CanvasLayer = null
var coin: int = 0
var fade_rect: ColorRect = null

func _ready() -> void:
	_initialize_scene()
	_load_data()
	_setup_platforms()
	_create_fade_rect()

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

func _initialize_scene() -> void:
	add_child(platform_generator)
	platform_generator.initialize_plane(plane)

func _load_data() -> void:
	var max_layer = Global.load_level_score_1()
	if max_layer != 0:
		layer_count = max_layer

func _setup_platforms() -> void:
	await platform_generator.spawn_clustered_path({
		"turns_count": layer_count,
		"platforms_per_turn": 9,
		"spiral_step": 1.0,
		"cluster_radius": 14.0,
		"vertical_step": 1.01,
		"difficulty": 1.03,
	})
	platform_generator.spawn_win_platform(_on_win_platform_activated)

func _on_platforms_spawned() -> void:
	platform_generator.spawn_win_platform(_on_win_platform_activated)

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
	if not menu_dialog_instance and not win_dialog_instance:
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
	if menu_dialog_instance || win_dialog_instance:
		return
	print("Открытие диалога меню")
	menu_dialog_instance = menu_dialog.instantiate()
	if not menu_dialog_instance:
		print("Ошибка: не удалось создать экземпляр menu_dialog")
		return
	add_child(menu_dialog_instance)
	menu_dialog_instance.open_dialog()
	menu_dialog_instance.menu_confirmed.connect(_on_menu_confirmed)
	menu_dialog_instance.restart_confirmed.connect(_restart_level)
	menu_dialog_instance.exit_menu_cancelled.connect(_on_exit_cancelled)

func _close_menu_dialog() -> void:
	if menu_dialog_instance:
		print("Закрытие диалога меню")
		menu_dialog_instance._on_cancel_pressed()
		menu_dialog_instance = null
	get_tree().paused = false
	get_viewport().set_input_as_handled()

func _show_win_dialog() -> void:
	if win_dialog_instance:
		return
	win_dialog_instance = win_dialog.instantiate()
	add_child(win_dialog_instance)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	win_dialog_instance.next_level_pressed.connect(_on_next_level_pressed)
	win_dialog_instance.menu_pressed.connect(_on_menu_pressed)
	win_dialog_instance.tree_exiting.connect(_on_win_dialog_closed)

func _on_win_dialog_closed() -> void:
	win_dialog_instance = null
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_coin_collected() -> void:
	coin += 1
	score_label.text = "🟡 %d" % coin
	Global.add_coins(coin)
	print("Монета собрана")

func _on_win_platform_activated() -> void:
	if win_dialog_instance:
		return
	print("Победа! Игрок достиг платформы победы.")
	layer_count += 2
	Global.set_layer(layer_count)
	Global.check_new_record(layer_count)
	player._dance_play()
	player.show_floating_text("Next level!")
	_show_win_dialog()

func _on_menu_confirmed() -> void:
	if menu_dialog_instance:
		var tween = create_tween()
		tween.tween_property(menu_dialog_instance.get_node("Control"), "modulate:a", 0.0, 0.3)
		tween.tween_property(fade_rect, "modulate:a", 1.0, 0.5)
		tween.tween_callback(menu_dialog_instance.queue_free)
		tween.tween_callback(_load_menu_scene)
		menu_dialog_instance = null

func _on_menu_pressed() -> void:
	if win_dialog_instance:
		var tween = create_tween()
		tween.tween_property(win_dialog_instance.get_node("Control"), "modulate:a", 0.0, 0.3)
		tween.tween_property(fade_rect, "modulate:a", 1.0, 0.5)
		tween.tween_callback(win_dialog_instance.queue_free)
		tween.tween_callback(_load_menu_scene)
		win_dialog_instance = null
	platform_generator.clear_platforms()

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

func _on_next_level_pressed() -> void:
	if win_dialog_instance:
		win_dialog_instance.queue_free()
		win_dialog_instance = null
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_restart_level()

func _restart_level() -> void:
	if win_dialog_instance:
		win_dialog_instance.queue_free()
		win_dialog_instance = null
	if menu_dialog_instance:
		menu_dialog_instance.queue_free()
		menu_dialog_instance = null
	platform_generator.clear_platforms()

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
		body.position = spawn.position + Vector3(0, 1.0, 0)
		body.show_floating_text("Oops!", 2.0)
