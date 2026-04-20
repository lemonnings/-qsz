extends Area2D

## ========================================================
## Boss Stone — 石巨人Boss
## 技能列表：
## 1. 滚石 — 随机从左右刷新横向滚石，1秒预警，12秒每秒2个，Boss仅停4秒
## 2. 连续冲锋 — 落石组合技中触发，撞石块眩晕+损夨10%HP
## 3. 落石 — 对脚下(无石块)+玩家位置下砸(生成实体石块+击飞)
## 4. 拍击 — 扇形连续攻击
## 5. 掙地 — 扇形攻击后生成扇形泥潭（减速+受伤）
## 6. 震地 — 以自身为中心步进扩大伤害圈+崩散粒子
## ========================================================

@onready var sprite = $BossStone
var debuff_manager: EnemyDebuffManager
var is_dead: bool = false
var is_attacking: bool = false
var is_charging: bool = false
var is_stunned: bool = false
var allow_turning: bool = true
var is_rolling_stones_active: bool = false

# 技能循环调度
var _is_first_attack: bool = true
var _skill_queue: Array = [] # 当前循环剩余技能组
var _combo_step: int = 0 # 落石组合技内部步骤: 0=落石, 1=拍击/掙地, 2=冲锋

signal debuff_applied(debuff_id: String)

# 屏幕边界
@export var top_boundary: float = 250.0
@export var bottom_boundary: float = 750.0
@export var left_boundary: float = -205.0
@export var right_boundary: float = 210.0

# 移动
var move_direction: int = 4
var target_position: Vector2
var update_move_timer: Timer

# 属性 — 基于stone_man基准 × Boss倍率
var speed: float = SettingMoster.stone_man("speed") * 1.2
var hpMax: float = SettingMoster.stone_man("hp") * 100
var hp: float = hpMax
var atk: float = SettingMoster.stone_man("atk") * 1.0
var get_point: int = SettingMoster.stone_man("point") * 30
var get_exp: int = 0

var attack_timer: Timer
var stun_timer: Timer

# 技能参数
const ROLLING_STONE_DURATION: float = 12.0
const ROLLING_STONE_INTERVAL: float = 0.5 # 每秒2个
const ROLLING_STONE_WARNING_TIME: float = 1.0
const ROLLING_STONE_SPEED: float = 180.0
const ROLLING_STONE_WIDTH: float = 40.0

const CHARGE_COUNT: int = 5
const CHARGE_SPEED_MULT: float = 14.0
const CHARGE_WARNING_TIME: float = 0.6
const CHARGE_DISTANCE: float = 500.0

# 冲锋专用边界（与 Boss 移动边界不同）
const CHARGE_LEFT: float = -205.0
const CHARGE_RIGHT: float = 210.0
const CHARGE_TOP: float = 250.0
const CHARGE_BOTTOM: float = 750.0

const FALLING_STONE_RADIUS: float = 50.0
const FALLING_STONE_WARNING_TIME: float = 1.5
const STONE_BLOCK_DURATION: float = 25.0

const SLAP_SECTOR_ANGLE: float = 70.0
const SLAP_RADIUS: float = 360.0
const SLAP_WARNING_TIME: float = 0.8
const SLAP_ROUNDS: int = 3

const FLIP_SECTOR_ANGLE: float = 90.0
const FLIP_RADIUS: float = 210.0
const FLIP_WARNING_TIME: float = 1.2
const MUD_POOL_DURATION: float = 10.0
const MUD_POOL_DAMAGE_TICK: float = 1.0
const MUD_POOL_SLOW_RATE: float = 0.5

const QUAKE_INITIAL_RADIUS: float = 50.0 # 震地第1次半径
const QUAKE_MAX_RADIUS: float = 180.0 # 震地第3次半径
const QUAKE_ROUNDS: int = 3 # 释放次数
const QUAKE_ROUND_WARNING: float = 0.8 # 每次预警时间
const QUAKE_ROUND_GAP: float = 0.3 # 每次间隔

# 石块追踪
var stone_blocks: Array = []

# 像素风格缓存
static var _rolling_stone_frames_cache: SpriteFrames = null
static var _stone_impact_frames_cache: SpriteFrames = null
static var _stone_block_texture_cache: ImageTexture = null

func _ready():
	add_to_group("boss")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# 根据玩家DPS和难度增加Boss HP
	var dps_multiplier := 5
	match Global.current_stage_difficulty:
		Global.STAGE_DIFFICULTY_DEEP:
			dps_multiplier = 6
		Global.STAGE_DIFFICULTY_CORE:
			dps_multiplier = 7
		Global.STAGE_DIFFICULTY_POETRY:
			dps_multiplier = 7
	hpMax += Global.get_current_dps() * dps_multiplier
	hp = hpMax

	debuff_manager = EnemyDebuffManager.new(self )
	add_child(debuff_manager)
	debuff_applied.connect(debuff_manager.add_debuff)

	CharacterEffects.create_shadow(self , 50.0, 16.0, 14.0)

	Global.emit_signal("boss_hp_bar_initialize", hpMax, hp, 12, "石巨人")
	Global.emit_signal("boss_hp_bar_show")

	# 移动计时器
	update_move_timer = Timer.new()
	add_child(update_move_timer)
	update_move_timer.wait_time = 0.5
	update_move_timer.timeout.connect(_update_target_position)
	update_move_timer.start()
	_update_target_position()

	# 攻击计时器
	attack_timer = Timer.new()
	add_child(attack_timer)
	attack_timer.wait_time = 3.0
	attack_timer.timeout.connect(_choose_attack)
	attack_timer.start()

func apply_debuff_effect(debuff_id: String):
	emit_signal("debuff_applied", debuff_id)

func _update_target_position():
	var player_pos = PC.player_instance.global_position
	var x_offset = 80
	if global_position.x < player_pos.x:
		x_offset = -80
	target_position = Vector2(player_pos.x + x_offset, player_pos.y)

func _physics_process(delta: float) -> void:
	if is_stunned:
		return

	if PC.player_instance and allow_turning:
		var player_pos = PC.player_instance.global_position
		if player_pos.x < global_position.x:
			sprite.flip_h = true
		else:
			sprite.flip_h = false

	if not is_dead and not is_attacking:
		_move_pattern(delta)

	if is_attacking:
		if not is_charging:
			if sprite.animation != "idle":
				sprite.play("idle")
		attack_timer.paused = true
	if not is_attacking:
		if sprite.animation != "run":
			sprite.play("run")
		attack_timer.paused = false

func _move_pattern(delta: float):
	var direction = position.direction_to(target_position)
	if position.distance_to(target_position) > 5:
		position += direction * speed * delta

# ========================================================
# 技能选择
# ========================================================
func _choose_attack():
	if is_dead or is_stunned:
		return
	is_attacking = true

	# 落石组合技内部步骤: 1=震地/掙地, 2=冲锋
	if _combo_step == 2:
		_combo_step = 0
		print("Boss Stone combo step: Charge")
		_attack_consecutive_charge()
		return
	if _combo_step == 1:
		_combo_step = 2
		var pick = ["quake", "flip"][randi() % 2]
		print("Boss Stone combo step: ", pick)
		if pick == "quake":
			_attack_quake()
		else:
			_attack_ground_flip()
		return

	# 首次攻击必定滚石
	if _is_first_attack:
		_is_first_attack = false
		print("Boss Stone first attack: Rolling Stones")
		_attack_rolling_stones()
		return

	# 洗牌循环: 队列空了则重新洗牌
	if _skill_queue.is_empty():
		_skill_queue = ["rolling", "slap_or_flip", "falling_combo", "quake"]
		_skill_queue.shuffle()
		print("Boss Stone new skill cycle: ", _skill_queue)

	var next_skill = _skill_queue.pop_front()
	print("Boss Stone skill from queue: ", next_skill)

	match next_skill:
		"rolling":
			if is_rolling_stones_active:
				# 滚石还在活动中，跳过这个放回队尾取下一个
				_skill_queue.append("rolling")
				_choose_attack()
				return
			_attack_rolling_stones()
		"slap_or_flip":
			var pick = [4, 5][randi() % 2]
			if pick == 4:
				_attack_slap()
			else:
				_attack_ground_flip()
		"falling_combo":
			_combo_step = 1 # 落石后进入组合技流程
			_attack_falling_stones()
		"quake":
			_attack_quake()

# ========================================================
# 技能1: 滚石
# ========================================================
func _attack_rolling_stones():
	print("Attack: Rolling Stones")
	is_rolling_stones_active = true
	Global.emit_signal("boss_chant_start", "滚石", 3.0)

	# 使用 Timer 持续生成滚石（fire-and-forget）
	var stone_timer = Timer.new()
	add_child(stone_timer)
	stone_timer.wait_time = ROLLING_STONE_INTERVAL
	stone_timer.one_shot = false
	var stones_spawned := [0]
	var total_stones := int(ROLLING_STONE_DURATION / ROLLING_STONE_INTERVAL)
	stone_timer.timeout.connect(func():
		if is_dead or stones_spawned[0] >= total_stones:
			stone_timer.stop()
			stone_timer.queue_free()
			is_rolling_stones_active = false
			return
		_spawn_rolling_stone_with_warning()
		stones_spawned[0] += 1
	)
	# 立刻生成第一个
	_spawn_rolling_stone_with_warning()
	stones_spawned[0] += 1
	stone_timer.start()

	# Boss 仅停顿 3 秒，之后恢复行动（滚石在后台继续生成）
	await get_tree().create_timer(3.0).timeout
	Global.emit_signal("boss_chant_end")
	is_attacking = false

func _spawn_rolling_stone_with_warning():
	var from_left := (randi() % 2 == 0)
	var y_pos := randf_range(250.0, 750.0)
	# 使用相机边界外侧作为滚石和预警的起止点
	var screen_left := -300.0 # 超出相机 limit_left(-261)
	var screen_right := 300.0 # 超出相机 limit_right(255)
	var start_x: float
	var end_x: float
	var warn_start: Vector2
	var warn_end: Vector2
	if from_left:
		start_x = screen_left - 40.0
		end_x = screen_right + 40.0
		warn_start = Vector2(screen_left, y_pos)
		warn_end = Vector2(screen_right, y_pos)
	else:
		start_x = screen_right + 40.0
		end_x = screen_left - 40.0
		warn_start = Vector2(screen_right, y_pos)
		warn_end = Vector2(screen_left, y_pos)

	# 预警矩形 — 挂到场景根节点，避免跟随 Boss 移动
	var warn = WarnRectUtil.new()
	get_tree().current_scene.add_child(warn)
	warn.start_warning(warn_start, warn_end, ROLLING_STONE_WIDTH, ROLLING_STONE_WARNING_TIME, 0.0, "落石翻滚")
	warn.warning_finished.connect(func(): _spawn_rolling_stone(Vector2(start_x, y_pos), Vector2(end_x, y_pos), warn))

func _spawn_rolling_stone(start_pos: Vector2, end_pos: Vector2, warn_node: Node):
	if is_instance_valid(warn_node):
		warn_node.cleanup()

	var stone = Area2D.new()
	stone.add_to_group("boss_projectile")
	stone.global_position = start_pos

	# 碰撞体
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 16.0
	col.shape = shape
	stone.add_child(col)

	# 像素风滚石动画
	var anim_sprite = AnimatedSprite2D.new()
	anim_sprite.sprite_frames = _get_rolling_stone_frames()
	anim_sprite.play("roll")
	anim_sprite.z_index = 2
	stone.add_child(anim_sprite)

	get_tree().current_scene.add_child(stone)

	var direction = (end_pos - start_pos).normalized()
	var travel_distance = start_pos.distance_to(end_pos)
	var travel_time = travel_distance / ROLLING_STONE_SPEED

	# 滚石移动
	var tween = stone.create_tween()
	tween.tween_property(stone, "global_position", end_pos, travel_time)
	tween.finished.connect(func():
		if is_instance_valid(stone):
			stone.queue_free()
	)

	# 连接碰撞信号
	stone.body_entered.connect(func(body: Node2D):
		if body is CharacterBody2D and not PC.invincible:
			var actual_damage = int(atk * 1.2 * (1.0 - PC.damage_reduction_rate))
			PC.player_hit(int(actual_damage), self , "攻击")
			if PC.pc_hp <= 0:
				PC.player_instance.game_over()
	)

# ========================================================
# 技能2: 连续冲锋
# ========================================================
func _attack_consecutive_charge():
	print("Attack: Consecutive Charge")
	allow_turning = false
	is_charging = true

	for i in range(CHARGE_COUNT):
		if is_dead or is_stunned:
			break

		var player_pos = PC.player_instance.global_position
		var charge_dir = global_position.direction_to(player_pos)
		if charge_dir == Vector2.ZERO:
			charge_dir = Vector2.RIGHT

		# 设置朝向
		sprite.flip_h = charge_dir.x < 0

		# 显示冲锋预警线 + 读条
		Global.emit_signal("boss_chant_start", "冲锋" + str(i + 1), CHARGE_WARNING_TIME)
		_show_charge_warning(charge_dir)
		await get_tree().create_timer(CHARGE_WARNING_TIME).timeout
		Global.emit_signal("boss_chant_end")

		# 计算冲锋终点（不预先clamp，保持方向正确）
		var charge_target = global_position + charge_dir * CHARGE_DISTANCE

		var charge_speed_val = speed * CHARGE_SPEED_MULT
		var dist = global_position.distance_to(charge_target)
		var charge_time = dist / charge_speed_val if charge_speed_val > 0 else 0.0

		$BossStone.play("run")

		# 执行冲锋 — 沿原始方向移动，逐帧clamp边界
		var start_pos = global_position
		var elapsed = 0.0
		var hit_stone = false
		while elapsed < charge_time and not is_dead:
			var dt = get_process_delta_time()
			elapsed += dt
			var progress_ratio = min(elapsed / charge_time, 1.0)
			var new_pos = start_pos.lerp(charge_target, progress_ratio)
			new_pos.x = clamp(new_pos.x, CHARGE_LEFT, CHARGE_RIGHT)
			new_pos.y = clamp(new_pos.y, CHARGE_TOP, CHARGE_BOTTOM)
			global_position = new_pos

			# 检测与石块碰撞
			for block in stone_blocks:
				if is_instance_valid(block) and global_position.distance_to(block.global_position) < 30.0:
					hit_stone = true
					_destroy_stone_block(block)
					break
			if hit_stone:
				break

			# 沿途伤害判定
			if PC.player_instance and not PC.invincible:
				if global_position.distance_to(PC.player_instance.global_position) < 25.0:
					var dmg = int(atk * 1.5 * (1.0 - PC.damage_reduction_rate))
					PC.player_hit(int(dmg), self , "攻击")
					if PC.pc_hp <= 0:
						PC.player_instance.game_over()
			await get_tree().process_frame

		if hit_stone:
			# 撞到石块 — 眩晕 + 损失10%HP
			print("Boss hit stone block! Stunned! Lost 10%% HP!")
			var hp_loss = int(hpMax * 0.1)
			hp -= hp_loss
			Global.emit_signal("boss_hp_bar_take_damage", hp_loss)
			if hp <= 0:
				_die()
				return
			_apply_stun(2.0)
			break

		# 冲锋间短暂间隔
		await get_tree().create_timer(0.3).timeout

	is_charging = false
	allow_turning = true
	if not is_stunned:
		is_attacking = false

func _show_charge_warning(direction: Vector2):
	var warn_line = Node2D.new()
	add_child(warn_line)
	warn_line.global_position = global_position

	var outer = Line2D.new()
	outer.default_color = Color(1.0, 0.3, 0.0, 0.45)
	outer.width = 44
	outer.add_point(Vector2.ZERO)
	outer.add_point(direction * CHARGE_DISTANCE)
	outer.modulate.a = 0.0
	warn_line.add_child(outer)

	var inner = Line2D.new()
	inner.default_color = Color(1.0, 0.8, 0.2, 0.7)
	inner.width = 32
	inner.add_point(Vector2.ZERO)
	inner.add_point(direction * CHARGE_DISTANCE)
	inner.modulate.a = 0.0
	warn_line.add_child(inner)

	var tw = create_tween().set_parallel(true)
	tw.tween_property(outer, "modulate:a", 1.0, 0.15)
	tw.tween_property(inner, "modulate:a", 1.0, 0.15)

	# 自动清除
	get_tree().create_timer(CHARGE_WARNING_TIME).timeout.connect(func():
		if is_instance_valid(warn_line):
			var fade = create_tween().set_parallel(true)
			fade.tween_property(outer, "modulate:a", 0.0, 0.1)
			fade.tween_property(inner, "modulate:a", 0.0, 0.1)
			fade.finished.connect(func():
				if is_instance_valid(warn_line):
					warn_line.queue_free()
			)
	)

func _apply_stun(duration: float):
	is_stunned = true
	is_attacking = true
	is_charging = false
	$BossStone.play("idle")

	# 眩晕视觉：闪白
	var blink_tw = create_tween()
	blink_tw.set_loops(int(duration * 3))
	blink_tw.tween_property(sprite, "modulate", Color(0.7, 0.7, 1.0, 1.0), 0.15)
	blink_tw.tween_property(sprite, "modulate", Color.WHITE, 0.15)

	await get_tree().create_timer(duration).timeout
	is_stunned = false
	sprite.modulate = Color.WHITE
	allow_turning = true
	is_attacking = false

func _destroy_stone_block(block: Node2D):
	stone_blocks.erase(block)
	# 碎裂特效
	_spawn_stone_break_effect(block.global_position)
	if is_instance_valid(block):
		block.queue_free()

# ========================================================
# 技能3: 落石
# ========================================================
func _attack_falling_stones():
	print("Attack: Falling Stones")
	Global.emit_signal("boss_chant_start", "落石", FALLING_STONE_WARNING_TIME)

	var boss_pos = global_position
	var player_pos = PC.player_instance.global_position

	# Boss脚下 — 只有伤害和视觉特效，不生成石块
	var warn_boss = WarnCircleUtil.new()
	add_child(warn_boss)
	warn_boss.warning_finished.connect(func():
		if is_instance_valid(warn_boss):
			warn_boss.cleanup()
		_spawn_stone_impact_effect(boss_pos)
		_screen_shake(5.0, 0.2)
	)
	warn_boss.start_warning(
		boss_pos, 1.2, FALLING_STONE_RADIUS,
		FALLING_STONE_WARNING_TIME, atk * 2.0, "巨石砸击", null,
		WarnCircleUtil.ReleaseMode.INSTANT_DAMAGE
	)

	await get_tree().create_timer(0.3).timeout

	# 玩家位置 — 伤害 + 石块 + 击飞
	var player_target = player_pos
	var warn_player = WarnCircleUtil.new()
	add_child(warn_player)
	warn_player.warning_finished.connect(func():
		if is_instance_valid(warn_player):
			warn_player.cleanup()
		_spawn_stone_impact_effect(player_target)
		_spawn_stone_block(player_target)
		_screen_shake(6.0, 0.25)
	)
	warn_player.damage_dealt.connect(func(_d):
		_knockback_player_from(player_target, 50.0)
	)
	warn_player.start_warning(
		player_target, 1.2, FALLING_STONE_RADIUS,
		FALLING_STONE_WARNING_TIME, atk * 2.0, "巨石砸击", null,
		WarnCircleUtil.ReleaseMode.INSTANT_DAMAGE
	)

	await get_tree().create_timer(FALLING_STONE_WARNING_TIME + 0.5).timeout
	Global.emit_signal("boss_chant_end")
	is_attacking = false

func _knockback_player_from(impact_pos: Vector2, distance: float):
	if not PC.player_instance or not is_instance_valid(PC.player_instance):
		return
	var dir = impact_pos.direction_to(PC.player_instance.global_position)
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	PC.player_instance.global_position += dir * distance

func _spawn_stone_block(pos: Vector2):
	var block = StaticBody2D.new()
	block.add_to_group("stone_block")
	block.global_position = pos
	block.z_index = 0

	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(32.0, 51.8) # 10*3=30宽, 12*3*1.3=46.8高
	col.shape = shape
	block.add_child(col)

	# 像素风石块精灵 — Y轴再拉高20%
	var block_sprite = Sprite2D.new()
	block_sprite.texture = _get_stone_block_texture()
	block_sprite.scale.y = 1.2
	block.add_child(block_sprite)

	get_tree().current_scene.add_child(block)
	stone_blocks.append(block)

	# 石块持续时间后自动消失
	get_tree().create_timer(STONE_BLOCK_DURATION).timeout.connect(func():
		if is_instance_valid(block):
			stone_blocks.erase(block)
			var fade_tw = block.create_tween()
			fade_tw.tween_property(block, "modulate:a", 0.0, 0.5)
			fade_tw.finished.connect(func():
				if is_instance_valid(block):
					block.queue_free()
			)
	)

# ========================================================
# 技能4: 拍击（扇形连续攻击）
# ========================================================
func _attack_slap():
	print("Attack: Slap")

	for i in range(SLAP_ROUNDS):
		if is_dead:
			break
		var player_pos = PC.player_instance.global_position
		var dir_to_player = global_position.direction_to(player_pos)
		var target_point = global_position + dir_to_player * SLAP_RADIUS

		# 第一下预警时间 +1秒
		var cur_warn_time = SLAP_WARNING_TIME + 1.0 if i == 0 else SLAP_WARNING_TIME

		# 读条 UI
		Global.emit_signal("boss_chant_start", "拍击" + str(i + 1), cur_warn_time)

		var warn = WarnSectorUtil.new()
		add_child(warn)
		warn.warning_finished.connect(func():
			if is_instance_valid(warn):
				_spawn_slap_effect(global_position, dir_to_player)
				_screen_shake(6.0, 0.2)
				warn.cleanup()
		)
		warn.damage_dealt.connect(func(d): print("拍击伤害: ", d))
		warn.start_warning(
			global_position, target_point, SLAP_SECTOR_ANGLE,
			cur_warn_time, atk * 1.8, "拍击", null, cur_warn_time * 0.4
		)
		await get_tree().create_timer(cur_warn_time + 0.25).timeout
		Global.emit_signal("boss_chant_end")

	is_attacking = false

# ========================================================
# 技能5: 掀地（扇形攻击 + 泥潭）
# ========================================================
func _attack_ground_flip():
	print("Attack: Ground Flip")

	var player_pos = PC.player_instance.global_position
	var dir_to_player = global_position.direction_to(player_pos)
	var target_point = global_position + dir_to_player * FLIP_RADIUS

	Global.emit_signal("boss_chant_start", "掀地", FLIP_WARNING_TIME)

	# 扇形预警
	var warn = WarnSectorUtil.new()
	add_child(warn)
	var sector_center_dir = dir_to_player
	warn.warning_finished.connect(func():
		if is_instance_valid(warn):
			warn.cleanup()
		# 生成泥潭 + 屏幕震颤
		_spawn_mud_pool(global_position, sector_center_dir, FLIP_RADIUS, FLIP_SECTOR_ANGLE)
		_screen_shake(3.0, 0.25)
	)
	warn.damage_dealt.connect(func(d): print("掀地伤害: ", d))
	warn.start_warning(
		global_position, target_point, FLIP_SECTOR_ANGLE,
		FLIP_WARNING_TIME, atk * 2.0, "掀地", null, FLIP_WARNING_TIME * 0.5
	)

	await get_tree().create_timer(FLIP_WARNING_TIME + 0.3).timeout
	Global.emit_signal("boss_chant_end")
	# 掀地特效
	_spawn_ground_flip_effect(global_position, sector_center_dir)
	await get_tree().create_timer(0.5).timeout
	is_attacking = false

# ========================================================
# 技能6: 震地 — 以自身为中心步进扩大伤害圈
# ========================================================
func _attack_quake():
	print("Attack: Quake")

	var origin = global_position
	for round_i in range(QUAKE_ROUNDS):
		if is_dead:
			break
		var t = float(round_i + 1) / float(QUAKE_ROUNDS)
		var cur_radius = lerp(QUAKE_INITIAL_RADIUS, QUAKE_MAX_RADIUS, t)

		# 读条
		Global.emit_signal("boss_chant_start", "震地" + str(round_i + 1), QUAKE_ROUND_WARNING)

		# 预警圈
		var warn = WarnCircleUtil.new()
		add_child(warn)
		warn.start_warning(
			origin, 1.0, cur_radius,
			QUAKE_ROUND_WARNING, 0.0, "地震波", null,
			WarnCircleUtil.ReleaseMode.INSTANT_DAMAGE
		)
		warn.warning_finished.connect(func():
			if is_instance_valid(warn):
				warn.cleanup()
		)

		await get_tree().create_timer(QUAKE_ROUND_WARNING).timeout
		Global.emit_signal("boss_chant_end")

		# 伤害判定
		if is_instance_valid(PC.player_instance) and not PC.invincible:
			var dist = origin.distance_to(PC.player_instance.global_position)
			if dist <= cur_radius:
				var dmg = max(1, int(atk * 1.5))
				PC.player_hit(int(dmg), self , "攻击")
				if PC.pc_hp <= 0:
					PC.player_instance.game_over()

		# 崩散粒子特效 + 屏幕震颤
		_spawn_quake_particles(origin, cur_radius, round_i)
		_screen_shake(8.0 + round_i * 3.0, 0.25)

		# 间隔
		if round_i < QUAKE_ROUNDS - 1:
			await get_tree().create_timer(QUAKE_ROUND_GAP).timeout

	await get_tree().create_timer(0.5).timeout
	is_attacking = false

func _spawn_quake_particles(origin: Vector2, radius: float, step: int):
	# 像素风粒子特效 — 在当前伤害圈边缘崩散大量粒子
	var P := 3 # 像素尺寸
	var count = 48 + step * 22 # 每步粒子数+50%
	var colors = [
		Color(0.45, 0.38, 0.25, 1.0), # 泥土色
		Color(0.60, 0.52, 0.35, 1.0), # 浅土色
		Color(0.35, 0.30, 0.22, 1.0), # 深石色
		Color(0.70, 0.62, 0.45, 1.0), # 亮土色
	]

	for i in range(count):
		var angle = randf() * TAU
		var spawn_r = radius * randf_range(0.7, 1.0)
		var spawn_pos = origin + Vector2(cos(angle), sin(angle)) * spawn_r
		# 像素对齐
		spawn_pos.x = round(spawn_pos.x / P) * P
		spawn_pos.y = round(spawn_pos.y / P) * P

		var chip = Node2D.new()
		chip.global_position = spawn_pos
		chip.z_index = 4
		get_tree().current_scene.add_child(chip)

		# 绘制像素方块粒子
		var drawer = _QuakeParticle.new()
		var size_cells = randi_range(1, 3) # 1~3个像素块大小
		drawer.cell_size = P
		drawer.cells = size_cells
		drawer.color = colors[randi() % colors.size()]
		chip.add_child(drawer)

		# 向外飞散
		var fly_dir = Vector2(cos(angle), sin(angle))
		var fly_dist = randf_range(15, 45)
		var fly_time = randf_range(0.3, 0.6)
		var target = spawn_pos + fly_dir * fly_dist
		target.x = round(target.x / P) * P
		target.y = round(target.y / P) * P

		var tw = chip.create_tween().set_parallel(true)
		tw.tween_property(chip, "global_position", target, fly_time)
		tw.tween_property(chip, "modulate:a", 0.0, fly_time)
		# 随机向上抛起感
		var rise = randf_range(-20, -5)
		tw.tween_property(chip, "global_position:y", target.y + rise, fly_time * 0.5)
		tw.finished.connect(func():
			if is_instance_valid(chip):
				chip.queue_free()
		)

# 像素粒子绘制内部类
class _QuakeParticle extends Node2D:
	var cell_size: int = 3
	var cells: int = 1
	var color: Color = Color.WHITE

	func _draw():
		var total = cells * cell_size
		var offset = - total / 2
		for cy in cells:
			for cx in cells:
				draw_rect(Rect2(offset + cx * cell_size, offset + cy * cell_size, cell_size, cell_size), color)

func _spawn_mud_pool(origin: Vector2, direction: Vector2, radius: float, angle_deg: float):
	var pool = Area2D.new()
	pool.add_to_group("mud_pool")
	pool.global_position = origin
	pool.z_index = -1

	# 不再用碰撞体近似扇形，改用手动角度+距离判定
	var half_angle_rad = deg_to_rad(angle_deg) / 2.0
	var center_angle = direction.angle()

	# 泥潭视觉 — 用 _draw 实现
	var drawer = _MudPoolDrawer.new()
	drawer.pool_radius = radius
	drawer.pool_angle = deg_to_rad(angle_deg)
	drawer.pool_direction = center_angle
	pool.add_child(drawer)

	pool.modulate.a = 0.0
	get_tree().current_scene.add_child(pool)

	# 渐入
	var tw = pool.create_tween()
	tw.tween_property(pool, "modulate:a", 0.7, 0.4)

	# 用Timer驱动持续伤害，手动判断扇形范围
	_start_mud_pool_process(pool, origin, center_angle, half_angle_rad, radius)

func _is_player_in_sector(origin: Vector2, center_angle: float, half_angle: float, radius: float) -> bool:
	if not PC.player_instance or not is_instance_valid(PC.player_instance):
		return false
	var player_pos = PC.player_instance.global_position
	var dist = origin.distance_to(player_pos)
	if dist > radius:
		return false
	var angle_to_player = (player_pos - origin).angle()
	var angle_diff = angle_difference(center_angle, angle_to_player)
	return abs(angle_diff) <= half_angle

func _start_mud_pool_process(pool: Node, origin: Vector2, center_angle: float, half_angle: float, radius: float):
	var timer = Timer.new()
	timer.wait_time = 0.05
	timer.autostart = true
	var life := [0.0]
	var tick := [0.0]
	pool.add_child(timer)

	timer.timeout.connect(func():
		life[0] += timer.wait_time
		# 手动判断玩家是否在扇形范围内
		var player_inside = _is_player_in_sector(origin, center_angle, half_angle, radius)
		if player_inside and not PC.invincible:
			tick[0] += timer.wait_time
			if tick[0] >= MUD_POOL_DAMAGE_TICK:
				tick[0] -= MUD_POOL_DAMAGE_TICK
				var dmg = max(1, int(atk * 0.3))
				PC.player_hit(int(dmg), self , "攻击")
				if PC.pc_hp <= 0:
					PC.player_instance.game_over()
		else:
			tick[0] = 0.0
		if life[0] >= MUD_POOL_DURATION - 0.8:
			pool.modulate.a = max(0.0, pool.modulate.a - timer.wait_time * 1.2)
		if life[0] >= MUD_POOL_DURATION:
			if is_instance_valid(pool):
				pool.queue_free()
	)

# 泥潭绘制内部类
class _MudPoolDrawer extends Node2D:
	var pool_radius: float = 100.0
	var pool_angle: float = 1.57
	var pool_direction: float = 0.0
	var pulse_time: float = 0.0

	func _process(delta):
		pulse_time += delta
		queue_redraw()

	func _draw():
		var P := 3 # 像素尺寸
		var half_a := pool_angle / 2.0
		var r := pool_radius
		var arc_steps := 32
	
		# --- 1. 像素化填充扇形底色 ---
		var base_col := Color(0.38, 0.25, 0.10, 0.75)
		var base_pts := PackedVector2Array()
		base_pts.append(Vector2.ZERO)
		for i in range(arc_steps + 1):
			var a = pool_direction - half_a + pool_angle * float(i) / float(arc_steps)
			var pt = Vector2(cos(a), sin(a)) * r
			pt.x = round(pt.x / P) * P
			pt.y = round(pt.y / P) * P
			base_pts.append(pt)
		draw_polygon(base_pts, PackedColorArray([base_col]))
	
		# --- 2. 像素化同心波浪纹 ---
		var wave_count := 6
		for wi in range(1, wave_count + 1):
			var ratio := float(wi) / float(wave_count)
			var wave_r := r * ratio
			var amp := 2.0 + ratio * 3.0
			var freq := 4.0 + float(wi) * 1.5
			var phase := pulse_time * (1.5 + ratio * 0.8) + float(wi) * 1.2
			var alpha := 0.25 + ratio * 0.5
			var wave_col := Color(0.55, 0.38, 0.15, alpha)
	
			var pts := PackedVector2Array()
			for i in range(arc_steps + 1):
				var t := float(i) / float(arc_steps)
				var a = pool_direction - half_a + pool_angle * t
				var wave_offset := sin(a * freq + phase) * amp
				var cur_r := wave_r + wave_offset
				var pt := Vector2(cos(a), sin(a)) * cur_r
				pt.x = round(pt.x / P) * P
				pt.y = round(pt.y / P) * P
				pts.append(pt)
			draw_polyline(pts, wave_col, float(P))
	
		# --- 3. 像素化浅色波峰纹 ---
		for wi in range(1, wave_count):
			var ratio := (float(wi) + 0.5) / float(wave_count)
			var wave_r := r * ratio
			var amp := 1.5 + ratio * 2.5
			var freq := 5.0 + float(wi) * 1.2
			var phase := pulse_time * 2.0 + float(wi) * 2.5 + 1.0
			var alpha := 0.15 + ratio * 0.3
			var highlight_col := Color(0.65, 0.50, 0.25, alpha)
	
			var pts := PackedVector2Array()
			for i in range(arc_steps + 1):
				var t := float(i) / float(arc_steps)
				var a = pool_direction - half_a + pool_angle * t
				var wave_offset := sin(a * freq + phase) * amp
				var cur_r := wave_r + wave_offset
				var pt := Vector2(cos(a), sin(a)) * cur_r
				pt.x = round(pt.x / P) * P
				pt.y = round(pt.y / P) * P
				pts.append(pt)
			draw_polyline(pts, highlight_col, float(P))
	
		# --- 4. 像素化泥泡涟漪 ---
		var bubble_col := Color(0.50, 0.38, 0.15, 0.8)
		for i in range(4):
			var ba := pool_direction + (float(i) / 4.0 - 0.375) * pool_angle * 0.6
			var br := r * (0.25 + 0.15 * sin(pulse_time * 1.8 + float(i) * 1.5))
			var bpos := Vector2(cos(ba), sin(ba)) * br
			bpos.x = round(bpos.x / P) * P
			bpos.y = round(bpos.y / P) * P
			var bsize := 2.0 + sin(pulse_time * 2.5 + float(i) * 2.0) * 1.0
			if bsize > 1.0:
				var half := int(ceil(bsize / P)) * P
				draw_rect(Rect2(bpos.x - half, bpos.y - half, half * 2, half * 2), bubble_col)

# ========================================================
# 碰撞 / 受伤 / 死亡
# ========================================================
func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and not is_dead and not PC.invincible:
		var actual_damage = int(atk * (1.0 - PC.damage_reduction_rate))
		PC.player_hit(int(actual_damage), self , "攻击")
		if PC.pc_hp <= 0:
			body.game_over()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("bullet") and area.has_method("get_bullet_damage_and_crit_status"):
		if not _is_monster_in_damage_range():
			return
		var collision_result = BulletCalculator.handle_bullet_collision_full(area, self , true)
		var final_damage_val = collision_result["final_damage"]
		var is_crit = collision_result["is_crit"]

		Global.emit_signal("boss_hp_bar_take_damage", final_damage_val)
		hp -= int(final_damage_val)

		if collision_result["should_rebound"]:
			area.call_deferred("create_rebound")
		if collision_result["should_delete_bullet"]:
			area.queue_free()

		if hp <= 0:
			_die()
		else:
			Global.play_hit_anime(position, is_crit)

func take_damage(damage: int, is_crit: bool, is_summon: bool, damage_type: String) -> void:
	if is_dead:
		return
	if not _is_monster_in_damage_range():
		return
	var final_damage_val = int(damage)

	if damage_type in ["bleed", "burn", "electrified", "corrosion", "corrosion2", "posion"]:
		Global.emit_signal("boss_hp_bar_take_damage", final_damage_val)
		hp -= final_damage_val
		if hp <= 0:
			_die()
		return

	var damage_offset = Vector2(randf_range(-15, 15), randf_range(-15, 15))
	if is_summon:
		Global.emit_signal("monster_damage", 4, final_damage_val, global_position - Vector2(35, 20) + damage_offset, damage_type)
	elif is_crit:
		Global.emit_signal("monster_damage", 2, final_damage_val, global_position - Vector2(35, 20) + damage_offset, damage_type)
	else:
		Global.emit_signal("monster_damage", 1, final_damage_val, global_position - Vector2(35, 20) + damage_offset, damage_type)
	Global.emit_signal("boss_hp_bar_take_damage", final_damage_val)
	hp -= final_damage_val
	if hp <= 0:
		_die()
	else:
		Global.play_hit_anime(position, is_crit)

func _die():
	if not is_dead:
		Global.emit_signal("boss_defeated", get_point)
		Global.emit_signal("monster_killed")
	is_dead = true
	remove_from_group("enemies")
	is_attacking = false
	# 停止技能计时器、清理读条 UI
	attack_timer.stop()
	Global.emit_signal("boss_chant_end")
	# 清理所有石块
	for block in stone_blocks:
		if is_instance_valid(block):
			block.queue_free()
	stone_blocks.clear()

	var collision_shape = get_node("CollisionShape2D")
	collision_shape.disabled = true
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	var shadow = get_node_or_null("Shadow")
	if shadow:
		shadow.visible = false
	queue_free()

func apply_knockback(_direction: Vector2, _force: float):
	pass # Boss免疫击退

# 屏幕震颤效果
func _screen_shake(intensity: float = 6.0, duration: float = 0.3, frequency: float = 30.0):
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	var original_offset = camera.offset
	var elapsed := 0.0
	while elapsed < duration:
		var dt = get_process_delta_time()
		elapsed += dt
		var strength = intensity * (1.0 - elapsed / duration)
		camera.offset = original_offset + Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)
		await get_tree().process_frame
	camera.offset = original_offset

func _is_monster_in_damage_range() -> bool:
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return true
	var viewport_size = get_viewport().get_visible_rect().size
	var camera_zoom = camera.zoom
	var visible_size = viewport_size / camera_zoom
	var camera_pos = camera.global_position
	var half = visible_size / 2
	var margin = 20.0
	var wm_x = margin / camera_zoom.x if camera_zoom.x != 0 else 0.0
	var wm_y = margin / camera_zoom.y if camera_zoom.y != 0 else 0.0
	var monster_pos = global_position
	return (monster_pos.x >= camera_pos.x - half.x - wm_x and
			monster_pos.x <= camera_pos.x + half.x + wm_x and
			monster_pos.y >= camera_pos.y - half.y - wm_y and
			monster_pos.y <= camera_pos.y + half.y + wm_y)

# ========================================================
# 像素风格资源构建
# ========================================================

# --- 滚石动画帧 ---
func _get_rolling_stone_frames() -> SpriteFrames:
	if _rolling_stone_frames_cache != null:
		return _rolling_stone_frames_cache
	_rolling_stone_frames_cache = _build_rolling_stone_frames()
	return _rolling_stone_frames_cache

func _build_rolling_stone_frames() -> SpriteFrames:
	var frames = SpriteFrames.new()
	frames.add_animation("roll")
	var P := 3
	var grid := 12
	var img_size := grid * P
	var col_dark := Color(0.30, 0.28, 0.25, 1.0)
	var col_mid := Color(0.55, 0.50, 0.42, 1.0)
	var col_hi := Color(0.72, 0.67, 0.58, 1.0)

	# 石头圆形图案
	var pattern: Array = [
		[0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0],
		[0, 0, 1, 2, 2, 2, 2, 2, 1, 0, 0, 0],
		[0, 1, 2, 2, 3, 3, 2, 2, 2, 1, 0, 0],
		[1, 2, 2, 3, 3, 2, 2, 2, 2, 2, 1, 0],
		[1, 2, 3, 3, 2, 2, 2, 2, 2, 2, 1, 0],
		[1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 0],
		[1, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 0],
		[1, 2, 2, 2, 2, 2, 2, 2, 2, 1, 0, 0],
		[0, 1, 2, 2, 2, 2, 2, 2, 1, 1, 0, 0],
		[0, 1, 1, 2, 2, 2, 2, 1, 1, 0, 0, 0],
		[0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0],
		[0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0],
	]
	# 4帧旋转动画（0°, 90°, 180°, 270° 绕中心旋转）
	for f_idx in 4:
		var img = Image.create(img_size, img_size, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for r in grid:
			for c in grid:
				# 根据帧索引做真正的90度旋转采样
				var src_r: int = r
				var src_c: int = c
				match f_idx:
					1: # 90° CW
						src_r = grid - 1 - c
						src_c = r
					2: # 180°
						src_r = grid - 1 - r
						src_c = grid - 1 - c
					3: # 270° CW
						src_r = c
						src_c = grid - 1 - r
				var cell = pattern[src_r][src_c]
				if cell == 0:
					continue
				var color: Color
				match cell:
					1: color = col_dark
					2: color = col_mid
					3: color = col_hi
					_: continue
				for py in P:
					for px in P:
						var ix = c * P + px
						var iy = r * P + py
						if ix < img_size and iy < img_size:
							img.set_pixel(ix, iy, color)
		frames.add_frame("roll", ImageTexture.create_from_image(img))
	frames.set_animation_speed("roll", 8.0)
	frames.set_animation_loop("roll", true)
	return frames

# --- 石块纹理 ---
func _get_stone_block_texture() -> ImageTexture:
	if _stone_block_texture_cache != null:
		return _stone_block_texture_cache
	_stone_block_texture_cache = _build_stone_block_texture()
	return _stone_block_texture_cache

func _build_stone_block_texture() -> ImageTexture:
	var P := 3
	var grid_w := 10
	var grid_h := 11 # 竖直石块，底部平切
	var img_w := grid_w * P
	var img_h := grid_h * P
	var col_dark := Color(0.30, 0.28, 0.24, 1.0)
	var col_mid := Color(0.50, 0.46, 0.38, 1.0)
	var col_hi := Color(0.68, 0.63, 0.52, 1.0)
	var col_edge := Color(0.22, 0.20, 0.17, 1.0)

	# 10×12 竖向石块图案（0=透明 1=边缘 2=中间 3=高光 4=暗角）
	# 底部用直线封底，不带弧度
	var pattern: Array = [
		[0, 0, 1, 1, 1, 1, 1, 1, 0, 0],
		[0, 1, 1, 2, 2, 2, 2, 1, 1, 0],
		[1, 1, 3, 3, 2, 2, 2, 2, 1, 1],
		[1, 2, 3, 3, 2, 2, 2, 2, 2, 1],
		[1, 2, 2, 3, 2, 2, 2, 2, 2, 1],
		[1, 2, 2, 2, 2, 2, 2, 2, 2, 1],
		[1, 2, 2, 2, 2, 2, 3, 2, 2, 1],
		[1, 2, 2, 4, 2, 2, 2, 2, 2, 1],
		[1, 2, 2, 2, 2, 2, 2, 3, 2, 1],
		[1, 2, 2, 3, 2, 2, 4, 2, 2, 1],
		[1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
	]
	var img = Image.create(img_w, img_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for r in grid_h:
		for c in grid_w:
			var cell = pattern[r][c]
			if cell == 0:
				continue
			var color: Color
			match cell:
				1: color = col_edge
				2: color = col_mid
				3: color = col_hi
				4: color = col_dark
				_: continue
			for py in P:
				for px in P:
					img.set_pixel(c * P + px, r * P + py, color)
	return ImageTexture.create_from_image(img)

# --- 落石冲击特效 ---
func _spawn_stone_impact_effect(pos: Vector2):
	if _stone_impact_frames_cache == null:
		_stone_impact_frames_cache = _build_stone_impact_frames()
	var impact = AnimatedSprite2D.new()
	impact.sprite_frames = _stone_impact_frames_cache
	impact.animation = "impact"
	impact.global_position = pos
	impact.z_index = 3
	impact.rotation = randf() * TAU
	get_tree().current_scene.add_child(impact)
	impact.play("impact")
	impact.animation_finished.connect(impact.queue_free)

func _build_stone_impact_frames() -> SpriteFrames:
	var frames = SpriteFrames.new()
	frames.add_animation("impact")
	var P := 4
	var grid := 26 # 范围+50%
	var img_size := grid * P
	var col_dark := Color(0.35, 0.30, 0.22, 1.0)
	var col_mid := Color(0.60, 0.52, 0.38, 1.0)
	var col_hi := Color(0.85, 0.78, 0.60, 1.0)
	var center := 10.0
	var max_dist := 10.5

	for f_idx in 6:
		var img = Image.create(img_size, img_size, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var show_radius: float
		var alpha: float
		if f_idx < 3:
			show_radius = (float(f_idx + 1) / 3.0) * max_dist
			alpha = 1.0
		else:
			show_radius = max_dist
			alpha = 1.0 - float(f_idx - 2) / 4.0

		for r in grid:
			for c in grid:
				var d = sqrt((r - center) * (r - center) + (c - center) * (c - center))
				if d > show_radius or d > max_dist:
					continue
				# 粒子散射图案 — 密度翻倍
				var ring = d / max_dist
				var gxi = int(r) + int(c)
				var draw = false
				var color := col_mid
				if ring > 0.7:
					draw = true # 原来 gxi%2==0，现在全填
					color = col_dark
				elif ring > 0.4:
					draw = true # 原来 gxi%3!=2，现在全填
					color = col_mid
				else:
					draw = true # 原来 gxi%2==0，现在全填
					color = col_hi
				if draw:
					var final_color = Color(color.r, color.g, color.b, color.a * alpha * 0.5)
					for py in P:
						for px in P:
							var ix = c * P + px
							var iy = r * P + py
							if ix < img_size and iy < img_size:
								img.set_pixel(ix, iy, final_color)
		frames.add_frame("impact", ImageTexture.create_from_image(img))
	frames.set_animation_speed("impact", 12.0)
	frames.set_animation_loop("impact", false)
	return frames

# --- 石块碎裂特效 ---
func _spawn_stone_break_effect(pos: Vector2):
	# 简单粒子碎片
	for i in range(6):
		var chip = Sprite2D.new()
		chip.texture = _get_stone_block_texture()
		chip.global_position = pos
		chip.scale = Vector2(0.3, 0.3)
		chip.z_index = 4
		chip.rotation = randf() * TAU
		get_tree().current_scene.add_child(chip)
		var dir = Vector2.from_angle(randf() * TAU)
		var tw = chip.create_tween().set_parallel(true)
		tw.tween_property(chip, "global_position", pos + dir * randf_range(20, 50), 0.4)
		tw.tween_property(chip, "modulate:a", 0.0, 0.4)
		tw.tween_property(chip, "rotation", chip.rotation + randf_range(-3, 3), 0.4)
		tw.finished.connect(func():
			if is_instance_valid(chip):
				chip.queue_free()
		)

# --- 拍击特效 ---
func _spawn_slap_effect(pos: Vector2, direction: Vector2):
	# 扇形碎石粒子 + 像素方块粒子
	var P := 3
	var half_angle = deg_to_rad(SLAP_SECTOR_ANGLE / 2.0)
	var base_angle = direction.angle()
	var colors = [
		Color(0.50, 0.42, 0.30, 1.0),
		Color(0.65, 0.55, 0.38, 1.0),
		Color(0.38, 0.32, 0.22, 1.0),
		Color(0.75, 0.68, 0.50, 1.0),
	]
	# 碎石粒子
	for i in range(21):
		var a = base_angle + randf_range(-half_angle, half_angle)
		var dist = randf_range(20, SLAP_RADIUS * 0.8)
		var chip = Sprite2D.new()
		chip.texture = _get_stone_block_texture()
		chip.global_position = pos
		chip.scale = Vector2(0.2, 0.2)
		chip.z_index = 3
		chip.rotation = randf() * TAU
		get_tree().current_scene.add_child(chip)
		var target = pos + Vector2(cos(a), sin(a)) * dist
		var tw = chip.create_tween().set_parallel(true)
		tw.tween_property(chip, "global_position", target, 0.3)
		tw.tween_property(chip, "modulate:a", 0.0, 0.35)
		tw.finished.connect(func():
			if is_instance_valid(chip):
				chip.queue_free()
		)
	# 像素方块粒子
	for i in range(30):
		var a = base_angle + randf_range(-half_angle, half_angle)
		var spawn_dist = randf_range(10, SLAP_RADIUS * 0.5)
		var spawn_pos = pos + Vector2(cos(a), sin(a)) * spawn_dist
		spawn_pos.x = round(spawn_pos.x / P) * P
		spawn_pos.y = round(spawn_pos.y / P) * P

		var particle = Node2D.new()
		particle.global_position = spawn_pos
		particle.z_index = 4
		get_tree().current_scene.add_child(particle)

		var drawer = _QuakeParticle.new()
		drawer.cell_size = P
		drawer.cells = randi_range(1, 2)
		drawer.color = colors[randi() % colors.size()]
		particle.add_child(drawer)

		var fly_dist = randf_range(25, SLAP_RADIUS * 0.7)
		var target = pos + Vector2(cos(a), sin(a)) * fly_dist
		target.x = round(target.x / P) * P
		target.y = round(target.y / P) * P
		var fly_time = randf_range(0.25, 0.5)

		var tw = particle.create_tween().set_parallel(true)
		tw.tween_property(particle, "global_position", target, fly_time)
		tw.tween_property(particle, "modulate:a", 0.0, fly_time)
		var rise = randf_range(-15, -3)
		tw.tween_property(particle, "global_position:y", target.y + rise, fly_time * 0.4)
		tw.finished.connect(func():
			if is_instance_valid(particle):
				particle.queue_free()
		)

# --- 掀地特效 ---
func _spawn_ground_flip_effect(pos: Vector2, direction: Vector2):
	# 地面掀起碎土粒子
	var half_angle = deg_to_rad(FLIP_SECTOR_ANGLE / 2.0)
	var base_angle = direction.angle()
	for i in range(12):
		var a = base_angle + randf_range(-half_angle, half_angle)
		var dist = randf_range(15, FLIP_RADIUS * 0.9)
		var chip = Sprite2D.new()
		chip.texture = _get_stone_block_texture()
		chip.global_position = pos + Vector2(cos(a), sin(a)) * dist * 0.3
		chip.scale = Vector2(0.15, 0.15)
		chip.z_index = 3
		chip.modulate = Color(0.6, 0.45, 0.2, 1.0) # 泥土色
		chip.rotation = randf() * TAU
		get_tree().current_scene.add_child(chip)
		var target = pos + Vector2(cos(a), sin(a)) * dist
		var tw = chip.create_tween().set_parallel(true)
		tw.tween_property(chip, "global_position", target, 0.35)
		tw.tween_property(chip, "modulate:a", 0.0, 0.5)
		tw.finished.connect(func():
			if is_instance_valid(chip):
				chip.queue_free()
		)
