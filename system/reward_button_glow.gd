extends Control
class_name RewardButtonGlow

const FPS: float = 10.0
const ORANGE_RUNNER_COLOR: Color = Color(1.0, 0.34, 0.025, 1.0)
const ORANGE_RUNNER_HOT_COLOR: Color = Color(1.0, 0.72, 0.20, 1.0)

var glow_color: Color = Color(1.0, 0.76, 0.14, 1.0)
var hot_color: Color = Color(1.0, 0.96, 0.66, 1.0)
var glow_spread: float = 42.0
var glow_alpha: float = 0.42
var ray_count: int = 12
var _button_size: Vector2 = Vector2.ZERO
var _is_red: bool = false
var _frame_timer: float = 0.0
var _frame_index: int = 0
var _rng := RandomNumberGenerator.new()
var _sparkle_positions: Array[Vector2] = []
var _sparkle_sizes: Array[float] = []
var _sparkle_lifetimes: Array[int] = []


func setup_for_rarity(rarity: String, button_size: Vector2) -> void:
	_button_size = button_size
	_is_red = rarity.to_lower() == "red"
	if _is_red:
		glow_color = Color(1.0, 0.12, 0.025, 1.0)
		hot_color = Color(1.0, 0.82, 0.46, 1.0)
		glow_spread = 58.0
		glow_alpha = 0.56
		ray_count = 16
	else:
		glow_color = Color(1.0, 0.70, 0.08, 1.0)
		hot_color = Color(1.0, 0.96, 0.62, 1.0)
		glow_spread = 42.0
		glow_alpha = 0.42
		ray_count = 12
	position = Vector2.ONE * -glow_spread
	size = button_size + Vector2.ONE * glow_spread * 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 0
	_rng.seed = Time.get_ticks_usec() ^ get_instance_id()
	_initialize_sparkles()
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_frame_timer += delta
	var frame_time := 1.0 / FPS
	if _frame_timer < frame_time:
		return
	_frame_timer = fmod(_frame_timer, frame_time)
	_frame_index = (_frame_index + 1) % 600
	_advance_sparkles()
	queue_redraw()


func _draw() -> void:
	var base_rect := Rect2(Vector2.ONE * glow_spread, _button_size)
	var pulse := 0.84 + float((_frame_index + 1) % 4) * 0.045
	_draw_connected_edge_light(base_rect, pulse)
	_draw_rays(base_rect, pulse)
	_draw_orange_runner_segments(base_rect, pulse)
	_draw_sparkles(base_rect, pulse)


func _draw_connected_edge_light(rect: Rect2, pulse: float) -> void:
	var edge_color := hot_color
	edge_color.a = glow_alpha * 0.58 * pulse
	var soft_color := glow_color
	soft_color.a = glow_alpha * 0.18 * pulse
	draw_rect(rect.grow(3.0), soft_color, false, 5.0)
	draw_rect(rect, edge_color, false, 2.0)


func _draw_rays(rect: Rect2, pulse: float) -> void:
	for i in range(ray_count):
		var edge := i % 4
		var ratio := 0.12 + fmod(float(i) * 0.37, 0.76)
		var tangent := sin(float(i * 7 + 3)) * 0.24
		var origin := Vector2.ZERO
		var direction := Vector2.ZERO
		match edge:
			0:
				origin = rect.position + Vector2(rect.size.x * ratio, -3.0)
				direction = Vector2(tangent, -1.0)
			1:
				origin = rect.position + Vector2(rect.size.x + 3.0, rect.size.y * ratio)
				direction = Vector2(1.0, tangent)
			2:
				origin = rect.position + Vector2(rect.size.x * ratio, rect.size.y + 3.0)
				direction = Vector2(tangent, 1.0)
			_:
				origin = rect.position + Vector2(-3.0, rect.size.y * ratio)
				direction = Vector2(-1.0, tangent)
		var flicker_step := float((i * 3 + _frame_index) % 5) / 4.0
		var length := glow_spread * (0.44 + flicker_step * 0.34)
		var intensity := pulse * (0.72 + float((i + _frame_index) % 3) * 0.11)
		_draw_straight_ray(origin, direction.normalized(), length, intensity)


func _draw_straight_ray(origin: Vector2, direction: Vector2, length: float, intensity: float) -> void:
	var start := origin.round()
	var end := (origin + direction * length).round()
	var outer_color := glow_color
	outer_color.a = glow_alpha * intensity * 0.42
	var core_color := hot_color
	core_color.a = glow_alpha * intensity * 0.78
	draw_line(start, end, outer_color, 5.0 if _is_red else 4.0, false)
	draw_line(start, start.lerp(end, 0.72), core_color, 2.0, false)


func _draw_orange_runner_segments(rect: Rect2, pulse: float) -> void:
	var perimeter := (rect.size.x + rect.size.y) * 2.0
	if perimeter <= 0.0:
		return
	var travel := perimeter * float(_frame_index % 60) / 60.0
	var segment_length := clampf(perimeter * 0.09, 52.0, 100.0)
	var first_start := fmod(rect.size.x * 0.12 + travel, perimeter)
	var second_start := fmod(first_start + perimeter * 0.5, perimeter)
	var soft_color := ORANGE_RUNNER_COLOR
	soft_color.a = 0.48 * pulse
	var hot_runner := ORANGE_RUNNER_HOT_COLOR
	hot_runner.a = 0.96 * pulse
	for start_distance in [first_start, second_start]:
		_draw_perimeter_segment(rect, float(start_distance), segment_length, soft_color, 8.0)
		_draw_perimeter_segment(rect, float(start_distance), segment_length, hot_runner, 3.0)


func _draw_perimeter_segment(rect: Rect2, start_distance: float, segment_length: float, color: Color, width: float) -> void:
	var side_lengths := [rect.size.x, rect.size.y, rect.size.x, rect.size.y]
	var perimeter := (rect.size.x + rect.size.y) * 2.0
	var cursor := fmod(start_distance, perimeter)
	var remaining := segment_length
	while remaining > 0.01:
		var side := 0
		var side_offset := cursor
		while side < 3 and side_offset >= float(side_lengths[side]):
			side_offset -= float(side_lengths[side])
			side += 1
		var available := float(side_lengths[side]) - side_offset
		var piece_length := minf(remaining, available)
		var from := _get_perimeter_point(rect, side, side_offset).round()
		var to := _get_perimeter_point(rect, side, side_offset + piece_length).round()
		draw_line(from, to, color, width, false)
		remaining -= piece_length
		cursor = fmod(cursor + piece_length, perimeter)


func _get_perimeter_point(rect: Rect2, side: int, offset: float) -> Vector2:
	match side:
		0:
			return rect.position + Vector2(offset, 0.0)
		1:
			return rect.position + Vector2(rect.size.x, offset)
		2:
			return rect.position + Vector2(rect.size.x - offset, rect.size.y)
		_:
			return rect.position + Vector2(0.0, rect.size.y - offset)


func _initialize_sparkles() -> void:
	_sparkle_positions.clear()
	_sparkle_sizes.clear()
	_sparkle_lifetimes.clear()
	var sparkle_count := 7 if _is_red else 5
	for i in range(sparkle_count):
		_sparkle_positions.append(Vector2.ZERO)
		_sparkle_sizes.append(0.0)
		_sparkle_lifetimes.append(0)
		_respawn_sparkle(i)
		if i % 2 == 1:
			_sparkle_lifetimes[i] = -_rng.randi_range(1, 6)


func _advance_sparkles() -> void:
	for i in range(_sparkle_lifetimes.size()):
		if _sparkle_lifetimes[i] > 0:
			_sparkle_lifetimes[i] -= 1
			if _sparkle_lifetimes[i] == 0:
				_sparkle_lifetimes[i] = -_rng.randi_range(2, 7)
		else:
			_sparkle_lifetimes[i] += 1
			if _sparkle_lifetimes[i] == 0:
				_respawn_sparkle(i)


func _respawn_sparkle(index: int) -> void:
	var rect := Rect2(Vector2.ONE * glow_spread, _button_size)
	var edge := _rng.randi_range(0, 3)
	var ratio := _rng.randf_range(0.08, 0.92)
	var distance := _rng.randf_range(glow_spread * 0.28, glow_spread * 0.88)
	match edge:
		0:
			_sparkle_positions[index] = rect.position + Vector2(rect.size.x * ratio, -distance)
		1:
			_sparkle_positions[index] = rect.position + Vector2(rect.size.x + distance, rect.size.y * ratio)
		2:
			_sparkle_positions[index] = rect.position + Vector2(rect.size.x * ratio, rect.size.y + distance)
		_:
			_sparkle_positions[index] = rect.position + Vector2(-distance, rect.size.y * ratio)
	_sparkle_sizes[index] = _rng.randf_range(4.0, 9.1)
	_sparkle_lifetimes[index] = _rng.randi_range(5, 13)


func _draw_sparkles(_rect: Rect2, pulse: float) -> void:
	for i in range(_sparkle_positions.size()):
		var lifetime := _sparkle_lifetimes[i]
		if lifetime <= 0:
			continue
		var fade := minf(1.0, float(lifetime) / 3.0)
		var alpha := glow_alpha * pulse * 0.86 * fade
		_draw_pixel_sparkle(_sparkle_positions[i].round(), _sparkle_sizes[i], alpha)


func _draw_pixel_sparkle(center: Vector2, sparkle_size: float, alpha: float) -> void:
	var color := hot_color
	color.a = alpha
	var arm := snappedf(sparkle_size, 2.0)
	draw_rect(Rect2(center - Vector2(1.0, arm), Vector2(2.0, arm * 2.0)), color)
	draw_rect(Rect2(center - Vector2(arm, 1.0), Vector2(arm * 2.0, 2.0)), color)
	draw_rect(Rect2(center - Vector2.ONE, Vector2.ONE * 2.0), Color(1.0, 1.0, 0.9, alpha))
