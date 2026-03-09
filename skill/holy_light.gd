extends Area2D
class_name HolyLight

@export var sprite : AnimatedSprite2D
@export var collision : CollisionShape2D

static var main_skill_holylight_damage: float = 0.7
static var holylight_final_damage_multi: float = 1.0
static var holylight_range_scale: float = 1.0
static var holylight_duration: float = 2.0
static var holylight_center_extra_damage: float = 0.0
static var holylight_heal_base: int = 3
static var holylight_heal_ratio: float = 0.03
static var holylight_dot_damage: float = 0.0
static var holylight_interval: float = 3.2
static var holylight_size_multiplier: float = 1.2
static var holylight_vulnerable_damage_bonus: float = 0.0
static var holylight_vulnerable_crit: bool = false

static func reset_data() -> void:
	main_skill_holylight_damage = 0.7
	holylight_final_damage_multi = 1.0
	holylight_range_scale = 1.0
	holylight_duration = 1.0
	holylight_center_extra_damage = 0.0
	holylight_heal_base = 3
	holylight_heal_ratio = 0.03
	holylight_dot_damage = 0.0
	holylight_interval = 3.2
	holylight_size_multiplier = 1.2
	holylight_vulnerable_damage_bonus = 0.0
	holylight_vulnerable_crit = false

var damage: float = 0.0
var heal_base: int = 0
var heal_ratio: float = 0.0
var duration: float = 3.0
var center_extra_damage: float = 0.0
var dot_damage: float = 0.0
var range_scale: float = 1.0
var vulnerable_damage_bonus: float = 0.0
var vulnerable_crit: bool = false

var circle_color = Color(1, 1, 0.6, 0.45) # 浅黄色
var radius: float = 0.0

static func fire_skill(scene: PackedScene, origin_pos: Vector2, tree: SceneTree) -> void:
	if not scene:
		return
		
	var data = _build_data()
	# 索敌范围150
	var target_pos = _find_best_target_pos(origin_pos, tree, 150.0, data.radius)
	
	var instance = scene.instantiate()
	tree.current_scene.add_child(instance)
	
	var options = {
		"center_extra_damage": data.center_extra_damage,
		"dot_damage": data.dot_damage,
		"vulnerable_damage_bonus": data.vulnerable_damage_bonus,
		"vulnerable_crit": data.vulnerable_crit
	}
	
	instance.setup(target_pos, data.damage, data.heal_base, data.heal_ratio, data.duration, data.range_scale, options)

static func _find_best_target_pos(origin: Vector2, tree: SceneTree, search_range: float, skill_radius: float) -> Vector2:
	var enemies = tree.get_nodes_in_group("enemies")
	var candidates = []
	var search_range_sq = search_range * search_range
	
	# 筛选范围内的敌人
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_squared_to(origin) <= search_range_sq:
			candidates.append(enemy)
			
	if candidates.is_empty():
		# 如果没有敌人，在玩家位置生成
		var player = tree.get_first_node_in_group("player")
		if player:
			return player.global_position
		return origin
		
	# 寻找敌人最密集点
	var best_pos = candidates[0].global_position
	var max_count = 0
	var skill_radius_sq = skill_radius * skill_radius
	
	for center_candidate in candidates:
		var count = 0
		var pos = center_candidate.global_position
		for other in candidates:
			if pos.distance_squared_to(other.global_position) <= skill_radius_sq:
				count += 1
		
		if count > max_count:
			max_count = count
			best_pos = pos
			
	return best_pos

static func _build_data() -> Dictionary:
	var life_damage_multiplier = Faze.get_life_damage_multiplier(PC.faze_life_level)
	var life_range_multiplier = Faze.get_life_range_multiplier(PC.faze_life_level)
	var damage_multiplier = main_skill_holylight_damage * holylight_final_damage_multi * life_damage_multiplier
	var range_scale = holylight_range_scale * holylight_size_multiplier * life_range_multiplier
	var duration = holylight_duration
	var heal_base = holylight_heal_base
	var heal_ratio = holylight_heal_ratio
	var center_extra_damage = holylight_center_extra_damage
	var dot_damage_ratio = holylight_dot_damage
	var vulnerable_damage_bonus = holylight_vulnerable_damage_bonus
	var vulnerable_crit = holylight_vulnerable_crit
	
	var damage = PC.pc_atk * damage_multiplier
	var dot_damage = PC.pc_atk * dot_damage_ratio
	
	# 估算半径用于索敌 (假设基础半径100)
	var radius = 100.0 * range_scale
	
	return {
		"damage": damage,
		"range_scale": range_scale,
		"duration": duration,
		"heal_base": heal_base,
		"heal_ratio": heal_ratio,
		"center_extra_damage": center_extra_damage,
		"dot_damage": dot_damage,
		"vulnerable_damage_bonus": vulnerable_damage_bonus,
		"vulnerable_crit": vulnerable_crit,
		"radius": radius
	}

func setup(pos: Vector2, p_damage: float, p_heal_base: int, p_heal_ratio: float, p_duration: float, p_range_scale: float, options: Dictionary = {}) -> void:
	global_position = pos
	damage = p_damage
	heal_base = p_heal_base
	heal_ratio = p_heal_ratio
	duration = p_duration
	range_scale = p_range_scale * holylight_size_multiplier
	
	center_extra_damage = options.get("center_extra_damage", 0.0)
	dot_damage = options.get("dot_damage", 0.0)
	vulnerable_damage_bonus = options.get("vulnerable_damage_bonus", 0.0)
	vulnerable_crit = options.get("vulnerable_crit", false)
	
	if not collision:
		collision = get_node_or_null("CollisionShape2D")
	
	if collision and collision.shape is CircleShape2D:
		radius = collision.shape.radius * range_scale + 5 # collision范围+5像素
		# 调整collision scale
		collision.scale = Vector2(range_scale, range_scale)
	else:
		radius = 100.0 * range_scale + 5 # 默认值
	
	# 初始状态
	scale = Vector2.ZERO
	rotation = 0
	
	# 进场动画：从中心点开始逐渐生成，0.5秒内扩大至全部范围
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	monitoring = true
	monitorable = true
	
	# 倒计时结束前闪烁并消失
	get_tree().create_timer(duration).timeout.connect(_on_burst)

func _process(delta: float) -> void:
	# 旋转：每2秒旋转360度
	rotation += PI * delta 
	
	queue_redraw()

func _draw() -> void:
	# 绘制光圈
	# 填充一个透明度是0.45的浅黄色光圈，向外渐变透明
	# 简单模拟：绘制多层不同透明度的圆
	var steps = 10
	for i in range(steps):
		var r = radius * (float(steps - i) / steps)
		var alpha = circle_color.a * (float(i + 1) / steps)
		var color = circle_color
		color.a = alpha * 0.15 # 调整透明度使其叠加后接近目标
		draw_circle(Vector2.ZERO, r, color)
		
	# 绘制最外圈
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, circle_color, 2.0)

func _on_burst() -> void:
	if not is_instance_valid(self):
		return
	
	# 闪烁并提高曝光度后消失
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(3, 3, 3, 1), 0.08)
	tween.tween_property(self, "modulate", Color(2.4, 2.4, 2.4, 1), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.finished.connect(_on_burst_finished)

func _on_burst_finished() -> void:
	_apply_end_damage_and_heal()
	queue_free()

func _apply_end_damage_and_heal() -> void:
	var areas = get_overlapping_areas()
	for area in areas:
		if area.is_in_group("enemies") and area.has_method("take_damage"):
			var final_damage = damage
			if center_extra_damage > 0:
				final_damage = damage * (1.0 + center_extra_damage)
			var is_vulnerable = false
			if area.get("debuff_manager") and area.debuff_manager.has_method("has_debuff"):
				is_vulnerable = area.debuff_manager.has_debuff("vulnerable")
			var is_crit = false
			if is_vulnerable and vulnerable_damage_bonus > 0:
				final_damage *= 1.0 + vulnerable_damage_bonus
			if is_vulnerable and vulnerable_crit:
				is_crit = true
				final_damage *= PC.crit_damage_multi
			area.take_damage(int(final_damage), is_crit, false, "holylight")
	var bodies = get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("player") and body.has_method("heal"):
			var heal_val = heal_base + int(PC.pc_max_hp * heal_ratio)
			var heal_multiplier = 1.0 + PC.heal_multi
			heal_val = int(ceil(float(heal_val) * heal_multiplier))
			body.heal(heal_val)
			if heal_val > 0:
				Global.emit_signal("player_heal", heal_val, body.global_position)
