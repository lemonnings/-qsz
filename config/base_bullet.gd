extends Area2D

@export var bullet_speed: float = 575
@export var bullet_range: float = PC.swordQi_range  # 子弹射程
@export var penetration_count: int = 1  # 穿透次数，默认为1

# 子弹的伤害和暴击状态（在创建时确定）
var bullet_damage: float = 0.0
var is_crit_hit: bool = false

# 射程和渐隐相关变量
var start_position: Vector2  # 子弹起始位置
var traveled_distance: float = 0.0  # 已飞行距离 
var is_fading: bool = false  # 是否正在渐隐
var fade_timer: float = 0.0  # 渐隐计时器
var fade_duration: float = 0.1  # 渐隐持续时间（秒） 

@export var sprite : Sprite2D  # 获取精灵节点引用
@export var sprite_summon :Sprite2D  # 获取精灵节点引用
@export var collision_shape :CollisionShape2D  # 获取碰撞形状节点引用

var direction: Vector2

var is_summon_bullet: bool = false  # 标记是否为额外发射的剑气
var is_other_sword_wave: bool = false  # 标记是否为额外发射的剑气

var is_rebound: bool = false  # 标记是否为反弹子弹
var parent_bullet: bool = true  # 标记是否为父级子弹，默认为true

# 用于防止同一帧内多次处理碰撞
var collision_processed_this_frame: bool = false
var current_frame: int = -1

func _ready() -> void:
	# 记录子弹起始位置
	start_position = global_position
	
	# 初始化子弹伤害和暴击状态
	initialize_bullet_damage()
	
	# 初始化碰撞形状大小
	update_collision_shape_size()
	
	# 自动销毁
	await get_tree().create_timer(3).timeout
	if !Global.is_level_up:
		queue_free()

	# 初始化时设置精灵方向
	sprite_summon.visible = false
	_update_sprite_rotation()

func _physics_process(delta: float) -> void:
	# 子弹始终保持移动（包括渐隐过程中）
	position += direction * bullet_speed * delta
	# 更新已飞行距离
	traveled_distance = start_position.distance_to(global_position)
	
	# 检查是否超出射程，开始渐隐
	if not is_fading and traveled_distance >= bullet_range:
		start_fade_out()
	
	# 更新精灵旋转以匹配移动方向
	_update_sprite_rotation()
	
	# 处理渐隐动画（子弹边飞边消失）
	if is_fading:
		fade_timer += delta
		var fade_progress = fade_timer / fade_duration
		
		# 计算透明度（从1.0渐变到0.0）
		var alpha = 1.0 - fade_progress
		
		# 应用透明度到精灵
		if sprite:
			sprite.modulate.a = alpha
		if sprite_summon:
			sprite_summon.modulate.a = alpha
		
		# 当透明度低于0.2时禁用碰撞
		if alpha < 0.2 and collision_shape and not collision_shape.disabled:
			collision_shape.set_deferred("disabled", true)
		
		# 渐隐完成后销毁子弹
			if fade_progress >= 1.0:
				queue_free()

# 开始渐隐动画
func start_fade_out() -> void:
	if not is_fading:
		is_fading = true
		fade_timer = 0.0
		

# 更新精灵旋转以匹配移动方向
func _update_sprite_rotation() -> void:
	if direction != Vector2.ZERO:
		# 计算方向向量的角度（弧度）
		var angle = direction.angle()
		# 设置精灵旋转
		sprite.rotation = angle

# 设置子弹方向并立即更新旋转
func set_direction(new_direction: Vector2) -> void:
	direction = new_direction
	_update_sprite_rotation()  # 立即更新旋转，避免第一帧显示错误方向

# 初始化子弹的伤害和暴击状态
func initialize_bullet_damage() -> void:
	var base_damage: float
	var can_crit: bool = true
	
	if is_other_sword_wave:
		base_damage = PC.pc_atk # * PC.swordQi_other_sword_wave_damage * PC.main_skill_swordQi_damage 
	else:
		base_damage = PC.pc_atk # * PC.main_skill_swordQi_damage 

	is_crit_hit = false
	bullet_damage = base_damage

	if can_crit:
		if randf() < PC.crit_chance:
			is_crit_hit = true
			bullet_damage *= PC.crit_damage_multiplier

# 获取子弹的实际伤害，并返回是否暴击
func get_bullet_damage_and_crit_status() -> Dictionary: # Returns {"damage": float, "is_crit": bool}
	return {"damage": bullet_damage, "is_crit": is_crit_hit, "is_summon_bullet": is_summon_bullet}

# 处理子弹穿透逻辑，返回是否应该销毁子弹
# 如果返回false，表示这一帧已经处理过碰撞，应该忽略当前碰撞
func handle_penetration() -> bool:
	var frame = Engine.get_process_frames()
	if PC.swordQi_penetration_count > 1 and !PC.selected_rewards.has("SplitSwordQi32"):
		var now_penetration_count = PC.swordQi_penetration_count - penetration_count + 1
		bullet_damage = bullet_damage * (1 - (0.15 * now_penetration_count))
	# 如果是新的一帧，重置处理标志
	if frame != current_frame:
		current_frame = frame
		collision_processed_this_frame = false
	
	# 如果这一帧已经处理过碰撞，忽略后续碰撞
	if collision_processed_this_frame:
		return false  # 返回false表示忽略这次碰撞

		
	# 标记这一帧已经处理过碰撞
	collision_processed_this_frame = true
	
	# 减少穿透计数
	penetration_count -= 1
	
	return true

# 设置子弹速度
func set_speed(new_speed: float) -> void:
	bullet_speed = new_speed

# 更新碰撞形状大小以匹配精灵缩放
func update_collision_shape_size() -> void:
	if collision_shape and collision_shape.shape:
		# 获取当前的缩放值
		var current_scale = scale

# 当子弹击中敌人时，生成子级反弹子弹
func create_rebound() -> void:
	if parent_bullet and not is_rebound:  # 只有父级子弹且非反弹子弹才能反弹
		var bullet_bound_num = PC.selected_rewards.count("rebound_num_up")
		# 创建1-3个随机方向的子级子弹
		var num_bullets = randi_range(1, (1 + bullet_bound_num* 0.5))
		for i in range(num_bullets):
			var child_bullet = load("res://Scenes/bullet.tscn").instantiate()
			# 设置子级子弹属性
			scale = scale * PC.rebound_size_multiplier
			update_collision_shape_size()  # 使用新函数同步更新碰撞形状
			child_bullet.is_rebound = true
			child_bullet.parent_bullet = false  # 标记为子级子弹，防止无限反弹
			# 随机方向
			var random_angle = randf_range(0, 2 * PI)
			child_bullet.direction = Vector2(cos(random_angle), sin(random_angle))
			# 设置位置（与当前子弹位置相同）
			child_bullet.position = position
			
			# 添加到场景
			get_tree().current_scene.add_child(child_bullet)

# 寻找最近的敌人
func find_nearest_enemy() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	
	var nearest_enemy = null
	var nearest_distance = INF
	
	for enemy in enemies:
		var distance = global_position.distance_to(enemy.global_position)
		if enemy and is_instance_valid(enemy) and enemy.has_method("_on_area_entered"):
			if  distance < nearest_distance:
				nearest_distance = distance
				nearest_enemy = enemy
