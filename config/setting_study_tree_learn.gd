extends Node
class_name SettingStudyTreeLearn

# ============================================================
# 修习树（领悟篇）效果实现
# 根据 Global.player_study_tree 中已点亮的节点等级，
# 刷新 Global 上对应的领悟系加成变量。
# 调用时机：读档后、每次修习成功后。
# ============================================================


# ===================== 公开接口 =====================

## 一次性刷新全部领悟修习效果
static func apply_all() -> void:
	var t: Dictionary = Global.player_study_tree

	# learn1-1  纹章效果提升 — 每级 +5%，上限 5 级
	Global.study_emblem_effect_bonus = t.get("learn1-1", 0) * 0.05

	# learn2-1  初始天命提升 — 每级 +1，上限 5 级
	Global.study_initial_lucky = t.get("learn2-1", 0) * 1

	# learn2-2  唤灵系召唤物伤害提升 — 每级 +3%，上限 5 级
	Global.study_summon_damage_bonus = t.get("learn2-2", 0) * 0.03

	# learn2-2-1  唤灵系召唤物攻击间隔减少 — 每级 -3%，上限 5 级
	Global.study_summon_interval_reduction = t.get("learn2-2-1", 0) * 0.03

	# learn2-4 + learn2-3-1  纹章栏位增加 — 各最多 +1 格
	Global.study_emblem_slots_bonus = t.get("learn2-4", 0) * 1 + t.get("learn2-3-1", 0) * 1

	# learn2-5  经验获取提升 — 每级 +3%，上限 5 级
	Global.study_exp_bonus = t.get("learn2-5", 0) * 0.03

	# learn2-5-1  升级经验降低 — 每级 -2%，上限 5 级
	Global.study_exp_reduction = t.get("learn2-5-1", 0) * 0.02

	# learn2-3  六识系出现概率提升 — 每级 +10%，上限 5 级
	Global.study_six_chance_bonus = t.get("learn2-3", 0) * 0.10

	# learn-2-1-1  逆天（红色）领悟概率提升 — 每级 +0.2%，上限 5 级
	Global.study_red_chance_bonus = t.get("learn-2-1-1", 0) * 0.002

	# learn-2-1-2  臻境（金色）领悟概率提升 — 每级 +0.8%，上限 5 级
	Global.study_gold_chance_bonus = t.get("learn-2-1-2", 0) * 0.008

	# learn2-1-3  悟道（紫色）领悟概率提升 — 每级 +1.6%，上限 5 级
	Global.study_purple_chance_bonus = t.get("learn2-1-3", 0) * 0.016

	print("[StudyTreeLearn] 领悟修习效果已刷新")
