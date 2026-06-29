extends AnimatedSprite2D

const STRIKE_FRAMES: Array[int] = [3, 9, 14]
const ANIMATION_FPS: float = 8.0
const ANIMATION_FRAME_COUNT: int = 21
const MOVE_SLOW_RELEASE_FRAMES_BEFORE_END: int = 3
const HAMMER_ROTATION_FPS: float = 15.0
const STRIKE_SCALES: Array[float] = [1.0, 1.5, 2.5]
const WU_AND_HIT_SCALES: Array[float] = [1.6, 4.5, 9]
const DEFAULT_DAMAGE_RATIOS: Array[float] = [1, 1.5, 3]
const HAMMER_START_ROTATION: float = deg_to_rad(-41.0)
const HAMMER_END_ROTATION: float = deg_to_rad(72.0)
const HAMMER_FADE_IN_TIME: float = 0.1
const HAMMER_SWING_TIME: float = 0.13
const HAMMER_FADE_OUT_TIME: float = 0.08
const STRIKE_SHAKE_BASE: float = 6.015
const STRIKE_SHAKE_DURATION: float = 0.22
const KNOCKBACK_BASE_FORCE: float = 18.0
const KNOCKBACK_MAX_FORCE: float = 46.0
const THIRD_STRIKE_OFFSET: Vector2 = Vector2(0.0, -20.0)
const THIRD_STRIKE_RISE_TIME: float = 0.14
const THIRD_STRIKE_FALL_TIME: float = 0.18
const THIRD_STRIKE_FALL_DELAY: float = 0.22

@export var hammer_sprite: Sprite2D
@export var wu_sprite: AnimatedSprite2D
@export var hit_area: Area2D
@export var hit_shape: CollisionShape2D

var owner_player: Node2D = null
var damage_ratios: Array[float] = DEFAULT_DAMAGE_RATIOS.duplicate()
var triggered_strikes: Dictionary = {}
var original_player_sprite: AnimatedSprite2D = null
var original_player_sprite_visible: bool = true
var base_hammer_position: Vector2 = Vector2.ZERO
var base_hammer_scale: Vector2 = Vector2.ONE
var base_hammer_modulate: Color = Color.WHITE
var base_wu_position: Vector2 = Vector2.ZERO
var base_wu_scale: Vector2 = Vector2.ONE
var base_wu_modulate: Color = Color.WHITE
var base_hit_shape_position: Vector2 = Vector2.ZERO
var base_hit_shape_scale: Vector2 = Vector2.ONE
var base_hit_radius: float = 30.0
var base_effect_position: Vector2 = Vector2.ZERO
var base_effect_scale: Vector2 = Vector2.ONE
var base_modulate: Color = Color.WHITE
var is_started: bool = false
var lock_released: bool = false
var slow_released: bool = false
var effect_position_tween: Tween = null


func _ready() -> void:
	_resolve_template_nodes()
	base_effect_scale = scale
	base_modulate = modulate
	base_hammer_position = hammer_sprite.position if hammer_sprite != null else Vector2.ZERO
	base_hammer_scale = hammer_sprite.scale if hammer_sprite != null else Vector2.ONE
	base_hammer_modulate = hammer_sprite.modulate if hammer_sprite != null else Color.WHITE
	base_wu_position = wu_sprite.position if wu_sprite != null else Vector2.ZERO
	base_wu_scale = wu_sprite.scale if wu_sprite != null else Vector2.ONE
	base_wu_modulate = wu_sprite.modulate if wu_sprite != null else Color.WHITE
	base_hit_shape_position = hit_shape.position if hit_shape != null else Vector2.ZERO
	base_hit_shape_scale = hit_shape.scale if hit_shape != null else Vector2.ONE
	base_hit_radius = _read_base_hit_radius()
	if hammer_sprite != null:
		hammer_sprite.visible = false
	if wu_sprite != null:
		wu_sprite.visible = false
		wu_sprite.stop()
	if hit_shape != null:
		hit_shape.disabled = true
	if hit_area != null:
		CharacterEffects.include_enemy_collision_mask(hit_area)
	visible = false
	stop()
	if not animation_finished.is_connected(_on_animation_finished):
		animation_finished.connect(_on_animation_finished)


func start(p_owner_player: Node2D, p_damage_ratios: Array[float] = []) -> void:
	_resolve_template_nodes()
	_hide_template_nodes()
	owner_player = p_owner_player
	base_effect_position = position
	damage_ratios.clear()
	lock_released = false
	slow_released = false
	if effect_position_tween != null:
		effect_position_tween.kill()
		effect_position_tween = null
	for ratio_value: float in p_damage_ratios:
		damage_ratios.append(ratio_value)
	if damage_ratios.size() < STRIKE_FRAMES.size():
		damage_ratios = DEFAULT_DAMAGE_RATIOS.duplicate()
	triggered_strikes.clear()
	_hide_owner_sprite()
	visible = true
	position = base_effect_position
	modulate = base_modulate
	is_started = true
	frame = 0
	frame_progress = 0.0
	play("default")
	_run_strike_timeline()
	_run_slow_release_timeline()


func _resolve_template_nodes() -> void:
	if hammer_sprite == null:
		hammer_sprite = get_node_or_null("chui") as Sprite2D
	if wu_sprite == null:
		wu_sprite = get_node_or_null("wu") as AnimatedSprite2D
	if hit_area == null:
		hit_area = get_node_or_null("Area2D") as Area2D
	if hit_shape == null:
		hit_shape = get_node_or_null("Area2D/CollisionShape2D") as CollisionShape2D


func _hide_template_nodes() -> void:
	if hammer_sprite != null:
		hammer_sprite.visible = false
	if wu_sprite != null:
		wu_sprite.visible = false
		wu_sprite.stop()
		wu_sprite.frame = 0
		wu_sprite.frame_progress = 0.0


func _process(_delta: float) -> void:
	if not is_started:
		return


func _run_strike_timeline() -> void:
	var previous_time: float = 0.0
	for i in range(STRIKE_FRAMES.size()):
		var strike_time: float = float(STRIKE_FRAMES[i]) / ANIMATION_FPS
		var wait_time: float = maxf(0.0, strike_time - previous_time)
		if i == 2:
			wait_time = maxf(0.0, wait_time - THIRD_STRIKE_RISE_TIME)
		if wait_time > 0.0:
			await get_tree().create_timer(wait_time, false).timeout
		if not is_started or not is_inside_tree():
			return
		if i == 2:
			await _tween_effect_position(base_effect_position + THIRD_STRIKE_OFFSET, THIRD_STRIKE_RISE_TIME)
			if not is_started or not is_inside_tree():
				return
		triggered_strikes[i] = true
		_perform_strike(i)
		if i == 2:
			_fall_effect_after_third_strike()
		previous_time = strike_time


func _run_slow_release_timeline() -> void:
	var release_frame: int = max(0, ANIMATION_FRAME_COUNT - MOVE_SLOW_RELEASE_FRAMES_BEFORE_END)
	var release_time: float = float(release_frame) / ANIMATION_FPS
	if release_time > 0.0:
		await get_tree().create_timer(release_time, false).timeout
	if not is_started or not is_inside_tree():
		return
	_release_owner_slow()


func _perform_strike(strike_index: int) -> void:
	var hammer_scale: float = float(STRIKE_SCALES[strike_index])
	var impact_scale: float = float(WU_AND_HIT_SCALES[strike_index])
	var damage_ratio: float = float(damage_ratios[strike_index])
	print("[DestructiveHammer] strike=", strike_index + 1, " frame=", frame, " hammer_scale=", hammer_scale, " impact_scale=", impact_scale)
	_update_hit_shape_scale(impact_scale)
	_spawn_hammer_visual(hammer_scale, impact_scale, damage_ratio)


func _tween_effect_position(target_position: Vector2, duration: float) -> void:
	if effect_position_tween != null:
		effect_position_tween.kill()
		effect_position_tween = null
	if duration <= 0.0:
		position = target_position
		return
	effect_position_tween = create_tween()
	effect_position_tween.set_trans(Tween.TRANS_SINE)
	effect_position_tween.set_ease(Tween.EASE_IN_OUT)
	effect_position_tween.tween_property(self, "position", target_position, duration)
	await effect_position_tween.finished
	effect_position_tween = null


func _fall_effect_after_third_strike() -> void:
	await get_tree().create_timer(THIRD_STRIKE_FALL_DELAY, false).timeout
	if not is_started or not is_inside_tree():
		return
	await _tween_effect_position(base_effect_position, THIRD_STRIKE_FALL_TIME)


func _update_hit_shape_scale(visual_scale: float) -> void:
	if hit_shape != null:
		hit_shape.position = base_hit_shape_position
		hit_shape.scale = base_hit_shape_scale * visual_scale


func _spawn_hammer_visual(hammer_scale: float, impact_scale: float, damage_ratio: float) -> void:
	if hammer_sprite == null:
		return
	var strike_hammer: Sprite2D = hammer_sprite.duplicate() as Sprite2D
	if strike_hammer == null:
		return
	strike_hammer.name = "chui_strike"
	add_child(strike_hammer)
	strike_hammer.visible = true
	strike_hammer.position = base_hammer_position
	strike_hammer.scale = base_hammer_scale * hammer_scale
	strike_hammer.rotation = HAMMER_START_ROTATION
	strike_hammer.modulate = base_hammer_modulate
	strike_hammer.modulate.a = 0.0
	_run_hammer_visual(strike_hammer, hammer_scale, impact_scale, damage_ratio)


func _run_hammer_visual(strike_hammer: Sprite2D, hammer_scale: float, impact_scale: float, damage_ratio: float) -> void:
	var target_alpha: float = 1.0
	target_alpha = base_hammer_modulate.a
	var elapsed: float = 0.0
	while elapsed < HAMMER_FADE_IN_TIME and is_instance_valid(strike_hammer):
		var delta: float = get_process_delta_time()
		elapsed += delta
		strike_hammer.modulate.a = target_alpha * clampf(elapsed / HAMMER_FADE_IN_TIME, 0.0, 1.0)
		await get_tree().process_frame
	if not is_instance_valid(strike_hammer):
		return
	strike_hammer.modulate.a = target_alpha
	elapsed = 0.0
	while elapsed < HAMMER_SWING_TIME and is_instance_valid(strike_hammer):
		var delta: float = 1.0 / HAMMER_ROTATION_FPS
		elapsed += delta
		var t: float = clampf(elapsed / HAMMER_SWING_TIME, 0.0, 1.0)
		var eased_t: float = t * t * t * t
		strike_hammer.rotation = lerpf(HAMMER_START_ROTATION, HAMMER_END_ROTATION, eased_t)
		await get_tree().create_timer(delta, false).timeout
	if not is_instance_valid(strike_hammer):
		return
	strike_hammer.rotation = HAMMER_END_ROTATION
	_spawn_wu_visual(impact_scale)
	GU.screen_shake(STRIKE_SHAKE_BASE * hammer_scale, STRIKE_SHAKE_DURATION)
	SEManager.play("111")
	_apply_strike_damage_after_frame(impact_scale, damage_ratio)
	elapsed = 0.0
	while elapsed < HAMMER_FADE_OUT_TIME and is_instance_valid(strike_hammer):
		var delta: float = get_process_delta_time()
		elapsed += delta
		strike_hammer.modulate.a = target_alpha * (1.0 - clampf(elapsed / HAMMER_FADE_OUT_TIME, 0.0, 1.0))
		await get_tree().process_frame
	if is_instance_valid(strike_hammer):
		strike_hammer.queue_free()


func _spawn_wu_visual(visual_scale: float) -> void:
	if wu_sprite == null:
		return
	var strike_wu: AnimatedSprite2D = wu_sprite.duplicate() as AnimatedSprite2D
	if strike_wu == null:
		return
	strike_wu.name = "wu_strike"
	add_child(strike_wu)
	strike_wu.visible = true
	strike_wu.position = base_wu_position
	strike_wu.scale = base_wu_scale * visual_scale
	strike_wu.modulate = base_wu_modulate
	strike_wu.stop()
	strike_wu.frame = 0
	strike_wu.frame_progress = 0.0
	strike_wu.play("default")
	_free_wu_after_finished(strike_wu)


func _free_wu_after_finished(strike_wu: AnimatedSprite2D) -> void:
	await strike_wu.animation_finished
	if is_instance_valid(strike_wu):
		strike_wu.queue_free()


func _apply_strike_damage_after_frame(visual_scale: float, damage_ratio: float) -> void:
	await get_tree().create_timer(1.0 / ANIMATION_FPS, false).timeout
	if not is_started or not is_inside_tree():
		return
	_apply_strike_damage(visual_scale, damage_ratio)


func _apply_strike_damage(visual_scale: float, damage_ratio: float) -> void:
	var center_position: Vector2 = _get_hit_center_position()
	var hit_radius: float = _get_hit_radius(visual_scale)
	var base_damage: float = float(PC.pc_atk) * damage_ratio * (1.0 + PC.active_skill_multi)
	var damaged_targets: Dictionary = {}
	_damage_targets_in_group("enemies", center_position, hit_radius, base_damage, damaged_targets)
	_damage_targets_in_group("boss", center_position, hit_radius, base_damage, damaged_targets)


func _damage_targets_in_group(group_name: String, center_position: Vector2, hit_radius: float, base_damage: float, damaged_targets: Dictionary) -> void:
	var targets: Array[Node] = get_tree().get_nodes_in_group(group_name)
	for target_node: Node in targets:
		if not is_instance_valid(target_node) or not target_node.has_method("take_damage"):
			continue
		if not target_node is Node2D:
			continue
		var target_2d := target_node as Node2D
		if center_position.distance_to(target_2d.global_position) > hit_radius:
			continue
		var target_id: int = target_node.get_instance_id()
		if damaged_targets.has(target_id):
			continue
		damaged_targets[target_id] = true
		target_node.take_damage(int(round(base_damage)), false, false, "destructive_hammer")
		if not target_node.is_in_group("boss"):
			_apply_knockback_to_target(target_2d, center_position, hit_radius)


func _apply_knockback_to_target(target: Node2D, center_position: Vector2, hit_radius: float) -> void:
	if target == null or not is_instance_valid(target) or not target.has_method("apply_knockback"):
		return
	var direction: Vector2 = target.global_position - center_position
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT if scale.x >= 0.0 else Vector2.LEFT
	var normalized_direction: Vector2 = direction.normalized()
	var force: float = minf(KNOCKBACK_MAX_FORCE, KNOCKBACK_BASE_FORCE + hit_radius * 0.08)
	target.apply_knockback(normalized_direction, force)


func _get_hit_center_position() -> Vector2:
	if hit_shape != null:
		return hit_shape.global_position
	if hit_area != null:
		return hit_area.global_position
	return global_position


func _get_hit_radius(visual_scale: float) -> float:
	return base_hit_radius * visual_scale * Global.get_attack_range_multiplier()


func _read_base_hit_radius() -> float:
	if hit_shape != null and hit_shape.shape != null:
		var shape := hit_shape.shape
		var shape_scale_max: float = maxf(absf(base_hit_shape_scale.x), absf(base_hit_shape_scale.y))
		if shape is CircleShape2D:
			return (shape as CircleShape2D).radius * shape_scale_max
		if shape is CapsuleShape2D:
			var capsule := shape as CapsuleShape2D
			return maxf(capsule.radius, capsule.height * 0.5) * shape_scale_max
		if shape is RectangleShape2D:
			var rectangle := shape as RectangleShape2D
			return maxf(rectangle.size.x, rectangle.size.y) * 0.5 * shape_scale_max
	return 30.0


func _hide_owner_sprite() -> void:
	if owner_player == null or not is_instance_valid(owner_player):
		return
	original_player_sprite = owner_player.get("sprite") as AnimatedSprite2D
	if original_player_sprite == null:
		original_player_sprite = owner_player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if original_player_sprite != null:
		original_player_sprite_visible = original_player_sprite.visible
		original_player_sprite.visible = false
		flip_h = false
		if original_player_sprite.flip_h:
			scale = Vector2(-absf(base_effect_scale.x), base_effect_scale.y)
		else:
			scale = Vector2(absf(base_effect_scale.x), base_effect_scale.y)
	if owner_player.has_method("start_destructive_hammer_lock"):
		owner_player.start_destructive_hammer_lock()


func _restore_owner_sprite() -> void:
	if effect_position_tween != null:
		effect_position_tween.kill()
		effect_position_tween = null
	position = base_effect_position
	if not lock_released and owner_player != null and is_instance_valid(owner_player) and owner_player.has_method("end_destructive_hammer_lock"):
		owner_player.end_destructive_hammer_lock()
		lock_released = true
	if original_player_sprite != null and is_instance_valid(original_player_sprite):
		original_player_sprite.visible = original_player_sprite_visible


func _on_animation_finished() -> void:
	is_started = false
	_restore_owner_sprite()
	queue_free()


func _exit_tree() -> void:
	_restore_owner_sprite()


func _release_owner_slow() -> void:
	if slow_released:
		return
	if owner_player != null and is_instance_valid(owner_player) and owner_player.has_method("release_destructive_hammer_slow"):
		owner_player.release_destructive_hammer_slow()
	slow_released = true
