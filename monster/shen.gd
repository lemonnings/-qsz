extends "res://Script/monster/monster_base.gd"

@onready var sprite = $AnimatedSprite2D
# 0为从左到右，1为从右向左，2为随机移动，3为靠近角色
var move_direction: int = 1

var base_speed: float = SettingMoster.shen("speed")
var speed: float
var hpMax: float = SettingMoster.shen("hp")
var hp: float = SettingMoster.shen("hp")
var atk: float = SettingMoster.shen("atk")
var get_point: int = SettingMoster.shen("point")
var get_exp: int = SettingMoster.shen("exp")
var get_mechanism: int = SettingMoster.shen("mechanism")
var last_sword_wave_damage_time: float = 0.0
const SWORD_WAVE_DAMAGE_INTERVAL: float = 0.25

# 精英怪相关


func _ready():
	setup_monster_base(is_elite)
	speed = base_speed # Initialize speed

func _physics_process(delta: float) -> void:
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
			if SettingMoster.shen("itemdrop") != null:
				for key in SettingMoster.shen("itemdrop"):
					var drop_chance = SettingMoster.shen("itemdrop")[key] * drop_rate_multiplier
					if randf() <= drop_chance:
						Global.emit_signal("drop_out_item", key, 1, global_position)
				# for item in SettingMoster.shen("itemdrop"):
				# 	if randf() <= SettingMoster.shen("itemdrop")[item]:
				# 		Global.emit_signal("drop_out_item", item, 1, global_position)
			await get_tree().create_timer(0.35).timeout
			queue_free()
		
	if hp < hpMax and hp > 0:
		show_health_bar()
	
	if debuff_manager.is_action_disabled():
		return
	
	# 处理推挤效果（防止怪物重叠）
	if not is_dead:
		CharacterEffects.apply_separation(self , 10.0, 12.0)
		
	if not is_dead:
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
	
	if move_direction == 0 and position.x <= -534:
		free_health_bar()
		queue_free()
		
	if move_direction == 1 and position.x >= 534:
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



