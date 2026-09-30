extends RefCounted
class_name PondScenery
## Builds the surroundings of the pond: grass tufts on the lawn, clumps of reeds
## (with a few cattails) at the water's edge, low-poly rocks, and a cheap distant
## landscape (a tree line and hazy hills). Everything is placed with a fixed random
## seed, so the scene looks the same every time (and in the editor).
##
## Design rule: pretty OUTSIDE the pond, quiet INSIDE it. Nothing here goes in the
## water, so the fish search area stays clean.
## Grass and reeds use MultiMesh: thousands of copies drawn in one go (cheap on Quest).
## The distant landscape is a few flat bands with a bumpy top edge, not real hills.

const BladesShader := preload("res://assets/shaders/grass_blades.gdshader")


static func build(pond_radius: float, lawn_radius: float, tufts: int, reeds: int, trees: int,
		rocks := 0, distant := false) -> Node3D:
	var root := Node3D.new()
	root.name = "Scenery"
	var rng := RandomNumberGenerator.new()
	rng.seed = 2177   # fixed, so the layout never changes

	# Grass tufts: spread over the lawn, denser near the pond (where you look most)
	var tuft_mesh := _blade_cluster(4, 0.12, 0.035)
	var tuft_positions: Array[Transform3D] = []
	for i in tufts:
		var r := pond_radius + 0.3 + pow(rng.randf(), 1.8) * (minf(lawn_radius, pond_radius + 25.0) - pond_radius)
		var a := rng.randf() * TAU
		var s := rng.randf_range(0.7, 1.4)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s))
		tuft_positions.append(Transform3D(basis, Vector3(cos(a) * r, 0.0, sin(a) * r)))
	root.add_child(_multimesh("GrassTufts", tuft_mesh, tuft_positions, _blades_material(
			Color(0.26, 0.42, 0.17), Color(0.5, 0.72, 0.32), 0.05)))

	# Reeds: a few big clumps hugging the shore (rather than many small ones),
	# denser in the middle of each clump, with a few cattail stalks sticking up
	var reed_mesh := _blade_cluster(7, 0.9, 0.025)
	var reed_positions: Array[Transform3D] = []
	var stalk_positions: Array[Transform3D] = []
	var per_clump := 16
	var clumps := maxi(1, reeds / per_clump) if reeds > 0 else 0
	var clump_angles: Array[float] = []
	for c in clumps:
		# spread clumps round the pond, with some wobble so it isn't too regular
		var ca := TAU * (c + rng.randf_range(0.1, 0.7)) / clumps
		clump_angles.append(ca)
		var spread := rng.randf_range(0.10, 0.18)          # clump size (radians of shore)
		for i in per_clump:
			var t := rng.randf_range(-1.0, 1.0)
			var a := ca + t * absf(t) * spread               # bunched towards the middle
			var r := pond_radius + rng.randf_range(0.05, 0.5 + 0.6 * (1.0 - absf(t)))
			var s := rng.randf_range(0.6, 1.3) * (1.0 - 0.35 * absf(t))   # taller in the middle
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
			reed_positions.append(Transform3D(basis, Vector3(cos(a) * r, 0.0, sin(a) * r)))
		for i in 3:
			var a := ca + rng.randf_range(-0.5, 0.5) * spread
			var r := pond_radius + rng.randf_range(0.15, 0.6)
			var tilt := Basis(Vector3(cos(a), 0, sin(a)).cross(Vector3.UP).normalized(), rng.randf_range(-0.12, 0.12))
			var h := rng.randf_range(0.9, 1.25)
			stalk_positions.append(Transform3D(tilt.scaled(Vector3(1, h, 1)), Vector3(cos(a) * r, 0.0, sin(a) * r)))
	if not reed_positions.is_empty():
		root.add_child(_multimesh("Reeds", reed_mesh, reed_positions, _blades_material(
				Color(0.25, 0.36, 0.15), Color(0.62, 0.68, 0.38), 0.1)))
		root.add_child(_multimesh("Cattails", _cattail_mesh(), stalk_positions, _vertex_color_material()))

	# Rocks: a few low-poly boulders on the bank, grouped near the reed clumps
	if rocks > 0:
		var rock_root := Node3D.new()
		rock_root.name = "Rocks"
		var rock_mat := StandardMaterial3D.new()
		rock_mat.albedo_color = Color(0.43, 0.42, 0.40)
		rock_mat.roughness = 1.0
		rock_mat.metallic_specular = 0.1      # matte, no shiny sky reflection
		for i in rocks:
			var a := rng.randf() * TAU
			if not clump_angles.is_empty() and i % 3 != 2:     # most rocks sit beside a reed clump
				a = clump_angles[i % clump_angles.size()] + rng.randf_range(0.12, 0.3) * (1.0 if i % 2 else -1.0)
			var r := pond_radius + rng.randf_range(0.4, 2.2)
			var size := rng.randf_range(0.3, 0.8)
			var mi := MeshInstance3D.new()
			mi.name = "Rock"
			mi.mesh = _rock_mesh(rng.randi())
			mi.material_override = rock_mat
			mi.scale = Vector3(size * rng.randf_range(1.0, 1.5), size * rng.randf_range(0.55, 0.8), size)
			mi.rotation.y = rng.randf() * TAU
			mi.position = Vector3(cos(a) * r, -0.12 * size, sin(a) * r)    # sunk into the ground a bit
			rock_root.add_child(mi)
		root.add_child(rock_root)

	# Trees: simple low-poly trunk + round canopy, out in the distance
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.36, 0.25, 0.16)
	for i in trees:
		var a := rng.randf() * TAU
		var r := rng.randf_range(pond_radius + 16.0, lawn_radius - 2.0)
		var h := rng.randf_range(3.0, 6.0)
		var tree := Node3D.new()
		tree.name = "Tree"
		tree.position = Vector3(cos(a) * r, 0.0, sin(a) * r)
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.12
		trunk.bottom_radius = 0.2
		trunk.height = h * 0.45
		trunk.radial_segments = 8
		_mesh(tree, trunk, trunk_mat, Vector3(0, h * 0.225, 0))
		var leaf_mat := StandardMaterial3D.new()
		leaf_mat.albedo_color = Color(0.2, 0.42, 0.18).lerp(Color(0.35, 0.5, 0.2), rng.randf())
		var crown := SphereMesh.new()
		crown.radius = h * 0.32
		crown.height = h * 0.6
		crown.radial_segments = 10
		crown.rings = 6
		_mesh(tree, crown, leaf_mat, Vector3(0, h * 0.62, 0))
		root.add_child(tree)

	# Distant landscape: flat ground out to the horizon, a tree line just past the
	# lawn, and two layers of hills. The scene's distance fog makes them hazy.
	if distant:
		var far := Node3D.new()
		far.name = "DistantLandscape"
		var ground_mat := StandardMaterial3D.new()
		ground_mat.albedo_color = Color(0.36, 0.5, 0.28)
		ground_mat.roughness = 1.0
		_mesh(far, _flat_ring(lawn_radius - 0.5, 400.0, -0.02), ground_mat, Vector3.ZERO)
		var band_mat := _vertex_color_material()
		_mesh(far, _far_band(lawn_radius + 1.5, 2.5, 6.5, 70.0, 7, Color(0.17, 0.28, 0.17), Color(0.26, 0.40, 0.23)), band_mat, Vector3.ZERO)
		_mesh(far, _far_band(150.0, 8.0, 26.0, 6.0, 11, Color(0.30, 0.42, 0.33), Color(0.38, 0.50, 0.40)), band_mat, Vector3.ZERO)
		_mesh(far, _far_band(260.0, 20.0, 55.0, 4.0, 13, Color(0.42, 0.52, 0.52), Color(0.50, 0.60, 0.62)), band_mat, Vector3.ZERO)
		root.add_child(far)
	return root


## A little clump of pointed blades fanning out from one spot.
## UV.y runs 0 (root) to 1 (tip) so the shader can colour and sway them.
static func _blade_cluster(blades: int, height: float, width: float) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = blades * 31 + int(height * 100)
	for b in blades:
		var ang := TAU * b / blades + rng.randf_range(-0.3, 0.3)
		var lean := Vector3(cos(ang), 0, sin(ang)) * height * rng.randf_range(0.1, 0.35)
		var h := height * rng.randf_range(0.7, 1.1)
		var side := Vector3(-sin(ang), 0, cos(ang)) * width * 0.5
		var tip := lean + Vector3(0, h, 0)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0, 0)); st.add_vertex(-side)
		st.set_uv(Vector2(1, 0)); st.add_vertex(side)
		st.set_uv(Vector2(0.5, 1)); st.add_vertex(tip)
	return st.commit()


## A cattail: thin green stalk with a brown head near the top (about 1.1 m tall).
static func _cattail_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tube(st, 0.0, 1.1, 0.008, 0.006, 5, Color(0.33, 0.42, 0.2))      # stalk
	_tube(st, 0.82, 1.0, 0.024, 0.024, 5, Color(0.36, 0.23, 0.13))    # brown head
	return st.commit()


static func _tube(st: SurfaceTool, y0: float, y1: float, r0: float, r1: float, sides: int, c: Color) -> void:
	st.set_color(c)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p00 := Vector3(cos(a0) * r0, y0, sin(a0) * r0)
		var p10 := Vector3(cos(a1) * r0, y0, sin(a1) * r0)
		var p01 := Vector3(cos(a0) * r1, y1, sin(a0) * r1)
		var p11 := Vector3(cos(a1) * r1, y1, sin(a1) * r1)
		st.add_vertex(p00); st.add_vertex(p11); st.add_vertex(p10)
		st.add_vertex(p00); st.add_vertex(p01); st.add_vertex(p11)
		st.add_vertex(Vector3(0, y1, 0)); st.add_vertex(p11); st.add_vertex(p01)   # cap


## A low-poly boulder: a coarse sphere with its corners pushed in and out at
## random, flat-shaded so every face reads as a facet.
static func _rock_mesh(seed_value: int) -> Mesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var sphere := SphereMesh.new()
	sphere.radial_segments = 7
	sphere.rings = 4
	sphere.radius = 0.5
	sphere.height = 1.0
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	# the same bump for vertices at the same spot (the sphere's seam repeats some)
	var bumps := {}
	for i in verts.size():
		var key := Vector3i((verts[i] * 1000.0).round())
		if not bumps.has(key):
			bumps[key] = rng.randf_range(0.8, 1.15)
		verts[i] *= bumps[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)              # flat shading: one normal per face
	for i in index.size():
		st.add_vertex(verts[index[i]])
	st.generate_normals()
	return st.commit()


## A flat ring of ground (for the land beyond the lawn).
static func _flat_ring(r0: float, r1: float, y: float) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var seg := 64
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var in0 := Vector3(cos(a0) * r0, y, sin(a0) * r0)
		var in1 := Vector3(cos(a1) * r0, y, sin(a1) * r0)
		var out0 := Vector3(cos(a0) * r1, y, sin(a0) * r1)
		var out1 := Vector3(cos(a1) * r1, y, sin(a1) * r1)
		st.add_vertex(in0); st.add_vertex(out0); st.add_vertex(out1)
		st.add_vertex(in0); st.add_vertex(out1); st.add_vertex(in1)
	return st.commit()


## A distant silhouette: an upright band all the way round at `radius`, whose top
## edge goes up and down. Many small bumps look like tree crowns; a few big ones
## look like hills. Darker at the bottom, lighter at the top.
static func _far_band(radius: float, min_h: float, max_h: float, bumps_per_turn: float,
		seed_value: int, bottom: Color, top: Color) -> Mesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 1.0
	var seg := 360
	var heights: Array[float] = []
	for i in seg + 1:
		var a := TAU * i / seg
		# noise sampled on a circle, so the ends join up seamlessly
		var p := Vector2(cos(a), sin(a)) * bumps_per_turn / TAU
		var n := noise.get_noise_2d(p.x, p.y) * 0.5 + 0.5
		n += (noise.get_noise_2d(p.x * 3.1 + 40.0, p.y * 3.1) * 0.5 + 0.5) * 0.35
		heights.append(lerpf(min_h, max_h, clampf(n / 1.35, 0.0, 1.0)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var b0 := Vector3(cos(a0) * radius, -1.0, sin(a0) * radius)
		var b1 := Vector3(cos(a1) * radius, -1.0, sin(a1) * radius)
		var t0 := Vector3(b0.x, heights[i], b0.z)
		var t1 := Vector3(b1.x, heights[i + 1], b1.z)
		st.set_color(bottom); st.add_vertex(b0)
		st.set_color(top); st.add_vertex(t0)
		st.set_color(top); st.add_vertex(t1)
		st.set_color(bottom); st.add_vertex(b0)
		st.set_color(top); st.add_vertex(t1)
		st.set_color(bottom); st.add_vertex(b1)
	return st.commit()


static func _vertex_color_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # flat colour, cheap
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


static func _blades_material(root_c: Color, tip_c: Color, wind: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = BladesShader
	mat.set_shader_parameter("root_color", root_c)
	mat.set_shader_parameter("tip_color", tip_c)
	mat.set_shader_parameter("wind_strength", wind)
	return mat


static func _multimesh(node_name: String, mesh: Mesh, xforms: Array[Transform3D], mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = mat
	return mmi


static func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
