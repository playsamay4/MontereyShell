extends Control

signal show_tooltip(type: String)
signal hide_tooltip

@onready var tabContainer = %TabContainer
@onready var mainItemStack = %MainItemsStack
@onready var clockLabel = %ClockLabel
@onready var battLabel = %BatteryLabel
@onready var android_plugin = $AndroidBatteryPlugin

@onready var navigate_btn = %NavigateTabButton
@onready var social_btn = %SocialTabButton
@onready var sharing_btn = %SharingTabButton
@onready var notification_btn = %NotificationsTabButton
@onready var settings_btn = %SettingsTabButton

@onready var roomscale_btn = %RoomscaleGuardianButton
@onready var stationary_btn = %StationaryGuardianButton

var battState = "UNPLUGGED"
var battLevel = 100


func _ready() -> void:
	if OS.is_debug_build():
		%DebugSettingsButton.show()
	
	# Tab Bindings
	navigate_btn.pressed.connect(_switch_to_tab.bind(0, navigate_btn))
	social_btn.pressed.connect(_switch_to_tab.bind(1, social_btn))
	sharing_btn.pressed.connect(_switch_to_tab.bind(2, sharing_btn))
	notification_btn.pressed.connect(_switch_to_tab.bind(3, notification_btn))
	settings_btn.pressed.connect(_switch_to_tab.bind(4, settings_btn))
	
	roomscale_btn.mouse_entered.connect(func(): show_tooltip.emit("roomscale"))
	roomscale_btn.mouse_exited.connect(func(): hide_tooltip.emit())

	stationary_btn.mouse_entered.connect(func(): show_tooltip.emit("stationary"))
	stationary_btn.mouse_exited.connect(func(): hide_tooltip.emit())
	
	
	if android_plugin:
		android_plugin.android_battery_level_changed.connect(self._on_battery_level_changed)
		android_plugin.android_battery_state_changed.connect(self._on_battery_state_changed)
	else:
		SystemLog.log("Android plugin not initialized!")
	
	var clockTimer = Timer.new()
	clockTimer.wait_time = 1.0
	clockTimer.autostart = true
	
	add_child(clockTimer)
	clockTimer.timeout.connect(_update_clock)
	
	_update_clock()
	
	_connect_sub_buttons(tabContainer)
	
	_switch_to_tab(0, navigate_btn)

func _connect_sub_buttons(current_node: Node) -> void:
	for child in current_node.get_children():
		if child.has_signal("action_triggered"):
			child.action_triggered.connect(_on_sub_item_triggered)
		if child.get_child_count() > 0:
			_connect_sub_buttons(child)
	

func _switch_to_tab(tab_index: int, clicked_button: Button) -> void:
	clicked_button.button_pressed = true
			
	#TODO: switch to tab groups idek why i wrote this
	for button in mainItemStack.get_children():
		if button is Button and button != clicked_button:
			button.button_pressed = false
		
	var sub_items_panel = tabContainer.get_parent().get_parent().get_parent()
	sub_items_panel.visible = true
	
	tabContainer.current_tab = tab_index
	

func _on_sub_item_triggered(action: String) -> void:
	SystemLog.log("Auto-routed action received from: ", action)
	
	_manage_sub_button_toggles(tabContainer, action)
	
	match action:

		"home":
			SignalBus.panel_open_requested.emit("res://scenes/Panel_Home.tscn")
		"library":
			SignalBus.panel_open_requested.emit("res://scenes/Library/Panel_Library.tscn")
		"volume":
			_switch_to_tab(5,settings_btn)
		"seeAll":
			SignalBus.panel_open_requested.emit("res://scenes/settings/Panel_Settings.tscn")
		"debug":
			SignalBus.panel_open_requested.emit("res://scenes/Debug/DebugPanel.tscn")
		#"seeOutside":
			##TODO: Move to SignalBus event
			#SignalBus.panel_open_requested.emit("seeOutside")
		"notifsViewAll":
			SignalBus.panel_open_requested.emit("res://scenes/DebugPanel.tscn")
		_:
			SystemLog.log("No route defined for: ", action)
			SignalBus.popup_open_requested.emit({
				"title": "No route defined",
				"text": "Sub item triggered: " + action + ", there is no route for this event.",
				"action_text": "",
				"primary_text": "OK",
				"cancel_text": ""
				})


func _manage_sub_button_toggles(current_node: Node, active_action: String) -> void:
	for child in current_node.get_children():
		if "action_type" in child:
			if child.action_type == active_action:
				child.button_pressed = true
			else:
				child.button_pressed = false
				
		if child.get_child_count() > 0:
			_manage_sub_button_toggles(child, active_action)

func _update_clock() -> void:
	var time = Time.get_time_dict_from_system()
	var hour = time.hour
	var minute = time.minute
	var period = "am" if hour < 12 else "pm"
	
	if hour == 0:
		hour = 12
	elif hour > 12:
		hour -= 12
		
	clockLabel.text = "%d:%02d %s" % [hour, minute, period]

func _on_battery_state_changed(state: int) -> void:

	match state:
		0:
			battState = 'Unplugged'
		1:
			battState = 'Charging'
		_:
			battState = 'Unknown'
	
func _on_battery_level_changed(level: int) -> void:
	battLevel = level
	battLabel.text = str(battLevel) + '%'
	
