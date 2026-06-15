extends Control

@onready var title_label: Label = %Header
@onready var body_text: RichTextLabel = %Body
@onready var action_btn: Button = %ActionButton
@onready var primary_btn: Button = %PrimaryButton
@onready var cancel_btn: Button = %CancelButton

#TODO: Remove callbacks, unused since we are using SignalBus now
var _on_action_callback: Callable
var _on_primary_callback: Callable
var _on_cancel_callback: Callable

func _ready() -> void:
	action_btn.pressed.connect(_on_button_pressed.bind("action"))
	primary_btn.pressed.connect(_on_button_pressed.bind("primary"))
	cancel_btn.pressed.connect(_on_button_pressed.bind("cancel"))

func setup_popup(config: Dictionary) -> void:
	title_label.text = config.get("title", "Notice")
	body_text.text = config.get("text", "")
	
	action_btn.text = config.get("action_text", "Action")
	primary_btn.text = config.get("primary_text", "Confirm")
	cancel_btn.text = config.get("cancel_text", "Cancel")
	
	action_btn.visible = config.get("action_text", "Action") != ""
	primary_btn.visible = config.get("primary_text", "Confirm") != ""
	cancel_btn.visible = config.get("cancel_text", "Cancel") != ""
	
	_on_action_callback = config.get("on_action", Callable())
	_on_primary_callback = config.get("on_primary", Callable())
	_on_cancel_callback = config.get("on_cancel", Callable())

func _on_button_pressed(reason: String) -> void:
	match reason:
		"action":
			if _on_action_callback.is_valid(): _on_action_callback.call()
		"primary":
			if _on_primary_callback.is_valid(): _on_primary_callback.call()
		"cancel":
			if _on_cancel_callback.is_valid(): _on_cancel_callback.call()
			
	SignalBus.popup_finish_requested.emit(reason)
