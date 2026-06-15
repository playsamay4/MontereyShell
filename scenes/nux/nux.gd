extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var xr_interface = XRServer.find_interface("OpenXR")
	
	
	if xr_interface:
		xr_interface.pose_recentered.connect(_on_xr_pose_recentered)



func _on_xr_pose_recentered() -> void:
	XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
