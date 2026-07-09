class_name AppBase
extends Control

## Optional convenience base class for apps whose root is a Control.
## Entirely optional - AppWindow calls _on_app_launch/_on_app_close on
## whatever instance it's given via duck typing, so existing scenes don't
## need to extend this to participate. Use it when starting a new app from
## scratch and you want the context stashed for you.

var context: AppContext


func _on_app_launch(_args: Dictionary, p_context: AppContext) -> void:
	context = p_context


## Called instead of _on_app_launch when this exact instance was already
## running (current or parked) and got reactivated rather than recreated -
## context.args reflects the new call, context itself is unchanged.
func _on_app_reopen(_args: Dictionary, _context: AppContext) -> void:
	pass


func _on_app_close() -> void:
	pass


## Override to intercept the universal back button (controller B/Y) instead
## of the default "close this app, reveal whatever was open before it".
## Return true if you handled it (e.g. went to your own previous page)
## false to fall through to the default behavior.
func _on_universal_back() -> bool:
	return false


func close() -> void:
	if context:
		context.close()
