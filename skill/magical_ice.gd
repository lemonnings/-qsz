extends Area2D

## 玄冰阵：在目标位置释放冰冻范围攻击，对其中敌人造成伤害并减速

@export var sprite: AnimatedSprite2D
@export var collisionShape: CollisionShape2D

@export var explore: AnimatedSprite2D
@export var exploreShape: CollisionShape2D

var damage_ratio: float = 4.0
var _activated: bool = false
var _hit_targets: Dictionary = {}

func _ready():
	# 初始状态：隐藏主体动画，禁用碰撞，停止autoplay
	if sprite:
		sprite.visible = false
		sprite.stop()
	if collisionShape:
		collisionShape.disabled = true
	if explore:
		explore.visible = false
		explore.stop()
	if exploreShape:
		exploreShape.disabled = true

func activate(dmg_ratio: float) -> void:
	"""激活玄冰阵效果"""
	damage_ratio = dmg_ratio
	_activated = true
	
	# 显示爆炸/冰冻效果动画
	if explore:
		explore.visible = true
		explore.stop()
		explore.frame = 0
		explore.play("default")
		explore.animation_finished.connect(_on_explore_finished, CONNECT_ONE_SHOT)
	
	# 小震屏
	GU.screen_shake(4.0, 0.4)
	
	# 对范围内敌人造成伤害并减速
	_apply_area_damage()
	_apply_slow_debuff()
	
	# 无动画时直接销毁
	if not explore:
		await get_tree().create_timer(0.2).timeout
		queue_free()

func _on_explore_finished() -> void:
	"""动画播完后延迟销毁"""
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self ):
		queue_free()

func _apply_area_damage() -> void:
	"""对范围内敌人造成伤害"""
	# 修习树技能篇：应用技能总伤害加成
	var base_damage = PC.pc_atk * damage_ratio * (1.0 + Global.study_skill_damage_bonus)
	var center = global_position
	
	# 从 exploreShape 获取爆炸半径
	var effect_radius: float = 105.0
	if exploreShape and exploreShape.shape:
		if exploreShape.shape is CircleShape2D:
			effect_radius = (exploreShape.shape as CircleShape2D).radius
		elif exploreShape.shape is CapsuleShape2D:
			effect_radius = (exploreShape.shape as CapsuleShape2D).height * 0.5
	# 修习树技能篇：玄冰范围加成
	effect_radius *= (1.0 + Global.study_xuanbing_size_bonus)
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue
		var dist = center.distance_to(enemy.global_position)
		if dist <= effect_radius:
			var target_id = enemy.get_instance_id()
			if _hit_targets.has(target_id):
				continue
			_hit_targets[target_id] = true
			enemy.take_damage(int(base_damage), false, false, "magical_ice")
	
	var bosses = get_tree().get_nodes_in_group("boss")
	for boss in bosses:
		if not is_instance_valid(boss) or not boss.has_method("take_damage"):
			continue
		var dist = center.distance_to(boss.global_position)
		if dist <= effect_radius:
			var target_id = boss.get_instance_id()
			if _hit_targets.has(target_id):
				continue
			_hit_targets[target_id] = true
			boss.take_damage(int(base_damage), false, false, "magical_ice")

func _apply_slow_debuff() -> void:
	"""对范围内敌人施加减速"""
	var center = global_position
	var effect_radius: float = 105.0
	if exploreShape and exploreShape.shape:
		if exploreShape.shape is CircleShape2D:
			effect_radius = (exploreShape.shape as CircleShape2D).radius
		elif exploreShape.shape is CapsuleShape2D:
			effect_radius = (exploreShape.shape as CapsuleShape2D).height * 0.5
	# 修习树技能篇：玄冰范围加成
	effect_radius *= (1.0 + Global.study_xuanbing_size_bonus)
	
	var all_targets = []
	all_targets.append_array(get_tree().get_nodes_in_group("enemies"))
	all_targets.append_array(get_tree().get_nodes_in_group("boss"))
	
	for target in all_targets:
		if not is_instance_valid(target):
			continue
		var dist = center.distance_to(target.global_position)
		if dist <= effect_radius:
			if target.has_signal("debuff_applied"):
				target.emit_signal("debuff_applied", "slow")
