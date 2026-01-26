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


static var debuff_configs: Dictionary = {
	"slow": DebuffData.new("slow", 5.0, 1, false, "", true, Color.SKY_BLUE, 0.0, 0.0, -0.25, false, 0.0, 1.0, false, 40.0),
	"vulnerable": DebuffData.new("vulnerable", 5.0, 1, false, "", true, Color(1.0, 0.5, 0.5), -0.25, 0.0, 0.0, false, 0.0, 1.0, false, 40.0),
	"penetrated": DebuffData.new("penetrated", 3.0, 1, false, "", false, Color.WHITE, 0.0, 0.2, 0.0, false, 0.0, 1.0, false, 40.0),
	"paralyze": DebuffData.new("paralyze", 3.0, 1, false, "", true, Color(0.7, 0.7, 1.0), 0.0, 0.0, 0.0, true, 0.0, 1.0, false, 40.0),
	"stun": DebuffData.new("stun", 3.0, 1, false, "", true, Color(0.9, 0.9, 0.9), 0.0, 0.0, 0.0, true, 0.0, 1.0, false, 40.0),
	"bleed": DebuffData.new("bleed", 5.0, 5, false, "", true, Color(0.9, 0.3, 0.3), 0.0, 0.0, 0.0, false, 0.1, 1.0, false, 40.0),
	"shock": DebuffData.new("shock", 5.0, 1, false, "", true, Color(1.0, 0.9, 0.4), 0.0, 0.0, 0.0, false, 0.3, 1.0, false, 40.0),
	"burn": DebuffData.new("burn", 5.0, 1, false, "", true, Color(1.0, 0.6, 0.2), 0.0, 0.0, 0.0, false, 0.1, 1.0, true, 60.0)
}

var active_debuffs: Dictionary = {} # {debuff_id: {timer: Timer, stacks: int, config: DebuffData, effect_instance: Node2D, dot_elapsed: float}}
var target_enemy: Node2D # 关联的敌人节点
var base_modulate: Color = Color.WHITE

func _init(enemy: Node2D):
	target_enemy = enemy
	base_modulate = target_enemy.modulate

func add_debuff(debuff_id: String):
	var config: DebuffData = debuff_configs[debuff_id]

	if active_debuffs.has(debuff_id):
		# 更新现有debuff
		var current_debuff = active_debuffs[debuff_id]
		var new_stacks = current_debuff["stacks"] + 1
		if new_stacks > config.max_stacks:
			new_stacks = config.max_stacks
		current_debuff["stacks"] = new_stacks
		current_debuff["timer"].start(config.duration)
		active_debuffs[debuff_id] = current_debuff
	else:
		# 添加新的debuff
		var timer = Timer.new()
		timer.wait_time = config.duration
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
	for debuff_id in active_debuffs:
		var config: DebuffData = active_debuffs[debuff_id]["config"]
		if config.damage_taken_multiplier != 0.0:
			multiplier += config.damage_taken_multiplier
	return multiplier

func get_speed_multiplier() -> float:
	var multiplier = 1.0
	for debuff_id in active_debuffs:
		var config: DebuffData = active_debuffs[debuff_id]["config"]
		if config.speed_multiplier != 0.0:
			multiplier += config.speed_multiplier
	return multiplier

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
		_apply_dot_damage(debuff_id, damage)

func _apply_dot_damage(debuff_id: String, damage: float) -> void:
	var debuff_entry = active_debuffs[debuff_id]
	var config: DebuffData = debuff_entry["config"]
	target_enemy.take_damage(int(damage), false, false, debuff_id)
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
			area.take_damage(int(damage), false, false, debuff_id)
