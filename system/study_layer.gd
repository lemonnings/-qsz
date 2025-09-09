extends CanvasLayer

@export var study_level1 : Button
@export var study_level2 : Button
@export var study_level3 : Button
@export var study_level4 : Button
@export var study_level5 : Button

@export var detail : RichTextLabel
@export var point_label : RichTextLabel

@export var up1 : Button
@export var up1_detail : RichTextLabel
@export var up11 : Button
@export var up11_detail : RichTextLabel
@export var up12 : Button
@export var up12_detail : RichTextLabel
@export var up2 : Button
@export var up2_detail : RichTextLabel
@export var up21 : Button
@export var up21_detail : RichTextLabel
@export var up22 : Button
@export var up22_detail : RichTextLabel
@export var up3 : Button
@export var up3_detail : RichTextLabel
@export var up31 : Button
@export var up31_detail : RichTextLabel
@export var up32 : Button
@export var up32_detail : RichTextLabel
@export var up4 : Button
@export var up4_detail : RichTextLabel
@export var up41 : Button
@export var up41_detail : RichTextLabel
@export var up42 : Button
@export var up42_detail : RichTextLabel
@export var up5 : Button
@export var up5_detail : RichTextLabel
@export var up51 : Button
@export var up51_detail : RichTextLabel
@export var up52 : Button
@export var up52_detail : RichTextLabel

# 玩家修习数据结构
var player_study_config = {
	"yiqiu": {
		1: {
			"skills": ["up1", "up11", "up12", "up2", "up21", "up3", "up4", "up41", "up5"],
			"skill_names": {
				"up1": "闪避",
				"up11": "无敌时间",
				"up12": "闪避CD",
				"up2": "剑气",
				"up21": "紫色系",
				"up3": "天命",
				"up4": "剑气强化",
				"up41": "剑气伤害",
				"up5": "刷新次数"
			},
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
var in_study: bool = false
var transition_tween: Tween

func _ready() -> void:
	# 连接可见性变化信号
	visibility_changed.connect(_on_visibility_changed)
	# 确保在显示时刷新真气数值
	await get_tree().process_frame
	# 确保玩家数据存在并设置默认显示1阶
	if not Global.player_study_data.has(current_player):
		Global.player_study_data[current_player] = {
			"study_level": 0,
			"learned_skills": [],
			"skill_levels": {}
		}
	
	# 连接所有技能按钮的鼠标悬停事件
	connect_skill_hover_events()
	
	update_study_display()

# 处理输入事件，禁用鼠标滚轮缩放
func _input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		# 禁用鼠标滚轮缩放（滚轮上滚和下滚）
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP or mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			get_viewport().set_input_as_handled()

# 连接所有技能按钮的鼠标悬停事件
func connect_skill_hover_events() -> void:
	var skill_buttons = [
		{"button": up1, "skill": "up1"},
		{"button": up11, "skill": "up11"},
		{"button": up12, "skill": "up12"},
		{"button": up2, "skill": "up2"},
		{"button": up21, "skill": "up21"},
		{"button": up22, "skill": "up22"},
		{"button": up3, "skill": "up3"},
		{"button": up31, "skill": "up31"},
		{"button": up32, "skill": "up32"},
		{"button": up4, "skill": "up4"},
		{"button": up41, "skill": "up41"},
		{"button": up42, "skill": "up42"},
		{"button": up5, "skill": "up5"},
		{"button": up51, "skill": "up51"},
		{"button": up52, "skill": "up52"}
	]
	
	for skill_data in skill_buttons:
		var button = skill_data["button"]
		var skill_name = skill_data["skill"]
		if button:
			if not button.mouse_entered.is_connected(_on_skill_mouse_entered):
				button.mouse_entered.connect(_on_skill_mouse_entered.bind(skill_name))
			if not button.mouse_exited.is_connected(_on_skill_mouse_exited):
				button.mouse_exited.connect(_on_skill_mouse_exited)

# 当界面变为可见时刷新显示
func _on_visibility_changed() -> void:
	if visible:
		update_study_display()

func update_study_display() -> void:
	# 获取当前玩家数据
	var player_data = Global.player_study_data.get(current_player, {})
	current_study_level = player_data.get("study_level", 0)
	var learned_skills = player_data.get("learned_skills", [])
	var skill_levels = player_data.get("skill_levels", {})
	
	# 更新修习等级显示
	point_label.text = "真气\n" + str(Global.total_points)
	
	# 隐藏所有升级按钮
	hide_all_upgrade_buttons()

	# 更新技能等级显示
	update_skill_level_display(skill_levels)
	
	# 根据当前阶段显示可用技能
	# 修习阶段0对应配置中的阶段1
	var config_stage = current_study_level + 1
	show_available_skills(config_stage)
	
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
		# 使用正确的节点路径
		var button = get_node_or_null("Panel/study_detail/" + skill_name)
		if button:
			button.visible = true

func update_skill_level_display(skill_levels: Dictionary) -> void:
	# 获取配置信息
	var config = player_study_config.get(current_player, {})
	# 修正阶段映射：当前修习阶段0对应配置中的阶段1
	var config_stage = current_study_level + 1
	var stage_config = config.get(config_stage, {})
	var max_levels = stage_config.get("max_levels", {})
	var point_costs = stage_config.get("point_costs", {})
	var skill_names = stage_config.get("skill_names", {})
	
	# 更新每个技能的等级显示
	var current_level: int
	var max_level: int
	var base_cost: int
	var true_cost: int
	
	# 更新up1相关
	if up1 and up1.visible:
		current_level = skill_levels.get("up1", 0)
		max_level = max_levels.get("up1", 1)
		base_cost = point_costs.get("up1", 0)
		true_cost = true_cost_culculate(base_cost, current_level + 1)
		up1.text = skill_names.get("up1", "up1")
		up1_detail.text = str(current_level) + "/" + str(max_level)
	
	if up11 and up11.visible:
		current_level = skill_levels.get("up11", 0)
		max_level = max_levels.get("up11", 1)
		base_cost = point_costs.get("up11", 0)
		true_cost = true_cost_culculate(base_cost, current_level + 1)
		up11.text = skill_names.get("up11", "up11")
		up11_detail.text = str(current_level) + "/" + str(max_level)
	
	if up12 and up12.visible:
		current_level = skill_levels.get("up12", 0)
		max_level = max_levels.get("up12", 1)
		base_cost = point_costs.get("up12", 0)
		true_cost = true_cost_culculate(base_cost, current_level + 1)
		up12.text = skill_names.get("up12", "up12")
		up12_detail.text = str(current_level) + "/" + str(max_level)
	
	# 更新up2相关
	if up2 and up2.visible:
		current_level = skill_levels.get("up2", 0)
		max_level = max_levels.get("up2", 1)
		base_cost = point_costs.get("up2", 0)
		true_cost = true_cost_culculate(base_cost, current_level + 1)
		up2.text = skill_names.get("up2", "up2")
		up2_detail.text = str(current_level) + "/" + str(max_level)
	
	if up21 and up21.visible:
		current_level = skill_levels.get("up21", 0)
		max_level = max_levels.get("up21", 1)
		base_cost = point_costs.get("up21", 0)
		true_cost = true_cost_culculate(base_cost, current_level + 1)
		up21.text = skill_names.get("up21", "up21")
		up21_detail.text = str(current_level) + "/" + str(max_level)
	
	if up22 and up22.visible:
		current_level = skill_levels.get("up22", 0)
		max_level = max_levels.get("up22", 1)
		base_cost = point_costs.get("up22", 0)
		true_cost = true_cost_culculate(base_cost, current_level + 1)
		up22.text = skill_names.get("up22", "up22")
		up22_detail.text = str(current_level) + "/" + str(max_level)
	
	# 更新up3相关
	if up3 and up3.visible:
		current_level = skill_levels.get("up3", 0)
		max_level = max_levels.get("up3", 1)
		base_cost = point_costs.get("up3", 0)
		true_cost = true_cost_culculate(base_cost, current_level + 1)
		up3.text = skill_names.get("up3", "up3")
		up3_detail.text = str(current_level) + "/" + str(max_level)
	
	if up31 and up31.visible:
		current_level = skill_levels.get("up31", 0)
		max_level = max_levels.get("up31", 1)
		base_cost = point_costs.get("up31", 0)
		true_cost = true_cost_culculate(base_cost, current_level + 1)
		up31.text = skill_names.get("up31", "up31")
		up31_detail.text = str(current_level) + "/" + str(max_level)
	
	if up32 and up32.visible:
		current_level = skill_levels.get("up32", 0)
		max_level = max_levels.get("up32", 1)
		base_cost = point_costs.get("up32", 0)
		true_cost = true_cost_culculate(base_cost, current_level + 1)
		up32.text = skill_names.get("up32", "up32")
		up32_detail.text = str(current_level) + "/" + str(max_level)
	
	# 更新up4相关
	if up4 and up4.visible:
		current_level = skill_levels.get("up4", 0)
		max_level = max_levels.get("up4", 1)
		base_cost = point_costs.get("up4", 0)
		true_cost = true_cost_culculate(base_cost, current_level + 1)
		up4.text = skill_names.get("up4", "up4")
		up4_detail.text = str(current_level) + "/" + str(max_level)
	
	if up41 and up41.visible:
		current_level = skill_levels.get("up41", 0)
		max_level = max_levels.get("up41", 1)
		base_cost = point_costs.get("up41", 0)
		true_cost = true_cost_culculate(base_cost, current_level + 1)
		up41.text = skill_names.get("up41", "up41")
		up41_detail.text = str(current_level) + "/" + str(max_level)
	
	if up42 and up42.visible:
		current_level = skill_levels.get("up42", 0)
		max_level = max_levels.get("up42", 1)
		base_cost = point_costs.get("up42", 0)
		true_cost = true_cost_culculate(base_cost, current_level + 1)
		up42.text = skill_names.get("up42", "up42")
		up42_detail.text = str(current_level) + "/" + str(max_level)
	
	# 更新up5相关
	if up5 and up5.visible:
		current_level = skill_levels.get("up5", 0)
		max_level = max_levels.get("up5", 1)
		base_cost = point_costs.get("up5", 0)
		true_cost = true_cost_culculate(base_cost, current_level + 1)
		up5.text = skill_names.get("up5", "up5")
		up5_detail.text = str(current_level) + "/" + str(max_level)
	
	if up51 and up51.visible:
		current_level = skill_levels.get("up51", 0)
		max_level = max_levels.get("up51", 1)
		base_cost = point_costs.get("up51", 0)
		true_cost = true_cost_culculate(base_cost, current_level + 1)
		up51.text = skill_names.get("up51", "up51")
		up51_detail.text = str(current_level) + "/" + str(max_level)
	
	if up52 and up52.visible:
		current_level = skill_levels.get("up52", 0)
		max_level = max_levels.get("up52", 1)
		base_cost = point_costs.get("up52", 0)
		true_cost = true_cost_culculate(base_cost, current_level + 1)
		up52.text = skill_names.get("up52", "up52")
		up52_detail.text = str(current_level) + "/" + str(max_level)

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
	# 修正阶段映射：当前修习阶段0对应配置中的阶段1
	var config_stage = current_study_level + 1
	var stage_config = config.get(config_stage, {})
	var max_levels = stage_config.get("max_levels", {})
	var point_costs = stage_config.get("point_costs", {})
	# 获取当前技能等级来计算真实消耗
	var current_level = skill_levels.get(skill_name, 0)
	var next_level = current_level + 1
	var base_cost = point_costs.get(skill_name, 0)
	var true_cost = true_cost_culculate(base_cost, next_level)
	
	# 检查技能是否存在配置
	if not max_levels.has(skill_name) or not point_costs.has(skill_name):
		var main_town = get_parent()
		if main_town and main_town.has_method("get") and main_town.tip:
			main_town.tip.start_animation("技能配置不存在: " + skill_name, 0.5)
		else:
			print("技能配置不存在: " + skill_name)
		return
	
	# 获取最大等级
	var max_level = max_levels[skill_name]
	
	# 检查是否已达到最大等级
	if current_level >= max_level:
		var main_town = get_parent()
		if main_town and main_town.has_method("get") and main_town.tip:
			main_town.tip.start_animation("技能已达到最大等级: " + skill_name, 0.5)
		else:
			print("技能已达到最大等级: " + skill_name)
		return
	
	# 检查真气是否足够
	if Global.total_points < true_cost:
		var main_town = get_parent()
		if main_town and main_town.has_method("get") and main_town.tip:
			main_town.tip.start_animation("真气不足，需要: " + str(true_cost) + "，当前: " + str(Global.total_points), 0.5)
		else:
			print("真气不足，需要: " + str(true_cost) + "，当前: " + str(Global.total_points))
		return
	
	# 升级技能
	skill_levels[skill_name] = current_level + 1
	Global.total_points -= true_cost
	
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
	
	var main_town = get_parent()
	if main_town and main_town.has_method("get") and main_town.tip:
		main_town.tip.start_animation("学习技能: " + skill_name + " 等级: " + str(skill_levels[skill_name]) + " 消耗真气: " + str(true_cost), 0.5)

func apply_skill_effect(skill_name: String) -> void:
	# 获取当前技能等级
	var player_data = Global.player_study_data.get(current_player, {})
	var skill_levels = player_data.get("skill_levels", {})
	var skill_level = skill_levels.get(skill_name, 0)
	
	# 调用技能效果配置文件中的函数
	SkillEffects.apply_skill_effect(current_player, current_study_level, skill_name, skill_level)

func _on_study_level_1_pressed() -> void:
	# 1阶对应study_level = 0，因为config_stage = current_study_level + 1
	# 所以1阶技能在配置中是stage 1，对应study_level = 0
	Global.player_study_data[current_player]["study_level"] = 0
	update_study_display()

func _on_study_level_2_pressed() -> void:
	# 2阶对应study_level = 1
	Global.player_study_data[current_player]["study_level"] = 1
	update_study_display()

func _on_study_level_3_pressed() -> void:
	# 3阶对应study_level = 2
	Global.player_study_data[current_player]["study_level"] = 2
	update_study_display()

func _on_study_level_4_pressed() -> void:
	# 4阶对应study_level = 3
	Global.player_study_data[current_player]["study_level"] = 3
	update_study_display()

func _on_study_level_5_pressed() -> void:
	# 5阶对应study_level = 4
	Global.player_study_data[current_player]["study_level"] = 4
	update_study_display()

# 检查技能是否在当前阶段可用
func is_skill_available(skill_name: String) -> bool:
	var config = player_study_config.get(current_player, {})
	# 修正阶段映射：当前修习阶段0对应配置中的阶段1
	var config_stage = current_study_level + 1
	var stage_config = config.get(config_stage, {})
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
	in_study = false
	_transition_to_layer()

func _transition_to_layer():
	# 先淡出当前界面
	if transition_tween:
		transition_tween.kill()
	
	transition_tween = create_tween()
	transition_tween.set_parallel(true)
	
	# 淡出当前层的所有子节点
	for child in get_children():
		if child.has_method("set_modulate"):
			transition_tween.tween_property(child, "modulate:a", 0.0, 0.125)
	
	# 等待淡出完成后处理退出逻辑
	transition_tween.tween_callback(_handle_exit).set_delay(0.125)

func _handle_exit():
	# 调用main_town的_on_exit_pressed方法来处理dark_overlay
	var main_town = get_parent()
	if main_town and main_town.has_method("_on_exit_pressed"):
		main_town._on_exit_pressed()
	
	# 调用本地的_switch_layers来隐藏界面
	_switch_layers()

func _switch_layers():
	# 隐藏当前层
	visible = false
	# 重置所有子节点的透明度
	for child in get_children():
		if child.has_method("set_modulate"):
			child.modulate.a = 1.0
	
	# 保存游戏
	Global.save_game()
	
	# 恢复玩家控制和游戏状态
	PC.movement_disabled = false
	get_tree().paused = false

# 鼠标悬停事件处理函数
func _on_skill_mouse_entered(skill_name: String) -> void:
	var player_data = Global.player_study_data.get(current_player, {})
	var skill_levels = player_data.get("skill_levels", {})
	var current_level = skill_levels.get(skill_name, 0)
	
	# 获取配置信息
	var config = player_study_config.get(current_player, {})
	var config_stage = current_study_level + 1
	var stage_config = config.get(config_stage, {})
	var max_levels = stage_config.get("max_levels", {})
	var point_costs = stage_config.get("point_costs", {})
	var descriptions = stage_config.get("descriptions", {})
	var skill_names = stage_config.get("skill_names", {})
	
	var max_level = max_levels.get(skill_name, 1)
	var base_cost = point_costs.get(skill_name, 0)
	var true_cost = true_cost_culculate(base_cost, current_level + 1)
	var description = descriptions.get(skill_name, "")
	var skill_display_name = skill_names.get(skill_name, skill_name)
	
	# 构建技能升级效果文本
	var effect_text = get_skill_effect_text(skill_name, current_level, max_level)
	
	# 构建完整的详情文本
	var detail_text = ""
	if effect_text != "":
		detail_text += effect_text + "\n\n"
	detail_text += "消耗真气：\n" + str(true_cost)
	
	detail.text = detail_text

func _on_skill_mouse_exited() -> void:
	# 鼠标离开时清空详情显示
	detail.text = ""

# 获取技能升级效果文本
func get_skill_effect_text(skill_name: String, current_level: int, max_level: int) -> String:
	var effect_text = ""
	
	match skill_name:
		"up1":
			effect_text = "[font_size=28]闪避技能[/font_size]\n"
			effect_text += "解锁闪避能力"
		"up11":
			effect_text = "[font_size=28]无敌时间[/font_size]\n"
			effect_text += "无敌时间 "
			for i in range(max_level):
				var value = 0.3 + i * 0.1  # 0.3/0.4/0.5秒
				if i == current_level:
					effect_text += "[color=green]" + str(value) + "[/color]/"
				else:
					effect_text += "[color=#999]" + str(value) + "[/color]/"
			effect_text = effect_text.rstrip("/") + "秒"
		"up12":
			effect_text = "[font_size=28]闪避冷却降低[/font_size]\n"
			effect_text += "CD "
			for i in range(max_level):
				var value = 10 - i  # 10/9/8秒
				if i == current_level:
					effect_text += "[color=green]" + str(value) + "[/color]/"
				else:
					effect_text += "[color=#999]" + str(value) + "[/color]/"
			effect_text = effect_text.rstrip("/") + "秒"
		"up2":
			effect_text = "[font_size=28]蓝色系召唤[/font_size]\n"
			effect_text += "开启蓝色系召唤技能"
		"up21":
			effect_text = "[font_size=28]紫色系召唤[/font_size]\n"
			effect_text += "开启紫色系召唤技能"
		"up3":
			effect_text = "[font_size=28]天命提升[/font_size]\n"
			effect_text += "天命初始 +"
			for i in range(max_level):
				var value = 3 + i * 3  # +3/6/9
				if i == current_level:
					effect_text += "[color=green]" + str(value) + "[/color]/"
				else:
					effect_text += "[color=#999]" + str(value) + "[/color]/"
			effect_text = effect_text.rstrip("/")
		"up4":
			effect_text = "[font_size=28]剑气强化[/font_size]\n"
			effect_text += "剑气初始强化 +"
			for i in range(max_level):
				var value = i + 1  # +1/2
				if i == current_level:
					effect_text += "[color=green]" + str(value) + "[/color]/"
				else:
					effect_text += "[color=#999]" + str(value) + "[/color]/"
			effect_text = effect_text.rstrip("/")
		"up41":
			effect_text = "[font_size=28]剑气伤害提升[/font_size]\n"
			effect_text += "剑气伤害 +"
			for i in range(max_level):
				var value = 6 + i * 6  # +6%/12%/18%
				if i == current_level:
					effect_text += "[color=green]" + str(value) + "%[/color]/"
				else:
					effect_text += "[color=#999]" + str(value) + "%[/color]/"
			effect_text = effect_text.rstrip("/")
		"up22":
			effect_text = "[font_size=28]召唤强化[/font_size]\n"
			effect_text += "召唤初始强化 +"
			for i in range(max_level):
				var value = i + 1  # +1/2
				if i == current_level:
					effect_text += "[color=green]" + str(value) + "[/color]/"
				else:
					effect_text += "[color=#999]" + str(value) + "[/color]/"
			effect_text = effect_text.rstrip("/")
		"up31":
			effect_text = "[font_size=28]天命上限提升[/font_size]\n"
			effect_text += "天命上限 +"
			for i in range(max_level):
				var value = 10 + i * 10  # +10/20/30
				if i == current_level:
					effect_text += "[color=green]" + str(value) + "[/color]/"
				else:
					effect_text += "[color=#999]" + str(value) + "[/color]/"
			effect_text = effect_text.rstrip("/")
		"up32":
			effect_text = "[font_size=28]天命获取提升[/font_size]\n"
			effect_text += "天命获取 +"
			for i in range(max_level):
				var value = 10 + i * 10  # +10%/20%/30%
				if i == current_level:
					effect_text += "[color=green]" + str(value) + "%[/color]/"
				else:
					effect_text += "[color=#999]" + str(value) + "%[/color]/"
			effect_text = effect_text.rstrip("/")
		"up42":
			effect_text = "[font_size=28]剑气冷却降低[/font_size]\n"
			effect_text += "剑气CD -"
			for i in range(max_level):
				var value = 0.5 + i * 0.5  # -0.5/-1.0/-1.5秒
				if i == current_level:
					effect_text += "[color=green]" + str(value) + "[/color]/"
				else:
					effect_text += "[color=#999]" + str(value) + "[/color]/"
			effect_text = effect_text.rstrip("/") + "秒"
		"up5":
			effect_text = "[font_size=28]刷新次数[/font_size]\n"
			effect_text += "刷新次数 +"
			for i in range(max_level):
				var value = i + 1  # +1/2
				if i == current_level:
					effect_text += "[color=green]" + str(value) + "[/color]/"
				else:
					effect_text += "[color=#999]" + str(value) + "[/color]/"
			effect_text = effect_text.rstrip("/")
		"up51":
			effect_text = "[font_size=28]刷新冷却降低[/font_size]\n"
			effect_text += "刷新CD -"
			for i in range(max_level):
				var value = 5 + i * 5  # -5/-10/-15秒
				if i == current_level:
					effect_text += "[color=green]" + str(value) + "[/color]/"
				else:
					effect_text += "[color=#999]" + str(value) + "[/color]/"
			effect_text = effect_text.rstrip("/") + "秒"
		"up52":
			effect_text = "[font_size=28]刷新品质提升[/font_size]\n"
			effect_text += "刷新品质 +"
			for i in range(max_level):
				var value = 10 + i * 10  # +10%/20%/30%
				if i == current_level:
					effect_text += "[color=green]" + str(value) + "%[/color]/"
				else:
					effect_text += "[color=#999]" + str(value) + "%[/color]/"
			effect_text = effect_text.rstrip("/")
		_:
			# 默认情况，显示技能名称
			effect_text = "[font_size=28]" + skill_name + "[/font_size]"
	
	return effect_text
