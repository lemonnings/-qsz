extends Node

const DroppedItemScene = preload("res://Scenes/global/drop_normal.tscn") # 请替换为实际路径
const HEAL_AURA_ITEM_ID := "item_001"
const MAX_HEAL_AURA_DROP_COUNT := 8
const MAX_TOTAL_DROP_ITEM_COUNT := 200
const DROP_DISTANCE_MIN := 20.0
const DROP_DISTANCE_MAX := 50.0
const DROP_MULTI_INITIAL_OFFSET_MIN := 4.0
const DROP_MULTI_INITIAL_OFFSET_MAX := 12.0
const DROP_ITEMS_PER_FRAME := 8
const LABEL_VISIBLE_DISTANCE := -1.0 # -1 表示掉落物名称不再按距离裁剪
const MAX_VISIBLE_ITEM_LABELS := -1 # -1 表示掉落物名称不再限制显示数量
const LABEL_REFRESH_FRAMES := 8

var victory_attracting: bool = false
var victory_player: Node2D
var victory_speed: float = 100.0
var _victory_collect_request_id: int = 0
var _pending_drop_entries: Array = []
var _pending_drop_flush_queued: bool = false
var _pending_drop_flush_running: bool = false
var _item_icon_cache: Dictionary = {}
var _label_refresh_offset: int = 0
var _visible_label_count: int = 0
# 缓存当前场景的可移动边界（从 Boundry 节点计算）
var _cached_boundary: Dictionary = {}
var _cached_boundary_scene: Node = null

func _ready():
	add_to_group("item_drop_controller")
	stop_victory_collect()
	# 连接到全局信号
	if Global.has_signal("drop_out_item"):
		Global.drop_out_item.connect(_on_drop_out_item)
	else:
		printerr("Global signal 'drop_out_item' not found!")

func _exit_tree() -> void:
	stop_victory_collect()

func stop_victory_collect() -> void:
	_victory_collect_request_id += 1
	victory_attracting = false
	victory_player = null
	Global.victory_collecting = false

func _process(delta: float) -> void:
	_update_item_label_visibility()
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

func get_drop_label_debug_stats() -> Dictionary:
	return {
		"visible": _visible_label_count,
		"max_visible": MAX_VISIBLE_ITEM_LABELS,
		"distance": LABEL_VISIBLE_DISTANCE,
		"victory_attracting": victory_attracting,
	}

func _update_item_label_visibility() -> void:
	var frame := Engine.get_process_frames()
	if frame % LABEL_REFRESH_FRAMES != _label_refresh_offset:
		return
	var items := get_tree().get_nodes_in_group("drop_item")
	_visible_label_count = 0
	for item in items:
		if not is_instance_valid(item) or item.is_queued_for_deletion():
			continue
		if not item.has_method("set_item_name_visible"):
			continue
		var item_id := str(item.get("item_id"))
		var item_data := ItemManager.get_item_all_data(item_id)
		var should_show := _should_show_drop_item_name(item_id, item_data)
		item.set_item_name_visible(should_show)
		if should_show:
			_visible_label_count += 1

func _get_label_player() -> Node2D:
	if PC.player_instance is Node2D and is_instance_valid(PC.player_instance):
		return PC.player_instance
	var players := get_tree().get_nodes_in_group("player")
	for player in players:
		if player is Node2D and is_instance_valid(player):
			return player
	return null

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
	if not _can_accept_drop_item(item_id):
		return
	_pending_drop_entries.append({
		"item_id": item_id,
		"quantity": max(1, quantity),
		"drop_position": drop_position
	})
	if _pending_drop_flush_queued or _pending_drop_flush_running:
		return
	_pending_drop_flush_queued = true
	call_deferred("_flush_pending_drops")

func _flush_pending_drops() -> void:
	if _pending_drop_flush_running:
		return
	_pending_drop_flush_queued = false
	_pending_drop_flush_running = true
	while not _pending_drop_entries.is_empty():
		var pending_entries = _pending_drop_entries.duplicate(true)
		_pending_drop_entries.clear()
		var grouped_entries := {}
		for entry in pending_entries:
			var drop_position: Vector2 = entry["drop_position"]
			if not grouped_entries.has(drop_position):
				grouped_entries[drop_position] = []
			grouped_entries[drop_position].append(entry)
		for group_entries in grouped_entries.values():
			await _spawn_drop_group(group_entries)
	_pending_drop_flush_running = false

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
	spawn_jobs = _apply_drop_item_limits(spawn_jobs)
	if spawn_jobs.is_empty():
		return
	var spread_data = _build_drop_spread_data(spawn_jobs.size())
	var spawned_this_frame := 0
	for i in range(spawn_jobs.size()):
		if not is_instance_valid(current_scene):
			return
		var spawn_job = spawn_jobs[i]
		var dropped_item_instance = DroppedItemScene.instantiate()
		dropped_item_instance.scale = Vector2(0.2, 0.2)
		dropped_item_instance.add_to_group("drop_item")
		var item_id: String = spawn_job["item_id"]
		var item_data: Dictionary = spawn_job["item_data"]
		dropped_item_instance.item_id = item_id
		var drop_data: Dictionary = spread_data[i]
		dropped_item_instance.global_position = drop_position + drop_data.get("initial_offset", Vector2.ZERO)
		if dropped_item_instance.has_node("Sprite2D"):
			var sprite = dropped_item_instance.get_node("Sprite2D")
			var icon_texture = _get_item_icon_texture(str(item_data.get("item_icon", "")))
			sprite.texture = icon_texture
			if _should_dim_drop_item(item_id, item_data):
				sprite.modulate.a = 0.3
			else:
				sprite.modulate.a = 1.0
		if dropped_item_instance.has_node("ItemNameLabel"):
			var name_label = dropped_item_instance.get_node("ItemNameLabel") as Label
			var item_name_color = _get_item_drop_name_color(item_data)
			name_label.text = str(item_data.get("item_name", ""))
			name_label.add_theme_color_override("font_color", item_name_color)
			if name_label.label_settings:
				var label_settings = name_label.label_settings.duplicate() as LabelSettings
				label_settings.font_color = item_name_color
				name_label.label_settings = label_settings
			name_label.visible = _should_show_drop_item_name(item_id, item_data)
		current_scene.add_child(dropped_item_instance)
		apply_drop_animation(dropped_item_instance, drop_data)
		spawned_this_frame += 1
		if spawned_this_frame >= DROP_ITEMS_PER_FRAME and i < spawn_jobs.size() - 1:
			spawned_this_frame = 0
			await get_tree().process_frame

func _can_accept_drop_item(item_id: String) -> bool:
	var counts := _get_live_drop_item_counts()
	if int(counts["total"]) >= MAX_TOTAL_DROP_ITEM_COUNT:
		return false
	if item_id == HEAL_AURA_ITEM_ID and int(counts["heal_aura"]) >= MAX_HEAL_AURA_DROP_COUNT:
		return false
	return true

func _apply_drop_item_limits(spawn_jobs: Array) -> Array:
	var counts := _get_live_drop_item_counts()
	var total_count := int(counts["total"])
	var heal_aura_count := int(counts["heal_aura"])
	var limited_jobs: Array = []
	for spawn_job in spawn_jobs:
		if total_count >= MAX_TOTAL_DROP_ITEM_COUNT:
			break
		var item_id := str(spawn_job.get("item_id", ""))
		if item_id == HEAL_AURA_ITEM_ID and heal_aura_count >= MAX_HEAL_AURA_DROP_COUNT:
			continue
		limited_jobs.append(spawn_job)
		total_count += 1
		if item_id == HEAL_AURA_ITEM_ID:
			heal_aura_count += 1
	return limited_jobs

func _get_live_drop_item_counts() -> Dictionary:
	var counts := {
		"total": 0,
		"heal_aura": 0
	}
	if get_tree() == null:
		return counts
	for item in get_tree().get_nodes_in_group("drop_item"):
		if not is_instance_valid(item) or item.is_queued_for_deletion():
			continue
		counts["total"] += 1
		if str(item.get("item_id")) == HEAL_AURA_ITEM_ID:
			counts["heal_aura"] += 1
	return counts

func _get_item_drop_name_color(item_data: Dictionary) -> Color:
	var rare_color = _get_rare_color(str(item_data.get("item_rare", "common")))
	var item_color = item_data.get("item_color", null)
	if item_color is Color:
		return item_color
	if item_color is String and not String(item_color).strip_edges().is_empty():
		return Color.from_string(String(item_color), rare_color)
	return rare_color

func _should_show_drop_item_name(item_id: String, item_data: Dictionary) -> bool:
	if _is_drop_item_setting_exempt(item_id, item_data):
		return true
	if Global.settings_manager == null:
		return true
	return Global.settings_manager.is_drop_visible_enabled()

func _should_dim_drop_item(item_id: String, item_data: Dictionary) -> bool:
	if _is_drop_item_setting_exempt(item_id, item_data):
		return false
	if Global.settings_manager == null:
		return false
	return Global.settings_manager.is_drop_mater_enabled()

func _is_drop_item_setting_exempt(item_id: String, item_data: Dictionary) -> bool:
	if item_id == HEAL_AURA_ITEM_ID:
		return true
	var rare := str(item_data.get("item_rare", "")).to_lower()
	return rare == "artifact" or rare == "red" or rare == "5"

func _get_item_icon_texture(icon_path: String) -> Texture2D:
	if icon_path.is_empty():
		return null
	if _item_icon_cache.has(icon_path):
		var cached_texture = _item_icon_cache[icon_path]
		if cached_texture is Texture2D:
			return cached_texture
	if not ResourceLoader.exists(icon_path):
		return null
	var texture := load(icon_path) as Texture2D
	if texture:
		_item_icon_cache[icon_path] = texture
	return texture

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

	# 优先从场景中的 Boundry 节点获取实际可移动边界（StaticBody2D 圈定的范围）
	var bounds = _get_scene_boundary(current_scene)
	_apply_scene_drop_limit_overrides(current_scene, bounds)
	if bounds.has("min_x") and bounds.has("max_x") and bounds.has("min_y") and bounds.has("max_y"):
		var top_offset = 10
		if Global.current_stage_id == "cave":
			top_offset = 60  # cave顶部边界下移30像素
		pos.x = clamp(pos.x, bounds["min_x"] + 10, bounds["max_x"] - 10)
		pos.y = clamp(pos.y, bounds["min_y"] + top_offset, bounds["max_y"] - 10)
		return pos

	# 回退：从 Camera2D 获取边界
	var camera = _find_scene_camera()
	if camera:
		pos.x = clamp(pos.x, camera.limit_left + 10, camera.limit_right - 10)
		pos.y = clamp(pos.y, camera.limit_top + 10, camera.limit_bottom - 10)
		return pos

	return pos

func _apply_scene_drop_limit_overrides(current_scene: Node, bounds: Dictionary) -> void:
	if current_scene.has_meta("drop_limit_left"):
		bounds["min_x"] = float(current_scene.get_meta("drop_limit_left"))
	if current_scene.has_meta("drop_limit_right"):
		bounds["max_x"] = float(current_scene.get_meta("drop_limit_right"))
	if current_scene.has_meta("drop_limit_top"):
		bounds["min_y"] = float(current_scene.get_meta("drop_limit_top"))
	if current_scene.has_meta("drop_limit_bottom"):
		bounds["max_y"] = float(current_scene.get_meta("drop_limit_bottom"))

## 获取当前场景的可移动边界（带缓存，场景切换时自动刷新）
func _get_scene_boundary(current_scene: Node) -> Dictionary:
	# 场景切换时清除缓存
	if _cached_boundary_scene != current_scene:
		_cached_boundary = {}
		_cached_boundary_scene = current_scene
	if not _cached_boundary.is_empty():
		return _cached_boundary
	# 从 Boundry 节点计算边界
	var boundary_node = current_scene.find_child("Boundry", true, false)
	if boundary_node:
		_cached_boundary = _compute_boundary_from_static_bodies(boundary_node)
	return _cached_boundary

## 从 Boundry 节点的 StaticBody2D 子节点计算实际可移动区域边界
## StaticBody2D 使用 WorldBoundaryShape2D，根据旋转角度判断墙壁方向：
##   rotation≈0    → 底部墙壁（max_y）
##   rotation≈±π   → 顶部墙壁（min_y）
##   rotation≈-π/2 → 右侧墙壁（max_x）
##   rotation≈+π/2 → 左侧墙壁（min_x）
## 关键：WorldBoundaryShape2D 的 distance 属性定义了沿法线方向的偏移，
## 实际边界位置 = 碰撞形状原点位置 + distance 沿旋转后法线方向的偏移
func _compute_boundary_from_static_bodies(boundary_node: Node2D) -> Dictionary:
	var result: Dictionary = {}
	var margin := 0.15 # 角度容差
	for child in boundary_node.get_children():
		if not child is StaticBody2D:
			continue
		var static_body: StaticBody2D = child
		# 查找 CollisionShape2D 子节点
		var col_shape: CollisionShape2D = null
		for sub in static_body.get_children():
			if sub is CollisionShape2D:
				col_shape = sub
				break
		if col_shape == null:
			continue
		if col_shape.shape == null or not col_shape.shape is WorldBoundaryShape2D:
			continue

		var wb_shape: WorldBoundaryShape2D = col_shape.shape
		var dist: float = wb_shape.distance

		# 将旋转角度归一化到 [-PI, PI]
		var rot = fposmod(static_body.global_rotation, TAU)
		if rot > PI:
			rot -= TAU
		var abs_rot = absf(rot)

		# 旋转后的法线方向（WorldBoundaryShape2D 默认法线为 (0, -1)）
		var normal := Vector2(0.0, -1.0).rotated(rot)
		# 边界线的全局位置 = 碰撞形状原点 + distance 沿法线方向的偏移
		var boundary_pos = col_shape.global_position + normal * dist

		if abs_rot < margin or absf(abs_rot - PI) < margin:
			# 水平墙壁 → 决定 Y 边界
			var y_val = boundary_pos.y
			if abs_rot < margin:
				# 旋转≈0 → 底部墙壁 → max_y
				if not result.has("max_y") or y_val < result["max_y"]:
					result["max_y"] = y_val
			else:
				# 旋转≈±π → 顶部墙壁 → min_y
				if not result.has("min_y") or y_val > result["min_y"]:
					result["min_y"] = y_val
		elif absf(abs_rot - PI / 2.0) < margin:
			# 垂直墙壁 → 决定 X 边界
			var x_val = boundary_pos.x
			if rot < 0:
				# 旋转≈-π/2 → 右侧墙壁 → max_x
				if not result.has("max_x") or x_val < result["max_x"]:
					result["max_x"] = x_val
			else:
				# 旋转≈+π/2 → 左侧墙壁 → min_x
				if not result.has("min_x") or x_val > result["min_x"]:
					result["min_x"] = x_val

	return result

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
