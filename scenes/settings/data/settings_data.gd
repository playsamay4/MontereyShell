class_name SettingsData

static var PAGES = {
	"index":
	[
		{"name": "SETTINGS_DEVICE", "pageID": "device_main"},
		{"name": "SETTINGS_GUARDIAN", "pageID": ""},
		{"name": "SETTINGS_STORAGE", "pageID": ""},
		{"name": "SETTINGS_APPLICATIONS", "pageID": ""},
		{"name": "SETTINGS_VIRTUAL_ENVIRONMENT", "pageID": ""},
		{"name": "SETTINGS_EXPERIMENTAL_FEATURES", "pageID": "experimental_main"},
		{"name": "SETTINGS_DEVELOPER", "pageID": "developer_main"},
		{"name": "SETTINGS_ABOUT", "pageID": "about_main"},
	],
		
	
	"device_main": {
		"title": "SETTINGS_DEVICE",
		"options": [
			{"id": "dndEnabled", "type": "toggle", "header": "SETTINGS_DND", "subtitle": "SETTINGS_DND_SUBTITLE", "icon": "res://images/oc_icon_disturb_on_2_24_ffffff.png"},
			{"id": "microphoneEnabled", "type": "toggle", "header": "SETTINGS_MICROPHONE",  "icon": "res://images/oc_icon_microphone_on_filled_24_d2d2d2.png"},
			{"id": "wifiExternal", "type": "external", "header": "SETTINGS_WIFI", "subtitle": "Placeholder-5G", "icon": "res://images/oc_icon_wifi_on_filled_2_24_d2d3d4.png"},
			{"id": "languageDropdown", "type": "dropdown", "header": "SETTINGS_LANGUAGE",  "icon": "res://images/oc_icon_world_filled_24_d2d2d2.png", "dropdown_keys": [""]},
			{"id": "privacyPage", "type": "page", "header": "SETTINGS_PRIVACY", "subtitle": "", "icon": "res://images/oc_icon_privacy_filled_24_dadada.png", "target_page": "device_privacy"},
			{"id": "notificationsPage", "type": "page", "header": "SETTINGS_NOTIFICATIONS", "subtitle": "SETTINGS_NOTIFICATIONS_SUBTITLE", "icon": "res://images/aui/tabs/notifications/ic_notifications.png", "target_page": "notifications"}
		]
	},
	"device_privacy": {
		"title": "SETTINGS_PRIVACY",
		"options": [
			
		]
	},
	"notifications": {
		"title": "SETTINGS_NOTIFICATIONS",
		"options": [
			{"id": "notiSubText", "type": "text",  "subtitle": "Define your headset notification preferences", },
			{"id": "notiMyActivity", "type": "toggle", "header": "My activity", "subtitle": "Learn about the experiences you use"},
			{"id": "4308290423", "type": "text", "header": "To be continued :D"},
			
		]
	},
	"developer_main": {
		"title": "SETTINGS_DEVELOPER",
		"options": [
			{"id": "devAudioStyle", "type": "dropdown", "header": "UI Audio", "subtitle": "Select which UI sounds you want to use", "icon": "res://images/aui/tabs/settings/ic_volume.png", "dropdown_keys": ["v3", "v16", "Modern"]},
			{"id": "devStartNux", "type": "button", "header": "Restart NUX", "subtitle": "Clears provisioning data and restarts NUX", "buttonText":"Start"},

		]
	},
	
	"experimental_main": {
			"title": "SETTINGS_EXPERIMENTAL_FEATURES",
			"options":
				[
					{"id": "experimentUseBootSequence", "type": "toggle", "header": "Power On Sequence", "subtitle": "Simulates the Quest's power on sequence upon launch"}
				]
		},
	
	"about_main": {
		"title": "SETTINGS_ABOUT",
		"options": [
			{
				"id": "aboutSwUpdate", "type": "button", "header":"SETTINGS_OTA_TITLE", "subtitle": "SETTINGS_OTA_CHECKING", 
				"subtitleSource": 
					{"target": "SettingsManager", "method": "get_update_info"}, 
				"subtitleChangeSignal": 
					{"target": "SettingsManager", "signal": "got_update_info"},
				"buttonSource": 
					{"target": "SettingsManager", "method": "get_button_update_text"}, 
				"buttonChangeSignal": 
					{"target": "SettingsManager", "signal": "got_button_update_text"}, 
				"buttonEnabledSource": 
					{"target": "SettingsManager", "method": "is_update_button_enabled"}, 
				"buttonEnabledChangeSignal": 
					{"target": "SettingsManager", "signal": "update_button_state_changed"}
				
			},
			{"id": "aboutVersion", "type": "text", "header":"SETTINGS_VERSION", "subtitleSource": {"target": "SettingsManager", "method": "get_version_info"}},
			{"id": "aboutTarget", "type": "text", "header":"SETTINGS_TARGET_VERSION", "subtitle": ""},
		]
	}
	
}
