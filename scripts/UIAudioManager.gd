extends Node


var hover_player : AudioStreamPlayer
var press_player : AudioStreamPlayer
var release_player : AudioStreamPlayer
var back_player : AudioStreamPlayer

var last_click_frame : int = 0

func _ready() -> void:
	press_player = AudioStreamPlayer.new()
	release_player = AudioStreamPlayer.new()
	hover_player = AudioStreamPlayer.new()
	back_player = AudioStreamPlayer.new()
	
	load_type(SettingsManager.get_value("settings","devAudioStyle"))
	
	SignalBus.controller_press_sound.connect(func(): press_player.play())
	
	add_child(press_player)
	add_child(release_player)
	add_child(hover_player)
	add_child(back_player)
	
	#catch newly added nodes
	get_tree().node_added.connect(_on_node_added)

	#catch existing nodes. lets sounds play during F6 debugging
	_scan_existing_nodes(get_tree().root)
	
	SettingsManager.system_setting_changed.connect(func(_id, _val):
		if _id == "devAudioStyle":
			load_type(_val)
	)

func load_type(type: String):
	match type:
		"v16":
			press_player.stream = load("res://audio/sfx_none.ogg")
			release_player.stream = load("res://audio/sfx_select_main.ogg")
			hover_player.stream = load("res://audio/sfx_hover.ogg")
			back_player.stream = load("res://audio/sfx_select_main_close.ogg")
		"Modern":
			press_player.stream = load("res://audio/new/sfx_press.ogg")
			release_player.stream = load("res://audio/new/sfx_release_main.ogg")
			hover_player.stream = load("res://audio/new/sfx_hover.ogg")
			back_player.stream = load("res://audio/new/sfx_back.ogg")
		"v3":
			press_player.stream = load("res://audio/sfx_none.ogg")
			release_player.stream = load("res://audio/v3/sfx_select_main.ogg")
			hover_player.stream = load("res://audio/v3/sfx_hover.ogg")
			back_player.stream = load("res://audio/v3/sfx_select_main_close.ogg")

func _scan_existing_nodes(node: Node) -> void:
	_on_node_added(node)

	for child in node.get_children():
		_scan_existing_nodes(child)
	
func _play_click() -> void:
	release_player.play()
	last_click_frame = Engine.get_frames_drawn()

func _play_hover() -> void:
	# bodge fix for double hover noise :/
	if Engine.get_frames_drawn() == last_click_frame:
		return
	hover_player.play()

func _on_node_added(node: Node) -> void:
	if node is BaseButton and node.disabled == false:
		node.mouse_entered.connect(func(): hover_player.play() )
		if node.is_in_group("back_buttons"):
			node.pressed.connect(func(): back_player.play())
		else:
			node.pressed.connect(func(): release_player.play())
	#our Custom controls:
	elif node is Control and node.has_signal("toggled") and not node is HBoxContainer:
		node.mouse_entered.connect(_play_hover)
		node.toggled.connect(func(_is_on): _play_click())
	# Whole row setting
	elif node.has_signal("setting_clicked"):
		if "option_type" in node and node.option_type in ["page", "external"]:
			node.mouse_entered.connect(func(): _play_hover())
		node.setting_clicked.connect(func(_id): _play_click())
	
