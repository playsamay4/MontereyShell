extends Node 

const SAVE_PATH = "user://settings.cfg"

const _BUILD_INFO = {
	"version":"0.0.1.001.20260618",
	"targetVersion":"16"
}

func get_version_info() -> String:
	return _BUILD_INFO["version"]

signal got_update_info()
signal got_button_update_text(text)
signal update_button_state_changed()

signal system_setting_changed(id: String, val: Variant)

const DEFAULTS = {
	"settings":
		{
			"locale":"en",
			"dndEnabled": false,
			"microphoneEnabled": true,
			
			
			
			"devAudioStyle": "v16"
			
		}
}

const LOCALES = [
	"en",
	"de-DE"
]


#TODO: Implement real update check in its own manager
var updateData = ""
var current_button_text: String = ""
var enable_update_button: bool = false
func get_update_info():
	if updateData == "":
		initiate_update_check()
		return "SETTINGS_OTA_CHECKING"
	else:
		return "System Version " + _BUILD_INFO.version
	
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
 

var _settings: Dictionary = {}

func _ready() -> void:
	load_data()

func get_value(section: String, key: String) -> Variant:
	if _settings.has(section) and _settings[section].has(key):
		return _settings[section][key]
		
	if DEFAULTS.has(section) and DEFAULTS[section].has(key):
		return DEFAULTS[section][key]
		
	return null

func set_value(section: String, key: String, value: Variant) -> bool:
	if not DEFAULTS.has(section) or not DEFAULTS[section].has(key):
		print("attempted to set an invalid setting: ", section, "/", key)
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
		print(" Settings loaded and merged successfully")
	else:
		print("First boot or missing config, Using  defaults")
