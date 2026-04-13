extends Area2D
class_name HolyLight

@export var sprite: AnimatedSprite2D
@export var collision: CollisionShape2D

static var main_skill_holylight_damage: float = 0.85
static var holylight_final_damage_multi: float = 1.0
static var holylight_range_scale: float = 1.0
static var holylight_duration: float = 2.0
static var holylight_center_extra_damage: float = 0.0
static var holylight_heal_base: int = 30
static var holylight_heal_ratio: float = 0.03
static var holylight_dot_damage: float = 0.0
static var holylight_interval: float = 3.2
static var holylight_size_multiplier: float = 1.2
static var holylight_vulnerable_damage_bonus: float = 0.0
static var holylight_vulnerable_crit: bool = false

static func reset_data() -> void:
	main_skill_holylight_damage = 0.85
	holylight_final_damage_multi = 1.0
	holylight_range_scale = 1.0
	holylight_duration = 1.0
	holylight_center_extra_damage = 0.0
	holylight_heal_base = 30
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
var base_collision_scale: Vector2 = Vector2.ONE

var elapsed_time: float = 0.0 # 填充进度计时器
var draw_rotation: float = 0.0 # 仅十字架旋转，椭圆外形保持不动

var circle_color = Color(1, 1, 0.6, 0.45) # 浅黄色
var radius: float = 0.0
var x_radius: float = 0.0

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
	var life_range_multiplier = Faze.get_life_range_multiplier(PC.faze_life_level)
	# 伤害仅由奖励直接累加（main_skill_holylight_damage），不再叠加生灵法则乘数，避免奖励加成 × 法则加成的双重放大
	var damage_multiplier = main_skill_holylight_damage * holylight_final_damage_multi
	var build_range_scale = holylight_range_scale * holylight_size_multiplier * life_range_multiplier
	var build_duration = holylight_duration
	var build_heal_base = holylight_heal_base
	var build_heal_ratio = holylight_heal_ratio
	var build_center_extra_damage = holylight_center_extra_damage
	var dot_damage_ratio = holylight_dot_damage
	var build_vulnerable_damage_bonus = holylight_vulnerable_damage_bonus
	var build_vulnerable_crit = holylight_vulnerable_crit
	
	var build_damage = PC.pc_atk * damage_multiplier
	var build_dot_damage = PC.pc_atk * dot_damage_ratio
	
	# 估算半径用于索敌 (假设基础半径100)
	var build_radius = 100.0 * build_range_scale
	
	return {
		"damage": build_damage,
		"range_scale": build_range_scale,
		"duration": build_duration,
		"heal_base": build_heal_base,
		"heal_ratio": build_heal_ratio,
		"center_extra_damage": build_center_extra_damage,
		"dot_damage": build_dot_damage,
		"vulnerable_damage_bonus": build_vulnerable_damage_bonus,
		"vulnerable_crit": build_vulnerable_crit,
		"radius": build_radius
	}

func setup(pos: Vector2, p_damage: float, p_heal_base: int, p_heal_ratio: float, p_duration: float, p_range_scale: float, options: Dictionary = {}) -> void:
	global_position = pos
	damage = p_damage
	heal_base = p_heal_base
	heal_ratio = p_heal_ratio
	duration = p_duration
	range_scale = p_range_scale * Global.get_attack_range_multiplier() # 统一叠加全局攻击范围倍率
	
	center_extra_damage = options.get("center_extra_damage", 0.0)
	dot_damage = options.get("dot_damage", 0.0)
	vulnerable_damage_bonus = options.get("vulnerable_damage_bonus", 0.0)
	vulnerable_crit = options.get("vulnerable_crit", false)
	
	if not collision:
		collision = get_node_or_null("CollisionShape2D")
	if collision:
		base_collision_scale = collision.scale
	
	if collision and collision.shape is CircleShape2D:
		radius = collision.shape.radius * range_scale + 5 # Y半径（碰撞范围+5px）
		x_radius = collision.shape.radius * range_scale * 1.3 + 5 # X半径（X轴1.3倍）
		# 椭圆碰撞体：X轴拉伸1.3倍
		collision.scale = Vector2(base_collision_scale.x * range_scale * 1.3, base_collision_scale.y * range_scale)
	else:
		radius = 100.0 * range_scale + 5
		x_radius = 100.0 * range_scale * 1.3 + 5
	
	# 初始状态
	scale = Vector2.ZERO
	rotation = 0
	
	# 进场动画：从中心点开始逐渐生成，0.5秒内扩大至全部范围
	var tween = create_tween()
	tween.tween_property(self , "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	monitoring = true
	monitorable = true
	
	# 倒计时结束前闪烁并消失
	get_tree().create_timer(duration).timeout.connect(_on_burst)

func _process(delta: float) -> void:
	# 仅旋转绘制层（十字架），不旋转节点本身，保持椭圆形状固定
	draw_rotation += PI * delta
	elapsed_time += delta
	queue_redraw()

func _draw() -> void:
	const P: int = 2
	# 填充进度 0→1，对应从空到满
	var fill_progress: float = clamp(elapsed_time / max(duration, 0.01), 0.0, 1.0)

	# 颜色
	var col_ring_a = Color(1.00, 1.00, 0.60, 0.92) # 外圈浅黄-亮
	var col_ring_b = Color(1.00, 0.95, 0.40, 0.78) # 外圈浅黄-暗（棋盘交替）
	var col_inner = Color(1.00, 1.00, 0.55, 0.20) # 内圈低透明浅黄
	var col_edge = Color(1.00, 1.00, 0.80, 0.62) # 填充前沿高亮
	var col_cross = Color(1.00, 1.00, 0.68, 0.96) # 十字架

	# 椭圆半轴：X=x_radius，Y=radius（87%处为内圈边界）
	var x_split: float = x_radius * 0.87
	var y_split: float = radius * 0.87

	# 预计算倒数，避免循环内重复除法
	var inv_xr2: float = 1.0 / (x_radius * x_radius) if x_radius > 0.01 else 0.0
	var inv_yr2: float = 1.0 / (radius * radius) if radius > 0.01 else 0.0
	var inv_xs2: float = 1.0 / (x_split * x_split) if x_split > 0.01 else 0.0
	var inv_ys2: float = 1.0 / (y_split * y_split) if y_split > 0.01 else 0.0

	# 填充前沿宽度（归一化椭圆坐标系，约4px宽）
	var edge_band: float = float(P) * 2.0 / min(x_split, y_split) if min(x_split, y_split) > 0.01 else 0.12

	var gx: int = - int(x_radius) - P
	while gx < int(x_radius) + P:
		var gy: int = - int(radius) - P
		while gy < int(radius) + P:
			var cx: float = gx + P * 0.5
			var cy: float = gy + P * 0.5
			# 外椭圆归一化距离²：≤1.0 表示在外圈内
			var de: float = cx * cx * inv_xr2 + cy * cy * inv_yr2
			if de <= 1.0:
				var rect = Rect2(gx, gy, P, P)
				var gxi: int = int(gx / float(P))
				var gyi: int = int(gy / float(P))
				# 内椭圆归一化距离²：>1.0 表示在外圈区域
				var ds: float = cx * cx * inv_xs2 + cy * cy * inv_ys2
				if ds > 1.0:
					# 外圈：双色棋盘浅黄，完整实心
					if (gxi + gyi) % 2 == 0:
						draw_rect(rect, col_ring_a)
					else:
						draw_rect(rect, col_ring_b)
				else:
					# 内圈：归一化距离（0=圆心→1=内圈边界）判断填充进度
					var ds_norm: float = sqrt(ds)
					if ds_norm <= fill_progress:
						draw_rect(rect, col_inner)
					elif fill_progress > 0.0 and ds_norm <= fill_progress + edge_band:
						draw_rect(rect, col_edge)
			gy += P
		gx += P

	# 十字架（中间偏上，仅十字架随 draw_rotation 旋转，外圈不转）
	draw_set_transform(Vector2.ZERO, draw_rotation)
	var c_x: float = 0.0
	var c_y: float = - radius * 0.24 # 十字架中心（偏上）
	var v_half: float = radius * 0.26 # 竖轴半高
	var h_half: float = radius * 0.13 # 横轴半宽
	var bar_w: float = P * 2.0 # 两轴宽度 4px
	# 横轴位置：从竖轴顶端向下 30% 处
	var h_y: float = c_y - v_half + (v_half * 2.0) * 0.30
	# 竖轴
	draw_rect(Rect2(c_x - bar_w * 0.5, c_y - v_half, bar_w, v_half * 2.0), col_cross)
	# 横轴
	draw_rect(Rect2(c_x - h_half, h_y - bar_w * 0.5, h_half * 2.0, bar_w), col_cross)
	# 重置变换，避免影响后续绘制
	draw_set_transform(Vector2.ZERO, 0.0)

func _on_burst() -> void:
	if not is_instance_valid(self ):
		return
	
	# 闪烁并提高曝光度后消失
	var tween = create_tween()
	tween.tween_property(self , "modulate", Color(3, 3, 3, 1), 0.08)
	tween.tween_property(self , "modulate", Color(2.4, 2.4, 2.4, 1), 0.1)
	tween.tween_property(self , "modulate:a", 0.0, 0.2)
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
