extends Node2D

# Привязываем функции к кнопкам через код или через вкладку "Сигналы" в Godot
func _on_Play_pressed() -> void:
	# Путь к вашей игровой сцене
	get_tree().change_scene_to_file("res://scene/os_menu.tscn") 
 
func _on_Start_Over_pressed() -> void:
	# Игра сбрасывается до автоматических настроек
	pass

func _on_Settings_pressed() -> void:
	# Путь к сцене настроек
	get_tree().change_scene_to_file("res://scene/settings.tscn")

func _on_Exit_pressed() -> void:
	# Выход из игры
	get_tree().quit()
