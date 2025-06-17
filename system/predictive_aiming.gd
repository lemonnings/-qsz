extends Node

# 预测性瞄准相关变量
var enemy_position_history: Dictionary = {}  # 存储敌人位置历史 {enemy_id: [positions...]}
var enemy_velocity_cache: Dictionary = {}  # 缓存敌人速度 {enemy_id: Vector2}
var max_history_frames: int = 5  # 最大历史帧数
var prediction_frames: int = 10  # 预测帧数
var bullet_speed_for_prediction: float = 550.0  # 用于预测的子弹速度

var enemies_in_scene: Array = [] # 场景中的敌人列表
var player_position: Vector2 # 玩家位置，需要从外部传入

func _physics_process(delta: float) -> void:
	# 更新敌人列表
	update_enemies_list()

# 更新敌人列表
func update_enemies_list() -> void:
	# 获取场景中的所有敌人
	enemies_in_scene.clear()
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy and is_instance_valid(enemy):
			# 敌人的Area2D在enemies组中，需要获取父节点（实际的敌人对象）
			var actual_enemy = enemy.get_parent() if enemy.get_parent() else enemy
			if actual_enemy and is_instance_valid(actual_enemy):
				enemies_in_scene.append(actual_enemy)
				# 更新敌人位置历史，使用Area2D节点的位置
				update_enemy_position_history(enemy)
	
	# 清理已失效敌人的历史记录
	cleanup_enemy_history()

# 寻找最近的敌人
func find_nearest_enemy() -> Node2D:
	var nearest_enemy = null
	var nearest_distance = INF
	
	for actual_enemy in enemies_in_scene:
		# 注意：enemies_in_scene中存储的是actual_enemy（父节点）
		# 我们需要找到其对应的Area2D节点（在"enemies"组中的节点）来获取位置
		var enemy_area_node = null
		for node_in_group in get_tree().get_nodes_in_group("enemies"):
			if node_in_group.get_parent() == actual_enemy:
				enemy_area_node = node_in_group
				break
			elif node_in_group == actual_enemy: # 如果父节点就是自己（不太可能，但作为保险）
				enemy_area_node = actual_enemy
				break

		if enemy_area_node and is_instance_valid(enemy_area_node):
			var distance = player_position.distance_to(enemy_area_node.position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_enemy = actual_enemy # 返回的仍然是actual_enemy
	
	return nearest_enemy

# 更新敌人位置历史
func update_enemy_position_history(enemy: Node2D) -> void:
	var enemy_id = enemy.get_instance_id()
	
	# 初始化历史记录
	if not enemy_position_history.has(enemy_id):
		enemy_position_history[enemy_id] = []
	
	# 添加当前位置
	var history = enemy_position_history[enemy_id]
	history.append(enemy.position)
	
	# 限制历史记录长度
	if history.size() > max_history_frames:
		history.pop_front()
	
	# 计算并缓存速度
	if history.size() >= 2:
		var velocity = (history[-1] - history[-2]) / get_physics_process_delta_time()
		enemy_velocity_cache[enemy_id] = velocity

# 清理已失效敌人的历史记录
func cleanup_enemy_history() -> void:
	var valid_enemy_ids = []
	for enemy in enemies_in_scene:
		if enemy and is_instance_valid(enemy):
			valid_enemy_ids.append(enemy.get_instance_id())
	
	# 移除无效敌人的记录
	var keys_to_remove = []
	for enemy_id in enemy_position_history.keys():
		if not enemy_id in valid_enemy_ids:
			keys_to_remove.append(enemy_id)
	
	for key in keys_to_remove:
		enemy_position_history.erase(key)
		enemy_velocity_cache.erase(key)

# 预测敌人未来位置
func predict_enemy_position(enemy: Node2D, time_to_hit: float) -> Vector2:
	var enemy_id = enemy.get_instance_id()
	var history = enemy_position_history.get(enemy_id, [])
	
	# 对于新敌人（历史数据不足），使用基于生成位置的预测
	if history.size() < 3:
		return predict_new_enemy_position(enemy, time_to_hit)
	
	# 如果没有速度缓存，使用基于生成位置的预测
	if not enemy_velocity_cache.has(enemy_id):
		return predict_new_enemy_position(enemy, time_to_hit)
	
	var velocity = enemy_velocity_cache[enemy_id]
	
	# 分析移动模式
	var movement_pattern = analyze_movement_pattern(history)
	
	# 根据移动模式进行预测
	match movement_pattern:
		"linear":
			# 线性移动预测
			return enemy.position + velocity * time_to_hit
		"circular":
			# 圆形移动预测（针对追踪玩家的敌人）
			return predict_circular_movement(enemy, time_to_hit)
		"random":
			# 随机移动，使用短期预测
			return enemy.position + velocity * min(time_to_hit, 0.2)
		_:
			# 默认线性预测
			return enemy.position + velocity * time_to_hit

# 分析敌人移动模式
func analyze_movement_pattern(history: Array) -> String:
	if history.size() < 5:
		return "linear"
	
	# 计算方向变化
	var direction_changes = 0
	var total_angle_change = 0.0
	
	for i in range(2, history.size()):
		var dir1 = (history[i-1] - history[i-2]).normalized()
		var dir2 = (history[i] - history[i-1]).normalized()
		
		if dir1.length() > 0 and dir2.length() > 0:
			var angle_diff = abs(dir1.angle_to(dir2))
			total_angle_change += angle_diff
			
			if angle_diff > 0.5:  # 约30度
				direction_changes += 1
	
	# 判断移动模式
	var avg_angle_change = total_angle_change / max(1, history.size() - 2)
	
	if direction_changes >= 3:
		return "random"
	elif avg_angle_change > 0.3:
		return "circular"
	else:
		return "linear"

# 预测圆形移动（追踪玩家的敌人）
func predict_circular_movement(enemy: Node2D, time_to_hit: float) -> Vector2:
	# 对于追踪玩家的敌人，预测它们会继续朝向玩家移动
	var current_to_player = (player_position - enemy.position).normalized()
	var enemy_speed = enemy_velocity_cache.get(enemy.get_instance_id(), Vector2.ZERO).length()
	
	# 预测敌人会朝玩家方向移动
	return enemy.position + current_to_player * enemy_speed * time_to_hit

# 寻找最佳射击目标（考虑预测命中率）
func find_best_target() -> Node2D:
	var best_target = null
	var best_score = -1.0
	
	for enemy in enemies_in_scene:
		if enemy and is_instance_valid(enemy):
			var score = calculate_target_score(enemy)
			if score > best_score:
				best_score = score
				best_target = enemy
	
	return best_target

# 计算目标评分（距离、预测命中率等）
func calculate_target_score(actual_enemy: Node2D) -> float:
	# 注意：传入的是actual_enemy（父节点）
	# 我们需要找到其对应的Area2D节点来获取位置和进行预测
	var enemy_area_node = null
	for node_in_group in get_tree().get_nodes_in_group("enemies"):
		if node_in_group.get_parent() == actual_enemy:
			enemy_area_node = node_in_group
			break
		elif node_in_group == actual_enemy:
			enemy_area_node = actual_enemy
			break
	
	if not enemy_area_node or not is_instance_valid(enemy_area_node):
		print("[评分计算] 无法找到 " + actual_enemy.name + " 对应的Area2D节点")
		return -1.0 # 无效评分

	var distance = player_position.distance_to(enemy_area_node.position)
	var time_to_hit = distance / bullet_speed_for_prediction
	
	print("[评分计算] 敌人 (", actual_enemy.name, ") Area2D位置: ", enemy_area_node.position, " 玩家位置: ", player_position, " 距离: ", distance)
	
	# 预测位置，传入Area2D节点
	var predicted_pos = predict_enemy_position(enemy_area_node, time_to_hit)
	var predicted_distance = player_position.distance_to(predicted_pos)
	
	print("[评分计算] 预测位置: ", predicted_pos, " 预测距离: ", predicted_distance)
	
	# 计算预测误差（移动越规律，误差越小），使用Area2D节点的ID
	var enemy_id = enemy_area_node.get_instance_id()
	var history = enemy_position_history.get(enemy_id, [])
	var prediction_confidence = calculate_prediction_confidence(history)
	
	# 综合评分：距离越近越好，预测置信度越高越好
	var distance_score = 1.0 / max(distance, 50.0)  # 避免除零
	var confidence_score = prediction_confidence
	
	return distance_score * 0.6 + confidence_score * 0.4

# 预测新敌人位置（历史数据不足时使用）
func predict_new_enemy_position(enemy: Node2D, time_to_hit: float) -> Vector2:
	# 分析敌人的生成位置和可能的移动方向
	var enemy_pos = enemy.position
	var player_pos = player_position
	
	print("[新敌人预测] 敌人位置: ", enemy_pos, " 玩家位置: ", player_pos)
	
	# 检查敌人是否有move_direction属性
	var predicted_velocity = Vector2.ZERO
	
	if enemy.has_method("get") and enemy.get("move_direction") != null:
		var move_direction = enemy.get("move_direction")
		var enemy_speed = 0.0
		
		# 根据敌人类型获取速度
		if enemy.has_method("get") and enemy.get("slime_speed") != null:
			enemy_speed = enemy.get("slime_speed")
		elif enemy.has_method("get") and enemy.get("bat_speed") != null:
			enemy_speed = enemy.get("bat_speed")
		elif enemy.has_method("get") and enemy.get("frog_speed") != null:
			enemy_speed = enemy.get("frog_speed")
		else:
			# 默认速度估算
			enemy_speed = 100.0
		
		# 根据move_direction预测移动方向
		match move_direction:
			0:  # 从左到右
				predicted_velocity = Vector2(enemy_speed, 0)
			1:  # 从右到左
				predicted_velocity = Vector2(-enemy_speed, 0)
			2, 3, 4, 5:  # 从下方向上（追踪玩家）
				# 对于追踪型敌人，使用迭代预测来模拟实时追踪行为
				return predict_tracking_enemy_position(enemy, enemy_speed, time_to_hit)
			_:  # 其他情况，假设追踪玩家
				return predict_tracking_enemy_position(enemy, enemy_speed, time_to_hit)
	else:
		# 没有move_direction属性，假设朝向玩家移动
		var result = predict_tracking_enemy_position(enemy, 100.0, time_to_hit)
		print("[新敌人预测] 无move_direction，返回追踪预测: ", result)
		return result
	
	# 返回预测位置（仅用于非追踪型敌人）
	var result = enemy_pos + predicted_velocity * time_to_hit
	print("[新敌人预测] 非追踪型敌人，返回: ", result)
	return result

# 预测追踪型敌人的位置（使用迭代方法模拟实时追踪）
func predict_tracking_enemy_position(enemy: Node2D, enemy_speed: float, time_to_hit: float) -> Vector2:
	var enemy_pos = enemy.position
	var player_pos = player_position
	
	# 调试信息
	print("[追踪预测] 敌人初始位置: ", enemy_pos, " 玩家位置: ", player_pos, " 敌人速度: ", enemy_speed, " 预测时间: ", time_to_hit)
	
	# 使用多步迭代来模拟敌人的实时追踪行为
	var steps = max(3, int(time_to_hit * 60))  # 根据时间动态调整步数，至少3步
	steps = min(steps, 10)  # 限制最大步数避免性能问题
	var step_time = time_to_hit / steps
	
	var current_enemy_pos = enemy_pos
	
	for i in range(steps):
		# 计算当前步骤中敌人朝向玩家的方向
		var direction_to_player = (player_pos - current_enemy_pos).normalized()
		
		# 移动敌人位置
		current_enemy_pos += direction_to_player * enemy_speed * step_time
		
		# 检查是否已经到达玩家位置附近（避免过度追踪）
		if current_enemy_pos.distance_to(player_pos) < 10.0:
			break
	
	print("[追踪预测] 最终预测位置: ", current_enemy_pos)
	return current_enemy_pos

# 计算预测置信度
func calculate_prediction_confidence(history: Array) -> float:
	if history.size() < 3:
		return 0.6  # 对新敌人给予中等置信度（因为我们有基于生成位置的预测）
	
	# 计算移动的一致性
	var velocity_consistency = 0.0
	var velocities = []
	
	for i in range(1, history.size()):
		var vel = history[i] - history[i-1]
		velocities.append(vel)
	
	if velocities.size() >= 2:
		# 计算速度向量的标准差
		var avg_vel = Vector2.ZERO
		for vel in velocities:
			avg_vel += vel
		avg_vel /= velocities.size()
		
		var variance = 0.0
		for vel in velocities:
			variance += (vel - avg_vel).length_squared()
		variance /= velocities.size()
		
		# 方差越小，一致性越高
		velocity_consistency = 1.0 / (1.0 + variance * 0.01)
	
	return clamp(velocity_consistency, 0.1, 1.0)

# 获取瞄准方向（供玩家脚本调用的主要接口）
func get_aim_direction(player_pos: Vector2, sprite_direction_right: bool, aim_stick_input: Vector2) -> Vector2:
	# 更新玩家位置
	player_position = player_pos
	
	# 调试输出
	print("[预测瞄准] 敌人数量: ", enemies_in_scene.size())
	
	# 寻找最佳目标（完全自动瞄准）
	var target = find_best_target()
	if not target:
		# 没有目标时，使用角色朝向
		print("[预测瞄准] 没有找到目标，使用默认方向")
		return Vector2.RIGHT if sprite_direction_right else Vector2.LEFT
	
	# target 是 actual_enemy (父节点)
	# 我们需要找到其对应的Area2D节点
	var target_area_node = null
	for node_in_group in get_tree().get_nodes_in_group("enemies"):
		if node_in_group.get_parent() == target:
			target_area_node = node_in_group
			break
		elif node_in_group == target:
			target_area_node = target
			break

	if not target_area_node or not is_instance_valid(target_area_node):
		print("[预测瞄准] 无法找到目标 " + target.name + " 对应的Area2D节点，使用默认方向")
		return Vector2.RIGHT if sprite_direction_right else Vector2.LEFT

	# 计算到达目标的时间
	var distance = player_position.distance_to(target_area_node.position)
	var time_to_hit = distance / bullet_speed_for_prediction
	
	# 预测目标位置，传入Area2D节点
	var predicted_position = predict_enemy_position(target_area_node, time_to_hit)
	
	print("[预测瞄准] 目标 (", target.name, ") Area2D位置: ", target_area_node.position, " 预测位置: ", predicted_position)
	
	# 计算瞄准方向
	var aim_direction = (predicted_position - player_position).normalized()
	print("[预测瞄准] 玩家位置: ", player_position, " 计算出的瞄准方向: ", aim_direction)
	
	# 返回瞄准方向
	return aim_direction
