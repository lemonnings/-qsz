extends CanvasLayer

@export var study_level1 : Button
@export var study_level2 : Button
@export var study_level3 : Button
@export var study_level4 : Button
@export var study_level5 : Button

@export var detail : RichTextLabel

@export var study_level : RichTextLabel

@export var up1 : Button
@export var up1_detail : String
@export var up11 : Button
@export var up11_detail : String
@export var up12 : Button
@export var up12_detail : String
@export var up2 : Button
@export var up2_detail : String
@export var up21 : Button
@export var up21_detail : String
@export var up22 : Button
@export var up22_detail : String
@export var up3 : Button
@export var up3_detail : String
@export var up31 : Button
@export var up31_detail : String
@export var up32 : Button
@export var up32_detail : String
@export var up4 : Button
@export var up4_detail : String
@export var up41 : Button
@export var up41_detail : String
@export var up42 : Button
@export var up42_detail : String
@export var up5 : Button
@export var up5_detail : String
@export var up51 : Button
@export var up51_detail : String
@export var up52 : Button
@export var up52_detail : String

# 玩家修习数据结构
var player_study_config = {
	"yiqiu": {
		1: {
			"skills": ["up1", "up11", "up12", "up2", "up21", "up3", "up4", "up41", "up5"],
			"descriptions": {
				"up1": "习得闪避",
				"up11": "闪避无敌0.3/0.4/0.5秒",
				"up12": "闪避冷却10/9/8秒",
				"up2": "开启召唤蓝色系",
				"up21": "开启紫色系",
				"up3": "天命初始+3/6/9",
				"up4": "剑气初始强化+1/2",
				"up41": "剑气伤害提升6%/12%/18%",
				"up5": "刷新次数+1/2"
			},
			"max_levels": {
				"up1": 1,
				"up11": 3,
				"up12": 3,
				"up2": 1,
				"up21": 1,
				"up3": 3,
				"up4": 2,
				"up41": 3,
				"up5": 2
			},
			"point_costs": {
				"up1": 200,
				"up11": 400,
				"up12": 600,
				"up2": 1000,
				"up21": 1250,
				"up3": 400,
				"up4": 400,
				"up41": 600,
				"up5": 400
			}
		}
	}
}

var current_player = "yiqiu"
var current_study_level = 0

func _ready() -> void:
	update_study_display()

func update_study_display() -> void:
	# 获取当前玩家数据
	var player_data = Global.player_study_data.get(current_player, {})
	current_study_level = player_data.get("study_level", 0)
	var learned_skills = player_data.get("learned_skills", [])
	var skill_levels = player_data.get("skill_levels", {})
	
	# 更新修习等级显示
	study_level.text = "当前修习阶段: " + str(current_study_level) + " | 真气: " + str(PC.point)
	
	# 隐藏所有升级按钮
	hide_all_upgrade_buttons()
		
	# 更新技能等级显示
	update_skill_level_display(skill_levels)
	
	# 根据当前阶段显示可用技能
	if current_study_level == 0:
		# 阶段1可选技能
		show_available_skills(1)
	elif current_study_level == 1:
		# 阶段2可选技能
		show_available_skills(2)
	elif current_study_level == 2:
		# 阶段3可选技能
		show_available_skills(3)
	elif current_study_level == 3:
		# 阶段4可选技能
		show_available_skills(4)
	elif current_study_level == 4:
		# 阶段5可选技能
		show_available_skills(5)
	
	# 更新技能描述
	update_skill_descriptions()

func hide_all_upgrade_buttons() -> void:
	var all_buttons = [up1, up11, up12, up2, up21, up22, up3, up31, up32, up4, up41, up42, up5, up51, up52]
	for button in all_buttons:
		if button:
			button.visible = false

func show_available_skills(stage: int) -> void:
	var config = player_study_config.get(current_player, {})
	var stage_config = config.get(stage, {})
	var available_skills = stage_config.get("skills", [])
	
	for skill_name in available_skills:
		var button = get_node_or_null(skill_name)
		if button:
			button.visible = true

func update_skill_level_display(skill_levels: Dictionary) -> void:
	# 获取配置信息
	var config = player_study_config.get(current_player, {})
	var stage_config = config.get(current_study_level, {})  # 使用当前修习阶段
	var max_levels = stage_config.get("max_levels", {})
	
	# 更新每个技能的等级显示
	var current_level: int
	var max_level: int
	
	# 更新up1相关
	if up1 and up1.visible:
		current_level = skill_levels.get("up1", 0)
		max_level = max_levels.get("up1", 1)
		up1_detail = str(current_level) + "/" + str(max_level)
	
	if up11 and up11.visible:
		current_level = skill_levels.get("up11", 0)
		max_level = max_levels.get("up11", 1)
		up11_detail = str(current_level) + "/" + str(max_level)
	
	if up12 and up12.visible:
		current_level = skill_levels.get("up12", 0)
		max_level = max_levels.get("up12", 1)
		up12_detail = str(current_level) + "/" + str(max_level)
	
	# 更新up2相关
	if up2 and up2.visible:
		current_level = skill_levels.get("up2", 0)
		max_level = max_levels.get("up2", 1)
		up2_detail = str(current_level) + "/" + str(max_level)
	
	if up21 and up21.visible:
		current_level = skill_levels.get("up21", 0)
		max_level = max_levels.get("up21", 1)
		up21_detail = str(current_level) + "/" + str(max_level)
	
	if up22 and up22.visible:
		current_level = skill_levels.get("up22", 0)
		max_level = max_levels.get("up22", 1)
		up22_detail = str(current_level) + "/" + str(max_level)
	
	# 更新up3相关
	if up3 and up3.visible:
		current_level = skill_levels.get("up3", 0)
		max_level = max_levels.get("up3", 1)
		up3_detail = str(current_level) + "/" + str(max_level)
	
	if up31 and up31.visible:
		current_level = skill_levels.get("up31", 0)
		max_level = max_levels.get("up31", 1)
		up31_detail = str(current_level) + "/" + str(max_level)
	
	if up32 and up32.visible:
		current_level = skill_levels.get("up32", 0)
		max_level = max_levels.get("up32", 1)
		up32_detail = str(current_level) + "/" + str(max_level)
	
	# 更新up4相关
	if up4 and up4.visible:
		current_level = skill_levels.get("up4", 0)
		max_level = max_levels.get("up4", 1)
		up4_detail = str(current_level) + "/" + str(max_level)
	
	if up41 and up41.visible:
		current_level = skill_levels.get("up41", 0)
		max_level = max_levels.get("up41", 1)
		up41_detail = str(current_level) + "/" + str(max_level)
	
	if up42 and up42.visible:
		current_level = skill_levels.get("up42", 0)
		max_level = max_levels.get("up42", 1)
		up42_detail = str(current_level) + "/" + str(max_level)
	
	# 更新up5相关
	if up5 and up5.visible:
		current_level = skill_levels.get("up5", 0)
		max_level = max_levels.get("up5", 1)
		up5_detail = str(current_level) + "/" + str(max_level)
	
	if up51 and up51.visible:
		current_level = skill_levels.get("up51", 0)
		max_level = max_levels.get("up51", 1)
		up51_detail = str(current_level) + "/" + str(max_level)
	
	if up52 and up52.visible:
		current_level = skill_levels.get("up52", 0)
		max_level = max_levels.get("up52", 1)
		up52_detail = str(current_level) + "/" + str(max_level)

func update_skill_descriptions() -> void:
	var config = player_study_config.get(current_player, {})
	var descriptions = {}
	
	# 合并所有阶段的描述
	for stage in config.values():
		descriptions.merge(stage.get("descriptions", {}))
	
	# 更新详细描述
	var player_data = Global.player_study_data.get(current_player, {})
	var learned_skills = player_data.get("learned_skills", [])
	
	var description_text = ""
	for skill in learned_skills:
		if descriptions.has(skill):
			description_text += descriptions[skill] + "\n"
	
	detail.text = description_text

func true_cost_culculate(default_cost: int, next_level: int) -> int:
	for i in range(1, next_level + 1):
		default_cost *= 1.5
	return default_cost


func learn_skill(skill_name: String) -> void:
	var player_data = Global.player_study_data.get(current_player, {})
	var learned_skills = player_data.get("learned_skills", [])
	var skill_levels = player_data.get("skill_levels", {})
	
	# 获取配置信息
	var config = player_study_config.get(current_player, {})
	var stage_config = config.get(current_study_level, {})  # 使用当前修习阶段
	var max_levels = stage_config.get("max_levels", {})
	var point_costs = stage_config.get("point_costs", {})
	# 获取当前技能等级来计算真实消耗
	var current_level = skill_levels.get(skill_name, 0)
	var next_level = current_level + 1
	var base_cost = point_costs.get(skill_name, 0)
	var true_cost = true_cost_culculate(base_cost, next_level)
	
	# 检查技能是否存在配置
	if not max_levels.has(skill_name) or not point_costs.has(skill_name):
		print("技能配置不存在: " + skill_name)
		return
	
	# 获取最大等级
	var max_level = max_levels[skill_name]
	
	# 检查是否已达到最大等级
	if current_level >= max_level:
		print("技能已达到最大等级: " + skill_name)
		return
	
	# 检查真气是否足够
	if zhenqi_points < true_cost:
		print("真气不足，需要: " + str(true_cost) + "，当前: " + str(zhenqi_points))
	if PC.point < cost:
		print("真气不足，需要: " + str(cost) + "，当前: " + str(PC.point))
		return
	
	# 升级技能
	skill_levels[skill_name] = current_level + 1
	zhenqi_points -= true_cost
	PC.point -= cost
	
	# 如果是第一次学习，添加到已学习技能列表
	if current_level == 0 and not skill_name in learned_skills:
		learned_skills.append(skill_name)
	
	# 更新全局数据
	Global.player_study_data[current_player]["learned_skills"] = learned_skills
	Global.player_study_data[current_player]["skill_levels"] = skill_levels
	
	# 应用技能效果
	apply_skill_effect(skill_name)
	
	# 更新显示
	update_study_display()
	
	print("学习技能: " + skill_name + " 等级: " + str(skill_levels[skill_name]) + " 消耗真气: " + str(true_cost))

func apply_skill_effect(skill_name: String) -> void:
	# 获取当前技能等级
	var player_data = Global.player_study_data.get(current_player, {})
	var skill_levels = player_data.get("skill_levels", {})
	var skill_level = skill_levels.get(skill_name, 0)
	
	# 调用技能效果配置文件中的函数
	SkillEffects.apply_skill_effect(current_player, current_study_level, skill_name, skill_level)

func _on_study_level_1_pressed() -> void:
	if current_study_level == 0:
		Global.player_study_data[current_player]["study_level"] = 1
		update_study_display()

func _on_study_level_2_pressed() -> void:
	if current_study_level == 1:
		Global.player_study_data[current_player]["study_level"] = 2
		update_study_display()

func _on_study_level_3_pressed() -> void:
	if current_study_level == 2:
		Global.player_study_data[current_player]["study_level"] = 3
		update_study_display()

func _on_study_level_4_pressed() -> void:
	if current_study_level == 3:
		Global.player_study_data[current_player]["study_level"] = 4
		update_study_display()

func _on_study_level_5_pressed() -> void:
	if current_study_level == 4:
		Global.player_study_data[current_player]["study_level"] = 5
		update_study_display()

# 检查技能是否在当前阶段可用
func is_skill_available(skill_name: String) -> bool:
	var config = player_study_config.get(current_player, {})
	var stage_config = config.get(current_study_level, {})
	var skills = stage_config.get("skills", [])
	return skill_name in skills

func _on_up_1_pressed() -> void:
	if is_skill_available("up1"):
		learn_skill("up1")

func _on_up_11_pressed() -> void:
	if is_skill_available("up11"):
		learn_skill("up11")

func _on_up_12_pressed() -> void:
	if is_skill_available("up12"):
		learn_skill("up12")

func _on_up_2_pressed() -> void:
	if is_skill_available("up2"):
		learn_skill("up2")

func _on_up_21_pressed() -> void:
	if is_skill_available("up21"):
		learn_skill("up21")

func _on_up_22_pressed() -> void:
	if is_skill_available("up22"):
		learn_skill("up22")

func _on_up_3_pressed() -> void:
	if is_skill_available("up3"):
		learn_skill("up3")

func _on_up_31_pressed() -> void:
	if is_skill_available("up31"):
		learn_skill("up31")

func _on_up_32_pressed() -> void:
	if is_skill_available("up32"):
		learn_skill("up32")

func _on_up_4_pressed() -> void:
	if is_skill_available("up4"):
		learn_skill("up4")

func _on_up_41_pressed() -> void:
	if is_skill_available("up41"):
		learn_skill("up41")

func _on_up_42_pressed() -> void:
	if is_skill_available("up42"):
		learn_skill("up42")

func _on_up_5_pressed() -> void:
	if is_skill_available("up5"):
		learn_skill("up5")

func _on_up_51_pressed() -> void:
	if is_skill_available("up51"):
		learn_skill("up51")

func _on_up_52_pressed() -> void:
	if is_skill_available("up52"):
		learn_skill("up52")

func _on_exit_pressed() -> void:
	Global.save_game()
	hide()
