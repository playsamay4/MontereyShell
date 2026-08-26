extends Node

## Replaces the old SignalBus.popup_open_requested / popup_finish_requested
## pair. That design had a real bug: any caller doing
## `await SignalBus.popup_finish_requested` got resolved by *any* popup
## finishing, not just the one it asked for - two overlapping popup
## requests would cross-resolve each other's awaits with the wrong reason.
##
## show_popup() below returns a result scoped to that one call (each
## request gets its own signal), and queues requests instead of a second
## one clobbering the first mid-display.

class PopupRequest:
	extends RefCounted
	signal resolved(reason: String)
	var config: Dictionary
	func _init(p_config: Dictionary) -> void:
		config = p_config

var _host: Node = null
var _aui_bar: Node = null
var _popup_instance: Control = null
var _anim_player: AnimationPlayer = null

var _queue: Array[PopupRequest] = []
var _current: PopupRequest = null


## Wires this manager to the scene that actually hosts the popup surface.
## Call once from that scene's _ready(); re-registering (e.g. on scene
## reload) is expected, same as WindowManager.register_window - any request
## still pending against the old host is resolved with "" so it can't hang
## an awaiter forever.
func register(host: Node, popup_instance: Control, anim_player: AnimationPlayer, aui_bar: Node = null) -> void:
	_abort_pending()

	_host = host
	_popup_instance = popup_instance
	_anim_player = anim_player
	_aui_bar = aui_bar

	if not _popup_instance.button_pressed.is_connected(_on_button_pressed):
		_popup_instance.button_pressed.connect(_on_button_pressed)


## Shows config and returns the reason ("action"/"primary"/"cancel", or ""
## if aborted) once the user dismisses it. If a popup is already showing,
## this one queues and displays after.
##
## config["fade_in"] (float, seconds): if > 0, the popup content fades in
## over that duration instead of appearing instantly. Defaults to instant -
## most popups (dialogs, confirmations) should just be there; the slow
## fade is for specific moments like the NUX "update complete" popup.
func show_popup(config: Dictionary) -> String:
	var request := PopupRequest.new(config)
	_queue.append(request)
	if _queue.size() == 1:
		_present(request)
	return await request.resolved


func _present(request: PopupRequest) -> void:
	_current = request
	_popup_instance.setup_popup(request.config)

	var fade_in_duration: float = request.config.get("fade_in", 0.0)
	if fade_in_duration > 0.0:
		_popup_instance.fade_in(fade_in_duration)
	else:
		_popup_instance.show_instant()

	_host.visible = true
	if _aui_bar:
		_aui_bar.enabled = false
	if _anim_player:
		_anim_player.play("popup_in")


func _on_button_pressed(reason: String) -> void:
	if not _current:
		return

	var finished := _current
	_current = null
	if not _queue.is_empty():
		_queue.pop_front()

	if _anim_player:
		_anim_player.play("popup_out")
	if _aui_bar:
		_aui_bar.enabled = true
	if _queue.is_empty():
		_host.visible = false

	finished.resolved.emit(reason)

	if not _queue.is_empty():
		_present(_queue[0])


func _abort_pending() -> void:
	_current = null
	while not _queue.is_empty():
		var request: PopupRequest = _queue.pop_front()
		request.resolved.emit("")
