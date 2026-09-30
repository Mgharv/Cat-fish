extends RefCounted
class_name FishBuilder
## Builds a 3D fish from a FishSpecies (the numbers). The same builder is used by
## the pond fish, the wanted poster and the species sheet, so they always match.
## The fish faces -Z (Godot's "forward"), like the rest of the project.

const PatternShader := preload("res://assets/shaders/fish_pattern.gdshader")
const BODY_SHARE := 0.8          # body = first 80% of the length, tail = last 20%
const RINGS := 40
const SEGMENTS := 32


static func build(species: FishSpecies) -> Node3D:
	var root := Node3D.new()
	root.name = "Look"
	var L := species.body_length
	var H := species.body_height * L
	var W := species.body_width * L

	var body_mat := _pattern_material(species, species.body_color, true)
	var fin_mat := _pattern_material(species, species.fin_color, false)

	_add(root, "Body", _body_mesh(L, H, W), body_mat)
	_add(root, "Tail", _tail_mesh(species, L, H), fin_mat)
	_add(root, "DorsalFin", _dorsal_mesh(L, H), fin_mat)
	for side in [-1.0, 1.0]:
		var fin := _add(root, "PectoralFin", _pectoral_mesh(L), fin_mat)
		fin.position = Vector3(side * W * 0.5 * _profile(0.27) * 0.85, -H * 0.08, _z(0.27, L))
		fin.rotation.y = -0.6 if side > 0.0 else PI + 0.6    # point outward and back
		fin.rotate_object_local(Vector3.BACK, -0.35)          # droop slightly down
		var eye := _add(root, "Eye", _eye_mesh(L), _eye_material())
		var eye_t := 0.10
		var ang := 0.35
		eye.position = Vector3(side * W * 0.5 * _profile(eye_t) * cos(ang) * 0.92,
				H * 0.5 * _profile(eye_t) * sin(ang), _z(eye_t, L))
	return root


# ---------- shapes ----------

## Body thickness along the fish: 0 at the nose, widest ~35% back, thin at the tail joint.
static func _profile(t: float) -> float:
	var raw := func(x: float) -> float: return pow(x, 0.62) * pow(1.0 - x * 0.86, 0.85)
	return raw.call(clampf(t, 0.0, 1.0)) / raw.call(0.4)


static func _z(t: float, L: float) -> float:
	return -L * 0.5 + t * L * BODY_SHARE


static func _body_mesh(L: float, H: float, W: float) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in RINGS + 1:
		var t := float(i) / RINGS
		var p := _profile(t)
		for j in SEGMENTS + 1:
			var th := TAU * float(j) / SEGMENTS
			var c := cos(th)
			var s := sin(th)
			st.set_uv(Vector2(t, float(j) / SEGMENTS))
			st.set_normal(Vector3(c / maxf(W, 0.001), s / maxf(H, 0.001), 0.0).normalized())
			st.add_vertex(Vector3(W * 0.5 * p * c, H * 0.5 * p * s, _z(t, L)))
	for i in RINGS:
		for j in SEGMENTS:
			var a := i * (SEGMENTS + 1) + j
			var b := a + SEGMENTS + 1
			st.add_index(a); st.add_index(b); st.add_index(a + 1)
			st.add_index(a + 1); st.add_index(b); st.add_index(b + 1)
	return st.commit()


static func _tail_mesh(species: FishSpecies, L: float, H: float) -> Mesh:
	var z0 := _z(1.0, L)                 # tail joint
	var z1 := L * 0.5                    # tail tip
	var joint := H * 0.5 * _profile(1.0)
	var span := H * 0.55                 # half-height of the tail at its tips
	var pts: Array[Vector2] = []         # (z, y) outline, around the tail
	if species.tail_type == FishSpecies.Tail.FORKED:
		pts = [Vector2(z0, joint), Vector2(z1, span), Vector2(z0 + (z1 - z0) * 0.55, 0.0),
				Vector2(z1, -span), Vector2(z0, -joint)]
	else:  # FAN: big rounded tail
		pts.append(Vector2(z0, joint))
		for k in 13:
			var ang := lerpf(1.25, -1.25, k / 12.0)
			pts.append(Vector2(z0 + cos(ang) * (z1 - z0) * 1.05, sin(ang) * span * 1.15))
		pts.append(Vector2(z0, -joint))
	return _flat_fan(Vector2(z0, 0.0), pts, Vector3.RIGHT)


static func _dorsal_mesh(L: float, H: float) -> Mesh:
	var t0 := 0.32
	var t1 := 0.58
	var y0 := H * 0.5 * _profile(t0) * 0.95
	var y1 := H * 0.5 * _profile(t1) * 0.95
	var pts: Array[Vector2] = [Vector2(_z(t0, L), y0), Vector2(_z(t0 + 0.12, L), y0 + H * 0.38),
			Vector2(_z(t1, L), y1)]
	return _flat_fan(Vector2(_z((t0 + t1) * 0.5, L), (y0 + y1) * 0.5), pts, Vector3.RIGHT)


static func _pectoral_mesh(L: float) -> Mesh:
	# a small oval fin lying flat, its root at the body and pointing outward (+x)
	var rx := L * 0.075
	var rz := L * 0.032
	var pts: Array[Vector2] = []
	for k in 17:
		var ang := TAU * k / 16.0
		pts.append(Vector2(rx + cos(ang) * rx, sin(ang) * rz))
	return _flat_fan(Vector2(rx, 0.0), pts, Vector3.UP)


## Makes a flat, two-sided polygon. In the (u, v) outline, u/v map to z/y for a
## vertical fin (normal = RIGHT) or x/z for a horizontal fin (normal = UP).
static func _flat_fan(center: Vector2, pts: Array[Vector2], normal: Vector3) -> Mesh:
	var to3 := func(p: Vector2) -> Vector3:
		return Vector3(0.0, p.y, p.x) if normal == Vector3.RIGHT else Vector3(p.x, 0.0, p.y)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(normal)
	st.set_uv(Vector2(0.5, 0.5))
	for k in pts.size() - 1:
		st.add_vertex(to3.call(center))
		st.add_vertex(to3.call(pts[k]))
		st.add_vertex(to3.call(pts[k + 1]))
	return st.commit()


static func _eye_mesh(L: float) -> Mesh:
	var m := SphereMesh.new()
	m.radius = L * 0.028
	m.height = L * 0.056
	return m


# ---------- materials ----------

static func _pattern_material(species: FishSpecies, color: Color, with_pattern: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = PatternShader
	mat.set_shader_parameter("body_color", color)
	mat.set_shader_parameter("pattern_color", species.pattern_color)
	mat.set_shader_parameter("pattern", int(species.pattern) if with_pattern else 0)
	mat.set_shader_parameter("pattern_frequency", species.pattern_frequency)
	mat.set_shader_parameter("pattern_size", species.pattern_size)
	mat.set_shader_parameter("length_to_girth", 1.0 / maxf(species.body_height, 0.05) * 0.5)
	mat.set_shader_parameter("shade_amount", 0.35 if with_pattern else 0.0)
	return mat


static func _eye_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.05, 0.05, 0.06)
	return m


static func _add(parent: Node3D, part_name: String, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)
	return mi
