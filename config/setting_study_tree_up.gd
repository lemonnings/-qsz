extends Node
class_name SettingStudyTreeUp

# ============================================================
# 修习树（武器篇）效果实现
# 根据 Global.player_study_tree 中已点亮的节点等级，
# 刷新 Global 上对应的伤害加成 / 武器解锁标记。
# 调用时机：读档后、每次修习成功后。
# ============================================================

# ---------- 武器标签 → 所属分类列表 ----------
# "main"       = 主武器层 (swordqi, light_bullet, ice, qigong)
# "sword"      = 刀剑系      "fire"     = 炽炎系(子类)
# "projectile" = 弹道系      "protect"  = 护佑系(子类)
# "wind"       = 啸风系      "thunder"  = 鸣雷系(子类)
# "wide"       = 广域系      "bagua"    = 八卦系(子类)
# "life"       = 生灵系      "heal"     = 治愈系(子类)
# "destroy"    = 破坏系      "treasure" = 宝器系(子类)      "deep" = 沉渊系

const WEAPON_CATEGORY_MAP: Dictionary = {
	# 四个角色基础武器（受主武器强化影响）
	"swordqi": ["main", "sword"],
	"light_bullet": ["main", "projectile"],
	"ice": ["main", "destroy"],
	"qigong": ["main", "wide"],
	# 刀剑系
	"qiankun": ["sword", "bagua"],
	# 刀剑系 > 炽炎系
	"moyan": ["sword", "fire"],
	"riyan": ["sword", "fire", "wide"],
	"ringfire": ["sword", "fire", "bagua"],
	"baoyan": ["sword", "fire"],
	# 弹道系 > 护佑系
	"genshan": ["projectile", "protect", "bagua"],
	# 啸风系
	"xunfeng": ["wind", "bagua"],
	"dragonwind": ["wind"],
	# 啸风系 > 鸣雷系
	"thunder": ["wind", "thunder", "bagua"],
	"thunder_break": ["wind", "thunder"],
	# 广域系
	"bloodwave": ["wide"],
	"bloodboardsword": ["wide"],
	# 广域系 > 八卦系
	"duize": ["wide", "bagua"],
	# 生灵系
	"water": ["life", "bagua"],
	# 生灵系 > 治愈系
	"holylight": ["life", "heal"],
	# 破坏系 > 宝器系
	"branch": ["destroy", "treasure"],
	"xuanwu": ["destroy", "treasure"],
	# 沉渊系
	"zhuazhuajuchui": ["deep"],
	"handizhang": ["deep"],
	"shihunlian": ["deep"],
	"faze_deep": ["deep"],
	# ---- 别名映射：take_damage(damage_type) 与 WEAPON_CATEGORY_MAP key 不一致的武器 ----
	"ice_flower": ["main", "destroy"], # ice_flower.gd 使用 "ice_flower"，等同 "ice"
	"blood_wave": ["wide"], # blood_wave.gd 使用 "blood_wave"，等同 "bloodwave"
	"blood_broadsword": ["wide"], # blood_broadsword.gd 使用 "blood_broadsword"，等同 "bloodboardsword"
	"ringFire": ["sword", "fire", "bagua"], # fire_instance.gd 使用 "ringFire"，等同 "ringfire"
	"faze_thunder_strike": ["thunder", "bagua"],
}

# 分类标识 → Global 上对应的变量名
const CATEGORY_BONUS_MAP: Dictionary = {
	"main": "study_main_weapon_damage_bonus",
	"sword": "study_sword_damage_bonus",
	"projectile": "study_projectile_damage_bonus",
	"wind": "study_wind_damage_bonus",
	"wide": "study_wide_damage_bonus",
	"life": "study_life_damage_bonus",
	"destroy": "study_destroy_damage_bonus",
	"fire": "study_fire_damage_bonus",
	"protect": "study_protect_damage_bonus",
	"thunder": "study_thunder_damage_bonus",
	"bagua": "study_bagua_damage_bonus",
	"heal": "study_heal_damage_bonus",
	"treasure": "study_treasure_damage_bonus",
	"deep": "",
}

static var _total_damage_bonus_cache: Dictionary = {}


# ===================== 公开接口 =====================

## 一次性刷新全部武器修习效果（游戏启动 / 读档 / 修习升级后调用）
static func apply_all() -> void:
	invalidate_total_damage_bonus_cache()
	_apply_damage_bonuses()
	_apply_weapon_unlocks()
	print("[StudyTreeUp] 武器修习效果已刷新")

static func invalidate_total_damage_bonus_cache() -> void:
	_total_damage_bonus_cache.clear()


# ===================== 伤害加成计算 =====================

static func _apply_damage_bonuses() -> void:
	var t: Dictionary = Global.player_study_tree

	# weapon1-1  主武器强化 — 每级 +3%，上限 4 级
	Global.study_main_weapon_damage_bonus = t.get("weapon1-1", 0) * 0.03

	# weapon2-1  刀剑系 — 每级 +4%，上限 3 级
	Global.study_sword_damage_bonus = t.get("weapon2-1", 0) * 0.04

	# weapon2-3  弹道系 — 每级 +4%，上限 3 级
	Global.study_projectile_damage_bonus = t.get("weapon2-3", 0) * 0.04

	# weapon2-4  啸风系 — 每级 +4%，上限 3 级
	Global.study_wind_damage_bonus = t.get("weapon2-4", 0) * 0.04

	# weapon2-6  广域系 — 每级 +4%，上限 3 级
	Global.study_wide_damage_bonus = t.get("weapon2-6", 0) * 0.04

	# weapon2-8  生灵系 — 每级 +4%，上限 3 级
	Global.study_life_damage_bonus = t.get("weapon2-8", 0) * 0.04

	# weapon2-10 破坏系 — 每级 +4%，上限 3 级
	Global.study_destroy_damage_bonus = t.get("weapon2-10", 0) * 0.04

	# weapon2-1-1  炽炎系 — 每级 +4%，上限 3 级
	Global.study_fire_damage_bonus = t.get("weapon2-1-1", 0) * 0.04

	# weapon2-3-1  护佑系 — 每级 +4%，上限 3 级
	Global.study_protect_damage_bonus = t.get("weapon2-3-1", 0) * 0.04

	# weapon2-4-1  鸣雷系 — 每级 +4%，上限 3 级
	Global.study_thunder_damage_bonus = t.get("weapon2-4-1", 0) * 0.04

	# weapon2-6-1  八卦系 — 每级 +4%，上限 3 级
	Global.study_bagua_damage_bonus = t.get("weapon2-6-1", 0) * 0.04

	# weapon2-8-1  治愈系 — 每级 +4%，上限 3 级
	Global.study_heal_damage_bonus = t.get("weapon2-8-1", 0) * 0.04

	# weapon2-10-1 宝器系 — 每级 +4%，上限 3 级
	Global.study_treasure_damage_bonus = t.get("weapon2-10-1", 0) * 0.04


# ===================== 武器解锁标记 =====================

static func _apply_weapon_unlocks() -> void:
	Global.study_unlock_qiankun = true # 乾坤双剑
	Global.study_unlock_dragonwind = true # 风龙杖
	Global.study_unlock_bloodwave = true # 血气波
	Global.study_unlock_water = true # 坎水诀
	Global.study_unlock_baoyan = true # 爆炎诀
	Global.study_unlock_genshan = true # 艮山诀
	Global.study_unlock_thunder_break = true # 天雷破
	Global.study_unlock_holylight = true # 圣光术
	Global.study_unlock_xuanwu = true # 玄武盾


# ===================== 面板展示辅助 =====================

## 返回指定 weapon_tag 享受的统一武器伤害加成（修习树、成就、法则等，小数，如 0.12 = 12%）。
## weapon_tag 与各武器脚本中 get_bullet_damage_and_crit_status() 返回值一致。
static func get_total_damage_bonus(weapon_tag: String) -> float:
	return get_total_damage_bonus_excluding(weapon_tag, [])

static func get_total_damage_bonus_excluding(weapon_tag: String, excluded_law_categories: Array = []) -> float:
	var categories: Array = WEAPON_CATEGORY_MAP.get(weapon_tag, [])
	var bonus: float = 0.0
	for cat in categories:
		var var_name: String = CATEGORY_BONUS_MAP.get(cat, "")
		if var_name != "":
			bonus += float(Global.get(var_name))
		if not excluded_law_categories.has(str(cat)):
			bonus += _get_law_weapon_damage_bonus(str(cat))
	bonus += Global.get_achievement_weapon_damage_bonus(weapon_tag)
	return bonus

static func apply_total_damage_bonus_to_base_multiplier(base_multiplier: float, weapon_tag: String) -> float:
	return base_multiplier + get_total_damage_bonus(weapon_tag)

static func apply_total_damage_bonus_to_base_multiplier_excluding(base_multiplier: float, weapon_tag: String, excluded_law_categories: Array = []) -> float:
	return base_multiplier + get_total_damage_bonus_excluding(weapon_tag, excluded_law_categories)

static func apply_total_damage_bonus_to_damage(base_damage: float, weapon_tag: String) -> float:
	return apply_total_damage_bonus_to_damage_excluding(base_damage, weapon_tag, [])

static func apply_total_damage_bonus_to_damage_excluding(base_damage: float, weapon_tag: String, excluded_law_categories: Array = []) -> float:
	if weapon_tag == "":
		return base_damage
	if PC.pc_atk <= 0:
		return base_damage * (1.0 + get_total_damage_bonus_excluding(weapon_tag, excluded_law_categories))
	var base_multiplier: float = base_damage / float(PC.pc_atk)
	return float(PC.pc_atk) * apply_total_damage_bonus_to_base_multiplier_excluding(base_multiplier, weapon_tag, excluded_law_categories)

static func _get_law_weapon_damage_bonus(category: String) -> float:
	match category:
		"bagua":
			return Faze.get_bagua_weapon_damage_bonus()
		"wide":
			return PC.faze_wide_damage_bonus
		"fire":
			return Faze.get_fire_weapon_damage_multiplier(PC.faze_fire_level) - 1.0
		"life":
			return Faze.get_life_damage_multiplier(PC.faze_life_level) - 1.0
		"destroy":
			return Faze.get_destroy_damage_multiplier(PC.faze_destroy_level) - 1.0
		"wind":
			return Faze.get_wind_weapon_damage_multiplier(PC.faze_wind_level) - 1.0
		"thunder":
			return Faze.get_thunder_weapon_damage_multiplier(PC.faze_thunder_level) - 1.0
		"treasure":
			return Faze.get_treasure_weapon_damage_multiplier(PC.faze_treasure_level, PC.get_lucky_level()) - 1.0
		"deep":
			return Faze.get_deep_weapon_damage_bonus(PC.faze_deep_level)
	return 0.0


## 检查指定武器是否已通过修习树解锁（非修习树管控的武器默认视为已解锁）
static func is_weapon_unlocked(_weapon_id: String) -> bool:
	return true
