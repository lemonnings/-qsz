extends Area2D

var damage: float = 0.0
var hit_cooldown: float = 0.3
var hit_cooldowns: Dictionary = {}

func _ready() -> void:
	CharacterEffects.include_enemy_collision_mask(self)
	# 设置碰撞检测
	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 12.0 # 火焰的碰撞范围
	if (PC.selected_rewards.has("RingFire3")):
		circle_shape.radius = 14.4 # +20%
	collision_shape.shape = circle_shape
	add_child(collision_shape)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	var player: Node = PC.player_instance
	if player != null and is_instance_valid(player) and player.has_method("is_beastify_replacing_weapon") and player.is_beastify_replacing_weapon("RingFire"):
		damage = 0.0
		return
	# 法则伤害加成累加（不是乘法），避免奖励加成 × 法则加成的双重叠加
	var damage_multiplier = PC.main_skill_ringFire_damage
	damage_multiplier += (Faze.get_fire_weapon_damage_multiplier(PC.faze_fire_level) - 1.0) # 火焰法则
	damage_multiplier = SettingStudyTreeUp.apply_total_damage_bonus_to_base_multiplier_excluding(damage_multiplier, "ringFire", ["fire"])
	damage = PC.pc_atk * damage_multiplier
	
	if (PC.selected_rewards.has("RingFire22")):
		damage = damage * 1.12
		
	# 更新冷却时间
	var to_remove = []
	for enemy in hit_cooldowns.keys():
		hit_cooldowns[enemy] -= delta
		if hit_cooldowns[enemy] <= 0:
			to_remove.append(enemy)
	
	for enemy in to_remove:
		hit_cooldowns.erase(enemy)

func _on_area_entered(area: Area2D) -> void:
	var player: Node = PC.player_instance
	if player != null and is_instance_valid(player) and player.has_method("is_beastify_replacing_weapon") and player.is_beastify_replacing_weapon("RingFire"):
		return
	# 检查是否是敌人
	if area.is_in_group("enemies"):
		# 检查该火焰实例是否对这个敌人在冷却中
		if _try_consume_hit_cooldown(area):
			# 造成伤害
			if area.has_method("take_damage"):
				var was_alive_for_bagua = area.get("hp") > 0 and not area.get("is_dead")
				var final_damage = damage
				if _should_apply_burn_bonus(area):
					final_damage += _get_burn_bonus_damage()
				var is_crit = false
				if randf() < PC.crit_chance:
					is_crit = true
					final_damage *= PC.crit_damage_multi
				area.take_damage(final_damage, is_crit, false, "ringFire")
				Faze.add_bagua_hit_progress(area, was_alive_for_bagua)
				
				if PC.selected_rewards.has("RingFire4") and randf() < 0.2:
					if area.has_signal("debuff_applied"):
						area.emit_signal("debuff_applied", "burn")
							
func _try_consume_hit_cooldown(area: Area2D) -> bool:
	var parent_node := get_parent()
	if parent_node != null and parent_node.has_method("try_consume_ring_fire_hit_cooldown"):
		return bool(parent_node.call("try_consume_ring_fire_hit_cooldown", area, hit_cooldown))
	if hit_cooldowns.has(area) and float(hit_cooldowns[area]) > 0.0:
		return false
	hit_cooldowns[area] = hit_cooldown
	return true

func _should_apply_burn_bonus(area: Area2D) -> bool:
	if not PC.selected_rewards.has("RingFire33"):
		return false
	if not area.get("debuff_manager") or not area.debuff_manager.has_method("has_debuff"):
		return false
	return area.debuff_manager.has_debuff("burn")

func _get_burn_bonus_damage() -> float:
	return PC.pc_atk * 0.05
