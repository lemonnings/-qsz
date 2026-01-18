extends Node
class_name EnemyDebuffManager

# Debuff数据结构
class DebuffData:
	var id: String
	var duration: float
	var stacks: int = 1
	var max_stacks: int = 1
	var has_effect: bool = false # 是否有视觉特效 (粒子等)
	var effect_path: String = "" # 特效路径
	var has_modulate: bool = false # 是否有颜色调制
	var modulate_color: Color = Color.WHITE # 调制颜色

	func _init(p_id: String, p_duration: float, p_max_stacks: int, p_has_effect: bool, p_effect_path: String, p_has_modulate: bool, p_modulate_color: Color):
		id = p_id
		duration = p_duration
		max_stacks = p_max_stacks
		has_effect = p_has_effect
		effect_path = p_effect_path
		has_modulate = p_has_modulate
		modulate_color = p_modulate_color


static var debuff_configs: Dictionary = {
	"slow": DebuffData.new("slow", 5.0, 1, false, "", true, Color.SKY_BLUE),
	"vulnerable": DebuffData.new("vulnerable", 5.0, 1, false, "", true, Color(1.0, 0.5, 0.5)), # 浅红色
	"penetrated": DebuffData.new("penetrated", 3.0, 1, false, "", false, Color.WHITE) # 穿透debuff，持续3秒
}

var active_debuffs: Dictionary = {} # {debuff_id: {timer: Timer, stacks: int, original_modulate: Color, effect_instance: Node2D}}
var target_enemy: Node2D # 关联的敌人节点

func _init(enemy: Node2D):
	target_enemy = enemy

func add_debuff(debuff_id: String):
	if not debuff_configs.has(debuff_id):
		print("Error: Debuff config not found for ID: ", debuff_id)
		return

	var config: DebuffData = debuff_configs[debuff_id]

	if active_debuffs.has(debuff_id):
		# 更新现有debuff
		var current_debuff = active_debuffs[debuff_id]
		current_debuff.stacks = min(current_debuff.stacks + 1, config.max_stacks)
		current_debuff.timer.start(config.duration) # 重置计时器
		print("Debuff '" + debuff_id + "' stacks updated to: ", current_debuff.stacks)
	else:
		# 添加新的debuff
		var timer = Timer.new()
		timer.wait_time = config.duration
		timer.one_shot = true
		timer.timeout.connect(_on_debuff_expired.bind(debuff_id))
		add_child(timer)
		timer.start()

		var original_modulate = target_enemy.modulate
		var effect_instance = null

		active_debuffs[debuff_id] = {
			"timer": timer,
			"stacks": 1,
			"config": config,
			"original_modulate": original_modulate,
			"effect_instance": effect_instance
		}

		_apply_debuff_effects(debuff_id)
		print("Debuff '" + debuff_id + "' added.")

func _apply_debuff_effects(debuff_id: String):
	if not active_debuffs.has(debuff_id):
		return

	var debuff_entry = active_debuffs[debuff_id]
	var config: DebuffData = debuff_entry.config

	if config.has_modulate:
		target_enemy.modulate = config.modulate_color
		print("Applied modulate for debuff: ", debuff_id, " color: ", config.modulate_color)

	if config.has_effect and config.effect_path != "":
		var effect_scene = load(config.effect_path)
		if effect_scene:
			debuff_entry.effect_instance = effect_scene.instantiate()
			target_enemy.add_child(debuff_entry.effect_instance)
			print("Applied effect for debuff: ", debuff_id, " path: ", config.effect_path)

func _remove_debuff_effects(debuff_id: String):
	if not active_debuffs.has(debuff_id):
		return

	var debuff_entry = active_debuffs[debuff_id]
	var config: DebuffData = debuff_entry.config

	if config.has_modulate:
		target_enemy.modulate = debuff_entry.original_modulate
		print("Removed modulate for debuff: ", debuff_id)

	if debuff_entry.effect_instance and is_instance_valid(debuff_entry.effect_instance):
		debuff_entry.effect_instance.queue_free()
		debuff_entry.effect_instance = null
		print("Removed effect for debuff: ", debuff_id)

func _on_debuff_expired(debuff_id: String):
	if active_debuffs.has(debuff_id):
		_remove_debuff_effects(debuff_id)
		var debuff_entry = active_debuffs.get(debuff_id)
		if debuff_entry and debuff_entry.has("timer") and is_instance_valid(debuff_entry.timer):
			debuff_entry.timer.queue_free()
		active_debuffs.erase(debuff_id)
		print("Debuff '" + debuff_id + "' expired and removed.")
		_reapply_remaining_debuff_effects()

func _reapply_remaining_debuff_effects():
	# 如果还有其他debuff，需要重新应用它们的modulate效果（通常是最后一个添加的生效）
	# 这里简化处理，只恢复到原始modulate，如果需要层叠modulate效果，逻辑会更复杂
	if active_debuffs.is_empty():
		# 如果没有其他debuff了，确保恢复原始颜色
		# 这个逻辑可能需要根据具体需求调整，例如，如果希望modulate效果叠加，则需要更复杂的处理
		pass # 当前逻辑是移除时恢复，这里可能不需要额外操作
	else:
		# 找到最后一个（或优先级最高的）有modulate效果的debuff并应用
		var last_modulate_debuff_id = null
		for id in active_debuffs:
			var d_config: DebuffData = active_debuffs[id].config
			if d_config.has_modulate:
				last_modulate_debuff_id = id # 简单取最后一个，实际可能需要优先级
		if last_modulate_debuff_id:
			target_enemy.modulate = active_debuffs[last_modulate_debuff_id].config.modulate_color


func get_take_damage_multiplier() -> float:
	var multiplier = 1.0
	if active_debuffs.has("devulnerable"):
		multiplier -= 0.25 # 造成-25%
	return multiplier

func get_damage_multiplier() -> float:
	var multiplier = 1.0
	if active_debuffs.has("vulnerable"):
		multiplier += 0.2 # 易伤效果，受到伤害增加20%
	if active_debuffs.has("penetrated"):
		multiplier += 0.2 # 穿透debuff，受到伤害增加20%
	return multiplier

func get_speed_multiplier() -> float:
	var multiplier = 1.0
	if active_debuffs.has("slow"):
		multiplier -= 0.25 # 减速效果，速度减少20%
	return multiplier

func has_debuff(debuff_id: String) -> bool:
	return active_debuffs.has(debuff_id)

func clear_all_debuffs():
	for debuff_id in active_debuffs.keys():
		_on_debuff_expired(debuff_id) # 触发过期逻辑来清理
	active_debuffs.clear()

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		clear_all_debuffs()
