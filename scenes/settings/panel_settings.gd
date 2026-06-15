extends PanelContainer

const SETTINGS_OPTION_SCENE = preload("res://scenes/settings/components/settings_option.tscn")
@onready var page_header: Label = %PageHeader
@onready var back_button: Button = %BackButton
@onready var device_v_stack: VBoxContainer = %DeviceVStack

var current_page_id: String = "device_main"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#%DNDOption.setting_toggled.connect(func(id: String, is_on: bool): 
		#if(is_on):
			#SignalBus.popup_open_requested.emit({
				#"title": "Restart required",
				#"text": "Your device needs to restart to apply this change",
				#"action_text": "Cancel",
				#"primary_text": "OK",
				#"cancel_text": "Cancel"
			#})
			#var reason = await SignalBus.popup_finish_requested
			#if (reason == "action"):
				#%DNDOption.toggled = false
		#
	#)
	%DeviceTab.pressed.connect(func(): load_page("device_main"))
	%DeveloperTab.pressed.connect(func(): load_page("developer_main"))
	

	back_button.pressed.connect(_on_back_pressed)
	
	load_page("device_main")
	
	pass

func load_page(page_id: String) -> void:
	current_page_id = page_id
	var page_data = SettingsData.PAGES[page_id]
	
	page_header.text = page_data["title"]
	#back_button.visible = (page_data["parent"] != "")
	
	for child in device_v_stack.get_children():
		child.queue_free()
		
	for option_data in page_data["options"]:
		var new_option = SETTINGS_OPTION_SCENE.instantiate()
		device_v_stack.add_child(new_option)
		
		new_option.setting_id = option_data["id"]
		new_option.option_type = option_data["type"]
		new_option.header_text = option_data["header"]
		new_option.subtitle_text = option_data.get("subtitle", "")
		new_option.icon_texture = load(option_data["icon"])
		
		
		if option_data["type"] == "page":
			var target = option_data["target_page"]
			new_option.setting_clicked.connect(func(): 
				load_page(target)
			)
		if option_data["type"] == "dropdown":
			var data = option_data["dropdown_keys"]
			new_option.options_list.assign(data)


func _on_back_pressed() -> void:
	var page_data = SettingsData.PAGES[current_page_id]
	var parent_page = page_data["parent"]
	if parent_page != "":
		load_page(parent_page)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
