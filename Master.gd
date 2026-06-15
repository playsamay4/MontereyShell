extends Node3D

@onready var left_hand = %LeftController
@onready var right_hand = %RightController
@onready var viewport : Viewport = get_viewport()
@onready var environment : Environment = $WorldEnvironment.environment

@export var target_scene_path: String = "res://scenes/QuestHome.tscn"
@onready var world_container: Node3D = $WorldContainer

var is_loading: bool = false
var sequence_finished: bool = false
var loaded_resource: PackedScene = null

var skip_boot = false

func _ready() -> void:
	_start_background_load()

	# OpenXR setup
	var xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		xr_interface.pose_recentered.connect(_on_xr_pose_recentered)
		switch_to_vr()
	
	_hide_controller_models()

	SignalBus.switch_to_ar.connect(switch_to_ar)
	SignalBus.switch_to_vr.connect(switch_to_vr)
	SignalBus.restart_home_requested.connect(restart_quest_home)
	
	SignalBus.fade_in_scene.connect(_fade_in_scene)
	SignalBus.fade_out_scene.connect(_fade_out_scene)
	
	SignalBus.controller_show_lasers.connect(_show_controller_lasers)
	SignalBus.controller_hide_lasers.connect(_hide_controller_lasers)
	SignalBus.controller_show_model.connect(_show_controller_models)
	SignalBus.controller_hide_model.connect(_hide_controller_models)
	
	if skip_boot:
		print("skipping boot sequence")
		%OculusLogo.hide()
		
		while is_loading or not loaded_resource:
			await get_tree().process_frame
			
		_finalize_scene_swap()
		return # skip intro 
	

	await get_tree().create_timer(3).timeout
	$AnimationPlayer.play("new_animation")
	$AudioStreamPlayer.play(0)
	
	await get_tree().create_timer(5).timeout
	print("ready to load")
	
	%OculusLogo.hide()
	await get_tree().create_timer(0.6).timeout
	
	%LoadingDots.show()
	$AnimationPlayer.play("fade_in_loading_dots")

	await get_tree().create_timer(2.0).timeout
	
	while is_loading or not loaded_resource:
		await get_tree().process_frame
	
	_finalize_scene_swap()

func _start_background_load() -> void:
	is_loading = true
	# use_sub_threads=true offload file parsing completely to another CPU core
	var error = ResourceLoader.load_threaded_request(target_scene_path, "", true)
	if error != OK:
		print("Background thread initialization failure")

func _process(_delta: float) -> void:
	if not is_loading:
		return
		
	var progress = []
	var status = ResourceLoader.load_threaded_get_status(target_scene_path, progress)
	
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			is_loading = false
			loaded_resource = ResourceLoader.load_threaded_get(target_scene_path)
				
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			print("questhome background load failure")
			is_loading = false

func _finalize_scene_swap() -> void:
	if not loaded_resource:
		return
		
	var new_scene_instance = loaded_resource.instantiate()
	
	for child in world_container.get_children():
		child.queue_free()
		
	world_container.add_child(new_scene_instance)
	print("questhome loaded")

	%LoadingDots.hide()
	_show_controller_lasers()
	_show_controller_models()
	

func restart_quest_home() -> void:
	if is_loading:
		print("already loading a scene, ignore restart request")
		return
		
	print("questhome restart")
	is_loading = true
	loaded_resource = null 
	
	%LoadingDots.show()
	_hide_controller_lasers()
	_hide_controller_models()
	environment.sky.sky_material.energy_multiplier = 0
	
	for child in world_container.get_children():
		child.queue_free()
		
	var error = ResourceLoader.load_threaded_request(target_scene_path, "", true)
	if error != OK:
		print("Restart thread initialization failure")
		is_loading = false
		return
		
	while is_loading or not loaded_resource:
		await get_tree().process_frame
		
	_finalize_scene_swap()


func switch_to_ar() -> bool:
	var success = false
	var xr_interface: XRInterface = XRServer.primary_interface
	if xr_interface:
		var modes = xr_interface.get_supported_environment_blend_modes()
		if XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND in modes:
			xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
			viewport.transparent_bg = true
			_hide_controller_models()
			success = true
		elif XRInterface.XR_ENV_BLEND_MODE_ADDITIVE in modes:
			xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ADDITIVE
			viewport.transparent_bg = false
			_hide_controller_models()
			success = true
			
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0) 
	
	
	return success

func switch_to_vr() -> bool:
	var success = false
	var xr_interface: XRInterface = XRServer.primary_interface
	if xr_interface:
		var modes = xr_interface.get_supported_environment_blend_modes()
		if XRInterface.XR_ENV_BLEND_MODE_OPAQUE in modes:
			xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_OPAQUE
			_show_controller_models()
			success = true
			
	viewport.transparent_bg = false

	environment.background_mode = Environment.BG_SKY
	environment.background_color = Color(0,0,0,1)
	
	
	return success
func _on_xr_pose_recentered() -> void:
	XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)
	
func _show_controller_models():
	%LeftController/OpenXRFbRenderModel.show()
	%RightController/OpenXRFbRenderModel.show()
	
func _hide_controller_models():
	%LeftController/OpenXRFbRenderModel.hide()
	%RightController/OpenXRFbRenderModel.hide()
	
func _show_controller_lasers():
	left_hand.laser_mesh.show()
	right_hand.laser_mesh.show()
	
func _hide_controller_lasers():
	left_hand.laser_mesh.hide()
	right_hand.laser_mesh.hide()
	
func _begin_scene_light_change() -> void:
	if environment:
		environment.sky.process_mode = environment.sky.PROCESS_MODE_REALTIME
		
func _end_scene_light_change() -> void:
	if environment:
		environment.sky.process_mode = environment.sky.PROCESS_MODE_AUTOMATIC
	
func _fade_in_scene() -> void:
	_begin_scene_light_change()
	$SceneLightingAnimationPlayer.play("scene_fade_in")
	await $SceneLightingAnimationPlayer.animation_finished
	_end_scene_light_change()
	SignalBus.fade_in_scene_finished.emit()
	
func _fade_out_scene() -> void:
	_begin_scene_light_change()
	$SceneLightingAnimationPlayer.play("scene_fade_black")
	await $SceneLightingAnimationPlayer.animation_finished
	_end_scene_light_change()
	SignalBus.fade_out_scene_finished.emit()
	
	
