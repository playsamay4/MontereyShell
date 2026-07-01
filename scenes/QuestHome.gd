extends Node3D

@onready var aui_bar_3d = $AUI_Bar   
@onready var tooltip_3d = $AUI_Tooltips

@onready var mainPanel = $CurvedPanel
@onready var popupPanel = $PopupPanel

@onready var viewport : Viewport = get_viewport()


var aui_fade_tween: Tween

var in_ar = false

var nux_steps: Array[String] = [
	"res://scenes/nux/full_vr/fit_and_focus_fit.tscn",
	"res://scenes/nux/full_vr/fit_and_focus_clarity.tscn",
	"res://scenes/nux/full_vr/fit_and_focus_focus.tscn",
	"res://scenes/nux/full_vr/HealthAndSafety.tscn",
	"res://scenes/nux/full_vr/create_guardian_boundary.tscn",
	"res://scenes/nux/full_vr/show_universal_menu.tscn",
]
var nux_current_step_index: int = 0
var nux_current_instance: Node = null
var nux_universal_menu_callable: Callable


#@export var scene_light: float = 1.0:
	#set(value):
		#scene_light = value
		#SignalBus.scene_light_intensity_changed.emit(value)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	tooltip_3d.visible = false
	var aui_bar_2d = aui_bar_3d.get_scene_instance()
	if aui_bar_2d:
		aui_bar_2d.show_tooltip.connect(_on_show_tooltip)
		aui_bar_2d.hide_tooltip.connect(_on_hide_tooltip)
	
	SignalBus.panel_open_requested.connect(curved_panel_go_to_scene)
	
	SignalBus.popup_open_requested.connect(open_popup)
	SignalBus.popup_finish_requested.connect(close_popup)
	
	SignalBus.aui_bar_show_requested.connect(func(): fade_aui_bar(true, 0.4))
	SignalBus.aui_bar_hide_requested.connect(func(): fade_aui_bar(false, 0.4))
	
	SignalBus.fade_in_scene.emit()
	aui_bar_3d.visible = false
	
	await SignalBus.fade_in_scene_finished
	
	if SettingsManager.get_value("settings", "nuxType") == "full_vr" && SettingsManager.get_value("settings", "nuxStatus") != SettingsManager.NUX_STATUS.NUX_COMPLETE:
		UiAudioManager.play_chime("res://audio/update_complete.ogg")
		await get_tree().create_timer(1.5).timeout

		UiAudioManager.play_chime("res://audio/nux/music_first_time_nux_home_intro.ogg", 2)
		SignalBus.popup_open_requested.emit({
				"title": tr("NUX_UPDATE_COMPLETE_TITLE"),
				"text": tr("NUX_UPDATE_COMPLETE_BODY"),
				"action_text": "",
				"primary_text": tr("NUX_CONTINUE"),
				"cancel_text": "",
				})
		popupPanel.get_scene_instance().fade_in(1)
		SignalBus.popup_finish_requested.connect(_start_nux_sequence.unbind(1), CONNECT_ONE_SHOT)
		await get_tree().create_timer(10).timeout
		UiAudioManager.fade_env_audio(-80,0, 1)
		UiAudioManager.play_env_audio("res://audio/nux/music_first_time_nux_home_loop.ogg")
		return
		
	init_aui()

func init_aui():

	await fade_aui_bar(true, 0.4)
	UiAudioManager.play_env_audio("res://audio/system_environment_ambix.ogg")
	#curved_panel_go_to_scene("res://scenes/Panel_Home.tscn")

func _start_nux_sequence() -> void:
	SignalBus.tween_scene_light.emit(0.95, 2)
	nux_current_step_index = 0
	_load_current_step()


func _load_current_step() -> void:
	if is_instance_valid(nux_current_instance):
		nux_current_instance.queue_free()
		nux_current_instance = null

	if nux_current_step_index < 0:
		nux_current_step_index = 0
		return
	if nux_current_step_index >= nux_steps.size():
		_on_nux_sequence_complete()
		return

	var scene_path = nux_steps[nux_current_step_index]
	
	#Pre initialization setup
	if scene_path == "res://scenes/nux/full_vr/HealthAndSafety.tscn":
		await UiAudioManager.fade_env_audio(0, -80, 1)

	nux_current_instance = await curved_panel_go_to_scene(scene_path)
	

	
	#Post initialization setup
	if scene_path == "res://scenes/nux/full_vr/HealthAndSafety.tscn":
		nux_current_instance.skip_enabled = true
		nux_current_instance.video_finished.connect(
			func(): UiAudioManager.fade_env_audio(-80, 0, 4), 
			CONNECT_ONE_SHOT
		)
	elif scene_path == "res://scenes/nux/full_vr/show_universal_menu.tscn":
		nux_universal_menu_callable = func(hand: String, action: String):
			if hand == "right" && action == "primary_click":
				SignalBus.controller_button_released.disconnect(nux_universal_menu_callable)
				curved_panel_go_to_scene("res://scenes/blank.tscn")
				UiAudioManager.play_chime("res://audio/nux/music_first_time_nux_home_outro.ogg")
				UiAudioManager.stop_env_audio()
				
				SignalBus.tween_scene_light.emit(5, 2)
				await SignalBus.tween_scene_light_finished

				init_aui()
				SettingsManager.set_value("settings","nuxStatus", SettingsManager.NUX_STATUS.NUX_COMPLETE)
		SignalBus.controller_button_released.connect(nux_universal_menu_callable)
		

	if nux_current_instance.has_signal("continue_button_pressed"):
		nux_current_instance.continue_button_pressed.connect(_on_next_step)
		
	if nux_current_instance.has_signal("back_button_pressed"):
		nux_current_instance.back_button_pressed.connect(_on_previous_step)


func _on_next_step() -> void:
	var scene_path = nux_steps[nux_current_step_index]
	if scene_path == "res://scenes/nux/full_vr/fit_and_focus_clarity.tscn":
		await curved_panel_go_to_scene("res://scenes/blank.tscn")
		SignalBus.tween_scene_light.emit(0,0.5)
		await SignalBus.tween_scene_light_finished
		
		SignalBus.controller_hide_lasers.emit()
		SignalBus.controller_hide_model.emit()
		SignalBus.controller_hide_reticles.emit()
		SignalBus.nux_show_fixed_display.emit("res://scenes/nux/clarity.tscn")
		await SignalBus.controller_trigger_pressed
		
		SignalBus.nux_hide_fixed_display.emit()
		SignalBus.controller_show_lasers.emit()
		SignalBus.controller_show_model.emit()
		SignalBus.controller_show_reticles.emit()
		SignalBus.tween_scene_light.emit(0.95,0.5)
		await SignalBus.tween_scene_light_finished
	elif scene_path == "res://scenes/nux/full_vr/fit_and_focus_focus.tscn":
		await curved_panel_go_to_scene("res://scenes/blank.tscn")
		SignalBus.tween_scene_light.emit(0,0.5)
		await SignalBus.tween_scene_light_finished
		
		SignalBus.controller_hide_lasers.emit()
		SignalBus.controller_hide_model.emit()
		SignalBus.controller_hide_reticles.emit()
		SignalBus.nux_show_fixed_display.emit("res://scenes/nux/ipd.tscn")
		await SignalBus.controller_trigger_pressed
		
		SignalBus.nux_hide_fixed_display.emit()
		SignalBus.controller_show_lasers.emit()
		SignalBus.controller_show_model.emit()
		SignalBus.controller_show_reticles.emit()
		SignalBus.tween_scene_light.emit(0.95,0.5)
		await SignalBus.tween_scene_light_finished
	elif scene_path == "res://scenes/nux/full_vr/create_guardian_boundary.tscn":
		SignalBus.panel_open_requested.emit("res://scenes/blank.tscn")
		await get_tree().create_timer(0.5).timeout
		PackageManager.launch_app("com.oculus.guardiansetup")
		await get_tree().create_timer(0.5).timeout
		
		
	nux_current_step_index += 1
	_load_current_step()


func _on_previous_step() -> void:
	nux_current_step_index -= 1
	_load_current_step()


func _on_nux_sequence_complete() -> void:
	print("NUX Sequence finished successfully!")



func open_popup(config: Dictionary):
	if popupPanel.has_method("get_scene_instance"):
		var popup_2d_node = popupPanel.get_scene_instance()
		
		if popup_2d_node and popup_2d_node.has_method("setup_popup"):
			popup_2d_node.setup_popup(config)
	
	
	popupPanel.visible = true
	aui_bar_3d.enabled = false
	$"AnimationPlayer".play("popup_in")

func close_popup(reason: String):
	popupPanel.visible = false
	aui_bar_3d.enabled = true
	$"AnimationPlayer".play("popup_out")
	
	
func fade_aui_bar(to_visible: bool, duration: float = 1.0) -> void:
	var screen_mesh: MeshInstance3D = aui_bar_3d.get_node_or_null("Screen")
	if not screen_mesh: return
	
	var mat = screen_mesh.get_active_material(0)
	
	if mat is StandardMaterial3D:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		
		#Kill any currently running fade
		if aui_fade_tween and aui_fade_tween.is_valid():
			aui_fade_tween.kill()
			
		aui_fade_tween = create_tween()
		
		if to_visible:
			var current_color = mat.albedo_color
			current_color.a = 0.0
			mat.albedo_color = current_color
			
			aui_bar_3d.visible = true
			
			aui_fade_tween.tween_property(mat, "albedo_color:a", 1.0, duration)
		else:
			aui_fade_tween.tween_property(mat, "albedo_color:a", 0.0, duration)
			aui_fade_tween.tween_callback(func(): aui_bar_3d.visible = false)
		
		await aui_fade_tween.finished


func curved_panel_go_to_scene(scene: String):
	if scene == "seeOutside":
		if in_ar == true:
			$"Root Scene".visible = true

			in_ar = false
			SignalBus.switch_to_vr.emit()
			SignalBus.fade_in_scene.emit()
		else:
			#We are in VR
			SignalBus.fade_out_scene.emit()
			await SignalBus.fade_out_scene_finished
			
			$"Root Scene".visible = false
	
			in_ar = true
		
			SignalBus.switch_to_ar.emit()
			
		return
	
	var new_scene_resource = load(scene)
	if new_scene_resource:

		mainPanel.set_scene(new_scene_resource)
		await get_tree().process_frame
		return mainPanel.get_scene_instance()
		


func _on_show_tooltip(type: String) -> void:
	var tooltip_2d = tooltip_3d.get_scene_instance()
	if tooltip_2d and tooltip_2d.has_method("display_mode"):
		tooltip_2d.display_mode(type)
		
	tooltip_3d.visible = true

func _on_hide_tooltip() -> void:
	tooltip_3d.visible = false
