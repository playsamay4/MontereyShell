extends Control

const SHELL_THEME = preload("res://templates/aui/shell.tres")

signal option_selected(option_id: String)

@onready var menu_panel: PanelContainer = $PanelContainer
@onready var scroll_container: ScrollContainer = $PanelContainer/ScrollContainer
@onready var item_list: VBoxContainer = $PanelContainer/ScrollContainer/MarginContainer/VBoxContainer

@export var max_height: float = 250.0 
@export var screen_padding: float = 16.0 

var dropdown_group = ButtonGroup.new()

var _target_node: Control = null

func setup(options: Array[String], selected_id: String, target_btn: Button) -> void:
	
	_target_node = target_btn
	_target_node.visibility_changed.connect(_on_target_hidden)
	_target_node.tree_exiting.connect(queue_free)
	
	
	for child in item_list.get_children():
		child.queue_free()
		
		
	for option_id in options:
		var btn = Button.new()
		btn.text = tr(option_id)
		btn.set_meta("id_key", option_id)
		
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.theme = SHELL_THEME
		btn.theme_type_variation = "DropdownButton"
		btn.button_group = dropdown_group
		btn.toggle_mode = true
		
		
		if option_id == selected_id:
			btn.button_pressed = true
		
		btn.pressed.connect(func():
			option_selected.emit(btn.get_meta("id_key"))
			queue_free()
		)
		item_list.add_child(btn)
		
	# force godot to calculate the container sizes immediately
	var target_btn_rect = target_btn.get_global_rect()
	menu_panel.custom_minimum_size.x = target_btn_rect.size.x
	menu_panel.reset_size()
	item_list.force_update_transform()
	
	#calculates how tall the content naturally wants to be
	# (Marggin container margins + VBox total content size)
	var margin_container = $PanelContainer/ScrollContainer/MarginContainer
	var total_content_height = item_list.get_minimum_size().y + margin_container.get_theme_constant("margin_top") + margin_container.get_theme_constant("margin_bottom")
	
	
	var final_height = min(total_content_height, max_height)
	menu_panel.custom_minimum_size.y = final_height
	menu_panel.size.y = final_height
	
	#above vs below
	var viewport_size = get_viewport_rect().size
	
	
	var space_below = viewport_size.y - target_btn_rect.end.y - screen_padding
	var space_above = target_btn_rect.position.y - screen_padding
	
	var final_pos = Vector2.ZERO
	final_pos.x = target_btn_rect.position.x # Match button X alignment
	

	if space_below >= final_height:
		# fits perfectly below
		final_pos.y = target_btn_rect.end.y + 4 
	elif space_above > space_below:
		# better fit above the button
		final_pos.y = target_btn_rect.position.y - final_height - 4
	else:
		# default to below, but we will clamp it to the screen below
		final_pos.y = target_btn_rect.end.y + 4
		
	
	# clamp X position within screen bounds
	final_pos.x = clamp(final_pos.x, screen_padding, viewport_size.x - menu_panel.size.x - screen_padding)
	# clamp Y position within screen bounds
	final_pos.y = clamp(final_pos.y, screen_padding, viewport_size.y - menu_panel.size.y - screen_padding)
	
	menu_panel.global_position = final_pos

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if not menu_panel.get_global_rect().has_point(get_global_mouse_position()):
			queue_free()
			
func _on_target_hidden() -> void:
	# if the button is no longer visible in the tree close the popup
	if _target_node and not _target_node.is_visible_in_tree():
		queue_free()
