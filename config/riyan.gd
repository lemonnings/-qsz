extends Area2D

@export var damage_interval: float = 1.0 # 赤曜伤害频率：1秒/次
const ELITE_BOSS_DAMAGE_BONUS: float = 3.0

var player_node: Node2D
@export var damage_timer: Timer
var is_initialized: bool = false
var draw_node: Node2D
var collision_shape: CollisionShape2D
var current_range_multiplier: float = 1.0
var current_speed_multiplier: float = 1.0
var pulse_time: float = 0.0 # 像素动画计时器

func _ready() -> void:
	CharacterEffects.include_enemy_collision_mask(self )
	Global.connect("riyan_damage_triggered", Callable(self , "_on_get_riyan"))

func _process(delta: float) -> void:
	if player_node:
		global_position = player_node.global_position
		visible = not (player_node.has_method("is_beastify_replacing_weapon") and player_node.is_beastify_replacing_weapon("Riyan"))
	if draw_node:
		pulse_time += delta
		draw_node.queue_redraw()

func _on_damage_timer_timeout() -> void:
	if player_node:
		if player_node.has_method("is_beastify_replacing_weapon") and player_node.is_beastify_replacing_weapon("Riyan"):
			return
		_check_updates()
		
		# 基础系数 0.08 (riyan_hp_max_damage)
		var hp_damage_ratio = PC.riyan_hp_max_damage
		# Riyan22: 16% (0.16)
		if PC.selected_rewards.has("Riyan22"):
			hp_damage_ratio = 0.16
		# Riyan2: 15% (0.15)
		elif PC.selected_rewards.has("Riyan2"):
			hp_damage_ratio = 0.15
			
		var hp_level_multiplier: float = pow(1.02, max(0, PC.pc_lv - 1))
		var damage_amount: float = (PC.pc_atk * PC.riyan_atk_damage) + (PC.pc_max_hp * hp_damage_ratio * hp_level_multiplier)
		# 法则伤害加成累加（不是乘法），避免奖励加成 × 法则加成的双重叠加
		var damage_scale: float = PC.main_skill_riyan_damage + (Faze.get_fire_weapon_damage_multiplier(PC.faze_fire_level) - 1.0)
		
		# 广域法则伤害加成（base_range_bonus = 非法则的范围加成，用于"范围转伤害"）
		var base_range_bonus = 0.0
		if PC.selected_rewards.has("Riyan3"):
			base_range_bonus += 0.2
		base_range_bonus += Global.get_attack_range_multiplier() - 1.0
		damage_scale += Faze.get_wide_damage_multiplier(base_range_bonus) - 1.0
		damage_scale = SettingStudyTreeUp.apply_total_damage_bonus_to_base_multiplier_excluding(damage_scale, "riyan", ["fire", "wide"])
		damage_amount *= damage_scale

		# Riyan1 / Riyan11: 减伤转化伤害
		var dr_bonus = 0.0
		var dr_rate = PC.damage_reduction_rate
		if PC.selected_rewards.has("Riyan11"):
			dr_bonus = min(dr_rate * 3.0, 1.8)
		elif PC.selected_rewards.has("Riyan1"):
			dr_bonus = min(dr_rate * 2.0, 0.9)
		damage_amount *= (1.0 + dr_bonus)
		
		for area in get_overlapping_areas():
			if _is_valid_riyan_target(area):
				var final_damage = damage_amount
				var is_crit = false
				if randf() < PC.crit_chance:
					is_crit = true
					final_damage *= PC.crit_damage_multi
				
				# Riyan33: 对燃烧敌人额外伤害
				if PC.selected_rewards.has("Riyan33"):
					if _has_burn(area):
						final_damage *= 1.6
				if Global.is_elite_or_boss_target(area):
					final_damage *= 1.0 + ELITE_BOSS_DAMAGE_BONUS
						
				area.take_damage(final_damage, is_crit, false, "riyan")
				# 击中粒子崩散特效
				HitParticleSpawner.spawn_by_weapon(get_tree(), area.global_position, "riyan")

func _is_valid_riyan_target(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not target.has_method("take_damage"):
		return false
	return target.is_in_group("enemies") or target.is_in_group("boss")

func _has_burn(enemy) -> bool:
	if enemy.get("debuff_manager") and enemy.debuff_manager.has_method("has_debuff"):
		return enemy.debuff_manager.has_debuff("burn")
	return false

func _check_updates() -> void:
	# Check range (Riyan3)
	var new_range_mult = 1.0
	if PC.selected_rewards.has("Riyan3"):
		new_range_mult = 1.2
	
	# 广域法则范围加成
	var wide_range_mult = Faze.get_wide_range_multiplier()
	# 全局伤害范围加成
	var global_range_mult = Global.get_attack_range_multiplier()
	var total_range_mult = new_range_mult * wide_range_mult * global_range_mult

	if not is_equal_approx(total_range_mult, current_range_multiplier):
		current_range_multiplier = total_range_mult
		_update_visuals()
		
	# Check speed (Riyan4)
	var new_speed_mult = 1.0
	if PC.selected_rewards.has("Riyan4"):
		new_speed_mult = 1.25
		
	if new_speed_mult != current_speed_multiplier:
		current_speed_multiplier = new_speed_mult
		damage_timer.wait_time = PC.riyan_cooldown / current_speed_multiplier

func _update_visuals() -> void:
	var radius = PC.riyan_range * current_range_multiplier
	if collision_shape and collision_shape.shape:
		collision_shape.shape.radius = radius
	if draw_node:
		draw_node.queue_redraw()

func _exit_tree() -> void:
	if damage_timer and is_instance_valid(damage_timer):
		remove_child(damage_timer)
		damage_timer.queue_free()

func _on_get_riyan():
	if is_initialized:
		return
	
	player_node = get_tree().get_first_node_in_group("player")
	global_position = player_node.global_position
	
	collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	var initial_range_mult = Faze.get_wide_range_multiplier() * Global.get_attack_range_multiplier()
	current_range_multiplier = initial_range_mult
	circle_shape.radius = PC.riyan_range * current_range_multiplier
	collision_shape.shape = circle_shape
	add_child(collision_shape)
	
	collision_layer = 0
	
	draw_node = Node2D.new()
	draw_node.z_index = -1
	draw_node.modulate = Color(1.0, 1.0, 1.0, 0.30)
	add_child(draw_node)
	draw_node.draw.connect(func():
		var radius: float = PC.riyan_range * current_range_multiplier
		const P: int = 4

		# 外圈：双红交替小方块，统一为烧灸红视觉
		var col_ring_dark = Color(0.82, 0.10, 0.01, 1.00) # 深烧红
		var col_ring_light = Color(1.00, 0.20, 0.04, 1.00) # 亮烧红
		# 内圈：热浪三色（波峰→余波→暗底）
		var col_wave_crest = Color(1.00, 0.78, 0.12, 0.98) # 波峰亮橙黄
		var col_wave_mid = Color(0.95, 0.36, 0.03, 0.78) # 余波中橙
		var col_wave_dark = Color(0.62, 0.10, 0.01, 0.38) # 暗底暗红

		var split_r: float = radius * 0.965
		var split_r2: float = split_r * split_r
		var R2: float = radius * radius

		# 热浪从圆心向外循环扩散： wave_pos 0→1 对应波峰在 0→split_r
		var wave_pos: float = fmod(pulse_time * 0.55, 1.0)

		var gx: int = - int(radius) - P
		while gx < int(radius) + P:
			var gy: int = - int(radius) - P
			while gy < int(radius) + P:
				var cx: float = gx + P * 0.5
				var cy: float = gy + P * 0.5
				var d2: float = cx * cx + cy * cy
				if d2 <= R2:
					var rect = Rect2(gx, gy, P, P)
					var gxi: int = int(gx / float(P))
					var gyi: int = int(gy / float(P))
					if d2 <= split_r2:
						# 内圈：热浪径向扩散
						var norm_d: float = sqrt(d2) / split_r # 0→1
						var band: float = fmod(norm_d - wave_pos + 10.0, 1.0)
						if band < 0.18:
							# 波峰：最亮
							draw_node.draw_rect(rect, col_wave_crest)
						elif band < 0.48:
							# 余波：中等亮度
							draw_node.draw_rect(rect, col_wave_mid)
						elif band < 0.72:
							# 暗底：实心填充
							draw_node.draw_rect(rect, col_wave_dark)
						# band >= 0.72：黑暗间隙，不画，形成环与环之间的分割感
					else:
						# 外圈：完整烧灸红圈，双色像素块纹理
						if (gxi + gyi) % 2 == 0:
							draw_node.draw_rect(rect, col_ring_dark)
						else:
							draw_node.draw_rect(rect, col_ring_light)
				gy += P
			gx += P
	)
	
	damage_timer.wait_time = PC.riyan_cooldown
	damage_timer.start()
	set_process(true)
	is_initialized = true
