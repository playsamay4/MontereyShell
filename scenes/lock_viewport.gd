extends Node3D

@export var xr_camera: XRCamera3D 
@export var face_distance: float = 1.0

@export_group("Lazy Follow Settings")
## Degrees the user can look left/right before the UI rotates/centers laterally
@export var angle_leeway_degrees: float = 45.0
## Distance the user can move left/right before the UI catches up
@export var lateral_leeway: float = 0.5
## Distance the user can move forward/backward before the UI catches up (Tight)
@export var depth_leeway: float = 0.1
## Distance the user can move up/down before the UI catches up (Tight)
@export var vertical_leeway: float = 0.1

@export var follow_speed: float = 3.0

var _follow_horizontal: bool = false
var _follow_vertical: bool = false
var _follow_depth: bool = false

func _ready() -> void:
	if xr_camera:
		_snap_to_ideal()

func _process(delta: float) -> void:
	if not xr_camera:
		return
		
	# calculate the user's flat coordinate system
	var camera_forward: Vector3 = -xr_camera.global_transform.basis.z
	var flat_forward: Vector3 = Vector3(camera_forward.x, 0.0, camera_forward.z)
	
	if flat_forward.length_squared() < 0.01:
		var camera_up: Vector3 = xr_camera.global_transform.basis.y
		flat_forward = Vector3(camera_up.x, 0.0, camera_up.z)
		if camera_forward.y > 0: 
			flat_forward = -flat_forward
			
	flat_forward = flat_forward.normalized()
	var flat_right: Vector3 = flat_forward.cross(Vector3.UP).normalized()
	
	# measure exactly where the panel currently is relative to the head
	var head_to_panel: Vector3 = global_position - xr_camera.global_position
	var current_lateral: float = head_to_panel.dot(flat_right)
	var current_depth: float = head_to_panel.dot(flat_forward)
	var current_y: float = global_position.y
	
	# define where the panel ideally SHOULD be
	var ideal_lateral: float = 0.0
	var ideal_depth: float = face_distance
	var ideal_y: float = xr_camera.global_position.y
	
	var ideal_target_pos: Vector3 = xr_camera.global_position + (flat_forward * face_distance)
	ideal_target_pos.y = ideal_y
	
	var ideal_rotation_y: float = rotation.y
	var dir_to_camera: Vector3 = (xr_camera.global_position - ideal_target_pos).normalized()
	if dir_to_camera.length_squared() > 0.01:
		var target_basis: Basis = Basis.looking_at(dir_to_camera, Vector3.UP).rotated(Vector3.UP, PI)
		ideal_rotation_y = target_basis.get_euler().y

	var diff_angle: float = abs(angle_difference(rotation.y, ideal_rotation_y))
	
	# 4. Check if any independent deadzones have been breached
	if not _follow_horizontal and (abs(current_lateral) > lateral_leeway or diff_angle > deg_to_rad(angle_leeway_degrees)):
		_follow_horizontal = true
	if not _follow_depth and abs(current_depth - ideal_depth) > depth_leeway:
		_follow_depth = true
	if not _follow_vertical and abs(current_y - ideal_y) > vertical_leeway:
		_follow_vertical = true
		
	var target_lateral: float = ideal_lateral if _follow_horizontal else current_lateral
	var target_depth: float = ideal_depth if _follow_depth else current_depth
	var target_y: float = ideal_y if _follow_vertical else current_y
	var target_rotation_y: float = ideal_rotation_y if _follow_horizontal else rotation.y
	
	# reconstruct the final target position
	var target_position: Vector3 = xr_camera.global_position + (flat_right * target_lateral) + (flat_forward * target_depth)
	target_position.y = target_y
	
	global_position = global_position.lerp(target_position, follow_speed * delta)
	rotation.y = lerp_angle(rotation.y, target_rotation_y, follow_speed * delta)
	
	# stop confditions
	if _follow_horizontal and abs(current_lateral) < 0.05 and diff_angle < 0.05:
		_follow_horizontal = false
	if _follow_depth and abs(current_depth - ideal_depth) < 0.05:
		_follow_depth = false
	if _follow_vertical and abs(current_y - ideal_y) < 0.05:
		_follow_vertical = false

func _snap_to_ideal() -> void:
	var camera_forward: Vector3 = -xr_camera.global_transform.basis.z
	var flat_forward: Vector3 = Vector3(camera_forward.x, 0.0, camera_forward.z).normalized()
	
	global_position = xr_camera.global_position + (flat_forward * face_distance)
	global_position.y = xr_camera.global_position.y
	
	var dir_to_camera: Vector3 = (xr_camera.global_position - global_position).normalized()
	var target_basis: Basis = Basis.looking_at(dir_to_camera, Vector3.UP).rotated(Vector3.UP, PI)
	rotation.y = target_basis.get_euler().y
