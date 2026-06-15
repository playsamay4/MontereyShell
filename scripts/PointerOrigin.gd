extends Node3D

#@onready var raycast: RayCast3D = $RayCast3D
@onready var laser_mesh: MeshInstance3D = $LaserMesh

@export var max_laser_length: float = 0.5

func _process(_delta: float) -> void:
	#if raycast.is_colliding():
		##  distance to the target panel
		#var collision_point = raycast.get_collision_point()
		#var distance = global_position.distance_to(collision_point)
		#
		#laser_mesh.mesh.height = distance
		#
	
		#laser_mesh.position = Vector3(0, 0, -distance / 2.0)
	#else:
		laser_mesh.mesh.height = max_laser_length
		laser_mesh.position = Vector3(0, 0, -max_laser_length / 2.0)
