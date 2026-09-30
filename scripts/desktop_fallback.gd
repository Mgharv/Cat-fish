## DESKTOP FALLBACK #########################
# Lets you play the scene on a laptop when no VR headset is connected.
# main.gd adds this node automatically when OpenXR fails to start, so you
# don't need to put it in the scene yourself.
#
# Controls
#   Click          capture the mouse (first click), then swat
#   Mouse          look around
#   W A S D        move
#   E / Space      move up
#   Q / Shift      move down
#   Esc            release the mouse
#
# Swatting casts a ray from the centre of the screen. Anything it hits that
# has an `on_swat(hit_position)` method (on the collider or any parent) gets
# that method called, and the `swatted` signal fires either way. That lets
# the fish use the same hit logic in VR and on desktop.
#############################################

extends Node3D
class_name DesktopFallback

signal swatted(hit_position: Vector3, collider: Object)

@export var eye_height := 1.6 ## metres, roughly standing head height
@export var move_speed := 2.0 ## m/s
@export var mouse_sensitivity := 0.003
@export var swat_reach := 5.0 ## metres: how far a click-pounce reaches (match the VR pounce)
@export var swat_push := 2.0 ## impulse applied to rigid bodies you swat

var _origin: XROrigin3D = null
var _camera: Camera3D = null
var _yaw := 0.0
var _pitch := 0.0
var _swat_requested := false
var _ignore: Array[RID] = []


func _ready() -> void:
	_origin = get_parent().get_node_or_null("XROrigin3D") as XROrigin3D
	if _origin == null:
		push_error("DesktopFallback|FATAL: couldn't find an XROrigin3D next to this node")
		return

	# A plain camera at head height. The XRCamera3D is left alone so VR is untouched.
	_camera = Camera3D.new()
	_camera.name = "DesktopCamera"
	_camera.position = Vector3(0, eye_height, 0)
	_origin.add_child(_camera)
	_camera.make_current()

	# Don't let the swat ray hit our own hand/controller grab areas.
	for node in _origin.find_children("*", "CollisionObject3D", true, false):
		_ignore.append((node as CollisionObject3D).get_rid())

	_build_hud()
	print("DesktopFallback|INFO: no headset, desktop mode on. Click to look around, WASD to move, click again to swat.")


func _unhandled_input(event: InputEvent) -> void:
	if _camera == null:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			_swat_requested = true

	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, -1.5, 1.5)
		_camera.rotation = Vector3(_pitch, _yaw, 0.0)

	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	if _camera == null:
		return

	var input := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): input.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S): input.z += 1.0
	if Input.is_physical_key_pressed(KEY_A): input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): input.x += 1.0
	if Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_SPACE): input.y += 1.0
	if Input.is_physical_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_SHIFT): input.y -= 1.0

	if input == Vector3.ZERO:
		return

	# Move relative to where you're facing, but keep walking level.
	var move := Basis(Vector3.UP, _yaw) * Vector3(input.x, 0.0, input.z)
	move.y = input.y
	_origin.global_position += move.normalized() * move_speed * delta


func _physics_process(_delta: float) -> void:
	# Physics queries are only safe here, so clicks just set a flag.
	if not _swat_requested:
		return
	_swat_requested = false

	var from := _camera.global_position
	var to := from - _camera.global_basis.z * swat_reach
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.exclude = _ignore

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		print("DesktopFallback|INFO: swat missed")
		swatted.emit(Vector3.INF, null)
		return

	var pos: Vector3 = hit.position
	var collider: Object = hit.collider
	_flash_paw(pos)

	if collider is RigidBody3D:
		(collider as RigidBody3D).apply_impulse(-_camera.global_basis.z * swat_push, pos - collider.global_position)

	# Walk up from the collider to find something that knows how to be swatted.
	var node := collider as Node
	while node != null:
		if node.has_method("on_swat"):
			node.on_swat(pos)
			break
		node = node.get_parent()

	print("DesktopFallback|INFO: swat hit %s" % (collider as Node).name)
	swatted.emit(pos, collider)


## A small sphere that pops up where you swatted, then fades.
func _flash_paw(pos: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.6, 0.2, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var sphere := SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12

	var paw := MeshInstance3D.new()
	paw.mesh = sphere
	paw.material_override = mat
	get_tree().current_scene.add_child(paw)
	paw.global_position = pos

	var tween := paw.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tween.tween_callback(paw.queue_free)


## Crosshair + controls hint, drawn on top of the 3D view.
func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "DesktopHUD"
	add_child(hud)

	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 28)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.grow_horizontal = Control.GROW_DIRECTION_BOTH
	crosshair.grow_vertical = Control.GROW_DIRECTION_BOTH
	hud.add_child(crosshair)

	var hint := Label.new()
	hint.text = "DESKTOP MODE (no headset)\nClick: capture mouse / swat   Mouse: look   WASD: move   E/Q: up/down   Esc: free mouse"
	hint.position = Vector2(12, 8)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 4)
	hud.add_child(hint)
