extends Control
 
@export var cards: Array[Control] = [] # Сюда перетащите ваши карты из инспектора
@export var btn_left: Button
@export var btn_right: Button
@export var btn_save: Button
@export var btn_close: Button

var current_index: int = 0
 
# Наборы параметров для визуального отображения (центральная, боковые, скрытые)
# Можно настроить позиции под ваш дизайн
const POS_CENTER = Vector2(500, 300)
const POS_LEFT = Vector2(289, 300)
const POS_RIGHT = Vector2(750, 300)
const POS_HIDDEN_LEFT = Vector2(100, 350)
const POS_HIDDEN_RIGHT = Vector2(900, 350)
 
func _ready():
	# Загружаем сохраненный выбор
	Global.load_game()
	current_index = Global.selected_track_index
	
	if btn_save and not btn_save.pressed.is_connected(_on_save_pressed):
		btn_save.pressed.connect(_on_save_pressed)
	if btn_close and not btn_close.pressed.is_connected(_on_close_pressed):
		btn_close.pressed.connect(_on_close_pressed)

	update_carousel()
 
func _on_left_pressed():
	if current_index > 0:
		current_index -= 1
		update_carousel()
 
func _on_right_pressed():
	if current_index < cards.size() - 1:
		current_index += 1
		update_carousel()

# Сохраняем выбор в глобальный скрипт только при нажатии на кнопку "Сохранить"
func _on_save_pressed():
	Global.selected_track_index = current_index
	Global.save_game()
	queue_free() # Закрываем сцену выбора
 
# При нажатии на крестик просто закрываем сцену без сохранения
func _on_close_pressed():
	queue_free()
 
func update_carousel():
	for i in range(cards.size()):
		var card = cards[i]
		
		# Автоматически находим метки внутри каждой карты
		var status_label = card.get_node_or_null("Panel/StatusLabel")
		var name_label = card.get_node_or_null("Panel/NameLabel")
		
		# Управляем локализованным текстом статуса
		if status_label:
			if i == Global.selected_track_index:
				# Ключ локализации для выбранной карты (например, из вашего CSV: "select.track" -> "ВЫБРАНО")
				status_label.text = tr("select.track")
				status_label.add_theme_color_override("font_color", Color("#2288ff"))
			else:
				# Ключ локализации для открытой/другой карты ("open.track" -> "ОТКРЫТО")
				status_label.text = tr("open.track")
				status_label.add_theme_color_override("font_color", Color("#22cc44"))

		# Названия треков вы можете прописать через CSV-ключи в NameLabel для каждой карты
		# (например, карточке 1 задать текст "diam.track", карточке 2 — другой ключ)
		# Разделяем логику в зависимости от позиции относительно выбранного индекса
		if i == current_index:
			# Центральная карта (ближе к пользователю)
			card.visible = true
			# Здесь можно использовать Tween для плавной анимации перемещения
			card.position = POS_CENTER
			card.scale = Vector2(1.0, 1.0)
			card.z_index = 10 # Поверх остальных
		elif i == current_index - 1:
			# Левая карта
			card.visible = true
			card.position = POS_LEFT
			card.scale = Vector2(0.8, 0.8)
			card.z_index = 5
		elif i == current_index + 1:
			# Правая карта
			card.visible = true
			card.position = POS_RIGHT
			card.scale = Vector2(0.8, 0.8)
			card.z_index = 5
		else:
			# Карты, которые находятся дальше видимой зоны (скрываем их)
			card.visible = false
 
	# Управляем видимостью кнопок-стрелок по краям
	if btn_left:
		btn_left.visible = (current_index > 0)
	if btn_right:
		btn_right.visible = (current_index < cards.size() - 1)
