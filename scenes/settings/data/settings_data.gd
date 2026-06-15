class_name SettingsData

static var PAGES = {
	"device_main": {
		"title": "Device",
		"parent": "", #toplevel
		"options": [
			{"id": "dndEnabled", "type": "toggle", "header": "Do Not Disturb", "subtitle": "Mute all notifications in VR", "icon": "res://images/oc_icon_disturb_on_2_24_ffffff.png"},
			{"id": "microphoneEnabled", "type": "toggle", "header": "Microphone", "subtitle": "", "icon": "res://images/oc_icon_microphone_on_filled_24_d2d2d2.png"},
			{"id": "wifiExternal", "type": "external", "header": "Wi-Fi", "subtitle": "Placeholder-5G", "icon": "res://images/oc_icon_wifi_on_filled_2_24_d2d3d4.png"},
			{"id": "languageDropdown", "type": "dropdown", "header": "Language", "subtitle": "", "icon": "res://images/oc_icon_world_filled_24_d2d2d2.png", "dropdown_keys": ["Lang"]},
			{"id": "privacyPage", "type": "page", "header": "Privacy", "subtitle": "", "icon": "res://images/oc_icon_privacy_filled_24_dadada.png", "target_page": "device_privacy"},
			{"id": "notificationsPage", "type": "page", "header": "Notifications", "subtitle": "Choose which notifications you want to see in VR and in the Oculus App", "icon": "res://images/aui/tabs/notifications/ic_notifications.png", "target_page": "notifications"}
		]
	},
	"device_privacy": {
		"title": "Privacy",
		"parent": "device_main",
		"options": [
			
		]
	},
	"notifications": {
		"title": "Notifications",
		"parent": "device_main",
		"options": [
			{"id": "notiSubText", "type": "text", "header": "", "subtitle": "Define your headset notification preferences", "icon": ""},
			{"id": "notiMyActivity", "type": "toggle", "header": "My activity", "subtitle": "Learn about the experiences you use", "icon": ""},
		]
	},
	"developer_main": {
		"title": "Developer",
		"parent": "",
		"options": [
			{"id": "devSubText", "type": "text", "header": "", "subtitle": "Todo: hook these options up", "icon": ""},
			{"id": "devAudioStyle", "type": "dropdown", "header": "UI Audio", "subtitle": "Select which UI sounds you want to use", "icon": "res://images/aui/tabs/settings/ic_volume.png", "dropdown_keys": ["v3", "v16", "Modern"]},
			
			
		]
	}
	
}
