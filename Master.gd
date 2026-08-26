extends Node3D

@onready var left_hand = %LeftController
@onready var right_hand = %RightController
@onready var viewport : Viewport = get_viewport()
@onready var environment : Environment = $WorldEnvironment.environment
@onready var locked_viewport = %LockedViewport
@onready var locked_viewport_parent = %LockedViewportParent
@onready var master_camera_fade = %MasterCameraFade

@onready var system_view = %SystemView
@onready var system_view_locked_viewport = %SystemViewLockedViewport

@export var target_scene_path: String = "res://scenes/QuestHome.tscn"
@onready var world_container: Node3D = %WorldContainer

@onready var video_screen: XRVideoPlayerQuad = %XRVideoPlayerQuad


var original_bg_mode: Environment.BGMode
var original_bg_color: Color
var is_in_system_view: bool = false
var system_view_prev_controller_laser_state: bool = false

var is_loading: bool = false
var sequence_finished: bool = false
var loaded_resource: PackedScene = null

var controller_lasers_showing: bool = false


var skip_boot = true

func _clear_world_container() -> void:
	for child in world_container.get_children():
		child.queue_free()

func _evaluate_boot_settings() -> void:
	var nuxStatus = SettingsManager.get_value("settings", "nuxStatus")
	if nuxStatus != SettingsManager.NUX_STATUS.NUX_COMPLETE:
		skip_boot = true
		SystemLog.log("NUX STATUS is %s",  SettingsManager.NUX_STATUS_NAME[nuxStatus])
	else:
		skip_boot = not SettingsManager.get_value("settings", "experimentUseBootSequence")


func _run_boot_sequence() -> void:
	_start_background_load()
	
	if skip_boot:
		SystemLog.log("skipping boot sequence")
		%OculusLogo.hide()
		
		while is_loading or not loaded_resource:
			await get_tree().process_frame
			
		_handle_post_boot_flow()
		return

	await get_tree().create_timer(3).timeout
	$AnimationPlayer.play("new_animation")
	UiAudioManager.play_boot_sound()
	
	await get_tree().create_timer(5).timeout
	SystemLog.log("ready to load")
	
	%OculusLogo.hide()
	await get_tree().create_timer(0.6).timeout
	
	%LoadingDots.show()
	$AnimationPlayer.play("fade_in_loading_dots")

	await get_tree().create_timer(2.0).timeout
	
	while is_loading or not loaded_resource:
		await get_tree().process_frame
	
	_handle_post_boot_flow()


func _ready() -> void:
	randomize()

	# OpenXR setup
	var xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		xr_interface.pose_recentered.connect(_on_xr_pose_recentered)
		switch_to_vr()
	
	_hide_controller_models()
	TranslationServer.set_locale(SettingsManager.get_value("settings","locale"))

	SignalBus.switch_to_ar.connect(switch_to_ar)
	SignalBus.switch_to_vr.connect(switch_to_vr)
	SignalBus.restart_home_requested.connect(restart_quest_home)
	SignalBus.fade_in_scene.connect(_fade_in_scene)
	SignalBus.fade_out_scene.connect(_fade_out_scene)
	SignalBus.tween_scene_light.connect(_tween_scene_light)
	SignalBus.controller_show_lasers.connect(_show_controller_lasers)
	SignalBus.controller_hide_lasers.connect(_hide_controller_lasers)
	SignalBus.controller_show_model.connect(_show_controller_models)
	SignalBus.controller_hide_model.connect(_hide_controller_models)
	SignalBus.controller_hide_reticles.connect(_hide_controller_reticles)
	SignalBus.controller_show_reticles.connect(_show_controller_reticles)
	var system_window := WindowManager.register_window(&"system", system_view_locked_viewport)
	system_window.app_opened.connect(_on_system_window_app_opened)
	SignalBus.boot_video_player = video_screen
	SignalBus.start_system_view.connect(show_system_view)
	SignalBus.end_system_view.connect(hide_system_view)
	SignalBus.power_off.connect(_power_off)
	SignalBus.restart.connect(_restart)
	
	SignalBus.nux_show_fixed_display.connect(func(scene: String):
		%FixedDisplay.hide()
		await set_fixed_display_viewport_scene(load(scene))
		await get_tree().process_frame
		%FixedDisplay.show()
		)
	
	SignalBus.nux_hide_fixed_display.connect(func():
		%FixedDisplay.hide()
		clear_fixed_display_viewport_scene()

		)
	
	_evaluate_boot_settings()
	_run_boot_sequence()

func _handle_post_boot_flow() -> void:
	%LoadingDots.hide()

	# QuestHome now owns the full NUX decision tree (OTA-block, twilight,
	# full_vr, or straight to Home) - Master's only remaining job here is
	# the pre-completion "curtain" backdrop and getting the controllers
	# visible, both independent of which specific flow QuestHome runs.
	if SettingsManager.get_value("settings", "nuxStatus") != SettingsManager.NUX_STATUS.NUX_COMPLETE:
		if locked_viewport:
			locked_viewport_parent.show()
		_show_controller_models()
		_show_controller_lasers()

	_finalize_scene_swap()


## Entry point for the "official" flow (power hold, shutdown, etc): brings
## up the system view presentation, then opens app_id into it.
func show_system_view(app_id: String, force: bool = false) -> void:
	if is_in_system_view and not force:
		return
	await _reveal_system_view(app_id)
	# The system window shows exactly one app - whichever one opened it -
	# and has no back-stack, so there's never anything to reveal underneath.
	await WindowManager.open_app(&"system", app_id, {}, false)


## Anything opening an app directly into the "system" window - without
## going through show_system_view(), e.g. the debug panel's launch-target
## picker - still needs the full presentation around it, or the app would
## load invisibly behind a SystemView node that's never told to show.
func _on_system_window_app_opened(_instance: Node, manifest: AppManifest) -> void:
	if is_in_system_view:
		return
	_reveal_system_view(manifest.id if manifest else "")


func _reveal_system_view(app_id: String = "") -> void:
	SystemLog.log("Transitioning to systemview %s", app_id)
	is_in_system_view = true
	system_view_locked_viewport.hide()


	# 1. Back up the current world environment state before touching it
	original_bg_mode = environment.background_mode
	original_bg_color = environment.background_color

	system_view_prev_controller_laser_state = controller_lasers_showing
	_hide_controller_lasers()


	# 2. Force background to solid flat color
	environment.background_mode = Environment.BG_COLOR

	# 3. Apply Hex 363636 ("54, 54, 54" in sRGB)
	environment.background_color = Color("363636")

	var mat = master_camera_fade.get_active_material(0) as StandardMaterial3D
	if not mat:
		SystemLog.log("MASTERCAMERAFADE MATERIAL NOT FOUND?")
		return
	mat.albedo_color.a = 1

	locked_viewport_parent.hide()
	world_container.hide()


	master_camera_fade.show()
	_hide_controller_reticles()

	UiAudioManager.pause_env_audio()

	await get_tree().create_timer(0.4).timeout


	var tween = create_tween()

	system_view_locked_viewport.show()
	tween.tween_property(mat, "albedo_color:a", 0, 0.5)

	system_view.show()
	_show_controller_lasers()
	_show_controller_reticles()


func hide_system_view() -> void:
	if not is_in_system_view:
		return
	SystemLog.log("SystemView ending, restoring environment state")
	
	var mat = master_camera_fade.get_active_material(0) as StandardMaterial3D
	if not mat: 
		SystemLog.log("MASTERCAMERAFADE MATERIAL NOT FOUND?") 
		return
	mat.albedo_color.a = 1
	_hide_controller_lasers()
	_hide_controller_reticles()
	
	master_camera_fade.show()

	WindowManager.close_app(&"system")

	await get_tree().create_timer(0.4).timeout

	
	is_in_system_view = false
	
	world_container.show()
	locked_viewport_parent.show()
	system_view.hide()
	master_camera_fade.hide()
	
	UiAudioManager.resume_env_audio()

	
	
	if system_view_prev_controller_laser_state == true:
		_show_controller_lasers()
	_show_controller_reticles()
	
	
	environment.background_mode = original_bg_mode
	environment.background_color = original_bg_color
	return
	

func set_fixed_display_viewport_scene(new_scene: PackedScene):
	print("setting scene")
	for child in %FixedDisplayViewport.get_children():
		child.free()
	
	var instance = new_scene.instantiate()
	
	%FixedDisplayViewport.add_child(instance)
	print("return")
	return instance
	
func clear_fixed_display_viewport_scene():
	print("freeing scene")
	for child in %FixedDisplayViewport.get_children():
		child.free()

	print("return2")
	

func _start_background_load() -> void:
	is_loading = true
	# use_sub_threads=true offload file parsing completely to another CPU core
	var error = ResourceLoader.load_threaded_request(target_scene_path, "", true)
	if error != OK:
		SystemLog.log("Background thread initialization failure")

func _shutdown() -> void:
	await show_system_view("system_grid.power_action", true)
	UiAudioManager.play_shutdown_sound()
	UiAudioManager.stop_env_audio()


func _power_off() -> void:
	await _shutdown()
	await get_tree().create_timer(3.0).timeout
	get_tree().quit() 


func _restart() -> void:
	SystemLog.log("Executing full soft-restart... Safe purging viewports.")
	
	_shutdown()
	
	await get_tree().create_timer(3.5).timeout
	
	
	# 1. Cancel active tasks
	is_loading = false
	loaded_resource = null
	$AnimationPlayer.stop()
	$SceneLightingAnimationPlayer.stop()
	
	# 2. Clear containers and viewports
	_clear_world_container()
	
	if is_instance_valid(locked_viewport):
		locked_viewport_parent.hide()
		
	WindowManager.close_app(&"system")
	if is_instance_valid(system_view):
		system_view.hide()
	
	# 3. Restore default variables
	is_in_system_view = false
	sequence_finished = false

	# 4. FORCE ENVIRONMENT BACK TO BOOT STATE
	if environment:
		environment.background_mode = Environment.BG_SKY
		environment.background_color = Color(0, 0, 0, 1)
	
	# 5. Reset UI Visibility
	master_camera_fade.show()
	_hide_controller_models()
	_hide_controller_lasers()
	
	world_container.show() 
	locked_viewport_parent.show()

	
	await get_tree().create_timer(1.8).timeout
	
	$AnimationPlayer.play("RESET")
	%OculusLogo.show()
	%LoadingDots.hide()
	master_camera_fade.hide()
	

	
	# 7. Evaluate settings and boot
	_evaluate_boot_settings()
	_run_boot_sequence()
		
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
			SystemLog.log("questhome background load failure")
			is_loading = false

func _finalize_scene_swap() -> void:
	if not loaded_resource:
		return
		
	var new_scene_instance = loaded_resource.instantiate()
	
	_clear_world_container() # Refactored
		
	world_container.add_child(new_scene_instance)
	SystemLog.log("questhome loaded")

	%LoadingDots.hide()
	_show_controller_lasers()
	_show_controller_models()
	

func restart_quest_home() -> void:
	if is_loading:
		SystemLog.log("already loading a scene, ignore restart request")
		return
		
	SystemLog.log("questhome restart")
	is_loading = true
	loaded_resource = null 
	
	%LoadingDots.show()
	_hide_controller_lasers()
	_hide_controller_models()
	environment.sky.sky_material.energy_multiplier = 0
	
	_clear_world_container()
		
	var error = ResourceLoader.load_threaded_request(target_scene_path, "", true)
	if error != OK:
		SystemLog.log("Restart thread initialization failure")
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
	controller_lasers_showing = true
	left_hand.laser_mesh.show()
	right_hand.laser_mesh.show()
	
func _hide_controller_lasers():
	controller_lasers_showing = false
	left_hand.laser_mesh.hide()
	right_hand.laser_mesh.hide()

func _show_controller_reticles():
	%LeftFunctionPointer.visible = true
	%RightFunctionPointer.visible = true
	
func _hide_controller_reticles():
	%LeftFunctionPointer.visible = false
	%RightFunctionPointer.visible = false
	

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
	
	
func _tween_scene_light(to: float, duration: float) -> void:
	_begin_scene_light_change()
	var tween = get_tree().create_tween()
	tween.tween_property(%WorldEnvironment, "environment:sky:sky_material:energy_multiplier", to, duration)
	await tween.finished
	_end_scene_light_change()
	SignalBus.tween_scene_light_finished.emit()
