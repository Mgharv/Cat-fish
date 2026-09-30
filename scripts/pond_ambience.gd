extends Node3D
## POND AMBIENCE: relaxing water sounds, made in code (no sound files needed).
##  - a soft, slowly rising and falling water "lapping" sound all around
##  - gentle drips / bloops that pop up at random spots on the pond, in 3D
## To use a real recording instead, set `water_loop` to any looping audio file.

@export var water_loop: AudioStream     ## optional: your own looping water recording
@export var lapping_volume_db := -18.0
@export var drip_volume_db := -14.0
@export var drip_every_min := 1.5       ## seconds between drips (random in this range)
@export var drip_every_max := 5.0
@export var pond_radius := 6.0          ## where drips can happen (set by the pond)
@export var surface_y := -0.25

const RATE := 22050

var _drip_sound: AudioStreamWAV
var _drip_players: Array[AudioStreamPlayer3D] = []
var _next_drip := 0.0


func _ready() -> void:
	var lap := AudioStreamPlayer.new()
	lap.name = "Lapping"
	lap.stream = water_loop if water_loop else _make_lapping_loop(8.0)
	lap.volume_db = lapping_volume_db
	lap.autoplay = true
	add_child(lap)
	_drip_sound = _make_drip()
	for i in 3:   # a few players so drips can overlap
		var p := AudioStreamPlayer3D.new()
		p.stream = _drip_sound
		p.volume_db = drip_volume_db
		p.unit_size = 3.0
		add_child(p)
		_drip_players.append(p)
	_next_drip = randf_range(drip_every_min, drip_every_max)


func _process(delta: float) -> void:
	_next_drip -= delta
	if _next_drip > 0.0:
		return
	_next_drip = randf_range(drip_every_min, drip_every_max)
	for p in _drip_players:
		if not p.playing:
			var a := randf() * TAU
			var r := sqrt(randf()) * pond_radius
			p.position = Vector3(cos(a) * r, surface_y, sin(a) * r)
			p.pitch_scale = randf_range(0.75, 1.35)   # every drip sounds a bit different
			p.play()
			return


## Soft, low "brown" noise whose loudness swells slowly, like water lapping.
## The end fades into the start so it loops without a click.
func _make_lapping_loop(seconds: float) -> AudioStreamWAV:
	var n := int(RATE * seconds)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var brown := 0.0
	var smooth := 0.0
	for i in n:
		brown = clampf(brown * 0.995 + randf_range(-1.0, 1.0) * 0.05, -1.0, 1.0)  # rumbly noise
		smooth += (brown - smooth) * 0.08                                        # soften the hiss
		var t := float(i) / RATE
		var swell := 0.55 + 0.45 * sin(TAU * t / seconds * 2.0) * sin(TAU * t / seconds * 3.0 + 1.0)
		samples[i] = smooth * swell
	# crossfade the last second into the first, so the loop is seamless
	var fade := RATE
	for i in fade:
		var w := float(i) / fade
		samples[i] = samples[i] * w + samples[n - fade + i] * (1.0 - w)
	return _to_wav(samples.slice(0, n - fade), true)


## A short "bloop": a quick rising tone that fades out.
func _make_drip() -> AudioStreamWAV:
	var n := int(RATE * 0.18)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var freq := 500.0 + 1400.0 * t / 0.18       # pitch rises, like a water drop
		phase += TAU * freq / RATE
		samples[i] = sin(phase) * exp(-t * 28.0) * 0.8
	return _to_wav(samples, false)


func _to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var peak := 0.001
	for v in samples:
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(samples[i] / peak * 0.8 * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = samples.size()
	return wav
