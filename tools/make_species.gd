extends SceneTree
# Creates (or re-creates) every species file in res://species/.
# Run from the project folder:  godot --headless --path . -s tools/make_species.gd
# Edit the lists below to add species; each is just a name + the settings that differ
# from the plain base fish (silver Darter, forked tail, no pattern).

const SILVER := {}
const ORANGE := {"body_color": Color(0.95, 0.55, 0.15), "fin_color": Color(0.98, 0.72, 0.42)}
const BLUE := {"body_color": Color(0.2, 0.42, 0.85), "fin_color": Color(0.5, 0.65, 0.93)}
const YELLOW := {"body_color": Color(0.95, 0.83, 0.2), "fin_color": Color(0.98, 0.9, 0.55)}
const ROUND := {"body_height": 0.45}
const LONG := {"body_length": 0.49, "body_height": 0.21, "body_width": 0.10}
const FAN := {"tail_type": 1}
const SPOTS := {"pattern": 1, "pattern_frequency": 3.0, "pattern_size": 0.6}
const BANDS := {"pattern": 2, "pattern_frequency": 2.0, "pattern_size": 0.3}
const STRIPES := {"pattern": 3, "pattern_frequency": 14.0, "pattern_size": 0.4}
const SPECKLES := {"pattern": 4, "pattern_frequency": 28.0, "pattern_size": 0.6}

func _mk(file: String, name: String, parts: Array) -> void:
	var s := FishSpecies.new()
	s.display_name = name
	for part in parts:
		for k in part: s.set(k, part[k])
	print(file, " ", ResourceSaver.save(s, "res://species/" + file))

func _initialize():
	# Tier 1: colour + coarse shape
	_mk("01_orange_roundfish.tres", "Orange Roundfish", [ORANGE, ROUND])
	_mk("02_blue_darter.tres", "Blue Darter", [BLUE])
	_mk("03_yellow_longfish.tres", "Yellow Longfish", [YELLOW, LONG])
	# Tier 2: medium features on the silver base
	_mk("04_spotted_darter.tres", "Spotted Darter", [SPOTS])
	_mk("05_fantail_darter.tres", "Fantail Darter", [FAN])
	_mk("06_banded_darter.tres", "Banded Darter", [BANDS])
	# Tier 3: fine detail only on the silver base
	_mk("07_pinstripe_darter.tres", "Pinstripe Darter", [STRIPES])
	_mk("08_speckled_darter.tres", "Speckled Darter", [SPECKLES])
	_mk("09_plain_darter.tres", "Plain Darter", [SILVER])
	# Combinations: each shares its colour with some species and its pattern/shape
	# with others, so no single feature gives the target away (a "conjunction" search).
	_mk("10_blue_spotted_darter.tres", "Blue Spotted Darter", [BLUE, SPOTS])
	_mk("11_orange_spotted_darter.tres", "Orange Spotted Darter", [ORANGE, SPOTS])
	_mk("12_yellow_spotted_darter.tres", "Yellow Spotted Darter", [YELLOW, SPOTS])
	_mk("13_blue_banded_darter.tres", "Blue Banded Darter", [BLUE, BANDS])
	_mk("14_orange_banded_roundfish.tres", "Orange Banded Roundfish", [ORANGE, ROUND, BANDS])
	_mk("15_yellow_banded_darter.tres", "Yellow Banded Darter", [YELLOW, BANDS])
	_mk("16_blue_pinstripe_darter.tres", "Blue Pinstripe Darter", [BLUE, STRIPES])
	_mk("17_orange_pinstripe_darter.tres", "Orange Pinstripe Darter", [ORANGE, STRIPES])
	_mk("18_yellow_pinstripe_longfish.tres", "Yellow Pinstripe Longfish", [YELLOW, LONG, STRIPES])
	_mk("19_silver_spotted_roundfish.tres", "Silver Spotted Roundfish", [ROUND, SPOTS])
	_mk("20_silver_banded_roundfish.tres", "Silver Banded Roundfish", [ROUND, BANDS])
	_mk("21_blue_fantail_darter.tres", "Blue Fantail Darter", [BLUE, FAN])
	quit()
