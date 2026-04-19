# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does boundary detection work reliably at doorways?
# Date: 2026-04-11
extends Node3D

## Registers all room Area3D nodes with the RoomManager autoload.
## Each room node must have a child named "RoomArea" (Area3D).


# Room definitions: id, node name, debug color
const ROOMS := [
	{id = &"entry_hall", node = "EntryHall", color = Color.CORNFLOWER_BLUE},
	{id = &"main_classroom", node = "MainClassroom", color = Color.SANDY_BROWN},
	{id = &"art_corner", node = "ArtCorner", color = Color.MEDIUM_PURPLE},
]


func _ready() -> void:
	# Register all rooms with the manager
	for room_def: Dictionary in ROOMS:
		var room_node := get_node(NodePath(room_def.node))
		var area: Area3D = room_node.get_node("RoomArea")
		RoomManager.register_room(room_def.id, area, room_def.color)
		print("[Preschool] Registered room: ", room_def.id)

	# Color-code the floors for visual feedback
	_apply_floor_colors()


func _apply_floor_colors() -> void:
	for room_def: Dictionary in ROOMS:
		var room_node := get_node(NodePath(room_def.node))
		var floor_node: CSGBox3D = room_node.get_node("Floor")
		var mat := StandardMaterial3D.new()
		mat.albedo_color = room_def.color.darkened(0.6)
		floor_node.material_override = mat

	# Enable collision on all CSG boxes (walls, floors, ceilings)
	_enable_csg_collisions()

	# Color walls a neutral grey
	_apply_wall_colors()


func _enable_csg_collisions() -> void:
	for room_def: Dictionary in ROOMS:
		var room_node := get_node(NodePath(room_def.node))
		for child: Node in room_node.get_children():
			if child is CSGBox3D and child.name != "RoomArea":
				child.use_collision = true
				child.collision_layer = 1  # World layer
				child.collision_mask = 0


func _apply_wall_colors() -> void:
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.85, 0.82, 0.78)  # Warm off-white

	for room_def: Dictionary in ROOMS:
		var room_node := get_node(NodePath(room_def.node))
		for child: Node in room_node.get_children():
			if child is CSGBox3D and child.name.begins_with("Wall"):
				child.material_override = wall_mat
