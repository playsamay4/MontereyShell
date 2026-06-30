@tool
extends Button
signal action_triggered(type: String)
@export var action_type: String = "home":
	set(value):
		action_type = value

@export var button_text: String = "Home":
	set(value):
		button_text = value
		if is_node_ready():
			_update_ui()

@export var button_icon: Texture2D:
	set(value):
		button_icon = value
		if is_node_ready():
			_update_ui()
			
@export var font_color: Color = Color.WHITE:
	set(value):
		font_color = value
		if is_node_ready():
			_update_ui()

func _ready() -> void:
	pressed.connect(func(): 
		SystemLog.log("BUTTON CLICKED Sending action_type: ", action_type)
		action_triggered.emit(action_type)
	)	
	_update_ui()

func _update_ui() -> void:
	if has_node("MarginContainer/CenterContainer/VBoxContainer/Label"):
		$MarginContainer/CenterContainer/VBoxContainer/Label.text = button_text
		$MarginContainer/CenterContainer/VBoxContainer/Label.add_theme_color_override("font_color", font_color)
		
	if has_node("MarginContainer/CenterContainer/VBoxContainer/Icon"):
		$MarginContainer/CenterContainer/VBoxContainer/Icon.texture = button_icon
	
