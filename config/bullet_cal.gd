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

	# 计算最终伤害值
	var final_damage_val = damage
	if area.has_method("get") and area.get("is_rebound") and not area.get("parent_bullet"):
		var rebound_base_damage = PC.pc_atk * PC.rebound_damage_multiplier
		# 反弹子弹如果原本是暴击，也应用暴击倍数
		if is_crit:
			rebound_base_damage *= PC.crit_damage_multiplier
		final_damage_val = rebound_base_damage
	
	result["final_damage"] = final_damage_val
	result["is_crit"] = is_crit
	
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
			# Boss伤害显示的偏移可能不同
			damage_offset = Vector2(
				randf_range(-15, 15),
				randf_range(-15, 15)
			)
			# Boss特殊处理
			if is_crit:
				Global.emit_signal("monster_damage", 2, final_damage_val, enemy.global_position - Vector2(35,20) + damage_offset)
			else:
				Global.emit_signal("monster_damage", 1, final_damage_val, enemy.global_position - Vector2(35,20) + damage_offset)
		else:
			# 普通怪物
			if is_summon_bullet:
				Global.emit_signal("monster_damage", 4, final_damage_val, enemy.global_position - damage_offset)
			elif is_crit:
				Global.emit_signal("monster_damage", 2, final_damage_val, enemy.global_position - damage_offset)
			else:
				Global.emit_signal("monster_damage", 1, final_damage_val, enemy.global_position - damage_offset)
	
	return result

# 检查是否应该处理子弹反弹
# 参数:
# - bullet: 子弹Area2D节点
# 返回: 是否应该创建反弹子弹
static func should_create_rebound(bullet: Area2D) -> bool:
	if not bullet:
		return false
	
	# 首先检查玩家是否有续剑技能
	if not PC.selected_rewards.has("SplitSwordQi12"):
		return false
	
	var is_rebound = bullet.get("is_rebound")
	var parent_bullet = bullet.get("parent_bullet")
	
	var change = randf()
	if not is_rebound and parent_bullet and change <= 0.25:
		return true
	else:
		return false  # 只有父级子弹且非反弹子弹才能反弹
