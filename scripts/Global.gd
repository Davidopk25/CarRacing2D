extends Node
 
const SAVE_PATH = "user://settings.cfg"
 
# Настройки по умолчанию
var volume_db: float = 0.0 # В децибелах
var language: String = "en"
var fps_enabled: bool = false
 
func _ready() -> void:
	load_settings()
 

# Загрузка настроек из файла
func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		volume_db = config.get_value("settings", "volume", 0.5)
		language = config.get_value("settings", "language", get_system_default_lang())
		fps_enabled = config.get_value("settings", "fps", false)
	else:
		# Если файла нет — берем системный язык и дефолтную громкость
		language = get_system_default_lang()
		volume_db = get_system_device_volume()
	
	apply_settings()
 
# Сохранение настроек в файл (вызывается только при нажатии Save)
func save_settings(new_vol: float, new_lang: String, new_fps: bool) -> void:
	volume_db = new_vol
	language = new_lang
	fps_enabled = new_fps
	
	var config = ConfigFile.new()
	config.set_value("settings", "volume", volume_db)
	config.set_value("settings", "language", language)
	config.set_value("settings", "fps", fps_enabled)
	config.save(SAVE_PATH)
	
	apply_settings()
 
# Применение настроек в саму игру
func apply_settings() -> void:
	# Применяем громкость (Master шина)
	var bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_idx, volume_db)
	
	# Применяем язык
	TranslationServer.set_locale(language)
	
	# Флаг FPS (можно отлавливать в других скриптах или оверлее)
 
func get_system_default_lang() -> String:
	var sys_lang = OS.get_locale_language()
	return sys_lang if sys_lang in ["ru", "en"] else "en"
 
func get_system_device_volume() -> float:
	# Возвращает базовый уровень в дБ (по умолчанию 0 дБ, так как прямого доступа к микшеру ОС в Godot нет)
	return 0.0
