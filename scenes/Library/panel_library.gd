extends PanelContainer

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

var LibraryPanelAppIcon = preload("res://templates/libraryPanelAppIcon.tscn")

@onready var apps_content = %AppsContent

var app_buttons: Dictionary = {}
var population_thread: Thread

func _ready() -> void:
	population_thread = Thread.new()
	population_thread.start(_bg_populate_library)
	
	PackageManager.app_icon_updated.connect(_on_app_icon_updated)

func _bg_populate_library() -> void:
	#temporarily store items here so wedon't manipulate the active scene tree yet
	var instantiated_items: Array = []
	
	for app in PackageManager.installed_apps:
		if app.package_id in PackageManager.BLACKLIST: 
			continue
			
		var new_item = LibraryPanelAppIcon.instantiate()
		new_item.title = app.name
		new_item.date = format_install_time(app.install_time_ms)
		
		new_item.pressed.connect(func(): PackageManager.launch_app(app.package_id))
		
		if app.icon_texture:
			new_item.icon = app.icon_texture
			
		app_buttons[app.package_id] = new_item
		instantiated_items.append(new_item)
		
	_add_items_to_tree.call_deferred(instantiated_items)

func _add_items_to_tree(items: Array) -> void:
	for item in items:
		apps_content.add_child(item)
		
	if population_thread and population_thread.is_started():
		population_thread.wait_to_finish()

func _exit_tree() -> void:
	if population_thread && population_thread.is_started():
		population_thread.wait_to_finish()

func _on_app_icon_updated(package_id: String, texture: Texture2D) -> void:
	if app_buttons.has(package_id) and is_instance_valid(app_buttons[package_id]):
		app_buttons[package_id].icon = texture

func format_install_time(unix_seconds: int) -> String:
	var date = Time.get_date_dict_from_unix_time(unix_seconds/1000)
	
	var month_name = MONTHS[date.month - 1]
	
	return "%s %02d, %d" % [month_name, date.day, date.year]
