extends Node


signal restart_home_requested

signal panel_open_requested(panel_res: String)
signal popup_open_requested(config: Dictionary)
signal popup_finish_requested(reason: String)
signal aui_bar_hide_requested()
signal aui_bar_show_requested()

signal controller_press_sound()

signal controller_trigger_haptic(hand: String, amplitude: float, duration: float)

signal controller_show_lasers()
signal controller_hide_lasers()
signal controller_show_model()
signal controller_hide_model()

signal switch_to_ar()
signal switch_to_vr()

signal fade_in_scene()
signal fade_in_scene_finished()
signal fade_out_scene()
signal fade_out_scene_finished()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
