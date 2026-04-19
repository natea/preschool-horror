# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does the photography loop feel satisfying and scary in first-person Godot 4.6?
# Date: 2026-04-10
extends CharacterBody3D

const SPEED_WALK := 2.0
const SPEED_RUN := 4.0
const SPEED_CAMERA_MODIFIER := 0.75
const MOUSE_SENS := 0.002
const CAMERA_RAISE_OFFSET := 0.08

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var viewfinder_ui: Control = $UI/Viewfinder
@onready var crosshair: Control = $UI/Crosshair
@onready var flash_rect: ColorRect = $UI/FlashRect
@onready var gallery_ui: Control = $UI/Gallery
@onready var gallery_grid: GridContainer = $UI/Gallery/Panel/GridContainer
@onready var photo_count_label: Label = $UI/PhotoCount
@onready var eval_label: Label = $UI/EvalLabel

var camera_raised := false
var is_running := false
var photos: Array[Image] = []
var gallery_open := false
var default_head_y: float
var flash_alpha := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	default_head_y = head.position.y
	flash_rect.color = Color(1, 1, 1, 0)
	viewfinder_ui.visible = false
	viewfinder_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_mouse_filter_recursive(viewfinder_ui, Control.MOUSE_FILTER_IGNORE)
	gallery_ui.visible = false
	eval_label.text = ""
	get_tree().root.focus_entered.connect(_on_window_focus)


func _on_window_focus() -> void:
	# Recapture mouse after fullscreen toggle or alt-tab
	if not gallery_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		if not gallery_open:
			# Small delay to let the window settle after fullscreen transition
			get_tree().create_timer(0.1).timeout.connect(func():
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			)


func _set_mouse_filter_recursive(node: Control, filter: Control.MouseFilter) -> void:
	node.mouse_filter = filter
	for child in node.get_children():
		if child is Control:
			_set_mouse_filter_recursive(child, filter)


func _input(event: InputEvent) -> void:
	# Mouse look — must be in _input so it's not blocked by UI
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		head.rotate_x(-event.relative.y * MOUSE_SENS)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	# Photo capture — must be in _input so viewfinder UI doesn't eat the click
	if event.is_action_pressed("take_photo") and camera_raised and not gallery_open:
		_take_photo()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("gallery_toggle"):
		_toggle_gallery()

	if event.is_action_pressed("interact"):
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif interact_ray.is_colliding():
			var collider := interact_ray.get_collider()
			if collider.has_method("interact"):
				collider.interact()

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if gallery_open:
			_toggle_gallery()
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta

	# Camera raise/lower
	is_running = Input.is_action_pressed("run") and not camera_raised
	camera_raised = Input.is_action_pressed("camera_raise") and not is_running and not gallery_open

	viewfinder_ui.visible = camera_raised
	crosshair.visible = not camera_raised and not gallery_open

	# Camera height offset
	var target_y := default_head_y + (CAMERA_RAISE_OFFSET if camera_raised else 0.0)
	head.position.y = lerpf(head.position.y, target_y, 10.0 * delta)

	# Movement
	if not gallery_open:
		var speed := SPEED_RUN if is_running else SPEED_WALK
		if camera_raised:
			speed *= SPEED_CAMERA_MODIFIER

		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)

		move_and_slide()

	# Flash fade
	if flash_alpha > 0.0:
		flash_alpha = maxf(0.0, flash_alpha - delta * 3.0)
		flash_rect.color = Color(1, 1, 1, flash_alpha)

	# Anomaly detection feedback
	if camera_raised:
		var eval_result := _evaluate_frame()
		if eval_result.anomaly_found:
			eval_label.text = "[ ANOMALY DETECTED — %.0f%% ]" % (eval_result.score * 100)
			eval_label.add_theme_color_override("font_color", Color.RED if eval_result.score > 0.7 else Color.YELLOW)
		else:
			eval_label.text = ""
	else:
		eval_label.text = ""


func _take_photo() -> void:
	# Flash effect
	flash_alpha = 1.0
	flash_rect.color = Color(1, 1, 1, 1)

	# Evaluate what's in frame
	var eval_result := _evaluate_frame()

	# Show result immediately
	if eval_result.anomaly_found:
		eval_label.text = "CAPTURED! Score: %.0f%%" % (eval_result.score * 100)
		eval_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		eval_label.text = "Nothing unusual..."
		eval_label.add_theme_color_override("font_color", Color.WHITE)

	# Capture viewport image on next frame (deferred to avoid blocking input)
	_capture_deferred()

	# Clear eval text after 2 seconds
	get_tree().create_timer(2.0).timeout.connect(func(): eval_label.text = "")


func _capture_deferred() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	photos.append(image)
	photo_count_label.text = "Photos: %d" % photos.size()


func _evaluate_frame() -> Dictionary:
	# Find all anomalies in the scene
	var anomalies := get_tree().get_nodes_in_group("anomaly")
	var best_score := 0.0
	var found := false

	for anomaly in anomalies:
		if not anomaly is Node3D:
			continue

		var anomaly_pos: Vector3 = anomaly.global_position
		var cam_pos := camera.global_position
		var cam_forward := -camera.global_basis.z
		var to_anomaly := (anomaly_pos - cam_pos).normalized()
		var distance := cam_pos.distance_to(anomaly_pos)

		# Check if anomaly is in front of camera
		var dot := cam_forward.dot(to_anomaly)
		if dot < 0.3:  # Must be roughly in front
			continue

		# Check if in camera frustum (not behind + within viewport bounds)
		if camera.is_position_behind(anomaly_pos):
			continue
		var screen_pos := camera.unproject_position(anomaly_pos)
		var vp_size := get_viewport().get_visible_rect().size
		if screen_pos.x < 0 or screen_pos.x > vp_size.x or screen_pos.y < 0 or screen_pos.y > vp_size.y:
			continue

		# Check line of sight (not occluded)
		var space_state := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(cam_pos, anomaly_pos)
		query.exclude = [self.get_rid()]
		var result := space_state.intersect_ray(query)
		if result and result.collider != anomaly:
			continue  # Something blocking the view

		# Score based on angle (centered = better) and distance (closer = better)
		var angle_score := clampf((dot - 0.3) / 0.7, 0.0, 1.0)  # 0.3-1.0 mapped to 0-1
		var distance_score := clampf(1.0 - (distance / 10.0), 0.0, 1.0)  # 0-10m mapped to 1-0
		var score := angle_score * 0.6 + distance_score * 0.4

		if score > best_score:
			best_score = score
			found = true

	return {"anomaly_found": found, "score": best_score}


func _toggle_gallery() -> void:
	gallery_open = not gallery_open
	gallery_ui.visible = gallery_open

	if gallery_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_populate_gallery()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Clear existing children
	if not gallery_open:
		for child in gallery_grid.get_children():
			child.queue_free()


func _populate_gallery() -> void:
	for child in gallery_grid.get_children():
		child.queue_free()

	for i in range(photos.size()):
		var tex := ImageTexture.create_from_image(photos[i])
		var rect := TextureRect.new()
		rect.texture = tex
		rect.custom_minimum_size = Vector2(200, 150)
		rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		gallery_grid.add_child(rect)
