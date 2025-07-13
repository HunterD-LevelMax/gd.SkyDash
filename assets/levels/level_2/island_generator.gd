extends Node3D

signal add_coin

@onready var spawn_obstacles = $SpawnObstacles
@onready var spawn_bonus = $SpawnBonus
@export var obstacle_1: PackedScene = preload("res://assets/levels/level_2/obstacle_1.tscn")
@export var obstacle_2: PackedScene = preload("res://assets/levels/level_2/obstacle_2.tscn")
@export var obstacle_3: PackedScene = preload("res://assets/levels/level_2/obstacle_3.tscn")
@export var obstacle_4: PackedScene = preload("res://assets/levels/level_2/obstacle_4.tscn")

@export var bonus: PackedScene = preload("res://assets/items/jump_bonus/Jump_bonus.tscn")
@export var coin: PackedScene = preload("res://assets/items/coin/coin.tscn")

@export var min_player_speed: float = 7.0
@export var max_player_speed: float = 14.0

func _ready() -> void:
	spawn_random_obstacle()
	spawn_random_bonus()
	
func spawn_random_obstacle() -> Node3D:
	var available_obstacles = [obstacle_1, obstacle_2, obstacle_3, obstacle_4]
	var weights = [0.4, 0.3, 0.2, 0.1]

	var random_value = randf()
	var selected_index = 0
	var cumulative_weight = weights[0]

	while random_value > cumulative_weight and selected_index < weights.size() - 1:
		selected_index += 1
		cumulative_weight += weights[selected_index]

	var new_obstacle = available_obstacles[selected_index].instantiate()
	new_obstacle.position.x = randf_range(-0.8, 0.6)
	new_obstacle.position.z = randf_range(-1.2, 1.0)

	spawn_obstacles.add_child(new_obstacle)
	return new_obstacle

func spawn_random_bonus() -> Node3D:
	var available_bonus = [bonus, coin]
	var weights = [0.2, 0.8]

	var random_value = randf()
	var selected_index = 0
	var cumulative_weight = weights[0]

	while random_value > cumulative_weight and selected_index < weights.size() - 1:
		selected_index += 1
		cumulative_weight += weights[selected_index]

	var new_bonus = available_bonus[selected_index].instantiate()
	spawn_bonus.add_child(new_bonus)
	
	if available_bonus[selected_index] == coin:
		new_bonus.connect("add_coin", _on_coin_collected_via_generator)
	
	return new_bonus

func _on_coin_collected_via_generator():
	emit_signal("add_coin")
