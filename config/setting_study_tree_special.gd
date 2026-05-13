extends Node
class_name SettingStudyTreeSpecial

# ============================================================
# 修习树（特殊篇）效果实现
# 根据 Global.player_study_tree 中已点亮的节点等级，
# 刷新 Global 上对应的特殊系加成变量。
# 调用时机：读档后、每次修习成功后。
# ============================================================


# ===================== 公开接口 =====================

## 一次性刷新全部特殊修习效果
static func apply_all() -> void:
	var t: Dictionary = Global.player_study_tree

	# special1-1  治愈灵气回复量提升 — 每级 +5%，上限 5 级
	Global.study_heal_aura_recovery_bonus = t.get("special1-1", 0) * 0.05

	# special2-1  治愈灵气出现概率提升 — 每级 +5%，上限 5 级
	Global.study_heal_aura_spawn_chance = t.get("special2-1", 0) * 0.05

	# special2-1-1  治愈灵气拾取后移速提升 — 每级 +10%，持续3秒，上限 5 级
	Global.study_heal_aura_speed_bonus = t.get("special2-1-1", 0) * 0.10

	# special2-1-2  治愈灵气拾取后减伤率提升 — 每级 +5%，持续3秒，上限 5 级
	Global.study_heal_aura_damage_reduction = t.get("special2-1-2", 0) * 0.05

	# special2-2  灵髓碎片出现概率提升 — 每级 +5%，上限 5 级
	Global.study_fragment_drop_chance = t.get("special2-2", 0) * 0.05

	# special2-2-1  boss掉落魔核概率提升 — 每级 +5%，上限 5 级
	Global.study_boss_core_drop_chance = t.get("special2-2-1", 0) * 0.05

	# special2-3  升级后回复体力量提升 — 每级 +5%，上限 5 级
	Global.study_levelup_heal_bonus = t.get("special2-3", 0) * 0.05

	# special2-3-1  升级后额外提升攻击 — 每级 +1 点，上限 2 级
	Global.study_levelup_atk_bonus = t.get("special2-3-1", 0) * 1

	# special2-3-2  升级后额外提升HP — 每级 +5 点，上限 2 级
	Global.study_levelup_hp_bonus = t.get("special2-3-2", 0) * 5

	# special2-4  金团团解锁 — 1 级即解锁
	Global.study_gold_ball_unlocked = t.get("special2-4", 0) >= 1

	# special2-4-1  金团团出现概率提升 — 每级 +10%，上限 5 级
	Global.study_gold_ball_chance_bonus = t.get("special2-4-1", 0) * 0.10

	# special2-4-2  金团团掉落真气量提升 — 每级 +10%，上限 5 级
	Global.study_gold_ball_qi_bonus = t.get("special2-4-2", 0) * 0.10

	print("[StudyTreeSpecial] 特殊修习效果已刷新")
