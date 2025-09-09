class_name SkillEffects

# 重新应用所有已学习的技能效果（用于游戏重置后恢复技能效果）
static func reapply_all_learned_skills() -> void:
	# 遍历所有玩家的学习数据
	for player_name in Global.player_study_data.keys():
		var player_data = Global.player_study_data[player_name]
		if player_data.has("learned_skills") and player_data.has("skill_levels"):
			var learned_skills = player_data["learned_skills"]
			var skill_levels = player_data["skill_levels"]
			# 遍历该玩家已学习的技能
			for skill_name in learned_skills:
				var skill_level = skill_levels.get(skill_name, 1)
				# 重新应用技能效果
				apply_skill_effect(player_name, 1, skill_name, skill_level)

static func apply_skill_effect(player_name: String, study_level: int, skill_name: String, skill_level: int) -> void:
	var function_name = "apply_%s_%d_%s_%d" % [player_name, study_level, skill_name, skill_level]
	
	# 根据函数名调用对应的技能效果
	match function_name:
		# 奕秋 - 第1层级技能效果
		"apply_yiqiu_1_up1_1":
			apply_yiqiu_1_up1_1()
		"apply_yiqiu_1_up11_1":
			apply_yiqiu_1_up11_1()
		"apply_yiqiu_1_up11_2":
			apply_yiqiu_1_up11_2()
		"apply_yiqiu_1_up11_3":
			apply_yiqiu_1_up11_3()
		"apply_yiqiu_1_up12_1":
			apply_yiqiu_1_up12_1()
		"apply_yiqiu_1_up12_2":
			apply_yiqiu_1_up12_2()
		"apply_yiqiu_1_up12_3":
			apply_yiqiu_1_up12_3()
		"apply_yiqiu_1_up2_1":
			apply_yiqiu_1_up2_1()
		"apply_yiqiu_1_up21_1":
			apply_yiqiu_1_up21_1()
		"apply_yiqiu_1_up3_1":
			apply_yiqiu_1_up3_1()
		"apply_yiqiu_1_up3_2":
			apply_yiqiu_1_up3_2()
		"apply_yiqiu_1_up3_3":
			apply_yiqiu_1_up3_3()
		"apply_yiqiu_1_up4_1":
			apply_yiqiu_1_up4_1()
		"apply_yiqiu_1_up4_2":
			apply_yiqiu_1_up4_2()
		"apply_yiqiu_1_up41_1":
			apply_yiqiu_1_up41_1()
		"apply_yiqiu_1_up41_2":
			apply_yiqiu_1_up41_2()
		"apply_yiqiu_1_up41_3":
			apply_yiqiu_1_up41_3()
		"apply_yiqiu_1_up5_1":
			apply_yiqiu_1_up5_1()
		"apply_yiqiu_1_up5_2":
			apply_yiqiu_1_up5_2()
		_:
			print("未找到技能效果函数: ", function_name)

# 奕秋 - 第1层级 - up1技能效果实现
static func apply_yiqiu_1_up1_1() -> void:
	# 习得闪避 - 等级1
	var skill_manager = Global.ActiveSkillManager
	if not skill_manager:
		push_error("ActiveSkillManager未找到，无法解锁闪避技能")
		return
	
	# 检查是否已经解锁
	if skill_manager.mastered_skills.has("dash"):
		print("闪避技能已经解锁")
		return
	
	# 创建并解锁闪避技能
	var dash_skill = skill_manager.DashSkill.new()
	dash_skill.is_unlocked = true
	skill_manager.mastered_skills[dash_skill.id] = dash_skill
	
	# 默认绑定到shift键（如果该键位为空）
	if not skill_manager.skill_slots.has("shift") or skill_manager.skill_slots["shift"] == "":
		skill_manager.skill_slots["shift"] = dash_skill.id
	
	print("已解锁闪避技能并绑定到Shift键")

# 奕秋 - 第1层级 - up11技能效果实现
static func apply_yiqiu_1_up11_1() -> void:
	# 闪避无敌时间 - 等级1 (0.3秒)
	var skill_manager = Global.ActiveSkillManager
	if not skill_manager:
		push_error("ActiveSkillManager未找到，无法修改闪避无敌时间")
		return
	
	var dash_skill = skill_manager.get_skill_by_id("dash")
	if not dash_skill:
		push_error("闪避技能未找到")
		return
	
	dash_skill.invincible_duration = 0.3
	print("闪避无敌时间设置为0.3秒")

static func apply_yiqiu_1_up11_2() -> void:
	# 闪避无敌时间 - 等级2 (0.4秒)
	var skill_manager = Global.ActiveSkillManager
	if not skill_manager:
		push_error("ActiveSkillManager未找到，无法修改闪避无敌时间")
		return
	
	var dash_skill = skill_manager.get_skill_by_id("dash")
	if not dash_skill:
		push_error("闪避技能未找到")
		return
	
	dash_skill.invincible_duration = 0.4
	print("闪避无敌时间设置为0.4秒")

static func apply_yiqiu_1_up11_3() -> void:
	# 闪避无敌时间 - 等级3 (0.5秒)
	var skill_manager = Global.ActiveSkillManager
	if not skill_manager:
		push_error("ActiveSkillManager未找到，无法修改闪避无敌时间")
		return
	
	var dash_skill = skill_manager.get_skill_by_id("dash")
	if not dash_skill:
		push_error("闪避技能未找到")
		return
	
	dash_skill.invincible_duration = 0.5
	print("闪避无敌时间设置为0.5秒")

# 奕秋 - 第1层级 - up12技能效果实现
static func apply_yiqiu_1_up12_1() -> void:
	# 闪避冷却时间 - 等级1 (10秒)
	var skill_manager = Global.ActiveSkillManager
	if not skill_manager:
		push_error("ActiveSkillManager未找到，无法修改闪避冷却时间")
		return
	
	var dash_skill = skill_manager.get_skill_by_id("dash")
	if not dash_skill:
		push_error("闪避技能未找到")
		return
	
	dash_skill.cooldown_time = 10.0
	print("闪避冷却时间设置为10秒")

static func apply_yiqiu_1_up12_2() -> void:
	# 闪避冷却时间 - 等级2 (9秒)
	var skill_manager = Global.ActiveSkillManager
	if not skill_manager:
		push_error("ActiveSkillManager未找到，无法修改闪避冷却时间")
		return
	
	var dash_skill = skill_manager.get_skill_by_id("dash")
	if not dash_skill:
		push_error("闪避技能未找到")
		return
	
	dash_skill.cooldown_time = 9.0
	print("闪避冷却时间设置为9秒")

static func apply_yiqiu_1_up12_3() -> void:
	# 闪避冷却时间 - 等级3 (8秒)
	var skill_manager = Global.ActiveSkillManager
	if not skill_manager:
		push_error("ActiveSkillManager未找到，无法修改闪避冷却时间")
		return
	
	var dash_skill = skill_manager.get_skill_by_id("dash")
	if not dash_skill:
		push_error("闪避技能未找到")
		return
	
	dash_skill.cooldown_time = 8.0
	print("闪避冷却时间设置为8秒")

# 奕秋 - 第1层级 - up2技能效果实现
static func apply_yiqiu_1_up2_1() -> void:
	# 开启召唤蓝色系 - 等级1
	if Global.player_study_data.has("yiqiu"):
		var learned_skills = Global.player_study_data["yiqiu"].get("learned_skills", [])
		if not learned_skills.has("summonBlue"):
			learned_skills.append("summonBlue")
			Global.player_study_data["yiqiu"]["learned_skills"] = learned_skills
			print("开启召唤蓝色系")

static func apply_yiqiu_1_up21_1() -> void:
	# 开启紫色系 - 等级1
	if Global.player_study_data.has("yiqiu"):
		var learned_skills = Global.player_study_data["yiqiu"].get("learned_skills", [])
		if not learned_skills.has("summonPurple"):
			learned_skills.append("summonPurple")
			Global.player_study_data["yiqiu"]["learned_skills"] = learned_skills
			print("开启召唤紫色系")

# 奕秋 - 第1层级 - up3技能效果实现
static func apply_yiqiu_1_up3_1() -> void:
	# 天命初始+3 - 等级1
	Global.lunky_level += 3

static func apply_yiqiu_1_up3_2() -> void:
	# 天命初始+6 - 等级2
	Global.lunky_level += 6

static func apply_yiqiu_1_up3_3() -> void:
	# 天命初始+9 - 等级3
	Global.lunky_level += 9

# 奕秋 - 第1层级 - up4技能效果实现
static func apply_yiqiu_1_up4_1() -> void:
	if Global.player_study_data.has("yiqiu"):
		var learned_skills = Global.player_study_data["yiqiu"].get("learned_skills", [])
		if not learned_skills.has("up4_1"):
			learned_skills.append("up4_1")
			Global.player_study_data["yiqiu"]["learned_skills"] = learned_skills

static func apply_yiqiu_1_up4_2() -> void:
	if Global.player_study_data.has("yiqiu"):
		var learned_skills = Global.player_study_data["yiqiu"].get("learned_skills", [])
		if not learned_skills.has("up4_2"):
			learned_skills.append("up4_2")
			Global.player_study_data["yiqiu"]["learned_skills"] = learned_skills

# 奕秋 - 第1层级 - up41技能效果实现
static func apply_yiqiu_1_up41_1() -> void:
	if Global.player_study_data.has("yiqiu"):
		var learned_skills = Global.player_study_data["yiqiu"].get("learned_skills", [])
		if not learned_skills.has("up41_1"):
			learned_skills.append("up41_1")
			Global.player_study_data["yiqiu"]["learned_skills"] = learned_skills

static func apply_yiqiu_1_up41_2() -> void:
	if Global.player_study_data.has("yiqiu"):
		var learned_skills = Global.player_study_data["yiqiu"].get("learned_skills", [])
		if not learned_skills.has("up41_2"):
			learned_skills.append("up41_2")
			Global.player_study_data["yiqiu"]["learned_skills"] = learned_skills

static func apply_yiqiu_1_up41_3() -> void:
	if Global.player_study_data.has("yiqiu"):
		var learned_skills = Global.player_study_data["yiqiu"].get("learned_skills", [])
		if not learned_skills.has("up41_3"):
			learned_skills.append("up41_3")
			Global.player_study_data["yiqiu"]["learned_skills"] = learned_skills

# 奕秋 - 第1层级 - up5技能效果实现
static func apply_yiqiu_1_up5_1() -> void:
	# 刷新次数+1 - 等级1
	Global.refresh_max_num += 1

static func apply_yiqiu_1_up5_2() -> void:
	# 刷新次数+2 - 等级2
	Global.refresh_max_num += 1
