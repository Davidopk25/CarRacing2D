extends Node2D
# Предзагружаем сцену настроек
var settings_scene = preload("res://scene/settings.tscn")
var track_scene = preload("res://scene/track.tscn")
var garage_scene = preload("res://scene/garage.tscn")

var current_car: int = 0


@onready var Carimg = $CarBlueprint
@onready var map_text = $Race/Map_Name

func _ready() -> void:
	Global.load_car()
	Global.load_CARS()
	Global.load_track()
	Global.load_user()
	Global.load_prices()
	
	current_car = Global.selected_car_index
	
	if current_car == 0:
		Carimg.texture = load("res://image/Garage/cars/Silvia/2.png")
	elif current_car == 1:
		Carimg.texture = load("res://image/Garage/cars/Porsche/2.png")
	elif current_car == 2:
		Carimg.texture = load("res://image/Garage/cars/Ferrari/2.png")
		
	_show_stats()
	_show_money()
	_show_upgrates()
	
	_update_track()

# переносы по сценам
func _on_Settings_pressed() -> void:
	var settings_instance = settings_scene.instantiate()
	get_tree().current_scene.add_child(settings_instance)

func _on_Map_pressed() -> void:
	var track_instance = track_scene.instantiate()
	get_tree().current_scene.add_child(track_instance)

func _on_Garage_pressed() -> void:
	var garage_instance = garage_scene.instantiate()
	get_tree().current_scene.add_child(garage_instance)

func _show_stats():
	$Stats/Speed_bar/Speed_stat.text = str(Global.all_cars[current_car]["speed"]["stats"])
	$Stats/Acceleration_bar/Acceleration_stat.text = str(Global.all_cars[current_car]["acceleration"]["stats"])
	$Stats/Handling_bar/Handling_stat.text = str(Global.all_cars[current_car]["management"]["stats"])
	$Stats/Braking_bar/Braking_stat.text = str(Global.all_cars[current_car]["braking"]["stats"])
	
	$Stats/Speed_bar/Speed_bar.value = Global.all_cars[current_car]["speed"]["stats"]
	$Stats/Acceleration_bar/Acceleration_bar.value = Global.all_cars[current_car]["acceleration"]["stats"]
	$Stats/Handling_bar/Handling_bar.value = Global.all_cars[current_car]["management"]["stats"]
	$Stats/Braking_bar/Braking_bar.value = Global.all_cars[current_car]["braking"]["stats"]

func _show_money():
	$Profile/Resourses/Coin_label.text = str(Global.player_gold)
	$Profile/Resourses/Diamond_label.text = str(Global.player_diamonds)

func _show_upgrates():
	$Engine/Panel2/Engine_price.text = str(int(Global.all_prices[current_car]["speed"]["price"] * (Global.all_prices[current_car]["inflation"]**Global.all_cars[current_car]["speed"]["lvl"])))
	$Chassis/Panel2/Chassis_price.text = str(int(Global.all_prices[current_car]["acceleration"]["price"] * (Global.all_prices[current_car]["inflation"]**Global.all_cars[current_car]["acceleration"]["lvl"])))
	$Brakes/Panel2/Brakes_price.text = str(int(Global.all_prices[current_car]["management"]["price"] * (Global.all_prices[current_car]["inflation"]**Global.all_cars[current_car]["management"]["lvl"])))
	$Gearbox/Panel2/Gearbox_price.text = str(int(Global.all_prices[current_car]["braking"]["price"] * (Global.all_prices[current_car]["inflation"]**Global.all_cars[current_car]["braking"]["lvl"])))
	
	$Engine/Engine_showup.text = "+" + str(Global.all_prices[current_car]["speed"]["upgrate"])
	$Chassis/Chassis_showup.text = "+" + str(Global.all_prices[current_car]["acceleration"]["upgrate"])
	$Brakes/Brakes_showup.text = "+" + str(Global.all_prices[current_car]["management"]["upgrate"])
	$Gearbox/Gearbox_showup.text = "+" + str(Global.all_prices[current_car]["braking"]["upgrate"])
	
	$Engine/Engine_showlv.text = "Lv " + str(Global.all_cars[current_car]["speed"]["lvl"]) + "/10"
	$Chassis/Chassis_showlv.text = "Lv " + str(Global.all_cars[current_car]["acceleration"]["lvl"]) + "/10"
	$Brakes/Brakes_showlv.text = "Lv " + str(Global.all_cars[current_car]["management"]["lvl"]) + "/10"
	$Gearbox/Gearbox_showlv.text = "Lv " + str(Global.all_cars[current_car]["braking"]["lvl"]) + "/10"

#отображение названия карты на кнопке RACE
func _update_track():
	var file1 = Global.selected_track_index
	
	if file1 == 0:
		map_text.text = "diam.track"
	elif file1 == 1:
		map_text.text = "the_russian.plain.track"
	elif file1 == 2:
		map_text.text = "mt.fuji.track"


func _on_engine_pressed() -> void:
	if Global.all_cars[current_car]["speed"]["lvl"] < 10:
		if Global.player_gold >= Global.all_prices[current_car]["speed"]["price"]:
		
			#currentprice = price*(inflation ** lvl)
			Global.player_gold = Global.player_gold - Global.all_prices[current_car]["speed"]["price"] * (Global.all_prices[current_car]["inflation"]**Global.all_cars[current_car]["speed"]["lvl"])
			#lvl = lvl + 1
			Global.all_cars[current_car]["speed"]["lvl"] = Global.all_cars[current_car]["speed"]["lvl"]+1 
			#speed = speed + power
			Global.all_cars[current_car]["speed"]["stats"] = Global.all_cars[current_car]["speed"]["stats"] + Global.all_prices[current_car]["speed"]["upgrate"]
			
			_show_stats()
			_show_money()
			_show_upgrates()
			
			Global.save_CARS()


func _on_chassis_pressed() -> void:
	if Global.all_cars[current_car]["acceleration"]["lvl"] < 10:
		if Global.player_gold >= Global.all_prices[current_car]["acceleration"]["price"]:
		
			#currentprice = price*(inflation ** lvl)
			Global.player_gold = Global.player_gold - Global.all_prices[current_car]["acceleration"]["price"] * (Global.all_prices[current_car]["inflation"]**Global.all_cars[current_car]["acceleration"]["lvl"])
			#lvl = lvl + 1
			Global.all_cars[current_car]["acceleration"]["lvl"] = Global.all_cars[current_car]["acceleration"]["lvl"]+1 
			#speed = speed + power
			Global.all_cars[current_car]["acceleration"]["stats"] = Global.all_cars[current_car]["acceleration"]["stats"] + Global.all_prices[current_car]["acceleration"]["upgrate"]
			
			_show_stats()
			_show_money()
			_show_upgrates()
			
			Global.save_CARS()


func _on_brakes_pressed() -> void:
	if Global.all_cars[current_car]["management"]["lvl"] < 10:
		if Global.player_gold >= Global.all_prices[current_car]["management"]["price"]:
		
			#currentprice = price*(inflation ** lvl)
			Global.player_gold = Global.player_gold - Global.all_prices[current_car]["management"]["price"] * (Global.all_prices[current_car]["inflation"]**Global.all_cars[current_car]["management"]["lvl"])
			#lvl = lvl + 1
			Global.all_cars[current_car]["management"]["lvl"] = Global.all_cars[current_car]["management"]["lvl"]+1 
			#speed = speed + power
			Global.all_cars[current_car]["management"]["stats"] = Global.all_cars[current_car]["management"]["stats"] + Global.all_prices[current_car]["management"]["upgrate"]
			
			_show_stats()
			_show_money()
			_show_upgrates()
			
			Global.save_CARS()


func _on_gearbox_pressed() -> void:
	if Global.all_cars[current_car]["braking"]["lvl"] < 10:
		if Global.player_gold >= Global.all_prices[current_car]["braking"]["price"]:
		
			#currentprice = price*(inflation ** lvl)
			Global.player_gold = Global.player_gold - Global.all_prices[current_car]["braking"]["price"] * (Global.all_prices[current_car]["inflation"]**Global.all_cars[current_car]["braking"]["lvl"])
			#lvl = lvl + 1
			Global.all_cars[current_car]["braking"]["lvl"] = Global.all_cars[current_car]["braking"]["lvl"]+1 
			#speed = speed + power
			Global.all_cars[current_car]["braking"]["stats"] = Global.all_cars[current_car]["braking"]["stats"] + Global.all_prices[current_car]["braking"]["upgrate"]
			
			_show_stats()
			_show_money()
			_show_upgrates()
			
			Global.save_CARS()



func _on_engine_mouse_entered() -> void:
	$Stats/Speed_bar.value = Global.all_cars[current_car]["speed"]["stats"] + Global.all_prices[current_car]["speed"]["upgrate"]
func _on_engine_mouse_exited() -> void:
	$Stats/Speed_bar.value = 0


func _on_engine_2_mouse_entered() -> void:
	$Stats/Acceleration_bar.value = Global.all_cars[current_car]["acceleration"]["stats"] + Global.all_prices[current_car]["acceleration"]["upgrate"]
func _on_engine_2_mouse_exited() -> void:
	$Stats/Acceleration_bar.value = 0


func _on_engine_3_mouse_entered() -> void:
	$Stats/Handling_bar.value = Global.all_cars[current_car]["management"]["stats"] + Global.all_prices[current_car]["management"]["upgrate"]
func _on_engine_3_mouse_exited() -> void:
	$Stats/Handling_bar.value = 0


func _on_engine_4_mouse_entered() -> void:
	$Stats/Braking_bar.value = Global.all_cars[current_car]["braking"]["stats"] + Global.all_prices[current_car]["braking"]["upgrate"]
func _on_engine_4_mouse_exited() -> void:
	$Stats/Braking_bar.value = 0
