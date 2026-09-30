extends Node3D
## POUNCE: the cat's strike in VR. Put this on a controller (as a child of an
## XRController3D). Point the controller at a fish and pull the trigger.
## A thin aiming line shows where you're pointing.
## (In desktop mode, clicking does the same thing via DesktopFallback.)

signal pounced(hit_position: Vector3, fish)   ## fish is null on a miss

@export var reach := 5.0                ## metres the pounce can reach
@export var action := "trigger_click"   ## which controller button pounces
@export var cooldown := 0.4             ## seconds between pounces
@export var show_aim_line := true

var _controller: XRController3D
var _line: Node3D                      # holder of the aiming line (scaled to its length)
var _ready_at := 0.0


func _ready() -> void:
	_controller = get_parent() as XRController3D
	if _controller == null:
		push_error("Pounce|ERROR: put this node under an XRController3D")
		return
	_controller.button_pressed.connect(_on_button_pressed)
	_make_line()


func _on_button_pressed(button: String) -> void:
	if button != action:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < _ready_at:
		return
	_ready_at = now + cooldown
	_pounce()


func _physics_process(_delta: float) -> void:
	if _line == null:
		return
	# stretch the aiming line to whatever it's pointing at (or full reach)
	var hit := _cast()
	var length := reach
	if not hit.is_empty():
		length = global_position.distance_to(hit.position)
	_line.visible = show_aim_line and _controller.get_has_tracking_data()
	_line.scale = Vector3(1, 1, length)


func _pounce() -> void:
	var hit := _cast()
	if hit.is_empty():
		pounced.emit(Vector3.INF, null)
		return
	# walk up from the hitbox to the fish
	var node := hit.collider as Node
	while node != null and not node.has_method("on_swat"):
		node = node.get_parent()
	if node:
		node.on_swat(hit.position)
	_controller.trigger_haptic_pulse("haptic", 0.0, 0.6, 0.08, 0.0)
	pounced.emit(hit.position, node)


func _cast() -> Dictionary:
	var from := global_position
	var to := from - global_basis.z * reach
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 2   # only fish hitboxes (Fish.FISH_LAYER)
	return get_world_3d().direct_space_state.intersect_ray(query)


func _make_line() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.004, 0.004, 1.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.75, 0.3, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var beam := MeshInstance3D.new()
	beam.mesh = mesh
	beam.material_override = mat
	beam.position = Vector3(0, 0, -0.5)   # the 1 m box starts at the hand and points forward
	_line = Node3D.new()                  # scaling this stretches the beam to any length
	add_child(_line)
	_line.add_child(beam)
