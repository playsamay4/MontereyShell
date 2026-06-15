extends Node


var hover_player : AudioStreamPlayer
var press_player : AudioStreamPlayer
var release_player : AudioStreamPlayer

func _ready() -> void:
	press_player = AudioStreamPlayer.new()
	release_player = AudioStreamPlayer.new()
	hover_player = AudioStreamPlayer.new()
	
	press_player.stream = load("res://audio/new/sfx_press.ogg")
	release_player.stream = load("res://audio/sfx_select_main.ogg")
	hover_player.stream = load("res://audio/sfx_hover.ogg")
	
	#SignalBus.controller_press_sound.connect(func(): press_player.play())
	
	add_child(press_player)
	add_child(release_player)
	add_child(hover_player)
	
	# LISTEN TO THE ENTIRE GAME ENGINE WINDOW FOR NEW NODES
	get_tree().node_added.connect(_on_node_added)
	

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.mouse_entered.connect(func(): hover_player.play() )
		node.pressed.connect(func(): release_player.play())
	#our Custom controls:
	elif node is Control and node.has_signal("toggled") and not node is HBoxContainer:
		node.mouse_entered.connect(func(): hover_player.play())
		node.toggled.connect(func(_is_on): release_player.play())
	# Whole row setting
	elif node.has_signal("setting_clicked"):
		node.mouse_entered.connect(func(): hover_player.play())
		node.setting_clicked.connect(func(): release_player.play())
	
