extends "res://Script/monster/monster_base.gd"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

enum State {SEEKING_PLAYER, WARNING, FIRING, FLEEING}

const ETHER_DROP_IDS: Array[String] = ["item_031", "item_032", "item_033", "item_034", "item_035"]
const ETHER_DROP_CHANCE: float = 0.03
const FRAGMENT_DROP_CHANCE: float = 0.20
const ATTACK_RANGE: float = 160.0
const IDEAL_DISTANCE: float = 130.0
const DISTANCE_TOLERANCE: float = 18.0
const ATTACK_WARNING_TIME: float = 1.2
const ATTACK_COOLDOWN: float = 6.0
const FLEE_DURATION: float = 1.8
const RAY_WIDTH: float = 80.0
const RAY_LENGTH: float = 800.0
const SWORD_WAVE_DAMAGE_INTERVAL: float = 0.25
const FACING_DEADZONE: float = 0.01
const ATTACK_BODY_WARNING_ALPHA: float = 0.8

var base_speed: float = SettingMoster.gu_insect("speed")
var speed: float
var hpMax: float = SettingMoster.gu_insect("hp")
var hp: float = SettingMoster.gu_insect("hp")
var atk: float = SettingMoster.gu_insect("atk")
var get_point: int = SettingMoster.gu_insect("point")
var get_exp: int = SettingMoster.gu_insect("exp")
var target_position: Vector2
var current_state: State = State.SEEKING_PLAYER
var action_timer: Timer
var attack_cooldown_timer: Timer
var flee_direction: Vector2 = Vector2.ZERO
var last_sword_wave_damage_time: float = 0.0
var attack_origin: Vector2 = Vector2.ZERO
var active_warning: Node2D = null
var attack_warning_overlay: AnimatedSprite2D = null
var attack_warning_tween: Tween = null

func _ready() -> void:
	set_meta("never_elite", true)
	add_to_group("non_elite_enemy")
	setup_monster_base(false)
	speed = base_speed
	health_bar_offset = Vector2(-15, -26)
	var shadow := CharacterEffects.create_shadow(self, 32.0, 8.0, 20.0)
	shadow.modulate = Color(0, 0, 0, 0.45)

	action_timer = Timer.new()
	action_timer.one_shot = true
	add_child(action_timer)

	attack_cooldown_timer = Timer.new()
	attack_cooldown_timer.one_shot = true
	add_child(attack_cooldown_timer)

	_enter_state(State.SEEKING_PLAYER)

func _enter_state(new_state: State) -> void:
	current_state = new_state
	match current_state:
		State.SEEKING_PLAYER:
			sprite.play("run")
		State.WARNING:
			sprite.play("run")
			attack_origin = global_position
			_start_attack_body_warning(ATTACK_WARNING_TIME)
			_spawn_cross_warning()
			action_timer.wait_time = ATTACK_WARNING_TIME
			_clear_action_timer_connections()
			action_timer.timeout.connect(Callable(self, "_fire_cross_ray"), CONNECT_ONE_SHOT)
			action_timer.start()
		State.FIRING:
			sprite.play("run")
			_finish_attack_body_warning()
			active_warning = null
			_apply_cross_ray_damage()
			_spawn_cross_ray_effect()
			attack_cooldown_timer.start(ATTACK_COOLDOWN)
			_enter_state(State.FLEEING)
		State.FLEEING:
			sprite.play("run")
			_determine_flee_target()
			action_timer.wait_time = FLEE_DURATION
			_clear_action_timer_connections()
			action_timer.timeout.connect(Callable(self, "_on_flee_timeout"), CONNECT_ONE_SHOT)
			action_timer.start()

func _physics_process(delta: float) -> void:
	if hp <= 0:
		_die()
		return

	update_offscreen_status()

	if not _is_offscreen and hp < hpMax and hp > 0:
		show_health_bar()

	if should_skip_actions_for_debuff():
		if current_state == State.WARNING:
			_cancel_pending_warning_attack()
		action_timer.paused = true
		attack_cooldown_timer.paused = true
		return
	action_timer.paused = false
	attack_cooldown_timer.paused = false

	if hp > 0 and CharacterEffects.is_player_dead_or_game_over():
		if action_timer.time_left > 0.0:
			action_timer.stop()
		if current_state == State.WARNING:
			_cancel_pending_warning_attack()
		current_state = State.SEEKING_PLAYER
		move_away_from_dead_player(delta, base_speed, sprite, false)
		return

	if not _is_offscreen and current_state != State.WARNING and current_state != State.FIRING:
		CharacterEffects.apply_separation(self, 13.0, 13.0)

	match current_state:
		State.SEEKING_PLAYER:
			_update_seek_target()
			_move_toward_target(delta, true)
			if _can_start_attack():
				_enter_state(State.WARNING)
		State.WARNING:
			_face_player()
		State.FIRING:
			_face_player()
		State.FLEEING:
			_move_toward_target(delta, true)

func _update_seek_target() -> void:
	if not PC.player_instance:
		target_position = global_position
		return
	var player_pos: Vector2 = PC.player_instance.global_position
	var from_player: Vector2 = global_position - player_pos
	if from_player.length_squared() <= 0.001:
		from_player = Vector2.RIGHT
	var distance: float = from_player.length()
	var direction: Vector2 = from_player.normalized()
	if distance < IDEAL_DISTANCE - DISTANCE_TOLERANCE:
		target_position = player_pos + direction * IDEAL_DISTANCE
	elif distance > IDEAL_DISTANCE + DISTANCE_TOLERANCE:
		target_position = player_pos + direction * IDEAL_DISTANCE
	else:
		target_position = global_position

func _move_toward_target(delta: float, face_move_direction: bool = false) -> void:
	var to_target: Vector2 = target_position - global_position
	if to_target.length_squared() <= 25.0:
		return
	speed = get_effective_move_speed(base_speed)
	var direction: Vector2 = CharacterEffects.apply_soft_separation_to_direction(self, to_target.normalized())
	if face_move_direction:
		_face_direction(direction)
	position += direction * speed * delta

func _face_player() -> void:
	if _is_offscreen or not PC.player_instance:
		return
	var player_offset_x: float = PC.player_instance.global_position.x - global_position.x
	_face_direction_x(player_offset_x)

func _face_direction(direction: Vector2) -> void:
	if _is_offscreen:
		return
	_face_direction_x(direction.x)

func _face_direction_x(direction_x: float) -> void:
	if direction_x > FACING_DEADZONE:
		CharacterEffects.set_enemy_flip_h(self, sprite, false, 0.0)
	elif direction_x < -FACING_DEADZONE:
		CharacterEffects.set_enemy_flip_h(self, sprite, true, 0.0)

func _can_start_attack() -> bool:
	if not PC.player_instance:
		return false
	if attack_cooldown_timer.time_left > 0.0:
		return false
	return global_position.distance_to(PC.player_instance.global_position) <= ATTACK_RANGE

func _fire_cross_ray() -> void:
	if is_dead:
		return
	_enter_state(State.FIRING)

func _clear_action_timer_connections() -> void:
	var fire_callable := Callable(self, "_fire_cross_ray")
	if action_timer.timeout.is_connected(fire_callable):
		action_timer.timeout.disconnect(fire_callable)
	var flee_callable := Callable(self, "_on_flee_timeout")
	if action_timer.timeout.is_connected(flee_callable):
		action_timer.timeout.disconnect(flee_callable)

func _cancel_pending_warning_attack() -> void:
	action_timer.stop()
	_clear_action_timer_connections()
	if active_warning != null and is_instance_valid(active_warning):
		active_warning.queue_free()
	active_warning = null
	_finish_attack_body_warning()
	current_state = State.SEEKING_PLAYER

func _on_flee_timeout() -> void:
	if is_dead:
		return
	_enter_state(State.SEEKING_PLAYER)

func _determine_flee_target() -> void:
	if not PC.player_instance:
		flee_direction = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
	else:
		flee_direction = (global_position - PC.player_instance.global_position).normalized()
		if flee_direction.length_squared() <= 0.001:
			flee_direction = Vector2.RIGHT
	target_position = global_position + flee_direction * base_speed * FLEE_DURATION * 1.4

func _spawn_cross_warning() -> void:
	var warning := _CrossRayWarning.new()
	warning.ray_width = RAY_WIDTH
	warning.ray_length = RAY_LENGTH
	warning.duration = ATTACK_WARNING_TIME
	warning.global_position = attack_origin
	get_tree().current_scene.add_child(warning)
	active_warning = warning

func _spawn_cross_ray_effect() -> void:
	var effect := _CrossRayEffect.new()
	effect.ray_width = RAY_WIDTH
	effect.ray_length = RAY_LENGTH
	effect.global_position = attack_origin
	get_tree().current_scene.add_child(effect)
	GU.screen_shake(3.0, 0.2)

func _apply_cross_ray_damage() -> void:
	if not is_instance_valid(PC.player_instance):
		return
	if PC.invincible:
		return
	var local_player: Vector2 = PC.player_instance.global_position - attack_origin
	var half_width: float = RAY_WIDTH * 0.5
	var hit_horizontal: bool = abs(local_player.y) <= half_width and abs(local_player.x) <= RAY_LENGTH
	var hit_vertical: bool = abs(local_player.x) <= half_width and abs(local_player.y) <= RAY_LENGTH
	if hit_horizontal or hit_vertical:
		var damage := int(atk * (1.0 - PC.damage_reduction_rate))
		PC.player_hit(damage, self, "蛊蚀射线")

func _die() -> void:
	free_health_bar()
	if is_dead:
		return

	if action_timer:
		action_timer.stop()
	if attack_cooldown_timer:
		attack_cooldown_timer.stop()
	if active_warning != null and is_instance_valid(active_warning):
		active_warning.queue_free()
	active_warning = null
	_finish_attack_body_warning()
	sprite.stop()
	sprite.play("death")
	var point_gain: int = int(get_point * Faze.get_point_multiplier())
	grant_kill_point_rewards(point_gain)
	var exp_gain: int = int(get_exp * Faze.get_exp_multiplier())
	Global.emit_signal("drop_exp_orb", exp_gain, global_position, false)
	if PC.selected_rewards.has("SplitSwordQi13") and randf() <= 0.05:
		Global.emit_signal("_fire_ring_bullets")
	if has_node("death"):
		$death.play()
	Global.emit_signal("monster_killed")
	is_dead = true
	remove_from_group("enemies")
	sprite.modulate = Color(1, 1, 1, 1)
	sprite.material = null
	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape:
		collision_shape.disabled = true
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	var shadow: Node = get_node_or_null("Shadow")
	if shadow:
		shadow.visible = false
	_drop_gu_insect_items()

	get_tree().create_timer(0.36).timeout.connect(Callable(self, "queue_free"), CONNECT_ONE_SHOT)

func _drop_gu_insect_items() -> void:
	var drop_multiplier: float = Global.get_effective_drop_multiplier() * drop_rate_multiplier
	var ether_drop_chance: float = ETHER_DROP_CHANCE * float(ETHER_DROP_IDS.size()) * drop_multiplier
	if randf() <= ether_drop_chance:
		var item_id: String = ETHER_DROP_IDS[randi() % ETHER_DROP_IDS.size()]
		Global.emit_signal("drop_out_item", item_id, 1, global_position)

	var fragment_chance: float = FRAGMENT_DROP_CHANCE * drop_multiplier * (1.0 + Global.study_fragment_drop_chance)
	if randf() <= fragment_chance:
		Global.emit_signal("drop_out_item", "item_007", 1, global_position)

func _get_attack_warning_overlay() -> AnimatedSprite2D:
	if attack_warning_overlay != null and is_instance_valid(attack_warning_overlay):
		return attack_warning_overlay
	attack_warning_overlay = AnimatedSprite2D.new()
	attack_warning_overlay.name = "AttackWarningOverlay"
	attack_warning_overlay.sprite_frames = sprite.sprite_frames
	attack_warning_overlay.visible = false
	attack_warning_overlay.modulate = Color(1.0, 0.0, 0.0, 0.0)
	attack_warning_overlay.z_index = sprite.z_index + 1
	add_child(attack_warning_overlay)
	_sync_attack_warning_overlay()
	return attack_warning_overlay

func _sync_attack_warning_overlay() -> void:
	if attack_warning_overlay == null or not is_instance_valid(attack_warning_overlay):
		return
	attack_warning_overlay.position = sprite.position
	attack_warning_overlay.scale = sprite.scale
	attack_warning_overlay.rotation = sprite.rotation
	attack_warning_overlay.flip_h = sprite.flip_h
	attack_warning_overlay.flip_v = sprite.flip_v
	attack_warning_overlay.centered = sprite.centered
	attack_warning_overlay.offset = sprite.offset
	attack_warning_overlay.animation = sprite.animation
	attack_warning_overlay.frame = sprite.frame

func _start_attack_body_warning(duration: float) -> void:
	var overlay := _get_attack_warning_overlay()
	_sync_attack_warning_overlay()
	overlay.visible = true
	overlay.modulate = Color(1.0, 0.0, 0.0, 0.0)
	overlay.play(sprite.animation)
	if attack_warning_tween != null and attack_warning_tween.is_valid():
		attack_warning_tween.kill()
	attack_warning_tween = create_tween()
	attack_warning_tween.tween_property(overlay, "modulate:a", ATTACK_BODY_WARNING_ALPHA, duration)

func _finish_attack_body_warning() -> void:
	if attack_warning_tween != null and attack_warning_tween.is_valid():
		attack_warning_tween.kill()
	if attack_warning_overlay == null or not is_instance_valid(attack_warning_overlay):
		return
	_sync_attack_warning_overlay()
	attack_warning_tween = create_tween()
	attack_warning_tween.tween_property(attack_warning_overlay, "modulate:a", 0.0, 0.08)
	attack_warning_tween.tween_callback(func():
		if attack_warning_overlay != null and is_instance_valid(attack_warning_overlay):
			attack_warning_overlay.visible = false
	)

func take_damage(damage: int, is_crit: bool, is_summon: bool, damage_type: String) -> void:
	if damage_type == "sword_wave":
		var time_scale: float = 0.5 if PC.selected_rewards.has("SplitSwordQi22") else 1.0
		if not can_apply_interval_damage("last_sword_wave_damage_time", SWORD_WAVE_DAMAGE_INTERVAL, time_scale):
			return
		apply_common_take_damage(damage, is_crit, is_summon, damage_type, {"show_damage_popup": false})
		return
	apply_common_take_damage(damage, is_crit, is_summon, damage_type)

func _on_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	if area.is_in_group("bullet") and area.has_method("get_bullet_damage_and_crit_status"):
		var collision_result: Dictionary = BulletCalculator.handle_bullet_collision_full(area, self, false)
		if collision_result["should_delete_bullet"]:
			area.queue_free()
		var final_damage_val: int = get_common_bullet_damage_value(collision_result["final_damage"])
		hp -= int(final_damage_val)
		if collision_result["should_rebound"]:
			area.call_deferred("create_rebound")
		if hp <= 0:
			if not is_dead:
				sprite.play("death")
		else:
			Global.play_hit_anime(position, collision_result["is_crit"])

class _CrossRayWarning extends Node2D:
	var ray_width := 80.0
	var ray_length := 800.0
	var duration := 1.0
	var elapsed := 0.0

	func _process(delta: float) -> void:
		elapsed += delta
		queue_redraw()
		if elapsed >= duration:
			queue_free()

	func _draw() -> void:
		var progress := clampf(elapsed / maxf(duration, 0.01), 0.0, 1.0)
		var alpha := 0.12 + 0.18 * sin(elapsed * 12.0)
		var fill_color := Color(0.0, 0.75, 0.25, alpha)
		var outline_color := Color(0.0, 0.22, 0.08, min(0.55, alpha + 0.15 + progress * 0.15))
		var half_width := ray_width * 0.5
		draw_rect(Rect2(-ray_length, -half_width, ray_length * 2.0, ray_width), fill_color)
		draw_rect(Rect2(-half_width, -ray_length, ray_width, ray_length * 2.0), fill_color)
		draw_rect(Rect2(-ray_length, -half_width, ray_length * 2.0, ray_width), outline_color, false, 3.0)
		draw_rect(Rect2(-half_width, -ray_length, ray_width, ray_length * 2.0), outline_color, false, 3.0)

class _CrossRayEffect extends Node2D:
	var ray_width := 80.0
	var ray_length := 800.0
	var elapsed := 0.0
	var _positions: PackedFloat32Array = []
	var _h_offsets: PackedFloat32Array = []
	var _v_offsets: PackedFloat32Array = []
	var _h_inner_offsets: PackedFloat32Array = []
	var _v_inner_offsets: PackedFloat32Array = []

	func _ready() -> void:
		for i in range(-int(ray_length), int(ray_length) + 1, 8):
			_positions.append(float(i))
			_h_offsets.append(randf_range(0.8, 1.0))
			_v_offsets.append(randf_range(0.8, 1.0))
			_h_inner_offsets.append(randf_range(0.8, 1.0))
			_v_inner_offsets.append(randf_range(0.8, 1.0))

	func _process(delta: float) -> void:
		elapsed += delta
		queue_redraw()
		if elapsed > 0.45:
			queue_free()

	func _draw() -> void:
		var alpha := 1.0 - elapsed / 0.45
		var width := ray_width * alpha
		var outer_color := Color(0.0, 1.0, 0.35, alpha * 0.65)
		var inner_color := Color(0.75, 1.0, 0.85, alpha)
		for i in range(_positions.size()):
			var x := _positions[i]
			var h := width * _h_offsets[i]
			draw_rect(Rect2(x, -h * 0.5, 8.0, h), outer_color)
			var inner_h := width * 0.28 * _h_inner_offsets[i]
			draw_rect(Rect2(x, -inner_h * 0.5, 8.0, inner_h), inner_color)
		for i in range(_positions.size()):
			var y := _positions[i]
			var w := width * _v_offsets[i]
			draw_rect(Rect2(-w * 0.5, y, w, 8.0), outer_color)
			var inner_w := width * 0.28 * _v_inner_offsets[i]
			draw_rect(Rect2(-inner_w * 0.5, y, inner_w, 8.0), inner_color)
