extends Area2D

@export var bullet_speed: float = 160
@export var bullet_range: float = PC.moyan_range  # 子弹射程
@export var penetration_count: int = 1

# 子弹的伤害和暴击状态（在创建时确定）
var bullet_damage: float = 0.0
var initial_damage: float = 0.0  # 保存初始伤害值
var is_crit_hit: bool = false

# 射程和爆炸相关变量
var start_position: Vector2  # 子弹起始位置
var traveled_distance: float = 0.0  # 已飞行距离 
var is_exploding: bool = false # 是否正在爆炸 
@export var sprite : Sprite2D  # 获取精灵节点引用
@export var collision_shape : CollisionShape2D  # 获取碰撞形状节点引用

# 魔焰相关变量
var initial_scale: Vector2  # 保存初始碰撞形状大小
static var moyan_count: int = 0  # 魔焰使用次数计数（静态变量以在实例间共享）
var is_giant_moyan: bool = false  # 是否为巨大魔焰

var direction: Vector2

func _ready() -> void:
	# 记录子弹起始位置
	start_position = global_position
	
	# 初始化子弹伤害和暴击状态
	initialize_bullet_damage()
		
	# 连接信号
	area_entered.connect(_on_area_entered)
	
	# 保存初始值
	initial_damage = bullet_damage
	initial_scale = collision_shape.scale
	
	# 检查是否为巨大魔焰
	moyan_count += 1
	if PC.selected_rewards.has("moyan23") and moyan_count >= 3:
		is_giant_moyan = true
		moyan_count = 0
		bullet_damage *= 2.05  # 1.7 * 1.2 (额外20%伤害)
		collision_shape.scale *= 1.8
	elif PC.selected_rewards.has("moyan3") and moyan_count >= 4:
		is_giant_moyan = true
		moyan_count = 0
		bullet_damage *= 1.8
		collision_shape.scale *= 1.8
	
	await get_tree().create_timer(4).timeout
	if !Global.is_level_up:
		queue_free()
	# 初始化时设置精灵方向
	_update_sprite_rotation()

func _physics_process(delta: float) -> void:
	# 子弹始终保持移动（包括渐隐过程中）
	position += direction * bullet_speed * delta
	# 更新已飞行距离
	traveled_distance = start_position.distance_to(global_position)

	# 魔焰逻辑
	var distance_meters = traveled_distance / 40.0 # 假设40像素=1米
	var damage_increase_multiplier = 1.0
	var scale_increase_multiplier = 1.0
	var crit_damage_increase = 0.0

	# 魔焰12：发射后的前2米，爆炸范围及伤害提升量提升至300%
	if PC.selected_rewards.has("moyan12") and distance_meters < 2:
		damage_increase_multiplier += floor(distance_meters) * 0.09
		scale_increase_multiplier += floor(distance_meters) * 0.30
	# 魔焰1：每前进1米，爆炸范围提升10%，伤害提升3%
	elif PC.selected_rewards.has("moyan1"): 
		damage_increase_multiplier += floor(distance_meters) * 0.03
		scale_increase_multiplier += floor(distance_meters) * 0.10

	# 魔焰13：每前进1米，魔焰爆击伤害额外提升5%
	if PC.selected_rewards.has("moyan13") and is_crit_hit:
		crit_damage_increase = floor(distance_meters) * 0.05
		if is_giant_moyan:  # 暴击伤害对巨大魔焰的加成翻倍
			crit_damage_increase *= 2

	# 应用伤害和范围加成
	bullet_damage = initial_damage * damage_increase_multiplier * (1 + crit_damage_increase)
	collision_shape.scale = initial_scale * scale_increase_multiplier

	# 检查是否超出射程或需要提前爆炸
	if not is_exploding:
		# 魔焰2：如果飞行距离小于2米就爆炸，伤害额外提升30%
		if PC.selected_rewards.has("moyan2") and distance_meters < 2:
			bullet_damage *= 1.3
			play_explosion_and_die()
		elif traveled_distance >= bullet_range:
			play_explosion_and_die()

	# 更新精灵旋转以匹配移动方向
	_update_sprite_rotation()
	
# 播放爆炸动画并销毁自身
func play_explosion_and_die():
	if is_exploding:
		return
	is_exploding = true

	# 创建爆炸动画
	var explosion = preload("res://Scenes/player/big_fire_bullet.tscn").instantiate()
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = global_position
	
	# 根据碰撞形状大小调整爆炸动画 大小
	explosion.scale = Vector2(1 + (PC.bullet_size), 1 + (PC.bullet_size))
	if explosion.has_node("CollisionShape2D"):
		explosion.get_node("CollisionShape2D").scale = explosion.scale
	
	var anim_player = explosion.gun_hit_anime
	var sound_player = explosion.gun_hit_sound

	if sound_player:
		sound_player.play()
	
	if anim_player:
		anim_player.play()		
		anim_player.connect("animation_finished", explosion.queue_free)
		
	# 隐藏子弹并禁用碰撞
	sprite.visible = false
	
	#collision_shape.set_deferred("disabled", true)
	# 根据PC.bullet_size调整爆炸动画和碰撞形状的大小

	# 正确调整 CircleShape2D 的半径
	var original_radius = 36.4 # 从 moyan_rectShape.tres 获取的原始半径
	
	#collision_shape.shape = explosion.gun_hit_circle
	#collision_shape.shape.radius = original_radius * explosion.scale.x
	var final_radius = original_radius * explosion.scale.x
	print("Before await timer")

	# 新增的逻辑：以final_radius为半径进行范围检测
	print("Starting damage calculation")
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = final_radius / 1.4
	query.set_shape(circle_shape)
	query.transform = global_transform
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = collision_mask

	print("After await timer")
	var result = space_state.intersect_shape(query)
	
	for hit in result:
		var area = hit.collider
		if area is Area2D and area.is_in_group("enemies") and area.has_method("take_damage"):
			area.take_damage(bullet_damage * 0.8, false, false, "")
			print("Damage dealt to: ", area.name)
	print("Finished damage calculation")
	
	# 直接销毁子弹
	queue_free()
	print("Node freed")

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies"):
		await play_explosion_and_die()

# 更新精灵旋转以匹配移动方向
func _update_sprite_rotation() -> void:
	if direction != Vector2.ZERO:
		# 计算方向向量的角度（弧度）
		var angle = direction.angle()
		sprite.rotation = angle

# 设置子弹方向并立即更新旋转
func set_direction(new_direction: Vector2) -> void:
	direction = new_direction
	_update_sprite_rotation()  # 立即更新旋转，避免第一帧显示错误方向

# 初始化子弹的伤害和暴击状态
func initialize_bullet_damage() -> void:
	var base_damage: float = PC.pc_atk * PC.main_skill_moyan_damage

	is_crit_hit = false
	bullet_damage = base_damage
	$CollisionShape2D.shape.radius = 5.7

	if randf() < PC.crit_chance:
		is_crit_hit = true
		var crit_multiplier = PC.crit_damage_multi
		# 魔焰13: 巨大魔焰暴击伤害翻倍
		if is_giant_moyan and PC.selected_rewards.has("moyan13"):
			crit_multiplier *= 2
		bullet_damage *= crit_multiplier

# 获取子弹的实际伤害，并返回是否暴击
func get_bullet_damage_and_crit_status() -> Dictionary:
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
		return false  # 返回false表示忽略这次碰撞

	# 标记这一帧已经处理过碰撞
	collision_processed_this_frame = true

	# 减少穿透计数
	penetration_count -= 1
	play_explosion_and_die()

	# 如果穿透计数小于0，则销毁子弹
	if penetration_count < 0:
		return false

	return true

# 设置子弹速度
func set_speed(new_speed: float) -> void:
	bullet_speed = new_speed

# 设置子弹射程
func set_range(new_range: float) -> void:
	bullet_range = new_range

# 设置子弹方向
func set_direction_and_speed(new_direction: Vector2, new_speed: float) -> void:
	direction = new_direction
	bullet_speed = new_speed
	_update_sprite_rotation()

# 更新碰撞形状大小以匹配精灵缩放
func update_collision_shape_size() -> void:
	if collision_shape and collision_shape.shape:
		# 获取当前的缩放值
		var current_scale = scale

# 设置子弹缩放并同步更新碰撞形状
func set_bullet_scale(new_scale: Vector2) -> void:
	scale = new_scale
	update_collision_shape_size()

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
