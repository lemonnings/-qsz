extends CharacterBody2D

@export var move_speed : float = 120.0 * (1 + (Global.move_speed_level * 0.02) + PC.pc_speed)

@export var hp : int = 0
@export var maxHP : int = 0

@export var animator : AnimatedSprite2D

@export var joystick_left : VirtualJoystick

@export var joystick_right : VirtualJoystick


@export var bullet_scene : PackedScene
@export var summon_scene : PackedScene

@export var fire_speed : Timer
@export var invincible_time : Timer

var active_summons: Array = []  # 当前活跃的召唤物列表

@onready var sprite = $AnimatedSprite2D
@export var sprite_direction_right : bool


# 摄像头缩放相关变量
@export var min_zoom : float = 2.5  # 最小缩放（视野最大）
@export var max_zoom : float = 5.2  # 最大缩放（视野最小）
@export var zoom_speed : float = 0.1  # 缩放速度
@onready var camera : Camera2D = $Camera2D

# 手机适配相关变量
@export var virtual_joystick_enabled : bool = true  # 是否启用虚拟摇杆
@export var joystick_deadzone : float = 0.1  # 摇杆死区
@export var joystick_radius : float = 100.0  # 摇杆半径
@export var joystick_position : Vector2 = Vector2(150, 400)  # 摇杆位置

# 触摸输入相关变量
var touch_points : Dictionary = {}  # 存储触摸点信息
var joystick_touch_id : int = -1  # 摇杆触摸ID
var joystick_center : Vector2  # 摇杆中心位置
var joystick_current : Vector2  # 当前摇杆位置
var is_joystick_active : bool = false  # 摇杆是否激活
var movement_vector : Vector2 = Vector2.ZERO  # 移动向量

# 双指缩放相关变量
var pinch_start_distance : float = 0.0  # 双指初始距离
var pinch_start_zoom : float = 0.0  # 缩放开始时的zoom值
var is_pinching : bool = false  # 是否正在双指缩放

# 主要定义player主体的行为以及部分子弹逻辑
func _ready() -> void:
	maxHP = PC.pc_hp
	hp = PC.pc_hp
	sprite_direction_right = not sprite.flip_h
	Global.connect("player_hit", Callable(self, "_on_player_hit"))
	Global.connect("zoom_camera", Callable(self, "_zoom_camera"))
	Global.connect("reset_camera", Callable(self, "_reset_camera"))
	
	# 设置初始缩放为当前的3.83（接近最小缩放）
	camera.zoom = Vector2(3.5, 3.5)
	
	# 初始化虚拟摇杆
	joystick_center = joystick_position
	joystick_current = joystick_center

func _process(_delta: float) -> void:
	# Rotation:
	if joystick_right and joystick_right.is_pressed:
		rotation = joystick_right.output.angle()
		
	if velocity == Vector2.ZERO or PC.is_game_over:
		$RunningSound.stop()
	elif not $RunningSound.playing:
		$RunningSound.play()
	
	if !Global.in_town :
		fire_speed.wait_time = 1.0 * pow(0.98, Global.atk_speed_level) / (1 + PC.pc_atk_speed)
		
		# 环形子弹逻辑
		if PC.selected_rewards.has("ring_bullet") and not PC.is_game_over and not Global.in_menu:
			PC.real_time += _delta
			if PC.real_time - PC.ring_bullet_last_shot_time >= PC.ring_bullet_interval:
				_fire_ring_bullets()
				PC.ring_bullet_last_shot_time = PC.real_time



# 处理鼠标滚轮缩放、键盘输入和触摸输入
func _input(event: InputEvent) -> void:
	# 处理鼠标滚轮缩放
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# 滚轮向上，缩小视野（增加缩放值）
			_zoom_camera(zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# 滚轮向下，放大视野（减少缩放值）
			_zoom_camera(-zoom_speed)
	
	# 处理键盘按键
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q:
			# 按下Q键添加攻击力提升buff
			Global.emit_signal("buff_added", "attack_boost", 10.0, 3)
	
	# 处理触摸输入
	if event is InputEventScreenTouch:
		_handle_touch_input(event)
	elif event is InputEventScreenDrag:
		_handle_drag_input(event)


func _reset_camera() -> void:
	camera.zoom = Vector2(3.5, 3.5)
	
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
	if not PC.is_game_over:
		# 获取输入向量（键盘或虚拟摇杆）
		var input_vector = Vector2.ZERO
		
		# 虚拟摇杆
		if OS.has_feature("mobile"):
			input_vector = Input.get_vector("ui_left","ui_right","ui_up","ui_down")
		else:
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
	_on_fire_detail()
	
	
func _on_fire_detail() -> void:
	var bullet_node_size = PC.bullet_size
	var input_vector = Input.get_vector("left", "right", "up", "down")
	var base_direction = Vector2.RIGHT # 默认向右
	
	if input_vector.x < -0.01:
		base_direction = Vector2.LEFT
	elif input_vector.x > 0.01:
		base_direction = Vector2.RIGHT
	else:
		# 如果没有输入，使用当前sprite方向
		if not sprite_direction_right:
			base_direction = Vector2.LEFT
		else:
			base_direction = Vector2.RIGHT

	var spawn_position
	if not sprite_direction_right:
		spawn_position = position + Vector2(-12, 4)
	else:
		spawn_position = position + Vector2(12, 0)

	# 播放音效
	$FireSound.play()

	# 获取当前是否存在多角度子弹
	if PC.selected_rewards.has("fiveway"):
		for angle in [-26.0,-13.0, 0.0, 13.0, 26.0]:
			var new_bullet = bullet_scene.instantiate()
			new_bullet.set_bullet_scale(Vector2(bullet_node_size, bullet_node_size))
			
			var rotated_direction = base_direction.rotated(deg_to_rad(angle))
			new_bullet.set_direction(rotated_direction)
			new_bullet.position = spawn_position
			
			# 设置反弹属性
			if PC.selected_rewards.has("rebound"):
				new_bullet.is_rebound = false  # 原始子弹应该为false才能反弹
			
			get_tree().current_scene.add_child(new_bullet)
	
	elif PC.selected_rewards.has("threeway"):
		for angle in [-13.0, 0.0, 13.0]:
			var new_bullet = bullet_scene.instantiate()
			new_bullet.set_bullet_scale(Vector2(bullet_node_size, bullet_node_size))
			
			var rotated_direction = base_direction.rotated(deg_to_rad(angle))
			new_bullet.set_direction(rotated_direction)
			new_bullet.position = spawn_position
			
			# 设置反弹属性
			if PC.selected_rewards.has("rebound"):
				new_bullet.is_rebound = false  # 原始子弹应该为false才能反弹
			
			get_tree().current_scene.add_child(new_bullet)
	else:
		# 没有 threeway，只发射一颗普通子弹
		var bullet_node = bullet_scene.instantiate()
		bullet_node.set_bullet_scale(Vector2(bullet_node_size, bullet_node_size))
		bullet_node.set_direction(base_direction)
		bullet_node.position = spawn_position
		
		# 设置反弹属性
		if PC.selected_rewards.has("rebound"):
			bullet_node.is_rebound = false  # 原始子弹应该为false才能反弹
		
		get_tree().current_scene.add_child(bullet_node)
	

func reload_scene() -> void:
	if Global.main_menu_instance != null:
		Global.emit_signal("normal_bgm")		
		# 设置菜单状态
		Global.in_menu = true
		get_tree().change_scene_to_packed(Global.main_menu_instance)


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
func cleanup_summons() -> void:
	for i in range(active_summons.size() - 1, -1, -1):
		var summon = active_summons[i]
		if not summon or not is_instance_valid(summon):
			active_summons.remove_at(i)

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
	
# 发射环形子弹
func _fire_ring_bullets() -> void:
	var bullet_count = PC.ring_bullet_count
	var bullet_size = PC.ring_bullet_size_multiplier
	var spawn_position = position
	
	# 播放音效
	$FireSound.play()
	
	# 按椭圆形状均匀散布子弹
	for i in range(bullet_count):
		var angle = (2.0 * PI * i) / bullet_count
		
		# 创建椭圆形状的方向向量
		var ring_bullet = bullet_scene.instantiate()
		# 设置反弹属性
		if PC.selected_rewards.has("rebound"):
			ring_bullet.is_rebound = false
		ring_bullet.set_bullet_scale(Vector2(bullet_size, bullet_size))
		ring_bullet.direction = Vector2(cos(angle) * 4, sin(angle) * 1.0).normalized()
		ring_bullet.position = spawn_position
		
		# 设置环形子弹的特殊属性
		ring_bullet.set_ring_bullet_damage(PC.ring_bullet_damage_multiplier)
		
		get_tree().current_scene.add_child(ring_bullet)

# 处理触摸输入
func _handle_touch_input(event: InputEventScreenTouch) -> void:
	var touch_pos = event.position
	
	if event.pressed:
		# 触摸开始
		touch_points[event.index] = touch_pos
		
		# 检查是否在虚拟摇杆区域内
		if virtual_joystick_enabled and joystick_touch_id == -1:
			var distance_to_joystick = touch_pos.distance_to(joystick_center)
			if distance_to_joystick <= joystick_radius:
				joystick_touch_id = event.index
				is_joystick_active = true
				_update_joystick(touch_pos)
		
		# 检查双指缩放
		_check_pinch_gesture()
	else:
		# 触摸结束
		if event.index == joystick_touch_id:
			# 摇杆触摸结束
			joystick_touch_id = -1
			is_joystick_active = false
			movement_vector = Vector2.ZERO
			joystick_current = joystick_center
		
		touch_points.erase(event.index)
		
		# 检查是否结束双指缩放
		if touch_points.size() < 2:
			is_pinching = false

# 处理拖拽输入
func _handle_drag_input(event: InputEventScreenDrag) -> void:
	var touch_pos = event.position
	touch_points[event.index] = touch_pos
	
	# 更新虚拟摇杆
	if event.index == joystick_touch_id and is_joystick_active:
		_update_joystick(touch_pos)
	
	# 更新双指缩放
	if is_pinching and touch_points.size() >= 2:
		_update_pinch_zoom()

# 更新虚拟摇杆
func _update_joystick(touch_pos: Vector2) -> void:
	var offset = touch_pos - joystick_center
	var distance = offset.length()
	
	# 限制摇杆范围
	if distance > joystick_radius:
		offset = offset.normalized() * joystick_radius
		distance = joystick_radius
	
	joystick_current = joystick_center + offset
	
	# 计算移动向量
	if distance > joystick_deadzone:
		movement_vector = offset.normalized() * ((distance - joystick_deadzone) / (joystick_radius - joystick_deadzone))
	else:
		movement_vector = Vector2.ZERO

# 检查双指缩放手势
func _check_pinch_gesture() -> void:
	if touch_points.size() == 2:
		var touch_positions = touch_points.values()
		pinch_start_distance = touch_positions[0].distance_to(touch_positions[1])
		pinch_start_zoom = camera.zoom.x
		is_pinching = true

# 更新双指缩放
func _update_pinch_zoom() -> void:
	var touch_positions = touch_points.values()
	var current_distance = touch_positions[0].distance_to(touch_positions[1])
	
	if pinch_start_distance > 0:
		var scale_factor = current_distance / pinch_start_distance
		var new_zoom = pinch_start_zoom * scale_factor
		
		# 限制缩放范围
		new_zoom = clamp(new_zoom, min_zoom, max_zoom)
		
		# 检查缩放后是否会超出场景边界
		var viewport_size = get_viewport().get_visible_rect().size
		var camera_rect_size = viewport_size / new_zoom
		
		# 获取场景边界
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

# 获取虚拟摇杆的渲染信息（供UI显示使用）
func get_joystick_info() -> Dictionary:
	return {
		"center": joystick_center,
		"current": joystick_current,
		"radius": joystick_radius,
		"active": is_joystick_active,
		"enabled": virtual_joystick_enabled
	}
