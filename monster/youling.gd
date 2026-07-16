extends "res://Script/monster/monster_base.gd"

const POISON_SCENE: PackedScene = preload("res://Scenes/moster/poison.tscn")
const SECTOR_TRIGGER_DISTANCE: float = 60.0
const SECTOR_RANGE: float = 80.0
const SECTOR_ANGLE_DEGREES: float = 45.0
const SECTOR_WARNING_TIME: float = 1.1
const SECTOR_POST_CAST_MOVE_LOCK_TIME: float = 0.3
const SECTOR_COOLDOWN: float = 4.0
const POISON_DEFAULT_DIRECTION: Vector2 = Vector2.DOWN
const POISON_VISUAL_SCALE: float = 1.7
const SWORD_WAVE_DAMAGE_INTERVAL: float = 0.25
const FLOAT_AMPLITUDE: float = 8.0
const FLOAT_SPEED: float = 3.0

@onready var sprite = $AnimatedSprite2D

var move_direction: int = 2
var base_speed: float = SettingMoster.youling("speed")
var speed: float
var hpMax: float = SettingMoster.youling("hp")
var hp: float = SettingMoster.youling("hp")
var atk: float = SettingMoster.youling("atk")
var get_point: int = SettingMoster.youling("point")
var get_exp: int = SettingMoster.youling("exp")
var last_sword_wave_damage_time: float = 0.0
var sector_cooldown_remaining: float = 0.0
var sector_warning_active: bool = false
var sector_post_cast_lock_remaining: float = 0.0
var active_sector_warning: WarnSectorUtil = null
var sprite_base_position: Vector2 = Vector2.ZERO
var float_phase: float = 0.0


func _ready() -> void:
	setup_monster_base(is_elite)
	speed = base_speed
	health_bar_offset = Vector2(-15, -20)
	sprite_base_position = sprite.position
	float_phase = randf() * TAU
	CharacterEffects.create_shadow(self, 24.0, 7.0, 13.0)


func _physics_process(delta: float) -> void:
	if hp <= 0:
		await _handle_death()
		return
	if not is_dead:
		_update_float_animation(delta)

	update_offscreen_status()
	if not _is_offscreen and hp < hpMax:
		show_health_bar()

	if should_skip_actions_for_debuff():
		return
	if is_corrupted_elite_charge_motion_locked():
		return

	_update_sector_skill(delta)

	if sector_warning_active:
		return
	if sector_post_cast_lock_remaining > 0.0:
		sector_post_cast_lock_remaining = maxf(0.0, sector_post_cast_lock_remaining - delta)
		return

	if not is_dead and not _is_offscreen:
		CharacterEffects.apply_separation(self, 10.0, 12.0)

	if not is_dead:
		_update_movement(delta)


func _update_float_animation(delta: float) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	float_phase += delta * FLOAT_SPEED
	sprite.position = sprite_base_position + Vector2(0.0, sin(float_phase) * FLOAT_AMPLITUDE)


func _handle_death() -> void:
	free_health_bar()
	if is_dead:
		return
	_cleanup_sector_warning()
	$AnimatedSprite2D.stop()
	$AnimatedSprite2D.play("death")
	var point_gain := int(get_point * Faze.get_point_multiplier())
	grant_kill_point_rewards(point_gain)
	var exp_gain := int(get_exp * Faze.get_exp_multiplier())
	Global.emit_signal("drop_exp_orb", exp_gain, global_position, is_elite)
	if PC.selected_rewards.has("SplitSwordQi13") and randf() <= 0.05:
		Global.emit_signal("_fire_ring_bullets")
	$death.play()
	Global.emit_signal("monster_killed")
	is_dead = true
	remove_from_group("enemies")
	$AnimatedSprite2D.modulate = Color(1, 1, 1, 1)
	$AnimatedSprite2D.material = null
	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		collision_shape.disabled = true
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	var shadow := get_node_or_null("Shadow")
	if shadow:
		shadow.visible = false
	var itemdrop = SettingMoster.youling("itemdrop")
	if typeof(itemdrop) == TYPE_DICTIONARY:
		drop_items_from_table(itemdrop)
	await get_tree().create_timer(0.35).timeout
	queue_free()


func _update_movement(delta: float) -> void:
	if hp > 0 and CharacterEffects.is_player_dead_or_game_over():
		move_away_from_dead_player(delta, base_speed, sprite)
		return
	if move_direction == 0:
		position += CharacterEffects.apply_soft_separation_to_direction(self, Vector2.RIGHT) * speed * delta
		if not _is_offscreen:
			CharacterEffects.set_enemy_flip_h(self, sprite, false)
	elif move_direction == 1:
		position += CharacterEffects.apply_soft_separation_to_direction(self, Vector2.LEFT) * speed * delta
		if not _is_offscreen:
			CharacterEffects.set_enemy_flip_h(self, sprite, true)
	else:
		if PC.player_instance != null:
			var direction_to_player := CharacterEffects.get_tracking_direction_to_player(self)
			if direction_to_player != Vector2.ZERO:
				speed = get_effective_move_speed(base_speed)
				position += direction_to_player * speed * delta
				if not _is_offscreen:
					CharacterEffects.face_player_x(self, sprite, false)


func _update_sector_skill(delta: float) -> void:
	if sector_cooldown_remaining > 0.0:
		sector_cooldown_remaining = maxf(0.0, sector_cooldown_remaining - delta)
	if sector_cooldown_remaining > 0.0 or sector_warning_active:
		return
	if PC.player_instance == null or CharacterEffects.is_player_dead_or_game_over():
		return
	var to_player: Vector2 = PC.player_instance.global_position - global_position
	if to_player.length() > SECTOR_TRIGGER_DISTANCE or to_player.length_squared() <= 0.001:
		return
	_cast_sector_skill(to_player.normalized())


func _cast_sector_skill(direction: Vector2) -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	sector_warning_active = true
	sector_cooldown_remaining = SECTOR_COOLDOWN
	var warning := WarnSectorUtil.new()
	active_sector_warning = warning
	get_tree().current_scene.add_child(warning)
	warning.attacker = self
	warning.player_ref = PC.player_instance
	warning.warning_finished.connect(Callable(self, "_on_sector_warning_finished").bind(warning, direction), CONNECT_ONE_SHOT)
	warning.start_warning(
		global_position,
		global_position + direction * SECTOR_RANGE,
		SECTOR_ANGLE_DEGREES,
		SECTOR_WARNING_TIME,
		atk,
		"幽灵毒雾",
		null,
		0.18
	)


func _on_sector_warning_finished(warning: WarnSectorUtil, direction: Vector2) -> void:
	sector_warning_active = false
	sector_post_cast_lock_remaining = SECTOR_POST_CAST_MOVE_LOCK_TIME
	if warning == active_sector_warning:
		active_sector_warning = null
	if not is_dead and is_inside_tree():
		_spawn_poison_visual(direction)
		if is_corrupted_elite_monster():
			fire_corrupted_radial_bullet_ring(8)
	if is_instance_valid(warning):
		warning.queue_free()


func _spawn_poison_visual(direction: Vector2) -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	var poison := POISON_SCENE.instantiate() as Node2D
	if poison == null:
		return
	get_tree().current_scene.add_child(poison)
	var attack_direction := direction.normalized()
	poison.global_position = global_position + attack_direction * (SECTOR_RANGE * 0.5)
	poison.global_rotation = _get_poison_visual_rotation(attack_direction)
	poison.scale = Vector2.ONE * POISON_VISUAL_SCALE
	var poison_sprite := poison.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if poison_sprite != null:
		poison_sprite.play("default")
	get_tree().create_timer(1.0).timeout.connect(Callable(poison, "queue_free"), CONNECT_ONE_SHOT)


func _get_poison_visual_rotation(direction: Vector2) -> float:
	if direction.length_squared() <= 0.001:
		return 0.0
	return direction.angle() - POISON_DEFAULT_DIRECTION.angle()


func _cleanup_sector_warning() -> void:
	sector_warning_active = false
	sector_post_cast_lock_remaining = 0.0
	if active_sector_warning != null and is_instance_valid(active_sector_warning):
		active_sector_warning.cleanup()
	active_sector_warning = null


func take_damage(damage: int, is_crit: bool, is_summon: bool, damage_type: String) -> void:
	if damage_type == "sword_wave":
		var time_scale := 0.5 if PC.selected_rewards.has("SplitSwordQi22") else 1.0
		if not can_apply_interval_damage("last_sword_wave_damage_time", SWORD_WAVE_DAMAGE_INTERVAL, time_scale):
			return
		apply_common_take_damage(damage, is_crit, is_summon, damage_type, {"show_damage_popup": false})
		return
	apply_common_take_damage(damage, is_crit, is_summon, damage_type)


func _on_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	if area.is_in_group("bullet") and area.has_method("get_bullet_damage_and_crit_status"):
		var collision_result = BulletCalculator.handle_bullet_collision_full(area, self, false)
		if collision_result["should_delete_bullet"]:
			area.queue_free()
		var base_bullet_damage = collision_result["final_damage"]
		var final_damage_val := get_common_bullet_damage_value(base_bullet_damage)
		var is_crit = collision_result["is_crit"]
		if collision_result["should_rebound"]:
			area.call_deferred("create_rebound")
		hp -= int(final_damage_val)
		if hp <= 0:
			if not is_dead:
				$AnimatedSprite2D.play("death")
		else:
			Global.play_hit_anime(position, is_crit)


func _on_body_entered(body: Node2D) -> void:
	handle_common_body_entered(body)


func _exit_tree() -> void:
	_cleanup_sector_warning()
