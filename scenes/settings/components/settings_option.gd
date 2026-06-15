@tool
extends HBoxContainer
class_name SettingsOption

signal setting_toggled(setting_id: String, is_on: bool)
#TODO: Signal Dropdown changed
signal setting_clicked(setting_id: String)

@export var setting_id: String = "unique_key"

@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		_update_ui()

@export var header_text: String = "Option Title":
	set(value):
		header_text = value
		_update_ui()

@export var subtitle_text: String = "":
	set(value):
		subtitle_text = value
		_update_ui()
		
@export var toggled: bool = false:
	set(value):
		if toggled == value: return
		toggled = value
		_update_ui()

@export var options_list: Array[String] = ["Option"]
@export var selected_index: int = 0

@export_enum("toggle", "dropdown", "external", "page", "text", "header") var option_type: String = "toggle":
	set(value):
		option_type = value
		_update_ui()


@onready var icon_rect: TextureRect = $Icon
@onready var header_label: Label = $TextStack/Header
@onready var subtitle_label: Label = $TextStack/Subtitle
@onready var toggle_btn: Control = $OculusToggle
@onready var icon_btn_texture: TextureRect = $IconButtonTexture

@onready var dropdown_btn: Button = $DropdownButton
const POPUP_SCENE = preload("res://templates/dropdown_popup.tscn")

var external_image = preload("res://images/oc_icon_open_tab_filled_24_dadada.png")
var chevron_right_image = preload("res://images/oc_icon_chevron_right_filled_24_dadada.png")



func _ready() -> void:
	_update_ui()
	
	# prevents the signal connection from running in the editor
	if not Engine.is_editor_hint():
		if toggle_btn and toggle_btn.has_signal("toggled"):
			toggle_btn.toggled.connect(_on_toggle_state_changed)
			
	dropdown_btn.text = options_list[selected_index]
	dropdown_btn.pressed.connect(_on_dropdown_btn_pressed)

func _update_ui() -> void:
	# we check if the nodes actually exist yet before trying to change them
	if not is_inside_tree() or !header_label: 
		return
		
	if icon_texture:
		icon_rect.show()
		icon_rect.texture = icon_texture
	else:
		icon_rect.hide()
	
	if header_text.is_empty():
		header_label.hide()
	else:
		header_label.text = header_text
		header_label.show()
	
	if subtitle_text.is_empty():
		subtitle_label.hide()
	else:
		subtitle_label.text = subtitle_text
		subtitle_label.show()
		
	
	
	
	toggle_btn.pre_toggled = toggled
	
	
	
	#hide all controls, we'll enable them by type
	dropdown_btn.hide()
	toggle_btn.hide()
	icon_btn_texture.hide()
	
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	if option_type == "toggle":
		toggle_btn.show()
	elif option_type == "dropdown":
		dropdown_btn.show()
	elif option_type == "external":
		icon_btn_texture.texture = external_image 
		icon_btn_texture.show()
		_make_row_clickable()
	elif option_type == "page":
		icon_btn_texture.texture = chevron_right_image 
		icon_btn_texture.show()
		_make_row_clickable()
	
		

func _make_row_clickable() -> void:
	#ensure the row catches the click event
	mouse_filter = Control.MOUSE_FILTER_STOP

#Whole row clicks
func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint(): return 
	
	# Only allow whole-row clicks if it's the correct type
	if option_type in ["external", "page"]:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			# Only trigger on mouse release, and verify the mouse is still inside the row's bounding box
			if not event.pressed and get_global_rect().has_point(get_global_mouse_position()):
				#setting_clicked.emit(setting_id)
				setting_clicked.emit()

func _on_mouse_entered() -> void:
	if option_type in ["external", "page"]:
		#TODO: icon hover
		pass

func _on_mouse_exited() -> void:
	#TODO: icon hover
	pass

func _on_toggle_state_changed(button_pressed: bool) -> void:
	toggled = button_pressed
	setting_toggled.emit(setting_id, button_pressed)

func _on_dropdown_btn_pressed() -> void:
	var popup = POPUP_SCENE.instantiate()
	get_viewport().add_child(popup)
	
	popup.setup(options_list, selected_index, dropdown_btn)
	popup.option_selected.connect(_on_item_chosen)
	

func _on_item_chosen(index: int, text: String) -> void:
	selected_index = index
	dropdown_btn.text = text
	print("User changed setting to: ", text)
	
