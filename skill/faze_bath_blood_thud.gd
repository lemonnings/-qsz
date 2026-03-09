extends Area2D

@export var sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D

var damage: float = 0.0
var bleed_chance: float = 0.0
var range_scale: float = 1.0
var elite_damage_bonus: float = 0.0

func _ready() -> void:
	sprite.play("default")
	monitoring = true
	monitorable = true

func setup_thud(p_position: Vector2, p_damage: float, p_bleed_chance: float, p_range_scale: float, p_elite_damage_bonus: float) -> void:
	global_position = p_position
	damage = p_damage
	bleed_chance = p_bleed_chance
	range_scale = p_range_scale
	elite_damage_bonus = p_elite_damage_bonus
	
	scale = Vector2.ONE * range_scale

	
	_play_fade_animation()
	call_deferred("_apply_damage_and_finish")

func _apply_damage_and_finish() -> void:
	# 等待两帧物理帧，确保 transform 和 scale 更新后，物理引擎完成碰撞检测
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	var areas = get_overlapping_areas()
	print("Thud damage check: pos=", global_position, " scale=", scale, " areas_count=", areas.size())
	
	for area in areas:
		if area.is_in_group("enemies") and area.has_method("take_damage"):
			var final_damage = damage
			if elite_damage_bonus > 0.0:
				if area.is_in_group("elite") or area.is_in_group("boss"):
					final_damage = damage * (1.0 + elite_damage_bonus)
			area.take_damage(int(final_damage), false, false, "faze_bath_blood_thud")
			_try_apply_bleed(area)
	monitoring = false
	monitorable = false

func _play_fade_animation() -> void:
	sprite.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 1.0, 0.1)
	tween.tween_interval(0.25)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)

func _try_apply_bleed(target: Node) -> void:
	if bleed_chance <= 0.0:
		return
	if bleed_chance >= 1.0:
		target.emit_signal("debuff_applied", "bleed")
		return
	if randf() < bleed_chance:
		target.emit_signal("debuff_applied", "bleed")
