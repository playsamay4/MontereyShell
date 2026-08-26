extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:

	await get_tree().create_timer(3.4).timeout
	%ProgressBar.show()
	
	if SettingsManager.get_value("settings", "nuxStatus") != SettingsManager.NUX_STATUS.DAY0_OTA_READY:
		while %ProgressBar.value < 50.0:
			var step_inc: float = float(randi() % 15 + 5)
			%ProgressBar.value = minf(%ProgressBar.value + step_inc, 50.0)
			await get_tree().create_timer(randf_range(0.4, 1.8)).timeout
		%ProgressBar.value = 50.0

		await get_tree().create_timer(2.0).timeout
		print("[NuxUpdatingPopup] Part 1 complete (50%), restarting into DAY0_OTA_READY")
		SettingsManager.set_value("settings", "nuxStatus", SettingsManager.NUX_STATUS.DAY0_OTA_READY)
		SignalBus.restart.emit()
		return
	else:
		%ProgressBar.value = 50.0
		while %ProgressBar.value < 100.0:
			var step_inc: float = float(randi() % 15 + 5)
			%ProgressBar.value = minf(%ProgressBar.value + step_inc, 100.0)
			await get_tree().create_timer(randf_range(0.4, 1.8)).timeout
		%ProgressBar.value = 100.0

		await get_tree().create_timer(1.0).timeout
		await UiAudioManager.fade_out_env_audio(1)
		SettingsManager.set_value("settings", "nuxStatus", SettingsManager.NUX_STATUS.NOTIFY_ENDPOINT)
		SignalBus.restart.emit()

		
