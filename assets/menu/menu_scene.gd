extends Node3D

const LEVEL_PATHS := {
	"level_1": "res://assets/levels/level_1/level_1.tscn",
	"level_2": "res://assets/levels/level_2/level_2.tscn"
}

@onready var exit_dialog := preload("res://assets/ui/exit_dialog.tscn")
@onready var record_text := $Teleport_Level_1/Record_Label_1
@onready var record_text_2 := $Teleport_Level_2/Record_Label_2
@onready var coins_text := $Coins_Label
@onready var player := $Player

var is_player_in_exit_area: bool = false
var dialog_instance: CanvasLayer = null

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_load_data()
	player.change_skin(Global.current_skin)
	
func _initialize_scene() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if not ResourceLoader.exists(LEVEL_PATHS.level_1):
		push_warning("Level scene not found at path: ", LEVEL_PATHS.level_1)
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		_reset_player_position()
		
	if event is InputEventKey and event.keycode == KEY_BACK and event.pressed:
		print("Back key pressed")
		
func _load_data() -> void:
	_update_record_text(Global.load_level_score_1(), record_text)
	_update_record_text(Global.load_level_score_2(), record_text_2)
	_update_coins_text(Global.load_coins())

func _update_record_text(record: int, label: Label3D) -> void:
	label.text = "🌟 RECORD NOT SET YET 🌟" if record == 0 else "🌟 MY RECORD: %d 🌟" % record

func _update_coins_text(coins: int) -> void:
	coins_text.text = "Gold Collected: %d 🟡" % coins if coins is int else "Need to collect coins"

func _load_level(level: String) -> void:
	var fade: ColorRect = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.size = get_viewport().get_visible_rect().size
	add_child(fade)
	
	var tween: Tween = create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.5)
	tween.tween_callback(func():
		var level_scene: PackedScene = load(level) as PackedScene
		if level_scene:
			get_tree().change_scene_to_packed(level_scene)
		else:
			push_error("Failed to load level scene")
			fade.queue_free())

func _reset_player_position() -> void:
	player.position = $Spawn.position + Vector3(0, 1.0, 0)
	player.show_floating_text("Oops!", 2.0)

func _show_exit_dialog() -> void:
	if dialog_instance:
		return
	dialog_instance = exit_dialog.instantiate()
	add_child(dialog_instance)
	dialog_instance.open_dialog()
	dialog_instance.exit_confirmed.connect(_on_exit_confirmed)
	dialog_instance.exit_cancelled.connect(_on_exit_cancelled)

func _on_start_area_3d_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		_load_level(LEVEL_PATHS.level_1)
		
func _on_start_area_3d_level_2_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		_load_level(LEVEL_PATHS.level_2)

func _on_exit_area_3d_body_entered(body: Node3D) -> void:
	if body.name == "Player" and not is_player_in_exit_area:
		is_player_in_exit_area = true
		_show_exit_dialog()

func _on_exit_area_3d_body_exited(body: Node3D) -> void:
	if body.name == "Player":
		is_player_in_exit_area = false
		if dialog_instance:
			dialog_instance._on_cancel_pressed()
			dialog_instance = null

func _on_exit_confirmed() -> void:
	get_tree().quit()

func _on_exit_cancelled() -> void:
	is_player_in_exit_area = false
	if dialog_instance:
		dialog_instance.queue_free()
		dialog_instance = null
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _handle_skin_purchase(body: Node3D, skin_path: String, skin_name: String, cost: int) -> void:
	if body.name != "Player":
		return
	
	if Global.current_skin == skin_path:
		player.show_floating_text(skin_name + " already selected!", 2.0)
		return
	
	if Global.is_skin_purchased(skin_path):
		# Skin already purchased - just switch
		player.change_skin(skin_path)
		player.show_floating_text(skin_name + " selected!", 2.0)
	elif Global.get_all_coins() >= cost:
		# Try to purchase skin
		if Global.purchase_skin(skin_path, cost):
			player.change_skin(skin_path)
			player.show_floating_text(skin_name + " purchased!", 2.0)
			_load_data()  # Refresh UI
		else:
			player.show_floating_text("Purchase error", 2.0)
	else:
		player.show_floating_text("Not enough gold", 2.0)
		
func _on_area_skelet_body_entered(body: Node3D) -> void:
	_handle_skin_purchase(body, Global.SKIN_PATHS.skeleton, "Skeleton", 700)

func _on_area_man_body_entered(body: Node3D) -> void:
	_handle_skin_purchase(body, Global.SKIN_PATHS.man, "Guy", 400)

func _on_area_bear_body_entered(body: Node3D) -> void:
	_handle_skin_purchase(body, Global.SKIN_PATHS.bear, "Bear", 0)

func _on_reset_area_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		body.position = $Spawn.position + Vector3(0, 1.0, 0)
		body.show_floating_text("Oops!", 2.0)
