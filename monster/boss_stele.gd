extends "res://Script/monster/monster_base.gd"

# ================= 被封印的石碑 (boss_stele.gd) =================
# 核心机制：暗影拘束、位移置换、高额腐蚀伤害

var is_attacking: bool = false

# 属性配置
var speed: float = 0.0 # 石碑不移动
var hpMax: float = SettingMoster.stone_man("hp") * 180
var hp: float = hpMax
var atk: float = SettingMoster.stone_man("atk") * 1.6
var get_point: int = SettingMoster.stone_man("point") * 75
var get_exp: int = 0

var attack_timer: Timer
var restrainers: Array = [] # 存储所有的拘束器
var hp_milestones: Array = [0.8, 0.55, 0.3] # 生成拘束器的血量比例
var spawned_milestones: Array = [false, false, false]

const RESTRAINER_MIN_GAP := 68.0
const DISPLACEMENT_SAFE_RADIUS := 65.0
const DISPLACEMENT_DAMAGE_RADIUS := 400.0
const TORNADO_RADIUS := 28.0

# 技能循环池
var skill_queue: Array = []
@onready var sprite = $BossStone # 使用与 boss_stone 相同的节点结构
var phase1_next_skill_is_ray: bool = true


func _ready():
	add_to_group("boss")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	hp = hpMax

	setup_monster_base()
	player_hit_emit_self = true
	use_debuff_take_damage_multiplier = false
	check_action_disabled_on_body_entered = false

	# 设置碰撞层
	collision_layer = 4
	collision_mask = 2

	CharacterEffects.create_shadow(self, 60.0, 15.0, 20.0)

	Global.emit_signal("boss_hp_bar_initialize", hpMax, hp, 12, "被封印的石碑")
	Global.emit_signal("boss_hp_bar_show")

	attack_timer = Timer.new()
	add_child(attack_timer)
	attack_timer.wait_time = 2.0
	attack_timer.timeout.connect(_choose_attack)
	attack_timer.start()
	
	if sprite and sprite.has_method("play"):
		sprite.play("idle")

func _physics_process(_delta: float) -> void:
	if is_dead: return
	
	if is_instance_valid(sprite):
		sprite.position.y = sin(Time.get_ticks_msec() * 0.003) * 12.0
	
	if is_attacking:
		attack_timer.paused = true
	else:
		attack_timer.paused = false

# ================= 技能管理逻辑 =================

func _choose_attack():
	if is_dead: return
	is_attacking = true
	
	var r_count = restrainers.size()
	
	if r_count == 0:
		# 射线和下压轮换
		var skill_id = 1 if phase1_next_skill_is_ray else 4
		phase1_next_skill_is_ray = not phase1_next_skill_is_ray
		_execute_skill(skill_id)
	else:
		# 全技能循环
		if skill_queue.is_empty():
			_refill_skill_queue(r_count)
		
		var skill_id = skill_queue.pop_front()
		_execute_skill(skill_id)

func _refill_skill_queue(r_count: int):
	skill_queue = [1, 3, 4, 5, 6]
	if r_count >= 2:
		skill_queue.append(7)
	skill_queue.shuffle()

func _execute_skill(skill_id: int):
	match skill_id:
		1: _skill_corrosive_ray()
		3: _skill_corrosive_storm()
		4: _skill_corrosive_slam()
		5: _skill_shadow_tornado()
		6: _skill_shadow_displacement()
		7: _skill_shadow_resonance()
		_: is_attacking = false

# ================= 技能具体实现 =================

## 1. 腐蚀射线 (宽度翻倍)
func _skill_corrosive_ray():
	Global.emit_signal("boss_chant_start", "腐蚀射线", 1.5)
	
	var warn_l = WarnRectUtil.new(); get_tree().current_scene.add_child(warn_l)
	var warn_r = WarnRectUtil.new(); get_tree().current_scene.add_child(warn_r)
	
	warn_l.attacker = self
	warn_r.attacker = self
	
	var ray_width = 160.0
	warn_l.start_warning(global_position, global_position + Vector2(-800, 0), ray_width, 1.5, atk * 1.2)
	warn_r.start_warning(global_position, global_position + Vector2(800, 0), ray_width, 1.5, atk * 1.2)
	
	await get_tree().create_timer(1.5).timeout
	if is_dead: return
	
	_screen_shake(6.0, 0.4)
	var effect = _RayEffect.new()
	effect.global_position = global_position
	effect.ray_width = ray_width
	get_tree().current_scene.add_child(effect)
	
	await get_tree().create_timer(0.6).timeout
	is_attacking = false

## 3. 腐蚀风暴 (长读条4秒, 500%伤害, 滤镜)
func _skill_corrosive_storm():
	Global.emit_signal("boss_chant_start", "腐蚀风暴", 4.0)
	
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	var filter = ColorRect.new()
	filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	filter.color = Color(0.0, 0.4, 0.1, 0.0)
	canvas.add_child(filter)
	get_tree().current_scene.add_child(canvas)
	
	var tw = create_tween()
	tw.tween_property(filter, "color:a", 0.3, 3.5)
	
	var elapsed = 0.0
	while elapsed < 4.0:
		if is_dead: break
		_spawn_particles(global_position + Vector2(randf_range(-400, 400), randf_range(-300, 300)), Color(0.05, 0.2, 0.05), 4, 60.0)
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	
	if not is_dead:
		_screen_shake(10.0, 0.8)
		if is_instance_valid(PC.player_instance) and not PC.invincible:
			var final_dmg = int(atk * 5.0 * (1.0 - PC.damage_reduction_rate))
			PC.apply_damage(final_dmg)
			Global.emit_signal("player_hit", self)
			
	if is_instance_valid(canvas) and is_instance_valid(filter):
		var tw2 = create_tween()
		tw2.tween_property(filter, "color:a", 0.0, 0.2)
		tw2.tween_callback(canvas.queue_free)
	
	is_attacking = false

## 4. 腐蚀下压 (扇形攻击，修正预警范围)
func _skill_corrosive_slam():
	Global.emit_signal("boss_chant_start", "腐蚀下压", 2.0)
	
	var range_dist = 800.0
	
	# 第一阶段：左上(225/-135)和右下(45)
	var w1 = WarnSectorUtil.new(); get_tree().current_scene.add_child(w1)
	var w2 = WarnSectorUtil.new(); get_tree().current_scene.add_child(w2)
	w1.attacker = self
	w2.attacker = self
	w1.start_warning(global_position, global_position + Vector2(-1, -1).normalized() * range_dist, 90.0, 1.0, atk)
	w2.start_warning(global_position, global_position + Vector2(1, 1).normalized() * range_dist, 90.0, 1.0, atk)
	
	await get_tree().create_timer(1.0).timeout
	if is_dead: return
	
	_spawn_particles_in_sectors(global_position, [-PI*0.75, PI*0.25], Color(0.3, 0.0, 0.4), 60, range_dist)
	
	# 第二阶段：右上(315/-45)和左下(135)
	var w3 = WarnSectorUtil.new(); get_tree().current_scene.add_child(w3)
	var w4 = WarnSectorUtil.new(); get_tree().current_scene.add_child(w4)
	w3.attacker = self
	w4.attacker = self
	w3.start_warning(global_position, global_position + Vector2(1, -1).normalized() * range_dist, 90.0, 1.0, atk)
	w4.start_warning(global_position, global_position + Vector2(-1, 1).normalized() * range_dist, 90.0, 1.0, atk)
	
	await get_tree().create_timer(1.0).timeout
	if is_dead: return
	_spawn_particles_in_sectors(global_position, [-PI*0.25, PI*0.75], Color(0.3, 0.0, 0.4), 60, range_dist)
	
	is_attacking = false

## 5. 暗影龙卷 (连发3次)
func _skill_shadow_tornado():
	Global.emit_signal("boss_chant_start", "暗影龙卷", 3.0)
	for i in range(3):
		if is_dead: break
		var p_pos = PC.player_instance.global_position if is_instance_valid(PC.player_instance) else global_position
		var tornado = _ShadowTornado.new()
		tornado.global_position = p_pos
		tornado.attacker = self
		tornado.damage_val = atk * 1.5
		get_tree().current_scene.add_child(tornado)
		await get_tree().create_timer(1.0).timeout
	is_attacking = false

## 6. 暗影置换
func _skill_shadow_displacement():
	var active_restrainers = _get_active_restrainers()
	if active_restrainers.is_empty():
		is_attacking = false
		return
		
	Global.emit_signal("boss_chant_start", "暗影置换", 2.0)
	var target_r = active_restrainers[randi() % active_restrainers.size()]
	
	var icon = _TargetIcon.new()
	target_r.add_child(icon)
	
	var ring_warn = _DisplacementRingWarn.new()
	ring_warn.global_position = target_r.global_position
	ring_warn.inner_radius = DISPLACEMENT_SAFE_RADIUS
	ring_warn.outer_radius = DISPLACEMENT_DAMAGE_RADIUS
	ring_warn.duration = 2.0
	get_tree().current_scene.add_child(ring_warn)
	
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(icon):
		icon.queue_free()
	if is_instance_valid(ring_warn):
		ring_warn.queue_free()
	if is_dead or not is_instance_valid(target_r):
		is_attacking = false
		return
	
	global_position = target_r.global_position
	_screen_shake(8.0, 0.5)
	
	# 环形爆炸特效 (脚下安全，外圈受击)
	for i in range(60):
		var angle = randf() * TAU
		var dist = randf_range(DISPLACEMENT_SAFE_RADIUS, DISPLACEMENT_DAMAGE_RADIUS)
		var spawn_pos = global_position + Vector2(cos(angle), sin(angle)) * dist
		var p = _PixelDot.new()
		p.color = Color(0.5, 0.0, 0.8)
		p.global_position = spawn_pos
		get_tree().current_scene.add_child(p)
		var target = spawn_pos + Vector2(0, -randf_range(10, 40))
		var tw = p.create_tween().set_parallel(true)
		tw.tween_property(p, "global_position", target, 0.5)
		tw.tween_property(p, "modulate:a", 0.0, 0.5)
		tw.finished.connect(p.queue_free)
	
	# 环形伤害判定 (脚下安全)
	if is_instance_valid(PC.player_instance) and not PC.invincible:
		var dist = global_position.distance_to(PC.player_instance.global_position)
		if dist > DISPLACEMENT_SAFE_RADIUS and dist <= DISPLACEMENT_DAMAGE_RADIUS:
			PC.apply_damage(int(atk * 1.5 * (1.0 - PC.damage_reduction_rate)))
			Global.emit_signal("player_hit", self)
			if PC.pc_hp <= 0 and is_instance_valid(PC.player_instance):
				PC.player_instance.game_over()
			
	is_attacking = false


## 7. 暗影共鸣
func _skill_shadow_resonance():
	Global.emit_signal("boss_chant_start", "暗影共鸣", 2.0)
	var points = [global_position]
	for r in restrainers: if is_instance_valid(r): points.append(r.global_position)
	
	for p in points:
		var warn = WarnCircleUtil.new(); get_tree().current_scene.add_child(warn)
		warn.attacker = self
		warn.start_warning(p, 1.0, 160.0, 2.0, atk * 1.2, null, WarnCircleUtil.ReleaseMode.INSTANT_DAMAGE)
		
	await get_tree().create_timer(2.0).timeout
	if is_dead: return
	_screen_shake(7.0, 0.35)
	for p in points:
		_spawn_particles(p, Color(0.7, 0.0, 1.0), 35, 160.0)

		
	is_attacking = false

# ================= 机制管理 =================

func _check_milestones(old_h, new_h):
	for i in range(hp_milestones.size()):
		var threshold = hpMax * hp_milestones[i]
		if not spawned_milestones[i] and old_h > threshold and new_h <= threshold:
			spawned_milestones[i] = true
			_spawn_restrainer()

func _get_active_restrainers() -> Array:
	var active: Array = []
	for r in restrainers:
		if is_instance_valid(r):
			active.append(r)
	restrainers = active
	return active

func _can_place_restrainer(pos: Vector2) -> bool:
	for other in _get_active_restrainers():
		if pos.distance_to(other.global_position) < RESTRAINER_MIN_GAP:
			return false
	return true

func _find_restrainer_spawn_position() -> Vector2:
	if _can_place_restrainer(global_position):
		return global_position
	
	var anchor = global_position
	if is_instance_valid(PC.player_instance):
		anchor = global_position.lerp(PC.player_instance.global_position, 0.25)
	
	for ring_idx in range(1, 6):
		var radius = 72.0 + ring_idx * 52.0
		var start_angle = randf() * TAU
		for step in range(8):
			var angle = start_angle + step * TAU / 8.0
			var candidate = anchor + Vector2.RIGHT.rotated(angle) * radius
			if _can_place_restrainer(candidate):
				return candidate
	
	return global_position + Vector2(0, 120)

func _spawn_restrainer():
	var spawn_pos = _find_restrainer_spawn_position()
	var restrainer = _ShadowRestrainer.new()
	restrainer.global_position = spawn_pos
	get_tree().current_scene.add_child(restrainer)
	_spawn_particles(spawn_pos, Color(0.35, 0.0, 0.5), 24, 80.0)
	_screen_shake(3.0, 0.15)
	
	for other in _get_active_restrainers():
		if spawn_pos.distance_to(other.global_position) < RESTRAINER_MIN_GAP:
			_explode_restrainers(restrainer, other)
			return
			
	restrainers.append(restrainer)

func _explode_restrainers(r1, r2):
	var pos = (r1.global_position + r2.global_position) / 2.0
	_screen_shake(15.0, 1.0)
	_spawn_particles(pos, Color.WHITE, 80, 300.0)
	
	if is_instance_valid(PC.player_instance):
		if pos.distance_to(PC.player_instance.global_position) < 220.0:
			PC.apply_damage(int(atk * 3.5 * (1.0 - PC.damage_reduction_rate)))
			if PC.pc_hp <= 0 and is_instance_valid(PC.player_instance):
				PC.player_instance.game_over()
			
	if restrainers.has(r1): restrainers.erase(r1)
	if restrainers.has(r2): restrainers.erase(r2)
	r1.queue_free()
	r2.queue_free()


# ================= 基础交互与攻击判定 =================

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("bullet") and area.has_method("get_bullet_damage_and_crit_status"):
		var collision_result = BulletCalculator.handle_bullet_collision_full(area, self, true)
		var final_damage_val = collision_result["final_damage"]
		var is_crit = collision_result["is_crit"]

		Global.emit_signal("boss_hp_bar_take_damage", final_damage_val)
		hp -= int(final_damage_val)
		
		_check_milestones(hp + final_damage_val, hp)

		if collision_result["should_rebound"]:
			area.call_deferred("create_rebound")
		if collision_result["should_delete_bullet"]:
			area.queue_free()

		if hp <= 0:
			_die()
		else:
			Global.play_hit_anime(position, is_crit)

func take_damage(damage: int, is_crit: bool, is_summon: bool, damage_type: String) -> void:
	if is_dead: return
	var old_h = hp
	var damage_result = apply_common_take_damage(damage, is_crit, is_summon, damage_type, {
		"use_debuff_multiplier": false,
		"update_boss_hp_bar": true,
		"play_hit_animation": true,
		"randomize_popup_offset": true
	})
	
	if damage_result["applied"]:
		_check_milestones(old_h, hp)
		if hp <= 0:
			_die()

func _die():
	if is_dead: return
	is_dead = true
	Global.emit_signal("boss_defeated", get_point)
	Global.emit_signal("monster_killed")
	Global.emit_signal("boss_chant_end")
	for r in _get_active_restrainers():
		r.queue_free()

	queue_free()

func _spawn_particles(pos: Vector2, color: Color, amount: int, radius: float):
	for i in range(amount):
		var p = _PixelDot.new()
		p.color = color
		p.global_position = pos + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		get_tree().current_scene.add_child(p)
		var target = p.global_position + Vector2.RIGHT.rotated(randf()*TAU) * randf_range(radius*0.3, radius)
		var tw = p.create_tween().set_parallel(true)
		var dur = randf_range(0.4, 0.7)
		tw.tween_property(p, "global_position", target, dur).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, dur)
		tw.finished.connect(p.queue_free)

func _spawn_particles_in_sectors(pos: Vector2, sectors: Array, color: Color, amount: int, range_dist: float):
	for i in range(amount):
		var sector_center = sectors[randi() % sectors.size()]
		var angle = sector_center + randf_range(-PI/4.0, PI/4.0)
		var dist = randf_range(50.0, range_dist)
		var spawn_pos = pos + Vector2(cos(angle), sin(angle)) * dist
		
		var p = _PixelDot.new()
		p.color = color
		p.global_position = spawn_pos
		get_tree().current_scene.add_child(p)
		
		var target = spawn_pos + Vector2(cos(angle), sin(angle)) * randf_range(20.0, 100.0)
		var tw = p.create_tween().set_parallel(true)
		var dur = randf_range(0.3, 0.6)
		tw.tween_property(p, "global_position", target, dur).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, dur)
		tw.finished.connect(p.queue_free)

func _screen_shake(intensity: float, duration: float):
	var cam = get_viewport().get_camera_2d()
	if not cam: return
	var orig = cam.offset
	var t = 0.0
	while t < duration:
		t += get_process_delta_time()
		var s = intensity * (1.0 - t/duration)
		cam.offset = orig + Vector2(randf_range(-s, s), randf_range(-s, s))
		await get_tree().process_frame
	cam.offset = orig

# ================= 辅助类 =================

class _PixelDot extends Node2D:
	var color: Color
	func _draw(): draw_rect(Rect2(-2, -2, 4, 4), color)

class _RayEffect extends Node2D:
	var t = 0.0
	var ray_width = 160.0
	func _process(delta):
		t += delta; queue_redraw()
		if t > 0.6: queue_free()
	func _draw():
		var a = 1.0 - t/0.6
		var c = Color(0.0, 1.0, 0.4, a * 0.7)
		var inner_c = Color(0.8, 1.0, 0.9, a)
		var rw = ray_width * a
		
		# 将平滑矩形拆分成小方块以产生像素激光感
		for i in range(-800, 800, 8):
			var h = rw * randf_range(0.8, 1.0)
			draw_rect(Rect2(i, -h/2, 8, h), c)
			var ih = rw * 0.3 * randf_range(0.8, 1.0)
			draw_rect(Rect2(i, -ih/2, 8, ih), inner_c)

class _DisplacementRingWarn extends Node2D:
	var inner_radius := 65.0
	var outer_radius := 400.0
	var duration := 2.0
	var elapsed := 0.0
	
	func _process(delta):
		elapsed += delta
		queue_redraw()
		if elapsed >= duration:
			queue_free()
	
	func _draw():
		var alpha = 0.08 + clamp(elapsed / max(duration, 0.01), 0.0, 1.0) * 0.18
		var step = 12
		for x in range(-int(outer_radius), int(outer_radius) + 1, step):
			for y in range(-int(outer_radius), int(outer_radius) + 1, step):
				var dist = Vector2(x, y).length()
				var grid_id = int(abs(x) / step + abs(y) / step)
				if dist >= inner_radius and dist <= outer_radius:
					if grid_id % 2 == 0:
						draw_rect(Rect2(x - step * 0.5, y - step * 0.5, step, step), Color(0.55, 0.0, 0.8, alpha))
				elif dist < inner_radius - 4.0 and grid_id % 3 == 0:
					draw_rect(Rect2(x - 4.0, y - 4.0, 8.0, 8.0), Color(0.2, 0.0, 0.3, 0.08 + alpha * 0.35))
		
		for i in range(48):
			var angle = i * TAU / 48.0
			var outer_pos = Vector2(cos(angle), sin(angle)) * outer_radius
			var inner_pos = Vector2(cos(angle), sin(angle)) * inner_radius
			draw_rect(Rect2(round(outer_pos.x / 4.0) * 4.0 - 4.0, round(outer_pos.y / 4.0) * 4.0 - 4.0, 8.0, 8.0), Color(0.85, 0.4, 1.0, alpha + 0.08))
			draw_rect(Rect2(round(inner_pos.x / 4.0) * 4.0 - 4.0, round(inner_pos.y / 4.0) * 4.0 - 4.0, 8.0, 8.0), Color(0.95, 0.75, 1.0, alpha + 0.12))

class _ShadowRestrainer extends Node2D:
	var p_in = false
	var applied_dr_delta := 0.0
	var applied_damage_factor := 1.0
	var rx := 20.0
	var ry := 15.0
	
	func _draw():
		var c = Color(0.4, 0.0, 0.6, 0.4 + 0.1 * sin(Time.get_ticks_msec()*0.01))
		var border_c = Color(0.8, 0.3, 1.0)
		
		# 像素化内部填充
		for x in range(-20, 22, 2):
			for y in range(-16, 18, 2):
				if (pow(x / rx, 2) + pow(y / ry, 2)) <= 1.0:
					draw_rect(Rect2(x, y, 2, 2), c)
					
		# 像素化边缘绘制
		for i in range(32):
			var angle = i * TAU / 32
			var px = round((cos(angle) * rx) / 2.0) * 2.0
			var py = round((sin(angle) * ry) / 2.0) * 2.0
			draw_rect(Rect2(px, py, 2, 2), border_c)
			
	func _process(_delta):
		queue_redraw()
		if not is_instance_valid(PC.player_instance):
			return
		
		var d = PC.player_instance.global_position - global_position
		var inside = (pow(d.x / rx, 2) + pow(d.y / ry, 2)) <= 1.0
		if inside:
			if not p_in:
				applied_dr_delta = 0.8 - PC.damage_reduction_rate
				PC.damage_reduction_rate += applied_dr_delta
				applied_damage_factor = 0.2
				PC.damage_deal_multiplier *= applied_damage_factor
				Global.emit_signal("buff_added", "restrained", 0.0, 1)
				p_in = true
		elif p_in:
			_clear_restrain_effect()
	
	func _exit_tree():
		if p_in:
			_clear_restrain_effect()
	
	func _clear_restrain_effect():
		PC.damage_reduction_rate -= applied_dr_delta
		if applied_damage_factor != 0.0:
			PC.damage_deal_multiplier /= applied_damage_factor
		Global.emit_signal("buff_removed", "restrained")
		applied_dr_delta = 0.0
		applied_damage_factor = 1.0
		p_in = false

class _ShadowTornado extends Node2D:
	var attacker: Node
	var damage_val: float
	var t := 0.0
	var active := false
	
	func _ready():
		modulate.a = 0.4
	
	func _process(delta):
		t += delta
		queue_redraw()
		
		if not active and is_instance_valid(PC.player_instance):
			var offset = PC.player_instance.global_position - global_position
			if offset.length() < TORNADO_RADIUS - 2.0:
				var push_dir = offset.normalized()
				if push_dir == Vector2.ZERO:
					push_dir = Vector2.UP
				PC.player_instance.global_position = global_position + push_dir * (TORNADO_RADIUS + 2.0)
		
		if t >= 1.0 and not active:
			active = true
			modulate.a = 1.0
		
		if active and is_instance_valid(PC.player_instance):
			if global_position.distance_to(PC.player_instance.global_position) < TORNADO_RADIUS:
				PC.apply_damage(int(damage_val * (1.0 - PC.damage_reduction_rate)))
				Global.emit_signal("player_hit", attacker)
				Global.emit_signal("buff_added", "stun", 2.0, 1)
				if PC.pc_hp <= 0 and is_instance_valid(PC.player_instance):
					PC.player_instance.game_over()
				queue_free()
		
		if t > 4.0:
			queue_free()
	
	func _draw():
		var rot = Time.get_ticks_msec() * 0.015
		for y in range(-20, 20, 4):
			var radius = 10.0 + (y + 20) * 0.4
			var ang = rot * (1.0 + y * 0.05)
			var offset_x = cos(ang) * radius
			draw_rect(Rect2(offset_x, y, 4, 4), Color(0.2, 0.0, 0.3))
			draw_rect(Rect2(-offset_x, y, 4, 4), Color(0.4, 0.1, 0.6))

class _TargetIcon extends Node2D:
	func _process(_delta):
		queue_redraw()
	
	func _draw():
		var y_off = sin(Time.get_ticks_msec() * 0.01) * 10.0 - 50.0
		y_off = round(y_off / 2.0) * 2.0
		var c = Color.RED
		var outline = Color.BLACK
		
		# 像素预警图标（感叹号）
		draw_rect(Rect2(-4, y_off + 4, 8, 16), outline)
		draw_rect(Rect2(-4, y_off - 4, 8, 6), outline)
		draw_rect(Rect2(-2, y_off + 6, 4, 12), c)
		draw_rect(Rect2(-2, y_off - 2, 4, 4), c)
