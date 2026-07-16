extends Area2D
class_name SoulSickle

@export var sprite: Sprite2D
@export var collision_shape: CollisionShape2D
@export var search_radius: float = 420.0

const BASE_DAMAGE_RATIO: float = 0.30
const BOSS_DAMAGE_MULTIPLIER: float = 2.0
const BASE_KNOCKBACK: float = 8.0
const SPEED: float = 91.0
const LIFE_TIME: float = 3.0
const FADE_OUT_TIME: float = 0.55
const PULL_FADE_OUT_TIME: float = 0.3
const MOTION_FRAME_RATE: float = 12.0
const PULL_SPEED: float = 225.0
const PULL_SPAWN_FLIGHT_TIME: float = 2.1
const PULL_DISTANCE: float = PULL_SPEED * PULL_SPAWN_FLIGHT_TIME
const PULL_LIFE_TIME: float = 1.8
const PULL_TOUCH_DISTANCE: float = 12.0
const OUTLINE_SCALE_MULTIPLIER: float = 1.1
const BASE_HEAL: float = 10.0
const HEAL_MAX_HP_RATIO: float = 0.005

static func reset_data() -> void:
	PC.main_skill_soul_sickle_damage = BASE_DAMAGE_RATIO

var direction: Vector2 = Vector2.RIGHT
var elapsed: float = 0.0
var motion_elapsed: float = 0.0
var motion_step_accumulator: float = 0.0
var base_sprite_scale: Vector2 = Vector2.ONE
var base_collision_scale: Vector2 = Vector2.ONE
var outline_sprite: Sprite2D = null
var start_scale_multiplier: float = 1.0
var end_scale_multiplier: float = 2.0
var damage: float = 0.0
var knockback_min: float = BASE_KNOCKBACK
var knockback_max: float = BASE_KNOCKBACK
var pull_mode: bool = false
var heal_limit: int = 4
var boss_heal_multiplier: float = 1.0
var heal_count: int = 0
var hit_targets: Dictionary = {}
var spirit_on_hit_kill: int = 0
var spirit_on_hit_defeated: int = 0
var custom_damage_multiplier: float = 1.0
var fading_out: bool = false
var fade_elapsed: float = 0.0
var fade_start_alpha: float = 1.0

func set_custom_damage_multiplier(value: float) -> void:
	custom_damage_multiplier = max(0.0, value)

func _ready() -> void:
	CharacterEffects.include_enemy_collision_mask(self)
	base_sprite_scale = sprite.scale if sprite != null else Vector2.ONE
	base_collision_scale = collision_shape.scale if collision_shape != null else Vector2.ONE
	_setup_outline_sprite()
	_build_data()
	var player := PC.player_instance as Node2D
	if player == null:
		queue_free()
		return
	var target_center := _find_most_dense_center(player.global_position)
	var to_target := target_center - player.global_position
	if to_target.length_squared() <= 0.001:
		to_target = Vector2.RIGHT if player.get("sprite_direction_right") else Vector2.LEFT
	direction = to_target.normalized()
	if pull_mode:
		global_position = player.global_position + direction * PULL_DISTANCE
		direction = -direction
	else:
		global_position = player.global_position
	rotation = direction.angle()
	_apply_scale(end_scale_multiplier if pull_mode else start_scale_multiplier)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", false)

func _physics_process(delta: float) -> void:
	if PC.is_game_over:
		queue_free()
		return
	elapsed += delta
	if fading_out:
		fade_elapsed += delta
		var fade_time := _get_fade_out_time()
		_set_visual_alpha(lerpf(fade_start_alpha, 0.0, clampf(fade_elapsed / fade_time, 0.0, 1.0)))
		if fade_elapsed >= fade_time:
			queue_free()
		return
	var max_life := PULL_LIFE_TIME if pull_mode else LIFE_TIME
	motion_step_accumulator += delta
	var motion_step := 1.0 / MOTION_FRAME_RATE
	var move_speed := PULL_SPEED if pull_mode else SPEED
	while motion_step_accumulator >= motion_step:
		motion_step_accumulator -= motion_step
		motion_elapsed = minf(motion_elapsed + motion_step, max_life)
		global_position += direction * move_speed * motion_step
		if not pull_mode:
			var t := clampf(motion_elapsed / LIFE_TIME, 0.0, 1.0)
			_apply_scale(lerpf(start_scale_multiplier, end_scale_multiplier, t))
	var visual_alpha := 0.85 + sin(elapsed * TAU * 3.0) * 0.15
	if not pull_mode and LIFE_TIME - elapsed <= FADE_OUT_TIME:
		visual_alpha *= clampf((LIFE_TIME - elapsed) / FADE_OUT_TIME, 0.0, 1.0)
	_set_visual_alpha(visual_alpha)
	_apply_hits()
	if elapsed >= max_life or (pull_mode and _is_touching_player()):
		_start_fade_out()

func _start_fade_out() -> void:
	if fading_out:
		return
	fading_out = true
	fade_elapsed = 0.0
	fade_start_alpha = sprite.modulate.a if sprite != null else 1.0
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

func _get_fade_out_time() -> float:
	return PULL_FADE_OUT_TIME if pull_mode else FADE_OUT_TIME

func _setup_outline_sprite() -> void:
	if sprite == null or outline_sprite != null:
		return
	outline_sprite = sprite.duplicate() as Sprite2D
	if outline_sprite == null:
		return
	outline_sprite.name = "OutlineSprite2D"
	outline_sprite.z_index = sprite.z_index - 1
	outline_sprite.modulate = Color(0.9, 0.82, 1.0, 0.65)
	add_child(outline_sprite)

func _set_visual_alpha(value: float) -> void:
	var alpha := clampf(value, 0.0, 1.0)
	if sprite != null:
		sprite.modulate.a = alpha
	if outline_sprite != null:
		outline_sprite.modulate.a = alpha * 0.7

func _build_data() -> void:
	var damage_ratio := PC.main_skill_soul_sickle_damage
	knockback_min = BASE_KNOCKBACK
	knockback_max = BASE_KNOCKBACK
	heal_limit = 4
	boss_heal_multiplier = 1.0
	start_scale_multiplier = 1.15
	end_scale_multiplier = 2.3
	pull_mode = false
	spirit_on_hit_kill = 0
	spirit_on_hit_defeated = 0
	if PC.selected_rewards.has("SoulSickle1"):
		pass
	if PC.selected_rewards.has("SoulSickle2"):
		start_scale_multiplier *= 1.15
		end_scale_multiplier *= 1.15
	if PC.selected_rewards.has("SoulSickle3"):
		pull_mode = true
		knockback_min = 4.0
		knockback_max = 50.0
	if PC.selected_rewards.has("SoulSickle4"):
		spirit_on_hit_defeated = 3
	if PC.selected_rewards.has("SoulSickle11"):
		heal_limit = 6
		boss_heal_multiplier = 4.0
	if PC.selected_rewards.has("SoulSickle22"):
		spirit_on_hit_kill = 6
	if PC.selected_rewards.has("SoulSickle33"):
		start_scale_multiplier *= 1.15
		end_scale_multiplier *= 1.15
		spirit_on_hit_defeated = max(spirit_on_hit_defeated, 5)
	damage = float(PC.pc_atk) * damage_ratio * custom_damage_multiplier
	damage = PC.apply_base_weapon_emblem_damage_bonus(damage, "soul_sickle")

func _apply_scale(value: float) -> void:
	var range_multiplier := Global.get_attack_range_multiplier()
	if sprite != null:
		sprite.scale = base_sprite_scale * value * range_multiplier
	if outline_sprite != null:
		outline_sprite.scale = base_sprite_scale * value * range_multiplier * OUTLINE_SCALE_MULTIPLIER
	if collision_shape != null:
		collision_shape.scale = base_collision_scale * value * range_multiplier

func _is_touching_player() -> bool:
	if not pull_mode or PC.player_instance == null:
		return false
	var player_position: Vector2 = PC.player_instance.global_position
	var player_radius := PULL_TOUCH_DISTANCE
	var hitbox_info := PC.get_player_hitbox_info()
	if not hitbox_info.is_empty() and hitbox_info.get("type") == "circle":
		player_position = hitbox_info.get("position", player_position)
		player_radius = float(hitbox_info.get("radius", player_radius))
	return global_position.distance_to(player_position) <= player_radius + PULL_TOUCH_DISTANCE

func _find_most_dense_center(player_position: Vector2) -> Vector2:
	var candidates: Array = []
	candidates.append_array(get_tree().get_nodes_in_group("enemies"))
	candidates.append_array(get_tree().get_nodes_in_group("boss"))
	var valid: Array[Node2D] = []
	for candidate in candidates:
		if candidate is Node2D and player_position.distance_to(candidate.global_position) <= search_radius * Global.get_attack_range_multiplier():
			valid.append(candidate)
	if valid.is_empty():
		return player_position + Vector2.RIGHT
	var best_count := 0
	var best_center := valid[0].global_position
	for enemy in valid:
		var count := 0
		var sum := Vector2.ZERO
		for other in valid:
			if enemy.global_position.distance_to(other.global_position) <= 90.0 * Global.get_attack_range_multiplier():
				count += 1
				sum += other.global_position
		if count > best_count:
			best_count = count
			best_center = sum / float(count)
	return best_center

func _apply_hits() -> void:
	for area in get_overlapping_areas():
		if not (area.is_in_group("enemies") or area.is_in_group("boss")):
			continue
		var area_id := area.get_instance_id()
		if hit_targets.has(area_id):
			continue
		hit_targets[area_id] = true
		var final_damage := damage
		if area.is_in_group("boss"):
			final_damage *= BOSS_DAMAGE_MULTIPLIER
		var is_crit := false
		if randf() < PC.crit_chance:
			is_crit = true
			final_damage *= PC.crit_damage_multi
		var hp_before := _get_target_hp(area)
		area.take_damage(int(round(final_damage)), is_crit, false, "soul_sickle")
		_apply_soul_sickle_heal(area)
		var knockback := _get_knockback_for_target(area)
		if pull_mode:
			_apply_knockback_toward_player(area, knockback)
		else:
			_apply_knockback(area, knockback)
		Faze.apply_deep_displacement_damage(area, damage, knockback, "soul_sickle")
		if spirit_on_hit_defeated > 0:
			area.set_meta("soul_sickle_extra_spirit", max(int(area.get_meta("soul_sickle_extra_spirit", 0)), spirit_on_hit_defeated))
		if spirit_on_hit_kill > 0 and hp_before > 0.0 and _get_target_hp(area) <= 0.0:
			area.set_meta("soul_sickle_extra_spirit", max(int(area.get_meta("soul_sickle_extra_spirit", 0)), spirit_on_hit_kill))
		HitParticleSpawner.spawn_by_weapon(get_tree(), area.global_position, "soul_sickle")

func _apply_soul_sickle_heal(target: Node) -> void:
	if heal_count >= heal_limit:
		return
	heal_count += 1
	var heal_amount := BASE_HEAL + float(PC.pc_max_hp) * HEAL_MAX_HP_RATIO
	if target != null and target.is_in_group("boss"):
		heal_amount *= boss_heal_multiplier
	heal_amount *= (1.0 + PC.heal_multi) * Global.get_heal_shield_effect_multiplier()
	var actual_heal := int(round(minf(heal_amount, float(PC.pc_max_hp - PC.pc_hp))))
	if actual_heal <= 0:
		return
	PC.pc_hp = mini(PC.pc_hp + actual_heal, PC.pc_max_hp)
	Global.emit_signal("player_heal", float(actual_heal), PC.player_instance.global_position, "soul_sickle")
	Global.emit_signal("player_healed", float(actual_heal))

func _get_knockback_for_target(target: Node2D) -> float:
	var knockback := knockback_min
	if pull_mode and PC.player_instance != null:
		var distance: float = PC.player_instance.global_position.distance_to(target.global_position)
		var t := clampf(distance / 360.0, 0.0, 1.0)
		knockback = lerpf(knockback_min, knockback_max, t)
	knockback *= Faze.get_deep_knockback_multiplier(PC.faze_deep_level)
	knockback *= PC.get_knockback_multiplier()
	return knockback

func _apply_knockback(target: Node2D, knockback: float) -> void:
	if knockback <= 0.0 or target == null or target.is_in_group("boss") or not target.has_method("apply_knockback"):
		return
	var push_direction := (target.global_position - global_position).normalized()
	if push_direction == Vector2.ZERO:
		push_direction = direction
	target.apply_knockback(push_direction, knockback)

func _apply_knockback_toward_player(target: Node2D, force: float) -> void:
	if force <= 0.0 or target == null or target.is_in_group("boss") or not target.has_method("apply_knockback") or PC.player_instance == null:
		return
	var player_position: Vector2 = PC.player_instance.global_position
	var knockback_direction: Vector2 = (player_position - target.global_position).normalized()
	if knockback_direction == Vector2.ZERO:
		knockback_direction = (player_position - global_position).normalized()
	if knockback_direction == Vector2.ZERO:
		knockback_direction = direction
	target.apply_knockback(knockback_direction, force)

func _get_target_hp(target: Node) -> float:
	if target == null:
		return 0.0
	var value = target.get("hp")
	if value == null:
		return 1.0
	return float(value)
