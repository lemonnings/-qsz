extends Node
class_name SettingStudyTreeSkill

# ============================================================
# 修习树（技能篇）效果实现
# 根据 Global.player_study_tree 中已点亮的节点等级，
# 刷新 Global 上对应的技能伤害加成 / 技能解锁 / 技能强化数值。
# 调用时机：读档后、每次修习成功后。
# ============================================================


# ===================== 公开接口 =====================

## 一次性刷新全部技能修习效果（游戏启动 / 读档 / 修习升级后调用）
static func apply_all() -> void:
	_apply_damage_bonus()
	_apply_skill_unlocks()
	_apply_skill_enhancements()
	print("[StudyTreeSkill] 技能修习效果已刷新")


# ===================== 技能伤害加成 =====================

static func _apply_damage_bonus() -> void:
	var t: Dictionary = Global.player_study_tree

	# skill1-1  技能伤害提升 — 每级 +3%，上限 3 级
	# skill2-7  技能伤害提升II — 每级 +3%，上限 3 级
	Global.study_skill_damage_bonus = t.get("skill1-1", 0) * 0.03 + t.get("skill2-7", 0) * 0.03


# ===================== 技能解锁标记 =====================

static func _apply_skill_unlocks() -> void:
	var t: Dictionary = Global.player_study_tree

	Global.study_unlock_mizongbu = t.get("skill2-1", 0) >= 1 # 迷踪步（墨宁专属）
	Global.study_unlock_shensheng = t.get("skill2-3", 0) >= 1 # 神圣灼烧（诺姆专属）
	Global.study_unlock_mowenzhen = t.get("skill2-4", 0) >= 1 # 魔纹阵（坎塞尔专属）
	Global.study_unlock_xuanbing = t.get("skill2-5", 0) >= 1 # 玄冰
	Global.study_unlock_luanji = t.get("skill2-6", 0) >= 1 # 乱击
	Global.study_unlock_shuimu = t.get("skill2-8", 0) >= 1 # 水幕护体
	Global.study_unlock_mingxiang = t.get("skill2-9", 0) >= 1 # 冥想


# ===================== 技能强化数值 =====================

static func _apply_skill_enhancements() -> void:
	var t: Dictionary = Global.player_study_tree

	# --- 主节点加成（与子节点叠加）---
	# skill2-2  术诀效果提升 — 风雷破+乱击+玄冰诀伤害提升 每级+3%
	var shujue_level = t.get("skill2-2", 0)
	var shujue_bonus = shujue_level * 0.03

	# skill2-10  魔法效果提升 — 神圣灼烧+炽炎伤害提升 每级+5%
	var mofa_level = t.get("skill2-10", 0)
	var mofa_bonus = mofa_level * 0.05

	# --- 子节点加成 ---
	# skill2-1-1  强化迷踪步 — 持续时间 每级+0.5秒，减伤率 每级+3%
	Global.study_mizongbu_duration_bonus = t.get("skill2-1-1", 0) * 0.5
	Global.study_mizongbu_dmgreduction_bonus = t.get("skill2-1-1", 0) * 0.03

	# skill2-2-1  强化兽化 — 持续时间 每级+1秒，变身期间攻速 每级+3%
	Global.study_shouhua_duration_bonus = t.get("skill2-2-1", 0) * 1.0
	Global.study_shouhua_atkspeed_bonus = t.get("skill2-2-1", 0) * 0.03

	# skill2-3-1  强化神圣灼烧 — 持续时间 每级+0.5秒，伤害提升 每级+6% + 魔法效果提升
	Global.study_shensheng_duration_bonus = t.get("skill2-3-1", 0) * 0.5
	Global.study_shensheng_damage_bonus = t.get("skill2-3-1", 0) * 0.06 + mofa_bonus

	# skill2-4-1  强化魔纹阵 — 大小提升 每级+6%，冷却减少 每级-1秒
	Global.study_mowenzhen_size_bonus = t.get("skill2-4-1", 0) * 0.06
	Global.study_mowenzhen_cd_reduction = t.get("skill2-4-1", 0) * 1.0

	# skill2-5-1  强化玄冰 — 大小提升 每级+8%，伤害提升 每级+8% + 术诀效果提升
	Global.study_xuanbing_size_bonus = t.get("skill2-5-1", 0) * 0.08
	Global.study_xuanbing_damage_bonus = t.get("skill2-5-1", 0) * 0.08 + shujue_bonus

	# skill2-6-1  强化乱击 — 发射剑气数 每级+2，伤害提升 每级+5% + 术诀效果提升
	Global.study_luanji_count_bonus = t.get("skill2-6-1", 0) * 2
	Global.study_luanji_damage_bonus = t.get("skill2-6-1", 0) * 0.05 + shujue_bonus

	# skill2-7-1  强化疗愈 — 回复提升 每级+5%，冷却减少 每级-1秒
	Global.study_liaoyu_recovery_bonus = t.get("skill2-7-1", 0) * 0.05
	Global.study_liaoyu_cd_reduction = t.get("skill2-7-1", 0) * 1.0

	# skill2-8-1  强化水幕护体 — 护盾量提升 每级+8%，冷却减少 每级-0.5秒
	Global.study_shuimu_shield_bonus = t.get("skill2-8-1", 0) * 0.08
	Global.study_shuimu_cd_reduction = t.get("skill2-8-1", 0) * 0.5

	# skill2-8-2  强化闪避 — 无敌时间 每级+0.1秒，冷却减少 每级-0.3秒
	Global.study_shanbi_invincible_bonus = t.get("skill2-8-2", 0) * 0.1
	Global.study_shanbi_cd_reduction = t.get("skill2-8-2", 0) * 0.3

	# skill2-9-1  强化冥想 — 冷却减少 每级-1.5秒
	Global.study_mingxiang_cd_reduction = t.get("skill2-9-1", 0) * 1.5

	# skill2-9-2  强化风雷破 — 伤害提升 每级+8% + 术诀效果提升，爆炸范围提升 每级+8%
	Global.study_fengleipo_damage_bonus = t.get("skill2-9-2", 0) * 0.08 + shujue_bonus
	Global.study_fengleipo_range_bonus = t.get("skill2-9-2", 0) * 0.08

	# skill2-10-1  强化炽炎 — 炽炎伤害提升 每级+8% + 魔法效果提升
	Global.study_chiyan_enhance_damage_bonus = t.get("skill2-10-1", 0) * 0.08 + mofa_bonus
