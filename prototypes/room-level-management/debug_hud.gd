# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does boundary detection work reliably at doorways?
# Date: 2026-04-11
extends CanvasLayer

@onready var label: Label = $Label
@onready var player: CharacterBody3D = get_tree().get_first_node_in_group("player")

var _time_in_room: float = 0.0


func _ready() -> void:
	RoomManager.player_entered_room.connect(_on_room_entered)


func _on_room_entered(_room_id: StringName) -> void:
	_time_in_room = 0.0


func _process(delta: float) -> void:
	_time_in_room += delta

	var room_id := RoomManager.get_current_room()
	var room_color := RoomManager.get_room_color(room_id)
	var pos := player.global_position if player else Vector3.ZERO

	var text := ""
	text += "=== ROOM LEVEL MANAGEMENT PROTOTYPE ===\n"
	text += "Current Room: %s\n" % room_id
	text += "Time in Room: %.1fs\n" % _time_in_room
	text += "Transitions: %d\n" % RoomManager.transition_count
	text += "Last Traversal: %.2fs\n" % RoomManager.last_traversal_time
	text += "Position: (%.1f, %.1f, %.1f)\n" % [pos.x, pos.y, pos.z]
	text += "Speed: %.1f m/s\n" % player.velocity.length() if player else ""
	text += "\n[WASD] Move  [Mouse] Look  [ESC] Cursor"

	label.text = text
	label.add_theme_color_override("font_color", room_color)
