extends Node
## Keeps the player on the ring bridge. Works with any way of moving:
## the thumbstick (VR), WASD (desktop mode), or physically walking around the room.
## Add this node to the game scene and point it at the player (XROrigin3D) and the pond.

@export var player: XROrigin3D          ## the XROrigin3D (the player)
@export var pond: Node3D                ## the pond (it knows where the bridge is)
@export var start_angle_degrees := 0.0  ## where around the ring the player starts


func _ready() -> void:
	if player and pond:
		var a := deg_to_rad(start_angle_degrees)
		player.global_position = pond.to_global(Vector3(cos(a), 0.0, sin(a)) * pond.bridge_radius)


func _physics_process(_delta: float) -> void:
	if player == null or pond == null:
		return
	var head := _head()
	if head == null:
		return
	var limits: Vector2 = pond.bridge_limits()   # x = inner edge, y = outer edge (distance from centre)
	# Where the head is, relative to the pond centre (looking down from above)
	var h := pond.to_local(head.global_position)
	var flat := Vector2(h.x, h.z)
	if flat.length() < 0.001:
		flat = Vector2(1, 0)
	var on_ring := flat.normalized() * clampf(flat.length(), limits.x, limits.y)
	var clamped := Vector3(on_ring.x, h.y, on_ring.y)
	# Move the whole player by however far the head has strayed off the bridge
	player.global_position += pond.to_global(clamped) - pond.to_global(h)
	# Stand on the deck: the player's floor is the bridge (y = 0)
	player.global_position.y = pond.global_position.y


## The active camera (VR headset camera or the desktop camera).
func _head() -> Node3D:
	var cam := player.get_viewport().get_camera_3d()
	if cam != null and player.is_ancestor_of(cam):
		return cam
	return null
