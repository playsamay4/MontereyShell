@tool
extends EditorPlugin

var export_stamper: MyExportStamper

func _enter_tree() -> void:
	export_stamper = MyExportStamper.new()
	add_export_plugin(export_stamper)

func _exit_tree() -> void:
	if export_stamper:
		remove_export_plugin(export_stamper)
		export_stamper = null

class MyExportStamper extends EditorExportPlugin:
	
	const WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
	const MONTHS = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	const COUNTER_PATH = "res://.build_counter.txt"
	
	func _get_name() -> String:
		return "ExportStamper"

	func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
		var current_date = get_formatted_datetime()
		var build_numbers = get_and_increment_build_number()
		var fingerprint = generate_android_fingerprint(build_numbers.display_ver, is_debug)
		
		var build_data = {
			"date": current_date,
			"build_code": build_numbers.code,
			"fingerprint": fingerprint,
			"type": "user",
			"display": ""
		}
		
		if is_debug:
			build_data.type = "userdebug"
			
		build_data.display = build_data.type + "-" + build_numbers.code
		
		var json_string = JSON.stringify(build_data)
		var file_bytes = json_string.to_utf8_buffer()
		
		add_file("res://build_info.txt", file_bytes, false)
		
	func get_formatted_datetime() -> String:
		var dt = Time.get_datetime_dict_from_system()
		var tz = Time.get_time_zone_from_system()
		var tz_name = tz.name if tz.name != "" else "UTC"
		
		return "%s %s %02d %02d:%02d:%02d %s %d" % [
			WEEKDAYS[dt.weekday], MONTHS[dt.month], dt.day, 
			dt.hour, dt.minute, dt.second, tz_name, dt.year
		]


	func get_and_increment_build_number() -> Dictionary:
		var current_count = 256550 
		
		if FileAccess.file_exists(COUNTER_PATH):
			var file = FileAccess.open(COUNTER_PATH, FileAccess.READ)
			if file:
				current_count = file.get_64()
				file.close()
		
		var next_count = current_count + 1
		var file = FileAccess.open(COUNTER_PATH, FileAccess.WRITE)
		if file:
			file.store_64(next_count)
			file.close()
			

		var branch_id = (current_count / 5) + 6400 
		
		var patch_ver = current_count % 10
		
		var display_str = "%d.%d.%d" % [current_count, branch_id, patch_ver]
		
		var code_str = "%d%02d%04d%03d%d" % [
			current_count, # 6 digits
			0,             # 2 padding zeros
			branch_id,     # 4 digits
			0,             # 3 padding zeros
			patch_ver      # 1 digit
		]
		
		return {"code": code_str, "display_ver": display_str}

	func generate_android_fingerprint(incremental_version: String, is_debug: bool) -> String:
		var brand = "oculus"
		var product = "vr_monterey"
		var device = "monterey"
		var android_release = "7.1.1"
		var build_id = "NGI77B"
		var build_type = "user"
		var build_tags = "release-keys"
		
		if is_debug:
			build_type = "userdebug"
		
		var template = "%s/%s/%s:%s/%s/%s:%s/%s"
		return template % [
			brand, product, device, android_release, 
			build_id, incremental_version, build_type, build_tags
		]
