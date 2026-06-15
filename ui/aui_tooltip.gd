extends Control

@onready var roomscale_box = $HBoxContainer/RoomscaleTooltip
@onready var stationary_box = $HBoxContainer/StationaryTooltip

func display_mode(mode: String) -> void:
	if mode == "roomscale":
		roomscale_box.modulate.a = 1
		stationary_box.modulate.a = 0
	elif mode == "stationary":
		roomscale_box.modulate.a = 0
		stationary_box.modulate.a = 1
