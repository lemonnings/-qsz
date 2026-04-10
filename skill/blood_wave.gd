extends Area2D
class_name BloodWave

@export var sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D
@export var rotation_offset: float = 0.0

static var main_skill_bloodwave_damage: float = 1.0
static var bloodwave_range: float = 120.0
static var bloodwave_apply_bleed: bool = false
static var bloodwave_hp_cost_multi: float = 1.0
static var bloodwave_extra_crit_chance: float = 0.0
static var bloodwave_extra_crit_damage: float = 0.0
static var bloodwave_missing_hp_damage_bonus: float = 0.0
static var bloodwave_missing_hp_range_bonus: float = 0.0
static var bloodwave_missing_hp_heal_bonus: float = 0.0
static var bloodwave_low_hp_damage_bonus: float = 0.0
static var bloodwave_low_hp_range_bonus: float = 0.0
static var bloodwave_bleed_move_speed_bonus: float = 0.0

static func reset_data() -> void:
	main_skill_bloodwave_damage = 1.0
	bloodwave_range = 120.0
	bloodwave_apply_bleed = false
	bloodwave_hp_cost_multi = 1.0
	bloodwave_extra_crit_chance = 0.0
	bloodwave_extra_crit_damage = 0.0
	bloodwave_missing_hp_damage_bonus = 0.0
	bloodwave_missing_hp_range_bonus = 0.0
	bloodwave_missing_hp_heal_bonus = 0.0
	bloodwave_low_hp_damage_bonus = 0.0
	bloodwave_low_hp_range_bonus = 0.0
	bloodwave_bleed_move_speed_bonus = 0.0

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

static func fire_skill(scene: PackedScene, origin_pos: Vector2, tree: SceneTree) -> void:
	if not scene:
		return
		
	var data = _build_data()
	
	# 扣除生命值逻辑
	if PC.pc_hp > 1:
		var raw_cost = PC.pc_hp * 0.01 * bloodwave_hp_cost_multi
		var hp_cost = int(ceil(raw_cost))
		if hp_cost < 1:
			hp_cost = 1
		PC.pc_hp -= hp_cost
		if PC.pc_hp < 1:
			PC.pc_hp = 1
			
	var base_direction = Vector2.RIGHT
	var player = tree.get_first_node_in_group("player")
	if player:
		var nearest_enemy = player.find_nearest_enemy()
		if nearest_enemy:
			base_direction = (nearest_enemy.position - player.position).normalized()
		else:
			if not player.sprite_direction_right:
				base_direction = Vector2.LEFT
			else:
				base_direction = Vector2.RIGHT
	
	var bloodwave_instance = scene.instantiate()
	tree.current_scene.add_child(bloodwave_instance)
	bloodwave_instance.setup_blood_wave(origin_pos, base_direction, data.range, data.damage, data.apply_bleed, data.extra_crit_chance, data.extra_crit_damage)

static func _build_data() -> Dictionary:
	var base_damage = PC.pc_atk * main_skill_bloodwave_damage
	
	var damage_multiplier = main_skill_bloodwave_damage
	var base_range = bloodwave_range
	
	var missing_hp_ratio = 0.0
	if PC.pc_max_hp > 0:
		missing_hp_ratio = float(PC.pc_max_hp - PC.pc_hp) / float(PC.pc_max_hp)
	
	var damage_bonus_ratio = missing_hp_ratio * bloodwave_missing_hp_damage_bonus
	var range_bonus_ratio = missing_hp_ratio * bloodwave_missing_hp_range_bonus
	
	if PC.pc_max_hp > 0:
		var hp_ratio = float(PC.pc_hp) / float(PC.pc_max_hp)
		if hp_ratio < 0.5:
			damage_bonus_ratio += bloodwave_low_hp_damage_bonus
			range_bonus_ratio += bloodwave_low_hp_range_bonus
			
	# 应用广域法则加成
	var wide_range_mult = Faze.get_wide_range_multiplier()
	var wide_damage_mult = Faze.get_wide_damage_multiplier(range_bonus_ratio) # 这里range_bonus_ratio是血气波自身的范围加成
	
	var final_damage = (PC.pc_atk * damage_multiplier) * (1.0 + damage_bonus_ratio) * wide_damage_mult
	var final_range = base_range * (1.0 + range_bonus_ratio) * wide_range_mult
	
	return {
		"damage": final_damage,
		"range": final_range,
		"apply_bleed": bloodwave_apply_bleed,
		"extra_crit_chance": bloodwave_extra_crit_chance,
		"extra_crit_damage": bloodwave_extra_crit_damage
	}

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
	var final_damage = wave_damage # 造成100%攻击的伤害
	
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
			# 击中粒子崩散特效
			HitParticleSpawner.spawn_by_weapon(get_tree(), body.global_position, "bloodwave")
			if apply_bleed:
				body.emit_signal("debuff_applied", "bleed")
