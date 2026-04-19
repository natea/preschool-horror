# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does a 3-room preschool greybox feel right for first-person horror?
# Date: 2026-04-11
extends CharacterBody3D

const WALK_SPEED := 2.0  # m/s from GDD
const MOUSE_SENSITIVITY := 0.002
const GRAVITY := 9.8

@onready var camera: Camera3D = $Camera3D


var _frames_waited: int = 0
var _room_initialized: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clampf(camera.rotation.x, -PI / 2.0, PI / 2.0)

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	# Deferred room init — wait 2 physics frames for Area3D to settle
	if not _room_initialized:
		_frames_waited += 1
		if _frames_waited >= 2:
			RoomManager.initialize_current_room(self)
			_room_initialized = true

	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Movement
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * WALK_SPEED
		velocity.z = direction.z * WALK_SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
		velocity.z = move_toward(velocity.z, 0, WALK_SPEED)

	move_and_slide()
