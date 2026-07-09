extends Node

## Scans res://apps/ for AppManifest resources and makes them available by
## id/category. Drop a new .tres under res://apps/ to register a new app -
## nothing else needs to hardcode it.

const APPS_DIR := "res://apps/"

var _apps_by_id: Dictionary = {}
var _apps: Array[AppManifest] = []


func _ready() -> void:
	_scan(APPS_DIR)
	SystemLog.log("[AppRegistry] Loaded %d app(s)" % _apps.size())


func register(manifest: AppManifest) -> void:
	if not manifest or manifest.id.is_empty():
		push_error("[AppRegistry] Refusing to register app with empty id (%s)" % (manifest.resource_path if manifest else "?"))
		return

	if _apps_by_id.has(manifest.id):
		push_warning("[AppRegistry] Duplicate app id '%s', replacing previous registration" % manifest.id)
		_apps.erase(_apps_by_id[manifest.id])

	_apps_by_id[manifest.id] = manifest
	_apps.append(manifest)


func get_app(id: String) -> AppManifest:
	return _apps_by_id.get(id, null)


func has_app(id: String) -> bool:
	return _apps_by_id.has(id)


func get_apps(category: String = "") -> Array[AppManifest]:
	if category.is_empty():
		return _apps.duplicate()

	var filtered: Array[AppManifest] = []
	for app in _apps:
		if app.category == category:
			filtered.append(app)
	return filtered


func get_categories() -> Array[String]:
	var seen: Array[String] = []
	for app in _apps:
		if not seen.has(app.category):
			seen.append(app.category)
	seen.sort()
	return seen


func _scan(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		push_warning("[AppRegistry] apps directory not found: %s" % path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_scan(path.path_join(file_name))
		else:
			# Exported builds convert .tres to binary and list the packed
			# entry as "name.tres.remap" instead of "name.tres" - load()
			# still resolves the original res:// path fine either way.
			var resource_name := file_name.trim_suffix(".remap")
			if resource_name.ends_with(".tres"):
				_try_register(path.path_join(resource_name))
		file_name = dir.get_next()
	dir.list_dir_end()


func _try_register(res_path: String) -> void:
	var res: Resource = load(res_path)
	if res is AppManifest:
		register(res)
	else:
		push_warning("[AppRegistry] %s is not an AppManifest, skipping" % res_path)
