extends SceneTree
# Creates the starting species files in res://species/
func _mk(file: String, name: String, props: Dictionary) -> void:
	var s := FishSpecies.new()
	s.display_name = name
	for k in props: s.set(k, props[k])
	print(file, " ", ResourceSaver.save(s, "res://species/" + file))
func _initialize():
	var P = FishSpecies.Pattern
	_mk("01_orange_roundfish.tres", "Orange Roundfish", {"body_height": 0.45, "body_color": Color(0.95, 0.55, 0.15), "fin_color": Color(0.98, 0.72, 0.42)})
	_mk("02_blue_darter.tres", "Blue Darter", {"body_color": Color(0.2, 0.42, 0.85), "fin_color": Color(0.5, 0.65, 0.93)})
	_mk("03_yellow_longfish.tres", "Yellow Longfish", {"body_length": 0.49, "body_height": 0.21, "body_width": 0.10, "body_color": Color(0.95, 0.83, 0.2), "fin_color": Color(0.98, 0.9, 0.55)})
	_mk("04_spotted_darter.tres", "Spotted Darter", {"pattern": P.SPOTS, "pattern_frequency": 3.0, "pattern_size": 0.6})
	_mk("05_fantail_darter.tres", "Fantail Darter", {"tail_type": FishSpecies.Tail.FAN})
	_mk("06_banded_darter.tres", "Banded Darter", {"pattern": P.BANDS, "pattern_frequency": 2.0, "pattern_size": 0.3})
	_mk("07_pinstripe_darter.tres", "Pinstripe Darter", {"pattern": P.STRIPES, "pattern_frequency": 24.0, "pattern_size": 0.3})
	_mk("08_speckled_darter.tres", "Speckled Darter", {"pattern": P.SPECKLES, "pattern_frequency": 45.0, "pattern_size": 0.45})
	_mk("09_plain_darter.tres", "Plain Darter", {})
	quit()
