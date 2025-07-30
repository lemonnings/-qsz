extends CharacterBody2D

@export var move_speed : float = 120.0 * (1 + (Global.cultivation_zhuifeng_level * 0.02) + PC.pc_speed)

@export var hp : int = 0
@export var maxHP : int = 0

@export var animator : AnimatedSprite2D

#@export var joystick_left : VirtualJoystick
#
#@export var joystick_right : VirtualJoystick

@export var pinch_zoom_module : Node      
@export var virtual_joystick_manager : Node 

@export var bullet_scene : PackedScene
@export var branch_scene : PackedScene
@export var moyan_scene : PackedScene
@export var summon_scene : PackedScene
@export var riyan_scene : PackedScene
@export var ringfire_scene : PackedScene

@export var fire_speed : Timer
@export var branch_fire_speed : Timer
@export var moyan_fire_speed : Timer
@export var riyan_fire_speed : Timer
@export var ringFire_fire_speed : Timer
@export var invincible_time : Timer

var active_summons: Array = []  # 当前活跃的召唤物列表


@onready var sprite = $AnimatedSprite2D
@export var sprite_direction_right : bool


# 摄像头缩放相关变量
@export var min_zoom : float = 2.4  # 最小缩放（视野最大）
@export var max_zoom : float = 5.2  # 最大缩放（视野最小）
@export var zoom_speed : float = 0.05  # 缩放速度
@onready var camera : Camera2D = $Camera2D

# 主要定义player主体的行为以及部分子弹逻辑
func _ready() -> void:
	# 将player节点添加到player组中
	add_to_group("player")
	
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
	
	camera.zoom = Vector2(3, 3)
	
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

func _process(_delta: float) -> void:
	# Rotation:
	#if joystick_right and joystick_right.is_pressed:
		#rotation = joystick_right.output.angle()
		
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
		## 环形子弹逻辑
		#if PC.selected_rewards.has("ring_bullet") and not PC.is_game_over and not Global.in_menu:
			#PC.real_time += _delta
			#if PC.real_time - PC.ring_bullet_last_shot_time >= PC.ring_bullet_interval:
				#_fire_ring_bullets()
				#PC.ring_bullet_last_shot_time = PC.real_time


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
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(-zoom_speed)
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q:
			Global.emit_signal("buff_added", "attack_boost", 10.0, 3)



func _reset_camera() -> void:
	camera.zoom = Vector2(3.0, 3.0)
	
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
			input_vector = Input.get_vector("left","right","up","down") 
			
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
			
		move_and_slide()


func game_over():
	if not PC.is_game_over:
		#防止出现gameover动画候杀了怪升级了
		PC.pc_exp = -1000000
		PC.is_game_over = true
		
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
		for angle_deg in [-45.0, 45.0]:
			var side_bullet = bullet_scene.instantiate()
			side_bullet.set_bullet_scale(Vector2(bullet_node_size, bullet_node_size))
			var rotated_direction = base_direction.rotated(deg_to_rad(angle_deg))
			side_bullet.set_direction(rotated_direction)
			side_bullet.position = spawn_position
			side_bullet.penetration_count = PC.swordQi_penetration_count
			# Assuming bullet_damage is a variable in your bullet script, adjust damage accordingly
			# side_bullet.damage = calculate_bullet_damage() * 0.5 # Half damage
			if PC.selected_rewards.has("rebound"): side_bullet.is_rebound = false
			get_tree().current_scene.add_child(side_bullet)

	if PC.selected_rewards.has("SplitSwordQi11"):
		var back_bullet = bullet_scene.instantiate()
		back_bullet.set_bullet_scale(Vector2(bullet_node_size, bullet_node_size))
		var back_direction = base_direction.rotated(deg_to_rad(180.0)) # -180 or 180 degrees for backward
		back_bullet.set_direction(back_direction)
		back_bullet.position = spawn_position
		back_bullet.penetration_count = PC.swordQi_penetration_count
		# back_bullet.damage = calculate_bullet_damage() # Full damage for back bullet
		if PC.selected_rewards.has("rebound"): back_bullet.is_rebound = false
		get_tree().current_scene.add_child(back_bullet)
	
	
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


func _on_player_hit() -> void:
	PC.invincible = true
	invincible_time.start(0.0)
	if PC.pc_hp > 0:
		$HitSound.play()
		sprite.modulate = Color(1, 0.5, 0.5)


# 确定召唤物类型
func determine_summon_type() -> int:
	if PC.new_summon == "gold":
		PC.new_summon = ""
		return 3  # 金色强化追踪召唤物
	elif PC.new_summon == "orange":
		PC.new_summon = ""
		return 2  # 橙色追踪召唤物
	elif PC.new_summon == "purple":
		PC.new_summon = ""
		return 1  # 紫色定向召唤物
	else:
		PC.new_summon = ""
		return 0  # 蓝色随机召唤物


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
	
# 更新所有技能的攻击速度
func update_skill_attack_speeds() -> void:
	# 基础攻速公式：初始攻速 / (1 + PC.pc_atk_speed)
	# 主攻击
	fire_speed.wait_time = 1.0 / (1 + PC.pc_atk_speed)
	
	# 分支攻击
	if branch_fire_speed:
		branch_fire_speed.wait_time = 2.0 / (1 + PC.pc_atk_speed)
	
	# 魔焰攻击
	if moyan_fire_speed:
		moyan_fire_speed.wait_time = 4.0 / (1 + PC.pc_atk_speed)
	
	# 日焰攻击
	if riyan_fire_speed:
		riyan_fire_speed.wait_time = 0.051 / (1 + PC.pc_atk_speed)
	
	# 环形火焰攻击
	if ringFire_fire_speed:
		ringFire_fire_speed.wait_time = 0.051 / (1 + PC.pc_atk_speed)

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
		ring_bullet.penetration_count = PC.swordQi_penetration_count  # 设置穿透次数
		
		get_tree().current_scene.add_child(ring_bullet)
