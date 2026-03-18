extends Node
class_name EnemyDebuffManager

# Debuff数据结构
class DebuffData:
	var id: String
	var duration: float
	var max_stacks: int = 1
	var has_effect: bool = false # 是否有视觉特效 (粒子等)
	var effect_path: String = "" # 特效路径
	var has_modulate: bool = false # 是否有颜色调制
	var modulate_color: Color = Color.WHITE # 调制颜色
	var damage_dealt_multiplier: float = 0.0 # 对外伤害倍率变化
	var damage_taken_multiplier: float = 0.0 # 受到伤害倍率变化
	var speed_multiplier: float = 0.0 # 移速倍率变化
	var action_blocked: bool = false # 禁止行动
	var dot_damage_ratio: float = 0.0 # 每秒DOT伤害比例
	var dot_tick_interval: float = 1.0 # DOT结算间隔
	var dot_affect_neighbors: bool = false # DOT是否影响周围敌人
	var dot_neighbor_radius: float = 40.0 # DOT影响半径

	func _init(
		p_id: String,
		p_duration: float,
		p_max_stacks: int,
		p_has_effect: bool,
		p_effect_path: String,
		p_has_modulate: bool,
		p_modulate_color: Color,
		p_damage_dealt_multiplier: float,
		p_damage_taken_multiplier: float,
		p_speed_multiplier: float,
		p_action_blocked: bool,
		p_dot_damage_ratio: float,
		p_dot_tick_interval: float,
		p_dot_affect_neighbors: bool,
		p_dot_neighbor_radius: float
	):
		id = p_id
		duration = p_duration
		max_stacks = p_max_stacks
		has_effect = p_has_effect
		effect_path = p_effect_path
		has_modulate = p_has_modulate
		modulate_color = p_modulate_color
		damage_dealt_multiplier = p_damage_dealt_multiplier
		damage_taken_multiplier = p_damage_taken_multiplier
		speed_multiplier = p_speed_multiplier
		action_blocked = p_action_blocked
		dot_damage_ratio = p_dot_damage_ratio
		dot_tick_interval = p_dot_tick_interval
		dot_affect_neighbors = p_dot_affect_neighbors
		dot_neighbor_radius = p_dot_neighbor_radius


var burn_scene = preload("res://Scenes/player/debuff_burn.tscn")

static var debuff_configs: Dictionary = {
	"slow": DebuffData.new("slow", 5.0, 1, false, "", true, Color.SKY_BLUE, 0.0, 0.0, -0.25, false, 0.0, 1.0, false, 40.0),
	"vulnerable": DebuffData.new("vulnerable", 5.0, 1, false, "", true, Color(1.0, 0.5, 0.5), -0.25, 0.0, 0.0, false, 0.0, 1.0, false, 40.0),
	"penetrated": DebuffData.new("penetrated", 3.0, 1, false, "", false, Color.WHITE, 0.0, 0.2, 0.0, false, 0.0, 1.0, false, 40.0),
	"paralyze": DebuffData.new("paralyze", 3.0, 1, false, "", true, Color(0.7, 0.7, 1.0), 0.0, 0.0, 0.0, true, 0.0, 1.0, false, 40.0),
	"stun": DebuffData.new("stun", 3.0, 1, false, "", true, Color(0.9, 0.9, 0.9), 0.0, 0.0, 0.0, true, 0.0, 1.0, false, 40.0),
	"bleed": DebuffData.new("bleed", 5.0, 5, false, "", true, Color(0.9, 0.3, 0.3), 0.0, 0.0, 0.0, false, 0.15, 1.0, false, 40.0),
	"burn": DebuffData.new("burn", 3.0, 1, false, "", true, Color(1.0, 0.6, 0.2), 0.0, 0.0, 0.0, false, 0.4, 1.0, true, 60.0),
	"electrified": DebuffData.new("electrified", 3.0, 1, false, "", true, Color(0.8, 0.8, 0.0), 0.0, 0.0, 0.0, false, 0.5, 1.0, false, 40.0),
	"light_accumulation": DebuffData.new("light_accumulation", 5.0, 20, false, "", true, Color(1.0, 1.0, 0.8), 0.0, 0.05, 0.0, false, 0.0, 1.0, false, 40.0),
	"corrosion": DebuffData.new("corrosion", 5.0, 1, false, "", true, Color(0.6, 0.8, 0.2), 0.0, 0.2, 0.0, false, 0.0, 1.0, false, 40.0), # 腐蚀：受到的伤害增加20%
	"corrosion2": DebuffData.new("corrosion2", 5.0, 1, false, "", true, Color(0.5, 0.9, 0.1), 0.0, 0.3, 0.0, false, 0.0, 1.0, false, 40.0) # 腐蚀2：受到的伤害增加30%
}

static var debuff_elite_boss_damage_bonus: Dictionary = {}

var active_debuffs: Dictionary = {} # {debuff_id: {timer: Timer, stacks: int, config: DebuffData, effect_instance: Node2D, dot_elapsed: float}}
var target_enemy: Node2D # 关联的敌人节点
var base_modulate: Color = Color.WHITE
var death_fade_started: bool = false

func _init(enemy: Node2D):
	target_enemy = enemy
	base_modulate = target_enemy.modulate

static func set_debuff_elite_boss_bonus(debuff_id: String, bonus: float) -> void:
	debuff_elite_boss_damage_bonus[debuff_id] = bonus

static func get_debuff_elite_boss_bonus(debuff_id: String) -> float:
	if debuff_elite_boss_damage_bonus.has(debuff_id):
		return debuff_elite_boss_damage_bonus[debuff_id]
	return 0.0

static func get_debuff_elite_boss_damage_multiplier(debuff_id: String, target: Node) -> float:
	var bonus = get_debuff_elite_boss_bonus(debuff_id)
	if bonus <= 0.0:
		return 1.0
	if target.is_in_group("elite") or target.is_in_group("boss"):
		return 1.0 + bonus
	return 1.0

func add_debuff(debuff_id: String, extra_stacks_limit: int = 0):
	var config: DebuffData = debuff_configs[debuff_id]
	# 炽焰法则 7阶+：燃烧持续时间额外增加
	var effective_duration = config.duration
	if debuff_id == "burn":
		effective_duration += Faze.get_burn_duration_bonus(PC.faze_fire_level)

	if active_debuffs.has(debuff_id):
		# 更新现有debuff
		var current_debuff = active_debuffs[debuff_id]
		var new_stacks = current_debuff["stacks"] + 1
		var limit = config.max_stacks + extra_stacks_limit
		if new_stacks > limit:
			new_stacks = limit
		current_debuff["stacks"] = new_stacks
		current_debuff["timer"].start(effective_duration)
		active_debuffs[debuff_id] = current_debuff
	else:
		# 添加新的debuff
		var timer = Timer.new()
		timer.wait_time = effective_duration
		timer.one_shot = true
		timer.timeout.connect(_on_debuff_expired.bind(debuff_id))
		add_child(timer)
		timer.start()

		var effect_instance = null

		active_debuffs[debuff_id] = {
			"timer": timer,
			"stacks": 1,
			"config": config,
			"effect_instance": effect_instance,
			"dot_elapsed": 0.0
		}

		_apply_debuff_effects(debuff_id)

func _apply_debuff_effects(debuff_id: String):
	var debuff_entry = active_debuffs[debuff_id]
	var config: DebuffData = debuff_entry["config"]

	if config.has_modulate:
		target_enemy.modulate = config.modulate_color

	if config.has_effect and config.effect_path != "":
		var effect_scene = load(config.effect_path)
		debuff_entry["effect_instance"] = effect_scene.instantiate()
		target_enemy.add_child(debuff_entry["effect_instance"])
		active_debuffs[debuff_id] = debuff_entry

func _remove_debuff_effects(debuff_id: String):
	var debuff_entry = active_debuffs[debuff_id]
	var config: DebuffData = debuff_entry["config"]

	if config.has_modulate:
		target_enemy.modulate = base_modulate

	if debuff_entry["effect_instance"]:
		debuff_entry["effect_instance"].queue_free()
		debuff_entry["effect_instance"] = null
		active_debuffs[debuff_id] = debuff_entry

func _on_debuff_expired(debuff_id: String):
	_remove_debuff_effects(debuff_id)
	var debuff_entry = active_debuffs[debuff_id]
	debuff_entry["timer"].queue_free()
	active_debuffs.erase(debuff_id)
	_reapply_remaining_debuff_effects()

func _reapply_remaining_debuff_effects():
	if active_debuffs.is_empty():
		target_enemy.modulate = base_modulate
	else:
		var last_modulate_debuff_id = null
		for id in active_debuffs:
			var d_config: DebuffData = active_debuffs[id]["config"]
			if d_config.has_modulate:
				last_modulate_debuff_id = id
		if last_modulate_debuff_id != null:
			target_enemy.modulate = active_debuffs[last_modulate_debuff_id]["config"].modulate_color
		else:
			target_enemy.modulate = base_modulate


func get_take_damage_multiplier() -> float:
	var multiplier = 1.0
	for debuff_id in active_debuffs:
		var config: DebuffData = active_debuffs[debuff_id]["config"]
		if config.damage_dealt_multiplier != 0.0:
			multiplier += config.damage_dealt_multiplier
	return multiplier

func get_damage_multiplier() -> float:
	var multiplier = 1.0
	
	# R33-UR33: 目标身上每有一层异常状态，对其造成的最终伤害提升
	var debuff_count = 0
	for debuff_id in active_debuffs:
		debuff_count += active_debuffs[debuff_id]["stacks"]
	
	var debuff_bonus = 0.0
	if debuff_count > 0:
		var bonus_per_stack = 0.0
		if PC.selected_rewards.has("UR33"): bonus_per_stack = 0.12
		elif PC.selected_rewards.has("SSR33"): bonus_per_stack = 0.10
		elif PC.selected_rewards.has("SR33"): bonus_per_stack = 0.09
		elif PC.selected_rewards.has("R33"): bonus_per_stack = 0.08
		
		if bonus_per_stack > 0:
			multiplier += debuff_count * bonus_per_stack

	for debuff_id in active_debuffs:
		var config: DebuffData = active_debuffs[debuff_id]["config"]
		if config.damage_taken_multiplier != 0.0:
			var effect_multiplier = 1.0
			
			# R35-UR35: 脆弱效果提升 (vulnerable)
			if debuff_id == "vulnerable":
				if PC.selected_rewards.has("UR35"): effect_multiplier += 0.325
				elif PC.selected_rewards.has("SSR35"): effect_multiplier += 0.275
				elif PC.selected_rewards.has("SR35"): effect_multiplier += 0.225
				elif PC.selected_rewards.has("R35"): effect_multiplier += 0.175
				
			# R36-UR36: 易伤效果提升 (vulnerability - 假设对应 penetrated 或其他易伤debuff，或者vulnerable本身)
			# 但这里我们假设是针对 damage_taken_multiplier 类型的debuff
			# 如果用户没有明确指定易伤是哪个debuff，我们先保留逻辑
			
			multiplier += config.damage_taken_multiplier * effect_multiplier
			
	multiplier = multiplier * Faze.get_final_damage_multiplier()
	
	# R40-UR40: 反击 - 每1%减伤率提供X%的最终伤害加成
	var counter_bonus = 0.0
	if PC.selected_rewards.has("UR40"): counter_bonus = PC.damage_reduction_rate * 100 * 0.008
	elif PC.selected_rewards.has("SSR40"): counter_bonus = PC.damage_reduction_rate * 100 * 0.006
	elif PC.selected_rewards.has("SR40"): counter_bonus = PC.damage_reduction_rate * 100 * 0.005
	elif PC.selected_rewards.has("R40"): counter_bonus = PC.damage_reduction_rate * 100 * 0.004
	
	multiplier += counter_bonus
	
	return multiplier

func get_speed_multiplier() -> float:
	var speed_multiplier = 1.0
	for debuff_id in active_debuffs:
		var config: DebuffData = active_debuffs[debuff_id]["config"]
		if config.speed_multiplier != 0.0:
			var multiplier_bonus = 1.0
			if debuff_id == "slow":
				# R34-UR34: 减速效果提升
				if PC.selected_rewards.has("UR34"): multiplier_bonus += 0.325
				elif PC.selected_rewards.has("SSR34"): multiplier_bonus += 0.275
				elif PC.selected_rewards.has("SR34"): multiplier_bonus += 0.225
				elif PC.selected_rewards.has("R34"): multiplier_bonus += 0.175
			speed_multiplier += config.speed_multiplier * multiplier_bonus
	return speed_multiplier

func is_action_disabled() -> bool:
	for debuff_id in active_debuffs:
		var config: DebuffData = active_debuffs[debuff_id]["config"]
		if config.action_blocked:
			return true
	return false

func has_debuff(debuff_id: String) -> bool:
	return active_debuffs.has(debuff_id)

func clear_all_debuffs():
	var debuff_ids = active_debuffs.keys()
	for debuff_id in debuff_ids:
		_on_debuff_expired(debuff_id)
	active_debuffs.clear()

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		clear_all_debuffs()

func _process(delta: float) -> void:
	if target_enemy.is_dead and not death_fade_started:
		_start_death_fade()
	if active_debuffs.is_empty():
		return
	var debuff_ids = active_debuffs.keys()
	for debuff_id in debuff_ids:
		var debuff_entry = active_debuffs[debuff_id]
		var config: DebuffData = debuff_entry["config"]
		if config.dot_damage_ratio <= 0.0:
			continue
		var dot_elapsed = debuff_entry["dot_elapsed"] + delta
		if dot_elapsed < config.dot_tick_interval:
			debuff_entry["dot_elapsed"] = dot_elapsed
			active_debuffs[debuff_id] = debuff_entry
			continue
		dot_elapsed -= config.dot_tick_interval
		debuff_entry["dot_elapsed"] = dot_elapsed
		active_debuffs[debuff_id] = debuff_entry
		var damage = PC.pc_atk * config.dot_damage_ratio * debuff_entry["stacks"]
		
		# DoT damage bonus check
		var dot_bonus_multiplier = 1.0
		
		if debuff_id == "electrified":
			damage *= Faze.get_thunder_electrified_damage_multiplier(PC.faze_thunder_level)
			# R38-UR38: 感电效果提升
			if PC.selected_rewards.has("UR38"): dot_bonus_multiplier += 0.65
			elif PC.selected_rewards.has("SSR38"): dot_bonus_multiplier += 0.55
			elif PC.selected_rewards.has("SR38"): dot_bonus_multiplier += 0.45
			elif PC.selected_rewards.has("R38"): dot_bonus_multiplier += 0.35
			
		elif debuff_id == "burn":
			# SR38-UR38: 燃烧效果提升 (Assume IDs overlap or user intent, apply to burn too if present)
			# Note: User listed R38 twice (Electrified and Burn). Assuming they share the ID slot or are distinct.
			# Given the text input, let's assume if the reward is present, it applies to both or specific one.
			# But since we use checking logic based on ID string, and IDs are same "R38", "SR38"...
			# It implies R38 buffs BOTH Electrified AND Burn if the description text was just merged or typo.
			# However, looking at the user input, they are separate entries.
			# Since we are not modifying reward.csv, we must assume the user might have different IDs in their mind or csv.
			# But based on the prompt "R38 ... 砺雷" and "R38 ... 灼烧", if they have same ID, they are same item.
			# If they are same item, then picking R38 buffs both.
			if PC.selected_rewards.has("UR38"): dot_bonus_multiplier += 0.65
			elif PC.selected_rewards.has("SSR38"): dot_bonus_multiplier += 0.55
			elif PC.selected_rewards.has("SR38"): dot_bonus_multiplier += 0.45
			elif PC.selected_rewards.has("R38"): dot_bonus_multiplier += 0.35
			
		elif debuff_id == "bleed":
			# R37-UR37: 流血效果提升
			if PC.selected_rewards.has("UR37"): dot_bonus_multiplier += 0.65
			elif PC.selected_rewards.has("SSR37"): dot_bonus_multiplier += 0.55
			elif PC.selected_rewards.has("SR37"): dot_bonus_multiplier += 0.45
			elif PC.selected_rewards.has("R37"): dot_bonus_multiplier += 0.35
			
		damage *= dot_bonus_multiplier
		_apply_dot_damage(debuff_id, damage)

func _start_death_fade() -> void:
	death_fade_started = true
	var debuff_ids = active_debuffs.keys()
	for debuff_id in debuff_ids:
		var debuff_entry = active_debuffs[debuff_id]
		debuff_entry["timer"].stop()
		debuff_entry["timer"].queue_free()
		if debuff_entry["effect_instance"]:
			var effect_node = debuff_entry["effect_instance"]
			var tween = effect_node.create_tween()
			tween.tween_property(effect_node, "modulate:a", 0.0, 0.1)
			tween.tween_callback(Callable(effect_node, "queue_free"))
	active_debuffs.clear()
	var modulate_tween = target_enemy.create_tween()
	modulate_tween.tween_property(target_enemy, "modulate", base_modulate, 0.1)

func _apply_dot_damage(debuff_id: String, damage: float) -> void:
	var debuff_entry = active_debuffs[debuff_id]
	var config: DebuffData = debuff_entry["config"]
	var damage_type_int = _get_dot_damage_type_int(debuff_id)
	if debuff_id == "burn":
		var burn_instance = burn_scene.instantiate()
		get_tree().current_scene.add_child(burn_instance)
		burn_instance.global_position = target_enemy.global_position
		burn_instance.scale = Vector2.ONE * Faze.get_burn_range_multiplier(PC.faze_fire_level)
		
		var burn_damage = damage * Faze.get_burn_damage_multiplier(PC.faze_fire_level)
		var main_target_multiplier = 1.0
		if target_enemy.is_in_group("elite") or target_enemy.is_in_group("boss"):
			main_target_multiplier = Faze.get_fire_elite_boss_multiplier(PC.faze_fire_level)
		var final_damage = burn_damage * main_target_multiplier
		target_enemy.take_damage(int(final_damage), false, false, debuff_id)
		Global.emit_signal("monster_damage", damage_type_int, final_damage, target_enemy.global_position - Vector2(16, 6))
		
		var burn_radius = burn_instance.collision.shape.radius * burn_instance.collision.global_scale.x
		var space_state = target_enemy.get_world_2d().direct_space_state
		var query = PhysicsShapeQueryParameters2D.new()
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = burn_radius
		query.set_shape(circle_shape)
		query.transform = Transform2D(0, target_enemy.global_position)
		query.collide_with_areas = true
		query.collide_with_bodies = false
		query.collision_mask = target_enemy.collision_mask
		var results = space_state.intersect_shape(query)
		for hit in results:
			var area = hit.collider
			if area == target_enemy:
				continue
			if area.is_in_group("enemies"):
				var neighbor_multiplier = 1.0
				if area.is_in_group("elite") or area.is_in_group("boss"):
					neighbor_multiplier = Faze.get_fire_elite_boss_multiplier(PC.faze_fire_level)
				var neighbor_damage = burn_damage * 0.5 * neighbor_multiplier
				area.take_damage(int(neighbor_damage), false, false, debuff_id)
				Global.emit_signal("monster_damage", damage_type_int, neighbor_damage, area.global_position)
		return
	var main_target_multiplier = EnemyDebuffManager.get_debuff_elite_boss_damage_multiplier(debuff_id, target_enemy)
	var final_damage = damage * main_target_multiplier
	target_enemy.take_damage(int(final_damage), false, false, debuff_id)
	Global.emit_signal("monster_damage", damage_type_int, final_damage, target_enemy.global_position - Vector2(16, 6))
	if not config.dot_affect_neighbors:
		return
	var space_state = target_enemy.get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = config.dot_neighbor_radius
	query.set_shape(circle_shape)
	query.transform = Transform2D(0, target_enemy.global_position)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = target_enemy.collision_mask
	# intersect_shape 用于使用形状在物理空间中查询重叠对象
	var results = space_state.intersect_shape(query)
	for hit in results:
		var area = hit.collider
		if area == target_enemy:
			continue
		if area.is_in_group("enemies"):
			var neighbor_multiplier = EnemyDebuffManager.get_debuff_elite_boss_damage_multiplier(debuff_id, area)
			var neighbor_damage = damage * neighbor_multiplier
			area.take_damage(int(neighbor_damage), false, false, debuff_id)
			Global.emit_signal("monster_damage", damage_type_int, neighbor_damage, area.global_position)

func _get_dot_damage_type_int(debuff_id: String) -> int:
	if debuff_id == "electrified":
		return 5
	if debuff_id == "burn":
		return 6
	if debuff_id == "bleed":
		return 7
	if debuff_id == "corrosion" or debuff_id == "corrosion2":
		return 8
	return 0
