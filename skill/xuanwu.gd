extends Area2D

@export var sprite : AnimatedSprite2D
@export var collision : CollisionShape2D

enum State { FORWARD, RETURN, MISS }
var state = State.FORWARD

var direction = Vector2.RIGHT
var speed = 320.0
var damage = 0.0
var max_dist = 240.0
var traveled_dist = 0.0
var return_angle_offset = 0.0
var return_start_dist = 0.0 # Distance to player when starting return
var return_traveled_dist = 0.0
var miss_dist = 150.0
var miss_traveled = 0.0

var hit_abnormal = false # Track if we hit an enemy with abnormal status

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("area_entered", Callable(self, "_on_area_entered"))
	
	if PC.has_xuanwu:
		var atk_dmg = PC.pc_atk * PC.main_skill_xuanwu_damage
		var hp_dmg = PC.pc_max_hp * PC.xuanwu_hp_damage_ratio
		damage = atk_dmg + hp_dmg
		
		# Xuanwu2: Bonus damage per shield %
		if PC.xuanwu_shield_bonus_damage > 0:
			var shield_total = PC.get_total_shield()
			var shield_pct = 0.0
			if PC.pc_max_hp > 0:
				shield_pct = float(shield_total) / float(PC.pc_max_hp) * 100.0
			# "每有最大体力1%的护盾，玄武盾伤害提升3%" -> +3% * shield_pct
			damage *= (1.0 + (shield_pct * PC.xuanwu_shield_bonus_damage * 0.01))
		
		# Apply final total damage multiplier
		if PC.xuanwu_final_damage_multi > 1.0:
			damage *= PC.xuanwu_final_damage_multi
		
		max_dist = PC.xuanwu_range
		
		# Xuanwu4 / Xuanwu33: Width increase
		if PC.xuanwu_width_scale != 1.0:
			scale *= Vector2(PC.xuanwu_width_scale, PC.xuanwu_width_scale)

	return_angle_offset = deg_to_rad(randf_range(-3, 3))

func setup(pos: Vector2, target_pos: Vector2):
	global_position = pos
	direction = (target_pos - pos).normalized()
	rotation = direction.angle()

func _process(delta):
	# Rotate 360 degrees per second
	rotation += 4 * PI * delta
	
	var step = speed * delta
	
	if state == State.FORWARD:
		position += direction * step
		traveled_dist += step
		if traveled_dist >= max_dist:
			_start_return()
			
	elif state == State.RETURN:
		position += direction * step
		return_traveled_dist += step
		
		if return_traveled_dist > return_start_dist + 50:
			state = State.MISS
			
	elif state == State.MISS:
		position += direction * step
		miss_traveled += step
		modulate.a = 1.0 - (miss_traveled / miss_dist)
		if miss_traveled >= miss_dist:
			queue_free()

func _start_return():
	state = State.RETURN
	if PC.player_instance:
		var to_player = (PC.player_instance.global_position - global_position)
		return_start_dist = to_player.length()
		direction = to_player.normalized().rotated(return_angle_offset)
		# rotation = direction.angle() # Removed to allow continuous rotation
	else:
		queue_free()

func _on_area_entered(area: Area2D):
	_handle_hit(area)

func _on_body_entered(body: Node):
	_handle_hit(body)

func _handle_hit(target: Node):
	if target.is_in_group("enemies"):
		if target.has_method("take_damage"):
			var is_crit = false
			var final_damage = damage
			
			if randf() < PC.crit_chance:
				is_crit = true
				final_damage *= PC.crit_damage_multi
			
			# take_damage(damage: int, is_crit: bool, is_summon: bool, damage_type: String)
			target.take_damage(int(final_damage), is_crit, false, "xuanwu")
			
			# Check abnormal status (for Xuanwu22)
			if target.get("debuff_manager") and target.debuff_manager.active_debuffs.size() > 0:
				hit_abnormal = true
			
			# Apply Xuanwu3 Slow
			if PC.xuanwu_slow_duration > 0:
				if target.has_signal("debuff_applied"):
					target.emit_signal("debuff_applied", "slow")
			
			# Apply Xuanwu4 Vulnerable
			if PC.xuanwu_vulnerable_duration > 0:
				if target.has_signal("debuff_applied"):
					target.emit_signal("debuff_applied", "vulnerable")
				
	elif target.is_in_group("player"):
		if state == State.RETURN:
			_apply_shield()
			queue_free()

func _apply_shield():
	var shield_val = float(PC.xuanwu_shield_base) + (float(PC.pc_max_hp) * PC.xuanwu_shield_hp_ratio)
	
	# Xuanwu22: Return shield +30% if hit abnormal
	if PC.xuanwu_return_shield_bonus > 0 and hit_abnormal:
		shield_val *= (1.0 + PC.xuanwu_return_shield_bonus)
		
	PC.add_shield(int(shield_val), 6.0)
