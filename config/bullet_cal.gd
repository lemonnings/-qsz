# 子弹碰撞计算全局类
# 统一处理所有怪物与子弹的碰撞逻辑
class_name BulletCalculator

# 处理子弹与敌人的完整碰撞逻辑
# 参数:
# - area: 子弹Area2D节点
# - enemy: 敌人节点
# - is_boss: 是否为Boss（可选，默认false）
# 返回: 字典包含 {"final_damage": float, "should_rebound": bool, "should_delete_bullet": bool}
static func handle_bullet_collision_full(area: Area2D, enemy: Node, is_boss: bool = false) -> Dictionary:
	var result = {
		"final_damage": 0.0,
		"should_rebound": false,
		"should_delete_bullet": true,
		"is_crit": false
	}
	
	if not area or not enemy:
		return result
	
	if not area.is_in_group("bullet") or not area.has_method("get_bullet_damage_and_crit_status"):
		return result
		
	if area.has_method("on_hit_target"):
		area.on_hit_target()
		
	# 获取子弹数据
	var bullet_data = area.get_bullet_damage_and_crit_status()
	var damage = bullet_data["damage"]
	var is_crit = bullet_data["is_crit"]
	var is_summon_bullet = bullet_data["is_summon_bullet"]
	var weapon_tag = ""
	if bullet_data.has("weapon_tag"):
		weapon_tag = bullet_data["weapon_tag"]
	var excluded_law_categories: Array = []
	if bullet_data.has("excluded_law_categories"):
		excluded_law_categories = bullet_data["excluded_law_categories"] as Array

	# 计算最终伤害值
	var final_damage_val = damage
	if area.has_method("get") and area.get("is_rebound") and not area.get("parent_bullet"):
		var rebound_base_damage = PC.pc_atk * PC.rebound_damage_multiplier
		# 反弹子弹如果原本是暴击，也应用暴击倍数
		if is_crit:
			rebound_base_damage *= PC.crit_damage_multi
		final_damage_val = rebound_base_damage
	
	# 处理惊鸿的额外攻击
	if area.has_meta("extra_attack"):
		var extra_multiplier = area.get_meta("extra_attack_multiplier")
		final_damage_val *= (1.0 + extra_multiplier)
	
	# 统一武器伤害加成：修习树、成就、法则类武器伤害都加到武器基础倍率上。
	if weapon_tag != "":
		final_damage_val = SettingStudyTreeUp.apply_total_damage_bonus_to_damage_excluding(final_damage_val, weapon_tag, excluded_law_categories)
	
	# 最终伤害乘区改由怪物基类统一结算，这里只保留子弹自身与目标类型相关的基础增伤。
	final_damage_val = Global.apply_enemy_damage_bonus(final_damage_val, enemy)
	
	if weapon_tag == "treasure" or weapon_tag == "branch":
		if enemy.is_in_group("elite") or enemy.is_in_group("boss"):
			final_damage_val = final_damage_val * Faze.get_treasure_elite_boss_multiplier(PC.faze_treasure_level, PC.get_lucky_level())
	
	result["final_damage"] = final_damage_val
	result["is_crit"] = is_crit
	var actual_damage_for_stats: float = final_damage_val
	if enemy.has_method("get"):
		actual_damage_for_stats = minf(float(final_damage_val), maxf(float(enemy.get("hp")), 0.0))
	
	# 处理子弹穿透逻辑
	if area.has_method("handle_penetration"):
		var penetration_result = area.handle_penetration()
		if penetration_result == false:
			# 这一帧已经处理过碰撞，忽略当前碰撞
			result["final_damage"] = 0
			result["should_delete_bullet"] = false
			return result
		else:
			# 正常处理碰撞，检查是否应该销毁子弹
			result["should_delete_bullet"] = (area.penetration_count <= 0)
	
	# 处理子弹反弹逻辑
	if should_create_rebound(area):
		result["should_rebound"] = true
	
	# 如果子弹击中敌人且启用了剑波痕迹，创建剑痕
	if area.has_method("get") and area.get("sword_wave_trace_enabled") and area.has_method("create_sword_trace_to_player"):
		area.create_sword_trace_to_player()
	
	# 检查是否需要添加vulnerable debuff
	if PC.selected_rewards.has("SplitSwordQi33") and enemy.has_signal("debuff_applied"):
		enemy.emit_signal("debuff_applied", "vulnerable")
	
	# 显示伤害数字（只有在敌人未死亡时才显示）
	if enemy.has_method("get") and not enemy.get("is_dead"):
		var damage_offset = Vector2(35, 20)
		if is_boss:
			# Boss伤害显示的偏移不同
			damage_offset = Vector2(
				randf_range(-15, 15),
				randf_range(-15, 15)
			)
			# Boss特殊处理
			if is_crit:
				Global.emit_signal("monster_damage", 2, actual_damage_for_stats, enemy.global_position - Vector2(35, 20) + damage_offset, weapon_tag)
			else:
				Global.emit_signal("monster_damage", 1, actual_damage_for_stats, enemy.global_position - Vector2(35, 20) + damage_offset, weapon_tag)
		else:
			# 普通怪物
			if is_summon_bullet:
				Global.emit_signal("monster_damage", 4, actual_damage_for_stats, enemy.global_position - damage_offset, weapon_tag)
			elif is_crit:
				Global.emit_signal("monster_damage", 2, actual_damage_for_stats, enemy.global_position - damage_offset, weapon_tag)
			else:
				Global.emit_signal("monster_damage", 1, actual_damage_for_stats, enemy.global_position - damage_offset, weapon_tag)
	
	if area.has_method("is_faze_bullet_weapon") and area.is_faze_bullet_weapon():
		Faze.on_bullet_hit()
	if area.has_method("is_sword_weapon") and area.is_sword_weapon():
		Faze.on_sword_weapon_hit(enemy)
	
	# 击中粒子崩散特效（受 particle_enabled 开关控制）
	if final_damage_val > 0 and enemy and is_instance_valid(enemy):
		HitParticleSpawner.spawn_by_weapon(area.get_tree(), enemy.global_position, weapon_tag)
	
	# 击中闪烁效果回调（子弹伤害不走 apply_common_take_damage，需要单独触发）
	if final_damage_val > 0 and is_instance_valid(enemy) and enemy.has_method("on_bullet_hit_response"):
		enemy.on_bullet_hit_response()
	
	return result

# 检查是否应该处理子弹反弹
static func should_create_rebound(_bullet: Area2D) -> bool:
	return false

# 应用全局buff效果到最终伤害
static func apply_global_buff_effects(damage: float) -> float:
	return damage * get_global_buff_damage_multiplier()

static func get_global_buff_damage_multiplier() -> float:
	var final_damage_bonus := 0.0
	
	# 沉静：1秒内没有移动，提升3.5*层数%的最终伤害
	if EmblemManager.has_emblem("chenjing"):
		var chenjing_stack = EmblemManager.get_emblem_stack("chenjing")
		if PC.player_instance and PC.player_instance.has_method("get_last_move_time"):
			var last_move = PC.player_instance.get_last_move_time()
			var current = Time.get_unix_time_from_system()
			if current - last_move >= 1.0: # 1秒
				final_damage_bonus += Global.get_scaled_emblem_value(0.035 * chenjing_stack)
	
	# 炼体：每1%的减伤率额外提升0.1*层数%的最终伤害，最多20%
	if EmblemManager.has_emblem("lianti"):
		var lianti_stack = EmblemManager.get_emblem_stack("lianti")
		var damage_reduction_percent = PC.damage_reduction_rate * 100
		var lianti_bonus = damage_reduction_percent * Global.get_scaled_emblem_value(0.001 * lianti_stack)
		final_damage_bonus += minf(lianti_bonus, Global.get_scaled_emblem_value(0.20))
	
	# 蛮力：当移动速度加成<0%时，提升5*层数%的最终伤害
	if EmblemManager.has_emblem("manli"):
		var manli_stack = EmblemManager.get_emblem_stack("manli")
		if PC.get_manli_effective_move_speed_bonus() < 0.0:
			final_damage_bonus += Global.get_scaled_emblem_value(0.05 * manli_stack)
	
	# 融会贯通：当前每拥有一个纹章，提升1.5*层数%最终伤害，每层最多提供10%
	if EmblemManager.has_emblem("ronghui"):
		var ronghui_stack = EmblemManager.get_emblem_stack("ronghui")
		var active_emblem_count = EmblemManager.get_emblem_count()
		var ronghui_bonus = active_emblem_count * Global.get_scaled_emblem_value(0.015 * ronghui_stack)
		var ronghui_max_bonus = Global.get_scaled_emblem_value(0.10 * ronghui_stack)
		final_damage_bonus += minf(ronghui_bonus, ronghui_max_bonus)
	
	return 1.0 + final_damage_bonus
