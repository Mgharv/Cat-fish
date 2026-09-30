extends RefCounted
class_name PondScenery
## Builds the surroundings of the pond: grass tufts on the lawn, reeds at the
## water's edge, and simple trees in the distance. Everything is placed with a fixed
## random seed, so the scene looks the same every time (and in the editor).
## Grass and reeds use MultiMesh: thousands of copies drawn in one go (cheap on Quest).

const BladesShader := preload("res://assets/shaders/grass_blades.gdshader")


static func build(pond_radius: float, lawn_radius: float, tufts: int, reeds: int, trees: int) -> Node3D:
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

	# Reeds: tall thin blades in clumps around the water's edge
	var reed_mesh := _blade_cluster(7, 0.9, 0.025)
	var reed_positions: Array[Transform3D] = []
	var clumps := maxi(1, reeds / 8)
	for c in clumps:
		var ca := rng.randf() * TAU
		for i in 8:
			var a := ca + rng.randf_range(-0.06, 0.06)
			var r := pond_radius + rng.randf_range(0.05, 0.6)
			var s := rng.randf_range(0.7, 1.3)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
			reed_positions.append(Transform3D(basis, Vector3(cos(a) * r, 0.0, sin(a) * r)))
	root.add_child(_multimesh("Reeds", reed_mesh, reed_positions, _blades_material(
			Color(0.25, 0.36, 0.15), Color(0.62, 0.68, 0.38), 0.1)))

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
