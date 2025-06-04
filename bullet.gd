extends Area2D

@export var bullet_speed: float = 350
var direction: Vector2
var is_rebound: bool = false  # 标记是否为反弹子弹
var parent_bullet: bool = true  # 标记是否为父级子弹，默认为true
var is_ring_bullet: bool = false  # 标记是否为环形子弹
var ring_bullet_damage_multiplier: float = 1.0  # 环形子弹伤害倍数
var is_summon_bullet: bool = false  # 标记是否为召唤物子弹
var summon_damage: float = 0.0  # 召唤物子弹伤害
var if_summon: bool = false 
@export var sprite :Sprite2D  # 获取精灵节点引用
@export var sprite_summon :Sprite2D  # 获取精灵节点引用
@export var collision_shape :CollisionShape2D  # 获取碰撞形状节点引用

func _ready() -> void:
	# 初始化子弹伤害和暴击状态
	initialize_bullet_damage()
	
	# 初始化碰撞形状大小
	update_collision_shape_size()
	
	await get_tree().create_timer(3).timeout
	if !Global.is_level_up:
		queue_free()
	# 初始化时设置精灵方向
	sprite_summon.visible = false
	_update_sprite_rotation()

func _physics_process(delta: float) -> void:
	if if_summon:
		sprite.visible = false
		sprite_summon.visible = true
	position += direction * bullet_speed * delta
	# 更新精灵旋转以匹配移动方向
	_update_sprite_rotation()

# 更新精灵旋转以匹配移动方向
func _update_sprite_rotation() -> void:
	if direction != Vector2.ZERO:
		# 计算方向向量的角度（弧度）
		var angle = direction.angle()
		# 设置精灵旋转（Godot中，0弧度是指向右的，所以不需要额外调整）
		# 召唤物子弹的旋转角度在创建时已经设置，不需要重复设置
		if not if_summon:
			sprite.rotation = angle
		else:
			# 召唤物子弹使用创建时设置的旋转角度
			pass

# 设置子弹方向并立即更新旋转
func set_direction(new_direction: Vector2) -> void:
	direction = new_direction
	_update_sprite_rotation()  # 立即更新旋转，避免第一帧显示错误方向

# 设置环形子弹伤害倍数
func set_ring_bullet_damage(damage_multiplier: float) -> void:
	is_ring_bullet = true
	ring_bullet_damage_multiplier = damage_multiplier

# 子弹的伤害和暴击状态（在创建时确定）
var bullet_damage: float = 0.0
var is_crit_hit: bool = false

# 初始化子弹的伤害和暴击状态
func initialize_bullet_damage() -> void:
	var base_damage: float
	var can_crit: bool = not is_summon_bullet # 召唤物子弹不参与暴击

	if is_summon_bullet:
		base_damage = summon_damage
	elif is_ring_bullet:
		base_damage = PC.pc_atk * ring_bullet_damage_multiplier
	else:
		base_damage = PC.pc_atk

	is_crit_hit = false
	bullet_damage = base_damage

	if can_crit:
		if randf() < PC.crit_chance:
			is_crit_hit = true
			bullet_damage *= PC.crit_damage_multiplier

# 获取子弹的实际伤害，并返回是否暴击
func get_bullet_damage_and_crit_status() -> Dictionary: # Returns {"damage": float, "is_crit": bool}
	return {"damage": bullet_damage, "is_crit": is_crit_hit, "is_summon_bullet": is_summon_bullet}

# 设置子弹速度
func set_speed(new_speed: float) -> void:
	bullet_speed = new_speed

# 更新碰撞形状大小以匹配精灵缩放
func update_collision_shape_size() -> void:
	if collision_shape and collision_shape.shape:
		# 获取当前的缩放值
		var current_scale = scale
		
		# 如果是RectangleShape2D
		if collision_shape.shape is RectangleShape2D:
			var rect_shape = collision_shape.shape as RectangleShape2D
			# 设置新的大小，基于原始大小和当前缩放
			var original_size = Vector2(16, 10)  # 原始碰撞形状大小
			rect_shape.size = original_size * current_scale
		
		# 如果是CircleShape2D
		elif collision_shape.shape is CircleShape2D:
			var circle_shape = collision_shape.shape as CircleShape2D
			# 设置新的半径，基于原始半径和当前缩放的平均值
			var original_radius = 8.0  # 原始碰撞形状半径
			circle_shape.radius = original_radius * ((current_scale.x + current_scale.y) / 2.0)

# 设置子弹缩放并同步更新碰撞形状
func set_bullet_scale(new_scale: Vector2) -> void:
	scale = new_scale
	update_collision_shape_size()

# 当子弹击中敌人时，生成子级反弹子弹
func create_rebound() -> void:
	if parent_bullet and not is_rebound:  # 只有父级子弹且非反弹子弹才能反弹
		var bullet_bound_num = PC.selected_rewards.count("rebound_num_up")
		# 创建1-3个随机方向的子级子弹
		var num_bullets = randi_range(1, (1 + bullet_bound_num* 0.5))
		for i in range(num_bullets):
			var child_bullet = load("res://Scenes/bullet.tscn").instantiate()
			# 设置子级子弹属性
			child_bullet.set_bullet_scale(scale * PC.rebound_size_multiplier)  # 使用新函数同步更新碰撞形状
			child_bullet.is_rebound = true
			child_bullet.parent_bullet = false  # 标记为子级子弹，防止无限反弹
			# 随机方向
			var random_angle = randf_range(0, 2 * PI)
			child_bullet.direction = Vector2(cos(random_angle), sin(random_angle))
			# 设置位置（与当前子弹位置相同）
			child_bullet.position = position
			
			# 添加到场景
			get_tree().current_scene.add_child(child_bullet)
