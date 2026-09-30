extends Node3D
## WANTED POSTER: a board that shows the target fish in high detail.
## It renders the ACTUAL target species (same builder as the pond fish), so the
## poster always matches: a big side view and a smaller top view, like a field guide.
## The board turns to face the player (the post it stands on stays put), and
## re-renders only when the target changes.

@export var poster_width := 1.4         ## metres
@export var side_resolution := Vector2i(1024, 512)
@export var top_resolution := Vector2i(1024, 384)
@export var paper_color := Color(0.93, 0.87, 0.72)
@export var frame_color := Color(0.45, 0.30, 0.18)   ## wooden frame + post
@export var ink_color := Color(0.25, 0.15, 0.08)
@export var frame_width := 0.07         ## metres

var _side: Dictionary     # {viewport, camera, holder}
var _top: Dictionary
var _title: Label3D
var _name: Label3D
var _score: Label3D
var _board: Node3D        # everything that turns to face the player


func _ready() -> void:
	var w := poster_width
	var side_h := w * side_resolution.y / side_resolution.x
	var top_h := w * top_resolution.y / top_resolution.x
	var pad := 0.06
	var title_h := 0.22
	var name_h := 0.14
	var score_h := 0.07
	var total_h := title_h + side_h + top_h + name_h + score_h + pad * 2
	var y := total_h * 0.5 - pad            # layout from the top down
	var paper := Vector2(w + pad * 2, total_h)

	_board = Node3D.new()
	_board.name = "Board"
	add_child(_board)
	_build_frame(paper)
	_build_post(-(paper.y * 0.5 + frame_width))

	# paper: a slightly darker edge, then the cream sheet on top
	_quad(paper, Vector3(0, 0, -0.012), _flat(paper_color.darkened(0.12)))
	_quad(paper - Vector2(0.03, 0.03), Vector3(0, 0, -0.01), _flat(paper_color))

	_title = _label("WANTED", 0.16, Vector3(0, y - title_h * 0.5, 0))
	y -= title_h
	_side = _make_view("SideView", side_resolution, Vector3(-2, 0, 0), Vector3.UP)
	_quad(Vector2(w, side_h), Vector3(0, y - side_h * 0.5, 0), _viewport_material(_side.viewport))
	y -= side_h
	_top = _make_view("TopView", top_resolution, Vector3(0, 2, 0), Vector3.RIGHT)
	_quad(Vector2(w, top_h), Vector3(0, y - top_h * 0.5, 0), _viewport_material(_top.viewport))
	y -= top_h
	_name = _label("", 0.09, Vector3(0, y - name_h * 0.5, 0))
	y -= name_h
	# score: small and faded in the bottom corner, so the fish stays the focus
	_score = _label("", 0.05, Vector3(w * 0.5 - 0.02, y - score_h * 0.5, 0))
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score.modulate = Color(ink_color, 0.55)


## Show a species on the poster (called by the Game Manager when the target changes).
func show_target(species: FishSpecies, score: int) -> void:
	for view in [_side, _top]:
		for child in view.holder.get_children():
			child.queue_free()
		if species:
			view.holder.add_child(FishBuilder.build(species))
			# zoom so the fish fills most of the width (orthographic size = view height)
			var L := species.body_length
			if view == _side:   # tall fish (e.g. Roundfish) need more room for the fin
				view.camera.size = L * maxf(0.6, species.body_height * 1.8 + 0.1)
			else:
				view.camera.size = L * 0.45
		view.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE   # render just once
	_name.text = species.display_name if species else ""
	set_score(score)


func set_score(score: int) -> void:
	_score.text = "Score: %d" % score


func _process(_delta: float) -> void:
	# turn to face the player (only around the vertical axis)
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var to_cam := cam.global_position - global_position
	to_cam.y = 0.0
	if to_cam.length() > 0.01:
		_board.global_basis = Basis.looking_at(-to_cam.normalized(), Vector3.UP)


# ---------- frame and post ----------

## A simple wooden frame around the paper, a backing board, and two nails.
func _build_frame(paper: Vector2) -> void:
	var wood := _wood(frame_color)
	var fw := frame_width
	var depth := 0.05
	var outer := paper + Vector2(fw * 2, fw * 2)
	_box(Vector3(outer.x, fw, depth), Vector3(0, (paper.y + fw) * 0.5, 0), wood)     # top
	_box(Vector3(outer.x, fw, depth), Vector3(0, -(paper.y + fw) * 0.5, 0), wood)    # bottom
	_box(Vector3(fw, paper.y, depth), Vector3(-(paper.x + fw) * 0.5, 0, 0), wood)    # left
	_box(Vector3(fw, paper.y, depth), Vector3((paper.x + fw) * 0.5, 0, 0), wood)     # right
	_box(Vector3(outer.x, outer.y, 0.02), Vector3(0, 0, -0.035), _wood(frame_color.darkened(0.25)))  # back
	var nail := SphereMesh.new()
	nail.radius = 0.018
	nail.height = 0.02
	for x in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		mi.mesh = nail
		mi.material_override = _flat(Color(0.18, 0.16, 0.14))
		mi.position = Vector3(x * (paper.x * 0.5 - 0.06), paper.y * 0.5 - 0.06, 0.01)
		_board.add_child(mi)


## One post from the pond floor up to the bottom of the board. It doesn't turn.
## Under the water it uses the pond's murky material, like the bridge posts.
func _build_post(top_y: float) -> void:
	var pond := get_parent()
	var floor_y: float = pond.bottom_y if pond and "bottom_y" in pond else -2.0
	var bottom := floor_y - position.y        # pond floor, in the poster's own coordinates
	var post := CylinderMesh.new()
	post.top_radius = 0.07
	post.bottom_radius = 0.08
	post.height = top_y - bottom
	post.radial_segments = 10
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/underwater_surface.gdshader")
	mat.set_shader_parameter("albedo", frame_color.darkened(0.2))
	var mi := MeshInstance3D.new()
	mi.name = "Post"
	mi.mesh = post
	mi.material_override = mat
	mi.position = Vector3(0, (top_y + bottom) * 0.5, 0)
	add_child(mi)
	if pond and pond.has_method("apply_water"):
		pond.apply_water.call_deferred()     # give the post the same murk as everything else


# ---------- building blocks ----------

## An off-screen mini world with its own camera, rendering one view of the fish.
func _make_view(view_name: String, res: Vector2i, cam_pos: Vector3, up: Vector3) -> Dictionary:
	var vp := SubViewport.new()
	vp.name = view_name
	vp.size = res
	vp.own_world_3d = true                  # keeps the poster fish out of the pond
	vp.msaa_3d = Viewport.MSAA_4X            # smooth edges on stripes and spots
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = paper_color
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.42
	vp.add_child(cam)
	cam.position = cam_pos
	cam.look_at(Vector3.ZERO, up)
	var holder := Node3D.new()
	vp.add_child(holder)
	return {"viewport": vp, "camera": cam, "holder": holder}


func _viewport_material(vp: SubViewport) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = vp.get_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return mat


func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	return mat


func _quad(size: Vector2, pos: Vector3, mat: Material) -> void:
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.position = pos
	_board.add_child(mi)


func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	_board.add_child(mi)


func _wood(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat


func _label(text: String, height_m: float, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 128
	l.pixel_size = height_m / 128.0
	l.modulate = ink_color
	l.outline_size = 0
	l.position = pos + Vector3(0, 0, 0.005)
	_board.add_child(l)
	return l
