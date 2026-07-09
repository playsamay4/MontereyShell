class_name AppManifest
extends Resource

## Declarative description of a launchable internal app.
## Drop a .tres of this type anywhere under res://apps/ and AppRegistry
## will pick it up automatically - no code changes needed to list it.

## Unique id, e.g. "system.settings" or "nux.health_and_safety".
@export var id: String = ""

## Human readable name shown in launchers.
@export var display_name: String = ""

## Icon shown in launchers. Optional.
@export var icon: Texture2D = null

## Root scene instantiated into a window when this app is launched.
@export var scene: PackedScene = null

## Grouping used by launcher UIs (debug panel, dock, etc).
@export var category: String = "General"
