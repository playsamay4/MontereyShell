extends Node

var boot_sound_player: AudioStreamPlayer = AudioStreamPlayer.new()
var boot_sound = preload("res://audio/startup1.wav")
var shutdown_sound = preload("res://audio/sfx_oculus_sys_shutdown.wav")

var hover_player : AudioStreamPlayer
var press_player : AudioStreamPlayer
var release_player : AudioStreamPlayer
var back_player : AudioStreamPlayer

var environment_player: AudioStreamPlayer
var chime_player : AudioStreamPlayer
var secondary_chime_player : AudioStreamPlayer

var last_click_frame : int = 0

var _environment_player_was_playing = false
var _environment_player_playback_position = 0

func _ready() -> void:
	
	press_player = AudioStreamPlayer.new()
	release_player = AudioStreamPlayer.new()
	hover_player = AudioStreamPlayer.new()
	back_player = AudioStreamPlayer.new()
	
	environment_player = AudioStreamPlayer.new()
	chime_player = AudioStreamPlayer.new()
	secondary_chime_player = AudioStreamPlayer.new()
	
	load_type(SettingsManager.get_value("settings","devAudioStyle"))
	
	SignalBus.controller_press_sound.connect(func(): press_player.play())
	
	add_child(boot_sound_player)
	
	add_child(press_player)
	add_child(release_player)
	add_child(hover_player)
	add_child(back_player)
	
	add_child(environment_player)
	add_child(chime_player)
	add_child(secondary_chime_player)
	
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
	# bodge fix for double hover noise
	if Engine.get_frames_drawn() == last_click_frame:
		return
	hover_player.play()

func play_boot_sound() -> void:
	boot_sound_player.stream = boot_sound
	boot_sound_player.play()

func play_shutdown_sound() -> void:
	boot_sound_player.stream = shutdown_sound
	boot_sound_player.play()

func play_env_audio(src: String):
	environment_player.stream = load(src)
	environment_player.play(0)
	_environment_player_was_playing = true

func stop_env_audio():
	environment_player.stop()
	_environment_player_was_playing = false

func pause_env_audio():
	_environment_player_playback_position = environment_player.get_playback_position()
	environment_player.stop()

func fade_env_audio(from: float, to: float, duration: float):
	environment_player.volume_db = from
	var tween = get_tree().create_tween()
	tween.tween_property(environment_player, "volume_db", to, duration)

	await tween.finished
	return


func fade_out_env_audio(duration: float):
	var tween = get_tree().create_tween()
	tween.tween_property(environment_player, "volume_db", -80.0, duration)

	await tween.finished
	stop_env_audio()
	return


func resume_env_audio():
	if _environment_player_was_playing == true:
		environment_player.play(_environment_player_playback_position)

func play_chime(src: String, player = 1):
	if player == 1:
		chime_player.stream = load(src)
		chime_player.play()
	elif player == 2:
		secondary_chime_player.stream = load(src)
		secondary_chime_player.play()

func stop_chime(player = 1):
	if player == 1:
		chime_player.stop()
	elif player == 2:
		secondary_chime_player.stop()

func _on_node_added(node: Node) -> void:

	if node is BaseButton :
		if not node.is_in_group("no_hover_sound"): node.mouse_entered.connect(func(): if node.disabled == false: hover_player.play() )
		if node.is_in_group("back_buttons"):
			node.pressed.connect(func(): back_player.play())
		else:
			if not node.is_in_group("no_press_sound"): node.pressed.connect(func(): if node.disabled == false: release_player.play())
	#our Custom controls:
	elif node is Control and node.has_signal("toggled") and not node is HBoxContainer:
		if not node.is_in_group("no_hover_sound"): node.mouse_entered.connect(_play_hover)
		if not node.is_in_group("no_press_sound"): node.toggled.connect(func(_is_on): _play_click())
	# Whole row setting
	elif node.has_signal("setting_clicked"):
		if "option_type" in node and node.option_type in ["page", "external"]:
			if not node.is_in_group("no_hover_sound"): node.mouse_entered.connect(func(): _play_hover())
		if not node.is_in_group("no_press_sound"): node.setting_clicked.connect(func(_id): _play_click())
	
