extends Node3D

@export var xr_camera: XRCamera3D 

@export var face_distance: float = 1

func _process(_delta: float) -> void:
	if not xr_camera:
		return
		
	
	global_position = xr_camera.global_position
	
	
	var camera_forward: Vector3 = -xr_camera.global_transform.basis.z
	var flat_forward: Vector3 = Vector3(0.0, 0.0, camera_forward.z).normalized()
	
	
	global_position += flat_forward * face_distance
	
	
	var look_target: Vector3 = xr_camera.global_position
	look_target.y = global_position.y
	
	look_at(look_target, Vector3.UP)
	rotate_y(PI)
