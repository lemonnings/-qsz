extends Area2D

@onready var sprite = $BossA
var debuff_manager: EnemyDebuffManager
var is_dead: bool = false
var is_attacking: bool = false
var allow_turning: bool = true

signal debuff_applied(debuff_id: String)

# 屏幕边界
@export var top_boundary: float = 0.0
@export var bottom_boundary: float = 265.0
@export var left_boundary: float = -340.0
@export var right_boundary: float = 340.0

# 0为从左到右，1为从右向左，2为随机移动，3为靠近角色，4为y轴靠近x轴保持距离，5为从左向右y随机，6为从右向左y随机
var move_direction: int = 4
var target_position: Vector2 # 用于存储移动目标位置
var update_move_timer: Timer # 移动模式计时器

var speed: float = SettingMoster.slime("speed") * 1 # Boss移动速度，可以调整
var hpMax: float = SettingMoster.slime("hp") * 90 # Boss最大生命值，可以调整
#var hpMax : float = SettingMoster.slime("hp") * 0.1 # Boss最大生命值，可以调整
var hp: float = hpMax # Boss当前生命值
var atk: float = SettingMoster.slime("atk") * 0.9 # Boss攻击力，可以调整
var get_point: int = SettingMoster.slime("point") * 25 # 击败Boss获得的积分
var get_exp: int = 0 # 击败Boss获得的经验

var attack_timer: Timer # Boss攻击计时器
var attack_indicator: Node2D # 攻击范围指示器
var outer_line_node: Line2D
var inner_line_node: Line2D
var charge_indicator_direction: Vector2 # 存储冲锋指示器方向
var charge_target_global_position: Vector2 # 存储冲锋的最终目标全局位置

# 子弹场景，需要预加载
const STRAIGHT_BULLET = preload("res://Scenes/global/small_fire_bullet.tscn") # 直线子弹
const RED_CIRCLE_WARNING = preload("res://Scenes/global/warning.tscn") # 红圈警告特效
# WarnCircleUtil 和 WarnSectorUtil 已有 class_name，直接使用类名即可

# 子弹场景 (Bullet Scenes)
const NORMAL_STRAIGHT_BULLET_SCENE = STRAIGHT_BULLET # 原直线子弹作为普通直线弹
const NORMAL_BARRAGE_BULLET_SCENE = preload("res://Scenes/global/small_fire_bullet.tscn")

# 随机弹幕攻击相关常量
const RANDOM_BARRAGE_BULLET_COUNT = 130
const RANDOM_BARRAGE_INTERVAL = 0.03

# 陨石攻击参数
const METEOR_SPAWN_RANGE: float = 60.0 # 玩家周围生成范围(n像素)
const METEOR_RADIUS: float = 35.0 # 陨石半径(x)
const METEOR_COUNT: int = 8 # 陨石数量(y)
const METEOR_WARNING_TIME: float = 1.5 # 预警时间(z秒)
const METEOR_PERSIST_DURATION: float = 12.0 # 持续伤害区域持续时间

# 扇形AOE参数
const SECTOR_ANGLE: float = 50.0 # 扇形角度(n度)
const SECTOR_WARNING_TIME: float = 1.5 # 扇形预警时间(x秒)
const SECTOR_RADIUS: float = 2000.0 # 扇形半径(超出场地画幅)
const MULTI_SECTOR_ROUNDS: int = 4 # 连续扇形轮数

func _ready():
	# 防止boss升级期间打人（但没生效，子弹会在暂停期间积累到一起全射出来）
	process_mode = Node.PROCESS_MODE_PAUSABLE
	hp = hpMax # 初始化当前血量
	
	debuff_manager = EnemyDebuffManager.new(self)
	add_child(debuff_manager)
	debuff_applied.connect(debuff_manager.add_debuff)
	
	# 创建脚底阴影（Boss阴影较大）
	CharacterEffects.create_shadow(self, 45.0, 14.0, 12.0)
	
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
	attack_timer.wait_time = 2.5
	attack_timer.timeout.connect(_choose_attack)
	attack_timer.start()


func apply_debuff_effect(debuff_id: String):
	emit_signal("debuff_applied", debuff_id)


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
	
	# 播放攻击前摇动画
	# sprite.play("attack_anticipation") 
	# await get_tree().create_timer(0.5).timeout # 等待前摇

	var attack_type = randi_range(1, 9) # 扩展到新技能
	print("Boss chooses attack: ", attack_type)

	# 显示攻击范围
	if [3, 4].has(attack_type):
		_show_attack_indicator(attack_type)
		await get_tree().create_timer(1.0).timeout

	match attack_type:
		1:
			_attack_straight_line() # _attack_straight_line 内部调用 _show_attack_indicator_for_straight_line
		2:
			_attack_triple_line() # _attack_triple_line 内部调用 _show_attack_indicator_for_triple_line
		3:
			_attack_eight_directions()
			_hide_attack_indicator_with_animation() # 八向攻击后隐藏指示器
		4:
			_attack_charge()
			_hide_attack_indicator_with_animation() # 冲锋攻击后也隐藏指示器
		5:
			_attack_random_barrage()
		6:
			_attack_meteor_instant() # 陨石攻击(即时伤害)
		7:
			_attack_meteor_persistent() # 陨石攻击(持续伤害区域)
		8:
			_attack_sector_aoe() # 扇形AOE
		9:
			_attack_multi_sector_aoe() # 连续扇形AOE


func _show_attack_indicator(type: int):
	# 实现不同攻击类型的范围显示逻辑
	print("Showing indicator for attack type: ", type)

	if attack_indicator and is_instance_valid(attack_indicator):
		attack_indicator.queue_free()
		attack_indicator = null
	
	await get_tree().process_frame # 确保旧指示器被清理

	attack_indicator = Node2D.new()
	add_child(attack_indicator)
	attack_indicator.global_position = global_position

	var player_pos = PC.player_instance.global_position
	var dir_to_player = global_position.direction_to(player_pos)

	match type:
		3: # 八方向
			var appear_tween = create_tween()
			appear_tween.set_parallel(true)
			for i in 8:
				var direction = Vector2.RIGHT.rotated(deg_to_rad(i * 45))
				# 创建外层红色线条
				var outer_line = Line2D.new()
				outer_line.default_color = Color(1.0, 0.1, 0.0, 0.35)
				outer_line.width = 46 # 与三线攻击一致的宽度
				outer_line.add_point(Vector2.ZERO)
				outer_line.add_point(direction * 600)
				outer_line.modulate.a = 0.0
				attack_indicator.add_child(outer_line)
				
				# 创建内层橙黄色线条
				var inner_line = Line2D.new()
				inner_line.default_color = Color(1.0, 1, 0, 0.35) # 与三线攻击一致的颜色
				inner_line.width = 39 # 与三线攻击一致的宽度
				inner_line.add_point(Vector2.ZERO)
				inner_line.add_point(direction * 600)
				inner_line.modulate.a = 0.0
				attack_indicator.add_child(inner_line)

				var max_length = 600.0 # 八向攻击指示器最大长度
				var extend_speed = 2800.0 # px/s
				var extend_duration = max_length / extend_speed

				# 透明度渐变动画 (与长度延伸并行)
				appear_tween.tween_property(inner_line, "modulate:a", 1.0, extend_duration * 0.25).set_delay(i * 0.025) # 透明度动画时间可以短一些
				appear_tween.tween_property(outer_line, "modulate:a", 1.0, extend_duration * 0.2).set_delay(i * 0.025 + 0.025)

				# 长度延伸动画
				inner_line.set_points([Vector2.ZERO, Vector2.ZERO]) # 初始长度为0
				outer_line.set_points([Vector2.ZERO, Vector2.ZERO]) # 初始长度为0
				appear_tween.tween_method(
					func(value: float):
						if is_instance_valid(inner_line):
							inner_line.set_point_position(1, direction * value)
						if is_instance_valid(outer_line):
							outer_line.set_point_position(1, direction * value),
					0.0, # from
					max_length, # to
					extend_duration
				).set_delay(i * 0.025) # 每条线错开延伸

			attack_indicator.visible = true
		4: # 冲锋
			# 禁止在冲锋选择目标后到冲锋结束前转向
			allow_turning = false
			# 确定冲锋的瞄准方向和最终目标位置
			var aim_direction = global_position.direction_to(PC.player_instance.global_position)
			if aim_direction == Vector2.ZERO:
				aim_direction = Vector2.RIGHT
				
			# 存储基于当前位置和瞄准方向的目标点
			charge_indicator_direction = aim_direction
			charge_target_global_position = global_position + aim_direction * 600.0
			print_debug("存储冲锋指示器方向: ", charge_indicator_direction, " 存储冲锋目标全局位置: ", charge_target_global_position)

			var charge_appear_tween = create_tween()
			charge_appear_tween.set_parallel(true)
			
			var current_frame_texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
			var sprite_height = 40
			if current_frame_texture:
				var unscaled_height = current_frame_texture.get_height()
				sprite_height = abs(unscaled_height * sprite.scale.y)
			
			var outer_line_width = sprite_height + 6
			var inner_line_width = sprite_height * 0.88

			var outer_line_charge = Line2D.new()
			outer_line_charge.default_color = Color(1.0, 0.1, 0.0, 0.45)
			outer_line_charge.width = outer_line_width
			outer_line_charge.add_point(Vector2.ZERO)
			outer_line_charge.add_point(aim_direction * 600) # 使用精确的aim_direction绘制指示器
			outer_line_charge.modulate.a = 0.0
			attack_indicator.add_child(outer_line_charge)

			var inner_line_charge = Line2D.new()
			inner_line_charge.default_color = Color(1.0, 1, 0, 0.75)
			inner_line_charge.width = inner_line_width
			inner_line_charge.add_point(Vector2.ZERO)
			inner_line_charge.add_point(aim_direction * 600) # 使用精确的aim_direction绘制指示器
			inner_line_charge.modulate.a = 0.0
			attack_indicator.add_child(inner_line_charge)

			var charge_max_length = 2400.0
			var charge_extend_speed = 2400.0
			var charge_extend_duration = charge_max_length / charge_extend_speed

			charge_appear_tween.tween_property(inner_line_charge, "modulate:a", 1.0, charge_extend_duration * 0.5)
			charge_appear_tween.tween_property(outer_line_charge, "modulate:a", 1.0, charge_extend_duration * 0.4).set_delay(0.05)

			inner_line_charge.set_points([Vector2.ZERO, Vector2.ZERO])
			outer_line_charge.set_points([Vector2.ZERO, Vector2.ZERO])
			charge_appear_tween.tween_method(
				func(value: float):
					if is_instance_valid(inner_line_charge):
						inner_line_charge.set_point_position(1, aim_direction * value) # 使用精确的aim_direction进行动画
					if is_instance_valid(outer_line_charge):
						outer_line_charge.set_point_position(1, aim_direction * value), # 使用精确的aim_direction进行动画
				0.0,
				charge_max_length,
				charge_extend_duration
			)

			attack_indicator.visible = true
		7: # 旋转激光
			outer_line_node.add_point(Vector2.ZERO)
			outer_line_node.add_point(Vector2.RIGHT * 800)
			inner_line_node.add_point(Vector2.ZERO)
			inner_line_node.add_point(Vector2.RIGHT * 800)
		9: # 黑洞
			var player_pos_for_indicator = PC.player_instance.global_position
			var black_hole_indicator_pos = global_position.direction_to(player_pos_for_indicator) * 200
			var circle_points = 32
			var radius = 100
			for i in circle_points + 1:
				var angle = TAU * i / circle_points
				var point = black_hole_indicator_pos + Vector2(cos(angle), sin(angle)) * radius
				outer_line_node.add_point(point)
				inner_line_node.add_point(point)
	
func _attack_straight_line():
	# 连续射击5次
	for i in range(5):
		# 每次射击前重新瞄准玩家
		var current_player_pos = PC.player_instance.global_position
		var current_direction = global_position.direction_to(current_player_pos)
		
		# 显示攻击指示器
		_show_attack_indicator_for_straight_line(current_direction)
		
		# 等待0.75秒让生成动画播放完毕
		await get_tree().create_timer(0.75).timeout
		
		# 播放消失动画
		_hide_attack_indicator_with_animation()
		
		# 播放射击音效
		$straight.play()
		
		# 进行伤害判定
		var player_pos = PC.player_instance.global_position
		var boss_pos = global_position
		var attack_range_length = 1000.0
		var line_width_tolerance = 25
		
		# 检查玩家是否在攻击直线上
		var line_end = boss_pos + current_direction * attack_range_length
		var distance_to_line = _point_to_line_distance(player_pos, boss_pos, line_end)
		var player_to_boss = player_pos - boss_pos
		var projection_length = player_to_boss.dot(current_direction)
		
		if distance_to_line <= line_width_tolerance and projection_length >= 0 and projection_length <= attack_range_length:
			Global.emit_signal("player_hit")
			var actual_damage = int(atk * (1.0 - PC.damage_reduction_rate))
			PC.apply_damage(actual_damage)
			if PC.pc_hp <= 0:
				PC.player_instance.game_over()
			print("Player hit by straight line attack, damage: ", actual_damage)
				
		await get_tree().create_timer(0.1).timeout
		
	if is_instance_valid(attack_indicator):
			attack_indicator.queue_free()
			attack_indicator = null
	is_attacking = false

# 为直线攻击单独创建攻击指示器显示函数
func _show_attack_indicator_for_straight_line(direction: Vector2):
	if attack_indicator and is_instance_valid(attack_indicator):
		attack_indicator.queue_free()
		attack_indicator = null
	await get_tree().process_frame

	attack_indicator = Node2D.new()
	add_child(attack_indicator)
	attack_indicator.global_position = global_position # 确保指示器在正确位置

	var line_appear_tween = create_tween()
	line_appear_tween.set_parallel(true)

	var outer_line_width = 45
	var inner_line_width = 34

	var outer_line_straight = Line2D.new()
	outer_line_straight.default_color = Color(1.0, 0.1, 0.0, 0.4)
	outer_line_straight.width = outer_line_width
	outer_line_straight.modulate.a = 0.0
	attack_indicator.add_child(outer_line_straight)

	var inner_line_straight = Line2D.new()
	inner_line_straight.default_color = Color(1.0, 1, 0, 0.4)
	inner_line_straight.width = inner_line_width
	inner_line_straight.modulate.a = 0.0
	attack_indicator.add_child(inner_line_straight)

	var straight_max_length = 2800.0 # 直线指示器最大长度
	var straight_extend_speed = 2800.0 # px/s
	var straight_extend_duration = straight_max_length / straight_extend_speed

	line_appear_tween.tween_property(inner_line_straight, "modulate:a", 1.0, straight_extend_duration * 0.1875)
	line_appear_tween.tween_property(outer_line_straight, "modulate:a", 1.0, straight_extend_duration * 0.15).set_delay(0.01875)

	inner_line_straight.set_points([Vector2.ZERO, Vector2.ZERO])
	outer_line_straight.set_points([Vector2.ZERO, Vector2.ZERO])
	line_appear_tween.tween_method(
		func(value: float):
			if is_instance_valid(inner_line_straight):
				inner_line_straight.set_point_position(1, direction * value)
			if is_instance_valid(outer_line_straight):
				outer_line_straight.set_point_position(1, direction * value),
		0.0,
		straight_max_length,
		straight_extend_duration
	)
	attack_indicator.visible = true
	

# 隐藏攻击指示器（带动画）
func _hide_attack_indicator_with_animation():
	if not attack_indicator or not is_instance_valid(attack_indicator):
		return
	
	var disappear_tween = create_tween()
	disappear_tween.set_parallel(true)

	var lines_to_animate = []
	for child in attack_indicator.get_children():
		if child is Line2D and is_instance_valid(child):
			lines_to_animate.append(child)

	# 所有线条同时开始消失，可以根据内外层或创建顺序调整延迟
	var base_delay = 0.0
	var delay_increment = 0.01 # 每条线之间的微小延迟，制造层次感
	
	# 可以根据线条宽度判断内外层，或者直接按子节点顺序处理
	# 这里简单地为所有线条应用动画，如果需要更复杂的内外层消失顺序，需要进一步分类
	for i in range(lines_to_animate.size()):
		var line = lines_to_animate[i]
		# 判断是外层还是内层，可以基于宽度或者命名约定
		var is_outer_line = line.width >= 34.5 # 假设外层线较宽
		var current_delay = base_delay + i * delay_increment
		
		if is_outer_line:
			disappear_tween.tween_property(line, "modulate:a", 0.0, 0.06).set_delay(current_delay)
		else: # 内层线条
			disappear_tween.tween_property(line, "modulate:a", 0.0, 0.06).set_delay(current_delay) # 内层可以稍微晚一点或与外层同步消失

	disappear_tween.finished.connect(func():
		if is_instance_valid(attack_indicator):
			attack_indicator.queue_free()
			attack_indicator = null
	)
	# 确保动画播放
	if not disappear_tween.is_running():
		disappear_tween.play()


func _attack_triple_line():
	print("Attack: Triple Line")
	
	# 连续射击3次
	for i in range(3):
		# 每次射击前重新瞄准玩家
		var current_player_pos = PC.player_instance.global_position
		var base_direction = global_position.direction_to(current_player_pos)
		
		# 显示攻击指示器（带生成动画）
		_show_attack_indicator_for_triple_line(base_direction)
		
		# 等待0.5秒让生成动画播放完毕
		await get_tree().create_timer(0.75).timeout
		
		# 播放消失动画
		_hide_attack_indicator_with_animation()
		
		# 隐藏攻击指示器
		# if attack_indicator:
		# 	attack_indicator.visible = false
		
		# 播放射击音效
		$straight.play()
		
		# 进行伤害判定
		var player_pos = PC.player_instance.global_position
		var boss_pos = global_position
		var attack_range_length = 1600.0
		var line_width_tolerance = 20
		var player_damaged_this_round = false
		
		# 检查玩家是否在三条攻击直线上
		for j in range(-1, 2):
			var attack_direction = base_direction.rotated(deg_to_rad(j * 20))
			var line_end = boss_pos + attack_direction * attack_range_length
			var distance_to_line = _point_to_line_distance(player_pos, boss_pos, line_end)
			var player_to_boss = player_pos - boss_pos
			var projection_length = player_to_boss.dot(attack_direction)
			
			if distance_to_line <= line_width_tolerance and projection_length >= 0 and projection_length <= attack_range_length:
				Global.emit_signal("player_hit")
				var actual_damage = int(atk * (1.0 - PC.damage_reduction_rate))
				PC.apply_damage(actual_damage)
				if PC.pc_hp <= 0:
					PC.player_instance.game_over()
				player_damaged_this_round = true
				print("Player hit by triple line attack, damage: ", actual_damage)
				break # 玩家已受伤，跳出方向循环
				
		await get_tree().create_timer(0.13).timeout
	
	is_attacking = false

# 为三线攻击单独创建攻击指示器显示函数（带动画）
func _show_attack_indicator_for_triple_line(base_direction: Vector2):
	if attack_indicator and is_instance_valid(attack_indicator):
		attack_indicator.queue_free()
		attack_indicator = null
	await get_tree().process_frame

	attack_indicator = Node2D.new()
	add_child(attack_indicator)
	attack_indicator.global_position = global_position # 确保指示器在正确位置

	var tri_appear_tween = create_tween()
	tri_appear_tween.set_parallel(true)
	var base_angle_rad = base_direction.angle()
	var angles_offset = [-deg_to_rad(20), 0, deg_to_rad(20)]

	var outer_width_tri = 30
	var inner_width_tri = 22

	for i in 3:
		var current_angle = base_angle_rad + angles_offset[i]
		var direction = Vector2.RIGHT.rotated(current_angle)
		
		var outer_line_tri = Line2D.new()
		outer_line_tri.default_color = Color(1.0, 0.1, 0.0, 0.35)
		outer_line_tri.width = outer_width_tri
		outer_line_tri.modulate.a = 0.0
		attack_indicator.add_child(outer_line_tri)

		var inner_line_tri = Line2D.new()
		inner_line_tri.default_color = Color(1.0, 1, 0, 0.35)
		inner_line_tri.width = inner_width_tri
		inner_line_tri.modulate.a = 0.0
		attack_indicator.add_child(inner_line_tri)

		var tri_max_length = 2500.0 # 三向指示器最大长度
		var tri_extend_speed = 2800.0 # px/s
		var tri_extend_duration = tri_max_length / tri_extend_speed

		tri_appear_tween.tween_property(inner_line_tri, "modulate:a", 1.0, tri_extend_duration * 0.375).set_delay(i * 0.0375)
		tri_appear_tween.tween_property(outer_line_tri, "modulate:a", 1.0, tri_extend_duration * 0.3).set_delay(i * 0.0375 + 0.0375)

		inner_line_tri.set_points([Vector2.ZERO, Vector2.ZERO])
		outer_line_tri.set_points([Vector2.ZERO, Vector2.ZERO])
		tri_appear_tween.tween_method(
			func(value: float):
				if is_instance_valid(inner_line_tri):
					inner_line_tri.set_point_position(1, direction * value)
				if is_instance_valid(outer_line_tri):
					outer_line_tri.set_point_position(1, direction * value),
			0.0,
			tri_max_length,
			tri_extend_duration
		).set_delay(i * 0.05) # 每条线错开延伸
	attack_indicator.visible = true


func _attack_eight_directions():
	print("Attack: Eight Directions")

	# 检查玩家是否在攻击范围内并造成伤害
	var player_node = PC.player_instance
	if player_node:
		var player_pos = player_node.global_position
		var boss_pos = global_position
		var attack_range_length = 600.0 # 与指示器一致
		var line_width_tolerance = 32
		var player_damaged_this_attack = false

		# 播放射击音效
		$straight.play()
		# 检查玩家是否在任一攻击直线上
		for i in 8:
			var attack_direction = Vector2.RIGHT.rotated(deg_to_rad(i * 45.0))
			var line_end = boss_pos + attack_direction * attack_range_length
			
			# 计算玩家到直线的距离
			var distance_to_line = _point_to_line_distance(player_pos, boss_pos, line_end)
			
			# 检查玩家是否在直线范围内（距离小于容差且在线段长度内）
			var player_to_boss = player_pos - boss_pos
			var projection_length = player_to_boss.dot(attack_direction)
			
			if distance_to_line <= line_width_tolerance and projection_length >= 0 and projection_length <= attack_range_length:
				Global.emit_signal("player_hit")
				var actual_damage = int(atk * (1.0 - PC.damage_reduction_rate))
				PC.apply_damage(actual_damage)
				if PC.pc_hp <= 0:
					PC.player_instance.game_over()
				player_damaged_this_attack = true
				print("Player hit by eight-direction line attack, damage: ", actual_damage)
				break # 玩家已受伤，跳出方向循环

	is_attacking = false


func _attack_charge():
	is_attacking = false
	print("Attack: Charge")

	# 根据 charge_indicator_direction (即瞄准方向) 设置sprite朝向
	# charge_indicator_direction 应该在 _show_attack_indicator 中被正确设置
	if charge_indicator_direction.x < 0:
		sprite.flip_h = true
	else:
		sprite.flip_h = false

	# 使用存储的冲锋方向，从当前位置出发计算目标位置
	# 这样即使Boss在预警期间移动了，也会沿着预警时锁定的方向冲锋
	var charge_direction_normalized = charge_indicator_direction # 预警时锁定的方向
	var charge_distance = 600.0 # 冲锋距离
	var intended_target_pos = global_position + charge_direction_normalized * charge_distance
	print("执行冲锋，从当前位置: ", global_position, " 沿方向: ", charge_direction_normalized, " 冲锋")

	var final_target_pos = intended_target_pos

	# 射线检测以确定与边界的碰撞点，保持方向
	var ray_origin = global_position
	var ray_end = ray_origin + charge_direction_normalized * 2000

	# 定义边界的四个线段
	var boundaries = [
		[Vector2(left_boundary, top_boundary), Vector2(right_boundary, top_boundary)], # 上边界
		[Vector2(left_boundary, bottom_boundary), Vector2(right_boundary, bottom_boundary)], # 下边界
		[Vector2(left_boundary, top_boundary), Vector2(left_boundary, bottom_boundary)], # 左边界
		[Vector2(right_boundary, top_boundary), Vector2(right_boundary, bottom_boundary)] # 右边界
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
				var original_target_distance_sq = (intended_target_pos - ray_origin).length_squared()
				if dist_sq < min_collision_distance_sq and dist_sq <= original_target_distance_sq:
					min_collision_distance_sq = dist_sq
					closest_collision_point = intersection
					collided_with_boundary = true
		# 如果没有找到交点，则clamp到边界
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
		$BossA.play("run")
		allow_turning = true # 允许boss转向


func _on_body_entered(body: Node2D) -> void:
	if (body is CharacterBody2D and not is_dead and not PC.invincible):
		Global.emit_signal("player_hit")
		var actual_damage = int(atk * (1.0 - PC.damage_reduction_rate)) # Boss也应用减伤
		PC.apply_damage(actual_damage)
		if PC.pc_hp <= 0:
			body.game_over()

# 检查怪物是否在可伤害范围内（超出视野20px才能被伤害）
func _is_monster_in_damage_range() -> bool:
	# 获取摄像头
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return true # 如果没有摄像头，默认可以伤害
	
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
			# 隐藏阴影
			var shadow = get_node_or_null("Shadow")
			if shadow:
				shadow.visible = false
			attack_timer.stop()
			# await get_tree().create_timer(1.0).timeout # 等待死亡动画
			queue_free()
		else:
			Global.play_hit_anime(position, is_crit)

func take_damage(damage: int, is_crit: bool, is_summon: bool, damage_type: String) -> void:
	if is_dead:
		return
	if not _is_monster_in_damage_range():
		return
	var final_damage_val = int(damage)
	var damage_offset = Vector2(randf_range(-15, 15), randf_range(-15, 15))
	if is_summon:
		Global.emit_signal("monster_damage", 4, final_damage_val, global_position - Vector2(35, 20) + damage_offset)
	elif is_crit:
		Global.emit_signal("monster_damage", 2, final_damage_val, global_position - Vector2(35, 20) + damage_offset)
	else:
		Global.emit_signal("monster_damage", 1, final_damage_val, global_position - Vector2(35, 20) + damage_offset)
	Global.emit_signal("boss_hp_bar_take_damage", final_damage_val)
	hp -= final_damage_val
	if hp <= 0:
		if not is_dead:
			Global.emit_signal("boss_defeated", get_point)
		is_dead = true
		var shadow = get_node_or_null("Shadow")
		if shadow:
			shadow.visible = false
		attack_timer.stop()
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

#func free_health_bar():
	#if health_bar != null and health_bar.is_inside_tree():
		#health_bar.queue_free()

func apply_knockback(direction: Vector2, force: float):
	# Boss可以有击退抗性，或者完全免疫
	pass

# ============== 新技能: 陨石攻击(即时伤害) ==============
func _attack_meteor_instant():
	"""技能6: 向玩家周围随机掉落陨石，落地后直接判定伤害"""
	print("Attack: Meteor Instant")
	
	var player_pos = PC.player_instance.global_position
	
	# 生成多个陨石预警
	for i in range(METEOR_COUNT):
		var warning_circle = WarnCircleUtil.new()
		add_child(warning_circle)
		
		# 在玩家周围随机位置生成
		var random_offset = Vector2(
			randf_range(-METEOR_SPAWN_RANGE, METEOR_SPAWN_RANGE),
			randf_range(-METEOR_SPAWN_RANGE, METEOR_SPAWN_RANGE)
		)
		var spawn_pos = player_pos + random_offset
		
		# 连接信号
		warning_circle.warning_finished.connect(_on_meteor_warning_finished.bind(warning_circle))
		warning_circle.damage_dealt.connect(_on_meteor_damage_dealt)
		
		# 开始预警 - 使用INSTANT_DAMAGE模式
		warning_circle.start_warning(
			spawn_pos, # 位置
			1.2, # 长宽比(圆形)
			METEOR_RADIUS, # 半径
			METEOR_WARNING_TIME, # 预警时间
			atk * 1.5, # 伤害
			null, # 动画播放器
			WarnCircleUtil.ReleaseMode.INSTANT_DAMAGE # 即时伤害模式
		)
		
		# 每个陨石之间稍微延迟，创造连续感
		await get_tree().create_timer(0.15).timeout
	
	# 等待最后一个陨石预警完成
	await get_tree().create_timer(METEOR_WARNING_TIME + 0.3).timeout
	is_attacking = false

func _on_meteor_warning_finished(warning_circle: Node2D):
	"""陨石预警结束回调"""
	if is_instance_valid(warning_circle):
		warning_circle.cleanup()

func _on_meteor_damage_dealt(damage_amount: float):
	"""陨石造成伤害回调"""
	print("陨石对玩家造成伤害: ", damage_amount)

# ============== 新技能: 陨石攻击(持续伤害区域) ==============
func _attack_meteor_persistent():
	"""技能7: 向玩家周围随机掉落陨石，落地后产生持续伤害区域"""
	print("Attack: Meteor Persistent")
	
	var player_pos = PC.player_instance.global_position
	
	# 生成多个陨石预警
	for i in range(METEOR_COUNT):
		var warning_circle = WarnCircleUtil.new()
		add_child(warning_circle)
		
		# 在玩家周围随机位置生成
		var random_offset = Vector2(
			randf_range(-METEOR_SPAWN_RANGE, METEOR_SPAWN_RANGE),
			randf_range(-METEOR_SPAWN_RANGE, METEOR_SPAWN_RANGE)
		)
		var spawn_pos = player_pos + random_offset
		
		# 连接信号
		warning_circle.area_entered.connect(_on_persist_area_entered)
		warning_circle.area_exited.connect(_on_persist_area_exited)
		
		# 开始预警 - 使用PERSISTENT_AREA模式
		warning_circle.start_warning(
			spawn_pos, # 位置
			1.2, # 长宽比(圆形)
			METEOR_RADIUS, # 半径
			METEOR_WARNING_TIME, # 预警时间
			atk * 0.3, # 持续伤害每次触发的伤害
			null, # 动画播放器
			WarnCircleUtil.ReleaseMode.PERSISTENT_AREA, # 持续区域模式
			null, # 区域精灵场景(TODO: 可添加火焰特效)
			METEOR_PERSIST_DURATION, # 持续时间
			"damage" # 效果类型
		)
		
		# 每个陨石之间稍微延迟
		await get_tree().create_timer(0.15).timeout
	
	# 等待预警完成
	await get_tree().create_timer(METEOR_WARNING_TIME + 0.3).timeout
	is_attacking = false

var persist_damage_timer: float = 0.0
const PERSIST_DAMAGE_INTERVAL: float = 0.5 # 持续伤害间隔

func _on_persist_area_entered(player_node: Node2D):
	"""玩家进入持续伤害区域"""
	print("玩家进入持续伤害区域")
	# 进入时立即造成一次伤害
	_deal_persist_damage()

func _on_persist_area_exited(player_node: Node2D):
	"""玩家离开持续伤害区域"""
	print("玩家离开持续伤害区域")

func _deal_persist_damage():
	"""处理持续伤害"""
	if PC.player_instance and not PC.invincible:
		Global.emit_signal("player_hit")
		var actual_damage = int(atk * 0.3 * (1.0 - PC.damage_reduction_rate))
		PC.apply_damage(actual_damage)
		if PC.pc_hp <= 0:
			PC.player_instance.game_over()
		print("持续伤害: ", actual_damage)

# ============== 新技能: 扇形AOE ==============
func _attack_sector_aoe():
	"""技能8: 向玩家方向发射扇形AOE"""
	print("Attack: Sector AOE")
	
	var player_pos = PC.player_instance.global_position
	var direction_to_player = global_position.direction_to(player_pos)
	var target_point = global_position + direction_to_player * SECTOR_RADIUS
	
	var warning_sector = WarnSectorUtil.new()
	add_child(warning_sector)
	
	# 连接信号
	warning_sector.warning_finished.connect(_on_sector_warning_finished.bind(warning_sector))
	warning_sector.damage_dealt.connect(_on_sector_damage_dealt)
	
	# 开始预警
	warning_sector.start_warning(
		global_position, # 起始位置(Boss位置)
		target_point, # 目标点(决定方向和半径)
		SECTOR_ANGLE, # 扇形角度
		SECTOR_WARNING_TIME, # 预警时间
		atk * 2.0, # 伤害
		null # 动画播放器
	)
	
	# 等待预警完成
	await get_tree().create_timer(SECTOR_WARNING_TIME + 0.3).timeout
	is_attacking = false

func _on_sector_warning_finished(warning_sector: Node2D):
	"""扇形预警结束回调"""
	if is_instance_valid(warning_sector):
		warning_sector.cleanup()

func _on_sector_damage_dealt(damage_amount: float):
	"""扇形AOE造成伤害回调"""
	print("扇形AOE对玩家造成伤害: ", damage_amount)

# ============== 新技能: 连续扇形AOE ==============
func _attack_multi_sector_aoe():
	"""技能9: 连续向玩家方向发射5轮扇形AOE，每次重新瞄准"""
	print("Attack: Multi Sector AOE")
	
	for i in range(MULTI_SECTOR_ROUNDS):
		# 每次攻击前重新瞄准玩家当前位置
		var current_player_pos = PC.player_instance.global_position
		var direction_to_player = global_position.direction_to(current_player_pos)
		var target_point = global_position + direction_to_player * SECTOR_RADIUS
		
		var warning_sector = WarnSectorUtil.new()
		add_child(warning_sector)
		
		# 连接信号
		warning_sector.warning_finished.connect(_on_multi_sector_warning_finished.bind(warning_sector))
		warning_sector.damage_dealt.connect(_on_multi_sector_damage_dealt)
		
		# 开始预警 - 连续攻击用更短的预警时间
		var quick_warning_time = SECTOR_WARNING_TIME * 0.6
		warning_sector.start_warning(
			global_position, # 起始位置(Boss位置)
			target_point, # 目标点(决定方向和半径)
			SECTOR_ANGLE * 0.8, # 连续攻击用稍小的角度
			quick_warning_time, # 更短的预警时间
			atk * 1.2, # 伤害
			null # 动画播放器
		)
		
		print("第 ", i + 1, " 轮扇形AOE，瞄准位置: ", current_player_pos)
		
		# 等待当前轮预警完成后再进行下一轮
		await get_tree().create_timer(quick_warning_time + 0.2).timeout
	
	is_attacking = false

func _on_multi_sector_warning_finished(warning_sector: Node2D):
	"""连续扇形预警结束回调"""
	if is_instance_valid(warning_sector):
		warning_sector.cleanup()

func _on_multi_sector_damage_dealt(damage_amount: float):
	"""连续扇形AOE造成伤害回调"""
	print("连续扇形AOE对玩家造成伤害: ", damage_amount)
