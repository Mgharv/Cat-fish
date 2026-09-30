extends Node3D
## One fish. Swims on its own using smooth noise ("wander") + steering.

signal swatted(fish)                    ## "I got hit!" -> the pond passes it up to the Game Manager

const FISH_LAYER := 2                   ## physics layer the fish hitboxes live on (pounces only look here)

# ---------- SPECIES (what the fish looks like) ----------
@export var species: FishSpecies        ## leave empty to keep the original triangle-fish look

# ---------- SETTINGS (appear in the Inspector) ----------
@export var cruise_speed := 0.35        ## metres per second
@export var speed_multiplier := 1.0     ## 0 = still fish (for controlled conditions)
@export var wander_rate := 0.3          ## how fast its "mood" changes
@export var wander_strength := 1.5      ## how much the noise bends its path
@export var vertical_freedom := 0.3     ## 0 = only swims level, 1 = up/down as freely as sideways
@export var steer_strength := 1.5       ## how quickly it turns toward what it wants
@export var turn_smoothing := 4.0       ## how quickly its body rotates to face its path
# ---------- POND EDGES (the pond fills these in when it spawns the fish) ----------
@export var pond_radius := 6.0          ## round pond: how far from the centre the fish may swim
@export var surface_y := -0.25          ## water surface
@export var bottom_y := -2.0            ## pond floor
@export var wall_margin := 0.5          ## starts turning away this far from an edge
@export var wall_strength := 3.0        ## how hard edges push back


var velocity := Vector3.ZERO
var noise := FastNoiseLite.new()
var t := 0.0


func _ready() -> void:
	if species:                   # build this fish's look from its species numbers
		$Body.visible = false
		add_child(FishBuilder.build(species))
	noise.seed = randi()          # every fish gets its own "personality"
	noise.frequency = 1.0
	# start swimming in a random level direction
	velocity = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * cruise_speed
	_add_hitbox()


# ---------- BEING SWATTED ----------

## Called by a pounce (VR) or a click (desktop) that hits this fish.
func on_swat(_hit_position: Vector3) -> void:
	swatted.emit(self)


## A wrong fish that got swatted darts away for a moment.
func startle() -> void:
	var away := Vector3(randf_range(-1, 1), -0.3, randf_range(-1, 1)).normalized()
	velocity = away * cruise_speed * 4.0


## An invisible box around the fish that pounces can hit. A bit bigger than the
## fish, so pointing at it doesn't need to be pixel-perfect.
func _add_hitbox() -> void:
	var size := Vector3(0.12, 0.12, 0.4)                # original triangle fish
	if species:
		var L := species.body_length
		size = Vector3(species.body_width * L * 1.6 + 0.06, species.body_height * L * 1.3 + 0.04, L * 1.1)
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	var area := Area3D.new()
	area.name = "Hitbox"
	area.collision_layer = FISH_LAYER
	area.collision_mask = 0
	area.monitoring = false
	area.add_child(col)
	add_child(area)

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
	# The pond is round: one circular wall, the surface and the floor.
	# The closer to an edge, the harder the push back toward the middle.
	var push := Vector3.ZERO
	var flat := Vector2(position.x, position.z)
	var outward := Vector3(flat.x, 0.0, flat.y).normalized()  # direction away from the centre
	push -= outward * _edge_push(pond_radius - flat.length())
	push.y += _edge_push(position.y - bottom_y) - _edge_push(surface_y - position.y)
	return push


## 0 when far from an edge; grows to 1 at the edge (and beyond, if past it).
func _edge_push(distance_to_edge: float) -> float:
	if distance_to_edge >= wall_margin:
		return 0.0
	return 1.0 - distance_to_edge / wall_margin


func _keep_inside() -> void:
	var flat := Vector2(position.x, position.z).limit_length(pond_radius)
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
