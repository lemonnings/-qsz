extends Node
class_name SettingStudyTreeTeam

# ============================================================
# 修习树（团队篇）效果实现
# 根据 Global.player_study_tree 中已点亮的节点等级，
# 刷新 Global 上对应的团队属性加成变量。
# 调用时机：读档后、每次修习成功后。
# ============================================================


# ===================== 公开接口 =====================

## 一次性刷新全部团队修习效果
static func apply_all() -> void:
	var t: Dictionary = Global.player_study_tree

	# team1-1  攻击提升 — 每级 +4%，上限 5 级
	Global.study_atk_bonus = t.get("team1-1", 0) * 0.04

	# team2-1  HP提升 — 每级 +50，上限 5 级
	Global.study_hp_bonus = t.get("team2-1", 0) * 50

	# team2-2  攻速提升 — 每级 +1%，上限 5 级
	Global.study_atk_speed_bonus = t.get("team2-2", 0) * 0.01

	# team2-3  移速提升 — 每级 +1%，上限 5 级
	Global.study_move_speed_bonus = t.get("team2-3", 0) * 0.01

	# team2-4  暴击率提升 — 每级 +1%，上限 5 级
	Global.study_crit_rate_bonus = t.get("team2-4", 0) * 0.01

	# team2-5  暴击伤害提升 — 每级 +3%，上限 5 级
	Global.study_crit_damage_bonus = t.get("team2-5", 0) * 0.03

	# team2-6  真气获取率提升 — 每级 +4%，上限 5 级
	Global.study_qi_gain_bonus = t.get("team2-6", 0) * 0.04

	# team2-1-1  减伤率提升 — 每级 +0.5%，上限 5 级
	Global.study_damage_reduction_bonus = t.get("team2-1-1", 0) * 0.005

	# team2-2-1  最终伤害提升 — 每级 +1%，上限 5 级
	Global.study_final_damage_bonus = t.get("team2-2-1", 0) * 0.01

	# team2-4-1  对小怪伤害提升 — 每级 +1.5%，上限 5 级
	Global.study_normal_monster_damage_bonus = t.get("team2-4-1", 0) * 0.015

	# team2-5-1  对精英首领伤害提升 — 每级 +1.5%，上限 5 级
	Global.study_elite_damage_bonus = t.get("team2-5-1", 0) * 0.015

	# team2-6-1  掉落率提升 — 每级 +2%，上限 5 级
	Global.study_drop_rate_bonus = t.get("team2-6-1", 0) * 0.02

	print("[StudyTreeTeam] 团队修习效果已刷新")
