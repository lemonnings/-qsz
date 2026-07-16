extends Area2D
class_name Zhuazhuajuchui

@export var sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D
@export var search_radius: float = 120.0

const BASE_DAMAGE_RATIO: float = 0.72
const BOSS_DAMAGE_MULTIPLIER: float = 2.0
const BASE_KNOCKBACK: float = 12.0
const VULNERABLE_DURATION: float = 5.0
const DEFAULT_HIT_TIME: float = 0.25
const DEFAULT_LIFE_TIME: float = 0.45
const EMPOWERED_POSITION_OFFSET: Vector2 = Vector2(0.0, -20.0)

static var main_skill_zhuazhuajuchui_damage: float = BASE_DAMAGE_RATIO
static var zhuazhuajuchui_knockback: float = BASE_KNOCKBACK
static var zhuazhuajuchui_slam_count: int = 0

var base_sprite_scale: Vector2 = Vector2.ONE
var base_sprite_position: Vector2 = Vector2.ZERO
var base_sprite_flip_h: bool = false
var base_collision_scale: Vector2 = Vector2.ONE
var base_collision_position: Vector2 = Vector2.ZERO
var cached_attack_data: Dictionary = {}
var current_range_multiplier: float = 1.0
var current_position_offset: Vector2 = Vector2.ZERO
var facing_right: bool = true
var target_direction: Vector2 = Vector2.RIGHT
var hit_targets: Dictionary = {}
var damage_active: bool = false
var custom_damage_multiplier: float = 1.0

func set_custom_damage_multiplier(multiplier: float) -> void:
	custom_damage_multiplier = maxf(0.0, multiplier)

static func reset_data() -> void:
	main_skill_zhuazhuajuchui_damage = BASE_DAMAGE_RATIO
	zhuazhuajuchui_knockback = BASE_KNOCKBACK
	zhuazhuajuchui_slam_count = 0

func _ready() -> void:
	CharacterEffects.include_enemy_collision_mask(self)
	base_sprite_scale = sprite.scale if sprite != null else Vector2.ONE
	base_sprite_position = sprite.position if sprite != null else Vector2.ZERO
	base_sprite_flip_h = sprite.flip_h if sprite != null else false
	base_collision_scale = collision_shape.scale if collision_shape != null else Vector2.ONE
	base_collision_position = collision_shape.position if collision_shape != null else Vector2.ZERO
	
	cached_attack_data = _build_attack_data()
	current_position_offset = cached_attack_data.get("position_offset", Vector2.ZERO)
	_apply_range(float(cached_attack_data.get("range_multiplier", 1.0)))
	
	var player := PC.player_instance as Node2D
	if player == null:
		queue_free()
		return
	var player_position := player.global_position
	var effective_radius := _get_effective_radius(float(cached_attack_data.get("range_multiplier", 1.0)))
	var target_center := _find_most_dense_center(player_position, search_radius * Global.get_attack_range_multiplier(), effective_radius)
	
	global_position = player_position
	_apply_facing(player_position, target_center)
	if sprite != null:
		sprite.play("default")
	
	await get_tree().physics_frame
	if collision_shape != null:
		collision_shape.set_deferred("disabled", false)
	damage_active = true
	await get_tree().create_timer(float(cached_attack_data.get("hit_time", DEFAULT_HIT_TIME))).timeout
	GU.screen_shake(1.45, 0.08)
	damage_active = false
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	var remain_time := float(cached_attack_data.get("life_time", DEFAULT_LIFE_TIME)) - float(cached_attack_data.get("hit_time", DEFAULT_HIT_TIME))
	if remain_time > 0.0:
		await get_tree().create_timer(remain_time).timeout
	queue_free()

func _build_attack_data() -> Dictionary:
	zhuazhuajuchui_slam_count += 1
	var damage_ratio := main_skill_zhuazhuajuchui_damage
	var knockback := zhuazhuajuchui_knockback
	var range_multiplier := 1.0
	var apply_vulnerable := false
	var vulnerable_knockback_bonus := 0.0
	var vulnerable_damage_bonus := 0.0
	var position_offset := Vector2.ZERO
	
	if PC.selected_rewards.has("Zhuazhuajuchui1"):
		damage_ratio += 0.05
		knockback = maxf(knockback, 16.0)
	if PC.selected_rewards.has("Zhuazhuajuchui2"):
		apply_vulnerable = true
		vulnerable_knockback_bonus = 4.0
	if PC.selected_rewards.has("Zhuazhuajuchui4"):
		damage_ratio += 0.05
		range_multiplier += 0.15
		range_multiplier += _get_missing_hp_range_bonus()
	if PC.selected_rewards.has("Zhuazhuajuchui11"):
		damage_ratio += 0.05
		range_multiplier += _get_missing_hp_range_bonus(true) - _get_missing_hp_range_bonus(false)
	if PC.selected_rewards.has("Zhuazhuajuchui22"):
		vulnerable_damage_bonus = 0.30
		vulnerable_knockback_bonus = 8.0
	
	damage_ratio += Faze.get_blood_weapon_damage_multiplier(PC.faze_blood_level) - 1.0
	
	var empowered := PC.selected_rewards.has("Zhuazhuajuchui3") and zhuazhuajuchui_slam_count % 3 == 0
	if empowered:
		var empowered_bonus := 1.00 if PC.selected_rewards.has("Zhuazhuajuchui33") else 0.50
		var empowered_knockback_bonus := 0.60 if PC.selected_rewards.has("Zhuazhuajuchui33") else 0.30
		damage_ratio *= 1.0 + empowered_bonus
		range_multiplier *= 1.0 + empowered_bonus
		knockback *= 1.0 + empowered_knockback_bonus
		position_offset = EMPOWERED_POSITION_OFFSET
	
	knockback *= Faze.get_deep_knockback_multiplier(PC.faze_deep_level)
	knockback *= PC.get_knockback_multiplier()
	var damage := float(PC.pc_atk) * damage_ratio * custom_damage_multiplier
	damage = PC.apply_base_weapon_emblem_damage_bonus(damage, "zhuazhuajuchui")
	
	return {
		"damage": damage,
		"deep_base_damage": damage,
		"knockback": knockback,
		"range_multiplier": range_multiplier,
		"apply_vulnerable": apply_vulnerable,
		"vulnerable_knockback_bonus": vulnerable_knockback_bonus,
		"vulnerable_damage_bonus": vulnerable_damage_bonus,
		"position_offset": position_offset,
		"hit_time": DEFAULT_HIT_TIME,
		"life_time": DEFAULT_LIFE_TIME
	}

func _get_missing_hp_range_bonus(upgraded: bool = false) -> float:
	if PC.pc_max_hp <= 0:
		return 0.0
	var missing_ratio: float = clampf(float(PC.pc_max_hp - PC.pc_hp) / float(PC.pc_max_hp), 0.0, 1.0)
	var steps: float = floor(missing_ratio / 0.05)
	var per_step: float = 0.03 if upgraded else 0.01
	return steps * per_step

func _apply_range(range_multiplier: float) -> void:
	current_range_multiplier = range_multiplier * Global.get_attack_range_multiplier()
	_apply_attack_transform()

func _apply_attack_transform() -> void:
	var direction_sign := 1.0 if facing_right else -1.0
	if sprite != null:
		sprite.position = Vector2(base_sprite_position.x * direction_sign, base_sprite_position.y) + current_position_offset
		sprite.scale = base_sprite_scale * current_range_multiplier
		sprite.flip_h = base_sprite_flip_h if facing_right else not base_sprite_flip_h
	if collision_shape != null:
		collision_shape.position = Vector2(base_collision_position.x * direction_sign, base_collision_position.y) + current_position_offset
		collision_shape.scale = base_collision_scale * current_range_multiplier

func _get_effective_radius(range_multiplier: float) -> float:
	if collision_shape == null or collision_shape.shape == null:
		return 60.0 * range_multiplier * Global.get_attack_range_multiplier()
	var circle_shape := collision_shape.shape as CircleShape2D
	if circle_shape != null:
		return circle_shape.radius * absf(base_collision_scale.x) * range_multiplier * Global.get_attack_range_multiplier()
	return 60.0 * range_multiplier * Global.get_attack_range_multiplier()

func _find_most_dense_center(player_position: Vector2, search_radius_limit: float, cluster_radius: float) -> Vector2:
	var candidates: Array = []
	candidates.append_array(get_tree().get_nodes_in_group("enemies"))
	candidates.append_array(get_tree().get_nodes_in_group("boss"))
	if candidates.is_empty():
		return player_position
	var valid_candidates: Array[Node2D] = []
	for candidate in candidates:
		if candidate is Node2D and player_position.distance_to(candidate.global_position) <= search_radius_limit:
			valid_candidates.append(candidate)
	if valid_candidates.is_empty():
		return player_position
	var best_count := 0
	var best_center := player_position
	for enemy in valid_candidates:
		var count := 0
		var sum_position := Vector2.ZERO
		for other in valid_candidates:
			if enemy.global_position.distance_to(other.global_position) <= cluster_radius:
				count += 1
				sum_position += other.global_position
		if count > best_count:
			best_count = count
			best_center = sum_position / float(count)
	return best_center

func _apply_facing(player_position: Vector2, target_center: Vector2) -> void:
	var direction := target_center - player_position
	if absf(direction.x) < 0.001:
		facing_right = PC.player_instance == null or PC.player_instance.sprite_direction_right
	else:
		facing_right = direction.x > 0.0
	target_direction = Vector2.RIGHT if facing_right else Vector2.LEFT
	rotation = 0.0
	_apply_attack_transform()

func _physics_process(_delta: float) -> void:
	if not damage_active:
		return
	if PC.player_instance == null:
		return
	global_position = PC.player_instance.global_position
	rotation = 0.0
	_apply_damage(cached_attack_data)

func _apply_damage(attack_data: Dictionary) -> void:
	for area in get_overlapping_areas():
		if not (area.is_in_group("enemies") or area.is_in_group("boss")):
			continue
		var area_id := area.get_instance_id()
		if hit_targets.has(area_id):
			continue
		hit_targets[area_id] = true
		var damage := float(attack_data.get("damage", 0.0))
		var deep_base_damage := float(attack_data.get("deep_base_damage", damage))
		var is_vulnerable := _has_debuff(area, "vulnerable")
		if is_vulnerable:
			damage *= 1.0 + float(attack_data.get("vulnerable_damage_bonus", 0.0))
		if area.is_in_group("boss"):
			damage *= BOSS_DAMAGE_MULTIPLIER
		var is_crit := false
		if randf() < PC.crit_chance:
			is_crit = true
			damage *= PC.crit_damage_multi
		area.take_damage(int(round(damage)), is_crit, false, "zhuazhuajuchui")
		if bool(attack_data.get("apply_vulnerable", false)):
			_add_debuff(area, "vulnerable", VULNERABLE_DURATION)
		var knockback := float(attack_data.get("knockback", 0.0))
		if is_vulnerable:
			knockback += float(attack_data.get("vulnerable_knockback_bonus", 0.0))
		var is_boss := area.is_in_group("boss")
		if is_boss:
			Faze.apply_deep_displacement_damage(area, deep_base_damage, knockback, "zhuazhuajuchui")
		else:
			_apply_knockback(area, knockback)
			Faze.apply_deep_displacement_damage(area, deep_base_damage, knockback, "zhuazhuajuchui")
		HitParticleSpawner.spawn_by_weapon(get_tree(), area.global_position, "zhuazhuajuchui")

func _apply_knockback(target: Node2D, knockback: float) -> void:
	if knockback <= 0.0 or target == null or not target.has_method("apply_knockback"):
		return
	var direction := (target.global_position - global_position).normalized()
	if direction == Vector2.ZERO:
		direction = target_direction
	target.apply_knockback(direction, knockback)

func _has_debuff(target: Node, debuff_id: String) -> bool:
	return target.get("debuff_manager") and target.debuff_manager.has_method("has_debuff") and target.debuff_manager.has_debuff(debuff_id)

func _add_debuff(target: Node, debuff_id: String, duration: float) -> void:
	if target.get("debuff_manager") and target.debuff_manager.has_method("add_debuff"):
		target.debuff_manager.add_debuff(debuff_id, 0, duration)
