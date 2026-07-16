extends Node2D
class_name ThunderGun

const BASE_DAMAGE_RATIO: float = 0.65
const BOSS_DAMAGE_MULTIPLIER: float = 1.40
const BASE_RANGE: float = 150.0
const CHAIN_DAMAGE_FACTOR: float = 0.40
const SPLASH_DAMAGE_FACTOR: float = 0.30
const SPLASH_DAMAGE_FACTOR_ADVANCED: float = 0.40
const BOSS_CRIT_DAMAGE_BONUS: float = 0.70

@onready var gun_sprite: AnimatedSprite2D = $gun
@onready var aoe_sprite: AnimatedSprite2D = $aoe
@onready var aoe_area: Area2D = $aoe/Area2D
@onready var aoe_collision_shape: CollisionShape2D = $aoe/Area2D/CollisionShape2D

var _hit_targets: Dictionary = {}
var _base_gun_scale: Vector2 = Vector2.ONE
var _gun_frame_height: float = 96.0
var _base_aoe_scale: Vector2 = Vector2.ONE
var _base_collision_scale: Vector2 = Vector2.ONE
var _custom_damage_multiplier: float = 1.0

static func reset_data() -> void:
	PC.main_skill_thunder_gun_damage = BASE_DAMAGE_RATIO
	PC.thunder_gun_ammo = 0
	PC.thunder_gun_reloading = false

static func has_valid_target(tree: SceneTree, from_position: Vector2) -> bool:
	return _find_nearest_target_static(tree, from_position, BASE_RANGE * Global.get_attack_range_multiplier(), {}) != null

static func _find_nearest_target_static(tree: SceneTree, from_position: Vector2, max_range: float, excluded: Dictionary) -> Node2D:
	if tree == null:
		return null
	var candidates: Array = []
	candidates.append_array(tree.get_nodes_in_group("enemies"))
	candidates.append_array(tree.get_nodes_in_group("boss"))
	var best: Node2D = null
	var best_distance := INF
	for candidate in candidates:
		if not (candidate is Node2D):
			continue
		if excluded.has(candidate.get_instance_id()):
			continue
		if bool(candidate.get("is_dead")):
			continue
		var distance := from_position.distance_to(candidate.global_position)
		if distance <= max_range and distance < best_distance:
			best = candidate
			best_distance = distance
	return best

func set_custom_damage_multiplier(value: float) -> void:
	_custom_damage_multiplier = maxf(0.0, value)

func _ready() -> void:
	if gun_sprite:
		_base_gun_scale = gun_sprite.scale
		var frame_texture := gun_sprite.sprite_frames.get_frame_texture(&"default", 0) if gun_sprite.sprite_frames else null
		if frame_texture:
			_gun_frame_height = maxf(1.0, float(frame_texture.get_height()))
	_base_aoe_scale = aoe_sprite.scale if aoe_sprite else Vector2.ONE
	_base_collision_scale = aoe_collision_shape.scale if aoe_collision_shape else Vector2.ONE
	if aoe_sprite:
		aoe_sprite.visible = false
	if aoe_area:
		aoe_area.monitoring = false
	call_deferred("_fire")

func _fire() -> void:
	if PC.player_instance == null:
		queue_free()
		return
	global_position = PC.player_instance.global_position
	var target := _find_nearest_target(global_position, _get_lock_range(), {})
	if target == null:
		queue_free()
		return
	_play_gun(target)
	var primary_result := _apply_hit(target, _get_base_damage(), true)
	var excluded := {target.get_instance_id(): true}
	var chain_count := _get_chain_count(primary_result.get("is_crit", false))
	var chain_origin: Vector2 = target.global_position
	for _i in range(chain_count):
		var next_target := _find_nearest_target(chain_origin, _get_lock_range(), excluded)
		if next_target == null:
			break
		excluded[next_target.get_instance_id()] = true
		_apply_hit(next_target, _get_base_damage() * CHAIN_DAMAGE_FACTOR, true)
		chain_origin = next_target.global_position
	await get_tree().create_timer(0.35, false).timeout
	queue_free()

func _get_lock_range() -> float:
	return BASE_RANGE * Global.get_attack_range_multiplier()

func _get_base_damage() -> float:
	var damage := float(PC.pc_atk) * PC.main_skill_thunder_gun_damage * _custom_damage_multiplier
	damage = PC.apply_base_weapon_emblem_damage_bonus(damage, "thunder_gun")
	return damage

func _get_crit_chance() -> float:
	var chance := PC.crit_chance
	if PC.selected_rewards.has("ThunderGun1"):
		chance += 0.10
	if PC.selected_rewards.has("ThunderGun4"):
		chance += 0.05
	if PC.selected_rewards.has("ThunderGun33"):
		chance += 0.05
	return chance

func _get_chain_count(primary_crit: bool) -> int:
	var count := 1
	if PC.selected_rewards.has("ThunderGun2"):
		count += 1
	if primary_crit and PC.selected_rewards.has("ThunderGun33"):
		count += 1
	return count

func _get_extra_spirit() -> int:
	if PC.selected_rewards.has("ThunderGun22"):
		return 6
	if PC.selected_rewards.has("ThunderGun2"):
		return 3
	return 0

func _find_nearest_target(from_position: Vector2, max_range: float, excluded: Dictionary) -> Node2D:
	return _find_nearest_target_static(get_tree(), from_position, max_range, excluded)

func _apply_hit(target: Node, raw_damage: float, can_splash: bool) -> Dictionary:
	var final_damage := raw_damage
	if target.is_in_group("boss"):
		final_damage *= BOSS_DAMAGE_MULTIPLIER
	var is_crit := randf() < _get_crit_chance()
	if is_crit:
		var crit_multi := PC.crit_damage_multi
		if target.is_in_group("boss") and PC.selected_rewards.has("ThunderGun33"):
			crit_multi += BOSS_CRIT_DAMAGE_BONUS
		final_damage *= crit_multi
	var hp_before := _get_target_hp(target)
	target.take_damage(int(round(final_damage)), is_crit, false, "thunder_gun")
	HitParticleSpawner.spawn_by_weapon(get_tree(), target.global_position, "thunder_gun")
	Faze.on_thunder_weapon_hit(target)
	if _get_extra_spirit() > 0 and hp_before > 0.0 and _get_target_hp(target) <= 0.0:
		target.set_meta("weapon_extra_spirit", max(int(target.get_meta("weapon_extra_spirit", 0)), _get_extra_spirit()))
	if can_splash:
		_apply_splash(target.global_position, raw_damage * _get_splash_damage_factor(), target.get_instance_id())
	return {"is_crit": is_crit, "damage": final_damage}

func _get_splash_damage_factor() -> float:
	if PC.selected_rewards.has("ThunderGun1"):
		return SPLASH_DAMAGE_FACTOR_ADVANCED
	return SPLASH_DAMAGE_FACTOR

func _apply_splash(center: Vector2, splash_damage: float, source_id: int) -> void:
	if aoe_sprite == null or aoe_area == null:
		return
	var splash_sprite := aoe_sprite.duplicate() as AnimatedSprite2D
	var splash_area := splash_sprite.get_node_or_null("Area2D") as Area2D
	var splash_collision := splash_sprite.get_node_or_null("Area2D/CollisionShape2D") as CollisionShape2D
	if splash_area == null:
		splash_sprite.queue_free()
		return
	CharacterEffects.include_enemy_collision_mask(splash_area)
	get_tree().current_scene.add_child(splash_sprite)
	splash_sprite.global_position = center
	_apply_aoe_scale(splash_sprite, splash_collision)
	splash_sprite.visible = true
	splash_sprite.play("default")
	splash_area.monitoring = true
	await get_tree().physics_frame
	var bodies := splash_area.get_overlapping_areas()
	for area in bodies:
		if not (area.is_in_group("enemies") or area.is_in_group("boss")):
			continue
		if area.get_instance_id() == source_id:
			continue
		if _hit_targets.has(area.get_instance_id()):
			continue
		_hit_targets[area.get_instance_id()] = true
		var damage := splash_damage
		if area.is_in_group("boss"):
			damage *= BOSS_DAMAGE_MULTIPLIER
		var is_crit := randf() < _get_crit_chance()
		if is_crit:
			damage *= PC.crit_damage_multi
		var hp_before := _get_target_hp(area)
		area.take_damage(int(round(damage)), is_crit, false, "thunder_gun")
		HitParticleSpawner.spawn_by_weapon(get_tree(), area.global_position, "thunder_gun")
		if _get_extra_spirit() > 0 and hp_before > 0.0 and _get_target_hp(area) <= 0.0:
			area.set_meta("weapon_extra_spirit", max(int(area.get_meta("weapon_extra_spirit", 0)), _get_extra_spirit()))
	await get_tree().create_timer(0.25, false).timeout
	if is_instance_valid(splash_sprite):
		splash_sprite.queue_free()

func _apply_aoe_scale(target_sprite: AnimatedSprite2D = null, target_collision_shape: CollisionShape2D = null) -> void:
	var scale_multiplier := Global.get_attack_range_multiplier()
	if PC.selected_rewards.has("ThunderGun22"):
		scale_multiplier *= 1.3
	var sprite := target_sprite if target_sprite != null else aoe_sprite
	var collision_shape := target_collision_shape if target_collision_shape != null else aoe_collision_shape
	if sprite:
		sprite.scale = _base_aoe_scale * scale_multiplier
	if collision_shape:
		collision_shape.scale = _base_collision_scale * scale_multiplier

func _play_gun(target: Node2D) -> void:
	if gun_sprite == null:
		return
	var direction := target.global_position - global_position
	var distance := maxf(1.0, direction.length())
	gun_sprite.global_position = global_position + direction * 0.5
	gun_sprite.rotation = direction.angle() - PI * 0.5
	gun_sprite.scale = Vector2(_base_gun_scale.x, _base_gun_scale.y * distance / _gun_frame_height)
	gun_sprite.play("default")

func _get_target_hp(target: Node) -> float:
	if target == null:
		return 0.0
	var value = target.get("hp")
	if value == null:
		return 0.0
	return float(value)
