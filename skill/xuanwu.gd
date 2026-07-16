extends Area2D
class_name Xuanwu

@export var sprite: AnimatedSprite2D
@export var collision: CollisionShape2D

static var main_skill_xuanwu_damage: float = 0.60
static var xuanwu_hp_damage_ratio: float = 0.08
static var xuanwu_range: float = 240.0
static var xuanwu_shield_base: int = 30
static var xuanwu_shield_hp_ratio: float = 0.04
static var xuanwu_width_scale: float = 1.0
static var xuanwu_slow_duration: float = 0.0
static var xuanwu_vulnerable_duration: float = 0.0
static var xuanwu_shield_bonus_damage: float = 0.0
static var xuanwu_return_shield_bonus: float = 0.0
static var xuanwu_shield_base_bonus: int = 0
static var xuanwu_final_damage_multi: float = 1.0
static var xuanwu_shield_duration: float = 5.0
const PLAYER_CATCH_PADDING: float = 14.0
const DAMAGE_DECAY_PER_HIT: float = 0.95

static func reset_data() -> void:
	main_skill_xuanwu_damage = 0.60
	xuanwu_hp_damage_ratio = 0.08
	xuanwu_range = 240.0
	xuanwu_shield_base = 30
	xuanwu_shield_hp_ratio = 0.04
	xuanwu_width_scale = 1.0
	xuanwu_slow_duration = 0.0
	xuanwu_vulnerable_duration = 0.0
	xuanwu_shield_bonus_damage = 0.0
	xuanwu_return_shield_bonus = 0.0
	xuanwu_shield_base_bonus = 0
	xuanwu_final_damage_multi = 1.0
	xuanwu_shield_duration = 5.0

enum State {FORWARD, RETURN, MISS}
var state = State.FORWARD

var direction = Vector2.RIGHT
var speed = 320.0
var damage = 0.0
var max_dist = 240.0
var traveled_dist = 0.0
var return_angle_offset = 0.0
var return_start_dist = 0.0 # Distance to player when starting return
var return_traveled_dist = 0.0
var miss_dist = 400.0
var miss_traveled = 0.0
var base_node_scale: Vector2 = Vector2.ONE

var hit_abnormal = false # Track if we hit an enemy with abnormal status

# Instance variables for effects
var shield_gain: int = 0
var slow_duration: float = 0.0
var vulnerable_duration: float = 0.0
var return_shield_bonus: float = 0.0
var shield_duration: float = 0.0
var current_damage_multiplier: float = 1.0
var _caught: bool = false

static func fire_skill(scene: PackedScene, origin_pos: Vector2, tree: SceneTree) -> void:
	if not scene:
		return
		
	var data = _build_data()
	
	# 寻找目标
	var enemies = tree.get_nodes_in_group("enemies")
	var target = null
	var min_dist = INF
	
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist = origin_pos.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				target = enemy
	
	var target_pos = Vector2.ZERO
	if target:
		target_pos = target.global_position
	else:
		# 如果没有敌人，向面朝方向发射
		var player = tree.get_first_node_in_group("player")
		if player and not player.sprite_direction_right:
			target_pos = origin_pos + Vector2(-100, 0)
		else:
			target_pos = origin_pos + Vector2(100, 0)
			
	var instance = scene.instantiate()
	tree.current_scene.add_child(instance)
	instance.setup(origin_pos, target_pos, data)

static func _build_data() -> Dictionary:
	var damage_multiplier = main_skill_xuanwu_damage # 60% 攻击 + 10% 最大体力
	var hp_damage_ratio = xuanwu_hp_damage_ratio
	var range_val = xuanwu_range
	var shield_base = xuanwu_shield_base
	var shield_hp_ratio = xuanwu_shield_hp_ratio
	var width_scale = xuanwu_width_scale
	var shield_bonus_damage = xuanwu_shield_bonus_damage
	var final_damage_multi = xuanwu_final_damage_multi
	
	var d_slow_duration = xuanwu_slow_duration
	var d_vulnerable_duration = xuanwu_vulnerable_duration
	var shield_base_bonus = xuanwu_shield_base_bonus
	var d_return_shield_bonus = xuanwu_return_shield_bonus
	var d_shield_duration = xuanwu_shield_duration
	
	# Upgrades
	if PC.selected_rewards.has("Xuanwu2"):
		shield_bonus_damage = 3.0
		
	if PC.selected_rewards.has("Xuanwu4") or PC.selected_rewards.has("Xuanwu33"):
		width_scale = 1.5
		
	if PC.selected_rewards.has("Xuanwu22"):
		d_return_shield_bonus = 0.3

	
	var atk_dmg = PC.pc_atk * damage_multiplier
	var hp_level_multiplier: float = pow(1.02, max(0, PC.pc_lv - 1))
	var hp_dmg = PC.pc_max_hp * hp_damage_ratio * hp_level_multiplier
	var total_damage = atk_dmg + hp_dmg
	# 法则伤害加成累加（不是乘法），避免奖励加成 × 法则加成的双重叠加
	total_damage = SettingStudyTreeUp.apply_total_damage_bonus_to_damage_excluding(total_damage, "xuanwu", ["treasure"])
	
	
	if shield_bonus_damage > 0:
		var shield_total = PC.get_total_shield()
		var shield_pct = 0.0
		if PC.pc_max_hp > 0:
			shield_pct = float(shield_total) / float(PC.pc_max_hp) * 100.0
		total_damage *= (1.0 + (shield_pct * shield_bonus_damage * 0.01))
		
	if final_damage_multi > 1.0:
		total_damage *= final_damage_multi
		
	# Calculate Shield Gain
	var shield_gain_val = shield_base + shield_base_bonus
	if PC.pc_max_hp > 0:
		shield_gain_val += int(PC.pc_max_hp * shield_hp_ratio)
		
	return {
		"damage": total_damage,
		"range": range_val,
		"width_scale": width_scale,
		"shield_gain": shield_gain_val,
		"slow_duration": d_slow_duration,
		"vulnerable_duration": d_vulnerable_duration,
		"return_shield_bonus": d_return_shield_bonus,
		"shield_duration": d_shield_duration
	}

func _ready():
	CharacterEffects.include_enemy_collision_mask(self)
	base_node_scale = scale
	connect("body_entered", Callable(self , "_on_body_entered"))
	connect("area_entered", Callable(self , "_on_area_entered"))
	
	return_angle_offset = deg_to_rad(randf_range(-3, 3))

func setup(pos: Vector2, target_pos: Vector2, data: Dictionary = {}):
	global_position = pos
	direction = (target_pos - pos).normalized()
	rotation = direction.angle()
	
	if data.has("damage"):
		damage = data.damage
	if data.has("range"):
		max_dist = data.range * Global.get_attack_range_multiplier()
	var width_scale = Global.get_attack_range_multiplier()
	if data.has("width_scale"):
		width_scale *= data.width_scale
	scale = Vector2(base_node_scale.x * width_scale, base_node_scale.y * width_scale)
	if data.has("shield_gain"):
		shield_gain = data.shield_gain
	if data.has("slow_duration"):
		slow_duration = data.slow_duration
	if data.has("vulnerable_duration"):
		vulnerable_duration = data.vulnerable_duration
	if data.has("return_shield_bonus"):
		return_shield_bonus = data.return_shield_bonus
	if data.has("shield_duration"):
		shield_duration = data.shield_duration

func _process(delta):
	if _caught:
		return

	var previous_global_position := global_position
	# Rotate 360 degrees per second
	rotation += 4 * PI * delta
	
	var step = speed * delta
	
	if state == State.FORWARD:
		position += direction * step
		traveled_dist += step
		if traveled_dist >= max_dist:
			_start_return()
			if _caught:
				return
			
	elif state == State.RETURN:
		position += direction * step
		return_traveled_dist += step
		_try_catch_player(previous_global_position)
		if _caught:
			return
		
		if return_traveled_dist > return_start_dist + 50:
			state = State.MISS
			
	elif state == State.MISS:
		position += direction * step
		miss_traveled += step
		_try_catch_player(previous_global_position)
		if _caught:
			return
		modulate.a = 1.0 - (miss_traveled / miss_dist)
		if miss_traveled >= miss_dist:
			queue_free()

func _start_return():
	state = State.RETURN
	if PC.player_instance:
		var to_player = (PC.player_instance.global_position - global_position)
		return_start_dist = to_player.length()
		direction = to_player.normalized().rotated(return_angle_offset)
		_try_catch_player(global_position)
	else:
		queue_free()

func _on_area_entered(area: Area2D):
	_handle_hit(area)

func _on_body_entered(body: Node):
	_handle_hit(body)

func _handle_hit(target: Node):
	if _caught:
		return
	if target.is_in_group("enemies"):
		if target.has_method("take_damage"):
			var is_crit = false
			var final_damage = damage * current_damage_multiplier
			if randf() < PC.crit_chance:
				is_crit = true
				final_damage *= PC.crit_damage_multi
			if target.is_in_group("elite") or target.is_in_group("boss"):
				final_damage = final_damage * Faze.get_treasure_elite_boss_multiplier(PC.faze_treasure_level, PC.get_lucky_level())
			if target.is_in_group("boss") and PC.selected_rewards.has("Xuanwu2"):
				final_damage *= 1.5
				
			target.take_damage(int(final_damage), is_crit, false, "xuanwu")
			current_damage_multiplier *= DAMAGE_DECAY_PER_HIT
			# 击中粒子崩散特效
			HitParticleSpawner.spawn_by_weapon(get_tree(), target.global_position, "xuanwu")
			
			# Check for abnormal status (for Xuanwu22 bonus)
			if target.get("debuff_manager") and target.debuff_manager.has_method("get_debuff_count"):
				if target.debuff_manager.get_debuff_count() > 0:
					hit_abnormal = true
				
			# Apply Debuffs
			if slow_duration > 0 and target.has_method("apply_debuff"):
				target.apply_debuff("slow", slow_duration)
				
			if vulnerable_duration > 0 and target.has_method("apply_debuff"):
				target.apply_debuff("vulnerable", vulnerable_duration)
				
	elif target.is_in_group("player") and _can_catch_player():
		_catch_returned_shield()

func _can_catch_player() -> bool:
	return not _caught and (state == State.RETURN or state == State.MISS)

func _try_catch_player(previous_global_position: Vector2) -> void:
	if not _can_catch_player():
		return
	if not is_instance_valid(PC.player_instance):
		return
	var player_pos: Vector2 = PC.player_instance.global_position
	var catch_radius := _get_player_catch_radius()
	if _point_to_segment_distance_squared(player_pos, previous_global_position, global_position) <= catch_radius * catch_radius:
		_catch_returned_shield()

func _get_player_catch_radius() -> float:
	var radius := 18.0
	if collision and collision.shape is CircleShape2D:
		var circle := collision.shape as CircleShape2D
		radius = circle.radius * maxf(absf(collision.global_scale.x), absf(collision.global_scale.y))
	return radius + PLAYER_CATCH_PADDING

func _point_to_segment_distance_squared(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> float:
	var segment := segment_end - segment_start
	var length_sq := segment.length_squared()
	if length_sq <= 0.0001:
		return point.distance_squared_to(segment_end)
	var t := clampf((point - segment_start).dot(segment) / length_sq, 0.0, 1.0)
	var closest := segment_start + segment * t
	return point.distance_squared_to(closest)

func _catch_returned_shield() -> void:
	if _caught:
		return
	_caught = true
	var final_shield = shield_gain
	if hit_abnormal:
		final_shield = int(float(final_shield) * (1.0 + return_shield_bonus))
	if final_shield > 0:
		PC.add_shield(final_shield, shield_duration, "xuanwu")
	queue_free()
