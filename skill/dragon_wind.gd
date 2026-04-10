extends Area2D
class_name DragonWind

@export var sprite: AnimatedSprite2D
@export var collision: CollisionShape2D

static var dragonwind_base_damage: float = 0.9
static var dragonwind_final_damage_multi: float = 1.0
static var dragonwind_range: float = 180.0
static var dragonwind_range_scale: float = 1.0
static var dragonwind_pull_force: float = 40.0
static var dragonwind_center_bonus_ratio: float = 0.0
static var dragonwind_slow_duration: float = 0.0
static var dragonwind_slow_damage_bonus: float = 0.0
static var dragonwind_boss_bonus_ratio: float = 0.0

var base_sprite_scale: Vector2 = Vector2.ONE
var base_collision_scale: Vector2 = Vector2.ONE
var base_sprite_alpha: float = 1.0
var base_sprite_color: Color = Color(1, 1, 1, 1)
var fade_in_time: float = 0.3
var fade_sustain_time: float = 2.5
var fade_out_time: float = 0.8

static func reset_data() -> void:
	dragonwind_base_damage = 0.9
	dragonwind_final_damage_multi = 1.0
	dragonwind_range = 200.0
	dragonwind_range_scale = 1.0
	dragonwind_pull_force = 40.0
	dragonwind_center_bonus_ratio = 0.0
	dragonwind_slow_duration = 0.0
	dragonwind_slow_damage_bonus = 0.0
	dragonwind_boss_bonus_ratio = 0.0

static func fire_skill(scene: PackedScene, origin_pos: Vector2, tree: SceneTree) -> void:
	if not scene or not tree:
		return
	var instance = scene.instantiate()
	tree.current_scene.add_child(instance)
	var target_pos = instance._find_cluster_center(origin_pos)
	instance.global_position = target_pos
	instance._setup_instance()

func _ready() -> void:
	monitoring = true
	monitorable = true
	base_sprite_scale = sprite.scale
	base_sprite_color = sprite.modulate
	base_sprite_alpha = base_sprite_color.a
	sprite.play()
	base_collision_scale = collision.scale
	_apply_range_scale()
	_reset_fade_state()
	_start_fade()

func _setup_instance() -> void:
	call_deferred("_apply_effects")

func _apply_range_scale() -> void:
	var scale_value = dragonwind_range_scale
	base_sprite_scale = base_sprite_scale * scale_value
	sprite.scale = base_sprite_scale
	base_collision_scale = base_collision_scale * scale_value
	collision.scale = base_collision_scale

func _find_cluster_center(player_position: Vector2) -> Vector2:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return player_position
	var candidates: Array = []
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if player_position.distance_to(enemy.global_position) <= dragonwind_range:
			candidates.append(enemy)
	if candidates.is_empty():
		return player_position
	var best_count = 0
	var best_center = player_position
	var cluster_radius = min(80.0, dragonwind_range * 0.4)
	for enemy in candidates:
		var center = enemy.global_position
		var count = 0
		var sum_position = Vector2.ZERO
		for other in candidates:
			var distance = center.distance_to(other.global_position)
			if distance <= cluster_radius:
				count += 1
				sum_position += other.global_position
		if count > best_count:
			best_count = count
			if count > 0:
				best_center = sum_position / float(count)
	return best_center

func _apply_effects() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var overlapping_areas = _collect_targets()
	var center_pos = global_position
	var center_radius = _get_effect_radius() * 0.35
	for area in overlapping_areas:
		var target = area
		if not target.is_in_group("enemies") and target.get_parent() and target.get_parent().is_in_group("enemies"):
			target = target.get_parent()
		if not target.is_in_group("enemies"):
			continue
		if not target.has_method("take_damage"):
			continue
		var final_damage = _calculate_damage(target, center_pos, center_radius)
		target.take_damage(int(final_damage), false, false, "dragonwind")
		_apply_pull(target, center_pos)
		_apply_slow(target)
		Faze.on_wind_weapon_hit()
	await get_tree().create_timer(_get_fade_total_time()).timeout
	queue_free()

func _reset_fade_state() -> void:
	sprite.modulate = Color(base_sprite_color.r, base_sprite_color.g, base_sprite_color.b, 0.0)
	sprite.scale = Vector2.ZERO

func _start_fade() -> void:
	var opaque_color = Color(base_sprite_color.r, base_sprite_color.g, base_sprite_color.b, base_sprite_alpha)
	var transparent_color = Color(base_sprite_color.r, base_sprite_color.g, base_sprite_color.b, 0.0)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", base_sprite_scale, fade_in_time)
	tween.tween_property(sprite, "modulate", opaque_color, fade_in_time)
	tween.set_parallel(false)
	tween.tween_interval(fade_sustain_time)
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate", transparent_color, fade_out_time)

func _get_fade_total_time() -> float:
	return fade_in_time + fade_sustain_time + fade_out_time

func _collect_targets() -> Array:
	var results: Array = get_overlapping_areas()
	if not results.is_empty():
		return results
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = _get_effect_radius()
	query.set_shape(circle_shape)
	query.transform = Transform2D(0, global_position)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 0x7fffffff
	var hits = space_state.intersect_shape(query)
	for hit in hits:
		if hit.has("collider"):
			results.append(hit.collider)
	return results

func _calculate_damage(target: Area2D, center_pos: Vector2, center_radius: float) -> float:
	var damage = PC.pc_atk * dragonwind_base_damage * dragonwind_final_damage_multi
	damage *= Faze.get_wind_weapon_damage_multiplier(PC.faze_wind_level)
	damage *= Faze.get_treasure_weapon_damage_multiplier(PC.faze_treasure_level, PC.lucky)
	var dist = center_pos.distance_to(target.global_position)
	if dist <= center_radius and dragonwind_center_bonus_ratio > 0.0:
		damage *= 1.0 + dragonwind_center_bonus_ratio
	if dragonwind_slow_damage_bonus > 0.0:
		if target.get("debuff_manager") and target.debuff_manager.has_debuff("slow"):
			damage *= 1.0 + dragonwind_slow_damage_bonus
	if target.is_in_group("elite") or target.is_in_group("boss"):
		damage *= Faze.get_wind_elite_boss_multiplier(PC.faze_wind_level, PC.wind_huanfeng_stacks)
		damage *= Faze.get_treasure_elite_boss_multiplier(PC.faze_treasure_level, PC.lucky)
	if target.is_in_group("boss") and dragonwind_boss_bonus_ratio > 0.0:
		damage *= 1.0 + dragonwind_boss_bonus_ratio
	return damage

func _apply_pull(target: Area2D, center_pos: Vector2) -> void:
	if dragonwind_pull_force <= 0:
		return
	if not target.has_method("apply_knockback"):
		return
	var offset = center_pos - target.global_position
	var distance = offset.length()
	if distance <= 0.001:
		return
	var direction = offset / distance
	var pull_force = dragonwind_pull_force * 0.5
	var effective_force = min(distance, pull_force)
	target.apply_knockback(direction, effective_force)

func _apply_slow(target: Area2D) -> void:
	if dragonwind_slow_duration <= 0.0:
		return
	if target.get("debuff_manager") and target.debuff_manager.has_method("add_debuff"):
		target.debuff_manager.add_debuff("slow")

func _get_effect_radius() -> float:
	if collision and collision.shape is CircleShape2D:
		var radius = collision.shape.radius
		return radius * collision.global_scale.x
	return dragonwind_range
