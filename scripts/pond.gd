@tool
extends Node3D
## THE POND: a round pond with a ring-shaped (circular) bridge in the middle.
## The player walks around the ring and looks down at fish inside the ring,
## outside it, and underneath it.
## It builds its own water, banks, bridge and floor from the numbers below,
## and spawns the fish when the game starts.
## Change any number in the Inspector and the pond reshapes itself (even in the editor).
##
##   y = 0 is the real floor = the bridge deck, where you stand.

signal fish_swatted(fish)               ## passed up from any fish that gets hit

# ---------- FISH ----------
@export var fish_scene: PackedScene     ## the fish template (fish.tscn)
@export var fish_count := 18            ## how many fish to spawn
@export var species_mix: Array[FishSpecies] = []  ## species to spawn (picked at random); empty = original look

# ---------- SIZE (metres) ----------
@export var pond_radius := 6.0:         ## size of the pond
	set(value):
		pond_radius = value
		_build_pond()
@export var bridge_radius := 3.0:       ## how far the ring bridge is from the centre
	set(value):
		bridge_radius = value
		_build_pond()
@export var bridge_width := 1.2:        ## how wide the walkway is
	set(value):
		bridge_width = value
		_build_pond()
@export var surface_y := -0.25:         ## water surface, just below the bridge deck
	set(value):
		surface_y = value
		_build_pond()
@export var bottom_y := -2.0:           ## pond floor
	set(value):
		bottom_y = value
		_build_pond()
@export var bank_width := 3.0:          ## grassy ground around the pond
	set(value):
		bank_width = value
		_build_pond()

# ---------- LOOK ----------
@export var water_color := Color(0.2, 0.55, 0.85, 0.25):  ## last number = see-through-ness
	set(value):
		water_color = value
		_build_pond()
@export var bank_color := Color(0.36, 0.52, 0.28)
@export var earth_color := Color(0.38, 0.30, 0.22)
@export var floor_color := Color(0.55, 0.48, 0.35)
@export var wood_color := Color(0.55, 0.38, 0.22)

const SEGMENTS := 96   # how smooth the circles are

var fishes: Node3D   # container the spawned fish go into


func _ready() -> void:
	_build_pond()
	if Engine.is_editor_hint():
		return  # in the editor: just show the pond, don't spawn fish
	for i in fish_count:
		spawn_fish()


## Where the player may walk: distance from the centre, from the ring's inner to outer edge.
func bridge_limits() -> Vector2:
	var keep_off_edge := 0.15
	return Vector2(bridge_radius - bridge_width * 0.5 + keep_off_edge,
			bridge_radius + bridge_width * 0.5 - keep_off_edge)


# ---------- SPAWNING ----------

## Spawns one fish at a random spot. Pass a species to choose it; otherwise one is
## picked at random from species_mix.
func spawn_fish(sp: FishSpecies = null) -> Node3D:
	var fish := fish_scene.instantiate()
	# tell the fish where the pond's edges are, before it starts swimming
	fish.pond_radius = pond_radius
	fish.surface_y = surface_y
	fish.bottom_y = bottom_y
	fish.position = random_point_in_pond()
	if sp:
		fish.species = sp
	elif not species_mix.is_empty():
		fish.species = species_mix.pick_random()
	fish.swatted.connect(func(f): fish_swatted.emit(f))   # signals go up
	fishes.add_child(fish)
	return fish


## Makes sure at least `count` fish of this species are swimming, so the
## wanted fish always exists. Adds extra fish of that species if needed.
func ensure_species(sp: FishSpecies, count: int) -> void:
	var have := 0
	for f in fishes.get_children():
		if f.species == sp and not f.is_queued_for_deletion():
			have += 1
	while have < count:
		spawn_fish(sp)
		have += 1


## Removes a fish and spawns a fresh random one elsewhere, keeping the count steady.
func replace_fish(fish: Node3D) -> void:
	fish.queue_free()
	spawn_fish()


func random_point_in_pond() -> Vector3:
	var angle := randf() * TAU                                  # anywhere around the circle
	var r := sqrt(randf()) * (pond_radius - 0.4)                # spread evenly, not touching the wall
	var y := randf_range(bottom_y + 0.3, surface_y - 0.15)      # not touching surface/floor
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

	var slab := 0.3                     # thickness of the grassy bank
	var r_in := bridge_radius - bridge_width * 0.5
	var r_out := bridge_radius + bridge_width * 0.5

	# Water surface and pond floor: flat discs
	_piece("Water", _ring_flat(0.0, pond_radius, surface_y), _see_through(water_color))
	_piece("PondFloor", _ring_flat(0.0, pond_radius, bottom_y), _solid(floor_color))
	# Earth wall around the edge (seen through the water, it shows how deep it is)
	_piece("PondWall", _ring_wall(pond_radius, bottom_y, -slab), _solid(earth_color))
	# Grassy bank all around, top at y = 0 (with its inner edge face)
	_piece("Bank", _ring_flat(pond_radius, pond_radius + bank_width, 0.0), _solid(bank_color))
	_piece("BankEdge", _ring_wall(pond_radius, -slab, 0.0), _solid(bank_color.darkened(0.2)))

	# The ring bridge: deck (top 5 mm above y = 0), its side faces, and low edge rails
	var wood := _solid(wood_color)
	var dark := _solid(wood_color.darkened(0.25))
	_piece("BridgeDeck", _ring_flat(r_in, r_out, 0.005), wood)
	_piece("BridgeSideIn", _ring_wall(r_in, -0.08, 0.005), dark)
	_piece("BridgeSideOut", _ring_wall(r_out, -0.08, 0.005), dark)
	_piece("RailIn", _ring_wall(r_in + 0.03, 0.005, 0.06), dark)
	_piece("RailOut", _ring_wall(r_out - 0.03, 0.005, 0.06), dark)

	# Posts holding the bridge up, standing in the water, about every 2 m
	var post_mat := _solid(wood_color.darkened(0.35))
	var posts := maxi(6, int(TAU * bridge_radius / 2.0))
	for i in posts:
		var ang := TAU * i / posts
		for r in [r_in + 0.08, r_out - 0.08]:
			var post := CylinderMesh.new()
			post.top_radius = 0.06
			post.bottom_radius = 0.06
			post.height = -bottom_y
			_piece("BridgePost", post, post_mat, Vector3(cos(ang) * r, bottom_y / 2.0, sin(ang) * r))


## A flat ring (or a full disc when r0 = 0), lying level at height y.
func _ring_flat(r0: float, r1: float, y: float) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in SEGMENTS:
		var a0 := TAU * i / SEGMENTS
		var a1 := TAU * (i + 1) / SEGMENTS
		var in0 := Vector3(cos(a0) * r0, y, sin(a0) * r0)
		var in1 := Vector3(cos(a1) * r0, y, sin(a1) * r0)
		var out0 := Vector3(cos(a0) * r1, y, sin(a0) * r1)
		var out1 := Vector3(cos(a1) * r1, y, sin(a1) * r1)
		st.add_vertex(in0); st.add_vertex(out0); st.add_vertex(out1)
		st.add_vertex(in0); st.add_vertex(out1); st.add_vertex(in1)
	return st.commit()


## An upright circular band at radius r, from height y0 up to y1.
func _ring_wall(r: float, y0: float, y1: float) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SEGMENTS:
		var a0 := TAU * i / SEGMENTS
		var a1 := TAU * (i + 1) / SEGMENTS
		var p00 := Vector3(cos(a0) * r, y0, sin(a0) * r)
		var p10 := Vector3(cos(a1) * r, y0, sin(a1) * r)
		var p01 := Vector3(cos(a0) * r, y1, sin(a0) * r)
		var p11 := Vector3(cos(a1) * r, y1, sin(a1) * r)
		st.set_normal(-Vector3(cos(a0), 0, sin(a0)))
		st.add_vertex(p00); st.add_vertex(p10); st.add_vertex(p11)
		st.add_vertex(p00); st.add_vertex(p11); st.add_vertex(p01)
	return st.commit()


func _piece(piece_name: String, mesh: Mesh, material: Material, pos := Vector3.ZERO) -> void:
	var piece := MeshInstance3D.new()
	piece.name = piece_name
	piece.mesh = mesh
	piece.material_override = material
	piece.position = pos
	add_child(piece)


func _solid(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED   # flat pieces are visible from both sides
	return mat


func _see_through(color: Color) -> StandardMaterial3D:
	var mat := _solid(color)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat
