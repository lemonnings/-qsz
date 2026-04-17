extends "res://Script/monster/monster_base.gd"

@onready var sprite = $AnimatedSprite2D
# 0为从左到右，1为从右向左，2为随机移动，3为靠近角色
var move_direction: int = 1

var base_speed: float = SettingMoster.stone_man("speed")
var speed: float
var hpMax: float = SettingMoster.stone_man("hp")
var hp: float = SettingMoster.stone_man("hp")
var atk: float = SettingMoster.stone_man("atk")
var get_point: int = SettingMoster.stone_man("point")
var get_exp: int = SettingMoster.stone_man("exp")
var get_mechanism: int = SettingMoster.stone_man("mechanism")
var last_swordqi_damage_time: float = 0.0
const SWORDQI_DAMAGE_INTERVAL: float = 0.25
const CHARGE_TRIGGER_DISTANCE: float = 100.0
const CHARGE_DISTANCE: float = 110.0
const CHARGE_SPEED_MULTIPLIER: float = 5.0
const CHARGE_WARNING_TIME: float = 1.2
const CHARGE_WARNING_WIDTH: float = 16.0
const CHARGE_COOLDOWN: float = 5.0

# 精英怪相关
var is_charge_warning: bool = false
var is_charging: bool = false
var charge_direction: Vector2 = Vector2.ZERO
var charge_start_position: Vector2 = Vector2.ZERO
var charge_target_point: Vector2 = Vector2.ZERO
var charge_warning_node: WarnRectUtil
var last_charge_start_time: float = -100.0


func _ready():
	setup_monster_base(is_elite)
	speed = base_speed # Initialize speed

func _physics_process(delta: float) -> void:
	if hp <= 0:
		clear_charge_warning()
		is_charge_warning = false
		is_charging = false
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
			if SettingMoster.stone_man("itemdrop") != null:
				for key in SettingMoster.stone_man("itemdrop"):
					var drop_chance = SettingMoster.stone_man("itemdrop")[key] * drop_rate_multiplier
					if randf() <= drop_chance:
						Global.emit_signal("drop_out_item", key, 1, global_position)
				# for item in SettingMoster.stone_man("itemdrop"):
				# 	if randf() <= SettingMoster.stone_man("itemdrop")[item]:
				# 		Global.emit_signal("drop_out_item", item, 1, global_position)
			await get_tree().create_timer(0.35).timeout
			queue_free()
		
	if hp < hpMax and hp > 0:
		show_health_bar()
	
	if debuff_manager.is_action_disabled():
		return
	
	# 处理推挤效果（防止怪物重叠）
	if not is_dead and not is_charge_warning and not is_charging:
		CharacterEffects.apply_separation(self , 10.0, 12.0)
		
	if not is_dead:
		if is_charging:
			update_charge_movement(delta)
		elif is_charge_warning:
			pass
		else:
			try_start_charge_skill()
			if not is_charge_warning and not is_charging:
				if move_direction == 0:
					position += Vector2(speed, 0) * delta
					sprite.flip_h = true;
				if move_direction == 1:
					position -= Vector2(speed, 0) * delta
					sprite.flip_h = false;
				if move_direction >= 2:
					# 靠近角色的移动方
					if PC.player_instance != null:
						var player_pos = PC.player_instance.global_position
						var direction_to_player = (player_pos - global_position).normalized()
						speed = get_effective_move_speed(base_speed)
						position += direction_to_player * speed * delta
						# 根据移动方向设置精灵翻转
						if direction_to_player.x > 0:
							sprite.flip_h = true
						else:
							sprite.flip_h = false
	
	
	# 处理敌人之间的碰撞撞?- 直接防止重叠
	if monitoring and not is_charge_warning and not is_charging:
		var overlapping_bodies = get_overlapping_areas()
		
		for body in overlapping_bodies:
			if body.is_in_group("enemies") and !body.is_in_group("fly") and body != self:
				var distance = global_position.distance_to(body.global_position)
				var min_distance = 12.0 # 最小允许距离离?
				# 如果距离太近，直接调整位置
				if distance < min_distance and distance > 0.1:
					var direction_away = (global_position - body.global_position).normalized()
					var overlap = min_distance - distance
					# 两个物体各自移动一半的重叠距离
					position += direction_away * (overlap * 0.5)
	
	if move_direction == 0 and position.x <= -534:
		clear_charge_warning()
		free_health_bar()
		queue_free()
		
	if move_direction == 1 and position.x >= 534:
		clear_charge_warning()
		free_health_bar()
		queue_free()


func take_damage(damage: int, is_crit: bool, is_summon: bool, damage_type: String) -> void:
	if damage_type == "swordqi":
		var time_scale = 0.5 if PC.selected_rewards.has("SplitSwordQi22") else 1.0
		if not can_apply_interval_damage("last_swordqi_damage_time", SWORDQI_DAMAGE_INTERVAL, time_scale):
			return
		apply_common_take_damage(damage, is_crit, is_summon, damage_type, {"popup_type_override": 1})
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

func try_start_charge_skill():
	if PC.player_instance == null:
		return
	var current_time = Time.get_ticks_msec() / 1000.0
	var cooldown_elapsed = current_time - last_charge_start_time
	if cooldown_elapsed < CHARGE_COOLDOWN:
		return
	var player_pos = PC.player_instance.global_position
	var distance_to_player = global_position.distance_to(player_pos)
	if distance_to_player > CHARGE_TRIGGER_DISTANCE:
		return
	charge_direction = (player_pos - global_position).normalized()
	if charge_direction == Vector2.ZERO:
		return
	charge_start_position = global_position
	charge_target_point = charge_start_position + charge_direction * CHARGE_DISTANCE
	is_charge_warning = true
	is_charging = false
	last_charge_start_time = current_time
	sprite.flip_h = charge_direction.x > 0
	clear_charge_warning()
	charge_warning_node = WarnRectUtil.new()
	get_tree().current_scene.add_child(charge_warning_node)
	charge_warning_node.warning_finished.connect(_on_charge_warning_finished)
	charge_warning_node.start_warning(charge_start_position, charge_target_point, CHARGE_WARNING_WIDTH, CHARGE_WARNING_TIME, 0.0, null, 0.25)

func _on_charge_warning_finished():
	clear_charge_warning()
	if is_dead:
		is_charge_warning = false
		is_charging = false
		return
	is_charge_warning = false
	is_charging = true
	charge_start_position = global_position

func update_charge_movement(delta: float):
	var charge_speed = get_effective_move_speed(base_speed, CHARGE_SPEED_MULTIPLIER)
	var moved_distance = global_position.distance_to(charge_start_position)
	var remain_distance = CHARGE_DISTANCE - moved_distance
	if remain_distance <= 0.0:
		is_charging = false
		return
	var step_distance = charge_speed * delta
	if step_distance > remain_distance:
		step_distance = remain_distance
	position += charge_direction * step_distance
	sprite.flip_h = charge_direction.x > 0
	if step_distance == remain_distance:
		is_charging = false

func clear_charge_warning():
	if charge_warning_node != null and is_instance_valid(charge_warning_node):
		charge_warning_node.cleanup()
	charge_warning_node = null

func _exit_tree():
	clear_charge_warning()



