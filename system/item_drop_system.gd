extends Node

const DroppedItemScene = preload("res://Scenes/global/drop_normal.tscn") # 请替换为实际路径
const DROP_DISTANCE_MIN := 20.0
const DROP_DISTANCE_MAX := 50.0
const DROP_MULTI_INITIAL_OFFSET_MIN := 4.0
const DROP_MULTI_INITIAL_OFFSET_MAX := 12.0

var victory_attracting: bool = false
var victory_player: Node2D
var victory_speed: float = 100.0
var _victory_collect_request_id: int = 0
var _pending_drop_entries: Array = []
var _pending_drop_flush_queued: bool = false

func _ready():
	# 连接到全局信号
	if Global.has_signal("drop_out_item"):
		Global.drop_out_item.connect(_on_drop_out_item)
	else:
		printerr("Global signal 'drop_out_item' not found!")

func _process(delta: float) -> void:
	if not victory_attracting:
		return
	if not is_instance_valid(victory_player):
		victory_attracting = false
		Global.victory_collecting = false
		return
	var items = get_tree().get_nodes_in_group("drop_item")
	for item in items:
		var distance = item.global_position.distance_to(victory_player.global_position)
		if distance <= 2.0:
			item._on_body_entered(victory_player)
		else:
			var step = victory_speed * delta
			item.global_position = item.global_position.move_toward(victory_player.global_position, step)

func start_victory_collect(player: Node2D, speed: float = 100.0, delay: float = 0.0) -> void:
	_victory_collect_request_id += 1
	var request_id = _victory_collect_request_id
	victory_attracting = false
	Global.victory_collecting = false
	victory_player = player
	victory_speed = speed
	if delay <= 0.0:
		victory_attracting = is_instance_valid(player)
		Global.victory_collecting = victory_attracting
		return
	await get_tree().create_timer(delay).timeout
	if request_id != _victory_collect_request_id:
		return
	if not is_instance_valid(player):
		return
	victory_player = player
	victory_speed = speed
	victory_attracting = true
	Global.victory_collecting = true

func _on_drop_out_item(item_id: String, quantity: int, drop_position: Vector2):
	_pending_drop_entries.append({
		"item_id": item_id,
		"quantity": max(1, quantity),
		"drop_position": drop_position
	})
	if _pending_drop_flush_queued:
		return
	_pending_drop_flush_queued = true
	call_deferred("_flush_pending_drops")

func _flush_pending_drops() -> void:
	_pending_drop_flush_queued = false
	if _pending_drop_entries.is_empty():
		return
	var pending_entries = _pending_drop_entries.duplicate(true)
	_pending_drop_entries.clear()
	var grouped_entries := {}
	for entry in pending_entries:
		var drop_position: Vector2 = entry["drop_position"]
		if not grouped_entries.has(drop_position):
			grouped_entries[drop_position] = []
		grouped_entries[drop_position].append(entry)
	for group_entries in grouped_entries.values():
		_spawn_drop_group(group_entries)

func _spawn_drop_group(group_entries: Array) -> void:
	if group_entries.is_empty():
		return
	var current_scene = get_tree().current_scene
	if not current_scene:
		printerr("Could not find current scene to add dropped item.")
		return
	var drop_position: Vector2 = group_entries[0]["drop_position"]
	var spawn_jobs: Array = []
	for entry in group_entries:
		var item_id: String = entry["item_id"]
		var item_data = ItemManager.get_item_all_data(item_id)
		if not item_data:
			printerr("Failed to drop item: Unknown item_id '", item_id, "'")
			continue
		for i in range(int(entry["quantity"])):
			spawn_jobs.append({
				"item_id": item_id,
				"item_data": item_data
			})
	if spawn_jobs.is_empty():
		return
	var spread_data = _build_drop_spread_data(spawn_jobs.size())
	for i in range(spawn_jobs.size()):
		var spawn_job = spawn_jobs[i]
		var dropped_item_instance = DroppedItemScene.instantiate()
		dropped_item_instance.scale = Vector2(0.2, 0.2)
		dropped_item_instance.add_to_group("drop_item")
		dropped_item_instance.item_id = spawn_job["item_id"]
		var drop_data: Dictionary = spread_data[i]
		dropped_item_instance.global_position = drop_position + drop_data.get("initial_offset", Vector2.ZERO)
		if dropped_item_instance.has_node("Sprite2D"):
			var sprite = dropped_item_instance.get_node("Sprite2D")
			var icon_texture = load(spawn_job["item_data"].item_icon)
			sprite.texture = icon_texture
		if dropped_item_instance.has_node("ItemNameLabel"):
			var name_label = dropped_item_instance.get_node("ItemNameLabel") as Label
			var item_name_color = _get_item_drop_name_color(spawn_job["item_data"])
			name_label.text = spawn_job["item_data"].item_name
			name_label.add_theme_color_override("font_color", item_name_color)
			if name_label.label_settings:
				var label_settings = name_label.label_settings.duplicate() as LabelSettings
				label_settings.font_color = item_name_color
				name_label.label_settings = label_settings
		current_scene.add_child(dropped_item_instance)
		apply_drop_animation(dropped_item_instance, drop_data)

func _get_item_drop_name_color(item_data: Dictionary) -> Color:
	var rare_color = _get_rare_color(str(item_data.get("item_rare", "common")))
	var item_color = item_data.get("item_color", null)
	if item_color is Color:
		return item_color
	if item_color is String and not String(item_color).strip_edges().is_empty():
		return Color.from_string(String(item_color), rare_color)
	return rare_color

func _get_rare_color(rare: String) -> Color:
	match rare.to_lower():
		"common", "1":
			return Color(1.0, 1.0, 1.0)
		"rare", "2":
			return Color(0.2, 0.5, 1.0)
		"epic", "3":
			return Color(0.7, 0.3, 0.9)
		"legend", "legendary", "4":
			return Color(1.0, 0.8, 0.0)
		"artifact", "5":
			return Color(1.0, 0.2, 0.2)
		_:
			return Color(1.0, 1.0, 1.0)


func _build_drop_spread_data(drop_count: int) -> Array:
	if drop_count <= 1:
		return [ {}]
	var spread_data: Array = []
	var base_angle = randf_range(0.0, TAU)
	var angle_step = TAU / float(drop_count)
	for i in range(drop_count):
		var angle_jitter = randf_range(-angle_step * 0.18, angle_step * 0.18)
		var angle = base_angle + angle_step * i + angle_jitter
		var direction = Vector2.RIGHT.rotated(angle)
		var travel_distance = randf_range(DROP_DISTANCE_MIN, DROP_DISTANCE_MAX)
		spread_data.append({
			"initial_offset": direction * randf_range(DROP_MULTI_INITIAL_OFFSET_MIN, DROP_MULTI_INITIAL_OFFSET_MAX),
			"travel_offset": Vector2(direction.x * travel_distance, direction.y * travel_distance * 0.5),
			"arc_height": randf_range(35.0, 80.0)
		})
	return spread_data

func apply_drop_animation(item_node, animation_data: Dictionary = {}):
	# 简单的抛物线效果
	var tween = get_tree().create_tween()
	var travel_offset := Vector2.ZERO
	var arc_height = randf_range(35.0, 80.0)
	if animation_data.is_empty():
		# 单个掉落时保持原有随机方向逻辑
		var random_angle = randf_range(0, TAU) # 全方向随机 (0 ~ 2π)
		var random_distance = randf_range(DROP_DISTANCE_MIN, DROP_DISTANCE_MAX) # 随机掉落距离
		travel_offset = Vector2(cos(random_angle) * random_distance, sin(random_angle) * random_distance * 0.5)
	else:
		travel_offset = animation_data.get("travel_offset", Vector2.ZERO)
		arc_height = float(animation_data.get("arc_height", arc_height))
	var initial_pos = item_node.global_position
	var control_offset = Vector2(travel_offset.x / 2.0, -arc_height) # 控制点，用于形成弧线
	var final_pos = _clamp_position_to_scene_bounds(initial_pos + travel_offset)
	# 使用 quadratic_bezier 插值模拟弧线
	# Godot 4.x Tween 属性插值
	# 主要掉落动画
	tween.tween_method(Callable(self , "_update_item_position_bezier").bind(item_node, initial_pos, initial_pos + control_offset, final_pos), 0.0, 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# 这个方法被 Tween 调用，用于更新物品位置以形成弧线
func _update_item_position_bezier(t: float, node, start_pos: Vector2, control_pos: Vector2, end_pos: Vector2):
	if not is_instance_valid(node):
		return

	var one_minus_t = 1.0 - t
	var x = one_minus_t * one_minus_t * start_pos.x + 2.0 * one_minus_t * t * control_pos.x + t * t * end_pos.x
	var y = one_minus_t * one_minus_t * start_pos.y + 2.0 * one_minus_t * t * control_pos.y + t * t * end_pos.y

	node.global_position = Vector2(x, y)

func _clamp_position_to_scene_bounds(pos: Vector2) -> Vector2:
	var current_scene = get_tree().current_scene
	if not current_scene:
		return pos
	
	# 优先从场景中的 Camera2D 获取边界（每个关卡都已配好 limit）
	var camera = _find_scene_camera()
	if camera:
		pos.x = clamp(pos.x, camera.limit_left + 10, camera.limit_right - 10)
		pos.y = clamp(pos.y, camera.limit_top + 10, camera.limit_bottom - 10)
		return pos
	
	return pos

## 从当前场景中查找 Camera2D（优先找玩家身上的相机）
func _find_scene_camera() -> Camera2D:
	var player_nodes = get_tree().get_nodes_in_group("player")
	for p in player_nodes:
		if is_instance_valid(p):
			var cam = p.find_child("*Camera*", true, false)
			if cam is Camera2D:
				return cam
	# 回退：搜索场景中任意 Camera2D
	var cameras = get_tree().get_nodes_in_group("_cameras")
	if not cameras.is_empty():
		return cameras[0] as Camera2D
	# 最终回退：从当前场景递归查找
	if get_tree() == null or get_tree().current_scene == null:
		return null
	var all_cameras = get_tree().current_scene.find_children("*Camera*", "Camera2D")
	if not all_cameras.is_empty():
		return all_cameras[0] as Camera2D
	return null
