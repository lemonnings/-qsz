extends CanvasLayer

@export var study_level1 : Button
@export var study_level2 : Button
@export var study_level3 : Button
@export var study_level4 : Button
@export var study_level5 : Button

@export var detail : RichTextLabel

@export var study_level : RichTextLabel

@export var up1 : Button
@export var up11 : Button
@export var up12 : Button
@export var up2 : Button
@export var up21 : Button
@export var up22 : Button
@export var up3 : Button
@export var up31 : Button
@export var up32 : Button
@export var up4 : Button
@export var up41 : Button
@export var up42 : Button
@export var up5 : Button
@export var up51 : Button
@export var up52 : Button

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
	
	# 更新修习等级显示
	study_level.text = "当前修习阶段: " + str(current_study_level)
	
	# 隐藏所有升级按钮
	hide_all_upgrade_buttons()
	
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

func learn_skill(skill_name: String) -> void:
	var player_data = Global.player_study_data.get(current_player, {})
	var learned_skills = player_data.get("learned_skills", [])
	
	if not skill_name in learned_skills:
		learned_skills.append(skill_name)
		Global.player_study_data[current_player]["learned_skills"] = learned_skills
		
		# 应用技能效果
		apply_skill_effect(skill_name)
		
		# 更新显示
		update_study_display()

func apply_skill_effect(skill_name: String) -> void:
	match skill_name:
		"up1":
			# 习得闪避
			pass
		"up11":
			# 闪避无敌时间
			pass
		"up12":
			# 闪避冷却时间
			pass
		"up2":
			# 开启召唤蓝色系
			pass
		"up21":
			# 开启紫色系
			pass
		"up3":
			# 天命初始+3/6/9
			pass
		"up4":
			# 剑气初始强化+1/2
			pass
		"up41":
			# 剑气伤害提升
			pass
		"up5":
			# 刷新次数+1/2
			Global.refresh_max_num += 1

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

func _on_up_1_pressed() -> void:
	learn_skill("up1")

func _on_up_11_pressed() -> void:
	learn_skill("up11")

func _on_up_12_pressed() -> void:
	learn_skill("up12")

func _on_up_2_pressed() -> void:
	learn_skill("up2")

func _on_up_21_pressed() -> void:
	learn_skill("up21")

func _on_up_22_pressed() -> void:
	pass # 未定义的技能

func _on_up_3_pressed() -> void:
	learn_skill("up3")

func _on_up_31_pressed() -> void:
	pass # 未定义的技能

func _on_up_32_pressed() -> void:
	pass # 未定义的技能

func _on_up_4_pressed() -> void:
	learn_skill("up4")

func _on_up_41_pressed() -> void:
	learn_skill("up41")

func _on_up_42_pressed() -> void:
	pass # 未定义的技能

func _on_up_5_pressed() -> void:
	learn_skill("up5")

func _on_up_51_pressed() -> void:
	pass # 未定义的技能

func _on_up_52_pressed() -> void:
	pass # 未定义的技能

func _on_exit_pressed() -> void:
	Global.save_game()
	hide()
