extends Node3D

@onready var aui_bar_3d = $AUI_Bar   
@onready var tooltip_3d = $AUI_Tooltips

@onready var mainPanel = $CurvedPanel
@onready var popupPanel = $PopupPanel

@onready var viewport : Viewport = get_viewport()


var aui_fade_tween: Tween

var in_ar = false

#@export var scene_light: float = 1.0:
	#set(value):
		#scene_light = value
		#SignalBus.scene_light_intensity_changed.emit(value)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	tooltip_3d.visible = false
	var aui_bar_2d = aui_bar_3d.get_scene_instance()
	if aui_bar_2d:
		aui_bar_2d.show_tooltip.connect(_on_show_tooltip)
		aui_bar_2d.hide_tooltip.connect(_on_hide_tooltip)
	
	SignalBus.panel_open_requested.connect(curved_panel_go_to_scene)
	
	SignalBus.popup_open_requested.connect(open_popup)
	SignalBus.popup_finish_requested.connect(close_popup)
	
	SignalBus.aui_bar_show_requested.connect(func(): fade_aui_bar(true, 0.4))
	SignalBus.aui_bar_hide_requested.connect(func(): fade_aui_bar(false, 0.4))
	
	SignalBus.fade_in_scene.emit()
	aui_bar_3d.visible = false
	
	await SignalBus.fade_in_scene_finished
	
	await fade_aui_bar(true, 0.4)
	curved_panel_go_to_scene("res://scenes/Panel_Home.tscn")

	
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func open_popup(config: Dictionary):
	if popupPanel.has_method("get_scene_instance"):
		var popup_2d_node = popupPanel.get_scene_instance()
		
		if popup_2d_node and popup_2d_node.has_method("setup_popup"):
			popup_2d_node.setup_popup(config)
	
	
	popupPanel.visible = true
	aui_bar_3d.enabled = false
	$"AnimationPlayer".play("popup_in")

func close_popup(reason: String):
	popupPanel.visible = false
	aui_bar_3d.enabled = true
	$"AnimationPlayer".play("popup_out")
	
	
func fade_aui_bar(to_visible: bool, duration: float = 1.0) -> void:
	var screen_mesh: MeshInstance3D = aui_bar_3d.get_node_or_null("Screen")
	if not screen_mesh: return
	
	var mat = screen_mesh.get_active_material(0)
	
	if mat is StandardMaterial3D:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		
		#Kill any currently running fade
		if aui_fade_tween and aui_fade_tween.is_valid():
			aui_fade_tween.kill()
			
		aui_fade_tween = create_tween()
		
		if to_visible:
			var current_color = mat.albedo_color
			current_color.a = 0.0
			mat.albedo_color = current_color
			
			aui_bar_3d.visible = true
			
			aui_fade_tween.tween_property(mat, "albedo_color:a", 1.0, duration)
		else:
			aui_fade_tween.tween_property(mat, "albedo_color:a", 0.0, duration)
			aui_fade_tween.tween_callback(func(): aui_bar_3d.visible = false)
		
		await aui_fade_tween.finished


func curved_panel_go_to_scene(scene: String):
	if scene == "seeOutside":
		if in_ar == true:
			$"Root Scene".visible = true

			in_ar = false
			SignalBus.switch_to_vr.emit()
			SignalBus.fade_in_scene.emit()
		else:
			#We are in VR
			SignalBus.fade_out_scene.emit()
			await SignalBus.fade_out_scene_finished
			
			$"Root Scene".visible = false
	
			in_ar = true
		
			SignalBus.switch_to_ar.emit()
			
		return
	
	var new_scene_resource = load(scene)
	if new_scene_resource:
		if mainPanel.has_method("set_scene_instance"):
			mainPanel.set_scene_instance(null)
		elif "scene_instance" in mainPanel:
			if is_instance_valid(mainPanel.scene_instance):
				mainPanel.scene_instance.queue_free()
			mainPanel.scene_instance = null

		mainPanel.set_scene(new_scene_resource)
		


func _on_show_tooltip(type: String) -> void:
	var tooltip_2d = tooltip_3d.get_scene_instance()
	if tooltip_2d and tooltip_2d.has_method("display_mode"):
		tooltip_2d.display_mode(type)
		
	tooltip_3d.visible = true

func _on_hide_tooltip() -> void:
	tooltip_3d.visible = false
