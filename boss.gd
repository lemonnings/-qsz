#extends Area2D
#
#@onready var sprite = $BossA # Boss的动画精灵
#var is_dead : bool = false # Boss是否死亡
#var is_attacking : bool = false # Boss是否正在攻击
#
## 移动模式，可以从bat.gd借鉴或自定义
## 0为从左到右，1为从右向左，2为随机移动，3为靠近角色，4为y轴靠近x轴保持距离，5为从左向右y随机，6为从右向左y随机
#var move_direction : int = 2 
#var target_position : Vector2 # 用于存储移动目标位置
#var update_move_timer : Timer # 用于特定移动模式的计时器
#var random_y_target : float # 用于随机y轴移动
#
#var boss_speed : float = SettingMoster.bat("speed") * 0.8 # Boss移动速度，可以调整
#var hpMax : float = SettingMoster.bat("hp") * 20 # Boss最大生命值，可以调整
#var hp : float = hpMax # Boss当前生命值
#var atk : float = SettingMoster.bat("atk") * 2 # Boss攻击力，可以调整
#var get_point : int = SettingMoster.bat("point") * 10 # 击败Boss获得的积分
#var get_exp : int = SettingMoster.bat("exp") * 10 # 击败Boss获得的经验
#
#var health_bar_shown: bool = false
#var health_bar: Node2D
#var progress_bar: ProgressBar
#
#var attack_timer : Timer # Boss攻击计时器
#var attack_indicator : Node2D # 攻击范围指示器
#
## 子弹场景，需要预加载
#const STRAIGHT_BULLET = preload("res://Scenes/bullet.tscn") # 假设这是直线子弹场景
#const RED_CIRCLE_WARNING = preload("res://Scenes/global/warning.tscn") # 假设这是红圈警告特效
#
## --- 特效与子弹模型独立路径定义 (Independent Paths for Effects and Bullet Models) ---
## 注意: 以下路径均为占位符, 请根据您的项目结构修改为实际的 .tscn 文件路径
## (Note: The following paths are placeholders, please change them to actual .tscn file paths according to your project structure)
#
## 特效场景 (Effect Scenes)
#const BLACK_HOLE_VISUAL_EFFECT_SCENE = preload("res://Scenes/global/blackhole.tscn") # 黑洞视觉特效 (Black Hole Visual Effect)
#const LASER_BEAM_EFFECT_SCENE = preload("res://Scenes/global/blackhole.tscn")             # 激光特效 (Laser Effect)
#
## 子弹场景 (Bullet Scenes)
#const NORMAL_STRAIGHT_BULLET_SCENE = STRAIGHT_BULLET # 原直线子弹作为普通直线弹 (Original straight bullet as normal straight bullet)
#const NORMAL_BARRAGE_BULLET_SCENE = preload("res://Scenes/bullet.tscn") # 普通弹幕子弹 (Normal Barrage Bullet)
#const AIMED_BULLET_SCENE = preload("res://Scenes/bullet.tscn")                   # 自机狙子弹 (Player-Aimed Bullet)
#const FRACTAL_BULLET_SCENE = preload("res://Scenes/bullet.tscn")               # 分裂子弹 (Fractal Bullet)
#const BOUNCING_BULLET_SCENE = preload("res://Scenes/bullet.tscn")             # 弹跳子弹 (Bouncing Bullet)
## --- 特效与子弹模型独立路径定义结束 ---
#
#func _ready():
	#hp = hpMax # 初始化当前血量
	## 初始化移动相关
	#if move_direction == 2 or move_direction == 5 or move_direction == 6:
		#randomize()
		#random_y_target = randf_range(Global.screen_size.y * 0.1, Global.screen_size.y * 0.9)
		#target_position = Vector2(position.x, random_y_target)
	#elif move_direction == 4:
		#update_move_timer = Timer.new()
		#add_child(update_move_timer)
		#update_move_timer.wait_time = 0.5
		#update_move_timer.timeout.connect(_update_target_position_mode4)
		#update_move_timer.start()
		#_update_target_position_mode4()
#
	## 初始化攻击计时器
	#attack_timer = Timer.new()
	#add_child(attack_timer)
	#attack_timer.wait_time = 3.0 # 每3秒攻击一次
	#attack_timer.timeout.connect(_choose_attack)
	#attack_timer.start()
#
	## 初始化攻击指示器 (如果需要一个通用的)
	## attack_indicator = Node2D.new() # 或者加载一个场景
	## add_child(attack_indicator)
	## attack_indicator.visible = false
#
#func show_health_bar():
	#if not health_bar_shown:
		#health_bar = preload("res://Scenes/global/hp_bar.tscn").instantiate()
		#add_child(health_bar)
		#health_bar.z_index = 100
		#progress_bar = health_bar.get_node("HPBar")
		#progress_bar.position = global_position + Vector2(-30, -20) #血条位置调整
		#health_bar_shown = true
		#progress_bar.top_level = true
	#elif progress_bar and progress_bar.is_inside_tree():
		#progress_bar.position = global_position + Vector2(-30, -20)
		#var target_value_hp = (float(hp / hpMax)) * 100
		#if progress_bar.value != target_value_hp:
			#var tween = create_tween()
			#tween.tween_property(progress_bar, "value", target_value_hp, 0.15)
		#
#func free_health_bar():
	#if health_bar != null and health_bar.is_inside_tree():
		#health_bar.queue_free()
#
#func _update_target_position_mode4():
	#if PC.is_player_node_valid():
		#var player_pos = PC.get_player_node().global_position
		#var x_offset = 300
		#if global_position.x < player_pos.x:
			#x_offset = -300
		#target_position = Vector2(player_pos.x + x_offset, player_pos.y)
#
#func _physics_process(delta: float) -> void:
	#if hp < hpMax and hp > 0:
		#show_health_bar()
		#
	#if not is_dead and not is_attacking: # 只有在不攻击的时候才移动
		#_move_pattern(delta)
	#
	## 边界检测 (可以从bat.gd复制并调整)
	#if move_direction == 0 and position.x <= -Global.screen_size.x/2 - 50:
		#position.x = Global.screen_size.x/2 + 40 # 从另一边出来
	#elif move_direction == 1 and position.x >= Global.screen_size.x/2 + 50:
		#position.x = -Global.screen_size.x/2 - 40 # 从另一边出来
	#elif move_direction == 5 and position.x > Global.screen_size.x/2 + 50:
		#position.x = -Global.screen_size.x/2 - 40
	#elif move_direction == 6 and position.x < -Global.screen_size.x/2 - 50:
		#position.x = Global.screen_size.x/2 + 40
#
#func _move_pattern(delta: float):
	## --- 移动逻辑开始 (参考bat.gd并可能修改) ---
	#if move_direction == 0:
		#position += Vector2(boss_speed, 0) * delta
		#sprite.flip_h = false;
	#elif move_direction == 1:
		#position -= Vector2(boss_speed, 0) * delta
		#sprite.flip_h = true;
	#elif move_direction == 2: 
		#if position.distance_to(target_position) < 10:
			#random_y_target = randf_range(Global.screen_size.y * 0.1, Global.screen_size.y * 0.9)
			#target_position = Vector2(randf_range(Global.screen_size.x * 0.1, Global.screen_size.x * 0.9), random_y_target) # x也随机
		#var direction = position.direction_to(target_position)
		#position += direction * boss_speed * delta
		#sprite.flip_h = direction.x < 0
	#elif move_direction == 3: 
		#if PC.is_player_node_valid():
			#var player_pos = PC.get_player_node().global_position
			#var direction = position.direction_to(player_pos)
			#position += direction * boss_speed * delta
			#sprite.flip_h = direction.x < 0
	#elif move_direction == 4: 
		#if PC.is_player_node_valid():
			#var direction = position.direction_to(target_position)
			#if position.distance_to(target_position) > 5: 
				#position += direction * boss_speed * delta
			#sprite.flip_h = direction.x < 0
	#elif move_direction == 5: 
		#var move_vec = Vector2(boss_speed, position.direction_to(Vector2(position.x + 100, random_y_target)).y * boss_speed * 0.5)
		#position += move_vec * delta
		#sprite.flip_h = false
		#if position.distance_to(Vector2(position.x, random_y_target)) < 10 or position.y < Global.screen_size.y * 0.05 or position.y > Global.screen_size.y * 0.95:
			#random_y_target = randf_range(Global.screen_size.y * 0.1, Global.screen_size.y * 0.9)
	#elif move_direction == 6: 
		#var move_vec = Vector2(-boss_speed, position.direction_to(Vector2(position.x - 100, random_y_target)).y * boss_speed * 0.5)
		#position += move_vec * delta
		#sprite.flip_h = true
		#if position.distance_to(Vector2(position.x, random_y_target)) < 10 or position.y < Global.screen_size.y * 0.05 or position.y > Global.screen_size.y * 0.95:
			#random_y_target = randf_range(Global.screen_size.y * 0.1, Global.screen_size.y * 0.9)
	## --- 移动逻辑结束 ---
#
#func _choose_attack():
	#if is_dead or not PC.is_player_node_valid():
		#return
	#
	#is_attacking = true # 标记开始攻击，停止移动
	## 播放攻击前摇动画（如果需要）
	## sprite.play("attack_anticipation") 
	## await get_tree().create_timer(0.5).timeout # 等待前摇
#
	#var attack_type = randi_range(1, 10) # 随机选择攻击类型 (扩展到10种)
	#print("Boss chooses attack: ", attack_type)
#
	## 显示攻击范围 (对于1,2,3,4,7,9)
	#if [1,2,3,4,7,9].has(attack_type): # 7是旋转激光，9是黑洞
		#_show_attack_indicator(attack_type)
		#await get_tree().create_timer(1.0).timeout # 暂停1秒显示范围，此时Boss不动
		#if attack_indicator: attack_indicator.visible = false # 隐藏指示器
#
	#match attack_type:
		#1: _attack_straight_line()
		#2: _attack_triple_line()
		#3: _attack_eight_directions()
		#4: _attack_charge()
		#5: _attack_continuous_shot()
		#6: _attack_random_circles()
		#7: _attack_rotating_laser()
		#8: _attack_summon_minions()
		#9: _attack_black_hole()
		#10: _attack_fullscreen_barrage()
	#
	## 攻击完成后，允许再次移动
	## is_attacking = false # 这个应该在具体攻击动画/计时结束后设置
	## attack_timer.start() # 重新启动攻击计时器 (如果不是one_shot)
#
#func _show_attack_indicator(type: int):
	## 实现不同攻击类型的范围显示逻辑
	## 例如，画线，画扇形等。这里用一个简单的占位符
	#print("Showing indicator for attack type: ", type)
	#if attack_indicator == null:
		#attack_indicator = Node2D.new() # 简单示例，实际应加载或绘制
		#var line = Line2D.new()
		#line.name = "IndicatorLine"
		#line.default_color = Color.RED
		#line.width = 5
		#attack_indicator.add_child(line)
		#add_child(attack_indicator)
	#
	#attack_indicator.global_position = global_position
	#attack_indicator.visible = true
	#var line_node = attack_indicator.get_node_or_null("IndicatorLine") as Line2D
	#if line_node:
		#line_node.clear_points()
		#var player_pos = PC.get_player_node().global_position
		#var dir_to_player = global_position.direction_to(player_pos)
		#match type:
			#1: # 直线
				#line_node.add_point(Vector2.ZERO)
				#line_node.add_point(dir_to_player * 1000) # 指向玩家方向的足够长的线
			#2: # 三方向 (示例：前方和左右斜前方20度)
				#line_node.add_point(Vector2.ZERO)
				#line_node.add_point(dir_to_player * 1000)
				#line_node.add_point(Vector2.ZERO)
				#line_node.add_point(dir_to_player.rotated(deg_to_rad(20)) * 800)
				#line_node.add_point(Vector2.ZERO)
				#line_node.add_point(dir_to_player.rotated(deg_to_rad(-20)) * 800)
			#3: # 八方向
				#for i in 8:
					#line_node.add_point(Vector2.ZERO)
					#line_node.add_point(Vector2.RIGHT.rotated(deg_to_rad(i * 45)) * 600)
			#4: # 冲锋 (显示路径)
				#line_node.add_point(Vector2.ZERO)
				#line_node.add_point(dir_to_player * 400) # 假设冲锋距离400
			#7: # 旋转激光 (显示初始范围或Boss自身高亮)
				## 对于旋转激光，指示器可以是Boss自身周围的一个圆圈，或者初始激光方向
				#line_node.add_point(Vector2.ZERO)
				#line_node.add_point(Vector2.RIGHT * 800) # 初始激光方向
			#9: # 黑洞 (显示生成位置和大致范围)
				#var player_pos_for_indicator = PC.get_player_node().global_position
				#var black_hole_indicator_pos = global_position.direction_to(player_pos_for_indicator) * 200 # 示意在玩家方向一段距离
				## 画一个圆表示黑洞大致范围
				#var circle_points = 32
				#var radius = 100
				#for i in circle_points + 1:
					#var angle = TAU * i / circle_points
					#line_node.add_point(black_hole_indicator_pos + Vector2(cos(angle), sin(angle)) * radius)
#
#
#func _attack_straight_line():
	#print("Attack: Straight Line")
	#if not PC.is_player_node_valid(): 
		#is_attacking = false
		#return
	#var bullet = NORMAL_STRAIGHT_BULLET_SCENE.instantiate() if NORMAL_STRAIGHT_BULLET_SCENE else STRAIGHT_BULLET.instantiate()
	#get_parent().add_child(bullet) # 添加到父节点（通常是主场景）
	#bullet.global_position = global_position
	#bullet.target_direction = global_position.direction_to(PC.get_player_node().global_position)
	#bullet.bullet_damage = atk
	## bullet.speed = 500 # 设置子弹速度
	#is_attacking = false
#
#func _attack_triple_line():
	#print("Attack: Triple Line")
	#if not PC.is_player_node_valid(): 
		#is_attacking = false
		#return
	#var player_dir = global_position.direction_to(PC.get_player_node().global_position)
	#for i in range(-1, 2): # -1, 0, 1
		#var bullet = NORMAL_STRAIGHT_BULLET_SCENE.instantiate() if NORMAL_STRAIGHT_BULLET_SCENE else STRAIGHT_BULLET.instantiate()
		#get_parent().add_child(bullet)
		#bullet.global_position = global_position
		#bullet.target_direction = player_dir.rotated(deg_to_rad(i * 20)) # 例如每条线偏移20度
		#bullet.bullet_damage = atk
	#is_attacking = false
#
#func _attack_eight_directions():
	#print("Attack: Eight Directions")
	#for i in 8:
		#var bullet = NORMAL_STRAIGHT_BULLET_SCENE.instantiate() if NORMAL_STRAIGHT_BULLET_SCENE else STRAIGHT_BULLET.instantiate()
		#get_parent().add_child(bullet)
		#bullet.global_position = global_position
		#bullet.target_direction = Vector2.RIGHT.rotated(deg_to_rad(i * 45)) # 8个方向，每个间隔45度
		#bullet.bullet_damage = atk
	#is_attacking = false
#
#func _attack_charge():
	#print("Attack: Charge")
	#if not PC.is_player_node_valid(): 
		#is_attacking = false
		#return
	#var player_pos = PC.get_player_node().global_position
	#var charge_direction = global_position.direction_to(player_pos)
	#var charge_distance = 400 # 冲锋距离
	#var charge_speed = boss_speed * 3 # 冲锋速度
	#
	## 简单冲锋：直接移动过去。可以做得更复杂，比如带动画和伤害判定
	#var tween = create_tween()
	#tween.tween_property(self, "position", global_position + charge_direction * charge_distance, charge_distance / charge_speed)
	#tween.finished.connect(func(): is_attacking = false)
	## 冲锋伤害判定可以在Area2D的on_body_entered中处理，或者专门做一个冲锋伤害区域
#
#func _attack_continuous_shot():
	#print("Attack: Continuous Shot")
	#var shot_count = 5 # 连续射击次数
	#var shot_interval = 0.3 # 射击间隔
	#
	#for i in range(shot_count):
		#if not PC.is_player_node_valid(): break # 如果玩家失效则停止
		#var bullet = NORMAL_STRAIGHT_BULLET_SCENE.instantiate() if NORMAL_STRAIGHT_BULLET_SCENE else STRAIGHT_BULLET.instantiate()
		#get_parent().add_child(bullet)
		#bullet.global_position = global_position
		#bullet.target_direction = global_position.direction_to(PC.get_player_node().global_position) # 持续瞄准
		#bullet.bullet_damage = atk * 0.7 # 连续射击单发伤害稍低
		#await get_tree().create_timer(shot_interval).timeout
	#is_attacking = false
#
#func _attack_random_circles():
	#print("Attack: Random Circles")
	#var circle_count = 10
	#var circle_interval = 0.3
	#var spawn_radius = 150 # 在玩家身边多大半径内生成
	#
	#for i in range(circle_count):
		#if not PC.is_player_node_valid(): break
		#var player_pos = PC.get_player_node().global_position
		#var random_offset = Vector2(randf_range(-spawn_radius, spawn_radius), randf_range(-spawn_radius, spawn_radius))
		#var spawn_pos = player_pos + random_offset
		#
		#var warning_circle = RED_CIRCLE_WARNING.instantiate()
		#get_parent().add_child(warning_circle)
		#warning_circle.global_position = spawn_pos
		## warning_circle通常有一个动画，在动画结束后造成伤害或生成实际的伤害区域
		## 这里简化，假设警告本身在一段时间后消失，并触发一个伤害（需要额外逻辑）
		## 例如： warning_circle.connect("animation_finished", Callable(self, "_deal_circle_damage").bind(spawn_pos))
		#await get_tree().create_timer(circle_interval).timeout
	#is_attacking = false
#
## func _deal_circle_damage(pos: Vector2):
## 	# 在pos位置造成伤害的逻辑
## 	pass
#
#func _attack_rotating_laser():
	#print("Attack: Rotating Laser")
	#is_attacking = true # 确保在复杂攻击中保持状态
	#var laser_duration = 3.0 # 激光持续时间
	#var rotation_speed = PI # 每秒旋转180度
	#var laser_length = 800
#
	## 使用预定义的激光特效场景
	#var laser_beam # : Node2D
	#if LASER_BEAM_EFFECT_SCENE:
		#laser_beam = LASER_BEAM_EFFECT_SCENE.instantiate()
		#if laser_beam:
			#add_child(laser_beam)
			#laser_beam.global_position = global_position
			## 根据激光特效场景的实现方式进行配置
			#if laser_beam is Line2D: # 如果特效场景是基于Line2D的
				#laser_beam.default_color = Color.YELLOW
				#laser_beam.width = 10
				#laser_beam.clear_points() # 清除可能存在的默认点
				#laser_beam.add_point(Vector2.ZERO)
				#laser_beam.add_point(Vector2.RIGHT * laser_length)
			#elif laser_beam.has_method("setup_laser"): # 如果有自定义的设置方法
				#laser_beam.setup_laser(laser_length, Color.YELLOW, 10) # 假设方法签名
			## 如果特效场景自己处理旋转和长度，可能不需要在这里设置点
		#else:
			#printerr("Failed to instantiate LASER_BEAM_EFFECT_SCENE for rotating laser!")
			#is_attacking = false
			#return
	#else: # Fallback to creating Line2D if scene not defined
		#printerr("LASER_BEAM_EFFECT_SCENE not defined, falling back to Line2D for rotating laser.")
		#laser_beam = Line2D.new()
		#laser_beam.default_color = Color.YELLOW
		#laser_beam.width = 10
		#add_child(laser_beam)
		#laser_beam.global_position = global_position
		#laser_beam.add_point(Vector2.ZERO)
		#laser_beam.add_point(Vector2.RIGHT * laser_length)
#
	#var elapsed_time = 0.0
	#while elapsed_time < laser_duration:
		#laser_beam.rotation += rotation_speed * get_physics_process_delta_time()
		## 这里需要实现激光的伤害判定逻辑，例如每帧检测与玩家的碰撞
		## 简单示例：如果玩家在激光路径上，则造成伤害
		## var laser_end_global = laser_beam.to_global(laser_beam.points[1])
		## var player_node = PC.get_player_node()
		## if player_node and Geometry2D.segment_intersects_circle(global_position, laser_end_global, player_node.global_position, player_node.get_node("CollisionShape2D").shape.radius) > -1:
		## 	PC.pc_hp -= atk * 0.1 # 持续伤害
		#elapsed_time += get_physics_process_delta_time()
		#await get_tree().process_frame
#
	#laser_beam.queue_free()
	#is_attacking = false
#
#func _attack_summon_minions():
	#print("Attack: Summon Minions")
	#var num_minions = 3
	## 假设有一个Minion场景，例如小蝙蝠
	#const MINION_SCENE = preload("res://Scenes/slime.tscn") # 需要替换成实际的小怪场景
#
	#for i in num_minions:
		#var minion = MINION_SCENE.instantiate()
		#get_parent().add_child(minion) # 添加到主场景
		## 在Boss周围随机位置生成
		#var spawn_offset = Vector2(randf_range(-100, 100), randf_range(-100, 100)).normalized() * 150
		#minion.global_position = global_position + spawn_offset
		## 可以给小怪设置一些初始属性或行为
		#await get_tree().create_timer(0.2).timeout # 稍微错开生成时间
	#is_attacking = false
#
#func _attack_black_hole():
	#print("Attack: Black Hole")
	#if not PC.is_player_node_valid():
		#is_attacking = false
		#return
#
	#var player_pos = PC.get_player_node().global_position
	#var black_hole_pos = player_pos + Vector2(randf_range(-50, 50), randf_range(-50, 50)) # 在玩家附近随机生成
#
	## 使用预定义的黑洞视觉特效场景
	#var black_hole_effect_instance # : Node2D
	#if BLACK_HOLE_VISUAL_EFFECT_SCENE:
		#black_hole_effect_instance = BLACK_HOLE_VISUAL_EFFECT_SCENE.instantiate()
		#if black_hole_effect_instance:
			#get_parent().add_child(black_hole_effect_instance)
			#black_hole_effect_instance.global_position = black_hole_pos
			## 假设特效场景有播放动画和处理拉扯的方法，或者它自己处理
			##if black_hole_effect_instance.has_method("play_effect_and_pull"):
				##black_hole_effect_instance.play_effect_and_pull(pull_duration, explosion_radius)
				#
			## 如果特效场景只是视觉，拉扯逻辑仍在此处
		#else:
			#printerr("Failed to instantiate BLACK_HOLE_VISUAL_EFFECT_SCENE!")
	## 如果特效场景未定义或实例化失败，则不显示特效，但逻辑继续
#
	## 拉扯和伤害逻辑
	#var pull_duration = 2.0
	#var pull_strength = 100.0
	#var explosion_radius = 100.0
	#var elapsed_time = 0.0
#
	## 如果特效实例存在，则不需要临时的指示器
	#var temp_black_hole_indicator # : ColorRect = null
	#if not is_instance_valid(black_hole_effect_instance):
		#temp_black_hole_indicator = ColorRect.new()
		#temp_black_hole_indicator.color = Color(0,0,0,0.5)
		#temp_black_hole_indicator.size = Vector2(explosion_radius * 2, explosion_radius * 2)
		#temp_black_hole_indicator.position = black_hole_pos - Vector2(explosion_radius, explosion_radius)
		#get_parent().add_child(temp_black_hole_indicator)
#
	#while elapsed_time < pull_duration:
		#if PC.is_player_node_valid():
			#var player = PC.get_player_node()
			#var dir_to_hole = player.global_position.direction_to(black_hole_pos)
			#player.global_position -= dir_to_hole * pull_strength * get_physics_process_delta_time()
		#elapsed_time += get_physics_process_delta_time()
		#await get_tree().process_frame
#
	#if is_instance_valid(temp_black_hole_indicator):
		#temp_black_hole_indicator.queue_free()
	## 黑洞特效场景也应该在适当时候清理，例如在爆炸后，或者它自己管理生命周期
	#if is_instance_valid(black_hole_effect_instance) and black_hole_effect_instance.has_method("stop_and_cleanup"):
		## black_hole_effect_instance.stop_and_cleanup() # Or just queue_free if it handles cleanup on its own
		#var cleanup_timer = get_tree().create_timer(0.5) # Delay cleanup slightly after explosion logic
		#cleanup_timer.timeout.connect(black_hole_effect_instance.queue_free)
	#elif is_instance_valid(black_hole_effect_instance):
		#var cleanup_timer = get_tree().create_timer(0.5)
		#cleanup_timer.timeout.connect(black_hole_effect_instance.queue_free)
#
	## 黑洞爆炸伤害
	#if PC.is_player_node_valid():
		#var player = PC.get_player_node()
		#if player.global_position.distance_to(black_hole_pos) < explosion_radius:
			#PC.pc_hp -= atk * 1.5 # 黑洞爆炸伤害较高
			#Global.emit_signal("player_hit")
			#print("Black hole exploded on player")
	#
	#is_attacking = false
#
#func _attack_fullscreen_barrage():
	#print("Attack: Fullscreen Barrage")
	#is_attacking = true
	#var barrage_type = randi_range(1, 10) # 随机选择一种弹幕模式 (扩展到10种)
	#print("Barrage type: ", barrage_type)
#
	#match barrage_type:
		#1: _barrage_fan_shot(7, 15.0, 0.2, 250.0) # 7束子弹，每束间隔15度，发射3波，每波间隔0.2秒，速度250
		#2: _barrage_rotating_shot(36, 0.1, 2.0, 200.0, 2*PI) # 每0.1秒发射一发，共发射2秒，速度200，旋转发射器每秒转2PI
		#3: _barrage_player_aimed_shot(5, 0.5, 400.0) # 5发自机狙，每发间隔0.5秒，速度400
		#4: _barrage_random_scatter_shot(50, 0.05, 150.0) # 共50发随机散弹，每发间隔0.05秒，速度150
		#5: _barrage_cross_shot(3, 10, 0.3, 300.0) # 3波交叉弹幕，每波左右各10发，波间隔0.3秒，速度300
		#6: _barrage_ring_expand_contract(12, 200.0, 1.0, 0.5, true) # 12发子弹的环，扩散速度200，持续1秒后收缩，收缩速度0.5倍，会收缩
		#7: _barrage_homing_curve_shot(3, 1.0, 150.0, 0.2) # 3发追踪弹，间隔1秒，速度150，追踪强度0.2
		#8: _barrage_fractal_shot(3, 2, 0.5, 200.0, 0.0) # 初始3发母弹，分裂2层，每层分裂3个，延迟0.5秒分裂，速度200
		#9: _barrage_laser_grid(5, 5, 0.3, 0.5) # 5x5网格，激光持续0.3秒，生成间隔0.5秒
		#10: _barrage_bouncing_shot(10, 0.2, 250.0, 3) # 10发弹跳弹，间隔0.2秒，速度250，最多反弹3次
#
	## 等待所有弹幕发射完毕或达到一个最长时间
	#await get_tree().create_timer(4.0).timeout # 示例：总弹幕持续时间上限，根据最长弹幕调整
	#is_attacking = false
#
## --- 弹幕子模式实现 --- 
#func _barrage_fan_shot(num_bullets_per_wave: int, angle_spread_deg: float, wave_interval: float, bullet_speed: float, num_waves: int = 3):
	#print("Barrage: Fan Shot")
	#if not PC.is_player_node_valid(): return
	#var base_dir = global_position.direction_to(PC.get_player_node().global_position)
	#var total_angle_rad = deg_to_rad(angle_spread_deg * (num_bullets_per_wave -1))
	#var start_angle_rad = base_dir.angle() - total_angle_rad / 2.0
#
	#for w in num_waves:
		#for i in num_bullets_per_wave:
			#var bullet = NORMAL_BARRAGE_BULLET_SCENE.instantiate() if NORMAL_BARRAGE_BULLET_SCENE else STRAIGHT_BULLET.instantiate()
			#get_parent().add_child(bullet)
			#bullet.global_position = global_position
			#var current_angle = start_angle_rad + deg_to_rad(angle_spread_deg) * i
			#bullet.target_direction = Vector2.RIGHT.rotated(current_angle)
			#bullet.bullet_damage = atk * 0.6
			## bullet.speed = bullet_speed # 假设子弹脚本有speed属性
		#await get_tree().create_timer(wave_interval).timeout
#
#func _barrage_rotating_shot(bullets_per_second: int, shot_interval: float, duration: float, bullet_speed: float, rotation_speed_rad_per_sec: float):
	#print("Barrage: Rotating Shot")
	#var elapsed_time = 0.0
	#var current_rotation = 0.0
	#var fire_point_offset = Vector2(50, 0) # 稍微偏离Boss中心发射
#
	#while elapsed_time < duration:
		#var bullet = NORMAL_BARRAGE_BULLET_SCENE.instantiate() if NORMAL_BARRAGE_BULLET_SCENE else STRAIGHT_BULLET.instantiate()
		#get_parent().add_child(bullet)
		#var rotated_offset = fire_point_offset.rotated(current_rotation)
		#bullet.global_position = global_position + rotated_offset
		#bullet.target_direction = Vector2.RIGHT.rotated(current_rotation)
		#bullet.bullet_damage = atk * 0.5
		## bullet.speed = bullet_speed
		#
		#current_rotation += rotation_speed_rad_per_sec * shot_interval
		#elapsed_time += shot_interval
		#await get_tree().create_timer(shot_interval).timeout
#
#func _barrage_player_aimed_shot(num_shots: int, interval: float, bullet_speed: float):
	#print("Barrage: Player-Aimed Shot")
	#for i in num_shots:
		#if not PC.is_player_node_valid(): break
		#var bullet = AIMED_BULLET_SCENE.instantiate() if AIMED_BULLET_SCENE else STRAIGHT_BULLET.instantiate()
		#get_parent().add_child(bullet)
		#bullet.global_position = global_position
		#bullet.target_direction = global_position.direction_to(PC.get_player_node().global_position)
		#bullet.bullet_damage = atk * 0.8 # 自机狙伤害略高
		## bullet.speed = bullet_speed
		#await get_tree().create_timer(interval).timeout
#
#func _barrage_random_scatter_shot(total_bullets: int, interval: float, bullet_speed: float):
	#print("Barrage: Random Scatter Shot")
	#for i in total_bullets:
		#var bullet = NORMAL_BARRAGE_BULLET_SCENE.instantiate() if NORMAL_BARRAGE_BULLET_SCENE else STRAIGHT_BULLET.instantiate()
		#get_parent().add_child(bullet)
		#bullet.global_position = global_position
		#bullet.target_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		#bullet.bullet_damage = atk * 0.4
		## bullet.speed = bullet_speed
		#await get_tree().create_timer(interval).timeout
#
#func _barrage_cross_shot(num_waves: int, bullets_per_side_per_wave: int, wave_interval: float, bullet_speed: float):
	#print("Barrage: Cross Shot")
	#var screen_width = Global.screen_size.x
	#var screen_height = Global.screen_size.y
#
	#for w in num_waves:
		## 从左侧发射
		#for i in bullets_per_side_per_wave:
			#var bullet_left = NORMAL_BARRAGE_BULLET_SCENE.instantiate() if NORMAL_BARRAGE_BULLET_SCENE else STRAIGHT_BULLET.instantiate()
			#get_parent().add_child(bullet_left)
			#var start_y_left = (screen_height / (bullets_per_side_per_wave + 1)) * (i + 1)
			#bullet_left.global_position = Vector2(-screen_width / 2 - 20, start_y_left)
			#bullet_left.target_direction = Vector2.RIGHT
			#bullet_left.bullet_damage = atk * 0.5
			## bullet_left.speed = bullet_speed
#
		## 从右侧发射
		#for i in bullets_per_side_per_wave:
			#var bullet_right = NORMAL_BARRAGE_BULLET_SCENE.instantiate() if NORMAL_BARRAGE_BULLET_SCENE else STRAIGHT_BULLET.instantiate()
			#get_parent().add_child(bullet_right)
			#var start_y_right = (screen_height / (bullets_per_side_per_wave + 1)) * (i + 1)
			#bullet_right.global_position = Vector2(screen_width / 2 + 20, start_y_right)
			#bullet_right.target_direction = Vector2.LEFT
			#bullet_right.bullet_damage = atk * 0.5
			## bullet_right.speed = bullet_speed
		#
		## 如果希望左右同时发射完再等待，可以把await放在外层
		## await get_tree().create_timer(0.05).timeout # 快速发射完一波内的子弹
		#await get_tree().create_timer(wave_interval).timeout
#
#func _barrage_ring_expand_contract(num_bullets: int, expand_speed: float, expand_duration: float, contract_speed_multiplier: float, should_contract: bool):
	#print("Barrage: Ring Expand/Contract")
	#var angle_step = TAU / num_bullets
	#var bullets_array = []
	#for i in num_bullets:
		#var bullet = NORMAL_BARRAGE_BULLET_SCENE.instantiate() if NORMAL_BARRAGE_BULLET_SCENE else STRAIGHT_BULLET.instantiate()
		#get_parent().add_child(bullet)
		#bullet.global_position = global_position
		#var angle = i * angle_step
		#bullet.target_direction = Vector2.RIGHT.rotated(angle)
		## bullet.speed = expand_speed # 假设子弹有speed属性，或者在bullet的_physics_process中用direction * speed
		#bullet.bullet_damage = atk * 0.5
		#bullets_array.append(bullet)
#
	## 扩散阶段
	#await get_tree().create_timer(expand_duration).timeout
#
	## 收缩阶段 (可选)
	#if should_contract:
		#for bullet_node in bullets_array:
			#if is_instance_valid(bullet_node):
				## 反转方向并调整速度，或者让子弹自己有收缩逻辑
				#bullet_node.target_direction = -bullet_node.target_direction 
				## bullet_node.speed = expand_speed * contract_speed_multiplier
		## await get_tree().create_timer(expand_duration / contract_speed_multiplier if contract_speed_multiplier > 0 else expand_duration).timeout
	## 子弹存活时间或手动清理
	## for b in bullets_array: if is_instance_valid(b): b.queue_free()
#
#func _barrage_homing_curve_shot(num_shots: int, interval: float, bullet_speed: float, homing_factor: float):
	#print("Barrage: Homing Curve Shot")
	#for i in num_shots:
		#if not PC.is_player_node_valid(): break
		## This bullet type likely needs its own scene due to complex logic (homing + curve)
		## Using AIMED_BULLET_SCENE as a placeholder if specific homing/curve scene isn't defined
		#var bullet = AIMED_BULLET_SCENE.instantiate() if AIMED_BULLET_SCENE else STRAIGHT_BULLET.instantiate() # 假设子弹有追踪逻辑
		#get_parent().add_child(bullet)
		#bullet.global_position = global_position
		#bullet.target_direction = global_position.direction_to(PC.get_player_node().global_position)
		## bullet.speed = bullet_speed
		## bullet.homing_factor = homing_factor # 传递给子弹脚本
		#bullet.bullet_damage = atk * 0.7
		## 曲线逻辑可能需要在子弹自己的脚本中实现，根据homing_factor调整朝向玩家的速度
		#await get_tree().create_timer(interval).timeout
#
#func _barrage_fractal_shot(initial_bullets: int, split_generations: int, bullets_per_split: int, split_delay: float, bullet_speed: float, current_generation: int = 0, base_angle_offset_deg: float = 0.0):
	#print("Barrage: Fractal Shot - Gen: ", current_generation)
	#if current_generation > split_generations: return
#
	#var angle_step_deg = 360.0 / initial_bullets
	#for i in initial_bullets:
		#var bullet = FRACTAL_BULLET_SCENE.instantiate() if FRACTAL_BULLET_SCENE else STRAIGHT_BULLET.instantiate()
		#get_parent().add_child(bullet)
		#bullet.global_position = global_position
		#var current_angle_deg = i * angle_step_deg + base_angle_offset_deg
		#bullet.target_direction = Vector2.RIGHT.rotated(deg_to_rad(current_angle_deg))
		## NOTE: 子弹 (bullet.tscn) 脚本需要自行处理速度 (speed) 和移动逻辑。
		## bullet.speed = bullet_speed
		#bullet.bullet_damage = atk * (0.6 - current_generation * 0.1) # 越分裂伤害越低
#
		#if current_generation < split_generations:
			#var bullet_instance = bullet # 保持引用
			## NOTE: 实际的分裂逻辑应在子弹脚本中实现。
			## 子弹可以有一个 timer，在超时后调用一个 split() 方法，该方法会实例化新的子弹。
			## 或者，Boss脚本通过信号或其他方式通知子弹进行分裂。
			## 此处的 _spawn_fractal_children 是一个辅助函数，模拟从Boss角度控制分裂。
			#var split_timer = get_tree().create_timer(split_delay)
			#split_timer.timeout.connect(func(): 
				#if is_instance_valid(bullet_instance):
					#var new_spawn_pos = bullet_instance.global_position # 分裂位置为母弹当前位置
					#print("INFO: Bullet at ", bullet_instance.global_position, " is triggering fractal spawn via Boss script.")
					#bullet_instance.queue_free() # 母弹消失
					#_spawn_fractal_children(new_spawn_pos, bullets_per_split, split_generations, bullets_per_split, split_delay, bullet_speed * 0.8, current_generation + 1, current_angle_deg)
			#)
#
## 辅助分形弹幕的子弹生成，避免在lambda中直接递归自身
#func _spawn_fractal_children(pos: Vector2, initial_bullets: int, split_generations: int, bullets_per_split: int, split_delay: float, bullet_speed: float, current_generation: int = 0, base_angle_offset_deg: float = 0.0):
	#print("Spawning fractal children at: ", pos, " Gen: ", current_generation)
	#if current_generation > split_generations: return
	#var angle_step_deg = 360.0 / initial_bullets
	#var spread_angle_deg = 60.0 # 子弹分裂时的扩散角度
#
	#for i in initial_bullets:
		#var bullet = FRACTAL_BULLET_SCENE.instantiate() if FRACTAL_BULLET_SCENE else STRAIGHT_BULLET.instantiate()
		#get_parent().add_child(bullet)
		#bullet.global_position = pos
		## 计算分裂角度，基于父弹方向做一定偏移
		#var relative_angle_deg = (i - (initial_bullets -1) / 2.0) * (spread_angle_deg / max(1, initial_bullets -1) if initial_bullets > 1 else 0)
		#var current_angle_deg = base_angle_offset_deg + relative_angle_deg
		#bullet.target_direction = Vector2.RIGHT.rotated(deg_to_rad(current_angle_deg))
		## bullet.speed = bullet_speed
		#bullet.bullet_damage = atk * (0.6 - current_generation * 0.1)
#
		#if current_generation < split_generations:
			#var bullet_instance = bullet
			#var split_timer = get_tree().create_timer(split_delay)
			#split_timer.timeout.connect(func():
				#if is_instance_valid(bullet_instance):
					#var next_pos = bullet_instance.global_position
					#bullet_instance.queue_free()
					#_spawn_fractal_children(next_pos, bullets_per_split, split_generations, bullets_per_split, split_delay, bullet_speed * 0.8, current_generation + 1, current_angle_deg)
			#)
#
#func _barrage_laser_grid(rows: int, cols: int, laser_duration: float, spawn_interval: float):
	#print("Barrage: Laser Grid")
	## 需要一个LaserBeam场景或用Line2D模拟
	## const LASER_BEAM_SCENE = preload("res://path_to_laser_beam.tscn")
	#var screen_w = Global.screen_size.x
	#var screen_h = Global.screen_size.y
#
	#for r in rows:
		#var y_pos = (screen_h / (rows + 1)) * (r + 1)
		#var laser_h # : Node2D
		#if LASER_BEAM_EFFECT_SCENE:
			#laser_h = LASER_BEAM_EFFECT_SCENE.instantiate()
			#if not laser_h:
				#printerr("Failed to instantiate LASER_BEAM_EFFECT_SCENE for laser grid (horizontal)!")
				#laser_h = Line2D.new() # Fallback
		#else:
			#laser_h = Line2D.new() # Fallback if scene not defined
#
		#get_parent().add_child(laser_h)
		## Configure laser_h (whether it's from scene or new Line2D)
		#if laser_h is Line2D:
			#laser_h.default_color = Color.ORANGE_RED
			#laser_h.width = 5
			#laser_h.clear_points()
			## Points should be local to the laser_h node if its global_position is set, or global if not.
			## Assuming laser_h is added directly and its position is (0,0) relative to boss, or boss is at (0,0) in its own scene.
			## The original code implies points are relative to the Boss's global_position if the Line2D is a direct child.
			## If LASER_BEAM_EFFECT_SCENE sets its own position, this needs adjustment.
			## For simplicity, let's assume the Line2D is positioned at the Boss's origin for now.
			#laser_h.add_point(Vector2(-screen_w/2, y_pos) - global_position) # Original logic for points relative to boss
			#laser_h.add_point(Vector2(screen_w/2, y_pos) - global_position)
		#elif laser_h.has_method("setup_beam_segment"):
			## Example: laser_h.setup_beam_segment(global_position + Vector2(-screen_w/2, y_pos), global_position + Vector2(screen_w/2, y_pos), Color.ORANGE_RED, 5)
			## This depends heavily on the LASER_BEAM_EFFECT_SCENE's API
			#pass # Placeholder for actual setup call
		#get_parent().add_child(laser_h)
		#laser_h.default_color = Color.ORANGE_RED
		#laser_h.width = 5
		#laser_h.add_point(Vector2(-screen_w/2, y_pos) - global_position) # 相对于Boss的偏移
		#laser_h.add_point(Vector2(screen_w/2, y_pos) - global_position)
		## laser_h.activate(laser_duration) # 假设激光有激活和自动销毁逻辑
		#var timer_h = get_tree().create_timer(laser_duration)
		#timer_h.timeout.connect(laser_h.queue_free)
		#await get_tree().create_timer(spawn_interval / 2.0).timeout
#
	#for c in cols:
		#var x_pos = (screen_w / (cols + 1)) * (c + 1)
		#var laser_v # : Node2D
		#if LASER_BEAM_EFFECT_SCENE:
			#laser_v = LASER_BEAM_EFFECT_SCENE.instantiate()
			#if not laser_v:
				#printerr("Failed to instantiate LASER_BEAM_EFFECT_SCENE for laser grid (vertical)!")
				#laser_v = Line2D.new() # Fallback
		#else:
			#laser_v = Line2D.new() # Fallback if scene not defined
#
		#get_parent().add_child(laser_v)
		#if laser_v is Line2D:
			#laser_v.default_color = Color.ORANGE_RED
			#laser_v.width = 5
			#laser_v.clear_points()
			#laser_v.add_point(Vector2(x_pos - screen_w/2, 0) - global_position)
			#laser_v.add_point(Vector2(x_pos - screen_w/2, screen_h) - global_position)
		#elif laser_v.has_method("setup_beam_segment"):
			#pass # Placeholder for actual setup call
		#get_parent().add_child(laser_v)
		#laser_v.default_color = Color.ORANGE_RED
		#laser_v.width = 5
		#laser_v.add_point(Vector2(x_pos - screen_w/2, 0) - global_position)
		#laser_v.add_point(Vector2(x_pos - screen_w/2, screen_h) - global_position)
		## laser_v.activate(laser_duration)
		#var timer_v = get_tree().create_timer(laser_duration)
		#timer_v.timeout.connect(laser_v.queue_free)
		#await get_tree().create_timer(spawn_interval / 2.0).timeout
#
#func _barrage_bouncing_shot(num_bullets: int, interval: float, bullet_speed: float, max_bounces: int):
	#print("Barrage: Bouncing Shot")
	#for i in num_bullets:
		#var bullet = BOUNCING_BULLET_SCENE.instantiate() if BOUNCING_BULLET_SCENE else STRAIGHT_BULLET.instantiate() # 假设子弹有反弹逻辑
		#get_parent().add_child(bullet)
		#bullet.global_position = global_position
		#bullet.target_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		## bullet.speed = bullet_speed
		## bullet.max_bounces = max_bounces # 传递给子弹脚本
		#bullet.bullet_damage = atk * 0.5
		## 反弹逻辑需要在子弹脚本中处理，检测到屏幕边缘时改变target_direction
		#await get_tree().create_timer(interval).timeout
#
#
#func _on_body_entered(body: Node2D) -> void:
	#if(body is CharacterBody2D and not is_dead and not PC.invincible) :
		#Global.emit_signal("player_hit")
		#var actual_damage = int(atk * (1.0 - PC.damage_reduction_rate)) # Boss也应用减伤
		#PC.pc_hp -= actual_damage
		#if PC.pc_hp <= 0:
			#body.game_over()
#
#func _on_area_entered(area: Area2D) -> void:
	#if area.is_in_group("bullet") and area.has_method("get_bullet_damage_and_crit_status"):
		#var bullet_data = area.get_bullet_damage_and_crit_status()
		#var damage = bullet_data["damage"]
		#var is_crit = bullet_data["is_crit"]
		#var final_damage_val = damage
		## Boss是否也受反弹子弹特殊加成？这里先按普通伤害计算
		#hp -= int(final_damage_val)
		#
		#if hp <= 0:
			#free_health_bar()
			## $AnimatedSprite2D.play("death") # Boss死亡动画
			#if not is_dead:
				#get_tree().current_scene.point += get_point
				#Global.total_points += get_point
				#PC.pc_exp += get_exp
				## $death.play() # Boss死亡音效
				#Global.emit_signal("boss_defeated") # 发送Boss被击败信号
				#area.queue_free()
			#is_dead = true
			#attack_timer.stop()
			## await get_tree().create_timer(1.0).timeout # 等待死亡动画
			#queue_free()
		#else:
			#Global.play_hit_anime(position, is_crit)
			#area.queue_free()
