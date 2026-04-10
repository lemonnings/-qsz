extends Area2D

@onready var sprite = $AnimatedSprite2D
var debuff_manager: EnemyDebuffManager
var is_dead: bool = false

var move_vector: Vector2 = Vector2.LEFT

# 发射子弹计时器
var fire_timer: Timer
const FIRE_INTERVAL: float = 4.0

var base_speed: float = SettingMoster.bat("speed")
var speed: float # Actual speed after debuffs
var hpMax: float = SettingMoster.bat("hp")
var hp: float = SettingMoster.bat("hp")
var atk: float = SettingMoster.bat("atk")
var get_point: int = SettingMoster.bat("point")
var get_exp: int = SettingMoster.bat("exp")
var get_mechanism: int = SettingMoster.bat("mechanism")
var health_bar_shown: bool = false

signal debuff_applied(debuff_id: String)

var health_bar: Node2D
var progress_bar: ProgressBar

var last_sword_wave_damage_time: float = 0.0
const SWORD_WAVE_DAMAGE_INTERVAL: float = 0.25

# 坐标日志计时器
var _log_timer: float = 0.0

# 精英怪相关
var is_elite: bool = false
var drop_rate_multiplier: float = 1.0

# 边界检测标志，防止重复触发转向
var is_out_of_bounds: bool = false

func _ready():
	debuff_manager = EnemyDebuffManager.new(self )
	add_child(debuff_manager)
	debuff_applied.connect(debuff_manager.add_debuff)
	if is_elite:
		add_to_group("elite")
	speed = base_speed # Initialize speed
	
	# 随机初始移动方向
	_pick_random_direction()
	
	# 初始化发射子弹定时器
	fire_timer = Timer.new()
	add_child(fire_timer)
	fire_timer.wait_time = FIRE_INTERVAL
	fire_timer.timeout.connect(_shoot_bullet)
	fire_timer.start()
	
	# 创建地面阴影（飞行单位阴影在更下方，表示地面投影）
	CharacterEffects.create_shadow(self , 16.0, 5.0, 13.0)

func show_health_bar():
	if not health_bar_shown:
		health_bar = preload("res://Scenes/global/hp_bar.tscn").instantiate()
		add_child(health_bar)
		health_bar.z_index = 100
		progress_bar = health_bar.get_node("HPBar")
		progress_bar.position = global_position + Vector2(-15, -10)
		health_bar_shown = true
		progress_bar.top_level = true
	elif progress_bar and progress_bar.is_inside_tree():
		progress_bar.position = global_position + Vector2(-15, -10)
		var target_value_hp = (float(hp / hpMax)) * 100
		if progress_bar.value != target_value_hp:
			var tween = create_tween()
			tween.tween_property(progress_bar, "value", target_value_hp, 0.15)
		
func free_health_bar():
	if health_bar != null and health_bar.is_inside_tree():
		health_bar.queue_free()

func _physics_process(delta: float) -> void:
	# 每秒打印一次坐标日志
	_log_timer += delta
	if _log_timer >= 1.0:
		_log_timer = 0.0
		print("[bat] position: ", position, " | global_position: ", global_position)
	
	if hp < hpMax and hp > 0:
		show_health_bar()
	
	if debuff_manager.is_action_disabled():
		fire_timer.paused = true
		return
	if fire_timer.paused:
		fire_timer.paused = false

	# 处理推挤效果（防止怪物重叠）
	if not is_dead:
		CharacterEffects.apply_separation(self , 10.0, 12.0)
	
	# 处理敌人之间的碰撞 - 直接防止重叠
	if monitoring:
		var overlapping_bodies = get_overlapping_areas()
		
		for body in overlapping_bodies:
			if body.is_in_group("enemies") and !body.is_in_group("fly") and body != self:
				var distance = global_position.distance_to(body.global_position)
				var min_distance = 12.0 # 最小允许距离
				
				# 如果距离太近，直接调整位置
				if distance < min_distance and distance > 0.1:
					var direction_away = (global_position - body.global_position).normalized()
					var overlap = min_distance - distance
					# 两个物体各自移动一半的重叠距离
					position += direction_away * (overlap * 0.5)

		
	if not is_dead:
		speed = base_speed * debuff_manager.get_speed_multiplier()
		position += move_vector * speed * delta
		# 根据水平移动方向翻转精灵
		if move_vector.x > 0:
			sprite.flip_h = true
		elif move_vector.x < 0:
			sprite.flip_h = false
		
		# 超出边界范围时，朝向玩家方向转向（只在刚越界时触发一次）
		# 边界：y > 25, y < -560, x > 305, x < -310，向内缩10像素作为触发边界
		# 使用 global_position 与世界坐标边界比较
		var currently_out_of_bounds = (global_position.y > 550 or global_position.y < 50 or global_position.x > 295 or global_position.x < -300)
		if currently_out_of_bounds and not is_out_of_bounds:
			_pick_direction_to_safe_zone()
			is_out_of_bounds = true
		elif not currently_out_of_bounds:
			is_out_of_bounds = false
		
	if hp <= 0:
		free_health_bar()
		if not is_dead: # Add this check
			$AnimatedSprite2D.stop()
			$AnimatedSprite2D.play("death")
			var point_gain = int(get_point * Faze.get_point_multiplier())
			get_tree().current_scene.point += point_gain
			Global.total_points += point_gain
			var exp_gain = int(get_exp * Faze.get_exp_multiplier())
			Global.emit_signal("drop_exp_orb", exp_gain, global_position, is_elite)
			Global.emit_signal("monster_mechanism_gained", get_mechanism)
			var change = randf()
			if PC.selected_rewards.has("SplitSwordQi13") and change <= 0.05:
				# Release a round of sword Qi in (90°)(270°) and other all directions
				release_round_sword_qi()
			$death.play()
			Global.emit_signal("monster_killed")
			is_dead = true
			remove_from_group("enemies")
			# 死亡时去除滤镜和描边
			$AnimatedSprite2D.modulate = Color(1, 1, 1, 1)
			$AnimatedSprite2D.material = null
			var collision_shape = get_node("CollisionShape2D")
			collision_shape.disabled = true
			collision_layer = 0
			collision_mask = 0
			monitoring = false
			monitorable = false
			# 隐藏阴影
			var shadow = get_node_or_null("Shadow")
			if shadow:
				shadow.visible = false
			if SettingMoster.ghost("itemdrop") != null:
				for key in SettingMoster.ghost("itemdrop"):
					var drop_chance = SettingMoster.ghost("itemdrop")[key] * drop_rate_multiplier
					if randf() <= drop_chance:
						Global.emit_signal("drop_out_item", key, 1, global_position)

			await get_tree().create_timer(0.35).timeout
			queue_free()


func _on_body_entered(body: Node2D) -> void:
	if debuff_manager.is_action_disabled():
		return
	if (body is CharacterBody2D and not is_dead and not PC.invincible):
		Global.emit_signal("player_hit", self )
		var damage_before_debuff = atk * (1.0 - PC.damage_reduction_rate)
		var actual_damage = int(damage_before_debuff * debuff_manager.get_take_damage_multiplier())
		PC.apply_damage(actual_damage)
		if PC.pc_hp <= 0:
			body.game_over()


func take_damage(damage: int, is_crit: bool, is_summon: bool, damage_type: String) -> void:
	var damage_offset = Vector2(35, 20)
	var final_damage = int(damage * debuff_manager.get_damage_multiplier())
	if damage_type == "sword_wave":
		var current_time = Time.get_ticks_msec() / 1000.0
		if PC.selected_rewards.has("SplitSwordQi22"):
			current_time = current_time / 2
		if current_time - last_sword_wave_damage_time >= SWORD_WAVE_DAMAGE_INTERVAL:
			hp -= final_damage
			last_sword_wave_damage_time = current_time
	else:
		hp -= final_damage
		# DoT伤害由EnemyDebuffManager负责显示跳字，避免重复显示白字
		if damage_type in ["bleed", "burn", "electrified", "corrosion", "corrosion2", "posion"]:
			return
		var damage_type_int = 1
		if is_summon:
			damage_type_int = 4
		elif is_crit:
			damage_type_int = 2
		Global.emit_signal("monster_damage", damage_type_int, final_damage, global_position - damage_offset)


func _on_area_entered(area: Area2D) -> void:
	if is_dead:
		return

	if area.is_in_group("bullet") and area.has_method("get_bullet_damage_and_crit_status"):
		# 使用BulletCalculator处理完整的子弹碰撞逻辑
		var collision_result = BulletCalculator.handle_bullet_collision_full(area, self , false)
		
		# 根据穿透逻辑决定是否销毁子弹
		if collision_result["should_delete_bullet"]:
			area.queue_free()
			
		var base_bullet_damage = collision_result["final_damage"]
		var final_damage_val = int(base_bullet_damage * debuff_manager.get_damage_multiplier())
		var is_crit = collision_result["is_crit"]
		
		# 处理子弹反弹
		if collision_result["should_rebound"]:
			area.call_deferred("create_rebound")
			
		hp -= int(final_damage_val)
		if hp <= 0:
			# 如果已经死亡，则不重复播放死亡动画，也不播放受击动画
			if not is_dead:
				$AnimatedSprite2D.play("death")
		else:
			Global.play_hit_anime(position, is_crit)

func apply_debuff_effect(debuff_id: String):
	emit_signal("debuff_applied", debuff_id)

# 随机选择一个移动方向
func _pick_random_direction() -> void:
	var angle = randf() * TAU
	move_vector = Vector2(cos(angle), sin(angle))

# 朝向安全区域中心选择方向（避免再次越界）
func _pick_direction_to_safe_zone() -> void:
	# 计算朝向玩家的方向
	var direction_to_player: Vector2
	if PC.player_instance:
		direction_to_player = (PC.player_instance.global_position - global_position).normalized()
	else:
		# 如果没有玩家实例，使用默认方向
		direction_to_player = Vector2.LEFT
	# 添加随机偏移（±30度），增加变化性
	var random_offset = deg_to_rad(randf_range(-30, 30))
	move_vector = direction_to_player.rotated(random_offset)

# 每隔 FIRE_INTERVAL 秒向玩家发射一次子弹
func _shoot_bullet() -> void:
	if is_dead:
		return
	var fireball_scene = preload("res://Scenes/moster/frog_attack.tscn")
	var fireball = fireball_scene.instantiate()
	get_parent().add_child(fireball)
	fireball.global_position = global_position
	var shoot_direction: Vector2
	if PC.player_instance:
		shoot_direction = (PC.player_instance.global_position - global_position).normalized()
	else:
		shoot_direction = move_vector
	fireball.set_direction(shoot_direction)
	fireball.play_animation("fire")

func apply_knockback(direction: Vector2, force: float):
	var tween = create_tween()
	tween.tween_property(self , "position", global_position + direction * force, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# Release a round of sword Qi in (90°)(270°) and other all directions
func release_round_sword_qi():
	var bullet_scene = preload("res://Scenes/bullet.tscn")
	var spawn_position = global_position
	var bullet_size = PC.bullet_size
	
	# Create sword Qi at 90°, 270° and other all directions
	var angles = [90.0, 270.0] # Initial angles as per requirement
	# Add other directions to make it a complete round
	for i in range(8): # Add 6 more directions to make 8 total directions
		var angle = (360.0 / 8) * i
		if not (angle == 90.0 or angle == 270.0): # Avoid duplicates
			angles.append(angle)
	
	for angle_deg in angles:
		var sword_qi = bullet_scene.instantiate()
		sword_qi.set_bullet_scale(Vector2(bullet_size, bullet_size))
		var direction = Vector2.RIGHT.rotated(deg_to_rad(angle_deg))
		sword_qi.set_direction(direction)
		sword_qi.position = spawn_position
		sword_qi.penetration_count = PC.swordQi_penetration_count
		sword_qi.is_other_sword_wave = true # Mark as additional sword wave for damage calculation
		get_tree().current_scene.add_child(sword_qi)
