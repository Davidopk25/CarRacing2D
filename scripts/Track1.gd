extends Node2D

@export var custom_start_positions: Array[Vector2] = [
	Vector2(125.0, 7.5),
	Vector2(25.0, 7.5),
	Vector2(50.0, -5.0),
	Vector2(75.0, -1.5),
	Vector2(100.0, -1.5)
]
@export var custom_start_angles_deg: Array[float] = [180.0, 180.0, 180.0, 180.0, 180.0] # Опционально: угол в градусах (0 = вправо, 180 = влево)
@export var start_y_offset: float = 200.0 # Смещение по Y стартовых позиций

@export var main_path: Path2D
@export var overtake_path: Path2D
@export var finish_line: Area2D
@export var player_follow_index: int = 0

@export var use_scene_positions: bool = true
@export var start_ratios: Array[float] = [0.02, 0.045, 0.07, 0.095, 0.12]
@export var grid_stagger_offset: float = 14.0
@export var launch_straight_time: float = 0.6
@export var start_hold_time: float = 0.5
@export var path_merge_duration: float = 0.65
@export var randomize_laps_each_race: bool = true
@export_range(3, 7) var total_laps: int = 3

@export var start_lane_lock_time: float = 1.6
@export var max_lateral_offset: float = 2.0
@export var two_lane_width: float = 2.0
@export var max_cars_in_overtake_row: int = 2

@export var speed_display_scale: float = 0.45
@export var overtake_detect_distance: float = 200.0
@export var overtake_clear_distance: float = 100.0
@export var car_separation_distance: float = 52.0
@export var car_body_radius: float = 25.0

@export var corner_lookahead_px: float = 120.0
@export var max_corner_slowdown: float = 0.29
@export var max_speed_drop_per_sec: float = 250.0
@export var boost_duration: float = 0.1
@export var boost_cooldown: float = 5.0
@export var boost_speed_mult: float = 1.5
@export var boost_accel_mult: float = 1.1

@export var max_trail_length: float = 85.0
@export var min_trail_length: float = 10.0
@export var wheel_track_offset: float = 7.0
@export var rear_axle_offset: float = 10.0

# Настройки для частых побед игрока без резких рывков ботов
const POST_START_CAR_BODY_RADIUS: float = 20.0
const POST_START_RADIUS_DELAY: float = 5.0
const BOT_STAT_MULTIPLIERS: Array[float] = [0.95, 0.9, 0.85, 0.9]
const BOT_AGGRESSIONS: Array[float] = [1.3, 1.2, 1.1, 1.0]
const CAR_TEXTURES: Array[String] = [
	"res://image/Garage/cars/Silvia/1.png",
	"res://image/Garage/cars/Porsche/1.png",
	"res://image/Garage/cars/Ferrari/1.png"
]

@onready var lap_label: Label = get_node_or_null("ProgressBar/LapCount")
@onready var time_label: Label = get_node_or_null("ProgressBar/RaceTime")
@onready var distance_bar: ProgressBar = get_node_or_null("DistanceBar")
@onready var current_speed_label: Label = get_node_or_null("SpeedStat/CurrentSpeed")
@onready var top_speed_label: Label = get_node_or_null("SpeedStat/TopSpeed")
@onready var back_button: Button = get_node_or_null("ExitButtonTrack")
@onready var pos_label: Label = get_node_or_null("ProgressBar/PositionLabel") if get_node_or_null("ProgressBar/PositionLabel") != null else get_node_or_null("PositionLabel")

class RacerData:
	var follow: PathFollow2D
	var area: Area2D
	var visual_node: CanvasItem = null
	var visual_base_rot: float = 0.0
	var car_width: float = 36.0
	var is_player: bool
	var max_speed: float
	var accel: float
	var handling: float
	var braking: float
	var aggression: float = 1.0
	var pace_offset: float = 0.0
	var current_speed: float = 0.0
	var lap: int = 1
	var start_ratio: float = 0.0
	var total_progress_ratio: float = 0.0
	var lap_progress_accum: float = 0.0
	var prev_ratio: float = 0.0
	var finished: bool = false
	var finish_order: int = 0
	var race_rank: int = 1

	var start_world_pos: Vector2 = Vector2.ZERO
	var start_angle: float = 0.0
	var initial_lateral_offset: float = 0.0
	var current_world_pos: Vector2 = Vector2.ZERO
	var current_angle: float = 0.0
	var start_grid_offset: float = 0.0

	# 0 = нет обгона, 1 = смена полосы, 2 = плавный обгон
	var overtake_stage: int = 0
	var using_overtake_path: bool = false
	var overtake_side: float = 1.0
	var lane_blend: float = 0.0
	var side_dodge_offset: float = 0.0
	var desired_lane_offset: float = 0.0
	var hold_timer: float = 0.0
	var overtake_cooldown: float = 0.0
	var ai_mistake_timer: float = 0.0
	var ai_mistake_bias: float = 0.0

	var yielding_to_main: bool = false
	var slight_push_active: bool = false

	var boost_timer: float = 0.0
	var boost_cooldown_timer: float = 0.0
	var prev_curvature: float = 0.0
	var smooth_curvature: float = 0.0
	var corner_exit_blend: float = 0.0
	var corner_exit_boost_timer: float = 0.0
	var slip_angle: float = 0.0

	var left_trail: Line2D = null
	var right_trail: Line2D = null
	var left_points: Array[Vector2] = []
	var right_points: Array[Vector2] = []
	var skid_cooldown: float = 0.0

var racers: Array[RacerData] = []
var race_time: float = 0.0
var race_running: bool = false
var top_speed_reached: float = 0.0
var finish_counter: int = 0

func _ready() -> void:
	randomize()
	Global.load_car()
	Global.load_CARS()
	Global.load_user()

	total_laps = randi_range(999, 999) if randomize_laps_each_race else clampi(total_laps, 999, 999)

	if main_path == null:
		main_path = get_node_or_null("Path2D")
	if overtake_path == null:
		overtake_path = get_node_or_null("Path2D2")
	if finish_line == null:
		finish_line = get_node_or_null("FinishLine")

	if distance_bar != null:
		distance_bar.min_value = 0.0
		distance_bar.max_value = 100.0
		distance_bar.value = 0.0
	if lap_label != null:
		lap_label.text = "LAP 1 / %d" % total_laps
	if time_label != null:
		time_label.text = "00:00.00"
	if current_speed_label != null:
		current_speed_label.text = "SPEED: 0"
	if top_speed_label != null:
		top_speed_label.text = "TOP SPEED: 0"
	if pos_label != null:
		pos_label.text = "POS: 1 / 1"

	if back_button and not back_button.pressed.is_connected(_on_back_button_pressed):
		back_button.pressed.connect(_on_back_button_pressed)
	if finish_line and not finish_line.area_entered.is_connected(_on_finish_area_entered):
		finish_line.area_entered.connect(_on_finish_area_entered)
	if finish_line and not finish_line.body_entered.is_connected(_on_finish_body_entered):
		finish_line.body_entered.connect(_on_finish_body_entered)

	_setup_racers()
	race_running = true

func _get_node_world_pos(node: CanvasItem, fallback_pf: PathFollow2D) -> Vector2:
	if node is Node2D:
		var p2d := (node as Node2D).global_position
		if p2d.length_squared() > 0.01:
			return p2d
	elif node is Control:
		var ctrl := node as Control
		var cpos := ctrl.global_position + ctrl.size * 0.5
		if cpos.length_squared() > 0.01:
			return cpos
	return fallback_pf.global_position

func _get_scene_start_angle(pf: PathFollow2D, vis: CanvasItem, fallback_ang: float) -> float:
	if vis is Node2D:
		var n2d := vis as Node2D
		if absf(n2d.rotation) > 0.0001:
			return n2d.global_rotation
	elif vis is Control:
		var ctrl := vis as Control
		if absf(ctrl.rotation) > 0.0001:
			return ctrl.global_rotation
	if absf(pf.rotation) > 0.0001:
		return pf.global_rotation
	return fallback_ang

func _center_visual_on_follow(vis: CanvasItem) -> void:
	if vis is Node2D:
		var n2d := vis as Node2D
		n2d.position = Vector2.ZERO
		n2d.rotation = 0.0
	elif vis is Control:
		var ctrl := vis as Control
		ctrl.pivot_offset = ctrl.size * 0.5
		ctrl.position = -ctrl.size * 0.5
		ctrl.rotation = 0.0

func _setup_racers() -> void:
	racers.clear()
	if main_path == null or main_path.curve == null:
		push_warning("Track: Assign main_path (Path2D) with a Curve2D.")
		return

	var follows: Array[PathFollow2D] = []
	for child in main_path.get_children():
		if child is PathFollow2D:
			follows.append(child)
	if follows.is_empty():
		return

	var safe_player_idx: int = clampi(player_follow_index, 0, follows.size() - 1)
	var car_idx: int = clampi(Global.selected_car_index, 0, int(maxf(float(Global.all_cars.size()) - 1.0, 0.0)))
	var player_car: Dictionary = Global.all_cars[car_idx] if not Global.all_cars.is_empty() else {}

	var p_speed: float = float(player_car.get("speed", {}).get("stats", 240.0)) * 1.38
	var p_accel: float = float(player_car.get("acceleration", {}).get("stats", 8.0)) * 42.0
	var p_handling: float = float(player_car.get("management", {}).get("stats", 7.0))
	var p_braking: float = float(player_car.get("braking", {}).get("stats", 5.0)) * 58.0

	var main_len: float = maxf(main_path.curve.get_baked_length(), 1.0)
	var bot_idx: int = 0

	for i in range(follows.size()):
		var pf: PathFollow2D = follows[i]
		pf.loop = true
		pf.h_offset = 0.0
		pf.v_offset = 0.0

		var old_marker: Node = pf.get_node_or_null("PlayerIndicator")
		if old_marker != null:
			old_marker.queue_free()

		var vis: CanvasItem = _find_visual_in_follow(pf)
		var scene_pos: Vector2 = _get_node_world_pos(vis, pf)

		var initial_ratio: float = 0.0
		var spawn_pos: Vector2 = scene_pos
		var path_ang_init: float = _get_curve_angle(main_path, 0.0, main_len)
		var scene_start_ang: float = _get_scene_start_angle(pf, vis, path_ang_init)

		if i < custom_start_positions.size():
			spawn_pos = custom_start_positions[i]
			if i < custom_start_angles_deg.size():
				scene_start_ang = deg_to_rad(custom_start_angles_deg[i])
		elif use_scene_positions:
			spawn_pos = scene_pos
			if i < custom_start_angles_deg.size():
				scene_start_ang = deg_to_rad(custom_start_angles_deg[i])
		else:
			initial_ratio = fposmod(start_ratios[i], 1.0) if i < start_ratios.size() else fposmod(0.02 + float(i) * 0.025, 1.0)
			var base_p: Vector2 = main_path.to_global(main_path.curve.sample_baked(initial_ratio * main_len, true))
			var base_a: float = _get_curve_angle(main_path, initial_ratio, main_len)
			var norm_v: Vector2 = Vector2(-sin(base_a), cos(base_a))
			var side_s: float = -1.0 if (i % 2 == 0) else 1.0
			spawn_pos = base_p + norm_v * (side_s * grid_stagger_offset)
			scene_start_ang = deg_to_rad(custom_start_angles_deg[i]) if i < custom_start_angles_deg.size() else base_a

		spawn_pos.y += start_y_offset

		if i < custom_start_positions.size() or use_scene_positions:
			var closest_offset: float = main_path.curve.get_closest_offset(main_path.to_local(spawn_pos))
			initial_ratio = fposmod(closest_offset / main_len, 1.0)

		pf.rotates = false
		if vis != null:
			_center_visual_on_follow(vis)

		var r: RacerData = RacerData.new()
		r.follow = pf
		r.area = _find_area_in_follow(pf)
		r.visual_node = vis
		if r.visual_node != null:
			r.visual_node.z_index = 3
			r.visual_base_rot = 0.0

		r.is_player = (i == safe_player_idx)
		r.start_ratio = initial_ratio
		r.prev_ratio = initial_ratio
		r.total_progress_ratio = initial_ratio

		var path_pos: Vector2 = main_path.to_global(main_path.curve.sample_baked(initial_ratio * main_len, true))
		var path_ang: float = _get_curve_angle(main_path, initial_ratio, main_len)
		var path_normal: Vector2 = Vector2(-sin(path_ang), cos(path_ang))

		var raw_lat: float = (spawn_pos - path_pos).dot(path_normal)
		r.initial_lateral_offset = clampf(raw_lat, -90.0, 90.0)
		r.start_grid_offset = clampf(raw_lat, -max_lateral_offset, max_lateral_offset)

		r.start_world_pos = spawn_pos
		r.start_angle = scene_start_ang
		r.current_world_pos = spawn_pos
		r.current_angle = scene_start_ang
		r.side_dodge_offset = r.initial_lateral_offset
		r.desired_lane_offset = r.initial_lateral_offset
		r.overtake_side = 1.0 if (i % 2 == 0) else -1.0
		r.pace_offset = randf_range(-0.06, -0.01)

		pf.progress_ratio = initial_ratio
		pf.global_position = r.current_world_pos
		pf.global_rotation = r.current_angle

		if r.is_player:
			r.max_speed = p_speed
			r.accel = p_accel
			r.handling = p_handling
			r.braking = p_braking
			r.aggression = 1.0
			_apply_car_visual(r, car_idx)
		else:
			var mult: float = BOT_STAT_MULTIPLIERS[bot_idx % BOT_STAT_MULTIPLIERS.size()]
			var aggr: float = BOT_AGGRESSIONS[bot_idx % BOT_AGGRESSIONS.size()]
			r.max_speed = p_speed * mult
			r.accel = p_accel * lerpf(0.76, 0.94, clampf((mult - 0.72) / 0.25, 0.0, 1.0))
			r.handling = maxf(2.5, p_handling * lerpf(0.88, 1.02, clampf((mult - 0.72) / 0.25, 0.0, 1.0)))
			r.braking = p_braking * mult
			r.aggression = aggr
			_apply_car_visual(r, bot_idx)
			bot_idx += 1

		r.left_trail = _create_wheel_trail(r.is_player, "Left")
		r.right_trail = _create_wheel_trail(r.is_player, "Right")
		_seed_initial_trails(r)
		racers.append(r)

func _find_visual_in_follow(pf: PathFollow2D) -> CanvasItem:
	for child in pf.get_children():
		if child is Sprite2D or child is TextureRect:
			return child as CanvasItem
		for sub in child.get_children():
			if sub is Sprite2D or sub is TextureRect:
				return sub as CanvasItem
	return null

func _apply_car_visual(r: RacerData, car_idx: int) -> void:
	if r.visual_node == null or CAR_TEXTURES.is_empty():
		return
	var safe_idx: int = posmod(car_idx, CAR_TEXTURES.size())
	var tex: Texture2D = load(CAR_TEXTURES[safe_idx])
	if tex == null:
		return

	if r.visual_node is Sprite2D:
		var sp: Sprite2D = r.visual_node as Sprite2D
		sp.texture = tex
		var tex_w: float = float(tex.get_width()) * absf(sp.scale.x)
		if tex_w > 1.0:
			r.car_width = tex_w
	elif r.visual_node is TextureRect:
		var ctrl: TextureRect = r.visual_node as TextureRect
		ctrl.texture = tex
		_center_visual_on_follow(ctrl)
		var rect_w: float = ctrl.size.x * absf(ctrl.scale.x)
		if rect_w > 1.0:
			r.car_width = rect_w

func _create_wheel_trail(is_player: bool, side_label: String) -> Line2D:
	var line := Line2D.new()
	line.name = ("Player" if is_player else "Bot") + side_label + "Trail"
	line.top_level = true
	line.z_index = 2
	line.width = 3.0 if is_player else 2.5
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND

	var grad := Gradient.new()
	if is_player:
		grad.set_color(0, Color(0.05, 0.45, 1.0, 0.0))
		grad.set_color(1, Color(0.15, 0.80, 1.0, 0.95))
	else:
		grad.set_color(0, Color(0.90, 0.08, 0.08, 0.0))
		grad.set_color(1, Color(1.0, 0.22, 0.22, 0.90))
	line.gradient = grad

	add_child(line)
	return line

func _get_wheel_world_positions(r: RacerData) -> Dictionary:
	var heading: float = r.current_angle + r.slip_angle
	var forward_vec: Vector2 = Vector2.from_angle(heading)
	var right_vec: Vector2 = Vector2(-forward_vec.y, forward_vec.x)
	var rear_center: Vector2 = r.current_world_pos - forward_vec * rear_axle_offset
	return {
		"left": rear_center - right_vec * wheel_track_offset,
		"right": rear_center + right_vec * wheel_track_offset
	}

func _seed_initial_trails(r: RacerData) -> void:
	var wpos: Dictionary = _get_wheel_world_positions(r)
	r.left_points = [wpos["left"]]
	r.right_points = [wpos["right"]]
	r.left_trail.points = PackedVector2Array(r.left_points)
	r.right_trail.points = PackedVector2Array(r.right_points)

func _append_wheel_point(pts: Array[Vector2], new_pt: Vector2, target_len: float) -> Array[Vector2]:
	var out: Array[Vector2] = pts.duplicate()
	if out.is_empty():
		out.append(new_pt)
	elif out.back().distance_to(new_pt) > 1.5:
		if out.back().distance_to(new_pt) > 140.0:
			out.clear()
		out.append(new_pt)

	var acc_len: float = 0.0
	var trimmed: Array[Vector2] = []
	for idx in range(out.size() - 1, -1, -1):
		var p: Vector2 = out[idx]
		if trimmed.is_empty():
			trimmed.append(p)
		else:
			var seg: float = trimmed.back().distance_to(p)
			if acc_len + seg <= target_len:
				trimmed.append(p)
				acc_len += seg
			else:
				var rem: float = maxf(target_len - acc_len, 0.0)
				if seg > 0.001:
					trimmed.append(trimmed.back().lerp(p, rem / seg))
				break
	trimmed.reverse()
	return trimmed

func _update_wheel_trails(r: RacerData) -> void:
	if r.left_trail == null or r.right_trail == null:
		return

	var wpos: Dictionary = _get_wheel_world_positions(r)
	var speed_ratio: float = clampf(r.current_speed / maxf(r.max_speed, 1.0), 0.0, 1.2)
	var shaped_ratio: float = pow(clampf(speed_ratio, 0.0, 1.0), 2.2)
	var target_len: float = lerpf(min_trail_length, max_trail_length, shaped_ratio)
	var w: float = lerpf(1.4, 3.6 if r.is_player else 2.9, shaped_ratio)

	r.left_points = _append_wheel_point(r.left_points, wpos["left"], target_len)
	r.right_points = _append_wheel_point(r.right_points, wpos["right"], target_len)

	r.left_trail.points = PackedVector2Array(r.left_points)
	r.right_trail.points = PackedVector2Array(r.right_points)
	r.left_trail.width = w
	r.right_trail.width = w

func _spawn_skid_puff(r: RacerData, is_heavy_brake: bool) -> void:
	if r.skid_cooldown > 0.0:
		return
	r.skid_cooldown = 0.06 if is_heavy_brake else 0.11

	var puff := Polygon2D.new()
	puff.top_level = true
	puff.z_index = 1
	var radius: float = (7.0 if is_heavy_brake else 5.0)
	var pts: PackedVector2Array = []
	for k in range(6):
		var a: float = (TAU / 6.0) * float(k)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	puff.polygon = pts
	puff.color = Color(0.22, 0.22, 0.24, 0.45 if is_heavy_brake else 0.25)

	var forward: Vector2 = Vector2.from_angle(r.current_angle)
	puff.global_position = r.current_world_pos - forward * rear_axle_offset
	add_child(puff)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(puff, "scale", Vector2(1.5, 1.5), 0.25)
	tw.tween_property(puff, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(puff.queue_free)

func _find_area_in_follow(pf: PathFollow2D) -> Area2D:
	for child in pf.get_children():
		if child is Area2D:
			return child as Area2D
		for sub in child.get_children():
			if sub is Area2D:
				return sub as Area2D
	return null

func _process(delta: float) -> void:
	if not race_running or racers.is_empty() or main_path == null or main_path.curve == null:
		return

	var dt: float = minf(delta, 0.05)
	var player: RacerData = _get_player_racer()
	if player != null and not player.finished:
		race_time += dt
		if time_label != null:
			time_label.text = _format_race_time(race_time)
		if Input.is_action_just_pressed("ui_accept"):
			_try_trigger_boost(player)

	var main_len: float = maxf(main_path.curve.get_baked_length(), 1.0)

	_update_boosts_and_slipstream(dt, main_len)
	_update_overtakes(dt, main_len)
	_update_side_dodge(dt, main_len)

	for r in racers:
		if r.skid_cooldown > 0.0:
			r.skid_cooldown = maxf(0.0, r.skid_cooldown - dt)
		_update_racer_movement(r, dt, main_len, player)

	_prevent_overlapping(dt)

	for r in racers:
		r.follow.global_position = r.current_world_pos
		r.follow.global_rotation = r.current_angle
		_update_wheel_trails(r)

	_update_race_positions()
	_update_hud(player)

func _try_trigger_boost(r: RacerData) -> void:
	if r.finished or r.boost_cooldown_timer > 0.0:
		return
	r.boost_timer = boost_duration
	r.boost_cooldown_timer = boost_cooldown

func _update_boosts_and_slipstream(delta: float, main_len: float) -> void:
	for i in range(racers.size()):
		var a: RacerData = racers[i]
		if a.boost_timer > 0.0:
			a.boost_timer = maxf(0.0, a.boost_timer - delta)
		if a.boost_cooldown_timer > 0.0:
			a.boost_cooldown_timer = maxf(0.0, a.boost_cooldown_timer - delta)
		if a.finished:
			continue

		var in_slipstream: bool = false
		for j in range(racers.size()):
			if i == j:
				continue
			var b: RacerData = racers[j]
			var ahead_px: float = fposmod(b.follow.progress_ratio - a.follow.progress_ratio, 1.0) * main_len
			var lateral_diff: float = absf(a.current_world_pos.distance_to(b.current_world_pos) - ahead_px)
			if ahead_px > 22.0 and ahead_px < 140.0 and lateral_diff < 24.0:
				in_slipstream = true
				break

		if not a.is_player:
			if a.overtake_stage == 2 and a.boost_cooldown_timer <= 0.0 and randf() < delta * (0.12 * a.aggression):
				_try_trigger_boost(a)
		else:
			if in_slipstream and a.boost_timer <= 0.0:
				a.boost_timer = maxf(a.boost_timer, 0.06)

func _is_overtake_lane_free(racer_idx: int, ratio: float, side: float, main_len: float) -> bool:
	var row_count: int = 0

	for j in range(racers.size()):
		if j == racer_idx:
			continue
		var other: RacerData = racers[j]
		var signed_gap: float = fposmod(other.follow.progress_ratio - ratio + 0.5, 1.0) - 0.5
		var dist_along: float = absf(signed_gap) * main_len

		if dist_along > 18.0 and dist_along < 34.0 and signf(other.side_dodge_offset) == signf(side) and absf(other.side_dodge_offset) > 9.0:
			return false

		if dist_along > 18.0 and dist_along < 48.0 and other.using_overtake_path and signf(other.overtake_side) == signf(side):
			row_count += 1

	return row_count < max_cars_in_overtake_row

func _get_effective_lane_lock_time() -> float:
	return maxf(start_lane_lock_time, start_hold_time + path_merge_duration)

func _update_overtakes(delta: float, main_len: float) -> void:
	var in_start_phase: bool = race_time < _get_effective_lane_lock_time()
	for i in range(racers.size()):
		var a: RacerData = racers[i]
		a.yielding_to_main = false
		a.slight_push_active = false

		if a.finished or in_start_phase:
			a.using_overtake_path = false
			a.overtake_stage = 0
			continue

		if a.hold_timer > 0.0:
			a.hold_timer = maxf(0.0, a.hold_timer - delta)
		if a.overtake_cooldown > 0.0:
			a.overtake_cooldown = maxf(0.0, a.overtake_cooldown - delta)

		if not a.is_player:
			if a.ai_mistake_timer > 0.0:
				a.ai_mistake_timer = maxf(0.0, a.ai_mistake_timer - delta)
			elif randf() < delta * 0.22:
				a.ai_mistake_timer = randf_range(0.35, 0.75)
				a.ai_mistake_bias = randf_range(-0.07, -0.01)

		var curvature_now: float = _get_curve_curvature(main_path, a.follow.progress_ratio, main_len)
		# Запрещаем начинать обгоны на резких поворотах, чтобы не было рывков
		var can_initiate_overtake: bool = curvature_now < 0.5

		var car_ahead: RacerData = null
		var closest_ahead_px: float = overtake_detect_distance + 1.0
		var already_passed: bool = false

		for j in range(racers.size()):
			if i == j:
				continue
			var b: RacerData = racers[j]
			var ahead_px: float = fposmod(b.follow.progress_ratio - a.follow.progress_ratio, 1.0) * main_len
			var behind_px: float = fposmod(a.follow.progress_ratio - b.follow.progress_ratio, 1.0) * main_len

			if ahead_px > -18.0 and ahead_px < closest_ahead_px:
				closest_ahead_px = ahead_px
				car_ahead = b

			if behind_px > 12.0 and behind_px < overtake_clear_distance:
				already_passed = true

		if already_passed and a.using_overtake_path and a.hold_timer <= 0.0:
			a.using_overtake_path = false
			a.overtake_stage = 0
			a.hold_timer = 0.28
			a.overtake_cooldown = 0.75
			continue

		if car_ahead != null and (can_initiate_overtake or (a.using_overtake_path and curvature_now < 0.34)):
			var allow_attempt: bool = a.is_player or (randf() < a.aggression)
			var primary_side: float = -1.0 if a.side_dodge_offset >= 0.0 else 1.0
			var secondary_side: float = -primary_side

			if not a.using_overtake_path and allow_attempt and a.hold_timer <= 0.0 and a.overtake_cooldown <= 0.0 and can_initiate_overtake:
				if _is_overtake_lane_free(i, a.follow.progress_ratio, primary_side, main_len):
					a.overtake_side = primary_side
					a.using_overtake_path = true
					a.overtake_stage = 1
					a.hold_timer = 0.25
				elif _is_overtake_lane_free(i, a.follow.progress_ratio, secondary_side, main_len):
					a.overtake_side = secondary_side
					a.using_overtake_path = true
					a.overtake_stage = 1
					a.hold_timer = 0.25
				else:
					a.yielding_to_main = true
					a.overtake_cooldown = 0.25

			if a.using_overtake_path:
				var lane_limit: float = maxf(minf(max_lateral_offset, two_lane_width), 1.0)
				var lane_progress: float = clampf(absf(a.side_dodge_offset) / lane_limit, 0.0, 1.0)
				if lane_progress >= 0.35 and a.hold_timer <= 0.0 and curvature_now < 0.5:
					a.overtake_stage = 2
					a.slight_push_active = true
				else:
					a.overtake_stage = 1
					a.slight_push_active = false
		elif a.using_overtake_path and a.hold_timer <= 0.0 and (curvature_now < 0.5 or curvature_now >= 0.75):
			a.using_overtake_path = false
			a.overtake_stage = 0
			a.hold_timer = 0.25
			a.overtake_cooldown = 0.65

func _get_corner_tighten(curvature_now: float) -> float:
	return clampf(1.0 - curvature_now * 0.35, 0.55, 1.0)

func _update_side_dodge(delta: float, main_len: float) -> void:
	if race_time < start_hold_time:
		for i in range(racers.size()):
			var a: RacerData = racers[i]
			if not a.finished:
				a.side_dodge_offset = a.initial_lateral_offset
				a.desired_lane_offset = a.initial_lateral_offset
		return

	var merge_elapsed: float = maxf(0.0, race_time - start_hold_time)
	var merge_t: float = clampf(merge_elapsed / maxf(path_merge_duration, 0.01), 0.0, 1.0)
	var smooth_merge: float = merge_t * merge_t * (3.0 - 2.0 * merge_t)
	var in_overtake_lock: bool = race_time < _get_effective_lane_lock_time()

	var base_lane_limit: float = minf(max_lateral_offset, two_lane_width)

	for i in range(racers.size()):
		var a: RacerData = racers[i]
		if a.finished:
			continue

		var curvature_now: float = _get_curve_curvature(main_path, a.follow.progress_ratio, main_len)
		var corner_tighten: float = _get_corner_tighten(curvature_now)
		var lane_limit: float = base_lane_limit * corner_tighten

		var track_lane_target: float = 0.0
		if not in_overtake_lock and a.using_overtake_path:
			track_lane_target = a.overtake_side * lane_limit

		var clamped_track_target: float = clampf(track_lane_target, -lane_limit, lane_limit)
		var base_target: float = lerpf(a.initial_lateral_offset * corner_tighten, clamped_track_target, smooth_merge)

		a.desired_lane_offset = lerpf(a.desired_lane_offset, base_target, clampf(delta * 0.9, 0.0, 1.0))
		var dodge_rate: float = clampf(a.handling * 3.0, 20.0, 40.0)
		var active_limit: float = lerpf(maxf(lane_limit, absf(a.initial_lateral_offset) * corner_tighten), lane_limit, smooth_merge)
		a.side_dodge_offset = clampf(move_toward(a.side_dodge_offset, a.desired_lane_offset, dodge_rate * delta), -active_limit, active_limit)

func _get_curve_curvature(p: Path2D, ratio: float, curve_len: float) -> float:
	var dist: float = ratio * curve_len
	var ang_now: float = _get_curve_angle(p, ratio, curve_len)
	var look_ratio: float = fposmod((dist + corner_lookahead_px) / curve_len, 1.0)
	var ang_ahead: float = _get_curve_angle(p, look_ratio, curve_len)
	return clampf(absf(angle_difference(ang_now, ang_ahead)) / 0.72, 0.0, 1.35)

func _get_rubberband_multiplier(r: RacerData, player: RacerData) -> float:
	if r.is_player or player == null or player.finished:
		return 1.0
	var p_rel: float = maxf(0.0, player.total_progress_ratio - player.start_ratio)
	var r_rel: float = maxf(0.0, r.total_progress_ratio - r.start_ratio)
	var gap: float = p_rel - r_rel
	# Не даём ботам резко догонять игрока при отрыве
	if gap > 0.35:
		return 1.0 + clampf((gap - 0.35) * 0.12, 0.0, 0.025)
	elif gap < -0.18:
		return 1.0 - clampf((absf(gap) - 0.18) * 0.22, 0.0, 0.06)
	return 1.0

func _update_racer_movement(r: RacerData, delta: float, main_len: float, player: RacerData) -> void:
	if r.corner_exit_boost_timer > 0.0:
		r.corner_exit_boost_timer = maxf(0.0, r.corner_exit_boost_timer - delta)

	var curvature_now: float = _get_curve_curvature(main_path, r.follow.progress_ratio, main_len)
	var look_ratio: float = fposmod((r.follow.progress_ratio * main_len + corner_lookahead_px) / main_len, 1.0)
	var curvature_ahead: float = _get_curve_curvature(main_path, look_ratio, main_len)
	var raw_curvature: float = maxf(curvature_now, curvature_ahead * 0.90)

	var curve_smooth_rate: float = clampf(3.0 + r.handling * 0.15, 2.8, 4.8)
	r.smooth_curvature = lerpf(r.smooth_curvature, raw_curvature, clampf(delta * curve_smooth_rate, 0.0, 1.0))

	var exiting_corner: bool = r.prev_curvature > 0.14 and curvature_now < r.prev_curvature - 0.015
	if exiting_corner:
		r.corner_exit_boost_timer = 0.45
	r.prev_curvature = curvature_now

	var target_exit_blend: float = 1.0 if (r.corner_exit_boost_timer > 0.0 or r.smooth_curvature > 0.12) else 0.0
	r.corner_exit_blend = lerpf(r.corner_exit_blend, target_exit_blend, clampf(delta * 2.0, 0.0, 1.0))

	var prev_speed: float = r.current_speed

	if r.finished:
		var stop_decel: float = minf(maxf(r.braking * 0.85, 140.0), max_speed_drop_per_sec)
		r.current_speed = move_toward(r.current_speed, 0.0, stop_decel * delta)
	else:
		var grip_factor: float = clampf(1.05 - (r.handling - 4.0) * 0.025, 0.72, 1.12)
		var corner_mult: float = 1.0 - clampf(r.smooth_curvature * max_corner_slowdown * grip_factor, 0.0, max_corner_slowdown)
		var rubber_mult: float = _get_rubberband_multiplier(r, player)

		# Плавный обгон без резкого рывка
		var overtake_mult: float = 1.0
		var overtake_accel_boost: float = 1.0
		if r.overtake_stage == 2 and r.slight_push_active and curvature_now < 0.78:
			overtake_mult = 1.15 if r.is_player else 1.08
			overtake_accel_boost = 1.25
		elif r.yielding_to_main:
			overtake_mult = 0.95

		var boost_mult: float = boost_speed_mult if r.boost_timer > 0.0 else 1.0

		var smooth_exit_curve: float = r.corner_exit_blend * r.corner_exit_blend * (3.0 - 2.0 * r.corner_exit_blend)
		var exit_power: float = smooth_exit_curve * (0.5 if r.corner_exit_boost_timer > 0.0 else 0.25)
		var exit_accel_factor: float = 1.0 + ((0.08 if r.is_player else 0.05) * exit_power if not r.yielding_to_main else 0.0)
		var exit_top_speed_factor: float = 1.0 + ((0.04 if r.is_player else 0.02) * exit_power if not r.yielding_to_main else 0.0)
		var eff_accel: float = r.accel * (boost_accel_mult if r.boost_timer > 0.0 else 1.0) * exit_accel_factor * overtake_accel_boost

		var desired_max: float = r.max_speed * corner_mult * rubber_mult * overtake_mult * boost_mult * exit_top_speed_factor
		if not r.is_player:
			var wave: float = sin(race_time * 0.75 + float(r.follow.get_index()) * 2.1) * 0.03 + r.pace_offset
			var mistake_mult: float = (1.0 + r.ai_mistake_bias) if r.ai_mistake_timer > 0.0 else 1.0
			desired_max *= clampf((1.0 + wave) * mistake_mult, 0.74, 1.02)

		if r.current_speed < desired_max:
			var corner_load: float = r.smooth_curvature * (0.65 if r.corner_exit_boost_timer > 0.0 else 1.0)
			var corner_traction: float = clampf(1.0 - corner_load * 0.30, 0.65, 1.0)
			var smooth_accel: float = eff_accel * corner_traction
			# Ограничиваем темп прироста скорости, чтобы не было резких рывков
			var max_accel_step: float = max_speed_drop_per_sec * 0.72 * delta
			r.current_speed = minf(r.current_speed + minf(smooth_accel * delta, max_accel_step), desired_max)
		elif r.current_speed > desired_max:
			var brake_skill: float = clampf(r.braking / 320.0, 0.65, 1.30)
			var brake_rate: float = minf(r.braking * brake_skill * (0.55 if r.yielding_to_main or r.smooth_curvature > 0.22 else 0.32), max_speed_drop_per_sec)
			r.current_speed = maxf(r.current_speed - brake_rate * delta, desired_max)

		var max_drop: float = max_speed_drop_per_sec * delta
		if r.current_speed < prev_speed - max_drop:
			r.current_speed = prev_speed - max_drop

	if (prev_speed - r.current_speed) / maxf(delta, 0.001) > 75.0 or (curvature_now > 0.35 and r.current_speed > r.max_speed * 0.65):
		_spawn_skid_puff(r, (prev_speed - r.current_speed) / maxf(delta, 0.001) > 120.0)

	var step_dist: float = maxf(r.current_speed * delta, 0.0)
	var merge_elapsed: float = maxf(0.0, race_time - start_hold_time)
	var merge_t: float = clampf(merge_elapsed / maxf(path_merge_duration, 0.01), 0.0, 1.0)
	var smooth_merge: float = merge_t * merge_t * (3.0 - 2.0 * merge_t)

	var new_ratio: float = r.follow.progress_ratio
	if race_time < start_hold_time or merge_t < 1.0:
		r.current_world_pos += Vector2.from_angle(r.current_angle) * step_dist
		var near_offset: float = main_path.curve.get_closest_offset(main_path.to_local(r.current_world_pos))
		new_ratio = fposmod(near_offset / main_len, 1.0)
	else:
		var delta_ratio: float = step_dist / main_len
		new_ratio = fposmod(r.follow.progress_ratio + delta_ratio, 1.0)

	var diff: float = new_ratio - r.prev_ratio
	if diff < -0.5:
		diff += 1.0
	elif diff > 0.5:
		diff -= 1.0

	if diff > 0.0:
		r.lap_progress_accum += diff
		if not r.finished:
			r.total_progress_ratio = minf(r.total_progress_ratio + diff, r.start_ratio + float(total_laps))

	r.prev_ratio = new_ratio
	r.follow.progress_ratio = new_ratio

	var corner_blend_cap: float = clampf(1.0 - curvature_now * 0.65, 0.15, 0.45)
	var target_blend: float = corner_blend_cap if r.using_overtake_path else 0.0
	r.lane_blend = move_toward(r.lane_blend, target_blend, 1.4 * delta)

	var pos_main: Vector2 = main_path.to_global(main_path.curve.sample_baked(new_ratio * main_len, true))
	var ang_main: float = _get_curve_angle(main_path, new_ratio, main_len)
	var base_pos: Vector2 = pos_main
	var base_ang: float = ang_main

	if overtake_path != null and overtake_path != main_path and overtake_path.curve != null:
		var ov_len: float = maxf(overtake_path.curve.get_baked_length(), 1.0)
		var pos_ov: Vector2 = overtake_path.to_global(overtake_path.curve.sample_baked(new_ratio * ov_len, true))
		var ang_ov: float = _get_curve_angle(overtake_path, new_ratio, ov_len)
		base_pos = pos_main.lerp(pos_ov, r.lane_blend * 0.40)
		base_ang = lerp_angle(ang_main, ang_ov, r.lane_blend * 0.40)

	var normal: Vector2 = Vector2(-sin(base_ang), cos(base_ang))
	var corner_tighten: float = _get_corner_tighten(curvature_now)
	var lane_limit: float = minf(max_lateral_offset, two_lane_width) * corner_tighten
	var max_allowed_offset: float = lerpf(maxf(lane_limit, absf(r.initial_lateral_offset) * corner_tighten), lane_limit, smooth_merge)
	var clamped_dodge: float = clampf(r.side_dodge_offset, -max_allowed_offset, max_allowed_offset)
	var road_target_pos: Vector2 = base_pos + normal * clamped_dodge

	if race_time < start_hold_time:
		r.current_angle = r.start_angle
	elif merge_t < 1.0:
		var pull_weight: float = smooth_merge * clampf(delta * 4.5, 0.0, 1.0)
		r.current_world_pos = r.current_world_pos.lerp(road_target_pos, pull_weight)

		var desired_merge_ang: float = lerp_angle(r.start_angle, base_ang, smooth_merge)
		r.current_angle = lerp_angle(r.current_angle, desired_merge_ang, clampf(delta * 6.0, 0.0, 1.0))
	else:
		var track_pull: float = clampf(delta * (13.0 if curvature_now > 0.35 else 11.0), 0.0, 1.0)
		r.current_world_pos = r.current_world_pos.lerp(road_target_pos, track_pull)
		r.current_angle = lerp_angle(r.current_angle, base_ang, clampf(delta * 10.0, 0.0, 1.0))

	var drift_factor: float = clampf(1.25 - (r.handling - 4.0) * 0.04, 0.65, 1.35)
	var speed_factor: float = clampf(r.current_speed / maxf(r.max_speed, 1.0), 0.15, 1.0)
	var target_slip: float = clampf((clamped_dodge * 0.003 + curvature_now * 0.06) * drift_factor * speed_factor, -0.12, 0.12)
	var slip_recovery: float = clampf(r.handling * 1.8, 5.0, 16.0)
	r.slip_angle = move_toward(r.slip_angle, target_slip, slip_recovery * delta)

	if r.visual_node != null:
		r.visual_node.rotation = lerp_angle(r.visual_node.rotation, r.visual_base_rot + r.slip_angle, clampf(delta * 12.0, 0.0, 1.0))

func _get_curve_angle(p: Path2D, ratio: float, curve_len: float) -> float:
	var dist: float = ratio * curve_len
	var p1: Vector2 = p.to_global(p.curve.sample_baked(dist, true))
	var p2: Vector2 = p.to_global(p.curve.sample_baked(fposmod(dist + 5.0, curve_len), true))
	return (p2 - p1).angle()

func _get_active_car_body_radius() -> float:
	if race_time < POST_START_RADIUS_DELAY:
		return car_body_radius
	return POST_START_CAR_BODY_RADIUS

func _prevent_overlapping(delta: float) -> void:
	var active_radius: float = _get_active_car_body_radius()
	var min_dist: float = maxf(active_radius * 2.0, car_separation_distance * 0.45 if race_time >= POST_START_RADIUS_DELAY else car_separation_distance * 0.75)
	var count: int = racers.size()
	var in_hold: bool = race_time < start_hold_time
	var early_start_scale: float = clampf(race_time / maxf(start_hold_time + 0.35, 0.35), 0.50, 1.0)

	for i in range(count):
		var a: RacerData = racers[i]
		for j in range(i + 1, count):
			var b: RacerData = racers[j]

			var delta_pos: Vector2 = b.current_world_pos - a.current_world_pos
			var dist: float = delta_pos.length()

			if dist < min_dist:
				var overlap: float = min_dist - dist
				var push_dir: Vector2 = delta_pos / dist if dist > 0.001 else Vector2.RIGHT.rotated(a.current_angle)

				var sep_vec: Vector2 = push_dir * (overlap * 0.5 * early_start_scale)
				if a.finished and not b.finished:
					b.current_world_pos += sep_vec * 2.0
				elif b.finished and not a.finished:
					a.current_world_pos -= sep_vec * 2.0
				else:
					a.current_world_pos -= sep_vec
					b.current_world_pos += sep_vec

				if not in_hold:
					var lat_nudge: float = minf(2.5, overlap * 0.22) * early_start_scale
					if a.side_dodge_offset <= b.side_dodge_offset:
						a.side_dodge_offset -= lat_nudge
						b.side_dodge_offset += lat_nudge
					else:
						a.side_dodge_offset += lat_nudge
						b.side_dodge_offset -= lat_nudge

				var ahead_wrap: float = fposmod(b.follow.progress_ratio - a.follow.progress_ratio + 0.5, 1.0) - 0.5
				var brake_amt: float = minf(65.0 * delta, overlap * 0.8) * early_start_scale
				if ahead_wrap > 0.0 and not a.finished and not a.using_overtake_path and a.current_speed > b.current_speed * 0.98:
					a.current_speed = maxf(0.0, minf(a.current_speed - brake_amt, b.current_speed * 0.99))
				elif ahead_wrap < 0.0 and not b.finished and not b.using_overtake_path and b.current_speed > a.current_speed * 0.98:
					b.current_speed = maxf(0.0, minf(b.current_speed - brake_amt, a.current_speed * 0.99))

func _update_race_positions() -> void:
	var sorted: Array[RacerData] = racers.duplicate()
	sorted.sort_custom(func(x: RacerData, y: RacerData) -> bool:
		if x.finished and y.finished:
			return x.finish_order < y.finish_order
		if x.finished != y.finished:
			return x.finished
		var x_rel: float = maxf(0.0, x.total_progress_ratio - x.start_ratio)
		var y_rel: float = maxf(0.0, y.total_progress_ratio - y.start_ratio)
		return x_rel > y_rel
	)
	for idx in range(sorted.size()):
		sorted[idx].race_rank = idx + 1

func _on_finish_area_entered(area: Area2D) -> void:
	var r: RacerData = _find_racer_by_area(area)
	if r != null:
		_handle_lap_crossing(r)

func _on_finish_body_entered(body: Node2D) -> void:
	for r in racers:
		if r.follow == body or r.follow.is_ancestor_of(body):
			_handle_lap_crossing(r)
			return

func _find_racer_by_area(area: Area2D) -> RacerData:
	for r in racers:
		if r.area == area or (r.area != null and r.area.is_ancestor_of(area)):
			return r
	return null

func _handle_lap_crossing(r: RacerData) -> void:
	if r.finished or r.lap_progress_accum < 0.55:
		return
	r.lap_progress_accum = 0.0

	if r.lap < total_laps:
		r.lap += 1
		if r.is_player and lap_label != null:
			lap_label.text = "LAP %d / %d" % [r.lap, total_laps]
	else:
		r.finished = true
		r.total_progress_ratio = r.start_ratio + float(total_laps)
		finish_counter += 1
		r.finish_order = finish_counter
		if r.is_player:
			if lap_label != null:
				lap_label.text = "FINISH!"
			if distance_bar != null:
				distance_bar.value = 100.0
			_award_player_for_position(r.finish_order)

func _award_player_for_position(pos: int) -> void:
	var rewards: Dictionary = {1: 1500, 2: 900, 3: 600, 4: 350, 5: 200}
	Global.player_gold += int(rewards.get(pos, 150))
	Global.save_user()

func _update_hud(player: RacerData) -> void:
	if player == null:
		return
	var shown_speed: float = player.current_speed * speed_display_scale
	top_speed_reached = maxf(top_speed_reached, shown_speed)

	if current_speed_label != null:
		current_speed_label.text = "SPEED: %d" % roundi(shown_speed)
	if top_speed_label != null:
		top_speed_label.text = "TOP SPEED: %d" % roundi(top_speed_reached)
	if pos_label != null:
		pos_label.text = "POS: %d / %d" % [player.race_rank, racers.size()]
	if not player.finished and distance_bar != null:
		var rel_progress: float = maxf(0.0, player.total_progress_ratio - player.start_ratio)
		var total_race_ratio: float = clampf(rel_progress / float(total_laps), 0.0, 1.0)
		distance_bar.value = maxf(distance_bar.value, total_race_ratio * 100.0)

func _get_player_racer() -> RacerData:
	for r in racers:
		if r.is_player:
			return r
	return racers[0] if not racers.is_empty() else null

func _format_race_time(seconds: float) -> String:
	var minutes: int = int(seconds / 60.0)
	var whole_seconds: int = int(seconds) % 60
	var hundredths: int = int((seconds - floorf(seconds)) * 100.0)
	return "%02d:%02d.%02d" % [minutes, whole_seconds, hundredths]

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/os_menu.tscn")
