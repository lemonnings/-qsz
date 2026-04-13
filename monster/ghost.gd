extends "res://Script/monster/monster_base.gd"

@onready var sprite = $AnimatedSprite2D

# 随机移动方向向量（飞行单位可以向任意方向移动）
var move_vector: Vector2 = Vector2.LEFT

# 发射子弹计时器
var fire_timer: Timer
const FIRE_INTERVAL: float = 4.0

var base_speed: float = SettingMoster.ghost("speed")
var speed: float # Actual speed after debuffs
var hpMax: float = SettingMoster.ghost("hp")
var hp: float = SettingMoster.ghost("hp")
var atk: float = SettingMoster.ghost("atk")
var get_point: int = SettingMoster.ghost("point")
var get_exp: int = SettingMoster.ghost("exp")
var get_mechanism: int = SettingMoster.ghost("mechanism")
var last_sword_wave_damage_time: float = 0.0
const SWORD_WAVE_DAMAGE_INTERVAL: float = 0.25

# 精英怪相关

func _ready():
	player_hit_emit_self = true
	health_bar_tween_duration = 0.15
	setup_monster_base(is_elite)
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

func _physics_process(delta: float) -> void:
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
	# 碰到边界（StaticBody2D）时随机改变方向
	if body is StaticBody2D:
		_pick_random_direction()
		return
	handle_common_body_entered(body)


func take_damage(damage: int, is_crit: bool, is_summon: bool, damage_type: String) -> void:
	if damage_type == "sword_wave":
		var time_scale = 0.5 if PC.selected_rewards.has("SplitSwordQi22") else 1.0
		if not can_apply_interval_damage("last_sword_wave_damage_time", SWORD_WAVE_DAMAGE_INTERVAL, time_scale):
			return
		apply_common_take_damage(damage, is_crit, is_summon, damage_type, {"show_damage_popup": false})
		return
	apply_common_take_damage(damage, is_crit, is_summon, damage_type)
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


# 随机选择一个移动方向
func _pick_random_direction() -> void:
	var angle = randf() * TAU
	move_vector = Vector2(cos(angle), sin(angle))

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


