extends Area2D

@export var sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D

var damage: float = 0.0
var bleed_chance: float = 0.0
var range_scale: float = 1.0
var elite_damage_bonus: float = 0.0
var _fade_tween: Tween
var _run_id: int = 0

const MAX_TARGETS_PER_FRAME := 18

func _ready() -> void:
	CharacterEffects.include_enemy_collision_mask(self)
	_resolve_nodes()
	if sprite:
		sprite.play("default")
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)

func setup_thud(p_position: Vector2, p_damage: float, p_bleed_chance: float, p_range_scale: float, p_elite_damage_bonus: float) -> void:
	_resolve_nodes()
	_run_id += 1
	global_position = p_position
	damage = p_damage
	bleed_chance = p_bleed_chance
	range_scale = p_range_scale
	elite_damage_bonus = p_elite_damage_bonus
	scale = Vector2.ONE * range_scale
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	if sprite:
		sprite.modulate.a = 0.0
	call_deferred("_start_thud", _run_id)

func _resolve_nodes() -> void:
	if sprite == null:
		sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D

func _start_thud(run_id: int) -> void:
	if run_id != _run_id:
		return
	if not is_inside_tree():
		call_deferred("_start_thud", run_id)
		return
	_play_fade_animation()
	_apply_damage_and_finish(run_id)

func _apply_damage_and_finish(run_id: int) -> void:
	# 等待两帧物理帧，确保 transform 和 scale 更新后，物理引擎完成碰撞检测
	await get_tree().physics_frame
	await get_tree().physics_frame
	if run_id != _run_id:
		return
	
	var areas = get_overlapping_areas()
	var processed_this_frame := 0
	for area in areas:
		if run_id != _run_id:
			return
		if area == null or not is_instance_valid(area):
			continue
		if area.is_in_group("enemies") and area.has_method("take_damage"):
			var final_damage = damage
			if elite_damage_bonus > 0.0:
				if area.is_in_group("elite") or area.is_in_group("boss"):
					final_damage = damage * (1.0 + elite_damage_bonus)
			area.take_damage(int(final_damage), false, false, "faze_bath_blood_thud")
			_try_apply_bleed(area)
			processed_this_frame += 1
			if processed_this_frame >= MAX_TARGETS_PER_FRAME:
				processed_this_frame = 0
				await get_tree().process_frame
				if run_id != _run_id:
					return
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

func _play_fade_animation() -> void:
	_resolve_nodes()
	if sprite == null:
		ObjectPool.recycle(self)
		return
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	sprite.modulate.a = 0.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(sprite, "modulate:a", 1.0, 0.1)
	_fade_tween.tween_interval(0.25)
	_fade_tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	_fade_tween.tween_callback(func(): ObjectPool.recycle(self))

func _try_apply_bleed(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_signal("debuff_applied"):
		return
	if bleed_chance <= 0.0:
		return
	if bleed_chance >= 1.0:
		target.emit_signal("debuff_applied", "bleed")
		return
	if randf() < bleed_chance:
		target.emit_signal("debuff_applied", "bleed")

func reset_for_pool() -> void:
	_run_id += 1
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
	damage = 0.0
	bleed_chance = 0.0
	range_scale = 1.0
	elite_damage_bonus = 0.0
	scale = Vector2.ONE
	global_position = Vector2.ZERO
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	_resolve_nodes()
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if sprite:
		sprite.modulate.a = 0.0
		sprite.rotation = 0.0
		sprite.play("default")
