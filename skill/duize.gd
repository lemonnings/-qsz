extends Area2D
class_name Duize

@export var sprite : AnimatedSprite2D
@export var collision : CollisionShape2D

static var main_skill_duize_damage: float = 0.2
static var duize_final_damage_multi: float = 1.0
static var duize_range: float = 60.0
static var duize_slow_ratio: float = 0.2

static func reset_data() -> void:
	main_skill_duize_damage = 0.2
	duize_final_damage_multi = 1.0
	duize_range = 60.0
	duize_slow_ratio = 0.2

# 基础属性
var damage_per_sec: float = 0.0
var slow_ratio: float = 0.2
var duration: float = 3.9 # 持续时间3.9秒
var elapsed: float = 0.0
var damage_interval: float = 0.5 # 每0.5秒伤害
var damage_timer: float = 0.0

# 升级相关效果
var damage_per_debuff_ratio: float = 0.0 # 每个异常状态增加的伤害比例
var apply_corrosion: bool = false # 是否施加腐蚀
var corrosion_extra_damage: float = 0.2 # 腐蚀额外增伤 20%
var corrosion_extra_damage_duize11: float = 0.3 # Duize11 额外增伤

# 范围内的敌人
var enemies_in_range: Array = []

# 静态方法处理发射逻辑
static func fire_skill(scene: PackedScene, origin_pos: Vector2, tree: SceneTree) -> void:
	if not scene:
		return
		
	# 索敌逻辑：周围300范围内，敌人最多的地方
	var target_pos = _find_best_target_pos(origin_pos, tree)
	
	_spawn_duize(scene, tree, target_pos)

static func _find_best_target_pos(origin: Vector2, tree: SceneTree) -> Vector2:
	var enemies = tree.get_nodes_in_group("enemies")
	var candidates = []
	var search_range = 150.0
	var search_range_sq = search_range * search_range
	
	# 筛选范围内的敌人
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_squared_to(origin) <= search_range_sq:
			candidates.append(enemy)
			
	if candidates.is_empty():
		# 如果没有敌人，在玩家位置生成
		return tree.get_first_node_in_group("player").global_position
		
	# 寻找敌人最密集点
	# 简单算法：遍历每个候选敌人，计算其周围一定半径（例如60，即兑泽基础范围）内的敌人数量
	# 取数量最多的敌人的位置作为中心
	var best_pos = candidates[0].global_position
	var max_count = 0
	var skill_radius = duize_range # 使用当前技能范围
	var skill_radius_sq = skill_radius * skill_radius
	
	for center_candidate in candidates:
		var count = 0
		var pos = center_candidate.global_position
		for other in candidates:
			if pos.distance_squared_to(other.global_position) <= skill_radius_sq:
				count += 1
		
		if count > max_count:
			max_count = count
			best_pos = pos
			
	return best_pos

static func _spawn_duize(scene: PackedScene, tree: SceneTree, target_pos: Vector2) -> void:
	var instance = scene.instantiate()
	tree.current_scene.add_child(instance)
	
	var damage = PC.pc_atk * main_skill_duize_damage * duize_final_damage_multi
	
	instance.setup(target_pos, damage)

func setup(pos: Vector2, p_damage: float) -> void:
	# 确保节点引用存在
	if not sprite:
		print("no sprite")
		sprite = get_node_or_null("AnimatedSprite2D")
	if not collision:
		print("no collision")
		collision = get_node_or_null("CollisionShape2D")
		
	global_position = pos
	damage_per_sec = p_damage
	slow_ratio = duize_slow_ratio
	
	# 升级效果参数初始化
	if PC.selected_rewards.has("Duize2"):
		damage_per_debuff_ratio = 0.3
	if PC.selected_rewards.has("Duize33"):
		damage_per_debuff_ratio = 0.7 # 覆盖 Duize2
		
	if PC.selected_rewards.has("Duize4"):
		apply_corrosion = true
		
	# 范围缩放
	# 默认 scale x1.0 y1.285
	# 默认 collision x3.155 y1.645
	# 基础范围 60. 现在的 range 已经是计算过加成的 duize_range
	# 需要计算 scale_multiplier = duize_range / 60.0
	# 初始兑泽的大小改为现在的3倍
	var scale_multiplier = (duize_range / 60.0) * 3.0
	
	var target_sprite_scale = Vector2(1.0, 1.285) * scale_multiplier
	var target_collision_scale = Vector2(3.155, 1.645) * scale_multiplier
	
	if sprite:
		# 初始状态：极小，但可见
		sprite.scale = Vector2.ZERO
		sprite.modulate.a = 0.75
		
	if collision:
		# 初始状态：极小
		collision.scale = Vector2.ZERO

	# 渐入渐出效果
	var tween = create_tween()
	
	# 渐入：缩放
	tween.set_parallel(true)
	if sprite:
		tween.tween_property(sprite, "scale", target_sprite_scale, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if collision:
		tween.tween_property(collision, "scale", target_collision_scale, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)

	# 保持 (总时间 - 渐入 - 渐出)
	var hold_time = max(0.0, duration - 0.6)
	tween.tween_interval(hold_time)
	# 渐出
	if sprite:
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	# 动画结束后销毁
	tween.finished.connect(queue_free)

func _ready() -> void:
	z_index = -1
	connect("area_entered", Callable(self, "_on_area_entered"))
	connect("area_exited", Callable(self, "_on_area_exited"))
	
	_deal_damage_to_all()

func _process(delta: float) -> void:
	elapsed += delta
	# 移除基于 elapsed 的销毁，改由 tween 控制
	# 但伤害计算仍需基于 damage_timer
		
	damage_timer += delta
	if damage_timer >= damage_interval:
		damage_timer = 0.0
		_deal_damage_to_all()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		if not enemies_in_range.has(area):
			enemies_in_range.append(area)
			_apply_slow(area)
			# 进入时是否施加腐蚀？
			if apply_corrosion:
				_apply_corrosion(area)

func _on_area_exited(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		if enemies_in_range.has(area):
			enemies_in_range.erase(area)
			_remove_slow(area)

func _apply_slow(enemy: Area2D) -> void:
	if enemy.get("debuff_manager") and enemy.debuff_manager.has_method("add_debuff"):
		enemy.debuff_manager.add_debuff("slow")

func _remove_slow(enemy: Area2D) -> void:
	pass

func _apply_corrosion(enemy: Area2D) -> void:
	if enemy.get("debuff_manager") and enemy.debuff_manager.has_method("add_debuff"):
		if PC.selected_rewards.has("Duize11"):
			# Duize11: 腐蚀2 (受到的伤害增加30%)
			enemy.debuff_manager.add_debuff("corrosion2")
		else:
			# Duize4: 腐蚀 (受到的伤害增加20%)
			enemy.debuff_manager.add_debuff("corrosion")

func _deal_damage_to_all() -> void:
	# 遍历当前范围内的敌人造成伤害
	# 由于 enemies_in_range 可能包含已死亡/销毁的实例，需要检查
	for i in range(enemies_in_range.size() - 1, -1, -1):
		var enemy = enemies_in_range[i]
		if not is_instance_valid(enemy):
			enemies_in_range.remove_at(i)
			continue
			
		_deal_single_damage(enemy)

func _deal_single_damage(enemy: Area2D) -> void:
	# 伤害间隔减半后，单次伤害也减半，保持DPS一致
	var final_damage = damage_per_sec * 0.5
	
	# Duize2/33: 异常状态增伤
	if damage_per_debuff_ratio > 0.0:
		if enemy.get("debuff_manager"):
			var debuff_count = 0
			if enemy.debuff_manager.has_method("get_debuff_count"):
				debuff_count = enemy.debuff_manager.get_debuff_count()
			elif "debuffs" in enemy.debuff_manager:
				debuff_count = enemy.debuff_manager.debuffs.size()
			
			if debuff_count > 0:
				final_damage *= (1.0 + debuff_count * damage_per_debuff_ratio)
	
	# 暴击
	var is_crit = false
	if randf() < PC.crit_chance:
		is_crit = true
		final_damage *= PC.crit_damage_multi
		
	if enemy.has_method("take_damage"):
		enemy.take_damage(int(final_damage), is_crit, false, "duize")

func _exit_tree() -> void:
	# 销毁时，移除所有敌人的缓速效果
	for enemy in enemies_in_range:
		_remove_slow(enemy)
