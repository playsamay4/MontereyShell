extends Node3D

@onready var aui_bar_3d = $AUI_Bar
@onready var tooltip_3d = $AUI_Tooltips

@onready var mainPanel = $CurvedPanel
@onready var popupPanel = $PopupPanel

@onready var viewport : Viewport = get_viewport()


var aui_fade_tween: Tween

var in_ar = false

var main_window: AppWindow

var nux_steps: Array[String] = [
	"nux.fit_and_focus_fit",
	"nux.fit_and_focus_clarity",
	"nux.fit_and_focus_focus",
	"nux.health_and_safety",
	"nux.create_guardian_boundary",
	"nux.show_universal_menu",
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

	main_window = WindowManager.register_window(&"main", mainPanel)
	PopupManager.register(popupPanel, popupPanel.get_scene_instance(), $"AnimationPlayer", aui_bar_3d)

	SignalBus.aui_bar_show_requested.connect(func(): fade_aui_bar(true, 0.4))
	SignalBus.aui_bar_hide_requested.connect(func(): fade_aui_bar(false, 0.4))

	SignalBus.fade_in_scene.emit()
	aui_bar_3d.visible = false

	await SignalBus.fade_in_scene_finished

	if SettingsManager.get_value("settings", "nuxType") == "full_vr" && SettingsManager.get_value("settings", "nuxStatus") != SettingsManager.NUX_STATUS.NUX_COMPLETE:
		UiAudioManager.play_chime("res://audio/update_complete.ogg")
		await get_tree().create_timer(1.5).timeout

		UiAudioManager.play_chime("res://audio/nux/music_first_time_nux_home_intro.ogg", 2)

		# Runs independently of the 10s timer below - whenever the user
		# actually dismisses this, kick off onboarding.
		var show_update_popup := func():
			await PopupManager.show_popup({
					"title": tr("NUX_UPDATE_COMPLETE_TITLE"),
					"text": tr("NUX_UPDATE_COMPLETE_BODY"),
					"action_text": "",
					"primary_text": tr("NUX_CONTINUE"),
					"cancel_text": "",
					})
			_start_nux_sequence()
		show_update_popup.call()

		await get_tree().create_timer(10).timeout
		UiAudioManager.fade_env_audio(-80,0, 1)
		UiAudioManager.play_env_audio("res://audio/nux/music_first_time_nux_home_loop.ogg")
		return

	init_aui()

func init_aui():

	await fade_aui_bar(true, 0.4)
	UiAudioManager.play_env_audio("res://audio/system_environment_ambix.ogg")

func _start_nux_sequence() -> void:
	# Onboarding is mandatory - it runs with keep_history=false (nothing to
	# fall back to), so the controller's universal back button must not be
	# able to dismiss a step and softlock on a blank panel.
	main_window.back_navigation_locked = true
	SignalBus.tween_scene_light.emit(0.95, 2)
	nux_current_step_index = 0
	_load_current_step()


func _load_current_step() -> void:
	nux_current_instance = null

	if nux_current_step_index < 0:
		nux_current_step_index = 0
		return
	if nux_current_step_index >= nux_steps.size():
		_on_nux_sequence_complete()
		return

	var app_id: String = nux_steps[nux_current_step_index]
	var manifest := AppRegistry.get_app(app_id)
	if not manifest:
		SystemLog.log("[QuestHome] Unknown nux app id '%s'", app_id)
		return

	#Pre initialization setup
	if app_id == "nux.health_and_safety":
		await UiAudioManager.fade_env_audio(0, -80, 1)

	nux_current_instance = await main_window.open(manifest, {}, false)



	#Post initialization setup
	if app_id == "nux.health_and_safety":
		nux_current_instance.skip_enabled = true
		nux_current_instance.video_finished.connect(
			func(): UiAudioManager.fade_env_audio(-80, 0, 4),
			CONNECT_ONE_SHOT
		)
	elif app_id == "nux.show_universal_menu":
		nux_universal_menu_callable = func(hand: String, action: String):
			if hand == "right" && action == "primary_click":
				SignalBus.controller_button_released.disconnect(nux_universal_menu_callable)
				main_window.open(AppRegistry.get_app("system.blank"), {}, false)
				UiAudioManager.play_chime("res://audio/nux/music_first_time_nux_home_outro.ogg")
				UiAudioManager.stop_env_audio()

				SignalBus.tween_scene_light.emit(5, 2)
				await SignalBus.tween_scene_light_finished

				main_window.back_navigation_locked = false
				init_aui()
				SettingsManager.set_value("settings","nuxStatus", SettingsManager.NUX_STATUS.NUX_COMPLETE)
		SignalBus.controller_button_released.connect(nux_universal_menu_callable)


	if nux_current_instance.has_signal("continue_button_pressed"):
		nux_current_instance.continue_button_pressed.connect(_on_next_step)

	if nux_current_instance.has_signal("back_button_pressed"):
		nux_current_instance.back_button_pressed.connect(_on_previous_step)


func _on_next_step() -> void:
	var app_id: String = nux_steps[nux_current_step_index]
	if app_id == "nux.fit_and_focus_clarity":
		await main_window.open(AppRegistry.get_app("system.blank"), {}, false)
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
	elif app_id == "nux.fit_and_focus_focus":
		await main_window.open(AppRegistry.get_app("system.blank"), {}, false)
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
	elif app_id == "nux.create_guardian_boundary":
		main_window.open(AppRegistry.get_app("system.blank"), {}, false)
		await get_tree().create_timer(0.5).timeout
		PackageManager.launch_app("com.oculus.guardiansetup")
		await get_tree().create_timer(0.5).timeout


	nux_current_step_index += 1
	_load_current_step()


func _on_previous_step() -> void:
	nux_current_step_index -= 1
	_load_current_step()


func _on_nux_sequence_complete() -> void:
	main_window.back_navigation_locked = false
	print("NUX Sequence finished successfully!")



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


## Toggles between the VR home and AR passthrough. Not currently wired to
## any input (it wasn't before this either - it was a leftover code path).
func toggle_see_outside() -> void:
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


func _on_show_tooltip(type: String) -> void:
	var tooltip_2d = tooltip_3d.get_scene_instance()
	if tooltip_2d and tooltip_2d.has_method("display_mode"):
		tooltip_2d.display_mode(type)

	tooltip_3d.visible = true

func _on_hide_tooltip() -> void:
	tooltip_3d.visible = false
