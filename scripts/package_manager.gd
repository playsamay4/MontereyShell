extends Node

class AppData:
	var name: String = ""
	var install_time_ms: int = 0
	var package_id: String = ""
	var icon_texture: Texture2D = null
	var icon_loaded: bool = false

var installed_apps: Array[AppData] = []
var plugin = null

var queue_timer: Timer
var request_queue: Array[AppData] = []
const QUEUE_DELAY_SEC: float = 0.001 

const CACHE_DIR: String = "user://icon_cache/"
const FAIL_LOG_PATH: String = "user://failed_fetches.txt"

const BLACKLIST: Array[String] = [
	"com.oculus.systemux", "com.oculus.vrshell", "com.oculus.panelapp.settings",
	"com.oculus.panelapp.library", "com.oculus.panelapp.kiosk", "com.oculus.panelapp.calendar",
	"com.oculus.panelapp.devicepairing", "com.oculus.socialplatform", "com.oculus.assistant",
	"com.oculus.metacam", "com.oculus.identitymanagement.service", 
	"com.oculus.xrstreamingclient", "com.android.settings", "com.android.documentsui",
	"com.meta.surfacetypingnux", "com.meta.HyperscapeHmdCapture", "com.meta.pclinkservice.server",
	"com.meta.handseducationmodule",
	"com.meta.quest_hard_link", "com.oculus.samples.isdkdemo",
	"com.oculus.xrsamples.xrsimdataforwardingserver", "com.threethan.launcher.service.navigator",
	"moe.shizuku.privileged.api", "com.oculus.avatareditor", "com.oculus.firsttimenux",
	"com.oculus.guardiansetup", "com.oculus.guidebook", "com.oculus.horizonmediaplayer",
	"com.oculus.hzosgallery", "com.oculus.os.chargecontrol", "com.oculus.os.clearactivity",
	"com.oculus.os.qrcodereader", "com.oculus.os.voidactivity", "com.oculus.store",
	"com.oculus.systemutilities", "com.oculus.accountscenter", "com.oculus.helpcenter"
]

# Tracks persistent server failures in memory across the current execution loop
var failure_tracker: Dictionary = {}

signal app_icon_updated(package_id: String, texture: Texture2D)
signal apps_refreshed

func _ready() -> void:
	_ensure_cache_dir_exists()
	_load_failure_log()

	queue_timer = Timer.new()
	queue_timer.one_shot = true
	queue_timer.wait_time = QUEUE_DELAY_SEC
	queue_timer.timeout.connect(_process_next_queue_item)
	add_child(queue_timer)

	if OS.get_name() == "Android":
		if Engine.has_singleton("LauncherPlugin"):
			plugin = Engine.get_singleton("LauncherPlugin")
			print("[PackageManager] LauncherPlugin singleton linked ")
			plugin.connect("network_fetch_completed", _on_native_network_completed)
			get_installed_packages() 
			get_tree().create_timer(1.0).timeout.connect(_cache_all_icons)
		else:
			push_error("[PackageManager] LauncherPlugin not found")
	else:
		print("[PackageManager] Not Android, loading mock data")
		_load_mock_data()
	
	

func get_installed_packages() -> void:
	if not installed_apps.is_empty():
		return
		
	var raw = plugin.getInstalledApps()
	var i = 0
	while i + 1 < raw.size():
		var app = AppData.new()
		app.name = raw[i]
		app.package_id = raw[i + 1]
		app.install_time_ms = int(raw[i + 2])
		installed_apps.append(app)
		i += 3
		
	print("[PackageManager] Successfully parsed and loaded ", installed_apps.size(), " apps.")
	apps_refreshed.emit()

func launch_app(package_id: String) -> void:
	if plugin:
		plugin.launchApp(package_id)

func _cache_all_icons() -> void:
	if installed_apps.is_empty():
		return

	print("[PackageManager] Beginning caching...")
	request_queue.clear()
	
	var cached_count = 0
	var blacklisted_count = 0
	var soft_blacklisted_count = 0

	for app in installed_apps:
		var pkg_lower = app.package_id.to_lower().strip_edges()
		
		# Builtin blacklist rule
		var is_blacklisted = false
		for blacklisted_id in BLACKLIST:
			if pkg_lower.contains(blacklisted_id):
				is_blacklisted = true
				break
				
		if is_blacklisted:
			_load_fallback_native_icon(app)
			blacklisted_count += 1
			continue

		#Black list rule
		if failure_tracker.has(pkg_lower) and failure_tracker[pkg_lower] >= 2:
			_load_fallback_native_icon(app)
			soft_blacklisted_count += 1
			continue

		# saved icon Hit Lookup
		if _load_icon_from_local_cache(app):
			cached_count += 1
			continue
			
		_load_fallback_native_icon(app)
		request_queue.append(app)

	print("[PackageManager] Caching complete.")
	print(" -> Cache hits: ", cached_count)
	print(" -> Hard blacklisted: ", blacklisted_count)
	print(" -> cached Blacklisted (>=2 FAILS): ", soft_blacklisted_count)
	print(" -> sent to request Queue: ", request_queue.size())
	
	if not request_queue.is_empty():
		_process_next_queue_item()

func _process_next_queue_item() -> void:
	if request_queue.is_empty():
		print("[PackageManager] All queue network requests completed successfully")
		return
		
	var next_app = request_queue.pop_front()
	print("[PackageManager] Fetching missing online asset for: ", next_app.package_id)
	
	var clean_package_id = next_app.package_id.strip_edges()
	var meta_url = "https://cdn.jsdelivr.net/gh/threethan/MetaMetadata@main/data/oculus_public/" + clean_package_id + ".json"
	
	plugin.fetchNetworkDataAsync(meta_url, next_app.package_id, "json")

func _on_native_network_completed(package_id: String, request_type: String, response_bytes: PackedByteArray) -> void:
	var pkg_lower = package_id.to_lower().strip_edges()
	
	if response_bytes.is_empty():
		if request_type == "json":
			_register_failed_fetch(pkg_lower)
		queue_timer.start()
		return
		
	var app = null
	for a in installed_apps:
		if a.package_id.to_lower().strip_edges() == pkg_lower:
			app = a
			break
			
	if not app:
		queue_timer.start()
		return

	if request_type == "json":
		var body_str = response_bytes.get_string_from_utf8()
		var json = JSON.parse_string(body_str)
		var image_url = ""
		
		if json:
			if json.has("cover_square_image") and json["cover_square_image"].has("uri"):
				image_url = json["cover_square_image"]["uri"]
			elif json.has("icon_image") and json["icon_image"].has("uri"):
				image_url = json["icon_image"]["uri"]
				
		if not image_url.is_empty():
			plugin.fetchNetworkDataAsync(image_url, app.package_id, "image")
		else:
			_register_failed_fetch(pkg_lower)
			queue_timer.start()

	elif request_type == "image":
		var img = Image.new()
		var error = img.load_webp_from_buffer(response_bytes)
		var ext = ".webp"
		
		if error != OK:
			error = img.load_png_from_buffer(response_bytes)
			ext = ".png"
		if error != OK:
			error = img.load_jpg_from_buffer(response_bytes)
			ext = ".jpg"
			
		if error == OK:
			var texture = ImageTexture.create_from_image(img)
			app.icon_texture = texture
			app.icon_loaded = true
			app_icon_updated.emit(app.package_id, texture)
			_save_icon_to_local_cache(app.package_id, response_bytes, ext)
			
			if failure_tracker.has(pkg_lower):
				failure_tracker.erase(pkg_lower)
				_save_failure_log()
		else:
			_register_failed_fetch(pkg_lower)
		
		queue_timer.start()

func _load_fallback_native_icon(app: AppData) -> void:
	if not plugin or app.icon_loaded:
		return

	var icon_bytes = plugin.getAppIcon(app.package_id)
	if icon_bytes != null and icon_bytes.size() > 0:
		var img = Image.new()
		var error = img.load_png_from_buffer(icon_bytes)
		if error == OK:
			var texture = ImageTexture.create_from_image(img)
			app.icon_texture = texture
			app_icon_updated.emit(app.package_id, texture)
	
	app.icon_loaded = true




func _load_failure_log() -> void:
	failure_tracker.clear()
	if FileAccess.file_exists(FAIL_LOG_PATH):
		var file = FileAccess.open(FAIL_LOG_PATH, FileAccess.READ)
		if file:
			var test_json = file.get_as_text()
			var parsed = JSON.parse_string(test_json)
			if parsed is Dictionary:
				failure_tracker = parsed

func _save_failure_log() -> void:
	var file = FileAccess.open(FAIL_LOG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(failure_tracker))

func _register_failed_fetch(pkg_lower: String) -> void:
	if not failure_tracker.has(pkg_lower):
		failure_tracker[pkg_lower] = 1
	else:
		failure_tracker[pkg_lower] += 1
	
	print("[PackageManager] Incrementing fetch failures for: ", pkg_lower, " (Total: ", failure_tracker[pkg_lower], ")")
	_save_failure_log()

# ==========================================
#        cahce storage managment
# ==========================================

func _ensure_cache_dir_exists() -> void:
	var dir = DirAccess.open("user://")
	if not dir.dir_exists(CACHE_DIR):
		dir.make_dir_recursive(CACHE_DIR)

func _get_cache_file_path(package_id: String, ext: String) -> String:
	var safe_name = package_id.to_lower().strip_edges().replace("/", "_")
	return CACHE_DIR + safe_name + ext

func _load_icon_from_local_cache(app: AppData) -> bool:
	for ext in [".webp", ".png", ".jpg"]:
		var path = _get_cache_file_path(app.package_id, ext)
		if FileAccess.file_exists(path):
			var file = FileAccess.open(path, FileAccess.READ)
			if file:
				var buffer = file.get_buffer(file.get_length())
				var img = Image.new()
				var error = OK
				
				match ext:
					".webp": error = img.load_webp_from_buffer(buffer)
					".png":  error = img.load_png_from_buffer(buffer)
					".jpg":  error = img.load_jpg_from_buffer(buffer)
					
				if error == OK:
					var texture = ImageTexture.create_from_image(img)
					app.icon_texture = texture
					app.icon_loaded = true
					app_icon_updated.emit(app.package_id, texture)
					return true
	return false

func _save_icon_to_local_cache(package_id: String, bytes: PackedByteArray, ext: String) -> void:
	var path = _get_cache_file_path(package_id, ext)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_buffer(bytes)

func clear_icon_cache() -> void:
	# Clean images
	var dir = DirAccess.open(CACHE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				dir.remove(file_name)
			file_name = dir.get_next()
	
	# Reset failure metrics completely
	failure_tracker.clear()
	_save_failure_log()
	print("[PackageManager] cache folders and failure registries cleared")
	
	for app in installed_apps:
		app.icon_loaded = false
	_cache_all_icons()

func get_external_cache_dir() -> String:
	if OS.get_name() == "Android":
		return "/sdcard/Download/monterey_icon_cache/"
	else:
		var downloads_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
		if not downloads_dir.is_empty():
			return downloads_dir.path_join("monterey_icon_cache")
		return "user://../monterey_external_icon_cache/"

func export_icon_cache(target_dir: String = "") -> Dictionary:
	if target_dir.is_empty():
		target_dir = get_external_cache_dir()

	_ensure_cache_dir_exists()

	var err = DirAccess.make_dir_recursive_absolute(target_dir)
	if err != OK and OS.get_name() == "Android" and target_dir != "/sdcard/MontereyShell/icon_cache/":
		var alt_target = "/sdcard/MontereyShell/icon_cache/"
		var alt_err = DirAccess.make_dir_recursive_absolute(alt_target)
		if alt_err == OK:
			target_dir = alt_target
			err = OK

	if err != OK:
		var err_msg = "Failed to create export directory:\n%s\n(Godot Error Code: %d)" % [target_dir, err]
		print("[PackageManager] ", err_msg)
		return {
			"success": false,
			"count": 0,
			"path": target_dir,
			"error_code": err,
			"error_message": err_msg
		}

	var cache_dir_access = DirAccess.open(CACHE_DIR)
	if not cache_dir_access:
		var err_msg = "Internal cache dir unreachable: %s" % CACHE_DIR
		print("[PackageManager] ", err_msg)
		return {
			"success": false,
			"count": 0,
			"path": target_dir,
			"error_code": -1,
			"error_message": err_msg
		}

	var exported_count = 0
	var copy_errors = 0
	cache_dir_access.list_dir_begin()
	var file_name = cache_dir_access.get_next()
	while file_name != "":
		if not cache_dir_access.current_is_dir():
			var src = CACHE_DIR + file_name
			var dst = target_dir.path_join(file_name)
			var c_err = DirAccess.copy_absolute(src, dst)
			if c_err == OK:
				exported_count += 1
			else:
				copy_errors += 1
				print("[PackageManager] Failed to copy ", src, " to ", dst, " Error: ", c_err)
		file_name = cache_dir_access.get_next()

	if FileAccess.file_exists(FAIL_LOG_PATH):
		DirAccess.copy_absolute(FAIL_LOG_PATH, target_dir.path_join("failed_fetches.txt"))

	print("[PackageManager] Exported ", exported_count, " icons to ", target_dir)
	return {
		"success": true,
		"count": exported_count,
		"copy_errors": copy_errors,
		"path": target_dir,
		"error_code": OK,
		"error_message": ""
	}

func restore_icon_cache(source_dir: String = "") -> Dictionary:
	if source_dir.is_empty():
		source_dir = get_external_cache_dir()

	if not DirAccess.dir_exists_absolute(source_dir):
		if OS.get_name() == "Android" and source_dir != "/sdcard/MontereyShell/icon_cache/":
			var alt_source = "/sdcard/MontereyShell/icon_cache/"
			if DirAccess.dir_exists_absolute(alt_source):
				source_dir = alt_source

	if not DirAccess.dir_exists_absolute(source_dir):
		var err_msg = "External backup dir not found at:\n%s" % source_dir
		print("[PackageManager] ", err_msg)
		return {
			"success": false,
			"count": 0,
			"path": source_dir,
			"error_code": -1,
			"error_message": err_msg
		}

	var source_dir_access = DirAccess.open(source_dir)
	if not source_dir_access:
		var err_msg = "Cannot access external backup dir at:\n%s" % source_dir
		print("[PackageManager] ", err_msg)
		return {
			"success": false,
			"count": 0,
			"path": source_dir,
			"error_code": -1,
			"error_message": err_msg
		}

	_ensure_cache_dir_exists()

	source_dir_access.list_dir_begin()
	var file_name = source_dir_access.get_next()
	var restored_count = 0
	while file_name != "":
		if not source_dir_access.current_is_dir():
			var src = source_dir.path_join(file_name)
			if file_name == "failed_fetches.txt":
				DirAccess.copy_absolute(src, FAIL_LOG_PATH)
			else:
				var dst = CACHE_DIR + file_name
				if DirAccess.copy_absolute(src, dst) == OK:
					restored_count += 1
		file_name = source_dir_access.get_next()

	_load_failure_log()
	for app in installed_apps:
		app.icon_loaded = false
	_cache_all_icons()
	print("[PackageManager] Restored ", restored_count, " icons from ", source_dir)
	return {
		"success": true,
		"count": restored_count,
		"path": source_dir,
		"error_code": OK,
		"error_message": ""
	}


func _load_mock_data() -> void:
	for i in range(25):
		var mock = AppData.new()
		mock.name = "Mock App " + str(i)
		mock.package_id = "com.mock.app" + str(i)
		installed_apps.append(mock)
	apps_refreshed.emit()
