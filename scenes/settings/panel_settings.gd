extends PanelContainer

const SETTINGS_OPTION_SCENE = preload("res://scenes/settings/components/settings_option.tscn")
@onready var page_header: Label = %PageHeader
@onready var back_button: Button = %BackButton
@onready var content_v_stack: VBoxContainer = %ContentVStack
@onready var sidebar_v_stack: VBoxContainer = %SidebarVStack


var button_left_align_theme: Theme = preload("res://templates/aui/shell.tres")

var current_page_id: String = ""
var previous_page_ids: Array[String] = []

var sidebar_button_group: ButtonGroup = ButtonGroup.new()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:

	back_button.pressed.connect(_on_back_pressed)
	
	
	
	var content_index = SettingsData.PAGES["index"]
	for item in content_index:
		
		var new_button = Button.new()
		new_button.text = item["name"]
		new_button.theme_type_variation = &"ButtonLeftAlign"
		new_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		new_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		new_button.custom_minimum_size = Vector2(250, 51)
		new_button.button_group = sidebar_button_group
		new_button.toggle_mode = true
		new_button.pressed.connect(func():
			load_page(item["pageID"])
		)
		new_button.set_meta("pageID", item["pageID"])
		
		sidebar_v_stack.add_child(new_button)
	
	if content_index[0]:
		load_page(content_index[0]["pageID"])
	


func load_page(page_id: String, is_back: bool = false) -> void:
	
	
	SystemLog.log("Settings loaded ", page_id)
	
	if(page_id == ""):
		return
	
	for node in sidebar_v_stack.get_children():
		if node is Button and node.has_meta("pageID") and node.get_meta("pageID") == page_id:
			node.button_pressed = true
		
	
	if !is_back and current_page_id != "":
		previous_page_ids.append(current_page_id)
		
	current_page_id = page_id
	var page_data = SettingsData.PAGES[page_id]

	page_header.text = page_data["title"]
	
	for child in content_v_stack.get_children():
		child.queue_free()
		
	for option_data in page_data["options"]:
		var new_option = SETTINGS_OPTION_SCENE.instantiate()
		
		
		new_option.setting_id = option_data["id"]
		new_option.option_type = option_data["type"]
		new_option.header_text = tr(option_data.get("header", ""))
		new_option.subtitle_text = tr(option_data.get("subtitle", ""))
		var icon_path = option_data.get("icon", "")
		if icon_path != "":
			new_option.icon_texture = load(icon_path)
		else:
			new_option.icon_texture = null
		
		
		if option_data["type"] == "page":
			var target = option_data["target_page"]
			new_option.setting_clicked.connect(func(_id): 
				load_page(target)
			)
		if option_data["type"] == "toggle":
			new_option.toggled = SettingsManager.get_value("settings",option_data["id"]) or false
			new_option.setting_toggled.connect(_on_setting_toggled)
		
		if option_data["type"] == "dropdown":
			var data = option_data["dropdown_keys"]
			var selected = SettingsManager.get_value("settings", option_data["id"])
			if selected == null:
				selected = "" 
				SystemLog.log("A null value was loaded for option ", option_data["id"])
			
			if(option_data["id"] == "languageDropdown"):
				data = SettingsManager.LOCALES.duplicate()
				selected = SettingsManager.get_value("settings", "locale")
			
			
			new_option.selected_id = selected
			
			new_option.options_list.assign(data)
			new_option.setting_dropdown_changed.connect(_on_setting_dropdown_changed)
		
		if option_data["type"] == "button":
			var btn_src = option_data.get("buttonSource")
			
			var get_current_btn_text = func() -> String:
				if btn_src is Dictionary:
					var singleton = Engine.get_main_loop().root.get_node_or_null(btn_src["target"])
					if singleton and singleton.has_method(btn_src["method"]):
						return str(singleton.call(btn_src["method"]))
				return tr(option_data.get("buttonText", "")) 
				
			new_option.button_text = get_current_btn_text.call()
			
			var btn_sig_data = option_data.get("buttonChangeSignal")
			if btn_sig_data is Dictionary:
				var target_node = Engine.get_main_loop().root.get_node_or_null(btn_sig_data["target"])
				var signal_name = btn_sig_data["signal"]
				
				if target_node and target_node.has_signal(signal_name):
					target_node.connect(signal_name, func(_arg = null):
						if is_instance_valid(new_option):
							new_option.button_text = get_current_btn_text.call()
					)
				
			var btn_enabled_src = option_data.get("buttonEnabledSource")
			
			var get_current_enabled_state = func() -> bool:
				if btn_enabled_src is Dictionary:
					var singleton = Engine.get_main_loop().root.get_node_or_null(btn_enabled_src["target"])
					if singleton and singleton.has_method(btn_enabled_src["method"]):
						return !!singleton.call(btn_enabled_src["method"])
				return true 
				
			new_option.button_enabled = get_current_enabled_state.call()
			
			var btn_enabled_sig = option_data.get("buttonEnabledChangeSignal")
			if btn_enabled_sig is Dictionary:
				var target_node = Engine.get_main_loop().root.get_node_or_null(btn_enabled_sig["target"])
				var signal_name = btn_enabled_sig["signal"]
				
				if target_node and target_node.has_signal(signal_name):
					target_node.connect(signal_name, func(_arg = null):
						if is_instance_valid(new_option):
							new_option.button_enabled = get_current_enabled_state.call()
					)

			var btn_action_data = option_data.get("buttonAction")
			new_option.setting_button_clicked.connect(func(_id):
				if btn_action_data is Dictionary:
					var target_node = Engine.get_main_loop().root.get_node_or_null(btn_action_data["target"])
					if target_node and target_node.has_method(btn_action_data["method"]):
						target_node.call(btn_action_data["method"])
					else:
						SystemLog.log("Settings button action target/method not found: ", btn_action_data)
				else:
					SystemLog.log("Settings button clicked with no buttonAction defined: ", option_data["id"])
			)


		if option_data.get("subtitle") or option_data.get("subtitleSource"):
			var sub_src = option_data.get("subtitleSource")
			
			var get_current_sub_text = func() -> String:
				if sub_src is Dictionary:
					var singleton = Engine.get_main_loop().root.get_node_or_null(sub_src["target"])
					if singleton and singleton.has_method(sub_src["method"]):
						return str(singleton.call(sub_src["method"]))
				return tr(option_data.get("subtitle", ""))
				
			new_option.subtitle_text = get_current_sub_text.call()
			
			var sub_sig_data = option_data.get("subtitleChangeSignal") 
			if sub_sig_data is Dictionary:
				var target_node = Engine.get_main_loop().root.get_node_or_null(sub_sig_data["target"])
				var signal_name = sub_sig_data["signal"]
				
				if target_node and target_node.has_signal(signal_name):
					target_node.connect(signal_name, func(_arg = null): 
						if is_instance_valid(new_option):
							new_option.subtitle_text = get_current_sub_text.call()
					)
				
		
		content_v_stack.add_child(new_option)


func _on_back_pressed() -> void:
	var id = previous_page_ids.pop_back()
	if id:
		load_page(id, true)

## Universal back button (controller B/Y): go to the previous settings page
## if there is one, same as tapping the in-app back button. Only when
## already at the root page do we decline and let the window close Settings
## and reveal whatever was open before it.
func _on_universal_back() -> bool:
	if previous_page_ids.is_empty():
		return false
	_on_back_pressed()
	return true

func _ask_for_restart() -> bool:
	var reason = await PopupManager.show_popup({
					"title": tr("SETTINGS_RESTART_REQUIRED"),
					"text": tr("SETTINGS_RESTART_REQUIRED_SUBTITLE"),
					"action_text": tr("BUTTON_CANCEL"),
					"primary_text": tr("BUTTON_OK"),
					"cancel_text": ""
				})
	return reason == "primary"


func _on_setting_toggled(id: String, is_on: bool) -> void:
	SystemLog.log("Setting toggled: ", id, " to ", is_on)
	
	
	match id:
		# All Toggles that require a restart 
		"TEST":
			if not is_on:
				SettingsManager.set_value("settings",id, false)
				return

			var restart = await _ask_for_restart()
			if restart:
				SettingsManager.set_value("settings",id, true)
				
				SystemLog.log("restart")
			else:
				flip_toggle_back(id)
		
		_:
			if !SettingsManager.set_value("settings",id, is_on):
				SystemLog.log("Couldn't find setting ", id, "!")
				if OS.is_debug_build():
					PopupManager.show_popup({
						"title": "Missing key?",
						"text": "This option was bound to a key that does not currently exist within the default schema.",
						"action_text": "",
						"primary_text": tr("BUTTON_OK"),
						"cancel_text": ""
					})


func flip_toggle_back(id: String):
	for child in content_v_stack.get_children():
		if child is SettingsOption and child.setting_id == id:
			child.toggled = false
			return

func set_dropdown(id: String, value: String):
	for child in content_v_stack.get_children():
		if child is SettingsOption and child.setting_id == id:
			child.selected_id = value

func _on_setting_dropdown_changed(id: String, value: String):
	SystemLog.log("Dropdown ", id, " changed to ", value)
	
	match id:
		"languageDropdown":
			var currentLocale = SettingsManager.get_value("settings", "locale")
			if value == currentLocale:
				return
			
			
			var restart = await _ask_for_restart()
			if restart:
				SettingsManager.set_value("settings", "locale", value)
				SystemLog.log("Restart")
			else:
				set_dropdown(id, currentLocale)
				pass
		_:
			if !SettingsManager.set_value("settings",id, value):
				SystemLog.log("Couldn't find setting ", id, "!")
				if OS.is_debug_build():
					PopupManager.show_popup({
						"title": "Missing key?",
						"text": "This option was bound to a key that does not currently exist within the default schema.",
						"action_text": "",
						"primary_text": tr("BUTTON_OK"),
						"cancel_text": ""
					})	
