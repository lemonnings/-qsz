extends Node
class_name CharacterEffects

# 角色效果工具类 - 提供阴影和碰撞推挤功能

# ============== 推挤冷却管理 ==============
# 存储每个敌人的上次推挤时间
static var _separation_cooldowns: Dictionary = {}
const SEPARATION_COOLDOWN: float = 0.5 # 推挤冷却时间（秒）

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
	
	return ImageTexture.create_from_image(image)

# ============== 碰撞推挤效果 ==============

## 处理敌人之间的推挤（用于防止重叠）
## 返回需要应用的位移向量
static func calculate_enemy_separation(current_enemy: Area2D, min_distance: float = 15.0) -> Vector2:
	var separation = Vector2.ZERO
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
	
	if distance < min_distance and distance > 0.1:
		var direction_away = (enemy.global_position - player_pos).normalized()
		var overlap = min_distance - distance
		return direction_away * (overlap * 0.6) # 被玩家推开的力度稍大
	
	return Vector2.ZERO

## 综合处理推挤效果（敌人之间 + 与玩家）
static func apply_separation(enemy: Area2D, enemy_min_dist: float = 15.0, player_min_dist: float = 18.0, ignore_fly: bool = true) -> void:
	# 如果是飞行单位，可能需要跳过
	if ignore_fly and enemy.is_in_group("fly"):
		return
	
	# 检查冷却
	var enemy_id = enemy.get_instance_id()
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# 清理无效的引用（每次调用时随机清理，避免内存泄漏）
	if randf() < 0.01: # 1%的概率清理
		_cleanup_invalid_cooldowns()
	
	if _separation_cooldowns.has(enemy_id):
		if current_time - _separation_cooldowns[enemy_id] < SEPARATION_COOLDOWN:
			return # 还在冷却中
	
	var separation = Vector2.ZERO
	var has_separation = false
	
	# 敌人之间的推挤
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
				has_separation = true
	
	# 与玩家的推挤
	if PC.player_instance:
		var player_pos = PC.player_instance.global_position
		var distance = enemy.global_position.distance_to(player_pos)
		if distance < player_min_dist and distance > 0.1:
			var direction_away = (enemy.global_position - player_pos).normalized()
			var overlap = player_min_dist - distance
			separation += direction_away * (overlap * 0.6)
			has_separation = true
	
	# 应用位移并记录冷却
	if separation != Vector2.ZERO:
		enemy.position += separation
		if has_separation:
			_separation_cooldowns[enemy_id] = current_time

## 清理无效的冷却记录
static func _cleanup_invalid_cooldowns() -> void:
	var keys_to_remove = []
	for key in _separation_cooldowns.keys():
		if not is_instance_id_valid(key):
			keys_to_remove.append(key)
	for key in keys_to_remove:
		_separation_cooldowns.erase(key)
