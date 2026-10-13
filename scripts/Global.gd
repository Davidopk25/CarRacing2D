extends Node
 
const SAVE_PATH = "user://settings.cfg"
const USER_PATH = "user://user.save"

const SELECTED_TRACK_PATH = "user://track.save"
const SELECTED_CAR_PATH = "user://selectcar.save"
const PRICES_PATH = "user://prices.save"
const CARS_PATH = "user://cars.save"


# Настройки по умолчанию
var volume_db: float = 0.0 # В децибелах
var language: String = "en"
var fps_enabled: bool = false

var player_gold: int = 0
var player_diamonds: int = 0

var selected_track_index
var selected_car_index
var all_cars = []
var all_prices = []


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


func save_track():
	var file = FileAccess.open(SELECTED_TRACK_PATH, FileAccess.WRITE)
	if file:
		file.store_var(selected_track_index)
 
func load_track():
	if FileAccess.file_exists(SELECTED_TRACK_PATH):
		var file = FileAccess.open(SELECTED_TRACK_PATH, FileAccess.READ)
		if file:
			var loaded_value = file.get_var()
			# проверка так как файл повредился прошлый раз
			if loaded_value != null:
				selected_track_index = loaded_value
			else:
				selected_track_index = 0
		else:
			selected_track_index = 0


func save_car():
	var file = FileAccess.open(SELECTED_CAR_PATH, FileAccess.WRITE)
	if file:
		file.store_var(selected_car_index)

func load_car():
	if FileAccess.file_exists(SELECTED_CAR_PATH):
		var file = FileAccess.open(SELECTED_CAR_PATH, FileAccess.READ)
		if file:
			var loaded_value = file.get_var()
			
			if loaded_value != null:
				selected_car_index = loaded_value
			else:
				selected_car_index = 0
		else:
			selected_car_index = 0
		
		print(selected_car_index)


func save_CARS():
	var file = FileAccess.open(CARS_PATH, FileAccess.WRITE)
	if file:
		file.store_var(all_cars)
		file.close()

func load_CARS():
	if FileAccess.file_exists(CARS_PATH):
		var file = FileAccess.open(CARS_PATH, FileAccess.READ)
		
		if file:
			if file.get_error() == OK:
				var loaded_data = file.get_var()
					
				if loaded_data is Array and loaded_data.size() > 0:
					all_cars = loaded_data
					
				else:
					fix_cars_stats()
			else:
				fix_cars_stats()
		else:
			fix_cars_stats()
	else:
		fix_cars_stats()

func fix_cars_stats():
	var file = FileAccess.open(CARS_PATH, FileAccess.WRITE)
	all_cars = [
		{
			"name": "Silvia",
			"islocked": false,
			"speed": {"stats": 320 , "lvl": 0},
			"acceleration": {"stats": 6.0 , "lvl": 0},
			"management": {"stats": 6.0 , "lvl": 0},
			"braking": {"stats": 5.5 , "lvl": 0}
		},
		{
			"name": "Porsche",
			"islocked": true,
			"speed": {"stats": 380 , "lvl": 0},
			"acceleration": {"stats": 7.2 , "lvl": 0},
			"management": {"stats": 7.0 , "lvl": 0},
			"braking": {"stats": 4.6 , "lvl": 0}
		},
		{
			"name": "Ferrari",
			"islocked": true,
			"speed": {"stats": 440 , "lvl": 0},
			"acceleration": {"stats": 8.5 , "lvl": 0},
			"management": {"stats": 8.2 , "lvl": 0},
			"braking": {"stats": 3.8 , "lvl": 0}
		}
		]
	file.store_var(all_cars)
	file.close()


func save_user():
	var file = ConfigFile.new()
	file.set_value("player", "money", player_gold)
	file.set_value("player", "diamonds", player_diamonds)
	file.save(USER_PATH)

func load_user():
	var file = ConfigFile.new()
	file.load(USER_PATH)
	if file:
		if file.get_value("player", "money") != null:
			player_gold = file.get_value("player", "money")
		else:
			player_gold = 99999999999
			
		if file.get_value("player", "diamonds") != null:
			player_diamonds = file.get_value("player", "diamonds")
		else:
			player_diamonds = 99999999999
	
	else:
		player_gold = 0
		player_diamonds = 0


func save_prices():
	var file = FileAccess.open(PRICES_PATH, FileAccess.WRITE)
	if file:
		file.store_var(all_prices)
		file.close()

func load_prices():
	if FileAccess.file_exists(PRICES_PATH):
		var file = FileAccess.open(PRICES_PATH, FileAccess.READ)
		
		if file:
			if file.get_error() == OK:
				var loaded_data = file.get_var()
				
				if loaded_data is Array and loaded_data.size() > 0:
					all_prices = loaded_data
					
				else:
					fix_prices()
			else:
				fix_prices()
		else:
			fix_prices()
	else:
		fix_prices()

func fix_prices():
	var file = FileAccess.open(PRICES_PATH, FileAccess.WRITE)
	all_prices = [
	  {
		"name": "Silvia_prices", 
		"inflation": 1.35,
		"speed": {"upgrate": 12, "price": 1000},
		"acceleration": {"upgrate": 0.3, "price": 900},
		"management": {"upgrate": 0.3, "price": 800},
		"braking": {"upgrate": 0.15, "price": 850}
	  },
	  {
		"name": "Porsche_prices", 
		"inflation": 1.38,
		"speed": {"upgrate": 12, "price": 1500},
		"acceleration": {"upgrate": 0.25, "price": 1350},
		"management": {"upgrate": 0.25, "price": 1200},
		"braking": {"upgrate": 0.12, "price": 1275}
	  },
	  {
		"name": "Ferrari_prices", 
		"inflation": 1.42,
		"speed": {"upgrate": 14, "price": 2200},
		"acceleration": {"upgrate": 0.2, "price": 1980},
		"management": {"upgrate": 0.2, "price": 1760},
		"braking": {"upgrate": 0.1, "price": 1870}
	  }
	]
	file.store_var(all_prices)
	file.close()


func reset_for_newgame():
	DirAccess.remove_absolute(USER_PATH)
	DirAccess.remove_absolute(SELECTED_TRACK_PATH)
	DirAccess.remove_absolute(SELECTED_CAR_PATH)
	DirAccess.remove_absolute(PRICES_PATH)
	DirAccess.remove_absolute(CARS_PATH)
