extends "res://Script/monster/monster_base.gd"

@onready var sprite = $AnimatedSprite2D

# 状态机
enum State {SEEKING_PLAYER, ATTACKING, FIRING, FLEEING}
var current_state: State = State.SEEKING_PLAYER

var base_speed: float = SettingMoster.frog_new("speed")
var speed: float # Actual speed after debuffs
var hpMax: float = SettingMoster.frog_new("hp")
var hp: float = SettingMoster.frog_new("hp")
var atk: float = SettingMoster.frog_new("atk")
var get_point: int = SettingMoster.frog_new("point")
var get_exp: int = SettingMoster.frog_new("exp")
var get_mechanism: int = SettingMoster.frog_new("mechanism")
var target_position: Vector2 # 用于存储移动目标位置
var attack_cooldown_timer: Timer # 攻击间隔计时器 (替换旧的 attack_timer)
var action_timer: Timer # 用于攻击前摇和逃跑计时

const ATTACK_RANGE: float = 100.0
const ATTACK_PREPARE_TIME: float = 0.65
const FLEE_DURATION: float = 2.4
var last_sword_wave_damage_time: float = 0.0
const SWORD_WAVE_DAMAGE_INTERVAL: float = 0.25

# 精英怪相关

# 攻击方向锁定
var locked_attack_direction: Vector2 = Vector2.ZERO # 锁定的攻击方向
var is_direction_locked: bool = false # 是否锁定方向（用于禁止翻转）


func _ready() -> void:
	player_hit_emit_self = true
	health_bar_tween_duration = 0.15
	setup_monster_base(is_elite)
	speed = base_speed # Initialize speed
	
	# 创建脚底阴影
	CharacterEffects.create_shadow(self , 20.0, 7.0, 13.0)

	# 初始化移动相关
	action_timer = Timer.new()
	add_child(action_timer)
	action_timer.one_shot = true
	# action_timer.timeout.connect() # 连接将在需要时动态设置

	# 初始状态
	_enter_state(State.SEEKING_PLAYER)

func _enter_state(new_state: State):
	current_state = new_state
	match current_state:
		State.SEEKING_PLAYER:
			# 在这个状态下，持续寻找玩家
			# print("Entering SEEKING_PLAYER")
			is_direction_locked = false # 解锁方向
			$AnimatedSprite2D.play("run")
		State.ATTACKING:
			# print("Entering ATTACKING")
			# 在准备攻击时就锁定攻击方向
			_lock_attack_direction()
			$AnimatedSprite2D.play("attack") # 或者一个准备攻击的动画
			action_timer.wait_time = ATTACK_PREPARE_TIME
			action_timer.timeout.connect(_fire_fireball, CONNECT_ONE_SHOT)
			action_timer.start()
		State.FIRING: # 实际发射火球的瞬间
			# print("Entering FIRING")
			$AnimatedSprite2D.play("attack")
			_spawn_fireball()
			_enter_state(State.FLEEING) # 发射后立即进入远离状态
		State.FLEEING:
			is_direction_locked = false # 解锁方向
			$AnimatedSprite2D.play("run")
			_determine_flee_target()
			action_timer.wait_time = FLEE_DURATION
			action_timer.timeout.connect(_on_flee_timeout, CONNECT_ONE_SHOT)
			action_timer.start()

# 锁定攻击方向
func _lock_attack_direction() -> void:
	is_direction_locked = true
	if PC.player_instance:
		locked_attack_direction = (PC.player_instance.global_position - global_position).normalized()
	else:
		# 没有玩家实例时，使用当前面向
		locked_attack_direction = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT

func _fire_fireball():
	if is_dead:
		return
	_enter_state(State.FIRING)

func _spawn_fireball():
	var fireball_scene = preload("res://Scenes/moster/frog_attack.tscn")
	var fireball = fireball_scene.instantiate()
	get_parent().add_child(fireball)
	fireball.global_position = global_position # 火球从青蛙当前位置发射

	# 使用锁定的攻击方向
	if locked_attack_direction != Vector2.ZERO:
		fireball.set_direction(locked_attack_direction)
	else:
		# 如果没有锁定方向，使用当前面向
		var default_direction = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
		fireball.set_direction(default_direction)
	
	fireball.play_animation("fire") # 假设 frog_attack.gd 有 play_animation 方法

func _determine_flee_target():
	if not PC.player_instance:
		target_position = global_position + Vector2(-100 if sprite.flip_h else 100, 0) # 默认逃跑方向
		return
	var player_pos = PC.player_instance.global_position
	# 只允许向正左或正右方向逃跑
	var flee_direction: Vector2
	if global_position.x > player_pos.x:
		# 青蛙在玩家右侧，向右逃跑
		flee_direction = Vector2.RIGHT
	else:
		# 青蛙在玩家左侧或同一位置，向左逃跑
		flee_direction = Vector2.LEFT
	target_position = global_position + flee_direction * speed * FLEE_DURATION * 1.2 # 目标设远一点确保能持续移动

func _on_flee_timeout():
	if is_dead:
		return
	_enter_state(State.SEEKING_PLAYER)

func _update_target_position_seeking():
	if PC.player_instance:
		target_position = PC.player_instance.global_position

func _move_pattern(delta: float):
	var direction_to_target = global_position.direction_to(target_position)
	var distance_to_target = global_position.distance_to(target_position)

	match current_state:
		State.SEEKING_PLAYER:
			if distance_to_target > 5: # 避免抖动
				speed = get_effective_move_speed(base_speed)
				position += direction_to_target * speed * delta
		State.FLEEING:
			if distance_to_target > 5:
				speed = get_effective_move_speed(base_speed)
				position += direction_to_target * speed * delta
				if target_position.x > global_position.x + 0.1: # 目标在右边 (0.1为小容差)
					sprite.flip_h = false # 面向右
				elif target_position.x < global_position.x - 0.1: # 目标在左边 (0.1为小容差)
					sprite.flip_h = true # 面向左
			else: # 到达逃跑点
				action_timer.stop() # 提前停止计时器
				_on_flee_timeout()
		State.ATTACKING, State.FIRING:
			# 在攻击或发射状态下不移动
			pass

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	if debuff_manager.is_action_disabled():
		action_timer.paused = true
		return
	if action_timer.paused:
		action_timer.paused = false

	# 处理推挤效果（攻击和发射状态不推挤，避免打断攻击动作）
	if current_state != State.ATTACKING and current_state != State.FIRING:
		CharacterEffects.apply_separation(self , 13.0, 13.0)

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
				Global.emit_signal("_fire_ring_bullets")
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
			if SettingMoster.frog_new("itemdrop") != null:
				for key in SettingMoster.frog_new("itemdrop"):
					var drop_chance = SettingMoster.frog_new("itemdrop")[key] * drop_rate_multiplier
					if randf() <= drop_chance:
						Global.emit_signal("drop_out_item", key, 1, global_position)

			await get_tree().create_timer(0.36).timeout
			queue_free()

	if not is_direction_locked and current_state != State.FLEEING and PC.player_instance: # 未锁定方向且非逃跑状态下，朝向玩家
		var player_pos = PC.player_instance.global_position
		if global_position.x > player_pos.x: # 青蛙在玩家右侧
			sprite.flip_h = true # 面向左 (朝向玩家)
		else: # 青蛙在玩家左侧或同一X轴
			sprite.flip_h = false # 面向右 (朝向玩家)
	

	match current_state:
		State.SEEKING_PLAYER:
			_update_target_position_seeking()
			_move_pattern(delta)
			if PC.player_instance and global_position.distance_to(PC.player_instance.global_position) <= ATTACK_RANGE:
				_enter_state(State.ATTACKING)
		State.ATTACKING:
			# 逻辑在 _enter_state 和 action_timer timeout 中处理
			pass
		State.FIRING:
			# 逻辑在 _enter_state 中处理
			pass
		State.FLEEING:
			_move_pattern(delta)

	if hp < hpMax and hp > 0:
		show_health_bar()
	

func take_damage(damage: int, is_crit: bool, is_summon: bool, damage_type: String) -> void:
	if damage_type == "sword_wave":
		if not can_apply_interval_damage("last_sword_wave_damage_time", SWORD_WAVE_DAMAGE_INTERVAL):
			return
		apply_common_take_damage(damage, is_crit, is_summon, damage_type, {"show_damage_popup": false})
		return
	apply_common_take_damage(damage, is_crit, is_summon, damage_type)
func _on_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	if area.is_in_group("bullet") and area.has_method("get_bullet_damage_and_crit_status"):
		var collision_result = BulletCalculator.handle_bullet_collision_full(area, self , false)
		# 根据穿透逻辑决定是否销毁子弹
		if collision_result["should_delete_bullet"]:
			area.queue_free()
			
		var base_bullet_damage = collision_result["final_damage"]
		var final_damage_val = get_common_bullet_damage_value(base_bullet_damage)
		var is_crit = collision_result["is_crit"]
		
		hp -= int(final_damage_val)
		
		# 处理子弹反弹
		if collision_result["should_rebound"]:
			area.call_deferred("create_rebound")
			
		
		if hp <= 0:
			# 如果已经死亡，则不重复播放死亡动画，也不播放受击动画
			if not is_dead:
				$AnimatedSprite2D.play("death")
		else:
			Global.play_hit_anime(position, is_crit)



