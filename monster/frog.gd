extends Area2D

@onready var sprite = $AnimatedSprite2D
var debuff_manager: EnemyDebuffManager
var is_dead : bool = false

# 状态机
enum State { SEEKING_PLAYER, ATTACKING, FIRING, FLEEING }
var current_state : State = State.SEEKING_PLAYER

var base_speed : float = SettingMoster.frog("speed")
var speed : float # Actual speed after debuffs
var hpMax : float = SettingMoster.frog("hp")
var hp : float = SettingMoster.frog("hp")
var atk : float = SettingMoster.frog("atk")
var get_point : int = SettingMoster.frog("point")
var get_exp : int = SettingMoster.frog("exp")
var get_mechanism : int = SettingMoster.frog("mechanism")
var health_bar_shown: bool = false
var health_bar: Node2D
var progress_bar: ProgressBar

var target_position : Vector2 # 用于存储移动目标位置
var attack_cooldown_timer : Timer # 攻击间隔计时器 (替换旧的 attack_timer)
var action_timer : Timer # 用于攻击前摇和逃跑计时

const ATTACK_RANGE : float = 100.0
const ATTACK_PREPARE_TIME : float = 0.9
const FLEE_DURATION : float = 2.4
var last_sword_wave_damage_time: float = 0.0
const SWORD_WAVE_DAMAGE_INTERVAL: float = 0.25

signal debuff_applied(debuff_id: String)

func _ready() -> void:
	debuff_manager = EnemyDebuffManager.new(self)
	add_child(debuff_manager)
	debuff_applied.connect(debuff_manager.add_debuff)
	speed = base_speed # Initialize speed

	# 初始化移动相关
	# 初始化攻击和行动计时器
	attack_cooldown_timer = Timer.new()
	add_child(attack_cooldown_timer)
	attack_cooldown_timer.one_shot = true # 确保只触发一次，需要手动重启
	attack_cooldown_timer.wait_time = 0.1 # 初始一个较小的值，主要用于逻辑循环
	attack_cooldown_timer.timeout.connect(_on_attack_cooldown_timeout)
	# attack_cooldown_timer.start() # 不在这里立即启动，由状态机控制

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
			# print("Entering SEEKING_PLAYER")
			$AnimatedSprite2D.play("run")
			# 在这个状态下，持续寻找玩家
		State.ATTACKING:
			# print("Entering ATTACKING")
			$AnimatedSprite2D.play("attack") # 或者一个准备攻击的动画
			action_timer.wait_time = ATTACK_PREPARE_TIME
			action_timer.timeout.connect(_fire_fireball, CONNECT_ONE_SHOT)
			action_timer.start()
		State.FIRING: # 实际发射火球的瞬间
			# print("Entering FIRING")
			$AnimatedSprite2D.play("attack")
			_spawn_fireball()
			_enter_state(State.FLEEING) # 发射后立即进入逃跑状态
		State.FLEEING:
			# print("Entering FLEEING")
			$AnimatedSprite2D.play("run")
			_determine_flee_target()
			action_timer.wait_time = FLEE_DURATION
			action_timer.timeout.connect(_on_flee_timeout, CONNECT_ONE_SHOT)
			action_timer.start()

func _fire_fireball():
	if is_dead:
		return
	_enter_state(State.FIRING)

func _spawn_fireball():
	var fireball_scene = preload("res://Scenes/frog_attack.tscn")
	var fireball = fireball_scene.instantiate()
	get_parent().add_child(fireball)
	fireball.global_position = global_position # 火球从青蛙当前位置发射

	# 火球方向应朝向玩家
	if PC.player_instance:
		var player_position_at_shot = PC.player_instance.global_position
		var direction_to_player = (player_position_at_shot - global_position).normalized()
		fireball.set_direction(direction_to_player) # set_direction会自动处理旋转
	else:
		# 如果没有玩家实例，默认向右或向左发射
		var default_direction = Vector2.RIGHT if not sprite.flip_h else Vector2.LEFT
		fireball.set_direction(default_direction) # set_direction会自动处理旋转
	
	fireball.play_animation("fire") # 假设 frog_attack.gd 有 play_animation 方法

func _determine_flee_target():
	if not PC.player_instance:
		target_position = global_position + Vector2(100 if sprite.flip_h else -100, 0) # 默认逃跑方向
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

func _on_attack_cooldown_timeout(): # 这个函数现在更像是一个状态更新的tick
	pass # 主要逻辑移到 _physics_process


func _update_target_position_seeking():
	if PC.player_instance:
		target_position = PC.player_instance.global_position

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
		
		
func _move_pattern(delta: float):
	var direction_to_target = global_position.direction_to(target_position)
	var distance_to_target = global_position.distance_to(target_position)

	match current_state:
		State.SEEKING_PLAYER:
			if distance_to_target > 5: # 避免抖动
				speed = base_speed * debuff_manager.get_speed_multiplier()
				position += direction_to_target * speed * delta
		State.FLEEING:
			if distance_to_target > 5:
				speed = base_speed * debuff_manager.get_speed_multiplier()
				position += direction_to_target * speed * delta
				if target_position.x > global_position.x + 0.1: # 目标在右边 (0.1为小容差)
					sprite.flip_h = true  # 面向右
				elif target_position.x < global_position.x - 0.1: # 目标在左边 (0.1为小容差)
					sprite.flip_h = false # 面向左
			else: # 到达逃跑点
				action_timer.stop() # 提前停止计时器
				_on_flee_timeout()
		State.ATTACKING, State.FIRING:
			# 在攻击或发射状态下不移动
			pass

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# 处理敌人之间的碰撞
	var overlapping_bodies = get_overlapping_areas()
	for body in overlapping_bodies:
		if body.is_in_group("enemies") and !body.is_in_group("fly") and body != self:
			var direction_to_other = global_position.direction_to(body.global_position)
			# 将自己推离另一个敌人
			var push_strength = 2.0 # 可以根据需要调整推力大小
			# 只有在非攻击和发射状态下才进行推动，避免打断攻击动作
			if current_state != State.ATTACKING and current_state != State.FIRING:
				position -= direction_to_other * push_strength * delta * 100 # 乘以一个系数使效果更明显

	if hp <= 0:
		free_health_bar()
		if not is_dead: # Add this check
			$AnimatedSprite2D.stop()
			$AnimatedSprite2D.play("death")
			get_tree().current_scene.point += get_point
			Global.total_points += get_point
			PC.pc_exp += get_exp
			Global.emit_signal("monster_mechanism_gained", get_mechanism)
			var change = randf()
			if PC.selected_rewards.has("SplitSwordQi13") and change <= 0.05:
				Global.emit_signal("_fire_ring_bullets")
			$death.play()
			is_dead = true
		
			await get_tree().create_timer(0.36).timeout
			queue_free()
		
	if current_state != State.FLEEING and PC.player_instance: # 非逃跑状态下 (SEEKING_PLAYER, ATTACKING, FIRING)，朝向玩家
		var player_pos = PC.player_instance.global_position
		if global_position.x > player_pos.x: # 青蛙在玩家右侧
			sprite.flip_h = false # 面向左 (朝向玩家)
		else: # 青蛙在玩家左侧或同一X轴
			sprite.flip_h = true # 面向右 (朝向玩家)
	

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
	
func _on_body_entered(body: Node2D) -> void:
	if(body is CharacterBody2D and not is_dead and not PC.invincible) :
		Global.emit_signal("player_hit")
		var damage_before_debuff = atk * (1.0 - PC.damage_reduction_rate)
		var actual_damage = int(damage_before_debuff * debuff_manager.get_damage_multiplier())
		PC.pc_hp -= actual_damage
		if PC.pc_hp <= 0:
			body.game_over()

func take_damage(damage: int, is_crit: bool, is_summon: bool, damage_type: String) -> void:
	var final_damage = int(damage * debuff_manager.get_damage_multiplier())
	if damage_type == "sword_wave":
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_sword_wave_damage_time >= SWORD_WAVE_DAMAGE_INTERVAL:
			hp -= final_damage
			last_sword_wave_damage_time = current_time
	else:
		hp -= final_damage


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("bullet") and area.has_method("get_bullet_damage_and_crit_status"):
		var collision_result = BulletCalculator.handle_bullet_collision_full(area, self, false)
		
		# 根据穿透逻辑决定是否销毁子弹
		if collision_result["should_delete_bullet"]:
			area.queue_free()
			
		var base_bullet_damage = collision_result["final_damage"]
		var final_damage_val = int(base_bullet_damage * debuff_manager.get_damage_multiplier())
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

func apply_debuff_effect(debuff_id: String):
	emit_signal("debuff_applied", debuff_id)
