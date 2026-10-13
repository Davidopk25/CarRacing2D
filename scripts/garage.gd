extends Node2D

@onready var Carimg = $CarBlueprint

var current_car: int = 0
var gold = Global.player_gold

func _ready():
	# Загружаем сохраненный выбор
	Global.load_car()
	Global.load_CARS()
	current_car = Global.selected_car_index
	
	if current_car == 0:
		Carimg.texture = load("res://image/Garage/cars/Silvia/2.png")
	elif current_car == 1:
		Carimg.texture = load("res://image/Garage/cars/Porsche/2.png")
	elif current_car == 2:
		Carimg.texture = load("res://image/Garage/cars/Ferrari/2.png")
	
	
	_show_stats()
	_show_money()
	_show_locks()



func _go_back() -> void:
	get_tree().change_scene_to_file("res://scene/os_menu.tscn")


func _on_car_1_pressed() -> void:
	current_car = 0
	Carimg.texture = load("res://image/Garage/cars/Silvia/2.png")
	
	_show_stats()


func _on_car_2_pressed() -> void:
	current_car = 1
	Carimg.texture = load("res://image/Garage/cars/Porsche/2.png")
	
	_show_stats()


func _on_car_3_pressed() -> void:
	current_car = 2
	Carimg.texture = load("res://image/Garage/cars/Ferrari/2.png")
	
	_show_stats()

func _show_stats():
	$Stats/Speed_bar/Speed_stat.text = str(Global.all_cars[current_car]["speed"]["stats"])
	$Stats/Acceleration_bar/Acceleration_stat.text = str(Global.all_cars[current_car]["acceleration"]["stats"])
	$Stats/Handling_bar/Handling_stat.text = str(Global.all_cars[current_car]["management"]["stats"])
	$Stats/Braking_bar/Braking_stat.text = str(Global.all_cars[current_car]["braking"]["stats"])
	
	$Stats/Speed_bar.value = Global.all_cars[current_car]["speed"]["stats"]
	$Stats/Acceleration_bar.value = Global.all_cars[current_car]["acceleration"]["stats"]
	$Stats/Handling_bar.value = Global.all_cars[current_car]["management"]["stats"]
	$Stats/Braking_bar.value = Global.all_cars[current_car]["braking"]["stats"]


func _show_locks():
	if Global.all_cars[1]["islocked"] == true:
		$Car2.disabled = true 
	else:
		$Car2.disabled = false 
		$Car2/Lock.disabled = true
		$Car2/Lock.visible = false
		
	if Global.all_cars[2]["islocked"] == true:
		$Car3.disabled = true
	else:
		$Car3.disabled = false 
		$Car3/Lock.disabled = true
		$Car3/Lock.visible = false


func _show_money():
	$Profile/Resourses/Coin_label.text = str(Global.player_gold)
	$Profile/Resourses/Diamond_label.text = str(Global.player_diamonds)


func _on_lock_pressed() -> void:
	if Global.player_gold >= 25000:
		
		Global.player_gold = Global.player_gold - 25000
		Global.all_cars[1]["islocked"] = false
		
		Global.save_user()
		Global.save_CARS()
		
		_show_stats()
		_show_money()
		_show_locks()

func _on_lock2_pressed() -> void:
	if Global.player_gold >= 75000:
		
		Global.player_gold = Global.player_gold - 75000
		Global.all_cars[2]["islocked"] = false
		
		Global.save_user()
		Global.save_CARS()
		
		_show_stats()
		_show_money()
		_show_locks()


func _on_select_pressed() -> void:
	#сохранить в .save
	Global.selected_car_index = current_car
	Global.save_car()
	_go_back()
