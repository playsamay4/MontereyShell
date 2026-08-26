extends Node3D

var xr_interface : XRInterface

@export var left_controller: XRController3D
@export var right_controller: XRController3D

var lstick_hold_time := 0.0
var lstick_held := false

func _ready():
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		SystemLog.log("OpenXR initialized")
		xr_interface.render_target_size_multiplier = 1.4

		
		
		if left_controller:
			left_controller.button_pressed.connect(_on_left_button_pressed)
			left_controller.button_released.connect(_on_left_button_released) 
		if right_controller:
			right_controller.button_pressed.connect(_on_right_button_pressed)
		
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		
		get_viewport().use_xr = true
	else:
		SystemLog.log("OpenXR initialization failure")

func _process(delta):
	if lstick_held:
		lstick_hold_time += delta

		if lstick_hold_time >= 3.0:
			SystemLog.log("Left stick held for 3 seconds. triggering power options")
			SignalBus.start_system_view.emit("system_grid.power_off_dialog")

			# Prevent repeated firing
			lstick_held = false
			lstick_hold_time = 0.0

func _on_right_button_pressed(button_name: String) -> void:
	if button_name == "ax_button":
		if _is_holding_grip():
			SignalBus.restart_home_requested.emit()
	elif button_name == "by_button":
		if not _is_holding_grip():
			WindowManager.go_back(&"main")


func _on_left_button_pressed(button_name: String) -> void:
	if button_name == "ax_button":
		if _is_holding_grip():
			SignalBus.restart_home_requested.emit()
	if button_name == "by_button":
		if _is_holding_grip():
			WindowManager.open_app(&"main", "system.debug")
		else:
			WindowManager.go_back(&"main")
	elif button_name == "primary_click":
		lstick_held = true
		lstick_hold_time = 0.0


func _on_left_button_released(button_name: String) -> void:
	if button_name == "primary_click":
		lstick_held = false
		lstick_hold_time = 0.0
			
func _is_holding_grip() -> bool:
	var left_grip = left_controller.get_float("grip") if left_controller else 0.0
	var right_grip = right_controller.get_float("grip") if right_controller else 0.0
	return left_grip > 0.5 or right_grip > 0.5
