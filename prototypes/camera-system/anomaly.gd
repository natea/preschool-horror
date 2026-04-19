# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does the photography loop feel satisfying and scary in first-person Godot 4.6?
# Date: 2026-04-10
extends StaticBody3D

## Type of anomaly for visual variation
@export_enum("rotated", "floating", "wrong_color", "moved") var anomaly_type := "rotated"

var _original_transform: Transform3D


func _ready() -> void:
	add_to_group("anomaly")
	_original_transform = transform
	_apply_anomaly()


func _apply_anomaly() -> void:
	match anomaly_type:
		"rotated":
			rotate_z(deg_to_rad(15))
			rotate_x(deg_to_rad(-10))
		"floating":
			position.y += 0.3
		"wrong_color":
			var mesh := _find_mesh()
			if mesh:
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.6, 0.1, 0.1)  # Sickly red
				mesh.material_override = mat
		"moved":
			position += Vector3(0.5, 0, 0.3)


func _find_mesh() -> MeshInstance3D:
	for child in get_children():
		if child is MeshInstance3D:
			return child
	return null


func interact() -> void:
	# Visual feedback when interacted with directly
	var mesh := _find_mesh()
	if mesh:
		var tween := create_tween()
		tween.tween_property(mesh, "scale", Vector3(1.1, 1.1, 1.1), 0.1)
		tween.tween_property(mesh, "scale", Vector3.ONE, 0.1)
