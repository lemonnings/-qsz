extends Area2D

@export var circleAnimate : AnimatedSprite2D
@export var sectorAnimate : AnimatedSprite2D
@export var circleCollision : CollisionShape2D
@export var sectorCollision : CollisionShape2D

# 基础属性
var damage: float = 0.0
var range_val: float = 0.0
var heal_amount: int = 1
var duration: float = 0.75

# 特殊效果标志
var enable_sector: bool = false # Water1: 水波
var apply_slow: bool = false # Water2: 迟滞
var apply_shield: bool = false # Water3: 流水
var shield_hp_threshold: float = 0.3 # Water3: 护盾触发血量阈值
var extra_damage_on_slow: bool = false # Water11: 水波-迟滞
var shield_bonus: float = 1.0 # Water22: 护盾量倍率
var heal_reduction: float = 1.0 # Water22: 治疗量倍率
var conditional_heal_bonus: bool = false # Water33: 击中敌人恢复量提升
var heal_multiplier: float = 1.0

# 内部变量
var hit_targets_circle: Dictionary = {}
var hit_targets_sector: Dictionary = {}
var elapsed: float = 0.0
var player_ref: Node2D = null
var locked_enemy_ref: WeakRef = null
var locked_direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
		
	# 初始状态
	modulate.a = 0.0
	if circleAnimate:
		circleAnimate.visible = true
		circleAnimate.play("default")
	if sectorAnimate:
		sectorAnimate.visible = false # 默认隐藏扇形
		
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
		
	# 在人物下方显示
	z_index = -1

func setup_water(pos: Vector2, p_damage: float, p_range: float, p_heal: int, options: Dictionary = {}) -> void:
	global_position = pos
	damage = p_damage
	range_val = p_range
	heal_amount = p_heal
	player_ref = get_tree().get_first_node_in_group("player")
	
	# 读取特殊选项
	enable_sector = options.get("enable_sector", false)
	apply_slow = options.get("apply_slow", false)
	apply_shield = options.get("apply_shield", false)
	shield_hp_threshold = options.get("shield_hp_threshold", 0.3)
	extra_damage_on_slow = options.get("extra_damage_on_slow", false)
	shield_bonus = options.get("shield_bonus", 1.0)
	heal_reduction = options.get("heal_reduction", 1.0)
	conditional_heal_bonus = options.get("conditional_heal_bonus", false)
	
	_update_visuals_and_collision()
	
	# 立即执行治疗（坎水诀基础效果：恢复体力）
	# 注意：Water22 可能会降低治疗量
	heal_multiplier = 1.0 + PC.heal_multi
	var actual_heal = int(heal_amount * heal_reduction * heal_multiplier)
	if actual_heal < 1:
		actual_heal = 1
	
	# Water3: 如果体力低于阈值，提供护盾
	# Water22: 提供护盾量提升100%
	var shield_value = 0
	if apply_shield:
		var hp_ratio = float(PC.pc_hp) / float(PC.pc_max_hp)
		if hp_ratio < shield_hp_threshold:
			shield_value = int(actual_heal * shield_bonus)
			PC.add_shield(shield_value, 12.0)
	
	# 如果 Water33 生效（击中敌人恢复量提升），则这里的治疗可能需要延迟到击中敌人后处理
	# 但题目描述是“如果击中敌人，恢复量提升至...”，这意味着基础恢复还是有的？
	# 或者说，如果击中敌人，则使用提升后的恢复量，否则使用基础恢复量？
	# 通常这种逻辑是：基础恢复 + 击中额外恢复。
	# 但描述是“恢复量提升至”，暗示是替代。
	# 为了简单起见，我们先进行基础治疗。如果击中了敌人且有 Water33，再补差价。
	# 或者：延迟治疗到 _process 结束或第一次击中敌人？
	# 让我们采取：先治疗基础值。如果触发 Water33 条件，再额外治疗 (目标值 - 基础值)。
	
	if player_ref and not conditional_heal_bonus:
		# 如果没有条件加成，直接治疗
		_perform_heal(actual_heal)
	
	# 如果有条件加成，我们在 _on_area_entered 中处理治疗逻辑，或者标记是否已经治疗过
	# Water33: "如果击中敌人，恢复量提升至..."
	# 我们可以在第一次击中敌人时，执行 (提升后的治疗量 - 已治疗量) 的治疗。
	# 如果直到消失都没击中敌人，那就只享受了基础治疗（如果我们在 setup 里做了）或者没治疗（如果完全延迟）。
	# 题目：“恢复1.5%... Water33: 如果击中敌人，恢复量提升至2.5%...”
	# 这意味着没击中就是1.5%，击中就是2.5%。
	# 所以我们在 setup 里先治疗 1.5%。
	if player_ref and conditional_heal_bonus:
		_perform_heal(actual_heal)

func _process(delta: float) -> void:
	elapsed += delta
	
	# 动画渐入渐出
	# 0.0 - 0.2: 渐入 (0 -> 0.5)
	# 0.2 - 0.55: 保持 (0.5)
	# 0.55 - 0.75: 渐出 (0.5 -> 0)
	
	if elapsed <= 0.15:
		modulate.a = (elapsed / 0.2) * 0.45
	elif elapsed <= 0.45:
		modulate.a = 0.45
	elif elapsed <= 0.6:
		modulate.a = 0.45 * (1.0 - (elapsed - 0.55) / 0.2)
	else:
		queue_free()
		
	# 跟随玩家移动
	if player_ref:
		global_position = player_ref.global_position + Vector2(0, 12)
		
		# 更新扇形朝向以跟随锁定的敌人（如果敌人还活着）
		if enable_sector and locked_enemy_ref and locked_enemy_ref.get_ref():
			var enemy = locked_enemy_ref.get_ref()
			if is_instance_valid(enemy):
				# 实时更新朝向
				locked_direction = (enemy.global_position - global_position).normalized()
				if sectorAnimate:
					sectorAnimate.rotation = locked_direction.angle() + PI / 2
				if sectorCollision:
					sectorCollision.rotation = locked_direction.angle() + PI / 2
					
	# 持续伤害检测（处理扇形旋转或敌人移动进入）
	var overlapping_areas = get_overlapping_areas()
	for area in overlapping_areas:
		if area.is_in_group("enemies"):
			_process_enemy_hit(area)

func _update_visuals_and_collision() -> void:
	# 设置圆形范围
	if circleCollision:
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = range_val
		circleCollision.shape = circle_shape
		
	if circleAnimate:
		var scale_val = range_val / 16.0 
		circleAnimate.scale = Vector2(scale_val, scale_val)
		
	# 设置扇形范围 (Water1)
	if enable_sector:
		if sectorAnimate:
			sectorAnimate.visible = true
			sectorAnimate.play("default")
			# 设置 offset 使其从角色脚下发出
			# 假设素材32x32，半径16，中心在16,16。
			# 我们希望底部(16,32)在角色中心。所以offset y = -16
			sectorAnimate.offset = Vector2(0, -16)
			
			var scale_val = range_val / 16.0
			sectorAnimate.scale = Vector2(scale_val, scale_val)
			
			# 扇形朝向：指向最近的敌人并锁定
			if player_ref:
				var nearest_enemy = player_ref.find_nearest_enemy()
				if nearest_enemy:
					locked_enemy_ref = weakref(nearest_enemy)
					locked_direction = (nearest_enemy.global_position - global_position).normalized()
				else:
					# 没有敌人时，默认朝向玩家前方
					if player_ref.sprite_direction_right:
						locked_direction = Vector2.RIGHT
					else:
						locked_direction = Vector2.LEFT
				
				# 应用初始朝向
				sectorAnimate.rotation = locked_direction.angle() + PI / 2
					
		if sectorCollision:
			# 扇形碰撞体通常比较复杂，这里简化为圆形碰撞体的一部分，或者使用 ConvexPolygonShape2D
			# 但 Area2D 的 shape 是共享的吗？不，是独立的节点。
			# 我们可以简单地启用/禁用 CollisionShape2D 节点
			sectorCollision.disabled = false
			# 假设 sectorCollision 已经配置好了形状（例如 CollisionPolygon2D），这里只需要旋转
			# 使用与视觉相同的锁定方向
			sectorCollision.rotation = locked_direction.angle() + PI / 2
	else:
		if sectorCollision:
			sectorCollision.disabled = true

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		_process_enemy_hit(area)
		
func _process_enemy_hit(area: Area2D) -> void:
	var enemy_id = area.get_instance_id()
	var should_deal_circle = false
	var should_deal_sector = false
	
	# 圆形伤害判定
	if not hit_targets_circle.has(enemy_id):
		hit_targets_circle[enemy_id] = true
		should_deal_circle = true
		
		# Water33: 击中敌人额外治疗
		if conditional_heal_bonus and player_ref:
			# 只在第一次击中时触发额外治疗
			if hit_targets_circle.size() == 1:
				# 计算额外治疗量
				var max_hp = player_ref.maxHP
				var target_heal = max(3, int(float(max_hp) * 0.025 * heal_multiplier))
				var current_base_heal = max(1, int(heal_amount * heal_reduction * heal_multiplier))
				var extra_heal = target_heal - current_base_heal
				if extra_heal > 0:
					_perform_heal(extra_heal)

	# 扇形伤害判定 (Water1)
	if enable_sector and player_ref:
		if not hit_targets_sector.has(enemy_id):
			var dir_to_enemy = (area.global_position - global_position).normalized()
			
			# 获取扇形的朝向（使用实时更新的锁定方向）
			var sector_dir = locked_direction
				
			# 假设扇形是 90 度 (PI/2)，即左右各 45 度
			var angle = sector_dir.angle_to(dir_to_enemy)
			if abs(angle) < PI / 4: # 45度
				hit_targets_sector[enemy_id] = true
				should_deal_sector = true
	
	# 统一执行伤害
	if should_deal_circle or should_deal_sector:
		_deal_damage(area, should_deal_circle, should_deal_sector)

func _deal_damage(enemy: Area2D, deal_circle: bool, deal_sector: bool) -> void:
	var is_crit = false
	if randf() < PC.crit_chance:
		is_crit = true
		
	var total_damage = 0.0
	
	# 圆形伤害
	if deal_circle:
		total_damage += damage
		
	# 扇形伤害 (额外一次)
	if deal_sector:
		var sector_bonus_mult = 1.0
		# Water11: 扇形伤害对已经在减速状态的敌人额外造成75%伤害
		if extra_damage_on_slow:
			if enemy.get("debuff_manager") and enemy.debuff_manager.has_method("has_debuff"):
				if enemy.debuff_manager.has_debuff("slow"):
					sector_bonus_mult = 1.75
		
		total_damage += damage * sector_bonus_mult
	
	# 统一造成伤害，避免因无敌帧导致第二次伤害丢失
	if total_damage > 0:
		var final_damage = total_damage
		if is_crit:
			final_damage *= PC.crit_damage_multi
			
		# Apply final total damage multiplier
		if PC.water_final_damage_multi > 1.0:
			final_damage *= PC.water_final_damage_multi
			
		if enemy.has_method("take_damage"):
			# 这里 source 传 "water" 或 "water_sector" 都可以，或者组合
			var source = "water"
			if deal_sector and not deal_circle:
				source = "water_sector"
			elif deal_sector and deal_circle:
				source = "water_combined"
				
			enemy.take_damage(int(final_damage), is_crit, false, source)
			
		# Water2: 迟滞 - 减速 (只要造成伤害且开启了减速)
		if apply_slow:
			if enemy.get("debuff_manager") and enemy.debuff_manager.has_method("add_debuff"):
				enemy.debuff_manager.add_debuff("slow")

func _perform_heal(amount: int) -> void:
	if PC.is_game_over:
		return
	if amount > 0:
		player_ref.heal(amount)
