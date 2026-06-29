extends Area2D

## 炽炎：在目标位置释放炽炎，对其中的敌人造成伤害

@export var sprite: AnimatedSprite2D
@export var collisionShape: CollisionShape2D

var damage_ratio: float = 2.2
var _activated: bool = false
var _hit_targets: Dictionary = {}

func _ready():
	# 初始状态：隐藏动画，禁用碰撞，停止autoplay
	if sprite:
		sprite.visible = false
		sprite.stop()
	if collisionShape:
		collisionShape.disabled = true

func activate(dmg_ratio: float) -> void:
	"""激活炽炎效果"""
	damage_ratio = dmg_ratio
	_activated = true
	var range_multiplier: float = Global.get_attack_range_multiplier()
	
	# 显示爆炸效果动画
	if sprite:
		sprite.visible = true
		sprite.scale *= range_multiplier
		sprite.stop()
		sprite.frame = 0
		sprite.play("default")
		sprite.animation_finished.connect(_on_animation_finished, CONNECT_ONE_SHOT)
	
	# 小震屏
	GU.screen_shake(3.0, 0.3)
	
	# 对范围内敌人造成伤害
	_apply_area_damage()
	
	# 无动画时直接销毁
	if not sprite:
		await get_tree().create_timer(0.2).timeout
		queue_free()

func _on_animation_finished() -> void:
	"""动画播完后延迟销毁"""
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self ):
		queue_free()

func _apply_area_damage() -> void:
	"""对范围内敌人造成伤害"""
	# 修习树技能篇：应用技能总伤害加成
	var base_damage = PC.pc_atk * damage_ratio * (1.0 + PC.active_skill_multi)
	var center = global_position
	
	# 从 collisionShape 获取效果半径
	var effect_radius: float = 105.0
	if collisionShape and collisionShape.shape:
		if collisionShape.shape is CircleShape2D:
			effect_radius = (collisionShape.shape as CircleShape2D).radius
		elif collisionShape.shape is CapsuleShape2D:
			effect_radius = (collisionShape.shape as CapsuleShape2D).height * 0.5
	effect_radius *= Global.get_attack_range_multiplier()
	
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
			enemy.take_damage(int(base_damage), false, false, "magical_fire")
	
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
			boss.take_damage(int(base_damage), false, false, "magical_fire")
