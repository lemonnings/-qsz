@warning_ignore("unused_signal")
extends Node

const CONFIG_PATH = "user://game_config.cfg"
const LINGSHI_ITEM_ID := "item_084"
const DEBUG_F1_ZHENQI_AMOUNT := 1000000

# 测试模式：跳过开屏动画，直接进入游戏
var is_test: bool = false
var time_slow_enabled: bool = false
var is_debug: bool = true

# 战斗速度倍率（由速度切换按钮控制）
var game_speed: float = 1.0

func reset_game_speed() -> void:
	game_speed = 1.0
	Engine.time_scale = 1.0

# 保存指示器相关
const SAVE_INDICATOR_SCENE := preload("res://Scenes/global/loading_anime.tscn")
var _save_indicator_layer: CanvasLayer
var _save_indicator_tween: Tween

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

# 关卡ID列表。
# 这里只先接你当前提出的 4 个正式关卡。
const STAGE_ID_LIST := ["peach_grove", "ruin", "cave", "forest"]

const CORE_DEPTH_MIN := 1
const CORE_DEPTH_MAX := 10
const CORE_DEPTH_STAT_STEP := 0.08
const DEEP_DIFFICULTY_STAT_MULTIPLIER := 1.25
const CORE_DIFFICULTY_BASE_STAT_MULTIPLIER := 1.5
const SHALLOW_DIFFICULTY_QI_GAIN_MULTIPLIER := 1.0
const DEEP_DIFFICULTY_QI_GAIN_MULTIPLIER := 1.2
const CORE_DIFFICULTY_BASE_QI_GAIN_MULTIPLIER := 1.4
const CORE_DEPTH_QI_GAIN_STEP := 0.1
const POETRY_BATTLE_START_TIME_SECONDS := 480.0
const POETRY_BOSS_DAMAGE_BASE_BONUS := 0.9
const POETRY_BOSS_DAMAGE_XUANYUAN_STEP := 0.005
const POETRY_BOSS_DAMAGE_HUTI_STEP := 0.01
const POETRY_BOSS_DAMAGE_RAMP_END_TIME := 570.0
const POETRY_BOSS_DAMAGE_INITIAL_CORRECTION := -0.40
const POETRY_BOSS_DAMAGE_CORRECTION_STEP := 0.2
const POETRY_MODIFIER_STEP_SECONDS := 10.0
const POETRY_PLAYER_FINAL_DAMAGE_STEP := 0.15
const POETRY_HEAL_SHIELD_STEP_PENALTY := 0.05
const POETRY_BOSS_HP_OUTPUT_SCALE := 2200.0
const POETRY_BOSS_HP_FACTORS := {
	"boss_a": 1.0,
	"boss_stone": 0.7,
	"boss_cansel": 0.6,
	"boss_stele": 1.4
}
const DEFAULT_START_WEAPON_BY_HERO := {
	"moning": "Qigong",
	"yiqiu": "Swordqi",
	"noam": "Lightbullet",
	"kansel": "Ice"
}
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
	"faze_chaos_level",
	"faze_skill_level",
	"faze_sixsense_level",
	"faze_wind_level"
]

# 各关卡在不同难度下的属性倍率。
const STAGE_DIFFICULTY_MULTIPLIERS := {
	"peach_grove": {
		STAGE_DIFFICULTY_SHALLOW: 1.0, # 30
		STAGE_DIFFICULTY_DEEP: 1.63, # 55
		STAGE_DIFFICULTY_CORE: 1.63 * 1.52, # 95
		STAGE_DIFFICULTY_POETRY: 1.63 * 1.52
	},
	"ruin": {
		STAGE_DIFFICULTY_SHALLOW: 0.8, # 削弱20%
		STAGE_DIFFICULTY_DEEP: 1.39 * 1.1, # 深层+10%
		STAGE_DIFFICULTY_CORE: 1.39 * 1.52 * 1.2, # 核心+20%
		STAGE_DIFFICULTY_POETRY: 1.39 * 1.52 * 1.2
	},
	"cave": {
		STAGE_DIFFICULTY_SHALLOW: 0.7, # 削弱30%
		STAGE_DIFFICULTY_DEEP: 1.4625 * 1.1, # 深层+10%
		STAGE_DIFFICULTY_CORE: 1.4625 * 1.2416 * 1.2, # 核心+20%
		STAGE_DIFFICULTY_POETRY: 1.4625 * 1.2416 * 1.2
	},
	"forest": {
		STAGE_DIFFICULTY_SHALLOW: 0.6, # 削弱40%
		STAGE_DIFFICULTY_DEEP: 1.1843 * 1.08, # 深层+8%
		STAGE_DIFFICULTY_CORE: 1.1843 * 1.069 * 1.16, # 核心+16%
		STAGE_DIFFICULTY_POETRY: 1.1843 * 1.069 * 1.16
	}
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

@export var total_points: int = 1000

@export var unlock_moning: bool = true
@export var unlock_yiqiu: bool = true
@export var unlock_noam: bool = false
@export var unlock_kansel: bool = false

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
@export var shop_lingshi_unit_price: int = 50

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
	}
}

# 每个关卡已通关的最高核心进阶层数。0 表示尚未通关核心进阶。
@export var core_depth_clear_progress: Dictionary = {
	"peach_grove": 0,
	"ruin": 0,
	"cave": 0,
	"forest": 0
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
@export var red_p: float = 0.5
@export var gold_p: float = 4
@export var darkorchid_p: float = 25.5
@export var blue_p: float = 70

# 刷新次数
@export var refresh_max_num: int = 5

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

# ---- 修习树 · 武器解锁标记 ----
@export var study_unlock_qiankun: bool = false # 乾坤双剑
@export var study_unlock_dragonwind: bool = false # 风龙杖
@export var study_unlock_bloodwave: bool = false # 血气波
@export var study_unlock_water: bool = false # 坎水诀
@export var study_unlock_baoyan: bool = false # 爆炎诀
@export var study_unlock_genshan: bool = false # 艮山诀
@export var study_unlock_thunder_break: bool = false # 天雷破
@export var study_unlock_holylight: bool = false # 圣光术
@export var study_unlock_xuanwu: bool = false # 玄武盾

# ---- 修习树 · 技能篇加成（由 SettingStudyTreeSkill.apply_all() 刷新）----
@export var study_skill_damage_bonus: float = 0.0 # 技能伤害提升
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
	}
}


@export var player_now_active_skill: Dictionary = {
	"moning": {"space": {"name": "dodge"}, "q": {"name": "wind_thunder"}, "e": {"name": ""}},
	"yiqiu": {"space": {"name": "dodge"}, "q": {"name": "beastify"}, "e": {"name": ""}},
	"noam": {"space": {"name": "dodge"}, "q": {"name": "heal_hot"}, "e": {"name": ""}},
	"kansel": {"space": {"name": "dodge"}, "q": {"name": "magical_fire"}, "e": {"name": ""}}
}

@export var selected_start_weapon: String = "Swordqi"
@export var selected_start_weapons_by_hero: Dictionary = {}
@export var available_start_weapons: Array[String] = ["Swordqi", "Qigong"]

# 世界等级
@export var world_level_multiple: float = 1
@export var world_level_reward_multiple: float = 1
@export var world_level: int = 1

@export var in_menu: bool = true
@export var in_town: bool = false
@export var is_level_up: bool = false
@export var main_menu_instance: PackedScene = null
@export var has_visited_town: bool = false
@export var is_first_game: bool = true
@export var has_seen_battle_tutorial: bool = false
@export var has_seen_town_tutorial: bool = false
@export var has_seen_peach_grove_dialogue: bool = false
@export var has_seen_peach_grove_boss: bool = false
@export var has_seen_peach_grove_boss_charge: bool = false
@export var has_defeated_peach_grove_boss: bool = false # 是否击败了桃林boss

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

# 首次通关ruin后进入story_5（诺姆解锁剧情）
@export var has_seen_story_5: bool = false

# 首次通关cave后进入story_7（坎塞尔解锁剧情）
@export var has_seen_story_7: bool = false
@export var has_seen_story_8: bool = false

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
signal player_heal(heal_value: float, world_position: Vector2)
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

# --------------------------
# --- DPS 计数逻辑 ---
const DPS_WINDOW_SECONDS: int = 30
var dps_damage_buckets: Array = []
@export var current_dps: float = 0.0
var highest_dps: float = 0.0
var weapon_dps: Dictionary = {}
var dps_timer: Timer

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

const MAX_DAMAGE_LABELS: int = 120
const MAX_DAMAGE_LABELS_PER_FRAME: int = 12
var _active_damage_label_count: int = 0
var _damage_label_frame: int = -1
var _damage_label_count_this_frame: int = 0
var _damage_label_scene = preload("res://Scenes/global/damage.tscn")

# 对象池 —— 减少高频 instantiate/queue_free 的 GC 开销
var damage_label_pool: ObjectPool
var rain_bullet_pool: ObjectPool
var light_bullet_pool: ObjectPool
var ice_flower_pool: ObjectPool
var branch_pool: ObjectPool
var frog_attack_pool: ObjectPool
var debuff_burn_pool: ObjectPool
var faze_thunder_pool: ObjectPool
var faze_destory_pool: ObjectPool

func _init_dps_counter() -> void:
	_reset_dps_buckets()
	dps_timer = Timer.new()
	dps_timer.wait_time = 1.0
	dps_timer.timeout.connect(_calculate_dps)
	dps_timer.autostart = true
	add_child(dps_timer)

func record_damage_for_dps(damage: float, weapon_name: String = "Unknown") -> void:
	if damage <= 0.0:
		return
	var current_second := int(Time.get_ticks_msec() / 1000)
	_ensure_dps_buckets()
	var bucket_index := current_second % DPS_WINDOW_SECONDS
	var bucket: Dictionary = dps_damage_buckets[bucket_index]
	if int(bucket.get("second", -1)) != current_second:
		bucket["second"] = current_second
		bucket["total"] = 0.0
		bucket["weapons"] = {}
	bucket["total"] = float(bucket.get("total", 0.0)) + damage
	var weapons: Dictionary = bucket.get("weapons", {})
	weapons[weapon_name] = float(weapons.get(weapon_name, 0.0)) + damage
	bucket["weapons"] = weapons

func _calculate_dps() -> void:
	var current_second := int(Time.get_ticks_msec() / 1000)
	var first_second := current_second - DPS_WINDOW_SECONDS + 1
	var total_damage = 0.0
	var weapon_totals = {}
	_ensure_dps_buckets()
	for bucket in dps_damage_buckets:
		var bucket_second := int(bucket.get("second", -1))
		if bucket_second < first_second or bucket_second > current_second:
			continue
		total_damage += float(bucket.get("total", 0.0))
		var weapons: Dictionary = bucket.get("weapons", {})
		for w_name in weapons:
			weapon_totals[w_name] = weapon_totals.get(w_name, 0.0) + float(weapons[w_name])
	current_dps = total_damage / float(DPS_WINDOW_SECONDS)
	highest_dps = max(highest_dps, current_dps)
	weapon_dps.clear()
	for w_name in weapon_totals:
		weapon_dps[w_name] = weapon_totals[w_name] / float(DPS_WINDOW_SECONDS)
	emit_signal("dps_updated", current_dps, weapon_dps)

func refresh_dps_counter() -> void:
	_calculate_dps()

func _ensure_dps_buckets() -> void:
	if dps_damage_buckets.size() == DPS_WINDOW_SECONDS:
		return
	_reset_dps_buckets()

func _reset_dps_buckets() -> void:
	dps_damage_buckets.clear()
	for i in range(DPS_WINDOW_SECONDS):
		dps_damage_buckets.append({"second": - 1, "total": 0.0, "weapons": {}})

# ---------------------------------

func _ready():
	set_process_input(true)
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

func _init_object_pools() -> void:
	damage_label_pool = ObjectPool.new(_damage_label_scene, 30)
	add_child(damage_label_pool)
	rain_bullet_pool = ObjectPool.new(preload("res://Scenes/player/faze_rain_bullet.tscn"), 50)
	add_child(rain_bullet_pool)
	light_bullet_pool = ObjectPool.new(preload("res://Scenes/player/light_bullet.tscn"), 20)
	add_child(light_bullet_pool)
	ice_flower_pool = ObjectPool.new(preload("res://Scenes/player/ice_flower.tscn"), 20)
	add_child(ice_flower_pool)
	branch_pool = ObjectPool.new(preload("res://Scenes/branch.tscn"), 20)
	add_child(branch_pool)
	frog_attack_pool = ObjectPool.new(preload("res://Scenes/moster/frog_attack.tscn"), 40)
	add_child(frog_attack_pool)
	debuff_burn_pool = ObjectPool.new(preload("res://Scenes/player/debuff_burn.tscn"), 10)
	add_child(debuff_burn_pool)
	faze_thunder_pool = ObjectPool.new(preload("res://Scenes/player/faze_thunder.tscn"), 5)
	add_child(faze_thunder_pool)
	faze_destory_pool = ObjectPool.new(preload("res://Scenes/player/faze_destory.tscn"), 5)
	add_child(faze_destory_pool)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
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
	pass

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
	if player_inventory[item_id] <= 0:
		player_inventory.erase(item_id)

func consume_item_count(item_id: String, count: int) -> bool:
	if count <= 0:
		return true
	if get_item_count(item_id) < count:
		return false
	add_item_count(item_id, -count)
	return true

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
		if typeof(stage_difficulty_clear_progress.get(stage_id, {})) != TYPE_DICTIONARY:
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
	if cleared_depth >= CORE_DEPTH_MAX:
		return CORE_DEPTH_MAX
	if cleared_depth > 0:
		return cleared_depth + 1
	if is_stage_difficulty_cleared(stage_id, STAGE_DIFFICULTY_DEEP):
		return CORE_DEPTH_MIN
	return 0

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

func get_core_stat_bonus_percent(depth: int = -1) -> int:
	var resolved_depth := current_core_depth if depth < CORE_DEPTH_MIN else depth
	return int(round(float(clamp_core_depth(resolved_depth)) * CORE_DEPTH_STAT_STEP * 100.0))

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

func get_poetry_player_final_damage_multiplier(real_time: float = -1.0) -> float:
	var step_count := get_poetry_modifier_step_count(real_time)
	return 1.0 + float(step_count) * POETRY_PLAYER_FINAL_DAMAGE_STEP

func get_poetry_heal_shield_multiplier(real_time: float = -1.0) -> float:
	var step_count := get_poetry_modifier_step_count(real_time)
	return maxf(0.0, 1.0 - float(step_count) * POETRY_HEAL_SHIELD_STEP_PENALTY)

func get_poetry_boss_damage_correction(real_time: float = -1.0) -> float:
	if not is_current_poetry_difficulty():
		return 0.0
	var resolved_time := real_time
	if resolved_time < 0.0 and typeof(PC) != TYPE_NIL:
		resolved_time = PC.real_time
	if resolved_time <= POETRY_BOSS_DAMAGE_RAMP_END_TIME:
		var ramp_duration := POETRY_BOSS_DAMAGE_RAMP_END_TIME - POETRY_BATTLE_START_TIME_SECONDS
		var progress := clampf((resolved_time - POETRY_BATTLE_START_TIME_SECONDS) / ramp_duration, 0.0, 1.0)
		return lerpf(POETRY_BOSS_DAMAGE_INITIAL_CORRECTION, 0.0, progress)
	var step_count := int(floor((resolved_time - POETRY_BOSS_DAMAGE_RAMP_END_TIME) / POETRY_MODIFIER_STEP_SECONDS))
	return float(maxi(0, step_count)) * POETRY_BOSS_DAMAGE_CORRECTION_STEP

func get_poetry_boss_damage_multiplier(real_time: float = -1.0) -> float:
	if not is_current_poetry_difficulty():
		return 1.0
	return maxf(0.0, 1.0 + POETRY_BOSS_DAMAGE_BASE_BONUS + get_poetry_boss_damage_correction(real_time) + get_poetry_boss_cultivation_damage_bonus())

func get_poetry_boss_cultivation_damage_bonus() -> float:
	var xuanyuan_bonus := float(maxi(0, cultivation_xuanyuan_level)) * POETRY_BOSS_DAMAGE_XUANYUAN_STEP
	var huti_bonus := float(maxi(0, cultivation_huti_level)) * POETRY_BOSS_DAMAGE_HUTI_STEP
	return xuanyuan_bonus + huti_bonus

func is_poetry_boss_damage_source(attacker: Node) -> bool:
	if not is_current_poetry_difficulty():
		return false
	if attacker == null or not is_instance_valid(attacker):
		return false
	var node := attacker
	while node != null and is_instance_valid(node):
		if node.is_in_group("boss") or node.is_in_group("boss_bullet") or node.is_in_group("boss_projectile") or node.is_in_group("boss_a_petal") or node.is_in_group("boss_a_poison_circle"):
			return true
		node = node.get_parent()
	return false

func get_poetry_total_faze_overflow(threshold: int = 17) -> int:
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
	var attack_speed_multiplier := maxf(0.01, 1.0 + PC.pc_atk_speed)
	var final_damage_multiplier := Faze.get_final_damage_multiplier()
	return maxf(0.0, float(PC.pc_atk) * crit_expected_multiplier * attack_speed_multiplier * final_damage_multiplier)

func get_poetry_boss_max_hp(boss_id: String, fallback_hp: float = 1.0) -> float:
	if not is_current_poetry_difficulty():
		return maxf(fallback_hp, 1.0)
	var expected_output := get_poetry_boss_expected_output()
	var faze_overflow_multiplier := 1.0 + float(get_poetry_total_faze_overflow()) * 0.10
	var boss_factor := float(POETRY_BOSS_HP_FACTORS.get(boss_id, 1.0))
	var hp_value := expected_output * POETRY_BOSS_HP_OUTPUT_SCALE * faze_overflow_multiplier * boss_factor
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
			return shallow_multiplier * CORE_DIFFICULTY_BASE_STAT_MULTIPLIER * get_core_depth_stat_multiplier(resolved_core_depth)
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
		var depth_ratio := get_core_depth_stat_multiplier(selected_core_depth) / get_core_depth_stat_multiplier(CORE_DEPTH_MIN)
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
	return max(0.0, 1.0 + effective_exp_bonus)

func get_effective_drop_multiplier() -> float:
	var effective_drop_bonus = drop_multi
	if typeof(PC) != TYPE_NIL:
		effective_drop_bonus = PC.drop_multi
	return max(0.0, 1.0 + effective_drop_bonus)

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
	var bonus = _get_effective_normal_monster_bonus()
	if is_elite_or_boss_target(target):
		bonus = _get_effective_boss_bonus()
	return max(0.0, 1.0 + bonus)

func apply_enemy_damage_bonus(damage: float, target: Node) -> float:
	if damage <= 0.0:
		return damage
	return damage * get_enemy_damage_bonus_multiplier(target)

func get_achievement_weapon_damage_bonus(weapon_tag: String) -> float:
	var achievement_manager = get_node_or_null("/root/AchievementManager")
	if achievement_manager != null and achievement_manager.has_method("get_category_damage_bonus_by_weapon_tag"):
		return float(achievement_manager.get_category_damage_bonus_by_weapon_tag(weapon_tag))
	return 0.0

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
		"Swordqi": {"id": "Swordqi", "display_name": "剑气诀", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/jianqi.png", "faze_levels": {"faze_sword_level": 3, "faze_bullet_level": 3}, "faze_text": "刀剑法则+3，弹雨法则+3"},
		"Qigong": {"id": "Qigong", "display_name": "气功波", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/qigong.png", "faze_levels": {"faze_wind_level": 3, "faze_wide_level": 3}, "faze_text": "啸风法则+3，广域法则+3"},
		"Lightbullet": {"id": "Lightbullet", "display_name": "光弹", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/guangdan.png", "faze_levels": {"faze_life_level": 3, "faze_bullet_level": 3}, "faze_text": "生灵法则+3，弹雨法则+3"},
		"Ice": {"id": "Ice", "display_name": "冰刺术", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/binghua.png", "faze_levels": {"faze_destroy_level": 3, "faze_bullet_level": 3}, "faze_text": "破坏法则+3，弹雨法则+3"},
		"Xunfeng": {"id": "Xunfeng", "display_name": "巽风诀", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/xunfeng.png", "faze_levels": {"faze_wind_level": 3, "faze_bullet_level": 3}, "faze_text": "啸风法则+3，弹雨法则+3"},
		"Genshan": {"id": "Genshan", "display_name": "艮山诀", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/genshan.png", "faze_levels": {"faze_bagua_level": 3, "faze_shield_level": 3}, "faze_text": "八卦法则+3，护佑法则+3"},
		"Bloodwave": {"id": "Bloodwave", "display_name": "血气波", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/xueqibo.png", "faze_levels": {"faze_wide_level": 3, "faze_blood_level": 3}, "faze_text": "广域法则+3，浴血法则+3"},
		"Xuanwu": {"id": "Xuanwu", "display_name": "玄武盾", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/xuanwu.png", "faze_levels": {"faze_destroy_level": 3, "faze_treasure_level": 3}, "faze_text": "破坏法则+3，宝器法则+3"},
		"Water": {"id": "Water", "display_name": "坎水诀", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/kanshui.png", "faze_levels": {"faze_life_level": 3, "faze_bagua_level": 3}, "faze_text": "生灵法则+3，八卦法则+3"},
		"Holylight": {"id": "Holylight", "display_name": "圣光术", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/shenshengzhuoshao.png", "faze_levels": {"faze_life_level": 3, "faze_heal_level": 3}, "faze_text": "生灵法则+3，愈疗法则+3"},
		"Branch": {"id": "Branch", "display_name": "仙枝", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/xianzhi.png", "faze_levels": {"faze_treasure_level": 3, "faze_bullet_level": 3}, "faze_text": "宝器法则+3，弹雨法则+3"},
		"Thunder": {"id": "Thunder", "display_name": "震雷诀", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/thunder.png", "faze_levels": {"faze_bagua_level": 3, "faze_thunder_level": 3}, "faze_text": "八卦法则+3，鸣雷法则+3"},
		"Thunderbreak": {"id": "Thunderbreak", "display_name": "天雷破", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/tianleipo2.png", "faze_levels": {"faze_thunder_level": 3, "faze_destroy_level": 3}, "faze_text": "鸣雷法则+3，破坏法则+3"},
		"Moyan": {"id": "Moyan", "display_name": "爆炎诀", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/moyan.png", "faze_levels": {"faze_fire_level": 3, "faze_destroy_level": 3}, "faze_text": "炽焰法则+3，破坏法则+3"},
		"Qiankun": {"id": "Qiankun", "display_name": "乾坤双剑", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/qiankun.png", "faze_levels": {"faze_sword_level": 3, "faze_bagua_level": 3}, "faze_text": "刀剑法则+3，八卦法则+3"},
		"Bloodboardsword": {"id": "Bloodboardsword", "display_name": "饮血刀", "icon": "res://AssetBundle/Sprites/Sprite sheets/skillIcon/yinxue.png", "faze_levels": {"faze_sword_level": 3, "faze_blood_level": 3}, "faze_text": "刀剑法则+3，浴血法则+3"},
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
	var normalized_weapons: Array[String] = []
	for weapon_id in available_start_weapons:
		var normalized_id := normalize_start_weapon_id(str(weapon_id))
		if not normalized_weapons.has(normalized_id):
			normalized_weapons.append(normalized_id)
	for default_weapon in ["Swordqi", "Qigong"]:
		if not normalized_weapons.has(default_weapon):
			normalized_weapons.append(default_weapon)
	if unlock_noam and not normalized_weapons.has("Lightbullet"):
		normalized_weapons.append("Lightbullet")
	if unlock_kansel and not normalized_weapons.has("Ice"):
		normalized_weapons.append("Ice")
	var achievement_manager = get_node_or_null("/root/AchievementManager")
	if achievement_manager != null and achievement_manager.has_method("get_unlocked_start_weapons"):
		for weapon_id in achievement_manager.get_unlocked_start_weapons():
			var normalized_id := normalize_start_weapon_id(str(weapon_id))
			if not normalized_weapons.has(normalized_id):
				normalized_weapons.append(normalized_id)
	available_start_weapons = normalized_weapons

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
			return "Swordqi"
		"LightBullet":
			return "Lightbullet"
		"ThunderBreak":
			return "Thunderbreak"
		_:
			return weapon_id

func get_default_start_weapon_for_hero(hero_name: String = "") -> String:
	var hero := _get_current_start_weapon_hero(hero_name)
	var weapon_id := normalize_start_weapon_id(str(DEFAULT_START_WEAPON_BY_HERO.get(hero, "Swordqi")))
	if is_start_weapon_available(weapon_id):
		return weapon_id
	return _get_first_available_start_weapon_id()

func _get_first_available_start_weapon_id() -> String:
	var available_weapons := get_available_start_weapons()
	if available_weapons.is_empty():
		return "Swordqi"
	return str(available_weapons[0].get("id", "Swordqi"))

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
		_:
			return ""


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

func save_game():
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
		"red_p": red_p,
		"gold_p": gold_p,
		"darkorchid_p": darkorchid_p,
		"blue_p": blue_p,
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
		"shop_lingshi_unit_price": shop_lingshi_unit_price,
		"has_seen_battle_tutorial": has_seen_battle_tutorial,
		"has_seen_town_tutorial": has_seen_town_tutorial,
		"has_seen_peach_grove_dialogue": has_seen_peach_grove_dialogue,
		"has_seen_peach_grove_boss": has_seen_peach_grove_boss,
		"has_seen_peach_grove_boss_charge": has_seen_peach_grove_boss_charge,
		"total_defeat_count": total_defeat_count,
		"has_seen_story_2": has_seen_story_2,
		"has_seen_story_3": has_seen_story_3,
		"has_seen_story_4": has_seen_story_4,
		"has_seen_story_5": has_seen_story_5,
		"has_seen_story_7": has_seen_story_7,
		"has_seen_story_8": has_seen_story_8,
		"has_seen_liandan_tutorial": has_seen_liandan_tutorial,
		"has_seen_shop_tutorial": has_seen_shop_tutorial,
		"has_seen_poem_tutorial": has_seen_poem_tutorial,
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
		"refresh_max_num": refresh_max_num,
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
		"study_skill_damage_bonus": study_skill_damage_bonus,
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
	}

	for key in data:
		config.set_value("save", key, data[key])
	
	var err = config.save(CONFIG_PATH)
	if err == OK:
		print("save success")
	else:
		push_error("save error")
	
	audio_manager.save_audio_settings()

func load_game():
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	if err != OK: return
	
	total_points = config.get_value("save", "total_points", total_points)
	PC.player_name = config.get_value("save", "player_name", PC.player_name)
	world_level = config.get_value("save", "world_level", world_level)
	world_level_multiple = config.get_value("save", "world_level_multiple", world_level_multiple)
	world_level_reward_multiple = config.get_value("save", "world_level_reward_multiple", world_level_reward_multiple)
	lunky_level = config.get_value("save", "lunky_level", lunky_level)
	red_p = config.get_value("save", "red_p", red_p)
	gold_p = config.get_value("save", "gold_p", gold_p)
	darkorchid_p = config.get_value("save", "darkorchid_p", darkorchid_p)
	blue_p = config.get_value("save", "blue_p", blue_p)
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
	refresh_max_num = int(config.get_value("save", "refresh_max_num", refresh_max_num))
	shop_level = clampi(int(config.get_value("save", "shop_level", shop_level)), 1, 8)
	shop_battle_refresh_count = clampi(int(config.get_value("save", "shop_battle_refresh_count", shop_battle_refresh_count)), 0, refresh_max_num)
	shop_lingshi_unit_price = max(int(config.get_value("save", "shop_lingshi_unit_price", shop_lingshi_unit_price)), 50)
	shop_first_entered = config.get_value("save", "shop_first_entered", shop_first_entered) == true
	has_visited_town = config.get_value("save", "has_visited_town", false) == true
	is_first_game = config.get_value("save", "is_first_game", true) == true
	has_seen_battle_tutorial = config.get_value("save", "has_seen_battle_tutorial", false) == true
	has_seen_town_tutorial = config.get_value("save", "has_seen_town_tutorial", false) == true
	has_seen_peach_grove_dialogue = config.get_value("save", "has_seen_peach_grove_dialogue", false) == true
	has_seen_peach_grove_boss = config.get_value("save", "has_seen_peach_grove_boss", false) == true
	has_seen_peach_grove_boss_charge = config.get_value("save", "has_seen_peach_grove_boss_charge", false) == true
	total_defeat_count = int(config.get_value("save", "total_defeat_count", 0))
	has_seen_story_2 = config.get_value("save", "has_seen_story_2", false) == true
	has_seen_story_3 = config.get_value("save", "has_seen_story_3", false) == true
	has_seen_story_4 = config.get_value("save", "has_seen_story_4", false) == true
	has_seen_story_5 = config.get_value("save", "has_seen_story_5", false) == true
	has_seen_story_7 = config.get_value("save", "has_seen_story_7", false) == true
	has_seen_story_8 = config.get_value("save", "has_seen_story_8", false) == true
	has_seen_liandan_tutorial = config.get_value("save", "has_seen_liandan_tutorial", false) == true
	has_seen_shop_tutorial = config.get_value("save", "has_seen_shop_tutorial", false) == true
	has_seen_poem_tutorial = config.get_value("save", "has_seen_poem_tutorial", false) == true
	var loaded_shop_items = config.get_value("save", "shop_saved_items", [])
	if typeof(loaded_shop_items) == TYPE_ARRAY:
		shop_saved_items = (loaded_shop_items as Array).duplicate(true)
	else:
		shop_saved_items = []
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
	refresh_max_num = config.get_value("save", "refresh_max_num", 5)
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
		if not loaded_study_data[p_name].has("zhenqi_points"): loaded_study_data[p_name]["zhenqi_points"] = 100
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
	# 修习树武器解锁
	study_unlock_qiankun = config.get_value("save", "study_unlock_qiankun", false)
	study_unlock_dragonwind = config.get_value("save", "study_unlock_dragonwind", false)
	study_unlock_bloodwave = config.get_value("save", "study_unlock_bloodwave", false)
	study_unlock_water = config.get_value("save", "study_unlock_water", false)
	study_unlock_baoyan = config.get_value("save", "study_unlock_baoyan", false)
	study_unlock_genshan = config.get_value("save", "study_unlock_genshan", false)
	study_unlock_thunder_break = config.get_value("save", "study_unlock_thunder_break", false)
	study_unlock_holylight = config.get_value("save", "study_unlock_holylight", false)
	study_unlock_xuanwu = config.get_value("save", "study_unlock_xuanwu", false)
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
	study_skill_damage_bonus = config.get_value("save", "study_skill_damage_bonus", 0.0)
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
	}
	for _sid in _skill_icon_table:
		if player_active_skill_data.has(_sid):
			player_active_skill_data[_sid]["icon"] = _skill_icon_table[_sid]
	player_now_active_skill = config.get_value("save", "player_now_active_skill", player_now_active_skill)
	var loaded_start_weapons = config.get_value("save", "available_start_weapons", available_start_weapons)
	if typeof(loaded_start_weapons) == TYPE_ARRAY:
		var normalized_start_weapons: Array[String] = []
		for weapon_id in loaded_start_weapons:
			normalized_start_weapons.append(normalize_start_weapon_id(str(weapon_id)))
		available_start_weapons = normalized_start_weapons
	else:
		var default_start_weapons: Array[String] = ["Swordqi", "Qigong"]
		available_start_weapons = default_start_weapons
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
	# 旧存档兼容：扁平格式（顶层键含 "space"）→ 迁移为角色嵌套格式
	if player_now_active_skill.has("space"):
		var _old_config = player_now_active_skill.duplicate(true)
		player_now_active_skill = {}
		for _hero_name in ["moning", "yiqiu", "noam", "kansel"]:
			player_now_active_skill[_hero_name] = _old_config.duplicate(true)
	# 确保所有角色都有完整的键位配置并填充默认Q技能
	for _hero_name in ["moning", "yiqiu", "noam", "kansel"]:
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
		settings_manager.current_resolution_index = _res_idx
		settings_manager.is_fullscreen = _fullscreen
		settings_manager.noborder_enabled = _noborder
		settings_manager.vignetting_enabled = _vignetting
		# 应用设置
		settings_manager.apply_all_settings()

func reset_battle_modifiers():
	# 这些字段现在承载局外长期加成（如秘丹效果），进入战斗时不再在这里清空。
	pass

var hit_scene = null
signal player_healed(amount: float)
signal player_shield_damaged(amount: float)

func play_hit_anime(position: Vector2, is_crit: bool = false, anime: int = 1):
	if anime == 0: return
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
	if damage_show_enabled:
		var lbl = _create_damage_label()
		if lbl: lbl.show_damage_number(damage_type_int, damage_value, world_position)
	record_damage_for_dps(damage_value, weapon_name)

func _on_player_heal(heal_value: float, world_position: Vector2):
	if PC.is_game_over:
		return
	emit_signal("player_healed", heal_value)
	if damage_show_enabled:
		var lbl = _create_damage_label()
		if lbl: lbl.show_damage_number(9, heal_value, world_position)

func _on_player_hit(damage_val: float, shield_val: float, attacker: Node2D, world_position: Vector2, source_name: String = ""):
	if shield_val > 0:
		emit_signal("player_shield_damaged", shield_val)
	if not damage_show_enabled: return
	if shield_val > 0:
		var lbl = _create_damage_label()
		if lbl: lbl.show_damage_number(10, shield_val, world_position, source_name)
	if damage_val > 0:
		var lbl = _create_damage_label()
		if lbl: lbl.show_damage_number(11, damage_val, world_position, source_name)

func _on_player_hit_ignore_invincible(damage_val: float, shield_val: float, attacker: Node2D, world_position: Vector2, source_name: String = ""):
	# 无视无敌伤害的弹幕显示（同player_hit，但不发射player_shield_damaged信号）
	if not damage_show_enabled: return
	if shield_val > 0:
		var lbl = _create_damage_label()
		if lbl: lbl.show_damage_number(10, shield_val, world_position, source_name)
	if damage_val > 0:
		var lbl = _create_damage_label()
		if lbl: lbl.show_damage_number(11, damage_val, world_position, source_name)

func _create_damage_label() -> Node2D:
	if _active_damage_label_count >= MAX_DAMAGE_LABELS: return null
	var frame := Engine.get_process_frames()
	if frame != _damage_label_frame:
		_damage_label_frame = frame
		_damage_label_count_this_frame = 0
	if _damage_label_count_this_frame >= MAX_DAMAGE_LABELS_PER_FRAME:
		return null
	_damage_label_count_this_frame += 1
	var instance = damage_label_pool.acquire(self )
	instance.z_index = 100
	_active_damage_label_count += 1
	# 回收时递减计数（兼容池化和非池化）
	if not instance.has_meta("_dmg_label_counted"):
		instance.set_meta("_dmg_label_counted", true)
		instance.tree_exiting.connect(func(): _active_damage_label_count = max(_active_damage_label_count - 1, 0))
	else:
		# 池化复用的实例，手动递减将在回收时处理
		pass
	return instance

var poetry_dps_override: float = -1.0 # 诗想难度DPS覆盖值，-1表示不覆盖
var poetry_last_code: String = "" # 上次诗想难度出战的备战码

func get_current_dps() -> float:
	if poetry_dps_override >= 0.0:
		return poetry_dps_override
	return current_dps
func get_highest_dps() -> float:
	if poetry_dps_override >= 0.0:
		return max(highest_dps, poetry_dps_override)
	return highest_dps
func get_weapon_dps() -> Dictionary: return weapon_dps

# 兼容旧逻辑函数
func reset_dps_counter() -> void:
	_reset_dps_buckets(); current_dps = 0.0; highest_dps = 0.0; weapon_dps.clear()
	poetry_dps_override = -1.0
	if dps_timer: dps_timer.start()
func stop_dps_counter() -> void:
	if dps_timer: dps_timer.stop()
