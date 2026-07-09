class_name AppContext
extends RefCounted

## Handed to an app instance when it is launched (see AppWindow.open).
## This is the app's API surface into the shell - apps should prefer this
## over reaching into SignalBus/WindowManager/other autoloads directly,
## so the shell can change how windows/launching work without every app
## needing to know about it.

var window: AppWindow
var manifest: AppManifest
var args: Dictionary = {}

func _init(p_window: AppWindow, p_manifest: AppManifest, p_args: Dictionary = {}) -> void:
	window = p_window
	manifest = p_manifest
	args = p_args


## Closes this app instance. If something was open before it (i.e. it was
## reached via history), that instance is revealed again - the same way
## the universal back button would leave things. If not, this is the last
## thing on the window and it hard-closes.
func close() -> void:
	if window:
		window.dismiss_current()


## Opens another app into a (possibly different) window. Defaults to the
## window this app is already running in.
func launch_app(app_id: String, launch_args: Dictionary = {}, window_id: StringName = &"") -> Node:
	var target_window_id := window_id
	if target_window_id == &"" and window:
		target_window_id = window.id
	return await WindowManager.open_app(target_window_id, app_id, launch_args)


## Shows the shell's simple config-driven modal dialog and returns the
## reason ("action"/"primary"/"cancel") once it's dismissed.
func open_popup(config: Dictionary) -> String:
	return await PopupManager.show_popup(config)
