extends Area2D

var damage: float = 0.0
var hit_cooldown: float = 0.3
var hit_cooldowns: Dictionary = {}

func _ready() -> void:
	# 设置碰撞检测
	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 10.0  # 火焰的碰撞范围
	collision_shape.shape = circle_shape
	add_child(collision_shape)

	# 创建火焰精灵
	var sprite = Sprite2D.new()
	# TODO: 使用实际的火焰贴图
	sprite.texture = preload("res://icon.svg")  # 临时使用默认图标
	sprite.scale = Vector2(0.3, 0.3)  # 调整大小
	add_child(sprite)

	# 连接碰撞信号
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	# 更新冷却时间
	var to_remove = []
	for enemy in hit_cooldowns.keys():
		hit_cooldowns[enemy] -= delta
		if hit_cooldowns[enemy] <= 0:
			to_remove.append(enemy)
	
	for enemy in to_remove:
		hit_cooldowns.erase(enemy)

func _on_area_entered(area: Area2D) -> void:
	# 检查是否是敌人
	if area.is_in_group("enemy"):
		# 检查该火焰实例是否对这个敌人在冷却中
		if not hit_cooldowns.has(area) or hit_cooldowns[area] <= 0:
			# 造成伤害
			if area.has_method("take_damage"):
				area.take_damage(damage)
				# 设置该火焰实例对这个敌人的冷却时间
				hit_cooldowns[area] = hit_cooldown