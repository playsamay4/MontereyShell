extends XRController3D

@export_enum("left", "right") var hand_side: String = "none"

@export var blue_material : Material = preload("res://materials/reticle_blue.tres")
@export var blue_ray : Material = preload("res://materials/ray_blue.tres")

var original_material_reticle : Material
var target_mesh_node_reticle : MeshInstance3D

var original_material_laser : Material 

@onready var function_pointer
@onready var laser_mesh = $PointerOrigin/LaserMesh

func _ready():
	await get_tree().process_frame
	if hand_side == "left":
		function_pointer = $LeftFunctionPointer
	elif hand_side == "right":
		function_pointer = $RightFunctionPointer
	
	if function_pointer:

		target_mesh_node_reticle = function_pointer.find_child("Target", true, false) as MeshInstance3D
		
		if target_mesh_node_reticle:
			original_material_reticle = target_mesh_node_reticle.material_override
			
	if laser_mesh:
		original_material_laser = laser_mesh.material_override
	
	button_pressed.connect(_on_button_pressed)
	button_released.connect(_on_button_released)
	
	SignalBus.controller_trigger_haptic.connect(_on_trigger_haptic)

#func enable_controller():
	#$FunctionPointer.enabled = true
	#$PointerOrigin/LaserMesh.visible = true
	#
#func disable_controller():
	#$FunctionPointer.enabled = false
	#$PointerOrigin/LaserMesh.visible = false

func _on_trigger_haptic(target_hand: String, amplitude: float, duration: float) -> void:
	if target_hand == hand_side:
		# trigger_haptic_pulse(action_name, frequency, amplitude, duration, delay)
		trigger_haptic_pulse("haptic", 0.0, amplitude, duration, 0.0)


func _on_button_pressed(action_name: String):
	
	if action_name.ends_with("_touch") == false:
		SignalBus.controller_button_pressed.emit(hand_side, action_name)
	
	
	if action_name == "trigger_click":
		# Swap the reticle to blue
		SignalBus.controller_press_sound.emit()
		
		SignalBus.controller_trigger_pressed.emit(hand_side)
		
		if target_mesh_node_reticle:
			target_mesh_node_reticle.material_override = blue_material
		
		if laser_mesh:
			laser_mesh.material_override = blue_ray

func _on_button_released(action_name: String):
	if action_name.ends_with("_touch") == false:
		SignalBus.controller_button_released.emit(hand_side, action_name)
	if action_name == "trigger_click":
		
		#_on_trigger_haptic(hand_side, 0.8, 0.1)
		
		if target_mesh_node_reticle:
			target_mesh_node_reticle.material_override = original_material_reticle
			
		if laser_mesh:
			laser_mesh.material_override = original_material_laser
