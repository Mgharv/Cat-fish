@tool
extends Node3D
## THE POND: a ring of water around the cat's pedestal.
## It builds its own water, pedestal, floor and rim from the numbers below,
## and spawns the fish when the game starts.
## Change any number in the Inspector and the pond reshapes itself (even in the editor).

# ---------- FISH ----------
@export var fish_scene: PackedScene     ## the fish template (fish.tscn)
@export var fish_count := 8             ## how many fish to spawn

# ---------- SIZE (metres) ----------
@export var inner_radius := 0.6:        ## pedestal, where the player stands
	set(value):
		inner_radius = value
		_build_pond()
@export var outer_radius := 3.0:        ## outer wall of the pond
	set(value):
		outer_radius = value
		_build_pond()
@export var surface_y := 0.7:           ## water surface height: keep within paw reach
	set(value):
		surface_y = value
		_build_pond()
@export var bottom_y := -1.0:           ## pond floor (can sit below the real floor)
	set(value):
		bottom_y = value
		_build_pond()

# ---------- LOOK ----------
@export var water_color := Color(0.2, 0.55, 0.85, 0.25):  ## last number = see-through-ness
	set(value):
		water_color = value
		_build_pond()
@export var pedestal_color := Color(0.55, 0.45, 0.35)
@export var floor_color := Color(0.35, 0.30, 0.20)

var fishes: Node3D   # container the spawned fish go into


func _ready() -> void:
	_build_pond()
	if Engine.is_editor_hint():
		return  # in the editor: just show the pond, don't spawn fish
	for i in fish_count:
		spawn_fish()


# ---------- SPAWNING ----------

func spawn_fish() -> Node3D:
	var fish := fish_scene.instantiate()
	# tell the fish where the pond's edges are, before it starts swimming
	fish.inner_radius = inner_radius
	fish.outer_radius = outer_radius
	fish.surface_y = surface_y
	fish.bottom_y = bottom_y
	fish.position = random_point_in_pond()
	fishes.add_child(fish)
	return fish


func random_point_in_pond() -> Vector3:
	var angle := randf() * TAU                                    # anywhere around the circle
	var r := randf_range(inner_radius + 0.3, outer_radius - 0.3)  # not touching a wall
	var y := randf_range(bottom_y + 0.3, surface_y - 0.3)         # not touching surface/floor
	return Vector3(cos(angle) * r, y, sin(angle) * r)


# ---------- BUILDING THE POND'S LOOK ----------
# (Made in code so the shapes always match the numbers above.)

func _build_pond() -> void:
	if not is_inside_tree():
		return
	# throw away the old pieces, then make fresh ones
	for child in get_children():
		if child.name != "Fishes":
			child.free()
	if fishes == null:
		fishes = get_node_or_null("Fishes")
	if fishes == null:
		fishes = Node3D.new()
		fishes.name = "Fishes"
		add_child(fishes)

	var depth := surface_y - bottom_y

	# Water surface: a doughnut (torus) squashed flat into a ring
	var water_mesh := TorusMesh.new()
	water_mesh.inner_radius = inner_radius
	water_mesh.outer_radius = outer_radius
	water_mesh.rings = 64
	_add_piece("Water", water_mesh, _see_through(water_color),
		Vector3(0, surface_y, 0), Vector3(1, 0.02, 1))

	# Pedestal: a column from the pond floor up to the real floor (y = 0), where you stand
	var pedestal_mesh := CylinderMesh.new()
	pedestal_mesh.top_radius = inner_radius
	pedestal_mesh.bottom_radius = inner_radius
	pedestal_mesh.height = -bottom_y
	_add_piece("Pedestal", pedestal_mesh, _solid(pedestal_color),
		Vector3(0, bottom_y / 2.0, 0))

	# Pond floor: a thin disc at the bottom
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = outer_radius
	floor_mesh.bottom_radius = outer_radius
	floor_mesh.height = 0.05
	_add_piece("PondFloor", floor_mesh, _solid(floor_color), Vector3(0, bottom_y, 0))

	# Rim: a faint glass wall around the outside, so you can see where the pond ends
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = outer_radius
	rim_mesh.bottom_radius = outer_radius
	rim_mesh.height = depth
	rim_mesh.cap_top = false
	rim_mesh.cap_bottom = false
	_add_piece("Rim", rim_mesh, _see_through(Color(water_color, 0.12)),
		Vector3(0, bottom_y + depth / 2.0, 0))


func _add_piece(piece_name: String, mesh: Mesh, material: Material,
		pos: Vector3, scale_by := Vector3.ONE) -> void:
	var piece := MeshInstance3D.new()
	piece.name = piece_name
	piece.mesh = mesh
	piece.material_override = material
	piece.position = pos
	piece.scale = scale_by
	add_child(piece)


func _solid(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat


func _see_through(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED   # visible from above and below
	return mat
