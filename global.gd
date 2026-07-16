@warning_ignore("unused_signal")
extends Node

const CONFIG_PATH = "user://game_config.cfg"
const SaveCrypto := preload("res://Script/system/save_crypto.gd")
const LINGSHI_ITEM_ID := "item_084"
const JIUYOU_KEY_ITEM_ID := "item_006"
const INITIAL_REFRESH_BASE_NUM: int = 2
const LEGACY_INITIAL_REFRESH_BASE_NUM: int = 5
const REFRESH_BASE_VERSION: int = 2
const ZHENQI_ECONOMY_VERSION: int = 2
const ZHENQI_ECONOMY_SCALE: float = 0.1

const DEBUG_F1_ZHENQI_AMOUNT := 100000
var DEBUG_COMMANDS_ENABLED: bool = false

const INPUT_DEVICE_MODE_PC: String = "pc"
const INPUT_DEVICE_MODE_MOBILE: String = "mobile"

# 测试模式：跳过开屏动画，直接进入游戏
var is_test: bool = false
var time_slow_enabled: bool = false
var is_debug: bool = true
var input_device_mode: String = INPUT_DEVICE_MODE_PC
var _mobile_input_restore_request_id: int = 0

# 战斗速度倍率（由速度切换按钮控制）
var game_speed: float = 1.0

func reset_game_speed() -> void:
	game_speed = 1.0
	Engine.time_scale = 1.0

# 保存指示器相关
const SAVE_INDICATOR_SCENE := preload("res://Scenes/global/loading_anime.tscn")
const DEFERRED_BATTLE_SAVE_RETRY_SECONDS := 1.0
var _save_indicator_layer: CanvasLayer
var _save_indicator_tween: Tween
var _deferred_battle_save_requested: bool = false
var _deferred_battle_save_running: bool = false

# 关卡难度ID常量。
# 这里统一用英文ID存数据，显示时再转换成中文，
# 这样后续存档和代码判断会更稳定，不容易因为中文改字而出问题。
const STAGE_DIFFICULTY_SHALLOW := "shallow"
const STAGE_DIFFICULTY_DEEP := "deep"
const STAGE_DIFFICULTY_CORE := "core"
const STAGE_DIFFICULTY_POETRY := "poetry"
const STAGE_DIFFICULTY_LIST := [
	STAGE_DIFFICULTY_SHALLOW,
	STAGE_DIFFICULTY_DEEP,
	STAGE_DIFFICULTY_CORE,
	STAGE_DIFFICULTY_POETRY
]
const STAGE_BOSS_MODIFIER_DELAY_SECONDS: float = 15.0
const STAGE_BOSS_MODIFIER_STEP_SECONDS: float = 5.0
const STAGE_BOSS_PLAYER_MODIFIER_BASE_BONUS: float = 0.05
const STAGE_BOSS_DAMAGE_MODIFIER_BASE_BONUS: float = 0.02
const STAGE_BOSS_MODIFIER_STEP_BONUS: float = 0.01
const STAGE_BOSS_MODIFIER_START_TIMES := {
	STAGE_DIFFICULTY_SHALLOW: 360.0,
	STAGE_DIFFICULTY_DEEP: 420.0,
	STAGE_DIFFICULTY_CORE: 480.0
}

# 关卡ID列表。
# 关卡列表，包含正式关卡与已开放的秘境关卡。
const STAGE_ID_LIST := ["peach_grove", "ruin", "cave", "forest", "difu"]

const CORE_DEPTH_MIN := 1
const CORE_DEPTH_MAX := 10
const CORE_DEPTH_STAT_STEP := 0.08
const DEEP_DIFFICULTY_STAT_MULTIPLIER := 1.25
const CORE_DIFFICULTY_BASE_STAT_MULTIPLIER := 1.5
const STAGE_CORE_DEPTH_STAT_MULTIPLIERS := {
	"peach_grove": {
		1: 1.62,
		2: 2.699,
		3: 3.778,
		4: 4.857,
		5: 5.217,
		6: 5.577,
		7: 5.937,
		8: 6.296,
		9: 6.656,
		10: 7.016
	},
	"ruin": {
		1: 1.62,
		2: 2.617,
		3: 3.613,
		4: 3.881,
		5: 4.149,
		6: 4.416,
		7: 4.684,
		8: 4.951,
		9: 5.219,
		10: 5.487
	},
	"cave": {
		1: 1.62,
		2: 2.272,
		3: 2.44,
		4: 2.608,
		5: 2.776,
		6: 2.945,
		7: 3.113,
		8: 3.281,
		9: 3.449,
		10: 3.618
	},
	"forest": {
		1: 1.62,
		2: 1.74,
		3: 1.86,
		4: 1.98,
		5: 2.1,
		6: 2.22,
		7: 2.34,
		8: 2.46,
		9: 2.58,
		10: 2.7
	},
	"difu": {
		1: 1.62,
		2: 1.74,
		3: 1.86,
		4: 1.98,
		5: 2.1,
		6: 2.22,
		7: 2.34,
		8: 2.46,
		9: 2.58,
		10: 2.7
	}
}
const SHALLOW_DIFFICULTY_QI_GAIN_MULTIPLIER := 1.0
const DEEP_DIFFICULTY_QI_GAIN_MULTIPLIER := 1.2
const CORE_DIFFICULTY_BASE_QI_GAIN_MULTIPLIER := 1.4
const CORE_DEPTH_QI_GAIN_STEP := 0.1
const POETRY_BATTLE_START_TIME_SECONDS := 480.0
const POETRY_BOSS_DAMAGE_BASE_BONUS := 0.9
const POETRY_BOSS_DAMAGE_XUANYUAN_STEP := 0.005
const POETRY_BOSS_DAMAGE_HUTI_STEP := 0.01
const POETRY_BOSS_DAMAGE_CORRECTION_STEP := 0.05
const POETRY_BOSS_DAMAGE_FINAL_MULTIPLIER := 0.65
const POETRY_MODIFIER_STEP_SECONDS := 10.0
const POETRY_MODIFIER_DOUBLE_AFTER_SECONDS := 60.0
const POETRY_PLAYER_FINAL_DAMAGE_STEP := 0.08
const POETRY_HEAL_SHIELD_STEP_PENALTY := 0.05
const POETRY_BOSS_HP_OUTPUT_SCALE := 900.0
const POETRY_BOSS_HP_FINAL_MULTIPLIER := 0.95
const POETRY_BOSS_HP_FACTORS := {
	"boss_a": 0.81,
	"boss_stone": 0.8525,
	"boss_cansel": 0.73,
	"boss_stele": 1.37
}
const DEFAULT_START_WEAPON_BY_HERO := {
	"moning": "Qigong",
	"yiqiu": "SwordQi",
	"noam": "LightBullet",
	"kansel": "Ice",
	"xueming": "Zhuazhuajuchui"
}
const START_WEAPON_ORDER: Array[String] = [
	"SwordQi",
	"Qigong",
	"LightBullet",
	"Ice",
	"Xunfeng",
	"Genshan",
	"Bloodwave",
	"Xuanwu",
	"Water",
	"HolyLight",
	"Branch",
	"Thunder",
	"ThunderBreak",
	"Moyan",
	"Qiankun",
	"BloodBoardSword",
	"Zhuazhuajuchui",
	"Riyan",
	"RingFire",
	"Duize",
	"DragonWind"
]
const FAZE_LEVEL_PROPERTIES := [
	"faze_blood_level",
	"faze_sword_level",
	"faze_thunder_level",
	"faze_heal_level",
	"faze_summon_level",
	"faze_shield_level",
	"faze_fire_level",
	"faze_destroy_level",
	"faze_life_level",
	"faze_bullet_level",
	"faze_wide_level",
	"faze_bagua_level",
	"faze_treasure_level",
	"faze_deep_level",
	"faze_shehun_level",
	"faze_chaos_level",
	"faze_skill_level",
	"faze_sixsense_level",
	"faze_wind_level"
]

# 各关卡在不同难度下的属性倍率。
const STAGE_DIFFICULTY_MULTIPLIERS := {
	"peach_grove": {
		STAGE_DIFFICULTY_SHALLOW: 1.0,
		STAGE_DIFFICULTY_DEEP: 1.5,
		STAGE_DIFFICULTY_CORE: 2.25,
		STAGE_DIFFICULTY_POETRY: 2.25
	},
	"ruin": {
		STAGE_DIFFICULTY_SHALLOW: 1.0,
		STAGE_DIFFICULTY_DEEP: 1.5,
		STAGE_DIFFICULTY_CORE: 2.25,
		STAGE_DIFFICULTY_POETRY: 2.25
	},
	"cave": {
		STAGE_DIFFICULTY_SHALLOW: 1.0,
		STAGE_DIFFICULTY_DEEP: 1.5,
		STAGE_DIFFICULTY_CORE: 2.25,
		STAGE_DIFFICULTY_POETRY: 2.25
	},
	"forest": {
		STAGE_DIFFICULTY_SHALLOW: 1.0,
		STAGE_DIFFICULTY_DEEP: 1.5,
		STAGE_DIFFICULTY_CORE: 2.25,
		STAGE_DIFFICULTY_POETRY: 2.25
	},
	"difu": {
		STAGE_DIFFICULTY_SHALLOW: 1.0,
		STAGE_DIFFICULTY_DEEP: 1.5,
		STAGE_DIFFICULTY_CORE: 2.25,
		STAGE_DIFFICULTY_POETRY: 2.25
	},
}

# 合成界面状态 - 用于禁用缩放等操作
var in_synthesis: bool = false
var _camera_zoom_lock_sources: Dictionary = {}

func lock_camera_zoom(source: String = "ui") -> void:
	if source.is_empty():
		source = "ui"
	_camera_zoom_lock_sources[source] = true

func unlock_camera_zoom(source: String = "ui") -> void:
	if source.is_empty():
		source = "ui"
	_camera_zoom_lock_sources.erase(source)

func reset_camera_zoom_locks() -> void:
	_camera_zoom_lock_sources.clear()

func is_camera_zoom_locked() -> bool:
	return in_synthesis or not _camera_zoom_lock_sources.is_empty()

# Victory结算吸取阶段标志 - 物品自动飞向玩家时不实际回血
var victory_collecting: bool = false


# 纹章配置管理器
var setting_emblem = preload("res://Script/config/setting_emblem.gd").new()

# 音频管理器
var audio_manager = preload("res://Script/system/audio_manager.gd").new()

# 设置管理器
var settings_manager = preload("res://Script/system/settings_manager.gd").new()

# 滤镜管理器
var soft_glow_manager = preload("res://Script/system/soft_glow_manager.gd").new()

# 主动技能管理器
var active_skill_manager = preload("res://Script/config/active_skill_manager.gd").new()

# 装备管理器
var equipment_manager = preload("res://Script/config/equipment_manager.gd").new()

# 经验光点系统
var exp_orb_system = preload("res://Script/system/exp_orb_system.gd").new()

@export var total_points: int = 100

@export var unlock_moning: bool = true
@export var unlock_yiqiu: bool = true
@export var unlock_noam: bool = false
@export var unlock_kansel: bool = false
@export var unlock_xueming: bool = false

@export var exp_multi: float = 0
@export var drop_multi: float = 0
@export var body_size: float = 1
@export var attack_range: float = 1.0
@export var heal_multi: float = 0
@export var sheild_multi: float = 0
@export var normal_monster_multi: float = 0
@export var boss_multi: float = 0
@export var cooldown: float = 0
@export var active_skill_multi: float = 0

@export var max_main_skill_num: int = 3
@export var max_weapon_num: int = 5

# 纹章相关字段
@export var emblem_slots_max: int = 4 # 纹章数量上限
@export var emblem_effect_rate: float = 0.0 # 纹章提升率

# 果实回复效果
@export var fruit_heal_multi: float = 1
@export var fruit_heal_multi_used_count: int = 0 # 回春露已使用次数（最多10次）

# 特殊秘丹使用上限
@export var special_pill_lower_max_uses: int = 50
@export var special_pill_middle_max_uses: int = 20
@export var special_pill_upper_max_uses: int = 10

# 丹药使用次数记录 {item_id: 已使用次数}
@export var pill_used_counts: Dictionary = {}

# 玩家背包与进度变量
var player_inventory: Dictionary = {}
@export var lingshi: int = 0
@export var shop_level: int = 1
@export var shop_battle_refresh_count: int = 0
@export var shop_lingshi_unit_price: float = 5.0

# 仅在当前存档第一次进入货摊时自动刷新一次
@export var shop_first_entered: bool = false

# 当前货摊商品列表会保存在存档里，保证再次进入时仍显示上次的货物状态。
var shop_saved_items: Array = []

# 关卡难度通关记录
@export var stage_difficulty_clear_progress: Dictionary = {
	"peach_grove": {
		STAGE_DIFFICULTY_SHALLOW: false,
		STAGE_DIFFICULTY_DEEP: false,
		STAGE_DIFFICULTY_CORE: false,
		STAGE_DIFFICULTY_POETRY: false
	},
	"ruin": {
		STAGE_DIFFICULTY_SHALLOW: false,
		STAGE_DIFFICULTY_DEEP: false,
		STAGE_DIFFICULTY_CORE: false,
		STAGE_DIFFICULTY_POETRY: false
	},
	"cave": {
		STAGE_DIFFICULTY_SHALLOW: false,
		STAGE_DIFFICULTY_DEEP: false,
		STAGE_DIFFICULTY_CORE: false,
		STAGE_DIFFICULTY_POETRY: false
	},
	"forest": {
		STAGE_DIFFICULTY_SHALLOW: false,
		STAGE_DIFFICULTY_DEEP: false,
		STAGE_DIFFICULTY_CORE: false,
		STAGE_DIFFICULTY_POETRY: false
	},
	"difu": {
		STAGE_DIFFICULTY_SHALLOW: false,
		STAGE_DIFFICULTY_DEEP: false,
		STAGE_DIFFICULTY_CORE: false,
		STAGE_DIFFICULTY_POETRY: false
	}
}

# 每个关卡已通关的最高核心进阶层数。0 表示尚未通关核心进阶。
@export var core_depth_clear_progress: Dictionary = {
	"peach_grove": 0,
	"ruin": 0,
	"cave": 0,
	"forest": 0,
	"difu": 0
}

# 当前在关卡选择界面里选中的难度
var selected_stage_difficulty: String = STAGE_DIFFICULTY_SHALLOW
var selected_core_depth: int = CORE_DEPTH_MIN

# 当前真正进入战斗的关卡ID与难度
# 怪物配置会读这里，决定本次战斗应该套用哪一个倍率
var current_stage_id: String = ""
var current_stage_difficulty: String = STAGE_DIFFICULTY_SHALLOW
var current_core_depth: int = CORE_DEPTH_MIN
var corrupted_elite_enabled: bool = false
var stage_boss_fight_time: float = 0.0

@export var recipe_unlock_progress: Dictionary = {
	"recipe_001": true,
	"recipe_002": false,
	"recipe_003": false,
	"recipe_004": false,
	"recipe_noam": false,
	"recipe_028": true
}

# lunky概率
@export var lunky_level: int = 1
@export var red_p: float = 0.2
@export var gold_p: float = 4
@export var darkorchid_p: float = 20.5
@export var blue_p: float = 75

# 刷新次数
@export var refresh_max_num: int = INITIAL_REFRESH_BASE_NUM
@export var initial_lock_num: int = 1
@export var initial_ban_num: int = 3

# 修炼解锁进度Cultivation
@export var cultivation_unlock_progress: int = 0

# 装备系统相关
@export var max_carry_equipment_slots: int = 2 # 当前解锁的随身法宝槽位数量（初始2个，最大5个）

# 修炼等级变量
@export var cultivation_poxu_level: int = 0 # 破虚 - 提升攻击力
@export var cultivation_xuanyuan_level: int = 0 # 玄元 - 提升生命值
@export var cultivation_liuguang_level: int = 0 # 流光 - 提升攻速
@export var cultivation_hualing_level: int = 0 # 化灵 - 提升真气获取
@export var cultivation_fengrui_level: int = 0 # 锋锐 - 提升暴击率
@export var cultivation_huti_level: int = 0 # 护体 - 提升减伤率
@export var cultivation_zhuifeng_level: int = 0 # 追风 - 提升移速
@export var cultivation_liejin_level: int = 0 # 烈劲 - 提升暴击伤害
@export var cultivation_heyi_level: int = 0 # 合一 - 提升技能冷却
@export var cultivation_tongxiao_level: int = 0 # 通晓 - 提升最终伤害

# 修炼等级上限
@export var cultivation_poxu_level_max: int = 50
@export var cultivation_xuanyuan_level_max: int = 50
@export var cultivation_liuguang_level_max: int = 25
@export var cultivation_hualing_level_max: int = 50
@export var cultivation_fengrui_level_max: int = 25
@export var cultivation_huti_level_max: int = 25
@export var cultivation_zhuifeng_level_max: int = 25
@export var cultivation_liejin_level_max: int = 50

# 玩家修习技能数据
@export var player_study_data: Dictionary = {
	"yiqiu": {
		"study_level": 0,
		"learned_skills": [],
		"skill_levels": {}
	},
	"moning": {
		"study_level": 0,
		"learned_skills": [],
		"skill_levels": {}
	}
}

# 天赋树节点等级 { "weapon1-1": 0, "weapon2-2": 1, ... }
@export var player_study_tree: Dictionary = {}

# ---- 修习树 · 武器伤害加成（由 SettingStudyTreeUp.apply_all() 刷新）----
@export var study_main_weapon_damage_bonus: float = 0.0 # 主武器强化
@export var study_sword_damage_bonus: float = 0.0 # 刀剑系
@export var study_projectile_damage_bonus: float = 0.0 # 弹道系
@export var study_wind_damage_bonus: float = 0.0 # 啸风系
@export var study_wide_damage_bonus: float = 0.0 # 广域系
@export var study_life_damage_bonus: float = 0.0 # 生灵系
@export var study_destroy_damage_bonus: float = 0.0 # 破坏系
@export var study_fire_damage_bonus: float = 0.0 # 炽炎系
@export var study_protect_damage_bonus: float = 0.0 # 护佑系
@export var study_thunder_damage_bonus: float = 0.0 # 鸣雷系
@export var study_bagua_damage_bonus: float = 0.0 # 八卦系
@export var study_heal_damage_bonus: float = 0.0 # 治愈系
@export var study_treasure_damage_bonus: float = 0.0 # 宝器系
@export var study_blood_damage_bonus: float = 0.0 # 浴血系
@export var study_deep_damage_bonus: float = 0.0 # 沉渊系
@export var study_shehun_damage_bonus: float = 0.0 # 摄魂系

# ---- 修习树 · 武器解锁标记 ----
@export var study_unlock_qiankun: bool = true # 乾坤双剑
@export var study_unlock_dragonwind: bool = true # 风龙杖
@export var study_unlock_bloodwave: bool = true # 血气波
@export var study_unlock_water: bool = true # 坎水诀
@export var study_unlock_baoyan: bool = true # 爆炎诀
@export var study_unlock_genshan: bool = true # 艮山诀
@export var study_unlock_thunder_break: bool = true # 天雷破
@export var study_unlock_holylight: bool = true # 圣光术
@export var study_unlock_xuanwu: bool = true # 玄武盾

# ---- 修习树 · 技能篇加成（由 SettingStudyTreeSkill.apply_all() 刷新）----
# -- 技能解锁标记 --
@export var study_unlock_shouhua: bool = false # 兽化
@export var study_unlock_shensheng: bool = false # 神圣灼烧
@export var study_unlock_mowenzhen: bool = false # 魔纹阵
@export var study_unlock_xuanbing: bool = false # 玄冰
@export var study_unlock_luanji: bool = false # 乱击
@export var study_unlock_liaoshang: bool = false # 疗伤
@export var study_unlock_mizongbu: bool = false # 迷踪步
@export var study_unlock_shuimu: bool = false # 水幕护体
@export var study_unlock_mingxiang: bool = false # 冥想
@export var study_unlock_chiyan: bool = false # 炽炎
# -- 技能强化数值 --
@export var study_fengleipo_damage_bonus: float = 0.0 # 强化风雷破·伤害提升
@export var study_fengleipo_range_bonus: float = 0.0 # 强化风雷破·范围提升
@export var study_shouhua_duration_bonus: float = 0.0 # 强化兽化·持续时间
@export var study_shouhua_atkspeed_bonus: float = 0.0 # 强化兽化·攻速提升
@export var study_shensheng_duration_bonus: float = 0.0 # 强化神圣灼烧·持续时间
@export var study_shensheng_damage_bonus: float = 0.0 # 强化神圣灼烧·伤害提升
@export var study_mowenzhen_size_bonus: float = 0.0 # 强化魔纹阵·大小提升
@export var study_mowenzhen_cd_reduction: float = 0.0 # 强化魔纹阵·冷却减少
@export var study_xuanbing_size_bonus: float = 0.0 # 强化玄冰·大小提升
@export var study_xuanbing_damage_bonus: float = 0.0 # 强化玄冰·伤害提升
@export var study_liaoyu_recovery_bonus: float = 0.0 # 强化疗愈·回复提升
@export var study_liaoyu_cd_reduction: float = 0.0 # 强化疗愈·冷却减少
@export var study_luanji_count_bonus: int = 0 # 强化乱击·剑气数量
@export var study_luanji_damage_bonus: float = 0.0 # 强化乱击·伤害提升
@export var study_mizongbu_duration_bonus: float = 0.0 # 强化迷踪步·持续时间
@export var study_mizongbu_dmgreduction_bonus: float = 0.0 # 强化迷踪步·减伤率
@export var study_shuimu_shield_bonus: float = 0.0 # 强化水幕护体·护盾提升
@export var study_shuimu_cd_reduction: float = 0.0 # 强化水幕护体·冷却减少
@export var study_mingxiang_cd_reduction: float = 0.0 # 强化冥想·冷却减少
@export var study_shanbi_invincible_bonus: float = 0.0 # 强化闪避·无敌时间
@export var study_shanbi_cd_reduction: float = 0.0 # 强化闪避·冷却减少
@export var study_chiyan_enhance_damage_bonus: float = 0.0 # 强化炽炎·伤害提升

# ---- 修习树 · 领悟篇加成（由 SettingStudyTreeLearn.apply_all() 刷新）----
@export var study_emblem_effect_bonus: float = 0.0 # 纹章效果提升
@export var study_initial_lucky: int = 0 # 初始天命提升
@export var study_summon_damage_bonus: float = 0.0 # 唤灵系伤害提升
@export var study_summon_interval_reduction: float = 0.0 # 唤灵系攻击间隔缩短
@export var study_emblem_slots_bonus: int = 0 # 纹章栏位增加
@export var study_exp_bonus: float = 0.0 # 经验获取提升
@export var study_exp_reduction: float = 0.0 # 升级经验降低
@export var study_six_chance_bonus: float = 0.0 # 六识系出现概率提升
@export var study_red_chance_bonus: float = 0.0 # 逆天概率提升
@export var study_gold_chance_bonus: float = 0.0 # 臻境概率提升
@export var study_purple_chance_bonus: float = 0.0 # 悟道概率提升

# ---- 修习树 · 团队篇加成（由 SettingStudyTreeTeam.apply_all() 刷新）----
@export var study_atk_bonus: float = 0.0 # 攻击提升
@export var study_hp_bonus: int = 0 # HP提升
@export var study_atk_speed_bonus: float = 0.0 # 攻速提升
@export var study_move_speed_bonus: float = 0.0 # 移速提升
@export var study_crit_rate_bonus: float = 0.0 # 暴击率提升
@export var study_crit_damage_bonus: float = 0.0 # 暴击伤害提升
@export var study_qi_gain_bonus: float = 0.0 # 真气获取率提升
@export var study_damage_reduction_bonus: float = 0.0 # 减伤率提升
@export var study_final_damage_bonus: float = 0.0 # 最终伤害提升
@export var study_normal_monster_damage_bonus: float = 0.0 # 对小怪伤害提升
@export var study_elite_damage_bonus: float = 0.0 # 对精英首领伤害提升
@export var study_drop_rate_bonus: float = 0.0 # 掉落率提升

# ---- 修习树 · 特殊篇加成（由 SettingStudyTreeSpecial.apply_all() 刷新）----
@export var study_heal_aura_recovery_bonus: float = 0.0 # 治愈灵气回复量提升
@export var study_heal_aura_spawn_chance: float = 0.0 # 治愈灵气出现概率提升
@export var study_heal_aura_speed_bonus: float = 0.0 # 治愈灵气拾取后移速提升
@export var study_heal_aura_damage_reduction: float = 0.0 # 治愈灵气拾取后减伤提升
@export var study_fragment_drop_chance: float = 0.0 # 灵髓碎片出现概率提升
@export var study_boss_core_drop_chance: float = 0.0 # boss掉落魔核概率提升
@export var study_levelup_heal_bonus: float = 0.0 # 升级后回复体力量提升
@export var study_levelup_atk_bonus: int = 0 # 升级后额外攻击
@export var study_levelup_hp_bonus: int = 0 # 升级后额外HP
@export var study_gold_ball_unlocked: bool = false # 金团团解锁
@export var study_gold_ball_chance_bonus: float = 0.0 # 金团团出现概率提升
@export var study_gold_ball_qi_bonus: float = 0.0 # 金团团掉落真气量提升

@export var player_active_skill_data: Dictionary = {
	"dodge": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shanbi.png"
	},
	"mizongbu": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/mizongbu.png"
	},
	"random_strike": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/luanji.png"
	},
	"beastify": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shouhua.png"
	},
	"heal_hot": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/yuliao.png"
	},
	"water_sheild": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shuiliumu.png"
	},
	"holy_fire": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shenshengzhuoshao.png"
	},
	"wind_thunder": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/fengleipo.png"
	},
	"magical_ice": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/binghua.png"
	},
	"magical_fire": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/RingFire.png"
	},
	"magic": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/mowenzhen.png"
	},
	"meditation": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/meditation.png"
	},
	"destructive_hammer": {
		"level": 1,
		"learned": [],
		"icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/juchui.png"
	}
}


@export var player_now_active_skill: Dictionary = {
	"moning": {"space": {"name": "dodge"}, "q": {"name": "wind_thunder"}, "e": {"name": ""}},
	"yiqiu": {"space": {"name": "dodge"}, "q": {"name": "beastify"}, "e": {"name": ""}},
	"noam": {"space": {"name": "dodge"}, "q": {"name": "heal_hot"}, "e": {"name": ""}},
	"kansel": {"space": {"name": "dodge"}, "q": {"name": "magical_fire"}, "e": {"name": ""}},
	"xueming": {"space": {"name": "dodge"}, "q": {"name": "destructive_hammer"}, "e": {"name": ""}}
}

@export var selected_start_weapon: String = "SwordQi"
@export var selected_start_weapons_by_hero: Dictionary = {}
@export var available_start_weapons: Array[String] = [
	"SwordQi",
	"Qigong"
]

# 世界等级
@export var world_level_multiple: float = 1
@export var world_level_reward_multiple: float = 1
@export var world_level: int = 1

@export var in_menu: bool = true
@export var in_town: bool = false
@export var is_level_up: bool = false
@export var main_menu_instance: PackedScene = null

func is_battle_time_paused() -> bool:
	var tree := get_tree()
	return is_level_up or (tree != null and tree.paused)

@export var has_visited_town: bool = false
@export var is_first_game: bool = true
@export var has_seen_battle_tutorial: bool = false
@export var has_seen_town_tutorial: bool = false
@export var has_seen_peach_grove_dialogue: bool = false
@export var has_seen_peach_grove_boss: bool = false
@export var has_seen_peach_grove_boss_charge: bool = false
@export var has_seen_ruin_boss: bool = false
@export var has_seen_cave_boss: bool = false
@export var has_seen_forest_boss: bool = false
@export var has_defeated_peach_grove_boss: bool = false # 是否击败了桃林boss
@export var town_companion_dialogue_history: Dictionary = {}

# 全局失败次数计数
@export var total_defeat_count: int = 0

# 首次离开peach_grove后进入story_2
@export var has_seen_story_2: bool = false

# 累计失败2次后进入story_3（炼丹炉解锁剧情）
@export var has_seen_story_3: bool = false

# 累计失败3次后进入story_4（神秘商铺解锁剧情）
@export var has_seen_story_4: bool = false

# 炼丹炉教程（看完story3回到main_town后触发）
@export var has_seen_liandan_tutorial: bool = false

# 神秘商铺教程（看完story4回到main_town后触发）
@export var has_seen_shop_tutorial: bool = false

# 诗想难度教程（看完story8回到main_town后触发）
@export var has_seen_poem_tutorial: bool = false

# 灵气漩涡教程（第一次在关卡中出现灵气漩涡后触发）
@export var has_seen_qi_vortex_tutorial: bool = false

# 首次通关ruin后进入story_5（诺姆解锁剧情）
@export var has_seen_story_5: bool = false
@export var has_seen_story_6: bool = false

# 首次通关cave后进入story_7（坎塞尔解锁剧情）
@export var has_seen_story_7: bool = false
@export var has_seen_story_8: bool = false
@export var has_received_story_6_magic_core_reward: bool = false

# 信号定义
@warning_ignore("unused_signal")
signal player_hit(damage_val: float, shield_val: float, attacker: Node2D, world_position: Vector2, source_name: String)
@warning_ignore("unused_signal")
signal player_hit_ignore_invincible(damage_val: float, shield_val: float, attacker: Node2D, world_position: Vector2, source_name: String)
@warning_ignore("unused_signal")
signal player_instakill(attacker: Node2D, world_position: Vector2, source_name: String)
@warning_ignore("unused_signal")
signal player_lv_up
@warning_ignore("unused_signal")
signal lucky_level_up
@warning_ignore("unused_signal")
signal setup_summons
@warning_ignore("unused_signal")
signal level_up_selection_complete
@warning_ignore("unused_signal")
signal manual_level_up_pending
@warning_ignore("unused_signal")
signal mobile_input_reset_requested
signal mobile_input_restore_requested
@warning_ignore("unused_signal")
signal player_heal
@warning_ignore("unused_signal")
signal monster_damage
@warning_ignore("unused_signal")
@warning_ignore("unused_signal")
signal monster_killed
@warning_ignore("unused_signal")
signal boss_defeated(get_point: int, boss_position: Vector2)
@warning_ignore("unused_signal")
signal skill_attack_speed_updated
@warning_ignore("unused_signal")
signal start_dialog(dialog_file_path: String)
@warning_ignore("unused_signal")
signal stage_bgm(stage_id: String)
@warning_ignore("unused_signal")
signal stage_ambient(stage_id: String)
@warning_ignore("unused_signal")
signal stop_ambient
@warning_ignore("unused_signal")
signal zoom_camera
@warning_ignore("unused_signal")
signal reset_camera
@warning_ignore("unused_signal")
signal boss_hp_bar_show
@warning_ignore("unused_signal")
signal boss_hp_bar_hide
@warning_ignore("unused_signal")
signal boss_hp_bar_initialize(max_hp: float, current_hp: float, bar_num: int)
@warning_ignore("unused_signal")
signal boss_hp_bar_take_damage(damage: float)
@warning_ignore("unused_signal")
signal boss_chant_start(skill_display_name: String, chant_duration: float)
@warning_ignore("unused_signal")
signal boss_chant_end
@warning_ignore("unused_signal")
signal player_chant_start(skill_display_name: String, chant_duration: float, icon_path: String)
@warning_ignore("unused_signal")
signal player_chant_end
@warning_ignore("unused_signal")
signal buff_added(buff_id: String, duration: float, stack: int)
@warning_ignore("unused_signal")
signal buff_removed(buff_id: String)
@warning_ignore("unused_signal")
signal buff_updated(buff_id: String, remaining_time: float, stack: int)
@warning_ignore("unused_signal")
signal buff_stack_changed(buff_id: String, new_stack: int)
@warning_ignore("unused_signal")
signal boss_buff_added(buff_id: String, display_name: String, icon_path: String, duration: float, stack: int, is_permanent: bool, description: String)
@warning_ignore("unused_signal")
signal boss_buff_removed(buff_id: String)
@warning_ignore("unused_signal")
signal boss_buff_updated(buff_id: String, remaining_time: float, stack: int)
@warning_ignore("unused_signal")
signal emblem_added(emblem_id: String, stack: int)
@warning_ignore("unused_signal")
signal emblem_removed(emblem_id: String)
@warning_ignore("unused_signal")
signal emblem_stack_changed(emblem_id: String, new_stack: int)
@warning_ignore("unused_signal")
signal skill_cooldown_complete
@warning_ignore("unused_signal")
signal skill_cooldown_complete_branch
@warning_ignore("unused_signal")
signal skill_cooldown_complete_moyan
@warning_ignore("unused_signal")
signal skill_cooldown_complete_riyan
@warning_ignore("unused_signal")
signal skill_cooldown_complete_ringFire
@warning_ignore("unused_signal")
signal skill_cooldown_complete_thunder
@warning_ignore("unused_signal")
signal skill_cooldown_complete_bloodwave
@warning_ignore("unused_signal")
signal skill_cooldown_complete_bloodboardsword
@warning_ignore("unused_signal")
signal skill_cooldown_complete_ice
@warning_ignore("unused_signal")
signal skill_cooldown_complete_thunder_break
@warning_ignore("unused_signal")
signal skill_cooldown_complete_light_bullet
@warning_ignore("unused_signal")
signal skill_cooldown_complete_water
@warning_ignore("unused_signal")
signal skill_cooldown_complete_qiankun
@warning_ignore("unused_signal")
signal skill_cooldown_complete_xuanwu
@warning_ignore("unused_signal")
signal skill_cooldown_complete_xunfeng
@warning_ignore("unused_signal")
signal skill_cooldown_complete_genshan
@warning_ignore("unused_signal")
signal skill_cooldown_complete_duize
@warning_ignore("unused_signal")
signal skill_cooldown_complete_holylight(skill_id)
@warning_ignore("unused_signal")
signal skill_cooldown_complete_qigong(skill_id)
@warning_ignore("unused_signal")
signal skill_cooldown_complete_dragonwind(skill_id)
@warning_ignore("unused_signal")
signal skill_cooldown_complete_zhuazhuajuchui(skill_id)
@warning_ignore("unused_signal")
signal skill_cooldown_complete_soul_sickle(skill_id)
@warning_ignore("unused_signal")
signal skill_cooldown_complete_thunder_gun(skill_id)
@warning_ignore("unused_signal")
signal riyan_damage_triggered
@warning_ignore("unused_signal")
signal ringFire_damage_triggered
@warning_ignore("unused_signal")
signal createSwordWave
@warning_ignore("unused_signal")
signal _fire_ring_bullets
@warning_ignore("unused_signal")
signal drop_out_item(item_id: String, quantity: int, position: Vector2)
@warning_ignore("unused_signal")
signal drop_exp_orb(exp_value: int, position: Vector2, is_elite: bool)
@warning_ignore("unused_signal")
signal press_f
@warning_ignore("unused_signal")
signal press_g
@warning_ignore("unused_signal")
signal press_h
@warning_ignore("unused_signal")
signal dps_updated(total_dps: float, weapon_dps: Dictionary)
@warning_ignore("unused_signal")
signal teammate_dialogue(speaker: String, text: String)
@warning_ignore("unused_signal")
signal input_device_mode_changed(mode: String)

# --------------------------
# --- DPS 计数逻辑 ---
const DPS_WINDOW_SECONDS: int = 30
const DPS_SINGLE_TARGET_KILL_COUNT_EXPONENT: float = 0.65
const DPS_TEST_MIN_DISPLAY_SECONDS: float = 1.0
const DPS_DETAIL_CATEGORY_WEAPON: String = "weapon"
const DPS_DETAIL_CATEGORY_DEBUFF: String = "debuff"
const DPS_DETAIL_CATEGORY_ACTIVE_SKILL: String = "active_skill"
const DPS_DETAIL_CATEGORY_FAZE: String = "faze"
const DPS_DETAIL_CATEGORY_OTHER: String = "other"
const DPS_DETAIL_DEFAULT_ICON: String = "res://AssetBundle/Sprites/Sprite sheets/skillIcon/jianqi.png"
const DPS_DETAIL_OTHER_ICON: String = "res://AssetBundle/Sprites/Sprite sheets/skillIcon/suming.png"
const DPS_DETAIL_DEBUFF_SOURCES: Dictionary = {
	"burn": {"name": "燃烧", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/zhuoshao.png"},
	"electrified": {"name": "感电", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/lilei.png"},
	"bleed": {"name": "流血", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/xueqi.png"},
}
const DPS_DETAIL_ACTIVE_SKILL_SOURCES: Dictionary = {
	"wind_thunder": {"name": "风雷破", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/fengleipo.png"},
	"magical_ice": {"name": "玄冰", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/binghua.png"},
	"magical_fire": {"name": "炽炎", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/RingFire.png"},
	"holy_fire": {"name": "神圣灼烧", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shenshengzhuoshao.png"},
	"heal_hot": {"name": "疗愈", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/liaoyu.png"},
	"water_sheild": {"name": "水幕护体", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shuimu.png"},
	"random_strike": {"name": "乱击", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/luanji.png"},
	"beastify": {"name": "兽化", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shouhua.png"},
	"destructive_hammer": {"name": "破坏圣锤", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/juchui.png"},
	"zhuazhuajuchui": {"name": "爪爪巨锤", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/zhuazhuachui.png"},
	"soul_sickle": {"name": "噬魂镰", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shihunlian.png"},
	"thunder_gun": {"name": "雷魂枪", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_thunder.png"},
	"summon": {"name": "唤物", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/huanwu.png"},
	"reflection": {"name": "反伤", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/tiegu.png"},
	"hp_regen": {"name": "生命恢复", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shengshengbuxi.png"},
	"pain_relief": {"name": "痛楚减弱", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shanghen.png"},
}
const ACTIVE_SKILL_STUDY_LEVEL_NODES: Dictionary = {
	"mizongbu": "skill2-1-1",
	"beastify": "skill2-2-1",
	"holy_fire": "skill2-3-1",
	"magic": "skill2-4-1",
	"magical_ice": "skill2-5-1",
	"random_strike": "skill2-6-1",
	"heal_hot": "skill2-7-1",
	"water_sheild": "skill2-8-1",
	"dodge": "skill2-8-2",
	"meditation": "skill2-9-1",
	"wind_thunder": "skill2-9-2",
	"magical_fire": "skill2-10-1",
}
const DPS_DETAIL_FAZE_SOURCES: Dictionary = {
	"faze_rain": {"name": "弹雨法则", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_bullet.png"},
	"faze_sword_coldlight": {"name": "刀剑法则", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_sword.png"},
	"faze_bath_blood_thud": {"name": "浴血法则", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_blood.png"},
	"faze_thunder_strike": {"name": "鸣雷法则", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_thunder.png"},
	"faze_destory_detonation": {"name": "破坏法则", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_destory.png"},
	"faze_heal": {"name": "愈疗法则", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_heal.png"},
	"faze_sacred_light": {"name": "生灵法则", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/faze_life.png"},
	"faze_deep": {"name": "沉渊法则", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/buff_chenyuan.png"},
	"faze_shehun": {"name": "摄魂法则", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/buff_shehun.png"},
}
const DPS_DETAIL_FAZE_ICON_BY_KEY: Dictionary = {
	"bagua": "faze_bagua",
	"blood": "faze_blood",
	"bullet": "faze_bullet",
	"rain": "faze_bullet",
	"chaos": "faze_chaos",
	"destroy": "faze_destory",
	"destory": "faze_destory",
	"fire": "faze_fire",
	"heal": "faze_heal",
	"sacred": "faze_life",
	"sacred_light": "faze_life",
	"life": "faze_life",
	"shield": "faze_sheild",
	"sheild": "faze_sheild",
	"six": "faze_liushi",
	"sixsense": "faze_liushi",
	"liushi": "faze_liushi",
	"skill": "faze_skill",
	"summon": "faze_summon",
	"sword": "faze_sword",
	"thunder": "faze_thunder",
	"treasure": "faze_treasure",
	"deep": "buff_chenyuan",
	"shehun": "buff_shehun",
	"wide": "faze_wide",
	"wind": "faze_wind",
}
const DPS_DETAIL_WEAPON_SOURCES: Dictionary = {
	"swordqi": {"name": "剑气诀", "reward_id": "SwordQi", "icon": "jianqi"},
	"branch": {"name": "仙枝", "reward_id": "Branch", "icon": "xianzhi"},
	"moyan": {"name": "爆炎诀", "reward_id": "Moyan", "icon": "yunshi"},
	"ringfire": {"name": "离火诀", "reward_id": "RingFire", "icon": "lihuo"},
	"riyan": {"name": "赤曜", "reward_id": "Riyan", "icon": "riyan"},
	"thunder": {"name": "震雷诀", "reward_id": "Thunder", "icon": "thunder"},
	"blood_wave": {"name": "血气波", "reward_id": "Bloodwave", "icon": "xueqibo"},
	"bloodwave": {"name": "血气波", "reward_id": "Bloodwave", "icon": "xueqibo"},
	"blood_broadsword": {"name": "饮血刀", "reward_id": "BloodBoardSword", "icon": "yinxue"},
	"bloodboardsword": {"name": "饮血刀", "reward_id": "BloodBoardSword", "icon": "yinxue"},
	"ice_flower": {"name": "冰刺术", "reward_id": "Ice", "icon": "binghua"},
	"ice": {"name": "冰刺术", "reward_id": "Ice", "icon": "binghua"},
	"thunder_break": {"name": "天雷破", "reward_id": "ThunderBreak", "icon": "tianleipo2"},
	"light_bullet": {"name": "光弹术", "reward_id": "LightBullet", "icon": "guangdan"},
	"water": {"name": "坎水诀", "reward_id": "Water", "icon": "kanshui"},
	"qiankun": {"name": "乾坤双剑", "reward_id": "Qiankun", "icon": "qiankun"},
	"xuanwu": {"name": "玄武盾", "reward_id": "Xuanwu", "icon": "xuanwu"},
	"xunfeng": {"name": "巽风诀", "reward_id": "Xunfeng", "icon": "xunfeng"},
	"genshan": {"name": "艮山诀", "reward_id": "Genshan", "icon": "genshan"},
	"duize": {"name": "兑泽诀", "reward_id": "Duize", "icon": "duize"},
	"holylight": {"name": "圣光术", "reward_id": "HolyLight", "icon": "shenshengzhuoshao"},
	"qigong": {"name": "气功波", "reward_id": "Qigong", "icon": "qigong"},
	"dragonwind": {"name": "风龙杖", "reward_id": "DragonWind", "icon": "fenglongzhang"},
}
var dps_damage_buckets: Array = []
var dps_potential_damage_buckets: Array = []
@export var current_dps: float = 0.0
var current_boss_scaling_dps: float = 0.0
var current_dps_window_kill_count: int = 0
var highest_dps: float = 0.0
var weapon_dps: Dictionary = {}
var dps_detail_source_dps: Dictionary = {}
var heal_shield_buckets: Array = []
var heal_shield_detail_source_rates: Dictionary = {}
var dps_timer: Timer
var dps_test_timer_active: bool = false
var dps_test_timer_started: bool = false
var dps_test_start_msec: int = 0
var dps_test_start_battle_time: float = 0.0
var dps_test_elapsed_seconds: float = 0.0
var dps_test_total_damage: float = 0.0
var dps_test_source_totals: Dictionary = {}
var heal_shield_test_total: float = 0.0
var heal_shield_test_source_totals: Dictionary = {}
var dps_test_last_total_dps: float = 0.0

# 显示配置
@export var damage_show_type: int = 2
@export var damage_show_enabled: bool = true
@export var particle_enable: bool = true
@export var moretip: bool = true
@export var screen_shake_enabled: bool = true

const MORETIP_OUTLINE_TARGET_GROUP := "moretip_outline_targets"

func set_moretip_enabled(enabled: bool) -> void:
	moretip = enabled
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group(MORETIP_OUTLINE_TARGET_GROUP):
		if is_instance_valid(node) and node.has_method("set_outline_enabled"):
			node.set_outline_enabled(enabled)

const DAMAGE_LABEL_POOL_SIZE: int = 400
const MAX_DAMAGE_LABELS: int = DAMAGE_LABEL_POOL_SIZE
const MAX_DAMAGE_LABELS_PER_FRAME: int = 72
const MAX_DOT_DAMAGE_LABELS_PER_FRAME: int = 36
const DAMAGE_LABEL_FLUSH_PER_FRAME: int = 72
const DAMAGE_LABEL_QUEUE_MAX_KEYS: int = 256
const DAMAGE_LABEL_AGGREGATE_CELL_SIZE: float = 24.0
const FROG_ATTACK_POOL_SIZE: int = 120
const FROG_ATTACK_ACTIVE_CAP: int = 9999
const PERF_STUTTER_FRAME_MS: int = 240
const PERF_STUTTER_FPS: float = 25.0
const PERF_STUTTER_LOG_INTERVAL_MS: int = 1000
var _damage_label_frame: int = -1
var _damage_label_count_this_frame: int = 0
var _dot_damage_label_count_this_frame: int = 0
var _damage_label_drop_total_limit: int = 0
var _damage_label_drop_frame_limit: int = 0
var _damage_label_queue: Dictionary = {}
var _last_perf_probe_msec: int = 0
var _damage_label_scene = preload("res://Scenes/global/damage.tscn")

# 对象池 —— 减少高频 instantiate/queue_free 的 GC 开销
var damage_label_pool: ObjectPool
var rain_bullet_pool: ObjectPool
var light_bullet_pool: ObjectPool
var ice_flower_pool: ObjectPool
var branch_pool: ObjectPool
var frog_attack_pool: ObjectPool
var debuff_burn_pool: ObjectPool
var faze_bath_blood_thud_pool: ObjectPool
var faze_thunder_pool: ObjectPool
var faze_destory_pool: ObjectPool
var faze_light_pool: ObjectPool

func _init_dps_counter() -> void:
	_reset_dps_buckets()
	_reset_dps_potential_buckets()
	_reset_heal_shield_buckets()
	dps_timer = Timer.new()
	dps_timer.wait_time = 1.0
	dps_timer.timeout.connect(_calculate_dps)
	dps_timer.autostart = true
	add_child(dps_timer)

func record_damage_for_dps(damage: float, weapon_name: String = "Unknown") -> void:
	if damage <= 0.0:
		return
	var current_second: int = _get_dps_battle_second()
	_ensure_dps_buckets()
	var bucket_index: int = current_second % DPS_WINDOW_SECONDS
	var bucket: Dictionary = dps_damage_buckets[bucket_index]
	if int(bucket.get("second", -1)) != current_second:
		bucket["second"] = current_second
		bucket["total"] = 0.0
		bucket["weapons"] = {}
		bucket["details"] = {}
	bucket["total"] = float(bucket.get("total", 0.0)) + damage
	var weapons: Dictionary = bucket.get("weapons", {})
	weapons[weapon_name] = float(weapons.get(weapon_name, 0.0)) + damage
	bucket["weapons"] = weapons
	_record_dps_detail_damage(bucket, damage, weapon_name)
	_record_dps_test_damage(damage, weapon_name)

func record_potential_damage_for_boss_dps(damage: float) -> void:
	if damage <= 0.0:
		return
	var current_second: int = _get_dps_battle_second()
	_ensure_dps_potential_buckets()
	var bucket_index: int = current_second % DPS_WINDOW_SECONDS
	var bucket: Dictionary = dps_potential_damage_buckets[bucket_index]
	if int(bucket.get("second", -1)) != current_second:
		bucket["second"] = current_second
		bucket["total"] = 0.0
	bucket["total"] = float(bucket.get("total", 0.0)) + damage

func record_kill_for_dps() -> void:
	var current_second: int = _get_dps_battle_second()
	_ensure_dps_buckets()
	var bucket_index: int = current_second % DPS_WINDOW_SECONDS
	var bucket: Dictionary = dps_damage_buckets[bucket_index]
	if int(bucket.get("second", -1)) != current_second:
		bucket["second"] = current_second
		bucket["total"] = 0.0
		bucket["weapons"] = {}
		bucket["details"] = {}
		bucket["kills"] = 0
	bucket["kills"] = int(bucket.get("kills", 0)) + 1

func _record_dps_detail_damage(bucket: Dictionary, damage: float, source_id: String) -> void:
	var source_info: Dictionary = _get_dps_source_info(source_id)
	var detail_key: String = str(source_info.get("key", source_id))
	var details: Dictionary = bucket.get("details", {})
	if not details.has(detail_key):
		details[detail_key] = {
			"key": detail_key,
			"source_id": source_id,
			"name": str(source_info.get("name", source_id)),
			"category": str(source_info.get("category", DPS_DETAIL_CATEGORY_OTHER)),
			"icon": str(source_info.get("icon", DPS_DETAIL_DEFAULT_ICON)),
			"damage": 0.0,
		}
	var entry: Dictionary = details[detail_key]
	entry["damage"] = float(entry.get("damage", 0.0)) + damage
	details[detail_key] = entry
	bucket["details"] = details

func _calculate_dps() -> void:
	var current_second: int = _get_dps_battle_second()
	var first_second: int = current_second - DPS_WINDOW_SECONDS + 1
	var total_damage: float = 0.0
	var total_potential_damage: float = 0.0
	var total_kills: int = 0
	var weapon_totals: Dictionary = {}
	var detail_totals: Dictionary = {}
	_ensure_dps_buckets()
	_ensure_dps_potential_buckets()
	for bucket in dps_damage_buckets:
		var bucket_second: int = int(bucket.get("second", -1))
		if bucket_second < first_second or bucket_second > current_second:
			continue
		total_damage += float(bucket.get("total", 0.0))
		total_kills += int(bucket.get("kills", 0))
		var weapons: Dictionary = bucket.get("weapons", {})
		for w_name in weapons:
			weapon_totals[w_name] = weapon_totals.get(w_name, 0.0) + float(weapons[w_name])
		var details: Dictionary = bucket.get("details", {})
		for detail_key in details:
			var detail_entry: Dictionary = details[detail_key]
			if not detail_totals.has(detail_key):
				detail_totals[detail_key] = detail_entry.duplicate(true)
				detail_totals[detail_key]["damage"] = 0.0
			detail_totals[detail_key]["damage"] = float(detail_totals[detail_key].get("damage", 0.0)) + float(detail_entry.get("damage", 0.0))
	for bucket in dps_potential_damage_buckets:
		var bucket_second: int = int(bucket.get("second", -1))
		if bucket_second < first_second or bucket_second > current_second:
			continue
		total_potential_damage += float(bucket.get("total", 0.0))
	current_dps = total_damage / float(DPS_WINDOW_SECONDS)
	current_boss_scaling_dps = maxf(current_dps, total_potential_damage / float(DPS_WINDOW_SECONDS))
	current_dps_window_kill_count = total_kills
	highest_dps = max(highest_dps, current_dps)
	weapon_dps.clear()
	for w_name in weapon_totals:
		weapon_dps[w_name] = weapon_totals[w_name] / float(DPS_WINDOW_SECONDS)
	dps_detail_source_dps.clear()
	for detail_key in detail_totals:
		var detail: Dictionary = detail_totals[detail_key]
		detail["dps"] = float(detail.get("damage", 0.0)) / float(DPS_WINDOW_SECONDS)
		dps_detail_source_dps[detail_key] = detail
	emit_signal("dps_updated", current_dps, weapon_dps)

func refresh_dps_counter() -> void:
	_calculate_dps()

func _ensure_dps_buckets() -> void:
	if dps_damage_buckets.size() == DPS_WINDOW_SECONDS:
		return
	_reset_dps_buckets()

func _ensure_dps_potential_buckets() -> void:
	if dps_potential_damage_buckets.size() == DPS_WINDOW_SECONDS:
		return
	_reset_dps_potential_buckets()

func _reset_dps_buckets() -> void:
	dps_damage_buckets.clear()
	for i in range(DPS_WINDOW_SECONDS):
		dps_damage_buckets.append({"second": - 1, "total": 0.0, "weapons": {}, "details": {}, "kills": 0})

func _reset_dps_potential_buckets() -> void:
	dps_potential_damage_buckets.clear()
	for i in range(DPS_WINDOW_SECONDS):
		dps_potential_damage_buckets.append({"second": - 1, "total": 0.0})

func record_heal_shield_for_stats(kind: String, amount: float, source_id: String = "unknown") -> void:
	if amount <= 0.0:
		return
	if _should_ignore_heal_shield_source(source_id):
		return
	var normalized_kind: String = "shield" if kind == "shield" else "heal"
	var current_second: int = _get_dps_battle_second()
	_ensure_heal_shield_buckets()
	var bucket_index: int = current_second % DPS_WINDOW_SECONDS
	var bucket: Dictionary = heal_shield_buckets[bucket_index]
	if int(bucket.get("second", -1)) != current_second:
		bucket["second"] = current_second
		bucket["total"] = 0.0
		bucket["details"] = {}
	bucket["total"] = float(bucket.get("total", 0.0)) + amount
	_record_heal_shield_detail(bucket, normalized_kind, amount, source_id)
	_record_heal_shield_test_value(normalized_kind, amount, source_id)

func _should_ignore_heal_shield_source(source_id: String) -> bool:
	var normalized: String = _normalize_dps_source_id(source_id)
	return normalized == "heal_aura" or normalized == "qi_vortex" or normalized == "boss_cansel"

func _record_heal_shield_detail(bucket: Dictionary, kind: String, amount: float, source_id: String) -> void:
	var source_info: Dictionary = _get_heal_shield_source_info(source_id)
	var detail_key: String = str(source_info.get("key", source_id))
	var details: Dictionary = bucket.get("details", {})
	if not details.has(detail_key):
		details[detail_key] = {
			"key": detail_key,
			"source_id": source_id,
			"name": str(source_info.get("name", source_id)),
			"category": str(source_info.get("category", DPS_DETAIL_CATEGORY_OTHER)),
			"icon": str(source_info.get("icon", DPS_DETAIL_DEFAULT_ICON)),
			"heal": 0.0,
			"shield": 0.0,
			"total": 0.0,
		}
	var entry: Dictionary = details[detail_key]
	entry[kind] = float(entry.get(kind, 0.0)) + amount
	entry["total"] = float(entry.get("heal", 0.0)) + float(entry.get("shield", 0.0))
	details[detail_key] = entry
	bucket["details"] = details

func _ensure_heal_shield_buckets() -> void:
	if heal_shield_buckets.size() == DPS_WINDOW_SECONDS:
		return
	_reset_heal_shield_buckets()

func _reset_heal_shield_buckets() -> void:
	heal_shield_buckets.clear()
	for i in range(DPS_WINDOW_SECONDS):
		heal_shield_buckets.append({"second": - 1, "total": 0.0, "details": {}})

func _calculate_heal_shield_rates() -> void:
	var current_second: int = _get_dps_battle_second()
	var first_second: int = current_second - DPS_WINDOW_SECONDS + 1
	var detail_totals: Dictionary = {}
	_ensure_heal_shield_buckets()
	for bucket in heal_shield_buckets:
		var bucket_second: int = int(bucket.get("second", -1))
		if bucket_second < first_second or bucket_second > current_second:
			continue
		var details: Dictionary = bucket.get("details", {})
		for detail_key in details:
			var detail_entry: Dictionary = details[detail_key]
			if not detail_totals.has(detail_key):
				detail_totals[detail_key] = detail_entry.duplicate(true)
				detail_totals[detail_key]["heal"] = 0.0
				detail_totals[detail_key]["shield"] = 0.0
				detail_totals[detail_key]["total"] = 0.0
			detail_totals[detail_key]["heal"] = float(detail_totals[detail_key].get("heal", 0.0)) + float(detail_entry.get("heal", 0.0))
			detail_totals[detail_key]["shield"] = float(detail_totals[detail_key].get("shield", 0.0)) + float(detail_entry.get("shield", 0.0))
			detail_totals[detail_key]["total"] = float(detail_totals[detail_key].get("heal", 0.0)) + float(detail_totals[detail_key].get("shield", 0.0))
	heal_shield_detail_source_rates.clear()
	for detail_key in detail_totals:
		var detail: Dictionary = detail_totals[detail_key]
		detail["rate"] = float(detail.get("total", 0.0)) / float(DPS_WINDOW_SECONDS)
		detail["heal_rate"] = float(detail.get("heal", 0.0)) / float(DPS_WINDOW_SECONDS)
		detail["shield_rate"] = float(detail.get("shield", 0.0)) / float(DPS_WINDOW_SECONDS)
		heal_shield_detail_source_rates[detail_key] = detail

func _get_dps_time_source() -> float:
	return maxf(0.0, float(PC.real_time))

func _get_dps_battle_second() -> int:
	return int(floor(_get_dps_time_source()))

# ---------------------------------

func _get_dps_source_info(source_id: String) -> Dictionary:
	var normalized: String = _normalize_dps_source_id(source_id)
	if DPS_DETAIL_DEBUFF_SOURCES.has(normalized):
		var info: Dictionary = DPS_DETAIL_DEBUFF_SOURCES[normalized].duplicate(true)
		info["key"] = "debuff:" + normalized
		info["category"] = DPS_DETAIL_CATEGORY_DEBUFF
		return info
	if DPS_DETAIL_ACTIVE_SKILL_SOURCES.has(normalized):
		var skill_info: Dictionary = DPS_DETAIL_ACTIVE_SKILL_SOURCES[normalized].duplicate(true)
		skill_info["key"] = "active_skill:" + normalized
		skill_info["category"] = DPS_DETAIL_CATEGORY_ACTIVE_SKILL
		return skill_info
	if DPS_DETAIL_FAZE_SOURCES.has(normalized):
		var faze_info: Dictionary = DPS_DETAIL_FAZE_SOURCES[normalized].duplicate(true)
		faze_info["key"] = "faze:" + normalized
		faze_info["category"] = DPS_DETAIL_CATEGORY_FAZE
		return faze_info
	if normalized.begins_with("faze_"):
		return {
			"key": "faze:" + normalized,
			"name": "法则伤害",
			"category": DPS_DETAIL_CATEGORY_FAZE,
			"icon": _resolve_dps_faze_icon_path(normalized),
		}
	if DPS_DETAIL_WEAPON_SOURCES.has(normalized):
		var weapon_info: Dictionary = DPS_DETAIL_WEAPON_SOURCES[normalized].duplicate(true)
		var icon_path: String = _resolve_dps_icon_path(str(weapon_info.get("icon", "")), str(weapon_info.get("reward_id", "")))
		weapon_info["key"] = "weapon:" + normalized
		weapon_info["category"] = DPS_DETAIL_CATEGORY_WEAPON
		weapon_info["icon"] = icon_path
		return weapon_info
	if normalized == "" or normalized == "unknown":
		return {
			"key": "other:unknown",
			"name": "其他来源",
			"category": DPS_DETAIL_CATEGORY_OTHER,
			"icon": DPS_DETAIL_OTHER_ICON,
		}
	return {
		"key": "weapon:" + normalized,
		"name": source_id,
		"category": DPS_DETAIL_CATEGORY_WEAPON,
		"icon": DPS_DETAIL_DEFAULT_ICON,
	}

func _get_heal_shield_source_info(source_id: String) -> Dictionary:
	var normalized: String = _normalize_dps_source_id(source_id)
	return _get_dps_source_info(normalized)

func _resolve_dps_faze_icon_path(source_id: String) -> String:
	var normalized := source_id.to_lower()
	if normalized.begins_with("faze_"):
		normalized = normalized.substr(5)
	if normalized.ends_with("_level"):
		normalized = normalized.substr(0, normalized.length() - "_level".length())
	if DPS_DETAIL_FAZE_ICON_BY_KEY.has(normalized):
		return _build_dps_faze_icon_path(str(DPS_DETAIL_FAZE_ICON_BY_KEY[normalized]))
	for part in normalized.split("_"):
		if DPS_DETAIL_FAZE_ICON_BY_KEY.has(part):
			return _build_dps_faze_icon_path(str(DPS_DETAIL_FAZE_ICON_BY_KEY[part]))
	return DPS_DETAIL_DEFAULT_ICON

func _build_dps_faze_icon_path(icon_name: String) -> String:
	var path := "res://AssetBundle/Sprites/Sprite sheets/skillIcon/" + icon_name + ".png"
	if ResourceLoader.exists(path):
		return path
	return DPS_DETAIL_DEFAULT_ICON

func _normalize_dps_source_id(source_id: String) -> String:
	var normalized: String = str(source_id).strip_edges()
	if normalized.is_empty():
		return "unknown"
	var lower: String = normalized.to_lower()
	match lower:
		"swordqi", "sword_qi", "sword":
			return "swordqi"
		"bullet":
			return "unknown"
		"reflection", "reflaction":
			return "reflection"
		"ringfire", "ring_fire":
			return "ringfire"
		"bloodwave", "blood_wave":
			return "blood_wave"
		"bloodboardsword", "blood_board_sword", "blood_broadsword":
			return "blood_broadsword"
		"ice", "ice_flower":
			return "ice_flower"
		"thunderbreak", "thunder_break":
			return "thunder_break"
		"lightbullet", "light_bullet":
			return "light_bullet"
		"holylight", "holy_light":
			return "holylight"
		"dragonwind", "dragon_wind":
			return "dragonwind"
		"genshan":
			return "genshan"
		"duize":
			return "duize"
		"qigong":
			return "qigong"
		"burn":
			return "burn"
		"electrified", "electric", "lilei":
			return "electrified"
		"bleed":
			return "bleed"
		"magical_fire", "magic_fire":
			return "magical_fire"
		"magical_ice", "magic_ice":
			return "magical_ice"
		"wind_thunder":
			return "wind_thunder"
		"holy_fire":
			return "holy_fire"
		"heal_hot", "heal":
			return "heal_hot"
		"hp_regen", "life_regen", "health_regen":
			return "hp_regen"
		"water_sheild", "water_shield":
			return "water_sheild"
		"beastify":
			return "beastify"
		"destructive_hammer", "xueming_chongzhuang", "po_huai_luan_chui":
			return "destructive_hammer"
		"summon", "huanwu":
			return "summon"
		_:
			return lower

func _resolve_dps_icon_path(icon_name: String, reward_id: String = "") -> String:
	if not icon_name.is_empty():
		var direct_path: String = icon_name
		if not direct_path.begins_with("res://"):
			direct_path = "res://AssetBundle/Sprites/Sprite sheets/skillIcon/" + direct_path + ".png"
		if ResourceLoader.exists(direct_path):
			return direct_path
	if not reward_id.is_empty() and LvUp != null and LvUp.has_method("get_reward_by_id"):
		var reward: Variant = LvUp.get_reward_by_id(reward_id)
		if reward != null:
			var reward_icon_path: String = LvUp.get_icon_path(str(reward.icon))
			if not reward_icon_path.is_empty() and ResourceLoader.exists(reward_icon_path):
				return reward_icon_path
	return DPS_DETAIL_DEFAULT_ICON

func _record_dps_test_damage(damage: float, source_id: String) -> void:
	if not dps_test_timer_active:
		return
	dps_test_total_damage += damage
	var source_info: Dictionary = _get_dps_source_info(source_id)
	var detail_key: String = str(source_info.get("key", source_id))
	if not dps_test_source_totals.has(detail_key):
		dps_test_source_totals[detail_key] = {
			"key": detail_key,
			"source_id": source_id,
			"name": str(source_info.get("name", source_id)),
			"category": str(source_info.get("category", DPS_DETAIL_CATEGORY_OTHER)),
			"icon": str(source_info.get("icon", DPS_DETAIL_DEFAULT_ICON)),
			"damage": 0.0,
		}
	var entry: Dictionary = dps_test_source_totals[detail_key]
	entry["damage"] = float(entry.get("damage", 0.0)) + damage
	dps_test_source_totals[detail_key] = entry

func _record_heal_shield_test_value(kind: String, amount: float, source_id: String) -> void:
	if not dps_test_timer_active:
		return
	heal_shield_test_total += amount
	var source_info: Dictionary = _get_heal_shield_source_info(source_id)
	var detail_key: String = str(source_info.get("key", source_id))
	if not heal_shield_test_source_totals.has(detail_key):
		heal_shield_test_source_totals[detail_key] = {
			"key": detail_key,
			"source_id": source_id,
			"name": str(source_info.get("name", source_id)),
			"category": str(source_info.get("category", DPS_DETAIL_CATEGORY_OTHER)),
			"icon": str(source_info.get("icon", DPS_DETAIL_DEFAULT_ICON)),
			"heal": 0.0,
			"shield": 0.0,
			"total": 0.0,
		}
	var entry: Dictionary = heal_shield_test_source_totals[detail_key]
	entry[kind] = float(entry.get(kind, 0.0)) + amount
	entry["total"] = float(entry.get("heal", 0.0)) + float(entry.get("shield", 0.0))
	heal_shield_test_source_totals[detail_key] = entry

func start_dps_test_timer() -> void:
	dps_test_timer_started = true
	dps_test_timer_active = true
	dps_test_start_msec = Time.get_ticks_msec()
	dps_test_start_battle_time = _get_dps_time_source()
	dps_test_elapsed_seconds = 0.0
	dps_test_total_damage = 0.0
	heal_shield_test_total = 0.0
	dps_test_last_total_dps = 0.0
	dps_test_source_totals.clear()
	heal_shield_test_source_totals.clear()

func stop_dps_test_timer() -> void:
	if not dps_test_timer_started:
		return
	_update_dps_test_elapsed()
	dps_test_timer_active = false
	dps_test_last_total_dps = _get_dps_test_total_dps()

func reset_dps_test_timer() -> void:
	dps_test_timer_started = false
	dps_test_timer_active = false
	dps_test_start_msec = 0
	dps_test_start_battle_time = 0.0
	dps_test_elapsed_seconds = 0.0
	dps_test_total_damage = 0.0
	heal_shield_test_total = 0.0
	dps_test_last_total_dps = 0.0
	dps_test_source_totals.clear()
	heal_shield_test_source_totals.clear()

func is_dps_test_timer_active() -> bool:
	return dps_test_timer_active

func has_dps_test_timer_data() -> bool:
	return dps_test_timer_started

func get_dps_test_elapsed_seconds() -> float:
	_update_dps_test_elapsed()
	return dps_test_elapsed_seconds

func _update_dps_test_elapsed() -> void:
	if dps_test_timer_active:
		dps_test_elapsed_seconds = maxf(0.0, _get_dps_time_source() - dps_test_start_battle_time)

func _get_dps_test_total_dps() -> float:
	var elapsed: float = max(get_dps_test_elapsed_seconds(), DPS_TEST_MIN_DISPLAY_SECONDS)
	return dps_test_total_damage / elapsed

func _get_heal_shield_test_total_rate() -> float:
	var elapsed: float = max(get_dps_test_elapsed_seconds(), DPS_TEST_MIN_DISPLAY_SECONDS)
	return heal_shield_test_total / elapsed

func get_dps_test_total_dps() -> float:
	if dps_test_timer_active:
		return _get_dps_test_total_dps()
	return dps_test_last_total_dps

func get_dps_detail_snapshot() -> Dictionary:
	if dps_test_timer_started:
		return _get_dps_test_detail_snapshot()
	refresh_dps_counter()
	return _build_dps_detail_snapshot(current_dps, dps_detail_source_dps, float(DPS_WINDOW_SECONDS), false)

func get_heal_shield_detail_snapshot() -> Dictionary:
	if dps_test_timer_started:
		return _get_heal_shield_test_detail_snapshot()
	_calculate_heal_shield_rates()
	var total_rate: float = 0.0
	for detail_key in heal_shield_detail_source_rates:
		total_rate += float(heal_shield_detail_source_rates[detail_key].get("rate", 0.0))
	return _build_heal_shield_detail_snapshot(total_rate, heal_shield_detail_source_rates, float(DPS_WINDOW_SECONDS), false)

func _get_dps_test_detail_snapshot() -> Dictionary:
	_update_dps_test_elapsed()
	var elapsed: float = max(dps_test_elapsed_seconds, DPS_TEST_MIN_DISPLAY_SECONDS)
	var source_dps: Dictionary = {}
	for detail_key in dps_test_source_totals:
		var entry: Dictionary = dps_test_source_totals[detail_key].duplicate(true)
		entry["dps"] = float(entry.get("damage", 0.0)) / elapsed
		source_dps[detail_key] = entry
	return _build_dps_detail_snapshot(get_dps_test_total_dps(), source_dps, elapsed, true)

func _get_heal_shield_test_detail_snapshot() -> Dictionary:
	_update_dps_test_elapsed()
	var elapsed: float = max(dps_test_elapsed_seconds, DPS_TEST_MIN_DISPLAY_SECONDS)
	var source_rates: Dictionary = {}
	for detail_key in heal_shield_test_source_totals:
		var entry: Dictionary = heal_shield_test_source_totals[detail_key].duplicate(true)
		entry["rate"] = float(entry.get("total", 0.0)) / elapsed
		entry["heal_rate"] = float(entry.get("heal", 0.0)) / elapsed
		entry["shield_rate"] = float(entry.get("shield", 0.0)) / elapsed
		source_rates[detail_key] = entry
	return _build_heal_shield_detail_snapshot(_get_heal_shield_test_total_rate(), source_rates, elapsed, true)

func _build_dps_detail_snapshot(total_dps_value: float, source_dps: Dictionary, window_seconds: float, is_test_mode: bool) -> Dictionary:
	var sources: Array = []
	for detail_key in source_dps:
		var entry: Dictionary = source_dps[detail_key].duplicate(true)
		var dps_value: float = float(entry.get("dps", 0.0))
		if dps_value <= 0.0:
			continue
		entry["percent"] = dps_value / max(total_dps_value, 0.001) * 100.0
		sources.append(entry)
	sources.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("dps", 0.0)) > float(b.get("dps", 0.0))
	)
	return {
		"total_dps": total_dps_value,
		"sources": sources,
		"window_seconds": window_seconds,
		"is_test_mode": is_test_mode,
		"timer_active": dps_test_timer_active,
	}

func _build_heal_shield_detail_snapshot(total_rate_value: float, source_rates: Dictionary, window_seconds: float, is_test_mode: bool) -> Dictionary:
	var sources: Array = []
	for detail_key in source_rates:
		var entry: Dictionary = source_rates[detail_key].duplicate(true)
		var rate_value: float = float(entry.get("rate", 0.0))
		if rate_value <= 0.0:
			continue
		entry["percent"] = rate_value / max(total_rate_value, 0.001) * 100.0
		sources.append(entry)
	sources.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("rate", 0.0)) > float(b.get("rate", 0.0))
	)
	return {
		"total_rate": total_rate_value,
		"sources": sources,
		"window_seconds": window_seconds,
		"is_test_mode": is_test_mode,
		"timer_active": dps_test_timer_active,
	}

func _ready():
	DEBUG_COMMANDS_ENABLED = OS.has_feature("editor")
	set_process(true)
	set_process_input(true)
	_init_input_device_mode()
	monster_damage.connect(_on_monster_damage)
	player_heal.connect(_on_player_heal)
	player_hit.connect(_on_player_hit)
	player_hit_ignore_invincible.connect(_on_player_hit_ignore_invincible)
	add_child(setting_emblem)
	add_child(audio_manager)
	add_child(soft_glow_manager)
	add_child(settings_manager)
	add_child(equipment_manager)
	add_child(active_skill_manager)
	add_child(exp_orb_system)
	load_game()
	_init_dps_counter()
	if dps_timer:
		dps_timer.start()
	MouseAnimation.start_mouse_animation()
	_init_object_pools()

func _init_input_device_mode() -> void:
	var detected_mode: String = INPUT_DEVICE_MODE_PC
	if _detect_mobile_device():
		detected_mode = INPUT_DEVICE_MODE_MOBILE
	set_input_device_mode(detected_mode, false)

func _detect_mobile_device() -> bool:
	var os_name: String = OS.get_name()
	return OS.has_feature("android") or OS.has_feature("ios") or os_name == "Android" or os_name == "iOS"

func set_input_device_mode(mode: String, emit_feedback: bool = true) -> void:
	var normalized_mode: String = mode.strip_edges().to_lower()
	if normalized_mode != INPUT_DEVICE_MODE_MOBILE:
		normalized_mode = INPUT_DEVICE_MODE_PC
	if input_device_mode == normalized_mode:
		if emit_feedback:
			_show_debug_command_feedback("输入模式：" + get_input_device_mode_display_name())
		return
	input_device_mode = normalized_mode
	emit_signal("input_device_mode_changed", input_device_mode)
	if emit_feedback:
		_show_debug_command_feedback("输入模式：" + get_input_device_mode_display_name())

func is_mobile_input_mode() -> bool:
	return input_device_mode == INPUT_DEVICE_MODE_MOBILE

func reset_mobile_input_now() -> void:
	if not is_mobile_input_mode():
		return
	_mobile_input_restore_request_id += 1
	emit_signal("mobile_input_reset_requested")

func request_mobile_input_restore() -> void:
	if not is_mobile_input_mode():
		return
	_mobile_input_restore_request_id += 1
	_restore_mobile_input_when_ready(_mobile_input_restore_request_id)

func _restore_mobile_input_when_ready(request_id: int) -> void:
	var tree := get_tree()
	if tree == null:
		emit_signal("mobile_input_restore_requested")
		return
	for _i in range(4):
		if request_id != _mobile_input_restore_request_id:
			return
		if not is_level_up and not tree.paused:
			break
		await tree.process_frame
	if request_id != _mobile_input_restore_request_id:
		return
	emit_signal("mobile_input_restore_requested")

func get_input_device_mode_display_name() -> String:
	if input_device_mode == INPUT_DEVICE_MODE_MOBILE:
		return "移动设备"
	return "PC"

func _init_object_pools() -> void:
	damage_label_pool = ObjectPool.new(_damage_label_scene, DAMAGE_LABEL_POOL_SIZE, true)
	add_child(damage_label_pool)
	rain_bullet_pool = ObjectPool.new(preload("res://Scenes/player/faze_rain_bullet.tscn"), 300, true)
	add_child(rain_bullet_pool)
	light_bullet_pool = ObjectPool.new(preload("res://Scenes/player/light_bullet.tscn"), 20)
	add_child(light_bullet_pool)
	ice_flower_pool = ObjectPool.new(preload("res://Scenes/player/ice_flower.tscn"), 20)
	add_child(ice_flower_pool)
	branch_pool = ObjectPool.new(preload("res://Scenes/branch.tscn"), 20)
	add_child(branch_pool)
	frog_attack_pool = ObjectPool.new(preload("res://Scenes/moster/frog_attack.tscn"), FROG_ATTACK_POOL_SIZE, true)
	add_child(frog_attack_pool)
	debuff_burn_pool = ObjectPool.new(preload("res://Scenes/player/debuff_burn.tscn"), 10)
	add_child(debuff_burn_pool)
	faze_bath_blood_thud_pool = ObjectPool.new(preload("res://Scenes/player/faze_bath_blood_thud.tscn"), 6)
	add_child(faze_bath_blood_thud_pool)
	faze_thunder_pool = ObjectPool.new(preload("res://Scenes/player/faze_thunder.tscn"), 5)
	add_child(faze_thunder_pool)
	faze_destory_pool = ObjectPool.new(preload("res://Scenes/player/faze_destory.tscn"), 5)
	add_child(faze_destory_pool)
	faze_light_pool = ObjectPool.new(preload("res://Scenes/player/faze_light.tscn"), 8)
	add_child(faze_light_pool)

func _process(delta: float) -> void:
	_flush_damage_label_queue()
	if not is_debug:
		return
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	var frame_ms := delta * 1000.0
	if frame_ms < PERF_STUTTER_FRAME_MS and fps > PERF_STUTTER_FPS:
		return
	var now := Time.get_ticks_msec()
	if now - _last_perf_probe_msec < PERF_STUTTER_LOG_INTERVAL_MS:
		return
	_last_perf_probe_msec = now
	_print_stutter_snapshot(frame_ms, fps)

func _input(event: InputEvent) -> void:
	if not DEBUG_COMMANDS_ENABLED:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12:
			_debug_command_f12()
			return
		_handle_debug_function_key(event.keycode)

func _handle_debug_function_key(keycode: Key) -> void:
	match keycode:
		KEY_F1:
			_debug_command_f1()
		KEY_F2:
			_debug_command_f2()
		KEY_F3:
			_debug_command_f3()
		KEY_F4:
			_debug_command_f4()
		KEY_F5:
			_debug_command_f5()
		KEY_F6:
			_debug_command_f6()
		KEY_F7:
			_debug_command_f7()
		KEY_F8:
			_debug_command_f8()
		KEY_F9:
			_debug_command_f9()
		KEY_F10:
			_debug_command_f10()
		KEY_F11:
			_debug_command_f11()
		KEY_F12:
			_debug_command_f12()

func _debug_command_f1() -> void:
	total_points += DEBUG_F1_ZHENQI_AMOUNT
	save_game()
	_refresh_debug_resource_views()
	_show_debug_command_feedback("调试指令 F1：真气 +%d，当前 %d" % [DEBUG_F1_ZHENQI_AMOUNT, total_points])

func _debug_command_f2() -> void:
	PC.pc_atk += 100
	_show_debug_command_feedback("调试指令 F2：攻击力 +100，当前 %d" % PC.pc_atk)

func _debug_command_f3() -> void:
	PC.pc_atk -= 100
	_show_debug_command_feedback("调试指令 F3：攻击力 -100，当前 %d" % PC.pc_atk)

func _debug_command_f4() -> void:
	PC.pc_max_hp += 1000
	PC.pc_hp = mini(PC.pc_hp + 1000, PC.pc_max_hp)
	_show_debug_command_feedback("调试指令 F4：体力上限 +1000，当前 %d" % PC.pc_max_hp)

func _debug_command_f5() -> void:
	PC.pc_max_hp -= 1000
	PC.pc_hp = mini(PC.pc_hp, PC.pc_max_hp)
	_show_debug_command_feedback("调试指令 F5：体力上限 -1000，当前 %d" % PC.pc_max_hp)

func _debug_command_f6() -> void:
	pass

func _debug_command_f7() -> void:
	pass

func _debug_command_f8() -> void:
	pass

func _debug_command_f9() -> void:
	_print_stutter_snapshot(1000.0 / maxf(1.0, Performance.get_monitor(Performance.TIME_FPS)), Performance.get_monitor(Performance.TIME_FPS))
	_show_debug_command_feedback("调试指令 F9：已输出性能快照")

func _debug_command_f10() -> void:
	_normalize_stage_difficulty_clear_progress()
	for stage_id in STAGE_ID_LIST:
		var stage_progress = stage_difficulty_clear_progress.get(stage_id, {})
		if typeof(stage_progress) != TYPE_DICTIONARY:
			stage_progress = {}
		for difficulty_id in STAGE_DIFFICULTY_LIST:
			stage_progress[difficulty_id] = true
		stage_difficulty_clear_progress[stage_id] = stage_progress
		core_depth_clear_progress[stage_id] = CORE_DEPTH_MAX
	selected_core_depth = CORE_DEPTH_MAX
	save_game()
	_refresh_debug_resource_views()
	_show_debug_command_feedback("调试指令 F10：全部难度与核心进阶10层已解锁")

func _debug_command_f11() -> void:
	var entries := StudyTreeConfig.get_all_entries()
	for id in entries.keys():
		var entry: Dictionary = entries[id]
		var max_level := int(entry.get("max_level", "1"))
		player_study_tree[String(id)] = max(1, max_level)
	SettingStudyTreeUp.apply_all()
	SettingStudyTreeSkill.apply_all()
	SettingStudyTreeLearn.apply_all()
	SettingStudyTreeTeam.apply_all()
	SettingStudyTreeSpecial.apply_all()
	save_game()
	_refresh_debug_resource_views()
	_show_debug_command_feedback("调试指令 F11：全部天赋已激活并升至满级")

var _debug_console: CanvasLayer = null

func _debug_command_f12() -> void:
	if _debug_console == null:
		_debug_console = preload("res://Script/system/debug_console.gd").new()
		add_child(_debug_console)
	_debug_console.toggle()

func _print_stutter_snapshot(frame_ms: float, fps: float) -> void:
	var tree := get_tree()
	var node_count := 0
	var orphan_count := 0
	var object_count := 0
	if tree != null:
		node_count = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		orphan_count = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		object_count = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var groups := _get_perf_group_counts(tree)
	var pools := _get_perf_pool_stats()
	var stage_stats := _get_perf_stage_stats(tree)
	var drop_label_stats := _get_perf_drop_label_stats(tree)
	var barrage_stats := Faze.get_barrage_debug_stats()
	var separation_stats := CharacterEffects.get_separation_debug_stats()
	print("[PerfStutter] frame_ms=%.1f fps=%.1f objects=%d nodes=%d orphan=%d resources=%d draw_objects=%d draw_primitives=%d draw_calls=%d video_mem=%.1fMB static_mem=%.1fMB groups=%s pools=%s stage=%s drop_labels=%s barrage=%s separation=%s damage_queue=%d frog_cap=%d damage_drop_total=%d damage_drop_frame=%d" % [
		frame_ms,
		fps,
		object_count,
		node_count,
		orphan_count,
		int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)) / 1048576.0,
		float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0,
		str(groups),
		str(pools),
		str(stage_stats),
		str(drop_label_stats),
		str(barrage_stats),
		str(separation_stats),
		_damage_label_queue.size(),
		FROG_ATTACK_ACTIVE_CAP,
		_damage_label_drop_total_limit,
		_damage_label_drop_frame_limit,
	])

func _get_perf_group_counts(tree: SceneTree) -> Dictionary:
	if tree == null:
		return {}
	var group_names := [
		"enemies",
		"boss",
		"bullet",
		"exp_orb",
		"drop_item",
		"boss_projectile",
		"boss_bullet",
		"boss_a_petal",
		"boss_a_poison_circle",
		"mud_pool",
		MORETIP_OUTLINE_TARGET_GROUP,
	]
	var result := {}
	for group_name in group_names:
		result[group_name] = tree.get_nodes_in_group(group_name).size()
	return result

func _get_perf_pool_stats() -> Dictionary:
	return {
		"damage": _get_pool_debug_stats(damage_label_pool),
		"rain": _get_pool_debug_stats(rain_bullet_pool),
		"light": _get_pool_debug_stats(light_bullet_pool),
		"ice": _get_pool_debug_stats(ice_flower_pool),
		"branch": _get_pool_debug_stats(branch_pool),
		"frog": _get_pool_debug_stats(frog_attack_pool),
		"burn": _get_pool_debug_stats(debuff_burn_pool),
		"blood_thud": _get_pool_debug_stats(faze_bath_blood_thud_pool),
		"thunder": _get_pool_debug_stats(faze_thunder_pool),
		"destroy": _get_pool_debug_stats(faze_destory_pool),
		"faze_light": _get_pool_debug_stats(faze_light_pool),
		"exp": _get_pool_debug_stats(exp_orb_system.exp_orb_pool if exp_orb_system != null else null),
	}

func _get_pool_debug_stats(pool: ObjectPool) -> Dictionary:
	if pool == null or not is_instance_valid(pool):
		return {}
	if pool.has_method("get_debug_stats"):
		return pool.get_debug_stats()
	return {
		"active": pool.active_count,
		"free": pool.free_count(),
	}

func _get_perf_stage_stats(tree: SceneTree) -> Dictionary:
	if tree == null or tree.current_scene == null:
		return {}
	var scene := tree.current_scene
	var result := {}
	for property_name in ["STAGE_ID", "_wave_spawning", "spawn_count", "current_monster_count", "max_monster_limit", "current_spawn_interval"]:
		var value = scene.get(property_name)
		if value != null:
			result[property_name] = value
	var timer = scene.get("monster_spawn_timer")
	if timer is Timer and is_instance_valid(timer):
		result["spawn_timer_time_left"] = timer.time_left
	return result

func _get_perf_drop_label_stats(tree: SceneTree) -> Dictionary:
	if tree == null or tree.current_scene == null:
		return {}
	for controller in tree.get_nodes_in_group("item_drop_controller"):
		if is_instance_valid(controller) and controller.has_method("get_drop_label_debug_stats"):
			return controller.get_drop_label_debug_stats()
	var visible_count := 0
	for item in tree.get_nodes_in_group("drop_item"):
		if is_instance_valid(item) and item.has_method("is_item_name_visible") and item.is_item_name_visible():
			visible_count += 1
	return {"visible": visible_count}

func _refresh_debug_resource_views() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	if "levelChangeLayer" in current_scene and current_scene.levelChangeLayer != null and current_scene.levelChangeLayer.has_method("prepare_for_open"):
		current_scene.levelChangeLayer.prepare_for_open()
	if current_scene.has_method("refresh_point"):
		current_scene.refresh_point()
	var study_layer := current_scene.get_node_or_null("StudyLayer")
	if study_layer != null and study_layer.has_method("refresh_study_tree_view"):
		study_layer.refresh_study_tree_view()
	var battle_layer := current_scene.get_node_or_null("CanvasLayer")
	if battle_layer != null and battle_layer.has_method("update_score_display"):
		battle_layer.update_score_display(total_points)

func _show_debug_command_feedback(message: String) -> void:
	print("[DebugHotkey] %s" % message)
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	if "tip" in current_scene and current_scene.tip != null and current_scene.tip.has_method("start_animation"):
		current_scene.tip.start_animation(message, 0.6)
		return
	var fallback_tip := current_scene.get_node_or_null("TipsLayer/Tip")
	if fallback_tip != null and fallback_tip.has_method("start_animation"):
		fallback_tip.start_animation(message, 0.6)

func get_item_count(item_id: String) -> int:
	if item_id == LINGSHI_ITEM_ID:
		return lingshi
	return player_inventory.get(item_id, 0)

func add_item_count(item_id: String, count: int) -> void:
	if count == 0:
		return
	if item_id == LINGSHI_ITEM_ID:
		lingshi = max(lingshi + count, 0)
		return
	player_inventory[item_id] = player_inventory.get(item_id, 0) + count
	if count > 0:
		var guide_manager = get_node_or_null("/root/GuideManager")
		if guide_manager != null and guide_manager.has_method("record_item_obtained"):
			guide_manager.record_item_obtained(item_id)
	if player_inventory[item_id] <= 0:
		player_inventory.erase(item_id)

func consume_item_count(item_id: String, count: int) -> bool:
	if count <= 0:
		return true
	if get_item_count(item_id) < count:
		return false
	add_item_count(item_id, -count)
	return true

func is_difu_mijing_unlocked() -> bool:
	return is_stage_cleared("forest")

func get_difu_required_key_count(difficulty_id: String = "", core_depth: int = 0) -> int:
	var valid_difficulty := validate_stage_difficulty_id(difficulty_id)
	if valid_difficulty == STAGE_DIFFICULTY_POETRY:
		return 0
	if valid_difficulty == STAGE_DIFFICULTY_DEEP:
		return 3
	if valid_difficulty == STAGE_DIFFICULTY_CORE:
		var depth := clamp_core_depth(core_depth if core_depth >= CORE_DEPTH_MIN else selected_core_depth)
		if depth >= 10:
			return 7
		if depth >= 7:
			return 6
		if depth >= 4:
			return 5
		return 4
	return 2

func get_mijing_stage_key_requirement(stage_id: String, difficulty_id: String = "", core_depth: int = 0) -> Dictionary:
	if stage_id == "difu":
		return {
			"item_id": JIUYOU_KEY_ITEM_ID,
			"required": get_difu_required_key_count(difficulty_id, core_depth)
		}
	return {"item_id": "", "required": 0}

func add_shop_battle_refresh(count: int = 1) -> void:
	shop_battle_refresh_count = clampi(shop_battle_refresh_count + count, 0, refresh_max_num)

func consume_shop_battle_refresh(count: int = 1) -> bool:
	if shop_battle_refresh_count < count:
		return false
	shop_battle_refresh_count -= count
	return true

# 把外部传进来的难度ID校正成可识别的值。
# 这样就算按钮配置错了，或者旧数据里写了别的字符串，
# 也会自动回退到"浅层"，不至于把逻辑跑崩。
func validate_stage_difficulty_id(difficulty_id: String) -> String:
	match difficulty_id:
		STAGE_DIFFICULTY_SHALLOW, STAGE_DIFFICULTY_DEEP, STAGE_DIFFICULTY_CORE, STAGE_DIFFICULTY_POETRY:
			return difficulty_id
		_:
			return STAGE_DIFFICULTY_SHALLOW

func get_stage_difficulty_display_name(difficulty_id: String) -> String:
	match validate_stage_difficulty_id(difficulty_id):
		STAGE_DIFFICULTY_SHALLOW:
			return "浅层"
		STAGE_DIFFICULTY_DEEP:
			return "深层"
		STAGE_DIFFICULTY_CORE:
			return "核心"
		STAGE_DIFFICULTY_POETRY:
			return "诗想"
		_:
			return "浅层"

# 返回进入某一层之前，必须先通关的前置层。
# 比如：想进"深层"，就必须先通关"浅层"。
func get_required_stage_clear_difficulty(difficulty_id: String) -> String:
	match validate_stage_difficulty_id(difficulty_id):
		STAGE_DIFFICULTY_DEEP:
			return STAGE_DIFFICULTY_SHALLOW
		STAGE_DIFFICULTY_CORE:
			return STAGE_DIFFICULTY_DEEP
		STAGE_DIFFICULTY_POETRY:
			return STAGE_DIFFICULTY_CORE
		_:
			return ""

# 旧存档里可能没有新字段，这里统一补齐。
func _normalize_stage_difficulty_clear_progress() -> void:
	if typeof(stage_difficulty_clear_progress) != TYPE_DICTIONARY:
		stage_difficulty_clear_progress = {}
	for stage_id in STAGE_ID_LIST:
		if not stage_difficulty_clear_progress.has(stage_id) or typeof(stage_difficulty_clear_progress.get(stage_id, {})) != TYPE_DICTIONARY:
			stage_difficulty_clear_progress[stage_id] = {}
		var stage_progress: Dictionary = stage_difficulty_clear_progress[stage_id]
		for difficulty_id in [STAGE_DIFFICULTY_SHALLOW, STAGE_DIFFICULTY_DEEP, STAGE_DIFFICULTY_CORE, STAGE_DIFFICULTY_POETRY]:
			stage_progress[difficulty_id] = stage_progress.get(difficulty_id, false) == true
		stage_difficulty_clear_progress[stage_id] = stage_progress
	_normalize_core_depth_clear_progress()

func _normalize_core_depth_clear_progress() -> void:
	if typeof(core_depth_clear_progress) != TYPE_DICTIONARY:
		core_depth_clear_progress = {}
	for stage_id in STAGE_ID_LIST:
		var cleared_depth := int(core_depth_clear_progress.get(stage_id, 0))
		var stage_progress = stage_difficulty_clear_progress.get(stage_id, {})
		if typeof(stage_progress) == TYPE_DICTIONARY and stage_progress.get(STAGE_DIFFICULTY_CORE, false) == true:
			cleared_depth = max(cleared_depth, CORE_DEPTH_MIN)
		core_depth_clear_progress[stage_id] = clampi(cleared_depth, 0, CORE_DEPTH_MAX)
	selected_core_depth = clamp_core_depth(selected_core_depth)
	current_core_depth = clamp_core_depth(current_core_depth)

func set_selected_stage_difficulty(difficulty_id: String) -> void:
	selected_stage_difficulty = validate_stage_difficulty_id(difficulty_id)

func clamp_core_depth(depth: int) -> int:
	return clampi(depth, CORE_DEPTH_MIN, CORE_DEPTH_MAX)

func set_selected_core_depth(depth: int) -> void:
	selected_core_depth = clamp_core_depth(depth)

func get_stage_core_depth_cleared(stage_id: String) -> int:
	_normalize_core_depth_clear_progress()
	if not core_depth_clear_progress.has(stage_id):
		return 0
	return clampi(int(core_depth_clear_progress.get(stage_id, 0)), 0, CORE_DEPTH_MAX)

func get_stage_max_unlocked_core_depth(stage_id: String) -> int:
	if STAGE_ID_LIST.find(stage_id) == -1:
		return 0
	var cleared_depth := get_stage_core_depth_cleared(stage_id)
	var global_start_depth := get_global_core_start_depth()
	if cleared_depth >= CORE_DEPTH_MAX:
		return CORE_DEPTH_MAX
	if cleared_depth > 0:
		return clampi(maxi(cleared_depth + 1, global_start_depth), CORE_DEPTH_MIN, CORE_DEPTH_MAX)
	if is_stage_difficulty_cleared(stage_id, STAGE_DIFFICULTY_DEEP):
		return global_start_depth
	return 0

func get_global_core_start_depth() -> int:
	_normalize_core_depth_clear_progress()
	var max_cleared_depth := 0
	for stage_id in STAGE_ID_LIST:
		max_cleared_depth = maxi(max_cleared_depth, clampi(int(core_depth_clear_progress.get(stage_id, 0)), 0, CORE_DEPTH_MAX))
	if max_cleared_depth >= 10:
		return 4
	if max_cleared_depth >= 7:
		return 3
	if max_cleared_depth >= 4:
		return 2
	return CORE_DEPTH_MIN

func get_global_max_unlocked_core_depth() -> int:
	_normalize_core_depth_clear_progress()
	var max_depth := 0
	for stage_id in STAGE_ID_LIST:
		max_depth = maxi(max_depth, get_stage_max_unlocked_core_depth(stage_id))
	return clampi(max_depth, 0, CORE_DEPTH_MAX)

func can_enter_core_depth(stage_id: String, depth: int) -> bool:
	var target_depth := clamp_core_depth(depth)
	return get_stage_max_unlocked_core_depth(stage_id) >= target_depth

func mark_stage_core_depth_cleared(stage_id: String, depth: int) -> void:
	_normalize_stage_difficulty_clear_progress()
	if STAGE_ID_LIST.find(stage_id) == -1:
		return
	var cleared_depth: int = maxi(get_stage_core_depth_cleared(stage_id), clamp_core_depth(depth))
	core_depth_clear_progress[stage_id] = cleared_depth
	var stage_progress = stage_difficulty_clear_progress.get(stage_id, {})
	if typeof(stage_progress) != TYPE_DICTIONARY:
		stage_progress = {}
	stage_progress[STAGE_DIFFICULTY_CORE] = true
	stage_difficulty_clear_progress[stage_id] = stage_progress

func is_current_core_difficulty() -> bool:
	return validate_stage_difficulty_id(current_stage_difficulty) == STAGE_DIFFICULTY_CORE

func get_current_core_depth() -> int:
	if not is_current_core_difficulty():
		return CORE_DEPTH_MIN
	return clamp_core_depth(current_core_depth)

func get_core_depth_stat_multiplier(depth: int = -1) -> float:
	var resolved_depth := current_core_depth if depth < CORE_DEPTH_MIN else depth
	return 1.0 + float(clamp_core_depth(resolved_depth)) * CORE_DEPTH_STAT_STEP

func get_stage_core_depth_stat_multiplier(stage_id: String = "", depth: int = -1) -> float:
	var resolved_stage_id := stage_id
	if resolved_stage_id.is_empty():
		resolved_stage_id = current_stage_id
	if not STAGE_CORE_DEPTH_STAT_MULTIPLIERS.has(resolved_stage_id):
		resolved_stage_id = str(STAGE_ID_LIST[0])
	var resolved_depth := current_core_depth if depth < CORE_DEPTH_MIN else depth
	var stage_data: Dictionary = STAGE_CORE_DEPTH_STAT_MULTIPLIERS.get(resolved_stage_id, {})
	return float(stage_data.get(clamp_core_depth(resolved_depth), CORE_DIFFICULTY_BASE_STAT_MULTIPLIER * get_core_depth_stat_multiplier(resolved_depth)))

func get_core_stat_bonus_percent(depth: int = -1) -> int:
	var resolved_depth := current_core_depth if depth < CORE_DEPTH_MIN else depth
	return int(round(float(clamp_core_depth(resolved_depth)) * CORE_DEPTH_STAT_STEP * 100.0))

func get_stage_core_stat_bonus_percent(stage_id: String = "", depth: int = -1) -> int:
	return int(round((get_stage_core_depth_stat_multiplier(stage_id, depth) - 1.0) * 100.0))

func get_core_qi_gain_multiplier(depth: int = -1) -> float:
	var resolved_depth := current_core_depth if depth < CORE_DEPTH_MIN else depth
	return CORE_DIFFICULTY_BASE_QI_GAIN_MULTIPLIER + float(clamp_core_depth(resolved_depth)) * CORE_DEPTH_QI_GAIN_STEP

func get_core_qi_gain_bonus_percent(depth: int = -1) -> int:
	return int(round((get_core_qi_gain_multiplier(depth) - 1.0) * 100.0))

func is_core_modifier_active(required_depth: int) -> bool:
	return is_current_core_difficulty() and get_current_core_depth() >= required_depth

func get_core_enemy_move_speed_multiplier() -> float:
	if is_core_modifier_active(10):
		return 1.25
	if is_core_modifier_active(2):
		return 1.15
	return 1.0

func get_core_attack_growth_multiplier() -> float:
	if is_core_modifier_active(10):
		return 1.30
	if is_core_modifier_active(5):
		return 1.20
	return 1.0

func get_core_required_exp_multiplier() -> float:
	if is_core_modifier_active(10):
		return 1.25
	if is_core_modifier_active(6):
		return 1.20
	return 1.0

func get_qi_vortex_cost_multiplier() -> float:
	return 1.25 if is_core_modifier_active(4) else 1.0

func get_heal_shield_effect_multiplier() -> float:
	var multiplier := 1.0
	if is_core_modifier_active(9):
		multiplier *= 0.70
	if is_current_poetry_difficulty():
		multiplier *= get_poetry_heal_shield_multiplier()
	return maxf(multiplier, 0.0)

func is_current_poetry_difficulty() -> bool:
	return validate_stage_difficulty_id(current_stage_difficulty) == STAGE_DIFFICULTY_POETRY

func get_battle_display_time(real_time: float) -> float:
	if not is_current_poetry_difficulty():
		return real_time
	return maxf(0.0, real_time - POETRY_BATTLE_START_TIME_SECONDS)

func get_poetry_elapsed_time(real_time: float = -1.0) -> float:
	var resolved_time := real_time
	if resolved_time < 0.0 and typeof(PC) != TYPE_NIL:
		resolved_time = PC.real_time
	return maxf(0.0, resolved_time - POETRY_BATTLE_START_TIME_SECONDS)

func get_poetry_modifier_step_count(real_time: float = -1.0) -> int:
	if not is_current_poetry_difficulty():
		return 0
	return maxi(0, int(floor(get_poetry_elapsed_time(real_time) / POETRY_MODIFIER_STEP_SECONDS)))

func _get_poetry_escalating_step_bonus(step_count: int, base_step: float) -> float:
	var double_after_steps := maxi(0, int(floor(POETRY_MODIFIER_DOUBLE_AFTER_SECONDS / POETRY_MODIFIER_STEP_SECONDS)))
	var normal_steps := mini(maxi(0, step_count), double_after_steps)
	var doubled_steps := maxi(0, step_count - double_after_steps)
	return float(normal_steps) * base_step + float(doubled_steps) * base_step * 2.0

func get_poetry_player_final_damage_multiplier(real_time: float = -1.0) -> float:
	var step_count := get_poetry_modifier_step_count(real_time)
	return 1.0 + _get_poetry_escalating_step_bonus(step_count, POETRY_PLAYER_FINAL_DAMAGE_STEP)

func get_poetry_heal_shield_multiplier(real_time: float = -1.0) -> float:
	var step_count := get_poetry_modifier_step_count(real_time)
	return maxf(0.0, 1.0 - float(step_count) * POETRY_HEAL_SHIELD_STEP_PENALTY)

func get_poetry_boss_damage_correction(real_time: float = -1.0) -> float:
	if not is_current_poetry_difficulty():
		return 0.0
	var step_count := get_poetry_modifier_step_count(real_time)
	return _get_poetry_escalating_step_bonus(step_count, POETRY_BOSS_DAMAGE_CORRECTION_STEP)

func get_poetry_boss_damage_multiplier(real_time: float = -1.0) -> float:
	if not is_current_poetry_difficulty():
		return 1.0
	return maxf(0.0, 1.0 + POETRY_BOSS_DAMAGE_BASE_BONUS + get_poetry_boss_damage_correction(real_time) + get_poetry_boss_cultivation_damage_bonus()) * POETRY_BOSS_DAMAGE_FINAL_MULTIPLIER

func get_poetry_boss_cultivation_damage_bonus() -> float:
	var xuanyuan_bonus := float(maxi(0, cultivation_xuanyuan_level)) * POETRY_BOSS_DAMAGE_XUANYUAN_STEP
	var huti_bonus := float(maxi(0, cultivation_huti_level)) * POETRY_BOSS_DAMAGE_HUTI_STEP
	return xuanyuan_bonus + huti_bonus

func get_stage_boss_modifier_step_count() -> int:
	if is_current_poetry_difficulty():
		return 0
	var difficulty_id := validate_stage_difficulty_id(current_stage_difficulty)
	if not STAGE_BOSS_MODIFIER_START_TIMES.has(difficulty_id):
		return 0
	var start_time := float(STAGE_BOSS_MODIFIER_START_TIMES.get(difficulty_id, 0.0))
	var elapsed := PC.real_time - start_time
	if elapsed < STAGE_BOSS_MODIFIER_DELAY_SECONDS:
		return 0
	return maxi(0, int(floor((elapsed - STAGE_BOSS_MODIFIER_DELAY_SECONDS) / STAGE_BOSS_MODIFIER_STEP_SECONDS)) + 1)

func get_stage_boss_damage_escalation_multiplier(base_bonus: float = STAGE_BOSS_PLAYER_MODIFIER_BASE_BONUS) -> float:
	var step_count := get_stage_boss_modifier_step_count()
	var multiplier := 1.0
	for i in range(step_count):
		multiplier *= 1.0 + base_bonus + float(i) * STAGE_BOSS_MODIFIER_STEP_BONUS
	return multiplier

func get_stage_boss_player_damage_multiplier() -> float:
	return get_stage_boss_damage_escalation_multiplier(STAGE_BOSS_PLAYER_MODIFIER_BASE_BONUS)

func get_stage_boss_damage_multiplier() -> float:
	return get_stage_boss_damage_escalation_multiplier(STAGE_BOSS_DAMAGE_MODIFIER_BASE_BONUS)

func is_boss_damage_source(attacker: Node) -> bool:
	if attacker == null or not is_instance_valid(attacker):
		return false
	var node := attacker
	while node != null and is_instance_valid(node):
		if node.is_in_group("boss") or node.is_in_group("boss_bullet") or node.is_in_group("boss_projectile") or node.is_in_group("boss_a_petal") or node.is_in_group("boss_a_poison_circle"):
			return true
		node = node.get_parent()
	return false

func is_poetry_boss_damage_source(attacker: Node) -> bool:
	if not is_current_poetry_difficulty():
		return false
	return is_boss_damage_source(attacker)

func get_poetry_total_faze_overflow(threshold: int = 20) -> int:
	if typeof(PC) == TYPE_NIL:
		return 0
	var overflow := 0
	for property_name in FAZE_LEVEL_PROPERTIES:
		overflow += maxi(0, int(PC.get(property_name)) - threshold)
	return overflow

func get_poetry_boss_expected_output() -> float:
	if typeof(PC) == TYPE_NIL:
		return 0.0
	var crit_chance := clampf(PC.crit_chance, 0.0, 1.0)
	var crit_expected_multiplier := 1.0 + crit_chance * maxf(0.0, PC.crit_damage_multi - 1.0)
	var attack_speed_multiplier := maxf(0.01, 1.0 + PC.attack_speed_bonus)
	var final_damage_multiplier := Faze.get_final_damage_multiplier()
	return maxf(0.0, float(PC.pc_atk) * crit_expected_multiplier * attack_speed_multiplier * final_damage_multiplier)

func get_poetry_boss_max_hp(boss_id: String, fallback_hp: float = 1.0) -> float:
	if not is_current_poetry_difficulty():
		return maxf(fallback_hp, 1.0)
	var expected_output := get_poetry_boss_expected_output()
	var faze_overflow_multiplier := 1.0 + float(get_poetry_total_faze_overflow()) * 0.18
	var boss_factor := float(POETRY_BOSS_HP_FACTORS.get(boss_id, 1.0))
	var hp_value := expected_output * POETRY_BOSS_HP_OUTPUT_SCALE * faze_overflow_multiplier * boss_factor * POETRY_BOSS_HP_FINAL_MULTIPLIER
	return maxf(hp_value, 1.0)

func should_use_reduced_qi_vortex_times() -> bool:
	return is_core_modifier_active(8)

func is_core_missile_enabled() -> bool:
	return is_core_modifier_active(7)

func is_corrupted_elite_enabled() -> bool:
	return is_core_modifier_active(3)

func is_stage_difficulty_cleared(stage_id: String, difficulty_id: String) -> bool:
	_normalize_stage_difficulty_clear_progress()
	if not stage_difficulty_clear_progress.has(stage_id):
		return false
	var stage_progress = stage_difficulty_clear_progress.get(stage_id, {})
	if typeof(stage_progress) != TYPE_DICTIONARY:
		return false
	return stage_progress.get(validate_stage_difficulty_id(difficulty_id), false) == true

func is_stage_cleared(stage_id: String) -> bool:
	for difficulty_id in [STAGE_DIFFICULTY_SHALLOW, STAGE_DIFFICULTY_DEEP, STAGE_DIFFICULTY_CORE, STAGE_DIFFICULTY_POETRY]:
		if is_stage_difficulty_cleared(stage_id, difficulty_id):
			return true
	return false

func get_previous_stage_id(stage_id: String) -> String:
	var stage_index := STAGE_ID_LIST.find(stage_id)
	if stage_index <= 0:
		return ""
	return str(STAGE_ID_LIST[stage_index - 1])

func is_stage_unlocked(stage_id: String) -> bool:
	return can_enter_stage_difficulty(stage_id, STAGE_DIFFICULTY_SHALLOW)

func has_any_stage_difficulty_cleared(difficulty_id: String) -> bool:
	var valid_difficulty := validate_stage_difficulty_id(difficulty_id)
	for stage_id in STAGE_ID_LIST:
		if is_stage_difficulty_cleared(stage_id, valid_difficulty):
			return true
	return false

func is_stage_difficulty_unlocked(difficulty_id: String) -> bool:
	var valid_difficulty := validate_stage_difficulty_id(difficulty_id)
	for stage_id in STAGE_ID_LIST:
		if can_enter_stage_difficulty(stage_id, valid_difficulty):
			return true
	return false

# 判断某个"关卡 + 难度"组合是否已经解锁。
# 规则：
# 1) 壹·浅层 初始解锁；
# 2) 浅层只会按关卡顺序横向解锁下一关；
# 3) 深层 / 核心 只会在同一关内纵向解锁下一难度；
# 4) 通关本格后保持已解锁；
# 5) 诗想难度需要通关cave后才可进入。
func can_enter_stage_difficulty(stage_id: String, difficulty_id: String) -> bool:
	_normalize_stage_difficulty_clear_progress()
	var resolved_stage_id := str(stage_id)
	var valid_difficulty := validate_stage_difficulty_id(difficulty_id)
	var stage_index := STAGE_ID_LIST.find(resolved_stage_id)
	if stage_index == -1:
		return false
	if resolved_stage_id == "difu" and valid_difficulty == STAGE_DIFFICULTY_POETRY:
		return false
	# 诗想难度：需要通关cave后才能进入
	if valid_difficulty == STAGE_DIFFICULTY_POETRY and not is_stage_cleared("cave"):
		return false
	if is_stage_difficulty_cleared(resolved_stage_id, valid_difficulty):
		return true
	var difficulty_index := STAGE_DIFFICULTY_LIST.find(valid_difficulty)
	if difficulty_index == -1:
		return false
	if difficulty_index == 0:
		if stage_index == 0:
			return true
		var previous_stage_id := str(STAGE_ID_LIST[stage_index - 1])
		return is_stage_difficulty_cleared(previous_stage_id, valid_difficulty)
	var previous_difficulty_id := str(STAGE_DIFFICULTY_LIST[difficulty_index - 1])
	return is_stage_difficulty_cleared(resolved_stage_id, previous_difficulty_id)

# 战斗胜利时调用，用来解锁下一层难度。
func mark_stage_difficulty_cleared(stage_id: String, difficulty_id: String) -> void:
	_normalize_stage_difficulty_clear_progress()
	if not stage_difficulty_clear_progress.has(stage_id):
		return
	var stage_progress = stage_difficulty_clear_progress.get(stage_id, {})
	if typeof(stage_progress) != TYPE_DICTIONARY:
		stage_progress = {}
	var valid_difficulty := validate_stage_difficulty_id(difficulty_id)
	stage_progress[valid_difficulty] = true
	stage_difficulty_clear_progress[stage_id] = stage_progress
	if valid_difficulty == STAGE_DIFFICULTY_CORE:
		mark_stage_core_depth_cleared(stage_id, current_core_depth)

# 取得某个关卡在某个难度下的倍率。
# 如果不传参数，就默认读取"当前已进入关卡"的上下文。
func get_stage_difficulty_stat_multiplier(stage_id: String = "", difficulty_id: String = "", core_depth: int = 0) -> float:
	var resolved_stage_id := stage_id
	if resolved_stage_id.is_empty():
		resolved_stage_id = current_stage_id
	var resolved_difficulty_id := difficulty_id
	if resolved_difficulty_id.is_empty():
		resolved_difficulty_id = current_stage_difficulty
	resolved_difficulty_id = validate_stage_difficulty_id(resolved_difficulty_id)
	if not STAGE_DIFFICULTY_MULTIPLIERS.has(resolved_stage_id):
		return 1.0
	var stage_multiplier_data = STAGE_DIFFICULTY_MULTIPLIERS.get(resolved_stage_id, {})
	if typeof(stage_multiplier_data) != TYPE_DICTIONARY:
		return 1.0
	var shallow_multiplier: float = maxf(float(stage_multiplier_data.get(STAGE_DIFFICULTY_SHALLOW, 1.0)), 1.0)
	match resolved_difficulty_id:
		STAGE_DIFFICULTY_DEEP:
			return shallow_multiplier * DEEP_DIFFICULTY_STAT_MULTIPLIER
		STAGE_DIFFICULTY_CORE:
			var resolved_core_depth := core_depth
			if resolved_core_depth < CORE_DEPTH_MIN:
				resolved_core_depth = current_core_depth if resolved_stage_id == current_stage_id else selected_core_depth
			return shallow_multiplier * get_stage_core_depth_stat_multiplier(resolved_stage_id, resolved_core_depth)
		STAGE_DIFFICULTY_POETRY:
			return float(stage_multiplier_data.get(STAGE_DIFFICULTY_POETRY, shallow_multiplier * CORE_DIFFICULTY_BASE_STAT_MULTIPLIER))
		_:
			return shallow_multiplier

func get_current_stage_stat_multiplier() -> float:
	return get_stage_difficulty_stat_multiplier(current_stage_id, current_stage_difficulty, current_core_depth)

func get_stage_difficulty_qi_gain_multiplier(difficulty_id: String = "", core_depth: int = 0) -> float:
	var resolved_difficulty_id := difficulty_id
	if resolved_difficulty_id.is_empty():
		resolved_difficulty_id = current_stage_difficulty
	resolved_difficulty_id = validate_stage_difficulty_id(resolved_difficulty_id)
	match resolved_difficulty_id:
		STAGE_DIFFICULTY_DEEP:
			return DEEP_DIFFICULTY_QI_GAIN_MULTIPLIER
		STAGE_DIFFICULTY_CORE:
			var resolved_core_depth := core_depth
			if resolved_core_depth < CORE_DEPTH_MIN:
				resolved_core_depth = current_core_depth
			return get_core_qi_gain_multiplier(resolved_core_depth)
		STAGE_DIFFICULTY_POETRY:
			return CORE_DIFFICULTY_BASE_QI_GAIN_MULTIPLIER
		_:
			return SHALLOW_DIFFICULTY_QI_GAIN_MULTIPLIER

func get_current_stage_qi_gain_multiplier() -> float:
	return get_stage_difficulty_qi_gain_multiplier(current_stage_difficulty, current_core_depth)

# 推荐修为固定值配置（关卡 × 难度 → 修为值）
const STAGE_RECOMMENDED_POWER := {
	"peach_grove": {
		"shallow": 1200,
		"deep": 4500,
		"core": 7000,
		"poetry": 7000
	},
	"ruin": {
		"shallow": 3200,
		"deep": 8000,
		"core": 12000,
		"poetry": 12000
	},
	"cave": {
		"shallow": 9000,
		"deep": 14000,
		"core": 19000,
		"poetry": 19000
	},
	"forest": {
		"shallow": 16000,
		"deep": 22000,
		"core": 26000,
		"poetry": 26000
	}
}

# 返回指定关卡和难度的推荐修为（固定值）
func get_stage_recommended_power(stage_id: String, difficulty_id: String) -> int:
	var valid_difficulty := validate_stage_difficulty_id(difficulty_id)
	if not STAGE_RECOMMENDED_POWER.has(stage_id):
		return 0
	var stage_data = STAGE_RECOMMENDED_POWER.get(stage_id, {})
	if typeof(stage_data) != TYPE_DICTIONARY:
		return 0
	var base_power := int(stage_data.get(valid_difficulty, 0))
	if valid_difficulty == STAGE_DIFFICULTY_CORE:
		var depth_ratio := get_stage_core_depth_stat_multiplier(stage_id, selected_core_depth) / get_stage_core_depth_stat_multiplier(stage_id, CORE_DEPTH_MIN)
		return int(ceil(float(base_power) * depth_ratio))
	return base_power

func _get_effective_normal_monster_bonus() -> float:
	if typeof(PC) != TYPE_NIL:
		# 修习树团队篇：对普通怪伤害百分比加成
		return PC.normal_monster_multi + study_normal_monster_damage_bonus
	return normal_monster_multi + study_normal_monster_damage_bonus

func _get_effective_boss_bonus() -> float:
	if typeof(PC) != TYPE_NIL:
		# 修习树团队篇：对精英/Boss伤害百分比加成
		return PC.boss_multi + study_elite_damage_bonus
	return boss_multi + study_elite_damage_bonus

func get_effective_exp_multiplier() -> float:
	var effective_exp_bonus = exp_multi
	if typeof(PC) != TYPE_NIL:
		effective_exp_bonus = PC.exp_multi
	return max(0.0, 1.0 + get_diminished_exp_bonus(effective_exp_bonus))

func get_diminished_exp_bonus(raw_bonus: float) -> float:
	if raw_bonus <= 1.0:
		return raw_bonus
	var diminished_bonus := 1.0 + (raw_bonus - 1.0) * 0.4
	if diminished_bonus <= 1.5:
		return diminished_bonus
	return 1.5 + (diminished_bonus - 1.5) * 0.3

func get_effective_drop_multiplier() -> float:
	var effective_drop_bonus = drop_multi
	if typeof(PC) != TYPE_NIL:
		effective_drop_bonus = PC.drop_multi
	return max(0.0, 1.0 + effective_drop_bonus)

func get_heal_aura_drop_bonus() -> float:
	var effective_heal_aura_bonus: float = study_heal_aura_spawn_chance
	if typeof(PC) != TYPE_NIL and PC != null:
		effective_heal_aura_bonus += PC.heal_aura_drop_multi
	return effective_heal_aura_bonus

func get_effective_heal_aura_drop_multiplier() -> float:
	return max(0.0, 1.0 + get_heal_aura_drop_bonus())

func get_attack_range_multiplier() -> float:
	var effective_attack_range = attack_range
	if typeof(PC) != TYPE_NIL and PC != null:
		effective_attack_range = float(PC.attack_range)
	return max(0.01, effective_attack_range)

func get_emblem_effect_multiplier() -> float:
	# 修习树领悟篇：纹章效果提升加成
	return max(0.0, 1.0 + emblem_effect_rate + study_emblem_effect_bonus)

func get_scaled_emblem_value(base_value: float) -> float:
	return base_value * get_emblem_effect_multiplier()

func get_total_skill_cooldown_reduction() -> float:
	var effective_cooldown := cooldown
	if typeof(PC) != TYPE_NIL and PC != null:
		effective_cooldown = PC.cooldown
	return clampf(effective_cooldown, 0.0, 0.5)

func get_cultivation_final_damage_bonus() -> float:
	return max(0.0, cultivation_tongxiao_level * 0.01)

func get_special_pill_max_uses(tier: String) -> int:
	match tier:
		"lower":
			return special_pill_lower_max_uses
		"middle":
			return special_pill_middle_max_uses
		"upper":
			return special_pill_upper_max_uses
		_:
			return 0

func is_elite_or_boss_target(target: Node) -> bool:
	if target == null or !is_instance_valid(target):
		return false
	return target.is_in_group("elite") or target.is_in_group("boss")

func get_enemy_damage_bonus_multiplier(target: Node) -> float:
	var bonus: float = _get_effective_normal_monster_bonus()
	if is_elite_or_boss_target(target):
		bonus = _get_effective_boss_bonus()
	var multiplier: float = max(0.0, 1.0 + bonus)
	return multiplier

func apply_enemy_damage_bonus(damage: float, target: Node) -> float:
	if damage <= 0.0:
		return damage
	return damage * get_enemy_damage_bonus_multiplier(target)

func get_achievement_weapon_damage_bonus(weapon_tag: String) -> float:
	var achievement_manager = get_node_or_null("/root/AchievementManager")
	if achievement_manager != null and achievement_manager.has_method("get_category_damage_bonus_by_weapon_tag"):
		return float(achievement_manager.get_category_damage_bonus_by_weapon_tag(weapon_tag))
	return 0.0

func get_initial_refresh_num() -> int:
	return refresh_max_num + _get_achievement_initial_int_bonus("get_initial_refresh_bonus")

func get_initial_lock_num() -> int:
	return initial_lock_num + _get_achievement_initial_int_bonus("get_initial_lock_bonus")

func get_initial_ban_num() -> int:
	return initial_ban_num + _get_achievement_initial_int_bonus("get_initial_ban_bonus")

func get_achievement_initial_lucky_bonus() -> int:
	return _get_achievement_initial_int_bonus("get_initial_lucky_bonus")

func _get_achievement_initial_int_bonus(method_name: String) -> int:
	var achievement_manager = get_node_or_null("/root/AchievementManager")
	if achievement_manager != null and achievement_manager.has_method(method_name):
		return int(achievement_manager.call(method_name))
	return 0

func get_achievement_summon_damage_bonus() -> float:
	var achievement_manager = get_node_or_null("/root/AchievementManager")
	if achievement_manager != null and achievement_manager.has_method("get_summon_damage_bonus"):
		return float(achievement_manager.get_summon_damage_bonus())
	return 0.0

## 显示保存指示器动画（右下角，渐进渐出，持续2秒）
# ===== 角色独立键位配置辅助 =====

## 获取当前角色的技能键位配置（自动补全缺失角色）
func get_current_active_skills() -> Dictionary:
	var hero := PC.player_name
	if not player_now_active_skill.has(hero):
		player_now_active_skill[hero] = _default_skill_config()
	return player_now_active_skill[hero]

func get_available_start_weapons() -> Array[Dictionary]:
	sync_available_start_weapons()
	var weapon_config := _get_start_weapon_config()
	var weapons: Array[Dictionary] = []
	for weapon_id in available_start_weapons:
		var normalized_id := normalize_start_weapon_id(weapon_id)
		if weapon_config.has(normalized_id):
			weapons.append(weapon_config[normalized_id])
	return weapons

func _get_start_weapon_config() -> Dictionary:
	return {
		"SwordQi": {"id": "SwordQi", "display_name": "剑气诀", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/jianqi.png", "faze_levels": {"faze_sword_level": 3, "faze_bullet_level": 3}, "faze_text": "刀剑法则+3，弹雨法则+3"},
		"Qigong": {"id": "Qigong", "display_name": "气功波", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/qigong.png", "faze_levels": {"faze_wind_level": 3, "faze_wide_level": 3}, "faze_text": "啸风法则+3，广域法则+3"},
		"LightBullet": {"id": "LightBullet", "display_name": "光弹术", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/guangdan.png", "faze_levels": {"faze_life_level": 3, "faze_bullet_level": 3}, "faze_text": "生灵法则+3，弹雨法则+3"},
		"Ice": {"id": "Ice", "display_name": "冰刺术", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/binghua.png", "faze_levels": {"faze_destroy_level": 3, "faze_bullet_level": 3}, "faze_text": "破坏法则+3，弹雨法则+3"},
		"Xunfeng": {"id": "Xunfeng", "display_name": "巽风诀", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/xunfeng.png", "faze_levels": {"faze_wind_level": 3, "faze_bullet_level": 3}, "faze_text": "啸风法则+3，弹雨法则+3"},
		"Genshan": {"id": "Genshan", "display_name": "艮山诀", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/genshan.png", "faze_levels": {"faze_bagua_level": 3, "faze_shield_level": 3}, "faze_text": "八卦法则+3，护佑法则+3"},
		"Bloodwave": {"id": "Bloodwave", "display_name": "血气波", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/xueqibo.png", "faze_levels": {"faze_wide_level": 3, "faze_blood_level": 3}, "faze_text": "广域法则+3，浴血法则+3"},
		"Xuanwu": {"id": "Xuanwu", "display_name": "玄武盾", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/xuanwu.png", "faze_levels": {"faze_shield_level": 3, "faze_treasure_level": 3}, "faze_text": "护佑法则+3，宝器法则+3"},
		"Water": {"id": "Water", "display_name": "坎水诀", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/kanshui.png", "faze_levels": {"faze_bagua_level": 3, "faze_heal_level": 3}, "faze_text": "八卦法则+3，愈疗法则+3"},
		"HolyLight": {"id": "HolyLight", "display_name": "圣光术", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shenshengzhuoshao.png", "faze_levels": {"faze_life_level": 3, "faze_heal_level": 3}, "faze_text": "生灵法则+3，愈疗法则+3"},
		"Branch": {"id": "Branch", "display_name": "仙枝", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/xianzhi.png", "faze_levels": {"faze_treasure_level": 3, "faze_bullet_level": 3}, "faze_text": "宝器法则+3，弹雨法则+3"},
		"Thunder": {"id": "Thunder", "display_name": "震雷诀", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/thunder.png", "faze_levels": {"faze_bagua_level": 3, "faze_thunder_level": 3}, "faze_text": "八卦法则+3，鸣雷法则+3"},
		"ThunderBreak": {"id": "ThunderBreak", "display_name": "天雷破", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/tianleipo2.png", "faze_levels": {"faze_thunder_level": 3, "faze_destroy_level": 3}, "faze_text": "鸣雷法则+3，破坏法则+3"},
		"Moyan": {"id": "Moyan", "display_name": "爆炎诀", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/moyan.png", "faze_levels": {"faze_fire_level": 3, "faze_destroy_level": 3}, "faze_text": "炽焰法则+3，破坏法则+3"},
		"Qiankun": {"id": "Qiankun", "display_name": "乾坤双剑", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/qiankun.png", "faze_levels": {"faze_sword_level": 3, "faze_bagua_level": 3}, "faze_text": "刀剑法则+3，八卦法则+3"},
		"BloodBoardSword": {"id": "BloodBoardSword", "display_name": "饮血刀", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/yinxue.png", "faze_levels": {"faze_sword_level": 3, "faze_blood_level": 3}, "faze_text": "刀剑法则+3，浴血法则+3"},
		"Zhuazhuajuchui": {"id": "Zhuazhuajuchui", "display_name": "爪爪巨锤", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/zhuazhuachui.png", "faze_levels": {"faze_deep_level": 3, "faze_blood_level": 3}, "faze_text": "沉渊法则+3，浴血法则+3"},
		"Riyan": {"id": "Riyan", "display_name": "赤曜", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/riyan.png", "faze_levels": {"faze_fire_level": 3, "faze_wide_level": 3}, "faze_text": "炽焰法则+3，广域法则+3"},
		"RingFire": {"id": "RingFire", "display_name": "离火诀", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/lihuo.png", "faze_levels": {"faze_fire_level": 3, "faze_bagua_level": 3}, "faze_text": "炽焰法则+3，八卦法则+3"},
		"Duize": {"id": "Duize", "display_name": "兑泽诀", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/duize.png", "faze_levels": {"faze_bagua_level": 3, "faze_wide_level": 3}, "faze_text": "八卦法则+3，广域法则+3"},
		"DragonWind": {"id": "DragonWind", "display_name": "风龙杖", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/fenglongzhang.png", "faze_levels": {"faze_treasure_level": 3, "faze_wind_level": 3}, "faze_text": "宝器法则+3，啸风法则+3"},
	}

func get_start_weapon_faze_levels(weapon_id: String = "") -> Dictionary:
	var resolved_id := normalize_start_weapon_id(weapon_id)
	if resolved_id.is_empty():
		resolved_id = get_selected_start_weapon()
	var weapon_config := _get_start_weapon_config()
	if not weapon_config.has(resolved_id):
		return {}
	return (weapon_config[resolved_id].get("faze_levels", {}) as Dictionary).duplicate(true)

func get_start_weapon_faze_text(weapon_id: String = "") -> String:
	var resolved_id := normalize_start_weapon_id(weapon_id)
	if resolved_id.is_empty():
		resolved_id = get_selected_start_weapon()
	var weapon_config := _get_start_weapon_config()
	if not weapon_config.has(resolved_id):
		return ""
	return str(weapon_config[resolved_id].get("faze_text", ""))

func sync_available_start_weapons() -> void:
	var weapon_config := _get_start_weapon_config()
	var normalized_weapons: Array[String] = []
	for weapon_id in ["SwordQi", "Qigong"]:
		_add_available_start_weapon_id(normalized_weapons, weapon_config, weapon_id)
	if unlock_noam:
		_add_available_start_weapon_id(normalized_weapons, weapon_config, "LightBullet")
	if unlock_kansel:
		_add_available_start_weapon_id(normalized_weapons, weapon_config, "Ice")
	if unlock_xueming:
		_add_available_start_weapon_id(normalized_weapons, weapon_config, "Zhuazhuajuchui")

	var achievement_manager = get_node_or_null("/root/AchievementManager")
	if achievement_manager != null and achievement_manager.has_method("get_unlocked_start_weapons"):
		for weapon_id in achievement_manager.get_unlocked_start_weapons():
			_add_available_start_weapon_id(normalized_weapons, weapon_config, str(weapon_id))

	_sort_start_weapon_ids(normalized_weapons)
	available_start_weapons = normalized_weapons

func _add_available_start_weapon_id(target: Array[String], weapon_config: Dictionary, weapon_id: String) -> void:
	var normalized_id := normalize_start_weapon_id(str(weapon_id))
	if weapon_config.has(normalized_id) and not target.has(normalized_id):
		target.append(normalized_id)

func _sort_start_weapon_ids(weapon_ids: Array[String]) -> void:
	weapon_ids.sort_custom(func(a: String, b: String) -> bool:
		var ai := START_WEAPON_ORDER.find(a)
		var bi := START_WEAPON_ORDER.find(b)
		if ai == -1:
			ai = 9999
		if bi == -1:
			bi = 9999
		return ai < bi
	)

func is_start_weapon_available(weapon_id: String) -> bool:
	for weapon in get_available_start_weapons():
		if str(weapon.get("id", "")) == weapon_id:
			return true
	return false

func _get_current_start_weapon_hero(hero_name: String = "") -> String:
	var hero := hero_name.strip_edges()
	if hero.is_empty() and typeof(PC) != TYPE_NIL and PC != null:
		hero = PC.player_name
	if hero.is_empty():
		hero = "yiqiu"
	return hero

func normalize_start_weapon_id(weapon_id: String) -> String:
	match weapon_id:
		"SwordQi":
			return "SwordQi"
		"RingFire":
			return "RingFire"
		"BloodBoardSword":
			return "BloodBoardSword"
		"LightBullet":
			return "LightBullet"
		"ThunderBreak":
			return "ThunderBreak"
		"HolyLight":
			return "HolyLight"
		"DragonWind":
			return "DragonWind"
		"Zhuazhuajuchui":
			return "Zhuazhuajuchui"
		_:
			return weapon_id

func get_default_start_weapon_for_hero(hero_name: String = "") -> String:
	var hero := _get_current_start_weapon_hero(hero_name)
	var weapon_id := normalize_start_weapon_id(str(DEFAULT_START_WEAPON_BY_HERO.get(hero, "SwordQi")))
	if is_start_weapon_available(weapon_id):
		return weapon_id
	return _get_first_available_start_weapon_id()

func _get_first_available_start_weapon_id() -> String:
	var available_weapons := get_available_start_weapons()
	if available_weapons.is_empty():
		return "SwordQi"
	return str(available_weapons[0].get("id", "SwordQi"))

func get_selected_start_weapon(hero_name: String = "") -> String:
	var hero := _get_current_start_weapon_hero(hero_name)
	var resolved_id := ""
	if selected_start_weapons_by_hero.has(hero):
		resolved_id = normalize_start_weapon_id(str(selected_start_weapons_by_hero[hero]))
		if not is_start_weapon_available(resolved_id):
			selected_start_weapons_by_hero.erase(hero)
			resolved_id = ""
	if resolved_id.is_empty():
		resolved_id = get_default_start_weapon_for_hero(hero)
	selected_start_weapon = resolved_id
	return resolved_id

func set_selected_start_weapon(weapon_id: String, hero_name: String = "") -> void:
	var hero := _get_current_start_weapon_hero(hero_name)
	var normalized_id := normalize_start_weapon_id(weapon_id)
	if not is_start_weapon_available(normalized_id):
		normalized_id = get_default_start_weapon_for_hero(hero)
	if normalized_id == get_default_start_weapon_for_hero(hero):
		selected_start_weapons_by_hero.erase(hero)
	else:
		selected_start_weapons_by_hero[hero] = normalized_id
	selected_start_weapon = normalized_id

func _normalize_selected_start_weapon_overrides() -> void:
	var normalized_overrides: Dictionary = {}
	for hero_name in selected_start_weapons_by_hero.keys():
		var hero := str(hero_name)
		var weapon_id := normalize_start_weapon_id(str(selected_start_weapons_by_hero[hero_name]))
		if weapon_id.is_empty():
			continue
		if is_start_weapon_available(weapon_id):
			normalized_overrides[hero] = weapon_id
	selected_start_weapons_by_hero = normalized_overrides
	selected_start_weapon = get_selected_start_weapon()

func _default_skill_config() -> Dictionary:
	return {
		"space": {"name": "dodge"},
		"q": {"name": ""},
		"e": {"name": ""}
	}

func _get_default_skill_config_for_hero(hero_name: String) -> Dictionary:
	return {
		"space": {"name": "dodge"},
		"q": {"name": _get_default_q_skill(hero_name)},
		"e": {"name": ""}
	}

func _get_default_q_skill(hero_name: String) -> String:
	match hero_name:
		"moning":
			return "wind_thunder"
		"yiqiu":
			return "beastify"
		"noam":
			return "heal_hot"
		"kansel":
			return "magical_fire"
		"xueming":
			return "destructive_hammer"
		_:
			return ""

func get_active_skill_base_level(skill_id: String) -> int:
	return int(player_active_skill_data.get(skill_id, {}).get("level", 1))

func get_active_skill_study_level_bonus(skill_id: String) -> int:
	var study_node := str(ACTIVE_SKILL_STUDY_LEVEL_NODES.get(skill_id, ""))
	if study_node.is_empty():
		return 0
	return int(player_study_tree.get(study_node, 0))

func get_active_skill_effective_level(skill_id: String) -> int:
	return max(1, get_active_skill_base_level(skill_id) + get_active_skill_study_level_bonus(skill_id))

func format_active_skill_level_text(skill_id: String) -> String:
	var effective_level := get_active_skill_effective_level(skill_id)
	var study_bonus := get_active_skill_study_level_bonus(skill_id)
	if study_bonus > 0:
		return "LV." + str(effective_level) + "(+" + str(study_bonus) + ")"
	return "LV." + str(effective_level)


func _show_save_indicator() -> void:
	# 如果已有动画在播放，先清理
	if _save_indicator_tween and _save_indicator_tween.is_running():
		_save_indicator_tween.kill()
	if _save_indicator_layer and is_instance_valid(_save_indicator_layer):
		_save_indicator_layer.queue_free()
	
	# 创建CanvasLayer确保显示在最上层
	_save_indicator_layer = CanvasLayer.new()
	_save_indicator_layer.layer = 100
	add_child(_save_indicator_layer)
	
	# 实例化loading动画场景
	var indicator = SAVE_INDICATOR_SCENE.instantiate()
	# 将动画精灵位置设置为容器中心
	var animated_sprite = indicator.get_child(0) if indicator.get_child_count() > 0 else null
	if animated_sprite:
		animated_sprite.position = Vector2(30, 30)
	
	# 用Control包裹，通过锚点定位到屏幕右下角
	var container = Control.new()
	container.name = "SaveIndicatorContainer"
	# 锚点到右下角
	container.anchor_left = 1.0
	container.anchor_top = 1.0
	container.anchor_right = 1.0
	container.anchor_bottom = 1.0
	container.offset_left = -70
	container.offset_top = -70
	container.offset_right = -10
	container.offset_bottom = -10
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.modulate.a = 0.0
	container.add_child(indicator)
	_save_indicator_layer.add_child(container)
	
	# 创建渐进渐出动画：0.3秒淡入 + 1.4秒保持 + 0.3秒淡出 = 2秒
	_save_indicator_tween = create_tween()
	_save_indicator_tween.tween_property(container, "modulate:a", 1.0, 0.3)
	_save_indicator_tween.tween_interval(1.4)
	_save_indicator_tween.tween_property(container, "modulate:a", 0.0, 0.3)
	_save_indicator_tween.tween_callback(func():
		if is_instance_valid(_save_indicator_layer):
			_save_indicator_layer.queue_free()
	)

func save_game(force_now: bool = false):
	if not force_now and _should_defer_save_game():
		_request_deferred_battle_save()
		return
	# 显示保存指示器动画
	_show_save_indicator()
	_normalize_selected_start_weapon_overrides()

	var config = ConfigFile.new()
	var data = {
		"total_points": total_points,
		"player_name": PC.player_name,
		"world_level": world_level,
		"world_level_multiple": world_level_multiple,
		"world_level_reward_multiple": world_level_reward_multiple,
		"lunky_level": lunky_level,
		"exp_multi": exp_multi,
		"drop_multi": drop_multi,
		"body_size": body_size,
		"attack_range": attack_range,
		"heal_multi": heal_multi,
		"sheild_multi": sheild_multi,
		"normal_monster_multi": normal_monster_multi,
		"boss_multi": boss_multi,
		"cooldown": cooldown,
		"active_skill_multi": active_skill_multi,
		"fruit_heal_multi": fruit_heal_multi,
		"fruit_heal_multi_used_count": fruit_heal_multi_used_count,
		"pill_used_counts": pill_used_counts,
		"player_inventory": player_inventory,
		"lingshi": lingshi,
		"shop_level": shop_level,
		"shop_battle_refresh_count": shop_battle_refresh_count,
		"zhenqi_economy_version": ZHENQI_ECONOMY_VERSION,
		"shop_lingshi_unit_price": shop_lingshi_unit_price,
		"has_seen_battle_tutorial": has_seen_battle_tutorial,
		"has_seen_town_tutorial": has_seen_town_tutorial,
		"has_seen_peach_grove_dialogue": has_seen_peach_grove_dialogue,
		"has_seen_peach_grove_boss": has_seen_peach_grove_boss,
		"has_seen_peach_grove_boss_charge": has_seen_peach_grove_boss_charge,
		"has_seen_ruin_boss": has_seen_ruin_boss,
		"has_seen_cave_boss": has_seen_cave_boss,
		"has_seen_forest_boss": has_seen_forest_boss,
		"town_companion_dialogue_history": town_companion_dialogue_history,
		"total_defeat_count": total_defeat_count,
		"has_seen_story_2": has_seen_story_2,
		"has_seen_story_3": has_seen_story_3,
		"has_seen_story_4": has_seen_story_4,
		"has_seen_story_5": has_seen_story_5,
		"has_seen_story_6": has_seen_story_6,
		"has_seen_story_7": has_seen_story_7,
		"has_seen_story_8": has_seen_story_8,
		"has_received_story_6_magic_core_reward": has_received_story_6_magic_core_reward,
		"has_seen_liandan_tutorial": has_seen_liandan_tutorial,
		"has_seen_shop_tutorial": has_seen_shop_tutorial,
		"has_seen_poem_tutorial": has_seen_poem_tutorial,
		"has_seen_qi_vortex_tutorial": has_seen_qi_vortex_tutorial,
		"shop_first_entered": shop_first_entered,
		"shop_saved_items": shop_saved_items,
		"has_visited_town": has_visited_town,
		"is_first_game": is_first_game,
		"stage_difficulty_clear_progress": stage_difficulty_clear_progress,
		"core_depth_clear_progress": core_depth_clear_progress,
		"selected_core_depth": selected_core_depth,
		"recipe_unlock_progress": recipe_unlock_progress,


		"unlock_moning": unlock_moning,
		"unlock_yiqiu": unlock_yiqiu,
		"unlock_noam": unlock_noam,
		"unlock_kansel": unlock_kansel,
		"unlock_xueming": unlock_xueming,
		"refresh_base_version": REFRESH_BASE_VERSION,
		"refresh_max_num": refresh_max_num,
		"initial_lock_num": initial_lock_num,
		"initial_ban_num": initial_ban_num,
		"cultivation_unlock_progress": cultivation_unlock_progress,
		"cultivation_poxu_level": cultivation_poxu_level,
		"cultivation_xuanyuan_level": cultivation_xuanyuan_level,
		"cultivation_liuguang_level": cultivation_liuguang_level,
		"cultivation_hualing_level": cultivation_hualing_level,
		"cultivation_fengrui_level": cultivation_fengrui_level,
		"cultivation_huti_level": cultivation_huti_level,
		"cultivation_zhuifeng_level": cultivation_zhuifeng_level,
		"cultivation_liejin_level": cultivation_liejin_level,
		"cultivation_heyi_level": cultivation_heyi_level,
		"cultivation_tongxiao_level": cultivation_tongxiao_level,
		"cultivation_poxu_level_max": cultivation_poxu_level_max,
		"cultivation_xuanyuan_level_max": cultivation_xuanyuan_level_max,
		"cultivation_liuguang_level_max": cultivation_liuguang_level_max,
		"cultivation_hualing_level_max": cultivation_hualing_level_max,
		"cultivation_fengrui_level_max": cultivation_fengrui_level_max,
		"cultivation_huti_level_max": cultivation_huti_level_max,
		"cultivation_zhuifeng_level_max": cultivation_zhuifeng_level_max,
		"cultivation_liejin_level_max": cultivation_liejin_level_max,
		"player_study_data": player_study_data,
		"player_study_tree": player_study_tree,
		# 修习树武器伤害加成
		"study_main_weapon_damage_bonus": study_main_weapon_damage_bonus,
		"study_sword_damage_bonus": study_sword_damage_bonus,
		"study_projectile_damage_bonus": study_projectile_damage_bonus,
		"study_wind_damage_bonus": study_wind_damage_bonus,
		"study_wide_damage_bonus": study_wide_damage_bonus,
		"study_life_damage_bonus": study_life_damage_bonus,
		"study_destroy_damage_bonus": study_destroy_damage_bonus,
		"study_fire_damage_bonus": study_fire_damage_bonus,
		"study_protect_damage_bonus": study_protect_damage_bonus,
		"study_thunder_damage_bonus": study_thunder_damage_bonus,
		"study_bagua_damage_bonus": study_bagua_damage_bonus,
		"study_heal_damage_bonus": study_heal_damage_bonus,
		"study_treasure_damage_bonus": study_treasure_damage_bonus,
		"study_blood_damage_bonus": study_blood_damage_bonus,
		"study_deep_damage_bonus": study_deep_damage_bonus,
		"study_shehun_damage_bonus": study_shehun_damage_bonus,
		# 修习树武器解锁
		"study_unlock_qiankun": study_unlock_qiankun,
		"study_unlock_dragonwind": study_unlock_dragonwind,
		"study_unlock_bloodwave": study_unlock_bloodwave,
		"study_unlock_water": study_unlock_water,
		"study_unlock_baoyan": study_unlock_baoyan,
		"study_unlock_genshan": study_unlock_genshan,
		"study_unlock_thunder_break": study_unlock_thunder_break,
		"study_unlock_holylight": study_unlock_holylight,
		"study_unlock_xuanwu": study_unlock_xuanwu,
		# 修习树领悟篇加成
		"study_emblem_effect_bonus": study_emblem_effect_bonus,
		"study_initial_lucky": study_initial_lucky,
		"study_summon_damage_bonus": study_summon_damage_bonus,
		"study_summon_interval_reduction": study_summon_interval_reduction,
		"study_emblem_slots_bonus": study_emblem_slots_bonus,
		"study_exp_bonus": study_exp_bonus,
		"study_exp_reduction": study_exp_reduction,
		"study_six_chance_bonus": study_six_chance_bonus,
		"study_red_chance_bonus": study_red_chance_bonus,
		"study_gold_chance_bonus": study_gold_chance_bonus,
		"study_purple_chance_bonus": study_purple_chance_bonus,
		# 修习树团队篇加成
		"study_atk_bonus": study_atk_bonus,
		"study_hp_bonus": study_hp_bonus,
		"study_atk_speed_bonus": study_atk_speed_bonus,
		"study_move_speed_bonus": study_move_speed_bonus,
		"study_crit_rate_bonus": study_crit_rate_bonus,
		"study_crit_damage_bonus": study_crit_damage_bonus,
		"study_qi_gain_bonus": study_qi_gain_bonus,
		"study_damage_reduction_bonus": study_damage_reduction_bonus,
		"study_final_damage_bonus": study_final_damage_bonus,
		"study_normal_monster_damage_bonus": study_normal_monster_damage_bonus,
		"study_elite_damage_bonus": study_elite_damage_bonus,
		"study_drop_rate_bonus": study_drop_rate_bonus,
		# 修习树特殊篇加成
		"study_heal_aura_recovery_bonus": study_heal_aura_recovery_bonus,
		"study_heal_aura_spawn_chance": study_heal_aura_spawn_chance,
		"study_heal_aura_speed_bonus": study_heal_aura_speed_bonus,
		"study_heal_aura_damage_reduction": study_heal_aura_damage_reduction,
		"study_fragment_drop_chance": study_fragment_drop_chance,
		"study_boss_core_drop_chance": study_boss_core_drop_chance,
		"study_levelup_heal_bonus": study_levelup_heal_bonus,
		"study_levelup_atk_bonus": study_levelup_atk_bonus,
		"study_levelup_hp_bonus": study_levelup_hp_bonus,
		"study_gold_ball_unlocked": study_gold_ball_unlocked,
		"study_gold_ball_chance_bonus": study_gold_ball_chance_bonus,
		"study_gold_ball_qi_bonus": study_gold_ball_qi_bonus,
		# 修习树技能篇加成
		"study_unlock_shouhua": study_unlock_shouhua,
		"study_unlock_shensheng": study_unlock_shensheng,
		"study_unlock_mowenzhen": study_unlock_mowenzhen,
		"study_unlock_xuanbing": study_unlock_xuanbing,
		"study_unlock_luanji": study_unlock_luanji,
		"study_unlock_liaoshang": study_unlock_liaoshang,
		"study_unlock_mizongbu": study_unlock_mizongbu,
		"study_unlock_shuimu": study_unlock_shuimu,
		"study_unlock_mingxiang": study_unlock_mingxiang,
		"study_unlock_chiyan": study_unlock_chiyan,
		"study_fengleipo_damage_bonus": study_fengleipo_damage_bonus,
		"study_fengleipo_range_bonus": study_fengleipo_range_bonus,
		"study_shouhua_duration_bonus": study_shouhua_duration_bonus,
		"study_shouhua_atkspeed_bonus": study_shouhua_atkspeed_bonus,
		"study_shensheng_duration_bonus": study_shensheng_duration_bonus,
		"study_shensheng_damage_bonus": study_shensheng_damage_bonus,
		"study_mowenzhen_size_bonus": study_mowenzhen_size_bonus,
		"study_mowenzhen_cd_reduction": study_mowenzhen_cd_reduction,
		"study_xuanbing_size_bonus": study_xuanbing_size_bonus,
		"study_xuanbing_damage_bonus": study_xuanbing_damage_bonus,
		"study_liaoyu_recovery_bonus": study_liaoyu_recovery_bonus,
		"study_liaoyu_cd_reduction": study_liaoyu_cd_reduction,
		"study_luanji_count_bonus": study_luanji_count_bonus,
		"study_luanji_damage_bonus": study_luanji_damage_bonus,
		"study_mizongbu_duration_bonus": study_mizongbu_duration_bonus,
		"study_mizongbu_dmgreduction_bonus": study_mizongbu_dmgreduction_bonus,
		"study_shuimu_shield_bonus": study_shuimu_shield_bonus,
		"study_shuimu_cd_reduction": study_shuimu_cd_reduction,
		"study_mingxiang_cd_reduction": study_mingxiang_cd_reduction,
		"study_shanbi_invincible_bonus": study_shanbi_invincible_bonus,
		"study_shanbi_cd_reduction": study_shanbi_cd_reduction,
		"study_chiyan_enhance_damage_bonus": study_chiyan_enhance_damage_bonus,
		"player_active_skill_data": player_active_skill_data,
		"player_now_active_skill": player_now_active_skill,
		"available_start_weapons": available_start_weapons,
		"selected_start_weapons_by_hero": selected_start_weapons_by_hero,
		"achievement_data": get_node_or_null("/root/AchievementManager").export_save_data() if get_node_or_null("/root/AchievementManager") != null else {},
		"guide_data": get_node_or_null("/root/GuideManager").export_save_data() if get_node_or_null("/root/GuideManager") != null else {},
		"max_main_skill_num": max_main_skill_num,
		"max_weapon_num": max_weapon_num,
		"emblem_slots_max": emblem_slots_max,
		"emblem_effect_rate": emblem_effect_rate,
		"max_carry_equipment_slots": max_carry_equipment_slots,
		"equipment_data": equipment_manager.save_equipment_data(),
		"master_volume": audio_manager.get_master_volume(),
		"bgm_volume": audio_manager.get_bgm_volume(),
		"sfx_volume": audio_manager.get_sfx_volume(),
		"bg_volume": audio_manager.get_bg_volume(),
		"damage_show_enabled": damage_show_enabled,
		"damage_show_type": damage_show_type,
		"particle_enable": particle_enable,
		"moretip": moretip,
		"screen_shake_enabled": screen_shake_enabled,
		"time_slow_enabled": time_slow_enabled,
		"is_test": is_test,
		"resolution_index": settings_manager.get_current_resolution_index() if settings_manager else 6,
		"is_fullscreen": settings_manager.is_fullscreen_enabled() if settings_manager else true,
		"noborder_enabled": settings_manager.is_noborder_enabled() if settings_manager else true,
		"vignetting_enabled": settings_manager.is_vignetting_enabled() if settings_manager else true,
		"player_hp_bar_enabled": settings_manager.is_player_hp_bar_enabled() if settings_manager else true,
	}

	for key in data:
		config.set_value("save", key, data[key])
	
	var err = SaveCrypto.save_config(config, CONFIG_PATH)
	if err == OK:
		print("save success")
	else:
		push_error("save error")
	
	audio_manager.save_audio_settings()

func _request_deferred_battle_save() -> void:
	_deferred_battle_save_requested = true
	if _deferred_battle_save_running:
		return
	_deferred_battle_save_running = true
	call_deferred("_flush_deferred_battle_save")

func _flush_deferred_battle_save() -> void:
	while true:
		var tree := get_tree()
		if tree == null:
			break
		while _should_defer_save_game():
			await tree.create_timer(DEFERRED_BATTLE_SAVE_RETRY_SECONDS, true).timeout
			if get_tree() == null:
				break
		if not _deferred_battle_save_requested:
			break
		_deferred_battle_save_requested = false
		save_game(true)
		if not _deferred_battle_save_requested:
			break
	_deferred_battle_save_running = false
	if _deferred_battle_save_requested:
		_request_deferred_battle_save()

func _should_defer_save_game() -> bool:
	if not _is_battle_running_for_save_defer():
		return false
	return true

func _is_battle_running_for_save_defer() -> bool:
	if in_town or in_menu or is_level_up:
		return false
	if PC.is_game_over:
		return false
	var tree := get_tree()
	if tree == null or tree.paused:
		return false
	if current_stage_id.is_empty() or not STAGE_ID_LIST.has(current_stage_id):
		return false
	var current_scene := tree.current_scene
	if current_scene == null:
		return false
	var scene_stage_id = current_scene.get("STAGE_ID")
	return scene_stage_id != null and not str(scene_stage_id).is_empty()

func _migrate_zhenqi_economy_if_needed(loaded_version: int) -> void:
	if loaded_version >= ZHENQI_ECONOMY_VERSION:
		return
	total_points = int(round(float(total_points) * ZHENQI_ECONOMY_SCALE))
	shop_lingshi_unit_price = maxf(shop_lingshi_unit_price * ZHENQI_ECONOMY_SCALE, 5.0)
	for i in range(shop_saved_items.size()):
		var offer = shop_saved_items[i]
		if typeof(offer) != TYPE_DICTIONARY:
			continue
		var offer_dict := offer as Dictionary
		if str(offer_dict.get("cost_resource", "")) != "point":
			continue
		if str(offer_dict.get("product_type", "")) == "lingshi_pack":
			offer_dict["cost"] = int(round(float(offer_dict.get("quantity", 0)) * shop_lingshi_unit_price))
		else:
			offer_dict["cost"] = int(round(float(offer_dict.get("cost", 0)) * ZHENQI_ECONOMY_SCALE))
		shop_saved_items[i] = offer_dict

func load_game():
	var config = ConfigFile.new()
	var err = SaveCrypto.load_config(config, CONFIG_PATH)
	if err != OK: return
	
	var loaded_zhenqi_economy_version := int(config.get_value("save", "zhenqi_economy_version", 1))
	total_points = config.get_value("save", "total_points", total_points)
	PC.player_name = config.get_value("save", "player_name", PC.player_name)
	world_level = config.get_value("save", "world_level", world_level)
	world_level_multiple = config.get_value("save", "world_level_multiple", world_level_multiple)
	world_level_reward_multiple = config.get_value("save", "world_level_reward_multiple", world_level_reward_multiple)
	lunky_level = config.get_value("save", "lunky_level", lunky_level)
	red_p = 0.2
	gold_p = 4
	darkorchid_p = 20.5
	blue_p = 75
	exp_multi = config.get_value("save", "exp_multi", exp_multi)
	drop_multi = config.get_value("save", "drop_multi", drop_multi)
	body_size = config.get_value("save", "body_size", body_size)
	heal_multi = config.get_value("save", "heal_multi", heal_multi)
	sheild_multi = config.get_value("save", "sheild_multi", sheild_multi)
	attack_range = config.get_value("save", "attack_range", attack_range)
	normal_monster_multi = config.get_value("save", "normal_monster_multi", normal_monster_multi)
	boss_multi = config.get_value("save", "boss_multi", boss_multi)
	cooldown = config.get_value("save", "cooldown", cooldown)
	active_skill_multi = config.get_value("save", "active_skill_multi", active_skill_multi)
	fruit_heal_multi = config.get_value("save", "fruit_heal_multi", fruit_heal_multi)
	fruit_heal_multi_used_count = config.get_value("save", "fruit_heal_multi_used_count", fruit_heal_multi_used_count)
	pill_used_counts = config.get_value("save", "pill_used_counts", {})
	player_inventory = config.get_value("save", "player_inventory", {})
	lingshi = config.get_value("save", "lingshi", lingshi)
	var loaded_refresh_base_version := int(config.get_value("save", "refresh_base_version", 1))
	var loaded_refresh_max_num := int(config.get_value("save", "refresh_max_num", refresh_max_num))
	if loaded_refresh_base_version < REFRESH_BASE_VERSION and loaded_refresh_max_num >= LEGACY_INITIAL_REFRESH_BASE_NUM:
		loaded_refresh_max_num -= LEGACY_INITIAL_REFRESH_BASE_NUM - INITIAL_REFRESH_BASE_NUM
	refresh_max_num = maxi(INITIAL_REFRESH_BASE_NUM, loaded_refresh_max_num)
	shop_level = clampi(int(config.get_value("save", "shop_level", shop_level)), 1, 8)
	shop_battle_refresh_count = clampi(int(config.get_value("save", "shop_battle_refresh_count", shop_battle_refresh_count)), 0, refresh_max_num)
	shop_lingshi_unit_price = maxf(float(config.get_value("save", "shop_lingshi_unit_price", shop_lingshi_unit_price)), 5.0)
	shop_first_entered = config.get_value("save", "shop_first_entered", shop_first_entered) == true
	has_visited_town = config.get_value("save", "has_visited_town", false) == true
	is_first_game = config.get_value("save", "is_first_game", true) == true
	has_seen_battle_tutorial = config.get_value("save", "has_seen_battle_tutorial", false) == true
	has_seen_town_tutorial = config.get_value("save", "has_seen_town_tutorial", false) == true
	has_seen_peach_grove_dialogue = config.get_value("save", "has_seen_peach_grove_dialogue", false) == true
	has_seen_peach_grove_boss = config.get_value("save", "has_seen_peach_grove_boss", false) == true
	has_seen_peach_grove_boss_charge = config.get_value("save", "has_seen_peach_grove_boss_charge", false) == true
	has_seen_ruin_boss = config.get_value("save", "has_seen_ruin_boss", false) == true
	has_seen_cave_boss = config.get_value("save", "has_seen_cave_boss", false) == true
	has_seen_forest_boss = config.get_value("save", "has_seen_forest_boss", false) == true
	var loaded_town_companion_dialogue_history = config.get_value("save", "town_companion_dialogue_history", {})
	if typeof(loaded_town_companion_dialogue_history) == TYPE_DICTIONARY:
		town_companion_dialogue_history = (loaded_town_companion_dialogue_history as Dictionary).duplicate(true)
	else:
		town_companion_dialogue_history = {}
	total_defeat_count = int(config.get_value("save", "total_defeat_count", 0))
	has_seen_story_2 = config.get_value("save", "has_seen_story_2", false) == true
	has_seen_story_3 = config.get_value("save", "has_seen_story_3", false) == true
	has_seen_story_4 = config.get_value("save", "has_seen_story_4", false) == true
	has_seen_story_5 = config.get_value("save", "has_seen_story_5", false) == true
	has_seen_story_6 = config.get_value("save", "has_seen_story_6", false) == true
	has_seen_story_7 = config.get_value("save", "has_seen_story_7", false) == true
	has_seen_story_8 = config.get_value("save", "has_seen_story_8", false) == true
	has_received_story_6_magic_core_reward = config.get_value("save", "has_received_story_6_magic_core_reward", false) == true
	has_seen_liandan_tutorial = config.get_value("save", "has_seen_liandan_tutorial", false) == true
	has_seen_shop_tutorial = config.get_value("save", "has_seen_shop_tutorial", false) == true
	has_seen_poem_tutorial = config.get_value("save", "has_seen_poem_tutorial", false) == true
	has_seen_qi_vortex_tutorial = config.get_value("save", "has_seen_qi_vortex_tutorial", false) == true
	var loaded_shop_items = config.get_value("save", "shop_saved_items", [])
	if typeof(loaded_shop_items) == TYPE_ARRAY:
		shop_saved_items = (loaded_shop_items as Array).duplicate(true)
	else:
		shop_saved_items = []
	_migrate_zhenqi_economy_if_needed(loaded_zhenqi_economy_version)
	var loaded_stage_clear_progress = config.get_value("save", "stage_difficulty_clear_progress", stage_difficulty_clear_progress)
	if typeof(loaded_stage_clear_progress) == TYPE_DICTIONARY:
		stage_difficulty_clear_progress = (loaded_stage_clear_progress as Dictionary).duplicate(true)
	else:
		stage_difficulty_clear_progress = stage_difficulty_clear_progress.duplicate(true)
	var loaded_core_depth_clear_progress = config.get_value("save", "core_depth_clear_progress", core_depth_clear_progress)
	if typeof(loaded_core_depth_clear_progress) == TYPE_DICTIONARY:
		core_depth_clear_progress = (loaded_core_depth_clear_progress as Dictionary).duplicate(true)
	else:
		core_depth_clear_progress = core_depth_clear_progress.duplicate(true)
	selected_core_depth = clamp_core_depth(int(config.get_value("save", "selected_core_depth", selected_core_depth)))
	_normalize_stage_difficulty_clear_progress()
	if player_inventory.has(LINGSHI_ITEM_ID):
		lingshi += int(player_inventory[LINGSHI_ITEM_ID])
		player_inventory.erase(LINGSHI_ITEM_ID)
	recipe_unlock_progress = config.get_value("save", "recipe_unlock_progress", recipe_unlock_progress)
	# 补齐旧存档缺失的配方解锁项
	if not recipe_unlock_progress.has("recipe_028"):
		recipe_unlock_progress["recipe_028"] = true


	unlock_moning = config.get_value("save", "unlock_moning", true)
	unlock_yiqiu = config.get_value("save", "unlock_yiqiu", true)
	unlock_noam = config.get_value("save", "unlock_noam", false)
	unlock_kansel = config.get_value("save", "unlock_kansel", false)
	unlock_xueming = is_stage_cleared("forest")
	refresh_max_num = maxi(INITIAL_REFRESH_BASE_NUM, loaded_refresh_max_num)
	initial_lock_num = maxi(1, int(config.get_value("save", "initial_lock_num", 1)))
	initial_ban_num = maxi(3, int(config.get_value("save", "initial_ban_num", 3)))
	cultivation_unlock_progress = config.get_value("save", "cultivation_unlock_progress", 0)
	cultivation_poxu_level = config.get_value("save", "cultivation_poxu_level", 0)
	cultivation_xuanyuan_level = config.get_value("save", "cultivation_xuanyuan_level", 0)
	cultivation_liuguang_level = config.get_value("save", "cultivation_liuguang_level", 0)
	cultivation_hualing_level = config.get_value("save", "cultivation_hualing_level", 0)
	cultivation_fengrui_level = config.get_value("save", "cultivation_fengrui_level", 0)
	cultivation_huti_level = config.get_value("save", "cultivation_huti_level", 0)
	cultivation_zhuifeng_level = config.get_value("save", "cultivation_zhuifeng_level", 0)
	cultivation_liejin_level = config.get_value("save", "cultivation_liejin_level", 0)
	cultivation_poxu_level_max = config.get_value("save", "cultivation_poxu_level_max", 50)
	cultivation_xuanyuan_level_max = config.get_value("save", "cultivation_xuanyuan_level_max", 50)
	cultivation_liuguang_level_max = config.get_value("save", "cultivation_liuguang_level_max", 25)
	cultivation_hualing_level_max = config.get_value("save", "cultivation_hualing_level_max", 50)
	cultivation_fengrui_level_max = config.get_value("save", "cultivation_fengrui_level_max", 25)
	cultivation_huti_level_max = config.get_value("save", "cultivation_huti_level_max", 25)
	cultivation_zhuifeng_level_max = config.get_value("save", "cultivation_zhuifeng_level_max", 25)
	cultivation_liejin_level_max = config.get_value("save", "cultivation_liejin_level_max", 50)
	var loaded_study_data = config.get_value("save", "player_study_data", player_study_data)
	for p_name in loaded_study_data.keys():
		if typeof(loaded_study_data[p_name]) != TYPE_DICTIONARY:
			continue
		var study_data := loaded_study_data[p_name] as Dictionary
		if study_data.has("zhenqi_points"):
			if loaded_zhenqi_economy_version < ZHENQI_ECONOMY_VERSION:
				study_data["zhenqi_points"] = int(round(float(study_data.get("zhenqi_points", 0)) * ZHENQI_ECONOMY_SCALE))
		else:
			study_data["zhenqi_points"] = 10
		loaded_study_data[p_name] = study_data
	player_study_data = loaded_study_data
	player_study_tree = config.get_value("save", "player_study_tree", player_study_tree)
	# 修习树武器伤害加成
	study_main_weapon_damage_bonus = config.get_value("save", "study_main_weapon_damage_bonus", 0.0)
	study_sword_damage_bonus = config.get_value("save", "study_sword_damage_bonus", 0.0)
	study_projectile_damage_bonus = config.get_value("save", "study_projectile_damage_bonus", 0.0)
	study_wind_damage_bonus = config.get_value("save", "study_wind_damage_bonus", 0.0)
	study_wide_damage_bonus = config.get_value("save", "study_wide_damage_bonus", 0.0)
	study_life_damage_bonus = config.get_value("save", "study_life_damage_bonus", 0.0)
	study_destroy_damage_bonus = config.get_value("save", "study_destroy_damage_bonus", 0.0)
	study_fire_damage_bonus = config.get_value("save", "study_fire_damage_bonus", 0.0)
	study_protect_damage_bonus = config.get_value("save", "study_protect_damage_bonus", 0.0)
	study_thunder_damage_bonus = config.get_value("save", "study_thunder_damage_bonus", 0.0)
	study_bagua_damage_bonus = config.get_value("save", "study_bagua_damage_bonus", 0.0)
	study_heal_damage_bonus = config.get_value("save", "study_heal_damage_bonus", 0.0)
	study_treasure_damage_bonus = config.get_value("save", "study_treasure_damage_bonus", 0.0)
	study_blood_damage_bonus = config.get_value("save", "study_blood_damage_bonus", 0.0)
	study_deep_damage_bonus = config.get_value("save", "study_deep_damage_bonus", 0.0)
	study_shehun_damage_bonus = config.get_value("save", "study_shehun_damage_bonus", 0.0)
	# 修习树武器解锁
	study_unlock_qiankun = true
	study_unlock_dragonwind = true
	study_unlock_bloodwave = true
	study_unlock_water = true
	study_unlock_baoyan = true
	study_unlock_genshan = true
	study_unlock_thunder_break = true
	study_unlock_holylight = true
	study_unlock_xuanwu = true
	# 修习树领悟篇加成
	study_emblem_effect_bonus = config.get_value("save", "study_emblem_effect_bonus", 0.0)
	study_initial_lucky = config.get_value("save", "study_initial_lucky", 0)
	study_summon_damage_bonus = config.get_value("save", "study_summon_damage_bonus", 0.0)
	study_summon_interval_reduction = config.get_value("save", "study_summon_interval_reduction", 0.0)
	study_emblem_slots_bonus = config.get_value("save", "study_emblem_slots_bonus", 0)
	study_exp_bonus = config.get_value("save", "study_exp_bonus", 0.0)
	study_exp_reduction = config.get_value("save", "study_exp_reduction", 0.0)
	study_six_chance_bonus = config.get_value("save", "study_six_chance_bonus", 0.0)
	study_red_chance_bonus = config.get_value("save", "study_red_chance_bonus", 0.0)
	study_gold_chance_bonus = config.get_value("save", "study_gold_chance_bonus", 0.0)
	study_purple_chance_bonus = config.get_value("save", "study_purple_chance_bonus", 0.0)
	# 修习树团队篇加成
	study_atk_bonus = config.get_value("save", "study_atk_bonus", 0.0)
	study_hp_bonus = config.get_value("save", "study_hp_bonus", 0)
	study_atk_speed_bonus = config.get_value("save", "study_atk_speed_bonus", 0.0)
	study_move_speed_bonus = config.get_value("save", "study_move_speed_bonus", 0.0)
	study_crit_rate_bonus = config.get_value("save", "study_crit_rate_bonus", 0.0)
	study_crit_damage_bonus = config.get_value("save", "study_crit_damage_bonus", 0.0)
	study_qi_gain_bonus = config.get_value("save", "study_qi_gain_bonus", 0.0)
	study_damage_reduction_bonus = config.get_value("save", "study_damage_reduction_bonus", 0.0)
	study_final_damage_bonus = config.get_value("save", "study_final_damage_bonus", 0.0)
	study_normal_monster_damage_bonus = config.get_value("save", "study_normal_monster_damage_bonus", 0.0)
	study_elite_damage_bonus = config.get_value("save", "study_elite_damage_bonus", 0.0)
	study_drop_rate_bonus = config.get_value("save", "study_drop_rate_bonus", 0.0)
	# 修习树特殊篇加成
	study_heal_aura_recovery_bonus = config.get_value("save", "study_heal_aura_recovery_bonus", 0.0)
	study_heal_aura_spawn_chance = config.get_value("save", "study_heal_aura_spawn_chance", 0.0)
	study_heal_aura_speed_bonus = config.get_value("save", "study_heal_aura_speed_bonus", 0.0)
	study_heal_aura_damage_reduction = config.get_value("save", "study_heal_aura_damage_reduction", 0.0)
	study_fragment_drop_chance = config.get_value("save", "study_fragment_drop_chance", 0.0)
	study_boss_core_drop_chance = config.get_value("save", "study_boss_core_drop_chance", 0.0)
	study_levelup_heal_bonus = config.get_value("save", "study_levelup_heal_bonus", 0.0)
	study_levelup_atk_bonus = config.get_value("save", "study_levelup_atk_bonus", 0)
	study_levelup_hp_bonus = config.get_value("save", "study_levelup_hp_bonus", 0)
	study_gold_ball_unlocked = config.get_value("save", "study_gold_ball_unlocked", false)
	study_gold_ball_chance_bonus = config.get_value("save", "study_gold_ball_chance_bonus", 0.0)
	study_gold_ball_qi_bonus = config.get_value("save", "study_gold_ball_qi_bonus", 0.0)
	# 修习树技能篇加成
	study_unlock_shouhua = config.get_value("save", "study_unlock_shouhua", false)
	study_unlock_shensheng = config.get_value("save", "study_unlock_shensheng", false)
	study_unlock_mowenzhen = config.get_value("save", "study_unlock_mowenzhen", false)
	study_unlock_xuanbing = config.get_value("save", "study_unlock_xuanbing", false)
	study_unlock_luanji = config.get_value("save", "study_unlock_luanji", false)
	study_unlock_liaoshang = config.get_value("save", "study_unlock_liaoshang", false)
	study_unlock_mizongbu = config.get_value("save", "study_unlock_mizongbu", false)
	study_unlock_shuimu = config.get_value("save", "study_unlock_shuimu", false)
	study_unlock_mingxiang = config.get_value("save", "study_unlock_mingxiang", false)
	study_unlock_chiyan = config.get_value("save", "study_unlock_chiyan", false)
	study_fengleipo_damage_bonus = config.get_value("save", "study_fengleipo_damage_bonus", 0.0)
	study_fengleipo_range_bonus = config.get_value("save", "study_fengleipo_range_bonus", 0.0)
	study_shouhua_duration_bonus = config.get_value("save", "study_shouhua_duration_bonus", 0.0)
	study_shouhua_atkspeed_bonus = config.get_value("save", "study_shouhua_atkspeed_bonus", 0.0)
	study_shensheng_duration_bonus = config.get_value("save", "study_shensheng_duration_bonus", 0.0)
	study_shensheng_damage_bonus = config.get_value("save", "study_shensheng_damage_bonus", 0.0)
	study_mowenzhen_size_bonus = config.get_value("save", "study_mowenzhen_size_bonus", 0.0)
	study_mowenzhen_cd_reduction = config.get_value("save", "study_mowenzhen_cd_reduction", 0.0)
	study_xuanbing_size_bonus = config.get_value("save", "study_xuanbing_size_bonus", 0.0)
	study_xuanbing_damage_bonus = config.get_value("save", "study_xuanbing_damage_bonus", 0.0)
	study_liaoyu_recovery_bonus = config.get_value("save", "study_liaoyu_recovery_bonus", 0.0)
	study_liaoyu_cd_reduction = config.get_value("save", "study_liaoyu_cd_reduction", 0.0)
	study_luanji_count_bonus = config.get_value("save", "study_luanji_count_bonus", 0)
	study_luanji_damage_bonus = config.get_value("save", "study_luanji_damage_bonus", 0.0)
	study_mizongbu_duration_bonus = config.get_value("save", "study_mizongbu_duration_bonus", 0.0)
	study_mizongbu_dmgreduction_bonus = config.get_value("save", "study_mizongbu_dmgreduction_bonus", 0.0)
	study_shuimu_shield_bonus = config.get_value("save", "study_shuimu_shield_bonus", 0.0)
	study_shuimu_cd_reduction = config.get_value("save", "study_shuimu_cd_reduction", 0.0)
	study_mingxiang_cd_reduction = config.get_value("save", "study_mingxiang_cd_reduction", 0.0)
	study_shanbi_invincible_bonus = config.get_value("save", "study_shanbi_invincible_bonus", 0.0)
	study_shanbi_cd_reduction = config.get_value("save", "study_shanbi_cd_reduction", 0.0)
	study_chiyan_enhance_damage_bonus = config.get_value("save", "study_chiyan_enhance_damage_bonus", 0.0)
	# 根据 player_study_tree 重算一次，确保一致性
	SettingStudyTreeUp.apply_all()
	SettingStudyTreeSkill.apply_all()
	SettingStudyTreeLearn.apply_all()
	SettingStudyTreeTeam.apply_all()
	SettingStudyTreeSpecial.apply_all()
	player_active_skill_data = config.get_value("save", "player_active_skill_data", player_active_skill_data)
	# 旧存档可能含有弃用的唤灵技能，清理掉
	player_active_skill_data.erase("huanling")
	# 强制修正技能图标路径，防止存档里的旧路径覆盖代码中更新的图标
	var _skill_icon_table: Dictionary = {
		"dodge": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shanbi.png",
		"mizongbu": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/mizongbu.png",
		"random_strike": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/luanji.png",
		"beastify": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shouhua.png",
		"heal_hot": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/yuliao.png",
		"water_sheild": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shuiliumu.png",
		"holy_fire": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shenshengzhuoshao.png",
		"magical_ice": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/binghua.png",
		"magical_fire": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/RingFire.png",
		"magic": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/mowenzhen.png",
		"meditation": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/meditation.png",
		"destructive_hammer": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/juchui.png",
	}
	for _sid in _skill_icon_table:
		if not player_active_skill_data.has(_sid):
			player_active_skill_data[_sid] = {"level": 1, "learned": [], "icon": _skill_icon_table[_sid]}
		else:
			player_active_skill_data[_sid]["icon"] = _skill_icon_table[_sid]
	player_now_active_skill = config.get_value("save", "player_now_active_skill", player_now_active_skill)
	sync_available_start_weapons()
	var has_selected_start_weapon_overrides := config.has_section_key("save", "selected_start_weapons_by_hero")
	var loaded_start_weapon_overrides = config.get_value("save", "selected_start_weapons_by_hero", {})
	selected_start_weapons_by_hero = {}
	if typeof(loaded_start_weapon_overrides) == TYPE_DICTIONARY:
		selected_start_weapons_by_hero = (loaded_start_weapon_overrides as Dictionary).duplicate(true)
	if not has_selected_start_weapon_overrides and config.has_section_key("save", "selected_start_weapon"):
		var legacy_weapon_id := normalize_start_weapon_id(str(config.get_value("save", "selected_start_weapon", selected_start_weapon)))
		var current_hero := _get_current_start_weapon_hero()
		if is_start_weapon_available(legacy_weapon_id) and legacy_weapon_id != get_default_start_weapon_for_hero(current_hero):
			selected_start_weapons_by_hero[current_hero] = legacy_weapon_id
	_normalize_selected_start_weapon_overrides()
	var achievement_manager = get_node_or_null("/root/AchievementManager")
	if achievement_manager != null and achievement_manager.has_method("import_save_data"):
		var achievement_data = config.get_value("save", "achievement_data", {})
		if typeof(achievement_data) == TYPE_DICTIONARY:
			achievement_manager.import_save_data(achievement_data)
		sync_available_start_weapons()
		_normalize_selected_start_weapon_overrides()
	var guide_manager = get_node_or_null("/root/GuideManager")
	if guide_manager != null and guide_manager.has_method("import_save_data"):
		var guide_data = config.get_value("save", "guide_data", {})
		if typeof(guide_data) == TYPE_DICTIONARY:
			guide_manager.import_save_data(guide_data)
	# 旧存档兼容：扁平格式（顶层键含 "space"）→ 迁移为角色嵌套格式
	if player_now_active_skill.has("space"):
		var _old_config = player_now_active_skill.duplicate(true)
		player_now_active_skill = {}
		for _hero_name in ["moning", "yiqiu", "noam", "kansel", "xueming"]:
			player_now_active_skill[_hero_name] = _old_config.duplicate(true)
		player_now_active_skill["xueming"]["q"] = {"name": "destructive_hammer"}
	# 确保所有角色都有完整的键位配置并填充默认Q技能
	for _hero_name in ["moning", "yiqiu", "noam", "kansel", "xueming"]:
		if not player_now_active_skill.has(_hero_name):
			player_now_active_skill[_hero_name] = _get_default_skill_config_for_hero(_hero_name)
		else:
			var _config = player_now_active_skill[_hero_name]
			if _config.get("q", {}).get("name", "") == "":
				_config["q"] = {"name": _get_default_q_skill(_hero_name)}
	max_main_skill_num = config.get_value("save", "max_main_skill_num", 3)
	max_weapon_num = config.get_value("save", "max_weapon_num", 5)
	
	emblem_slots_max = config.get_value("save", "emblem_slots_max", 4)
	emblem_effect_rate = config.get_value("save", "emblem_effect_rate", emblem_effect_rate)
	max_carry_equipment_slots = config.get_value("save", "max_carry_equipment_slots", 2)
	equipment_manager.load_equipment_data(config.get_value("save", "equipment_data", {}))
	audio_manager.set_master_volume(config.get_value("save", "master_volume", 1.0))
	audio_manager.set_bgm_volume(config.get_value("save", "bgm_volume", 1.0))
	audio_manager.set_sfx_volume(config.get_value("save", "sfx_volume", 1.0))
	audio_manager.set_bg_volume(config.get_value("save", "bg_volume", 1.0))
	damage_show_enabled = config.get_value("save", "damage_show_enabled", true)
	damage_show_type = config.get_value("save", "damage_show_type", 2)
	particle_enable = config.get_value("save", "particle_enable", true)
	moretip = config.get_value("save", "moretip", true) == true
	screen_shake_enabled = config.get_value("save", "screen_shake_enabled", true)
	time_slow_enabled = config.get_value("save", "time_slow_enabled", false)
	is_test = config.get_value("save", "is_test", is_test)
	if settings_manager:
		settings_manager.particle_enabled = particle_enable
		settings_manager.damage_show_enabled = damage_show_enabled
		# 从存档加载分辨率、全屏、暗角设置
		var _res_idx = config.get_value("save", "resolution_index", 6)
		var _fullscreen = config.get_value("save", "is_fullscreen", true)
		var _noborder = config.get_value("save", "noborder_enabled", true)
		var _vignetting = config.get_value("save", "vignetting_enabled", true)
		var _player_hp_bar = config.get_value("save", "player_hp_bar_enabled", true)
		settings_manager.current_resolution_index = _res_idx
		settings_manager.is_fullscreen = _fullscreen
		settings_manager.noborder_enabled = _noborder
		settings_manager.vignetting_enabled = _vignetting
		settings_manager.player_hp_bar_enabled = _player_hp_bar
		# 应用设置
		settings_manager.apply_all_settings()

func reset_battle_modifiers():
	# 这些字段现在承载局外长期加成（如秘丹效果），进入战斗时不再在这里清空。
	pass

var hit_scene = null
signal player_healed(amount: float)
signal player_shield_damaged(amount: float)
const HIT_ANIME_MAX_PER_FRAME: int = 8
var _hit_anime_budget_frame: int = -1
var _hit_anime_budget_count: int = 0

func play_hit_anime(position: Vector2, is_crit: bool = false, anime: int = 1):
	if anime == 0: return
	var current_frame := Engine.get_process_frames()
	if current_frame != _hit_anime_budget_frame:
		_hit_anime_budget_frame = current_frame
		_hit_anime_budget_count = 0
	if _hit_anime_budget_count >= HIT_ANIME_MAX_PER_FRAME:
		return
	_hit_anime_budget_count += 1
	if hit_scene == null: hit_scene = ResourceLoader.load("res://Scenes/global/hit.tscn")
	var hit = hit_scene.instantiate()
	hit.position = position + Vector2(-1, 5)
	get_tree().current_scene.add_child(hit)
	if hit.get_node_or_null("GunHitSound"): hit.get_node("GunHitSound").bus = "SFX"
	if hit.get_node_or_null("GunHitCriSound"): hit.get_node("GunHitCriSound").bus = "SFX"
	if is_crit:
		hit.get_node("GunHitCri").play("hit"); hit.get_node("GunHitCriSound").play(0.0); hit.emit_signal("critical_hit_played")
	else:
		hit.get_node("GunHit").play("hit"); hit.get_node("GunHitSound").play(0.0)
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(hit): hit.queue_free()

func _on_monster_damage(damage_type_int: int, damage_value: float, world_position: Vector2, weapon_name: String = "Unknown"):
	if damage_show_enabled and damage_value > 0.0:
		_queue_damage_label(damage_type_int, damage_value, world_position)
	record_damage_for_dps(damage_value, weapon_name)

func _queue_damage_label(damage_type_int: int, damage_value: float, world_position: Vector2) -> void:
	if damage_value <= 0.0:
		return
	if _damage_label_queue.size() >= DAMAGE_LABEL_QUEUE_MAX_KEYS:
		_damage_label_drop_total_limit += 1
		return
	var cell := Vector2i(
		int(floor(world_position.x / DAMAGE_LABEL_AGGREGATE_CELL_SIZE)),
		int(floor(world_position.y / DAMAGE_LABEL_AGGREGATE_CELL_SIZE))
	)
	var key := "%d:%d:%d" % [damage_type_int, cell.x, cell.y]
	var entry: Dictionary = _damage_label_queue.get(key, {})
	if entry.is_empty():
		entry = {
			"type": damage_type_int,
			"value": damage_value,
			"position": world_position,
			"count": 1,
		}
	else:
		entry["value"] = float(entry.get("value", 0.0)) + damage_value
		entry["position"] = (entry.get("position", world_position) as Vector2).lerp(world_position, 0.35)
		entry["count"] = int(entry.get("count", 1)) + 1
	_damage_label_queue[key] = entry

func _flush_damage_label_queue() -> void:
	if _damage_label_queue.is_empty():
		return
	var emitted := 0
	for key in _damage_label_queue.keys():
		if emitted >= DAMAGE_LABEL_FLUSH_PER_FRAME:
			break
		var entry: Dictionary = _damage_label_queue[key]
		_damage_label_queue.erase(key)
		var damage_type_int := int(entry.get("type", 1))
		var lbl = _create_damage_label(true, _is_dot_damage_label_type(damage_type_int))
		if lbl:
			lbl.show_damage_number(damage_type_int, float(entry.get("value", 0.0)), entry.get("position", Vector2.ZERO))
			emitted += 1
		else:
			_damage_label_drop_frame_limit += 1

func _on_player_heal(heal_value: float, world_position: Vector2, source_id: String = "unknown"):
	if PC.is_game_over:
		return
	emit_signal("player_healed", heal_value)
	record_heal_shield_for_stats("heal", heal_value, source_id)
	if damage_show_enabled and heal_value > 0.0:
		var lbl = _create_damage_label(false)
		if lbl: lbl.show_damage_number(9, heal_value, world_position)

func _on_player_hit(damage_val: float, shield_val: float, attacker: Node2D, world_position: Vector2, source_name: String = ""):
	if shield_val > 0:
		emit_signal("player_shield_damaged", shield_val)
	if not damage_show_enabled: return
	if shield_val > 0:
		var lbl = _create_damage_label(false)
		if lbl: lbl.show_damage_number(10, shield_val, world_position, source_name)
	if damage_val > 0:
		var lbl = _create_damage_label(false)
		if lbl: lbl.show_damage_number(11, damage_val, world_position, source_name)

func _on_player_hit_ignore_invincible(damage_val: float, shield_val: float, attacker: Node2D, world_position: Vector2, source_name: String = ""):
	# 无视无敌伤害的弹幕显示（同player_hit，但不发射player_shield_damaged信号）
	if not damage_show_enabled: return
	if shield_val > 0:
		var lbl = _create_damage_label(false)
		if lbl: lbl.show_damage_number(10, shield_val, world_position, source_name)
	if damage_val > 0:
		var lbl = _create_damage_label(false)
		if lbl: lbl.show_damage_number(11, damage_val, world_position, source_name)

func _create_damage_label(use_frame_limit: bool = true, use_dot_limit: bool = false) -> Node2D:
	if damage_label_pool == null:
		return null
	if damage_label_pool.active_count >= MAX_DAMAGE_LABELS:
		_damage_label_drop_total_limit += 1
		return null
	if use_frame_limit:
		var frame := Engine.get_process_frames()
		if frame != _damage_label_frame:
			_damage_label_frame = frame
			_damage_label_count_this_frame = 0
			_dot_damage_label_count_this_frame = 0
		if _damage_label_count_this_frame >= MAX_DAMAGE_LABELS_PER_FRAME:
			_damage_label_drop_frame_limit += 1
			return null
		if use_dot_limit and _dot_damage_label_count_this_frame >= MAX_DOT_DAMAGE_LABELS_PER_FRAME:
			_damage_label_drop_frame_limit += 1
			return null
		_damage_label_count_this_frame += 1
		if use_dot_limit:
			_dot_damage_label_count_this_frame += 1
	var instance = damage_label_pool.acquire(self )
	instance.z_index = 100
	return instance

func _is_dot_damage_label_type(damage_type_int: int) -> bool:
	return damage_type_int == 5 or damage_type_int == 6 or damage_type_int == 7 or damage_type_int == 8

var poetry_dps_override: float = -1.0 # 诗想难度DPS覆盖值，-1表示不覆盖
var poetry_last_code: String = "" # 上次诗想难度出战的备战码

func get_current_dps() -> float:
	if poetry_dps_override >= 0.0:
		return poetry_dps_override
	return current_dps
func get_current_single_target_dps() -> float:
	if poetry_dps_override >= 0.0:
		return poetry_dps_override
	if current_dps_window_kill_count <= 0:
		return current_dps
	var effective_kill_count := pow(float(current_dps_window_kill_count), DPS_SINGLE_TARGET_KILL_COUNT_EXPONENT)
	return current_dps / maxf(1.0, effective_kill_count)
func get_current_boss_scaling_dps() -> float:
	if poetry_dps_override >= 0.0:
		return poetry_dps_override
	return maxf(current_dps, current_boss_scaling_dps)
func get_current_dps_window_kill_count() -> int:
	return current_dps_window_kill_count
func get_highest_dps() -> float:
	if poetry_dps_override >= 0.0:
		return max(highest_dps, poetry_dps_override)
	return highest_dps
func get_weapon_dps() -> Dictionary: return weapon_dps

# 兼容旧逻辑函数
func reset_dps_counter() -> void:
	_reset_dps_buckets(); _reset_dps_potential_buckets(); current_dps = 0.0; current_boss_scaling_dps = 0.0; current_dps_window_kill_count = 0; highest_dps = 0.0; weapon_dps.clear(); dps_detail_source_dps.clear()
	_reset_heal_shield_buckets(); heal_shield_detail_source_rates.clear()
	reset_dps_test_timer()
	poetry_dps_override = -1.0
	if dps_timer: dps_timer.start()
func stop_dps_counter() -> void:
	if dps_timer: dps_timer.stop()
