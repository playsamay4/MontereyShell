extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:

	await get_tree().create_timer(3.4).timeout
	%ProgressBar.show()
	
	if SettingsManager.get_value("settings", "nuxStatus") != SettingsManager.NUX_STATUS.DAY0_OTA_READY:
		while %ProgressBar.value < 50.0:
			%ProgressBar.value += (randi() % 20)
			await get_tree().create_timer((randi() % 3+0.4)).timeout
		%ProgressBar.value = 50.0
	
		await get_tree().create_timer(3).timeout
		print("restart!!")
		SettingsManager.set_value("settings", "nuxStatus", SettingsManager.NUX_STATUS.DAY0_OTA_READY)
		SignalBus.restart.emit()
		return
	else:
		%ProgressBar.value = 50.0
		await get_tree().create_timer(3).timeout
		await UiAudioManager.fade_out_env_audio(1)
		SettingsManager.set_value("settings", "nuxStatus", SettingsManager.NUX_STATUS.NOTIFY_ENDPOINT)
		SignalBus.restart.emit()
		
