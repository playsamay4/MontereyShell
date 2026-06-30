extends PanelContainer

@onready var video_player = %VideoPlayer

signal back_button_pressed
signal continue_button_pressed

signal skip_pressed

signal video_finished

var skip_enabled: bool = false:
	set(value):
		skip_enabled = value
		_update_ui()

func _update_ui():
	if skip_enabled == true:
		%SkipContainer.show()
	else:
		%SkipContainer.hide()
		

func _ready() -> void:
	video_player.hide()
	
	video_player.video_finished.connect(func():
		video_finished.emit()
	)
	
	video_player.video_started.connect(func():
		video_player.show()
		var tween = create_tween()
		
		_update_ui()
		
		skip_pressed.connect(func():
			if tween:
				tween.kill()
			)
		
		tween.tween_interval(1.0)
		tween.tween_callback(func(): %TextA.text = tr("NUX_HS_VID_1"))
		tween.tween_property(%TextA, "modulate:a", 1, 0.5)
		
		tween.tween_interval(7.5)
		tween.tween_callback(func(): %TextB.text = tr("NUX_HS_VID_2"))
		
		tween.set_parallel(true)
		tween.tween_property(%TextA, "modulate:a", 0, 0.5)
		tween.tween_property(%TextB, "modulate:a", 1, 0.5)
		tween.set_parallel(false) 
		
		tween.tween_interval(13.5)
		tween.tween_callback(func(): %TextA.text = tr("NUX_HS_VID_3"))
		
		tween.set_parallel(true)
		tween.tween_property(%TextB, "modulate:a", 0, 0.5)
		tween.tween_property(%TextA, "modulate:a", 1, 0.5)
		tween.set_parallel(false)
		
		tween.tween_interval(11.5) 
		tween.tween_callback(func(): %TextB.text = tr("NUX_HS_VID_4"))
		
		tween.set_parallel(true)
		tween.tween_property(%TextA, "modulate:a", 0, 0.5)
		tween.tween_property(%TextB, "modulate:a", 1, 0.5)
		tween.set_parallel(false)
		
		tween.tween_interval(3.5)
		tween.tween_callback(func(): %TextA.text = tr("NUX_HS_VID_5"))
		
		tween.set_parallel(true)
		tween.tween_property(%TextB, "modulate:a", 0, 0.5)
		tween.tween_property(%TextA, "modulate:a", 1, 0.5)
		tween.set_parallel(false)
		

		tween.tween_interval(12.5)
		tween.tween_property(%TextA, "modulate:a", 0, 0.5)


		tween.tween_interval(7.5)
		
		tween.tween_callback(func(): 
			%AcknowledgeButton.disabled = false
			%SkipContainer.hide()
			)
		
		tween.tween_property(%SafetyPanel, "modulate:a", 1, 0.8)
		
		await tween.finished
		%BackButton.show()
		
	)
	
	video_player.play() 
	
	%SkipButton.pressed.connect(func():
		%SkipContainer.hide()
		%BackButton.show()
		%SafetyPanel.modulate.a = 1
		%AcknowledgeButton.disabled = false
		%TextA.hide()
		%TextB.hide()
		skip_pressed.emit()
		
		video_player.seek(59.0)

		)
	
	%BackButton.pressed.connect(func(): back_button_pressed.emit())
	%AcknowledgeButton.pressed.connect(func(): continue_button_pressed.emit())


func _process(delta: float) -> void:
	pass
