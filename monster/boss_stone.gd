extends "res://Script/monster/monster_base.gd"

## ========================================================
## Boss Stone — 石巨人Boss
## 技能列表：
## 1. 滚石 — 随机从左右刷新横向滚石，1秒预警，12秒每秒2个，Boss仅停4秒
## 2. 连续冲锋 — 落石组合技中触发，撞石减速度+损失石甲
## 3. 落石 — 对脚下(无石块)+玩家位置下砸(生成实体石块+击飞)
## 4. 拍击 — 扇形连续攻击
## 5. 掙地 — 扇形攻击后生成扇形泥潭（减速+受伤）
## 6. 震地 — 以自身为中心步进扩大伤害圈+崩散粒子
## 7. 落石预兆 — 深层以上出现，给玩家多层debuff倒计时后逐个生成落石
## ========================================================

@onready var sprite = $BossStone
var is_attacking: bool = false
var is_charging: bool = false
var is_stunned: bool = false
var allow_turning: bool = true
var is_rolling_stones_active: bool = false

# 技能循环调度
var _is_first_attack: bool = true
var _skill_queue: Array = [] # 当前循环剩余技能组
var _combo_step: int = 0 # 落石组合技内部步骤: 0=落石, 1=拍击/掙地, 2=冲锋

# 屏幕边界
@export var top_boundary: float = -300.0
@export var bottom_boundary: float = 280.0
@export var left_boundary: float = 80.0
@export var right_boundary: float = 550.0

# 移动
var move_direction: int = 4
var target_position: Vector2
var update_move_timer: Timer

# 属性 — 基于stone_man基准 × Boss倍率
var speed: float = SettingMoster.stone_man("speed") * 1.2
var hpMax: float = SettingMoster.stone_man("hp") * 22
var hp: float = hpMax
var atk: float = SettingMoster.stone_man("atk") * 1.0
var get_point: int = SettingMoster.stone_man("point") * 30
var get_exp: int = 0

# 难度系统
var stage_difficulty: String = Global.STAGE_DIFFICULTY_SHALLOW

var attack_timer: Timer
var stun_timer: Timer

# 技能参数
const ROLLING_STONE_WARNING_TIME: float = 1.0
const ROLLING_STONE_SPEED: float = 180.0
const ROLLING_STONE_WIDTH: float = 32.0

# 滚石活动范围（与冲锋边界一致）
const ROLLING_LEFT: float = -330.0
const ROLLING_RIGHT: float = 300.0
const ROLLING_TOP: float = 70.0
const ROLLING_BOTTOM: float = 560.0

const CHARGE_COUNT: int = 3
const CHARGE_SPEED_MULT: float = 14.0
const CHARGE_SPEED_BOOST: float = 1.5 # 冲锋速度永久加成50%
const CHARGE_HIT_SPEED_REDUCTION: float = 0.3 # 撞石头每次降低30%速度
const CHARGE_MAX_REDUCTION_STACKS: int = 2 # 最多降低2次
const CHARGE_WARNING_TIME: float = 1.2
const CHARGE_DISTANCE: float = 500.0

# 冲锋专用边界（与 Boss 移动边界不同）
const CHARGE_LEFT: float = -300.0
const CHARGE_RIGHT: float = 280.0
const CHARGE_TOP: float = 80.0
const CHARGE_BOTTOM: float = 550.0

const FALLING_STONE_RADIUS: float = 50.0
const FALLING_STONE_WARNING_TIME: float = 1.5
const STONE_BLOCK_DURATION: float = 30.0

const SLAP_SECTOR_ANGLE: float = 70.0
const SLAP_RADIUS: float = 360.0
const SLAP_WARNING_TIME: float = 0.8
const SLAP_ROUNDS: int = 3

const FLIP_SECTOR_ANGLE: float = 90.0
const FLIP_RADIUS: float = 210.0
const FLIP_WARNING_TIME: float = 1.5
const MUD_POOL_DURATION: float = 10.0
const MUD_POOL_DAMAGE_TICK: float = 0.5
const MUD_POOL_SLOW_RATE: float = 0.5
const MUD_POOL_FADE_IN: float = 0.6 # 泥潭渐入时间，期间不造成伤害

const QUAKE_INITIAL_RADIUS: float = 50.0 # 震地第1次半径
const QUAKE_MAX_RADIUS: float = 180.0 # 震地第3次半径
const QUAKE_ROUNDS: int = 3 # 释放次数
const QUAKE_ROUND_WARNING: float = 0.8 # 每次预警时间
const QUAKE_ROUND_GAP: float = 0.3 # 每次间隔

# 石块追踪
var stone_blocks: Array = []

# 石甲系统
var stone_armor: int = 0 # 当前石甲层数
var stone_armor_max: int = 0 # 石甲上限

# 落石预兆
var _rockfall_omen_timers: Array = [] # 落石预兆的Timer列表
var _rockfall_omen_buff_ids: Array = [] # 对应的buff id列表

# 冲锋速度降低栈（每次冲锋技能开始重置）
var _charge_speed_reduction_stacks: int = 0

# 诗想难度特殊参数
const POETRY_STONE_SIZE_BOOST: float = 1.2 # 诗想难度石头大小额外+20%
const POETRY_CHARGE_HIT_SPEED_REDUCTION: float = 0.2 # 诗想难度撞石只降20%
const POETRY_CHARGE_MAX_REDUCTION_STACKS: int = 3 # 诗想难度最多叠加3次

# 落石场景
const STONE_STONE_SCENE = preload("res://Scenes/moster/stone_stone.tscn")
const SMALL_FIRE_BULLET = preload("res://Scenes/moster/boss_light_bullet.tscn")
const STONE_BASE_SCALE: float = 1.5 # 浅层基础缩放倍率

# 像素风格缓存
static var _rolling_stone_frames_cache: SpriteFrames = null
static var _stone_impact_frames_cache: SpriteFrames = null
static var _stone_block_texture_cache: ImageTexture = null

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
	# 诗想难度下Boss生命额外提升40倍
	if stage_difficulty == Global.STAGE_DIFFICULTY_POETRY:
		hpMax *= 30
	hp = hpMax
	
	# 浅层难度下Boss只造成50%伤害
	if stage_difficulty == Global.STAGE_DIFFICULTY_SHALLOW:
		atk *= 0.5
	# 诗想难度下Boss攻击额外提升50%
	if stage_difficulty == Global.STAGE_DIFFICULTY_POETRY:
		atk *= 2

	# 石甲初始化：浅层2/深层4/核心6/诗想9
	match stage_difficulty:
		Global.STAGE_DIFFICULTY_SHALLOW:
			stone_armor_max = 2
		Global.STAGE_DIFFICULTY_DEEP:
			stone_armor_max = 4
		Global.STAGE_DIFFICULTY_CORE:
			stone_armor_max = 6
		Global.STAGE_DIFFICULTY_POETRY:
			stone_armor_max = 9
		_:
			stone_armor_max = 2
	stone_armor = stone_armor_max

	setup_monster_base()
	use_debuff_take_damage_multiplier = false
	check_action_disabled_on_body_entered = false

	CharacterEffects.create_shadow(self , 50.0, 16.0, 31.0)

	Global.emit_signal("boss_hp_bar_initialize", hpMax, hp, 12, "石巨人")
	Global.emit_signal("boss_hp_bar_show")
	# 石甲作为boss正面buff显示在血条上
	Global.emit_signal("boss_buff_added", "stone_armor", "石甲", "res://AssetBundle/Sprites/Sprite sheets/skillIcon/panshi.png", 0.0, stone_armor, true, "每层减少10%受到的伤害")

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
	# 深层以上技能衔接时间减少
	if stage_difficulty != Global.STAGE_DIFFICULTY_SHALLOW:
		attack_timer.wait_time = 2.2
	else:
		attack_timer.wait_time = 3.0
	attack_timer.timeout.connect(_choose_attack)
	attack_timer.start()

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
		var new_pos = global_position + direction * speed * delta
		# 非冲锋时石块阻挡Boss移动
		if not is_charging:
			new_pos = _resolve_stone_block_collision(new_pos)
		global_position = new_pos

## 解算石块碰撞：将Boss推出与石块重叠的区域
func _resolve_stone_block_collision(new_pos: Vector2) -> Vector2:
	var boss_radius := 25.0
	for block in stone_blocks:
		if not is_instance_valid(block):
			continue
		var block_radius = 30.0 * block.scale.x
		var min_dist = boss_radius + block_radius
		var offset = new_pos - block.global_position
		var dist = offset.length()
		if dist < min_dist:
			if dist > 0.001:
				new_pos = block.global_position + offset.normalized() * min_dist
			else:
				new_pos = block.global_position + Vector2(min_dist, 0.0)
	return new_pos

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

	# 首次攻击：浅层滚石，深层以上由洗牌队列决定（rockfall_omen固定在队首）
	if _is_first_attack:
		_is_first_attack = false
		if stage_difficulty == Global.STAGE_DIFFICULTY_SHALLOW:
			print("Boss Stone first attack: Rolling Stones")
			_attack_rolling_stones()
			return

	# 洗牌循环: 队列空了则重新洗牌
	if _skill_queue.is_empty():
		# 诗想难度：固定循环顺序
		if stage_difficulty == Global.STAGE_DIFFICULTY_POETRY:
			_skill_queue = ["rockfall_omen", "rolling", "charge", "stone_glow", "falling", "flip"]
		else:
			_skill_queue = ["rolling", "slap_or_flip", "falling_combo", "quake", "stone_glow"]
			_skill_queue.shuffle()
			# 深层以上：落石预兆固定插入队首（每个循环的第一次）
			if stage_difficulty != Global.STAGE_DIFFICULTY_SHALLOW:
				_skill_queue.push_front("rockfall_omen")
		print("Boss Stone new skill cycle: ", _skill_queue)

	var next_skill = _skill_queue.pop_front()
	print("Boss Stone skill from queue: ", next_skill)

	match next_skill:
		"stone_glow":
			_attack_stone_glow()
		"rockfall_omen":
			_attack_rockfall_omen()
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
		"charge":
			# 诗想难度专用：独立冲锋（不作为组合技的一部分）
			_attack_consecutive_charge()
		"falling":
			# 诗想难度专用：独立落石（不触发组合技后续）
			_attack_falling_stones()
		"flip":
			# 诗想难度专用：独立掌地
			_attack_ground_flip()

# ========================================================
# 技能1: 滚石
# ========================================================
func _attack_rolling_stones():
	SEManager.play("110")
	print("Attack: Rolling Stones")
	is_rolling_stones_active = true
	Global.emit_signal("boss_chant_start", "滚石", 2.5)

	# 根据难度决定滚石参数
	var stones_per_second: float = 3.0
	var duration: float = 12.0
	match stage_difficulty:
		Global.STAGE_DIFFICULTY_DEEP:
			stones_per_second = 3.0
			duration = 13.0
		Global.STAGE_DIFFICULTY_CORE:
			stones_per_second = 3.0
			duration = 14.0
		Global.STAGE_DIFFICULTY_POETRY:
			stones_per_second = 4.0
			duration = 16.0

	var interval = 1.0 / stones_per_second

	# 使用 Timer 持续生成滚石（fire-and-forget）
	var stone_timer = Timer.new()
	add_child(stone_timer)
	stone_timer.wait_time = interval
	stone_timer.one_shot = false
	var stones_spawned := [0]
	var total_stones := int(duration * stones_per_second)
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

	# Boss 仅停顿 2 秒，之后恢复行动（滚石在后台继续生成）
	await get_tree().create_timer(2.5).timeout
	Global.emit_signal("boss_chant_end")
	is_attacking = false

func _spawn_rolling_stone_with_warning():
	var from_left := (randi() % 2 == 0)
	# Y范围扩展到整个场地
	var y_pos := randf_range(ROLLING_TOP, ROLLING_BOTTOM)
	var start_x: float
	var end_x: float
	var warn_start: Vector2
	var warn_end: Vector2
	if from_left:
		start_x = ROLLING_LEFT - 40.0
		end_x = ROLLING_RIGHT + 40.0
		warn_start = Vector2(ROLLING_LEFT, y_pos)
		warn_end = Vector2(ROLLING_RIGHT, y_pos)
	else:
		start_x = ROLLING_RIGHT + 40.0
		end_x = ROLLING_LEFT - 40.0
		warn_start = Vector2(ROLLING_RIGHT, y_pos)
		warn_end = Vector2(ROLLING_LEFT, y_pos)

	# 预警矩形 — 挂到场景根节点，避免跟随 Boss 移动
	var warn = WarnRectUtil.new()
	get_tree().current_scene.add_child(warn)
	warn.source_name = "落石翻滚"
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
	shape.radius = 10.0
	col.shape = shape
	stone.add_child(col)

	# 像素风滚石动画
	var anim_sprite = AnimatedSprite2D.new()
	anim_sprite.sprite_frames = _get_rolling_stone_frames()
	anim_sprite.play("roll")
	anim_sprite.z_index = -1
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
			var actual_damage = int(atk * 0.84 * (1.0 - PC.damage_reduction_rate))
			PC.player_hit(int(actual_damage), self , "滚石")
	)

# ========================================================
# 技能2: 连续冲锋
# ========================================================
func _attack_consecutive_charge():
	SEManager.play("115")
	print("Attack: Consecutive Charge")
	allow_turning = false
	is_charging = true
	# 每次冲锋技能开始时重置速度降低栈
	_charge_speed_reduction_stacks = 0

	# 诗想难度下使用不同的减速参数
	var hit_speed_reduction = CHARGE_HIT_SPEED_REDUCTION
	var max_reduction_stacks = CHARGE_MAX_REDUCTION_STACKS
	if stage_difficulty == Global.STAGE_DIFFICULTY_POETRY:
		hit_speed_reduction = POETRY_CHARGE_HIT_SPEED_REDUCTION
		max_reduction_stacks = POETRY_CHARGE_MAX_REDUCTION_STACKS

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

		# 计算冲锋终点 — 直接朝玩家方向冲固定距离
		var charge_target = global_position + charge_dir * CHARGE_DISTANCE

		# 冲锋速度 = 基础速度 × 倍率 × 增速50% × 撞石减速累积
		var speed_reduction = max(0.1, 1.0 - hit_speed_reduction * _charge_speed_reduction_stacks)
		var charge_speed_val = speed * CHARGE_SPEED_MULT * CHARGE_SPEED_BOOST * speed_reduction
		var charge_time = CHARGE_DISTANCE / charge_speed_val if charge_speed_val > 0 else 0.5

		# 冲锋动画速度：初始200%，每撞石减少等量百分比，最低120%
		var anim_speed_scale = max(1.2, 2.0 - hit_speed_reduction * _charge_speed_reduction_stacks)
		$BossStone.play("run")
		$BossStone.speed_scale = anim_speed_scale

		# 冲锋特效：身体发光 + 水平拉伸
		sprite.modulate = Color(1.0, 0.7, 0.7, 1.0) # 暖色发光
		var stretch_x = 1.0 + abs(charge_dir.x) * 0.02 # 水平方向拉伸
		var stretch_y = 1.0 - abs(charge_dir.x) * 0.01 # 垂直方向微压缩
		sprite.scale = Vector2(stretch_x, stretch_y)

		# 执行冲锋 — 逐帧移动，碰到边界立即停止
		var prev_pos = global_position
		var _afterimage_counter: int = 0
		var elapsed = 0.0
		var hit_boundary = false
		var hit_stones_this_charge: Array = []
		while elapsed < charge_time and not is_dead:
			var dt = get_process_delta_time()
			elapsed += dt
			var raw_pos = global_position + charge_dir * charge_speed_val * dt
			var new_pos = Vector2(
				clamp(raw_pos.x, CHARGE_LEFT, CHARGE_RIGHT),
				clamp(raw_pos.y, CHARGE_TOP, CHARGE_BOTTOM)
			)
			# 碰到边界则停在该位置，但继续等冲锋时间走完
			if raw_pos.x != new_pos.x or raw_pos.y != new_pos.y:
				if not hit_boundary:
					prev_pos = global_position
					global_position = new_pos
					hit_boundary = true
				# 已到边界，不再移动，只等时间结束
			else:
				prev_pos = global_position
				global_position = new_pos

			# 线段碰撞检测：检测prev_pos→global_position路径是否穿过石块
			for block in stone_blocks:
				if is_instance_valid(block) and not hit_stones_this_charge.has(block):
					var hit_dist = 30.0 * block.scale.x + 15.0
					var seg_dist = _segment_point_dist(prev_pos, global_position, block.global_position)
					if seg_dist < hit_dist:
						hit_stones_this_charge.append(block)
						_destroy_stone_block(block)
						# 立刻损失1层石甲
						_charge_speed_reduction_stacks = min(_charge_speed_reduction_stacks + 1, max_reduction_stacks)
						if stone_armor > 0:
							stone_armor -= 1
							Global.emit_signal("boss_buff_updated", "stone_armor", 0.0, stone_armor)
						print("[Charge] HIT stone at ", block.global_position, " dist=", seg_dist, " Armor left: ", stone_armor)

			# 冲锋残影特效：每3帧生成一个
			_afterimage_counter += 1
			if _afterimage_counter % 3 == 0:
				_spawn_charge_afterimage(charge_dir)

			# 沿途伤害判定
			if PC.player_instance and not PC.invincible:
				if global_position.distance_to(PC.player_instance.global_position) < 25.0:
					var dmg = int(atk * 1.5 * (1.0 - PC.damage_reduction_rate))
					PC.player_hit(int(dmg), self , "冲锋")
			await get_tree().process_frame

		# 冲锋结束：还原视觉
		sprite.modulate = Color.WHITE
		sprite.scale = Vector2.ONE

		# 冲锋间短暂间隔
		await get_tree().create_timer(0.3).timeout

	is_charging = false
	allow_turning = true
	# 重置动画速度
	$BossStone.speed_scale = 1.0
	if not is_stunned:
		is_attacking = false

func _show_charge_warning(direction: Vector2):
	# 挂载到场景根节点，避免被 Boss 的 z_index 或其他子节点遮挡
	var warn_line = Node2D.new()
	get_tree().current_scene.add_child(warn_line)
	warn_line.global_position = global_position
	warn_line.z_index = 10

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

	var tw = get_tree().create_tween().set_parallel(true)
	tw.tween_property(outer, "modulate:a", 1.0, 0.15)
	tw.tween_property(inner, "modulate:a", 1.0, 0.15)

	# 自动清除
	get_tree().create_timer(CHARGE_WARNING_TIME).timeout.connect(func():
		if is_instance_valid(warn_line):
			var fade = get_tree().create_tween().set_parallel(true)
			fade.tween_property(outer, "modulate:a", 0.0, 0.1)
			fade.tween_property(inner, "modulate:a", 0.0, 0.1)
			fade.finished.connect(func():
				if is_instance_valid(warn_line):
					warn_line.queue_free()
			)
	)

## 冲锋残影特效：生成一个半透明的Boss副本，快速淡出
func _spawn_charge_afterimage(charge_dir: Vector2):
	var ghost = Sprite2D.new()
	# 复制当前帧的纹理
	var current_frame = $BossStone.frame
	var anim_name = $BossStone.animation
	var sprite_frames = $BossStone.sprite_frames
	if sprite_frames and sprite_frames.has_animation(anim_name):
		var frame_tex = sprite_frames.get_frame_texture(anim_name, current_frame)
		if frame_tex:
			ghost.texture = frame_tex
	ghost.global_position = global_position
	ghost.flip_h = sprite.flip_h
	ghost.modulate = Color(0.6, 0.8, 1.0, 0.5) # 淡蓝色半透明
	ghost.scale = sprite.scale
	ghost.z_index = z_index - 1
	get_tree().current_scene.add_child(ghost)
	# 0.2秒淡出后销毁
	var tw = get_tree().create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.2)
	tw.finished.connect(func():
		if is_instance_valid(ghost):
			ghost.queue_free()
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
	if is_instance_valid(block):
		# 播放碎裂动画，结束后销毁
		block.play("broken")
		block.animation_finished.connect(func():
			if is_instance_valid(block):
				block.queue_free()
		)

## 检测新石块与已有石块的距离，小于阈值则爆炸生成泥沼
func _check_stone_block_proximity_explosion(new_block: Node2D):
	var explosion_pairs: Array = []
	# 石块碰撞半径约 30 * scale，两石块边缘接触时中心距 ≈ 2 * 30 * scale
	# 用边缘距离 < 0px 作为判定：center_dist < 2 * block_radius
	var new_radius = 30.0 * new_block.scale.x
	for block in stone_blocks:
		if block == new_block or not is_instance_valid(block):
			continue
		var block_radius = 30.0 * block.scale.x
		var dist = new_block.global_position.distance_to(block.global_position)
		var threshold = new_radius + block_radius - 10
		print("[StoneBlock] Proximity check: dist=", dist, " threshold=", threshold, " new_pos=", new_block.global_position, " block_pos=", block.global_position)
		if dist < threshold:
			explosion_pairs.append(block)
	
	if explosion_pairs.is_empty():
		return
	
	# 找到最近的石块配对
	var closest = explosion_pairs[0]
	for b in explosion_pairs:
		if new_block.global_position.distance_to(b.global_position) < new_block.global_position.distance_to(closest.global_position):
			closest = b
	
	# 两石块中点生成椭圆泥沼
	var mid_pos = (new_block.global_position + closest.global_position) / 2.0
	
	# 销毁两块石头
	_destroy_stone_block(new_block)
	_destroy_stone_block(closest)
	
	# 生成大范围椭圆泥沼
	_spawn_elliptical_mud_pool(mid_pos, 120.0, 0.7, 15.0)
	GU.screen_shake(8.0, 0.4)
	print("[StoneBlock] Proximity explosion! Mud pool at ", mid_pos)

## 生成椭圆泥沼（石块爆炸产生）
func _spawn_elliptical_mud_pool(origin: Vector2, radius: float, aspect: float, duration: float):
	var pool = Area2D.new()
	pool.add_to_group("mud_pool")
	pool.global_position = origin
	pool.z_index = -1

	# 椭圆泥潭视觉
	var drawer = _MudPoolDrawer.new()
	drawer.pool_radius = radius
	drawer.pool_angle = TAU # 360度=完整椭圆
	drawer.pool_direction = 0.0
	pool.add_child(drawer)

	pool.modulate.a = 0.0
	get_tree().current_scene.add_child(pool)

	# 渐入
	var tw = pool.create_tween()
	tw.tween_property(pool, "modulate:a", 0.75, 0.4)

	# 用Timer驱动持续伤害，椭圆范围判定
	_start_elliptical_mud_pool_process(pool, origin, radius, aspect, duration)

## 椭圆泥沼的持续伤害处理
func _start_elliptical_mud_pool_process(pool: Node, origin: Vector2, radius: float, aspect: float, duration: float):
	var timer = Timer.new()
	timer.wait_time = 0.05
	timer.autostart = true
	var life := [0.0]
	var tick := [0.0]
	var damage_active := [false]
	pool.add_child(timer)

	# 渐入延迟，期间不造成伤害
	get_tree().create_timer(MUD_POOL_FADE_IN).timeout.connect(func():
		damage_active[0] = true
	)

	timer.timeout.connect(func():
		life[0] += timer.wait_time
		if damage_active[0]:
			if PC.player_instance and is_instance_valid(PC.player_instance):
				var player_pos = PC.player_instance.global_position
				var dx = (player_pos.x - origin.x) / radius
				var dy = (player_pos.y - origin.y) / (radius * aspect)
				var inside = (dx * dx + dy * dy) <= 1.0
				if inside:
					tick[0] += timer.wait_time
					if tick[0] >= MUD_POOL_DAMAGE_TICK:
						tick[0] -= MUD_POOL_DAMAGE_TICK
						var dmg = max(1, int(atk * 0.15))
						PC.player_hit_ignore_invincible(int(dmg), self , "泥沼")
				else:
					tick[0] = 0.0
		if life[0] >= duration - 0.8:
			pool.modulate.a = max(0.0, pool.modulate.a - timer.wait_time * 1.2)
		if life[0] >= duration:
			if is_instance_valid(pool):
				pool.queue_free()
	)

## 计算点P到线段AB的最短距离，用于高速移动的碰撞检测
func _segment_point_dist(a: Vector2, b: Vector2, p: Vector2) -> float:
	var ab = b - a
	var ap = p - a
	var ab_len_sq = ab.length_squared()
	if ab_len_sq < 0.001:
		return a.distance_to(p)
	var t = clampf(ap.dot(ab) / ab_len_sq, 0.0, 1.0)
	var closest = a + ab * t
	return closest.distance_to(p)

# ========================================================
# 技能3: 落石
# ========================================================
func _attack_falling_stones():
	SEManager.play("112")
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
		GU.screen_shake(5.0, 0.2)
	)
	warn_boss.source_name = "巨石砸击"
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
		GU.screen_shake(6.0, 0.25)
	)
	warn_player.damage_dealt.connect(func(_d):
		_knockback_player_from(player_target, 50.0)
	)
	warn_player.source_name = "巨石砸击"
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

func _get_stone_block_scale(size_multiplier: float = 1.0) -> float:
	return STONE_BASE_SCALE * size_multiplier

func _spawn_stone_block(pos: Vector2, size_multiplier: float = 1.0):
	var stone_scale = _get_stone_block_scale(size_multiplier)

	var block = STONE_STONE_SCENE.instantiate()
	block.add_to_group("stone_block")
	block.z_index = 0
	block.scale = Vector2(stone_scale, stone_scale)

	get_tree().current_scene.add_child(block)
	# 先add_child再设global_position，确保坐标空间正确
	block.global_position = pos
	# 播放默认静止帧
	block.play("default")
	stone_blocks.append(block)
	print("[StoneBlock] Spawned at ", pos, " scale=", stone_scale, " total=", stone_blocks.size())

	# 检测是否与已有石块距离小于15像素，触发爆炸
	_check_stone_block_proximity_explosion(block)

	# 石块持续时间后自动消失
	get_tree().create_timer(STONE_BLOCK_DURATION).timeout.connect(func():
		if is_instance_valid(block) and stone_blocks.has(block):
			stone_blocks.erase(block)
			# 播放碎裂动画后销毁
			block.play("broken")
			block.animation_finished.connect(func():
				if is_instance_valid(block):
					block.queue_free()
			)
	)

# ========================================================
# 技能4: 拍击（扇形连续攻击）
# ========================================================
func _attack_slap():
	SEManager.play("111")
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
				GU.screen_shake(6.0, 0.2)
				warn.cleanup()
		)
		warn.damage_dealt.connect(func(d): print("拍击伤害: ", d))
		warn.source_name = "拍击"
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
	SEManager.play("113")
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
		Global.emit_signal("boss_chant_end")
		if is_instance_valid(warn):
			warn.cleanup()
		# 根据难度调整泥沼扇形角度
		var mud_pool_angle = FLIP_SECTOR_ANGLE
		match stage_difficulty:
			Global.STAGE_DIFFICULTY_SHALLOW:
				pass # 浅层保持当前角度
			Global.STAGE_DIFFICULTY_DEEP:
				mud_pool_angle += 5.0
			Global.STAGE_DIFFICULTY_CORE:
				mud_pool_angle += 10.0
			Global.STAGE_DIFFICULTY_POETRY:
				mud_pool_angle += 30.0

		# 缓速冲击感 — 泥沼出现前0.1秒开始，持续0.4秒
		Engine.time_scale = 0.6
		get_tree().create_timer(0.1, true, false, true).timeout.connect(func():
			_spawn_mud_pool(global_position, sector_center_dir, FLIP_RADIUS, mud_pool_angle)
			GU.screen_shake(8.0, 0.4)
		)
		get_tree().create_timer(0.4, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)
	)
	warn.damage_dealt.connect(func(d): print("掀地伤害: ", d))
	warn.source_name = "掀地"
	warn.start_warning(
		global_position, target_point, FLIP_SECTOR_ANGLE,
		FLIP_WARNING_TIME, atk * 2.0, "掀地", null, FLIP_WARNING_TIME * 0.5
	)

	await get_tree().create_timer(FLIP_WARNING_TIME + 0.3).timeout
	# 掀地特效
	_spawn_ground_flip_effect(global_position, sector_center_dir)
	await get_tree().create_timer(0.5).timeout
	is_attacking = false

# ========================================================
# 技能6: 震地 — 以自身为中心步进扩大伤害圈
# ========================================================
func _attack_quake():
	SEManager.play("114")
	print("Attack: Quake")

	var origin = global_position
	for round_i in range(QUAKE_ROUNDS):
		if is_dead:
			break
		var t = float(round_i + 1) / float(QUAKE_ROUNDS)
		var cur_radius = lerp(QUAKE_INITIAL_RADIUS, QUAKE_MAX_RADIUS, t)
		# 深层以上，震地第三次范围额外+20%
		if stage_difficulty != Global.STAGE_DIFFICULTY_SHALLOW and round_i == QUAKE_ROUNDS - 1:
			cur_radius *= 1.2

		# 读条
		Global.emit_signal("boss_chant_start", "震地" + str(round_i + 1), QUAKE_ROUND_WARNING)

		# 预警圈
		var warn = WarnCircleUtil.new()
		add_child(warn)
		warn.source_name = "地震波"
		warn.start_warning(
			origin, 1.0, cur_radius,
			QUAKE_ROUND_WARNING, atk * 1.2, "震地", null,
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
				PC.player_hit(int(dmg), self , "震地")

		# 崩散粒子特效 + 屏幕震颤
		_spawn_quake_particles(origin, cur_radius, round_i)
		GU.screen_shake(8.0 + round_i * 3.0, 0.25)

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
	tw.tween_property(pool, "modulate:a", 0.75, 0.4)

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
	var damage_active := [false] # 渐入结束后才开始伤害
	pool.add_child(timer)

	# 渐入延迟：类似 poison_circle 的 FADE_IN_TIME，期间不造成伤害
	get_tree().create_timer(MUD_POOL_FADE_IN).timeout.connect(func():
		damage_active[0] = true
	)

	timer.timeout.connect(func():
		life[0] += timer.wait_time
		# 渐入结束后才判定伤害
		if damage_active[0]:
			var player_inside = _is_player_in_sector(origin, center_angle, half_angle, radius)
			if player_inside and not PC.invincible:
				tick[0] += timer.wait_time
				if tick[0] >= MUD_POOL_DAMAGE_TICK:
					tick[0] -= MUD_POOL_DAMAGE_TICK
					var dmg = max(1, int(atk * 0.3))
					PC.player_hit(int(dmg), self , "泥潭")
			else:
				tick[0] = 0.0
		if life[0] >= MUD_POOL_DURATION - 0.8:
			pool.modulate.a = max(0.0, pool.modulate.a - timer.wait_time * 1.2)
		if life[0] >= MUD_POOL_DURATION:
			if is_instance_valid(pool):
				pool.queue_free()
	)

# 泥潭绘制内部类 —— 半透明泥地 + 冒泡泡
class _MudPoolDrawer extends Node2D:
	var pool_radius: float = 100.0
	var pool_angle: float = 1.57 # 扇形张角（弧度）
	var pool_direction: float = 0.0 # 扇形中心方向（弧度）
	var pulse_time: float = 0.0

	# 泡泡数据: [x, y, 当前生命, 最大生命, 半径]
	var _bubbles: Array = []
	var _bubble_spawn_timer: float = 0.0

	func _process(delta):
		pulse_time += delta
		_update_bubbles(delta)
		queue_redraw()

	func _update_bubbles(delta: float):
		# 定期生成新泡泡
		_bubble_spawn_timer += delta
		if _bubble_spawn_timer >= 0.35:
			_bubble_spawn_timer = 0.0
			_spawn_bubble()

		# 更新现有泡泡
		var i = _bubbles.size() - 1
		while i >= 0:
			var b = _bubbles[i]
			b[2] += delta # 增加生命
			if b[2] >= b[3]:
				_bubbles.remove_at(i)
			i -= 1

	func _spawn_bubble():
		# 在扇形内随机位置生成泡泡
		var half_a: float = pool_angle / 2.0
		var angle = pool_direction + randf_range(-half_a * 0.85, half_a * 0.85)
		var dist = randf_range(pool_radius * 0.1, pool_radius * 0.85)
		var bx = cos(angle) * dist
		var by = sin(angle) * dist
		var max_life = randf_range(0.6, 1.4)
		var radius = randf_range(3.0, 7.0)
		_bubbles.append([bx, by, 0.0, max_life, radius])
		# 限制泡泡数量
		if _bubbles.size() > 12:
			_bubbles.pop_front()

	func _draw():
		var P: int = 3
		var R: float = pool_radius
		var half_a: float = pool_angle / 2.0
		var pulse: float = (sin(pulse_time * 2.5) + 1.0) * 0.5

		# --- 1. 半透明泥地底色 ---
		var mud_color = Color(0.35, 0.22, 0.10, 0.40 + pulse * 0.08)
		var R2: float = R * R
		var gx: int = - int(R) - P
		while gx < int(R) + P:
			var gy: int = - int(R) - P
			while gy < int(R) + P:
				var cx: float = gx + P * 0.5
				var cy: float = gy + P * 0.5
				var d2: float = cx * cx + cy * cy
				if d2 <= R2:
					var point_angle: float = atan2(cy, cx)
					var adiff: float = angle_difference(point_angle, pool_direction)
					if abs(adiff) <= half_a:
						draw_rect(Rect2(gx, gy, P, P), mud_color)
				gy += P
			gx += P

		# --- 2. 泡泡 ---
		for b in _bubbles:
			var bx: float = b[0]
			var by: float = b[1]
			var life: float = b[2]
			var max_life: float = b[3]
			var b_radius: float = b[4]
			var t: float = life / max_life # 0→1 进度

			# 泡泡先膨胀再收缩
			var scale_factor: float
			if t < 0.3:
				scale_factor = t / 0.3 # 0→1 膨胀
			else:
				scale_factor = 1.0 - (t - 0.3) / 0.7 # 1→0 收缩
			scale_factor = max(scale_factor, 0.0)

			# 泡泡向上微微飘动
			var draw_y = by - life * 8.0
			var draw_r = b_radius * scale_factor

			if draw_r > 0.5:
				# 泡泡主体（浅色半透明圆）
				var bubble_alpha = 0.5 * scale_factor
				draw_circle(Vector2(bx, draw_y), draw_r, Color(0.6, 0.42, 0.22, bubble_alpha))
				# 泡泡高光
				if draw_r > 2.0:
					draw_circle(Vector2(bx - draw_r * 0.25, draw_y - draw_r * 0.25), draw_r * 0.35, Color(0.8, 0.65, 0.4, bubble_alpha * 0.6))

# ========================================================
# 技能7: 落石预兆 — 深层以上出现
# ========================================================
func _attack_rockfall_omen():
	SEManager.play("112")
	print("Attack: Rockfall Omen")
	Global.emit_signal("boss_chant_start", "落石预兆", 2.0)
	
	# 根据难度决定debuff数量
	var debuff_count := 3
	match stage_difficulty:
		Global.STAGE_DIFFICULTY_DEEP:
			debuff_count = 3
		Global.STAGE_DIFFICULTY_CORE:
			debuff_count = 4
		Global.STAGE_DIFFICULTY_POETRY:
			debuff_count = 5
	
	# 清空旧的Timer引用
	_rockfall_omen_timers.clear()
	_rockfall_omen_buff_ids.clear()
	
	# 获取BuffManager实例（通过场景树查找）
	var buff_manager = _find_player_buff_manager()
	
	for i in range(debuff_count):
		var buff_id = "rockfall_warn_%d" % (i + 1)
		var duration = 4.0 + i * randf_range(2.5, 4.5)
		
		# 通过BuffManager添加玩家可见的debuff（显示在UI上）
		if buff_manager and buff_manager.has_method("add_buff"):
			buff_manager.add_buff(buff_id, duration, 1)
		
		# 弹出buff通知
		_show_rockfall_buff_notification(buff_id)
		
		# 创建Timer，到期后触发落石
		var omen_timer = Timer.new()
		add_child(omen_timer)
		omen_timer.wait_time = duration
		omen_timer.one_shot = true
		omen_timer.timeout.connect(_on_rockfall_omen_expired.bind(i, buff_id))
		omen_timer.start()
		
		_rockfall_omen_timers.append(omen_timer)
		_rockfall_omen_buff_ids.append(buff_id)
		
		# 每0.4秒弹一个通知
		await get_tree().create_timer(0.75).timeout
	
	# Boss仅停顿2秒读条
	await get_tree().create_timer(2.0 - (debuff_count - 1) * 0.4).timeout
	Global.emit_signal("boss_chant_end")
	is_attacking = false

func _on_rockfall_omen_expired(index: int, buff_id: String):
	# 弹出buff消失通知（"-"+buff名）
	_show_rockfall_buff_notification(buff_id, " - ")
	# 移除对应的buffer
	BuffManager.remove_buff(buff_id)
	
	# 清理Timer引用
	if index < _rockfall_omen_timers.size():
		_rockfall_omen_timers[index] = null
	
	# 如果Boss已死或玩家不存在则跳过
	if is_dead or not is_instance_valid(PC.player_instance):
		return
	
	# 获取玩家当前位置（生成预警时的位置）
	var player_pos = PC.player_instance.global_position
	
	# 2秒红圈预警，与普通落石一致
	var warn = WarnCircleUtil.new()
	get_tree().current_scene.add_child(warn)
	warn.warning_finished.connect(func():
		if is_instance_valid(warn):
			warn.cleanup()
		# 预警结束后：伤害 + 掉落石块
		_spawn_stone_impact_effect(player_pos)
		_spawn_stone_block(player_pos, 1.0)
		GU.screen_shake(7.0, 0.3)
	)
	warn.damage_dealt.connect(func(_d):
		_knockback_player_from(player_pos, 60.0)
	)
	warn.start_warning(
		player_pos, 1.2, FALLING_STONE_RADIUS,
		2.0, atk * 1.5, "落石预兆", null,
		WarnCircleUtil.ReleaseMode.INSTANT_DAMAGE
	)

# ========================================================
# 技能8: 石头发光？ (弹幕连射)
# ========================================================
func _attack_stone_glow():
	SEManager.play("105") # 借用花雨音效
	print("Attack: Stone Glow")
	
	var chant_time_prepare = 1.5
	Global.emit_signal("boss_chant_start", "石头发光？", chant_time_prepare)
	await get_tree().create_timer(chant_time_prepare).timeout
	Global.emit_signal("boss_chant_end")
	
	var total_circles = 4
	var circle_duration = 1.0
	if stage_difficulty == Global.STAGE_DIFFICULTY_POETRY:
		total_circles = 7
		circle_duration = 0.6
		
	var bullet_count_per_circle = 36
	var interval = circle_duration / bullet_count_per_circle
	var total_barrage_time = total_circles * circle_duration
	
	Global.emit_signal("boss_chant_start", "石头发光！", total_barrage_time)
	
	# 黄色滤镜
	sprite.modulate = Color(1.0, 1.0, 0.7, 1.0)
	
	var base_angle = 0.0
	var rotation_speed = 360.0 / bullet_count_per_circle # degrees per step to make a full circle per round
	var current_direction = 1 # 1 for clockwise, -1 for counter-clockwise
	
	for circle_idx in range(total_circles):
		if circle_idx > 0 and circle_idx % 3 == 0:
			current_direction *= -1
		
		var circle_offset = deg_to_rad(randf_range(-15.0, 15.0))
			
		for i in range(bullet_count_per_circle):
			if is_dead or not is_instance_valid(PC.player_instance):
				return
				
			while Global.in_menu or Global.in_town or get_tree().paused:
				if is_dead:
					return
				await get_tree().create_timer(0.1).timeout
				
			base_angle += rotation_speed * current_direction
			var dir = Vector2.RIGHT.rotated(deg_to_rad(base_angle) + circle_offset)
			var spawn_pos = global_position
			
			var bullet = SMALL_FIRE_BULLET.instantiate()
			if get_parent():
				get_parent().add_child(bullet)
			else:
				get_tree().current_scene.add_child(bullet)
			
			bullet.global_position = spawn_pos
			if bullet.has_method("set_direction"):
				bullet.set_direction(dir)
			bullet.bullet_speed = 320.0 * 0.7 * 0.8 # 再降低30%
			bullet.bullet_damage = atk * 0.5
			bullet.source_name = "石头发光！"
			
			await get_tree().create_timer(interval, false).timeout
			
	Global.emit_signal("boss_chant_end")
	sprite.modulate = Color.WHITE
	is_attacking = false

# ========================================================
# 碰撞 / 受伤 / 死亡
# ========================================================

## 查找当前战斗场景中的玩家BuffManager
func _find_player_buff_manager():
	var canvas = get_tree().current_scene.get_node_or_null("CanvasLayer")
	if canvas and canvas.has_method("get_buff_manager"):
		return canvas.get_buff_manager()
	# 备选：直接查找BuffManager节点
	return get_tree().current_scene.find_child("BuffManager", true, false)

## 落石预兆buff通知弹出
func _show_rockfall_buff_notification(buff_id: String, prefix: String = " + "):
	var buff_config = BuffManager.get_buff_data(buff_id)
	if not buff_config:
		return
	var canvas = get_tree().current_scene.get_node_or_null("CanvasLayer")
	if canvas and canvas.has_method("show_buff_notification"):
		canvas.show_buff_notification(buff_config.icon_path, buff_config.name, prefix)
func _on_body_entered(body: Node2D) -> void:
	super._on_body_entered(body)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("bullet") and area.has_method("get_bullet_damage_and_crit_status"):
		var collision_result = BulletCalculator.handle_bullet_collision_full(area, self , true)
		if collision_result["should_rebound"]: area.call_deferred("create_rebound")
		if collision_result["should_delete_bullet"]: area.queue_free()
		var raw_dmg = get_common_bullet_damage_value(collision_result["final_damage"])
		take_damage(int(raw_dmg), collision_result["is_crit"], false, "bullet")

func take_damage(damage: int, is_crit: bool, is_summon: bool, damage_type: String) -> void:
	if is_dead: return
	# 石甲减伤：每层降低10%受到的伤害
	var armor_reduction = 1.0 - stone_armor * 0.1
	var adjusted_damage = max(1, int(damage * armor_reduction))
	var res = apply_common_take_damage(adjusted_damage, is_crit, is_summon, damage_type, {"use_debuff_multiplier": false, "update_boss_hp_bar": true, "play_hit_animation": true, "randomize_popup_offset": true})
	if res["applied"] and hp <= 0:
		_die()

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
	Global.emit_signal("drop_out_item", magic_cores[randi() % magic_cores.size()], 1, global_position)

func _die():
	if not is_dead:
		_drop_boss_rewards()
		Global.emit_signal("boss_defeated", get_point, global_position)
		Global.emit_signal("monster_killed")
	is_dead = true
	remove_from_group("enemies")
	is_attacking = false
	# 停止技能计时器、清理读条 UI
	attack_timer.stop()
	Global.emit_signal("boss_chant_end")
	# 移除boss血条上的石甲buff
	Global.emit_signal("boss_buff_removed", "stone_armor")
	# 清理所有落石预兆Timer
	for timer_ref in _rockfall_omen_timers:
		if is_instance_valid(timer_ref):
			timer_ref.queue_free()
	_rockfall_omen_timers.clear()
	_rockfall_omen_buff_ids.clear()
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
	var P := 2
	var grid := 12
	var img_size := grid * P
	var col_dark := Color(0.10, 0.08, 0.05, 1.0)
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
	impact.global_position = pos + Vector2(4, 6)
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
