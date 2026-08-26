extends Control

const TEXT_HEADER_SCENE = preload("res://scenes/Debug/DebugTextHeader.tscn")
const TEXT_ENTRY_SCENE = preload("res://scenes/Debug/DebugTextEntry.tscn")
const BUTTON_ENTRY_SCENE = preload("res://scenes/Debug/DebugButtonEntry.tscn")
const SETTINGS_OPTION_SCENE = preload("res://scenes/settings/components/settings_option.tscn")
const DROPDOWN_POPUP_SCENE = preload("res://templates/dropdown_popup.tscn")

const DEFAULT_LAUNCH_TARGET_LABEL := "Default (per-app)"

@onready var device_info = %DeviceInfoVBox
@onready var launch_panel = %LaunchPanelVBox
@onready var launch_target_dropdown: Button = %LaunchTargetDropdown
@onready var device_config = %DeviceConfigVBox

var app_buttons: Dictionary = {}
var population_thread: Thread

var _launch_target_options: Array[String] = []
var _launch_target_selected: String = DEFAULT_LAUNCH_TARGET_LABEL

# Called when the node enters the scene tree for the first time.
func _ready() -> void:

	%TestActions.pressed.connect(func(): %TestActionsPanel.show() )
	%DeviceInfo.pressed.connect(func(): %DeviceInfoPanel.show() )
	%Launch.pressed.connect(func(): %LaunchPanel.show() )
	%DeviceConfig.pressed.connect(func(): %DeviceConfigPanel.show() )
	launch_target_dropdown.pressed.connect(_on_launch_target_dropdown_pressed)


	%ShowDialog.pressed.connect(func():
		PopupManager.show_popup({
				"title": "Dialog Flow",
				"text": "This is a test dialog",
				"action_text": "Action",
				"primary_text": "Close",
				"cancel_text": "Cancel",
				})
		)
		
	populate_device_info()

	populate_launch_target_dropdown()
	populate_launch_entries()

	populate_device_config()

	%TestActionsPanel.show()
	
	%DeviceInfoScrollContainer.get_v_scroll_bar().custom_maximum_size.x = 0
	
	PackageManager.app_icon_updated.connect(_on_app_icon_updated)
	
	%EnterGuardianSetup.pressed.connect(func():
		PackageManager.launch_app("com.oculus.guardiansetup")
		)	
	
	%ClearAppDBCacheBtn.pressed.connect(func():
		PackageManager.clear_icon_cache()
		PopupManager.show_popup({
				"title": "APP DB CACHE",
				"text": "Cleared App DB cache. Restart to trigger a new cache update.",
				"action_text": "",
				"primary_text": "OK",
				"cancel_text": "",
				})
		)

	%ExportIconCacheBtn.pressed.connect(func():
		var res: Dictionary = PackageManager.export_icon_cache()
		var msg: String
		if res.get("success", false):
			msg = "Exported %d icons to external path:\n%s" % [res.get("count", 0), res.get("path", "")]
			if res.get("copy_errors", 0) > 0:
				msg += "\n(Note: %d files failed to copy)" % res.get("copy_errors", 0)
		else:
			msg = "Export Failed!\n" + res.get("error_message", "Unknown error")
		PopupManager.show_popup({
				"title": "EXPORT ICON CACHE",
				"text": msg,
				"action_text": "",
				"primary_text": "OK",
				"cancel_text": "",
				})
		)

	%RestoreIconCacheBtn.pressed.connect(func():
		var res: Dictionary = PackageManager.restore_icon_cache()
		var msg: String
		if res.get("success", false):
			msg = "Restored %d icons from external path:\n%s" % [res.get("count", 0), res.get("path", "")]
		else:
			msg = "Restore Failed!\n" + res.get("error_message", "Unknown error")
		PopupManager.show_popup({
				"title": "RESTORE ICON CACHE",
				"text": msg,
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

## "Default (per-app)" plus every window currently registered with
## WindowManager, so a debug user can force any registered app to open in
## any window regardless of what it would normally pick for itself -
## e.g. previewing a System Grid dialog in the main panel, or vice versa.
##
## Uses the project's own custom dropdown (templates/dropdown_popup.tscn)
## rather than Godot's built-in OptionButton - the native one opens its
## popup as a separate top-level window, which doesn't render inside these
## panels' SubViewport-in-3D setup and is effectively unusable in XR.
func populate_launch_target_dropdown() -> void:
	_launch_target_options = [DEFAULT_LAUNCH_TARGET_LABEL]
	for window_id in WindowManager.get_window_ids():
		_launch_target_options.append(str(window_id))

	_launch_target_selected = DEFAULT_LAUNCH_TARGET_LABEL
	launch_target_dropdown.text = _launch_target_selected

func _on_launch_target_dropdown_pressed() -> void:
	var popup = DROPDOWN_POPUP_SCENE.instantiate()
	get_viewport().add_child(popup)
	popup.setup(_launch_target_options, _launch_target_selected, launch_target_dropdown)
	popup.option_selected.connect(func(option_id: String):
		_launch_target_selected = option_id
		launch_target_dropdown.text = option_id
		)

func _resolve_launch_target(manifest: AppManifest) -> StringName:
	if _launch_target_selected == DEFAULT_LAUNCH_TARGET_LABEL:
		return manifest.default_window
	return StringName(_launch_target_selected)

func populate_launch_entries():
	for child in launch_panel.get_children():
		child.queue_free()

	# Registered apps (res://apps/**/*.tres), grouped by category. Adding a
	# new app anywhere in the project only requires dropping an AppManifest
	# .tres under res://apps/ - nothing here needs to change.
	for category in AppRegistry.get_categories():
		var header = TEXT_HEADER_SCENE.instantiate()
		header.text = category
		header.mouse_filter = Control.MOUSE_FILTER_PASS
		launch_panel.add_child(header)

		for manifest in AppRegistry.get_apps(category):
			var entry = BUTTON_ENTRY_SCENE.instantiate()
			entry.get_node("%Button").text = manifest.display_name
			entry.get_node("%Button").pressed.connect(func(): WindowManager.open_app(_resolve_launch_target(manifest), manifest.id))
			entry.mouse_filter = Control.MOUSE_FILTER_PASS
			launch_panel.add_child(entry)

	var host_header = TEXT_HEADER_SCENE.instantiate()
	host_header.text = "Host Device Packages"
	host_header.mouse_filter = Control.MOUSE_FILTER_PASS
	launch_panel.add_child(host_header)

	# There can be 100+ installed host apps - building a Button per app
	# synchronously here is the single biggest source of hitching when this
	# panel opens. Build them off-thread (same pattern panel_library.gd
	# already uses) and only touch the live tree once, deferred back onto
	# the main thread.
	app_buttons.clear()
	if population_thread and population_thread.is_started():
		population_thread.wait_to_finish()
	population_thread = Thread.new()
	population_thread.start(_bg_populate_host_apps)

func _bg_populate_host_apps() -> void:
	var built: Array = []
	for app in PackageManager.installed_apps:
		var btn = Button.new()
		btn.text = app.name + "(" + app.package_id + ")"
		btn.custom_minimum_size = Vector2(120, 120)
		btn.expand_icon = true
		btn.pressed.connect(func(): PackageManager.launch_app(app.package_id))

		if app.icon_texture:
			btn.icon = app.icon_texture

		built.append({"package_id": app.package_id, "button": btn})

	_add_host_app_buttons.call_deferred(built)

func _add_host_app_buttons(built: Array) -> void:
	for entry in built:
		launch_panel.add_child(entry["button"])
		app_buttons[entry["package_id"]] = entry["button"]

	if population_thread and population_thread.is_started():
		population_thread.wait_to_finish()

func _exit_tree() -> void:
	if population_thread and population_thread.is_started():
		population_thread.wait_to_finish()

## Raw editor for every key in SettingsManager.DEFAULTS["settings"], built
## dynamically off that dictionary rather than hardcoded here - so it stays
## complete as settings get added, and covers keys that don't otherwise
## have friendly UI in the real Settings app (e.g. nuxStatus). Bools get a
## toggle; everything else gets a free-text row parsed back to its type.
func populate_device_config() -> void:
	for child in device_config.get_children():
		child.queue_free()

	var keys := SettingsManager.DEFAULTS["settings"].keys()
	keys.sort()

	for key in keys:
		var default_value = SettingsManager.DEFAULTS["settings"][key]
		var row = SETTINGS_OPTION_SCENE.instantiate()
		row.setting_id = key
		row.header_text = key
		row.mouse_filter = Control.MOUSE_FILTER_PASS

		if default_value is bool:
			row.option_type = "toggle"
			row.toggled = SettingsManager.get_value("settings", key) or false
			row.setting_toggled.connect(func(id: String, is_on: bool):
				SettingsManager.set_value("settings", id, is_on)
				)
		else:
			row.option_type = "edit"
			row.edit_text = str(SettingsManager.get_value("settings", key))
			row.setting_edited.connect(_on_device_config_edited)

		device_config.add_child(row)

func _on_device_config_edited(id: String, value: String) -> void:
	var default_value = SettingsManager.DEFAULTS["settings"].get(id)
	var coerced: Variant = value

	if default_value is int:
		coerced = int(value) if value.is_valid_int() else default_value
	elif default_value is float:
		coerced = float(value) if value.is_valid_float() else default_value
	# else: leave as the raw string

	if !SettingsManager.set_value("settings", id, coerced):
		SystemLog.log("Couldn't set device config value for ", id)

func _on_app_icon_updated(package_id: String, texture: Texture2D) -> void:
	if app_buttons.has(package_id) and is_instance_valid(app_buttons[package_id]):
		app_buttons[package_id].icon = texture
