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
	victory_player = player
	victory_speed = speed
	if delay <= 0.0:
		victory_attracting = is_instance_valid(player)
		return
	await get_tree().create_timer(delay).timeout
	if request_id != _victory_collect_request_id:
		return
	if not is_instance_valid(player):
		return
	victory_player = player
	victory_speed = speed
	victory_attracting = true

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
			var name_label = dropped_item_instance.get_node("ItemNameLabel")
			name_label.text = spawn_job["item_data"].item_name
		current_scene.add_child(dropped_item_instance)
		apply_drop_animation(dropped_item_instance, drop_data)

func _build_drop_spread_data(drop_count: int) -> Array:
	if drop_count <= 1:
		return [{}]
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
	tween.tween_method(Callable(self, "_update_item_position_bezier").bind(item_node, initial_pos, initial_pos + control_offset, final_pos), 0.0, 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

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
		
	# 检查是否为 battle_forest 场景
	# 可以通过场景文件名或名称来判断，这里假设包含 battle_forest 字符串
	if "battle_forest" in current_scene.scene_file_path or current_scene.name == "BattleForest":
		var min_x = -275.0
		var max_x = 275.0
		var min_y = 110.0
		var max_y = 310.0
		
		pos.x = clamp(pos.x, min_x, max_x)
		pos.y = clamp(pos.y, min_y, max_y)
		
	return pos
