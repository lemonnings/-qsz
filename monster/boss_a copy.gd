extends Area2D

@onready var sprite = $BossA
var is_dead : bool = false
var is_attacking : bool = false
var allow_turning : bool = true

# 屏幕边界
@export var top_boundary: float = 0.0
@export var bottom_boundary: float = 265.0
@export var left_boundary: float = -340.0
@export var right_boundary: float = 340.0

# 0为从左到右，1为从右向左，2为随机移动，3为靠近角色，4为y轴靠近x轴保持距离，5为从左向右y随机，6为从右向左y随机
var move_direction : int = 4
var target_position : Vector2 # 用于存储移动目标位置
var update_move_timer : Timer # 移动模式计时器

var speed : float = SettingMoster.slime("speed") * 1 # Boss移动速度，可以调整
var hpMax : float = SettingMoster.slime("hp") * 90 # Boss最大生命值，可以调整
var hp : float = hpMax # Boss当前生命值
var atk : float = SettingMoster.slime("atk") * 0.9 # Boss攻击力，可以调整
var get_point : int = SettingMoster.slime("point") * 25 # 击败Boss获得的积分
var get_exp : int = 0 # 击败Boss获得的经验

var attack_timer : Timer # Boss攻击计时器
var attack_indicator : Node2D # 攻击范围指示器
var outer_line_node : Line2D
var inner_line_node : Line2D
var charge_indicator_direction : Vector2 # 存储冲锋指示器方向
var charge_target_global_position : Vector2 # 存储冲锋的最终目标全局位置

func _ready():
	# 防止boss升级期间打人
	process_mode = Node.PROCESS_MODE_PAUSABLE
	hp = hpMax # 初始化当前血量
	Global.emit_signal("boss_hp_bar_initialize", hpMax, hp, 12, "测试BOSS")
	Global.emit_signal("boss_hp_bar_show")
	
	# 初始化移动相关
	update_move_timer = Timer.new()
	add_child(update_move_timer)
	update_move_timer.wait_time = 0.5
	update_move_timer.timeout.connect(_update_target_position_mode4)
	update_move_timer.start()
	_update_target_position_mode4()

	# 初始化攻击计时器
	attack_timer = Timer.new()
	add_child(attack_timer)
	attack_timer.wait_time = 1.75
	attack_timer.timeout.connect(_choose_attack)
	attack_timer.start()


func _update_target_position_mode4():
	var player_pos = PC.player_instance.global_position
	var x_offset = 90
	if global_position.x < player_pos.x:
		x_offset = -90
	target_position = Vector2(player_pos.x + x_offset, player_pos.y)

func _physics_process(delta: float) -> void:
	# Boss朝向逻辑，仅在允许转向且不处于攻击状态（特别是冲锋）时才根据玩家位置调整朝向
	if PC.player_instance and allow_turning:
		var player_pos = PC.player_instance.global_position
		if player_pos.x < global_position.x:
			if allow_turning:
				sprite.flip_h = true
		else:
			if allow_turning:
				sprite.flip_h = false
		
	if not is_dead and not is_attacking: # 只有在不攻击的时候才移动
		_move_pattern(delta)
		
	if is_attacking:
		$BossA.play("idle")
		attack_timer.paused = true
	if not is_attacking:
		$BossA.play("run")
		attack_timer.paused = false

func _move_pattern(delta: float):
	var direction = position.direction_to(target_position)
	if position.distance_to(target_position) > 5: 
		position += direction * speed * delta

func _choose_attack():
	if is_dead:
		return
		
	is_attacking = true # 标记开始攻击，停止移动
	
	var attack_type = randi_range(1, 2)
	print("Boss chooses attack: ", attack_type)

	match attack_type:
		1: 
			_attack_straight_line() # 以boss为中心，锁定玩家的初始位置，造成25像素的矩形范围伤害，预警时间为1.5秒
		2: 
			_attack_random_circle() # 在玩家周围200px内，每0.1秒生成一个15像素的，长宽比为0.67的圆形攻击范围，预警时间为1秒，共生成30个

func _attack_charge():
	is_attacking = false
	print("Attack: Charge")

	# 根据 charge_indicator_direction (即瞄准方向) 设置sprite朝向
	# charge_indicator_direction 应该在 _show_attack_indicator 中被正确设置
	if charge_indicator_direction.x < 0:
		sprite.flip_h = true
	else:
		sprite.flip_h = false

	# 使用在 _show_attack_indicator 中计算并存储的 charge_target_global_position 和 charge_indicator_direction
	var intended_target_pos = charge_target_global_position
	var charge_direction_normalized = charge_indicator_direction # 这个在指示器阶段已经归一化了
	print("执行冲锋，原始目标全局位置: ", intended_target_pos, " 冲锋方向: ", charge_direction_normalized)

	var final_target_pos = intended_target_pos

	# 射线检测以确定与边界的碰撞点，保持方向
	var space_state = get_world_2d().direct_space_state
	# 创建一个非常长的射线，确保能达到任何边界
	var ray_origin = global_position
	var ray_end = ray_origin + charge_direction_normalized * 2000

	# 定义边界的四个线段
	var boundaries = [
		[Vector2(left_boundary, top_boundary), Vector2(right_boundary, top_boundary)],       # 上边界
		[Vector2(left_boundary, bottom_boundary), Vector2(right_boundary, bottom_boundary)], # 下边界
		[Vector2(left_boundary, top_boundary), Vector2(left_boundary, bottom_boundary)],     # 左边界
		[Vector2(right_boundary, top_boundary), Vector2(right_boundary, bottom_boundary)]    # 右边界
	]

	var closest_collision_point = intended_target_pos # 默认为原始目标
	var min_collision_distance_sq = (intended_target_pos - ray_origin).length_squared()
	var collided_with_boundary = false

	# 检查原始目标点是否在边界内
	var intended_target_in_bounds = intended_target_pos.x >= left_boundary and intended_target_pos.x <= right_boundary and \
								  intended_target_pos.y >= top_boundary and intended_target_pos.y <= bottom_boundary

	if not intended_target_in_bounds:
		# 如果原始目标点超出边界，则计算与边界的交点
		min_collision_distance_sq = INF # 重置为无穷大，以便找到最近的交点
		for boundary_segment in boundaries:
			var intersection = Geometry2D.segment_intersects_segment(ray_origin, ray_end, boundary_segment[0], boundary_segment[1])
			if intersection:
				var dist_sq = (intersection - ray_origin).length_squared()
				# 确保交点在冲锋方向上，并且比当前最近的交点更近
				# 并且交点不能比原始冲锋目标点更远 (除非原始目标点就在边界外侧很近的地方)
				var original_target_distance_sq = (intended_target_pos - ray_origin).length_squared()
				if dist_sq < min_collision_distance_sq and dist_sq <= original_target_distance_sq:
					min_collision_distance_sq = dist_sq
					closest_collision_point = intersection
					collided_with_boundary = true
				# 如果射线与边界平行且共线，或者其他复杂情况，intersection可能为null
		# 如果没有找到交点（理论上不太可能，除非边界设置有问题或Boss在边界外开始冲锋），则clamp
		if not collided_with_boundary:
			closest_collision_point.x = clamp(intended_target_pos.x, left_boundary, right_boundary)
			closest_collision_point.y = clamp(intended_target_pos.y, top_boundary, bottom_boundary)
	else:
		# 如果原始目标点就在边界内，则不需要碰撞检测
		collided_with_boundary = false # 明确标记未与边界碰撞

	final_target_pos = closest_collision_point

	var charge_speed = speed * 12 # 冲锋速度

	# 根据最终目标位置，重新计算实际冲锋距离和时间
	var actual_charge_vector = final_target_pos - global_position
	var actual_charge_distance = actual_charge_vector.length()
	var charge_time = 0.0
	if charge_speed > 0 and actual_charge_distance > 0.1: # 增加一个小的阈值避免极小距离的移动
		charge_time = actual_charge_distance / charge_speed

	$BossA.play("run")
	var tween = create_tween()
	
	# 如果实际冲锋距离和时间都大于0，才执行移动
	if actual_charge_distance > 0.1 and charge_time > 0: # 增加一个小的阈值避免极小距离的移动
		tween.tween_property(self, "global_position", final_target_pos, charge_time)
		tween.finished.connect(func():
			is_attacking = false
			$BossA.play("run") 
			allow_turning = true # 允许boss转向
		)
	else:
		# 如果无法冲锋 (例如已在边界、目标点与当前位置相同，或计算出的时间为0或距离过小)
		is_attacking = false
		# $BossA.play("fly") # Removed as per user feedback, 'fly' animation does not exist
		$BossA.play("run") 
		allow_turning = true # 允许boss转向


func _on_body_entered(body: Node2D) -> void:
	if(body is CharacterBody2D and not is_dead and not PC.invincible) :
		Global.emit_signal("player_hit")
		var actual_damage = int(atk * (1.0 - PC.damage_reduction_rate)) # Boss也应用减伤
		PC.pc_hp -= actual_damage
		if PC.pc_hp <= 0:
			body.game_over()

# 检查怪物是否在可伤害范围内（超出视野20px才能被伤害）
func _is_monster_in_damage_range() -> bool:
	# 获取摄像头
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return true  # 如果没有摄像头，默认可以伤害
	
	# 获取视野范围
	var viewport_size = get_viewport().get_visible_rect().size
	var camera_zoom = camera.zoom
	var visible_size = viewport_size / camera_zoom
	
	# 计算摄像头的可视区域边界
	var camera_pos = camera.global_position
	var half_visible_size = visible_size / 2
	
	var left_bound = camera_pos.x - half_visible_size.x
	var right_bound = camera_pos.x + half_visible_size.x
	var top_bound = camera_pos.y - half_visible_size.y
	var bottom_bound = camera_pos.y + half_visible_size.y
	
	# 扩展边界，使其在屏幕上保持固定的N像素边距 (例如20像素)
	# 原来的 damage_margin 是固定的世界单位，导致缩放时屏幕上的实际边距变化
	# 现在我们将其理解为屏幕像素，并转换为世界单位
	var screen_pixel_margin = 20.0 
	if camera_zoom.x == 0.0 or camera_zoom.y == 0.0:
		# 防止除以零错误，尽管camera_zoom通常不会是0
		# 在这种不太可能的情况下，可以不加边距或设置一个默认的世界边距
		# 例如，这里选择不修改边界 (等同于边距为0)
		pass
	else:
		var world_margin_x = screen_pixel_margin / camera_zoom.x
		var world_margin_y = screen_pixel_margin / camera_zoom.y
		
		left_bound -= world_margin_x
		right_bound += world_margin_x
		top_bound -= world_margin_y
		bottom_bound += world_margin_y
	
	# 检查怪物位置是否在可伤害范围内
	var monster_pos = global_position
	return (monster_pos.x >= left_bound and monster_pos.x <= right_bound and 
			monster_pos.y >= top_bound and monster_pos.y <= bottom_bound)


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("bullet") and area.has_method("get_bullet_damage_and_crit_status"):
		# 检查怪物是否在视野范围内（超出视野20px才能被伤害）
		if not _is_monster_in_damage_range():
			return
		
		# 使用BulletCalculator处理完整的子弹碰撞逻辑
		var collision_result = BulletCalculator.handle_bullet_collision_full(area, self, true)
		var final_damage_val = collision_result["final_damage"]
		var is_crit = collision_result["is_crit"]
		
		# Boss血条更新
		Global.emit_signal("boss_hp_bar_take_damage", final_damage_val)
		hp -= int(final_damage_val)
		
		# 处理子弹反弹
		if collision_result["should_rebound"]:
			area.call_deferred("create_rebound")
		
		# 根据穿透逻辑决定是否销毁子弹
		if collision_result["should_delete_bullet"]:
			area.queue_free()
			
		if hp <= 0:
			#free_health_bar()
			# $AnimatedSprite2D.play("death") # Boss死亡动画
			if not is_dead:
				# $death.play() # Boss死亡音效
				Global.emit_signal("boss_defeated", get_point) # 发送Boss被击败信号
				
			is_dead = true
			attack_timer.stop()
			# await get_tree().create_timer(1.0).timeout # 等待死亡动画
			queue_free()
		else:
			Global.play_hit_anime(position, is_crit)


# 计算点到直线的距离的辅助函数
func _point_to_line_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line_vec = line_end - line_start
	var point_vec = point - line_start
	var line_length_sq = line_vec.length_squared()
	
	if line_length_sq == 0:
		return point_vec.length() # 如果线段长度为0，返回点到起点的距离
	
	# 计算点在直线上的投影
	var t = point_vec.dot(line_vec) / line_length_sq
	t = clamp(t, 0.0, 1.0) # 限制在线段范围内
	
	# 计算最近点
	var closest_point = line_start + t * line_vec
	return point.distance_to(closest_point)


func _attack_random_barrage():
	print("Attack: Random Barrage")
	for i in range(RANDOM_BARRAGE_BULLET_COUNT):
		var bullet = STRAIGHT_BULLET.instantiate()
		
		# 将子弹添加到场景树
		if get_parent():
			get_parent().add_child(bullet)
		else:
			get_tree().current_scene.add_child(bullet)
		
		# 设置子弹位置和方向
		bullet.global_position = global_position
		var random_angle = randf_range(0, TAU)
		var direction = Vector2.RIGHT.rotated(random_angle)
		
		# 设置子弹方向和速度
		bullet.set_direction(direction)
		bullet.bullet_speed = 190.0
		bullet.bullet_damage = atk
		
		await get_tree().create_timer(RANDOM_BARRAGE_INTERVAL).timeout
	
	is_attacking = false # 攻击结束


func _attack_straight_line():
	"""以boss为中心，锁定玩家的初始位置，造成25像素的矩形范围伤害，预警时间为1.5秒"""
	print("Attack: Straight Line")
	
	# 获取玩家当前位置
	var player_pos = PC.player_instance.global_position
	var boss_pos = global_position
	
	# 创建矩形预警
	var WarnRectUtil = preload("res://util/warn_rect_util.gd")
	var warning_rect = WarnRectUtil.new()
	get_parent().add_child(warning_rect)
	
	# 连接信号
	warning_rect.warning_finished.connect(_on_straight_line_finished)
	
	# 开始预警：从boss位置到玩家位置的矩形攻击
	warning_rect.start_warning(
		boss_pos,        # 起始位置
		player_pos,      # 目标位置
		25.0,            # 矩形宽度25像素
		1.5,             # 预警时间1.5秒
		atk              # 伤害值
	)

func _on_straight_line_finished():
	"""直线攻击结束回调"""
	is_attacking = false
	print("Straight line attack finished")

func _attack_random_circle():
	"""在玩家周围200px内，每0.1秒生成一个15像素的，长宽比为0.67的圆形攻击范围，预警时间为1秒，共生成30个"""
	print("Attack: Random Circle")
	
	# 获取玩家当前位置
	var player_pos = PC.player_instance.global_position
	
	# 生成30个圆形攻击
	for i in range(30):
		# 在玩家周围200px内随机生成位置
		var random_angle = randf() * TAU
		var random_distance = randf() * 200.0
		var random_offset = Vector2.RIGHT.rotated(random_angle) * random_distance
		var attack_pos = player_pos + random_offset
		
		# 创建圆形预警
		var WarnCircleUtil = preload("res://util/warn_circle_util.gd")
		var warning_circle = WarnCircleUtil.new()
		get_parent().add_child(warning_circle)
		
		# 如果是最后一个圆形，连接结束信号
		if i == 29:
			warning_circle.warning_finished.connect(_on_random_circle_finished)
		
		# 开始预警：15像素半径，长宽比0.67的椭圆形攻击
		warning_circle.start_warning(
			attack_pos,      # 生成位置
			0.67,            # 长宽比0.67
			15.0,            # 半径15像素
			1.0,             # 预警时间1秒
			atk              # 伤害值
		)
		
		# 等待0.1秒再生成下一个
		await get_tree().create_timer(0.1).timeout

func _on_random_circle_finished():
	"""随机圆形攻击结束回调"""
	is_attacking = false
	print("Random circle attack finished")

func apply_knockback(direction: Vector2, force: float):
	# Boss可以有击退抗性，或者完全免疫
	pass
