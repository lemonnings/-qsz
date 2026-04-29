extends Area2D

@export var sprite: AnimatedSprite2D
@export var collisionShape: CollisionShape2D

@export var explore: AnimatedSprite2D
@export var exploreShape: CollisionShape2D

# 发射参数
var direction: Vector2 = Vector2.RIGHT
var speed: float = 500.0
var damage_ratio: float = 2.25
var max_distance: float = 800.0

# 内部状态
var _launched: bool = false
var _traveled: float = 0.0
var _exploded: bool = false
var _hit_targets: Dictionary = {} # 爆炸已伤害目标

func _ready():
	# 初始状态：隐藏爆炸动画和爆炸碗形
	if explore:
		explore.visible = false
	if exploreShape:
		exploreShape.disabled = true
	if collisionShape:
		collisionShape.disabled = true
	# 连接弹体碰撞信号
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func launch(dir: Vector2, dmg_ratio: float) -> void:
	"""发射风雷弹"""
	direction = dir.normalized()
	damage_ratio = dmg_ratio
	_launched = true
	# 设置旋转角度（弹体朝向飞行方向）
	rotation = direction.angle()
	# 启用弹体碰撞
	if collisionShape:
		collisionShape.disabled = false
	# 播放弹体动画
	if sprite:
		sprite.play("default")

func _physics_process(delta: float) -> void:
	if not _launched or _exploded:
		return
	# 移动弹体
	var move_amount = direction * speed * delta
	global_position += move_amount
	_traveled += move_amount.length()
	# 超出最大距离后自动爆炸
	if _traveled >= max_distance:
		_trigger_explosion()

func _on_body_entered(body: Node2D) -> void:
	"""弹体击中敌人时触发爆炸"""
	if _exploded:
		return
	if body.is_in_group("enemies") or body.is_in_group("boss"):
		_trigger_explosion()

func _on_area_entered(area: Area2D) -> void:
	"""弹体击中敌人 Area2D 时触发爆炸"""
	if _exploded:
		return
	if area.is_in_group("enemies") or area.is_in_group("boss"):
		_trigger_explosion()

func _trigger_explosion() -> void:
	"""触发大范围爆炸"""
	if _exploded:
		return
	_exploded = true
	_launched = false
	
	# 隐藏弹体，禁用弹体碰撞
	if sprite:
		sprite.visible = false
	if collisionShape:
		collisionShape.disabled = true
	
	# 显示爆炸动画
	if explore:
		explore.visible = true
		explore.frame = 0
		explore.play("default")
	
	# 爆炸震屏 0.5秒
	GU.screen_shake(6.0, 0.5)
	
	# 直接执行爆炸伤害（基于exploreShape半径做距离判定，不依赖物理帧重叠）
	_apply_explosion_damage()
	
	# 爆炸动画播完后销毁
	if explore:
		await explore.animation_finished
	await get_tree().create_timer(0.1).timeout
	queue_free()

func _apply_explosion_damage() -> void:
	"""基于exploreShape半径，对范围内敌人造成伤害"""
	var base_damage = PC.pc_atk * damage_ratio
	var explosion_center = global_position
	
	# 从exploreShape获取爆炸半径
	var explosion_radius: float = 105.0
	if exploreShape and exploreShape.shape is CircleShape2D:
		explosion_radius = (exploreShape.shape as CircleShape2D).radius
	
	# 遍历敌人，距离判定
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue
		var dist = explosion_center.distance_to(enemy.global_position)
		if dist <= explosion_radius:
			var target_id = enemy.get_instance_id()
			if _hit_targets.has(target_id):
				continue
			_hit_targets[target_id] = true
			var final_damage = Global.apply_enemy_damage_bonus(base_damage, enemy)
			enemy.take_damage(int(final_damage), false, false, "wind_thunder")
			Global.emit_signal("monster_damage", 1, final_damage, enemy.global_position - Vector2(16, 6), "wind_thunder")
	
	var bosses = get_tree().get_nodes_in_group("boss")
	for boss in bosses:
		if not is_instance_valid(boss) or not boss.has_method("take_damage"):
			continue
		var dist = explosion_center.distance_to(boss.global_position)
		if dist <= explosion_radius:
			var target_id = boss.get_instance_id()
			if _hit_targets.has(target_id):
				continue
			_hit_targets[target_id] = true
			var final_damage = Global.apply_enemy_damage_bonus(base_damage, boss)
			boss.take_damage(int(final_damage), false, false, "wind_thunder")
			Global.emit_signal("monster_damage", 1, final_damage, boss.global_position - Vector2(16, 6), "wind_thunder")
