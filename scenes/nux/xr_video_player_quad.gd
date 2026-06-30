class_name XRVideoPlayerQuad
extends OpenXRCompositionLayerQuad

signal video_started
signal video_finished

@export_file("*.mp4") var android_video_path: String = "video/health_and_safety.mp4"
@export_file("*.ogv") var pc_fallback_path: String = "res://video/fallback.ogv"
@export var video_resolution: Vector2i = Vector2i(1080, 1080)
@export var loop_video: bool = false

var media_player: Object        
var pc_video_player: VideoStreamPlayer 
var pc_viewport: SubViewport     


var android_listener_instance: Object
var android_java_proxy: Object

var _xr_session_ready: bool = false
var _is_prepared: bool = false
var _play_requested_early: bool = false

func _ready() -> void:
	print("[XRVideoPlayerQuad] Starting")
	self.android_surface_size = video_resolution
	
	var xr_interface: OpenXRInterface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		xr_interface.session_begun.connect(_on_openxr_session_begun)
		# Backup hook: handles slower headsets where swapchains allocate after session start
		xr_interface.session_focussed.connect(_on_openxr_session_focussed)

		var system_info := xr_interface.get_system_info()
		var xr_runtime_name: String = system_info['XRRuntimeName']
		var renderer := RenderingServer.get_current_rendering_driver_name()
		var modes = xr_interface.get_supported_environment_blend_modes()
		
		if xr_interface.XR_ENV_BLEND_MODE_OPAQUE in modes:
			xr_interface.set_environment_blend_mode(xr_interface.XR_ENV_BLEND_MODE_OPAQUE)

		var flip_composition_layer := false
		if xr_runtime_name.begins_with('Oculus'):
			print("[XRVideoPlayerQuad] Oculus Runtime detected")
			flip_composition_layer = (renderer == "opengl3" or renderer == "opengl3_es")
		elif xr_runtime_name.begins_with('Pico'):
			flip_composition_layer = (renderer == "vulkan")

		self.set('XR_FB_composition_layer_image_layout/vertical_flip', flip_composition_layer)
		
		if OS.get_name() != "Android":
			setup_pc_video_fallback()
		else:
			self.use_android_surface = true


func _on_openxr_session_begun() -> void:
	_xr_session_ready = true
	_try_android_setup()


func _on_openxr_session_focussed() -> void:
	# If session_begun was too early, this fallback frame will catch it
	if OS.get_name() == "Android" and not _is_prepared:
		print("[XRVideoPlayerQuad] Session focused event fired. Re-attempting surface binding.")
		_try_android_setup()


func _try_android_setup() -> void:
	if OS.get_name() == "Android" and not _is_prepared:
		var android_surface = self.get_android_surface()
		if android_surface:
			print("[XRVideoPlayerQuad] Obtained Android surface; deferring execution.")
			_initialize_android_media_player.call_deferred(android_surface, android_video_path)


func play_video() -> void:
	if not _xr_session_ready or (OS.get_name() == "Android" and not _is_prepared):
		print("[XRVideoPlayerQuad] play_video: Engine/Decoder not ready. Queueing request.")
		_play_requested_early = true
		return
		
	if OS.get_name() == "Android":
		if media_player:
			print("[XRVideoPlayerQuad] Directing Android MediaPlayer to start.")
			media_player.start()
			video_started.emit()
	else:
		if pc_video_player and not pc_video_player.is_playing():
			pc_video_player.play()
			video_started.emit()


func pause_video() -> void:
	if OS.get_name() == "Android":
		if media_player and media_player.isPlaying():
			media_player.pause()
	else:
		if pc_video_player and pc_video_player.is_playing():
			pc_video_player.paused = true


func stop_video() -> void:
	_play_requested_early = false
	if OS.get_name() == "Android":
		if media_player:
			media_player.stop()
			media_player.prepare() 
	else:
		if pc_video_player:
			pc_video_player.stop()

func change_and_play_video(new_path: String) -> void:
	print("[XRVideoPlayerQuad] Changing video to: ", new_path)
	
	if OS.get_name() == "Android":
		# 1. Reset state flags so play_video() doesn't fire prematurely
		_is_prepared = false
		_play_requested_early = true # Force it to auto-play once prepared
		
		if media_player:
			# 2. Reset the native player to clean its data source and state
			media_player.reset()
			
			# 3. Re-run setup using the new path and existing surface
			var android_surface = self.get_android_surface()
			if android_surface:
				_initialize_android_media_player(android_surface, new_path)
			else:
				print("[XRVideoPlayerQuad] Error: Lost Android surface during video swap.")
	else:
		# PC Fallback Path
		if pc_video_player:
			pc_video_player.stop()
			
			# Update the path tracker variable
			pc_fallback_path = new_path 
			var ogv_stream = load(pc_fallback_path)
			
			if ogv_stream:
				pc_video_player.stream = ogv_stream
				pc_video_player.play()
				video_started.emit()
			else:
				print("[XRVideoPlayerQuad] Error: Failed to load PC fallback video: ", new_path)

func setup_pc_video_fallback() -> void:
	self.use_android_surface = false
	pc_viewport = SubViewport.new()
	pc_viewport.size = video_resolution 
	pc_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(pc_viewport)
	
	pc_video_player = VideoStreamPlayer.new()
	pc_video_player.expand = true
	pc_video_player.anchor_right = 1.0
	pc_video_player.anchor_bottom = 1.0
	pc_video_player.loop = loop_video
	pc_video_player.finished.connect(func(): video_finished.emit())
	
	var ogv_stream = load(pc_fallback_path)
	if ogv_stream:
		pc_video_player.stream = ogv_stream
	pc_viewport.add_child(pc_video_player)
	self.layer_viewport = pc_viewport


# Change the file path reference inside this function to use the passed variable:
func _initialize_android_media_player(surface, video_path) -> void:
	print("[XRVideoPlayerQuad] Initializing native Android components...")
	if surface == null: return

	var MediaPlayer = JavaClassWrapper.wrap('android.media.MediaPlayer')
	if media_player == null:
		media_player = MediaPlayer.MediaPlayer()

	var AndroidRuntime = Engine.get_singleton("AndroidRuntime")
	var context = AndroidRuntime.getActivity()

	# USE THE PASSED video_path PARAMETER HERE (instead of android_video_path)
	var sanitized_path = video_path.replace("res://", "")
	var afd = context.getAssets().openFd(sanitized_path)
	if afd == null: return
		
	media_player.setDataSource(afd.getFileDescriptor(), afd.getStartOffset(), afd.getLength())
	afd.close()

	media_player.setSurface(surface)
	media_player.setLooping(loop_video)
	media_player.prepare()

	_is_prepared = true
	print("[XRVideoPlayerQuad] Native Android media components initialized successfully!")

	# Re-bind listeners (Crucial after a media_player.reset())
	android_listener_instance = VideoCompletionListener.new(self)
	android_java_proxy = JavaClassWrapper.create_proxy(
		android_listener_instance, 
		["android.media.MediaPlayer$OnCompletionListener"]
	)
	media_player.setOnCompletionListener(android_java_proxy)

	if _play_requested_early:
		_play_requested_early = false
		play_video()
		
func _on_android_video_finished() -> void:
	print("[XRVideoPlayerQuad] Android Native Video Finished. Safely deferring signal to Main Thread.")
	video_finished.emit.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and media_player:
		media_player.release()
		media_player = null


# 1. Define a simple local helper class right inside your script file (at the very bottom)
class VideoCompletionListener:
	var parent_node: Node3D
	
	func _init(parent: Node3D) -> void:
		parent_node = parent
		
	func onCompletion(mp) -> void:
		# Use call_deferred here to guarantee we bounce off the native Android media thread immediately
		if parent_node and parent_node.has_method("_on_android_video_finished"):
			parent_node.call_deferred("_on_android_video_finished")
