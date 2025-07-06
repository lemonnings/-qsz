extends Area2D

var damage: float = 0.0
var hit_cooldown: float = 0.3
var hit_cooldowns: Dictionary = {}

func _ready() -> void:
	# 设置碰撞检测
	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 12.0  # 火焰的碰撞范围
	if(PC.selected_rewards.has("ringFire13")):
		circle_shape.radius = 18.0
	collision_shape.shape = circle_shape
	add_child(collision_shape)

	# 连接碰撞信号
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	damage = PC.pc_atk * 0.25 * PC.main_skill_ringFire_damage
	if(PC.selected_rewards.has("ringFire3")):
		damage = damage * 1.25
	if(PC.selected_rewards.has("ringFire13")):
		damage = damage * 1.1
	if(PC.selected_rewards.has("ringFire23")):
		damage = damage * 1.1
		if randf() < PC.crit_chance:
			damage *= PC.crit_damage_multiplier
		
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
				area.take_damage(damage, false, false, "")
				# 设置该火焰实例对这个敌人的冷却时间
				hit_cooldowns[area] = hit_cooldown
