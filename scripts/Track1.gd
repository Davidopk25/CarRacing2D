extends Node2D

## Assign the moving car and finish-line Area2D in the Inspector.
@export var car: Node2D
@export var finish_line: Area2D

## Distance required to complete one lap.
@export_range(1.0, 1000000.0, 1.0) var distance_per_lap: float = 1000.0

## Speed display multiplier.
@export var speed_display_scale: float = 1.0

const TOTAL_LAPS: int = 3

@onready var lap_label: Label = $ProgressBar/LapCount
@onready var time_label: Label = $ProgressBar/RaceTime
@onready var distance_bar: ProgressBar = $ProgressBar/DistanceBar
@onready var current_speed_label: Label = $SpeedStat/CurrentSpeed
@onready var top_speed_label: Label = $SpeedStat/TopSpeed
@onready var back_button: Button = $ExitButtonTrack

var current_lap: int = 1
var race_time: float = 0.0
var current_speed: float = 0.0
var top_speed: float = 0.0
var distance_this_lap: float = 0.0
var previous_car_position: Vector2 = Vector2.ZERO
var race_started: bool = false
var race_finished: bool = false


func _ready() -> void:
	lap_label.text = "LAP 1 / %d" % TOTAL_LAPS
	time_label.text = "00:00.00"

	distance_bar.min_value = 0.0
	distance_bar.max_value = 100.0
	distance_bar.value = 0.0

	current_speed_label.text = "SPEED: 0"
	top_speed_label.text = "TOP SPEED: 0"

	back_button.pressed.connect(_on_back_button_pressed)

	if car != null:
		previous_car_position = car.global_position
		race_started = true
	else:
		push_warning("Track1: Assign the car Node2D in the Inspector.")

	if finish_line != null:
		finish_line.body_entered.connect(
			_on_finish_line_body_entered
		)
	else:
		push_warning("Track1: Assign a finish-line Area2D.")


func _process(delta: float) -> void:
	if race_finished:
		return

	if race_started:
		race_time += delta
		time_label.text = _format_race_time(race_time)

	_update_car_stats(delta)
	_update_distance_progress()


func _update_car_stats(_delta: float) -> void:
	if car == null:
		return

	var frame_distance := car.global_position.distance_to(
		previous_car_position
	)

	distance_this_lap += frame_distance

	var velocity_value: Variant = car.get("velocity")

	if velocity_value is Vector2:
		current_speed = (
			velocity_value as Vector2
		).length() * speed_display_scale
	else:
		current_speed = (
			frame_distance /
			maxf(get_process_delta_time(), 0.0001)
		) * speed_display_scale

	previous_car_position = car.global_position

	top_speed = maxf(top_speed, current_speed)

	current_speed_label.text = "SPEED: %d" % roundi(current_speed)
	top_speed_label.text = "TOP SPEED: %d" % roundi(top_speed)


func _update_distance_progress() -> void:
	var total_distance := distance_per_lap * TOTAL_LAPS

	var completed_distance := (
		(current_lap - 1) * distance_per_lap
		+ distance_this_lap
	)

	var progress_percent := clampf(
		completed_distance / total_distance * 100.0,
		0.0,
		100.0
	)

	distance_bar.value = progress_percent


func _on_finish_line_body_entered(body: Node2D) -> void:
	if race_finished or car == null or body != car:
		return

	if current_lap < TOTAL_LAPS:
		current_lap += 1
		distance_this_lap = 0.0

		lap_label.text = "LAP %d / %d" % [
			current_lap,
			TOTAL_LAPS
		]
	else:
		race_finished = true

		distance_bar.value = 100.0
		lap_label.text = "FINISH!"


func add_lap_distance(amount: float) -> void:
	if not race_finished and amount > 0.0:
		distance_this_lap += amount


func _format_race_time(seconds: float) -> String:
	var minutes := int(seconds / 60.0)
	var whole_seconds := int(seconds) % 60

	var hundredths := int(
		(seconds - floorf(seconds)) * 100.0
	)

	return "%02d:%02d.%02d" % [
		minutes,
		whole_seconds,
		hundredths
	]


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(
		"res://scene/garage.tscn"
	)
