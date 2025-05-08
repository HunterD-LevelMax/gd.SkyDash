extends Node3D

# Ноды сцены
@onready var player = $Player
@onready var score_label: Label = $UI/Control/CoinContainer/CoinsLabel
@onready var platform_generator: PlatformGenerator = $PlatformGenerator
@onready var plane = $Plane

func _ready() -> void:
	# Инициализация размеров плоскости для генерации платформ
	platform_generator.initialize_plane(plane)
	
	# Создание базовой сетки платформ
	await platform_generator.spawn_base_grid({
		"spacing": 8.0,
		"offset": 5.0,
		"scale": Vector3(1.2, 0.4, 1.9)
	})
	
	# Создание кластерного пути
	await platform_generator.spawn_clustered_path({
		"layer_count": 10,
		"cluster_size": 5,
		"horizontal_spacing": 5.0,
		"vertical_spacing": 1.9,
		"chaos": 0.6,
		"difficulty": 1.2,
		"scale": Vector3(1.0, 0.4, 1.5)
		
		# Vector3(1.2, 0.4, 1.9)
	})
	
	# Создание платформы победы
	platform_generator.spawn_win_platform(_on_win_platform_activated)

func _input(event: InputEvent) -> void:
	# Перезапуск уровня при нажатии клавиши рестарта
	if event.is_action_pressed("restart"):
		_restart_level()

func _on_coin_collected() -> void:
	# Увеличение счета игрока и обновление текста
	player.add_score()
	score_label.text = "Coins: %d" %  player._score
	print("Монета собрана")

func _on_win_platform_activated() -> void:
	# Отображение диалога победы
	print("Победа! Игрок достиг платформы победы.")
	
	player._dance_play()
	
	
	
#	var dialog := ConfirmationDialog.new()
	#dialog.title = "Win"
#	dialog.dialog_text = "Good job!"
#	add_child(dialog)
#	dialog.popup_centered()

func _on_teleport_body_entered(body: Node3D) -> void:
	# Телепортация игрока при входе в зону телепорта
	if body.name == "Player":
		_teleport_player()

func _on_teleport_zone_body_entered(body: Node3D) -> void:
	# Телепортация игрока при входе в зону телепорта
	if body.name == "Player":
		_teleport_player()

func _teleport_player() -> void:
	# Телепортация игрока в случайную точку спавна
	var spawn_points := [$Spawn1, $Spawn2, $Spawn3]
	if spawn_points.size() > 0:
		var random_spawn: Node3D = spawn_points[randi() % spawn_points.size()]
		player.global_transform.origin = random_spawn.global_transform.origin + Vector3(0, 0.5, 0)

func _restart_level() -> void:
	# Перезапуск текущей сцены
	get_tree().reload_current_scene()

func player_fell() -> void:
	# Перезапуск уровня при падении игрока
	_restart_level()
