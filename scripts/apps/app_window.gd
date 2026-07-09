class_name AppWindow
extends RefCounted

## A single "slot" that can host one running app at a time - e.g. the main
## curved panel, a popup surface, a fixed display. Wraps whatever node
## actually presents content (an XRToolsViewport2DIn3D, or a plain Control
## apps get added to) behind a small interface: open()/go_back()/close().
##
## Owns its host's content directly (rather than delegating to
## XRToolsViewport2DIn3D.set_scene()) so that navigating forward can park
## the outgoing instance - hidden, kept alive, off the scene tree - instead
## of destroying it. Going back then restores that exact instance with
## whatever state it had, not a freshly relaunched one.
##
## Created via WindowManager.register_window(), not directly.

signal app_opened(instance: Node, manifest: AppManifest)
signal app_closed(manifest: AppManifest)

var id: StringName
var host: Node
var max_history: int

var current_manifest: AppManifest = null
var current_instance: Node = null
var current_context: AppContext = null

## When true, go_back() is a no-op. For flows that must not be escapable via
## the controller's universal back button - e.g. mandatory onboarding - since
## those already run with keep_history=false and have nothing to fall back
## to, letting go_back() through would tear down the current step with
## nothing to restore it to.
var back_navigation_locked: bool = false

var _sub_viewport: Node = null
var _back_stack: Array[Dictionary] = []  # [{manifest, instance, context}, ...]
var _adopted_stray_children: bool = false


func _init(p_id: StringName, p_host: Node, p_max_history: int = 8) -> void:
	id = p_id
	host = p_host
	max_history = p_max_history
	if host and host.has_node("Viewport"):
		_sub_viewport = host.get_node("Viewport")


## Opens manifest into this window.
##
## Never creates a second instance of an app that's already running in this
## window: if manifest.id is already current, it's just refocused; if it's
## sitting parked on the back-stack, that exact instance is brought back to
## the front instead of a fresh one being instantiated (so e.g. reopening
## Settings while it's parked behind Debug returns to the same instance,
## same page, same scroll position - not a new one).
##
## Otherwise, when keep_history is true (default) and something else is
## already open, that instance is parked on this window's back-stack - kept
## alive, taken off the tree, not freed - so go_back() can later return to
## it. When false, the outgoing instance is destroyed outright and no
## history entry is created (use this for flows with their own dedicated
## forward/back navigation, e.g. a linear onboarding sequence, so the
## controller back button doesn't also walk through it).
func open(manifest: AppManifest, args: Dictionary = {}, keep_history: bool = true) -> Node:
	if not manifest or not manifest.scene:
		push_error("[AppWindow:%s] app manifest is missing a scene (id=%s)" % [id, manifest.id if manifest else "?"])
		return null

	if not is_instance_valid(host):
		push_error("[AppWindow:%s] host node is no longer valid" % id)
		return null

	if current_manifest and current_manifest.id == manifest.id and is_instance_valid(current_instance):
		current_context.args = args
		if current_instance.has_method("_on_app_reopen"):
			current_instance._on_app_reopen(args, current_context)
		return current_instance

	var reused: Dictionary = _take_from_stack(manifest.id)

	if is_instance_valid(current_instance):
		if keep_history:
			_park_current()
		else:
			_destroy_current()

	if not reused.is_empty():
		current_manifest = reused["manifest"]
		current_instance = reused["instance"]
		current_context = reused["context"]
		current_context.args = args
		_add_instance(current_instance)
		if current_instance.has_method("_on_app_reopen"):
			current_instance._on_app_reopen(args, current_context)
		if current_instance.has_method("_on_app_focus"):
			current_instance._on_app_focus()
		app_opened.emit(current_instance, current_manifest)
		return current_instance

	var instance: Node = manifest.scene.instantiate()
	_add_instance(instance)

	if host.is_inside_tree():
		await host.get_tree().process_frame

	if not is_instance_valid(instance):
		return null

	current_manifest = manifest
	current_instance = instance
	current_context = AppContext.new(self, manifest, args)

	if instance.has_method("_on_app_launch"):
		instance._on_app_launch(args, current_context)
	if instance.has_method("_on_app_focus"):
		instance._on_app_focus()

	app_opened.emit(instance, manifest)
	return instance


## The universal-back algorithm: gives the current app a chance to handle
## it itself first (e.g. a settings app wanting to go to its own previous
## page instead of closing outright); only if it declines - or doesn't
## implement the hook at all - do we dismiss it. Returns true if anything
## happened.
func go_back() -> bool:
	if back_navigation_locked:
		return false
	if is_instance_valid(current_instance) and current_instance.has_method("_on_universal_back"):
		if current_instance._on_universal_back():
			return true
	return dismiss_current()


## Closes the current app and reveals whatever's behind it on the
## back-stack (restoring that exact instance), or hard-closes if there's
## nothing to go back to. Unlike go_back(), this skips the current app's
## own _on_universal_back override - it's for the app (or something acting
## on its behalf) deciding for itself that it's done.
func dismiss_current() -> bool:
	if _back_stack.is_empty():
		if is_instance_valid(current_instance):
			close()
			return true
		return false

	_destroy_current()
	var entry: Dictionary = _back_stack.pop_back()
	_restore(entry)
	return true


func can_go_back() -> bool:
	return not _back_stack.is_empty()


## Hard close: destroys the current instance and drops the entire
## back-stack. No history is preserved after this.
func close() -> void:
	_destroy_current()
	while not _back_stack.is_empty():
		_free_entry(_back_stack.pop_back())


func get_instance() -> Node:
	return current_instance


func get_context() -> AppContext:
	return current_context


## Removes and returns the parked back-stack entry for app_id, if any, so
## the caller can restore it instead of creating a duplicate instance.
func _take_from_stack(app_id: String) -> Dictionary:
	for i in range(_back_stack.size()):
		var entry: Dictionary = _back_stack[i]
		var entry_manifest: AppManifest = entry.get("manifest")
		if entry_manifest and entry_manifest.id == app_id:
			_back_stack.remove_at(i)
			return entry
	return {}


func _target_parent() -> Node:
	return _sub_viewport if _sub_viewport else host


func _add_instance(instance: Node) -> void:
	var parent := _target_parent()
	# The host may already have its own default scene instantiated (e.g.
	# XRToolsViewport2DIn3D's own @export scene ran before we ever touched
	# it) - adopt/clear that once so we don't end up with two overlapping
	# children.
	if not _adopted_stray_children:
		for stray in parent.get_children():
			parent.remove_child(stray)
			stray.queue_free()
		_adopted_stray_children = true
	parent.add_child(instance)
	if "scene_node" in host:
		host.scene_node = instance


func _park_current() -> void:
	if current_instance.has_method("_on_app_unfocus"):
		current_instance._on_app_unfocus()

	var parent := current_instance.get_parent()
	if parent:
		parent.remove_child(current_instance)

	_back_stack.append({
		"manifest": current_manifest,
		"instance": current_instance,
		"context": current_context,
	})
	while _back_stack.size() > max_history:
		_free_entry(_back_stack.pop_front())

	current_manifest = null
	current_instance = null
	current_context = null


func _restore(entry: Dictionary) -> void:
	current_manifest = entry["manifest"]
	current_instance = entry["instance"]
	current_context = entry["context"]

	_add_instance(current_instance)

	if current_instance.has_method("_on_app_focus"):
		current_instance._on_app_focus()

	app_opened.emit(current_instance, current_manifest)


func _destroy_current() -> void:
	if not is_instance_valid(current_instance):
		current_manifest = null
		current_context = null
		return

	if current_instance.has_method("_on_app_close"):
		current_instance._on_app_close()

	var closed_manifest := current_manifest
	current_instance.queue_free()

	current_manifest = null
	current_instance = null
	current_context = null

	app_closed.emit(closed_manifest)


func _free_entry(entry: Dictionary) -> void:
	var instance: Node = entry.get("instance")
	if is_instance_valid(instance):
		if instance.has_method("_on_app_close"):
			instance._on_app_close()
		instance.queue_free()
