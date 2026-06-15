@tool 
extends Control

signal toggled(is_on: bool)

# flag to prevent animations during the initial loading frame
var _allow_animation: bool = false

@export_category("Oculus Toggle")
@export var pre_toggled: bool = false:
	set(value):
		pre_toggled = value
		is_pressed = value
		
		if is_inside_tree():
			# snap instantly in the editor OR during the initial loading frame
			if Engine.is_editor_hint() or not _allow_animation:
				_update_visuals_instant() 
			else:
				_animate_toggle() # slide smoothly at runtime

@onready var track: Panel = $Track
@onready var knob: Panel = $Knob

var is_pressed: bool = false
var is_hovered: bool = false

const COLOR_TRACK_OFF: Color = Color("#3e4045")
const COLOR_TRACK_ON: Color = Color("#0060d8")

var track_stylebox: StyleBoxFlat

func _ready() -> void:
	#  click events pass to the root
	if track and knob:
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_setup_stylebox()
	
	# set baseline value
	is_pressed = pre_toggled
	_update_visuals_instant()
	
	# only connect runtime signals if we aren't running inside the editor tool pipeline
	if not Engine.is_editor_hint():
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)
		
		
		set_deferred("_allow_animation", true)

func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint(): return 
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and get_global_rect().has_point(get_global_mouse_position()):
			pre_toggled = !pre_toggled 
			toggled.emit(pre_toggled)

func _setup_stylebox() -> void:
	if not track: return
	var original_style = track.get_theme_stylebox("panel")
	if original_style and not track_stylebox:
		track_stylebox = original_style.duplicate()
		track.add_theme_stylebox_override("panel", track_stylebox)

func _animate_toggle() -> void:
	if Engine.is_editor_hint() or not is_inside_tree(): return
	
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	var target_anchor = 1.0 if is_pressed else 0.0
	var base_color = COLOR_TRACK_ON if is_pressed else COLOR_TRACK_OFF
	var target_color = base_color.lerp(Color.WHITE, 0.1) if is_hovered else base_color
	
	var target_offset_left = -24.0 if is_pressed else 4.0   
	var target_offset_right = -4.0 if is_pressed else 24.0  
	
	tween.tween_property(knob, "anchor_left", target_anchor, 0.25)
	tween.tween_property(knob, "anchor_right", target_anchor, 0.25)
	tween.tween_property(knob, "offset_left", target_offset_left, 0.25)
	tween.tween_property(knob, "offset_right", target_offset_right, 0.25)
	
	if track_stylebox:
		tween.tween_property(track_stylebox, "bg_color", target_color, 0.2)

func _update_visuals_instant() -> void:
	if not is_inside_tree() or not knob: return
	_setup_stylebox()
	
	var target_anchor = 1.0 if is_pressed else 0.0
	knob.anchor_left = target_anchor
	knob.anchor_right = target_anchor
	knob.offset_left = -24.0 if is_pressed else 4.0
	knob.offset_right = -4.0 if is_pressed else 24.0
	
	var base_color = COLOR_TRACK_ON if is_pressed else COLOR_TRACK_OFF
	if track_stylebox:
		track_stylebox.bg_color = base_color.lerp(Color.WHITE, 0.1) if is_hovered else base_color

func _on_mouse_entered() -> void:
	is_hovered = true
	if track_stylebox:
		var base_color = COLOR_TRACK_ON if is_pressed else COLOR_TRACK_OFF
		track_stylebox.bg_color = base_color.lerp(Color.WHITE, 0.1)

func _on_mouse_exited() -> void:
	is_hovered = false
	if track_stylebox:
		var base_color = COLOR_TRACK_ON if is_pressed else COLOR_TRACK_OFF
		track_stylebox.bg_color = base_color
