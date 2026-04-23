extends "res://Script/monster/monster_base.gd"

@onready var sprite = $AnimatedSprite2D
# 0为从左到右，1为从右向左，2为随机移动，3为靠近角色
var move_direction: int = 1

var base_speed: float = SettingMoster.ball("speed")
var speed: float
var hpMax: float = SettingMoster.ball("hp")
var hp: float = SettingMoster.ball("hp")
var atk: float = SettingMoster.ball("atk")
var get_point: int = SettingMoster.ball("point")
var get_exp: int = SettingMoster.ball("exp")
var get_mechanism: int = SettingMoster.ball("mechanism")
var last_sword_wave_damage_time: float = 0.0
const SWORD_WAVE_DAMAGE_INTERVAL: float = 0.25

# AOE技能参数
const AOE_TRIGGER_DISTANCE: float = 20.0
const AOE_WARNING_TIME: float = 2.0
const AOE_COOLDOWN: float = 15.0
const AOE_ELLIPSE_A: float = 20.0 # 椭圆半长轴（水平），长40像素
const AOE_ELLIPSE_B: float = 15.0 # 椭圆半短轴（垂直），高30像素

# 精英怪相关

# AOE技能状态
var is_aoe_warning: bool = false
var aoe_warning_timer: float = 0.0
var last_aoe_start_time: float = -100.0
var aoe_warning_node: Node2D = null


func _ready():
	setup_monster_base(is_elite)
	speed = base_speed # Initialize speed

func _physics_process(delta: float) -> void:
	if hp <= 0:
		_clear_aoe_warning()
		is_aoe_warning = false
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
			if SettingMoster.ball("itemdrop") != null:
				for key in SettingMoster.ball("itemdrop"):
					var drop_chance = SettingMoster.ball("itemdrop")[key] * drop_rate_multiplier
					if randf() <= drop_chance:
						Global.emit_signal("drop_out_item", key, 1, global_position)
			await get_tree().create_timer(0.35).timeout
			queue_free()
		
	if hp < hpMax and hp > 0:
		show_health_bar()
	
	if debuff_manager.is_action_disabled():
		return
	
	# 处理推挤效果（AOE预警期间不推挤）
	if not is_dead and not is_aoe_warning:
		CharacterEffects.apply_separation(self , 10.0, 12.0)
		
	if not is_dead:
		if is_aoe_warning:
			_aoe_warning_update(delta)
		else:
			# 尝试触发AOE
			try_start_aoe_skill()
			if not is_aoe_warning:
				if move_direction == 0:
					position += Vector2(speed, 0) * delta
					sprite.flip_h = true;
				if move_direction == 1:
					position -= Vector2(speed, 0) * delta
					sprite.flip_h = false;
				if move_direction >= 2:
					# 靠近角色的移动方式
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
	
	
	# 处理敌人之间的碰撞（AOE预警期间不处理）
	if monitoring and not is_aoe_warning:
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
	
	if move_direction == 0 and position.x <= -534:
		_clear_aoe_warning()
		free_health_bar()
		queue_free()
		
	if move_direction == 1 and position.x >= 534:
		_clear_aoe_warning()
		free_health_bar()
		queue_free()


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


# ============== AOE技能逻辑 ==============

func try_start_aoe_skill() -> void:
	"""检查是否满足AOE触发条件"""
	if PC.player_instance == null:
		return
	var current_time = Time.get_ticks_msec() / 1000.0
	var cooldown_elapsed = current_time - last_aoe_start_time
	if cooldown_elapsed < AOE_COOLDOWN:
		return
	var player_pos = PC.player_instance.global_position
	var distance_to_player = global_position.distance_to(player_pos)
	if distance_to_player > AOE_TRIGGER_DISTANCE:
		return
	# 满足条件：开始AOE预警
	last_aoe_start_time = current_time
	is_aoe_warning = true
	aoe_warning_timer = 0.0
	# 播放aoe动画
	$AnimatedSprite2D.play("aoe")
	# 创建椭圆预警视觉效果
	_create_aoe_warning()

func _create_aoe_warning() -> void:
	"""创建椭圆形AOE预警视觉效果"""
	var warning = Node2D.new()
	warning.name = "BallAOEWarning"
	warning.set_script(preload("res://Script/util/ellipse_warning.gd"))
	get_tree().current_scene.add_child(warning)
	warning.start(global_position, AOE_ELLIPSE_A, AOE_ELLIPSE_B, AOE_WARNING_TIME)
	aoe_warning_node = warning

func _aoe_warning_update(delta: float) -> void:
	"""AOE预警期间：跟着玩家走，更新预警位置，计时判定"""
	# 跟着玩家移动
	if PC.player_instance != null:
		var player_pos = PC.player_instance.global_position
		var direction_to_player = (player_pos - global_position).normalized()
		speed = get_effective_move_speed(base_speed)
		position += direction_to_player * speed * delta
		if direction_to_player.x > 0:
			sprite.flip_h = true
		else:
			sprite.flip_h = false
	
	# 更新预警节点位置
	if aoe_warning_node and is_instance_valid(aoe_warning_node):
		aoe_warning_node.global_position = global_position
	
	# 计时
	aoe_warning_timer += delta
	if aoe_warning_timer >= AOE_WARNING_TIME:
		# 预警结束，判定伤害
		_aoe_deal_damage()
		is_aoe_warning = false
		_clear_aoe_warning()
		# 恢复行走动画
		$AnimatedSprite2D.play("default")

func _aoe_deal_damage() -> void:
	"""椭圆形范围伤害判定"""
	if PC.player_instance == null or not is_instance_valid(PC.player_instance):
		return
	if PC.invincible:
		return
	var player_pos = PC.player_instance.global_position
	var relative = player_pos - global_position
	# 椭圆方程: (x/a)^2 + (y/b)^2 <= 1
	var nx = relative.x / AOE_ELLIPSE_A
	var ny = relative.y / AOE_ELLIPSE_B
	if nx * nx + ny * ny <= 1.0:
		var actual_damage = int(atk * (1.0 - PC.damage_reduction_rate))
		var hit_source_name = "范围伤害"
		PC.player_hit(actual_damage, self , hit_source_name)
		if PC.pc_hp <= 0:
			PC.player_instance.game_over()

func _clear_aoe_warning() -> void:
	"""清理AOE预警节点"""
	if aoe_warning_node != null and is_instance_valid(aoe_warning_node):
		aoe_warning_node.queue_free()
	aoe_warning_node = null

func _exit_tree():
	_clear_aoe_warning()
