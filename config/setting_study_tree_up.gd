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
# "destroy"    = 破坏系      "treasure" = 宝器系(子类)

const WEAPON_CATEGORY_MAP: Dictionary = {
	# 四个角色基础武器（受主武器强化影响）
	"swordqi": ["main", "sword"],
	"light_bullet": ["main", "projectile"],
	"ice": ["main", "destroy"],
	"qigong": ["main"],
	# 刀剑系
	"qiankun": ["sword"],
	# 刀剑系 > 炽炎系
	"moyan": ["sword", "fire"],
	"riyan": ["sword", "fire"],
	"ringfire": ["sword", "fire"],
	"baoyan": ["sword", "fire"],
	# 弹道系 > 护佑系
	"genshan": ["projectile", "protect"],
	# 啸风系
	"xunfeng": ["wind"],
	"dragonwind": ["wind"],
	# 啸风系 > 鸣雷系
	"thunder": ["wind", "thunder"],
	"thunder_break": ["wind", "thunder"],
	# 广域系
	"bloodwave": ["wide"],
	"bloodboardsword": ["wide"],
	# 广域系 > 八卦系
	"duize": ["wide", "bagua"],
	# 生灵系
	"water": ["life"],
	# 生灵系 > 治愈系
	"holylight": ["life", "heal"],
	# 破坏系 > 宝器系
	"branch": ["destroy", "treasure"],
	"xuanwu": ["destroy", "treasure"],
	# ---- 别名映射：take_damage(damage_type) 与 WEAPON_CATEGORY_MAP key 不一致的武器 ----
	"ice_flower": ["main", "destroy"], # ice_flower.gd 使用 "ice_flower"，等同 "ice"
	"blood_wave": ["wide"], # blood_wave.gd 使用 "blood_wave"，等同 "bloodwave"
	"blood_broadsword": ["wide"], # blood_broadsword.gd 使用 "blood_broadsword"，等同 "bloodboardsword"
	"ringFire": ["sword", "fire"], # fire_instance.gd 使用 "ringFire"，等同 "ringfire"
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
}


# ===================== 公开接口 =====================

## 一次性刷新全部武器修习效果（游戏启动 / 读档 / 修习升级后调用）
static func apply_all() -> void:
	_apply_damage_bonuses()
	_apply_weapon_unlocks()
	print("[StudyTreeUp] 武器修习效果已刷新")


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
	var t: Dictionary = Global.player_study_tree

	Global.study_unlock_qiankun = t.get("weapon2-2", 0) >= 1 # 乾坤双剑
	Global.study_unlock_dragonwind = t.get("weapon2-5", 0) >= 1 # 风龙杖
	Global.study_unlock_bloodwave = t.get("weapon2-7", 0) >= 1 # 血气波
	Global.study_unlock_water = t.get("weapon2-9", 0) >= 1 # 坎水诀
	Global.study_unlock_baoyan = t.get("weapon2-1-2", 0) >= 1 # 爆炎诀
	Global.study_unlock_genshan = t.get("weapon2-3-2", 0) >= 1 # 艮山诀
	Global.study_unlock_thunder_break = t.get("weapon2-4-2", 0) >= 1 # 天雷破
	Global.study_unlock_holylight = t.get("weapon2-8-2", 0) >= 1 # 圣光术
	Global.study_unlock_xuanwu = t.get("weapon2-10-2", 0) >= 1 # 玄武盾


# ===================== 面板展示辅助 =====================

## 返回指定 weapon_tag 享受的修习树总伤害加成（小数，如 0.12 = 12%）。
## weapon_tag 与各武器脚本中 get_bullet_damage_and_crit_status() 返回值一致。
static func get_total_damage_bonus(weapon_tag: String) -> float:
	var categories: Array = WEAPON_CATEGORY_MAP.get(weapon_tag, [])
	var bonus: float = 0.0
	for cat in categories:
		var var_name: String = CATEGORY_BONUS_MAP.get(cat, "")
		if var_name != "":
			bonus += float(Global.get(var_name))
	return bonus


## 检查指定武器是否已通过修习树解锁（非修习树管控的武器默认视为已解锁）
static func is_weapon_unlocked(weapon_id: String) -> bool:
	match weapon_id:
		"qiankun": return Global.study_unlock_qiankun
		"dragonwind": return Global.study_unlock_dragonwind
		"bloodwave": return Global.study_unlock_bloodwave
		"water": return Global.study_unlock_water
		"baoyan": return Global.study_unlock_baoyan
		"genshan": return Global.study_unlock_genshan
		"thunder_break": return Global.study_unlock_thunder_break
		"holylight": return Global.study_unlock_holylight
		"xuanwu": return Global.study_unlock_xuanwu
		_: return true
