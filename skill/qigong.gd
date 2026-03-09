extends Area2D
class_name Qigong

@export var sprite: AnimatedSprite2D
@export var collision: CollisionShape2D
@export var explore_sprite: AnimatedSprite2D
@export var explore_collision: CollisionShape2D

# 静态变量，由升级系统修改
static var main_skill_qigong_damage: float = 1.0 # 伤害倍率
static var qigong_splash_damage_ratio: float = 0.3 # 溅射伤害比例
static var qigong_speed: float = 300.0 # 飞行速度
static var qigong_range: float = 150.0 # 射程（飞行距离）
static var qigong_explore_range_scale: float = 1.0 # 爆炸范围缩放
static var qigong_knockback: float = 0.0 # 击退力度
static var qigong_electrified_damage: float = 0.0 # 感电伤害倍率 (0表示无感电)
static var qigong_electrified_chance: float = 0.0 # 感电概率
static var qigong_double_hit_chance: float = 0.0 # 连发概率
static var qigong_triple_hit_chance: float = 0.0 # 三连发概率
static var qigong_double_hit_damage_multiplier: float = 0.7 # 第二发伤害倍率
static var qigong_triple_hit_damage_multiplier: float = 0.56 # 第三发伤害倍率
static var qigong_chakra_count: int = 0 # 脉轮数量（其他武器数量）
static var qigong_electrified_bonus_damage: float = 0.0 # 对感电目标的额外伤害倍率
static var qigong_distance_bonus: bool = false # 是否启用距离伤害加成
static var qigong_size_scale: float = 1.0 # 弹体大小缩放
static var qigong_electrified_splash_damage_ratio: float = 0.0 # 感电目标溅射伤害倍率

var velocity: Vector2 = Vector2.ZERO
var traveled_distance: float = 0.0
var target_enemy: Area2D = null
var damage: int = 0
var is_exploding: bool = false
var start_position: Vector2

func _ready() -> void:
	# 连接区域进入信号
	connect("area_entered", Callable(self, "_on_area_entered"))
	
	# 初始化时不显示爆炸效果
	if explore_sprite:
		explore_sprite.hide()
	if explore_collision:
		explore_collision.disabled = true
		
	# 播放飞行子弹动画
	if sprite:
		sprite.play("default") # 假设默认动画名为default

func setup(start_pos: Vector2, direction: Vector2, base_damage: int, damage_multiplier: float = 1.0) -> void:
	global_position = start_pos
	start_position = start_pos
	velocity = direction.normalized() * qigong_speed
	rotation = direction.angle()
	sprite.flip_h = true
	
	# 计算脉轮加成
	var chakra_dmg_bonus = 0.0
	var chakra_range_bonus = 0.0
	var chakra_size_bonus = 0.0
	
	if qigong_chakra_count > 0:
		chakra_dmg_bonus = qigong_chakra_count * Qigong.per_chakra_damage_rate
		chakra_range_bonus = qigong_chakra_count * Qigong.per_chakra_range_rate
		chakra_size_bonus = qigong_chakra_count * Qigong.per_chakra_size_rate
	
	var final_damage_scale = main_skill_qigong_damage + chakra_dmg_bonus
	damage = int(base_damage * final_damage_scale * damage_multiplier * Faze.get_wind_weapon_damage_multiplier(PC.faze_wind_level))
	
	# 应用射程加成 (修改实例变量，不修改静态变量)
	# 注意：qigong_range是静态的，我们在process里用。
	# 这里我们需要一个实例变量 range_limit
	range_limit = qigong_range * (1.0 + chakra_range_bonus)
	
	# 应用大小加成
	var total_scale = (1.0 + chakra_size_bonus) * qigong_size_scale
	scale = Vector2(total_scale, total_scale)

var range_limit: float = 150.0
static var per_chakra_damage_rate: float = 0.2
static var per_chakra_range_rate: float = 0.1
static var per_chakra_size_rate: float = 0.1
static var per_chakra_splash_range_rate: float = 0.0
static var qigong_electrified_splash_range_bonus: bool = false # 是否启用感电目标溅射范围加成

static func sync_reward_modifiers() -> void:
	# 根据已选择的奖励同步气功波属性
	main_skill_qigong_damage = 1.0
	qigong_splash_damage_ratio = 0.3
	qigong_explore_range_scale = 1.0
	qigong_knockback = 0.0
	qigong_electrified_chance = 0.0
	qigong_double_hit_chance = 0.0
	qigong_triple_hit_chance = 0.0
	qigong_double_hit_damage_multiplier = 0.7
	qigong_triple_hit_damage_multiplier = 0.56
	qigong_chakra_count = 0
	qigong_electrified_bonus_damage = 0.0
	qigong_distance_bonus = false
	qigong_size_scale = 1.0
	qigong_electrified_splash_damage_ratio = 0.0
	per_chakra_damage_rate = 0.2
	per_chakra_range_rate = 0.1
	per_chakra_size_rate = 0.1
	per_chakra_splash_range_rate = 0.0
	qigong_electrified_splash_range_bonus = false
	
	var total_damage_bonus = 0.0
		
	if PC.selected_rewards.has("Qigong1"):
		total_damage_bonus += 0.3
		qigong_electrified_chance = 1.0
		
	if PC.selected_rewards.has("Qigong2"):
		total_damage_bonus += 0.7
		qigong_knockback = 1.0
		
	if PC.selected_rewards.has("Qigong3"):
		total_damage_bonus += 0.4
		qigong_size_scale = 1.3
		qigong_explore_range_scale = 1.3
		qigong_splash_damage_ratio = 0.4
		
	if PC.selected_rewards.has("Qigong4"):
		total_damage_bonus += 0.3
		qigong_double_hit_chance = 0.4
		qigong_double_hit_damage_multiplier = 0.7
		
	var has_qigong5 = PC.selected_rewards.has("Qigong5")
	var has_qigong11 = PC.selected_rewards.has("Qigong11")
	if has_qigong5 or has_qigong11:
		total_damage_bonus += 0.5
		qigong_chakra_count = PC.current_weapon_num - 1
		per_chakra_damage_rate = 0.2
		per_chakra_range_rate = 0.1
		per_chakra_size_rate = 0.1
		
	if has_qigong11:
		total_damage_bonus += 0.7
		per_chakra_damage_rate = 0.3
		per_chakra_splash_range_rate = 0.1
		
	if PC.selected_rewards.has("Qigong22"):
		total_damage_bonus += 0.5
		qigong_electrified_bonus_damage = 0.8
		
	if PC.selected_rewards.has("Qigong33"):
		total_damage_bonus += 0.7
		qigong_triple_hit_chance = 0.4
		qigong_triple_hit_damage_multiplier = 0.56
		
	if PC.selected_rewards.has("Qigong44"):
		total_damage_bonus += 0.5
		qigong_electrified_splash_range_bonus = true
		qigong_electrified_splash_damage_ratio = 0.5
		
	if PC.selected_rewards.has("Qigong55"):
		total_damage_bonus += 0.6
		qigong_distance_bonus = true
		
	main_skill_qigong_damage += total_damage_bonus

func _physics_process(delta: float) -> void:
	if is_exploding:
		return
		
	var movement = velocity * delta
	position += movement
	traveled_distance += movement.length()
	
	if traveled_distance >= range_limit:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if is_exploding:
		return
		
	if area.is_in_group("enemies"): # 假设敌人都在enemies组
		_trigger_explosion(area)

func _trigger_explosion(direct_hit_target: Area2D) -> void:
	is_exploding = true
	velocity = Vector2.ZERO
	
	# 隐藏飞行子弹
	if sprite:
		sprite.hide()
	if collision:
		collision.set_deferred("disabled", true)
		
	# 对直接命中的目标造成伤害
	var hit_target_electrified = false
	if direct_hit_target and is_instance_valid(direct_hit_target) and direct_hit_target.has_method("take_damage"):
		if direct_hit_target.get("debuff_manager") and direct_hit_target.debuff_manager.has_debuff("electrified"):
			hit_target_electrified = true
		_apply_damage(direct_hit_target, damage, true)
		
		# 击退效果
		if qigong_knockback > 0 and direct_hit_target.has_method("apply_knockback"):
			# Qigong2/55: 距离越近击退越远
			var dist = global_position.distance_to(start_position) 
			var knockback_force = _get_knockback_force(dist)
			var knockback_dir = (direct_hit_target.global_position - start_position).normalized()
			direct_hit_target.apply_knockback(knockback_dir, knockback_force)
			
	# 显示爆炸效果
	if explore_sprite:
		explore_sprite.show()
		
		# 计算爆炸范围
		var current_explore_scale = qigong_explore_range_scale
		if qigong_chakra_count > 0 and per_chakra_splash_range_rate > 0:
			var chakra_splash_bonus = 1.0 + qigong_chakra_count * per_chakra_splash_range_rate
			current_explore_scale = current_explore_scale * chakra_splash_bonus
		
		# Qigong44: 击中感电目标，溅射范围+30%
		if qigong_electrified_splash_range_bonus and hit_target_electrified:
			current_explore_scale *= 1.3
		
		explore_sprite.scale = explore_sprite.scale * current_explore_scale
		
		# 播放爆炸动画
		explore_sprite.play("default")
		if not explore_sprite.is_connected("animation_finished", Callable(self, "_on_explosion_finished")):
			explore_sprite.connect("animation_finished", Callable(self, "_on_explosion_finished"))
		
		# 启用爆炸范围检测
		if explore_collision:
			explore_collision.scale = explore_collision.scale * current_explore_scale
			explore_collision.set_deferred("disabled", false)
			
			# 延迟一帧检测范围内的敌人
			call_deferred("_check_splash_damage", direct_hit_target, hit_target_electrified, direct_hit_target.global_position)
			
	else:
		# 如果没有爆炸动画节点，直接销毁
		queue_free()

func _on_explosion_finished() -> void:
	queue_free()

func _check_splash_damage(exclude_target: Area2D, is_electrified_target: bool, main_target_position: Vector2) -> void:
	# 等待物理帧刷新重叠信息
	await get_tree().physics_frame
	# 获取当前Area2D重叠的所有区域（此时explore_collision已启用）
	var overlapping_areas = get_overlapping_areas()
	
	var current_splash_ratio = qigong_splash_damage_ratio
	if is_electrified_target and qigong_electrified_splash_damage_ratio > 0:
		current_splash_ratio = qigong_electrified_splash_damage_ratio	
	
	var splash_damage = int(damage * current_splash_ratio)
	
	for area in overlapping_areas:
		if area.is_in_group("enemies") and area.has_method("take_damage"):
			if area == exclude_target:
				continue
			_apply_damage(area, splash_damage, false)
			_apply_splash_knockback(area, main_target_position)
		elif area.get_parent().is_in_group("enemies") and area.get_parent().has_method("take_damage"):
			if area.get_parent() == exclude_target:
				continue
			_apply_damage(area.get_parent(), splash_damage, false)
			_apply_splash_knockback(area.get_parent(), main_target_position)

func _apply_damage(target: Area2D, dmg: int, is_direct_hit: bool) -> void:
	var final_dmg = dmg
	
	# Qigong55: 距离伤害加成
	if qigong_distance_bonus:
		var dist = global_position.distance_to(start_position)
		var bonus_ratio = 0.2
		if dist < 20:
			bonus_ratio = 1.0
		elif dist < 150:
			bonus_ratio = 0.5
		
		final_dmg = int(final_dmg * (1.0 + bonus_ratio))
	
	# Qigong44: 对感电目标造成额外80%伤害
	if qigong_electrified_bonus_damage > 0:
		if target.get("debuff_manager") and target.debuff_manager.has_debuff("electrified"):
			final_dmg = int(final_dmg * (1.0 + qigong_electrified_bonus_damage))
	
	if target.is_in_group("elite") or target.is_in_group("boss"):
		final_dmg = int(final_dmg * Faze.get_wind_elite_boss_multiplier(PC.faze_wind_level, PC.wind_huanfeng_stacks))
	target.take_damage(final_dmg, false, false, "")
	Faze.on_wind_weapon_hit()
	
	# Qigong1: 获得感电效果 (攻击有15%几率使敌人感电)
	if qigong_electrified_chance > 0:
		if randf() < qigong_electrified_chance:	
			if target.get("debuff_manager"):
				target.debuff_manager.add_debuff("electrified")

func _get_knockback_force(distance_to_player: float) -> float:
	if distance_to_player < 20:
		return 15.0
	if distance_to_player < 150:
		return 10.0
	return 5.0

func _apply_splash_knockback(target: Node2D, main_target_position: Vector2) -> void:
	if qigong_knockback <= 0:
		return
	if not target.has_method("apply_knockback"):
		return
	var dist = start_position.distance_to(target.global_position)
	var knockback_force = _get_knockback_force(dist)
	var knockback_dir = (target.global_position - main_target_position).normalized()
	target.apply_knockback(knockback_dir, knockback_force)
