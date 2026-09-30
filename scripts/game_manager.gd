extends Node
## GAME MANAGER: runs the rounds and judges every swat.
##  - picks a WANTED species and shows it on the wanted poster
##  - right species: + points, a new wanted species
##  - wrong species: - points, that fish darts away
##  - every pounce is written to the data log
## It only listens to the pond ("a fish was swatted") and pounces ("I missed").

@export var pond: Node3D                ## the pond
@export var points_right := 10
@export var points_wrong := -5
@export var min_targets_in_pond := 2    ## always at least this many wanted fish swimming
@export var poster_height := 1.7        ## height of the wanted poster in the middle of the ring

var score := 0
var round_number := 0
var target: FishSpecies
var _round_started := 0.0
var _poster: Node3D
var _logger: Node
var _beep_right: AudioStreamPlayer
var _beep_wrong: AudioStreamPlayer

const DataLogger := preload("res://scripts/data_logger.gd")
const WantedPoster := preload("res://scripts/wanted_poster.gd")


func _ready() -> void:
	if pond == null:
		push_error("GameManager|ERROR: assign the pond in the Inspector")
		return
	pond.fish_swatted.connect(_on_fish_swatted)
	_logger = DataLogger.new()
	_logger.name = "DataLogger"
	add_child(_logger)
	_poster = WantedPoster.new()
	_poster.name = "WantedPoster"
	_poster.position = Vector3(0, poster_height, 0)   # set before adding, so its post reaches the floor
	pond.add_child(_poster)
	_beep_right = _make_beep(880.0, 0.15)
	_beep_wrong = _make_beep(220.0, 0.25)
	# wait one frame so the pond has spawned its fish (and desktop mode has started), then start
	await get_tree().process_frame
	_listen_for_misses()
	_new_round()


## Pounces (VR) and clicks (desktop) that hit a fish reach us through the pond.
## Here we also listen for the ones that hit nothing, so misses get logged.
func _listen_for_misses() -> void:
	for n in get_tree().current_scene.find_children("*", "", true, false):
		if n.has_signal("pounced"):            # a VR Pounce node
			n.pounced.connect(func(_pos, fish): if fish == null: on_pounce_missed())
		elif n.name == "DesktopFallback":      # desktop-mode clicking
			n.swatted.connect(func(_pos, collider): if collider == null: on_pounce_missed())


func _new_round() -> void:
	round_number += 1
	var choices: Array = pond.species_mix
	if choices.is_empty():
		push_warning("GameManager|WARN: the pond has no species_mix, so there is nothing to hunt")
		return
	var previous := target
	while target == previous and choices.size() > 1:
		target = choices.pick_random()
	if choices.size() == 1:
		target = choices[0]
	pond.ensure_species(target, min_targets_in_pond)
	_round_started = _now()
	_poster.show_target(target, score)


func _on_fish_swatted(fish) -> void:
	var correct: bool = fish.species == target
	var points := points_right if correct else points_wrong
	score += points
	_popup(fish.global_position, ("+%d" % points) if correct else ("%d" % points), correct)
	(_beep_right if correct else _beep_wrong).play()
	_logger.log_row([snappedf(_now(), 0.01), round_number, _name(target), _name(fish.species),
			"right" if correct else "wrong", points, score,
			snappedf(_now() - _round_started, 0.01), snappedf(pond.surface_y - fish.position.y, 0.01)])
	if correct:
		pond.replace_fish(fish)
		_new_round()
	else:
		fish.startle()
		_poster.set_score(score)


## Pounces that hit nothing are logged too (they cost no points).
func on_pounce_missed() -> void:
	_logger.log_row([snappedf(_now(), 0.01), round_number, _name(target), "", "miss", 0, score,
			snappedf(_now() - _round_started, 0.01), ""])


# ---------- display ----------

## A "+10" / "-5" that floats up from the fish and fades away.
func _popup(where: Vector3, text: String, good: bool) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 72
	label.pixel_size = 0.003
	label.outline_size = 14
	label.modulate = Color(0.4, 1.0, 0.45) if good else Color(1.0, 0.35, 0.3)
	label.no_depth_test = true   # visible even though it starts under the water
	get_tree().current_scene.add_child(label)
	label.global_position = where + Vector3(0, 0.3, 0)
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "global_position:y", where.y + 1.2, 1.0)
	tw.tween_property(label, "modulate:a", 0.0, 1.0)
	tw.chain().tween_callback(label.queue_free)


## A short generated tone, so no sound files are needed yet.
func _make_beep(freq: float, seconds: float) -> AudioStreamPlayer:
	var rate := 22050
	var n := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var env := minf(1.0, float(n - i) / (rate * 0.05))   # fade out at the end
		var v := int(sin(TAU * freq * i / rate) * 0.35 * env * 32767.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	var player := AudioStreamPlayer.new()
	player.stream = wav
	add_child(player)
	return player


func _name(sp: FishSpecies) -> String:
	return sp.display_name if sp else "original fish"


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
