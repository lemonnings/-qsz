extends Node2D

# ============== 通用导出变量 ==============
@export var boss_robot_scene: PackedScene
@export var warning_scene: Control
@export var monster_spawn_timer: Timer
@export var point: int
@export var layer_ui: BattleCanvasLayer
var spirit: int = 0
var spirit_raw: float = 0.0

# ============== 所有关卡完全一致的常数 ==============
const MONSTER_LIMIT_INCREASE_WAVE_STEP: int = 2
const INITIAL_WAVE_SPAWN_COUNT: int = 4
const MAX_WAVE_SPAWN_COUNT: int = 21
const WAVE_SPAWNS_PER_FRAME: int = 1
const EARLY_WAVE_LIMIT: int = 10
const NORMAL_SPIRIT_GAIN: int = 10
const SPECIAL_SPIRIT_GAIN: int = 12
const ELITE_SPIRIT_MULTIPLIER: int = 5
const SPIRIT_GAIN_PER_MINUTE_RATE: float = 0.10
const SHALLOW_STAGE_DURATION_SECONDS: float = 360.0
const DEEP_STAGE_DURATION_SECONDS: float = 420.0
const CORE_STAGE_DURATION_SECONDS: float = 480.0
const POETRY_STAGE_DURATION_SECONDS: float = 1.0
const QI_VORTEX_SCENE: PackedScene = preload("res://Scenes/level/qi_vortex.tscn")
const BATTLE_CANVAS_LAYER_MOBILE_SCENE: PackedScene = preload("res://Scenes/global/battle_canvas_layer_mobile.tscn")
const QI_VORTEX_SHOP_MANAGER_SCRIPT: Script = preload("res://Script/system/qi_vortex_shop_manager.gd")
const QI_VORTEX_TUTORIAL_SCENE: PackedScene = preload("res://Scenes/town/qi_vortex_tutorial.tscn")
const QI_VORTEX_SHALLOW_TIMES: Array[float] = [75.0, 150.0, 225.0, 290.0, 340.0]
const QI_VORTEX_DEEP_TIMES: Array[float] = [75.0, 140.0, 205.0, 270.0, 335.0, 400.0]
const QI_VORTEX_CORE_TIMES: Array[float] = [75.0, 135.0, 195.0, 255.0, 315.0, 375.0, 435.0]
const QI_VORTEX_CORE_REDUCED_TIMES: Array[float] = [75.0, 145.0, 220.0, 275.0, 370.0, 440.0]
const QI_VORTEX_SPAWN_MARGIN: float = 48.0
const QI_VORTEX_VIEW_MARGIN: float = 64.0
const QI_VORTEX_MASK_ALPHA: float = 0.35
const QI_VORTEX_SPAWN_FLASH_SECONDS: float = 0.75
const QI_VORTEX_SPAWN_FLASH_COLOR: Color = Color(0.55, 0.85, 1.0, 0.5)
const QI_VORTEX_INDICATOR_MARGIN: float = 56.0
const QI_VORTEX_INDICATOR_SCALE: float = 8.0
const QI_VORTEX_INDICATOR_ALPHA: float = 0.7
const QI_VORTEX_INDICATOR_TEXTURE: Texture2D = preload("res://AssetBundle/Sprites/Sprite sheets/qi_tips.png")
const MOBILE_MONSTER_HP_MULTIPLIER: float = 0.9
const MOBILE_MONSTER_ATK_MULTIPLIER: float = 0.85
const MOBILE_MONSTER_SPEED_MULTIPLIER: float = 0.95
const MOBILE_BOSS_ATK_MULTIPLIER: float = 0.9
const GOLD_BALL_SPAWN_FLASH_SECONDS: float = 0.55
const GOLD_BALL_SPAWN_FLASH_COLOR: Color = Color(1.0, 0.82, 0.28, 0.28)
const CORE_MISSILE_SCENE: PackedScene = preload("res://Scenes/moster/frog_attack.tscn")
const CORE_MISSILE_MIN_INTERVAL: float = 2.0
const CORE_MISSILE_MAX_INTERVAL: float = 6.0
const CORE_MISSILE_MIN_COUNT: int = 2
const CORE_MISSILE_MAX_COUNT: int = 4
const CORE_MISSILE_OFFSCREEN_MARGIN: float = 96.0
const CORE_MISSILE_SPEED: float = 72.8 # 在104基础上再降低30%
const CORE_MISSILE_RANGE: float = 3000.0
const CORE_MISSILE_DAMAGE_MULTIPLIER: float = 0.67
const CORRUPTED_ELITE_CONTROLLER_SCRIPT: Script = preload("res://Script/system/corrupted_elite_controller.gd")
const CORRUPTED_ELITE_INTERVAL: float = 50.0
const CORRUPTED_ELITE_SCALE_EXTRA: float = 1.15
const CORRUPTED_ELITE_ATK_EXTRA: float = 1.2
const CORRUPTED_ELITE_HP_EXTRA: float = 5.0
const CORRUPTED_ELITE_REWARD_EXTRA: float = 3.0
const CORRUPTED_ELITE_GUARANTEED_DROP_ID: String = "item_102"
const CORRUPTED_ELITE_OUTLINE_COLOR: Color = Color(0.72, 0.1, 1.0, 1.0)
const CORRUPTED_ELITE_OUTLINE_THICKNESS: float = 1.65
const CORRUPTED_ELITE_SPRITE_MODULATE: Color = Color(1.0, 0.86, 1.0, 1.0)
const CORRUPTED_ELITE_SPAWN_MARGIN: float = 72.0
const PLAYER_SPAWN_SAFE_RADIUS: float = 300.0
const PLAYER_SPAWN_SAFE_RADIUS_SQ: float = PLAYER_SPAWN_SAFE_RADIUS * PLAYER_SPAWN_SAFE_RADIUS
const PLAYER_SPAWN_SAFE_REROLL_ATTEMPTS: int = 10

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
const POETRY_WEAPON_DAMAGE_PER_LEVEL: float = 0.06

# 动态平衡（所有关卡一致的常数）
const DYNAMIC_BALANCE_SPAWN_HIGH_THRESHOLD: float = 0.6 # 出怪增量高阈值（60%时0%增量）
const DYNAMIC_BALANCE_HP_LOW_THRESHOLD: float = 0.7 # HP削减低阈值（70%开始削弱）
const DYNAMIC_BALANCE_HP_HIGH_THRESHOLD: float = 1.0 # HP削减高阈值（100%最大削弱）
const DYNAMIC_BALANCE_HP_MIN_REDUCTION: float = 0.1 # 最小HP削减10%

# ============== 各关卡不同的配置值（var，子类可覆盖）==============
var STAGE_ID: String = ""
var SPAWN_INTERVAL_SECONDS: float = 5.0
var INITIAL_MONSTER_LIMIT: int = 50
var WAVE_SPAWN_INCREASE_STEP: int = 6
var MAX_MONSTER_CAP: int = 84
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
var _wave_spawning: bool = false

var boss_event_triggered: bool = false
var _boss_fight_active: bool = false

var other_type_alive: int = 0 # 非基础类型怪物当前存活数
var elite_alive: int = 0 # 当前存活精英怪数量

var current_wave_hp_reduction: float = 0.0 # 当前波的HP削减比例
var current_spawn_interval: float = 0.0 # 当前出怪间隔（运行时由SPAWN_INTERVAL_SECONDS初始化）
var late_game_speed_bonus: float = 0.0 # 120秒后累积的speed加成（最大0.3=30%）

# 怪物生成池（子类初始化）
var stage_spawn_pool: Array[Dictionary] = []

# 金团团场景（修习树特殊篇解锁后可用）
const GOLD_BALL_BASE_CHANCE: float = 0.015 # 每波 1.5% 基础概率
var _gold_ball_scene: PackedScene = null

# 战斗动态对话系统
var battle_chat: BattleChat = null
var qi_vortex_spawn_times: Array[float] = []
var qi_vortex_spawn_index: int = 0
var active_qi_vortex: Node2D = null
var qi_vortex_tutorial_pending: bool = false

func _get_player_spawn_safe_position(candidate: Vector2, reroll_callable: Callable = Callable()) -> Vector2:
	var player_pos: Vector2 = _get_current_player_position()
	if player_pos == Vector2.INF:
		return candidate
	var resolved: Vector2 = candidate
	if reroll_callable.is_valid():
		for i in range(PLAYER_SPAWN_SAFE_REROLL_ATTEMPTS):
			if resolved.distance_squared_to(player_pos) >= PLAYER_SPAWN_SAFE_RADIUS_SQ:
				return resolved
			var next_candidate: Variant = reroll_callable.call()
			if next_candidate is Vector2:
				resolved = next_candidate
	if resolved.distance_squared_to(player_pos) >= PLAYER_SPAWN_SAFE_RADIUS_SQ:
		return resolved
	var from_player: Vector2 = resolved - player_pos
	if from_player.length_squared() < 0.0001:
		from_player = Vector2.RIGHT
	return player_pos + from_player.normalized() * PLAYER_SPAWN_SAFE_RADIUS

func _get_current_player_position() -> Vector2:
	if PC.player_instance != null and is_instance_valid(PC.player_instance):
		return PC.player_instance.global_position
	var player_node := get_tree().get_first_node_in_group("player")
	if player_node is Node2D:
		return (player_node as Node2D).global_position
	return Vector2.INF
var qi_vortex_shop_manager: Node = null
var qi_vortex_mask: ColorRect = null
var qi_vortex_indicator: Sprite2D = null
var _qi_vortex_mask_tween: Tween = null
var battle_lost_hp: float = 0.0
var _core_missile_elapsed: float = 0.0
var _core_next_missile_time: float = 0.0
var _corrupted_elite_timer: Timer = null

# ============== 初始化 ==============
func _ready() -> void:
	_setup_stage_config()
	Global.victory_collecting = false
	Global.stage_boss_fight_time = 0.0
	_boss_fight_active = false
	if Global.current_stage_difficulty == Global.STAGE_DIFFICULTY_CORE:
		Global.current_core_depth = Global.clamp_core_depth(Global.current_core_depth)
	else:
		Global.current_core_depth = Global.CORE_DEPTH_MIN
	Global.corrupted_elite_enabled = Global.is_corrupted_elite_enabled()
	_schedule_next_core_missile()
	spirit = 0
	spirit_raw = 0.0
	PC.sync_spirit(spirit_raw)
	max_monster_limit = INITIAL_MONSTER_LIMIT
	current_spawn_interval = SPAWN_INTERVAL_SECONDS

	PC.player_instance = $Player
	_setup_battle_canvas_layer_for_device()
	Global.emit_signal("reset_camera")

	map_mechanism_num = 0
	map_mechanism_num_max = _get_stage_duration_seconds()

	DpsManager.reset_dps_counter()
	Global.reset_dps_counter()
	battle_lost_hp = 0.0
	AchievementManager.record_stage_started()

	# 重置击杀计数
	GU.reset_kill_count()

	# 诗想难度：玩家直接50级 + Boss基于第8分钟数据
	if Global.current_stage_difficulty == Global.STAGE_DIFFICULTY_POETRY:
		_apply_poetry_init()
		if $Player.has_method("_update_start_weapon_timers"):
			$Player.call("_update_start_weapon_timers")

	# 连接关卡特定信号
	Global.connect("boss_defeated", Callable(self , "_on_boss_defeated"))
	var player_damage_callable = Callable(self, "_on_player_damage_for_summary")
	if not Global.is_connected("player_hit", player_damage_callable):
		Global.connect("player_hit", player_damage_callable)
	if not Global.is_connected("player_hit_ignore_invincible", player_damage_callable):
		Global.connect("player_hit_ignore_invincible", player_damage_callable)

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
	_setup_corrupted_elite_timer()

	# 初始化技能冷却显示
	layer_ui.update_skill_cooldowns($Player)
	# 诗想难度不刷第一波怪
	if Global.current_stage_difficulty != Global.STAGE_DIFFICULTY_POETRY:
		_spawn_wave()

	# 初始化战斗动态对话系统
	battle_chat = BattleChat.new()
	add_child(battle_chat)
	battle_chat.initialize(layer_ui.teammate_dialogue_mgr)
	_setup_qi_vortex_system()

# ============== 虚方法（子类覆盖）==============
func _setup_stage_config() -> void:
	pass # 子类覆盖，设置 STAGE_ID 和各种配置值

func _setup_battle_canvas_layer_for_device() -> void:
	if not Global.is_mobile_input_mode():
		return
	var current_layer := get_node_or_null("CanvasLayer") as BattleCanvasLayer
	var mobile_layer := BATTLE_CANVAS_LAYER_MOBILE_SCENE.instantiate() as BattleCanvasLayer
	if mobile_layer == null:
		return
	mobile_layer.name = "CanvasLayer"
	var insert_index := get_child_count()
	if current_layer != null:
		insert_index = current_layer.get_index()
		remove_child(current_layer)
		current_layer.queue_free()
	add_child(mobile_layer)
	move_child(mobile_layer, insert_index)
	layer_ui = mobile_layer

func _get_stage_duration_seconds() -> float:
	var difficulty_id := Global.validate_stage_difficulty_id(Global.current_stage_difficulty)
	if difficulty_id == Global.STAGE_DIFFICULTY_DEEP:
		return DEEP_STAGE_DURATION_SECONDS
	if difficulty_id == Global.STAGE_DIFFICULTY_CORE:
		return CORE_STAGE_DURATION_SECONDS
	if difficulty_id == Global.STAGE_DIFFICULTY_POETRY:
		return POETRY_STAGE_DURATION_SECONDS
	return SHALLOW_STAGE_DURATION_SECONDS

func _setup_qi_vortex_system() -> void:
	qi_vortex_spawn_times = _get_qi_vortex_spawn_times()
	qi_vortex_spawn_index = 0
	qi_vortex_shop_manager = QI_VORTEX_SHOP_MANAGER_SCRIPT.new()
	add_child(qi_vortex_shop_manager)
	if qi_vortex_shop_manager.has_signal("opened"):
		qi_vortex_shop_manager.connect("opened", Callable(self, "_show_qi_vortex_shop_mask"))
	if qi_vortex_shop_manager.has_signal("closed"):
		qi_vortex_shop_manager.connect("closed", Callable(self, "_hide_qi_vortex_shop_mask"))

func _get_qi_vortex_spawn_times() -> Array[float]:
	var difficulty_id := Global.validate_stage_difficulty_id(Global.current_stage_difficulty)
	if difficulty_id == Global.STAGE_DIFFICULTY_DEEP:
		return QI_VORTEX_DEEP_TIMES.duplicate()
	if difficulty_id == Global.STAGE_DIFFICULTY_CORE:
		if Global.should_use_reduced_qi_vortex_times():
			return QI_VORTEX_CORE_REDUCED_TIMES.duplicate()
		return QI_VORTEX_CORE_TIMES.duplicate()
	if difficulty_id == Global.STAGE_DIFFICULTY_POETRY:
		return []
	return QI_VORTEX_SHALLOW_TIMES.duplicate()

# ============== 诗想难度初始化 ===============
func _apply_poetry_init() -> void:
	# 1. 执行49次属性成长（不含奖励选择），使玩家达到50级属性
	for i in range(49):
		_poetry_stat_growth()
	PC.pc_lv = 50
	PC.pc_hp = PC.pc_max_hp
	
	# 2. 设置游戏时间为第8分钟(480秒)，使怪物/Boss基于该时刻的数值
	PC.real_time = Global.POETRY_BATTLE_START_TIME_SECONDS
	PC.current_time = Global.POETRY_BATTLE_START_TIME_SECONDS
	
	# 3. 重新应用诗想备战配置（reset_player_attr会清空selected_rewards，此处恢复）
	_apply_poetry_loadout()
	if layer_ui and layer_ui.has_method("refresh_faze_ui"):
		layer_ui.refresh_faze_ui()
	
	# 4. 设置诗想难度下的DPS计算覆盖值
	Global.poetry_dps_override = Global.get_poetry_boss_expected_output()
	
	# 5. 直接出Boss：机制上限设为5，进图即触发
	map_mechanism_num_max = POETRY_STAGE_DURATION_SECONDS
	map_mechanism_num = map_mechanism_num_max
	
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
		_apply_poetry_weapon_damage_bonus(w12_id, 12)
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
			_apply_poetry_weapon_damage_bonus(w_id, 3)
			if i < adv3_ids.size() and adv3_ids[i] != "":
				_grant_poetry_advancement(adv3_ids[i])

func _grant_poetry_weapon_level(w_id: String, target_level: int):
	var base_func = "reward_" + w_id
	if LvUp.has_method(base_func):
		LvUp.call(base_func)
	var upgrade_func = "reward_R" + w_id
	for i in range(target_level - 1):
		if LvUp.has_method(upgrade_func):
			LvUp.call(upgrade_func)

func _apply_poetry_weapon_damage_bonus(w_id: String, level: int) -> void:
	var bonus := float(level) * POETRY_WEAPON_DAMAGE_PER_LEVEL
	match _normalize_poetry_weapon_id(w_id):
		"SwordQi":
			PC.main_skill_swordQi_damage += bonus
		"Branch":
			PC.main_skill_branch_damage += bonus
		"Moyan":
			PC.main_skill_moyan_damage += bonus
		"RingFire":
			PC.main_skill_ringFire_damage += bonus
		"Riyan":
			PC.main_skill_riyan_damage += bonus
		"Thunder":
			PC.main_skill_thunder_damage += bonus
		"Bloodwave":
			BloodWave.main_skill_bloodwave_damage += bonus
		"BloodBoardSword":
			PC.main_skill_bloodboardsword_damage += bonus
		"Ice":
			IceFlower.main_skill_ice_damage += bonus
		"ThunderBreak":
			PC.thunder_break_final_damage_multi += bonus
		"LightBullet":
			PC.light_bullet_final_damage_multi += bonus
		"Water":
			PC.water_final_damage_multi += bonus
		"Qiankun":
			Qiankun.qiankun_final_damage_multi += bonus
		"Xuanwu":
			Xuanwu.xuanwu_final_damage_multi += bonus
		"Xunfeng":
			Xunfeng.xunfeng_final_damage_multi += bonus
		"Genshan":
			Genshan.genshan_final_damage_multi += bonus
		"Duize":
			Duize.duize_final_damage_multi += bonus
		"HolyLight":
			HolyLight.main_skill_holylight_damage += bonus
		"DragonWind":
			DragonWind.dragonwind_final_damage_multi += bonus
			PC.main_skill_dragonwind_damage = DragonWind.dragonwind_final_damage_multi
		"Qigong":
			Qigong.main_skill_qigong_damage += bonus

func _normalize_poetry_weapon_id(w_id: String) -> String:
	match str(w_id):
		"Swordqi":
			return "SwordQi"
		"Ringfire":
			return "RingFire"
		"Bloodboardsword":
			return "BloodBoardSword"
		"Thunderbreak":
			return "ThunderBreak"
		"Lightbullet":
			return "LightBullet"
		"Holylight":
			return "HolyLight"
		"Dragonwind":
			return "DragonWind"
		_:
			return str(w_id)

func _grant_poetry_advancement(adv_id: String):
	var adv_func = "reward_" + adv_id
	if LvUp.has_method(adv_func):
		LvUp.call(adv_func)

## 诗想难度单次属性成长（模拟 global_level_up 中的纯属性部分）
func _poetry_stat_growth() -> void:
	PC.pc_atk += LvUp.LEVEL_UP_BASE_ATK_FLAT_BONUS
	PC.pc_start_atk += LvUp.LEVEL_UP_BASE_ATK_FLAT_BONUS
	var atk_growth_multiplier := 1.0 + LvUp.LEVEL_UP_BASE_ATK_RATE * (1.0 + PC.lingwu_atk_bonus)
	PC.pc_atk = int(PC.pc_atk * atk_growth_multiplier)
	PC.pc_start_atk = int(PC.pc_start_atk * atk_growth_multiplier)
	PC.pc_max_hp += 20
	PC.pc_start_max_hp += 20
	PC.pc_hp += 20
	var lv_hp_bonus = int(PC.pc_start_max_hp * 0.02)
	PC.pc_max_hp += lv_hp_bonus
	PC.pc_start_max_hp += lv_hp_bonus

func _spawn_wave() -> void:
	pass # 子类覆盖，实现怪物波生成

func _begin_wave_spawn() -> bool:
	if boss_event_triggered or _wave_spawning:
		return false
	var current_frame = Engine.get_process_frames()
	if current_frame == last_wave_spawn_frame:
		return false
	last_wave_spawn_frame = current_frame
	_wave_spawning = true
	if monster_spawn_timer != null and is_instance_valid(monster_spawn_timer):
		monster_spawn_timer.stop()
	return true

func _finish_wave_spawn(restart_timer: bool = true) -> void:
	_wave_spawning = false
	if not restart_timer or boss_event_triggered:
		return
	if monster_spawn_timer != null and is_instance_valid(monster_spawn_timer):
		monster_spawn_timer.start()

func _choose_individual_type(wave_other_type_counts: Dictionary) -> String:
	var available_entries: Array[Dictionary] = []
	var total_weight = 0
	for entry in stage_spawn_pool:
		var entry_type = entry["type"]
		if spawn_count <= EARLY_WAVE_LIMIT and entry["blocked_early"]:
			continue
		if not _can_choose_spawn_entry(entry, wave_other_type_counts):
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

func _can_choose_spawn_entry(_entry: Dictionary, _wave_other_type_counts: Dictionary) -> bool:
	return true

func _get_boss_position() -> Vector2:
	return Vector2(-370, randf_range(185, 259)) # 默认值，子类可覆盖

func _get_boss_camera_zoom() -> Vector2:
	return Vector2(3.5, 3.5) # 默认Boss战缩放，子类可覆盖

# ============== 每帧更新 ==============
func _process(_delta: float) -> void:
	# 更新分数显示
	layer_ui.update_score_display(point, spirit)

	# 检查并更新技能图标
	layer_ui.check_and_update_skill_icons($Player)

	# 更新DPS显示
	layer_ui.update_dps_display()

	_update_qi_vortex_indicator()

func _physics_process(_delta: float) -> void:
	# 机关进度只由关卡经过时间决定，击杀不再推进进度条。
	if not boss_event_triggered:
		map_mechanism_num = min(map_mechanism_num + _delta, map_mechanism_num_max)

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
		Global.stage_boss_fight_time = 0.0
		_trigger_boss_event()
		return

	PC.real_time += _delta
	if _boss_fight_active and Global.current_stage_difficulty != Global.STAGE_DIFFICULTY_POETRY and not PC.is_game_over:
		Global.stage_boss_fight_time += _delta
	_check_qi_vortex_spawn()
	_update_core_missile_attack(_delta)
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
	var required_exp := layer_ui.get_required_lv_up_value(PC.pc_lv)
	if PC.pc_exp >= required_exp:
		layer_ui.add_pending_level_up()
		PC.pc_exp = clamp(PC.pc_exp - required_exp, 0, layer_ui.get_required_lv_up_value(PC.pc_lv + 1))
		PC.pc_lv += 1
		if Global.current_stage_difficulty != Global.STAGE_DIFFICULTY_POETRY:
			LvUp.pre_apply_level_growth_for_pending_level()
		Global.emit_signal("player_lv_up")


# ============== Boss事件 ==============
func _trigger_boss_event() -> void:
	print("Boss event triggered!")
	monster_spawn_timer.stop()
	if _corrupted_elite_timer != null and is_instance_valid(_corrupted_elite_timer):
		_corrupted_elite_timer.stop()
	
	# Boss出现时强制恢复1倍速并隐藏加速按钮
	Global.reset_game_speed()
	layer_ui.set_speed_button_visible(false)

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
	_boss_fight_active = true
	Global.stage_boss_fight_time = 0.0
	_apply_mobile_boss_balance(boss_node)
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
		tween.tween_callback(Callable(enemy, "queue_free"))

func _push_teammate_dialogue_sequence(dialogues: Array[Dictionary]) -> void:
	var dialogue_mgr = layer_ui.teammate_dialogue_mgr
	if dialogue_mgr == null:
		return
	for line in dialogues:
		if not is_inside_tree():
			return
		var speaker := str(line.get("speaker", ""))
		var text := str(line.get("text", ""))
		if speaker.is_empty() or text.is_empty():
			continue
		dialogue_mgr.push_dialogue(speaker, text)
		var delay := 1.0 + text.length() * 0.15 + 0.7
		await _wait_unpaused(delay)

func _wait_unpaused(duration: float) -> void:
	var elapsed := 0.0
	while elapsed < duration:
		if not is_inside_tree():
			return
		await get_tree().process_frame
		if not get_tree().paused:
			elapsed += get_process_delta_time()


func _on_monster_spawn_timer_timeout() -> void:
	if boss_event_triggered:
		monster_spawn_timer.stop()
		return
	_try_spawn_gold_ball()
	_spawn_wave()
	# 120秒后：出怪间隔逐渐降低，怪物速度逐渐提升
	if PC.real_time >= LATE_GAME_RAMP_TIME:
		current_spawn_interval = max(LATE_GAME_MIN_INTERVAL, current_spawn_interval - LATE_GAME_INTERVAL_DECREASE)
		late_game_speed_bonus = min(LATE_GAME_MAX_SPEED_BONUS, late_game_speed_bonus + LATE_GAME_SPEED_INCREASE)
	monster_spawn_timer.wait_time = current_spawn_interval

func _setup_corrupted_elite_timer() -> void:
	if not Global.is_corrupted_elite_enabled():
		return
	if Global.current_stage_difficulty == Global.STAGE_DIFFICULTY_POETRY:
		return
	_corrupted_elite_timer = Timer.new()
	_corrupted_elite_timer.wait_time = CORRUPTED_ELITE_INTERVAL
	_corrupted_elite_timer.one_shot = false
	add_child(_corrupted_elite_timer)
	_corrupted_elite_timer.timeout.connect(_on_corrupted_elite_timer_timeout)
	_corrupted_elite_timer.start()

func _on_corrupted_elite_timer_timeout() -> void:
	if boss_event_triggered:
		if _corrupted_elite_timer != null and is_instance_valid(_corrupted_elite_timer):
			_corrupted_elite_timer.stop()
		return
	_spawn_corrupted_elite()

func _spawn_corrupted_elite() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var entry := _choose_corrupted_elite_spawn_entry()
	if entry.is_empty():
		return
	var spawn_type := str(entry.get("type", ""))
	var spawn_data := _get_corrupted_elite_spawn_data(spawn_type)
	if spawn_data.is_empty():
		return
	var monster_scene := spawn_data.get("scene", null) as PackedScene
	if monster_scene == null or _is_gold_ball_scene(monster_scene):
		return
	var monster_id := str(spawn_data.get("monster_id", _get_scene_monster_id(monster_scene, spawn_type)))
	if monster_id == "gold_ball":
		return
	var monster_node := monster_scene.instantiate() as MonsterBase
	if monster_node == null:
		return
	monster_node.global_position = _get_corrupted_elite_spawn_position()
	if monster_node.get("move_direction") != null:
		monster_node.set("move_direction", 2)
	get_tree().current_scene.add_child(monster_node)
	_mark_spirit_enemy_type(monster_node, spawn_data.get("is_special_enemy", not BASIC_TYPES.has(spawn_type)) == true)
	_make_corrupted_elite(monster_node, monster_id)
	_apply_dynamic_hp_reduction(monster_node)
	_apply_late_game_speed_bonus(monster_node)
	_apply_mobile_monster_balance(monster_node)
	monster_node.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(monster_node, "modulate:a", 1.0, 0.7)
	current_monster_count += 1
	monster_node.tree_exiting.connect(_on_monster_defeated)

func _choose_corrupted_elite_spawn_entry() -> Dictionary:
	var available_entries: Array[Dictionary] = []
	var total_weight := 0
	for entry in stage_spawn_pool:
		var spawn_type := str(entry.get("type", ""))
		if spawn_type.is_empty() or spawn_type == "gold_ball":
			continue
		if entry.get("never_elite", false) == true:
			continue
		var spawn_data := _get_corrupted_elite_spawn_data(spawn_type)
		if spawn_data.is_empty():
			continue
		var monster_scene := spawn_data.get("scene", null) as PackedScene
		if monster_scene == null or _is_gold_ball_scene(monster_scene):
			continue
		available_entries.append(entry)
		total_weight += int(entry.get("weight", 0))
	if available_entries.is_empty() or total_weight <= 0:
		return {}
	var random_weight := randi_range(1, total_weight)
	var accumulated_weight := 0
	for entry in available_entries:
		accumulated_weight += int(entry.get("weight", 0))
		if random_weight <= accumulated_weight:
			return entry
	return available_entries[available_entries.size() - 1]

func _get_corrupted_elite_spawn_data(_spawn_type: String) -> Dictionary:
	return {}

func _make_corrupted_elite(monster_node: MonsterBase, monster_id: String) -> void:
	monster_node.is_elite = true
	monster_node.add_to_group("elite")
	monster_node.add_to_group("core_corrupted_elite")
	monster_node.set_meta("is_elite_monster", true)
	monster_node.set_meta("is_corrupted_elite", true)
	monster_node.set_meta("corrupted_elite_monster_id", monster_id)
	monster_node.set_meta("corrupted_elite_guaranteed_drop_id", CORRUPTED_ELITE_GUARANTEED_DROP_ID)
	elite_alive += 1
	monster_node.tree_exiting.connect(Callable(self, "_on_elite_monster_tree_exiting"))

	monster_node.scale *= ELITE_SCALE_MULTIPLIER * CORRUPTED_ELITE_SCALE_EXTRA
	monster_node.set("atk", float(monster_node.get("atk")) * ELITE_ATK_MULTIPLIER * CORRUPTED_ELITE_ATK_EXTRA)
	monster_node.set("hp", float(monster_node.get("hp")) * ELITE_HP_MULTIPLIER * CORRUPTED_ELITE_HP_EXTRA)
	monster_node.set("hpMax", float(monster_node.get("hpMax")) * ELITE_HP_MULTIPLIER * CORRUPTED_ELITE_HP_EXTRA)
	monster_node.set("get_exp", int(monster_node.get("get_exp")) * int(ELITE_EXP_MULTIPLIER * CORRUPTED_ELITE_REWARD_EXTRA))
	monster_node.set("get_point", int(monster_node.get("get_point")) * int(ELITE_POINT_MULTIPLIER * CORRUPTED_ELITE_REWARD_EXTRA))
	monster_node.drop_rate_multiplier = ELITE_DROP_MULTIPLIER * CORRUPTED_ELITE_REWARD_EXTRA
	_apply_elite_visual(monster_node, CORRUPTED_ELITE_OUTLINE_COLOR, CORRUPTED_ELITE_OUTLINE_THICKNESS, CORRUPTED_ELITE_SPRITE_MODULATE)

	var controller := CorruptedEliteController.new()
	controller.setup(monster_node, monster_id)
	monster_node.add_child(controller)

func _get_corrupted_elite_spawn_position() -> Vector2:
	var player := $Player as Node2D
	var camera := (player.get_node_or_null("Camera2D") as Camera2D) if player != null else null
	var visible_rect := _get_camera_visible_rect(camera)
	if visible_rect.size == Vector2.ZERO:
		var viewport_size := get_viewport().get_visible_rect().size
		visible_rect = Rect2(player.global_position - viewport_size * 0.5, viewport_size) if player != null else Rect2(Vector2(-320.0, -180.0), Vector2(640.0, 360.0))
	var edge := randi_range(0, 3)
	var spawn_position := Vector2.ZERO
	match edge:
		0:
			spawn_position = Vector2(randf_range(visible_rect.position.x, visible_rect.position.x + visible_rect.size.x), visible_rect.position.y - CORRUPTED_ELITE_SPAWN_MARGIN)
		1:
			spawn_position = Vector2(randf_range(visible_rect.position.x, visible_rect.position.x + visible_rect.size.x), visible_rect.position.y + visible_rect.size.y + CORRUPTED_ELITE_SPAWN_MARGIN)
		2:
			spawn_position = Vector2(visible_rect.position.x - CORRUPTED_ELITE_SPAWN_MARGIN, randf_range(visible_rect.position.y, visible_rect.position.y + visible_rect.size.y))
		_:
			spawn_position = Vector2(visible_rect.position.x + visible_rect.size.x + CORRUPTED_ELITE_SPAWN_MARGIN, randf_range(visible_rect.position.y, visible_rect.position.y + visible_rect.size.y))
	var bounds := _get_scene_boundary_rect()
	if bounds.size.x > 1.0 and bounds.size.y > 1.0:
		spawn_position = _clamp_point_to_rect(spawn_position, bounds)
	return spawn_position

func _is_gold_ball_scene(scene: PackedScene) -> bool:
	return _get_scene_monster_id(scene, "") == "gold_ball"

func _get_scene_monster_id(scene: PackedScene, fallback_id: String) -> String:
	if scene == null:
		return fallback_id
	var scene_path := scene.resource_path
	if scene_path.is_empty():
		return fallback_id
	return scene_path.get_file().get_basename()

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
	var speed_multiplier := (1.0 + late_game_speed_bonus) * Global.get_core_enemy_move_speed_multiplier()
	if is_equal_approx(speed_multiplier, 1.0):
		return
	var base_speed_value = monster_node.get("base_speed")
	if base_speed_value != null:
		monster_node.set("base_speed", float(base_speed_value) * speed_multiplier)
	var speed_value = monster_node.get("speed")
	if speed_value != null:
		monster_node.set("speed", float(speed_value) * speed_multiplier)

func _apply_mobile_monster_balance(monster_node: Node) -> void:
	if not Global.is_mobile_input_mode():
		return
	if monster_node == null or not is_instance_valid(monster_node):
		return
	if monster_node.is_in_group("boss"):
		return
	if bool(monster_node.get_meta("mobile_monster_balance_applied", false)):
		return
	monster_node.set_meta("mobile_monster_balance_applied", true)
	var hp_value: Variant = monster_node.get("hp")
	if hp_value != null:
		monster_node.set("hp", float(hp_value) * MOBILE_MONSTER_HP_MULTIPLIER)
	var hp_max_value: Variant = monster_node.get("hpMax")
	if hp_max_value != null:
		monster_node.set("hpMax", float(hp_max_value) * MOBILE_MONSTER_HP_MULTIPLIER)
	var atk_value: Variant = monster_node.get("atk")
	if atk_value != null:
		monster_node.set("atk", float(atk_value) * MOBILE_MONSTER_ATK_MULTIPLIER)
	var base_speed_value: Variant = monster_node.get("base_speed")
	if base_speed_value != null:
		monster_node.set("base_speed", float(base_speed_value) * MOBILE_MONSTER_SPEED_MULTIPLIER)
	var speed_value: Variant = monster_node.get("speed")
	if speed_value != null:
		monster_node.set("speed", float(speed_value) * MOBILE_MONSTER_SPEED_MULTIPLIER)

func _apply_mobile_boss_balance(boss_node: Node) -> void:
	if not Global.is_mobile_input_mode():
		return
	if boss_node == null or not is_instance_valid(boss_node):
		return
	if bool(boss_node.get_meta("mobile_boss_balance_applied", false)):
		return
	boss_node.set_meta("mobile_boss_balance_applied", true)
	var atk_value: Variant = boss_node.get("atk")
	if atk_value != null:
		boss_node.set("atk", float(atk_value) * MOBILE_BOSS_ATK_MULTIPLIER)


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

func _on_other_type_monster_tree_exiting() -> void:
	other_type_alive = max(0, other_type_alive - 1)

func _on_elite_monster_tree_exiting() -> void:
	elite_alive = max(0, elite_alive - 1)

func add_kill_rewards(monster_node: Node, point_gain: int) -> void:
	point += point_gain
	Global.total_points += point_gain
	add_spirit(_calculate_spirit_gain(monster_node) + PC.get_kill_spirit_bonus())

func add_spirit(amount: float) -> void:
	if amount <= 0:
		return
	spirit_raw += floor(amount * 10.0) / 10.0
	spirit = PC.get_display_spirit(spirit_raw)
	PC.sync_spirit(spirit_raw)

func spend_spirit(amount: int) -> bool:
	if amount <= 0:
		return true
	if spirit < amount:
		return false
	spirit_raw = max(0.0, spirit_raw - float(amount))
	spirit = PC.get_display_spirit(spirit_raw)
	PC.sync_spirit(spirit_raw)
	return true

func _check_qi_vortex_spawn() -> void:
	if qi_vortex_spawn_index >= qi_vortex_spawn_times.size():
		return
	if active_qi_vortex and is_instance_valid(active_qi_vortex):
		return
	if PC.real_time < qi_vortex_spawn_times[qi_vortex_spawn_index]:
		return
	qi_vortex_spawn_index += 1
	_spawn_qi_vortex()

func _spawn_qi_vortex() -> void:
	var vortex := QI_VORTEX_SCENE.instantiate() as Node2D
	if vortex == null:
		return
	vortex.global_position = _get_qi_vortex_spawn_position()
	get_tree().current_scene.add_child(vortex)
	active_qi_vortex = vortex
	_show_qi_vortex_focus_ui()
	if battle_chat and is_instance_valid(battle_chat):
		battle_chat.notify_qi_vortex_spawned()
	_try_show_qi_vortex_tutorial()
	if vortex.has_signal("completed"):
		vortex.completed.connect(_on_qi_vortex_completed)
	if vortex.has_signal("expired"):
		vortex.expired.connect(_on_qi_vortex_expired)
	vortex.tree_exiting.connect(Callable(self, "_on_active_qi_vortex_tree_exiting"))

func _try_show_qi_vortex_tutorial() -> void:
	if Global.has_seen_qi_vortex_tutorial or qi_vortex_tutorial_pending:
		return
	qi_vortex_tutorial_pending = true
	_show_qi_vortex_tutorial_after_delay()

func _show_qi_vortex_tutorial_after_delay() -> void:
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree() or get_tree() == null:
		qi_vortex_tutorial_pending = false
		return
	if Global.has_seen_qi_vortex_tutorial:
		qi_vortex_tutorial_pending = false
		return
	var tutorial := QI_VORTEX_TUTORIAL_SCENE.instantiate()
	if tutorial == null:
		qi_vortex_tutorial_pending = false
		return
	add_child(tutorial)
	Global.has_seen_qi_vortex_tutorial = true
	Global.save_game()
	qi_vortex_tutorial_pending = false

func _on_active_qi_vortex_tree_exiting() -> void:
	active_qi_vortex = null
	_hide_qi_vortex_focus_ui()

func _schedule_next_core_missile() -> void:
	_core_missile_elapsed = 0.0
	_core_next_missile_time = randf_range(CORE_MISSILE_MIN_INTERVAL, CORE_MISSILE_MAX_INTERVAL)

func _update_core_missile_attack(delta: float) -> void:
	if not Global.is_core_missile_enabled():
		return
	if PC.is_game_over or boss_event_triggered:
		return
	_core_missile_elapsed += delta
	if _core_missile_elapsed < _core_next_missile_time:
		return
	_spawn_core_missile_wave()
	_schedule_next_core_missile()

func _spawn_core_missile_wave() -> void:
	if get_tree().current_scene == null:
		return
	var player := $Player as Node2D
	if player == null:
		return
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	var visible_rect := _get_camera_visible_rect(camera)
	if visible_rect.size == Vector2.ZERO:
		var viewport_size := get_viewport().get_visible_rect().size
		visible_rect = Rect2(player.global_position - viewport_size * 0.5, viewport_size)
	var missile_count := randi_range(CORE_MISSILE_MIN_COUNT, CORE_MISSILE_MAX_COUNT)
	var used_edges: Array[int] = []
	for _i in range(missile_count):
		var edge := randi_range(0, 3)
		var guard := 0
		while used_edges.has(edge) and used_edges.size() < 4 and guard < 8:
			edge = randi_range(0, 3)
			guard += 1
		used_edges.append(edge)
		_spawn_core_missile_from_edge(edge, visible_rect, player.global_position)

func _spawn_core_missile_from_edge(edge: int, visible_rect: Rect2, target_position: Vector2) -> void:
	var spawn_position := Vector2.ZERO
	match edge:
		0:
			spawn_position = Vector2(randf_range(visible_rect.position.x, visible_rect.position.x + visible_rect.size.x), visible_rect.position.y - CORE_MISSILE_OFFSCREEN_MARGIN)
		1:
			spawn_position = Vector2(randf_range(visible_rect.position.x, visible_rect.position.x + visible_rect.size.x), visible_rect.position.y + visible_rect.size.y + CORE_MISSILE_OFFSCREEN_MARGIN)
		2:
			spawn_position = Vector2(visible_rect.position.x - CORE_MISSILE_OFFSCREEN_MARGIN, randf_range(visible_rect.position.y, visible_rect.position.y + visible_rect.size.y))
		_:
			spawn_position = Vector2(visible_rect.position.x + visible_rect.size.x + CORE_MISSILE_OFFSCREEN_MARGIN, randf_range(visible_rect.position.y, visible_rect.position.y + visible_rect.size.y))
	var missile: Area2D = null
	if Global.frog_attack_pool:
		missile = Global.frog_attack_pool.acquire(get_tree().current_scene) as Area2D
	else:
		missile = CORE_MISSILE_SCENE.instantiate() as Area2D
	if missile == null:
		return
	var missile_direction := (target_position - spawn_position).normalized()
	var missile_damage: float = float(SettingMoster.frog("atk")) * CORE_MISSILE_DAMAGE_MULTIPLIER
	if missile.has_method("setup_projectile"):
		missile.setup_projectile(spawn_position, missile_direction, missile_damage, CORE_MISSILE_SPEED, CORE_MISSILE_RANGE)
	else:
		if missile.get_parent() == null:
			get_tree().current_scene.add_child(missile)
		missile.global_position = spawn_position
		if missile.get("speed") != null:
			missile.set("speed", CORE_MISSILE_SPEED)
		if missile.get("max_range") != null:
			missile.set("max_range", CORE_MISSILE_RANGE)
		if missile.get("atk") != null:
			missile.set("atk", missile_damage)
		if missile.has_method("set_direction"):
			missile.set_direction(missile_direction)
		if missile.has_method("play_animation"):
			missile.play_animation("fire")

func _get_qi_vortex_spawn_position() -> Vector2:
	var camera := $Player.get_node_or_null("Camera2D") as Camera2D
	var bounds := _get_qi_vortex_spawn_bounds(camera)
	var visible_rect := _get_camera_visible_rect(camera).grow(QI_VORTEX_VIEW_MARGIN)
	for _i in range(40):
		var candidate := _random_point_in_rect(bounds)
		if not visible_rect.has_point(candidate):
			return _clamp_point_to_rect(candidate, bounds)
	return _clamp_point_to_rect(_get_qi_vortex_edge_fallback(bounds, visible_rect), bounds)

func _get_qi_vortex_spawn_bounds(camera: Camera2D) -> Rect2:
	var scene_bounds := _get_scene_boundary_rect()
	if scene_bounds.size.x > 1.0 and scene_bounds.size.y > 1.0:
		return _shrink_rect(scene_bounds, QI_VORTEX_SPAWN_MARGIN)
	return _get_camera_limit_rect(camera)

func _get_camera_limit_rect(camera: Camera2D) -> Rect2:
	if camera == null:
		return Rect2(Vector2(-500.0, -500.0), Vector2(1000.0, 1000.0))
	var left := float(camera.limit_left) + QI_VORTEX_SPAWN_MARGIN
	var top := float(camera.limit_top) + QI_VORTEX_SPAWN_MARGIN
	var right := float(camera.limit_right) - QI_VORTEX_SPAWN_MARGIN
	var bottom := float(camera.limit_bottom) - QI_VORTEX_SPAWN_MARGIN
	if left > right:
		var center_x := (float(camera.limit_left) + float(camera.limit_right)) * 0.5
		left = center_x
		right = center_x
	if top > bottom:
		var center_y := (float(camera.limit_top) + float(camera.limit_bottom)) * 0.5
		top = center_y
		bottom = center_y
	return Rect2(Vector2(left, top), Vector2(max(1.0, right - left), max(1.0, bottom - top)))

func _get_camera_visible_rect(camera: Camera2D) -> Rect2:
	if camera == null:
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var viewport_size := get_viewport().get_visible_rect().size
	var zoom_value := camera.zoom
	var half_size := Vector2(
		viewport_size.x / max(zoom_value.x, 0.01),
		viewport_size.y / max(zoom_value.y, 0.01)
	) * 0.5
	var center := camera.get_screen_center_position()
	return Rect2(center - half_size, half_size * 2.0)

func _random_point_in_rect(rect: Rect2) -> Vector2:
	return Vector2(
		randf_range(rect.position.x, rect.position.x + rect.size.x),
		randf_range(rect.position.y, rect.position.y + rect.size.y)
	)

func _get_qi_vortex_edge_fallback(bounds: Rect2, visible_rect: Rect2) -> Vector2:
	var bands: Array[Rect2] = []
	var left_band := Rect2(bounds.position, Vector2(max(0.0, visible_rect.position.x - bounds.position.x), bounds.size.y))
	var right_start := visible_rect.position.x + visible_rect.size.x
	var right_band := Rect2(Vector2(right_start, bounds.position.y), Vector2(max(0.0, bounds.position.x + bounds.size.x - right_start), bounds.size.y))
	var top_band := Rect2(bounds.position, Vector2(bounds.size.x, max(0.0, visible_rect.position.y - bounds.position.y)))
	var bottom_start := visible_rect.position.y + visible_rect.size.y
	var bottom_band := Rect2(Vector2(bounds.position.x, bottom_start), Vector2(bounds.size.x, max(0.0, bounds.position.y + bounds.size.y - bottom_start)))
	for band in [left_band, right_band, top_band, bottom_band]:
		if band.size.x > 1.0 and band.size.y > 1.0:
			bands.append(band)
	if bands.is_empty():
		return _random_point_in_rect(bounds)
	return _random_point_in_rect(bands[randi_range(0, bands.size() - 1)])

func _shrink_rect(rect: Rect2, margin: float) -> Rect2:
	var left := rect.position.x + margin
	var top := rect.position.y + margin
	var right := rect.position.x + rect.size.x - margin
	var bottom := rect.position.y + rect.size.y - margin
	if left > right:
		var center_x := rect.position.x + rect.size.x * 0.5
		left = center_x
		right = center_x
	if top > bottom:
		var center_y := rect.position.y + rect.size.y * 0.5
		top = center_y
		bottom = center_y
	return Rect2(Vector2(left, top), Vector2(max(1.0, right - left), max(1.0, bottom - top)))

func _clamp_point_to_rect(point: Vector2, rect: Rect2) -> Vector2:
	return Vector2(
		clamp(point.x, rect.position.x, rect.position.x + rect.size.x),
		clamp(point.y, rect.position.y, rect.position.y + rect.size.y)
	)

func _get_scene_boundary_rect() -> Rect2:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return Rect2()
	var boundary_node := current_scene.find_child("Boundry", true, false) as Node2D
	if boundary_node == null:
		return Rect2()
	var bounds := _compute_boundary_from_static_bodies(boundary_node)
	if not (bounds.has("min_x") and bounds.has("max_x") and bounds.has("min_y") and bounds.has("max_y")):
		return Rect2()
	var min_x := float(bounds["min_x"])
	var max_x := float(bounds["max_x"])
	var min_y := float(bounds["min_y"])
	var max_y := float(bounds["max_y"])
	if STAGE_ID == "cave":
		min_y += 60.0
	if min_x >= max_x or min_y >= max_y:
		return Rect2()
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _compute_boundary_from_static_bodies(boundary_node: Node2D) -> Dictionary:
	var result: Dictionary = {}
	var margin := 0.15
	for child in boundary_node.get_children():
		if not child is StaticBody2D:
			continue
		var static_body := child as StaticBody2D
		var col_shape: CollisionShape2D = null
		for sub in static_body.get_children():
			if sub is CollisionShape2D:
				col_shape = sub
				break
		if col_shape == null:
			continue
		if col_shape.shape == null or not col_shape.shape is WorldBoundaryShape2D:
			continue
		var wb_shape := col_shape.shape as WorldBoundaryShape2D
		var rot := fposmod(static_body.global_rotation, TAU)
		if rot > PI:
			rot -= TAU
		var abs_rot := absf(rot)
		var normal := Vector2(0.0, -1.0).rotated(rot)
		var boundary_pos := col_shape.global_position + normal * wb_shape.distance
		if abs_rot < margin or absf(abs_rot - PI) < margin:
			var y_val := boundary_pos.y
			if abs_rot < margin:
				if not result.has("max_y") or y_val < result["max_y"]:
					result["max_y"] = y_val
			else:
				if not result.has("min_y") or y_val > result["min_y"]:
					result["min_y"] = y_val
		elif absf(abs_rot - PI / 2.0) < margin:
			var x_val := boundary_pos.x
			if rot < 0:
				if not result.has("max_x") or x_val < result["max_x"]:
					result["max_x"] = x_val
			else:
				if not result.has("min_x") or x_val > result["min_x"]:
					result["min_x"] = x_val
	return result

func _show_qi_vortex_focus_ui() -> void:
	_ensure_qi_vortex_indicator()
	_show_qi_vortex_spawn_flash()
	_update_qi_vortex_indicator()

func _hide_qi_vortex_focus_ui() -> void:
	if qi_vortex_indicator:
		qi_vortex_indicator.visible = false

func _show_qi_vortex_shop_mask() -> void:
	_ensure_qi_vortex_mask()
	if qi_vortex_mask == null:
		return
	if _qi_vortex_mask_tween and _qi_vortex_mask_tween.is_valid():
		_qi_vortex_mask_tween.kill()
	qi_vortex_mask.visible = true
	qi_vortex_mask.color.a = 0.0
	_qi_vortex_mask_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_qi_vortex_mask_tween.set_ignore_time_scale(true)
	_qi_vortex_mask_tween.tween_property(qi_vortex_mask, "color:a", QI_VORTEX_MASK_ALPHA, 0.25)

func _hide_qi_vortex_shop_mask() -> void:
	if qi_vortex_mask:
		if _qi_vortex_mask_tween and _qi_vortex_mask_tween.is_valid():
			_qi_vortex_mask_tween.kill()
		_qi_vortex_mask_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_qi_vortex_mask_tween.set_ignore_time_scale(true)
		_qi_vortex_mask_tween.tween_property(qi_vortex_mask, "color:a", 0.0, 0.2)
		_qi_vortex_mask_tween.tween_callback(Callable(self, "_hide_qi_vortex_mask_after_fade"))

func _hide_qi_vortex_mask_after_fade() -> void:
	if qi_vortex_mask and is_instance_valid(qi_vortex_mask):
		qi_vortex_mask.visible = false

func _show_qi_vortex_spawn_flash() -> void:
	if layer_ui == null:
		return
	var flash := ColorRect.new()
	flash.name = "QiVortexSpawnFlash"
	flash.color = QI_VORTEX_SPAWN_FLASH_COLOR
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.process_mode = Node.PROCESS_MODE_ALWAYS
	flash.z_index = 70
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.offset_left = 0.0
	flash.offset_top = 0.0
	flash.offset_right = 0.0
	flash.offset_bottom = 0.0
	layer_ui.add_child(flash)
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	tween.tween_property(flash, "color:a", 0.0, QI_VORTEX_SPAWN_FLASH_SECONDS)
	tween.tween_callback(flash.queue_free)

func _show_gold_ball_spawn_flash() -> void:
	if layer_ui == null:
		return
	var flash := ColorRect.new()
	flash.name = "GoldBallSpawnFlash"
	flash.color = GOLD_BALL_SPAWN_FLASH_COLOR
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.process_mode = Node.PROCESS_MODE_ALWAYS
	flash.z_index = 72
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.offset_left = 0.0
	flash.offset_top = 0.0
	flash.offset_right = 0.0
	flash.offset_bottom = 0.0
	layer_ui.add_child(flash)
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	tween.tween_property(flash, "color:a", 0.0, GOLD_BALL_SPAWN_FLASH_SECONDS)
	tween.tween_callback(flash.queue_free)

func _ensure_qi_vortex_mask() -> void:
	if qi_vortex_mask and is_instance_valid(qi_vortex_mask):
		return
	if layer_ui == null:
		return
	qi_vortex_mask = ColorRect.new()
	qi_vortex_mask.name = "QiVortexMask"
	qi_vortex_mask.color = Color(0.0, 0.0, 0.0, 0.0)
	qi_vortex_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	qi_vortex_mask.process_mode = Node.PROCESS_MODE_ALWAYS
	qi_vortex_mask.z_index = -100
	qi_vortex_mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	qi_vortex_mask.offset_left = 0.0
	qi_vortex_mask.offset_top = 0.0
	qi_vortex_mask.offset_right = 0.0
	qi_vortex_mask.offset_bottom = 0.0
	layer_ui.add_child(qi_vortex_mask)
	qi_vortex_mask.visible = false

func _ensure_qi_vortex_indicator() -> void:
	if qi_vortex_indicator and is_instance_valid(qi_vortex_indicator):
		return
	if layer_ui == null:
		return
	qi_vortex_indicator = Sprite2D.new()
	qi_vortex_indicator.name = "QiVortexIndicator"
	qi_vortex_indicator.texture = QI_VORTEX_INDICATOR_TEXTURE
	qi_vortex_indicator.centered = true
	qi_vortex_indicator.scale = Vector2.ONE * QI_VORTEX_INDICATOR_SCALE
	qi_vortex_indicator.modulate.a = QI_VORTEX_INDICATOR_ALPHA
	qi_vortex_indicator.process_mode = Node.PROCESS_MODE_ALWAYS
	qi_vortex_indicator.z_index = 80
	qi_vortex_indicator.visible = false
	layer_ui.add_child(qi_vortex_indicator)

func _update_qi_vortex_indicator() -> void:
	if active_qi_vortex == null or not is_instance_valid(active_qi_vortex):
		if qi_vortex_indicator:
			qi_vortex_indicator.visible = false
			qi_vortex_indicator.modulate.a = QI_VORTEX_INDICATOR_ALPHA
		return
	_ensure_qi_vortex_indicator()
	if qi_vortex_indicator == null:
		return
	var camera := $Player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		qi_vortex_indicator.visible = false
		qi_vortex_indicator.modulate.a = QI_VORTEX_INDICATOR_ALPHA
		return
	var visible_rect := _get_camera_visible_rect(camera)
	if visible_rect.has_point(active_qi_vortex.global_position):
		qi_vortex_indicator.visible = false
		qi_vortex_indicator.modulate.a = QI_VORTEX_INDICATOR_ALPHA
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var zoom_value := camera.zoom
	var target_screen_pos := Vector2(
		(active_qi_vortex.global_position.x - visible_rect.position.x) * max(zoom_value.x, 0.01),
		(active_qi_vortex.global_position.y - visible_rect.position.y) * max(zoom_value.y, 0.01)
	)
	var viewport_center := viewport_size * 0.5
	var direction := target_screen_pos - viewport_center
	if direction.length_squared() <= 0.001:
		qi_vortex_indicator.visible = false
		qi_vortex_indicator.modulate.a = QI_VORTEX_INDICATOR_ALPHA
		return
	direction = direction.normalized()
	var half_area := viewport_center - Vector2(QI_VORTEX_INDICATOR_MARGIN, QI_VORTEX_INDICATOR_MARGIN)
	var x_distance := 1.0e20
	var y_distance := 1.0e20
	if absf(direction.x) > 0.001:
		x_distance = half_area.x / absf(direction.x)
	if absf(direction.y) > 0.001:
		y_distance = half_area.y / absf(direction.y)
	qi_vortex_indicator.position = viewport_center + direction * min(x_distance, y_distance)
	qi_vortex_indicator.rotation = direction.angle()
	if active_qi_vortex.has_method("get_expiring_flash_alpha"):
		qi_vortex_indicator.modulate.a = active_qi_vortex.get_expiring_flash_alpha(QI_VORTEX_INDICATOR_ALPHA)
	else:
		qi_vortex_indicator.modulate.a = QI_VORTEX_INDICATOR_ALPHA
	qi_vortex_indicator.visible = true

func _on_qi_vortex_completed(vortex: Node2D) -> void:
	if vortex != active_qi_vortex:
		return
	add_spirit(500)
	_restore_player_full_hp_from_qi_vortex()
	if qi_vortex_shop_manager:
		qi_vortex_shop_manager.open(self, layer_ui)

func _restore_player_full_hp_from_qi_vortex() -> void:
	if PC.pc_max_hp <= 0 or PC.pc_hp >= PC.pc_max_hp:
		return
	var heal_amount := float(PC.pc_max_hp - PC.pc_hp)
	PC.pc_hp = PC.pc_max_hp
	Global.emit_signal("player_heal", heal_amount, $Player.global_position, "qi_vortex")
	Global.emit_signal("player_healed", heal_amount)
	if layer_ui:
		layer_ui.update_hp_bar(PC.pc_hp, PC.pc_max_hp, PC.get_total_shield())

func _on_qi_vortex_expired(vortex: Node2D) -> void:
	if vortex == active_qi_vortex:
		active_qi_vortex = null
		_hide_qi_vortex_focus_ui()

func _calculate_spirit_gain(monster_node: Node) -> float:
	var base_gain := NORMAL_SPIRIT_GAIN
	if monster_node != null and monster_node.get_meta("is_special_enemy", false) == true:
		base_gain = SPECIAL_SPIRIT_GAIN
	if monster_node != null and (monster_node.get_meta("is_elite_monster", false) == true or monster_node.is_in_group("elite")):
		base_gain *= ELITE_SPIRIT_MULTIPLIER
	if monster_node != null and monster_node.get_meta("is_corrupted_elite", false) == true:
		base_gain = int(round(float(base_gain) * CORRUPTED_ELITE_REWARD_EXTRA))
	var elapsed_minutes := int(floor(PC.real_time / 60.0))
	var gain_rate := PC.spirit_multi + float(elapsed_minutes) * SPIRIT_GAIN_PER_MINUTE_RATE
	return floor(float(base_gain) * (1.0 + gain_rate) * 10.0) / 10.0

func _mark_spirit_enemy_type(monster_node: Node, is_special_enemy: bool) -> void:
	if monster_node == null:
		return
	monster_node.set_meta("is_special_enemy", is_special_enemy)

func _register_spawned_monster(monster_node: Node, is_special_enemy: bool, allow_elite: bool = true, connect_other_type_counter: bool = false) -> void:
	if monster_node == null:
		return
	_mark_spirit_enemy_type(monster_node, is_special_enemy)
	if allow_elite:
		_try_make_elite(monster_node)
	_apply_dynamic_hp_reduction(monster_node)
	_apply_late_game_speed_bonus(monster_node)
	_apply_mobile_monster_balance(monster_node)
	monster_node.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(monster_node, "modulate:a", 1.0, 0.7)
	current_monster_count += 1
	monster_node.connect("tree_exiting", Callable(self, "_on_monster_defeated"))
	if connect_other_type_counter:
		monster_node.connect("tree_exiting", Callable(self, "_on_other_type_monster_tree_exiting"))

## 尝试将怪物升级为精英怪（2%概率）
func _try_make_elite(monster_node: Node) -> void:
	if monster_node == null:
		return
	if monster_node.get_meta("never_elite", false) == true or monster_node.is_in_group("non_elite_enemy"):
		return
	if randf() > ELITE_SPAWN_CHANCE:
		return # 未触发精英怪
	if elite_alive >= ELITE_MAX:
		return # 精英怪已达上限

	# 标记为精英怪
	monster_node.is_elite = true
	monster_node.add_to_group("elite")
	elite_alive += 1
	monster_node.connect("tree_exiting", Callable(self, "_on_elite_monster_tree_exiting"))

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
func _apply_elite_visual(monster_node: Node, line_color: Color = Color(1.0, 0.0, 0.0, 1.0), line_thickness: float = 0.75, sprite_modulate: Color = Color(1.0, 0.95, 0.95, 1.0)) -> void:
	# 获取精灵节点并添加红色色调
	var sprite = monster_node.get_node_or_null("AnimatedSprite2D")
	if sprite:
		# 修改滤镜颜色为红色，透明度0.3
		sprite.modulate = sprite_modulate

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
		shader_material.set_shader_parameter("line_color", line_color)
		shader_material.set_shader_parameter("line_thickness", line_thickness)
		sprite.material = shader_material

	# 给怪物添加精英怪标记
	monster_node.set_meta("is_elite_monster", true)

# ============== 金团团生成 ==============
## 每波怪生成时尝试刷新金团团（基础 1.5% 概率，受修习树加成影响）
func _try_spawn_gold_ball() -> void:
	if boss_event_triggered:
		return
	if not Global.study_gold_ball_unlocked:
		return
	# 实际概率 = 基础 1.5% × (1 + 金团团概率加成)
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
	_show_gold_ball_spawn_flash()
	_mark_spirit_enemy_type(gold_ball_node, true)
	_apply_mobile_monster_balance(gold_ball_node)
	gold_ball_node.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(gold_ball_node, "modulate:a", 1.0, 0.7)
	current_monster_count += 1
	gold_ball_node.connect("tree_exiting", Callable(self , "_on_monster_defeated"))
	if battle_chat and is_instance_valid(battle_chat):
		battle_chat.notify_gold_ball_spawned()
	print("[GoldBall] 金团团已生成！")

# ============== 游戏结果 ==============
func _on_player_damage_for_summary(damage_val: float, shield_val: float, _attacker: Node2D, _world_position: Vector2, _source_name: String = "") -> void:
	battle_lost_hp += max(0.0, damage_val) + max(0.0, shield_val)

func show_game_over():
	PC.is_game_over = true
	Global.total_defeat_count += 1
	AchievementManager.record_stage_finished()
	Global.save_game()
	EmblemManager.clear_all_emblems()
	DpsManager.stop_dps_counter()
	Global.stop_dps_counter()
	layer_ui.show_game_over()
	var player = get_node("Player")
	player.stop_all_skill_cooldowns()
	layer_ui.stop_all_skill_cooldowns()
	await get_tree().create_timer(2).timeout
	if not is_inside_tree():
		return
	# 首次离开peach_grove时进入story_2
	if STAGE_ID == "peach_grove" and not Global.has_seen_story_2:
		Global.has_seen_story_2 = true
		Global.save_game()
		SceneChange.change_scene("res://Scenes/story/story_2.tscn", true)
		return
	# 累计失败2次时进入story_3（炼丹炉解锁剧情）
	if Global.total_defeat_count >= 2 and not Global.has_seen_story_3:
		Global.has_seen_story_3 = true
		Global.save_game()
		SceneChange.change_scene("res://Scenes/story/story_3.tscn", true)
		return
	# 累计失败3次时进入story_4（神秘商铺解锁剧情）
	if Global.total_defeat_count >= 3 and not Global.has_seen_story_4:
		Global.has_seen_story_4 = true
		Global.save_game()
		SceneChange.change_scene("res://Scenes/story/story_4.tscn", true)
		return
	SceneChange.change_scene("res://Scenes/main_town.tscn", true)

func _on_boss_defeated(_get_point: int, boss_position: Vector2):
	if not PC.is_game_over:
		# 标记游戏结束状态，防止后续逻辑触发
		PC.is_game_over = true
		
		# 采样结算数据并停止DPS计数器
		Global.refresh_dps_counter()
		var victory_snapshot := AchievementManager.build_victory_snapshot(
			STAGE_ID,
			Global.current_stage_difficulty,
			Global.current_core_depth,
			PC.real_time,
			GU.get_kill_count(),
			Global.get_highest_dps(),
			battle_lost_hp,
			point,
			spirit
		)
		AchievementManager.record_stage_result(victory_snapshot)
		
		# 清除所有纹章效果
		EmblemManager.clear_all_emblems()
		
		if layer_ui and layer_ui.has_method("set_victory_summary_data"):
			layer_ui.set_victory_summary_data({
				"boss_defeat_time": PC.real_time,
				"kill_count": GU.get_kill_count(),
				"highest_dps": Global.get_highest_dps(),
				"lost_hp": battle_lost_hp,
			})
		DpsManager.stop_dps_counter()
		Global.stop_dps_counter()
		
		$Victory.play()
		SEManager.play("202")
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
		# 角色解锁：首次通关指定关卡后开放对应角色和初始武器。
		if STAGE_ID == "ruin" and not Global.unlock_noam:
			Global.unlock_noam = true
			Global.sync_available_start_weapons()
			print("[HeroUnlock] 首次通关ruin，解锁诺姆及疗愈技能")
		if STAGE_ID == "cave" and not Global.unlock_kansel:
			Global.unlock_kansel = true
			Global.sync_available_start_weapons()
			print("[HeroUnlock] 首次通关cave，解锁坎塞尔及炽炎技能")
		if STAGE_ID == "forest" and not Global.unlock_xueming:
			Global.unlock_xueming = true
			Global.sync_available_start_weapons()
			print("[HeroUnlock] 首次通关forest，解锁雪铭及爪爪巨锤")
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
		# 首次离开peach_grove时进入story_2
		if STAGE_ID == "peach_grove" and not Global.has_seen_story_2:
			Global.has_seen_story_2 = true
			Global.save_game()
			SceneChange.change_scene("res://Scenes/story/story_2.tscn", true)
			return
		# 首次通关ruin后进入story_5（诺姆解锁剧情）
		if STAGE_ID == "ruin" and not Global.has_seen_story_5:
			Global.has_seen_story_5 = true
			Global.save_game()
			SceneChange.change_scene("res://Scenes/story/story_5.tscn", true)
			return
		# 首次通关cave后进入story_7（坎塞尔解锁剧情）
		if STAGE_ID == "cave" and not Global.has_seen_story_7:
			Global.has_seen_story_7 = true
			Global.save_game()
			SceneChange.change_scene("res://Scenes/story/story_7.tscn", true)
			return
		SceneChange.change_scene("res://Scenes/main_town.tscn", true)

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
