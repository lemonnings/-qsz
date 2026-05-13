extends Node2D

# ============== 通用导出变量 ==============
@export var boss_robot_scene: PackedScene
@export var warning_scene: Control
@export var monster_spawn_timer: Timer
@export var point: int
@export var layer_ui: BattleCanvasLayer

# ============== 所有关卡完全一致的常数 ==============
const MONSTER_LIMIT_INCREASE_WAVE_STEP: int = 1
const INITIAL_WAVE_SPAWN_COUNT: int = 4
const WAVE_SPAWN_INCREASE_STEP: int = 5
const MAX_WAVE_SPAWN_COUNT: int = 30
const EARLY_WAVE_LIMIT: int = 10

# 精英怪配置（所有关卡一致）
const ELITE_SPAWN_CHANCE: float = 0.02 # 2%概率生成精英怪
const ELITE_SCALE_MULTIPLIER: float = 1.3 # 体型增加30%
const ELITE_ATK_MULTIPLIER: float = 1.2 # 攻击提升20%
const ELITE_HP_MULTIPLIER: float = 8.0 # 血量提升800%
const ELITE_EXP_MULTIPLIER: float = 4.0 # 经验4倍
const ELITE_POINT_MULTIPLIER: float = 5.0 # 真气5倍
const ELITE_DROP_MULTIPLIER: float = 15.0 # 掉落率15倍

const LATE_GAME_RAMP_TIME: float = 120.0 # 120秒后开始加速出怪
const LATE_GAME_INTERVAL_DECREASE: float = 0.1 # 每次出怪间隔降低0.1秒
const LATE_GAME_MIN_INTERVAL: float = 2.0 # 最低出怪间隔2.0秒
const LATE_GAME_SPEED_INCREASE: float = 0.01 # 每次出怪speed提升1%
const LATE_GAME_MAX_SPEED_BONUS: float = 0.30 # speed最多提升30%

# 动态平衡（所有关卡一致的常数）
const DYNAMIC_BALANCE_SPAWN_HIGH_THRESHOLD: float = 0.6 # 出怪增量高阈值（60%时0%增量）
const DYNAMIC_BALANCE_HP_LOW_THRESHOLD: float = 0.7 # HP削减低阈值（70%开始削弱）
const DYNAMIC_BALANCE_HP_HIGH_THRESHOLD: float = 1.0 # HP削减高阈值（100%最大削弱）
const DYNAMIC_BALANCE_HP_MIN_REDUCTION: float = 0.1 # 最小HP削减10%

# ============== 各关卡不同的配置值（var，子类可覆盖）==============
var STAGE_ID: String = ""
var SPAWN_INTERVAL_SECONDS: float = 5.0
var INITIAL_MONSTER_LIMIT: int = 50
var MAX_MONSTER_CAP: int = 120
var DYNAMIC_BALANCE_SPAWN_LOW_THRESHOLD: float = 0.3
var DYNAMIC_BALANCE_SPAWN_MAX_BONUS: float = 1.5
var DYNAMIC_BALANCE_HP_MAX_REDUCTION: float = 0.4
var LOW_POPULATION_FORCE_WAVE_MIN_TIME_LEFT: float = 1.25 # 场上怪过少且离下次刷怪还很久时，提前补下一波
var LATE_GAME_TIME_THRESHOLD: float = 180.0 # 180秒后进入后期
var LATE_GAME_LOW_POPULATION_RATIO: float = 0.35 # 后期怪数量<35%容量时立即补怪
var BASIC_TYPES: Array = [] # 如 ["slime", "peach_yao"]
var OTHER_TYPE_PER_WAVE_MAX: int = 1 # 非基础类型每波每种最多1个
var OTHER_TYPE_TOTAL_MAX: int = 4 # 非基础类型总上限4个
var ELITE_MAX: int = 3 # 精英怪同时存在最多3个

# ============== 通用成员变量 ==============
var monster_move_direction: int
var map_mechanism_num: float
var map_mechanism_num_max: float

var spawn_count: int = 0
var current_monster_count: int = 0
var max_monster_limit: int = 50 # 在 _ready() 中用 INITIAL_MONSTER_LIMIT 重新初始化
var last_wave_spawn_frame: int = -1

var boss_event_triggered: bool = false

var other_type_alive: int = 0 # 非基础类型怪物当前存活数
var elite_alive: int = 0 # 当前存活精英怪数量

var current_wave_hp_reduction: float = 0.0 # 当前波的HP削减比例
var current_spawn_interval: float = 0.0 # 当前出怪间隔（运行时由SPAWN_INTERVAL_SECONDS初始化）
var late_game_speed_bonus: float = 0.0 # 120秒后累积的speed加成（最大0.3=30%）

# 怪物生成池（子类初始化）
var stage_spawn_pool: Array[Dictionary] = []

# 金团团场景（修习树特殊篇解锁后可用）
const GOLD_BALL_BASE_CHANCE: float = 0.003 # 每波 0.3% 基础概率
var _gold_ball_scene: PackedScene = null

# 战斗动态对话系统
var battle_chat: BattleChat = null

# ============== 初始化 ==============
func _ready() -> void:
	_setup_stage_config()
	max_monster_limit = INITIAL_MONSTER_LIMIT
	current_spawn_interval = SPAWN_INTERVAL_SECONDS

	PC.player_instance = $Player
	Global.emit_signal("reset_camera")

	map_mechanism_num = 0
	var stage_index = Global.STAGE_ID_LIST.find(Global.current_stage_id)
	if Global.current_stage_id == "peach_grove" and Global.current_stage_difficulty == Global.STAGE_DIFFICULTY_SHALLOW:
		map_mechanism_num_max = 20000
	else:
		map_mechanism_num_max = 52000 + stage_index * 1000
		#map_mechanism_num_max = 5

	DpsManager.reset_dps_counter()

	# 重置击杀计数
	GU.reset_kill_count()

	# 诗想难度：玩家直接50级 + Boss基于第8分钟数据
	if Global.current_stage_difficulty == Global.STAGE_DIFFICULTY_POETRY:
		_apply_poetry_init()

	# 连接关卡特定信号
	Global.connect("monster_mechanism_gained", Callable(self , "_on_monster_mechanism_gained"))
	Global.connect("boss_defeated", Callable(self , "_on_boss_defeated"))

	# 初始化主技能图标
	layer_ui.init_main_skill($Player.fire_speed.wait_time)

	# 初始化怪物生成计时器
	monster_spawn_timer = Timer.new()
	add_child(monster_spawn_timer)
	monster_spawn_timer.wait_time = SPAWN_INTERVAL_SECONDS
	monster_spawn_timer.one_shot = false
	monster_spawn_timer.connect("timeout", Callable(self , "_on_monster_spawn_timer_timeout"))
	# 诗想难度不启动刷怪计时器
	if Global.current_stage_difficulty != Global.STAGE_DIFFICULTY_POETRY:
		monster_spawn_timer.start()

	# 初始化技能冷却显示
	layer_ui.update_skill_cooldowns($Player)
	# 诗想难度不刷第一波怪
	if Global.current_stage_difficulty != Global.STAGE_DIFFICULTY_POETRY:
		_spawn_wave()

	# 初始化战斗动态对话系统
	battle_chat = BattleChat.new()
	add_child(battle_chat)
	battle_chat.initialize(layer_ui.teammate_dialogue_mgr)

# ============== 虚方法（子类覆盖）==============
func _setup_stage_config() -> void:
	pass # 子类覆盖，设置 STAGE_ID 和各种配置值

# ============== 诗想难度初始化 ===============
func _apply_poetry_init() -> void:
	# 1. 执行49次属性成长（不含奖励选择），使玩家达到50级属性
	for i in range(49):
		_poetry_stat_growth()
	PC.pc_lv = 50
	PC.pc_hp = PC.pc_max_hp
	
	# 2. 设置游戏时间为第8分钟(480秒)，使怪物/Boss基于该时刻的数值
	PC.real_time = 480
	PC.current_time = 480
	
	# 3. 重新应用诗想备战配置（reset_player_attr会清空selected_rewards，此处恢复）
	_apply_poetry_loadout()
	
	# 4. 设置诗想难度下的DPS计算覆盖值
	Global.poetry_dps_override = PC.pc_atk * 15.0
	
	# 5. 直接出Boss：机制上限设为5，进图即触发
	map_mechanism_num_max = 5
	
	print("[Poetry] 玩家初始化50级, ATK=", PC.pc_atk, " HP=", PC.pc_max_hp, " DPS覆盖=", Global.poetry_dps_override)

## 重新应用诗想备战配置并添加武器伤害加成
func _apply_poetry_loadout() -> void:
	var loadout = PC.poetry_loadout
	if loadout.is_empty():
		return
	
	PC.selected_rewards.clear()
	PC.current_weapon_num = 0
	
	# 应用+12武器及进阶
	var w12_id = loadout.get("w12_id", "")
	if w12_id != "":
		_grant_poetry_weapon_level(w12_id, 12)
		for adv_id in loadout.get("adv12_ids", []):
			if adv_id != "":
				_grant_poetry_advancement(adv_id)
	
	# 应用+3武器及进阶
	var w3_ids = loadout.get("w3_ids", [])
	var adv3_ids = loadout.get("adv3_ids", [])
	for i in range(w3_ids.size()):
		var w_id = w3_ids[i]
		if w_id != "":
			_grant_poetry_weapon_level(w_id, 3)
			if i < adv3_ids.size() and adv3_ids[i] != "":
				_grant_poetry_advancement(adv3_ids[i])
	
	# 添加武器伤害加成：+12武器72%，每个+3武器18%
	PC.pc_final_atk += 0.72 + w3_ids.size() * 0.18

func _grant_poetry_weapon_level(w_id: String, target_level: int):
	var base_func = "reward_" + w_id
	if LvUp.has_method(base_func):
		LvUp.call(base_func)
	var upgrade_func = "reward_R" + w_id
	for i in range(target_level - 1):
		if LvUp.has_method(upgrade_func):
			LvUp.call(upgrade_func)

func _grant_poetry_advancement(adv_id: String):
	var adv_func = "reward_" + adv_id
	if LvUp.has_method(adv_func):
		LvUp.call(adv_func)

## 诗想难度单次属性成长（模拟 global_level_up 中的纯属性部分）
func _poetry_stat_growth() -> void:
	PC.pc_atk += 5
	PC.pc_start_atk += 5
	PC.pc_atk = int(PC.pc_atk * 1.1)
	PC.pc_start_atk = int(PC.pc_start_atk * 1.1)
	PC.pc_max_hp += 20
	PC.pc_start_max_hp += 20
	PC.pc_hp += 20
	var lv_hp_bonus = int(PC.pc_start_max_hp * 0.02)
	PC.pc_max_hp += lv_hp_bonus
	PC.pc_start_max_hp += lv_hp_bonus

func _spawn_wave() -> void:
	pass # 子类覆盖，实现怪物波生成

func _choose_individual_type(wave_other_type_counts: Dictionary) -> String:
	var available_entries: Array[Dictionary] = []
	var total_weight = 0
	for entry in stage_spawn_pool:
		var entry_type = entry["type"]
		if spawn_count <= EARLY_WAVE_LIMIT and entry["blocked_early"]:
			continue
		if not BASIC_TYPES.has(entry_type):
			if other_type_alive >= OTHER_TYPE_TOTAL_MAX:
				continue
			if wave_other_type_counts.has(entry_type) and wave_other_type_counts[entry_type] >= OTHER_TYPE_PER_WAVE_MAX:
				continue
		available_entries.append(entry)
		total_weight += int(entry["weight"])

	if available_entries.is_empty() or total_weight <= 0:
		return "slime"

	var random_weight = randi_range(1, total_weight)
	var accumulated_weight = 0
	for entry in available_entries:
		accumulated_weight += int(entry["weight"])
		if random_weight <= accumulated_weight:
			return entry["type"]

	return available_entries[available_entries.size() - 1]["type"]

func _get_boss_position() -> Vector2:
	return Vector2(-370, randf_range(185, 259)) # 默认值，子类可覆盖

func _get_boss_camera_zoom() -> Vector2:
	return Vector2(3.5, 3.5) # 默认Boss战缩放，子类可覆盖

# ============== 每帧更新 ==============
func _process(_delta: float) -> void:
	# 更新分数显示
	layer_ui.update_score_display(point)

	# 检查并更新技能图标
	layer_ui.check_and_update_skill_icons($Player)

	# 更新DPS显示
	layer_ui.update_dps_display()

func _physics_process(_delta: float) -> void:
	# 机关进度更新
	if not boss_event_triggered:
		map_mechanism_num += _delta * 40

	# 难度递增
	if PC.current_time < 0.3:
		PC.current_time = PC.current_time + 0.00024
	elif PC.current_time > 0.6 and PC.current_time <= 6.4:
		PC.current_time = PC.current_time + 0.00048
	else:
		PC.current_time = PC.current_time + 0.001

	# 检查Boss触发
	if map_mechanism_num >= map_mechanism_num_max and not boss_event_triggered:
		boss_event_triggered = true
		_trigger_boss_event()
		return

	PC.real_time += _delta
	PC.update_shields(_delta)

	# 更新UI显示
	layer_ui.update_time_display(PC.real_time)
	_check_level_up()
	layer_ui.update_hp_bar(PC.pc_hp, PC.pc_max_hp, PC.get_total_shield())
	layer_ui.update_lv_up_visibility()
	layer_ui.update_exp_bar(PC.pc_exp, layer_ui.get_required_lv_up_value(PC.pc_lv))
	layer_ui.update_mechanism_bar(map_mechanism_num, map_mechanism_num_max, boss_event_triggered)
	layer_ui.update_level_display(PC.pc_lv)

# ============== 升级检查 ==============
func _check_level_up() -> void:
	if PC.is_game_over:
		return
	if layer_ui.warning_active:
		return
	if PC.pc_exp >= layer_ui.get_required_lv_up_value(PC.pc_lv):
		layer_ui.add_pending_level_up()
		PC.pc_lv += 1
		PC.pc_exp = clamp((PC.pc_exp - layer_ui.get_required_lv_up_value(PC.pc_lv)), 0, layer_ui.get_required_lv_up_value(PC.pc_lv))
		Global.emit_signal("player_lv_up")


# ============== Boss事件 ==============
func _trigger_boss_event() -> void:
	print("Boss event triggered!")
	monster_spawn_timer.stop()

	# 播放Warning动画
	layer_ui.play_warning_animation()

	_on_warning_finished()

func _on_warning_finished() -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(3).timeout
	if not is_inside_tree():
		return

	var boss_node = boss_robot_scene.instantiate()

	# 逐步缩放相机
	for i in range(7):
		Global.emit_signal("zoom_camera", -0.08)
		if not is_inside_tree():
			return
		await get_tree().create_timer(0.2).timeout
		if not is_inside_tree():
			return

	boss_node.position = _get_boss_position()
	# Boss渐变出现效果
	boss_node.modulate.a = 0.0
	get_tree().current_scene.add_child(boss_node)
	var boss_tween = boss_node.create_tween()
	boss_tween.tween_property(boss_node, "modulate:a", 1.0, 0.8)
	_clear_non_boss_enemies()

func _clear_non_boss_enemies() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.is_in_group("boss"):
			continue
		enemy.monitoring = false
		enemy.monitorable = false
		enemy.collision_layer = 0
		enemy.collision_mask = 0
		var tween = enemy.create_tween()
		tween.tween_property(enemy, "modulate:a", 0.0, 0.4)
		tween.tween_callback(func(): enemy.queue_free())


func _on_monster_spawn_timer_timeout() -> void:
	_try_spawn_gold_ball()
	_spawn_wave()
	# 120秒后：出怪间隔逐渐降低，怪物速度逐渐提升
	if PC.real_time >= LATE_GAME_RAMP_TIME:
		current_spawn_interval = max(LATE_GAME_MIN_INTERVAL, current_spawn_interval - LATE_GAME_INTERVAL_DECREASE)
		late_game_speed_bonus = min(LATE_GAME_MAX_SPEED_BONUS, late_game_speed_bonus + LATE_GAME_SPEED_INCREASE)
	monster_spawn_timer.wait_time = current_spawn_interval

func _get_wave_spawn_count() -> int:
	var growth_steps = int(float(spawn_count - 1) / float(WAVE_SPAWN_INCREASE_STEP))
	var wave_spawn_count = INITIAL_WAVE_SPAWN_COUNT + growth_steps
	return min(wave_spawn_count, MAX_WAVE_SPAWN_COUNT)

func _update_wave_monster_limit() -> void:
	var limit_growth = int(float(spawn_count - 1) / float(MONSTER_LIMIT_INCREASE_WAVE_STEP))
	var base_limit = min(INITIAL_MONSTER_LIMIT + limit_growth, MAX_MONSTER_CAP)

	var extra_mult = 0.0
	if PC.selected_rewards.has("UR39"): extra_mult += 0.09
	elif PC.selected_rewards.has("SSR39"): extra_mult += 0.07
	elif PC.selected_rewards.has("SR39"): extra_mult += 0.06
	elif PC.selected_rewards.has("R39"): extra_mult += 0.05
	# 洪流（R48系列）：敌人数量加成
	if PC.selected_rewards.has("SSR48"): extra_mult += 0.12
	elif PC.selected_rewards.has("SR48"): extra_mult += 0.10
	elif PC.selected_rewards.has("R48"): extra_mult += 0.08
	# 驱迫（R49系列）：敌人数量加成
	if PC.selected_rewards.has("SSR49"): extra_mult += 0.15
	elif PC.selected_rewards.has("SR49"): extra_mult += 0.10
	elif PC.selected_rewards.has("R49"): extra_mult += 0.08
	# 狂怒（R50系列）：敌人数量加成
	if PC.selected_rewards.has("SSR50"): extra_mult += 0.12
	elif PC.selected_rewards.has("SR50"): extra_mult += 0.10
	elif PC.selected_rewards.has("R50"): extra_mult += 0.08
	# 兵临（R53系列）：敌人数量加成
	if PC.selected_rewards.has("SSR53"): extra_mult += 0.12
	elif PC.selected_rewards.has("SR53"): extra_mult += 0.08
	elif PC.selected_rewards.has("R53"): extra_mult += 0.05

	max_monster_limit = int(base_limit * (1.0 + extra_mult))

# ============== 动态平衡函数 ==============
## 获取当前容量占用率（0.0~1.0+）
func _get_capacity_ratio() -> float:
	if max_monster_limit <= 0:
		return 0.0
	return float(current_monster_count) / float(max_monster_limit)

## 计算出怪数量增量（30%时+150%，60%时+0%，线性衰减）
func _calculate_spawn_count_multiplier() -> float:
	var ratio = _get_capacity_ratio()
	var base_mult = 1.0
	if ratio >= DYNAMIC_BALANCE_SPAWN_HIGH_THRESHOLD:
		base_mult = 1.0 # 60%及以上，无增量
	elif ratio <= DYNAMIC_BALANCE_SPAWN_LOW_THRESHOLD:
		base_mult = 1.0 + DYNAMIC_BALANCE_SPAWN_MAX_BONUS # 低阈值及以下，+最大增量
	else:
		# 线性衰减：从低阈值的+最大增量衰减到60%的+0%
		var t = (ratio - DYNAMIC_BALANCE_SPAWN_LOW_THRESHOLD) / (DYNAMIC_BALANCE_SPAWN_HIGH_THRESHOLD - DYNAMIC_BALANCE_SPAWN_LOW_THRESHOLD)
		base_mult = 1.0 + DYNAMIC_BALANCE_SPAWN_MAX_BONUS * (1.0 - t)

	var extra_mult = 0.0
	if PC.selected_rewards.has("UR39"): extra_mult += 0.09
	elif PC.selected_rewards.has("SSR39"): extra_mult += 0.07
	elif PC.selected_rewards.has("SR39"): extra_mult += 0.06
	elif PC.selected_rewards.has("R39"): extra_mult += 0.05
	# 洪流（R48系列）：敌人数量加成
	if PC.selected_rewards.has("SSR48"): extra_mult += 0.12
	elif PC.selected_rewards.has("SR48"): extra_mult += 0.10
	elif PC.selected_rewards.has("R48"): extra_mult += 0.08
	# 驱迫（R49系列）：敌人数量加成
	if PC.selected_rewards.has("SSR49"): extra_mult += 0.15
	elif PC.selected_rewards.has("SR49"): extra_mult += 0.10
	elif PC.selected_rewards.has("R49"): extra_mult += 0.08
	# 狂怒（R50系列）：敌人数量加成
	if PC.selected_rewards.has("SSR50"): extra_mult += 0.12
	elif PC.selected_rewards.has("SR50"): extra_mult += 0.10
	elif PC.selected_rewards.has("R50"): extra_mult += 0.08
	# 兵临（R53系列）：敌人数量加成
	if PC.selected_rewards.has("SSR53"): extra_mult += 0.12
	elif PC.selected_rewards.has("SR53"): extra_mult += 0.08
	elif PC.selected_rewards.has("R53"): extra_mult += 0.05

	return base_mult + extra_mult

## 计算HP削减比例（70%时-10%，100%时-30%，线性增加）
func _calculate_hp_reduction() -> float:
	var ratio = _get_capacity_ratio()
	if ratio < DYNAMIC_BALANCE_HP_LOW_THRESHOLD:
		return 0.0 # 70%以下无削弱
	if ratio >= DYNAMIC_BALANCE_HP_HIGH_THRESHOLD:
		return DYNAMIC_BALANCE_HP_MAX_REDUCTION # 100%时最大削减
	# 线性增加：从70%的-10%增加到100%的最大削减
	var t = (ratio - DYNAMIC_BALANCE_HP_LOW_THRESHOLD) / (DYNAMIC_BALANCE_HP_HIGH_THRESHOLD - DYNAMIC_BALANCE_HP_LOW_THRESHOLD)
	return DYNAMIC_BALANCE_HP_MIN_REDUCTION + (DYNAMIC_BALANCE_HP_MAX_REDUCTION - DYNAMIC_BALANCE_HP_MIN_REDUCTION) * t

## 应用动态平衡HP削减到怪物
func _apply_dynamic_hp_reduction(monster_node: Node) -> void:
	if current_wave_hp_reduction <= 0.0:
		return
	var reduction_multiplier = 1.0 - current_wave_hp_reduction
	monster_node.hp *= reduction_multiplier
	monster_node.hpMax *= reduction_multiplier

## 应用120秒后的怪物速度加成
func _apply_late_game_speed_bonus(monster_node: Node) -> void:
	if late_game_speed_bonus <= 0.0:
		return
	monster_node.speed *= (1.0 + late_game_speed_bonus)


func _should_force_low_population_wave() -> bool:
	if boss_event_triggered or monster_spawn_timer == null or not is_instance_valid(monster_spawn_timer):
		return false
	if current_monster_count <= 0:
		return true
	# 后期（180秒后）：怪数量<低人口比例容量时立即补怪
	if PC.real_time >= LATE_GAME_TIME_THRESHOLD:
		var late_threshold: int = max(1, int(ceil(float(max_monster_limit) * LATE_GAME_LOW_POPULATION_RATIO)))
		if current_monster_count <= late_threshold:
			return true
	var low_population_threshold: int = max(1, int(floor(float(max_monster_limit) * DYNAMIC_BALANCE_SPAWN_LOW_THRESHOLD)))
	return current_monster_count <= low_population_threshold and monster_spawn_timer.time_left > LOW_POPULATION_FORCE_WAVE_MIN_TIME_LEFT


func _on_monster_defeated():
	current_monster_count -= 1
	# 确保计数器不会变为负数
	current_monster_count = max(0, current_monster_count)
	if _should_force_low_population_wave():
		monster_spawn_timer.stop()
		call_deferred("_spawn_wave")

## 尝试将怪物升级为精英怪（2%概率）
func _try_make_elite(monster_node: Node) -> void:
	if randf() > ELITE_SPAWN_CHANCE:
		return # 未触发精英怪
	if elite_alive >= ELITE_MAX:
		return # 精英怪已达上限

	# 标记为精英怪
	monster_node.is_elite = true
	monster_node.add_to_group("elite")
	elite_alive += 1
	monster_node.connect("tree_exiting", func(): elite_alive = max(0, elite_alive - 1))

	# 体型增加30%
	monster_node.scale *= ELITE_SCALE_MULTIPLIER

	# 攻击提升20%
	monster_node.atk *= ELITE_ATK_MULTIPLIER

	# 血量提升800%
	monster_node.hp *= ELITE_HP_MULTIPLIER
	monster_node.hpMax *= ELITE_HP_MULTIPLIER

	# 经验4倍
	monster_node.get_exp = int(monster_node.get_exp * ELITE_EXP_MULTIPLIER)

	# 真气5倍
	monster_node.get_point = int(monster_node.get_point * ELITE_POINT_MULTIPLIER)

	# 掉落率15倍
	monster_node.drop_rate_multiplier = ELITE_DROP_MULTIPLIER

	# 添加精英视觉效果
	_apply_elite_visual(monster_node)

## 应用精英怪视觉效果（红色滤镜+描边）
func _apply_elite_visual(monster_node: Node) -> void:
	# 获取精灵节点并添加红色色调
	var sprite = monster_node.get_node_or_null("AnimatedSprite2D")
	if sprite:
		# 修改滤镜颜色为红色，透明度0.3
		sprite.modulate = Color(1.0, 0.92, 0.92, 1)

		# 添加4像素红色描边
		var shader_code = """
shader_type canvas_item;
uniform vec4 line_color : source_color = vec4(1, 0, 0, 1);
uniform float line_thickness : hint_range(0, 10) = 0.75;

void fragment() {
	vec2 size = TEXTURE_PIXEL_SIZE * line_thickness;
	
	float outline = texture(TEXTURE, UV + vec2(-size.x, 0)).a;
	outline += texture(TEXTURE, UV + vec2(0, size.y)).a;
	outline += texture(TEXTURE, UV + vec2(size.x, 0)).a;
	outline += texture(TEXTURE, UV + vec2(0, -size.y)).a;
	outline += texture(TEXTURE, UV + vec2(-size.x, size.y)).a;
	outline += texture(TEXTURE, UV + vec2(size.x, size.y)).a;
	outline += texture(TEXTURE, UV + vec2(-size.x, -size.y)).a;
	outline += texture(TEXTURE, UV + vec2(size.x, -size.y)).a;
	outline = min(outline, 1.0);
	
	vec4 tex_color = texture(TEXTURE, UV);
	vec4 body_color = tex_color * COLOR;
	COLOR = mix(body_color, line_color, outline - tex_color.a);
}
"""
		var shader_material = ShaderMaterial.new()
		var shader = Shader.new()
		shader.code = shader_code
		shader_material.shader = shader
		sprite.material = shader_material

	# 给怪物添加精英怪标记
	monster_node.set_meta("is_elite_monster", true)

# ============== 金团团生成 ==============
## 每波怪生成时尝试刷新金团团（基础 0.3% 概率，受修习树加成影响）
func _try_spawn_gold_ball() -> void:
	if boss_event_triggered:
		return
	if not Global.study_gold_ball_unlocked:
		return
	# 实际概率 = 基础 0.3% × (1 + 金团团概率加成)
	var chance = GOLD_BALL_BASE_CHANCE * (1.0 + Global.study_gold_ball_chance_bonus)
	if randf() > chance:
		return
	# 延迟加载场景（首次生成时加载）
	if _gold_ball_scene == null:
		_gold_ball_scene = load("res://Scenes/moster/gold_ball.tscn")
	if _gold_ball_scene == null:
		return
	var gold_ball_node = _gold_ball_scene.instantiate()
	gold_ball_node.move_direction = 2 # 朝向角色移动
	var spawn_edge = randi_range(0, 3)
	var spawn_position = Vector2.ZERO
	match spawn_edge:
		0: spawn_position = Vector2(randf_range(-500, 500), -30)
		1: spawn_position = Vector2(randf_range(-500, 500), 550)
		2: spawn_position = Vector2(-550, randf_range(50, 450))
		3: spawn_position = Vector2(550, randf_range(50, 450))
	gold_ball_node.position = spawn_position
	get_tree().current_scene.add_child(gold_ball_node)
	gold_ball_node.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(gold_ball_node, "modulate:a", 1.0, 0.7)
	current_monster_count += 1
	gold_ball_node.connect("tree_exiting", Callable(self , "_on_monster_defeated"))
	print("[GoldBall] 金团团已生成！")

# ============== 游戏结果 ==============
func show_game_over():
	PC.is_game_over = true
	Global.total_defeat_count += 1
	Global.save_game()
	EmblemManager.clear_all_emblems()
	DpsManager.stop_dps_counter()
	layer_ui.show_game_over()
	var player = get_node("Player")
	player.stop_all_skill_cooldowns()
	layer_ui.stop_all_skill_cooldowns()
	await get_tree().create_timer(2).timeout
	if not is_inside_tree():
		return
	SceneChange.change_scene("res://Scenes/main_town.tscn", true)

func _on_boss_defeated(_get_point: int, boss_position: Vector2):
	if not PC.is_game_over:
		# 标记游戏结束状态，防止后续逻辑触发
		PC.is_game_over = true
		
		# 清除所有纹章效果
		EmblemManager.clear_all_emblems()
		
		# 停止DPS计数器
		DpsManager.stop_dps_counter()
		
		$Victory.play()
		var player = get_node("Player")
		player.enter_victory_state()
		player.stop_all_skill_cooldowns()
		layer_ui.stop_all_skill_cooldowns()
		var item_control = get_node("ItemControl")
		item_control.start_victory_collect(player, 225.0, 3.0)
		
		# 如果是桃林关卡，标记已击败boss
		if STAGE_ID == "peach_grove":
			Global.has_defeated_peach_grove_boss = true
		
		Global.mark_stage_difficulty_cleared(STAGE_ID, Global.current_stage_difficulty)
		# 角色解锁：首次通关ruin解锁诺姆，首次通关cave解锁坎塞尔
		if STAGE_ID == "ruin" and not Global.unlock_noam:
			Global.unlock_noam = true
			print("[HeroUnlock] 首次通关ruin，解锁诺姆及疗愈技能")
		if STAGE_ID == "cave" and not Global.unlock_kansel:
			Global.unlock_kansel = true
			print("[HeroUnlock] 首次通关cave，解锁坎塞尔及炽炎技能")
		Global.add_shop_battle_refresh(1)
		await player.play_boss_defeat_camera_focus(boss_position)

		await layer_ui.play_victory_sequence()

		# 等待掉落物全部拾取后再保存，确保背包数据完整
		if not is_inside_tree():
			return
		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree():
			return
		Global.save_game()
		Global.in_menu = true
		SceneChange.change_scene("res://Scenes/main_town.tscn", true)

func _on_monster_mechanism_gained(mechanism_value: int) -> void:
	map_mechanism_num += mechanism_value

# ============== UI回调代理 ==============
func _on_attr_button_focus_entered() -> void:
	layer_ui.show_attr_label()

func _on_attr_button_focus_exited() -> void:
	layer_ui.hide_attr_label()

func _on_skill_icon_1_mouse_entered() -> void:
	layer_ui.show_skill1_label($Player)

func _on_skill_icon_1_mouse_exited() -> void:
	layer_ui.hide_skill1_label()

func _on_refresh_button_pressed() -> void:
	layer_ui.handle_refresh_button(1)

func _on_refresh_button_2_pressed() -> void:
	layer_ui.handle_refresh_button(2)

func _on_refresh_button_3_pressed() -> void:
	layer_ui.handle_refresh_button(3)

# 纹章鼠标事件
func _on_emblem_1_mouse_entered() -> void:
	layer_ui.show_emblem_detail(1)

func _on_emblem_1_mouse_exited() -> void:
	layer_ui.hide_emblem_detail(1)

func _on_emblem_2_mouse_entered() -> void:
	layer_ui.show_emblem_detail(2)

func _on_emblem_2_mouse_exited() -> void:
	layer_ui.hide_emblem_detail(2)

func _on_emblem_3_mouse_entered() -> void:
	layer_ui.show_emblem_detail(3)

func _on_emblem_3_mouse_exited() -> void:
	layer_ui.hide_emblem_detail(3)

func _on_emblem_4_mouse_entered() -> void:
	layer_ui.show_emblem_detail(4)

func _on_emblem_4_mouse_exited() -> void:
	layer_ui.hide_emblem_detail(4)

func _on_emblem_5_mouse_entered() -> void:
	layer_ui.show_emblem_detail(5)

func _on_emblem_5_mouse_exited() -> void:
	layer_ui.hide_emblem_detail(5)

func _on_emblem_6_mouse_entered() -> void:
	layer_ui.show_emblem_detail(6)

func _on_emblem_6_mouse_exited() -> void:
	layer_ui.hide_emblem_detail(6)

func _on_emblem_7_mouse_entered() -> void:
	layer_ui.show_emblem_detail(7)

func _on_emblem_7_mouse_exited() -> void:
	layer_ui.hide_emblem_detail(7)

func _on_emblem_8_mouse_entered() -> void:
	layer_ui.show_emblem_detail(8)

func _on_emblem_8_mouse_exited() -> void:
	layer_ui.hide_emblem_detail(8)
