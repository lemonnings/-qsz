extends Area2D

@export var bullet_speed: float = 325
@export var bullet_fisson: float = 1
@export var bullet_range: float = PC.branch_range  # 子弹射程
@export var penetration_count: int = 999

# 子弹的伤害和暴击状态（在创建时确定）
var bullet_damage: float = 0.0
var is_crit_hit: bool = false

# 射程和渐隐相关变量
var start_position: Vector2  # 子弹起始位置
var traveled_distance: float = 0.0  # 已飞行距离 
var is_fading: bool = false  # 是否正在渐隐
var fade_timer: float = 0.0  # 渐隐计时器
var fade_duration: float = 0.2  # 渐隐持续时间（秒） 
@export var sprite : Sprite2D  # 获取精灵节点引用
@export var collision_shape :CollisionShape2D  # 获取碰撞形状节点引用

var direction: Vector2

var is_rebound: bool = false  # 标记是否为反弹子弹
var parent_bullet: bool = true  # 标记是否为父级子弹，默认为true

func _ready() -> void:
	# 记录子弹起始位置
	start_position = global_position
	
	# 初始化子弹伤害和暴击状态
	initialize_bullet_damage()
		
	# 初始化碰撞形状大小
	update_collision_shape_size()
	
	await get_tree().create_timer(3).timeout
	if !Global.is_level_up:
		queue_free()
	# 初始化时设置精灵方向
	_update_sprite_rotation()

func _physics_process(delta: float) -> void:
	# 子弹始终保持移动（包括渐隐过程中）
	position += direction * bullet_speed * delta
	# 更新已飞行距,
	traveled_distance = start_position.distance_to(global_position)
	# 树枝22: 每飞行0.2米，伤害提升2%
	if PC.selected_rewards.has("branch22"):
		var distance_meters = traveled_distance * 0.04
		var damage_increase_multiplier = 1.0 + floor(distance_meters / 0.2) * 0.02
		bullet_damage *= damage_increase_multiplier

	# 树枝1: 行进至射程一半时分裂0.1 
	if PC.selected_rewards.has("branch1") and not is_fading and traveled_distance >= bullet_range / 2:
		_create_sword_wave_instance(global_position)
		# 防止重复分裂
		#PC.selected_rewards.erase("branch1")

	# 检查是否超出射程
	# 羁绊设计：基于中国，北欧，希腊，埃及神话，每个神话有N个专属的主羁绊，然后有共通的若干个子羁绊
		# 例如，中国神话的主羁绊可以设计为九重天（道教的三清，四御...），佛土（佛陀，菩萨...），山海经（麒麟，穷奇...），
		# 麒麟：山海经3 祥瑞2 守护者1
		# 青龙&朱雀：九重天3 星辰使2 祥瑞1
		# 百解：祥瑞1 斗士1 凶兽1
	# 大羁绊固定派系下的*3=9个，对应领袖*1有3个，可以凑到12
	# 小羁绊英雄*2的有3个，加上1个*1的最多可以凑到7，携带6个领袖，*1的有5个，可以凑到12，专武有两个+1，铜银金各+1，彩+2，彩卡+1
	# 基准，战力类提升3：10%，6,24%，9:50%，12：:90%，15，150%，18，280%
	# 不死：HP降至1以下会无敌2秒，期间提升,80%的攻速，冷却60秒 3：持续时间+2s，冷却-20s
	# 6：期间额外提升80%攻击，并且在不死状态结束后恢复30%最大hp
	# 9：持续时间+2s，冷却-15s
	# 12：如果在冷却中hp再次降到0以下，会进入复燃状态，期间无法攻击，阻挡敌人，在不死的冷却完成后会复生并立刻触发不死
	# 15，期间提升攻击攻速提升至100%，持续时间+2s，冷却-10s
	# 18，期间提升攻击攻速提升至150%，持续时间+2s
	# 祥瑞：3：祥瑞秘宝的最大数量为6,
	# 6：每波次结束后获得1个秘宝，祥瑞秘宝最大数量提升至8，
	# 9：每波次结束后获得2个秘宝，祥瑞秘宝最大数量提升至10,
	# 12，每波次结束后获得3个秘宝，祥瑞秘宝数量最大提升至13,
	# 15，每波次结束后获得5个秘宝，祥瑞秘宝数量最大提升至16,
	# 18，每波次结束后获得8个秘宝，祥瑞秘宝数量最大提升至24
	# 秘宝价值：1个秘宝：2价值，2个秘宝，5价值，3:9,4：:14,5:20,6:28
	# 7:40,8:52
	# 9:68，10:84
	# 11:104，12:124,13:144
	# 14:168,15:192,16:216
	# 17:240 18:270 19:310 20:360 21:420 22:490 23:570 24:660
	# 奖励类型：25pp->1 蓝卡 5 紫卡 40 金卡 80 红卡 200 铜海克斯 25 银 75 金 140 虹 240 散件 20 成装 35 光明装 80 专武 140 秘宝特殊武器 100 秘宝特殊海克斯 200 
	# 雷电：3,攻击有25%触发一道雷光，随机攻击场上一个敌人造成40%atk
	# 6，触发概率提升至30%，攻击速度额外提升8%，雷光伤害对boss提升10%
	# 9，触发概率提升至35%，伤害提升至75%atk
	# 12，触发概率提升至40%，攻击速度提升量增至40%，雷光伤害对boss提升30%
	# 15，触发概率提升至50%，伤害提升至90%atk，攻击速度提升量增至60%
	# 18，伤害提升至125%atk，攻击速度提升量增至100%，雷光伤害对boss提升70%
	# 烈焰：
	# 凶兽：
	# 
	if not is_fading and traveled_distance >= bullet_range:
		_create_sword_wave_instance(global_position)
		start_fade_out()
		# 树枝11: 到达最大射程后返回
		if PC.selected_rewards.has("branch11") and not is_rebound:
			is_rebound = true
			var player = get_tree().get_first_node_in_group("player")
			if player:
				direction = (player.global_position - global_position).normalized()
				start_position = global_position # 重置起始位置以计算返回距离
				traveled_distance = 0
			else:
				start_fade_out()


		# 树枝23: 分裂的树枝在最大射程后发射飞刺
		elif PC.selected_rewards.has("branch23") and not parent_bullet:
			_create_sword_wave_instance(global_position)
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
	_update_sprite_rotation()  # 立即更新旋转，避免第一帧显示错误方向

# 初始化子弹的伤害和暴击状态
func initialize_bullet_damage() -> void:
	var base_damage: float
	base_damage = PC.pc_atk * PC.main_skill_branch_damage
	bullet_fisson = 1

	var crit_chance_bonus = 0.0
	if PC.selected_rewards.has("branch4"):
		crit_chance_bonus += 0.20
	if PC.selected_rewards.has("branch33"):
		crit_chance_bonus += 0.05

	is_crit_hit = false
	bullet_damage = base_damage * 0.4

	if randf() < (PC.crit_chance + crit_chance_bonus):
		is_crit_hit = true
		bullet_damage *= PC.crit_damage_multiplier

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
	#if PC.swordQi_penetration_count > 1 and !PC.selected_rewards.has("SplitSwordQi32"):
		#var now_penetration_count = PC.swordQi_penetration_count - penetration_count + 1
		#bullet_damage = bullet_damage * (1 - (0.15 * now_penetration_count))
	# 如果是新的一帧，重置处理标志
	if frame != current_frame:
		current_frame = frame
		collision_processed_this_frame = false

	# 如果这一帧已经处理过碰撞，忽略后续碰撞
	if collision_processed_this_frame:
		return false  # 返回false表示忽略这次碰撞

	# 标记这一帧已经处理过碰撞
	collision_processed_this_frame = true

	# 树枝2 & 12: 穿透伤害提升
	if penetration_count < 999: # 意味着至少穿透了一次
		var damage_increase = 0.08
		if PC.selected_rewards.has("branch12"):
			damage_increase = 0.12
		bullet_damage *= (1 + damage_increase)

	# 树枝4: 击退效果
	if PC.selected_rewards.has("branch4") and not is_rebound:
		var bodies = get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("enemies"):
				if body.has_method("apply_knockback"):
					body.apply_knockback(direction, 30) # 假设击退力为200

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
			if PC.selected_rewards.has("branch12"):
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
			if  distance < nearest_distance:
				nearest_distance = distance
				nearest_enemy = enemy
