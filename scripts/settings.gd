extends Control
 
# Ссылки на ваши узлы интерфейса (проверьте пути под ваше дерево сцены)
@onready var h_slider: HSlider = $%HSlider
@onready var check_button: CheckButton = $%CheckButton
 
# Ссылки на панели, которые будут менять цвет
@onready var en_panel: Control = $%EN_Panel
@onready var ru_panel: Control = $%RU_Panel

# Временные переменные для несохраненных изменений
var temp_volume: float = 0.0
var original_volume: float = 0.0
var temp_language: String = "en"
var original_language: String = "en"
var temp_fps: bool = false
var original_fps: bool = false
 
func _ready() -> void:
	# Загружаем текущие значения из глобального менеджера во временные
	temp_volume = Global.volume_db
	original_volume = Global.volume_db
	temp_language = Global.language
	original_language = Global.language
	temp_fps = Global.fps_enabled
	original_fps=Global.fps_enabled
	
	# Устанавливаем элементы интерфейса в актуальное положение
	h_slider.value = temp_volume
	check_button.button_pressed = temp_fps
	# Обновляем подсветку панелей при открытии меню
	update_language_panels(temp_language)
 
# Изменение слайдера громкости (пока меняется только временно)
func _on_h_slider_value_changed(value: float) -> void:
	temp_volume = value
	var bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_idx, temp_volume)
 
# Кнопки смены языка (временный выбор)
func _on_russian_pressed() -> void:
	temp_language = "ru"
	TranslationServer.set_locale(temp_language)
	update_language_panels(temp_language)

func _on_english_pressed() -> void:
	temp_language = "en"
	TranslationServer.set_locale(temp_language)
	update_language_panels(temp_language)

# Чекбокс FPS (временный выбор)
func _on_check_button_toggled(toggled_on: bool) -> void:
	temp_fps = toggled_on
	Global.fps_enabled = temp_fps
 
# Кнопка сохранения (Save_Img / или кнопка поверх нее)
# Привяжите сигнал нажатия (например, gui_input или Button) к этой функции:
func _on_save_pressed() -> void:
	Global.save_settings(temp_volume, temp_language, temp_fps)
	print("Настройки успешно сохранены!")
	queue_free()
 
# Кнопка закрытия без сохранения (крестик)
func _on_close_pressed() -> void:
	# Ничего не сохраняем, просто закрываем сцену
	Global.fps_enabled = original_fps
	var bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_idx, original_volume)
	TranslationServer.set_locale(Global.language)
	queue_free()
	
# Функция для изменения цвета панелей в зависимости от языка
func update_language_panels(lang: String) -> void:
	if lang == "ru":
		ru_panel.self_modulate = Color("659fd1") # активный
		en_panel.self_modulate = Color("172647") # Обычный цвет
	else:
		en_panel.self_modulate = Color("659fd1") # активный
		ru_panel.self_modulate = Color("172647") # Обычный цвет
