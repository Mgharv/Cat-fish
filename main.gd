## TEMPLATE FILE ############################
# This file is the main script that enables the central workings of XR in Godot.
# This file specifically hinges on the fact that Godot propagates _ready() signals
# up through children, so all things are done in order.
#############################################

extends Node3D
var xr_interface: OpenXRInterface

## Preferred refresh rate. Will fallback to what the headset reports
@export var target_refresh_rate := 72.0

## Tick this to play on the laptop screen even when a headset is plugged in.
## (You can also launch with the user argument `--desktop`.)
@export var force_desktop_mode := false

const DesktopFallbackScript := preload("res://scripts/desktop_fallback.gd")

func _ready() -> void:

	if force_desktop_mode or "--desktop" in OS.get_cmdline_user_args():
		print("Main|INFO: desktop mode forced")
		_start_desktop_mode()
		return

	# First, we get the current xr_interface. This is defined in the settings, and if undefined, you likely
	# have not enalbed XR in settings.
	xr_interface = XRServer.find_interface("OpenXR") as OpenXRInterface
	if xr_interface == null:
		push_warning("Main|WARN: OpenXR interface not found (check Project Settings -> XR). Starting desktop mode.")
		_start_desktop_mode()
		return

	# Here we check if the xr interface *is* setup but not initialized. This indicates the device is ready to use a headset,
	# but there is no detected/connected headset.
	if not xr_interface.is_initialized() and not xr_interface.initialize():
		push_warning("Main|WARN: OpenXR failed to initialise (no headset?). Starting desktop mode.")
		_start_desktop_mode()
		return

	print("Main|INFO: OpenXR initialised successfully")

	# XR runtime frame pacing
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	get_viewport().use_xr = true

	xr_interface.session_begun.connect(_on_session_begun)


func _on_session_begun() -> void:
	var rates := xr_interface.get_available_display_refresh_rates()
	if target_refresh_rate in rates:
		xr_interface.display_refresh_rate = target_refresh_rate
	elif not rates.is_empty():
		print("Main|WARN: %s Hz unavailable, runtime offers %s" % [target_refresh_rate, rates])

	# Match physics to the actual rate.
	var actual: float = xr_interface.display_refresh_rate
	if actual > 0.0:
		Engine.physics_ticks_per_second = int(round(actual))
	print("Main|INFO: running at %s Hz" % Engine.physics_ticks_per_second)


## No headset: add a mouse + keyboard player so the scene is still playable.
func _start_desktop_mode() -> void:
	var fallback := DesktopFallbackScript.new()
	fallback.name = "DesktopFallback"
	add_child(fallback)
