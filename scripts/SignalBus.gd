extends Node


signal restart_home_requested

signal request_locked_viewport_scene(scene_path: String)
var active_locked_scene_instance: Node = null

signal aui_bar_hide_requested()
signal aui_bar_show_requested()

signal controller_press_sound()

signal controller_trigger_haptic(hand: String, amplitude: float, duration: float)

signal controller_trigger_pressed(hand: String)
signal controller_button_pressed(action: String,  hand: String)
signal controller_button_released(action: String, hand: String)

signal controller_show_lasers()
signal controller_hide_lasers()
signal controller_show_model()
signal controller_hide_model()
signal controller_show_reticles()
signal controller_hide_reticles()

signal switch_to_ar()
signal switch_to_vr()

signal fade_in_scene()
signal fade_in_scene_finished()
signal fade_out_scene()
signal fade_out_scene_finished()
signal tween_scene_light()
signal tween_scene_light_finished()

signal start_system_view(app_id: String)
signal end_system_view()


signal nux_show_fixed_display(scene: String)
signal nux_hide_fixed_display()

## The OpenXR composition-layer video quad Master.tscn owns for the
## twilight NUX flow. It stays Master-owned (a native Android media surface
## backs it - recreating that on every QuestHome reload would be wasteful
## and risky) but the sequencing/decision logic that drives it lives in
## QuestHome's nux.twilight app, which reaches it through this reference.
var boot_video_player: XRVideoPlayerQuad = null

signal power_off()
signal restart()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
