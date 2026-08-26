extends Control

signal button_pressed(reason: String)

@onready var title_label: Label = %Header
@onready var body_text: RichTextLabel = %Body
@onready var action_btn: Button = %ActionButton
@onready var primary_btn: Button = %PrimaryButton
@onready var cancel_btn: Button = %CancelButton

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

func _on_button_pressed(reason: String) -> void:
	button_pressed.emit(reason)

func fade_in(duration: float):
	var tween = create_tween()

	%PanelContainer.modulate.a = 0
	tween.tween_property(%PanelContainer, "modulate:a", 1, duration)

func show_instant() -> void:
	%PanelContainer.modulate.a = 1
