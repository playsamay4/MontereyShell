extends Control

const TEXT_HEADER_SCENE = preload("res://scenes/Debug/DebugTextHeader.tscn")
const TEXT_ENTRY_SCENE = preload("res://scenes/Debug/DebugTextEntry.tscn")
const BUTTON_ENTRY_SCENE = preload("res://scenes/Debug/DebugButtonEntry.tscn")

@onready var device_info = %DeviceInfoVBox
@onready var launch_panel = %LaunchPanelVBox

var app_buttons: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:

	%TestActions.pressed.connect(func(): %TestActionsPanel.show() )
	%DeviceInfo.pressed.connect(func(): %DeviceInfoPanel.show() )
	%Launch.pressed.connect(func(): %LaunchPanel.show() )


	%ShowDialog.pressed.connect(func():
		SignalBus.popup_open_requested.emit({
				"title": "Dialog Flow",
				"text": "This is a test dialog",
				"action_text": "Action",
				"primary_text": "Close",
				"cancel_text": "Cancel",
				})
		)
		
	populate_device_info()
	
	populate_launch_entries()
	
	%TestActionsPanel.show()
	
	%DeviceInfoScrollContainer.get_v_scroll_bar().custom_maximum_size.x = 0
	
	PackageManager.app_icon_updated.connect(_on_app_icon_updated)
	
	%ClearAppDBCacheBtn.pressed.connect(func():
		PackageManager.clear_icon_cache()
		SignalBus.popup_open_requested.emit({
				"title": "APP DB CACHE",
				"text": "Cleared App DB cache. Restart to trigger a new cache update.",
				"action_text": "",
				"primary_text": "OK",
				"cancel_text": "",
				})
		)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func populate_device_info():
	var info = [
		{"type":"header","text":"SETTINGS"},
		{"type":"entry","title":"Device ID", "body":SettingsManager.generate_seeded_uuid(OS.get_unique_id().hash())},
		{"type":"entry","title":"Pairing Code", "body":SettingsManager.get_pairing_code()},
		{"type":"header","text":"BUILD"},
		{"type":"entry","title":"Build.BOARD", "body":SettingsManager.BUILD_INFO["BOARD"]},
		{"type":"entry","title":"Build.BOOTLOADER", "body":SettingsManager.BUILD_INFO["BOOTLOADER"]},
		{"type":"entry","title":"Build.BRANCH", "body":SettingsManager.BUILD_INFO["BRANCH"]},
		{"type":"entry","title":"Build.DATE", "body":SettingsManager.BUILD_INFO["DATE"]},
		{"type":"entry","title":"Build.DEVICE", "body":SettingsManager.BUILD_INFO["DEVICE"]},
		{"type":"entry","title":"Build.DISPLAY", "body":SettingsManager.BUILD_INFO["DISPLAY"]},
		{"type":"entry","title":"Build.FINGERPRINT", "body":SettingsManager.BUILD_INFO["FINGERPRINT"]},
		{"type":"entry","title":"Build.MANUFACTURER", "body":SettingsManager.BUILD_INFO["MANUFACTURER"]},
		{"type":"entry","title":"Build.MODEL", "body":SettingsManager.BUILD_INFO["MODEL"]},
		{"type":"entry","title":"Build.TYPE", "body":SettingsManager.BUILD_INFO["TYPE"]},
	]

	for child in device_info.get_children():
		child.queue_free()
		
	for option_data in info:
		var new_item
		if option_data["type"] == "header":
			new_item = TEXT_HEADER_SCENE.instantiate()
			new_item.text = option_data["text"]
			device_info.add_child(new_item)
		elif option_data["type"] == "entry":
			new_item = TEXT_ENTRY_SCENE.instantiate()
			new_item.get_node("%Title").text = option_data["title"]
			if option_data["body"] is String:
				new_item.get_node("%Body").text = option_data["body"]
			elif option_data["body"] is Callable:
				new_item.get_node("%Body").text = option_data["body"].call()
				
			
			new_item.mouse_filter = Control.MOUSE_FILTER_PASS
			device_info.add_child(new_item)

func populate_launch_entries():
	var info = [
		{"type":"header","text":"VR Packages"},
		{"type":"entry","title":"Explore", "target":"res://scenes/Panel_Home.tscn"},
		{"type":"entry","title":"Settings", "target":"res://scenes/settings/Panel_Settings.tscn"},
		{"type":"entry","title":"anytimeui", "target":"res://scenes/AUI_Bar.tscn"},
		{"type":"entry","title":"LoadingDots", "target":"res://scenes/LoadingDots.tscn"},
		{"type":"entry","title":"popup", "target":"res://scenes/PanelPopup.tscn"},
		{"type":"header","text":"NUX"},
		{"type":"entry","title":"Create Guardian Boundary", "target":"res://scenes/nux/full_vr/create_guardian_boundary.tscn"},
		{"type":"entry","title":"Fit And Focus (Clarity)", "target":"res://scenes/nux/full_vr/fit_and_focus_clarity.tscn"},
		{"type":"entry","title":"Fit And Focus (Fit)", "target":"res://scenes/nux/full_vr/fit_and_focus_fit.tscn"},
		{"type":"entry","title":"Fit And Focus (Focus)", "target":"res://scenes/nux/full_vr/fit_and_focus_focus.tscn"},
		{"type":"entry","title":"Health and Safety", "target":"res://scenes/nux/full_vr/HealthAndSafety.tscn"},
		{"type":"entry","title":"Show Universal Menu", "target":"res://scenes/nux/full_vr/show_universal_menu.tscn"},
		{"type":"entry","title":"clarity", "target":"res://scenes/nux/clarity.tscn"},
		{"type":"entry","title":"ipd", "target":"res://scenes/nux/ipd.tscn"},
		{"type":"entry","title":"NuxOtaBlock", "target":"res://scenes/nux/NuxOtaBlock.tscn"},
		{"type":"entry","title":"NuxUpdatingPopup", "target":"res://scenes/nux/NuxUpdatingPopup.tscn"},
		{"type":"header","text":"SystemGrid"},
		{"type":"entry","title":"PowerAction", "target":"res://scenes/SystemGrid/PowerAction.tscn"},
		{"type":"entry","title":"PowerOffDialog", "target":"res://scenes/SystemGrid/PowerOffDialog.tscn"},
		{"type":"header","text":"Host Device Packages"}
	]

	for child in launch_panel.get_children():
		child.queue_free()
		
	# Instantiate static panel buttons
	for option_data in info:
		var new_item
		if option_data["type"] == "header":
			new_item = TEXT_HEADER_SCENE.instantiate()
			new_item.text = option_data["text"]
		elif option_data["type"] == "entry":
			new_item = BUTTON_ENTRY_SCENE.instantiate()
			new_item.get_node("%Button").text = option_data["title"]
			new_item.get_node("%Button").pressed.connect(func(): SignalBus.panel_open_requested.emit(option_data["target"]) )
			
		new_item.mouse_filter = Control.MOUSE_FILTER_PASS
		launch_panel.add_child(new_item)
	
	app_buttons.clear()
	for app in PackageManager.installed_apps:
		var btn = Button.new()
		btn.text = app.name + "(" + app.package_id + ")"
		btn.custom_minimum_size = Vector2(120, 120) 
		btn.expand_icon = true
		btn.pressed.connect(func(): PackageManager.launch_app(app.package_id))
		
		if app.icon_texture:
			btn.icon = app.icon_texture
			
		launch_panel.add_child(btn)
		app_buttons[app.package_id] = btn

func _on_app_icon_updated(package_id: String, texture: Texture2D) -> void:
	if app_buttons.has(package_id) and is_instance_valid(app_buttons[package_id]):
		app_buttons[package_id].icon = texture
