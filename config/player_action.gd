extends CharacterBody2D

@export var move_speed: float = 120.0 * (1 + (Global.cultivation_zhuifeng_level * 0.02) + PC.pc_speed)

@export var hp: int = 0
@export var maxHP: int = 0

@export var animator: AnimatedSprite2D

var last_move_time: float = -1.0 # -1表示未初始化
var chenjing_effect: Node2D = null # 沉静纹章的脚底光圈效果

#@export var joystick_left : VirtualJoystick
#
#@export var joystick_right : VirtualJoystick

@export var pinch_zoom_module: Node
@export var virtual_joystick_manager: Node

@export var bullet_scene: PackedScene
@export var branch_scene: PackedScene
@export var moyan_scene: PackedScene
@export var summon_scene: PackedScene
@export var riyan_scene: PackedScene
@export var ringfire_scene: PackedScene

@export var fire_speed: Timer
@export var branch_fire_speed: Timer
@export var moyan_fire_speed: Timer
@export var riyan_fire_speed: Timer
@export var ringFire_fire_speed: Timer
@export var invincible_time: Timer

var active_summons: Array = [] # 当前活跃的召唤物列表


@onready var sprite = $AnimatedSprite2D
@export var sprite_direction_right: bool


# 摄像头缩放相关变量
@export var min_zoom: float = 1.4 # 最小缩放（视野最大）
@export var max_zoom: float = 4.5 # 最大缩放（视野最小）
@export var zoom_speed: float = 0.05 # 缩放速度
@onready var camera: Camera2D = $Camera2D

# 主要定义player主体的行为以及部分子弹逻辑
func _ready() -> void:
	# 将player节点添加到player组中
	add_to_group("player")
	
	# 创建脚底阴影
	CharacterEffects.create_shadow(self, 22.0, 9.0, 7.5)
	
	hp = PC.pc_hp
	sprite_direction_right = not sprite.flip_h
	Global.connect("player_hit", Callable(self, "_on_player_hit"))
	Global.connect("zoom_camera", Callable(self, "_zoom_camera"))
	Global.connect("reset_camera", Callable(self, "_reset_camera"))
	# 初始化技能攻速
	update_skill_attack_speeds()
	Global.connect("_fire_ring_bullets", Callable(self, "_fire_ring_bullets"))
	
	Global.connect("skill_cooldown_complete", Callable(self, "_on_fire"))
	Global.connect("skill_cooldown_complete_branch", Callable(self, "_on_fire_branch"))
	Global.connect("skill_cooldown_complete_moyan", Callable(self, "_on_fire_moyan"))
	Global.connect("skill_cooldown_complete_riyan", Callable(self, "_on_fire_riyan"))
	Global.connect("skill_cooldown_complete_ringFire", Callable(self, "_on_fire_ringFire"))
	
	camera.zoom = Vector2(1.6, 1.6)
	
	# 设置音效使用SFX总线
	setup_audio_buses()
	
	# 初始化 last_move_time 为当前时间
	last_move_time = Time.get_unix_time_from_system()
	
	if PC.has_riyan and PC.first_has_riyan_pc:
	# 实例化日炎攻击
		if riyan_scene:
			var riyan_instance = riyan_scene.instantiate()
			get_parent().add_child(riyan_instance)
			riyan_instance.global_position = global_position
			PC.first_has_riyan_pc = false
	
	## 初始化虚拟摇杆
	#joystick_center = joystick_position
	#joystick_current = joystick_center

func setup_audio_buses() -> void:
	# 设置所有音效使用SFX总线
	if has_node("RunningSound"):
		$RunningSound.bus = "SFX"
	if has_node("GameOver"):
		$GameOver.bus = "SFX"
	if has_node("FireSound"):
		$FireSound.bus = "SFX"
	if has_node("HitSound"):
		$HitSound.bus = "SFX"

func _process(_delta: float) -> void:
	# Rotation:
	#if joystick_right and joystick_right.is_pressed:
		#rotation = joystick_right.output.angle()
	if Global.in_town:
		# 主城中只使用局外属性（追风修炼等级），不使用局内移速 PC.pc_speed
		move_speed = 240.0 * (1 + (Global.cultivation_zhuifeng_level * 0.02))
		
	if velocity == Vector2.ZERO or PC.is_game_over:
		$RunningSound.stop()
	elif not $RunningSound.playing:
		$RunningSound.play()
	
	#if !Global.in_town :
	# 更新技能攻速（当攻速属性改变时）
	if PC.last_atk_speed != PC.pc_atk_speed:
		update_skill_attack_speeds()
		# 发射信号通知技能攻速更新
		Global.emit_signal("skill_attack_speed_updated")
		PC.last_atk_speed = PC.pc_atk_speed
		
	# 环形子弹逻辑
	if PC.selected_rewards.has("ring_bullet") and not PC.is_game_over and not Global.in_menu:
		if PC.real_time - PC.ring_bullet_last_shot_time >= PC.ring_bullet_interval:
			_fire_ring_bullets()
			PC.ring_bullet_last_shot_time = PC.real_time

	# 若已获得浪形子弹奖励，则开启浪形子弹
	if PC.selected_rewards.has("wave_bullet"):
		PC.wave_bullet_enabled = true

	# 浪形子弹冷却：当启用且满足冷却时自动发射
	if PC.wave_bullet_enabled and not PC.is_game_over and not Global.in_menu:
		if (PC.real_time - PC.wave_bullet_last_shot_time) >= PC.wave_bullet_interval:
			PC.wave_bullet_last_shot_time = PC.real_time
			_fire_wave_bullets()


# 处理鼠标滚轮缩放、键盘输入和触摸输入
func _input(event: InputEvent) -> void:
	var handled_by_module = false
	if pinch_zoom_module and pinch_zoom_module.has_method("handle_input_event"):
		if pinch_zoom_module.handle_input_event(event):
			handled_by_module = true

	if not handled_by_module and virtual_joystick_manager and virtual_joystick_manager.has_method("handle_input_event"):
		if virtual_joystick_manager.handle_input_event(event):
			handled_by_module = true
	
	if handled_by_module:
		return # Event was handled by a module, stop further processing in this function

	# Keep mouse wheel zoom if not handled by pinch_zoom_module or for non-touch devices
	if event is InputEventMouseButton and not Global.in_synthesis:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(-zoom_speed)
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q:
			Global.emit_signal("buff_added", "attack_boost", 10.0, 3)


func _reset_camera() -> void:
	camera.zoom = Vector2(2, 2)
	
func _zoom_camera(zoom_delta: float) -> void:
	var new_zoom = camera.zoom.x + zoom_delta
	# 限制缩放范围
	new_zoom = clamp(new_zoom, min_zoom, max_zoom)
	
	# 检查缩放后是否会超出场景边界
	var viewport_size = get_viewport().get_visible_rect().size
	var camera_rect_size = viewport_size / new_zoom
	
	# 获取场景边界（从Camera2D的limit设置）
	var limit_left = camera.limit_left
	var limit_right = camera.limit_right
	var limit_top = camera.limit_top
	var limit_bottom = camera.limit_bottom
	
	# 计算场景大小
	var scene_width = limit_right - limit_left
	var scene_height = limit_bottom - limit_top
	
	# 确保缩放后的视野不会超出场景边界
	if camera_rect_size.x <= scene_width and camera_rect_size.y <= scene_height:
		camera.zoom = Vector2(new_zoom, new_zoom)

func _physics_process(_delta: float) -> void:
	if not PC.is_game_over and not PC.movement_disabled:
		# 获取输入向量（键盘或虚拟摇杆）
		var input_vector = Vector2.ZERO
		
		# 虚拟摇杆
		if OS.has_feature("mobile"):
			if virtual_joystick_manager and virtual_joystick_manager.has_method("get_left_stick_output"):
				input_vector = virtual_joystick_manager.get_left_stick_output()
			# If virtual_joystick_manager is not set up, input_vector remains ZERO for mobile movement.
			# Add fallback if necessary: 
			# else: input_vector = Input.get_vector("ui_left","ui_right","ui_up","ui_down") 
		else: # Keyboard
			input_vector = Input.get_vector("left", "right", "up", "down")
			
		velocity = input_vector * move_speed
		
		if velocity.x < -0.01:
			sprite.flip_h = true
			sprite_direction_right = false
		elif velocity.x > 0.01:
			sprite.flip_h = false
			sprite_direction_right = true
		
		if velocity == Vector2.ZERO:
			animator.play("idle")
		else:
			animator.play("run")
			last_move_time = Time.get_unix_time_from_system()
		
		# 更新沉静buff视觉效果
		update_chenjing_visual()
		
		move_and_slide()


func game_over():
	if not PC.is_game_over:
		#防止出现gameover动画候杀了怪升级了
		PC.pc_exp = -1000000
		PC.is_game_over = true
		
		# 禁用自动发射技能，防止回主城后还会触发
		PC.wave_bullet_enabled = false
		PC.ring_bullet_last_shot_time = PC.real_time + 999999 # 防止环形子弹触发
		
		# 清除所有纹章效果，防止回主城后继续触发
		EmblemManager.clear_all_emblems()
		
		# 停止DPS计数器
		Global.stop_dps_counter()
		
		Global.save_game()
		$GameOver.play()
		animator.play("game_over")
		get_tree().current_scene.show_game_over()
		$RestartTimer.start()


func _on_fire_idle() -> void:
	if Global.in_menu or Global.in_town:
		return
	if PC.is_game_over:
		return
	pass
	
func _on_fire(skill_id: int) -> void:
	if Global.in_menu or Global.in_town:
		return
	if PC.is_game_over:
		return
	_on_fire_detail()
	
	
func _on_fire_branch(skill_id: int) -> void:
	if Global.in_menu or Global.in_town:
		return
	if PC.is_game_over:
		return
	_on_fire_detail_branch()

func _on_fire_moyan(skill_id: int) -> void:
	if Global.in_menu or Global.in_town:
		return
	if PC.is_game_over:
		return
	_on_fire_detail_moyan()

func _on_fire_riyan(skill_id: int) -> void:
	if Global.in_menu or Global.in_town:
		return
	if PC.is_game_over:
		return
	_on_fire_detail_riyan()

func _on_fire_ringFire(skill_id: int) -> void:
	if Global.in_menu or Global.in_town:
		return
	if PC.is_game_over:
		return
	_on_fire_detail_ringFire()

func _on_fire_detail() -> void:
	var bullet_node_size = PC.bullet_size
	var base_direction = Vector2.RIGHT # Default direction
	var spawn_position = position

	# 直接攻击最近的敌人，不再使用预测瞄准
	var nearest_enemy = find_nearest_enemy()
	if nearest_enemy:
		# 计算朝向最近敌人的方向
		base_direction = (nearest_enemy.position - position).normalized()
	else:
		# 没有敌人时使用角色朝向
		if not sprite_direction_right:
			base_direction = Vector2.LEFT
		else:
			base_direction = Vector2.RIGHT

	# Play sound
	$FireSound.play()

	# Instantiate bullets
	# Default bullet
	var main_bullet = bullet_scene.instantiate()
	main_bullet.set_bullet_scale(Vector2(bullet_node_size, bullet_node_size))
	main_bullet.set_direction(base_direction)
	main_bullet.position = spawn_position
	main_bullet.penetration_count = PC.swordQi_penetration_count
	# Assuming bullet_damage is a variable in your bullet script, otherwise, you might need to pass damage as a parameter
	# main_bullet.damage = calculate_bullet_damage() # Placeholder for actual damage calculation
	if PC.selected_rewards.has("rebound"): main_bullet.is_rebound = false
	get_tree().current_scene.add_child(main_bullet)

	if PC.selected_rewards.has("SplitSwordQi1"):
		for angle_deg in [45.0, 315.0]: # Changed to 45° and 315° (equivalent to -45°) as per requirement
			var side_bullet = bullet_scene.instantiate()
			side_bullet.set_bullet_scale(Vector2(bullet_node_size, bullet_node_size))
			var rotated_direction = base_direction.rotated(deg_to_rad(angle_deg))
			side_bullet.set_direction(rotated_direction)
			side_bullet.position = spawn_position
			side_bullet.penetration_count = PC.swordQi_penetration_count
			side_bullet.is_other_sword_wave = true # Mark as additional sword wave for damage calculation (50% damage)
			if PC.selected_rewards.has("rebound"): side_bullet.is_rebound = false
			get_tree().current_scene.add_child(side_bullet)

	if PC.selected_rewards.has("SplitSwordQi11"):
		var back_bullet = bullet_scene.instantiate()
		back_bullet.set_bullet_scale(Vector2(bullet_node_size, bullet_node_size))
		var back_direction = base_direction.rotated(deg_to_rad(180.0)) # 180 degrees for backward
		back_bullet.set_direction(back_direction)
		back_bullet.position = spawn_position
		back_bullet.penetration_count = PC.swordQi_penetration_count
		back_bullet.is_other_sword_wave = true # Mark as additional sword wave for damage calculation (50% damage)
		if PC.selected_rewards.has("rebound"): back_bullet.is_rebound = false
		get_tree().current_scene.add_child(back_bullet)
	
func fire_extra_attack(damage_multiplier: float) -> void:
	var bullet_node_size = PC.bullet_size
	var base_direction = Vector2.RIGHT # Default direction
	var spawn_position = position

	# 直接攻击最近的敌人，不再使用预测瞄准
	var nearest_enemy = find_nearest_enemy()
	if nearest_enemy:
		# 计算朝向最近敌人的方向
		base_direction = (nearest_enemy.position - position).normalized()
	else:
		# 没有敌人时使用角色朝向
		if not sprite_direction_right:
			base_direction = Vector2.LEFT
		else:
			base_direction = Vector2.RIGHT

	# Play sound
	$FireSound.play()

	# Instantiate bullets
	# Default bullet
	var main_bullet = bullet_scene.instantiate()
	main_bullet.set_bullet_scale(Vector2(bullet_node_size, bullet_node_size))
	main_bullet.set_direction(base_direction)
	main_bullet.position = spawn_position
	main_bullet.penetration_count = PC.swordQi_penetration_count
	# Set extra damage multiplier
	main_bullet.extra_damage_multiplier = damage_multiplier
	main_bullet.is_extra_attack_flag = true
	
	if PC.selected_rewards.has("rebound"): main_bullet.is_rebound = false
	get_tree().current_scene.add_child(main_bullet)
	
func _on_fire_detail_branch() -> void:
	var bullet_node_size = PC.bullet_size
	var base_direction = Vector2.RIGHT # Default direction
	var spawn_position = position

	# 直接攻击最近的敌人，不再使用预测瞄准
	var nearest_enemy = find_nearest_enemy()
	if nearest_enemy:
		# 计算朝向最近敌人的方向
		base_direction = (nearest_enemy.position - position).normalized()
	else:
		# 没有敌人时使用角色朝向
		if not sprite_direction_right:
			base_direction = Vector2.LEFT
		else:
			base_direction = Vector2.RIGHT

	# Play sound
	#$FireSound.play()

	var main_bullet = branch_scene.instantiate()
	main_bullet.set_bullet_scale(Vector2(bullet_node_size, bullet_node_size))
	main_bullet.set_direction(base_direction)
	main_bullet.position = spawn_position
	get_tree().current_scene.add_child(main_bullet)


func _on_fire_detail_moyan() -> void:
	var bullet_node_size = PC.bullet_size
	var base_direction = Vector2.RIGHT # Default direction
	var spawn_position = position

	# 直接攻击最近的敌人，不再使用预测瞄准
	var nearest_enemy = find_nearest_enemy()
	if nearest_enemy:
		# 计算朝向最近敌人的方向
		base_direction = (nearest_enemy.position - position).normalized()
	else:
		# 没有敌人时使用角色朝向
		if not sprite_direction_right:
			base_direction = Vector2.LEFT
		else:
			base_direction = Vector2.RIGHT

	# Play sound
	#$FireSound.play()

	var main_bullet = moyan_scene.instantiate()
	main_bullet.set_bullet_scale(Vector2(bullet_node_size, bullet_node_size))
	main_bullet.set_direction(base_direction)
	main_bullet.position = spawn_position
	get_tree().current_scene.add_child(main_bullet)


func _on_fire_detail_riyan() -> void:
	Global.emit_signal("riyan_damage_triggered")

func _on_fire_detail_ringFire() -> void:
	Global.emit_signal("ringFire_damage_triggered")


func reload_scene() -> void:
	if Global.main_menu_instance != null:
		Global.emit_signal("normal_bgm")
		# 设置菜单状态
		Global.in_menu = true
		SceneChange.change_scene("res://Scenes/main_menu.tscn", true)


func _on_player_hit(attacker: Node2D = null) -> void:
	# 处理铁骨纹章的反弹效果
	if EmblemManager.has_emblem("tiegu"):
		var tiegu_stack = EmblemManager.get_emblem_stack("tiegu")
		var reflected_damage = PC.pc_max_hp * 0.25 * tiegu_stack
		# 找到攻击者并反弹伤害
		if attacker and is_instance_valid(attacker) and attacker.has_method("take_damage"):
			attacker.take_damage(int(reflected_damage), false, false, "reflection")
		else:
			# 如果没有指定攻击者，查找最近的敌人
			var nearest_enemy = find_nearest_enemy()
			if nearest_enemy and is_instance_valid(nearest_enemy) and nearest_enemy.has_method("take_damage"):
				nearest_enemy.take_damage(int(reflected_damage), false, false, "reflection")

	PC.invincible = true
	invincible_time.start(0.0)
	if PC.pc_hp > 0:
		$HitSound.play()
		sprite.modulate = Color(1, 0.5, 0.5)


# 确定召唤物类型
func determine_summon_type() -> int:
	if PC.new_summon == "gold":
		PC.new_summon = ""
		return 3 # 金色强化追踪召唤物
	elif PC.new_summon == "orange":
		PC.new_summon = ""
		return 2 # 橙色追踪召唤物
	elif PC.new_summon == "purple":
		PC.new_summon = ""
		return 1 # 紫色定向召唤物
	else:
		PC.new_summon = ""
		return 0 # 蓝色随机召唤物


# 添加新召唤物（当获得召唤物奖励时调用）
func add_summon(summon_type: int) -> void:
	if not summon_scene:
		return
	
	var summon = summon_scene.instantiate()
	summon.set_summon_type(summon_type)
	
	# 设置召唤物位置（在玩家周围随机位置）
	var offset = Vector2(randf_range(-120, 120), randf_range(-120, 120))
	summon.position = position + offset
	
	# 添加到场景和管理列表
	get_parent().add_child(summon)
	active_summons.append(summon)


# 移除失效的召唤物
func remove_invalid_summons() -> void:
	for i in range(active_summons.size() - 1, -1, -1):
		var summon = active_summons[i]
		if not summon or not is_instance_valid(summon):
			active_summons.remove_at(i)

# 寻找最近的敌人
func find_nearest_enemy() -> Node2D:
	var nearest_enemy = null
	var nearest_distance = INF
	
	# 获取场景中的所有敌人
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		var distance = position.distance_to(enemy.position)
		if distance > PC.swordQi_range + 15:
			continue
		if enemy and is_instance_valid(enemy):
			# 计算距离
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_enemy = enemy
	
	return nearest_enemy

# 更新所有召唤物的属性
func update_summons_properties() -> void:
	for summon in active_summons:
		if summon and is_instance_valid(summon):
			# 更新发射间隔
			if summon.has_method("update_fire_interval"):
				summon.update_fire_interval()
			# 可以添加其他属性更新逻辑
	
func stop_invincible() -> void:
	sprite.modulate = Color(1, 1, 1)
	PC.invincible = false

func get_last_move_time() -> float:
	return last_move_time

# 创建沉静纹章的椭圆形脚底光圈
func create_chenjing_effect() -> Node2D:
	var effect = Node2D.new()
	effect.z_index = -1 # 在角色下方
	
	# 创建椭圆形光圈 Sprite
	var ellipse_sprite = Sprite2D.new()
	ellipse_sprite.name = "EllipseSprite"
	ellipse_sprite.texture = create_ellipse_texture()
	ellipse_sprite.modulate = Color(0.3, 0.6, 1.0, 0.6) # 蓝色，60%透明度
	# 将光圈放在脚底位置（向下偏移）
	ellipse_sprite.position = Vector2(0, 7) # 脚底位置
	effect.add_child(ellipse_sprite)
	
	return effect

# 创建椭圆形纹理
func create_ellipse_texture() -> ImageTexture:
	var width = 36
	var height = 15 # 椭圆形，宽大于高
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	var center_x = width / 2.0
	var center_y = height / 2.0
	var radius_x = width / 2.0 - 2
	var radius_y = height / 2.0 - 2
	var border_thickness = 2.0
	
	# 绘制椭圆形边框
	for x in range(width):
		for y in range(height):
			var dx = (x - center_x) / radius_x
			var dy = (y - center_y) / radius_y
			var dist = sqrt(dx * dx + dy * dy)
			
			# 判断是否在椭圆边框上
			var inner_dist = sqrt(pow((x - center_x) / (radius_x - border_thickness), 2) + pow((y - center_y) / (radius_y - border_thickness), 2))
			
			if dist <= 1.0 and inner_dist >= 1.0:
				# 边框区域 - 从内到外渐变
				var alpha = 1.0 - (1.0 - dist) * 2
				alpha = clamp(alpha, 0.3, 1.0)
				image.set_pixel(x, y, Color(0.5, 0.8, 1.0, alpha))
			elif dist <= 1.0:
				# 内部填充 - 淡薄的蓝色
				image.set_pixel(x, y, Color(0.3, 0.6, 1.0, 0.15))
	
	var texture = ImageTexture.create_from_image(image)
	return texture

# 更新沉静buff视觉效果
func update_chenjing_visual():
	# 检查是否拥有沉静纹章
	if not EmblemManager.has_emblem("chenjing"):
		# 没有纹章，隐藏效果
		if chenjing_effect and is_instance_valid(chenjing_effect):
			chenjing_effect.visible = false
		return
	
	# 动态创建光圈效果（如果还没创建）
	if not chenjing_effect or not is_instance_valid(chenjing_effect):
		chenjing_effect = create_chenjing_effect()
		add_child(chenjing_effect)
	
	var last_move = get_last_move_time()
	var current = Time.get_unix_time_from_system()
	
	if current - last_move >= 1.0: # 1秒未移动
		chenjing_effect.visible = true
		# 添加脉动效果
		var pulse = 0.6 + 0.2 * sin(current * 3.0)
		var ellipse_sprite = chenjing_effect.get_node("EllipseSprite")
		if ellipse_sprite:
			ellipse_sprite.modulate.a = pulse
			# 轻微缩放效果
			var scale_factor = 1.0 + 0.05 * sin(current * 2.0)
			ellipse_sprite.scale = Vector2(scale_factor, scale_factor)
	else:
		chenjing_effect.visible = false
	
# 更新定时器的等待时间，同时保持当前进度的百分比
func update_timer_preserve_ratio(timer: Timer, new_wait_time: float) -> void:
	if not timer:
		return
	
	# 如果新的等待时间和当前的等待时间几乎一样，就不做任何操作
	if abs(timer.wait_time - new_wait_time) < 0.0001:
		return
		
	if timer.is_stopped():
		timer.wait_time = new_wait_time
		return
	
	var old_wait_time = timer.wait_time
	if old_wait_time <= 0:
		timer.wait_time = new_wait_time
		return
		
	# 计算剩余时间的比例
	var ratio_left = timer.time_left / old_wait_time
	var new_time_left = new_wait_time * ratio_left
	
	# 防止时间过短
	new_time_left = max(0.02, new_time_left)
	
	# start(time) 会重置计时器并设置 wait_time 为 time
	# 注意：如果 start(new_time_left) 被调用，wait_time 也会变成 new_time_left
	timer.start(new_time_left)
	# 立即将 wait_time 设置回新的完整周期，这样下一次循环就会使用新的周期
	timer.wait_time = new_wait_time

# 更新所有技能的攻击速度
func update_skill_attack_speeds() -> void:
	# 计算踏风buff的冷却缩减
	var cooldown_reduction = 0.0
	if EmblemManager.has_emblem("tafeng"):
		var tafeng_stack = EmblemManager.get_emblem_stack("tafeng")
		var move_speed_percent = PC.pc_speed * 100
		cooldown_reduction = (move_speed_percent / 10.0) * 0.005 * tafeng_stack
	
	# 基础攻速公式：初始攻速 / (1 + PC.pc_atk_speed + 冷却缩减)
	var total_speed_multiplier = 1 + PC.pc_atk_speed + cooldown_reduction
	
	# 主攻击
	update_timer_preserve_ratio(fire_speed, 0.66 / total_speed_multiplier)
	
	# 分支攻击
	update_timer_preserve_ratio(branch_fire_speed, 1.5 / total_speed_multiplier)
	
	# 魔焰攻击
	update_timer_preserve_ratio(moyan_fire_speed, 4.0 / total_speed_multiplier)
	
	# 日焰攻击
	update_timer_preserve_ratio(riyan_fire_speed, 1.0 / total_speed_multiplier)
	
	# 环形火焰攻击
	update_timer_preserve_ratio(ringFire_fire_speed, 0.051 / total_speed_multiplier)

# 发射环形子弹
func _fire_ring_bullets() -> void:
	var bullet_count = PC.ring_bullet_count
	var bullet_size = PC.ring_bullet_size_multiplier
	var spawn_position = position
	
	# 播放音效
	$FireSound.play()
	
	# 按圆形状均匀散布子弹
	for i in range(bullet_count):
		var angle = (2.0 * PI * i) / bullet_count
		
		# 创建圆形状的方向向量
		var ring_bullet = bullet_scene.instantiate()
		# 设置反弹属性
		if PC.selected_rewards.has("rebound"):
			ring_bullet.is_rebound = false
		ring_bullet.set_bullet_scale(Vector2(bullet_size, bullet_size))
		ring_bullet.direction = Vector2(cos(angle) * 1, sin(angle) * 1.0).normalized()
		ring_bullet.position = spawn_position
		
		# 设置环形子弹的特殊属性
		ring_bullet.set_ring_bullet_damage(PC.ring_bullet_damage_multiplier)
		ring_bullet.penetration_count = PC.swordQi_penetration_count # 设置穿透次数
		
		get_tree().current_scene.add_child(ring_bullet)

# 浪形子弹
# 每发伤害为角色攻击的50%（通过 bullet.gd 的 set_wave_bullet_damage 配置）
func _fire_wave_bullets() -> void:
	var bullet_count = PC.wave_bullet_count
	var spawn_position = position
	var base_direction = Vector2.RIGHT
	if not sprite_direction_right:
		base_direction = Vector2.LEFT
	
	# 播放音效
	$FireSound.play()
	
	var current_arc_deg = 35.0 + PC.wave_bullet_count
	for i in range(bullet_count):
		# 在当前弧度范围内随机一个偏移角度
		var offset_deg = randf_range(-current_arc_deg / 2.0, current_arc_deg / 2.0)
		var shot_direction = base_direction.rotated(deg_to_rad(offset_deg)).normalized()
		
		# 实例化并配置子弹
		var wave_bullet = bullet_scene.instantiate()
		if PC.selected_rewards.has("rebound"):
			wave_bullet.is_rebound = false
		wave_bullet.set_bullet_scale(Vector2(PC.bullet_size, PC.bullet_size))
		wave_bullet.set_direction(shot_direction)
		wave_bullet.position = spawn_position
		wave_bullet.penetration_count = PC.swordQi_penetration_count
		# 设置浪形子弹伤害倍数：50%
		wave_bullet.set_wave_bullet_damage(PC.wave_bullet_damage_multiplier)
		get_tree().current_scene.add_child(wave_bullet)
		
		# 弧度逐步增大，最大75°
		current_arc_deg = min(current_arc_deg + 1.0, 75.0)
		
		# 每发间隔0.05秒
		await get_tree().create_timer(0.02).timeout
