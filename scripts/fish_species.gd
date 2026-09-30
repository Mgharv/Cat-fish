extends Resource
class_name FishSpecies
## One fish species = a set of numbers. Every species is built from the same base,
## so species differ ONLY in the settings you change here.
##
## Spatial-frequency scales:
##   COARSE  -> body_length, body_height, body_width (silhouette, size)
##   MEDIUM  -> tail_type, SPOTS, BANDS
##   FINE    -> STRIPES, SPECKLES (pattern_frequency = how fine)

enum Tail { FORKED, FAN }
enum Pattern { NONE, SPOTS, BANDS, STRIPES, SPECKLES }

@export var display_name := "Plain Darter"

@export_group("Coarse: body shape")
@export var body_length := 0.35         ## metres, nose to tail tip
@export var body_height := 0.30         ## height as a fraction of length (side view)
@export var body_width := 0.13          ## width as a fraction of length (top view; fish are slim)

@export_group("Medium: fins")
@export var tail_type := Tail.FORKED

@export_group("Colour")
@export var body_color := Color(0.62, 0.64, 0.66)   ## silver-grey
@export var fin_color := Color(0.78, 0.79, 0.80)

@export_group("Pattern")
@export var pattern := Pattern.NONE
@export var pattern_color := Color(0.18, 0.19, 0.21)
@export var pattern_frequency := 3.0    ## SPOTS/BANDS: how many. STRIPES: stripes around the body. SPECKLES: dots per body length
@export_range(0.05, 0.9) var pattern_size := 0.5  ## spot/band/stripe thickness (fraction of one repeat)
