extends Node3D

@export var level_scene_path: String = "res://Assets/Levels/level.tscn"  # Путь к сцене уровня

func _ready():
	print("Start scene loaded. Level path: ", level_scene_path)
	if not ResourceLoader.exists(level_scene_path):
		push_warning("Level scene not found at path: ", level_scene_path)
		
func _on_start_area_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		# Эффект затемнения перед загрузкой
		var fade = ColorRect.new()
		fade.color = Color(0, 0, 0, 0)
		fade.size = get_viewport().size
		add_child(fade)
		
		var tween = create_tween()
		tween.tween_property(fade, "color", Color.BLACK, 0.5)
		tween.tween_callback(func(): 
			var level_scene = load(level_scene_path)
			get_tree().change_scene_to_packed(level_scene)
		)

func _on_exit_area_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		show_exit_confirmation()

func show_exit_confirmation():
	var dialog = ConfirmationDialog.new()
	dialog.title = "Выход"
	dialog.dialog_text = "Вы уверены, что хотите выйти?"
	dialog.confirmed.connect(get_tree().quit)
	add_child(dialog)
	dialog.popup_centered()
