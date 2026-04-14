extends "res://Script/monster/monster_base.gd"

# ================= 被封印的石碑 (boss_stele.gd) =================
# 核心机制：暗影拘束、位移置换、高额腐蚀伤害

var is_attacking: bool = false

# 属性配置
var speed: float = 0.0 # 石碑不移动
var hpMax: float = SettingMoster.stone_man("hp") * 180
var hp: float = hpMax
var atk: float = SettingMoster.stone_man("atk") * 1.2
var get_point: int = SettingMoster.stone_man("point") * 75
var get_exp: int = 0

# 屏幕边界
@export var top_boundary: float = 250.0
@export var bottom_boundary: float = 750.0
@export var left_boundary: float = -205.0
@export var right_boundary: float = 210.0

var allow_turning: bool = true
var attack_timer: Timer
var restrainers: Array = [] # 存储所有的拘束器
var hp_milestones: Array = [0.8, 0.55, 0.3] # 生成拘束器的血量比例
var spawned_milestones: Array = [false, false, false]

const RESTRAINER_MIN_GAP := 68.0
const DISPLACEMENT_SAFE_RX := 101.4 # 安全区长轴
const DISPLACEMENT_SAFE_RY := 81.12 # 安全区短轴 (缩小20%)
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

	# 设置影子
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
		
	if PC.player_instance and allow_turning:
		var player_pos = PC.player_instance.global_position
		if player_pos.x < global_position.x:
			if sprite: sprite.flip_h = true
		else:
			if sprite: sprite.flip_h = false
	
	if is_attacking:
		attack_timer.paused = true
	else:
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")
		attack_timer.paused = false

# ================= 技能管理逻辑 =================

func _finish_skill():
	if is_dead:
		is_attacking = false
		return
	
	if is_instance_valid(PC.player_instance) and is_instance_valid(sprite):
		# 技能后短暂停留
		await get_tree().create_timer(0.5).timeout
		if is_dead: 
			is_attacking = false
			return
		
		# 渐出
		var tw = create_tween()
		tw.tween_property(sprite, "modulate:a", 0.0, 0.3)
		await tw.finished
		if is_dead:
			is_attacking = false
			return
		
		# 瞬移到玩家周围 80~120 像素的位置
		var p_pos = PC.player_instance.global_position
		var valid_pos = global_position
		for i in range(15):
			var angle = randf() * TAU
			var dist = randf_range(80.0, 120.0)
			var test_pos = p_pos + Vector2(cos(angle), sin(angle)) * dist
			if test_pos.x >= left_boundary and test_pos.x <= right_boundary and test_pos.y >= top_boundary and test_pos.y <= bottom_boundary:
				valid_pos = test_pos
				break
		global_position = valid_pos
		
		# 渐入
		var tw2 = create_tween()
		tw2.tween_property(sprite, "modulate:a", 1.0, 0.3)
		await tw2.finished
		
	is_attacking = false

func _choose_attack():
	if is_dead: return
	is_attacking = true
	
	var r_count = _get_active_restrainers().size()
	
	if r_count == 0:
		var skill_id = 1 if phase1_next_skill_is_ray else 4
		phase1_next_skill_is_ray = not phase1_next_skill_is_ray
		_execute_skill(skill_id)
	else:
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

## 1. 腐蚀射线
func _skill_corrosive_ray():
	Global.emit_signal("boss_chant_start", "腐蚀射线", 1.5)
	var warn_l = WarnRectUtil.new(); get_tree().current_scene.add_child(warn_l)
	var warn_r = WarnRectUtil.new(); get_tree().current_scene.add_child(warn_r)
	warn_l.attacker = self; warn_r.attacker = self
	var ray_width = 160.0
	warn_l.start_warning(global_position, global_position + Vector2(-800, 0), ray_width, 1.5, atk * 1.2)
	warn_r.start_warning(global_position, global_position + Vector2(800, 0), ray_width, 1.5, atk * 1.2)
	
	await get_tree().create_timer(1.5).timeout
	if is_dead: return
	_screen_shake(6.0, 0.4)
	var effect = _RayEffect.new()
	effect.global_position = global_position; effect.ray_width = ray_width
	get_tree().current_scene.add_child(effect)
	
	await get_tree().create_timer(0.6).timeout
	_finish_skill()

## 3. 腐蚀风暴 (长读条4秒, 300%伤害, 增加释放前检测逻辑)
func _skill_corrosive_storm():
	# 检查 Boss 是否站在拘束圈上
	var on_restrainer = false
	for r in _get_active_restrainers():
		var d = global_position - r.global_position
		# 拘束圈判定半径 rx=20, ry=15
		if (pow(d.x / 20.0, 2) + pow(d.y / 15.0, 2)) <= 1.0:
			on_restrainer = true
			break
	
	# 如果站在拘束圈上，先强制瞬移走一次
	if on_restrainer and is_instance_valid(PC.player_instance) and is_instance_valid(sprite):
		var tw_out = create_tween()
		tw_out.tween_property(sprite, "modulate:a", 0.0, 0.2)
		await tw_out.finished
		if is_dead: 
			is_attacking = false
			return
		
		var p_pos = PC.player_instance.global_position
		var valid_pos = global_position
		for i in range(15):
			var angle = randf() * TAU
			var dist = randf_range(130.0, 200.0) # 瞬移得远一点，离拘束器远点
			var test_pos = p_pos + Vector2(cos(angle), sin(angle)) * dist
			if test_pos.x >= left_boundary and test_pos.x <= right_boundary and test_pos.y >= top_boundary and test_pos.y <= bottom_boundary:
				valid_pos = test_pos
				break
		global_position = valid_pos
		
		var tw_in = create_tween()
		tw_in.tween_property(sprite, "modulate:a", 1.0, 0.2)
		await tw_in.finished
		if is_dead:
			is_attacking = false
			return

	Global.emit_signal("boss_chant_start", "腐蚀风暴", 4.0)
	var canvas = CanvasLayer.new(); canvas.layer = 100
	var filter = ColorRect.new(); filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	filter.color = Color(0.0, 0.4, 0.1, 0.0); canvas.add_child(filter); get_tree().current_scene.add_child(canvas)
	var tw = create_tween(); tw.tween_property(filter, "color:a", 0.3, 3.5)
	
	var elapsed = 0.0
	while elapsed < 4.0:
		if is_dead: break
		_spawn_particles(global_position + Vector2(randf_range(-400, 400), randf_range(-300, 300)), Color(0.05, 0.3, 0.05), 10, 60.0)
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	
	if not is_dead:
		_screen_shake(10.0, 0.8)
		if is_instance_valid(PC.player_instance) and not PC.invincible:
			var final_dmg = int(atk * 3.0 * (1.0 - PC.damage_reduction_rate))
			PC.apply_damage(final_dmg); Global.emit_signal("player_hit", self)
			
	if is_instance_valid(canvas):
		var tw2 = create_tween(); tw2.tween_property(filter, "color:a", 0.0, 0.2); tw2.tween_callback(canvas.queue_free)
	_finish_skill()

## 4. 腐蚀下压 (随机顺序)
func _skill_corrosive_slam():
	Global.emit_signal("boss_chant_start", "腐蚀下压", 2.0)
	var range_dist = 800.0
	var is_tl_br_first = randf() < 0.5
	var first_vecs = [Vector2(-1, -1), Vector2(1, 1)] if is_tl_br_first else [Vector2(1, -1), Vector2(-1, 1)]
	var second_vecs = [Vector2(1, -1), Vector2(-1, 1)] if is_tl_br_first else [Vector2(-1, -1), Vector2(1, 1)]
	
	var w1 = WarnSectorUtil.new(); get_tree().current_scene.add_child(w1); var w2 = WarnSectorUtil.new(); get_tree().current_scene.add_child(w2)
	w1.attacker = self; w2.attacker = self
	w1.start_warning(global_position, global_position + first_vecs[0].normalized() * range_dist, 90.0, 1.0, atk)
	w2.start_warning(global_position, global_position + first_vecs[1].normalized() * range_dist, 90.0, 1.0, atk)
	await get_tree().create_timer(1.0).timeout
	if is_dead: return
	_spawn_particles_in_sectors(global_position, [first_vecs[0].angle(), first_vecs[1].angle()], Color(0.05, 0.3, 0.05), 600, range_dist)
	_screen_shake(4.0, 0.3)
	
	var w3 = WarnSectorUtil.new(); get_tree().current_scene.add_child(w3); var w4 = WarnSectorUtil.new(); get_tree().current_scene.add_child(w4)
	w3.attacker = self; w4.attacker = self
	w3.start_warning(global_position, global_position + second_vecs[0].normalized() * range_dist, 90.0, 1.0, atk)
	w4.start_warning(global_position, global_position + second_vecs[1].normalized() * range_dist, 90.0, 1.0, atk)
	await get_tree().create_timer(1.0).timeout
	if is_dead: return
	_spawn_particles_in_sectors(global_position, [second_vecs[0].angle(), second_vecs[1].angle()], Color(0.05, 0.3, 0.05), 600, range_dist)
	_screen_shake(4.0, 0.3)
	_finish_skill()

## 5. 暗影龙卷
func _skill_shadow_tornado():
	for i in range(3):
		if is_dead: break
		var chant_time = 1.5 if i == 0 else 0.8
		Global.emit_signal("boss_chant_start", "暗影龙卷", chant_time)
		await get_tree().create_timer(chant_time).timeout
		if is_dead: break
		var p_pos = PC.player_instance.global_position if is_instance_valid(PC.player_instance) else global_position
		var tornado = _ShadowTornado.new()
		tornado.global_position = p_pos; tornado.attacker = self; tornado.damage_val = atk * 1.5; tornado.scale = Vector2(0.70, 0.70)
		get_tree().current_scene.add_child(tornado)
	_finish_skill()

## 6. 暗影置换
func _skill_shadow_displacement():
	var active_restrainers = _get_active_restrainers()
	if active_restrainers.is_empty(): _finish_skill(); return
	Global.emit_signal("boss_chant_start", "暗影置换", 2.0)
	var target_r = active_restrainers[randi() % active_restrainers.size()]
	var icon = _TargetIcon.new(); target_r.add_child(icon)
	await get_tree().create_timer(1.1).timeout
	if is_dead or not is_instance_valid(target_r):
		if is_instance_valid(icon): icon.queue_free()
		_finish_skill(); return
	var ring_warn = _DisplacementRingWarn.new()
	ring_warn.global_position = target_r.global_position; ring_warn.inner_rx = DISPLACEMENT_SAFE_RX; ring_warn.inner_ry = DISPLACEMENT_SAFE_RY; ring_warn.outer_radius = DISPLACEMENT_DAMAGE_RADIUS; ring_warn.duration = 0.9
	get_tree().current_scene.add_child(ring_warn)
	await get_tree().create_timer(0.9).timeout
	if is_instance_valid(icon): icon.queue_free()
	if is_instance_valid(ring_warn): ring_warn.queue_free()
	if is_dead or not is_instance_valid(target_r): _finish_skill(); return	
	
	global_position = target_r.global_position; _screen_shake(8.0, 0.5)
	var original_mask = collision_mask
	collision_mask = 0
	
	for i in range(300):
		var angle = randf() * TAU; var dist = randf_range(80.0, DISPLACEMENT_DAMAGE_RADIUS); var spawn_pos = global_position + Vector2(cos(angle), sin(angle)) * dist
		var p = _PixelDot.new(); p.color = Color(0.5, 0.0, 0.8); p.global_position = spawn_pos; get_tree().current_scene.add_child(p)
		var target = spawn_pos + Vector2(0, -randf_range(10, 40)); var tw = p.create_tween().set_parallel(true)
		tw.tween_property(p, "global_position", target, 0.5); tw.tween_property(p, "modulate:a", 0.0, 0.5); tw.finished.connect(p.queue_free)
	if is_instance_valid(PC.player_instance) and not PC.invincible:
		var d = PC.player_instance.global_position - global_position
		var inside_safe = (pow(d.x / DISPLACEMENT_SAFE_RX, 2) + pow(d.y / DISPLACEMENT_SAFE_RY, 2)) <= 1.0
		if not inside_safe and d.length() <= DISPLACEMENT_DAMAGE_RADIUS:
			PC.apply_damage(int(atk * 1.5 * (1.0 - PC.damage_reduction_rate))); Global.emit_signal("player_hit", self)
			if PC.pc_hp <= 0: PC.player_instance.game_over()
	
	await get_tree().create_timer(0.6).timeout
	collision_mask = original_mask
	_finish_skill()

## 7. 暗影共鸣 (爆炸范围提升50%，读条延长0.8秒)
func _skill_shadow_resonance():
	# 原读条2.0s -> 2.8s
	Global.emit_signal("boss_chant_start", "暗影共鸣", 2.8)
	var points = [global_position]
	for r in _get_active_restrainers(): points.append(r.global_position)
	
	# 原范围160 -> 240 (160 * 1.5)
	var resonance_radius = 240.0
	
	for p in points:
		var warn = WarnCircleUtil.new(); get_tree().current_scene.add_child(warn)
		warn.attacker = self
		# 设置伤害为0，手动结算以无视 DR
		warn.start_warning(p, 1.0, resonance_radius, 2.8, 0.0, null, WarnCircleUtil.ReleaseMode.INSTANT_DAMAGE)
		
	await get_tree().create_timer(2.8).timeout
	if is_dead: return
	_screen_shake(7.0, 0.35)
	
	var resonance_damage = atk * 1.2
	if is_instance_valid(PC.player_instance) and not PC.invincible:
		var hit = false
		for p in points:
			if p.distance_to(PC.player_instance.global_position) <= resonance_radius:
				hit = true
				break
		if hit:
			PC.apply_damage(int(resonance_damage))
			Global.emit_signal("player_hit", self)

	for p in points:
		_spawn_particles(p, Color(0.7, 0.0, 1.0), 35, resonance_radius)
	_finish_skill()

# ================= 机制管理 =================

func _check_milestones(old_h, new_h):
	for i in range(hp_milestones.size()):
		var threshold = hpMax * hp_milestones[i]
		if not spawned_milestones[i] and old_h > threshold and new_h <= threshold:
			spawned_milestones[i] = true; _spawn_restrainer()

func _get_active_restrainers() -> Array:
	var active: Array = []; for r in restrainers: if is_instance_valid(r): active.append(r)
	restrainers = active; return active

func _spawn_restrainer():
	var spawn_pos = global_position
	var restrainer = _ShadowRestrainer.new(); restrainer.global_position = spawn_pos; get_tree().current_scene.add_child(restrainer)
	_spawn_particles(spawn_pos, Color(0.35, 0.0, 0.5), 24, 80.0); _screen_shake(3.0, 0.15)
	for other in _get_active_restrainers():
		if other != restrainer and spawn_pos.distance_to(other.global_position) < RESTRAINER_MIN_GAP:
			_explode_restrainers(restrainer, other); return
	restrainers.append(restrainer)

func _explode_restrainers(r1, r2):
	var pos = (r1.global_position + r2.global_position) / 2.0
	_screen_shake(15.0, 1.0); _spawn_particles(pos, Color.WHITE, 80, 300.0)
	if is_instance_valid(PC.player_instance):
		if pos.distance_to(PC.player_instance.global_position) < 220.0:
			PC.apply_damage(int(atk * 3.5 * (1.0 - PC.damage_reduction_rate)))
			if PC.pc_hp <= 0: PC.player_instance.game_over()
	if restrainers.has(r1): restrainers.erase(r1)
	if restrainers.has(r2): restrainers.erase(r2)
	r1.queue_free(); r2.queue_free()

# ================= 交互判定 =================

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("bullet") and area.has_method("get_bullet_damage_and_crit_status"):
		var collision_result = BulletCalculator.handle_bullet_collision_full(area, self, true)
		var dmg = collision_result["final_damage"]
		Global.emit_signal("boss_hp_bar_take_damage", dmg)
		hp -= int(dmg); _check_milestones(hp + dmg, hp)
		if collision_result["should_rebound"]: area.call_deferred("create_rebound")
		if collision_result["should_delete_bullet"]: area.queue_free()
		if hp <= 0: _die()
		else: Global.play_hit_anime(position, collision_result["is_crit"])

func take_damage(damage: int, is_crit: bool, is_summon: bool, damage_type: String) -> void:
	if is_dead: return
	var old_h = hp
	var res = apply_common_take_damage(damage, is_crit, is_summon, damage_type, {"use_debuff_multiplier": false, "update_boss_hp_bar": true, "play_hit_animation": true, "randomize_popup_offset": true})
	if res["applied"]:
		_check_milestones(old_h, hp)
		if hp <= 0: _die()

func _drop_boss_rewards() -> void:
	drop_items_from_table(SettingMoster.ruin_boss("itemdrop"))

func _die():
	if not is_dead:
		_drop_boss_rewards()
		Global.emit_signal("boss_defeated", get_point, global_position)
		Global.emit_signal("monster_killed")
	is_dead = true; remove_from_group("enemies"); is_attacking = false; attack_timer.stop(); Global.emit_signal("boss_chant_end")
	for r in _get_active_restrainers(): if is_instance_valid(r): r.queue_free()
	var col = get_node_or_null("CollisionShape2D"); if col: col.disabled = true
	collision_layer = 0; collision_mask = 0; monitoring = false; monitorable = false
	var shadow = get_node_or_null("Shadow"); if shadow: shadow.visible = false
	queue_free()

func apply_knockback(_dir: Vector2, _force: float): pass

func _spawn_particles(pos: Vector2, color: Color, amount: int, radius: float):
	for i in range(amount):
		var p = _PixelDot.new(); p.color = color; p.global_position = pos + Vector2(randf_range(-10, 10), randf_range(-10, 10)); get_tree().current_scene.add_child(p)
		var target = p.global_position + Vector2.RIGHT.rotated(randf()*TAU) * randf_range(radius*0.3, radius); var tw = p.create_tween().set_parallel(true)
		var dur = randf_range(0.4, 0.7); tw.tween_property(p, "global_position", target, dur).set_ease(Tween.EASE_OUT); tw.tween_property(p, "modulate:a", 0.0, dur); tw.finished.connect(p.queue_free)

func _spawn_particles_in_sectors(pos: Vector2, angles: Array, color: Color, amount: int, range_dist: float):
	for i in range(amount):
		var ang_base = angles[randi() % angles.size()]
		var angle = ang_base + randf_range(-PI/4.0, PI/4.0); var dist = randf_range(50.0, range_dist); var spawn_pos = pos + Vector2(cos(angle), sin(angle)) * dist
		var p = _PixelDot.new(); p.color = color; p.global_position = spawn_pos; get_tree().current_scene.add_child(p)
		var target = spawn_pos + Vector2(cos(angle), sin(angle)) * randf_range(20.0, 100.0) * 2.6; var tw = p.create_tween().set_parallel(true)
		var dur = randf_range(0.6, 1.2); tw.tween_property(p, "global_position", target, dur).set_ease(Tween.EASE_OUT); tw.tween_property(p, "modulate:a", 0.0, dur); tw.finished.connect(p.queue_free)

# ================= 辅助类 =================

class _PixelDot extends Node2D:
	var color: Color
	func _draw(): draw_rect(Rect2(-2, -2, 4, 4), color)

class _RayEffect extends Node2D:
	var t = 0.0; var ray_width = 160.0
	func _process(delta):
		t += delta; queue_redraw()
		if t > 0.6: queue_free()
	func _draw():
		var a = 1.0 - t/0.6; var c = Color(0.0, 1.0, 0.4, a * 0.7); var inner_c = Color(0.8, 1.0, 0.9, a); var rw = ray_width * a
		for i in range(-800, 800, 8):
			var h = rw * randf_range(0.8, 1.0); draw_rect(Rect2(i, -h/2, 8, h), c); var ih = rw * 0.3 * randf_range(0.8, 1.0); draw_rect(Rect2(i, -ih/2, 8, ih), inner_c)

class _DisplacementRingWarn extends Node2D:
	var inner_rx := 101.4
	var inner_ry := 81.12
	var outer_radius := 400.0
	var duration := 2.0
	var elapsed := 0.0
	
	func _ready():
		modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(self, "modulate:a", 1.0, 0.2)
	
	func fade_out():
		var tw = create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.2)
		tw.tween_callback(self.queue_free)
	
	func _process(delta):
		elapsed += delta
		queue_redraw()
		if elapsed >= duration - 0.2 and modulate.a > 0.9:
			fade_out()
	
	func _draw():
		var alpha = 0.08 + clamp(elapsed / max(duration, 0.01), 0.0, 1.0) * 0.18
		
		# 暗紫色背景层
		draw_circle(Vector2.ZERO, outer_radius, Color(0.1, 0.0, 0.15, 0.2 * modulate.a))
		
		var step = 6
		for x in range(-int(outer_radius), int(outer_radius) + 1, step):
			for y in range(-int(outer_radius), int(outer_radius) + 1, step):
				var dist = Vector2(x, y).length()
				var inside_safe = (pow(x / inner_rx, 2) + pow(y / inner_ry, 2)) <= 1.0
				var grid_id = int(abs(x) / step + abs(y) / step)
				if not inside_safe and dist <= outer_radius:
					if grid_id % 2 == 0: draw_rect(Rect2(x - step * 0.5, y - step * 0.5, step, step), Color(0.55, 0.0, 0.8, alpha))
				elif inside_safe and grid_id % 3 == 0:
					draw_rect(Rect2(x - 3.0, y - 3.0, 6.0, 6.0), Color(0.2, 0.0, 0.3, 0.08 + alpha * 0.35))
		for i in range(64):
			var angle = i * TAU / 64.0
			var outer_pos = Vector2(cos(angle), sin(angle)) * outer_radius
			var inner_pos = Vector2(cos(angle) * inner_rx, sin(angle) * inner_ry)
			draw_rect(Rect2(round(outer_pos.x / 4.0) * 4.0 - 4.0, round(outer_pos.y / 4.0) * 4.0 - 4.0, 8.0, 8.0), Color(0.85, 0.4, 1.0, alpha + 0.08))
			draw_rect(Rect2(round(inner_pos.x / 4.0) * 4.0 - 4.0, round(inner_pos.y / 4.0) * 4.0 - 4.0, 8.0, 8.0), Color(0.95, 0.75, 1.0, alpha + 0.12))

class _ShadowRestrainer extends Node2D:
	var p_in = false; var applied_dr_delta := 0.0; var applied_damage_factor := 1.0; var rx := 20.0; var ry := 15.0; var dot_timer := 0.0
	func _draw():
		var c = Color(0.4, 0.0, 0.6, 0.4 + 0.1 * sin(Time.get_ticks_msec()*0.01)); var border_c = Color(0.8, 0.3, 1.0)
		for x in range(-20, 22, 2):
			for y in range(-16, 18, 2):
				if (pow(x / rx, 2) + pow(y / ry, 2)) <= 1.0: draw_rect(Rect2(x, y, 2, 2), c)
		for i in range(32):
			var angle = i * TAU / 32; var px = round((cos(angle) * rx) / 2.0) * 2.0; var py = round((sin(angle) * ry) / 2.0) * 2.0
			draw_rect(Rect2(px, py, 2, 2), border_c)
	func _process(delta):
		queue_redraw()
		if not is_instance_valid(PC.player_instance): return
		var d = PC.player_instance.global_position - global_position
		if (pow(d.x / rx, 2) + pow(d.y / ry, 2)) <= 1.0:
			if not p_in:
				applied_dr_delta = 0.9 - PC.damage_reduction_rate; PC.damage_reduction_rate += applied_dr_delta
				applied_damage_factor = 0.2; PC.damage_deal_multiplier *= applied_damage_factor
				Global.emit_signal("buff_added", "restrained", 0.0, 1); p_in = true
			dot_timer += delta
			if dot_timer >= 1.0:
				dot_timer -= 1.0; PC.apply_damage(max(1, int(PC.pc_max_hp * 0.01)))
		elif p_in: _clear_restrain_effect()
	func _exit_tree(): if p_in: _clear_restrain_effect()
	func _clear_restrain_effect():
		PC.damage_reduction_rate -= applied_dr_delta
		if applied_damage_factor != 0.0: PC.damage_deal_multiplier /= applied_damage_factor
		Global.emit_signal("buff_removed", "restrained"); applied_dr_delta = 0.0; applied_damage_factor = 1.0; p_in = false; dot_timer = 0.0

class _ShadowTornado extends Node2D:
	var attacker: Node; var damage_val: float; var t := 0.0; var active := false; var fading_out := false; var has_hit := false
	func _ready(): modulate.a = 0.4
	func _process(delta):
		t += delta; queue_redraw()
		var hit_radius = TORNADO_RADIUS * scale.x
		if t >= 0.8 and not active: active = true; modulate.a = 1.0
		if active and not has_hit and is_instance_valid(PC.player_instance):
			if global_position.distance_to(PC.player_instance.global_position) < hit_radius:
				has_hit = true; _screen_flash_purple()
				PC.apply_damage(int(damage_val * (1.0 - PC.damage_reduction_rate)))
				Global.emit_signal("player_hit", attacker); Global.emit_signal("buff_added", "stun", 2.0, 1)
				if PC.pc_hp <= 0: PC.player_instance.game_over()
		if t > 20.0 and not fading_out:
			fading_out = true
			var tw = create_tween(); tw.tween_property(self, "modulate:a", 0.0, 1.0); tw.tween_callback(self.queue_free)
	func _screen_flash_purple():
		var canvas = CanvasLayer.new(); canvas.layer = 100; var filter = ColorRect.new(); filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		filter.color = Color(0.4, 0.0, 0.6, 0.4); canvas.add_child(filter); get_tree().current_scene.add_child(canvas)
		var tw = create_tween(); tw.tween_property(filter, "color:a", 0.0, 0.5); tw.tween_callback(canvas.queue_free)
	func _draw():
		var rot = Time.get_ticks_msec() * 0.015
		for y in range(-20, 20, 4):
			var radius = 10.0 + (y + 20) * 0.4; var ang = rot * (1.0 + y * 0.05); var offset_x = cos(ang) * radius
			draw_rect(Rect2(offset_x, y, 4, 4), Color(0.2, 0.0, 0.3)); draw_rect(Rect2(-offset_x, y, 4, 4), Color(0.4, 0.1, 0.6))

class _TargetIcon extends Node2D:
	func _process(_delta): queue_redraw()
	func _draw():
		var y_off = round((sin(Time.get_ticks_msec() * 0.01) * 10.0 - 50.0) / 2.0) * 2.0
		var c = Color.RED; var outline = Color.BLACK
		draw_rect(Rect2(-4, y_off + 4, 8, 16), outline); draw_rect(Rect2(-4, y_off - 4, 8, 6), outline); draw_rect(Rect2(-2, y_off + 6, 4, 12), c); draw_rect(Rect2(-2, y_off - 2, 4, 4), c)

func _screen_shake(intensity: float = 6.0, duration: float = 0.3):
	var camera = get_viewport().get_camera_2d()
	if not camera: return
	var original_offset = camera.offset
	var elapsed := 0.0
	while elapsed < duration:
		var dt = get_process_delta_time()
		elapsed += dt
		var strength = intensity * (1.0 - elapsed / duration)
		camera.offset = original_offset + Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		await get_tree().process_frame
	camera.offset = original_offset
