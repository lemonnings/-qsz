extends "res://Script/monster/monster_base.gd"

@onready var sprite = $BossA
var is_attacking: bool = false
var is_charging: bool = false # 是否正在冲锋
var allow_turning: bool = true

# 落花技能状态变量
var petal_use_count: int = 0 # 落花已使用次数（0 = 尚未使用，开局触发）
var attacks_since_last_petal: int = 0 # 上次落花后已释放的随机技能数
var _petal_loop_generation: int = 0 # 微触发新循环时使旧循环自动退出


# 屏幕边界
@export var top_boundary: float = 110.0
@export var bottom_boundary: float = 460.0
@export var left_boundary: float = -560.0
@export var right_boundary: float = 550.0

# 0为从左到右，1为从右向左，2为随机移动，3为靠近角色，4为y轴靠近x轴保持距离，5为从左向右y随机，6为从右向左y随机
var move_direction: int = 4
var target_position: Vector2 # 用于存储移动目标位置
var update_move_timer: Timer # 移动模式计时器

var speed: float = SettingMoster.slime_blue("speed") * 0.75 # Boss移动速度，可以调整
var hpMax: float = SettingMoster.slime_blue("hp") * 22 # Boss最大生命值，可以调整
#var hpMax : float = SettingMoster.slime("hp") * 0.1 # Boss最大生命值，可以调整
var hp: float = hpMax # Boss当前生命值
var atk: float = SettingMoster.slime_blue("atk") * 0.9 # Boss攻击力，可以调整
var get_point: int = SettingMoster.slime_blue("point") * 25 # 击败首领获得的积分
var get_exp: int = 0 # 击败首领获得的经验

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

var attack_timer: Timer # Boss攻击计时器
var attack_indicator: Node2D # 攻击范围指示器
var outer_line_node: Line2D
var inner_line_node: Line2D
var charge_indicator_direction: Vector2 # 存储冲锋指示器方向
var charge_target_global_position: Vector2 # 存储冲锋的最终目标全局位置

# 子弹场景，需要预加载
const STRAIGHT_BULLET = preload("res://Scenes/global/small_fire_bullet.tscn") # 直线子弹
const RED_CIRCLE_WARNING = preload("res://Scenes/global/warning.tscn") # 红圈警告特效
# WarnCircleUtil 和 WarnSectorUtil 已有 class_name，直接使用类名即可

# 子弹场景 (Bullet Scenes)
const NORMAL_STRAIGHT_BULLET_SCENE = STRAIGHT_BULLET # 原直线子弹作为普通直线弹
const NORMAL_BARRAGE_BULLET_SCENE = preload("res://Scenes/global/small_fire_bullet.tscn")

# 随机弹幕攻击相关常量
const RANDOM_BARRAGE_BULLET_COUNT = 130
const RANDOM_BARRAGE_INTERVAL = 0.03

# 陨石攻击参数
const METEOR_SPAWN_RANGE: float = 50.0 # 玩家周围生成范围(n像素)
const METEOR_RADIUS: float = 38.0 # 陨石半径(x)
const METEOR_COUNT: int = 8 # 陨石数量(y)
const METEOR_WARNING_TIME: float = 1.5 # 预警时间(z秒)
const METEOR_PERSIST_DURATION: float = 12.0 # 持续伤害区域持续时间

# 扇形AOE参数
const SECTOR_ANGLE: float = 50.0 # 扇形角度(n度)
const SECTOR_WARNING_TIME: float = 1.5 # 扇形预警时间(x秒)
const SECTOR_RADIUS: float = 2000.0 # 扇形半径(超出场地画幅)
const MULTI_SECTOR_ROUNDS: int = 4 # 连续扇形轮数

const DETOX_BUFF_ID := "boss_a_detox"
const DEEP_METEOR_SIZE_MULTIPLIER: float = 1.3
const CORE_PETAL_SPEED_MULTIPLIER: float = 1.25
const GOLDEN_PETAL_CHANCE: float = 0.06
const GOLDEN_PETAL_SCALE_MULTIPLIER: float = 1.25
const POETRY_BARRAGE_DENSITY_MULTIPLIER: float = 1.3
const POETRY_EXTRA_METEOR_MIN_COUNT: int = 3
const POETRY_EXTRA_METEOR_MAX_COUNT: int = 4
const POETRY_EXTRA_METEOR_MIN_DISTANCE: float = 46.0
const POETRY_EXTRA_METEOR_MAX_DISTANCE: float = 120.0

var stage_difficulty: String = Global.STAGE_DIFFICULTY_SHALLOW
var forced_poison_attack_index: int = -1

func _ready():
	add_to_group("boss")
	stage_difficulty = Global.validate_stage_difficulty_id(Global.current_stage_difficulty)
	hpMax *= _get_difficulty_hp_multiplier()
	# 根据玩家DPS和难度增加Boss HP
	var dps_multiplier := 8
	match Global.current_stage_difficulty:
		Global.STAGE_DIFFICULTY_DEEP:
			dps_multiplier = 11
		Global.STAGE_DIFFICULTY_CORE:
			dps_multiplier = 14
		Global.STAGE_DIFFICULTY_POETRY:
			dps_multiplier = 14
	hpMax += Global.get_current_dps() * dps_multiplier
	print("[BossA] DPS加成HP: +", Global.get_current_dps() * dps_multiplier, "  最终hpMax: ", hpMax)
	
	# 防止boss升级期间打人
	process_mode = Node.PROCESS_MODE_PAUSABLE
	hp = hpMax # 初始化当前血量
	
	# 浅层难度下Boss只造成25%伤害
	if stage_difficulty == Global.STAGE_DIFFICULTY_SHALLOW:
		atk *= 0.5
	
	setup_monster_base()
	use_debuff_take_damage_multiplier = false
	check_action_disabled_on_body_entered = false
	
	# 创建脚底阴影（Boss阴影较大）
	CharacterEffects.create_shadow(self , 50.0, 20.0, 41.0)
	
	Global.emit_signal("boss_hp_bar_initialize", hpMax, hp, 12, "桃树精王")
	Global.emit_signal("boss_hp_bar_show")
	
	# 初始化移动相关
	update_move_timer = Timer.new()
	add_child(update_move_timer)
	update_move_timer.wait_time = 0.5
	update_move_timer.timeout.connect(_update_target_position_mode4)
	update_move_timer.start()
	_update_target_position_mode4()

	# 初始化攻击计时器
	attack_timer = Timer.new()
	add_child(attack_timer)
	attack_timer.wait_time = 2.5
	attack_timer.timeout.connect(_choose_attack)
	attack_timer.start()


func _is_deep_or_harder() -> bool:
	return stage_difficulty in [Global.STAGE_DIFFICULTY_DEEP, Global.STAGE_DIFFICULTY_CORE, Global.STAGE_DIFFICULTY_POETRY]


func _is_core_or_harder() -> bool:
	return stage_difficulty in [Global.STAGE_DIFFICULTY_CORE, Global.STAGE_DIFFICULTY_POETRY]


func _is_poetry() -> bool:
	return stage_difficulty == Global.STAGE_DIFFICULTY_POETRY


func _uses_forced_poison_cycle() -> bool:
	return stage_difficulty in [Global.STAGE_DIFFICULTY_DEEP, Global.STAGE_DIFFICULTY_POETRY]


func _reset_interval_attack_plan() -> void:
	forced_poison_attack_index = randi_range(1, 4) if _uses_forced_poison_cycle() else -1


func _get_next_random_attack_type() -> int:
	if _uses_forced_poison_cycle() and attacks_since_last_petal == forced_poison_attack_index:
		return 7
	return randi_range(1, 6) if _uses_forced_poison_cycle() else randi_range(1, 7)


func _get_difficulty_hp_multiplier() -> float:
	match stage_difficulty:
		Global.STAGE_DIFFICULTY_DEEP:
			return 1.2
		Global.STAGE_DIFFICULTY_CORE:
			return 1.4
		Global.STAGE_DIFFICULTY_POETRY:
			return 1.5
		_:
			return 1.0


func _get_meteor_radius() -> float:
	return METEOR_RADIUS * (DEEP_METEOR_SIZE_MULTIPLIER if _is_deep_or_harder() else 1.0)


func _get_poison_circle_scale() -> Vector2:
	var meteor_radius := _get_meteor_radius()
	return Vector2(meteor_radius * 1.2 / 15.0, meteor_radius / 15.0)


func _get_petal_spawn_count() -> int:
	var count := petal_use_count * 2 + 1
	if _is_deep_or_harder():
		count += 2
	if _is_poetry():
		count += 1 + max(0, petal_use_count - 1)
	return count


func _get_petal_speed_multiplier() -> float:
	return CORE_PETAL_SPEED_MULTIPLIER if _is_core_or_harder() else 1.0


func _get_random_barrage_bullet_count() -> int:
	if _is_poetry():
		return int(ceil(RANDOM_BARRAGE_BULLET_COUNT * POETRY_BARRAGE_DENSITY_MULTIPLIER))
	return RANDOM_BARRAGE_BULLET_COUNT


func _get_random_barrage_duration() -> float:
	return RANDOM_BARRAGE_BULLET_COUNT * RANDOM_BARRAGE_INTERVAL


func _clamp_position_to_arena(world_pos: Vector2, padding: float = 16.0) -> Vector2:
	return Vector2(
		clamp(world_pos.x, left_boundary + padding, right_boundary - padding),
		clamp(world_pos.y, top_boundary + padding, bottom_boundary - padding)
	)


func _get_random_player_side_meteor_position(player_pos: Vector2, min_distance: float, max_distance: float) -> Vector2:
	var angle := randf() * TAU
	var distance := randf_range(min_distance, max_distance)
	return _clamp_position_to_arena(player_pos + Vector2.RIGHT.rotated(angle) * distance, 28.0)


func _spawn_meteor_warning_at(spawn_pos: Vector2, persistent: bool = false, _source_name: String = "陨石") -> void:
	var warning_circle := WarnCircleUtil.new()
	add_child(warning_circle)
	var meteor_radius := _get_meteor_radius()
	var clamped_spawn_pos := _clamp_position_to_arena(spawn_pos, meteor_radius)
	if persistent:
		warning_circle.warning_finished.connect(
			_on_meteor_persistent_warning_finished.bind(clamped_spawn_pos, warning_circle)
		)
	else:
		warning_circle.warning_finished.connect(_on_meteor_warning_finished.bind(clamped_spawn_pos, warning_circle))
		warning_circle.damage_dealt.connect(_on_meteor_damage_dealt)
	warning_circle.start_warning(
		clamped_spawn_pos,
		1.2,
		meteor_radius,
		METEOR_WARNING_TIME,
		0.0 if persistent else atk * 1.5,
		_source_name,
		null,
		WarnCircleUtil.ReleaseMode.INSTANT_DAMAGE
	)


func _spawn_poetry_extra_meteors() -> void:
	if not _is_poetry() or not is_instance_valid(PC.player_instance):
		return
	var player_pos: Vector2 = PC.player_instance.global_position

	for i in range(randi_range(POETRY_EXTRA_METEOR_MIN_COUNT, POETRY_EXTRA_METEOR_MAX_COUNT)):
		var spawn_pos := _get_random_player_side_meteor_position(
			player_pos,
			POETRY_EXTRA_METEOR_MIN_DISTANCE,
			POETRY_EXTRA_METEOR_MAX_DISTANCE
		)
		_spawn_meteor_warning_at(spawn_pos)


func _should_spawn_golden_petal() -> bool:
	return _is_core_or_harder() and randf() <= GOLDEN_PETAL_CHANCE


func _update_target_position_mode4():
	var player_pos = PC.player_instance.global_position
	var x_offset = 90
	if global_position.x < player_pos.x:
		x_offset = -90
	target_position = Vector2(player_pos.x + x_offset, player_pos.y)

func _physics_process(delta: float) -> void:
	# Boss朝向逻辑，仅在允许转向且不处于攻击状态（特别是冲锋）时才根据玩家位置调整朝向
	if PC.player_instance and allow_turning:
		var player_pos = PC.player_instance.global_position
		if player_pos.x < global_position.x:
			if allow_turning:
				sprite.flip_h = true
		else:
			if allow_turning:
				sprite.flip_h = false
		
	if not is_dead and not is_attacking: # 只有在不攻击的时候才移动
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

func _choose_attack():
	if is_dead:
		return

	is_attacking = true # 标记开始攻击，停止移动

	# 开局必定优先使用落花
	if petal_use_count == 0:
		_attack_petal_rain()
		return

	# 每累计 4 次随机技能后必定使用一次落花
	if attacks_since_last_petal >= 4:
		_attack_petal_rain()
		return

	# 正常随机技能（计数 +1）
	attacks_since_last_petal += 1

	var attack_type := _get_next_random_attack_type()
	print("Boss chooses attack: ", attack_type)

	# 显示攻击范围
	if [3, 4].has(attack_type):
		var chant_name = "荆棘遍布" if attack_type == 3 else "冲锋"
		Global.emit_signal("boss_chant_start", chant_name, 1.0)
		if attack_type == 3:
			_spawn_poetry_extra_meteors()
		_show_attack_indicator(attack_type)
		await get_tree().create_timer(1.0).timeout
		Global.emit_signal("boss_chant_end")

	match attack_type:
		1:
			_attack_straight_line() # _attack_straight_line 内部调用 _show_attack_indicator_for_straight_line
		2:
			_attack_triple_line() # _attack_triple_line 内部调用 _show_attack_indicator_for_triple_line
		3:
			_attack_eight_directions()
			_hide_attack_indicator_with_animation() # 八向攻击后隐藏指示器
		4:
			_attack_charge()
			_hide_attack_indicator_with_animation() # 冲锋攻击后也隐藏指示器
		5:
			_attack_random_barrage()
		6:
			_attack_meteor_instant() # 陨石攻击(即时伤害)
		7:
			_attack_meteor_persistent() # 陨石攻击(持续伤害区域)
		_:
			# 未实现的攻击类型，直接重置攻击状态防止 boss 冻住
			is_attacking = false


func _show_attack_indicator(type: int):
	# 实现不同攻击类型的范围显示逻辑
	print("Showing indicator for attack type: ", type)

	if attack_indicator and is_instance_valid(attack_indicator):
		attack_indicator.queue_free()
		attack_indicator = null
	
	await get_tree().process_frame # 确保旧指示器被清理

	attack_indicator = Node2D.new()
	add_child(attack_indicator)
	attack_indicator.global_position = global_position

	var player_pos = PC.player_instance.global_position
	var _dir_to_player = global_position.direction_to(player_pos)


	match type:
		3: # 八方向
			var appear_tween = create_tween()
			appear_tween.set_parallel(true)
			for i in 8:
				var direction = Vector2.RIGHT.rotated(deg_to_rad(i * 45))
				# 创建外层红色线条
				var outer_line = Line2D.new()
				outer_line.default_color = Color(1.0, 0.1, 0.0, 0.35)
				outer_line.width = 46 # 与三线攻击一致的宽度
				outer_line.add_point(Vector2.ZERO)
				outer_line.add_point(direction * 600)
				outer_line.modulate.a = 0.0
				attack_indicator.add_child(outer_line)
				
				# 创建内层橙黄色线条
				var inner_line = Line2D.new()
				inner_line.default_color = Color(1.0, 1, 0, 0.35) # 与三线攻击一致的颜色
				inner_line.width = 39 # 与三线攻击一致的宽度
				inner_line.add_point(Vector2.ZERO)
				inner_line.add_point(direction * 600)
				inner_line.modulate.a = 0.0
				attack_indicator.add_child(inner_line)

				var max_length = 600.0 # 八向攻击指示器最大长度
				var extend_speed = 2800.0 # px/s
				var extend_duration = max_length / extend_speed

				# 透明度渐变动画 (与长度延伸并行)
				appear_tween.tween_property(inner_line, "modulate:a", 1.0, extend_duration * 0.25).set_delay(i * 0.025) # 透明度动画时间可以短一些
				appear_tween.tween_property(outer_line, "modulate:a", 1.0, extend_duration * 0.2).set_delay(i * 0.025 + 0.025)

				# 长度延伸动画
				inner_line.set_points([Vector2.ZERO, Vector2.ZERO]) # 初始长度为0
				outer_line.set_points([Vector2.ZERO, Vector2.ZERO]) # 初始长度为0
				appear_tween.tween_method(
					func(value: float):
						if is_instance_valid(inner_line):
							inner_line.set_point_position(1, direction * value)
						if is_instance_valid(outer_line):
							outer_line.set_point_position(1, direction * value),
					0.0, # from
					max_length, # to
					extend_duration
				).set_delay(i * 0.025) # 每条线错开延伸

			attack_indicator.visible = true
		4: # 冲锋
			# 禁止在冲锋选择目标后到冲锋结束前转向
			allow_turning = false
			# 确定冲锋的瞄准方向和最终目标位置
			var aim_direction = global_position.direction_to(PC.player_instance.global_position)
			if aim_direction == Vector2.ZERO:
				aim_direction = Vector2.RIGHT
				
			# 存储基于当前位置和瞄准方向的目标点
			charge_indicator_direction = aim_direction
			charge_target_global_position = global_position + aim_direction * 600.0
			print_debug("存储冲锋指示器方向: ", charge_indicator_direction, " 存储冲锋目标全局位置: ", charge_target_global_position)

			var charge_appear_tween = create_tween().bind_node(attack_indicator)
			charge_appear_tween.set_parallel(true)
			
			var current_frame_texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
			var sprite_height = 40
			if current_frame_texture:
				var unscaled_height = current_frame_texture.get_height()
				sprite_height = abs(unscaled_height * sprite.scale.y)
			
			var outer_line_width = sprite_height + 6
			var inner_line_width = sprite_height * 0.88

			var outer_line_charge = Line2D.new()
			outer_line_charge.default_color = Color(1.0, 0.1, 0.0, 0.45)
			outer_line_charge.width = outer_line_width
			outer_line_charge.add_point(Vector2.ZERO)
			outer_line_charge.add_point(aim_direction * 600) # 使用精确的aim_direction绘制指示器
			outer_line_charge.modulate.a = 0.0
			attack_indicator.add_child(outer_line_charge)

			var inner_line_charge = Line2D.new()
			inner_line_charge.default_color = Color(1.0, 1, 0, 0.75)
			inner_line_charge.width = inner_line_width
			inner_line_charge.add_point(Vector2.ZERO)
			inner_line_charge.add_point(aim_direction * 600) # 使用精确的aim_direction绘制指示器
			inner_line_charge.modulate.a = 0.0
			attack_indicator.add_child(inner_line_charge)

			var charge_max_length = 600.0
			var charge_extend_speed = 600.0
			var charge_extend_duration = charge_max_length / charge_extend_speed

			charge_appear_tween.tween_property(inner_line_charge, "modulate:a", 1.0, charge_extend_duration * 0.5)
			charge_appear_tween.tween_property(outer_line_charge, "modulate:a", 1.0, charge_extend_duration * 0.4).set_delay(0.05)

			inner_line_charge.set_points([Vector2.ZERO, Vector2.ZERO])
			outer_line_charge.set_points([Vector2.ZERO, Vector2.ZERO])
			charge_appear_tween.tween_method(
				func(value: float):
					if is_instance_valid(inner_line_charge):
						inner_line_charge.set_point_position(1, aim_direction * value) # 使用精确的aim_direction进行动画
					if is_instance_valid(outer_line_charge):
						outer_line_charge.set_point_position(1, aim_direction * value), # 使用精确的aim_direction进行动画
				0.0,
				charge_max_length,
				charge_extend_duration
			)

			attack_indicator.visible = true
	
func _attack_straight_line():
	# 连续射击5次
	for i in range(5):
		# 每次射击前重新瞄准玩家
		var current_player_pos = PC.player_instance.global_position
		var current_direction = global_position.direction_to(current_player_pos)
		
		# 读条
		Global.emit_signal("boss_chant_start", "荆棘之刺" + str(i + 1), 0.75)
		if i == 0 or i == 3:
			_spawn_poetry_extra_meteors()
		
		# 显示攻击指示器
		_show_attack_indicator_for_straight_line(current_direction)
		
		# 等待0.75秒让生成动画播放完毕
		await get_tree().create_timer(0.75).timeout
		Global.emit_signal("boss_chant_end")
		
		# 播放消失动画
		_hide_attack_indicator_with_animation()
		# 播放藤蔓攻击动画
		_spawn_vine_along_line(global_position, current_direction, 1000.0, 4)
		
		# 播放射击音效
		$straight.play()
		_screen_shake(3.0, 0.15)
		
		# 进行伤害判定
		var player_pos = PC.player_instance.global_position
		var boss_pos = global_position
		var attack_range_length = 1000.0
		var line_width_tolerance = 25
		
		# 检查玩家是否在攻击直线上
		var line_end = boss_pos + current_direction * attack_range_length
		var distance_to_line = _point_to_line_distance(player_pos, boss_pos, line_end)
		var player_to_boss = player_pos - boss_pos
		var projection_length = player_to_boss.dot(current_direction)
		
		if distance_to_line <= line_width_tolerance and projection_length >= 0 and projection_length <= attack_range_length:
			Global.emit_signal("player_hit")
			var actual_damage = int(atk * (1.0 - PC.damage_reduction_rate))
			PC.player_hit(int(actual_damage), self , "荆棘之刺")
			if PC.pc_hp <= 0:
				PC.player_instance.game_over()
			print("Player hit by straight line attack, damage: ", actual_damage)
				
		await get_tree().create_timer(0.1).timeout
		
	if is_instance_valid(attack_indicator):
			attack_indicator.queue_free()
			attack_indicator = null
	is_attacking = false

# 为直线攻击单独创建攻击指示器显示函数
func _show_attack_indicator_for_straight_line(direction: Vector2):
	if attack_indicator and is_instance_valid(attack_indicator):
		attack_indicator.queue_free()
		attack_indicator = null
	await get_tree().process_frame

	attack_indicator = Node2D.new()
	add_child(attack_indicator)
	attack_indicator.global_position = global_position # 确保指示器在正确位置

	var line_appear_tween = create_tween().bind_node(attack_indicator)
	line_appear_tween.set_parallel(true)

	var outer_line_width = 45
	var inner_line_width = 34

	var outer_line_straight = Line2D.new()
	outer_line_straight.default_color = Color(1.0, 0.1, 0.0, 0.4)
	outer_line_straight.width = outer_line_width
	outer_line_straight.modulate.a = 0.0
	attack_indicator.add_child(outer_line_straight)

	var inner_line_straight = Line2D.new()
	inner_line_straight.default_color = Color(1.0, 1, 0, 0.4)
	inner_line_straight.width = inner_line_width
	inner_line_straight.modulate.a = 0.0
	attack_indicator.add_child(inner_line_straight)

	var straight_max_length = 2800.0 # 直线指示器最大长度
	var straight_extend_speed = 2800.0 # px/s
	var straight_extend_duration = straight_max_length / straight_extend_speed

	line_appear_tween.tween_property(inner_line_straight, "modulate:a", 1.0, straight_extend_duration * 0.1875)
	line_appear_tween.tween_property(outer_line_straight, "modulate:a", 1.0, straight_extend_duration * 0.15).set_delay(0.01875)

	inner_line_straight.set_points([Vector2.ZERO, Vector2.ZERO])
	outer_line_straight.set_points([Vector2.ZERO, Vector2.ZERO])
	line_appear_tween.tween_method(
		func(value: float):
			if is_instance_valid(inner_line_straight):
				inner_line_straight.set_point_position(1, direction * value)
			if is_instance_valid(outer_line_straight):
				outer_line_straight.set_point_position(1, direction * value),
		0.0,
		straight_max_length,
		straight_extend_duration
	)
	attack_indicator.visible = true
	

# 隐藏攻击指示器（带动画）
func _hide_attack_indicator_with_animation():
	if not attack_indicator or not is_instance_valid(attack_indicator):
		return
	
	var disappear_tween = create_tween()
	disappear_tween.set_parallel(true)

	var lines_to_animate = []
	for child in attack_indicator.get_children():
		if child is Line2D and is_instance_valid(child):
			lines_to_animate.append(child)

	# 所有线条同时开始消失，可以根据内外层或创建顺序调整延迟
	var base_delay = 0.0
	var delay_increment = 0.01 # 每条线之间的微小延迟，制造层次感
	
	# 可以根据线条宽度判断内外层，或者直接按子节点顺序处理
	# 这里简单地为所有线条应用动画，如果需要更复杂的内外层消失顺序，需要进一步分类
	for i in range(lines_to_animate.size()):
		var line = lines_to_animate[i]
		# 判断是外层还是内层，可以基于宽度或者命名约定
		var is_outer_line = line.width >= 34.5 # 假设外层线较宽
		var current_delay = base_delay + i * delay_increment
		
		if is_outer_line:
			disappear_tween.tween_property(line, "modulate:a", 0.0, 0.06).set_delay(current_delay)
		else: # 内层线条
			disappear_tween.tween_property(line, "modulate:a", 0.0, 0.06).set_delay(current_delay) # 内层可以稍微晚一点或与外层同步消失

	disappear_tween.finished.connect(func():
		if is_instance_valid(attack_indicator):
			attack_indicator.queue_free()
			attack_indicator = null
	)
	# 确保动画播放
	if not disappear_tween.is_running():
		disappear_tween.play()


func _attack_triple_line():
	print("Attack: Triple Line")
	
	# 连续射击3次

	for i in range(3):
		# 每次射击前重新瞄准玩家
		var current_player_pos = PC.player_instance.global_position
		var base_direction = global_position.direction_to(current_player_pos)
		
		# 读条
		Global.emit_signal("boss_chant_start", "分裂荆棘" + str(i + 1), 0.75)
		if i == 0:
			_spawn_poetry_extra_meteors()
		
		# 显示攻击指示器（带生成动画）
		_show_attack_indicator_for_triple_line(base_direction)
		
		# 等待0.5秒让生成动画播放完毕
		await get_tree().create_timer(0.75).timeout
		Global.emit_signal("boss_chant_end")
		
		# 播放消失动画
		_hide_attack_indicator_with_animation()
		# 播放藤蔓攻击动画（三个方向）
		for jv in range(-1, 2):
			_spawn_vine_along_line(global_position, base_direction.rotated(deg_to_rad(jv * 20)), 1600.0, 3)
		
		# 隐藏攻击指示器
		# if attack_indicator:
		# 	attack_indicator.visible = false
		
		# 播放射击音效
		$straight.play()
		_screen_shake(3.0, 0.15)
		
		# 进行伤害判定
		var player_pos = PC.player_instance.global_position
		var boss_pos = global_position
		var attack_range_length = 1600.0
		var line_width_tolerance = 20
		var _player_damaged_this_round = false

		
		# 检查玩家是否在三条攻击直线上
		for j in range(-1, 2):
			var attack_direction = base_direction.rotated(deg_to_rad(j * 20))
			var line_end = boss_pos + attack_direction * attack_range_length
			var distance_to_line = _point_to_line_distance(player_pos, boss_pos, line_end)
			var player_to_boss = player_pos - boss_pos
			var projection_length = player_to_boss.dot(attack_direction)
			
			if distance_to_line <= line_width_tolerance and projection_length >= 0 and projection_length <= attack_range_length:
				Global.emit_signal("player_hit")
				var actual_damage = int(atk * (1.0 - PC.damage_reduction_rate))
				PC.player_hit(int(actual_damage), self , "分裂荆棘")
				if PC.pc_hp <= 0:
					PC.player_instance.game_over()
				_player_damaged_this_round = true

				print("Player hit by triple line attack, damage: ", actual_damage)
				break # 玩家已受伤，跳出方向循环
				
		await get_tree().create_timer(0.13).timeout
	
	is_attacking = false

# 为三线攻击单独创建攻击指示器显示函数（带动画）
func _show_attack_indicator_for_triple_line(base_direction: Vector2):
	if attack_indicator and is_instance_valid(attack_indicator):
		attack_indicator.queue_free()
		attack_indicator = null
	await get_tree().process_frame

	attack_indicator = Node2D.new()
	add_child(attack_indicator)
	attack_indicator.global_position = global_position # 确保指示器在正确位置

	var tri_appear_tween = create_tween().bind_node(attack_indicator)
	tri_appear_tween.set_parallel(true)
	var base_angle_rad = base_direction.angle()
	var angles_offset = [-deg_to_rad(20), 0, deg_to_rad(20)]

	var outer_width_tri = 30
	var inner_width_tri = 22

	for i in 3:
		var current_angle = base_angle_rad + angles_offset[i]
		var direction = Vector2.RIGHT.rotated(current_angle)
		
		var outer_line_tri = Line2D.new()
		outer_line_tri.default_color = Color(1.0, 0.1, 0.0, 0.35)
		outer_line_tri.width = outer_width_tri
		outer_line_tri.modulate.a = 0.0
		attack_indicator.add_child(outer_line_tri)

		var inner_line_tri = Line2D.new()
		inner_line_tri.default_color = Color(1.0, 1, 0, 0.35)
		inner_line_tri.width = inner_width_tri
		inner_line_tri.modulate.a = 0.0
		attack_indicator.add_child(inner_line_tri)

		var tri_max_length = 2500.0 # 三向指示器最大长度
		var tri_extend_speed = 2800.0 # px/s
		var tri_extend_duration = tri_max_length / tri_extend_speed

		tri_appear_tween.tween_property(inner_line_tri, "modulate:a", 1.0, tri_extend_duration * 0.375).set_delay(i * 0.0375)
		tri_appear_tween.tween_property(outer_line_tri, "modulate:a", 1.0, tri_extend_duration * 0.3).set_delay(i * 0.0375 + 0.0375)

		inner_line_tri.set_points([Vector2.ZERO, Vector2.ZERO])
		outer_line_tri.set_points([Vector2.ZERO, Vector2.ZERO])
		tri_appear_tween.tween_method(
			func(value: float):
				if is_instance_valid(inner_line_tri):
					inner_line_tri.set_point_position(1, direction * value)
				if is_instance_valid(outer_line_tri):
					outer_line_tri.set_point_position(1, direction * value),
			0.0,
			tri_max_length,
			tri_extend_duration
		).set_delay(i * 0.05) # 每条线错开延伸
	attack_indicator.visible = true


func _attack_eight_directions():
	print("Attack: Eight Directions")

	# 检查玩家是否在攻击范围内并造成伤害

	var player_node = PC.player_instance
	if player_node:
		var player_pos = player_node.global_position
		var boss_pos = global_position
		var attack_range_length = 600.0 # 与指示器一致
		var line_width_tolerance = 32
		var _player_damaged_this_attack = false


		# 播放射击音效
		$straight.play()
		# 检查玩家是否在任一攻击直线上
		for i in 8:
			var attack_direction = Vector2.RIGHT.rotated(deg_to_rad(i * 45.0))
			var line_end = boss_pos + attack_direction * attack_range_length
			
			# 计算玩家到直线的距离
			var distance_to_line = _point_to_line_distance(player_pos, boss_pos, line_end)
			
			# 检查玩家是否在直线范围内（距离小于容差且在线段长度内）
			var player_to_boss = player_pos - boss_pos
			var projection_length = player_to_boss.dot(attack_direction)
			
			if distance_to_line <= line_width_tolerance and projection_length >= 0 and projection_length <= attack_range_length:
				Global.emit_signal("player_hit")
				var actual_damage = int(atk * (1.0 - PC.damage_reduction_rate))
				PC.player_hit(int(actual_damage), self , "荆棘遍布")
				if PC.pc_hp <= 0:
					PC.player_instance.game_over()
				_player_damaged_this_attack = true

				print("Player hit by eight-direction line attack, damage: ", actual_damage)
				break # 玩家已受伤，跳出方向循环

	# 播放藤蔓攻击动画（八个方向）
	for i in 8:
		var vine_dir = Vector2.RIGHT.rotated(deg_to_rad(i * 45.0))
		_spawn_vine_along_line(global_position, vine_dir, 600.0, 3)
	_screen_shake(4.0, 0.2)

	await get_tree().create_timer(0.5).timeout
	is_attacking = false


func _attack_charge():
	print("Attack: Charge")

	# 根据锁定的冲锋方向设置 sprite 朝向
	if charge_indicator_direction.x < 0:
		sprite.flip_h = true
	else:
		sprite.flip_h = false

	# 【核心修复】直接使用指示器生成时锁定的方向矢量，
	# 不再从「当前 boss 位置 → 存储目标点」重新推算方向。
	# 这样无论 boss 在预警期间是否有任何位置偏移，冲锋方向与指示器始终完全一致。
	var charge_dir := charge_indicator_direction # 锁定方向
	var charge_dist := 600.0 # 与指示器一致的预设冲锋距离
	var ray_origin := global_position
	var ray_end := ray_origin + charge_dir * 2000.0

	# 从当前 boss 位置沿锁定方向出发，计算预设落地点
	var intended_target_pos := ray_origin + charge_dir * charge_dist

	# 边界截断：若落地点超出场地边界则截断到最近边界交点
	var boundaries := [
		[Vector2(left_boundary, top_boundary), Vector2(right_boundary, top_boundary)],
		[Vector2(left_boundary, bottom_boundary), Vector2(right_boundary, bottom_boundary)],
		[Vector2(left_boundary, top_boundary), Vector2(left_boundary, bottom_boundary)],
		[Vector2(right_boundary, top_boundary), Vector2(right_boundary, bottom_boundary)]
	]

	var final_target_pos := intended_target_pos
	var min_dist_sq := (intended_target_pos - ray_origin).length_squared()
	for seg in boundaries:
		var intersection = Geometry2D.segment_intersects_segment(
				ray_origin, ray_end, seg[0], seg[1])
		if intersection:
			var hit_point := intersection as Vector2 # 显式转型，解决 Variant 类型推断失败
			var d_sq := (hit_point - ray_origin).length_squared()
			if d_sq < min_dist_sq:
				min_dist_sq = d_sq
				final_target_pos = hit_point

	print("执行冲锋: 方向=", charge_dir, " 目标=", final_target_pos)

	var charge_speed := speed * 12
	var actual_distance := (final_target_pos - ray_origin).length()
	var charge_time := 0.0
	if charge_speed > 0 and actual_distance > 0.1:
		charge_time = actual_distance / charge_speed

	$BossA.play("run")
	is_charging = true # 冲锋开始
	var tween := create_tween()
	if actual_distance > 0.1 and charge_time > 0:
		_start_charge_shake() # 启动后台持续小幅震颟
		tween.tween_property(self , "global_position", final_target_pos, charge_time)
		tween.finished.connect(func():
			is_attacking = false
			is_charging = false
			$BossA.play("run")
			allow_turning = true
		)
	else:
		is_attacking = false
		is_charging = false
		$BossA.play("run")
		allow_turning = true


# 检查怪物是否在可伤害范围内（超出视野20px才能被伤害）
func _is_monster_in_damage_range() -> bool:
	# 获取摄像头
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return true # 如果没有摄像头，默认可以伤害
	
	# 获取视野范围
	var viewport_size = get_viewport().get_visible_rect().size
	var camera_zoom = camera.zoom
	var visible_size = viewport_size / camera_zoom
	
	# 计算摄像头的可视区域边界
	var camera_pos = camera.global_position
	var half_visible_size = visible_size / 2
	
	var left_bound = camera_pos.x - half_visible_size.x
	var right_bound = camera_pos.x + half_visible_size.x
	var top_bound = camera_pos.y - half_visible_size.y
	var bottom_bound = camera_pos.y + half_visible_size.y
	
	# 扩展边界，使其在屏幕上保持固定的N像素边距 (例如20像素)
	# 原来的 damage_margin 是固定的世界单位，导致缩放时屏幕上的实际边距变化
	# 现在我们将其理解为屏幕像素，并转换为世界单位
	var screen_pixel_margin = 20.0
	if camera_zoom.x == 0.0 or camera_zoom.y == 0.0:
		# 防止除以零错误，尽管camera_zoom通常不会是0
		# 在这种不太可能的情况下，可以不加边距或设置一个默认的世界边距
		# 例如，这里选择不修改边界 (等同于边距为0)
		pass
	else:
		var world_margin_x = screen_pixel_margin / camera_zoom.x
		var world_margin_y = screen_pixel_margin / camera_zoom.y
		
		left_bound -= world_margin_x
		right_bound += world_margin_x
		top_bound -= world_margin_y
		bottom_bound += world_margin_y
	
	# 检查怪物位置是否在可伤害范围内
	var monster_pos = global_position
	return (monster_pos.x >= left_bound and monster_pos.x <= right_bound and
			monster_pos.y >= top_bound and monster_pos.y <= bottom_bound)


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("bullet") and area.has_method("get_bullet_damage_and_crit_status"):
		# 检查怪物是否在视野范围内（超出视野20px才能被伤害）
		if not _is_monster_in_damage_range():
			return
		
		# 使用BulletCalculator处理完整的子弹碰撞逻辑
		var collision_result = BulletCalculator.handle_bullet_collision_full(area, self , true)
		var final_damage_val = get_common_bullet_damage_value(collision_result["final_damage"])
		var is_crit = collision_result["is_crit"]
		
		# Boss血条更新
		Global.emit_signal("boss_hp_bar_take_damage", final_damage_val)
		hp -= int(final_damage_val)
		
		# 处理子弹反弹
		if collision_result["should_rebound"]:
			area.call_deferred("create_rebound")
		
		# 根据穿透逻辑决定是否销毁子弹
		if collision_result["should_delete_bullet"]:
			area.queue_free()
			
		if hp <= 0:
			_die()
		else:
			Global.play_hit_anime(position, is_crit)

func take_damage(damage: int, is_crit: bool, is_summon: bool, damage_type: String) -> void:
	var damage_result = apply_common_take_damage(damage, is_crit, is_summon, damage_type, {
		"use_debuff_multiplier": false,
		"update_boss_hp_bar": true,
		"play_hit_animation": true,
		"randomize_popup_offset": true,
		"require_damage_range_check": true
	})
	if damage_result["applied"] and damage_result["is_lethal"]:
		_die()
func _die():
	if not is_dead:
		_drop_boss_rewards()
		Global.emit_signal("boss_defeated", get_point, global_position)
		Global.emit_signal("monster_killed")
	is_dead = true
	remove_from_group("enemies")
	Global.emit_signal("boss_chant_end")
	get_tree().call_group("boss_a_petal", "queue_free")
	get_tree().call_group("boss_a_poison_circle", "queue_free")
	var collision_shape = get_node("CollisionShape2D")

	collision_shape.disabled = true
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	var shadow = get_node_or_null("Shadow")
	if shadow:
		shadow.visible = false
	attack_timer.stop()
	queue_free()

# 计算点到直线的距离的辅助函数
func _point_to_line_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line_vec = line_end - line_start
	var point_vec = point - line_start
	var line_length_sq = line_vec.length_squared()
	
	if line_length_sq == 0:
		return point_vec.length() # 如果线段长度为0，返回点到起点的距离
	
	# 计算点在直线上的投影
	var t = point_vec.dot(line_vec) / line_length_sq
	t = clamp(t, 0.0, 1.0) # 限制在线段范围内
	
	# 计算最近点
	var closest_point = line_start + t * line_vec
	return point.distance_to(closest_point)

func _attack_random_barrage():
	print("Attack: Random Barrage")
	var barrage_bullet_count := _get_random_barrage_bullet_count()
	var barrage_duration := _get_random_barrage_duration()
	var barrage_interval := barrage_duration / float(barrage_bullet_count)
	Global.emit_signal("boss_chant_start", "花雨", barrage_duration)
	var petal_bullet_scene = preload("res://Scenes/moster/petal_bullet.tscn")
	for i in range(barrage_bullet_count):
		var bullet = petal_bullet_scene.instantiate()
		
		# 将子弹添加到场景树
		if get_parent():
			get_parent().add_child(bullet)
		else:
			get_tree().current_scene.add_child(bullet)
		
		# 设置子弹位置和方向
		bullet.global_position = global_position
		var random_angle = randf_range(0, TAU)
		var direction = Vector2.RIGHT.rotated(random_angle)
		
		# 设置子弹方向和速度
		bullet.set_direction(direction)
		bullet.bullet_speed = 190.0
		bullet.bullet_damage = atk
		bullet.source_name = "花雨"
		
		await get_tree().create_timer(barrage_interval, false).timeout
	
	Global.emit_signal("boss_chant_end")
	is_attacking = false # 攻击结束


#func free_health_bar():
	#if health_bar != null and health_bar.is_inside_tree():
		#health_bar.queue_free()

func apply_knockback(_direction: Vector2, _force: float):
	# Boss可以有击退抗性，或者完全免疫
	pass

# ============== 新技能: 陨石攻击(即时伤害) ==============
func _attack_meteor_instant():
	"""技能6: 向玩家周围随机掉落陨石，落地后直接判定伤害"""
	print("Attack: Meteor Instant")
	Global.emit_signal("boss_chant_start", "盛放之棘", METEOR_WARNING_TIME + METEOR_COUNT * 0.15)
	
	var player_pos = PC.player_instance.global_position
	
	# 生成多个陨石预警
	for i in range(METEOR_COUNT):
		var random_offset = Vector2(
			randf_range(-METEOR_SPAWN_RANGE, METEOR_SPAWN_RANGE),
			randf_range(-METEOR_SPAWN_RANGE, METEOR_SPAWN_RANGE)
		)
		_spawn_meteor_warning_at(player_pos + random_offset, false, "盛放之棘")
		
		# 每个陨石之间稍微延迟，创造连续感
		await get_tree().create_timer(0.15, false).timeout
	
	# 等待最后一个陨石预警完成
	await get_tree().create_timer(METEOR_WARNING_TIME + 0.3, false).timeout
	Global.emit_signal("boss_chant_end")
	is_attacking = false


func _on_meteor_warning_finished(spawn_pos: Vector2, warning_circle: Node2D):
	"""陨石预警结束回调：清除预警圈并在落点生成藤蔓特效"""
	if is_instance_valid(warning_circle):
		warning_circle.cleanup()
	# 在落点中心及周围生成一簇藤蔓，模拟水泌/荆棘爆发感
	_spawn_vine_effect_at(spawn_pos)
	for i in 4:
		var angle := i * PI * 0.5 + randf_range(-0.3, 0.3) # 四方向带小幅随机偏移
		var offset := Vector2.RIGHT.rotated(angle) * randf_range(12.0, 22.0)
		_spawn_vine_effect_at(spawn_pos + offset)
	# 陨石落地震颟
	_screen_shake(1.75, 0.2)

func _on_meteor_damage_dealt(damage_amount: float):
	"""陨石造成伤害回调"""
	print("陨石对玩家造成伤害: ", damage_amount)

# ============== 新技能: 陨石攻击(持续伤害区域) ==============
func _attack_meteor_persistent():
	"""技能7: 向玩家周围随机掉落陨石，落地后产生poison_circle持续伤害绿圈"""
	print("Attack: Meteor Persistent")
	Global.emit_signal("boss_chant_start", "剧毒之棘", METEOR_WARNING_TIME + METEOR_COUNT * 0.15)
	
	var player_pos = PC.player_instance.global_position
	
	# 生成多个陨石预警
	for i in range(METEOR_COUNT):
		var random_offset = Vector2(
			randf_range(-METEOR_SPAWN_RANGE, METEOR_SPAWN_RANGE),
			randf_range(-METEOR_SPAWN_RANGE, METEOR_SPAWN_RANGE)
		)
		_spawn_meteor_warning_at(player_pos + random_offset, true, "剧毒之棘")
		
		# 每个陨石之间稍微延迟
		await get_tree().create_timer(0.15, false).timeout
	
	# 等待预警完成
	await get_tree().create_timer(METEOR_WARNING_TIME + 0.3, false).timeout
	Global.emit_signal("boss_chant_end")
	is_attacking = false


func _on_meteor_persistent_warning_finished(spawn_pos: Vector2, warning_circle: Node2D):
	"""陨石预警结束，生成持续伤害绻圈（poison_circle 像素风格）"""
	if is_instance_valid(warning_circle):
		warning_circle.cleanup()
	
	# 生成 poison_circle（像素风格绿圈，负责视觉显示和持续伤害）
	# scale 根据当前难度修正后的陨石半径动态计算，确保判定范围与预警圈一致
	var poison_circle_scene = preload("res://Scenes/moster/poison_circle.tscn")
	var pc_instance = poison_circle_scene.instantiate()
	pc_instance.damage_per_tick = atk * 0.4
	pc_instance.attacker = self
	pc_instance.source_name = "剧毒之棘"
	pc_instance.duration = METEOR_PERSIST_DURATION
	pc_instance.is_permanent = _is_core_or_harder()
	pc_instance.global_position = spawn_pos
	pc_instance.scale = _get_poison_circle_scale()
	pc_instance.add_to_group("boss_a_poison_circle")
	get_tree().current_scene.add_child(pc_instance)
	# 陨石落地震颟
	_screen_shake(1.75, 0.2)


# ============== 新技能: 扇形AOE ==============
func _attack_sector_aoe():
	"""技能8: 向玩家方向发射扇形AOE"""
	print("Attack: Sector AOE")
	
	var player_pos = PC.player_instance.global_position
	var direction_to_player = global_position.direction_to(player_pos)
	var target_point = global_position + direction_to_player * SECTOR_RADIUS
	
	var warning_sector = WarnSectorUtil.new()
	add_child(warning_sector)
	
	# 连接信号
	warning_sector.warning_finished.connect(_on_sector_warning_finished.bind(warning_sector))
	warning_sector.damage_dealt.connect(_on_sector_damage_dealt)
	
	# 开始预警
	warning_sector.start_warning(
		global_position, # 起始位置(Boss位置)
		target_point, # 目标点(决定方向和半径)
		SECTOR_ANGLE, # 扇形角度
		SECTOR_WARNING_TIME, # 预警时间
		atk * 2.0, # 伤害
		"扇形AOE", # 伤害来源
		null, # 动画播放器
		0.5
	)
	
	# 等待预警完成
	await get_tree().create_timer(SECTOR_WARNING_TIME + 0.3).timeout
	is_attacking = false

func _on_sector_warning_finished(warning_sector: Node2D):
	"""扇形预警结束回调"""
	if is_instance_valid(warning_sector):
		warning_sector.cleanup()

func _on_sector_damage_dealt(damage_amount: float):
	"""扇形AOE造成伤害回调"""
	print("扇形AOE对玩家造成伤害: ", damage_amount)

# ============== 新技能: 连续扇形AOE ==============
func _attack_multi_sector_aoe():
	"""技能9: 连续向玩家方向发射5轮扇形AOE，每次重新瞄准"""
	print("Attack: Multi Sector AOE")
	
	for i in range(MULTI_SECTOR_ROUNDS):
		# 每次攻击前重新瞄准玩家当前位置
		var current_player_pos = PC.player_instance.global_position
		var direction_to_player = global_position.direction_to(current_player_pos)
		var target_point = global_position + direction_to_player * SECTOR_RADIUS
		
		var warning_sector = WarnSectorUtil.new()
		add_child(warning_sector)
		
		# 连接信号
		warning_sector.warning_finished.connect(_on_multi_sector_warning_finished.bind(warning_sector))
		warning_sector.damage_dealt.connect(_on_multi_sector_damage_dealt)
		
		# 开始预警 - 连续攻击用更短的预警时间
		var quick_warning_time = SECTOR_WARNING_TIME * 0.6
		warning_sector.start_warning(
			global_position, # 起始位置(Boss位置)
			target_point, # 目标点(决定方向和半径)
			SECTOR_ANGLE * 0.8, # 连续攻击用稍小的角度
			quick_warning_time, # 更短的预警时间
			atk * 1.2, # 伤害
			"连续扇形AOE", # 伤害来源
			null, # 动画播放器
			quick_warning_time * 0.5
		)
		
		print("第 ", i + 1, " 轮扇形AOE，瞄准位置: ", current_player_pos)
		
		# 等待当前轮预警完成后再进行下一轮
		await get_tree().create_timer(quick_warning_time + 0.2).timeout
	
	is_attacking = false

func _on_multi_sector_warning_finished(warning_sector: Node2D):
	"""连续扇形预警结束回调"""
	if is_instance_valid(warning_sector):
		warning_sector.cleanup()

func _on_multi_sector_damage_dealt(damage_amount: float):
	"""连续扇形AOE造成伤害回调"""
	print("连续扇形AOE对玩家造成伤害: ", damage_amount)

# ============== 藤蔓攻击动画辅助函数 ==============
func _spawn_vine_along_line(origin: Vector2, direction: Vector2, length: float, _count: int = 4) -> void:
	"""沿攻击线段每隔 38 像素生成一个藤蔓特效，直至射程末端"""
	var step := 16.0
	var traveled := step * 2 # 从半步开始，避免直接在 boss 脚下生成
	while traveled <= length:
		_spawn_vine_effect_at(origin + direction * traveled)
		traveled += step

# 静态缓存：像素风藤蔓动画帧，多次攻击共享同一份数据
static var _vine_frames_cache: SpriteFrames = null

func _build_vine_frames() -> SpriteFrames:
	"""
	程序化绘制像素风格藤蔓动画（不依赖任何外部图片）。
	12×12 艺术像素网格，每格 4×4 实际像素 = 48×48 帧尺寸。
	颜色参考用户手绘：深绿轮廓 / 中绿主体 / 亮绿高亮，厚实方块笔触。
	"""
	var frames := SpriteFrames.new()
	frames.add_animation("attack")

	# 三层颜色（参考上传图片的手绘马克笔像素风格）
	var col_dark := Color(0.051, 0.282, 0.051, 1.0) # 深绿 - 粗轮廓
	var col_mid := Color(0.102, 0.541, 0.102, 1.0) # 中绿 - 主体填充
	var col_hi := Color(0.141, 0.741, 0.141, 1.0) # 亮绿 - 高亮点缀

	# 藤蔓图案：12×12 网格（0=透明 1=深绿 2=中绿 3=亮绿）
	# 风格：厚实方块笔触、多方向分叉的有机藤蔓枝干
	var pattern: Array = [
		[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], # 行 0
		[0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0], # 行 1  左上分支起始
		[0, 1, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0], # 行 2
		[0, 0, 1, 2, 1, 0, 0, 0, 0, 0, 0, 0], # 行 3
		[0, 0, 1, 2, 2, 1, 0, 0, 0, 0, 0, 0], # 行 4  汇入主干
		[0, 0, 0, 1, 2, 2, 1, 1, 1, 0, 0, 0], # 行 5  主干 + 右侧分支
		[0, 0, 0, 0, 1, 2, 3, 2, 2, 1, 0, 0], # 行 6  高亮节点
		[0, 0, 0, 0, 1, 2, 2, 3, 2, 1, 0, 0], # 行 7  右分支延伸
		[0, 0, 0, 0, 0, 1, 2, 2, 1, 0, 0, 0], # 行 8  右分支末端
		[0, 0, 0, 0, 1, 2, 1, 0, 0, 0, 0, 0], # 行 9  下方分支
		[0, 0, 0, 1, 2, 2, 1, 0, 0, 0, 0, 0], # 行 10 下左延伸
		[0, 0, 0, 1, 2, 1, 0, 0, 0, 0, 0, 0], # 行 11 底部末端
	]

	var pixel_size := 4 # 每个艺术像素占 4×4 实际像素
	var grid_size := 12
	var img_size := grid_size * pixel_size # = 48

	# 计算图案内所有有效像素到视觉中心 (5.5, 5.5) 的最大距离
	var center_r := 5.5
	var center_c := 5.5
	var max_dist := 0.001
	for r in grid_size:
		for c in grid_size:
			if pattern[r][c] != 0:
				var d := sqrt((r - center_r) * (r - center_r) + (c - center_c) * (c - center_c))
				if d > max_dist:
					max_dist = d

	var TOTAL_FRAMES := 8
	var GROW_FRAMES := 6 # 前 6 帧：从中心向外生长
	var FADE_FRAMES := 2 # 后 2 帧：整体淡出消散

	for frame_idx in TOTAL_FRAMES:
		var img := Image.create(img_size, img_size, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))

		# 当前帧的最大显示半径和整体透明度
		var radius_shown: float
		var alpha: float
		if frame_idx < GROW_FRAMES:
			radius_shown = (float(frame_idx + 1) / float(GROW_FRAMES)) * max_dist
			alpha = 1.0
		else:
			radius_shown = max_dist # 全部显示
			alpha = 1.0 - float(frame_idx - GROW_FRAMES + 1) / float(FADE_FRAMES + 1)

		for r in grid_size:
			for c in grid_size:
				var cell: int = pattern[r][c]
				if cell == 0:
					continue
				var dist := sqrt((r - center_r) * (r - center_r) + (c - center_c) * (c - center_c))
				if dist > radius_shown:
					continue
				var base_color: Color
				match cell:
					1: base_color = col_dark
					2: base_color = col_mid
					3: base_color = col_hi
					_: continue
				var draw_color := Color(base_color.r, base_color.g, base_color.b, base_color.a * alpha)
				# 填充 4×4 像素块
				for py in pixel_size:
					for px in pixel_size:
						img.set_pixel(c * pixel_size + px, r * pixel_size + py, draw_color)

		frames.add_frame("attack", ImageTexture.create_from_image(img))

	frames.set_animation_speed("attack", 12.0)
	frames.set_animation_loop("attack", false)
	return frames

func _spawn_vine_effect_at(pos: Vector2) -> void:
	"""在指定位置生成一个像素风格藤蔓/荆棘攻击动画节点，播放完毕后自动销毁"""
	if _vine_frames_cache == null:
		_vine_frames_cache = _build_vine_frames()

	var vine := AnimatedSprite2D.new()
	vine.sprite_frames = _vine_frames_cache
	vine.animation = "attack"
	vine.global_position = pos
	vine.z_index = 1
	vine.scale = Vector2(0.9, 0.9) # 显示尺寸 36×36（48×0.75）
	vine.rotation = randf() * TAU # 随机旋转，增加每次生成的多样感
	get_tree().current_scene.add_child(vine)
	vine.play("attack")
	vine.animation_finished.connect(vine.queue_free)

# ============== 技能: 落花 ==============
func _attack_petal_rain() -> void:
	"""落花：从场地顶部持续飘落带红色勾边的花瓣，碰到玩家造成 ATK×60% 伤害。
	不同难度会额外提升初始数量、重复使用增长量与花瓣速度。
	花瓣持续飘落直到 boss 死亡才停止。"""
	petal_use_count += 1
	attacks_since_last_petal = 0
	_reset_interval_attack_plan()
	_petal_loop_generation += 1 # 使旧循环立即失效
	var my_gen: int = _petal_loop_generation

	var petals_per_second := _get_petal_spawn_count()
	var spawn_interval: float = 0.5 / float(petals_per_second)

	# 技能读条
	Global.emit_signal("boss_chant_start", "落花", 1.2)
	await get_tree().create_timer(1.2, false).timeout
	Global.emit_signal("boss_chant_end")

	# 读条结束后立即解除攻击锁定，boss 可继续释放其他技能
	is_attacking = false

	# 启动后台连续生成循环（不阻塞攻击状态）
	_start_petal_loop(spawn_interval, my_gen)


func _start_petal_loop(spawn_interval: float, generation: int) -> void:
	"""花瓣后台生成循环（非阻塞）。
	当 is_dead=true、boss 节点已释放、或者新一轮落花启动如旧进出循环。"""
	while not is_dead and is_instance_valid(self ) and _petal_loop_generation == generation:
		_spawn_one_petal()
		await get_tree().create_timer(spawn_interval, false).timeout


func _spawn_one_petal() -> void:
	"""在场地顶部随机 x 位置生成一片花瓣"""
	var petal_scene = preload("res://Scenes/moster/petal.tscn")
	var p = petal_scene.instantiate()
	var is_golden_petal := _should_spawn_golden_petal()
	get_tree().current_scene.add_child(p)
	p.scale = Vector2(0.3, 0.3) * (GOLDEN_PETAL_SCALE_MULTIPLIER if is_golden_petal else 1.0)
	var spawn_x = randf_range(left_boundary, right_boundary)
	var spawn_y = top_boundary - randf_range(20.0, 80.0) # 从顶部边界上方飘落
	p.initialize(
		atk * 0.6,
		Vector2(spawn_x, spawn_y),
		bottom_boundary + 100.0,
		_get_petal_speed_multiplier(),
		is_golden_petal
	)


# 屏幕震颟效果
func _start_charge_shake() -> void:
	"""冲锋位移期间持续小幅震颟，直到 is_charging = false。
	用独立的 base_offset 捕获 + 循环帧偏移，避免与 _screen_shake 冲突。"""
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	var base_offset = camera.offset
	while is_charging and is_instance_valid(self ):
		camera.offset = base_offset + Vector2(
			randf_range(-2.0, 2.0),
			randf_range(-1.0, 1.0)
		)
		await get_tree().process_frame
	if is_instance_valid(camera):
		camera.offset = base_offset


func _screen_shake(intensity: float = 6.0, duration: float = 0.3, _frequency: float = 30.0):
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
