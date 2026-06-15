extends PanelContainer

@onready var internalButton = $Button
@onready var border_panel = $MarginContainer/PanelContainer

func _ready() -> void:
	var current_sb = border_panel.get_theme_stylebox("panel")
	if current_sb:
		var unique_sb = current_sb.duplicate(true) 
		border_panel.add_theme_stylebox_override("panel", unique_sb)

	internalButton.mouse_entered.connect(_button_hover_anim)
	internalButton.mouse_exited.connect(_button_unhover_anim)
	
	_button_unhover_anim()
	
func _button_hover_anim() -> void:
	$MarginContainer/PanelContainer/MarginContainer/TextureRect/VeilOverlay.modulate.a = 1
	_set_border_alpha(1.0)
	
func _button_unhover_anim() -> void:
	$MarginContainer/PanelContainer/MarginContainer/TextureRect/VeilOverlay.modulate.a = 0
	_set_border_alpha(0.0)

func _set_border_alpha(alpha_value: float) -> void:
	var sb = border_panel.get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		sb.border_color.a = alpha_value
