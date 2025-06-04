extends Area2D

@onready var sprite = $AnimatedSprite2D
var is_dead : bool = false

# 状态机
enum State { SEEKING_PLAYER, ATTACKING, FIRING, FLEEING }
var current_state : State = State.SEEKING_PLAYER

var frog_speed : float = SettingMoster.frog("speed")
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

func _ready() -> void:
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
	fireball.global_position = global_position + Vector2(0, 0) # 调整火球生成位置，避免穿模
	# 火球方向应朝向玩家
	if PC.player_instance:
		var player_direction = (PC.player_instance.global_position - global_position).normalized()
		fireball.set_direction(player_direction) # 假设 frog_attack.gd 有 set_direction 方法
	else:
		fireball.set_direction(Vector2.LEFT if sprite.flip_h else Vector2.RIGHT)
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
	target_position = global_position + flee_direction * frog_speed * FLEE_DURATION * 1.2 # 目标设远一点确保能持续移动

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
				position += direction_to_target * frog_speed * delta
		State.FLEEING:
			if distance_to_target > 5:
				position += direction_to_target * frog_speed * delta
			else: # 到达逃跑点
				action_timer.stop() # 提前停止计时器
				_on_flee_timeout()
		State.ATTACKING, State.FIRING:
			# 在攻击或发射状态下不移动
			pass

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# 翻转逻辑
	if PC.player_instance and current_state != State.FLEEING: # 逃跑时不看玩家
		var player_pos = PC.player_instance.global_position
		# 如果青蛙在玩家右边，且目标位置在玩家左边（即青蛙要向左移动），则不翻转 (sprite.flip_h = false)
		# 如果青蛙在玩家左边，且目标位置在玩家右边（即青蛙要向右移动），则翻转 (sprite.flip_h = true)
		if global_position.x > player_pos.x: # 青蛙在玩家右侧
			sprite.flip_h = false # 面向左
		else: # 青蛙在玩家左侧或同一X轴
			sprite.flip_h = true # 面向右
			
	if PC.player_instance and current_state == State.FLEEING:
		var player_pos = PC.player_instance.global_position
		# 如果青蛙在玩家右边，且目标位置在玩家左边（即青蛙要向左移动），则不翻转 (sprite.flip_h = false)
		# 如果青蛙在玩家左边，且目标位置在玩家右边（即青蛙要向右移动），则翻转 (sprite.flip_h = true)
		if global_position.x > player_pos.x: # 青蛙在玩家右侧
			sprite.flip_h = true # 面向左
		else: # 青蛙在玩家左侧或同一X轴
			sprite.flip_h = false # 面向右

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
		
		
# 检查怪物是否在可伤害范围内（超出视野20px就不判定了）
func _is_monster_in_damage_range() -> bool:
	# 获取摄像头
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return true  # 如果没有摄像头，默认可以伤害
	
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
	var screen_pixel_margin = 20.0 
	if camera_zoom.x == 0.0 or camera_zoom.y == 0.0:
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


func _on_body_entered(body: Node2D) -> void:
	if(body is CharacterBody2D and not is_dead and not PC.invincible) :
		Global.emit_signal("player_hit")
		var actual_damage = int(atk * (1.0 - PC.damage_reduction_rate))
		PC.pc_hp -= actual_damage
		if PC.pc_hp <= 0:
			body.game_over()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("bullet") and area.has_method("get_bullet_damage_and_crit_status"):
		# 检查怪物是否在视野范围内（超出视野20px才能被伤害）
		if not _is_monster_in_damage_range():
			return
		
		# 使用BulletCalculator处理完整的子弹碰撞逻辑
		var collision_result = BulletCalculator.handle_bullet_collision_full(area, self, false)
		var final_damage_val = collision_result["final_damage"]
		var is_crit = collision_result["is_crit"]
		
		hp -= int(final_damage_val)
		
		# 处理子弹反弹
		if collision_result["should_rebound"]:
			area.call_deferred("create_rebound")
			
		if hp <= 0:
			free_health_bar()
			$AnimatedSprite2D.play("death")
			if not is_dead:
				get_tree().current_scene.point += get_point
				Global.total_points += get_point
				PC.pc_exp += get_exp
				Global.emit_signal("monster_mechanism_gained", get_mechanism)
				$death.play()
				area.queue_free()
			is_dead = true
			
			await get_tree().create_timer(0.35).timeout
			queue_free()
		else:
			Global.play_hit_anime(position, is_crit)
			area.queue_free()
