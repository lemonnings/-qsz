extends Area2D

@export var damage_interval: float = 1.0 # 赤曜伤害频率：1秒/次

var player_node: Node2D
@export var damage_timer: Timer
var is_initialized: bool = false
var draw_node: Node2D
var collision_shape: CollisionShape2D
var current_range_multiplier: float = 1.0
var current_speed_multiplier: float = 1.0

func _ready() -> void:
	Global.connect("riyan_damage_triggered", Callable(self , "_on_get_riyan"))

func _process(delta: float) -> void:
	if player_node:
		global_position = player_node.global_position

func _on_damage_timer_timeout() -> void:
	if player_node:
		_check_updates()
		
		# 基础系数 0.06
		var hp_damage_ratio = PC.riyan_hp_max_damage
		# Riyan22: 35% (0.105)
		if PC.selected_rewards.has("Riyan22"):
			hp_damage_ratio = 0.105
		# Riyan2: 30% (0.09)
		elif PC.selected_rewards.has("Riyan2"):
			hp_damage_ratio = 0.09
			
		var damage_amount: float = (PC.pc_atk * PC.riyan_atk_damage) + (PC.pc_max_hp * hp_damage_ratio)
		damage_amount = damage_amount * PC.main_skill_riyan_damage
		damage_amount = damage_amount * Faze.get_fire_weapon_damage_multiplier(PC.faze_fire_level)
		
		# Riyan1 / Riyan11: 减伤转化伤害
		var dr_bonus = 0.0
		var dr_rate = PC.damage_reduction_rate
		if PC.selected_rewards.has("Riyan11"):
			dr_bonus = min(dr_rate * 1.5, 0.6)
		elif PC.selected_rewards.has("Riyan1"):
			dr_bonus = min(dr_rate, 0.3)
		damage_amount *= (1.0 + dr_bonus)
		
		for area in get_overlapping_areas():
			if area.is_in_group("enemies") and area.has_method("take_damage"):
				var final_damage = damage_amount
				
				# Riyan33: 对燃烧敌人额外伤害
				if PC.selected_rewards.has("Riyan33"):
					if _has_burn(area):
						final_damage *= 1.6
						
				area.take_damage(final_damage, false, false, "riyan")

func _has_burn(enemy) -> bool:
	if enemy.get("debuff_manager") and enemy.debuff_manager.has_method("has_debuff"):
		return enemy.debuff_manager.has_debuff("burn")
	return false

func _check_updates() -> void:
	# Check range (Riyan3)
	var new_range_mult = 1.0
	if PC.selected_rewards.has("Riyan3"):
		new_range_mult = 1.2
	
	if new_range_mult != current_range_multiplier:
		current_range_multiplier = new_range_mult
		_update_visuals()
		
	# Check speed (Riyan4)
	var new_speed_mult = 1.0
	if PC.selected_rewards.has("Riyan4"):
		new_speed_mult = 1.25
		
	if new_speed_mult != current_speed_multiplier:
		current_speed_multiplier = new_speed_mult
		damage_timer.wait_time = PC.riyan_cooldown / current_speed_multiplier

func _update_visuals() -> void:
	var radius = PC.riyan_range * current_range_multiplier
	if collision_shape and collision_shape.shape:
		collision_shape.shape.radius = radius
	if draw_node:
		draw_node.queue_redraw()

func _exit_tree() -> void:
	if damage_timer and is_instance_valid(damage_timer):
		remove_child(damage_timer)
		damage_timer.queue_free()

func _on_get_riyan():
	if is_initialized:
		return
	
	player_node = get_tree().get_first_node_in_group("player")
	global_position = player_node.global_position
	
	collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = PC.riyan_range
	collision_shape.shape = circle_shape
	add_child(collision_shape)
	
	collision_layer = 0
	
	draw_node = Node2D.new()
	add_child(draw_node)
	draw_node.draw.connect(func():
		var radius = PC.riyan_range * current_range_multiplier
		var color_fill = Color(1.0, 0.6, 0.0, 0.2)
		var color_border = Color(1.0, 0.6, 0.0, 0.5)
		var border_width = 2.0
		draw_node.draw_circle(Vector2.ZERO, radius, color_fill)
		draw_node.draw_arc(Vector2.ZERO, radius, 0, PI * 2, 64, color_border, border_width, true)
		draw_node.z_index = -1
	)
	
	damage_timer.wait_time = PC.riyan_cooldown
	damage_timer.start()
	set_process(true)
	is_initialized = true
