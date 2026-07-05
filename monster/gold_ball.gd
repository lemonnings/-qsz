extends "res://Script/monster/monster_base.gd"

@onready var sprite = $AnimatedSprite2D
# 保留字段兼容旧生成代码；金团团实际使用类似 ghost 的随机游走。
var move_direction: int = 2
var move_vector: Vector2 = Vector2.LEFT
var wander_direction_timer: float = 0.0
var is_out_of_view: bool = false

var base_speed: float = SettingMoster.goldball("speed")
var speed: float
var hpMax: float = SettingMoster.goldball("hp")
var hp: float = SettingMoster.goldball("hp")
var atk: float = SettingMoster.goldball("atk")
var get_point: int = SettingMoster.goldball("point")
var get_exp: int = SettingMoster.goldball("exp")
var last_sword_wave_damage_time: float = 0.0
const SWORD_WAVE_DAMAGE_INTERVAL: float = 0.25
const WANDER_DIRECTION_CHANGE_INTERVAL: float = 2.0
const WANDER_VIEW_MARGIN_PIXELS: float = 48.0


func _ready():
	setup_monster_base(is_elite)
	speed = base_speed # Initialize speed
	_pick_random_direction()

func _physics_process(delta: float) -> void:
	if hp <= 0:
		free_health_bar()
		if not is_dead: # Add this check
			$AnimatedSprite2D.stop()
			$AnimatedSprite2D.play("death")
			var point_gain = int(get_point * Faze.get_point_multiplier())
			# 修习树特殊篇：金团团掉落真气量提升
			grant_kill_point_rewards(point_gain)
			Global.total_points += point_gain
			var exp_gain = int(get_exp * Faze.get_exp_multiplier())
			Global.emit_signal("drop_exp_orb", exp_gain, global_position, is_elite)
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
			if SettingMoster.goldball("itemdrop") != null:
				for key in SettingMoster.goldball("itemdrop"):
					var drop_chance = SettingMoster.goldball("itemdrop")[key] * SettingMoster.get_item_drop_rate_multiplier(key, drop_rate_multiplier)
					if randf() <= drop_chance:
						Global.emit_signal("drop_out_item", key, 3, global_position)
				# for item in SettingMoster.paper("itemdrop"):
				# 	if randf() <= SettingMoster.paper("itemdrop")[item]:
				# 		Global.emit_signal("drop_out_item", item, 1, global_position)
			await get_tree().create_timer(0.35).timeout
			queue_free()
		
	if hp < hpMax and hp > 0:
		show_health_bar()
	
	if should_skip_actions_for_debuff():
		return
	
	# 处理推挤效果（防止怪物重叠）
	if not is_dead:
		CharacterEffects.apply_separation(self , 10.0, 12.0)
		
	if not is_dead:
		if hp > 0 and CharacterEffects.is_player_dead_or_game_over():
			move_away_from_dead_player(delta, base_speed, sprite)
			return
		speed = get_effective_move_speed(base_speed)
		_update_wander_direction(delta)
		position += CharacterEffects.apply_soft_separation_to_direction(self, move_vector) * speed * delta
		if move_vector.x > 0:
			CharacterEffects.set_enemy_flip_h(self, sprite, true)
		elif move_vector.x < 0:
			CharacterEffects.set_enemy_flip_h(self, sprite, false)
		if clamp_self_to_scene_bounds(16.0):
			_pick_direction_to_safe_zone()

func _pick_random_direction() -> void:
	move_vector = choose_camera_wander_direction(move_vector, 35.0, WANDER_VIEW_MARGIN_PIXELS, 16.0)
	wander_direction_timer = randf_range(0.0, WANDER_DIRECTION_CHANGE_INTERVAL)

func _update_wander_direction(delta: float) -> void:
	wander_direction_timer -= delta
	var wander_bounds := get_camera_wander_bounds(WANDER_VIEW_MARGIN_PIXELS, 16.0)
	var currently_out_of_view := is_position_outside_rect(global_position, wander_bounds)
	if currently_out_of_view and not is_out_of_view:
		wander_direction_timer = 0.0
	if wander_direction_timer <= 0.0:
		move_vector = choose_camera_wander_direction(move_vector, 35.0, WANDER_VIEW_MARGIN_PIXELS, 16.0)
		wander_direction_timer = WANDER_DIRECTION_CHANGE_INTERVAL
	is_out_of_view = currently_out_of_view

func _pick_direction_to_safe_zone() -> void:
	move_vector = choose_camera_wander_direction(move_vector, 25.0, WANDER_VIEW_MARGIN_PIXELS, 16.0)


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
			# 如果已经死亡，则不重复播放死亡动画，也不播放动画
			if not is_dead:
				$AnimatedSprite2D.play("death")
		else:
			Global.play_hit_anime(position, is_crit)
