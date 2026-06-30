extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	%Cancel.pressed.connect(func(): SignalBus.end_system_view.emit())
	%PowerOff.pressed.connect(func(): SignalBus.power_off.emit())
	%Restart.pressed.connect(func(): SignalBus.restart.emit())


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
