extends Area2D

var damage: float = 0.0
var hit_cooldown: float = 0.3
var hit_cooldowns: Dictionary = {}

func _ready() -> void:
	# 设置碰撞检测
	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 12.0 # 火焰的碰撞范围
	if (PC.selected_rewards.has("RingFire3")):
		circle_shape.radius = 16.2 # +35%
	collision_shape.shape = circle_shape
	add_child(collision_shape)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	# 法则伤害加成累加（不是乘法），避免奖励加成 × 法则加成的双重叠加
	var damage_multiplier = 0.3 * PC.main_skill_ringFire_damage
	damage_multiplier += (Faze.get_fire_weapon_damage_multiplier(PC.faze_fire_level) - 1.0) # 火焰法则
	damage = PC.pc_atk * damage_multiplier
	
	if (PC.selected_rewards.has("RingFire22")):
		damage = damage * 1.25
		
	# 更新冷却时间
	var to_remove = []
	for enemy in hit_cooldowns.keys():
		hit_cooldowns[enemy] -= delta
		if hit_cooldowns[enemy] <= 0:
			to_remove.append(enemy)
	
	for enemy in to_remove:
		hit_cooldowns.erase(enemy)

func _on_area_entered(area: Area2D) -> void:
	# 检查是否是敌人
	if area.is_in_group("enemies"):
		# 检查该火焰实例是否对这个敌人在冷却中
		if not hit_cooldowns.has(area) or hit_cooldowns[area] <= 0:
			# 造成伤害
			if area.has_method("take_damage"):
				var final_damage = damage
				area.take_damage(final_damage, false, false, "")
				
				if PC.selected_rewards.has("RingFire4"):
					if area.has_signal("debuff_applied"):
						area.emit_signal("debuff_applied", "burn")
						
				if PC.selected_rewards.has("RingFire33"):
					if area.get("debuff_manager") and area.debuff_manager.has_method("has_debuff"):
						if area.debuff_manager.has_debuff("burn"):
							# 触发一次燃烧判定
							# 假设 deubff_manager 有 _apply_dot_damage 方法，但它是私有的
							# 我们可能需要手动触发伤害
							# 或者给 deubff_manager 加一个 public 方法
							# 这里先简单处理：造成一次燃烧伤害
							# 燃烧伤害 = 40% atk (from new config)
							var burn_damage = PC.pc_atk * 0.4
							area.take_damage(burn_damage, false, false, "burn")
							
				# 设置该火焰实例对这个敌人的冷却时间
				hit_cooldowns[area] = hit_cooldown
