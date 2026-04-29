extends "res://Script/monster/monster_base.gd"

# ================= 被封印的石碑 (boss_stele.gd) =================
# 核心机制：暗影拘束、位移置换、高额腐蚀伤害

var is_attacking: bool = false

# 属性配置
var speed: float = 0.0 # 石碑不移动
var hpMax: float = SettingMoster.stone_man("hp") * 24
var hp: float = hpMax
var atk: float = SettingMoster.stone_man("atk") * 0.85
var get_point: int = SettingMoster.stone_man("point") * 75
var get_exp: int = 0

# 难度系统
var stage_difficulty: String = Global.STAGE_DIFFICULTY_SHALLOW

# 屏幕边界
@export var top_boundary: float = 50.0
@export var bottom_boundary: float = 550.0
@export var left_boundary: float = -300.0
@export var right_boundary: float = 300.0

var allow_turning: bool = true
var attack_timer: Timer
var restrainers: Array = [] # 存储所有的拘束器
var hp_milestones: Array = [0.91666, 0.58333, 0.25] # 生成拘束器的血量比例,11管，7管，3管
var spawned_milestones: Array = [false, false, false]

const RESTRAINER_MIN_GAP := 40.0
const DISPLACEMENT_SAFE_RX := 115 # 安全区长轴
const DISPLACEMENT_SAFE_RY := 90 # 安全区短轴 (缩小20%)
const DISPLACEMENT_DAMAGE_RADIUS := 500.0
const TORNADO_RADIUS := 28.0

# 黑球贴图（诗想难度）
const BLACK_BALL_TEXTURE: Texture2D = preload("res://AssetBundle/Sprites/SpecialEffects/black_ball.png")

# 技能循环池
var skill_queue: Array = []
@onready var sprite = $BossStone # 使用与 boss_stone 相同的节点结构
var phase1_skill_index: int = 0

var disable_contact_damage: bool = false
var restrainer_player_count: int = 0
var restrainer_applied_dr_delta: float = 0.0

var damage_history: Array = []
var is_invincible: bool = false
var invincibility_timer: Timer

# 黑球机制（诗想难度）
var black_ball_timer: Timer = null
var black_ball_spawned: bool = false # 是否已启动黑球机制

func _on_body_entered(body: Node2D) -> void:
	if disable_contact_damage: return
	super._on_body_entered(body)

func add_restrainer_buff():
	restrainer_player_count += 1
	if restrainer_player_count == 1:
		restrainer_applied_dr_delta = max(0.0, 0.9 - PC.damage_reduction_rate)
		PC.damage_reduction_rate += restrainer_applied_dr_delta
		PC.damage_deal_multiplier *= 0.2
		Global.emit_signal("buff_added", "restrained", 0.0, 1)

func remove_restrainer_buff():
	restrainer_player_count -= 1
	if restrainer_player_count <= 0:
		restrainer_player_count = 0
		PC.damage_reduction_rate -= restrainer_applied_dr_delta
		PC.damage_deal_multiplier /= 0.2
		restrainer_applied_dr_delta = 0.0
		Global.emit_signal("buff_removed", "restrained")

func _ready():
	add_to_group("boss")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	stage_difficulty = Global.validate_stage_difficulty_id(Global.current_stage_difficulty)
	# 根据玩家DPS和难度增加Boss HP
	var dps_multiplier := 6
	match Global.current_stage_difficulty:
		Global.STAGE_DIFFICULTY_DEEP:
			dps_multiplier = 8
		Global.STAGE_DIFFICULTY_CORE:
			dps_multiplier = 10
		Global.STAGE_DIFFICULTY_POETRY:
			dps_multiplier = 10
	hpMax += Global.get_current_dps() * dps_multiplier
	hp = hpMax
	
	# 浅层难度下Boss只造成25%伤害
	if stage_difficulty == Global.STAGE_DIFFICULTY_SHALLOW:
		atk *= 0.5

	setup_monster_base()
	player_hit_emit_self = true
	use_debuff_take_damage_multiplier = false
	check_action_disabled_on_body_entered = false

	# 设置影子
	CharacterEffects.create_shadow(self , 55.0, 14.0, 52.0)

	Global.emit_signal("boss_hp_bar_initialize", hpMax, hp, 12, "被封印的石碑")
	Global.emit_signal("boss_hp_bar_show")

	attack_timer = Timer.new()
	add_child(attack_timer)
	attack_timer.wait_time = 2.0
	attack_timer.timeout.connect(_choose_attack)
	attack_timer.start()
	
	invincibility_timer = Timer.new()
	invincibility_timer.one_shot = true
	invincibility_timer.timeout.connect(_on_invincibility_timeout)
	add_child(invincibility_timer)
	
	if sprite and sprite.has_method("play"):
		sprite.play("idle")

# 难度辅助
func _is_poetry() -> bool:
	return stage_difficulty == Global.STAGE_DIFFICULTY_POETRY

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
		disable_contact_damage = true
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
		
		await get_tree().create_timer(0.2).timeout
		disable_contact_damage = false
		
	is_attacking = false

func _choose_attack():
	if is_dead: return
	is_attacking = true
	
	var r_count = _get_active_restrainers().size()
	
	if r_count == 0:
		# 第一阶段技能轮换
		var phase1_skills = [9, 8] if _is_poetry() else [1, 4, 8]
		var skill_id = phase1_skills[phase1_skill_index % phase1_skills.size()]
		phase1_skill_index += 1
		_execute_skill(skill_id)
	else:
		if skill_queue.is_empty():
			_refill_skill_queue(r_count)
		var skill_id = skill_queue.pop_front()
		_execute_skill(skill_id)

func _refill_skill_queue(r_count: int):
	# 诗想难度：腐蚀连击(9)替代腐蚀射线(1)和腐蚀下压(4)
	if _is_poetry():
		skill_queue = [3, 9, 5, 6, 8]
	else:
		skill_queue = [1, 3, 4, 5, 6, 8]
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
		8: _skill_cross_ray()
		9: _skill_corrosive_combo()
		_: is_attacking = false

# ================= 技能具体实现 =================

## 1. 腐蚀射线
func _skill_corrosive_ray():
	Global.emit_signal("boss_chant_start", "腐蚀射线", 1.5)
	var warn_l = WarnRectUtil.new(); get_tree().current_scene.add_child(warn_l)
	var warn_r = WarnRectUtil.new(); get_tree().current_scene.add_child(warn_r)
	warn_l.attacker = self ; warn_r.attacker = self
	warn_l.source_name = "腐蚀射线"
	warn_r.source_name = "腐蚀射线"
	if is_instance_valid(PC.player_instance):
		warn_l.player_ref = PC.player_instance
		warn_r.player_ref = PC.player_instance
	var ray_width = 160.0
	warn_l.start_warning(global_position, global_position + Vector2(-800, 0), ray_width, 1.5, atk * 1.2, "腐蚀射线")
	warn_r.start_warning(global_position, global_position + Vector2(800, 0), ray_width, 1.5, atk * 1.2, "腐蚀射线")
	
	await get_tree().create_timer(1.5).timeout
	if is_dead: return
	GU.screen_shake(6.0, 0.4)
	var effect = _RayEffect.new()
	effect.global_position = global_position; effect.ray_width = ray_width
	get_tree().current_scene.add_child(effect)
	
	await get_tree().create_timer(0.6).timeout
	_finish_skill()

## 9. 腐蚀连击（诗想专属：腐蚀射线+腐蚀下压融合，同时释放激光和两次不同方向扇形攻击）
func _skill_corrosive_combo():
	Global.emit_signal("boss_chant_start", "腐蚀连击", 2.0)
	var ray_width = 160.0
	var range_dist = 800.0

	var is_tl_br_first = randf() < 0.5
	var first_vecs = [Vector2(-1, -1), Vector2(1, 1)] if is_tl_br_first else [Vector2(1, -1), Vector2(-1, 1)]
	var second_vecs = [Vector2(1, -1), Vector2(-1, 1)] if is_tl_br_first else [Vector2(-1, -1), Vector2(1, 1)]

	# === 第一轮：激光 + 第一次扇形 ===
	# 激光预警（1.0s，伤害由手动触发，避免与动画错位）
	var warn_l1 = WarnRectUtil.new(); get_tree().current_scene.add_child(warn_l1)
	var warn_r1 = WarnRectUtil.new(); get_tree().current_scene.add_child(warn_r1)
	warn_l1.attacker = self ; warn_r1.attacker = self
	warn_l1.source_name = "腐蚀连击"; warn_r1.source_name = "腐蚀连击"
	if is_instance_valid(PC.player_instance):
		warn_l1.player_ref = PC.player_instance
		warn_r1.player_ref = PC.player_instance
	warn_l1.start_warning(global_position, global_position + Vector2(-800, 0), ray_width, 1.0, 0.0, "腐蚀连击")
	warn_r1.start_warning(global_position, global_position + Vector2(800, 0), ray_width, 1.0, 0.0, "腐蚀连击")
	warn_l1.warning_finished.connect(warn_l1.queue_free)
	warn_r1.warning_finished.connect(warn_r1.queue_free)

	# 第一次扇形预警
	var w1 = WarnSectorUtil.new(); get_tree().current_scene.add_child(w1); var w2 = WarnSectorUtil.new(); get_tree().current_scene.add_child(w2)
	w1.attacker = self ; w2.attacker = self
	w1.source_name = "腐蚀连击"; w2.source_name = "腐蚀连击"
	w1.warning_finished.connect(w1.queue_free); w2.warning_finished.connect(w2.queue_free)
	w1.start_warning(global_position, global_position + first_vecs[0].normalized() * range_dist, 90.0, 1.0, atk, "腐蚀连击")
	w2.start_warning(global_position, global_position + first_vecs[1].normalized() * range_dist, 90.0, 1.0, atk, "腐蚀连击")

	await get_tree().create_timer(1.0).timeout
	if is_dead: return

	# 第一轮激光发射（动画+手动伤害，确保同步）
	GU.screen_shake(6.0, 0.4)
	var effect1 = _RayEffect.new()
	effect1.global_position = global_position; effect1.ray_width = ray_width
	get_tree().current_scene.add_child(effect1)
	print("[腐蚀连击] 第一轮激光发射，Boss位置=", global_position, "，玩家位置=", PC.player_instance.global_position if is_instance_valid(PC.player_instance) else "N/A")
	_deal_combo_ray_damage(ray_width)

	# 第一次扇形攻击判定 + 粒子
	_spawn_particles_in_sectors(global_position, [first_vecs[0].angle(), first_vecs[1].angle()], Color(0.05, 0.3, 0.05), 500, range_dist)
	GU.screen_shake(4.0, 0.3)

	# 等待激光特效结束后再开始第二轮预警
	await get_tree().create_timer(0.6).timeout
	if is_dead: return

	# === 第二轮：激光 + 第二次扇形 ===
	# 激光预警（1.0s，伤害由手动触发）
	var warn_l2 = WarnRectUtil.new(); get_tree().current_scene.add_child(warn_l2)
	var warn_r2 = WarnRectUtil.new(); get_tree().current_scene.add_child(warn_r2)
	warn_l2.attacker = self ; warn_r2.attacker = self
	warn_l2.source_name = "腐蚀连击"; warn_r2.source_name = "腐蚀连击"
	if is_instance_valid(PC.player_instance):
		warn_l2.player_ref = PC.player_instance
		warn_r2.player_ref = PC.player_instance
	warn_l2.start_warning(global_position, global_position + Vector2(-800, 0), ray_width, 1.0, 0.0, "腐蚀连击")
	warn_r2.start_warning(global_position, global_position + Vector2(800, 0), ray_width, 1.0, 0.0, "腐蚀连击")
	warn_l2.warning_finished.connect(warn_l2.queue_free)
	warn_r2.warning_finished.connect(warn_r2.queue_free)

	# 第二次扇形预警
	var w3 = WarnSectorUtil.new(); get_tree().current_scene.add_child(w3); var w4 = WarnSectorUtil.new(); get_tree().current_scene.add_child(w4)
	w3.attacker = self ; w4.attacker = self
	w3.source_name = "腐蚀连击"; w4.source_name = "腐蚀连击"
	w3.warning_finished.connect(w3.queue_free); w4.warning_finished.connect(w4.queue_free)
	w3.start_warning(global_position, global_position + second_vecs[0].normalized() * range_dist, 90.0, 1.0, atk, "腐蚀连击")
	w4.start_warning(global_position, global_position + second_vecs[1].normalized() * range_dist, 90.0, 1.0, atk, "腐蚀连击")

	await get_tree().create_timer(1.0).timeout
	if is_dead: return

	# 第二轮激光发射（动画+手动伤害，确保同步）
	GU.screen_shake(6.0, 0.4)
	var effect2 = _RayEffect.new()
	effect2.global_position = global_position; effect2.ray_width = ray_width
	get_tree().current_scene.add_child(effect2)
	print("[腐蚀连击] 第二轮激光发射，Boss位置=", global_position, "，玩家位置=", PC.player_instance.global_position if is_instance_valid(PC.player_instance) else "N/A", "，PC.invincible=", PC.invincible)
	# 第二轮激光使用无视受击无敌的伤害判定，确保连击的连续性
	_deal_combo_ray_damage_ignore_invincible(ray_width)

	# 第二次扇形攻击判定 + 粒子
	_spawn_particles_in_sectors(global_position, [second_vecs[0].angle(), second_vecs[1].angle()], Color(0.05, 0.3, 0.05), 500, range_dist)
	GU.screen_shake(4.0, 0.3)

	await get_tree().create_timer(0.6).timeout
	_finish_skill()

func _deal_combo_ray_damage(ray_width: float):
	if not is_instance_valid(PC.player_instance):
		print("[腐蚀连击] 伤害判定跳过：玩家无效")
		return
	if PC.invincible:
		print("[腐蚀连击] 伤害判定跳过：玩家无敌，invincible=true")
		return
	var player_pos = PC.player_instance.global_position
	var half_width = ray_width / 2.0
	# 左射线：玩家在 Boss 左侧且 y 方向在宽度范围内
	var in_left_ray = abs(player_pos.y - global_position.y) <= half_width and player_pos.x <= global_position.x
	# 右射线：玩家在 Boss 右侧且 y 方向在宽度范围内
	var in_right_ray = abs(player_pos.y - global_position.y) <= half_width and player_pos.x >= global_position.x
	print("[腐蚀连击] 伤害判定：玩家=", player_pos, "，Boss=", global_position, "，half_width=", half_width, "，in_left=", in_left_ray, "，in_right=", in_right_ray)
	if in_left_ray or in_right_ray:
		var damage = int(atk * 1.2 * (1.0 - PC.damage_reduction_rate))
		print("[腐蚀连击] 命中！伤害=", damage)
		PC.player_hit(damage, self , "腐蚀连击")
	else:
		print("[腐蚀连击] 未命中")

## 腐蚀连击激光伤害（无视受击无敌，用于第二轮确保命中）
func _deal_combo_ray_damage_ignore_invincible(ray_width: float):
	if not is_instance_valid(PC.player_instance):
		print("[腐蚀连击-无视无敌] 伤害判定跳过：玩家无效")
		return
	var player_pos = PC.player_instance.global_position
	var half_width = ray_width / 2.0
	var in_left_ray = abs(player_pos.y - global_position.y) <= half_width and player_pos.x <= global_position.x
	var in_right_ray = abs(player_pos.y - global_position.y) <= half_width and player_pos.x >= global_position.x
	print("[腐蚀连击-无视无敌] 伤害判定：玩家=", player_pos, "，Boss=", global_position, "，half_width=", half_width, "，in_left=", in_left_ray, "，in_right=", in_right_ray)
	if in_left_ray or in_right_ray:
		var damage = int(atk * 1.2 * (1.0 - PC.damage_reduction_rate))
		print("[腐蚀连击-无视无敌] 命中！伤害=", damage)
		PC.player_hit_ignore_invincible(damage, self , "腐蚀连击")
	else:
		print("[腐蚀连击-无视无敌] 未命中")

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
		
		disable_contact_damage = true
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
		
		await get_tree().create_timer(0.2).timeout
		disable_contact_damage = false
		
		if is_dead:
			is_attacking = false
			return

	Global.emit_signal("boss_chant_start", "腐蚀风暴", 4.0)
	var canvas = CanvasLayer.new(); canvas.layer = 100
	var filter = ColorRect.new(); filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	filter.color = Color(0.0, 0.4, 0.1, 0.0); canvas.add_child(filter); get_tree().current_scene.add_child(canvas)
	var tw = create_tween(); tw.tween_property(filter, "color:a", 0.3, 3.5)
	
	var elapsed = 0.0
	var particle_spawn_interval := 0.15 # 每0.15秒生成一次粒子，而非每帧
	var particle_timer := 0.0
	while elapsed < 4.0:
		if is_dead: break
		var dt = get_process_delta_time()
		elapsed += dt
		particle_timer += dt
		if particle_timer >= particle_spawn_interval:
			particle_timer = 0.0
			_spawn_particles(global_position + Vector2(randf_range(-400, 400), randf_range(-300, 300)), Color(0.05, 0.3, 0.05), 10, 60.0)
		await get_tree().process_frame
	
	if not is_dead:
		GU.screen_shake(10.0, 0.8)
		if is_instance_valid(PC.player_instance) and not PC.invincible:
			var final_dmg = int(atk * 3.0 * (1.0 - PC.damage_reduction_rate))
			PC.player_hit(int(final_dmg), self , "腐蚀风暴")
			
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
	w1.attacker = self ; w2.attacker = self
	w1.source_name = "腐蚀下压"
	w2.source_name = "腐蚀下压"
	w1.warning_finished.connect(w1.queue_free); w2.warning_finished.connect(w2.queue_free)
	w1.start_warning(global_position, global_position + first_vecs[0].normalized() * range_dist, 90.0, 1.0, atk, "腐蚀下压")
	w2.start_warning(global_position, global_position + first_vecs[1].normalized() * range_dist, 90.0, 1.0, atk, "腐蚀下压")
	await get_tree().create_timer(1.0).timeout
	if is_dead: return
	_spawn_particles_in_sectors(global_position, [first_vecs[0].angle(), first_vecs[1].angle()], Color(0.05, 0.3, 0.05), 500, range_dist)
	GU.screen_shake(4.0, 0.3)
	
	var w3 = WarnSectorUtil.new(); get_tree().current_scene.add_child(w3); var w4 = WarnSectorUtil.new(); get_tree().current_scene.add_child(w4)
	w3.attacker = self ; w4.attacker = self
	w3.source_name = "腐蚀下压"
	w4.source_name = "腐蚀下压"
	w3.warning_finished.connect(w3.queue_free); w4.warning_finished.connect(w4.queue_free)
	w3.start_warning(global_position, global_position + second_vecs[0].normalized() * range_dist, 90.0, 1.0, atk, "腐蚀下压")
	w4.start_warning(global_position, global_position + second_vecs[1].normalized() * range_dist, 90.0, 1.0, atk, "腐蚀下压")
	await get_tree().create_timer(1.0).timeout
	if is_dead: return
	_spawn_particles_in_sectors(global_position, [second_vecs[0].angle(), second_vecs[1].angle()], Color(0.05, 0.3, 0.05), 500, range_dist)
	GU.screen_shake(4.0, 0.3)
	_finish_skill()

## 5. 暗影龙卷
func _skill_shadow_tornado():
	# 诗想难度：数量+1，大小+20%，不受拘束圈影响
	var tornado_count = 4 if _is_poetry() else 3
	var tornado_scale = Vector2(0.49 * 1.2, 0.49 * 1.2) if _is_poetry() else Vector2(0.49, 0.49)
	var poetry_ignore_restrainer = _is_poetry()
	for i in range(tornado_count):
		if is_dead: break
		var chant_time = 1.5 if i == 0 else 0.8
		Global.emit_signal("boss_chant_start", "暗影龙卷", chant_time)
		await get_tree().create_timer(chant_time).timeout
		if is_dead: break
		var p_pos = PC.player_instance.global_position if is_instance_valid(PC.player_instance) else global_position
		var tornado = _ShadowTornado.new()
		tornado.global_position = p_pos; tornado.attacker = self ; tornado.damage_val = atk * 1.5; tornado.scale = tornado_scale
		tornado.ignore_restrainer = poetry_ignore_restrainer
		get_tree().current_scene.add_child(tornado)
	_finish_skill()

## 6. 暗影置换
func _skill_shadow_displacement():
	var active_restrainers = _get_active_restrainers()
	if active_restrainers.is_empty(): _finish_skill(); return
	# 浅层难度：额外0.75秒反应时间，警告区提前0.2秒出现
	var is_shallow = (stage_difficulty == Global.STAGE_DIFFICULTY_SHALLOW)
	var chant_time = 3.25 if is_shallow else 2.5
	var pre_warn_delay = 0.9 if is_shallow else 1.1 # 浅层提前0.2秒
	var warn_duration = 1.65 if is_shallow else 0.9 # 浅层延长0.75秒
	var post_warn_delay = 1.55 if is_shallow else 0.8 # 浅层延长0.75秒
	Global.emit_signal("boss_chant_start", "暗影置换", chant_time)
	var target_r = active_restrainers[randi() % active_restrainers.size()]
	var icon = _TargetIcon.new(); target_r.add_child(icon)
	await get_tree().create_timer(pre_warn_delay).timeout
	if is_dead or not is_instance_valid(target_r):
		if is_instance_valid(icon): icon.queue_free()
		_finish_skill(); return
	var ring_warn = _DisplacementRingWarn.new()
	ring_warn.global_position = target_r.global_position; ring_warn.inner_rx = DISPLACEMENT_SAFE_RX; ring_warn.inner_ry = DISPLACEMENT_SAFE_RY; ring_warn.outer_radius = DISPLACEMENT_DAMAGE_RADIUS; ring_warn.duration = warn_duration
	get_tree().current_scene.add_child(ring_warn)
	await get_tree().create_timer(post_warn_delay).timeout
	if is_instance_valid(icon): icon.queue_free()
	if is_instance_valid(ring_warn): ring_warn.queue_free()
	if is_dead or not is_instance_valid(target_r): _finish_skill(); return
	
	disable_contact_damage = true
	global_position = target_r.global_position; GU.screen_shake(8.0, 0.5)
	var original_mask = collision_mask
	collision_mask = 0
	
	# GPUParticles2D 替代 300 个 _PixelDot 用于置换爆炸粒子
	var gpu = GPUParticles2D.new()
	gpu.global_position = global_position
	gpu.amount = 256
	gpu.lifetime = 0.5
	gpu.one_shot = true
	gpu.explosiveness = 1.0
	gpu.emitting = false
	var gpu_mat = ParticleProcessMaterial.new()
	gpu_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	gpu_mat.emission_sphere_radius = DISPLACEMENT_DAMAGE_RADIUS
	gpu_mat.direction = Vector3(0, -1, 0)
	gpu_mat.spread = 180.0
	gpu_mat.initial_velocity_min = 10.0
	gpu_mat.initial_velocity_max = 40.0
	gpu_mat.gravity = Vector3.ZERO
	gpu_mat.scale_min = 2.0
	gpu_mat.scale_max = 4.0
	gpu_mat.color = Color(0.5, 0.0, 0.8, 0.9)
	gpu_mat.alpha_curve = _get_shared_alpha_gradient()
	gpu.process_material = gpu_mat
	get_tree().current_scene.add_child(gpu)
	gpu.emitting = true
	gpu.finished.connect(gpu.queue_free)
	if is_instance_valid(PC.player_instance) and not PC.invincible:
		var d = PC.player_instance.global_position - global_position
		var inside_safe = (pow(d.x / DISPLACEMENT_SAFE_RX, 2) + pow(d.y / DISPLACEMENT_SAFE_RY, 2)) <= 1.0
		if not inside_safe and d.length() <= DISPLACEMENT_DAMAGE_RADIUS:
			PC.player_hit(int(atk * 1.5 * (1.0 - PC.damage_reduction_rate)), self , "暗影置换")
	
	await get_tree().create_timer(0.6).timeout
	collision_mask = original_mask
	await get_tree().create_timer(0.2).timeout
	disable_contact_damage = false
	_finish_skill()

## 7. 暗影共鸣 (爆炸范围提升50%，读条延长0.8秒)
func _skill_shadow_resonance():
	# 原读条2.0s -> 3.0s
	Global.emit_signal("boss_chant_start", "暗影共鸣", 3.0)
	var points = [global_position]
	for r in _get_active_restrainers(): points.append(r.global_position)
	
	# 原范围160 -> 240 (160 * 1.5)
	var resonance_radius = 240.0
	
	for p in points:
		var warn = WarnCircleUtil.new(); get_tree().current_scene.add_child(warn)
		warn.attacker = self
		# 设置伤害为0，手动结算以无视 DR
		warn.start_warning(p, 1.0, resonance_radius, 3.0, 0.0, "暗影共鸣", null, WarnCircleUtil.ReleaseMode.INSTANT_DAMAGE)
		
	await get_tree().create_timer(3.0).timeout
	if is_dead: return
	GU.screen_shake(7.0, 0.35)
	
	var resonance_damage = atk * 1.2
	if is_instance_valid(PC.player_instance) and not PC.invincible:
		var hit = false
		for p in points:
			if p.distance_to(PC.player_instance.global_position) <= resonance_radius:
				hit = true
				break
		if hit:
			PC.player_hit(int(resonance_damage), self , "暗影共鸣")

	for p in points:
		_spawn_particles(p, Color(0.7, 0.0, 1.0), 35, resonance_radius)
	_finish_skill()

## 8. 十字射线 (宽度30px，静态0.5秒后旋转360度，伤害倍率100%)
func _skill_cross_ray():
	Global.emit_signal("boss_chant_start", "腐蚀轮转", 1.5)
	# 诗想难度：宽度+30%
	var base_ray_width = 30.0
	var ray_width = base_ray_width * 1.3 if _is_poetry() else base_ray_width
	# 显示十字警告
	var warn = _CrossRayWarn.new()
	warn.global_position = global_position
	warn.ray_width = ray_width
	warn.ray_length = 800.0
	warn.duration = 1.5
	get_tree().current_scene.add_child(warn)
	
	await get_tree().create_timer(1.5).timeout
	if is_dead: return
	GU.screen_shake(6.0, 0.4)
	# 生成十字射线特效（静态0.5秒→旋转2秒→消散0.3秒）
	var effect = _CrossRayEffect.new()
	effect.global_position = global_position
	effect.ray_width = ray_width
	effect.attacker = self
	effect.damage_val = atk * 1.0 # 100%倍率
	get_tree().current_scene.add_child(effect)
	
	# 等待整个特效完成（0.5静态 + 2.0旋转 + 0.3消散 = 2.8秒）
	await get_tree().create_timer(2.8).timeout
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
	var restrainer = _ShadowRestrainer.new(); restrainer.boss = self ; restrainer.global_position = spawn_pos; get_tree().current_scene.add_child(restrainer)
	_spawn_particles(spawn_pos, Color(0.35, 0.0, 0.5), 24, 80.0); GU.screen_shake(3.0, 0.15)
	for other in _get_active_restrainers():
		if other != restrainer and spawn_pos.distance_to(other.global_position) < RESTRAINER_MIN_GAP:
			_explode_restrainers(restrainer, other); return
	restrainers.append(restrainer)
	# 诗想难度：首个拘束圈后启动黑球生成
	if _is_poetry() and not black_ball_spawned:
		black_ball_spawned = true
		_start_black_ball_timer()

func _explode_restrainers(r1, r2):
	if restrainers.has(r1): restrainers.erase(r1)
	if restrainers.has(r2): restrainers.erase(r2)
	
	is_attacking = true
	Global.emit_signal("boss_chant_start", "拘束联结", 1.5)
	
	var tw1 = r1.create_tween()
	tw1.tween_property(r1, "scale", Vector2(6.0, 6.0), 1.5)
	var tw2 = r2.create_tween()
	tw2.tween_property(r2, "scale", Vector2(6.0, 6.0), 1.5)
	
	await get_tree().create_timer(1.5).timeout
	if is_dead: return
	
	var pos = (r1.global_position + r2.global_position) / 2.0
	GU.screen_shake(15.0, 1.0); _spawn_particles(pos, Color.RED, 200, 400.0)
	
	if is_instance_valid(r1): r1.queue_free()
	if is_instance_valid(r2): r2.queue_free()
	
	Global.emit_signal("boss_chant_start", "拘束爆炸", 1.0)
	# 拘束爆炸判定跟读条同时
	if is_instance_valid(PC.player_instance) and not PC.invincible:
		if pos.distance_to(PC.player_instance.global_position) < 800.0:
			PC.player_hit(int(atk * 999999 * (1.0 - PC.damage_reduction_rate)), self , "拘束爆炸")
	
	await get_tree().create_timer(1.0).timeout
	if is_dead: return
	
	var canvas = CanvasLayer.new(); canvas.layer = 100
	var filter = ColorRect.new(); filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	filter.color = Color(1.0, 0.0, 0.0, 0.5); canvas.add_child(filter); get_tree().current_scene.add_child(canvas)
	var tw_filter = canvas.create_tween(); tw_filter.tween_property(filter, "color:a", 0.0, 0.3); tw_filter.tween_callback(canvas.queue_free)
	
	GU.screen_shake(20.0, 1.0)
			
	is_attacking = false

# ================= 交互判定 =================

func _on_area_entered(area: Area2D) -> void:
	if is_invincible:
		# 无敌期间不处理任何子弹碰撞，也不销毁子弹（让子弹正常穿透/飞过）
		return
	if area.is_in_group("bullet") and area.has_method("get_bullet_damage_and_crit_status"):
		var collision_result = BulletCalculator.handle_bullet_collision_full(area, self , true)
		if collision_result["should_rebound"]: area.call_deferred("create_rebound")
		if collision_result["should_delete_bullet"]: area.queue_free()
		# 统一走 take_damage 入口，由其集中处理扣血、阶段检查与死亡判定
		var raw_dmg = get_common_bullet_damage_value(collision_result["final_damage"])
		take_damage(int(raw_dmg), collision_result["is_crit"], false, "bullet")

func take_damage(damage: int, is_crit: bool, is_summon: bool, damage_type: String) -> void:
	if is_dead: return
	if is_invincible: return
	var old_h = hp
	var show_popup = (damage_type != "bullet")
	var res = apply_common_take_damage(damage, is_crit, is_summon, damage_type, {"use_debuff_multiplier": false, "update_boss_hp_bar": true, "play_hit_animation": true, "randomize_popup_offset": true, "show_damage_popup": show_popup})
	if res["applied"]:
		var actual_damage = old_h - hp
		_record_damage(actual_damage)
		_check_milestones(old_h, hp)
		if hp <= 0: _die()

## 覆盖父类的击中闪烁，无敌期间保持金色滤镜不变
func _play_hit_flash() -> void:
	if is_invincible:
		return
	super._play_hit_flash()

func _record_damage(amount: float) -> void:
	if amount <= 0: return
	var current_time = Time.get_ticks_msec() / 1000.0
	damage_history.append({"time": current_time, "damage": amount})
	
	var valid_history = []
	var recent_total = 0.0
	for record in damage_history:
		if current_time - record["time"] <= 3.0:
			valid_history.append(record)
			recent_total += record["damage"]
	damage_history = valid_history
	
	if recent_total >= hpMax * 0.25:
		_trigger_invincibility()

func _trigger_invincibility() -> void:
	if is_invincible: return
	is_invincible = true
	damage_history.clear()
	
	if sprite:
		sprite.modulate = Color(2.0, 2.0, 1.2, 1.0) # 浅黄色发亮
		
	if invincibility_timer:
		invincibility_timer.start(4.0)

func _on_invincibility_timeout() -> void:
	is_invincible = false
	if sprite:
		sprite.modulate = Color.WHITE

func _drop_boss_rewards() -> void:
	# 15%基础概率掉落1种以太（火风雷水土其一）
	var ether_ids = ["item_031", "item_032", "item_033", "item_034", "item_035"]
	if randf() <= 0.75:
		var chosen_ether = ether_ids[randi() % ether_ids.size()]
		Global.emit_signal("drop_out_item", chosen_ether, 1, global_position)
	# 魔核+凝灵碎片掉落
	drop_items_from_table(SettingMoster.get_boss_extra_drop())
	# 固定掉落1个随机魔核
	var magic_cores = ["item_097", "item_098", "item_099", "item_100", "item_101"]
	var fixed_core = magic_cores[randi() % magic_cores.size()]
	Global.emit_signal("drop_out_item", fixed_core, 1, global_position)

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

# ================= 共享资源 =================
# 预创建透明度渐变纹理，避免每次 _spawn_particles 时重复创建 Gradient + GradientTexture1D
var _alpha_gradient_tex: GradientTexture1D = null

func _get_shared_alpha_gradient() -> GradientTexture1D:
	if _alpha_gradient_tex == null:
		var grad = Gradient.new()
		grad.add_point(0.0, Color(1, 1, 1, 1))
		grad.add_point(1.0, Color(1, 1, 1, 0))
		var tex = GradientTexture1D.new()
		tex.gradient = grad
		_alpha_gradient_tex = tex
	return _alpha_gradient_tex

func _spawn_particles(pos: Vector2, color: Color, amount: int, radius: float):
	var gpu = GPUParticles2D.new()
	gpu.global_position = pos
	gpu.amount = clampi(amount, 1, 256)
	gpu.lifetime = 0.7
	gpu.one_shot = true
	gpu.explosiveness = 1.0
	gpu.emitting = false
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 10.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = radius * 0.3
	mat.initial_velocity_max = radius
	mat.gravity = Vector3.ZERO
	mat.scale_min = 2.0
	mat.scale_max = 4.0
	mat.color = Color(color.r, color.g, color.b, 0.9)
	mat.alpha_curve = _get_shared_alpha_gradient()
	gpu.process_material = mat
	
	get_tree().current_scene.add_child(gpu)
	gpu.emitting = true
	# 自动清理
	gpu.finished.connect(gpu.queue_free)

func _spawn_particles_in_sectors(pos: Vector2, angles: Array, color: Color, amount: int, range_dist: float):
	var per_angle_amount = clampi(int(amount / max(angles.size(), 1)), 1, 256)
	for ang_base in angles:
		var gpu = GPUParticles2D.new()
		gpu.global_position = pos
		gpu.amount = per_angle_amount
		gpu.lifetime = 0.9
		gpu.one_shot = true
		gpu.explosiveness = 1.0
		gpu.emitting = false
		
		var mat = ParticleProcessMaterial.new()
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
		# 方向设置：将 GDScript Vector2 角度转换为 Godot3D 粒子方向
		var dir2d = Vector2(cos(ang_base), sin(ang_base))
		mat.direction = Vector3(dir2d.x, dir2d.y, 0)
		mat.spread = 45.0
		mat.initial_velocity_min = range_dist * 0.4
		mat.initial_velocity_max = range_dist * 1.1
		mat.gravity = Vector3.ZERO
		mat.scale_min = 2.0
		mat.scale_max = 4.0
		mat.color = Color(color.r, color.g, color.b, 0.9)
		mat.alpha_curve = _get_shared_alpha_gradient()
		gpu.process_material = mat
		
		get_tree().current_scene.add_child(gpu)
		gpu.emitting = true
		gpu.finished.connect(gpu.queue_free)

# ================= 辅助类 =================

class _RayEffect extends Node2D:
	var t = 0.0; var ray_width = 160.0
	var _x_positions: PackedFloat32Array = []
	func _ready():
		for i in range(-800, 800, 8):
			_x_positions.append(float(i))
		print("[腐蚀射线特效] 生成，位置=", global_position, "，ray_width=", ray_width)
	func _process(delta):
		t += delta; queue_redraw()
		if t > 0.6:
			print("[腐蚀射线特效] 销毁，存活时间=", t)
			queue_free()
	func _draw():
		var a = 1.0 - t / 0.6; var c = Color(0.0, 1.0, 0.4, a * 0.7); var inner_c = Color(0.8, 1.0, 0.9, a); var rw = ray_width * a
		for x in _x_positions:
			var h = rw * randf_range(0.8, 1.0); draw_rect(Rect2(x, -h / 2, 8, h), c); var ih = rw * 0.3 * randf_range(0.8, 1.0); draw_rect(Rect2(x, -ih / 2, 8, ih), inner_c)
		print("[腐蚀射线特效] _draw调用，位置=", global_position, "，t=", t, "，alpha=", a, "，rw=", rw)

class _DisplacementRingWarn extends Node2D:
	var inner_rx := 101.4
	var inner_ry := 81.12
	var outer_radius := 400.0
	var duration := 2.0
	var elapsed := 0.0
	# 预计算的网格坐标缓存，避免每帧重建
	var _grid_positions: PackedVector2Array = []
	var _border_outer: PackedVector2Array = []
	var _border_inner: PackedVector2Array = []
	
	func _ready():
		_precalculate_geometry()
		modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(self , "modulate:a", 1.0, 0.2)
	
	func _precalculate_geometry():
		# 预计算安全区外的网格坐标（仅计算一次）
		var step = 6
		for x in range(-int(outer_radius), int(outer_radius) + 1, step):
			for y in range(-int(outer_radius), int(outer_radius) + 1, step):
				var dist = Vector2(x, y).length()
				var inside_safe = (pow(x / inner_rx, 2) + pow(y / inner_ry, 2)) <= 1.0
				if not inside_safe and dist <= outer_radius:
					var grid_id = int(abs(x) / step + abs(y) / step)
					if grid_id % 2 == 0:
						_grid_positions.append(Vector2(x - step * 0.5, y - step * 0.5))
		# 预计算边界点
		for i in range(64):
			var angle = i * TAU / 64.0
			var outer_pos = Vector2(cos(angle), sin(angle)) * outer_radius
			var inner_pos = Vector2(cos(angle) * inner_rx, sin(angle) * inner_ry)
			_border_outer.append(Vector2(round(outer_pos.x / 4.0) * 4.0 - 4.0, round(outer_pos.y / 4.0) * 4.0 - 4.0))
			_border_inner.append(Vector2(round(inner_pos.x / 4.0) * 4.0 - 4.0, round(inner_pos.y / 4.0) * 4.0 - 4.0))
	
	func fade_out():
		var tw = create_tween()
		tw.tween_property(self , "modulate:a", 0.0, 0.2)
		tw.tween_callback(self.queue_free)
	
	func _process(delta):
		elapsed += delta
		queue_redraw()
		if elapsed >= duration - 0.2 and modulate.a > 0.9:
			fade_out()
	
	func _draw():
		var alpha = 0.08 + clamp(elapsed / max(duration, 0.01), 0.0, 1.0) * 0.18
		
		# 暗紫色背景层（仅在安全区外绘制）
		var bg_color = Color(0.1, 0.0, 0.15, 0.2 * modulate.a)
		var points = PackedVector2Array()
		for i in range(65):
			var angle = i * TAU / 64.0
			points.append(Vector2(cos(angle), sin(angle)) * outer_radius)
		for i in range(64, -1, -1):
			var angle = i * TAU / 64.0
			points.append(Vector2(cos(angle) * inner_rx, sin(angle) * inner_ry))
		draw_polygon(points, PackedColorArray([bg_color]))
		
		# 使用缓存的网格坐标绘制，避免每帧遍历整个网格
		var grid_color = Color(0.55, 0.0, 0.8, alpha)
		for pos in _grid_positions:
			draw_rect(Rect2(pos.x, pos.y, 6, 6), grid_color)
		
		var outer_color = Color(0.85, 0.4, 1.0, alpha + 0.08)
		var inner_color = Color(0.95, 0.75, 1.0, alpha + 0.12)
		for i in range(64):
			draw_rect(Rect2(_border_outer[i].x, _border_outer[i].y, 8.0, 8.0), outer_color)
			draw_rect(Rect2(_border_inner[i].x, _border_inner[i].y, 8.0, 8.0), inner_color)

class _ShadowRestrainer extends Node2D:
	var boss: Node
	var p_in = false; var rx := 16.0; var ry := 12.0; var dot_timer := 0.0
	var _redraw_timer := 0.0
	var _inner_pixels: PackedVector2Array = []
	var _border_pixels: PackedVector2Array = []
	func _ready():
		# 预计算内部像素和边界像素坐标
		for x in range(-16, 18, 2):
			for y in range(-12, 14, 2):
				if (pow(x / rx, 2) + pow(y / ry, 2)) <= 1.0:
					_inner_pixels.append(Vector2(x, y))
		for i in range(32):
			var angle = i * TAU / 32
			_border_pixels.append(Vector2(round((cos(angle) * rx) / 2.0) * 2.0, round((sin(angle) * ry) / 2.0) * 2.0))
	func _draw():
		var c = Color(0.4, 0.0, 0.6, 0.4 + 0.1 * sin(Time.get_ticks_msec() * 0.01))
		var border_c = Color(0.8, 0.3, 1.0)
		for pos in _inner_pixels:
			draw_rect(Rect2(pos.x, pos.y, 2, 2), c)
		for pos in _border_pixels:
			draw_rect(Rect2(pos.x, pos.y, 2, 2), border_c)
	func _process(delta):
		# 低频重绘：约10FPS即可满足脉动效果
		_redraw_timer += delta
		if _redraw_timer >= 0.1:
			_redraw_timer = 0.0
			queue_redraw()
		if not is_instance_valid(PC.player_instance): return
		if not is_instance_valid(boss) or boss.is_dead:
			queue_free()
			return
		var d = PC.player_instance.global_position - global_position
		if (pow(d.x / rx, 2) + pow(d.y / ry, 2)) <= 1.0:
			if not p_in:
				p_in = true
				boss.add_restrainer_buff()
			# 受击无敌期间暂停DOT累积
			if not PC.invincible:
				dot_timer += delta
				if dot_timer >= 1.0:
					dot_timer -= 1.0
					var was_invincible = PC.invincible
					PC.player_hit(max(1, int(PC.pc_max_hp * 0.01)), self , "暗影拘束")
					# 暗影拘束不触发受击无敌：如果player_hit设置了无敌，立即取消
					if not was_invincible and PC.invincible and PC.player_instance and PC.player_instance.has_method("stop_invincible"):
						PC.player_instance.stop_invincible()
		elif p_in: _clear_restrain_effect()
	func _exit_tree(): if p_in: _clear_restrain_effect()
	func _clear_restrain_effect():
		p_in = false; dot_timer = 0.0
		if is_instance_valid(boss): boss.remove_restrainer_buff()

class _ShadowTornado extends Node2D:
	var attacker: Node; var damage_val: float; var t := 0.0; var active := false; var fading_out := false; var has_hit := false
	var ignore_restrainer: bool = false # 诗想难度下不受拘束圈影响
	# 预计算的Y偏移数据（避免每帧重复计算flipped_y和radius基数）
	var _y_offsets: Array = [] # [{y, flipped_y, radius_base}]
	func _ready():
		modulate.a = 0.4
		# 预计算Y轴偏移参数
		for y in range(-20, 20, 4):
			var flipped_y = -y - 4
			_y_offsets.append({"y": y, "fy": flipped_y, "rb": 10.0 + (flipped_y + 20) * 0.4})
	func _process(delta):
		t += delta; queue_redraw()
		var hit_radius = TORNADO_RADIUS * scale.x
		if t >= 0.8 and not active: active = true; modulate.a = 1.0
		if active and not has_hit and is_instance_valid(PC.player_instance):
			# 检查攻击者是否仍然有效
			if attacker == null or (attacker is Node and (not is_instance_valid(attacker) or attacker.is_dead)):
				queue_free()
				return
			if global_position.distance_to(PC.player_instance.global_position) < hit_radius:
				has_hit = true; _screen_flash_purple()
				if ignore_restrainer:
					# 诗想难度：无视拘束圈减伤
					PC.player_hit(int(damage_val), self , "暗影龙卷")
				else:
					PC.player_hit(int(damage_val * (1.0 - PC.damage_reduction_rate)), self , "暗影龙卷")
				Global.emit_signal("buff_added", "stun", 2.0, 1)
				queue_free()
		if t > 20.0 and not fading_out:
			fading_out = true
			var tw = create_tween(); tw.tween_property(self , "modulate:a", 0.0, 1.0); tw.tween_callback(self.queue_free)
	func _screen_flash_purple():
		var canvas = CanvasLayer.new(); canvas.layer = 100; var filter = ColorRect.new(); filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		filter.color = Color(0.4, 0.0, 0.6, 0.4); canvas.add_child(filter); get_tree().current_scene.add_child(canvas)
		var tw = canvas.create_tween(); tw.tween_property(filter, "color:a", 0.0, 0.5); tw.tween_callback(canvas.queue_free)
	func _draw():
		var rot = int(t * 8.0) * 1000.0 / 8.0 * 0.015
		# 单次遍历，三层效果合并绘制
		for yo in _y_offsets:
			var ang = rot * (1.0 + yo.fy * 0.05)
			var offset_x = cos(ang) * yo.rb
			# 外层发光
			draw_rect(Rect2(offset_x - 4, yo.y - 1, 12, 6), Color(0.5, 0.1, 0.9, 0.25))
			draw_rect(Rect2(-offset_x - 4, yo.y - 1, 12, 6), Color(0.5, 0.1, 0.9, 0.25))
			# 主体像素
			draw_rect(Rect2(offset_x, yo.y, 4, 4), Color(0.2, 0.0, 0.3))
			draw_rect(Rect2(-offset_x, yo.y, 4, 4), Color(0.4, 0.1, 0.6))
			# 边缘高亮描边
			draw_rect(Rect2(offset_x - 2, yo.y, 2, 4), Color(0.7, 0.2, 1.0, 0.7))
			draw_rect(Rect2(offset_x + 4, yo.y, 2, 4), Color(0.7, 0.2, 1.0, 0.7))
			draw_rect(Rect2(-offset_x - 2, yo.y, 2, 4), Color(0.7, 0.2, 1.0, 0.7))
			draw_rect(Rect2(-offset_x + 4, yo.y, 2, 4), Color(0.7, 0.2, 1.0, 0.7))

class _TargetIcon extends Node2D:
	func _process(_delta): queue_redraw()
	func _draw():
		var y_off = round((sin(Time.get_ticks_msec() * 0.01) * 10.0 - 50.0) / 2.0) * 2.0
		var c = Color.RED; var outline = Color.BLACK
		draw_rect(Rect2(-4, y_off - 18, 8, 16), outline); draw_rect(Rect2(-4, y_off, 8, 6), outline); draw_rect(Rect2(-2, y_off - 16, 4, 12), c); draw_rect(Rect2(-2, y_off + 2, 4, 4), c)

# 十字射线特效：参考腐蚀射线的像素风格，静态显示0.5秒后旋转360度
class _CrossRayEffect extends Node2D:
	var t := 0.0
	var ray_width := 30.0
	var ray_length := 800.0
	var attacker: Node
	var damage_val := 0.0
	var hit_cooldown := 0.0
	var phase := 0 # 0=静态展示 1=旋转 2=消散
	var _pos_cache: PackedFloat32Array = []
	# 预缓存每列的随机高度偏移（避免每帧randf导致闪烁+性能开销）
	var _h_offsets_h: PackedFloat32Array = [] # 水平臂外层
	var _ih_offsets_h: PackedFloat32Array = [] # 水平臂内层
	var _h_offsets_v: PackedFloat32Array = [] # 垂直臂外层
	var _ih_offsets_v: PackedFloat32Array = [] # 垂直臂内层
	
	func _ready():
		for i in range(-int(ray_length), int(ray_length) + 1, 8):
			_pos_cache.append(float(i))
		_refresh_random_offsets()
	
	func _refresh_random_offsets():
		_h_offsets_h.clear(); _ih_offsets_h.clear()
		_h_offsets_v.clear(); _ih_offsets_v.clear()
		for i in range(_pos_cache.size()):
			_h_offsets_h.append(randf_range(0.8, 1.0))
			_ih_offsets_h.append(randf_range(0.8, 1.0))
			_h_offsets_v.append(randf_range(0.8, 1.0))
			_ih_offsets_v.append(randf_range(0.8, 1.0))
	
	func _process(delta):
		t += delta
		# 检查攻击者是否仍然有效
		if attacker == null or (attacker is Node and (not is_instance_valid(attacker) or attacker.is_dead)):
			queue_free()
			return
		if phase == 0:
			# 静态展示阶段
			queue_redraw()
			if t >= 0.5:
				phase = 1
				t = 0.0
		elif phase == 1:
			# 旋转阶段：2秒严格旋转360度（一圈），不超过
			rotation = clampf((t / 2.0) * (TAU / 4.0), 0.0, TAU / 4.0)
			queue_redraw()
			# 碰撞检测保持每帧执行（使用最新rotation）
			hit_cooldown -= delta
			if hit_cooldown <= 0.0 and is_instance_valid(PC.player_instance) and not PC.invincible:
				var local_p = to_local(PC.player_instance.global_position)
				var half_w = ray_width * 0.5
				# 检测水平臂：|local_p.y| < half_w 且 |local_p.x| < ray_length
				var hit_horizontal = abs(local_p.y) < half_w and abs(local_p.x) < ray_length
				# 检测垂直臂：|local_p.x| < half_w 且 |local_p.y| < ray_length
				var hit_vertical = abs(local_p.x) < half_w and abs(local_p.y) < ray_length
				if hit_horizontal or hit_vertical:
					hit_cooldown = 0.5
					PC.player_hit(int(damage_val * (1.0 - PC.damage_reduction_rate)), attacker, "腐蚀轮转")
			if t >= 2.0:
				phase = 2
				rotation = TAU
				t = 0.0
		elif phase == 2:
			# 消散阶段：保持rotation不动
			modulate.a = max(0.0, 1.0 - t / 0.3)
			queue_redraw()
			if t >= 0.3:
				queue_free()
				return
		# 随机偏移仅在初始化时生成一次，避免旋转过程中外观变化造成"多圈"错觉
	
	func _draw():
		var alpha: float
		match phase:
			0: alpha = 1.0
			1: alpha = 1.0 - t / 2.0 * 0.3 # 旋转时缓慢变淡
			_: alpha = modulate.a
		var rw = ray_width * alpha
		var c = Color(0.0, 1.0, 0.4, alpha * 0.7)
		var inner_c = Color(0.8, 1.0, 0.9, alpha)
		# 绘制水平臂
		for i in range(_pos_cache.size()):
			var x = _pos_cache[i]
			var h = rw * _h_offsets_h[i]
			draw_rect(Rect2(x, -h / 2, 8, h), c)
			var ih = rw * 0.3 * _ih_offsets_h[i]
			draw_rect(Rect2(x, -ih / 2, 8, ih), inner_c)
		# 绘制垂直臂
		for i in range(_pos_cache.size()):
			var y = _pos_cache[i]
			var w = rw * _h_offsets_v[i]
			draw_rect(Rect2(-w / 2, y, w, 8), c)
			var iw = rw * 0.3 * _ih_offsets_v[i]
			draw_rect(Rect2(-iw / 2, y, iw, 8), inner_c)

# 十字射线警告指示（十字形轮廓闪烁）
class _CrossRayWarn extends Node2D:
	var ray_width := 30.0
	var ray_length := 800.0
	var duration := 1.5
	var elapsed := 0.0
	
	func _process(delta):
		elapsed += delta
		queue_redraw()
		if elapsed >= duration:
			queue_free()
	
	func _draw():
		var alpha = 0.15 + 0.15 * sin(elapsed * 8.0)
		var c = Color(0.0, 1.0, 0.4, alpha)
		var half_w = ray_width / 2.0
		# 水平臂轮廓
		draw_rect(Rect2(-ray_length, -half_w, ray_length * 2, ray_width), c)
		# 垂直臂轮廓
		draw_rect(Rect2(-half_w, -ray_length, ray_width, ray_length * 2), c)
		# 整体十字轮廓描边（墨绿色，4像素）
		var outline_color = Color(0.0, 0.2, 0.1, alpha * 1.5)
		var outline_w = 4.0
		# 水平臂外框
		draw_rect(Rect2(-ray_length, -half_w, ray_length * 2, ray_width), outline_color, false, outline_w)
		# 垂直臂外框
		draw_rect(Rect2(-half_w, -ray_length, ray_width, ray_length * 2), outline_color, false, outline_w)
		print("[十字射线] _draw调用，position=", global_position, "，ray_length=", ray_length, "，ray_width=", ray_width, "，alpha=", alpha)

# ================= 黑球机制（诗想难度） =================

func _start_black_ball_timer():
	black_ball_timer = Timer.new()
	black_ball_timer.wait_time = 8.0
	black_ball_timer.one_shot = false
	black_ball_timer.timeout.connect(_spawn_black_ball)
	add_child(black_ball_timer)
	# 首次延迟2秒后生成第一个黑球
	await get_tree().create_timer(2.0).timeout
	if is_dead or not is_instance_valid(self ): return
	_spawn_black_ball()
	black_ball_timer.start()

func _spawn_black_ball():
	if is_dead: return
	if not is_instance_valid(PC.player_instance): return
	var ball = _BlackBall.new()
	ball.boss_ref = self
	ball.texture = BLACK_BALL_TEXTURE
	ball.scale = Vector2(0.25, 0.25)
	# 在场地边缘随机生成
	var side = randi() % 4
	var spawn_pos = Vector2.ZERO
	match side:
		0: spawn_pos = Vector2(randf_range(left_boundary, right_boundary), top_boundary)
		1: spawn_pos = Vector2(randf_range(left_boundary, right_boundary), bottom_boundary)
		2: spawn_pos = Vector2(left_boundary, randf_range(top_boundary, bottom_boundary))
		3: spawn_pos = Vector2(right_boundary, randf_range(top_boundary, bottom_boundary))
	ball.global_position = spawn_pos
	get_tree().current_scene.add_child(ball)


# ================= 黑球类（诗想难度） =================
class _BlackBall extends Area2D:
	var boss_ref: Node = null
	var texture: Texture2D = null
	var move_speed: float = 40.0 # 缓慢跟踪速度
	var lifetime: float = 60.0
	var elapsed: float = 0.0
	var hit_radius: float = 10
	var _sprite: Sprite2D = null
	var _collision: CollisionShape2D = null

	func _ready():
		# 添加到boss_projectile组
		add_to_group("boss_projectile")
		z_index = 5

		# 精灵显示
		_sprite = Sprite2D.new()
		_sprite.texture = texture
		_sprite.centered = true
		_sprite.scale = Vector2(1.2, 1.2)
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_sprite)

		# 碰撞体
		_collision = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = hit_radius
		_collision.shape = shape
		add_child(_collision)

		# 暗色光晕脉动
		modulate = Color(0.6, 0.6, 0.6, 0.9)

		# 监听body进入
		body_entered.connect(_on_body_entered)

	func _physics_process(delta):
		if not is_instance_valid(PC.player_instance):
			queue_free()
			return
		if not is_instance_valid(boss_ref) or boss_ref.is_dead:
			queue_free()
			return
		elapsed += delta
		if elapsed > lifetime:
			queue_free()
			return

		# 缓慢跟踪玩家
		var dir = global_position.direction_to(PC.player_instance.global_position)
		global_position += dir * move_speed * delta

		# 脉动效果
		var pulse = 1.4 + 0.03 * sin(elapsed * 5.0)
		if _sprite:
			_sprite.scale = Vector2(pulse, pulse)

		# 距离判定碰撞（更精确）
		if is_instance_valid(PC.player_instance):
			var dist = global_position.distance_to(PC.player_instance.global_position)
			if dist < hit_radius + 10.0:
				_on_hit_player()

	func _on_body_entered(body: Node2D):
		if body is CharacterBody2D and body.is_in_group("player"):
			_on_hit_player()

	func _on_hit_player():
		if not is_instance_valid(PC.player_instance): return
		if not is_instance_valid(boss_ref) or boss_ref.is_dead:
			queue_free()
			return
		var player_pos = PC.player_instance.global_position

		# 判断玩家是否在拘束圈内
		var in_restrainer = false
		for r in boss_ref._get_active_restrainers():
			if not is_instance_valid(r): continue
			var d = player_pos - r.global_position
			if (pow(d.x / r.rx, 2) + pow(d.y / r.ry, 2)) <= 1.0:
				in_restrainer = true
				break

		# 迸发暗紫色+暗绿色粒子
		_burst_particles()

		if in_restrainer:
			# 拘束圈内免伤免减速
			pass
		else:
			# 直接撞击：200%伤害 + 减速90% 4秒
			if not PC.invincible:
				var damage = int(boss_ref.atk * 2.0 * (1.0 - PC.damage_reduction_rate))
				PC.player_hit(damage, boss_ref, "暗影迸裂")
				Global.emit_signal("player_hit", boss_ref)
				# 减速90% 4秒
				Global.emit_signal("buff_added", "slow", 4.0, 9) # 9层 = 90%减速

		queue_free()

	func _burst_particles():
		if not is_instance_valid(boss_ref): return
		# 黑球碎裂粒子：使用更长的lifetime和自定义alpha曲线，实现渐变消失
		var burst_colors = [Color(0.25, 0.0, 0.4), Color(0.0, 0.25, 0.1)]
		for col in burst_colors:
			var gpu = GPUParticles2D.new()
			gpu.global_position = global_position
			gpu.amount = 80
			gpu.lifetime = 1.5
			gpu.one_shot = true
			gpu.explosiveness = 1.0
			gpu.emitting = false
			
			var mat = ParticleProcessMaterial.new()
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			mat.emission_sphere_radius = 10.0
			mat.direction = Vector3(0, -1, 0)
			mat.spread = 180.0
			mat.initial_velocity_min = 45.0
			mat.initial_velocity_max = 150.0
			mat.gravity = Vector3.ZERO
			mat.scale_min = 2.0
			mat.scale_max = 4.0
			mat.color = Color(col.r, col.g, col.b, 0.9)
			# 自定义alpha曲线：前70%保持不透明，后30%渐变到透明
			var grad = Gradient.new()
			grad.add_point(0.0, Color(1, 1, 1, 1))
			grad.add_point(0.7, Color(1, 1, 1, 1))
			grad.add_point(1.0, Color(1, 1, 1, 0))
			var tex = GradientTexture1D.new()
			tex.gradient = grad
			mat.alpha_curve = tex
			gpu.process_material = mat
			
			get_tree().current_scene.add_child(gpu)
			gpu.emitting = true
			gpu.finished.connect(gpu.queue_free)
