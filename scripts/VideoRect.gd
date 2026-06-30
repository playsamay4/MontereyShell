## CrossPlatformVideoRect
## A reusable TextureRect that plays video on Android (MediaPlayer + OES) and
## PC (VideoStreamPlayer). No ShaderMaterial or .gdshader file needed in your
## scene — the shader is built entirely at runtime, only on Android, so the
## editor never touches the OES extension and produces no uniform spam.
##
## SETUP:
##   1. Attach this script to a TextureRect. Leave Material EMPTY in the scene.
##   2. Set android_video_path (relative .mp4, no res://).
##   3. Set pc_video_stream to your .ogv VideoStream resource.
##   4. Connect video_finished / video_started / video_error as needed.

extends TextureRect

# ── Exports ───────────────────────────────────────────────────────────────────

## Path to the .mp4, relative to the APK assets root (no res:// prefix).
@export_file("*.mp4") var android_video_path: String = ""

## .ogv VideoStream resource used on PC / Oculus Link.
@export var pc_video_stream: VideoStream = null

## Native decode resolution for the Android ExternalTexture.
@export var video_resolution: Vector2i = Vector2i(1080, 1080)

## Whether the video should loop.
@export var loop_video: bool = false

## If true, playback begins automatically in _ready().
@export var autoplay: bool = true

# ── Signals ───────────────────────────────────────────────────────────────────

signal video_finished
signal video_started
signal video_error(message: String)

# ── Shader source (OES — only compiled at runtime on Android) ─────────────────

const _ANDROID_SHADER_SRC := """
shader_type canvas_item;
uniform samplerExternalOES android_video_texture : filter_linear, repeat_disable;
void fragment() {
    COLOR = vec4(texture(android_video_texture, UV).rgb, 1.0);
}
"""

# ── Private state ─────────────────────────────────────────────────────────────

var _is_android: bool = false

# Android-only
var _media_player: Object
var _ext_texture: ExternalTexture
var _android_surface_texture: Object
var _android_listener_instance: Object  # GC anchor
var _android_java_proxy: Object         # GC anchor

# PC-only
var _pc_player: VideoStreamPlayer

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_is_android = OS.get_name() == "Android"
	if autoplay:
		play()


func _process(_delta: float) -> void:
	if _is_android and _android_surface_texture:
		RenderingServer.call_on_render_thread(_update_android_gl_texture)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cleanup()

# ── Public API ────────────────────────────────────────────────────────────────

func play() -> void:
	if _is_android:
		_setup_android()
	else:
		_setup_pc()


func stop() -> void:
	_cleanup()

func seek(seconds: float) -> void:
	if _is_android:
		if _media_player:
			_media_player.seekTo(int(seconds * 1000.0))
	elif _pc_player:
		_pc_player.stream_position = seconds

func is_playing() -> bool:
	if _is_android:
		return _media_player != null
	elif _pc_player:
		return _pc_player.is_playing()
	return false
	

# ── Android backend ───────────────────────────────────────────────────────────

func _setup_android() -> void:
	if android_video_path.is_empty():
		_emit_error("android_video_path is not set.")
		return

	# Build the shader and material entirely in code — nothing in the scene file.
	var shader := Shader.new()
	shader.code = _ANDROID_SHADER_SRC

	var mat := ShaderMaterial.new()
	mat.shader = shader

	_ext_texture = ExternalTexture.new()
	_ext_texture.size = video_resolution

	mat.set_shader_parameter("android_video_texture", _ext_texture)
	self.material = mat
	self.texture = _ext_texture

	var native_id := _ext_texture.get_external_texture_id()
	print("[VideoRect] Android external texture ID: ", native_id)
	_initialize_android_decoder.call_deferred(native_id, android_video_path)


func _initialize_android_decoder(texture_id: int, video_path: String) -> void:
	print("[VideoRect] Initializing Android MediaPlayer...")

	var sanitized := video_path.replace("res://", "")

	var SurfaceTextureClass = JavaClassWrapper.wrap("android.graphics.SurfaceTexture")
	var SurfaceClass        = JavaClassWrapper.wrap("android.view.Surface")
	var MediaPlayerClass    = JavaClassWrapper.wrap("android.media.MediaPlayer")

	_android_surface_texture = SurfaceTextureClass.SurfaceTexture(texture_id)
	var android_surface      = SurfaceClass.Surface(_android_surface_texture)
	_media_player            = MediaPlayerClass.MediaPlayer()

	var context = Engine.get_singleton("AndroidRuntime").getActivity()
	var afd     = context.getAssets().openFd(sanitized)

	if afd == null:
		_emit_error("Could not open video asset: " + sanitized)
		return

	_media_player.setDataSource(afd.getFileDescriptor(), afd.getStartOffset(), afd.getLength())
	afd.close()

	_media_player.setSurface(android_surface)
	_media_player.setLooping(loop_video)
	_media_player.prepare()

	_android_listener_instance = _AndroidCompletionListener.new(self)
	_android_java_proxy = JavaClassWrapper.create_proxy(
		_android_listener_instance,
		["android.media.MediaPlayer$OnCompletionListener"]
	)
	_media_player.setOnCompletionListener(_android_java_proxy)

	_media_player.start()
	print("[VideoRect] Android hardware decode started.")
	video_started.emit()


func _update_android_gl_texture() -> void:
	if _android_surface_texture:
		_android_surface_texture.updateTexImage()


func _on_android_video_finished() -> void:
	print("[VideoRect] Android playback finished.")
	video_finished.emit()

# ── PC backend ────────────────────────────────────────────────────────────────

func _setup_pc() -> void:
	if pc_video_stream == null:
		_emit_error("pc_video_stream is not set.")
		return

	_pc_player = VideoStreamPlayer.new()
	_pc_player.stream        = pc_video_stream
	_pc_player.autoplay      = false
	_pc_player.loop          = loop_video
	_pc_player.expand        = true
	_pc_player.anchor_left   = 0.0
	_pc_player.anchor_top    = 0.0
	_pc_player.anchor_right  = 1.0
	_pc_player.anchor_bottom = 1.0
	_pc_player.offset_left   = 0.0
	_pc_player.offset_top    = 0.0
	_pc_player.offset_right  = 0.0
	_pc_player.offset_bottom = 0.0

	add_child(_pc_player)
	_pc_player.finished.connect(_on_pc_video_finished)
	_pc_player.play()

	print("[VideoRect] PC VideoStreamPlayer started.")
	video_started.emit()


func _on_pc_video_finished() -> void:
	print("[VideoRect] PC playback finished.")
	video_finished.emit()

# ── Shared cleanup ────────────────────────────────────────────────────────────

func _cleanup() -> void:
	if _media_player:
		_media_player.release()
		_media_player = null
	_android_surface_texture   = null
	_android_listener_instance = null
	_android_java_proxy        = null
	_ext_texture               = null
	self.material              = null

	if _pc_player and is_instance_valid(_pc_player):
		_pc_player.stop()
		_pc_player.queue_free()
		_pc_player = null

# ── Helpers ───────────────────────────────────────────────────────────────────

func _emit_error(msg: String) -> void:
	printerr("[VideoRect] ERROR: ", msg)
	video_error.emit(msg)

# ── Inner class: Android completion listener (GC-safe) ────────────────────────

class _AndroidCompletionListener:
	var _parent: TextureRect

	func _init(parent: TextureRect) -> void:
		_parent = parent

	func onCompletion(_mp) -> void:
		if _parent and is_instance_valid(_parent):
			_parent.call_deferred("_on_android_video_finished")
