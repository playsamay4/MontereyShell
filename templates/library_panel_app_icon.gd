extends PanelContainer

@onready var main_icon_button: Button = %MainIconButton
@onready var border_panel: PanelContainer = %BorderPanel
@onready var veil_overlay: PanelContainer = %VeilOverlay

signal pressed
signal options_pressed

var is_hovered: bool = false 

@export var title: String:
	set(value):
		%TitleLabel.text = value
		
@export var date: String:
	set(value):
		%DateLabel.text = value

@export var icon: Texture2D:
	set(value):
		%IconSquare.texture = value

func _ready() -> void:
	var current_sb = border_panel.get_theme_stylebox("panel")
	if current_sb:
		var unique_sb = current_sb.duplicate(true) 
		border_panel.add_theme_stylebox_override("panel", unique_sb)

	mouse_entered.connect(_button_hover_anim)
	mouse_exited.connect(_on_mouse_exited)
	
	main_icon_button.mouse_entered.connect(_button_hover_anim)
	main_icon_button.mouse_exited.connect(_on_mouse_exited)
	

	main_icon_button.pressed.connect(func(): pressed.emit())

	%Button.pressed.connect(func(): options_pressed.emit())
	
	_button_unhover_anim()

func _process(_delta: float) -> void:
	if is_hovered:
		var global_mouse_pos = get_global_mouse_position()
		var card_rect = get_global_rect()
		
		if !card_rect.has_point(global_mouse_pos) or get_viewport().get_mouse_position() != global_mouse_pos:
			_button_unhover_anim()

func _button_hover_anim() -> void:
	is_hovered = true
	veil_overlay.modulate.a = 1.0
	_set_border_alpha(1.0)

func _on_mouse_exited() -> void:
	await get_tree().process_frame
	
	var local_mouse_pos = get_local_mouse_position()
	var card_rect = Rect2(Vector2.ZERO, size)
	
	if card_rect.has_point(local_mouse_pos):
		return 
		
	_button_unhover_anim()

func _button_unhover_anim() -> void:
	is_hovered = false
	veil_overlay.modulate.a = 0.0
	_set_border_alpha(0.0)

func _set_border_alpha(alpha_value: float) -> void:
	var sb = border_panel.get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		sb.border_color.a = alpha_value
