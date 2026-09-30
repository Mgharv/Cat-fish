extends SceneTree
## Renders every species in res://species/ from three views (side, top, cat's-eye 45°)
## into res://species/renders/. Run from the project folder:
##   godot --path . -s tools/render_species_sheet.gd
const VIEWS := {
	"side": [Vector3(-2, 0, 0), Vector3.UP],
	"top": [Vector3(0, 2, 0), Vector3.RIGHT],
	"cats_eye": [Vector3(-1.414, 1.414, 0), Vector3.UP],
}

func _initialize():
	DirAccess.make_dir_recursive_absolute("res://species/renders")
	var vp := SubViewport.new()
	vp.size = Vector2i(640, 400)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.WHITE
	var we := WorldEnvironment.new(); we.environment = env
	vp.add_child(we)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.42
	vp.add_child(cam)
	for i in 10: await process_frame  # let shaders compile first
	for f in DirAccess.get_files_at("res://species"):
		if not f.ends_with(".tres"): continue
		var sp: FishSpecies = load("res://species/" + f)
		var fish := FishBuilder.build(sp)
		vp.add_child(fish)
		for view in VIEWS:
			cam.position = VIEWS[view][0]
			cam.look_at(Vector3.ZERO, VIEWS[view][1])
			cam.size = maxf(0.42, sp.body_length * 1.15)
			for i in 4: await process_frame
			vp.get_texture().get_image().save_png("res://species/renders/%s_%s.png" % [f.get_basename(), view])
		fish.queue_free()
		await process_frame
	print("species renders done")
	quit()
