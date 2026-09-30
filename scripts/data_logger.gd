extends Node
## DATA LOGGER: writes one CSV row per pounce to user://logs/.
## On a laptop that's Godot's app-data folder (Project -> Open User Data Folder).
## On the Quest, pull it off with:  adb pull /sdcard/Android/data/<package>/files/logs

var _file: FileAccess
var path := ""


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://logs")
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	path = "user://logs/session_%s.csv" % stamp
	_file = FileAccess.open(path, FileAccess.WRITE)
	_file.store_csv_line(PackedStringArray(["time_s", "round", "target_species", "hit_species",
			"result", "points", "score", "search_time_s", "fish_depth_m"]))
	_file.flush()
	print("DataLogger|INFO: logging to ", ProjectSettings.globalize_path(path))


func log_row(values: Array) -> void:
	if _file == null:
		return
	var row := PackedStringArray()
	for v in values:
		row.append(str(v))
	_file.store_csv_line(row)
	_file.flush()   # write right away so nothing is lost if the game closes
