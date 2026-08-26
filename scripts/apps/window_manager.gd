extends Node

## Registry of AppWindows (main panel, popup, etc). Scenes that host a
## window register it here on _ready(); anything else in the project opens
## apps by id through this autoload instead of loading .tscn paths and
## pushing them around over SignalBus.

var _windows: Dictionary = {}  # StringName -> AppWindow


## Wraps host (an XRToolsViewport2DIn3D-style node with a "Viewport" child,
## or a plain Control apps get added to directly) as a window identified by
## id. Re-registering an id replaces the previous window, which is expected
## when a scene owning a window gets reloaded - the old window (and
## anything still parked on its back-stack) is hard-closed first so nothing
## gets orphaned: Node instances aren't refcounted like the AppWindow that
## held them, so simply dropping the reference would leak them.
func register_window(id: StringName, host: Node, max_history: int = 8) -> AppWindow:
	var previous: AppWindow = _windows.get(id, null)
	if previous:
		previous.close()

	var window := AppWindow.new(id, host, max_history)
	_windows[id] = window
	return window


func unregister_window(id: StringName) -> void:
	var window: AppWindow = _windows.get(id, null)
	if window:
		window.close()
	_windows.erase(id)


func get_app_window(id: StringName) -> AppWindow:
	return _windows.get(id, null)


## Every currently-registered window id, e.g. for a debug launcher letting
## you pick which one to open an app into.
func get_window_ids() -> Array:
	return _windows.keys()


## keep_history defaults to true: the app currently open in window_id (if
## any) is parked rather than destroyed, so go_back() can return to it.
## Pass false for flows with their own dedicated forward/back navigation
## (e.g. a linear onboarding sequence) that shouldn't also show up on the
## controller's universal back button.
func open_app(window_id: StringName, app_id: String, args: Dictionary = {}, keep_history: bool = true) -> Node:
	var window: AppWindow = _windows.get(window_id, null)
	if not window:
		push_error("[WindowManager] Unknown window '%s'" % window_id)
		return null

	var manifest := AppRegistry.get_app(app_id)
	if not manifest:
		push_error("[WindowManager] Unknown app id '%s'" % app_id)
		return null

	return await window.open(manifest, args, keep_history)


## Universal-back entrypoint. Returns true if something happened.
func go_back(window_id: StringName) -> bool:
	var window: AppWindow = _windows.get(window_id, null)
	return window.go_back() if window else false


func can_go_back(window_id: StringName) -> bool:
	var window: AppWindow = _windows.get(window_id, null)
	return window.can_go_back() if window else false


## Locks/unlocks the controller's universal back button for window_id - see
## AppWindow.back_navigation_locked.
func set_back_navigation_locked(window_id: StringName, locked: bool) -> void:
	var window: AppWindow = _windows.get(window_id, null)
	if window:
		window.back_navigation_locked = locked


func close_app(window_id: StringName) -> void:
	var window: AppWindow = _windows.get(window_id, null)
	if window:
		window.close()


func get_current_app(window_id: StringName) -> AppManifest:
	var window: AppWindow = _windows.get(window_id, null)
	return window.current_manifest if window else null
