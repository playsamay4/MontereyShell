extends PanelContainer

@onready var video_player = %VideoPlayer

signal back_button_pressed
signal continue_button_pressed

func _ready() -> void:
	video_player.video_started.connect(func():
		%TextPanel.modulate.a = 0
		var tween = create_tween()

		tween.tween_interval(2.5)
		
		tween.tween_callback(func(): 
			%ContinueButton.disabled = false
			%ContinueButton.pressed.connect(func(): continue_button_pressed.emit())
			)
		
		tween.tween_property(%TextPanel, "modulate:a", 1, 0.8)
		
		await tween.finished
		%BackButton.show()
		
		%BackButton.pressed.connect(func(): back_button_pressed.emit())
	)
	
	video_player.play() 


func _process(delta: float) -> void:
	pass
