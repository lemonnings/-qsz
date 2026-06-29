extends "res://Script/monster/monster_base.gd"

@onready var sprite = $AnimatedSprite2D
# 0为从左到右，1为从右向左，2为随机移动，3为靠近角色
var move_direction: int = 1

var base_speed: float = SettingMoster.armor_stone("speed")
var speed: float
var hpMax: float = SettingMoster.armor_stone("hp")
var hp: float = SettingMoster.armor_stone("hp")
var atk: float = SettingMoster.armor_stone("atk")
var get_point: int = SettingMoster.armor_stone("point")
var get_exp: int = SettingMoster.armor_stone("exp")
var last_sword_wave_damage_time: float = 0.0
const SWORD_WAVE_DAMAGE_INTERVAL: float = 0.25


func _ready():
	setup_monster_base(is_elite)
	speed = base_speed # Initialize speed
	CharacterEffects.create_shadow(self, 24.0, 8.0, 11.0)

func _physics_process(delta: float) -> void:
	if hp <= 0:
		free_health_bar()
		if not is_dead: # Add this check
			$AnimatedSprite2D.stop()
			$AnimatedSprite2D.play("death")
			var point_gain = int(get_point * Faze.get_point_multiplier())
			grant_kill_point_rewards(point_gain)
			var exp_gain = int(get_exp * Faze.get_exp_multiplier())
			Global.emit_signal("drop_exp_orb", exp_gain, global_position, is_elite)
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
			if SettingMoster.armor_stone("itemdrop") != null:
				for key in SettingMoster.armor_stone("itemdrop"):
					var drop_chance = SettingMoster.armor_stone("itemdrop")[key] * SettingMoster.get_item_drop_rate_multiplier(key, drop_rate_multiplier)
					if randf() <= drop_chance:
						Global.emit_signal("drop_out_item", key, 1, global_position)
				# for item in SettingMoster.armor_stone("itemdrop"):
				# 	if randf() <= SettingMoster.armor_stone("itemdrop")[item]:
				# 		Global.emit_signal("drop_out_item", item, 1, global_position)
			await get_tree().create_timer(0.35).timeout
			queue_free()
		
	if hp < hpMax and hp > 0:
		show_health_bar()
	
	if should_skip_actions_for_debuff():
		return
	
	# 处理推挤效果（防止怪物重叠））
	if not is_dead:
		CharacterEffects.apply_separation(self , 10.0, 12.0)
		
	if not is_dead:
		if hp > 0 and CharacterEffects.is_player_dead_or_game_over():
			move_away_from_dead_player(delta, base_speed, sprite)
			return
		if move_direction == 0:
			position += CharacterEffects.apply_soft_separation_to_direction(self, Vector2.RIGHT) * speed * delta
			CharacterEffects.set_enemy_flip_h(self, sprite, true)
		if move_direction == 1:
			position += CharacterEffects.apply_soft_separation_to_direction(self, Vector2.LEFT) * speed * delta
			CharacterEffects.set_enemy_flip_h(self, sprite, false)
		if move_direction >= 2:
					# 靠近角色的移动方式
			if PC.player_instance != null:
				var direction_to_player = CharacterEffects.get_tracking_direction_to_player(self)
				if direction_to_player != Vector2.ZERO:
					speed = get_effective_move_speed(base_speed)
					position += direction_to_player * speed * delta
							# 根据移动方向设置精灵翻转
					CharacterEffects.face_player_x(self, sprite)
	
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
		
		# 根据穿透逻辑决定是否销毁子弹弹
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
			# 如果已经死亡，则不重复播放死亡动画，也不播放动画
			if not is_dead:
				$AnimatedSprite2D.play("death")
		else:
			Global.play_hit_anime(position, is_crit)

func _exit_tree():
	pass
