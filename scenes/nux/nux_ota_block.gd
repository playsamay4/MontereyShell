extends Control

@onready var download_cta: Label = %DownloadCTA
@onready var appstore_icon: TextureRect = %AppStoreIcon
@onready var playstore_icon: TextureRect = %PlayStoreIcon
@onready var anim_container: VBoxContainer = %AnimContainer
@onready var pairing_code: Label = %PairingCode


const LANGUAGES: Array[String] = ["en", "de","es", "fr", "it", "ja", "ko", "pt", "ru", "zh_cn", "zh_tw"]
var current_lang_index: int = 0
var languages_since_english := 0

func _ready() -> void:
	pairing_code.text = SettingsManager.get_pairing_code()
	await get_tree().create_timer(4.0).timeout
	_cycle_language()
	pass

func _cycle_language() -> void:
	var tween = create_tween()
	
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(anim_container, "modulate:a", 0.0, 0.4)
	tween.tween_property(anim_container, "offset_top", -15.0, 0.4)
	tween.tween_property(anim_container, "offset_bottom", -15.0, 0.4)

	tween.chain().tween_callback(func():
		var next_locale: String

		if languages_since_english >= 2:

			next_locale = "en"
			languages_since_english = 0
		else:
			current_lang_index += 1

			if current_lang_index >= LANGUAGES.size():
				current_lang_index = 1

			next_locale = LANGUAGES[current_lang_index]
			languages_since_english += 1

		var appstore_path = "res://images/nux/img_ota_appstore_%s.png" % next_locale
		var playstore_path = "res://images/nux/img_ota_googleplay_%s.png" % next_locale

		if ResourceLoader.exists(appstore_path):
			appstore_icon.texture = load(appstore_path)

		if ResourceLoader.exists(playstore_path):
			playstore_icon.texture = load(playstore_path)

		download_cta.text = tr("NUX_OTA_BLOCK_QUEST_TITLE_" + next_locale.to_upper())
	)

	tween.chain().set_parallel(true)
	tween.tween_property(anim_container, "modulate:a", 1.0, 0.5)
	tween.tween_property(anim_container, "offset_top", 0.0, 0.5).from(15.0)
	tween.tween_property(anim_container, "offset_bottom", 0.0, 0.5).from(15.0)

	tween.chain().tween_interval(4.0)
	tween.chain().tween_callback(_cycle_language)
