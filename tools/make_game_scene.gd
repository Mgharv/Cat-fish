extends SceneTree
# Builds res://game.tscn: the VR rig from main.tscn (controllers, hands, movement,
# passthrough) + the pond, bridge walking, game manager and pounce.
func _initialize():
	var game: Node3D = load("res://main.tscn").instantiate()
	game.name = "Game"
	for n in game.get_children():
		var keep := ["XROrigin3D", "WorldEnvironment", "SunLight", "Passthrough"]
		if not keep.has(str(n.name)):
			game.remove_child(n); n.free()
	var nothing_to_hide: Array[NodePath] = []   # the floor/table it used to hide are gone
	game.get_node("Passthrough").hide_in_passthrough = nothing_to_hide
	var pond = load("res://pond.tscn").instantiate()
	game.add_child(pond); pond.owner = game
	var bw := Node.new(); bw.name = "BridgeWalk"; bw.set_script(load("res://scripts/bridge_walk.gd"))
	game.add_child(bw); bw.owner = game
	bw.player = game.get_node("XROrigin3D"); bw.pond = pond
	var gm := Node.new(); gm.name = "GameManager"; gm.set_script(load("res://scripts/game_manager.gd"))
	game.add_child(gm); gm.owner = game
	gm.pond = pond
	for side in ["XRControllerLeft", "XRControllerRight"]:
		var p := Node3D.new(); p.name = "Pounce"; p.set_script(load("res://scripts/pounce.gd"))
		var c = game.get_node("XROrigin3D/" + side)
		c.add_child(p); p.owner = game
	var ps := PackedScene.new(); print("pack ", ps.pack(game))
	print("save ", ResourceSaver.save(ps, "res://game.tscn"))
	quit()
