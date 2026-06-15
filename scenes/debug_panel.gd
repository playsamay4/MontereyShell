extends Control



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	%OpenNuxButton.pressed.connect(func(): 
		SignalBus.aui_bar_hide_requested.emit()
		SignalBus.panel_open_requested.emit("res://scenes/nux/NuxOtaBlock.tscn")
		SignalBus.controller_hide_lasers.emit()
		SignalBus.controller_hide_model.emit()
		SignalBus.fade_out_scene.emit()
		
	)
	%ShowPopupBtn.pressed.connect(func(): 
		SignalBus.popup_open_requested.emit({
		"title": "Get softlocked",
		"text": ":D",
		"action_text": "", 
		"primary_text": "",
		"cancel_text": ""
		})
		SignalBus.aui_bar_hide_requested.emit()
		SignalBus.panel_open_requested.emit("res://scenes/blank.tscn")

	)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
