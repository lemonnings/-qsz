extends Node

const ZHUAZHUAJUCHUI_SCRIPT = preload("res://Script/skill/zhuazhuajuchui.gd")
const THUNDER_GUN_SCRIPT = preload("res://Script/skill/thunder_gun.gd")
const SHEHUN_SPIRIT_PROGRESS_BUFF_ID := "shehun_spirit_progress"

@export var player_instance: Node = null
@export var player_name: String = "yiqiu"
@export var pc_atk: int = 25 # 局内攻击
@export var base_atk: int = 25 # 攻击百分比加成结算基准，只由初始化和升级成长维护
@export var final_damage_bonus: float = 0.0 # 局内最终伤害加成（例如0.1代表+10%）
@export var pc_hp: int = 50: # 局内HP
	get:
		return _pc_hp_value
	set(value):
		var new_value := int(value)
		if is_game_over and new_value > _pc_hp_value:
			return
		_pc_hp_value = new_value
@export var pc_sheild: Array[Dictionary] = [] # 当前盾量
@export var pc_lv: int = 1 # 局内等级
@export var pc_exp: int = 0 # 局内经验
@export var pc_max_hp: int = 50 # 局内最大hp
@export var pc_start_max_hp: int = 50 # 进入关卡时的初始HP上限

var _pc_hp_value: int = 50

@export var move_speed_bonus: float = 0.0 # 局内移动速度加成
@export var attack_speed_bonus: float = 0.0 # 局内攻击速度加成

const DISTANCE_UNIT_PIXELS: float = 20.0

func world_pixels_to_distance_steps(pixels: float) -> float:
	return pixels / DISTANCE_UNIT_PIXELS

func distance_steps_to_world_pixels(distance_steps: float) -> float:
	return distance_steps * DISTANCE_UNIT_PIXELS
@export var crit_chance: float = 0.0 # 局内暴击率
@export var crit_damage_multi: float = 0.5 # 局内暴击伤害倍率 (例如0.5代表150%伤害)
@export var damage_reduction_rate: float = 0.0 # 局内减伤率 (例如0.1代表10%减伤)
@export var independent_damage_reduction_multiplier: float = 1.0 # 独立受击倍率，0.6代表额外40%减伤
var independent_damage_reduction_sources: Dictionary = {}
@export var damage_deal_multiplier: float = 1.0 # 独立伤害倍率，仅用于暗影拘束等特殊机制，普通“最终伤害”必须接入 final_damage_bonus
@export var point_multi: float = 0 # 额外真气获取率
@export var spirit_multi: float = 0.0 # 额外精魄获取率
@export var exp_multi: float = 0 # 额外exp获取率
@export var drop_multi: float = 0 # 额外掉落率
@export var heal_aura_drop_multi: float = 0.0 # 额外治愈灵气掉落率
@export var body_size: float = 1 # 体型大小
@export var attack_range: float = 1.0 # 伤害范围
@export var knockback_bonus: float = 0.0 # 击退幅度加成
@export var heal_multi: float = 0 # 额外治疗加成
@export var bloodwave_dynamic_heal_bonus: float = 0.0
@export var sheild_multi: float = 0 # 额外护盾加成
@export var normal_monster_multi: float = 0 # 对小怪额外伤害
@export var boss_multi: float = 0 # 对精英首领额外伤害
@export var cooldown: float = 0 # 主动技能冷却缩减
@export var active_skill_multi: float = 0 # 主动技能伤害加成
@export var chant_cooldown_acceleration: float = 0.0 # 咏唱技能冷却加速倍率（0=无加速，1.0=100%加速即每秒额外减1秒）
@export var chant_time_reduction: float = 0.0 # 咏唱时间缩减比例（0=无缩减，0.5=缩减50%）
@export var enemy_move_speed_multiplier: float = 1.0 # 关卡内敌人移动速度倍率（每次进入关卡重置为1.0）
@export var enemy_hp_multiplier: float = 1.0 # 关卡内敌人体力上限倍率（每次进入关卡重置为1.0）
@export var enemy_damage_multiplier: float = 1.0 # 关卡内敌人伤害倍率（每次进入关卡重置为1.0）

const INCOMING_DAMAGE_VARIANCE_MIN: float = 0.95
const INCOMING_DAMAGE_VARIANCE_MAX: float = 1.05
const ENEMY_MIN_DAMAGE_PLAYER_HP_RATIO: float = 0.10
const MIN_DAMAGE_EXCLUDED_SOURCES: Array[String] = [
	"泥潭",
	"泥沼",
	"暗影拘束",
	"腐蚀轮转",
	"答问",
]

func get_total_attack_speed_bonus() -> float:
	return attack_speed_bonus

func is_outside_move_speed_bonus_disabled() -> bool:
	return EmblemManager.has_emblem("manli")

func get_outside_move_speed_bonus() -> float:
	if is_outside_move_speed_bonus_disabled():
		return 0.0
	return Global.cultivation_zhuifeng_level * 0.01 + Global.study_move_speed_bonus

func get_total_move_speed_bonus() -> float:
	if is_outside_move_speed_bonus_disabled():
		return move_speed_bonus
	return move_speed_bonus + get_outside_move_speed_bonus()

func get_manli_effective_move_speed_bonus() -> float:
	return move_speed_bonus

func get_total_damage_reduction_rate() -> float:
	return damage_reduction_rate

func get_knockback_multiplier() -> float:
	return maxf(0.0, 1.0 + knockback_bonus)

func add_final_damage_bonus(value: float) -> void:
	final_damage_bonus += value

func add_attack_speed_bonus(value: float) -> void:
	attack_speed_bonus += value

func add_move_speed_bonus(value: float) -> void:
	move_speed_bonus += value

func add_damage_reduction_bonus(value: float, max_value: float = 0.7) -> void:
	damage_reduction_rate = min(damage_reduction_rate + value, max_value)

func add_attack_flat_bonus(value: int) -> void:
	pc_atk += value

func add_attack_percent_bonus(value: float) -> void:
	pc_atk += int(round(float(base_atk) * value))

func add_base_attack_growth(flat_bonus: int, rate_bonus: float) -> void:
	var old_base_atk := base_atk
	base_atk += flat_bonus
	base_atk = int(float(base_atk) * (1.0 + rate_bonus))
	pc_atk += base_atk - old_base_atk

func refresh_yujian_summon_bonuses() -> void:
	if yujian_applied_summon_damage_bonus != 0.0:
		summon_damage_multiplier -= yujian_applied_summon_damage_bonus
		yujian_applied_summon_damage_bonus = 0.0
	if not is_equal_approx(yujian_applied_interval_multiplier, 1.0):
		yujian_applied_interval_multiplier = 1.0
	var move_damage_bonus := 0.0
	if yujian_move_summon_damage_per_10 > 0.0:
		var move_groups := floori(maxf(0.0, get_total_move_speed_bonus()) / 0.10)
		move_damage_bonus = minf(float(move_groups) * yujian_move_summon_damage_per_10, yujian_move_summon_damage_cap)
	var level_damage_bonus := float(main_skill_yujian) * yujian_level_summon_damage_per_level
	yujian_applied_summon_damage_bonus = move_damage_bonus + level_damage_bonus
	summon_damage_multiplier += yujian_applied_summon_damage_bonus
	if yujian_interval_reduction_per_level > 0.0:
		var reduction := clampf(float(main_skill_yujian) * yujian_interval_reduction_per_level, 0.0, 0.90)
		yujian_applied_interval_multiplier = 1.0 - reduction
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("update_summons_properties"):
		player.update_summons_properties()

@export var total_distance_moved: float = 0.0 # 本局累计移动距离（世界像素，20世界像素=20距离）
var distance_buff_offsets: Dictionary = {} # 各移动距离buff获取时的距离步数，key=reward_id, value=steps_at_acquisition
@export var xianqi_points: int = 0 # 仙气凝聚层数
@export var xianli_active: bool = false # 仙力护体是否已激活
@export var xianqi_final_damage_applied_bonus: float = 0.0 # 仙气凝聚已应用最终伤害
@export var xianqi_hp_applied_bonus: float = 0.0 # 仙气凝聚已应用体力上限数值
@export var xuji_remaining: int = 0 # 蓄积(UR53)剩余升级次数（每次升级+5%攻击）
@export var bleed_damage_multi: float = 0.0 # 流血伤害加成倍率（UR51十八层）
@export var electrification_damage_multi: float = 0.0 # 感电伤害加成倍率（UR51十八层）
@export var fire_damage_multi: float = 0.0 # 灼烧伤害加成倍率（UR51十八层）
@export var debuff_cross_damage_multi: float = 0.0 # 异常交叉伤害加成倍率（UR51十八层：有一种异常时其他两异常伤害+150%）

func get_burn_damage_bonus() -> float:
	var bonus := fire_damage_multi
	if faze_fire_level >= 4:
		bonus += 0.5
	if faze_fire_level >= 9:
		bonus += 0.5
	if faze_fire_level >= 22:
		bonus += 1.2
	if faze_fire_level >= 29:
		bonus += 1.2
	bonus += _get_best_selected_reward_bonus({
		"SSR38a": 0.55,
		"SR38a": 0.45,
		"R38a": 0.35,
	})
	return bonus

func get_electrified_damage_bonus() -> float:
	var bonus := electrification_damage_multi
	if faze_thunder_level >= 4:
		bonus += 0.4
	bonus += _get_best_selected_reward_bonus({
		"SSR38": 0.55,
		"SR38": 0.45,
		"R38": 0.35,
	})
	return bonus

func get_bleed_damage_bonus() -> float:
	var bonus := bleed_damage_multi
	if faze_blood_level >= 29:
		bonus += 16.0
	elif faze_blood_level >= 16:
		bonus += 5.0
	bonus += _get_best_selected_reward_bonus({
		"SSR37": 0.55,
		"SR37": 0.45,
		"R37": 0.35,
	})
	return bonus

func get_vulnerability_effect_bonus() -> float:
	return _get_best_selected_reward_bonus({
		"SSR36": 0.275,
		"SR36": 0.225,
		"R36": 0.175,
	})

func get_vulnerable_effect_bonus() -> float:
	return _get_best_selected_reward_bonus({
		"SSR35": 0.275,
		"SR35": 0.225,
		"R35": 0.175,
	})

func get_slow_effect_bonus() -> float:
	return _get_best_selected_reward_bonus({
		"SSR34": 0.275,
		"SR34": 0.225,
		"R34": 0.175,
	})

func _get_best_selected_reward_bonus(reward_bonuses: Dictionary) -> float:
	var best_bonus := 0.0
	for reward_id in reward_bonuses.keys():
		if selected_rewards.has(str(reward_id)):
			best_bonus = maxf(best_bonus, float(reward_bonuses[reward_id]))
	return best_bonus

# 护甲与生命恢复
@export var pc_armor: float = 0.0 # 护甲值（减伤公式: armor/(armor+500)）
@export var pc_hp_regen: float = 0.0 # 生命恢复（百分比，如5.5代表每次恢复5.5%最大体力）
@export var hp_regen_interval: float = 5.0 # 生命恢复间隔（秒）
@export var hp_regen_timer: float = 0.0 # 生命恢复计时器
@export var spirit: int = 0 # 本局精魄（显示/消费使用向下取整后的整数）
@export var spirit_raw: float = 0.0 # 本局精魄实际值（保留到小数点后一位）
@export var spirit_armor_applied_bonus: float = 0.0 # 精魄加护已应用护甲
@export var spirit_final_damage_applied_bonus: float = 0.0 # 精魄之力已应用最终伤害
@export var emblem_awakening_final_damage_applied_bonus: float = 0.0 # 纹章觉醒已应用最终伤害
@export var emblem_awakening_damage_reduction_applied_bonus: float = 0.0 # 纹章觉醒已应用减伤率
@export var pain_relief_active: bool = false # 痛楚减弱持续恢复中
@export var pain_relief_remaining_heal: float = 0.0
@export var pain_relief_tick_accumulator: float = 0.0
@export var pain_relief_remaining_time: float = 0.0

# 领悟系列：每级额外属性加成
@export var lingwu_atk_flat_bonus: int = 0 # 力量领悟：每级攻击固定提升量
@export var lingwu_atk_bonus: float = 0.0 # 力量领悟：每级攻击百分比提升量
@export var lingwu_hp_bonus: float = 0.0 # 体质领悟：每级体力上限提升百分比
@export var lingwu_atk_speed_bonus: float = 0.0 # 敏捷领悟：每级攻速加成
@export var lingwu_speed_bonus: float = 0.0 # 速度领悟：每级移速加成
@export var lingwu_final_dmg_bonus: float = 0.0 # 威压领悟：每级最终伤害加成
@export var lingwu_armor_bonus: float = 0.0 # 护御领悟：每级额外护甲
# 铸匠/宝器/唤灵之魂：升级概率提升
@export var lingwu_weapon_upgrade_bonus: float = 0.0 # 铸匠之魂：武器升级概率提升
@export var lingwu_lucky_upgrade_bonus: float = 0.0 # 宝器之魂：天命升级概率提升
@export var lingwu_summon_upgrade_bonus: float = 0.0 # 唤灵之魂：召唤升级概率提升
@export var lingwu_live_upgrade_bonus: float = 0.0 # 存续之魂：生存升级概率提升
var weapon_upgrade_law_bonus_rates: Dictionary = {}
var weapon_upgrade_law_decay_counts: Dictionary = {}

@export var faze_blood_level: int = 0
@export var faze_sword_level: int = 0
@export var faze_thunder_level: int = 7
@export var faze_heal_level: int = 0
@export var faze_summon_level: int = 0
@export var faze_shield_level: int = 0
@export var faze_fire_level: int = 0
@export var faze_destroy_level: int = 0
@export var faze_life_level: int = 0
@export var faze_bullet_level: int = 0
@export var faze_wide_level: int = 0
@export var faze_bagua_level: int = 0
@export var faze_treasure_level: int = 0
@export var faze_deep_level: int = 0
@export var faze_shehun_level: int = 0
@export var faze_chaos_level: int = 0
@export var faze_skill_level: int = 0
@export var faze_sixsense_level: int = 0
@export var sixsense_bonus_multiplier: float = 1.0
@export var sixsense_base_crit_chance: float = 0.0
@export var sixsense_base_crit_damage_multi: float = 0.0
@export var sixsense_base_final_damage: float = 0.0
@export var sixsense_base_atk_speed: float = 0.0
@export var sixsense_base_damage_reduction: float = 0.0
@export var sixsense_base_atk: float = 0.0
@export var sixsense_applied_crit_chance: float = 0.0
@export var sixsense_applied_crit_damage_multi: float = 0.0
@export var sixsense_applied_final_damage: float = 0.0
@export var sixsense_applied_atk_speed: float = 0.0
@export var sixsense_applied_damage_reduction: float = 0.0
@export var sixsense_applied_atk: float = 0.0
@export var faze_bagua_progress: int = 0
@export var faze_bagua_complete_layers: int = 0
@export var faze_bagua_next_threshold: int = 100
@export var faze_sword_coldlight_stack: int = 0
@export var faze_wind_level: int = 0
@export var wind_huanfeng_stacks: int = 0
@export var wind_huanfeng_max_stacks: int = 0
@export var wind_huanfeng_duration: float = 12.0
@export var faze_heal_shield_bonus: float = 0.0
@export var shehun_law_spirit_multi_bonus: float = 0.0
@export var shehun_law_crit_chance_bonus: float = 0.0
@export var shehun_law_final_damage_bonus: float = 0.0
@export var shehun_law_damage_reduction_bonus: float = 0.0
@export var shehun_law_spirit_next_threshold: float = 4000.0
@export var shehun_law_spirit_spent: float = 0.0

# 御灵法则 (Summon Law)
@export var faze_summon_extra_capacity: int = 0
@export var faze_summon_bullet_size_bonus: float = 0.0
@export var faze_summon_damage_bonus: float = 0.0
@export var faze_summon_interval_reduction: float = 0.0
@export var has_summoned_bipolar_sword: bool = false
@export var has_summoned_sword_spirit: bool = false

# 护佑法则 (Shield Law)
@export var faze_shield_hp_bonus: float = 0.0
@export var faze_shield_gain_bonus: float = 0.0
@export var faze_shield_heal_conversion_ratio: float = 0.0
@export var faze_shield_damage_reduction_bonus: float = 0.0

# 广域法则 (Wide Law)
@export var faze_wide_range_bonus: float = 0.0
@export var faze_wide_damage_bonus: float = 0.0
@export var faze_wide_range_to_damage_ratio: float = 0.0
@export var faze_wide_global_attack_range_bonus: float = 0.0

# 八卦法则 (Bagua Law)
@export var faze_bagua_damage_bonus: float = 0.0
@export var faze_bagua_gain_multiplier: float = 1.0
@export var faze_bagua_completed_layers: int = 0

@export var invincible: bool = false
@export var instant_level_up: bool = true # true=升级立即弹出，false=存储待手动触发

@export var current_time: float = 0
@export var real_time: float = 0

@export var last_lunky_level: int = 1
@export var last_speed: float = 0
@export var last_atk_speed: float = 0
@export var battle_start_lunky_level: int = 1
@export var battle_start_atk_speed: float = 0.0

@export var current_weapon_num: int = 0
@export var new_weapon_obtained_count: int = 0 # 新获得武器计数（用于怪物血量乘算）

# 魔焰相关变量
@export var main_skill_moyan = 0
@export var main_skill_moyan_advance = 0
@export var first_has_moyan: bool = true
@export var main_skill_moyan_damage: float = 1.6 # 魔焰基础伤害倍率
@export var moyan_range: float = 200.0 # 魔焰基础射程

# 跟升级抽卡有关系的
@export var now_lunky_level: int = 1
@export var now_red_p: float = 0.2
@export var now_gold_p: float = 4
@export var now_darkorchid_p: float = 20.5
@export var now_blue_p: float = 75
@export var selected_rewards = []

const RED_CHANCE_PER_LUCKY: float = 0.01
const GOLD_CHANCE_PER_LUCKY: float = 0.175
const DARKORCHID_CHANCE_PER_LUCKY: float = 0.5

# 诗想难度备战配置（跨场景保持，reset_player_attr不重置此字段）
var poetry_loadout: Dictionary = {}

# 存储主要技能等级
@export var main_skill_swordQi = 0
@export var main_skill_swordQi_advance = 0

# 剑气相关属性
@export var main_skill_swordQi_damage: float = 1
@export var swordQi_penetration_count: int = 1
@export var swordQi_other_sword_wave_damage: float = 0.5
@export var swordQi_range: float = 132
@export var jinghong_attack_count: int = 0
@export var first_has_swordqi: bool = true

# 树枝相关属性
@export var main_skill_branch = 0
@export var main_skill_branch_advance = 0
@export var first_has_branch: bool = true
@export var main_skill_branch_damage: float = 1
@export var branch_split_count: int = 3
@export var branch_range: float = 90

# 日炎相关变量
@export var main_skill_riyan = 0
@export var main_skill_riyan_advance = 0
@export var main_skill_riyan_damage: float = 1
@export var first_has_riyan: bool = true
@export var first_has_riyan_pc: bool = true
@export var riyan_range: float = 84.0
@export var riyan_cooldown: float = 1 # 赤曜伤害频率：1秒/次
@export var riyan_hp_max_damage: float = 0.08 # 赤曜基础伤害：最大体力的8%/秒
@export var riyan_atk_damage: float = 0.30 # 赤曜基础伤害：攻击力的30%

# 环火相关量
@export var main_skill_ringFire = 0
@export var main_skill_ringFire_advance = 0
@export var main_skill_ringFire_damage: float = 0.15 # 炎轮基础伤害15%
@export var first_has_ringFire: bool = true

# 雷光相关量
@export var main_skill_thunder = 0
@export var main_skill_thunder_advance = 0
@export var main_skill_thunder_damage: float = 0.75
@export var first_has_thunder: bool = true
@export var thunder_range: float = 260.0

# 血气波相关量
@export var main_skill_bloodwave = 0
@export var main_skill_bloodwave_advance = 0
@export var first_has_bloodwave: bool = true

# 饮血刀
@export var main_skill_bloodboardsword = 0
@export var main_skill_bloodboardsword_advance = 0
@export var main_skill_bloodboardsword_damage: float = 0.95
@export var first_has_bloodboardsword: bool = true

# 冰刺术相关变量
@export var main_skill_ice = 0
@export var main_skill_ice_advance = 0
@export var first_has_ice: bool = true


# 天雷破相关变量
@export var main_skill_thunder_break = 0
@export var main_skill_thunder_break_advance = 0
@export var first_has_thunder_break: bool = true
@export var main_skill_thunder_break_damage: float = 0.65
@export var thunder_break_final_damage_multi: float = 1.0 # 天雷破总伤害加成

# 光弹术相关变量
@export var main_skill_light_bullet = 0
@export var main_skill_light_bullet_advance = 0
@export var first_has_light_bullet: bool = true
@export var main_skill_light_bullet_damage: float = 0.45
@export var light_bullet_final_damage_multi: float = 1.0 # 光弹术总伤害加成
@export var light_bullet_shot_count = 0

# 坎水诀相关变量
@export var main_skill_water = 0
@export var main_skill_water_advance = 0
@export var first_has_water: bool = true
@export var main_skill_water_damage: float = 0.35
@export var water_final_damage_multi: float = 1.0 # 坎水诀总伤害加成

# 乾坤双剑相关变量
@export var main_skill_qiankun = 0
@export var main_skill_qiankun_advance = 0
@export var first_has_qiankun: bool = true


# 玄武相关变量
@export var main_skill_xuanwu = 0
@export var main_skill_xuanwu_advance = 0
@export var first_has_xuanwu: bool = true


# 巽风诀相关变量
@export var main_skill_xunfeng = 0
@export var main_skill_xunfeng_advance = 0
@export var first_has_xunfeng: bool = true
@export var main_skill_dragonwind = 0
@export var main_skill_dragonwind_advance = 0
@export var main_skill_dragonwind_damage: float = 1.0
@export var first_has_dragonwind: bool = true


# 艮山诀相关变量
@export var main_skill_genshan = 0
@export var main_skill_genshan_advance = 0
@export var first_has_genshan: bool = true

# 兑泽诀相关变量
@export var main_skill_duize = 0
@export var main_skill_duize_advance = 0
@export var first_has_duize: bool = true

# 圣光术相关变量
@export var main_skill_holylight = 0
@export var main_skill_holylight_advance = 0
@export var first_has_holylight: bool = true


# 气功波相关变量
@export var main_skill_qigong = 0
@export var main_skill_qigong_advance = 0
@export var first_has_qigong: bool = true
@export var main_skill_qigong_damage: float = 0.0

# 爪爪巨锤相关变量
@export var main_skill_zhuazhuajuchui = 0
@export var main_skill_zhuazhuajuchui_advance = 0
@export var first_has_zhuazhuajuchui: bool = true

# 噬魂镰相关变量
@export var main_skill_soul_sickle = 0
@export var main_skill_soul_sickle_advance = 0
@export var main_skill_soul_sickle_damage: float = 0.30
@export var first_has_soul_sickle: bool = true

# 雷魂枪相关变量
@export var main_skill_thunder_gun = 0
@export var main_skill_thunder_gun_advance = 0
@export var main_skill_thunder_gun_damage: float = 0.65
@export var first_has_thunder_gun: bool = true
@export var thunder_gun_ammo: int = 0
@export var thunder_gun_reloading: bool = false

# 御剑相关变量
@export var main_skill_yujian = 0
@export var main_skill_yujian_advance = 0
@export var first_has_yujian: bool = true
@export var yujian_move_summon_damage_per_10: float = 0.0
@export var yujian_move_summon_damage_cap: float = 0.0
@export var yujian_level_summon_damage_per_level: float = 0.0
@export var yujian_applied_summon_damage_bonus: float = 0.0
@export var yujian_interval_reduction_per_level: float = 0.0
@export var yujian_applied_interval_multiplier: float = 1.0


# 反弹子弹相关属性
@export var rebound_size_multiplier: float = 0.4 # 反弹子弹大小倍数
@export var rebound_damage_multiplier: float = 0.35 # 反弹子弹伤害倍数

# 环形子弹相关属性
@export var ring_bullet_enabled: bool = false
@export var ring_bullet_count: int = 8
@export var ring_bullet_size_multiplier: float = 0.7
@export var ring_bullet_damage_multiplier: float = 1
@export var ring_bullet_interval: float = 2.5
@export var ring_bullet_last_shot_time: float = 0.0

# 浪形子弹相关属性
@export var wave_bullet_enabled: bool = false
@export var wave_bullet_interval: float = 4.0
@export var wave_bullet_last_shot_time: float = 0.0
@export var wave_bullet_damage_multiplier: float = 0.5 # 浪形子弹伤害倍数（默认50%攻击）
@export var wave_bullet_count: int = 8 # 浪形子弹每轮发射的弹体数量，默认8

# 召唤物相关属性
@export var summon_count: int = 0 # 当前召唤物数量
@export var summon_count_max: int = 3 # 当前召唤物数量
@export var new_summon: String
@export var summon_damage_multiplier: float = 1.0 # 召唤物伤害倍数
@export var summon_interval_multiplier: float = 1.0 # 召唤物发射间隔倍数
@export var summon_bullet_size_multiplier: float = 1.0 # 召唤物子弹大小倍数
@export var summon_range_multiplier: float = 1.0 # 召唤物射程倍率
@export var summon_penetration_count: int = 0 # 召唤物可穿透敌人数量


# 刷新次数
@export var refresh_num: int = 5
# 锁定次数
@export var lock_num: int = 3
# 禁用次数
@export var ban_num: int = 0
var banned_lingwu_series: Dictionary = {}

# 纹章相关字段
@export var emblem_slots_max: int = 4
@export var current_emblems: Dictionary = {} # 当前持有的纹章 {emblem_id: stack}
@export var xueqi_last_trigger_time: float = -99999.0

const START_WEAPON_RUNTIME_MAP := {
	"SwordQi": {"skill_id": "swordqi", "reward_id": "SwordQi", "attack_ids": ["swordqi"]},
	"Qigong": {"skill_id": "qigong", "reward_id": "Qigong", "attack_ids": ["qigong"]},
	"LightBullet": {"skill_id": "light_bullet", "reward_id": "LightBullet", "attack_ids": ["light_bullet", "light bullet"]},
	"Ice": {"skill_id": "ice", "reward_id": "Ice", "attack_ids": ["ice_flower", "ice", "ice flower"]},
	"Xunfeng": {"skill_id": "xunfeng", "reward_id": "Xunfeng", "attack_ids": ["xunfeng"]},
	"Genshan": {"skill_id": "genshan", "reward_id": "Genshan", "attack_ids": ["genshan"]},
	"Bloodwave": {"skill_id": "bloodwave", "reward_id": "Bloodwave", "attack_ids": ["bloodwave", "blood_wave"]},
	"Xuanwu": {"skill_id": "xuanwu", "reward_id": "Xuanwu", "attack_ids": ["xuanwu"]},
	"Water": {"skill_id": "water", "reward_id": "Water", "attack_ids": ["water"]},
	"HolyLight": {"skill_id": "holylight", "reward_id": "HolyLight", "attack_ids": ["holylight", "holy_light"]},
	"Branch": {"skill_id": "branch", "reward_id": "Branch", "attack_ids": ["branch"]},
	"Thunder": {"skill_id": "thunder", "reward_id": "Thunder", "attack_ids": ["thunder"]},
	"ThunderBreak": {"skill_id": "thunder_break", "reward_id": "ThunderBreak", "attack_ids": ["thunder_break"]},
	"Moyan": {"skill_id": "moyan", "reward_id": "Moyan", "attack_ids": ["moyan"]},
	"Qiankun": {"skill_id": "qiankun", "reward_id": "Qiankun", "attack_ids": ["qiankun"]},
	"BloodBoardSword": {"skill_id": "bloodboardsword", "reward_id": "BloodBoardSword", "attack_ids": ["bloodboardsword", "blood_broadsword"]},
	"Riyan": {"skill_id": "riyan", "reward_id": "Riyan", "attack_ids": ["riyan"]},
	"RingFire": {"skill_id": "ringFire", "reward_id": "RingFire", "attack_ids": ["ringfire", "ringFire", "ring_fire"]},
	"Duize": {"skill_id": "duize", "reward_id": "Duize", "attack_ids": ["duize"]},
	"DragonWind": {"skill_id": "dragonwind", "reward_id": "DragonWind", "attack_ids": ["dragonwind", "dragon_wind"]},
	"Zhuazhuajuchui": {"skill_id": "zhuazhuajuchui", "reward_id": "Zhuazhuajuchui", "attack_ids": ["zhuazhuajuchui"]},
	"SoulSickle": {"skill_id": "soul_sickle", "reward_id": "SoulSickle", "attack_ids": ["soul_sickle"]},
	"ThunderGun": {"skill_id": "thunder_gun", "reward_id": "ThunderGun", "attack_ids": ["thunder_gun"]},
}

# active配置字段
@export var cooldown_multi: float = 1.0 # active cd
@export var dodge_multi: float = 1.0
@export var random_strike_multi: float = 1.0


@export var is_game_over: bool = false
@export var movement_disabled: bool = false # 控制玩家移动是否被禁用
@export var is_chanting: bool = false # 是否正在咏唱技能（咏唱期间可移动但减速）
@export var chant_speed_reduction: float = 0.0 # 咏唱期间移动速度减少比例（0.7=减70%）

func _ready():
	Global.connect("lucky_level_up", Callable(self , "_on_lucky_level_up"))

func _on_lucky_level_up(lunky_up: float) -> void:
	_recalculate_reward_rarity_chances()

func get_reward_acquisition_count(fallback_reward_id: String):
	return selected_rewards.count(fallback_reward_id)

func get_pain_relief_ratio() -> float:
	if selected_rewards.has("SSR83"):
		return 0.12
	if selected_rewards.has("SR83"):
		return 0.10
	if selected_rewards.has("R83"):
		return 0.08
	return 0.0

func get_pain_spirit_gain() -> int:
	if selected_rewards.has("SSR84"):
		return 90
	if selected_rewards.has("SR84"):
		return 60
	if selected_rewards.has("R84"):
		return 40
	return 0

func get_pain_exp_ratio() -> float:
	if selected_rewards.has("SSR85"):
		return 0.025
	if selected_rewards.has("SR85"):
		return 0.02
	if selected_rewards.has("R85"):
		return 0.015
	return 0.0

func get_kill_spirit_bonus() -> int:
	if selected_rewards.has("SSR87"):
		return 3
	if selected_rewards.has("SR87"):
		return 2
	return 0

func get_display_spirit(value: float) -> int:
	return max(int(floor(value)), 0)

func get_spirit_armor_per_group() -> float:
	if selected_rewards.has("SSR90"):
		return 8.0
	if selected_rewards.has("SR90"):
		return 6.0
	if selected_rewards.has("R90"):
		return 5.0
	return 0.0

func get_spirit_final_damage_per_group() -> float:
	if selected_rewards.has("SSR91"):
		return 0.015
	if selected_rewards.has("SR91"):
		return 0.0125
	if selected_rewards.has("R91"):
		return 0.01
	return 0.0

func add_spirit(amount: float) -> void:
	if amount <= 0:
		return
	spirit_raw += floor(amount * 10.0) / 10.0
	_update_shehun_law_spirit_progress(amount)
	spirit = get_display_spirit(spirit_raw)
	update_spirit_reward_bonuses()
	update_shehun_spirit_progress_buff()
	_scan_achievement_runtime_keys(["spirit", "armor", "final_damage"])

func sync_spirit(value: float) -> void:
	var old_spirit_raw := spirit_raw
	spirit_raw = max(value, 0.0)
	if spirit_raw > old_spirit_raw:
		_update_shehun_law_spirit_progress(spirit_raw - old_spirit_raw)
	spirit = get_display_spirit(spirit_raw)
	update_spirit_reward_bonuses()
	update_shehun_spirit_progress_buff()
	_scan_achievement_runtime_keys(["spirit", "armor", "final_damage"])

func _update_shehun_law_spirit_progress(gained_amount: float) -> void:
	if gained_amount <= 0.0 or faze_shehun_level < 8:
		return
	shehun_law_spirit_spent += gained_amount
	var leveled := false
	while shehun_law_spirit_spent >= shehun_law_spirit_next_threshold:
		shehun_law_spirit_spent -= shehun_law_spirit_next_threshold
		shehun_law_spirit_next_threshold += 4000.0
		faze_shehun_level += 1
		leveled = true
	if leveled and Faze.manager_instance:
		Faze.manager_instance.check_and_apply_law_bonuses()

func _format_shehun_spirit_remaining(value: float) -> String:
	var amount := int(ceil(maxf(0.0, value)))
	if amount > 10000:
		return "%dk" % int(round(float(amount) / 1000.0))
	if amount > 1000:
		return "%.1fk" % (float(amount) / 1000.0)
	return str(amount)

func update_shehun_spirit_progress_buff() -> void:
	if faze_shehun_level <= 9:
		if BuffManager.has_buff(SHEHUN_SPIRIT_PROGRESS_BUFF_ID):
			Global.emit_signal("buff_removed", SHEHUN_SPIRIT_PROGRESS_BUFF_ID)
		return

	var remaining := maxf(0.0, shehun_law_spirit_next_threshold - shehun_law_spirit_spent)
	var remaining_text := _format_shehun_spirit_remaining(remaining)
	var remaining_amount := int(ceil(remaining))
	BuffManager.update_buff_description(
		SHEHUN_SPIRIT_PROGRESS_BUFF_ID,
		"距离下一层摄魂法则还需要 " + str(remaining_amount) + " 精魄"
	)
	if BuffManager.has_buff(SHEHUN_SPIRIT_PROGRESS_BUFF_ID):
		Global.emit_signal("buff_updated", SHEHUN_SPIRIT_PROGRESS_BUFF_ID, -1, 1)
	else:
		Global.emit_signal("buff_added", SHEHUN_SPIRIT_PROGRESS_BUFF_ID, -1, 1)
	BuffManager.set_buff_stack_text(SHEHUN_SPIRIT_PROGRESS_BUFF_ID, remaining_text)

func update_spirit_reward_bonuses() -> void:
	var spirit_groups := mini(int(floor(float(spirit) / 1000.0)), 50)
	var armor_target := float(spirit_groups) * get_spirit_armor_per_group()
	var armor_delta := armor_target - spirit_armor_applied_bonus
	if not is_equal_approx(armor_delta, 0.0):
		pc_armor += armor_delta
		spirit_armor_applied_bonus = armor_target

	var final_damage_target := float(spirit_groups) * get_spirit_final_damage_per_group()
	var final_damage_delta := final_damage_target - spirit_final_damage_applied_bonus
	if not is_equal_approx(final_damage_delta, 0.0):
		final_damage_bonus += final_damage_delta
		spirit_final_damage_applied_bonus = final_damage_target

	var shehun_groups := int(floor(float(spirit) / 5000.0))
	var shehun_final_per_group := Faze.get_shehun_final_damage_per_spirit_group(faze_shehun_level)
	var shehun_dr_per_group := Faze.get_shehun_damage_reduction_per_spirit_group(faze_shehun_level)
	var shehun_final_target := float(shehun_groups) * shehun_final_per_group
	var shehun_final_delta := shehun_final_target - shehun_law_final_damage_bonus
	if not is_equal_approx(shehun_final_delta, 0.0):
		final_damage_bonus += shehun_final_delta
		shehun_law_final_damage_bonus = shehun_final_target
	var shehun_dr_target := float(shehun_groups) * shehun_dr_per_group
	var shehun_dr_delta := shehun_dr_target - shehun_law_damage_reduction_bonus
	if not is_equal_approx(shehun_dr_delta, 0.0):
		damage_reduction_rate += shehun_dr_delta
		shehun_law_damage_reduction_bonus = shehun_dr_target

func _scan_achievement_runtime_keys(keys: Array[String]) -> void:
	var achievement_manager = get_node_or_null("/root/AchievementManager")
	if achievement_manager != null and achievement_manager.has_method("scan_runtime_keys"):
		achievement_manager.scan_runtime_keys(keys, false)

func _normalize_attack_id(attack_id: String) -> String:
	return attack_id.strip_edges().to_lower().replace(" ", "_")

func get_base_weapon_runtime_info(player_name_override: String = "") -> Dictionary:
	var start_weapon_id := Global.get_selected_start_weapon(player_name_override)
	if START_WEAPON_RUNTIME_MAP.has(start_weapon_id):
		return START_WEAPON_RUNTIME_MAP[start_weapon_id]
	return {}

func get_base_weapon_attack_id(player_name_override: String = "") -> String:
	var weapon_info := get_base_weapon_runtime_info(player_name_override)
	return _normalize_attack_id(str(weapon_info.get("skill_id", "")))

func is_base_weapon_attack(attack_id: String, player_name_override: String = "") -> bool:
	var normalized_attack_id := _normalize_attack_id(attack_id)
	if normalized_attack_id.is_empty():
		return false
	var weapon_info := get_base_weapon_runtime_info(player_name_override)
	if weapon_info.is_empty():
		return false
	for candidate in weapon_info.get("attack_ids", []):
		if normalized_attack_id == _normalize_attack_id(str(candidate)):
			return true
	return normalized_attack_id == _normalize_attack_id(str(weapon_info.get("skill_id", "")))

func _grant_start_weapon(start_weapon_id: String) -> void:
	var normalized_id := Global.normalize_start_weapon_id(start_weapon_id)
	var start_weapon_info: Dictionary = START_WEAPON_RUNTIME_MAP.get(normalized_id, {})
	if start_weapon_info.is_empty():
		return
	var reward_id := str(start_weapon_info.get("reward_id", "SwordQi"))
	if not PC.selected_rewards.has(reward_id):
		PC.selected_rewards.append(reward_id)
	PC.current_weapon_num += 1
	_reset_start_weapon_runtime_data(normalized_id)
	var faze_levels := Global.get_start_weapon_faze_levels(normalized_id)
	for faze_prop in faze_levels.keys():
		PC.set(faze_prop, int(PC.get(faze_prop)) + int(faze_levels[faze_prop]))
	_activate_granted_start_weapon_runtime(normalized_id)

func _activate_granted_start_weapon_runtime(start_weapon_id: String) -> void:
	var player = PC.player_instance
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("activate_granted_start_weapon"):
		player.call_deferred("activate_granted_start_weapon", start_weapon_id)

func _reset_start_weapon_runtime_data(start_weapon_id: String) -> void:
	match start_weapon_id:
		"Ice":
			IceFlower.reset_data()
		"Bloodwave":
			BloodWave.reset_data()
		"Qiankun":
			Qiankun.reset_data()
		"Xuanwu":
			Xuanwu.reset_data()
		"Xunfeng":
			Xunfeng.reset_data()
		"Genshan":
			Genshan.reset_data()
		"Duize":
			Duize.reset_data()
		"HolyLight":
			HolyLight.reset_data()
		"DragonWind":
			DragonWind.reset_data()
		"Zhuazhuajuchui":
			ZHUAZHUAJUCHUI_SCRIPT.reset_data()
		"SoulSickle":
			SoulSickle.reset_data()
		"ThunderGun":
			THUNDER_GUN_SCRIPT.reset_data()
		"Qigong":
			Qigong.sync_reward_modifiers()

func apply_base_weapon_emblem_damage_bonus(base_damage: float, attack_id: String, is_extra_attack: bool = false) -> float:
	var final_damage := base_damage
	if not is_base_weapon_attack(attack_id):
		return final_damage
	
	if EmblemManager.has_emblem("xueqi"):
		var current_battle_time = Time.get_ticks_msec() / 1000.0
		if current_battle_time - xueqi_last_trigger_time >= 1.0:
			var xueqi_stack = EmblemManager.get_emblem_stack("xueqi")
			var hp_percent_damage = pc_hp * Global.get_scaled_emblem_value(0.06 * xueqi_stack)
			final_damage += hp_percent_damage
			xueqi_last_trigger_time = current_battle_time
	
	if EmblemManager.has_emblem("jinghong") and not is_extra_attack:
		jinghong_attack_count += 1
		if jinghong_attack_count % 3 == 0:
			var jinghong_stack = EmblemManager.get_emblem_stack("jinghong")
			var extra_damage_multiplier = Global.get_scaled_emblem_value(0.12 * jinghong_stack)
			queue_base_weapon_extra_attack(extra_damage_multiplier)
	
	return final_damage

func queue_base_weapon_extra_attack(damage_multiplier: float) -> void:
	if damage_multiplier <= 0.0:
		return
	var tree := get_tree()
	if tree == null:
		return
	var timer = tree.create_timer(0.1)
	timer.timeout.connect(func():
		if player_instance and is_instance_valid(player_instance) and player_instance.has_method("fire_extra_attack"):
			player_instance.fire_extra_attack(damage_multiplier)
	)


func reset_player_attr() -> void:
	# 清除所有buff/debuff（燃烧、冰冻等战斗debuff不会残留到城镇）
	BuffManager.clear_all_buffs()
	if LvUp and LvUp.has_method("reset_battle_reward_state"):
		LvUp.reset_battle_reward_state()

	# 重置权重
	if PlayerRewardWeights:
		PlayerRewardWeights.reset_all_weights()

	# 初始化一系列单局内会发生变化的变量
	Global.in_menu = false
	PC.is_game_over = false
	if Global.active_skill_manager and Global.active_skill_manager.has_method("reset_battle_state"):
		Global.active_skill_manager.reset_battle_state()
	
	Global.reset_battle_modifiers()
	
	exec_pc_atk()
	exec_pc_hp()
	exec_pc_attack_range()
	exec_lucky_level()
	
	# 根据已学习的技能初始化剑气等级和伤害
	exec_swordqi_skills()

	PC.real_time = 0
	PC.current_time = 0
	
	PC.pc_lv = 1
	PC.pc_exp = 0
	PC.move_speed_bonus = 0 # 修炼追风加成在移速公式中单独计算，此处不重复叠加
	# 修习树团队篇：攻速百分比加成
	PC.attack_speed_bonus = 0 + (Global.cultivation_liuguang_level * 0.008) + Global.study_atk_speed_bonus # 流光提升攻速，每级+0.8%
	PC.pc_sheild = []

	PC.current_weapon_num = 0
	PC.new_weapon_obtained_count = 0 # 重置新获得武器计数

	PC.invincible = false
	
	PC.ring_bullet_enabled = false
	PC.ring_bullet_count = 8
	PC.ring_bullet_size_multiplier = 0.9
	PC.ring_bullet_damage_multiplier = 0.7
	PC.ring_bullet_interval = 2.5
	PC.ring_bullet_last_shot_time = 0.0

	# 初始化浪形子弹冷却与时间
	PC.wave_bullet_enabled = false
	PC.wave_bullet_count = 8
	PC.wave_bullet_damage_multiplier = 0.5
	PC.wave_bullet_interval = 4.0
	PC.wave_bullet_last_shot_time = 0.0
	
	# 重置反弹子弹相关属性
	PC.rebound_size_multiplier = 0.9
	PC.rebound_damage_multiplier = 0.35
	
	PC.summon_count = 0
	PC.summon_count_max = 3
	PC.summon_damage_multiplier = 0.0
	PC.summon_interval_multiplier = 1.0
	PC.summon_bullet_size_multiplier = 1.0
	PC.summon_range_multiplier = 1.0
	PC.summon_penetration_count = 0
	
	# 重置暴击相关属性
	# 修习树团队篇：暴击率加成
	PC.crit_chance = 0.1 + (Global.cultivation_fengrui_level * 0.004) + Global.study_crit_rate_bonus # 基础暴击率 + 局外成长
	# 修习树团队篇：暴击伤害加成
	PC.crit_damage_multi = 1.5 + (Global.cultivation_liejin_level * 0.016) + Global.study_crit_damage_bonus # 基础暴击伤害倍率 + 局外成长
	
	# 修习树团队篇：减伤率加成
	PC.damage_reduction_rate = min(0.0 + (Global.cultivation_huti_level * 0.002) + Global.study_damage_reduction_bonus, 0.7) # 基础减伤率 + 局外成长，最高70%
	PC.clear_independent_damage_reduction_sources()
	PC.damage_deal_multiplier = 1.0
	PC.final_damage_bonus = Global.get_cultivation_final_damage_bonus()
	var achievement_bonus := _get_achievement_bonus_summary()
	PC.final_damage_bonus += float(achievement_bonus.get("final_damage", 0.0))
	PC.wind_huanfeng_stacks = 0
	PC.wind_huanfeng_max_stacks = 0
	PC.wind_huanfeng_duration = 12.0
	PC.sixsense_bonus_multiplier = 1.0
	PC.sixsense_base_crit_chance = 0.0
	PC.sixsense_base_crit_damage_multi = 0.0
	PC.sixsense_base_final_damage = 0.0
	PC.sixsense_base_atk_speed = 0.0
	PC.sixsense_base_damage_reduction = 0.0
	PC.sixsense_base_atk = 0.0
	PC.sixsense_applied_crit_chance = 0.0
	PC.sixsense_applied_crit_damage_multi = 0.0
	PC.sixsense_applied_final_damage = 0.0
	PC.sixsense_applied_atk_speed = 0.0
	PC.sixsense_applied_damage_reduction = 0.0
	PC.sixsense_applied_atk = 0.0
	# 修习树团队篇：真气获取率百分比加成
	PC.point_multi = 0 + (Global.cultivation_hualing_level * 0.02) + Global.study_qi_gain_bonus + float(achievement_bonus.get("point", 0.0))
	var equipment_stats = Global.equipment_manager.calculate_total_equipment_stats()
	PC.spirit_multi = equipment_stats.get("spirit_multi", 0.0) + float(achievement_bonus.get("spirit", 0.0))
	PC.exp_multi = Global.exp_multi + Global.study_exp_bonus + float(achievement_bonus.get("exp", 0.0)) # 修习树领悟篇：经验获取提升
	# 修习树团队篇：掉落率百分比加成
	PC.drop_multi = Global.drop_multi + Global.study_drop_rate_bonus + float(achievement_bonus.get("drop", 0.0))
	PC.heal_aura_drop_multi = 0.0
	PC.body_size = Global.body_size
	PC.set_attack_range_value(Global.attack_range)
	PC.knockback_bonus = 0.0
	PC.heal_multi = Global.heal_multi
	PC.bloodwave_dynamic_heal_bonus = 0.0
	PC.sheild_multi = Global.sheild_multi
	PC.normal_monster_multi = Global.normal_monster_multi
	PC.boss_multi = Global.boss_multi
	PC.cooldown = Global.cooldown
	PC.active_skill_multi = Global.active_skill_multi + float(achievement_bonus.get("active_skill", 0.0))
	PC.enemy_move_speed_multiplier = 1.0 # 重置敌人移速倍率
	PC.enemy_hp_multiplier = 1.0 # 重置敌人体力倍率
	PC.enemy_damage_multiplier = 1.0 # 重置敌人伤害倍率
	PC.total_distance_moved = 0.0 # 重置移动距离
	PC.distance_buff_offsets.clear() # 重置移动距离buff偏移
	PC.xianqi_points = 0 # 重置仙气凝聚层数
	PC.xianli_active = false # 重置仙力护体状态
	PC.xianqi_final_damage_applied_bonus = 0.0
	PC.xianqi_hp_applied_bonus = 0.0
	PC.xuji_remaining = 0 # 重置蓄积剩余次数
	PC.bleed_damage_multi = 0.0 # 重置流血伤害加成
	PC.electrification_damage_multi = 0.0 # 重置感电伤害加成
	PC.fire_damage_multi = 0.0 # 重置炙烧伤害加成
	PC.debuff_cross_damage_multi = 0.0 # 重置异常交叉伤害加成
	PC.pc_armor = float(achievement_bonus.get("armor", 0.0)) # 重置护甲
	PC.pc_hp_regen = 0.0 # 重置生命恢复
	PC.hp_regen_interval = 5.0 # 重置生命恢复间隔
	PC.hp_regen_timer = 0.0 # 重置生命恢复计时器
	PC.spirit = 0
	PC.spirit_raw = 0.0
	PC.spirit_armor_applied_bonus = 0.0
	PC.spirit_final_damage_applied_bonus = 0.0
	PC.emblem_awakening_final_damage_applied_bonus = 0.0
	PC.emblem_awakening_damage_reduction_applied_bonus = 0.0
	PC.pain_relief_active = false
	PC.pain_relief_remaining_heal = 0.0
	PC.pain_relief_tick_accumulator = 0.0
	PC.pain_relief_remaining_time = 0.0
	# 重置领悟系列属性
	PC.lingwu_atk_flat_bonus = 0
	PC.lingwu_atk_bonus = 0.0
	PC.lingwu_hp_bonus = 0.0
	PC.lingwu_atk_speed_bonus = 0.0
	PC.lingwu_speed_bonus = 0.0
	PC.lingwu_final_dmg_bonus = 0.0
	PC.lingwu_armor_bonus = 0.0
	PC.lingwu_weapon_upgrade_bonus = 0.0
	PC.lingwu_lucky_upgrade_bonus = 0.0
	PC.lingwu_summon_upgrade_bonus = 0.0
	PC.lingwu_live_upgrade_bonus = 0.0
	PC.weapon_upgrade_law_bonus_rates.clear()
	PC.weapon_upgrade_law_decay_counts.clear()
	PC.last_atk_speed = 0
	PC.last_speed = 0
	PC.last_lunky_level = 1
	PC.battle_start_lunky_level = PC.now_lunky_level
	PC.battle_start_atk_speed = PC.attack_speed_bonus
	
	PC.faze_blood_level = 0
	PC.faze_sword_level = 0
	PC.faze_thunder_level = 0
	PC.faze_heal_level = 0
	PC.faze_summon_level = 0
	PC.faze_shield_level = 0
	PC.faze_fire_level = 0
	PC.faze_destroy_level = 0
	PC.faze_life_level = 0
	PC.faze_bullet_level = 0
	PC.faze_wide_level = 0
	PC.faze_bagua_level = 0
	PC.faze_treasure_level = 0
	PC.faze_deep_level = 0
	PC.faze_shehun_level = 0
	PC.faze_chaos_level = 0
	PC.faze_skill_level = 0
	PC.faze_sixsense_level = 0
	PC.faze_wind_level = 0
	PC.sixsense_bonus_multiplier = 1.0
	PC.sixsense_base_crit_chance = 0.0
	PC.sixsense_base_crit_damage_multi = 0.0
	PC.sixsense_base_final_damage = 0.0
	PC.sixsense_base_atk_speed = 0.0
	PC.sixsense_base_damage_reduction = 0.0
	PC.sixsense_base_atk = 0.0
	PC.sixsense_applied_crit_chance = 0.0
	PC.sixsense_applied_crit_damage_multi = 0.0
	PC.sixsense_applied_final_damage = 0.0
	PC.sixsense_applied_atk_speed = 0.0
	PC.sixsense_applied_damage_reduction = 0.0
	PC.sixsense_applied_atk = 0.0
	PC.faze_bagua_progress = 0
	PC.faze_bagua_completed_layers = 0
	PC.faze_bagua_next_threshold = 100
	PC.faze_bagua_damage_bonus = 0.0
	PC.faze_bagua_gain_multiplier = 1.0
	
	PC.faze_wide_range_bonus = 0.0
	PC.faze_wide_damage_bonus = 0.0
	PC.faze_wide_range_to_damage_ratio = 0.0
	PC.faze_wide_global_attack_range_bonus = 0.0
	
	PC.faze_sword_coldlight_stack = 0
	
	PC.faze_heal_shield_bonus = 0.0
	PC.shehun_law_spirit_multi_bonus = 0.0
	PC.shehun_law_crit_chance_bonus = 0.0
	PC.shehun_law_final_damage_bonus = 0.0
	PC.shehun_law_damage_reduction_bonus = 0.0
	PC.shehun_law_spirit_next_threshold = 4000.0
	PC.shehun_law_spirit_spent = 0.0
	PC.has_summoned_bipolar_sword = false
	PC.has_summoned_sword_spirit = false
	# 重置主要技能等级
	PC.main_skill_swordQi = 0
	PC.main_skill_swordQi_advance = 0
	PC.main_skill_swordQi_damage = 1
	PC.swordQi_penetration_count = 1
	PC.swordQi_other_sword_wave_damage = 0.3
	PC.swordQi_range = 132
	PC.first_has_swordqi = true
	
	# 重置魔焰相关属性
	PC.main_skill_moyan = 0
	PC.main_skill_moyan_advance = 0
	PC.first_has_moyan = true
	PC.main_skill_moyan_damage = 1.6
	PC.moyan_range = 220.0
	
	# 重置树枝相关属性
	PC.main_skill_branch = 0
	PC.main_skill_branch_advance = 0
	PC.first_has_branch = true
	PC.main_skill_branch_damage = 1
	PC.branch_split_count = 3
	PC.branch_range = 90
	
	# 重置日炎相关属性
	PC.main_skill_riyan = 0
	PC.main_skill_riyan_advance = 0
	PC.main_skill_riyan_damage = 1
	PC.first_has_riyan = true
	PC.first_has_riyan_pc = true
	PC.riyan_range = 84.0
	PC.riyan_cooldown = 1.0
	PC.riyan_hp_max_damage = 0.08
	PC.riyan_atk_damage = 0.30
	
	# 重置环火相关属性
	PC.main_skill_ringFire = 0
	PC.main_skill_ringFire_advance = 0
	PC.main_skill_ringFire_damage = 0.15
	PC.first_has_ringFire = true
	
	# 重置雷光相关属性
	PC.main_skill_thunder = 0
	PC.main_skill_thunder_advance = 0
	PC.main_skill_thunder_damage = 0.75
	PC.first_has_thunder = true
	PC.thunder_range = 260.0
	
	# 重置血气波相关属性
	PC.main_skill_bloodwave = 0
	PC.main_skill_bloodwave_advance = 0
	PC.first_has_bloodwave = true
	
	PC.main_skill_bloodboardsword = 0
	PC.main_skill_bloodboardsword_advance = 0
	PC.main_skill_bloodboardsword_damage = 0.95
	PC.first_has_bloodboardsword = true
	
	# 重置冰刺术相关属性
	PC.main_skill_ice = 0
	PC.main_skill_ice_advance = 0
	PC.first_has_ice = true
	
	# 重置天雷破相关属性
	PC.main_skill_thunder_break = 0
	PC.main_skill_thunder_break_advance = 0
	PC.first_has_thunder_break = true
	PC.main_skill_thunder_break_damage = 0.65
	PC.thunder_break_final_damage_multi = 1.0
	
	# 重置光弹术相关属性
	PC.main_skill_light_bullet = 0
	PC.main_skill_light_bullet_advance = 0
	PC.first_has_light_bullet = true
	PC.main_skill_light_bullet_damage = 0.45
	PC.light_bullet_final_damage_multi = 1.0
	
	# 重置坎水诀相关属性
	PC.main_skill_water = 0
	PC.main_skill_water_advance = 0
	PC.first_has_water = true
	PC.main_skill_water_damage = 0.35
	PC.water_final_damage_multi = 1.0
	
	# 重置乾坤双剑相关属性
	PC.main_skill_qiankun = 0
	PC.main_skill_qiankun_advance = 0
	PC.first_has_qiankun = true
	
	# 重置玄武盾相关属性
	PC.main_skill_xuanwu = 0
	PC.main_skill_xuanwu_advance = 0
	PC.first_has_xuanwu = true
	
	# 重置巽风诀相关属性
	PC.main_skill_xunfeng = 0
	PC.main_skill_xunfeng_advance = 0
	PC.first_has_xunfeng = true
	
	# 重置风龙杖相关属性
	PC.main_skill_dragonwind = 0
	PC.main_skill_dragonwind_advance = 0
	PC.main_skill_dragonwind_damage = 1.0
	PC.first_has_dragonwind = true
	
	# 重置艮山诀相关属性
	PC.main_skill_genshan = 0
	PC.main_skill_genshan_advance = 0
	PC.first_has_genshan = true
	
	# 重置兑泽诀相关属性
	PC.main_skill_duize = 0
	PC.main_skill_duize_advance = 0
	PC.first_has_duize = true
	
	# 重置圣光术相关属性
	PC.main_skill_holylight = 0
	PC.main_skill_holylight_advance = 0
	PC.first_has_holylight = true
	
	# 重置气功波相关属性
	PC.main_skill_qigong = 0
	PC.main_skill_qigong_advance = 0
	PC.first_has_qigong = true
	PC.main_skill_qigong_damage = 0.0
	PC.main_skill_zhuazhuajuchui = 0
	PC.main_skill_zhuazhuajuchui_advance = 0
	PC.first_has_zhuazhuajuchui = true
	ZHUAZHUAJUCHUI_SCRIPT.reset_data()
	PC.main_skill_soul_sickle = 0
	PC.main_skill_soul_sickle_advance = 0
	PC.main_skill_soul_sickle_damage = 0.30
	PC.first_has_soul_sickle = true
	PC.main_skill_thunder_gun = 0
	PC.main_skill_thunder_gun_advance = 0
	PC.main_skill_thunder_gun_damage = 0.65
	PC.first_has_thunder_gun = true
	PC.thunder_gun_ammo = 0
	PC.thunder_gun_reloading = false
	PC.main_skill_yujian = 0
	PC.main_skill_yujian_advance = 0
	PC.first_has_yujian = true
	PC.yujian_move_summon_damage_per_10 = 0.0
	PC.yujian_move_summon_damage_cap = 0.0
	PC.yujian_level_summon_damage_per_level = 0.0
	PC.yujian_applied_summon_damage_bonus = 0.0
	PC.yujian_interval_reduction_per_level = 0.0
	PC.yujian_applied_interval_multiplier = 1.0
	
	PC.refresh_num = Global.get_initial_refresh_num()
	PC.lock_num = Global.get_initial_lock_num()
	PC.ban_num = Global.get_initial_ban_num()
	PC.banned_lingwu_series.clear()
	
	# 重置纹章系统
	PC.current_emblems.clear()
	PC.jinghong_attack_count = 0
	PC.xueqi_last_trigger_time = -99999.0
	EmblemManager.clear_all_emblems()
	
	# todo 测试武器升级
	PC.selected_rewards = []
	
	# 非诗想难度清除备战配置，诗想难度由_apply_poetry_init恢复
	if Global.current_stage_difficulty != Global.STAGE_DIFFICULTY_POETRY:
		PC.poetry_loadout = {}

	# 诗想难度下不添加角色默认武器（由poetry_loadout统一管理），非诗想难度才添加
	if Global.current_stage_difficulty != Global.STAGE_DIFFICULTY_POETRY:
		PC._grant_start_weapon(Global.get_selected_start_weapon())
	

func add_shield(amount: int, duration: float, source_id: String = "unknown") -> void:
	if is_game_over:
		return
	var shield_bonus = 1.0 + PC.sheild_multi
	var final_amount = int(ceil(float(amount) * shield_bonus * Global.get_heal_shield_effect_multiplier()))
	if final_amount <= 0:
		return
	var shield = {"value": final_amount, "time_left": duration}
	pc_sheild.append(shield)
	Global.record_heal_shield_for_stats("shield", float(final_amount), source_id)
	_scan_achievement_runtime_keys(["shield_ratio"])

func update_shields(delta: float) -> void:
	if Global.is_battle_time_paused():
		return
	for i in range(pc_sheild.size()):
		var shield = pc_sheild[i]
		shield["time_left"] = float(shield["time_left"]) - delta
		pc_sheild[i] = shield
	_remove_empty_shields()

func get_total_shield() -> int:
	var total = 0
	for shield in pc_sheild:
		total += int(shield["value"])
	return total

func player_hit(damage: int, attacker: Node2D = null, source_name: String = "未知") -> int:
	if is_game_over or invincible:
		return 0
	damage = _apply_incoming_damage_variance(damage)
	if Global.is_poetry_boss_damage_source(attacker):
		damage = int(ceil(float(damage) * Global.get_poetry_boss_damage_multiplier()))
	elif Global.is_boss_damage_source(attacker):
		damage = int(ceil(float(damage) * Global.get_stage_boss_damage_multiplier()))
	# 护甲减伤：armor/(armor+500)
	var armor_reduction = pc_armor / (pc_armor + 500.0) if pc_armor > 0 else 0.0
	damage = int(damage * (1.0 - armor_reduction))
	damage = _apply_independent_damage_reduction(damage)
	damage = _apply_enemy_minimum_damage(damage, source_name)
	if damage < 1:
		damage = 1
	var remaining_damage = damage
	var absorbed_damage = 0
	
	if pc_sheild.size() > 0:
		pc_sheild.sort_custom(func(a, b): return a["time_left"] < b["time_left"])
		for i in range(pc_sheild.size()):
			if remaining_damage <= 0:
				break
			var shield = pc_sheild[i]
			var shield_value = int(shield["value"])
			if shield_value > remaining_damage:
				shield["value"] = shield_value - remaining_damage
				absorbed_damage += remaining_damage
				remaining_damage = 0
				pc_sheild[i] = shield
			else:
				absorbed_damage += shield_value
				remaining_damage -= shield_value
				shield["value"] = 0
				pc_sheild[i] = shield
		_remove_empty_shields()
	if remaining_damage > 0:
		pc_hp -= remaining_damage
		
	if player_instance:
		Global.emit_signal("player_hit", float(remaining_damage), float(absorbed_damage), attacker, player_instance.global_position, source_name)
		
	# 集中致死判断
	if pc_hp <= 0:
		player_instance.game_over()
		
	return remaining_damage

## 无视无敌状态的伤害（用于DOT、燃烧等不应触发无敌的伤害）
func player_hit_ignore_invincible(damage: int, attacker: Node2D = null, source_name: String = "未知") -> int:
	if is_game_over:
		return 0
	damage = _apply_incoming_damage_variance(damage)
	if Global.is_poetry_boss_damage_source(attacker):
		damage = int(ceil(float(damage) * Global.get_poetry_boss_damage_multiplier()))
	elif Global.is_boss_damage_source(attacker):
		damage = int(ceil(float(damage) * Global.get_stage_boss_damage_multiplier()))
	# 护甲减伤：armor/(armor+500)
	var armor_reduction = pc_armor / (pc_armor + 500.0) if pc_armor > 0 else 0.0
	damage = int(damage * (1.0 - armor_reduction))
	damage = _apply_independent_damage_reduction(damage)
	damage = _apply_enemy_minimum_damage(damage, source_name)
	if damage < 1:
		damage = 1
	var remaining_damage = damage
	var absorbed_damage = 0
	
	# 护盾吸收（同player_hit）
	if pc_sheild.size() > 0:
		pc_sheild.sort_custom(func(a, b): return a["time_left"] < b["time_left"])
		for i in range(pc_sheild.size()):
			if remaining_damage <= 0:
				break
			var shield = pc_sheild[i]
			var shield_value = int(shield["value"])
			if shield_value > remaining_damage:
				shield["value"] = shield_value - remaining_damage
				absorbed_damage += remaining_damage
				remaining_damage = 0
				pc_sheild[i] = shield
			else:
				absorbed_damage += shield_value
				remaining_damage -= shield_value
				shield["value"] = 0
				pc_sheild[i] = shield
		_remove_empty_shields()
	if remaining_damage > 0:
		pc_hp -= remaining_damage
	
	if player_instance:
		Global.emit_signal("player_hit_ignore_invincible", float(remaining_damage), float(absorbed_damage), attacker, player_instance.global_position, source_name)
	
	# 集中致死判断
	if pc_hp <= 0:
		player_instance.game_over()
	
	return remaining_damage

func _apply_incoming_damage_variance(damage: int) -> int:
	if damage <= 0:
		return damage
	return max(1, int(round(float(damage) * randf_range(INCOMING_DAMAGE_VARIANCE_MIN, INCOMING_DAMAGE_VARIANCE_MAX))))

func _apply_enemy_minimum_damage(damage: int, source_name: String) -> int:
	if damage <= 0:
		return damage
	if _should_skip_enemy_minimum_damage(source_name):
		return damage
	var armor_reduction = pc_armor / (pc_armor + 500.0) if pc_armor > 0 else 0.0
	var minimum_damage := int(ceil(
		float(pc_max_hp)
		* ENEMY_MIN_DAMAGE_PLAYER_HP_RATIO
		* (1.0 - clampf(damage_reduction_rate, 0.0, 0.99))
		* (1.0 - armor_reduction)
		* clampf(independent_damage_reduction_multiplier, 0.0, 1.0)
	))
	return maxi(damage, minimum_damage)

func _should_skip_enemy_minimum_damage(source_name: String) -> bool:
	return MIN_DAMAGE_EXCLUDED_SOURCES.has(source_name)

func _apply_independent_damage_reduction(damage: int) -> int:
	if independent_damage_reduction_multiplier >= 0.999:
		return damage
	return int(ceil(float(damage) * clampf(independent_damage_reduction_multiplier, 0.0, 1.0)))

func add_independent_damage_reduction_source(source_id: String, multiplier: float) -> void:
	if source_id.is_empty():
		return
	independent_damage_reduction_sources[source_id] = clampf(multiplier, 0.0, 1.0)
	_refresh_independent_damage_reduction_multiplier()

func remove_independent_damage_reduction_source(source_id: String) -> void:
	independent_damage_reduction_sources.erase(source_id)
	_refresh_independent_damage_reduction_multiplier()

func clear_independent_damage_reduction_sources() -> void:
	independent_damage_reduction_sources.clear()
	independent_damage_reduction_multiplier = 1.0

func _refresh_independent_damage_reduction_multiplier() -> void:
	var multiplier := 1.0
	for value in independent_damage_reduction_sources.values():
		multiplier = minf(multiplier, float(value))
	independent_damage_reduction_multiplier = multiplier

## 无视无敌状态的秒杀（用于核爆/玄冰等Buff不匹配时的即死判定）
func player_instakill(attacker: Node2D = null, source_name: String = "未知") -> void:
	if is_game_over:
		return
	pc_hp = 0
	if player_instance:
		Global.emit_signal("player_instakill", attacker, player_instance.global_position, source_name)
		player_instance.game_over()

func _remove_empty_shields() -> void:
	var remain: Array[Dictionary] = []
	for shield in pc_sheild:
		if int(shield["value"]) > 0 and float(shield["time_left"]) > 0:
			remain.append(shield)
		elif float(shield["time_left"]) <= 0 and int(shield["value"]) > 0:
			# Shield expired, check for heal conversion (Shield Law)
			if faze_shield_heal_conversion_ratio > 0.0 and not is_game_over:
				var heal_amount = int(ceil(float(int(shield["value"])) * faze_shield_heal_conversion_ratio * Global.get_heal_shield_effect_multiplier()))
				if heal_amount > 0:
					pc_hp += heal_amount
					if pc_hp > pc_max_hp:
						pc_hp = pc_max_hp
					if player_instance:
						Global.emit_signal("player_healed", heal_amount)
	pc_sheild = remain

	
func exec_pc_atk() -> void:
	# 修习树团队篇：攻击力百分比加成
	var achievement_bonus := _get_achievement_bonus_summary()
	PC.pc_atk = int((25 + int(Global.cultivation_poxu_level * 2) + int(round(float(achievement_bonus.get("atk", 0.0))))) * (1.0 + Global.study_atk_bonus))
	PC.base_atk = PC.pc_atk
	
func exec_pc_hp() -> void:
	# 修习树团队篇：HP绝对值加成
	var achievement_bonus := _get_achievement_bonus_summary()
	PC.pc_max_hp = int(500 + int(Global.cultivation_xuanyuan_level * 20) + int(round(float(achievement_bonus.get("hp", 0.0))))) + Global.study_hp_bonus
	PC.pc_start_max_hp = PC.pc_max_hp
	PC.pc_hp = PC.pc_max_hp

func _get_achievement_bonus_summary() -> Dictionary:
	var summary := {}
	var achievement_manager = get_node_or_null("/root/AchievementManager")
	if achievement_manager != null and achievement_manager.has_method("get_bonus_summary"):
		summary = achievement_manager.get_bonus_summary().duplicate(true)
	var guide_manager = get_node_or_null("/root/GuideManager")
	if guide_manager != null and guide_manager.has_method("get_bonus_summary"):
		var guide_summary: Dictionary = guide_manager.get_bonus_summary()
		for key in guide_summary.keys():
			summary[key] = float(summary.get(key, 0.0)) + float(guide_summary[key])
	return summary
	
func exec_pc_attack_range() -> void:
	set_attack_range_value(Global.attack_range)

func set_attack_range_value(value: float) -> void:
	attack_range = max(0.01, value)

func add_attack_range(delta: float) -> void:
	set_attack_range_value(attack_range + delta)

func exec_lucky_level() -> void:
	PC.now_lunky_level = Global.lunky_level + Global.study_initial_lucky + Global.get_achievement_initial_lucky_bonus()
	_recalculate_reward_rarity_chances()
	# 修习树领悟篇：纹章栏位增加
	PC.emblem_slots_max = 4 + Global.study_emblem_slots_bonus

func get_lucky_level() -> int:
	return now_lunky_level

func _recalculate_reward_rarity_chances() -> void:
	now_red_p = Global.red_p + float(now_lunky_level) * RED_CHANCE_PER_LUCKY + Global.study_red_chance_bonus
	now_gold_p = Global.gold_p + float(now_lunky_level) * GOLD_CHANCE_PER_LUCKY + Global.study_gold_chance_bonus
	now_darkorchid_p = Global.darkorchid_p + float(now_lunky_level) * DARKORCHID_CHANCE_PER_LUCKY + Global.study_purple_chance_bonus
	now_red_p = clampf(now_red_p, 0.0, 100.0)
	now_gold_p = clampf(now_gold_p, 0.0, 100.0 - now_red_p)
	now_darkorchid_p = clampf(now_darkorchid_p, 0.0, 100.0 - now_red_p - now_gold_p)
	now_blue_p = maxf(0.0, 100.0 - now_red_p - now_gold_p - now_darkorchid_p)

func exec_swordqi_skills() -> void:
	# 根据已学习的技能初始化剑气等级和伤害
	if Global.player_study_data.has("yiqiu"):
		var learned_skills = Global.player_study_data["yiqiu"].get("learned_skills", [])
		
		# 检查剑气初始强化技能
		if learned_skills.has("up4_1"):
			PC.main_skill_swordQi += 1
		if learned_skills.has("up4_2"):
			PC.main_skill_swordQi += 1
		
		# 检查剑气伤害提升技能
		if learned_skills.has("up41_1"):
			PC.main_skill_swordQi_damage += 0.06
		if learned_skills.has("up41_2"):
			PC.main_skill_swordQi_damage += 0.06
		if learned_skills.has("up41_3"):
			PC.main_skill_swordQi_damage += 0.06

# 角色数据配置 - 用于背包界面显示
var character_data = {
	"yiqiu": {
		"display_name": "言秋",
		"animation_path": "res://AssetBundle/Sprites/idle.png",
		"animation_name": "idle"
	},
	"moning": {
		"display_name": "墨宁",
		"animation_path": "res://AssetBundle/Sprites/idle.png",
		"animation_name": "idle"
	},
	"noam": {
		"display_name": "诺姆",
		"animation_path": "res://AssetBundle/Sprites/idle.png",
		"animation_name": "idle"
	},
	"kansel": {
		"display_name": "坎塞尔",
		"animation_path": "res://AssetBundle/Sprites/idle.png",
		"animation_name": "idle"
	},
	"xueming": {
		"display_name": "雪铭",
		"animation_path": "res://AssetBundle/Sprites/new_character/xueming_idle.png",
		"animation_name": "idle"
	}
}

# 获取角色显示名称
func get_character_display_name(char_name: String = "") -> String:
	if char_name.is_empty():
		char_name = player_name
	if character_data.has(char_name):
		return character_data[char_name].display_name
	return char_name

# 获取角色动画资源路径
func get_character_animation_path(char_name: String = "") -> String:
	if char_name.is_empty():
		char_name = player_name
	if character_data.has(char_name):
		return character_data[char_name].animation_path
	return ""

# 获取角色动画名称
func get_character_animation_name(char_name: String = "") -> String:
	if char_name.is_empty():
		char_name = player_name
	if character_data.has(char_name):
		return character_data[char_name].animation_name
	return "idle"

# 获取角色属性文本（用于背包界面显示）
func get_character_attributes_text() -> String:
	# 计算基础属性值
	var base_atk = int(25 + int(Global.cultivation_poxu_level * 2))
	var base_hp = int(500 + int(Global.cultivation_xuanyuan_level * 20))
	
	# 获取装备加成
	var equipment_stats = Global.equipment_manager.calculate_total_equipment_stats()
	
	# 计算最终属性
	var final_atk = base_atk + equipment_stats["pc_atk"]
	var final_hp = base_hp + equipment_stats["pc_hp"]
	var atk_speed = (Global.cultivation_liuguang_level * 0.008 + equipment_stats["attack_speed_bonus"]) * 100
	var move_speed = (Global.cultivation_zhuifeng_level * 0.008 + equipment_stats["move_speed_bonus"]) * 100
	var damage_reduction = min((Global.cultivation_huti_level * 0.002) + equipment_stats["damage_reduction_rate"], 0.7) * 100
	var crit_rate = (0.1 + Global.cultivation_fengrui_level * 0.004 + equipment_stats["crit_chance"]) * 100
	var crit_damage = (1.5 + Global.cultivation_liejin_level * 0.016 + equipment_stats["crit_damage_multi"]) * 100
	var point_rate = (1 + Global.cultivation_hualing_level * 0.02 + equipment_stats["point_multi"]) * 100
	var spirit_rate = (1 + equipment_stats.get("spirit_multi", 0.0)) * 100
	var exp_rate = (1 + Global.exp_multi + equipment_stats["exp_multi"] + Global.study_exp_bonus) * 100 # 修习树领悟篇：经验获取提升
	var drop_rate = (1 + Global.drop_multi + equipment_stats["drop_multi"]) * 100
	
	# 计算次要属性（用于修为计算）
	var attack_range_val = equipment_stats["attack_range"] * 100
	var body_size_val = Global.body_size * 100 # 秘丹加成
	var heal_multi_val = (Global.heal_multi + equipment_stats.get("heal_multi", 0)) * 100
	var sheild_multi_val = (Global.sheild_multi + equipment_stats.get("sheild_multi", 0)) * 100
	var normal_monster_multi_val = (Global.normal_monster_multi + equipment_stats.get("normal_monster_multi", 0)) * 100
	var boss_multi_val = (Global.boss_multi + equipment_stats.get("boss_multi", 0)) * 100
	var cooldown_val = equipment_stats.get("cooldown", 0) * 100
	var active_skill_multi_val = equipment_stats.get("active_skill_multi", 0) * 100
	
	# 计算修为
	var cultivation_power = _calculate_cultivation_power(
		final_atk, final_hp, atk_speed, move_speed, damage_reduction,
		crit_rate, crit_damage, point_rate, exp_rate, drop_rate,
		attack_range_val, body_size_val, heal_multi_val, sheild_multi_val,
		normal_monster_multi_val, boss_multi_val, cooldown_val, active_skill_multi_val,
		spirit_rate
	)
	
	# 计算期望DPS
	# 攻击*暴击期望*攻速加成*最终伤害*对小怪伤害加成的一半*对精英首领伤害加成的一半
	# 暴击期望 = 1 + crit_chance * (crit_damage_multi - 1)
	var crit_chance_decimal = (0.1 + Global.cultivation_fengrui_level * 0.005 + equipment_stats["crit_chance"])
	var crit_damage_decimal = (1.5 + Global.cultivation_liejin_level * 0.01 + equipment_stats["crit_damage_multi"])
	var crit_expected_multi = 1.0 + crit_chance_decimal * (crit_damage_decimal - 1.0)
	
	# 攻速加成
	var atk_speed_decimal = 1.0 + (Global.cultivation_liuguang_level * 0.01 + equipment_stats["attack_speed_bonus"])
	
	# 最终伤害加成
	var final_damage_decimal = 1.0 + equipment_stats.get("final_damage_bonus", 0.0)
	
	# 对小怪增伤一半（装备+秘丹）
	var normal_monster_bonus_multi = 1.0 + ((equipment_stats.get("normal_monster_multi", 0.0) + Global.normal_monster_multi) * 0.5)
	
	# 对精英首领增伤一半（装备+秘丹）
	var boss_bonus_multi = 1.0 + ((equipment_stats.get("boss_multi", 0.0) + Global.boss_multi) * 0.5)
	
	var expected_dps = float(final_atk) * crit_expected_multi * atk_speed_decimal * final_damage_decimal * normal_monster_bonus_multi * boss_bonus_multi
	
	var attr_text = ""
	# 修为使用金红过渡色和稍大字号显示
	attr_text += _get_cultivation_bbcode(cultivation_power) + "\n"
	# attr_text += "[color=#FF6B6B]期望DPS  %.1f[/color]\n" % expected_dps
	attr_text += "攻击  " + str(final_atk) + "\n"
	attr_text += "体力  " + str(final_hp) + "\n"
	# 护甲值及护甲减伤（公式：armor/(armor+500)）
	var armor_total = PC.pc_armor
	var armor_reduction_pct = armor_total / (armor_total + 500.0) * 100.0 if armor_total > 0 else 0.0
	attr_text += "护甲  " + str(int(armor_total)) + "(%.2f%%)\n" % armor_reduction_pct
	attr_text += "攻击速度  " + _fmt_attr(atk_speed) + "%\n"
	attr_text += "移动速度  " + _fmt_attr(move_speed) + "%\n"
	attr_text += "减伤率  " + _fmt_attr(damage_reduction) + "%\n"
	attr_text += "暴击率  " + _fmt_attr(crit_rate) + "%\n"
	attr_text += "暴击伤害  " + _fmt_attr(crit_damage) + "%"
	
	return attr_text

# 计算修为值
# 公式: 攻击*攻速*暴击期望 + 体力*移动速度*减伤期望 + 各项额外加成
func _calculate_cultivation_power(final_atk: int, final_hp: int, atk_speed: float, move_speed: float,
								   damage_reduction: float, crit_rate: float, crit_damage: float,
								   point_rate: float, exp_rate: float, drop_rate: float,
								   p_attack_range: float = 0, p_body_size: float = 0, p_heal_multi: float = 0, p_sheild_multi: float = 0,
								   p_normal_monster_multi: float = 0, p_boss_multi: float = 0, p_cooldown: float = 0, p_active_skill_multi: float = 0,
								   spirit_rate: float = 100.0) -> int:
	# 攻速实际倍率 = 1 + atk_speed/100
	var atk_speed_multi = 1.0 + atk_speed / 100.0
	# 暴击期望 = 1 + 暴击率 * (暴击伤害倍率 - 1)
	# crit_damage 是百分比形式(如150表示150%)，需要转换为倍率
	var crit_expectation = 1.0 + (crit_rate / 100.0) * (crit_damage / 100.0 - 1.0)
	# 攻击部分 = 攻击 * 攻速 * 暴击期望
	var atk_part = final_atk * 8 * atk_speed_multi * crit_expectation
	
	# 移动速度实际倍率 = 1 + move_speed/100
	var move_speed_multi = 1.0 + move_speed / 100.0
	# 减伤期望 = 1 / (1 - 减伤率)，例如50%减伤可以抗原来200%的伤害
	# damage_reduction 是百分比形式(如50表示50%)
	var damage_reduction_ratio = damage_reduction / 100.0
	var reduction_expectation = 1.0 / max(1.0 - damage_reduction_ratio, 0.1) # 防止除以0
	# 体力部分 = 体力 * 移动速度 * 减伤期望
	var hp_part = final_hp * 5 * move_speed_multi * reduction_expectation
	
	# 真气获取部分直接加入
	var point_part = max(point_rate - 100, 0) * 6
	
	# 经验获取每超出100%的1%加6点
	var exp_bonus = max(exp_rate - 100, 0) * 9
	
	# 掉落率每超出100%的1%加8点
	var drop_bonus = max(drop_rate - 100, 0) * 12
	# 精魄获取每超出100%的1%加6点
	var spirit_bonus = max(spirit_rate - 100, 0) * 6
	
	# === 属性额外加成（不参与乘算） ===
	# 攻速每1%额外加416点修为
	var atk_speed_bonus = atk_speed * 16.0
	# 移动速度每1%额外加16点修为
	var move_speed_bonus = move_speed * 16.0
	# 暴击率每0.5%额外加8点修为（即每1%加16点）
	var crit_rate_bonus = crit_rate * 64.0
	# 暴击伤害在150%基础上，每1%额外加8点修为
	var crit_damage_bonus = max(crit_damage - 150, 0) * 16.0
	# 减伤率每0.1%额外加3点修为（即每1%加30点）
	var damage_reduction_bonus = damage_reduction * 120.0
	
	# === 次要属性额外加成 ===
	# 伤害范围每1%提升16修为
	var attack_range_bonus = p_attack_range * 16.0
	# 体型偏离基础值也视为收益；体型减小丹药降低受击体积，不能扣修为。
	var body_size_bonus = abs(p_body_size) * 4.0
	# 治疗加成每1%提升6修为
	var heal_multi_bonus = p_heal_multi * 6.0
	# 护盾加成每1%提升6修为
	var sheild_multi_bonus = p_sheild_multi * 6.0
	# 对小怪增伤每1%提升8修为
	var normal_monster_bonus = p_normal_monster_multi * 8.0
	# 精英首领增伤每1%提升8修为
	var boss_bonus = p_boss_multi * 8.0
	# 主动技能冷却缩减每1%提升32修为
	var cooldown_bonus = p_cooldown * 32.0
	# 主动技能增伤每1%提升6修为
	var active_skill_bonus = p_active_skill_multi * 6.0
	var progression_power_bonus = _get_study_tree_cultivation_power_bonus() + _get_cultivation_level_power_bonus()
	
	# 总修为
	var total_cultivation = atk_part + hp_part + point_part + exp_bonus + drop_bonus + spirit_bonus \
		+ atk_speed_bonus + move_speed_bonus + crit_rate_bonus + crit_damage_bonus + damage_reduction_bonus \
		+ attack_range_bonus + body_size_bonus + heal_multi_bonus + sheild_multi_bonus \
		+ normal_monster_bonus + boss_bonus + cooldown_bonus + active_skill_bonus \
		+ progression_power_bonus - 2750
	
	return int(total_cultivation)

func _get_study_tree_cultivation_power_bonus() -> int:
	var learned_talent_levels := 0
	for level in Global.player_study_tree.values():
		learned_talent_levels += max(int(level), 0)
	return learned_talent_levels * 50

func _get_cultivation_level_power_bonus() -> int:
	var power_bonus := 0
	var initial_50_max_cultivations := [
		"cultivation_poxu_level",
		"cultivation_xuanyuan_level",
		"cultivation_hualing_level",
		"cultivation_liejin_level"
	]
	var initial_25_max_cultivations := [
		"cultivation_liuguang_level",
		"cultivation_fengrui_level",
		"cultivation_huti_level",
		"cultivation_zhuifeng_level"
	]
	for level_var in initial_50_max_cultivations:
		power_bonus += max(int(Global.get(level_var)), 0) * 5
	for level_var in initial_25_max_cultivations:
		power_bonus += max(int(Global.get(level_var)), 0) * 10
	return power_bonus

# 生成修为的BBCode文本（金红过渡色，稍大字号）
func _get_cultivation_bbcode(cultivation_power: int) -> String:
	# 将修为值转换为字符串
	var power_str = str(cultivation_power)
	var result = "[font_size=28][color=#FFD700]修为 [/color]"
	
	# 为每个字符应用金红渐变色
	# 金色(FFD700)
	var colors = [
		"#FF4500"
	]
	
	var char_count = power_str.length()
	for i in range(char_count):
		# 根据字符位置选择颜色
		var color_index = int(float(i) / float(max(char_count - 1, 1)) * (colors.size() - 1))
		color_index = clamp(color_index, 0, colors.size() - 1)
		result += "[color=" + colors[color_index] + "]" + power_str[i] + "[/color]"
	
	result += "[/font_size]"
	return result

## 格式化属性值：保留一位小数，若正好.0则不显示
func _fmt_attr(val: float) -> String:
	var s = "%.1f" % val
	if s.ends_with(".0"):
		s = s.substr(0, s.length() - 2)
	return s

# 获取次要属性文本（用于背包界面悬停显示）
func get_secondary_attributes_text() -> String:
	# 获取装备加成
	var equipment_stats = Global.equipment_manager.calculate_total_equipment_stats()
	
	# 计算次要属性
	var attack_range_val = (1 + Global.attack_range - 1.0 + equipment_stats["attack_range"]) * 100 # 伤害范围包含秘丹加成
	var point_multi_val = (1 + Global.cultivation_hualing_level * 0.02 + equipment_stats["point_multi"]) * 100
	var spirit_multi_val = (1 + equipment_stats.get("spirit_multi", 0.0)) * 100
	var exp_multi_val = (1 + Global.exp_multi + equipment_stats["exp_multi"]) * 100
	var drop_multi_val = (1 + Global.drop_multi + equipment_stats["drop_multi"]) * 100
	var body_size_val = Global.body_size * 100 # 秘丹加成
	var heal_multi_val = (1 + Global.heal_multi + equipment_stats.get("heal_multi", 0)) * 100
	var sheild_multi_val = (1 + Global.sheild_multi + equipment_stats.get("sheild_multi", 0)) * 100
	var normal_monster_multi_val = (Global.normal_monster_multi + equipment_stats.get("normal_monster_multi", 0)) * 100
	var boss_multi_val = (Global.boss_multi + equipment_stats.get("boss_multi", 0)) * 100
	var cooldown_val = equipment_stats.get("cooldown", 0) * 100
	var active_skill_multi_val = equipment_stats.get("active_skill_multi", 0) * 100
	var achievement_bonus := _get_achievement_bonus_summary()
	var final_damage_val = (
		Global.get_cultivation_final_damage_bonus()
		+ Global.study_final_damage_bonus
		+ float(equipment_stats.get("final_damage_bonus", 0.0))
		+ float(achievement_bonus.get("final_damage", 0.0))
	) * 100
	
	var attr_text = ""
	attr_text += "最终伤害  " + _fmt_attr(final_damage_val) + "%\n"
	attr_text += "伤害范围  " + _fmt_attr(attack_range_val) + "%\n"
	attr_text += "真气获取  " + _fmt_attr(point_multi_val) + "%\n"
	attr_text += "精魄获取  " + _fmt_attr(spirit_multi_val) + "%\n"
	attr_text += "经验获取  " + _fmt_attr(exp_multi_val) + "%\n"
	attr_text += "掉落率  " + _fmt_attr(drop_multi_val) + "%\n"
	attr_text += "体型大小  " + _fmt_attr(body_size_val) + "%\n"
	attr_text += "治疗加成  " + _fmt_attr(heal_multi_val) + "%\n"
	attr_text += "护盾加成  " + _fmt_attr(sheild_multi_val) + "%\n"
	attr_text += "对小怪增伤  " + _fmt_attr(normal_monster_multi_val) + "%\n"
	attr_text += "对精英首领增伤  " + _fmt_attr(boss_multi_val) + "%\n"
	attr_text += "技能冷却缩减  " + _fmt_attr(cooldown_val) + "%\n"
	attr_text += "技能增伤  " + _fmt_attr(active_skill_multi_val) + "%"
	
	return attr_text

## 获取玩家碰撞体信息（用于技能伤害判定，以CollisionShape2D为准）
func get_player_hitbox_info() -> Dictionary:
	if not is_instance_valid(player_instance):
		return {}
	var col_shape = player_instance.get_node_or_null("CollisionShape2D")
	if not col_shape or not col_shape.shape:
		return {}
	var info = {
		"position": col_shape.global_position,
		"shape": col_shape.shape,
		"scale": col_shape.global_scale,
	}
	var shape = col_shape.shape
	if shape is CircleShape2D:
		info["radius"] = shape.radius * max(col_shape.global_scale.x, col_shape.global_scale.y)
		info["type"] = "circle"
	elif shape is RectangleShape2D:
		info["size"] = shape.size * col_shape.global_scale
		info["type"] = "rect"
	else:
		info["type"] = "unknown"
	return info
