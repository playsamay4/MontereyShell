extends Node3D

var xr_interface : XRInterface

@export var left_controller: XRController3D
@export var right_controller: XRController3D

func _ready():
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		print("OpenXR initialized")
		
		if left_controller:
			left_controller.button_pressed.connect(_on_button_pressed)
		if right_controller:
			right_controller.button_pressed.connect(_on_button_pressed)
		
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		
		get_viewport().use_xr = true
	else:
		print("OpenXR initialization failure")

func _on_button_pressed(button_name: String) -> void:
	if button_name == "ax_button":
		if _is_holding_grip():
			SignalBus.restart_home_requested.emit()
			
			
func _is_holding_grip() -> bool:
	var left_grip = left_controller.get_float("grip") if left_controller else 0.0
	var right_grip = right_controller.get_float("grip") if right_controller else 0.0
	return left_grip > 0.5 or right_grip > 0.5
