extends Area2D

@export var bullet_speed: float = 325
@export var bullet_fisson: float = 1
@export var bullet_range: float = PC.branch_range # 子弹射程
@export var penetration_count: int = 999

# 子弹的伤害和暴击状态（在创建时确定）
var bullet_damage: float = 0.0
var is_crit_hit: bool = false

# 射程和渐隐相关变量
var start_position: Vector2 # 子弹起始位置
var traveled_distance: float = 0.0 # 已飞行距离
var is_fading: bool = false # 是否正在渐隐
var is_half_split: bool = false
var fade_timer: float = 0.0 # 渐隐计时器
var fade_duration: float = 0.2 # 渐隐持续时间（秒）
@export var sprite: Sprite2D # 获取精灵节点引用
@export var collision_shape: CollisionShape2D # 获取碰撞形状节点引用

var direction: Vector2

var is_rebound: bool = false # 标记是否为反弹子弹
var parent_bullet: bool = true # 标记是否为父级子弹，默认为true
var grandson_bullet: bool = false # 标记是否为孙级子弹

func _ready() -> void:
	# 记录子弹起始位置
	start_position = global_position
	
	# 初始化子弹伤害和暴击状态
	initialize_bullet_damage()
		
	# 初始化碰撞形状大小
	update_collision_shape_size()
	
	# 连接区域进入信号
	area_entered.connect(_on_area_entered)
	
	await get_tree().create_timer(3).timeout
	if !Global.is_level_up:
		queue_free()
	# 初始化时设置精灵方向
	_update_sprite_rotation()

func _physics_process(delta: float) -> void:
	# 子弹始终保持移动（包括渐隐过程中）
	position += direction * bullet_speed * delta
	# 更新已飞行距
	traveled_distance = start_position.distance_to(global_position)
	# 树枝22: 每飞行0.2米，伤害提升2%
	if PC.selected_rewards.has("branch22"):
		var distance_meters = traveled_distance * 0.04
		var damage_increase_multiplier = 1.0 + floor(distance_meters / 0.2) * 0.02
		bullet_damage *= damage_increase_multiplier

	# 树枝1: 行进至射程一半时分裂(视觉上提前一点分裂)
	if PC.selected_rewards.has("branch1") and not is_fading and traveled_distance >= bullet_range / 2.25 and not is_half_split:
		is_half_split = true
		_create_sword_wave_instance(global_position)
		# 防止重复分裂
		#PC.selected_rewards.erase("branch1")

	# 检查是否超出射程
	if not is_fading and traveled_distance >= bullet_range:
		if parent_bullet: # 只有父级子弹才会在射程终点分裂
			_create_sword_wave_instance(global_position)
		# 树枝11: 到达最大射程后返回
		if PC.selected_rewards.has("branch11") and not is_rebound:
			is_rebound = true
			var player = get_tree().get_first_node_in_group("player")
			if player:
				direction = (player.global_position - global_position).normalized()
				start_position = global_position # 重置起始位置以计算返回距离
				traveled_distance = 0
				# 重新设置射程为到玩家的距离
				bullet_range = global_position.distance_to(player.global_position)
			else:
				start_fade_out()
		# 树枝12: 分裂的子枝在达到最大射程后，会向随机方向再射出一个孙枝，造成同等伤害但不会触发分裂与多重分裂-返
		elif PC.selected_rewards.has("branch12") and not parent_bullet and not grandson_bullet:
			# 创建孙枝
			var grandson_bullet = load("res://Scenes/branch.tscn").instantiate()
			grandson_bullet.direction = Vector2.from_angle(randf() * 2 * PI) # 随机方向
			grandson_bullet.global_position = global_position
			grandson_bullet.parent_bullet = false # 孙枝也不会分裂
			grandson_bullet.is_rebound = true # 避免多重分裂-返效果
			grandson_bullet.bullet_damage = bullet_damage # 继承当前伤害
			grandson_bullet.grandson_bullet = true # 标记为孙级子弹
			get_parent().add_child(grandson_bullet)
			start_fade_out()
		else:
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
		# 不立即禁用碰撞，等透明度低于0.2时再禁用
		

# 更新精灵旋转以匹配移动方向
func _update_sprite_rotation() -> void:
	if direction != Vector2.ZERO:
		# 计算方向向量的角度（弧度）
		var angle = direction.angle()
		sprite.rotation = angle

# 设置子弹方向并立即更新旋转
func set_direction(new_direction: Vector2) -> void:
	direction = new_direction
	_update_sprite_rotation() # 立即更新旋转，避免第一帧显示错误方向

# 初始化子弹的伤害和暴击状态
func initialize_bullet_damage() -> void:
	var base_damage: float
	base_damage = PC.pc_atk * PC.main_skill_branch_damage
	bullet_fisson = 1

	var crit_chance_bonus = 0.0
	if PC.selected_rewards.has("branch4"):
		crit_chance_bonus += 0.20

	is_crit_hit = false
	bullet_damage = base_damage * 0.4 # 基础伤害40%

	if randf() < (PC.crit_chance + crit_chance_bonus):
		is_crit_hit = true
		bullet_damage *= PC.crit_damage_multi

# 获取子弹的实际伤害，并返回是否暴击
func get_bullet_damage_and_crit_status() -> Dictionary: # Returns {"damage": float, "is_crit": bool}
	return {"damage": bullet_damage, "is_crit": is_crit_hit, "is_summon_bullet": false}

# 用于防止同一帧内多次处理碰撞
var collision_processed_this_frame: bool = false
var current_frame: int = -1

# 处理子弹穿透逻辑，返回是否应该销毁子弹
# 如果返回false，表示这一帧已经处理过碰撞，应该忽略当前碰撞
func handle_penetration() -> bool:
	var frame = Engine.get_process_frames()
	
	# 如果是新的一帧，重置处理标志
	if frame != current_frame:
		current_frame = frame
		collision_processed_this_frame = false

	# 如果这一帧已经处理过碰撞，忽略后续碰撞
	if collision_processed_this_frame:
		return false # 返回false表示忽略这次碰撞

	# 标记这一帧已经处理过碰撞
	collision_processed_this_frame = true

	# 树枝2 & 12: 穿透伤害提升
	if PC.selected_rewards.has("branch2"): # 意味着至少穿透了一次
		var damage_increase = 0.3
		if PC.selected_rewards.has("branch21"):
			damage_increase = 0.4
		bullet_damage *= (1 + damage_increase)

	# 树枝4: 击退效果
	if PC.selected_rewards.has("branch4") and not is_rebound:
		var bodies = get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("enemies"):
				if body.has_method("apply_knockback"):
					body.apply_knockback(direction, 30)

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


func _create_sword_wave_instance(position: Vector2) -> void:
	if parent_bullet:
		var split_count = PC.branch_split_count
		if PC.selected_rewards.has("branch3"):
			split_count += 1
		if PC.selected_rewards.has("branch33"):
			split_count += 1
		
		var base_angle = direction.angle()
		var angle_range = deg_to_rad(330)

		for i in range(split_count):
			var new_bullet = load("res://Scenes/branch.tscn").instantiate()
			var random_angle = base_angle - angle_range / 2 + randf() * angle_range
			new_bullet.direction = Vector2.from_angle(random_angle)
			new_bullet.global_position = position
			new_bullet.parent_bullet = false # 子弹不再分裂
			
			# 树枝12: 分裂出的子树枝也会继承这个加成
			if PC.selected_rewards.has("branch21"):
				new_bullet.bullet_damage = bullet_damage # 继承当前伤害
			
			get_parent().add_child(new_bullet)

# 设置子弹缩放并同步更新碰撞形状
func set_bullet_scale(new_scale: Vector2) -> void:
	scale = new_scale
	update_collision_shape_size()

func _create_aoe_damage(position: Vector2) -> void:
	var aoe_area = Area2D.new()
	var aoe_shape = CircleShape2D.new()
	aoe_shape.radius = 20 # 小范围半径
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = aoe_shape
	aoe_area.add_child(collision_shape)
	aoe_area.global_position = position
	get_parent().add_child(aoe_area)

	await get_tree().create_timer(0.1).timeout
	var bodies = aoe_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			body.take_damage(bullet_damage * 0.3, false, false)
	
	aoe_area.queue_free()

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
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_enemy = enemy

# 当与其他区域进入碰撞时
func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies") and PC.selected_rewards.has("branch4") and parent_bullet and not is_rebound:
		# 应用击退效果（只对父级子弹生效）
		if area.has_method("apply_knockback"):
			area.apply_knockback(direction, 30)
