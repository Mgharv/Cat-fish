extends Node3D
## One fish. Swims on its own using smooth noise ("wander") + steering.

# ---------- SETTINGS (appear in the Inspector) ----------
@export var cruise_speed := 0.35        ## metres per second
@export var speed_multiplier := 1.0     ## 0 = still fish (for controlled conditions)
@export var wander_rate := 0.3          ## how fast its "mood" changes
@export var wander_strength := 1.5      ## how much the noise bends its path
@export var vertical_freedom := 0.3     ## 0 = only swims level, 1 = up/down as freely as sideways
@export var steer_strength := 1.5       ## how quickly it turns toward what it wants
@export var turn_smoothing := 4.0       ## how quickly its body rotates to face its path
# ---------- POND EDGES (the pond fills these in when it spawns the fish) ----------
@export var inner_radius := 0.6         ## pedestal edge
@export var outer_radius := 3.0         ## outer pond wall
@export var surface_y := 0.7            ## water surface
@export var bottom_y := -1.0            ## pond floor
@export var wall_margin := 0.5          ## starts turning away this far from an edge
@export var wall_strength := 3.0        ## how hard edges push back


var velocity := Vector3.ZERO
var noise := FastNoiseLite.new()
var t := 0.0


func _ready() -> void:
	noise.seed = randi()          # every fish gets its own "personality"
	noise.frequency = 1.0
	# start swimming in a random level direction
	velocity = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * cruise_speed

func _physics_process(delta: float) -> void:
	t += delta * wander_rate

	# 1. WANDER: keep going roughly forward, bent by smooth noise
	var wish := velocity.normalized()
	wish += Vector3(
		noise.get_noise_2d(t, 0.0),
		noise.get_noise_2d(t, 100.0) * vertical_freedom,
		noise.get_noise_2d(t, 200.0)
	) * wander_strength

	# 2. WALLS: push back toward the middle when close to an edge
	wish += _push_from_walls() * wall_strength

	# 3. STEER: ease the velocity toward what it wants (no snapping)
	var desired := wish.normalized() * cruise_speed * speed_multiplier
	velocity = velocity.lerp(desired, clampf(steer_strength * delta, 0.0, 1.0))
	position += velocity * delta
	_keep_inside()  # safety net

	# 4. FACE the way it's swimming
	_face_direction(delta)
	
	
func _push_from_walls() -> Vector3:
	var push := Vector3.ZERO
	# sideways: how far am I from the pond's centre?
	var flat := Vector2(position.x, position.z)
	var r := flat.length()
	var outward := Vector3(flat.x, 0.0, flat.y).normalized()  # direction away from the centre
	if r - inner_radius < wall_margin:      # too close to the pedestal -> push outward
		push += outward * (1.0 - (r - inner_radius) / wall_margin)
	if outer_radius - r < wall_margin:      # too close to the outer wall -> push inward
		push -= outward * (1.0 - (outer_radius - r) / wall_margin)
	# up/down: surface and floor
	if surface_y - position.y < wall_margin:
		push.y -= 1.0 - (surface_y - position.y) / wall_margin
	if position.y - bottom_y < wall_margin:
		push.y += 1.0 - (position.y - bottom_y) / wall_margin
	return push




func _keep_inside() -> void:
	var flat := Vector2(position.x, position.z)
	var r := clampf(flat.length(), inner_radius, outer_radius)
	flat = flat.normalized() * r
	position.x = flat.x
	position.z = flat.y
	position.y = clampf(position.y, bottom_y, surface_y)
func _face_direction(delta: float) -> void:
	if velocity.length() < 0.02:
		return
	var dir := velocity.normalized()
	if absf(dir.y) > 0.98:
		return  # pointing straight up/down confuses "look at"
	var target := Quaternion(Basis.looking_at(dir, Vector3.UP))
	quaternion = quaternion.slerp(target, clampf(turn_smoothing * delta, 0.0, 1.0))
