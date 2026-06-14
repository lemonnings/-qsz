extends Node
class_name CharacterEffects

# 角色效果工具类 - 提供阴影和碰撞推挤功能

# ============== 推挤冷却管理 ==============
# 存储每个敌人的上次推挤时间
static var _separation_cooldowns: Dictionary = {}
static var _shadow_texture_cache: Dictionary = {}
const SEPARATION_COOLDOWN: float = 0.25 # 推挤冷却时间（秒）
const PLAYER_PUSH_MAX_STEP: float = 4.0
const PLAYER_DEATH_SCATTER_ANGLE_DEGREES: float = 55.0
const PLAYER_DEATH_SCATTER_META: String = "_player_death_scatter_direction"

# ============== 阴影效果 ==============

## 为角色创建脚底阴影
static func create_shadow(parent: Node2D, shadow_width: float = 24.0, shadow_height: float = 8.0, offset_y: float = 12.0) -> Sprite2D:
	var shadow = Sprite2D.new()
	shadow.name = "Shadow"
	shadow.texture = _create_ellipse_shadow_texture(int(shadow_width), int(shadow_height))
	shadow.z_index = -1 # 在角色下方
	shadow.position = Vector2(0, offset_y) # 脚底位置
	shadow.modulate = Color(0, 0, 0, 0.35) # 半透明黑色
	parent.add_child(shadow)
	return shadow

## 创建椭圆形阴影纹理
static func _create_ellipse_shadow_texture(width: int, height: int) -> ImageTexture:
	var cache_key := "%d:%d" % [width, height]
	if _shadow_texture_cache.has(cache_key):
		return _shadow_texture_cache[cache_key]
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var center_x = width / 2.0
	var center_y = height / 2.0
	var radius_x = width / 2.0 - 1
	var radius_y = height / 2.0 - 1
	
	# 绘制椭圆形阴影（带边缘羽化）
	for x in range(width):
		for y in range(height):
			var dx = (x - center_x) / radius_x
			var dy = (y - center_y) / radius_y
			var dist = sqrt(dx * dx + dy * dy)
			
			if dist <= 1.0:
				# 从中心到边缘渐变透明度
				var alpha = 1.0 - dist * dist # 二次衰减，边缘更柔和
				image.set_pixel(x, y, Color(0, 0, 0, alpha))
	
	var texture := ImageTexture.create_from_image(image)
	_shadow_texture_cache[cache_key] = texture
	return texture

# ============== 碰撞推挤效果 ==============

## 处理敌人之间的推挤（用于防止重叠）
## 返回需要应用的位移向量
static func calculate_enemy_separation(current_enemy: Area2D, min_distance: float = 15.0) -> Vector2:
	var separation = Vector2.ZERO
	if not current_enemy.monitoring:
		return separation
	var overlapping = current_enemy.get_overlapping_areas()
	
	for other in overlapping:
		if other.is_in_group("enemies") and other != current_enemy:
			var distance = current_enemy.global_position.distance_to(other.global_position)
			if distance < min_distance and distance > 0.1:
				var direction_away = (current_enemy.global_position - other.global_position).normalized()
				var overlap = min_distance - distance
				separation += direction_away * (overlap * 0.5)
	
	return separation

## 处理敌人与玩家的推挤
## 返回需要应用的位移向量
static func calculate_player_push(enemy: Node2D, min_distance: float = 18.0) -> Vector2:
	if not PC.player_instance:
		return Vector2.ZERO
	
	var player_pos = PC.player_instance.global_position
	var distance = enemy.global_position.distance_to(player_pos)
	
	if distance < min_distance:
		var direction_away = _get_stable_push_direction(enemy, player_pos, distance)
		var overlap = min_distance - distance
		return direction_away * min(overlap * 0.45, PLAYER_PUSH_MAX_STEP)
	
	return Vector2.ZERO

## 综合处理推挤效果（敌人之间 + 与玩家）
static func apply_separation(enemy: Area2D, enemy_min_dist: float = 15.0, player_min_dist: float = 18.0, ignore_fly: bool = true) -> void:
	# 如果是飞行单位，可能需要跳过
	if ignore_fly and enemy.is_in_group("fly"):
		return
	
	# 检查监测状态，如果未启用则直接返回
	if not enemy.monitoring:
		return
	
	var enemy_id = enemy.get_instance_id()
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# 清理无效的引用（每次调用时随机清理，避免内存泄漏）
	if randf() < 0.01: # 1%的概率清理
		_cleanup_invalid_cooldowns()
	
	var separation = Vector2.ZERO
	
	# 敌人之间的推挤仍然走冷却，避免高怪物数量时每帧碰撞查询。
	var can_check_enemy_separation := true
	if _separation_cooldowns.has(enemy_id):
		can_check_enemy_separation = current_time - _separation_cooldowns[enemy_id] >= SEPARATION_COOLDOWN
	if can_check_enemy_separation:
		_separation_cooldowns[enemy_id] = current_time
		var overlapping = enemy.get_overlapping_areas()
		for other in overlapping:
			if other.is_in_group("enemies") and other != enemy:
				# 飞行单位不参与地面单位的推挤
				if ignore_fly and other.is_in_group("fly"):
					continue
				var distance = enemy.global_position.distance_to(other.global_position)
				if distance < enemy_min_dist and distance > 0.1:
					var direction_away = (enemy.global_position - other.global_position).normalized()
					var overlap = enemy_min_dist - distance
					separation += direction_away * (overlap * 0.5)
	
	# 与玩家的推挤只做一次直接距离判断，不走冷却。
	# 延迟到帧末追加位移，避免被同一帧后续的“追向玩家”移动抵消。
	var player_push := calculate_player_push(enemy, player_min_dist)
	if player_push != Vector2.ZERO:
		enemy.call_deferred("translate", player_push)
	
	# 应用位移并记录冷却
	if separation != Vector2.ZERO:
		enemy.position += separation

static func _get_stable_push_direction(enemy: Node2D, player_pos: Vector2, distance: float) -> Vector2:
	if distance > 0.1:
		var direction := (enemy.global_position - player_pos).normalized()
		enemy.set_meta("_last_player_push_dir", direction)
		return direction
	if enemy.has_meta("_last_player_push_dir"):
		var cached_direction: Vector2 = enemy.get_meta("_last_player_push_dir")
		if cached_direction != Vector2.ZERO:
			return cached_direction.normalized()
	var fallback_angle := deg_to_rad(float(enemy.get_instance_id() % 360))
	var fallback_direction := Vector2.RIGHT.rotated(fallback_angle)
	enemy.set_meta("_last_player_push_dir", fallback_direction)
	return fallback_direction

static func get_tracking_direction_to_player(enemy: Node2D, stop_distance: float = 12.0) -> Vector2:
	if is_player_dead_or_game_over():
		return get_player_death_scatter_direction(enemy)
	if not PC.player_instance:
		return Vector2.ZERO
	var offset: Vector2 = PC.player_instance.global_position - enemy.global_position
	if offset.length() <= stop_distance:
		return Vector2.ZERO
	return offset.normalized()

static func is_player_dead_or_game_over() -> bool:
	return PC.pc_hp <= 0

static func get_player_death_scatter_direction(enemy: Node2D) -> Vector2:
	if enemy.has_meta(PLAYER_DEATH_SCATTER_META):
		var cached_direction: Vector2 = enemy.get_meta(PLAYER_DEATH_SCATTER_META)
		if cached_direction != Vector2.ZERO:
			return cached_direction.normalized()
	var away_direction := Vector2.ZERO
	if PC.player_instance and is_instance_valid(PC.player_instance):
		away_direction = enemy.global_position - PC.player_instance.global_position
	if away_direction.length_squared() <= 0.01:
		var fallback_angle := randf() * TAU
		away_direction = Vector2.RIGHT.rotated(fallback_angle)
	else:
		away_direction = away_direction.normalized()
	var scatter_offset := deg_to_rad(randf_range(-PLAYER_DEATH_SCATTER_ANGLE_DEGREES, PLAYER_DEATH_SCATTER_ANGLE_DEGREES))
	var scatter_direction := away_direction.rotated(scatter_offset).normalized()
	enemy.set_meta(PLAYER_DEATH_SCATTER_META, scatter_direction)
	return scatter_direction

## 清理无效的冷却记录
static func _cleanup_invalid_cooldowns() -> void:
	var keys_to_remove = []
	for key in _separation_cooldowns.keys():
		if not is_instance_id_valid(key):
			keys_to_remove.append(key)
	for key in keys_to_remove:
		_separation_cooldowns.erase(key)
