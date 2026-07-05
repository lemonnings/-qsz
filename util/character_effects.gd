extends Node
class_name CharacterEffects

# 角色效果工具类 - 提供阴影和碰撞推挤功能

# ============== 推挤网格管理 ==============
static var _shadow_texture_cache: Dictionary = {}
static var _separation_debug_stats: Dictionary = {}
static var _separation_grid_frame: int = -1
static var _separation_grid_ignore_fly: bool = false
static var _separation_grid: Dictionary = {}
static var _separation_positions: Dictionary = {}
static var _separation_current_cells: Dictionary = {}
static var _separation_assigned_cells: Dictionary = {}
const SHADOW_Z_INDEX: int = -10
const DEFAULT_COLLISION_LAYER: int = 1
const ENEMY_COLLISION_LAYER: int = 1 << 1
const SEPARATION_GRID_CELL_SIZE: float = 12.0
const SEPARATION_UPDATE_INTERVAL_FRAMES: int = 1
const SEPARATION_MAX_PUSH_NEIGHBORS: int = 8
const SEPARATION_MAX_CANDIDATES_PER_ENEMY: int = 8
const SEPARATION_PAIR_PUSH_RATIO: float = 0.55
const SEPARATION_MAX_PAIR_STEP: float = 1.1
const SEPARATION_TARGET_PULL_RATIO: float = 0.45
const SEPARATION_MAX_TARGET_STEP: float = 2.0
const SEPARATION_MAX_TOTAL_STEP: float = 2.2
const SEPARATION_OCCUPANCY_SEARCH_RADIUS: int = 8
const SEPARATION_FORCE_META: String = "_soft_separation_force"
const SEPARATION_TARGET_CELL_META: String = "_separation_target_cell"
const SEPARATION_FORCE_LERP: float = 0.26
const SEPARATION_FORCE_DECAY: float = 0.6
const SEPARATION_DIRECTION_WEIGHT: float = 0.75
const SEPARATION_BLOCK_GRID_MOVEMENT: bool = false
const ENEMY_FLIP_COOLDOWN_SECONDS: float = 0.5
const ENEMY_FLIP_TIME_META: String = "_last_enemy_flip_change_time"
const PLAYER_PUSH_MAX_STEP: float = 4.0
const CHARGE_SIDE_KNOCKBACK_DISTANCE: float = 18.0
const PLAYER_DEATH_SCATTER_ANGLE_DEGREES: float = 55.0
const PLAYER_DEATH_SCATTER_META: String = "_player_death_scatter_direction"

# ============== 阴影效果 ==============

## 为角色创建脚底阴影
static func create_shadow(parent: Node2D, shadow_width: float = 24.0, shadow_height: float = 8.0, offset_y: float = 12.0) -> Sprite2D:
	var shadow = Sprite2D.new()
	shadow.name = "Shadow"
	shadow.texture = _create_ellipse_shadow_texture(int(shadow_width), int(shadow_height))
	shadow.z_index = SHADOW_Z_INDEX # 只比底层地图图块高一点
	shadow.z_as_relative = false
	shadow.show_behind_parent = true
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

static func configure_enemy_collision(enemy: CollisionObject2D) -> void:
	if enemy == null:
		return
	enemy.collision_layer = ENEMY_COLLISION_LAYER
	enemy.collision_mask = DEFAULT_COLLISION_LAYER
	if enemy is Area2D:
		var area := enemy as Area2D
		area.monitoring = true
		area.monitorable = true

static func include_enemy_collision_mask(area: CollisionObject2D) -> void:
	if area == null:
		return
	area.collision_mask = int(area.collision_mask) | ENEMY_COLLISION_LAYER

static func apply_player_charge_side_knockback(player_body: Node2D, charge_direction: Vector2, source_position: Vector2, distance: float = CHARGE_SIDE_KNOCKBACK_DISTANCE) -> void:
	if player_body == null or not is_instance_valid(player_body) or distance <= 0.0:
		return
	var body := player_body as CharacterBody2D
	if body == null or not body.is_inside_tree():
		return
	var forward := charge_direction.normalized()
	if forward == Vector2.ZERO:
		forward = (body.global_position - source_position).normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.RIGHT
	var side := forward.orthogonal().normalized()
	var source_to_player := body.global_position - source_position
	if source_to_player.dot(side) < 0.0:
		side = -side
	var motion := side * distance
	body.move_and_collide(motion)

static func set_enemy_flip_h(enemy: Node, sprite_node: Node, flip_h: bool, cooldown_seconds: float = ENEMY_FLIP_COOLDOWN_SECONDS) -> bool:
	if sprite_node == null or not is_instance_valid(sprite_node):
		return false
	var current_flip := bool(sprite_node.get("flip_h"))
	if current_flip == flip_h:
		return true
	if enemy != null and is_instance_valid(enemy) and cooldown_seconds > 0.0:
		var now := Time.get_ticks_msec() / 1000.0
		var last_change := float(enemy.get_meta(ENEMY_FLIP_TIME_META, -9999.0))
		if now - last_change < cooldown_seconds:
			return false
		enemy.set_meta(ENEMY_FLIP_TIME_META, now)
	sprite_node.set("flip_h", flip_h)
	return true

static func set_enemy_flip_from_x(enemy: Node, sprite_node: Node, direction_x: float, flip_when_moving_right: bool = true, deadzone: float = 0.01) -> bool:
	if direction_x > deadzone:
		return set_enemy_flip_h(enemy, sprite_node, flip_when_moving_right)
	if direction_x < -deadzone:
		return set_enemy_flip_h(enemy, sprite_node, not flip_when_moving_right)
	return false

static func face_player_x(enemy: Node2D, sprite_node: Node, flip_when_player_right: bool = true, deadzone: float = 0.01) -> bool:
	if enemy == null or not is_instance_valid(enemy) or not PC.player_instance:
		return false
	var player_offset_x: float = PC.player_instance.global_position.x - enemy.global_position.x
	return set_enemy_flip_from_x(enemy, sprite_node, player_offset_x, flip_when_player_right, deadzone)

# ============== 碰撞推挤效果 ==============

## 处理敌人之间的推挤（用于防止重叠）
## 返回需要应用的位移向量
static func calculate_enemy_separation(current_enemy: Area2D, min_distance: float = 15.0) -> Vector2:
	if current_enemy == null or not is_instance_valid(current_enemy):
		return Vector2.ZERO
	if not current_enemy.monitoring:
		return Vector2.ZERO
	var frame := Engine.get_physics_frames()
	_begin_separation_frame(frame)
	_ensure_separation_grid(current_enemy, frame, false)
	return _calculate_grid_separation(current_enemy, min_distance, false, frame)

## 处理敌人与玩家的推挤
## 返回需要应用的位移向量
static func calculate_player_push(enemy: Node2D, min_distance: float = 18.0) -> Vector2:
	if enemy == null or not is_instance_valid(enemy):
		return Vector2.ZERO
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
	if enemy == null or not is_instance_valid(enemy):
		return
	# 如果是飞行单位，可能需要跳过
	if ignore_fly and enemy.is_in_group("fly"):
		return

	# 检查监测状态，如果未启用则直接返回
	if not enemy.monitoring:
		return

	var frame := Engine.get_physics_frames()
	_begin_separation_frame(frame)

	_ensure_separation_grid(enemy, frame, ignore_fly)
	var separation := _calculate_grid_separation(enemy, enemy_min_dist, ignore_fly, frame)
	var player_push := calculate_player_push(enemy, player_min_dist)
	if player_push != Vector2.ZERO:
		separation = _clamp_separation_force(separation + player_push)
	_set_soft_separation_force(enemy, separation)
	var smooth_step := _get_soft_separation_force(enemy)
	if smooth_step != Vector2.ZERO:
		enemy.global_position += smooth_step

static func _ensure_separation_grid(enemy: Area2D, frame: int, ignore_fly: bool) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if _separation_grid_frame == frame and _separation_grid_ignore_fly == ignore_fly:
		return
	_separation_grid_frame = frame
	_separation_grid_ignore_fly = ignore_fly
	_separation_grid.clear()
	_separation_positions.clear()
	_separation_current_cells.clear()
	_separation_assigned_cells.clear()

	var tree := enemy.get_tree()
	if tree == null:
		return
	var enemies := tree.get_nodes_in_group("enemies")
	_separation_debug_stats["enemy_count"] = enemies.size()
	for node in enemies:
		if not node is Area2D:
			continue
		var area := node as Area2D
		if not is_instance_valid(area) or not area.monitoring:
			continue
		if ignore_fly and area.is_in_group("fly"):
			continue
		var enemy_id: int = area.get_instance_id()
		var position := area.global_position
		var cell_key := _get_separation_grid_cell(position)
		var assigned_cell := cell_key
		_separation_positions[enemy_id] = position
		_separation_current_cells[enemy_id] = cell_key
		if _separation_grid.has(cell_key):
			_increment_separation_stat("grid_bucket_drops")
			assigned_cell = _get_or_create_target_cell(area, cell_key)
		else:
			_clear_target_cell_meta(area)
		if assigned_cell != cell_key and position.distance_squared_to(_get_separation_cell_center(assigned_cell)) <= 4.0:
			assigned_cell = cell_key
			_clear_target_cell_meta(area)
		_separation_assigned_cells[enemy_id] = assigned_cell
		_separation_grid[assigned_cell] = area
	_separation_debug_stats["grid_cells"] = _separation_grid.size()

static func _calculate_grid_separation(enemy: Area2D, enemy_min_dist: float, ignore_fly: bool, frame: int) -> Vector2:
	if enemy == null or not is_instance_valid(enemy):
		return Vector2.ZERO
	var enemy_id: int = enemy.get_instance_id()
	var enemy_position: Vector2 = _separation_positions.get(enemy_id, enemy.global_position)
	var current_cell: Vector2i = _separation_current_cells.get(enemy_id, _get_separation_grid_cell(enemy_position))
	var assigned_cell: Vector2i = _separation_assigned_cells.get(enemy_id, current_cell)
	var effective_min_dist := maxf(enemy_min_dist, SEPARATION_GRID_CELL_SIZE)
	var min_dist_sq := effective_min_dist * effective_min_dist
	var separation := Vector2.ZERO
	if assigned_cell != current_cell:
		var target_position := _get_separation_cell_center(assigned_cell)
		var to_target := target_position - enemy_position
		if to_target.length_squared() > 0.01:
			separation += to_target.limit_length(SEPARATION_MAX_TARGET_STEP) * SEPARATION_TARGET_PULL_RATIO
	var pushed_count := 0
	var candidate_count := 0

	for offset_x in range(-1, 2):
		for offset_y in range(-1, 2):
			var cell_key := Vector2i(current_cell.x + offset_x, current_cell.y + offset_y)
			if not _separation_grid.has(cell_key):
				continue
			var occupant = _separation_grid[cell_key]
			if occupant == null or not is_instance_valid(occupant) or not occupant is Area2D:
				_separation_grid.erase(cell_key)
				continue
			if candidate_count >= SEPARATION_MAX_CANDIDATES_PER_ENEMY:
				_add_separation_stat("grid_candidates", candidate_count)
				_add_separation_stat("grid_pairs", pushed_count)
				return _clamp_separation_force(separation)
			var other_area := occupant as Area2D
			if other_area == enemy:
				continue
			if ignore_fly and other_area.is_in_group("fly"):
				continue
			var other_id: int = other_area.get_instance_id()
			var other_position: Vector2 = _separation_positions.get(other_id, other_area.global_position)
			var offset := enemy_position - other_position
			var dist_sq := offset.length_squared()
			candidate_count += 1
			if dist_sq > min_dist_sq:
				continue

			var direction := Vector2.ZERO
			var distance := 0.0
			if dist_sq > 0.01:
				distance = sqrt(dist_sq)
				direction = offset / distance
			else:
				var fallback_angle := deg_to_rad(float(posmod(enemy_id * 97 + other_id * 53, 360)))
				direction = Vector2.RIGHT.rotated(fallback_angle)

			var overlap := effective_min_dist - distance
			if overlap > 0.0:
				separation += direction * minf(overlap * SEPARATION_PAIR_PUSH_RATIO, SEPARATION_MAX_PAIR_STEP)
				pushed_count += 1
				if pushed_count >= SEPARATION_MAX_PUSH_NEIGHBORS:
					_add_separation_stat("grid_candidates", candidate_count)
					_add_separation_stat("grid_pairs", pushed_count)
					return _clamp_separation_force(separation)

	_add_separation_stat("grid_candidates", candidate_count)
	_add_separation_stat("grid_pairs", pushed_count)
	return _clamp_separation_force(separation)

static func _find_open_separation_cell(desired_cell: Vector2i) -> Vector2i:
	if not _separation_grid.has(desired_cell):
		return desired_cell

	for radius in range(1, SEPARATION_OCCUPANCY_SEARCH_RADIUS + 1):
		for dx in range(-radius, radius + 1):
			var top_cell := Vector2i(desired_cell.x + dx, desired_cell.y - radius)
			if not _separation_grid.has(top_cell):
				return top_cell
			var bottom_cell := Vector2i(desired_cell.x + dx, desired_cell.y + radius)
			if not _separation_grid.has(bottom_cell):
				return bottom_cell
		for dy in range(-radius + 1, radius):
			var left_cell := Vector2i(desired_cell.x - radius, desired_cell.y + dy)
			if not _separation_grid.has(left_cell):
				return left_cell
			var right_cell := Vector2i(desired_cell.x + radius, desired_cell.y + dy)
			if not _separation_grid.has(right_cell):
				return right_cell

	_increment_separation_stat("occupancy_overflow")
	return desired_cell

static func _get_or_create_target_cell(enemy: Area2D, desired_cell: Vector2i) -> Vector2i:
	if enemy.has_meta(SEPARATION_TARGET_CELL_META):
		var cached_cell: Vector2i = enemy.get_meta(SEPARATION_TARGET_CELL_META)
		if not _separation_grid.has(cached_cell):
			return cached_cell
	var target_cell := _find_open_separation_cell(desired_cell)
	enemy.set_meta(SEPARATION_TARGET_CELL_META, target_cell)
	return target_cell

static func _clear_target_cell_meta(enemy: Area2D) -> void:
	if enemy.has_meta(SEPARATION_TARGET_CELL_META):
		enemy.remove_meta(SEPARATION_TARGET_CELL_META)

static func _get_separation_grid_cell(point: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(point.x / SEPARATION_GRID_CELL_SIZE)),
		int(floor(point.y / SEPARATION_GRID_CELL_SIZE))
	)

static func _get_separation_cell_center(cell: Vector2i) -> Vector2:
	return Vector2(
		(float(cell.x) + 0.5) * SEPARATION_GRID_CELL_SIZE,
		(float(cell.y) + 0.5) * SEPARATION_GRID_CELL_SIZE
	)

static func _set_soft_separation_force(enemy: Area2D, target_force: Vector2) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var current_force := _get_soft_separation_force(enemy)
	var next_force := current_force.lerp(target_force, SEPARATION_FORCE_LERP)
	if target_force == Vector2.ZERO:
		next_force *= SEPARATION_FORCE_DECAY
	if next_force.length_squared() < 0.0001:
		next_force = Vector2.ZERO
	enemy.set_meta(SEPARATION_FORCE_META, next_force)

static func _get_soft_separation_force(enemy: Node2D) -> Vector2:
	if enemy == null or not is_instance_valid(enemy):
		return Vector2.ZERO
	if not enemy.has_meta(SEPARATION_FORCE_META):
		return Vector2.ZERO
	return enemy.get_meta(SEPARATION_FORCE_META) as Vector2

static func _get_soft_separation_vector(enemy: Node2D) -> Vector2:
	if enemy == null or not is_instance_valid(enemy):
		return Vector2.ZERO
	var force := _get_soft_separation_force(enemy)
	if force.length_squared() <= 0.0001:
		return Vector2.ZERO
	var strength := clampf(force.length() / SEPARATION_MAX_TOTAL_STEP, 0.0, 1.0)
	return force.normalized() * strength

static func _clamp_separation_force(separation: Vector2) -> Vector2:
	var length := separation.length()
	if length <= SEPARATION_MAX_TOTAL_STEP:
		return separation
	return separation / length * SEPARATION_MAX_TOTAL_STEP

static func apply_soft_separation_to_direction(enemy: Node2D, move_direction: Vector2, weight: float = SEPARATION_DIRECTION_WEIGHT) -> Vector2:
	if enemy == null or not is_instance_valid(enemy):
		return move_direction
	var separation_vector := _get_soft_separation_vector(enemy)
	var result := move_direction
	if separation_vector == Vector2.ZERO:
		result = move_direction
	elif move_direction == Vector2.ZERO:
		result = separation_vector.normalized()
	else:
		result = (move_direction.normalized() + separation_vector * weight).normalized()
	if not SEPARATION_BLOCK_GRID_MOVEMENT:
		return result
	return _block_occupied_grid_direction(enemy, result)

static func _block_occupied_grid_direction(enemy: Node2D, move_direction: Vector2) -> Vector2:
	if move_direction.length_squared() <= 0.0001:
		return Vector2.ZERO
	if enemy == null or not is_instance_valid(enemy):
		return move_direction
	if not enemy is Area2D:
		return move_direction
	var area := enemy as Area2D
	if area.is_in_group("fly") or not area.monitoring:
		return move_direction

	var frame := Engine.get_physics_frames()
	_begin_separation_frame(frame)
	_ensure_separation_grid(area, frame, true)

	var enemy_id: int = area.get_instance_id()
	var current_cell: Vector2i = _separation_current_cells.get(enemy_id, _get_separation_grid_cell(area.global_position))
	var step_x := 0
	var step_y := 0
	if move_direction.x > 0.01:
		step_x = 1
	elif move_direction.x < -0.01:
		step_x = -1
	if move_direction.y > 0.01:
		step_y = 1
	elif move_direction.y < -0.01:
		step_y = -1

	var adjusted := move_direction
	var x_blocked := false
	var y_blocked := false
	if step_x != 0:
		x_blocked = _is_separation_cell_blocked(Vector2i(current_cell.x + step_x, current_cell.y), area)
		if x_blocked:
			adjusted.x = 0.0
	if step_y != 0:
		y_blocked = _is_separation_cell_blocked(Vector2i(current_cell.x, current_cell.y + step_y), area)
		if y_blocked:
			adjusted.y = 0.0
	if step_x != 0 and step_y != 0:
		var diagonal_cell := Vector2i(current_cell.x + step_x, current_cell.y + step_y)
		if _is_separation_cell_blocked(diagonal_cell, area):
			if absf(move_direction.x) >= absf(move_direction.y):
				if not x_blocked:
					adjusted.y = 0.0
				elif not y_blocked:
					adjusted.x = 0.0
			else:
				if not y_blocked:
					adjusted.x = 0.0
				elif not x_blocked:
					adjusted.y = 0.0

	if adjusted.length_squared() <= 0.0001:
		var tangent_direction := _get_unblocked_tangent_direction(area, current_cell, step_x, step_y)
		if tangent_direction != Vector2.ZERO:
			_increment_separation_stat("sidestep_moves")
			return tangent_direction
		_increment_separation_stat("blocked_moves")
		return Vector2.ZERO
	if adjusted != move_direction:
		_increment_separation_stat("blocked_moves")
	return adjusted.normalized()

static func _get_unblocked_tangent_direction(enemy: Area2D, current_cell: Vector2i, step_x: int, step_y: int) -> Vector2:
	var enemy_id := enemy.get_instance_id()
	if step_y != 0:
		var first_x := 1 if enemy_id % 2 == 0 else -1
		for side_x in [first_x, -first_x]:
			if not _is_separation_cell_blocked(Vector2i(current_cell.x + side_x, current_cell.y), enemy):
				return Vector2(float(side_x), 0.0)
	if step_x != 0:
		var first_y := 1 if int(enemy_id / 2) % 2 == 0 else -1
		for side_y in [first_y, -first_y]:
			if not _is_separation_cell_blocked(Vector2i(current_cell.x, current_cell.y + side_y), enemy):
				return Vector2(0.0, float(side_y))
	return Vector2.ZERO

static func _is_separation_cell_blocked(cell: Vector2i, enemy: Area2D) -> bool:
	if not _separation_grid.has(cell):
		return false
	var occupant = _separation_grid[cell]
	if occupant == null or not is_instance_valid(occupant) or not occupant is Area2D:
		_separation_grid.erase(cell)
		return false
	return occupant != enemy

static func _begin_separation_frame(frame: int) -> void:
	if int(_separation_debug_stats.get("frame", -1)) == frame:
		return
	_separation_debug_stats = {
		"frame": frame,
		"enemy_count": 0,
		"grid_cells": 0,
		"grid_candidates": 0,
		"grid_pairs": 0,
		"skipped_interval": 0,
	}

static func _increment_separation_stat(key: String) -> void:
	_separation_debug_stats[key] = int(_separation_debug_stats.get(key, 0)) + 1

static func _add_separation_stat(key: String, value: int) -> void:
	_separation_debug_stats[key] = int(_separation_debug_stats.get(key, 0)) + value

static func get_separation_debug_stats() -> Dictionary:
	return _separation_debug_stats.duplicate()

static func _get_stable_push_direction(enemy: Node2D, player_pos: Vector2, distance: float) -> Vector2:
	if enemy == null or not is_instance_valid(enemy):
		return Vector2.ZERO
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
	if enemy == null or not is_instance_valid(enemy):
		return Vector2.ZERO
	if is_player_dead_or_game_over():
		return get_player_death_scatter_direction(enemy)
	if not PC.player_instance:
		return Vector2.ZERO
	var offset: Vector2 = PC.player_instance.global_position - enemy.global_position
	if offset.length() <= stop_distance:
		return apply_soft_separation_to_direction(enemy, Vector2.ZERO)
	return apply_soft_separation_to_direction(enemy, offset.normalized())

static func is_player_dead_or_game_over() -> bool:
	return PC.pc_hp <= 0

static func get_player_death_scatter_direction(enemy: Node2D) -> Vector2:
	if enemy == null or not is_instance_valid(enemy):
		return Vector2.ZERO
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
