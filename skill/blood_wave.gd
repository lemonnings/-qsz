extends Area2D

@export var sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D
@export var rotation_offset: float = 0.0

var wave_damage: float = 0.0
var wave_range: float = 0.0
var wave_direction: Vector2 = Vector2.RIGHT
var apply_bleed: bool = false
var extra_crit_chance: float = 0.0
var extra_crit_damage: float = 0.0
var sprite_base_scale: Vector2
var collision_base_scale: Vector2
var base_range: float = 0.0
var default_range: float = 120.0
var travel_speed: float = 360.0
var travel_duration: float = 0.0
var travel_elapsed: float = 0.0
var start_position: Vector2
var end_position: Vector2
var hit_targets: Dictionary = {}

func _ready() -> void:
	sprite_base_scale = sprite.scale
	collision_base_scale = collision_shape.scale
	var rect_shape = collision_shape.shape as RectangleShape2D
	base_range = rect_shape.size.x * collision_base_scale.x
	
	if sprite.animation != "default" or not sprite.is_playing():
		sprite.play("default")
	
	_apply_visual()

func _process(delta: float) -> void:
	travel_elapsed += delta
	var t = travel_elapsed / travel_duration
	if t > 1.0:
		t = 1.0
	global_position = start_position.lerp(end_position, t)
	modulate.a = 1.0 - t
	_apply_damage()
	if travel_elapsed >= travel_duration:
		queue_free()

func setup_blood_wave(p_start_position: Vector2, p_direction: Vector2, p_range: float, p_damage: float, p_apply_bleed: bool, p_extra_crit_chance: float, p_extra_crit_damage: float) -> void:
	start_position = p_start_position
	wave_direction = p_direction.normalized()
	wave_range = p_range
	if wave_range <= 0.0:
		wave_range = default_range
	wave_damage = p_damage
	apply_bleed = p_apply_bleed
	extra_crit_chance = p_extra_crit_chance
	extra_crit_damage = p_extra_crit_damage
	end_position = start_position + wave_direction * wave_range
	travel_duration = wave_range / travel_speed
	
	_apply_visual()

func _apply_visual() -> void:
	rotation = wave_direction.angle() + rotation_offset
	global_position = start_position
	sprite.scale = sprite_base_scale
	collision_shape.scale = collision_base_scale

func _apply_damage() -> void:
	var crit_chance = PC.crit_chance + extra_crit_chance
	var crit_damage_multi = PC.crit_damage_multi + extra_crit_damage
	
	var is_crit = false
	var final_damage = wave_damage * 0.8 # 造成80%攻击的伤害
	if randf() < crit_chance:
		is_crit = true
		final_damage *= crit_damage_multi
	
	var bodies = get_overlapping_areas()
	for body in bodies:
		if body.is_in_group("enemies"):
			var body_id = body.get_instance_id()
			if hit_targets.has(body_id):
				continue
			hit_targets[body_id] = true
			body.take_damage(int(final_damage), is_crit, false, "blood_wave")
			if apply_bleed:
				body.emit_signal("debuff_applied", "bleed")
