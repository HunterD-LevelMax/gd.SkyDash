extends Node

const SKIN_PATHS := {
	"skeleton": "res://assets/characters/skeleton/skeleton.tscn",
	"bear": "res://assets/characters/bear/player_bear.tscn",
	"man": "res://assets/characters/man/man.tscn"
}

const SAVE_PATH := "user://user_data.dat"
const DEFAULT_SKIN := "bear"

var current_skin: String = SKIN_PATHS[DEFAULT_SKIN]
var purchased_skins: Array = [SKIN_PATHS[DEFAULT_SKIN]]
var current_layer := 10
var current_score := 0
var level_score_1 := 0
var level_score_2 := 0
var all_coins := 0

func get_current_layer() -> int:
	return current_layer
	
func set_layer(new_layer: int) -> void:
	current_layer = new_layer
	save_data()
	
func save_data() -> void:
	var data := {
		"level_score_1": level_score_1,
		"level_score_2": level_score_2,
		"all_coins": all_coins,
		"current_skin": current_skin,
		"purchased_skins": purchased_skins
	}
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("Failed to open save file")
		return
	
	file.store_var(data)
	file.close()

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("Failed to open save file for reading")
		return
	
	var loaded_data = file.get_var()
	if not loaded_data:
		return
	
	level_score_1 = loaded_data.get("level_score_1", 0)
	level_score_2 = loaded_data.get("level_score_2", 0)
	all_coins = loaded_data.get("all_coins", 0)
	current_skin = loaded_data.get("current_skin", SKIN_PATHS[DEFAULT_SKIN])
	purchased_skins = loaded_data.get("purchased_skins", [SKIN_PATHS[DEFAULT_SKIN]])
	file.close()

func purchase_skin(skin_path: String, cost: int) -> bool:
	if skin_path in purchased_skins or all_coins < cost:
		return false
	
	all_coins -= cost
	purchased_skins.append(skin_path)
	save_data()
	return true

func is_skin_purchased(skin_path: String) -> bool:
	return skin_path in purchased_skins

func set_skin(new_skin: String) -> void:
	if new_skin in SKIN_PATHS.values():
		current_skin = new_skin
		save_data()

func load_level_score_1() -> int:
	load_data()
	return level_score_1

func load_level_score_2() -> int:
	load_data()
	return level_score_2

func load_coins() -> int:
	load_data()
	return all_coins

func check_new_record(score: int) -> bool:
	if score > level_score_1:
		level_score_1 = score
		save_data()
		return true
	return false
	
func check_new_record_level_2(score: int) -> bool:
	if score > level_score_2:
		level_score_2 = score
		save_data()
		return true
	return false

func reset_best_score() -> void:
	level_score_1 = 0
	level_score_2 = 0
	save_data()

func add_coins(coins: int) -> void:
	if coins <= 0:
		return
	
	all_coins += coins
	save_data()

func get_all_coins() -> int:
	return all_coins
