extends Area2D

@export var bullet_speed: float = 550
@export var bullet_range: float = 150.0  # 子弹射程
@export var penetration_count: int = 1  # 穿透次数，默认为1

# 预加载剑痕场景
const SwordWaveScene = preload("res://Scenes/sword_wave.tscn")

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

var is_other_sword_wave: bool = false  # 标记是否为额外发射的剑气

var is_rebound: bool = false  # 标记是否为反弹子弹
var parent_bullet: bool = true  # 标记是否为父级子弹，默认为true
var is_ring_bullet: bool = false  # 标记是否为环形子弹
var ring_bullet_damage_multiplier: float = 1.0  # 环形子弹伤害倍数

var if_summon: bool = false
var is_summon_bullet: bool = false  # 标记是否为召唤物子弹
var summon_damage: float = 0.0  # 召唤物子弹伤害

# 剑波痕迹相关变量
var sword_wave_trace_enabled: bool = false
var trace_positions: Array[Vector2] = []
var trace_sprites: Array[Sprite2D] = []
var trace_damage_areas: Array[Area2D] = []
var trace_update_interval: float = 0.05  # 痕迹更新间隔
var trace_timer: float = 0.0
var trace_lifetime: float = 2.0  # 痕迹持续时间
var trace_fade_start_time: float = 1.0  # 开始渐隐的时间
var trace_damage_percent: float = 0.2  # 痕迹伤害百分比

# SwordQi4 追踪相关变量
var sword_qi4_enabled: bool = false
var target_enemy: Node = null
var speed_boost_timer: float = 0.0
var speed_boost_interval: float = 0.1  # 每0.1秒提升速度
var speed_boost_amount: float = 50.0  # 每次提升50速度
var has_hit_target: bool = false  # 是否已击中目标

func _ready() -> void:
	# 记录子弹起始位置
	start_position = global_position
	
	# 检查是否启用剑波痕迹
	if PC.selected_rewards.has("swordWaveTrace"):
		sword_wave_trace_enabled = true
	
	# 检查是否启用SwordQi4追踪功能
	if PC.selected_rewards.has("SwordQi4"):
		sword_qi4_enabled = true
		find_nearest_enemy()
	
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
		
	# SwordQi4 追踪逻辑
	if sword_qi4_enabled and not has_hit_target:
		update_sword_qi4_tracking(delta)
		
	# 或者是分裂可以追踪
	if !parent_bullet and PC.selected_rewards.has("SplitSwordQi12") and not has_hit_target:
		update_sword_qi4_tracking(delta)
		
	# 子弹始终保持移动（包括渐隐过程中）
	position += direction * bullet_speed * delta
	# 更新已飞行距离
	traveled_distance = start_position.distance_to(global_position)
	
	# 检查是否超出射程，开始渐隐
	if not is_fading and traveled_distance >= bullet_range:
		if PC.selected_rewards.has("swordWaveTrace") and !if_summon:
			#print("Bullet reached range, creating SwordWave at: ", global_position)
			_create_sword_wave_instance(global_position)
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
		# 不立即禁用碰撞，等透明度低于0.2时再禁用
		

# 更新精灵旋转以匹配移动方向
func _update_sprite_rotation() -> void:
	if direction != Vector2.ZERO:
		# 计算方向向量的角度（弧度）
		var angle = direction.angle()
		# 设置精灵旋转（Godot中，0弧度是指向右的，所以不需要额外调整）
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


# 初始化子弹的伤害和暴击状态
func initialize_bullet_damage() -> void:
	var base_damage: float
	var can_crit: bool = not is_summon_bullet # 召唤物子弹不参与暴击
	
	if is_summon_bullet:
		base_damage = summon_damage * PC.main_skill_swordQi_damage 
	elif is_ring_bullet:
		base_damage = PC.pc_atk * ring_bullet_damage_multiplier* PC.main_skill_swordQi_damage 
	elif is_other_sword_wave:
		base_damage = PC.pc_atk * PC.swordQi_other_sword_wave_damage* PC.main_skill_swordQi_damage 
	else:
		base_damage = PC.pc_atk * PC.main_skill_swordQi_damage 

	is_crit_hit = false
	bullet_damage = base_damage

	if can_crit:
		if randf() < PC.crit_chance:
			is_crit_hit = true
			bullet_damage *= PC.crit_damage_multiplier

# 获取子弹的实际伤害，并返回是否暴击
func get_bullet_damage_and_crit_status() -> Dictionary: # Returns {"damage": float, "is_crit": bool}
	return {"damage": bullet_damage, "is_crit": is_crit_hit, "is_summon_bullet": is_summon_bullet}

# 用于防止同一帧内多次处理碰撞
var collision_processed_this_frame: bool = false
var current_frame: int = -1

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
	
	# 返回true表示处理这次碰撞，如果穿透计数<=0则销毁子弹
	if PC.selected_rewards.has("swordWaveTrace") and !if_summon:
		print("Bullet hit enemy, creating SwordWave at: ", global_position)
		_create_sword_wave_instance(global_position)
		
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


func _create_sword_wave_instance(position: Vector2) -> void:
	if PC.swordQi_penetration_count > 1 and penetration_count == PC.swordQi_penetration_count:
		if SwordWaveScene:
			var sword_wave_instance = SwordWaveScene.instantiate()
			# 将剑痕实例添加到与子弹相同的父节点下，或者一个专门管理特效的节点下
			if get_parent():
				get_parent().call_deferred("add_child", sword_wave_instance)
				# 设置剑痕的初始位置（虽然setup_wave会重新计算，但先设置一个大致位置）
				# sword_wave_instance.global_position = position # 延迟调用后，直接设置属性可能过早
				# 调用剑痕的设置方法
				if sword_wave_instance.has_method("setup_wave"):
					# 确保在节点添加到场景树之后再调用 setup_wave
					# 可以通过一个简短的延迟或者连接到 ready 信号（如果 setup_wave 依赖于 _ready）
					# 更简单的方式是也延迟调用 setup_wave，并传递必要的参数
					sword_wave_instance.call_deferred("setup_wave", position)
			
			# 如果是RectangleShape2D
			if collision_shape.shape is RectangleShape2D:
				var rect_shape = collision_shape.shape as RectangleShape2D
				# 设置新的大小，基于原始大小和当前缩放
				var original_size = Vector2(14, 26)  # 原始碰撞形状大小
				rect_shape.size = original_size * scale
			
			# 如果是CircleShape2D
			elif collision_shape.shape is CircleShape2D:
				var circle_shape = collision_shape.shape as CircleShape2D
				# 设置新的半径，基于原始半径和当前缩放的平均值
				var original_radius = 20.0  # 原始碰撞形状半径
				if PC.selected_rewards.has("SplitSwordQi21"):
					original_radius = 25.0
				circle_shape.radius = original_radius * ((scale.x + scale.y) / 2.0)

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

# 寻找最近的敌人
func find_nearest_enemy() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	
	var nearest_enemy = null
	var nearest_distance = INF
	
	for enemy in enemies:
		if enemy and is_instance_valid(enemy) and enemy.has_method("_on_area_entered"):
			var distance = global_position.distance_to(enemy.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_enemy = enemy
	
	if nearest_enemy:
		target_enemy = nearest_enemy

func update_sword_qi4_tracking(delta: float) -> void:
	# 检查目标敌人是否仍然有效
	if not target_enemy or not is_instance_valid(target_enemy):
		# 目标无效，重新寻找最近的敌人
		find_nearest_enemy()
		if not target_enemy:
			return
	
	# 更新方向指向目标敌人
	var target_direction = (target_enemy.global_position - global_position).normalized()
	direction = target_direction
	
	# 更新速度提升计时器
	speed_boost_timer += delta
	if speed_boost_timer >= speed_boost_interval:
		speed_boost_timer = 0.0
		bullet_speed += speed_boost_amount

func on_hit_target() -> void:
	if sword_qi4_enabled:
		has_hit_target = true
