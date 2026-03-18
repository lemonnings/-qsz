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
@export var thunder_scene: PackedScene
@export var bloodwave_scene: PackedScene
@export var bloodboardsword_scene: PackedScene
@export var ice_flower_scene: PackedScene
@export var qigong_scene: PackedScene
@export var dragonwind_scene: PackedScene
@export var thunder_break_scene: PackedScene
@export var light_bullet_scene: PackedScene
@export var water_scene: PackedScene
@export var qiankun_scene: PackedScene
@export var xuanwu_scene: PackedScene
@export var xunfeng_scene: PackedScene
@export var genshan_scene: PackedScene
@export var duize_scene: PackedScene
@export var holy_light_scene: PackedScene

@export var fire_speed: Timer
@export var branch_fire_speed: Timer
@export var moyan_fire_speed: Timer
@export var riyan_fire_speed: Timer
@export var ringFire_fire_speed: Timer
@export var thunder_fire_speed: Timer
@export var bloodwave_fire_speed: Timer
@export var bloodboardsword_fire_speed: Timer
@export var ice_flower_fire_speed: Timer
@export var qigong_fire_speed: Timer
@export var dragonwind_fire_speed: Timer
@export var thunder_break_fire_speed: Timer
@export var light_bullet_fire_speed: Timer
@export var water_fire_speed: Timer
@export var qiankun_fire_speed: Timer
@export var xuanwu_fire_speed: Timer
@export var xunfeng_fire_speed: Timer
@export var genshan_fire_speed: Timer
@export var duize_fire_speed: Timer
@export var holy_light_fire_speed: Timer

@export var invincible_time: Timer

var active_summons: Array = [] # 当前活跃的召唤物列表


@onready var yiqiu_sprite: AnimatedSprite2D = $yiqiu
@onready var moning_sprite: AnimatedSprite2D = $moning
@onready var noam_sprite: AnimatedSprite2D = $noam
@onready var kansel_sprite: AnimatedSprite2D = $kansel
@onready var qujie_sprite: AnimatedSprite2D = $qujie
var sprite: AnimatedSprite2D
@export var sprite_direction_right: bool

var beastify_active: bool = false
var beastify_prev_atk: int = 0
var beastify_prev_atk_speed: float = 0.0
var beastify_prev_move_speed: float = 0.0
var beastify_prev_sprite: AnimatedSprite2D = null
var beastify_claw_ratio: float = 0.0
var beastify_effect_scene: PackedScene = preload("res://Scenes/player/beastification.tscn")
var beastify_hit_shape: Shape2D = null
var beastify_hit_offset: Vector2 = Vector2.ZERO
var beastify_forward_offset: float = 15.0
var beastify_lock_range: float = 75.0
var mizongbu_active: bool = false
var mizongbu_applied_speed_bonus: float = 0.0
var mizongbu_applied_dr_bonus: float = 0.0
var mizongbu_outgoing_factor: float = 1.0
var mizongbu_visual_tween: Tween = null


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
	var faze_manager = Faze.new()
	add_child(faze_manager)
	faze_manager.setup(self)
	
	hp = PC.pc_hp
	maxHP = PC.pc_max_hp
	Global.connect("player_hit", Callable(self, "_on_player_hit"))
	Global.connect("zoom_camera", Callable(self, "_zoom_camera"))
	Global.connect("reset_camera", Callable(self, "_reset_camera"))
	# 初始化技能攻速
	update_skill_attack_speeds()
	
	_set_active_hero(PC.player_name)
	_update_active_skill_timers(PC.player_name)
	_cache_beastify_hitbox()

	Global.connect("_fire_ring_bullets", Callable(self, "_fire_ring_bullets"))
	
	Global.connect("skill_cooldown_complete", Callable(self, "_on_fire"))
	Global.connect("skill_cooldown_complete_branch", Callable(self, "_on_fire_branch"))
	Global.connect("skill_cooldown_complete_moyan", Callable(self, "_on_fire_moyan"))
	Global.connect("skill_cooldown_complete_riyan", Callable(self, "_on_fire_riyan"))
	Global.connect("skill_cooldown_complete_ringFire", Callable(self, "_on_fire_ringFire"))
	Global.connect("skill_cooldown_complete_thunder", Callable(self, "_on_fire_thunder"))
	Global.connect("skill_cooldown_complete_bloodwave", Callable(self, "_on_fire_bloodwave"))
	Global.connect("skill_cooldown_complete_bloodboardsword", Callable(self, "_on_fire_bloodboardsword"))
	Global.connect("skill_cooldown_complete_ice", Callable(self, "_on_fire_ice"))
	Global.connect("skill_cooldown_complete_thunder_break", Callable(self, "_on_fire_thunder_break"))
	Global.connect("skill_cooldown_complete_light_bullet", Callable(self, "_on_fire_light_bullet"))
	Global.connect("skill_cooldown_complete_water", Callable(self, "_on_fire_water"))
	Global.connect("skill_cooldown_complete_qiankun", Callable(self, "_on_fire_qiankun"))
	Global.connect("skill_cooldown_complete_xuanwu", Callable(self, "_on_fire_xuanwu"))
	Global.connect("skill_cooldown_complete_xunfeng", Callable(self, "_on_fire_xunfeng"))
	Global.connect("skill_cooldown_complete_genshan", Callable(self, "_on_fire_genshan"))
	Global.connect("skill_cooldown_complete_duize", Callable(self, "_on_fire_duize"))
	Global.connect("skill_cooldown_complete_holylight", Callable(self, "_on_fire_holylight"))
	Global.connect("skill_cooldown_complete_qigong", Callable(self, "_on_fire_qigong"))
	Global.connect("skill_cooldown_complete_dragonwind", Callable(self, "_on_fire_dragonwind"))
	
	camera.zoom = Vector2(1.6, 1.6)
	
	# 设置音效使用SFX总线
	setup_audio_buses()
	
	# 初始化 last_move_time 为当前时间
	last_move_time = Time.get_unix_time_from_system()
	
	if PC.selected_rewards.has("Riyan") and PC.first_has_riyan_pc:
	# 实例化日炎攻击
		if riyan_scene:
			var riyan_instance = riyan_scene.instantiate()
			get_parent().add_child(riyan_instance)
			riyan_instance.global_position = global_position
			PC.first_has_riyan_pc = false
			
	if PC.selected_rewards.has("Qiankun"):
		init_qiankun()
	
	## 初始化虚拟摇杆
	#joystick_center = joystick_position
	#joystick_current = joystick_center

func change_hero(hero_key: String) -> void:
	_set_active_hero(hero_key)
	_update_active_skill_timers(hero_key)

func get_hero_sprite_frames(hero_key: String) -> SpriteFrames:
	var hero_sprite = _get_hero_sprite(hero_key)
	return hero_sprite.sprite_frames

func _set_active_hero(hero_key: String) -> void:
	var hero_sprite = _get_hero_sprite(hero_key)
	yiqiu_sprite.visible = false
	moning_sprite.visible = false
	noam_sprite.visible = false
	kansel_sprite.visible = false
	qujie_sprite.visible = false
	hero_sprite.visible = true
	animator = hero_sprite
	sprite = hero_sprite
	sprite_direction_right = not animator.flip_h

func _cache_beastify_hitbox() -> void:
	var temp = beastify_effect_scene.instantiate()
	var col: CollisionShape2D = temp.get_node("CollisionShape2D")
	beastify_hit_shape = col.shape.duplicate()
	beastify_hit_offset = col.position
	temp.queue_free()

func _get_hero_sprite(hero_key: String) -> AnimatedSprite2D:
	if hero_key == "yiqiu":
		return yiqiu_sprite
	if hero_key == "moning":
		return moning_sprite
	if hero_key == "noam":
		return noam_sprite
	if hero_key == "kansel":
		return kansel_sprite
	assert(false, "未知角色: " + hero_key)
	return yiqiu_sprite

func _update_active_skill_timers(hero_key: String) -> void:
	if hero_key == "moning":
		if fire_speed: fire_speed.stop()
		if light_bullet_fire_speed: light_bullet_fire_speed.stop()
		if ice_flower_fire_speed: ice_flower_fire_speed.stop()
		if qigong_fire_speed: qigong_fire_speed.start()
		return
	if hero_key == "yiqiu":
		if fire_speed: fire_speed.start()
		if light_bullet_fire_speed: light_bullet_fire_speed.stop()
		if ice_flower_fire_speed: ice_flower_fire_speed.stop()
		if qigong_fire_speed: qigong_fire_speed.stop()
		return
	if hero_key == "noam":
		if fire_speed: fire_speed.stop()
		if light_bullet_fire_speed: light_bullet_fire_speed.start()
		if ice_flower_fire_speed: ice_flower_fire_speed.stop()
		if qigong_fire_speed: qigong_fire_speed.stop()
		return
	if hero_key == "kansel":
		if fire_speed: fire_speed.stop()
		if light_bullet_fire_speed: light_bullet_fire_speed.stop()
		if ice_flower_fire_speed: ice_flower_fire_speed.start()
		if qigong_fire_speed: qigong_fire_speed.stop()
		return
	assert(false, "未知角色: " + hero_key)

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
	else:
		var bloodwave_speed_bonus = _get_bloodwave_move_speed_bonus()
		move_speed = 120.0 * (1 + (Global.cultivation_zhuifeng_level * 0.02) + PC.pc_speed + bloodwave_speed_bonus)
		
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
	var missing_hp_ratio = float(PC.pc_max_hp - PC.pc_hp) / float(PC.pc_max_hp)
	var bloodwave_heal_bonus = missing_hp_ratio * BloodWave.bloodwave_missing_hp_heal_bonus * 100.0
	PC.heal_multi = Global.heal_multi + bloodwave_heal_bonus
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

func enter_victory_state() -> void:
	PC.movement_disabled = true
	velocity = Vector2.ZERO
	animator.play("idle")
	$RunningSound.stop()

func stop_all_skill_cooldowns() -> void:
	fire_speed.stop()
	branch_fire_speed.stop()
	moyan_fire_speed.stop()
	riyan_fire_speed.stop()
	ringFire_fire_speed.stop()
	thunder_fire_speed.stop()
	bloodwave_fire_speed.stop()
	bloodboardsword_fire_speed.stop()
	ice_flower_fire_speed.stop()
	qigong_fire_speed.stop()
	thunder_break_fire_speed.stop()
	light_bullet_fire_speed.stop()
	water_fire_speed.stop()
	qiankun_fire_speed.stop()
	xuanwu_fire_speed.stop()
	xunfeng_fire_speed.stop()
	genshan_fire_speed.stop()
	duize_fire_speed.stop()
	holy_light_fire_speed.stop()
	dragonwind_fire_speed.stop()


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

func _on_fire_thunder(skill_id: int) -> void:
	if Global.in_menu or Global.in_town:
		return
	if PC.is_game_over:
		return
	_on_fire_detail_thunder()

func _on_fire_bloodwave(skill_id: int) -> void:
	if Global.in_menu or Global.in_town:
		return
	if PC.is_game_over:
		return
	if not PC.selected_rewards.has("Bloodwave"):
		return
	_on_fire_detail_bloodwave()

func _on_fire_bloodboardsword(skill_id: int) -> void:
	if Global.in_menu or Global.in_town:
		return
	if PC.is_game_over:
		return
	if not PC.selected_rewards.has("Bloodboardsword"):
		return
	_on_fire_detail_bloodboardsword()

func _on_fire_ice(skill_id: int = 9) -> void:
	if Global.in_menu or Global.in_town:
		return
	if PC.is_game_over:
		return
	if not PC.selected_rewards.has("Ice"):
		return
	_on_fire_detail_ice()

func _on_fire_thunder_break(skill_id: int = 10) -> void:
	if Global.in_menu or Global.in_town:
		return
	if PC.is_game_over:
		return
	_on_fire_detail_thunder_break()

func _on_fire_light_bullet(skill_id: int = 11) -> void:
	if Global.in_menu or Global.in_town:
		return
	if PC.is_game_over:
		return
	_on_fire_detail_light_bullet()

func _on_fire_detail_light_bullet() -> void:
	if not light_bullet_scene:
		return
		
	var data = _build_light_bullet_data()
	var spawn_position = global_position
	var base_direction = Vector2.RIGHT
	
	var nearest_enemy = find_nearest_enemy()
	if nearest_enemy:
		base_direction = (nearest_enemy.position - position).normalized()
	else:
		if not sprite_direction_right:
			base_direction = Vector2.LEFT
		else:
			base_direction = Vector2.RIGHT
			
	var shot_directions = []
	var offsets = []
	
	if data.shot_type == "triple":
		# 三发并排，中间差距5像素
		# 假设 base_direction 是正前方
		# 需要计算垂直于 base_direction 的向量
		var perpendicular = Vector2(-base_direction.y, base_direction.x)
		offsets = [
			perpendicular * -5.0,
			Vector2.ZERO,
			perpendicular * 5.0
		]
		shot_directions = [base_direction, base_direction, base_direction]
	elif data.shot_type == "double":
		# 双发并排，中间差距6像素
		var perpendicular = Vector2(-base_direction.y, base_direction.x)
		offsets = [
			perpendicular * -3.0,
			perpendicular * 3.0
		]
		shot_directions = [base_direction, base_direction]
	else:
		# 单发
		offsets = [Vector2.ZERO]
		shot_directions = [base_direction]
		
	# 处理 LightBullet4: 每发射15次，向周围一圈额外发射
	if data.extra_ring_shot:
		PC.light_bullet_shot_count += 1
		
		if PC.light_bullet_shot_count >= 15:
			PC.light_bullet_shot_count = 0
			_fire_light_bullet_ring(data)
			
	for i in range(offsets.size()):
		var instance = light_bullet_scene.instantiate()
		get_tree().current_scene.add_child(instance)
		
		var pos = spawn_position + offsets[i]
		var dir = shot_directions[i]
		
		var options = {
			"apply_light_accumulation": data.apply_light_accumulation,
			"accumulation_max_stacks_bonus": data.accumulation_max_stacks_bonus
		}
		
		instance.setup_light_bullet(pos, dir, data.damage, data.range, data.penetration_count, options)

func _fire_light_bullet_ring(data: Dictionary) -> void:
	# 向周围一圈发射
	# LightBullet4: 一轮
	# LightBullet44: 两轮，伤害提升30%
	var rounds = 1
	var damage_mult = 1.0
	
	if PC.selected_rewards.has("LightBullet44"):
		rounds = 2
		damage_mult = 1.3
		
	# 每圈子弹数量
	var bullet_count = 44
	var angle_step_deg = 9.0
	var interval = 0.025
	
	# 起始方向：正上方 (Vector2.UP = (0, -1))
	var start_angle = -PI / 2 # -90 degrees
	
	# 用于跟踪每一轮的发射进度
	var current_bullet_indices = []
	for r in range(rounds):
		current_bullet_indices.append(0)
		
	# 如果是第二轮，需要在第一轮发射到50%时开始
	var second_round_start_threshold = int(bullet_count * 0.5)
	
	# 用一个循环来驱动，每一帧检查各轮是否需要发射
	var max_steps = bullet_count
	if rounds > 1:
		max_steps += second_round_start_threshold
		
	for step in range(max_steps):
		# 检查对象是否有效
		if not is_instance_valid(self) or PC.is_game_over:
			return
			
		# 处理暂停
		while Global.in_menu or Global.in_town or get_tree().paused:
			if PC.is_game_over:
				return
			await get_tree().create_timer(0.1).timeout
			
		# 尝试发射每一轮的子弹
		for r in range(rounds):
			# 判断当前轮是否可以发射
			var can_fire = false
			
			if r == 0:
				# 第一轮：只要还没发完就可以发
				if current_bullet_indices[r] < bullet_count:
					can_fire = true
			elif r == 1:
				# 第二轮：需要第一轮发射超过阈值 (即 step >= threshold) 且自己还没发完
				if step >= second_round_start_threshold and current_bullet_indices[r] < bullet_count:
					can_fire = true
					
			if can_fire:
				var i = current_bullet_indices[r]
				current_bullet_indices[r] += 1
				
				var current_angle = start_angle + deg_to_rad(i * angle_step_deg)
				var dir = Vector2(cos(current_angle), sin(current_angle))
				
				var spawn_position = global_position
				
				var instance = light_bullet_scene.instantiate()
				get_tree().current_scene.add_child(instance)
				
				var options = {
					"apply_light_accumulation": data.apply_light_accumulation,
					"accumulation_max_stacks_bonus": data.accumulation_max_stacks_bonus
				}
				
				instance.setup_light_bullet(spawn_position, dir, data.damage * damage_mult, data.range, data.penetration_count, options)
		
		# 等待间隔
		await get_tree().create_timer(interval).timeout

func _build_light_bullet_data() -> Dictionary:
	var damage_multiplier = PC.main_skill_light_bullet_damage # Base 0.45
	var range_val = 300.0
	var penetration_count = 0
	
	var shot_type = "single" # single, double, triple
	var apply_light_accumulation = false
	var accumulation_max_stacks_bonus = 0
	var extra_ring_shot = false
	
	# LightBullet1: 析光
	if PC.selected_rewards.has("LightBullet1"):
		penetration_count += 2
		
	# LightBullet2: 蓄光
	if PC.selected_rewards.has("LightBullet2"):
		apply_light_accumulation = true
		
	# LightBullet3: 凝光
	if PC.selected_rewards.has("LightBullet3"):
		range_val *= 1.2
		# 范围提升50% -> 这里的范围如果是指子弹大小/宽度，light_bullet.gd 似乎没有宽度参数，只有 collision shape
		# 我们可以在 setup 中缩放 sprite
		
	# LightBullet4: 溢光
	if PC.selected_rewards.has("LightBullet4"):
		extra_ring_shot = true
		
	# LightBullet5: 双发
	if PC.selected_rewards.has("LightBullet5"):
		shot_type = "double"
		damage_multiplier *= 0.5 # 单发伤害降低50%
		# 范围降低30% -> 缩放降低
		
	# LightBullet11: 双发-蓄光 (三发)
	if PC.selected_rewards.has("LightBullet11"):
		shot_type = "triple"
		damage_multiplier *= 0.35 # 单发伤害降低30%
		accumulation_max_stacks_bonus += 10
		
	# LightBullet22: 溢光-析光
	if PC.selected_rewards.has("LightBullet22"):
		penetration_count += 1
		
	# LightBullet33: 蓄光-凝光
	if PC.selected_rewards.has("LightBullet33"):
		range_val *= 1.3
		accumulation_max_stacks_bonus += 10
		
	# LightBullet44: 析光-溢光
	if PC.selected_rewards.has("LightBullet44"):
		pass
		
	var damage = PC.pc_atk * damage_multiplier
	
	return {
		"damage": damage,
		"range": range_val,
		"penetration_count": penetration_count,
		"shot_type": shot_type,
		"apply_light_accumulation": apply_light_accumulation,
		"accumulation_max_stacks_bonus": accumulation_max_stacks_bonus,
		"extra_ring_shot": extra_ring_shot
	}

func _on_fire_water(skill_id: int = 12) -> void:
	if Global.in_menu or Global.in_town:
		return
	if PC.is_game_over:
		return
	_on_fire_detail_water()

func _on_fire_detail_water() -> void:
	if not water_scene:
		return
		
	var data = _build_water_data()
	var instance = water_scene.instantiate()
	get_tree().current_scene.add_child(instance)
	
	var options = {
		"enable_sector": data.enable_sector,
		"apply_slow": data.apply_slow,
		"apply_shield": data.apply_shield,
		"shield_hp_threshold": data.shield_hp_threshold,
		"extra_damage_on_slow": data.extra_damage_on_slow,
		"shield_bonus": data.shield_bonus,
		"heal_reduction": data.heal_reduction,
		"conditional_heal_bonus": data.conditional_heal_bonus
	}
	
	instance.setup_water(global_position, data.damage, data.range, data.heal_amount, options)

func _build_water_data() -> Dictionary:
	var damage_multiplier = PC.main_skill_water_damage # Base 0.45
	var range_val = 65.0
	var heal_amount = 0 # 基础治疗量
	
	# 计算基础治疗量：1.5% 最大体力，最低1点
	if PC.pc_max_hp > 0:
		heal_amount = max(1, int(float(PC.pc_max_hp) * 0.015))
	
	var enable_sector = false
	var apply_slow = false
	var apply_shield = false
	var shield_hp_threshold = 0.3
	var extra_damage_on_slow = false
	var shield_bonus = 1.0
	var heal_reduction = 1.0
	var conditional_heal_bonus = false
	
	# Water1: 水波
	if PC.selected_rewards.has("Water1"):
		enable_sector = true
		
	# Water2: 迟滞
	if PC.selected_rewards.has("Water2"):
		apply_slow = true
		
	# Water3: 流水
	if PC.selected_rewards.has("Water3"):
		apply_shield = true
		
	# Water4: 流幕
	if PC.selected_rewards.has("Water4"):
		# 恢复量提升至2%最大体力，最低2点
		if PC.pc_max_hp > 0:
			heal_amount = max(2, int(float(PC.pc_max_hp) * 0.02))
			
	# Water11: 水波-迟滞
	if PC.selected_rewards.has("Water11"):
		extra_damage_on_slow = true
		
	# Water22: 流水-流幕
	if PC.selected_rewards.has("Water22"):
		shield_hp_threshold = 0.7
		heal_reduction = 0.7 # 治疗量降低30%
		shield_bonus = 2.0 # 提供护盾量提升100%
		
	# Water33: 水波-流幕
	if PC.selected_rewards.has("Water33"):
		conditional_heal_bonus = true
		
	var damage = PC.pc_atk * damage_multiplier
	
	return {
		"damage": damage,
		"range": range_val,
		"heal_amount": heal_amount,
		"enable_sector": enable_sector,
		"apply_slow": apply_slow,
		"apply_shield": apply_shield,
		"shield_hp_threshold": shield_hp_threshold,
		"extra_damage_on_slow": extra_damage_on_slow,
		"shield_bonus": shield_bonus,
		"heal_reduction": heal_reduction,
		"conditional_heal_bonus": conditional_heal_bonus
	}

func init_qiankun() -> void:
	if Global.in_town:
		return
	if not qiankun_scene:
		return
		
	var script = load("res://Script/skill/qiankun.gd")
	if script:
		script.init_instances(qiankun_scene, get_tree(), global_position)

func _on_fire_qiankun(skill_id: int = 13) -> void:
	if Global.in_menu or Global.in_town:
		return
	if PC.is_game_over:
		return
	
	if not qiankun_scene:
		return
		
	var script = load("res://Script/skill/qiankun.gd")
	if script:
		script.fire_skill(qiankun_scene, global_position, get_tree())

func _on_fire_detail() -> void:
	if beastify_active:
		_beast_claw_attack()
		return
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

	$FireSound.play()

	var main_bullet = bullet_scene.instantiate()
	main_bullet.set_bullet_scale(Vector2(bullet_node_size, bullet_node_size))
	main_bullet.set_direction(base_direction)
	main_bullet.position = spawn_position
	main_bullet.penetration_count = PC.swordQi_penetration_count
	
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
			side_bullet.is_other_sword_wave = true
			if PC.selected_rewards.has("rebound"): side_bullet.is_rebound = false
			get_tree().current_scene.add_child(side_bullet)

	if PC.selected_rewards.has("SplitSwordQi11"):
		var back_bullet = bullet_scene.instantiate()
		back_bullet.set_bullet_scale(Vector2(bullet_node_size, bullet_node_size))
		var back_direction = base_direction.rotated(deg_to_rad(180.0)) 
		back_bullet.set_direction(back_direction)
		back_bullet.position = spawn_position
		back_bullet.penetration_count = PC.swordQi_penetration_count
		back_bullet.is_other_sword_wave = true 
		if PC.selected_rewards.has("rebound"): back_bullet.is_rebound = false
		get_tree().current_scene.add_child(back_bullet)
	
func fire_extra_attack(damage_multiplier: float) -> void:
	if PC.is_game_over:
		return
	var bullet_node_size = PC.bullet_size
	var base_direction = Vector2.RIGHT 
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
	
func start_beastify(duration: float, atk_bonus: float, atk_speed_bonus: float, move_bonus: float, claw_damage_ratio: float) -> void:
	if beastify_active:
		return
	beastify_active = true
	beastify_prev_atk = PC.pc_atk
	beastify_prev_atk_speed = PC.pc_atk_speed
	beastify_prev_move_speed = PC.pc_speed
	PC.pc_atk = int(round(float(PC.pc_atk) * (1.0 + atk_bonus)))
	PC.pc_atk_speed = PC.pc_atk_speed + atk_speed_bonus
	PC.pc_speed = PC.pc_speed + move_bonus
	beastify_claw_ratio = max(0.0, claw_damage_ratio)
	beastify_prev_sprite = sprite
	if qujie_sprite:
		qujie_sprite.flip_h = sprite_direction_right
		await _fade_swap_sprite(beastify_prev_sprite, qujie_sprite, 0.5)
		animator = qujie_sprite
		sprite = qujie_sprite
	await get_tree().create_timer(duration).timeout
	end_beastify()

func end_beastify() -> void:
	if not beastify_active:
		return
	beastify_active = false
	PC.pc_atk = beastify_prev_atk
	PC.pc_atk_speed = beastify_prev_atk_speed
	PC.pc_speed = beastify_prev_move_speed
	var scene = get_tree().current_scene
	if scene and scene is CanvasItem:
		var t = create_tween()
		t.tween_property(scene, "modulate", Color(1, 0, 0, 1), 0.5)
		t.tween_property(scene, "modulate", Color(1, 1, 1, 1), 0.1)
		await t.finished
	if beastify_prev_sprite:
		await _fade_swap_sprite(qujie_sprite, beastify_prev_sprite, 0.5)
		animator = beastify_prev_sprite
		sprite = beastify_prev_sprite
	elif qujie_sprite:
		qujie_sprite.visible = false
	beastify_claw_ratio = 0.0

func _fade_swap_sprite(from_sprite: AnimatedSprite2D, to_sprite: AnimatedSprite2D, duration: float) -> void:
	if to_sprite == null:
		if from_sprite:
			from_sprite.visible = false
		return
	var half = max(0.01, duration * 0.5)
	to_sprite.visible = true
	to_sprite.modulate.a = 0.0
	if from_sprite:
		from_sprite.visible = true
		from_sprite.modulate.a = 1.0
		var t1 = create_tween()
		t1.tween_property(from_sprite, "modulate:a", 0.0, half)
		await t1.finished
		from_sprite.visible = false
		from_sprite.modulate.a = 1.0
	var t2 = create_tween()
	t2.tween_property(to_sprite, "modulate:a", 1.0, half)
	await t2.finished
	to_sprite.modulate.a = 1.0

func start_mizongbu(duration: float, move_speed_bonus_ratio: float, damage_reduction_ratio: float, outgoing_damage_reduction_ratio: float) -> void:
	if mizongbu_active:
		return
	mizongbu_active = true
	mizongbu_applied_speed_bonus = move_speed_bonus_ratio
	PC.pc_speed += mizongbu_applied_speed_bonus
	var before_dr = PC.damage_reduction_rate
	var after_dr = min(before_dr + damage_reduction_ratio, 0.9)
	mizongbu_applied_dr_bonus = after_dr - before_dr
	PC.damage_reduction_rate = after_dr
	mizongbu_outgoing_factor = max(0.01, 1.0 - outgoing_damage_reduction_ratio)
	PC.pc_atk = max(1, int(round(float(PC.pc_atk) * mizongbu_outgoing_factor)))
	_start_mizongbu_visual()
	Global.emit_signal("buff_added", "mizongbu", duration, 1)
	var remaining = duration
	while remaining > 0.0 and mizongbu_active:
		await get_tree().create_timer(0.1).timeout
		remaining = max(0.0, remaining - 0.1)
		if remaining > 0.0:
			Global.emit_signal("buff_updated", "mizongbu", remaining, 1)
	if mizongbu_active:
		end_mizongbu()

func end_mizongbu() -> void:
	if not mizongbu_active:
		return
	mizongbu_active = false
	PC.pc_speed -= mizongbu_applied_speed_bonus
	PC.damage_reduction_rate = max(0.0, PC.damage_reduction_rate - mizongbu_applied_dr_bonus)
	if mizongbu_outgoing_factor > 0.0:
		PC.pc_atk = max(1, int(round(float(PC.pc_atk) / mizongbu_outgoing_factor)))
	mizongbu_applied_speed_bonus = 0.0
	mizongbu_applied_dr_bonus = 0.0
	mizongbu_outgoing_factor = 1.0
	_stop_mizongbu_visual()
	if BuffManager.has_buff("mizongbu"):
		BuffManager.remove_buff("mizongbu")

func _start_mizongbu_visual() -> void:
	_stop_mizongbu_visual()
	modulate = Color(1, 1, 1, 1)
	mizongbu_visual_tween = create_tween()
	mizongbu_visual_tween.set_loops()
	mizongbu_visual_tween.tween_property(self, "modulate", Color(1, 1, 1, 0.45), 0.15)
	mizongbu_visual_tween.tween_property(self, "modulate", Color(1, 1, 1, 0.9), 0.15)

func _stop_mizongbu_visual() -> void:
	if mizongbu_visual_tween:
		mizongbu_visual_tween.kill()
		mizongbu_visual_tween = null
	modulate = Color(1, 1, 1, 1)

func _beast_claw_attack() -> void:
	if PC.is_game_over or not beastify_active:
		return
	var angle = _get_beast_best_attack_angle()
	sprite_direction_right = cos(angle) >= 0.0
	var hits = _collect_beast_hits_at_angle(angle)
	var base = float(PC.pc_atk) * PC.main_skill_swordQi_damage * beastify_claw_ratio
	base *= Faze.get_bullet_damage_multiplier(PC.faze_bullet_level)
	if hits.size() < 3:
		base *= 1.5
	for e in hits:
		if is_instance_valid(e) and e.has_method("take_damage"):
			var is_crit = randf() < PC.crit_chance
			var final_damage = base
			if is_crit:
				final_damage *= Faze.get_sword_crit_damage_multiplier(PC.faze_sword_level)
			e.take_damage(int(round(final_damage)), is_crit, false, "claw")
			Faze.on_bullet_hit()
			Faze.on_sword_weapon_hit(e)
	var inst = beastify_effect_scene.instantiate()
	get_tree().current_scene.add_child(inst)
	inst.rotation = angle
	inst.global_position = global_position + Vector2.RIGHT.rotated(angle) * beastify_forward_offset

func _get_beast_best_attack_angle() -> float:
	var default_angle = 0.0
	if not sprite_direction_right:
		default_angle = PI
	var best_enemy: Node2D = null
	var best_dist_sq = beastify_lock_range * beastify_lock_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var to_enemy = enemy.global_position - global_position
		var dist_sq = to_enemy.length_squared()
		if dist_sq <= 0.0001:
			continue
		if dist_sq > best_dist_sq:
			continue
		best_dist_sq = dist_sq
		best_enemy = enemy
	if best_enemy == null:
		return default_angle
	return (best_enemy.global_position - global_position).angle()

func _collect_beast_hits_at_angle(angle: float) -> Array:
	if beastify_hit_shape == null:
		return []
	var offset = beastify_hit_offset.rotated(angle) + Vector2.RIGHT.rotated(angle) * beastify_forward_offset
	var world_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = beastify_hit_shape
	query.transform = Transform2D(angle, global_position + offset)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0x7fffffff
	var results = world_state.intersect_shape(query)
	var hits: Array = []
	for item in results:
		if not item.has("collider"):
			continue
		var e = item.collider
		if not is_instance_valid(e):
			continue
		if e.get_parent() and e.get_parent().is_in_group("enemies"):
			e = e.get_parent()
		if not e.is_in_group("enemies"):
			continue
		if not e.has_method("take_damage"):
			continue
		if hits.has(e):
			continue
		hits.append(e)
	return hits

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

func _on_fire_detail_thunder() -> void:
	var start_position = global_position
	var thunder_data = _build_thunder_data()
	var shot_targets = find_nearest_enemies_for_thunder(start_position, thunder_data.range, thunder_data.shot_count)
	var end_positions: Array[Vector2] = []
	var target_enemies: Array[Node2D] = []
	
	if shot_targets.is_empty():
		var fallback_dir = Vector2.RIGHT if sprite_direction_right else Vector2.LEFT
		for i in range(thunder_data.shot_count):
			end_positions.append(start_position + fallback_dir * thunder_data.range)
			target_enemies.append(null)
	else:
		var primary_target: Node2D = shot_targets[0]
		for i in range(thunder_data.shot_count):
			var target_enemy: Node2D = primary_target
			if i < shot_targets.size():
				target_enemy = shot_targets[i]
			target_enemies.append(target_enemy)
			end_positions.append(target_enemy.global_position)
	
	for i in range(thunder_data.shot_count):
		var thunder_instance = thunder_scene.instantiate()
		get_tree().current_scene.add_child(thunder_instance)
		thunder_instance.setup_thunder(start_position, end_positions[i], target_enemies[i], thunder_data.damage * thunder_data.shot_damage_multiplier, thunder_data.chain_left, thunder_data.damage_decay, thunder_data.chain_range, thunder_data.paralyze_duration, thunder_data.boss_extra_damage, self)

func _on_fire_detail_bloodwave() -> void:
	if not bloodwave_scene:
		return
		
	var script = load("res://Script/skill/blood_wave.gd")
	if script:
		script.fire_skill(bloodwave_scene, global_position, get_tree())

func _on_fire_detail_bloodboardsword() -> void:
	var bloodboardsword_instance = bloodboardsword_scene.instantiate()
	get_tree().current_scene.add_child(bloodboardsword_instance)

func _on_fire_detail_ice() -> void:
	if not ice_flower_scene:
		return
		
	var script = load("res://Script/skill/ice_flower.gd")
	if script:
		script.fire_skill(ice_flower_scene, global_position, get_tree())


func _on_fire_duize(skill_id: int = 14) -> void:
	if Global.in_menu or Global.in_town:
		return
	if PC.is_game_over:
		return
	_on_fire_detail_duize()

func _on_fire_detail_duize() -> void:
	if not duize_scene:
		return
	
	var script = load("res://Script/skill/duize.gd")
	if script:
		script.fire_skill(duize_scene, global_position, get_tree())

# ==========================================
# 圣光术逻辑
# ==========================================
func _on_fire_holylight(skill_id: int = 18) -> void:
	if Global.in_menu or Global.in_town:
		return
	if PC.is_game_over:
		return
	if not PC.selected_rewards.has("HolyLight"):
		return
	_on_fire_detail_holylight()

func _on_fire_detail_holylight() -> void:
	if not holy_light_scene:
		return
		
	var script = load("res://Script/skill/holy_light.gd")
	if script:
		script.fire_skill(holy_light_scene, global_position, get_tree())


func _on_fire_detail_thunder_break() -> void:
	if not thunder_break_scene:
		return
		
	var data = _build_thunder_break_data()
	var spawn_position = global_position
	var base_direction = Vector2.RIGHT
	
	var nearest_enemy = find_nearest_enemy()
	if nearest_enemy:
		base_direction = (nearest_enemy.position - position).normalized()
	else:
		if not sprite_direction_right:
			base_direction = Vector2.LEFT
		else:
			base_direction = Vector2.RIGHT
			
	var instance = thunder_break_scene.instantiate()
	get_tree().current_scene.add_child(instance)
	
	var options = {
		"infinite_range": data.infinite_range,
		"damage_drop_after_400": data.damage_drop_after_400,
		"crit_after_180": data.crit_after_180,
		"apply_electrified": data.apply_electrified,
		"damage_distance_bonus": data.damage_distance_bonus,
		"apply_vulnerable": data.apply_vulnerable
	}
	
	instance.setup_thunder_break(spawn_position, base_direction, data.damage, data.range, data.width, options)

func _build_thunder_break_data() -> Dictionary:
	var damage_multiplier = 0.5 # Base 50%
	var range_val = 200.0
	var width = 50.0
	
	var infinite_range = false
	var damage_drop_after_400 = false
	var crit_after_180 = false
	var apply_electrified = false
	var damage_distance_bonus = false
	var apply_vulnerable = false
	
	# ThunderBreak1: 引雷
	if PC.selected_rewards.has("ThunderBreak1"):
		damage_multiplier += 0.4
		width *= 1.3
		
	# ThunderBreak2: 穿雷
	if PC.selected_rewards.has("ThunderBreak2"):
		damage_multiplier += 0.3
		range_val += 120.0
		
	# ThunderBreak3: 感电
	if PC.selected_rewards.has("ThunderBreak3"):
		damage_multiplier += 0.2
		apply_electrified = true
		
	# ThunderBreak4: 霹雷
	if PC.selected_rewards.has("ThunderBreak4"):
		damage_multiplier += 0.2
		damage_distance_bonus = true
		
	# ThunderBreak11: 引雷x穿雷
	if PC.selected_rewards.has("ThunderBreak11"):
		damage_multiplier += 0.3
		infinite_range = true
		damage_drop_after_400 = true
		
	# ThunderBreak22: 穿雷x霹雷
	if PC.selected_rewards.has("ThunderBreak22"):
		damage_multiplier += 0.4
		crit_after_180 = true
		
	# ThunderBreak33: 引雷x震雷
	if PC.selected_rewards.has("ThunderBreak33"):
		damage_multiplier += 0.8
		apply_vulnerable = true
		
	var damage = PC.pc_atk * damage_multiplier
	
	return {
		"damage": damage,
		"range": range_val,
		"width": width,
		"infinite_range": infinite_range,
		"damage_drop_after_400": damage_drop_after_400,
		"crit_after_180": crit_after_180,
		"apply_electrified": apply_electrified,
		"damage_distance_bonus": damage_distance_bonus,
		"apply_vulnerable": apply_vulnerable
	}

func _build_thunder_data() -> Dictionary:
	var damage_ratio = 0.65
	var chain_left = 3
	var chain_range = 130.0
	var damage_decay = 0.45
	var range = PC.thunder_range
	var paralyze_duration = 0.0
	var boss_extra_damage = 0.0
	var shot_count = 1
	var shot_damage_multiplier = 1.0
	
	if PC.selected_rewards.has("RThunder"):
		damage_ratio += 0.2
	if PC.selected_rewards.has("SRThunder"):
		damage_ratio += 0.25
	if PC.selected_rewards.has("SSRThunder"):
		damage_ratio += 0.3
	if PC.selected_rewards.has("URThunder"):
		damage_ratio += 0.4
	
	if PC.selected_rewards.has("Thunder1"):
		damage_ratio += 0.4
		damage_decay = 0.4
		chain_left = 5
	
	if PC.selected_rewards.has("Thunder2"):
		damage_ratio += 0.4
		shot_count = 2
		shot_damage_multiplier = 0.6
	
	if PC.selected_rewards.has("Thunder3"):
		damage_ratio += 0.6
		chain_range = 195.0
	
	if PC.selected_rewards.has("Thunder4"):
		damage_ratio += 0.4
		paralyze_duration = 0.2
		boss_extra_damage = 0.3
	
	if PC.selected_rewards.has("Thunder11"):
		damage_ratio += 0.3
		damage_decay = 0.35
		chain_left = 7
	
	if PC.selected_rewards.has("Thunder22"):
		damage_ratio += 0.6
		paralyze_duration = 0.25
		boss_extra_damage = 0.5
	
	if PC.selected_rewards.has("Thunder33"):
		damage_ratio += 0.5
		shot_count = 3
		shot_damage_multiplier = 0.5
	
	var damage = PC.pc_atk * PC.main_skill_thunder_damage * damage_ratio
	
	return {
		"damage": damage,
		"chain_left": chain_left,
		"chain_range": chain_range,
		"damage_decay": damage_decay,
		"range": range,
		"paralyze_duration": paralyze_duration,
		"boss_extra_damage": boss_extra_damage,
		"shot_count": shot_count,
		"shot_damage_multiplier": shot_damage_multiplier
	}



func find_nearest_enemies_for_thunder(from_position: Vector2, max_range: float, count: int) -> Array[Node2D]:
	var candidates: Array[Dictionary] = []
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		var distance = from_position.distance_to(enemy.global_position)
		if distance > max_range:
			continue
		candidates.append({"enemy": enemy, "distance": distance})
	
	candidates.sort_custom(func(a, b): return a["distance"] < b["distance"])
	
	var results: Array[Node2D] = []
	for item in candidates:
		results.append(item["enemy"])
		if results.size() >= count:
			break
	return results


func reload_scene() -> void:
	if Global.main_menu_instance != null:
		Global.emit_signal("normal_bgm")
		# 设置菜单状态
		Global.in_menu = true
		SceneChange.change_scene("res://Scenes/main_menu.tscn", true)


func _on_player_hit(attacker: Node2D = null) -> void:
	if PC.is_game_over:
		return
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

func heal(amount: int) -> void:
	var new_hp = PC.pc_hp + amount
	if new_hp > PC.pc_max_hp:
		new_hp = PC.pc_max_hp
	PC.pc_hp = new_hp

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

func _get_bloodwave_move_speed_bonus() -> float:
	if BloodWave.bloodwave_bleed_move_speed_bonus <= 0.0:
		return 0.0
	var bleeding_count = _get_bleeding_enemy_count()
	return float(bleeding_count) * BloodWave.bloodwave_bleed_move_speed_bonus

func _get_bleeding_enemy_count() -> int:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var count = 0
	for enemy in enemies:
		if enemy.debuff_manager.has_debuff("bleed"):
			count += 1
	return count
	
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
	var life_interval_multiplier = Faze.get_life_attack_interval_multiplier(PC.faze_life_level)
	
	# 主攻击
	var sword_speed_multiplier = Faze.get_sword_attack_speed_multiplier(PC.faze_sword_level)
	update_timer_preserve_ratio(fire_speed, 0.66 / total_speed_multiplier / sword_speed_multiplier)
	
	# 分支攻击
	update_timer_preserve_ratio(branch_fire_speed, 1.5 / total_speed_multiplier)
	
	# 魔焰攻击
	update_timer_preserve_ratio(moyan_fire_speed, 4.0 / total_speed_multiplier)
	
	# 日焰攻击
	update_timer_preserve_ratio(riyan_fire_speed, 1.0 / total_speed_multiplier)
	
	# 环形火焰攻击
	update_timer_preserve_ratio(ringFire_fire_speed, 0.051 / total_speed_multiplier)
	
	# 雷光攻击
	update_timer_preserve_ratio(thunder_fire_speed, 1.2 / total_speed_multiplier)
	
	# 血气波攻击
	update_timer_preserve_ratio(bloodwave_fire_speed, 2.0 / total_speed_multiplier)
	
	update_timer_preserve_ratio(bloodboardsword_fire_speed, 2.0 / total_speed_multiplier / sword_speed_multiplier)
	
	# 冰刺术
	update_timer_preserve_ratio(ice_flower_fire_speed, 1 / total_speed_multiplier)
	
	# 天雷破 (基础1.6秒/次)
	update_timer_preserve_ratio(thunder_break_fire_speed, 1.6 / total_speed_multiplier)

	# 光弹 (基础0.4秒/次) todo
	var light_bullet_interval = 0.4
	# LightBullet4: 攻击间隔额外减少10%
	if PC.selected_rewards.has("LightBullet4"):
		light_bullet_interval *= 0.9
	# LightBullet22: 攻击间隔额外降低20%
	if PC.selected_rewards.has("LightBullet22"):
		light_bullet_interval *= 0.8
		
	light_bullet_interval = light_bullet_interval * life_interval_multiplier
	update_timer_preserve_ratio(light_bullet_fire_speed, light_bullet_interval / total_speed_multiplier)
	
	# 坎水诀 (基础2.2秒/次)
	update_timer_preserve_ratio(water_fire_speed, 2.2 * life_interval_multiplier / total_speed_multiplier)
	
	# 乾坤双剑 (基础3.5秒/次)
	update_timer_preserve_ratio(qiankun_fire_speed, 3.5 / total_speed_multiplier / sword_speed_multiplier)

	# 玄武盾 (基础4秒/次)
	update_timer_preserve_ratio(xuanwu_fire_speed, 4 / total_speed_multiplier)

	# 巽风诀 (基础0.6秒/次)
	update_timer_preserve_ratio(xunfeng_fire_speed, 0.6 / total_speed_multiplier)

	# 艮山诀 (基础3.5秒/次)
	update_timer_preserve_ratio(genshan_fire_speed, 3.5 / total_speed_multiplier)

	# 兑泽诀 (基础4.0秒/次)
	update_timer_preserve_ratio(duize_fire_speed, 4.0 / total_speed_multiplier)

	# 圣光术 (基础3.2秒/次)
	update_timer_preserve_ratio(holy_light_fire_speed, 3.2 * life_interval_multiplier / total_speed_multiplier)

	# 气功波
	update_timer_preserve_ratio(qigong_fire_speed, 1.2 / total_speed_multiplier)
	
	# 风龙杖
	update_timer_preserve_ratio(dragonwind_fire_speed, 2.5 / total_speed_multiplier)

func _on_fire_xunfeng(skill_id: int) -> void:
	if Global.in_menu or Global.in_town:
		return
	if PC.is_game_over:
		return
	if not PC.selected_rewards.has("Xunfeng"):
		return
	_on_fire_detail_xunfeng()

func _on_fire_detail_xunfeng() -> void:
	if not xunfeng_scene:
		return
		
	var XunfengScript = load("res://Script/skill/xunfeng.gd")
	if XunfengScript and XunfengScript.has_method("fire_skill"):
		XunfengScript.fire_skill(xunfeng_scene, global_position, get_tree())

func _on_fire_genshan(skill_id: int) -> void:
	if Global.in_menu or Global.in_town:
		return
	if PC.is_game_over:
		return
	if not PC.selected_rewards.has("Genshan"):
		return
	_on_fire_detail_genshan()

func _on_fire_detail_genshan() -> void:
	if not genshan_scene:
		return
		
	var GenshanScript = load("res://Script/skill/genshan.gd")
	if GenshanScript and GenshanScript.has_method("fire_skill"):
		GenshanScript.fire_skill(genshan_scene, global_position, get_tree())

# 发射环形子弹
func _fire_ring_bullets() -> void:
	if PC.is_game_over:
		return
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
	if PC.is_game_over:
		return
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

func _on_fire_xuanwu(skill_id: int) -> void:
	if Global.in_menu or Global.in_town:
		return
	if PC.is_game_over:
		return
	if not PC.selected_rewards.has("Xuanwu"):
		return
	_on_fire_detail_xuanwu()

func _on_fire_detail_xuanwu() -> void:
	if not xuanwu_scene:
		return
		
	var script = load("res://Script/skill/xuanwu.gd")
	if script:
		script.fire_skill(xuanwu_scene, global_position, get_tree())

func _on_fire_qigong(skill_id: int = 19) -> void:
	if Global.in_menu or Global.in_town:
		return
	if PC.is_game_over:
		return
	if not PC.selected_rewards.has("Qigong"):
		return
	_on_fire_detail_qigong()

func _on_fire_detail_qigong() -> void:
	if not qigong_scene:
		return
		
	Qigong.sync_reward_modifiers()
		
	var base_direction = Vector2.RIGHT
	var nearest_enemy = find_nearest_enemy()
	if nearest_enemy:
		base_direction = (nearest_enemy.position - position).normalized()
	else:
		if not sprite_direction_right:
			base_direction = Vector2.LEFT
		else:
			base_direction = Vector2.RIGHT
			
	var other_weapon_count = 0
	if PC.selected_rewards.has("Qigong5") or PC.selected_rewards.has("Qigong11"):
		other_weapon_count = PC.current_weapon_num - 1
	Qigong.qigong_chakra_count = other_weapon_count
			
	# 计算连发
	var double_hit = false
	var triple_hit = false
	if Qigong.qigong_double_hit_chance > 0 and randf() < Qigong.qigong_double_hit_chance:
		double_hit = true
		if Qigong.qigong_triple_hit_chance > 0 and randf() < Qigong.qigong_triple_hit_chance:
			triple_hit = true
			
	var damage_multipliers: Array[float] = []
	damage_multipliers.append(1.0)
	if double_hit:
		damage_multipliers.append(Qigong.qigong_double_hit_damage_multiplier)
		if triple_hit:
			damage_multipliers.append(Qigong.qigong_triple_hit_damage_multiplier)
		
	# 发射逻辑
	for i in range(damage_multipliers.size()):
		if not is_instance_valid(self) or PC.is_game_over:
			break
			
		_spawn_qigong(base_direction, Vector2.ZERO, damage_multipliers[i])
		
		if i < damage_multipliers.size() - 1:
			await get_tree().create_timer(0.1).timeout

func _on_fire_dragonwind(skill_id: int = 20) -> void:
	if Global.in_menu or Global.in_town:
		return
	if PC.is_game_over:
		return
	if not PC.selected_rewards.has("Dragonwind"):
		return
	_on_fire_detail_dragonwind()

func _on_fire_detail_dragonwind() -> void:
	if not dragonwind_scene:
		return
	var script = load("res://Script/skill/dragon_wind.gd")
	if script and script.has_method("fire_skill"):
		script.fire_skill(dragonwind_scene, global_position, get_tree())

func _spawn_qigong(direction: Vector2, offset: Vector2 = Vector2.ZERO, damage_multiplier: float = 1.0) -> void:
	var qigong_instance = qigong_scene.instantiate()
	get_tree().current_scene.add_child(qigong_instance)
	# setup(start_pos: Vector2, direction: Vector2, base_damage: int, damage_multiplier: float = 1.0)
	qigong_instance.setup(global_position + offset, direction, PC.pc_atk, damage_multiplier)
