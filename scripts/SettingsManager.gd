extends Node 

const SAVE_PATH = "user://settings.cfg"

var BUILD_INFO = {
	"BOARD": "monterey",
	"BOOTLOADER": "unknown",
	"BRANCH": "releases-main-0.0.1",
	"DATE": "unknown",
	"DEVICE": "monterey",
	"DISPLAY": "unknown",
	"FINGERPRINT": "unknown",
	"MANUFACTURER": "Oculus",
	"MODEL": "Quest",
	"TYPE": "user",
	"BUILD_NUMBER": "unknown",
	
	
	
	"version":"0.0.1.001.20260618",
	"targetVersion":"16"
}



signal got_update_info()
signal got_button_update_text(text)
signal update_button_state_changed()

signal system_setting_changed(id: String, val: Variant)


enum NUX_STATUS {
	NEW_DEVICE, # Unprovisioned
	APP_NUX_COMPLETE, # finished linking with app
	DAY0_NO_OTA, #OTA not ready yet
	DAY0_OTA_READY, # OTA Downloaded and ready to install,
	WAITING_FOR_REBOOT,
	REBOOTING,
	WAITING_FOR_HIGH_PRI_APPS_DOWNLOAD, # NUX stage 2
	NOTIFY_ENDPOINT, # download complete
	NUX_COMPLETE
}
var NUX_STATUS_NAME = NUX_STATUS.keys()


const DEFAULTS = {
	"settings":
		{
			"locale":"en",
			"dndEnabled": false,
			"microphoneEnabled": true,
			
			
			#Experiments
			"experimentUseBootSequence": false,
			
			"devAudioStyle": "v16",
			
			
			"nuxStatus": NUX_STATUS.NUX_COMPLETE,
			
			
			"nuxType": "full_vr"
		}
}

const LOCALES = [
	"en",
	"de-DE",
	"es-ES",
	"fr-FR"
]




var _settings: Dictionary = {}

func get_pairing_code() -> String:
	var unique_id = OS.get_unique_id()
	
	if unique_id.is_empty():
		#Yes this will change on restart but idc
		unique_id = "MONTEREY" + Time.get_datetime_string_from_system()
	
	var hashed_int: int = abs(unique_id.hash())
	
	var pairing_code: int = (hashed_int % 90000) + 10000
	
	return str(pairing_code)
	

func _ready() -> void:
	if FileAccess.file_exists("res://build_info.txt"):
		var file = FileAccess.open("res://build_info.txt", FileAccess.READ)
		if file:
			var raw_text = file.get_as_text()
			file.close()
			
			var parsed_data = JSON.parse_string(raw_text)
			
			if parsed_data is Dictionary:
				BUILD_INFO["DATE"] = parsed_data.get("date", "unknown")
				BUILD_INFO["DISPLAY"] = parsed_data.get("build_code", "0")
				BUILD_INFO["FINGERPRINT"] = parsed_data.get("fingerprint", "unknown")
				BUILD_INFO["DISPLAY"] = parsed_data.get("display", "unknown")
				BUILD_INFO["TYPE"] = parsed_data.get("type", "user")
				BUILD_INFO["BUILD_NUMBER"] = parsed_data.get("build_code", "unknown")
				
	
	load_data()

func get_value(section: String, key: String) -> Variant:
	if _settings.has(section) and _settings[section].has(key):
		return _settings[section][key]
		
	if DEFAULTS.has(section) and DEFAULTS[section].has(key):
		return DEFAULTS[section][key]
		
	return null

func set_value(section: String, key: String, value: Variant) -> bool:
	if not DEFAULTS.has(section) or not DEFAULTS[section].has(key):
		SystemLog.log("attempted to set an invalid setting: ", section, "/", key)
		return false
		
	if not _settings.has(section):
		_settings[section] = {}
	
	_settings[section][key] = value
	_save_to_disk()
	system_setting_changed.emit(key, value)
	
	return true
func _save_to_disk() -> void:
	var config = ConfigFile.new()
	for section in _settings:
		for key in _settings[section]:
			config.set_value(section, key, _settings[section][key])
			
	var error = config.save(SAVE_PATH)
	if error != OK:
		push_error("Failed to save settings! Error code: ", error)

func load_data() -> void:
	_settings = DEFAULTS.duplicate(true)
	
	var config = ConfigFile.new()
	var error = config.load(SAVE_PATH)
	
	if error == OK:
		# Only overwrite keys that exist 
		for section in config.get_sections():
			for key in config.get_section_keys(section):
				if not _settings.has(section):
					_settings[section] = {}
				_settings[section][key] = config.get_value(section, key)
		SystemLog.log(" Settings loaded and merged successfully")
	else:
		SystemLog.log("First boot or missing config, Using  defaults")
		
# ==================================
# Software Update placeholder functions
# ==================================
var updateData = ""
var current_button_text: String = ""
var enable_update_button: bool = false
func get_update_info():
	if updateData == "":
		initiate_update_check()
		return "SETTINGS_OTA_CHECKING"
	else:
		return "System Version " + BUILD_INFO.BUILD_NUMBER
	
func get_button_update_text() -> String:
	if current_button_text == "":
		return "" 
	return current_button_text

func is_update_button_enabled() -> bool:
	return enable_update_button

func initiate_update_check():
	await get_tree().create_timer(3).timeout
	updateData = "NO UPDATES"
	current_button_text = "SETTINGS_OTA_NOT_AVAILABLE"
	enable_update_button = false
	got_update_info.emit()
	got_button_update_text.emit()
	update_button_state_changed.emit()

func get_version_info() -> String:
	return BUILD_INFO["version"]

func get_target_version_info() -> String:
	return BUILD_INFO["targetVersion"]

# ==================================
# NUX
# ==================================
func restart_nux() -> void:
	set_value("settings", "nuxStatus", NUX_STATUS.NEW_DEVICE)
	SignalBus.restart_home_requested.emit()

# =================
# Tools
# =================
func generate_seeded_uuid(seed_value: int) -> String:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	
	var bytes := PackedByteArray()
	for i in range(16):
		bytes.append(rng.randi_range(0, 255))
	
	bytes[6] = (bytes[6] & 0x0f) | 0x40 
	bytes[8] = (bytes[8] & 0x3f) | 0x80 

	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		bytes[0], bytes[1], bytes[2], bytes[3],
		bytes[4], bytes[5],
		bytes[6], bytes[7],
		bytes[8], bytes[9],
		bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
	]
 
