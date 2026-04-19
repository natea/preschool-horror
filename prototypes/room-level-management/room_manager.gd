# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does boundary detection work reliably at doorways?
# Date: 2026-04-11
extends Node

## Emitted when the player fully enters a new room.
signal player_entered_room(room_id: StringName)
## Emitted when the player leaves a room.
signal player_exited_room(room_id: StringName)

var current_room: StringName = &""
var _pending_room: StringName = &""
var _rooms: Dictionary = {}  # room_id -> Area3D
var _room_colors: Dictionary = {}  # room_id -> Color (for debug)

# Traversal tracking
var _last_transition_time: float = 0.0
var _transition_start_time: float = 0.0
var last_traversal_time: float = 0.0
var transition_count: int = 0


func register_room(room_id: StringName, area: Area3D, debug_color: Color = Color.WHITE) -> void:
	_rooms[room_id] = area
	_room_colors[room_id] = debug_color
	area.body_entered.connect(_on_room_body_entered.bind(room_id))
	area.body_exited.connect(_on_room_body_exited.bind(room_id))


func get_current_room() -> StringName:
	return current_room


func get_room_color(room_id: StringName) -> Color:
	return _room_colors.get(room_id, Color.WHITE)


func initialize_current_room(player_body: CharacterBody3D) -> void:
	for room_id: StringName in _rooms:
		var area: Area3D = _rooms[room_id]
		if area.overlaps_body(player_body):
			current_room = room_id
			_pending_room = &""
			player_entered_room.emit(current_room)
			print("[RoomManager] Initialized current_room: ", current_room)
			return
	push_warning("[RoomManager] Player not inside any room at initialization!")


func _on_room_body_entered(body: Node3D, room_id: StringName) -> void:
	if not body is CharacterBody3D:
		return
	if current_room == &"":
		# First room entry
		current_room = room_id
		player_entered_room.emit(current_room)
		print("[RoomManager] First entry: ", current_room)
		return

	if room_id != current_room:
		# Player entered a new room — mark as pending until old room exits
		_pending_room = room_id
		_transition_start_time = Time.get_ticks_msec() / 1000.0


func _on_room_body_exited(body: Node3D, room_id: StringName) -> void:
	if not body is CharacterBody3D:
		return
	if room_id == current_room and _pending_room != &"":
		# Old room exited — commit the pending room
		_commit_room_change()


func _physics_process(_delta: float) -> void:
	# Fallback: if pending room exists but body_exited hasn't fired in 1 frame,
	# commit anyway (debounce safety valve from GDD)
	if _pending_room != &"" and _transition_start_time > 0.0:
		var elapsed := Time.get_ticks_msec() / 1000.0 - _transition_start_time
		if elapsed > 0.05:  # ~3 physics frames at 60fps
			_commit_room_change()


func _commit_room_change() -> void:
	var old_room := current_room
	current_room = _pending_room
	_pending_room = &""

	var now := Time.get_ticks_msec() / 1000.0
	if _last_transition_time > 0.0:
		last_traversal_time = now - _last_transition_time
	_last_transition_time = now
	transition_count += 1

	player_exited_room.emit(old_room)
	player_entered_room.emit(current_room)
	print("[RoomManager] Transition: ", old_room, " -> ", current_room,
		" (traversal: %.2fs)" % last_traversal_time)
