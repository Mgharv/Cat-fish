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
@export var fish_count := 30            ## how many fish to spawn
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
@export var bank_width := 40.0:         ## how far the lawn stretches out from the pond
	set(value):
		bank_width = value
		_build_pond()

# ---------- SURROUNDINGS ----------
@export var grass_tufts := 700:        ## little clumps of grass on the lawn
	set(value):
		grass_tufts = value
		_build_pond()
@export var reeds := 64:               ## tall reeds at the water's edge
	set(value):
		reeds = value
		_build_pond()
@export var trees := 0:                ## simple trees in the distance
	set(value):
		trees = value
		_build_pond()
@export var rocks := 10:               ## low-poly rocks on the bank (none go in the water)
	set(value):
		rocks = value
		_build_pond()
@export var distant_scenery := true:   ## far tree line + hazy hills (very cheap: a few flat bands)
	set(value):
		distant_scenery = value
		_build_pond()

@export var play_ambience := true       ## relaxing water sounds (lapping + drips)

# ---------- WATER CLARITY ----------
@export_range(0.0, 1.0, 0.05) var water_clarity := 0.2:   ## 1 = crystal clear, 0 = very murky
	set(value):
		water_clarity = value
		apply_water()
@export var murk_color := Color(0.10, 0.36, 0.33)  ## colour things fade toward in murky water (blue-green)
@export var max_murk_per_metre := 0.7   ## how murky "clarity 0" is (fade per metre of water)

# ---------- LOOK ----------
@export var water_color := Color(0.12, 0.44, 0.45, 0.3):  ## surface tint (muted teal); last number = see-through-ness
	set(value):
		water_color = value
		_build_pond()
@export_range(0.0, 1.0, 0.05) var ripple_strength := 0.5:  ## surface ripples: 0 = flat calm water
	set(value):
		ripple_strength = value
		_build_pond()
@export var ripple_scale := 1.2:        ## ripples per metre (bigger = finer ripples)
	set(value):
		ripple_scale = value
		_build_pond()
@export_range(0.0, 1.0, 0.05) var reflection_strength := 0.45:  ## sky reflection when looking across the water (weak looking straight down)
	set(value):
		reflection_strength = value
		_build_pond()
@export var bank_color := Color(0.36, 0.52, 0.28)
@export var earth_color := Color(0.38, 0.30, 0.22)
@export var floor_color := Color(0.55, 0.48, 0.35)
@export var wood_color := Color(0.52, 0.35, 0.21)   ## warm medium brown (bridge + poster frame)

const SEGMENTS := 96   # how smooth the circles are
const UnderwaterShader := preload("res://assets/shaders/underwater_surface.gdshader")
const WaterSurfaceShader := preload("res://assets/shaders/water_surface.gdshader")
const PondAmbience := preload("res://scripts/pond_ambience.gd")
const GrassShader := preload("res://assets/shaders/grass_ground.gdshader")

var fishes: Node3D   # container the spawned fish go into


func _ready() -> void:
	_build_pond()
	if Engine.is_editor_hint():
		return  # in the editor: just show the pond, don't spawn fish
	for i in fish_count:
		spawn_fish()
	if play_ambience:
		var amb := PondAmbience.new()
		amb.name = "Ambience"
		amb.pond_radius = pond_radius
		amb.surface_y = surface_y
		add_child(amb)


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
	_apply_water_to(fish)
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
		if child.name != "Fishes" and child.name != "Ambience":
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
	_piece("Water", _ring_flat(0.0, pond_radius, surface_y), _water_surface())
	_piece("PondFloor", _ring_flat(0.0, pond_radius, bottom_y), _underwater(floor_color))
	# Earth wall around the edge (seen through the water, it shows how deep it is)
	_piece("PondWall", _ring_wall(pond_radius, bottom_y, -slab), _underwater(earth_color))
	# Lawn all around, top at y = 0 (with its inner edge face at the water)
	var grass := ShaderMaterial.new()
	grass.shader = GrassShader
	_piece("Bank", _ring_flat(pond_radius, pond_radius + bank_width, 0.0), grass)
	_piece("BankEdge", _ring_wall(pond_radius, -slab, 0.0), _solid(earth_color))
	# Grass tufts, reeds, rocks, trees and the distant landscape
	add_child(PondScenery.build(pond_radius, pond_radius + bank_width, grass_tufts, reeds, trees,
			rocks, distant_scenery))

	# The ring bridge: separate planks (top 5 mm above y = 0) on a dark frame,
	# side boards, and a low curb along each edge
	var dark := _solid(wood_color.darkened(0.3))
	_piece("BridgeFrame", _ring_flat(r_in, r_out, -0.035), _solid(wood_color.darkened(0.6)))
	_piece("BridgePlanks", _ring_planks(r_in, r_out, -0.03, 0.005), _plank_material())
	_piece("BridgeSideIn", _ring_wall(r_in, -0.09, -0.03), dark)
	_piece("BridgeSideOut", _ring_wall(r_out, -0.09, -0.03), dark)
	_piece("CurbIn", _ring_box(r_in, r_in + 0.07, 0.005, 0.065), dark)
	_piece("CurbOut", _ring_box(r_out - 0.07, r_out, 0.005, 0.065), dark)

	# Posts holding the bridge up, standing in the water, about every 2 m
	var post_mat := _underwater(wood_color.darkened(0.35))
	var posts := maxi(6, int(TAU * bridge_radius / 2.0))
	for i in posts:
		var ang := TAU * i / posts
		for r in [r_in + 0.08, r_out - 0.08]:
			var post := CylinderMesh.new()
			post.top_radius = 0.06
			post.bottom_radius = 0.06
			post.height = -bottom_y
			_piece("BridgePost", post, post_mat, Vector3(cos(ang) * r, bottom_y / 2.0, sin(ang) * r))
	apply_water()


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


## The bridge deck as separate planks laid across the walkway, with small gaps
## and slightly bevelled top edges. Each plank gets a slightly different shade
## (stored as vertex colour), so the deck reads as wood without a texture.
func _ring_planks(r0: float, r1: float, y0: float, y1: float) -> Mesh:
	var plank_w := 0.2                               # plank width along the walkway (m)
	var gap := 0.012                                  # gap between planks (m)
	var bevel := 0.008
	var count := maxi(12, int(TAU * (r0 + r1) * 0.5 / plank_w))
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in count:
		var shade := rng.randf_range(-0.07, 0.07)
		st.set_color(Color(1.0 + shade, 1.0 + shade, 1.0 + shade * 0.8))
		var half_gap := gap * 0.5 / ((r0 + r1) * 0.5)
		var a0 := TAU * i / count + half_gap
		var a1 := TAU * (i + 1) / count - half_gap
		var ab := bevel / ((r0 + r1) * 0.5)          # bevel as an angle
		# corners: top face (inset by the bevel) and the outline at the bevel's foot
		var ti := [_polar(r0 + bevel, a0 + ab, y1), _polar(r1 - bevel, a0 + ab, y1),
				_polar(r1 - bevel, a1 - ab, y1), _polar(r0 + bevel, a1 - ab, y1)]
		var bo := [_polar(r0, a0, y1 - bevel), _polar(r1, a0, y1 - bevel),
				_polar(r1, a1, y1 - bevel), _polar(r0, a1, y1 - bevel)]
		var bt := [_polar(r0, a0, y0), _polar(r1, a0, y0), _polar(r1, a1, y0), _polar(r0, a1, y0)]
		_quad_st(st, ti[0], ti[1], ti[2], ti[3])                  # top
		for k in 4:                                            # bevel strips + sides
			var k2 := (k + 1) % 4
			_quad_st(st, bo[k], bo[k2], ti[k2], ti[k])
			_quad_st(st, bt[k], bt[k2], bo[k2], bo[k])
	st.generate_normals()
	return st.commit()


## A curved beam (ring-shaped box) between two radii and two heights.
func _ring_box(r0: float, r1: float, y0: float, y1: float) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SEGMENTS:
		var a0 := TAU * i / SEGMENTS
		var a1 := TAU * (i + 1) / SEGMENTS
		_quad_st(st, _polar(r0, a0, y1), _polar(r1, a0, y1), _polar(r1, a1, y1), _polar(r0, a1, y1))
		_quad_st(st, _polar(r0, a0, y0), _polar(r0, a0, y1), _polar(r0, a1, y1), _polar(r0, a1, y0))
		_quad_st(st, _polar(r1, a0, y0), _polar(r1, a1, y0), _polar(r1, a1, y1), _polar(r1, a0, y1))
	st.generate_normals()
	return st.commit()


func _polar(r: float, a: float, y: float) -> Vector3:
	return Vector3(cos(a) * r, y, sin(a) * r)


func _quad_st(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
	st.add_vertex(a); st.add_vertex(c); st.add_vertex(d)


func _plank_material() -> StandardMaterial3D:
	var mat := _solid(wood_color)
	mat.vertex_color_use_as_albedo = true     # albedo = wood_color x each plank's shade
	mat.roughness = 0.85
	return mat


## Murk per metre for the current clarity setting.
func murk_per_metre() -> float:
	return (1.0 - water_clarity) * max_murk_per_metre


## Pushes the current water settings to everything under the water (fish + pond parts).
## Call this after changing water_clarity during a game (e.g. a new level).
func apply_water() -> void:
	if not is_inside_tree():
		return
	for node in find_children("*", "MeshInstance3D", true, false):
		_set_water(node.material_override)
	if fishes:
		for f in fishes.get_children():
			_apply_water_to(f)


func _apply_water_to(fish: Node) -> void:
	for node in fish.find_children("*", "MeshInstance3D", true, false):
		_set_water(node.material_override)


func _set_water(mat: Material) -> void:
	if mat is ShaderMaterial:
		mat.set_shader_parameter("surface_y", global_position.y + surface_y)
		mat.set_shader_parameter("water_color", murk_color)
		mat.set_shader_parameter("murk_per_metre", murk_per_metre())


func _water_surface() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = WaterSurfaceShader
	mat.set_shader_parameter("tint", water_color)
	mat.set_shader_parameter("ripple_strength", ripple_strength)
	mat.set_shader_parameter("ripple_scale", ripple_scale)
	mat.set_shader_parameter("reflection_strength", reflection_strength)
	return mat


func _underwater(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = UnderwaterShader
	mat.set_shader_parameter("albedo", color)
	return mat


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
