extends Node3D

## Lazily follows the XR camera so a panel stays in view without being
## rigidly welded to the user's head. Drives target_node if set, or self.

@export var xr_camera: XRCamera3D
@export var face_distance: float = 1.0

## When set, this script positions target_node instead of the node it's
## attached to. Leave unset to behave exactly as before (drive self).
@export var target_node: Node3D = null

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


func _get_target() -> Node3D:
	return target_node if target_node else self


func _process(delta: float) -> void:
	if not xr_camera:
		return

	var node: Node3D = _get_target()

	# calculate the user's flat coordinate system
	var camera_forward: Vector3 = -xr_camera.global_transform.basis.z
	var flat_forward: Vector3 = Vector3(camera_forward.x, 0.0, camera_forward.z)

	if flat_forward.length_squared() < 0.01:
		var camera_up: Vector3 = xr_camera.global_transform.basis.y
		flat_forward = Vector3(camera_up.x, 0.0, camera_up.z)
		if camera_forward.y > 0.0:
			flat_forward = -flat_forward

	flat_forward = flat_forward.normalized()
	var flat_right: Vector3 = flat_forward.cross(Vector3.UP).normalized()

	# measure exactly where the panel currently is relative to the head
	var head_to_panel: Vector3 = node.global_position - xr_camera.global_position
	var current_lateral: float = head_to_panel.dot(flat_right)
	var current_depth: float = head_to_panel.dot(flat_forward)
	var current_y: float = node.global_position.y

	# define where the panel ideally SHOULD be
	var ideal_lateral: float = 0.0
	var ideal_depth: float = face_distance
	var ideal_y: float = xr_camera.global_position.y

	var ideal_target_pos: Vector3 = xr_camera.global_position + (flat_forward * face_distance)
	ideal_target_pos.y = ideal_y

	var dir_to_camera: Vector3 = -flat_forward
	var target_basis: Basis = Basis.looking_at(dir_to_camera, Vector3.UP).rotated(Vector3.UP, PI)
	var ideal_rotation_y: float = target_basis.get_euler().y

	var diff_angle: float = absf(angle_difference(node.rotation.y, ideal_rotation_y))

	# 4. Check if any independent deadzones have been breached
	if not _follow_horizontal and (absf(current_lateral) > lateral_leeway or diff_angle > deg_to_rad(angle_leeway_degrees)):
		_follow_horizontal = true
	if not _follow_depth and absf(current_depth - ideal_depth) > depth_leeway:
		_follow_depth = true
	if not _follow_vertical and absf(current_y - ideal_y) > vertical_leeway:
		_follow_vertical = true

	var target_lateral: float = ideal_lateral if _follow_horizontal else current_lateral
	var target_depth: float = ideal_depth if _follow_depth else current_depth
	var target_y: float = ideal_y if _follow_vertical else current_y
	var target_rotation_y: float = ideal_rotation_y if _follow_horizontal else node.rotation.y

	# reconstruct the final target position
	var target_position: Vector3 = xr_camera.global_position + (flat_right * target_lateral) + (flat_forward * target_depth)
	target_position.y = target_y

	node.global_position = node.global_position.lerp(target_position, follow_speed * delta)
	node.rotation.y = lerp_angle(node.rotation.y, target_rotation_y, follow_speed * delta)

	# stop conditions
	if _follow_horizontal and absf(current_lateral) < 0.05 and diff_angle < 0.05:
		_follow_horizontal = false
	if _follow_depth and absf(current_depth - ideal_depth) < 0.05:
		_follow_depth = false
	if _follow_vertical and absf(current_y - ideal_y) < 0.05:
		_follow_vertical = false


func _snap_to_ideal() -> void:
	var node: Node3D = _get_target()
	var camera_forward: Vector3 = -xr_camera.global_transform.basis.z
	var flat_forward: Vector3 = Vector3(camera_forward.x, 0.0, camera_forward.z).normalized()

	node.global_position = xr_camera.global_position + (flat_forward * face_distance)
	node.global_position.y = xr_camera.global_position.y

	var dir_to_camera: Vector3 = -flat_forward
	var target_basis: Basis = Basis.looking_at(dir_to_camera, Vector3.UP).rotated(Vector3.UP, PI)
	node.rotation.y = target_basis.get_euler().y


func go_float(p_xr_camera: XRCamera3D) -> void:
	xr_camera = p_xr_camera
	_follow_horizontal = false
	_follow_vertical = false
	_follow_depth = false
	if xr_camera:
		_snap_to_ideal()


func go_static(p_transform: Transform3D) -> void:
	xr_camera = null
	_get_target().transform = p_transform
