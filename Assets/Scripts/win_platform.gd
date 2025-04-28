extends StaticBody3D

signal platform_win

func _ready():
	var mesh = $MeshInstance3D
	# Делаем уникальный материал для каждого box
	if mesh.material_override:
		mesh.material_override = mesh.material_override.duplicate()
	else:
		mesh.set_surface_override_material(0, mesh.get_active_material(0).duplicate())

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		emit_signal("platform_win") 
	# Сигнал о победе
