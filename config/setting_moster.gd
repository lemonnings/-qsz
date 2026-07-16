extends Node

const DEFAULT_STAGE_ID := "peach_grove"

const STAGE_STAT_BASES := {
	"peach_grove": {"atk": 160.0, "hp": 22.0},
	"ruin": {"atk": 300.0, "hp": 33.0},
	"cave": {"atk": 390.0, "hp": 50.0},
	"forest": {"atk": 480.0, "hp": 72.0},
	"difu": {"atk": 580.0, "hp": 90.0}
}

const MONSTER_STAT_MULTIPLIERS := {
	"slime_blue": {"default_stage": "peach_grove", "atk": 1.0, "hp": 1.0},
	"copper": {"default_stage": "peach_grove", "atk": 1.2, "hp": 1.2},
	"taohua_yao": {"default_stage": "peach_grove", "atk": 160.0 / 140.0, "hp": 30.0 / 27.0},
	"frog": {"default_stage": "peach_grove", "atk": 120.0 / 140.0, "hp": 24.0 / 27.0},
	"paper": {"default_stage": "ruin", "atk": 1.0, "hp": 1.0},
	"lantern": {"default_stage": "ruin", "atk": 350.0 / 360.0, "hp": 45.0 / 50.0},
	"bat": {"default_stage": "ruin", "atk": 320.0 / 360.0, "hp": 41.0 / 50.0},
	"slime_grey": {"default_stage": "ruin", "atk": 1.0, "hp": 1.0},
	"gu_insect": {"default_stage": "ruin", "atk": 1.0, "hp": 3.0},
	"armor_stone": {"default_stage": "cave", "atk": 1.0, "hp": 1.0},
	"ghost": {"default_stage": "cave", "atk": 420.0 / 500.0, "hp": 70.0 / 75.0},
	"stone_man": {"default_stage": "cave", "atk": 1.0, "hp": 80.0 / 75.0},
	"slime_green": {"default_stage": "cave", "atk": 420.0 / 500.0, "hp": 65.0 / 75.0},
	"shen": {"default_stage": "forest", "atk": 1.0, "hp": 1.0},
	"frog_new": {"default_stage": "forest", "atk": 500.0 / 600.0, "hp": 110.0 / 120.0},
	"ball": {"default_stage": "forest", "atk": 550.0 / 600.0, "hp": 1.0},
	"youling": {"default_stage": "difu", "atk": 1.0, "hp": 1.0}
}

const SUMMON_HP_BONUS_BLUE := 0.15
const SUMMON_HP_BONUS_DARKORCHID := 0.30
const SUMMON_HP_BONUS_GOLD := 0.45
const SUMMON_HP_BONUS_RED := 0.60
const SUMMON_HP_BONUS_EFFECT_SCALE := 0.50
const YUJIAN_SUMMON_HP_BONUS_EFFECT_SCALE := 0.75


func _get_current_stage_multiplier() -> float:
	# 当前没有进入正式关卡时，倍率默认回到 1.0。
	# 这样在主城、菜单或直接打开脚本时，不会因为缺少上下文导致数值异常。
	if typeof(Global) == TYPE_NIL:
		return 1.0
	return max(Global.get_current_stage_stat_multiplier(), 1.0)

# 浅层100%、深层120%、核心140%且每层核心进阶额外+10%
func _get_difficulty_point_multiplier() -> float:
	if typeof(Global) == TYPE_NIL:
		return 1.0
	return Global.get_current_stage_qi_gain_multiplier()

func _calc_point(base_point: float) -> float:
	return base_point * 0.1 * _get_difficulty_point_multiplier() * min(((1 + (PC.current_time / 100))), 8) * (1 + (Global.cultivation_hualing_level * 0.03))

func _calc_stage_scaled_value(base_value: float) -> float:
	# 怪物基础值现在只吃“当前关卡难度倍率”。
	# 这样配置更直观，你看到多少基础值，就能直接推算出进图后的结果。
	return base_value * _get_current_stage_multiplier()

func _get_stage_stat_base(stage_id: String, stat_name: String) -> float:
	var resolved_stage_id = stage_id
	if not STAGE_STAT_BASES.has(resolved_stage_id):
		resolved_stage_id = DEFAULT_STAGE_ID
	var stage_data: Dictionary = STAGE_STAT_BASES.get(resolved_stage_id, STAGE_STAT_BASES[DEFAULT_STAGE_ID])
	return float(stage_data.get(stat_name, 1.0))

func _get_stat_stage_id(default_stage_id: String) -> String:
	if typeof(Global) == TYPE_NIL:
		return default_stage_id if STAGE_STAT_BASES.has(default_stage_id) else DEFAULT_STAGE_ID
	var current_stage_id := str(Global.current_stage_id)
	if STAGE_STAT_BASES.has(current_stage_id):
		return current_stage_id
	return default_stage_id if STAGE_STAT_BASES.has(default_stage_id) else DEFAULT_STAGE_ID

func _get_monster_base_stat(monster_id: String, stat_name: String) -> float:
	var monster_data: Dictionary = MONSTER_STAT_MULTIPLIERS.get(monster_id, {})
	var default_stage_id := str(monster_data.get("default_stage", DEFAULT_STAGE_ID))
	var stage_id := _get_stat_stage_id(default_stage_id)
	var stage_base := _get_stage_stat_base(stage_id, stat_name)
	var stat_multiplier := float(monster_data.get(stat_name, 1.0))
	return stage_base * stat_multiplier

func _calc_monster_atk(monster_id: String) -> float:
	return _calc_atk(_get_monster_base_stat(monster_id, "atk"))

func _calc_monster_hp(monster_id: String) -> float:
	return _calc_hp(_get_monster_base_stat(monster_id, "hp"))

func _calc_atk(base_atk: float) -> float:
	var t: float = float(PC.real_time)
	var raw_mult: float = _get_current_stage_multiplier()
	var growth_mult := Global.get_core_attack_growth_multiplier() if typeof(Global) != TYPE_NIL else 1.0
	var base_part: float = base_atk * raw_mult * 0.75
	var time_part: float = (0.3 * t + 0.0015 * t * t) * pow(1.035, PC.pc_lv - 1) * growth_mult
	return (base_part + time_part) * PC.enemy_damage_multiplier

# 计算新武器带来的怪物血量加成
func _get_new_weapon_hp_multiplier() -> float:
	var count = PC.new_weapon_obtained_count
	var multiplier = 1.0
	if count >= 1:
		multiplier *= 1.6
	if count >= 2:
		multiplier *= 1.325
	if count >= 3:
		multiplier *= 1.225
	if count >= 4:
		multiplier *= 1.175
	if count >= 5:
		multiplier *= 1.125
	return multiplier

func _get_same_law_weapon_hp_multiplier() -> float:
	var law_counts: Dictionary = {}
	for faction in PlayerRewardWeights.get_owned_weapon_factions():
		for law in PlayerRewardWeights.get_weapon_upgrade_laws(faction):
			law_counts[law] = int(law_counts.get(law, 0)) + 1

	var highest_count := 0
	for count in law_counts.values():
		highest_count = maxi(highest_count, int(count))

	if highest_count >= 5:
		return 1.1 * 1.15
	if highest_count >= 4:
		return 1.1
	return 1.0

func _get_summon_hp_bonus_multiplier() -> float:
	var summon_bonus := _get_highest_summon_hp_bonus()
	if summon_bonus <= 0.0:
		return 1.0
	summon_bonus *= _get_summon_hp_bonus_effect_scale()
	summon_bonus *= _get_summon_hp_bonus_weapon_count_factor()
	return 1.0 + summon_bonus

func _get_summon_hp_bonus_effect_scale() -> float:
	if PC.selected_rewards.has("Yujian"):
		return YUJIAN_SUMMON_HP_BONUS_EFFECT_SCALE
	return SUMMON_HP_BONUS_EFFECT_SCALE

func _get_highest_summon_hp_bonus() -> float:
	if _has_any_reward([
		"red_summon",
		"red_special_summon",
		"red_heal_summon",
		"red_aux_summon"
	]):
		return SUMMON_HP_BONUS_RED
	if _has_any_reward([
		"gold_summon",
		"gold_heal_summon",
		"gold_aux_summon"
	]):
		return SUMMON_HP_BONUS_GOLD
	if _has_any_reward([
		"darkorchid_summon",
		"darkorchid_heal_summon",
		"darkorchid_aux_summon"
	]):
		return SUMMON_HP_BONUS_DARKORCHID
	if PC.selected_rewards.has("blue_summon"):
		return SUMMON_HP_BONUS_BLUE
	return 0.0

func _has_any_reward(reward_ids: Array[String]) -> bool:
	for reward_id in reward_ids:
		if PC.selected_rewards.has(reward_id):
			return true
	return false

func _get_summon_hp_bonus_weapon_count_factor() -> float:
	var weapon_count := maxi(1, PC.new_weapon_obtained_count)
	if weapon_count >= 5:
		return 0.20
	if weapon_count >= 4:
		return 0.40
	if weapon_count >= 3:
		return 0.60
	if weapon_count >= 2:
		return 0.80
	return 1.0

func _calc_hp(base_hp: float) -> float:
	var t = float(PC.real_time)
	var lv_bonus = pow(1.115, PC.pc_lv - 1) # 玩家每升1级，怪物血量提升
	var new_weapon_bonus = _get_new_weapon_hp_multiplier() # 新武器带来的血量加成
	var same_law_weapon_bonus := _get_same_law_weapon_hp_multiplier()
	var summon_hp_bonus := _get_summon_hp_bonus_multiplier()

	var first_part = base_hp + t / 8.0
	var linear_part = 5.0 * t / 7500.0
	var quadratic_part = t * t / 400000.0
	var second_part = 1.0 + linear_part + quadratic_part

	var first_jump_time = 90.0
	var second_jump_time = 170.0
	var third_jump_time = 250.0
	var fourth_jump_time = 325.0
	var fifth_jump_time = 390.0
	var sixth_jump_time = 450.0

	var first_jump_multiplier = 1.6
	var second_jump_multiplier = 2.4
	var third_jump_multiplier = 3.6
	var fourth_jump_multiplier = 5.4
	var fifth_jump_multiplier = 8
	var sixth_jump_multiplier = 12

	var jump_multiplier = 1.0
	if t < first_jump_time:
		jump_multiplier = 1.0
	elif t < second_jump_time:
		jump_multiplier = first_jump_multiplier
	elif t < third_jump_time:
		jump_multiplier = second_jump_multiplier
	elif t < fourth_jump_time:
		jump_multiplier = third_jump_multiplier
	elif t < fifth_jump_time:
		jump_multiplier = fourth_jump_multiplier
	elif t < sixth_jump_time:
		jump_multiplier = fifth_jump_multiplier
	else:
		jump_multiplier = sixth_jump_multiplier

	return first_part * second_part * jump_multiplier * lv_bonus * new_weapon_bonus * same_law_weapon_bonus * summon_hp_bonus * _get_current_stage_multiplier() * PC.enemy_hp_multiplier


func _finalize_monster_data(data: Dictionary, query: String):
	# 修习树特殊篇：提升治愈灵气和灵髓碎片的掉落概率
	if query == "itemdrop" and data.has("itemdrop"):
		var drops = data["itemdrop"]
		if drops.has("item_001"):
			drops["item_001"] *= Global.get_effective_heal_aura_drop_multiplier()
		if drops.has("item_007") and Global.study_fragment_drop_chance > 0.0:
			drops["item_007"] *= (1.0 + Global.study_fragment_drop_chance)
	return data.get(query, null)

func get_item_drop_rate_multiplier(item_id: String, monster_drop_rate_multiplier: float) -> float:
	if item_id == "item_001":
		return 1.0
	return monster_drop_rate_multiplier

func goldball(query: String):
	var data = {
		"atk": _calc_atk(1),
		"hp": Global.get_current_dps() * 1 + 30,
		"speed": 75,
		"exp": 2500,
		"point": _calc_point(200),
		"mechanism": 10,
		"itemdrop": {"item_007": 1.0}
	}
	return _finalize_monster_data(data, query)

# ============== 关卡1 桃林(PEACH_GROVE) ==============

func slime_blue(query: String): # 蓝色史莱姆 / 普通怪1
	var data = {
		"atk": _calc_monster_atk("slime_blue"),
		"hp": _calc_monster_hp("slime_blue"),
		"speed": 42,
		"exp": 350,
		"point": _calc_point(10),
		"mechanism": 10,
		"itemdrop": {"item_001": 0.01, "item_002": 0.015 * Global.get_effective_drop_multiplier(), "item_009": 0.006 * Global.get_effective_drop_multiplier(), "item_007": 0.01 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func copper(query: String): # 铜兽 / 特殊近战怪
	var exp_value := _get_reference_normal_exp_for_current_stage()
	var data = {
		"atk": _calc_monster_atk("copper"),
		"hp": _calc_monster_hp("copper"),
		"speed": 38,
		"exp": exp_value,
		"point": _get_reference_normal_point_for_current_stage(),
		"mechanism": 10,
		"itemdrop": {}
	}
	return _finalize_monster_data(data, query)

func _get_reference_normal_exp_for_current_stage() -> int:
	match str(Global.current_stage_id):
		"ruin":
			return int(paper("exp"))
		"cave":
			return int(armor_stone("exp"))
		"forest":
			return int(shen("exp"))
		"difu":
			return int(youling("exp"))
		_:
			return int(slime_blue("exp"))

func _get_reference_normal_point_for_current_stage() -> float:
	match str(Global.current_stage_id):
		"ruin":
			return float(paper("point"))
		"cave":
			return float(armor_stone("point"))
		"forest":
			return float(shen("point"))
		"difu":
			return float(youling("point"))
		_:
			return float(slime_blue("point"))

func taohua_yao(query: String): # 桃花妖 / 普通怪2
	var data = {
		"atk": _calc_monster_atk("taohua_yao"),
		"hp": _calc_monster_hp("taohua_yao"),
		"speed": 36,
		"exp": 450,
		"point": _calc_point(15),
		"mechanism": 12,
		"itemdrop": {"item_001": 0.01, "item_003": 0.03 * Global.get_effective_drop_multiplier(), "item_014": 0.01 * Global.get_effective_drop_multiplier(), "item_007": 0.01 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func frog(query: String): # 幼体树精 / 远程怪
	var data = {
		"atk": _calc_monster_atk("frog"),
		"hp": _calc_monster_hp("frog"),
		"speed": 35,
		"exp": 500,
		"point": _calc_point(20),
		"mechanism": 14,
		"itemdrop": {"item_001": 0.01, "item_023": 0.05 * Global.get_effective_drop_multiplier(), "item_010": 0.015 * Global.get_effective_drop_multiplier(), "item_007": 0.01 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

# ============== 关卡2 废墟(RUIN) ==============

func lantern(query: String): # 灯笼怪 / 普通怪2
	var data = {
		"atk": _calc_monster_atk("lantern"),
		"hp": _calc_monster_hp("lantern"),
		"speed": 38,
		"exp": 450,
		"point": _calc_point(14),
		"mechanism": 12,
		"itemdrop": {"item_001": 0.01, "item_011": 0.015 * Global.get_effective_drop_multiplier(), "item_015": 0.006 * Global.get_effective_drop_multiplier(), "item_007": 0.01 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func paper(query: String): # 宣纸精 / 普通怪1
	var data = {
		"atk": _calc_monster_atk("paper"),
		"hp": _calc_monster_hp("paper"),
		"speed": 42,
		"exp": 500,
		"point": _calc_point(13),
		"mechanism": 14,
		"itemdrop": {"item_001": 0.01, "item_011": 0.015 * Global.get_effective_drop_multiplier(), "item_017": 0.006 * Global.get_effective_drop_multiplier(), "item_007": 0.01 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func bat(query: String): # 草药怪 / 远程怪
	var data = {
		"atk": _calc_monster_atk("bat"),
		"hp": _calc_monster_hp("bat"),
		"speed": 36,
		"exp": 600,
		"point": _calc_point(15),
		"mechanism": 16,
		"itemdrop": {"item_001": 0.01, "item_045": 0.05 * Global.get_effective_drop_multiplier(), "item_010": 0.015 * Global.get_effective_drop_multiplier(), "item_007": 0.01 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func slime_grey(query: String): # 灰色史莱姆 / 特殊怪
	var data = {
		"atk": _calc_monster_atk("slime_grey"),
		"hp": _calc_monster_hp("slime_grey"),
		"speed": 36,
		"exp": 550,
		"point": _calc_point(16),
		"mechanism": 16,
		"itemdrop": {"item_001": 0.01, "item_002": 0.05 * Global.get_effective_drop_multiplier(), "item_009": 0.015 * Global.get_effective_drop_multiplier(), "item_007": 0.01 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func gu_insect(query: String): # 蛊虫 / 十字射线怪
	var data = {
		"atk": _calc_monster_atk("gu_insect"),
		"hp": _calc_monster_hp("gu_insect"),
		"speed": 36,
		"exp": _get_reference_normal_exp_for_current_stage() * 3,
		"point": _get_reference_normal_point_for_current_stage(),
		"mechanism": 14,
		"itemdrop": {}
	}
	return _finalize_monster_data(data, query)

# ============== 关卡3 洞窟(CAVE) ==============

func ghost(query: String): # 鬼魂 / 远程怪
	var data = {
		"atk": _calc_monster_atk("ghost"),
		"hp": _calc_monster_hp("ghost"),
		"speed": 30,
		"exp": 500,
		"point": _calc_point(18),
		"mechanism": 12,
		"itemdrop": {"item_001": 0.01, "item_003": 0.02 * Global.get_effective_drop_multiplier(), "item_017": 0.0075 * Global.get_effective_drop_multiplier(), "item_007": 0.01 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func armor_stone(query: String): # 甲石 / 普通怪1
	var data = {
		"atk": _calc_monster_atk("armor_stone"),
		"hp": _calc_monster_hp("armor_stone"),
		"speed": 32,
		"exp": 400,
		"point": _calc_point(19),
		"mechanism": 14,
		"itemdrop": {"item_001": 0.01, "item_044": 0.02 * Global.get_effective_drop_multiplier(), "item_014": 0.0075 * Global.get_effective_drop_multiplier(), "item_007": 0.01 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func stone_man(query: String): # 石人 / 特殊怪
	var data = {
		"atk": _calc_monster_atk("stone_man"),
		"hp": _calc_monster_hp("stone_man"),
		"speed": 28,
		"exp": 550,
		"point": _calc_point(22),
		"mechanism": 16,
		"itemdrop": {"item_001": 0.01, "item_044": 0.05 * Global.get_effective_drop_multiplier(), "item_014": 0.015 * Global.get_effective_drop_multiplier(), "item_007": 0.01 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func slime_green(query: String): # 绿色史莱姆 / 普通怪2
	var data = {
		"atk": _calc_monster_atk("slime_green"),
		"hp": _calc_monster_hp("slime_green"),
		"speed": 42,
		"exp": 550,
		"point": _calc_point(16),
		"mechanism": 16,
		"itemdrop": {"item_001": 0.01, "item_002": 0.05 * Global.get_effective_drop_multiplier(), "item_009": 0.015 * Global.get_effective_drop_multiplier(), "item_007": 0.01 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

# ============== 关卡4 森林(FOREST) ==============

func shen(query: String): # 参精怪 / 普通怪1
	var data = {
		"atk": _calc_monster_atk("shen"),
		"hp": _calc_monster_hp("shen"),
		"speed": 42,
		"exp": 450,
		"point": _calc_point(24),
		"mechanism": 12,
		"itemdrop": {"item_001": 0.01, "item_045": 0.02 * Global.get_effective_drop_multiplier(), "item_015": 0.0075 * Global.get_effective_drop_multiplier(), "item_007": 0.01 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func frog_new(query: String): # 新蛙 / 远程怪
	var data = {
		"atk": _calc_monster_atk("frog_new"),
		"hp": _calc_monster_hp("frog_new"),
		"speed": 35,
		"exp": 600,
		"point": _calc_point(22),
		"mechanism": 14,
		"itemdrop": {"item_001": 0.01, "item_003": 0.02 * Global.get_effective_drop_multiplier(), "item_010": 0.0075 * Global.get_effective_drop_multiplier(), "item_007": 0.01 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)

func ball(query: String): # 弹跳兽 / 特殊怪
	var data = {
		"atk": _calc_monster_atk("ball"),
		"hp": _calc_monster_hp("ball"),
		"speed": 50,
		"exp": 500,
		"point": _calc_point(26),
		"mechanism": 16,
		"itemdrop": {"item_001": 0.01, "item_046": 0.05 * Global.get_effective_drop_multiplier(), "item_010": 0.015 * Global.get_effective_drop_multiplier(), "item_007": 0.01 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)


# ============== 关卡5 九幽冥府(DIFU) ==============

func youling(query: String): # 幽灵 / 地府普通怪
	var data = {
		"atk": _calc_monster_atk("youling"),
		"hp": _calc_monster_hp("youling"),
		"speed": 40,
		"exp": 600,
		"point": _calc_point(26),
		"mechanism": 14,
		"itemdrop": {"item_001": 0.01, "item_007": 0.01 * Global.get_effective_drop_multiplier(), "item_004": 0.002 * Global.get_effective_drop_multiplier()}
	}
	return _finalize_monster_data(data, query)


# ============== Boss通用魔核+凝灵碎片掉落 ==============
# 返回包含5种魔核概率掉落和凝灵碎片固定掉落的itemdrop字典
# 调用方需在此之外额外执行"固定1个随机魔核"的强制掉落
func get_boss_extra_drop() -> Dictionary:
	var difficulty = Global.current_stage_difficulty
	var wlv = max(1, Global.world_level) # 世界等级，从1开始
	var extra_round = max(0, wlv - 1) # 从第二关开始的额外加成轮次

	# 五种魔核ID
	var magic_core_ids = ["item_097", "item_098", "item_099", "item_100", "item_101"]

	# 计算每种魔核的额外掉落概率（扣除固定1个后，剩余期望平分给5种）
	# 浅层期望: 2 + 0.3*extra_round，深层: 2.75 + 0.45*extra_round，核心: 3.5 + 0.6*extra_round
	var total_expected: float
	match difficulty:
		Global.STAGE_DIFFICULTY_DEEP:
			total_expected = 1.75 + 0.35 * extra_round
		Global.STAGE_DIFFICULTY_CORE, Global.STAGE_DIFFICULTY_POETRY:
			total_expected = 3 + 0.45 * extra_round
		_: # shallow
			total_expected = 1 + 0.25 * extra_round

	# 固定掉落1个，剩余期望由5种魔核概率掉落覆盖
	var extra_expected = max(0.0, total_expected - 1.0)
	var each_chance = clampf(extra_expected / 5.0, 0.0, 1.0) * Global.get_effective_drop_multiplier()
	# 修习树特殊篇：boss掉落魔核概率提升
	each_chance *= (1.0 + Global.study_boss_core_drop_chance)

	# 桃林浅层：新手教学关，魔核概率降为50%
	var is_peach_shallow = (difficulty == Global.STAGE_DIFFICULTY_SHALLOW and Global.current_stage_id == "peach_grove")
	# if is_peach_shallow:
	# 	each_chance *= 0.5

	# 凝灵碎片固定数量
	var lingjing_count: int
	if is_peach_shallow:
		lingjing_count = 1
	else:
		match difficulty:
			Global.STAGE_DIFFICULTY_DEEP:
				lingjing_count = 3
			Global.STAGE_DIFFICULTY_CORE, Global.STAGE_DIFFICULTY_POETRY:
				lingjing_count = 4
			_:
				lingjing_count = 2

	var drop_table: Dictionary = {}
	for core_id in magic_core_ids:
		drop_table[core_id] = {"chance": each_chance, "quantity": 1}
	# 凝灵碎片固定掉落（chance=2.0保证必定触发）
	drop_table["item_102"] = {"chance": 2.0, "quantity": lingjing_count}
	return drop_table
