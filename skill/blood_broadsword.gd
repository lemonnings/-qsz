extends Area2D

@export var sprite: AnimatedSprite2D
@export var collision_shape: CollisionShape2D
@export var rotation_offset: float = - PI / 2.0
@export var search_radius: float = 100.0

var broadsword_scene: PackedScene = preload("res://Scenes/player/blood_broadsword.tscn")
var base_sprite_scale: Vector2
var base_collision_scale: Vector2
var custom_range_multiplier: float = 1.0
var can_repeat: bool = true
var target_direction: Vector2 = Vector2.RIGHT
var cached_attack_data: Dictionary = {}
var hit_targets: Dictionary = {}
var damage_active: bool = false
var effect_applied: bool = false

func set_custom_range_multiplier(multiplier: float) -> void:
	custom_range_multiplier = multiplier

func disable_repeat() -> void:
	can_repeat = false

func _ready() -> void:
	base_sprite_scale = sprite.scale
	base_collision_scale = collision_shape.scale
	
	cached_attack_data = _build_attack_data()
	_apply_range(cached_attack_data.range_multiplier)
	
	var player = PC.player_instance
	var player_position = player.global_position
	var effective_radius = _get_effective_radius(cached_attack_data.range_multiplier)
	var target_center = _find_most_dense_center(player_position, search_radius, effective_radius)
	
	global_position = player_position
	_apply_rotation(player_position, target_center)
	
	if sprite.animation != "default" or not sprite.is_playing():
		sprite.play("default")
	
	await get_tree().physics_frame
	damage_active = true
	
	if can_repeat and cached_attack_data.repeat_chance > 0.0:
		var roll = randf()
		if roll < cached_attack_data.repeat_chance:
			await get_tree().create_timer(cached_attack_data.repeat_delay).timeout
			_spawn_repeat_attack(cached_attack_data)
	
	await get_tree().create_timer(cached_attack_data.life_time).timeout
	queue_free()

func _build_attack_data() -> Dictionary:
	var damage_ratio = PC.main_skill_bloodboardsword_damage
	var heal_ratio = 0.01
	var min_heal = 10
	var range_multiplier = 1.0
	var bleed_damage_bonus = 0.0
	var heal_on_bleed_bonus = 0.0
	var repeat_chance = 0.0
	var repeat_delay = 0.5
	var repeat_range_multiplier = 1.0
	var shield_hit_count = 0
	var shield_ratio = 0.0
	var shield_min = 0
	var shield_duration = 0.0
	var life_time = 0.6
	
	if PC.selected_rewards.has("BloodBoardSword1"):
		damage_ratio += 0.1
		heal_ratio = 0.02
		min_heal = 20
	
	if PC.selected_rewards.has("BloodBoardSword2"):
		damage_ratio += 0.1
		range_multiplier += 0.3
	
	if PC.selected_rewards.has("BloodBoardSword3"):
		repeat_chance = 0.3
	
	if PC.selected_rewards.has("BloodBoardSword4"):
		bleed_damage_bonus = 0.5
	
	if PC.selected_rewards.has("BloodBoardSword11"):
		damage_ratio += 0.1
		shield_hit_count = 5
		shield_ratio = 0.02
		shield_min = 20
		shield_duration = 12.0
	
	if PC.selected_rewards.has("BloodBoardSword22"):
		damage_ratio += 0.2
		heal_on_bleed_bonus = 0.3
	
	if PC.selected_rewards.has("BloodBoardSword33"):
		repeat_chance = 0.4
		repeat_range_multiplier = 1.3
	
	range_multiplier *= custom_range_multiplier
	
	var damage = PC.pc_atk * damage_ratio
	
	return {
		"damage": damage,
		"heal_ratio": heal_ratio,
		"min_heal": min_heal,
		"range_multiplier": range_multiplier,
		"bleed_damage_bonus": bleed_damage_bonus,
		"heal_on_bleed_bonus": heal_on_bleed_bonus,
		"repeat_chance": repeat_chance,
		"repeat_delay": repeat_delay,
		"repeat_range_multiplier": repeat_range_multiplier,
		"shield_hit_count": shield_hit_count,
		"shield_ratio": shield_ratio,
		"shield_min": shield_min,
		"shield_duration": shield_duration,
		"life_time": life_time
	}

func _apply_range(range_multiplier: float) -> void:
	var final_range_multiplier = range_multiplier * Global.get_attack_range_multiplier()
	sprite.scale = Vector2(base_sprite_scale.x * final_range_multiplier, base_sprite_scale.y * final_range_multiplier)
	collision_shape.scale = Vector2(base_collision_scale.x * final_range_multiplier, base_collision_scale.y * final_range_multiplier)

func _get_effective_radius(range_multiplier: float) -> float:
	var circle_shape = collision_shape.shape as CircleShape2D
	var radius = circle_shape.radius
	return radius * base_collision_scale.x * range_multiplier * Global.get_attack_range_multiplier()

func _find_most_dense_center(player_position: Vector2, search_radius_limit: float, cluster_radius: float) -> Vector2:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return player_position
	
	var candidates: Array = []
	for enemy in enemies:
		if player_position.distance_to(enemy.global_position) <= search_radius_limit:
			candidates.append(enemy)
	
	if candidates.is_empty():
		return player_position
	
	var best_count = 0
	var best_center = player_position
	
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

func _apply_rotation(player_position: Vector2, target_center: Vector2) -> void:
	var direction = target_center - player_position
	if direction == Vector2.ZERO:
		if PC.player_instance.sprite_direction_right:
			direction = Vector2.RIGHT
		else:
			direction = Vector2.LEFT
	target_direction = direction.normalized()
	rotation = target_direction.angle() + rotation_offset

func _physics_process(_delta: float) -> void:
	if not damage_active:
		return
	global_position = PC.player_instance.global_position
	rotation = target_direction.angle() + rotation_offset
	var hit_result = _apply_damage(cached_attack_data)
	if not effect_applied and hit_result.hit_count > 0:
		effect_applied = true
		_apply_heal(cached_attack_data, hit_result)
		_apply_shield(cached_attack_data, hit_result)

func _apply_damage(attack_data: Dictionary) -> Dictionary:
	var areas = get_overlapping_areas()
	var hit_count = 0
	var hit_bleed = false
	
	for area in areas:
		if not area.is_in_group("enemies"):
			continue
		var area_id = area.get_instance_id()
		if hit_targets.has(area_id):
			continue
		hit_targets[area_id] = true
		
		hit_count += 1
		var damage = attack_data.damage
		var is_crit = false
		var crit_roll = randf()
		if crit_roll < PC.crit_chance:
			is_crit = true
			damage = damage * Faze.get_sword_crit_damage_multiplier(PC.faze_sword_level)
		
		var has_bleed = area.debuff_manager.has_debuff("bleed")
		if has_bleed:
			damage = damage * (1.0 + attack_data.bleed_damage_bonus)
			hit_bleed = true
		
		# 添加流血效果
		if area.has_signal("debuff_applied"):
			area.emit_signal("debuff_applied", "bleed")
		
		area.take_damage(int(damage), is_crit, false, "blood_broadsword")
		# 击中粒子崩散特效
		HitParticleSpawner.spawn_by_weapon(get_tree(), area.global_position, "blood_broadsword")
		Faze.on_sword_weapon_hit(area)
	
	return {"hit_count": hit_count, "hit_bleed": hit_bleed}

func _apply_heal(attack_data: Dictionary, hit_result: Dictionary) -> void:
	if PC.is_game_over:
		return
	var missing_hp = PC.pc_max_hp - PC.pc_hp
	if missing_hp <= 0:
		return
	
	var heal_ratio = attack_data.heal_ratio
	if hit_result.hit_bleed:
		heal_ratio = heal_ratio * (1.0 + attack_data.heal_on_bleed_bonus)
	
	var heal_amount = int(ceil(missing_hp * heal_ratio * (1.0 + PC.heal_multi)))
	if heal_amount < attack_data.min_heal:
		heal_amount = attack_data.min_heal
	
	PC.pc_hp += heal_amount
	if PC.pc_hp > PC.pc_max_hp:
		PC.pc_hp = PC.pc_max_hp
	
	if heal_amount > 0:
		Global.emit_signal("player_heal", heal_amount, PC.player_instance.global_position)

func _apply_shield(attack_data: Dictionary, hit_result: Dictionary) -> void:
	if attack_data.shield_hit_count <= 0:
		return
	if hit_result.hit_count < attack_data.shield_hit_count:
		return
	
	var shield_amount = int(ceil(PC.pc_max_hp * attack_data.shield_ratio))
	if shield_amount < attack_data.shield_min:
		shield_amount = attack_data.shield_min
	
	PC.add_shield(shield_amount, attack_data.shield_duration)

func _spawn_repeat_attack(attack_data: Dictionary) -> void:
	var repeat_instance = broadsword_scene.instantiate()
	repeat_instance.set_custom_range_multiplier(attack_data.repeat_range_multiplier)
	repeat_instance.disable_repeat()
	# 第二刀动画水平镜像
	repeat_instance.sprite.flip_h = true
	get_tree().current_scene.add_child(repeat_instance)
