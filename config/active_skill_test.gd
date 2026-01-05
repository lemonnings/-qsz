extends Node

# 主动技能系统测试脚本
# 用于测试和演示主动技能系统的使用

class_name ActiveSkillTest

# 技能管理器引用
var skill_manager: ActiveSkillManager

# 技能配置窗口引用
var skill_config_ui: SkillHotkeyConfig

func _ready():
	# 获取技能管理器
	skill_manager = Global.ActiveSkillManager
	
	# 连接技能事件
	connect_skill_events()
	
	# 打印初始状态
	print_skill_status()

func connect_skill_events():
	"""连接技能相关事件"""
	if skill_manager:
		skill_manager.skill_used.connect(_on_skill_used)
		skill_manager.skill_cooldown_started.connect(_on_skill_cooldown_started)
		skill_manager.skill_cooldown_finished.connect(_on_skill_cooldown_finished)

func _on_skill_used(skill_id: String):
	"""技能使用时的回调"""
	var skill = skill_manager.get_skill_by_id(skill_id)
	if skill:
		print("使用技能: ", skill.name, " (", skill_id, ")")

func _on_skill_cooldown_started(skill_id: String, cooldown_time: float):
	"""技能冷却开始时的回调"""
	var skill = skill_manager.get_skill_by_id(skill_id)
	if skill:
		print("技能 ", skill.name, " 进入冷却，时间: ", cooldown_time, "秒")

func _on_skill_cooldown_finished(skill_id: String):
	"""技能冷却结束时的回调"""
	var skill = skill_manager.get_skill_by_id(skill_id)
	if skill:
		print("技能 ", skill.name, " 冷却完成，可以使用")

func print_skill_status():
	"""打印技能状态"""
	print("=== 主动技能系统状态 ===")
	
	if not skill_manager:
		print("错误: 技能管理器未找到")
		return
	
	# 打印已掌握的技能
	var mastered_skills = skill_manager.get_mastered_skills()
	print("已掌握的技能数量: ", mastered_skills.size())
	
	for skill in mastered_skills:
		print("  - ", skill.name, " (", skill.id, ") - 冷却: ", skill.cooldown_time, "秒")
	
	# 打印快捷键配置
	print("\n快捷键配置:")
	var slot_keys = ["shift", "space", "q", "e"]
	for slot_key in slot_keys:
		var skill_id = skill_manager.get_skill_slot(slot_key)
		if skill_id:
			var skill = skill_manager.get_skill_by_id(skill_id)
			if skill:
				print("  ", slot_key.to_upper(), ": ", skill.name)
			else:
				print("  ", slot_key.to_upper(), ": ", skill_id, " (未找到技能)")
		else:
			print("  ", slot_key.to_upper(), ": 空")
	
	print("========================")

func create_skill_config_ui() -> SkillHotkeyConfig:
	"""创建技能配置UI"""
	if skill_config_ui:
		return skill_config_ui
	
	# 创建配置窗口
	skill_config_ui = SkillHotkeyConfig.new()
	skill_config_ui.name = "SkillHotkeyConfig"
	
	# 设置窗口属性
	skill_config_ui.size = Vector2(800, 600)
	skill_config_ui.position = Vector2(100, 100)
	
	# 连接信号
	skill_config_ui.config_confirmed.connect(_on_config_confirmed)
	skill_config_ui.config_cancelled.connect(_on_config_cancelled)
	
	# 添加到场景树
	get_tree().current_scene.add_child(skill_config_ui)
	
	return skill_config_ui

func show_skill_config():
	"""显示技能配置窗口"""
	var config_ui = create_skill_config_ui()
	config_ui.show_config()

func _on_config_confirmed():
	"""配置确认回调"""
	print("技能配置已确认")
	print_skill_status()

func _on_config_cancelled():
	"""配置取消回调"""
	print("技能配置已取消")

# 测试方法
func test_dash_skill():
	"""测试闪避技能"""
	print("\n=== 测试闪避技能 ===")
	
	if not skill_manager:
		print("错误: 技能管理器未找到")
		return
	
	# 尝试使用闪避技能
	var success = skill_manager.use_skill("dash")
	if success:
		print("闪避技能使用成功")
	else:
		print("闪避技能使用失败（可能在冷却中或其他原因）")

func test_skill_slots():
	"""测试技能槽位配置"""
	print("\n=== 测试技能槽位配置 ===")
	
	if not skill_manager:
		print("错误: 技能管理器未找到")
		return
	
	# 测试设置技能到不同槽位
	var test_configs = [
		{"slot": "shift", "skill": "dash"},
		{"slot": "space", "skill": "dash"},
		{"slot": "q", "skill": ""},  # 清空
		{"slot": "e", "skill": "dash"}
	]
	
	for config in test_configs:
		var success = skill_manager.set_skill_slot(config.slot, config.skill)
		if success:
			if config.skill == "":
				print("成功清空槽位: ", config.slot)
			else:
				print("成功设置槽位 ", config.slot, " -> ", config.skill)
		else:
			print("设置槽位失败: ", config.slot, " -> ", config.skill)
	
	# 打印最终配置
	print("\n最终槽位配置:")
	var slot_keys = ["shift", "space", "q", "e"]
	for slot_key in slot_keys:
		var skill_id = skill_manager.get_skill_slot(slot_key)
		print("  ", slot_key, ": ", skill_id if skill_id else "空")

# 输入处理（用于测试）
func _input(event: InputEvent):
	"""处理测试输入"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				print_skill_status()
			KEY_F2:
				test_dash_skill()
			KEY_F3:
				test_skill_slots()
			KEY_F4:
				show_skill_config()
			KEY_F5:
				print("\n=== 测试按键说明 ===")
				print("F1: 打印技能状态")
				print("F2: 测试闪避技能")
				print("F3: 测试技能槽位配置")
				print("F4: 显示技能配置窗口")
				print("F5: 显示此帮助")
				print("Shift/Space/Q/E: 使用对应槽位的技能")
				print("===================")

# 自动运行测试（可选）
func run_auto_test():
	"""运行自动测试"""
	print("\n=== 开始自动测试 ===")
	
	# 等待一帧确保初始化完成
	await get_tree().process_frame
	
	# 运行各项测试
	print_skill_status()
	test_skill_slots()
	test_dash_skill()
	
	print("\n=== 自动测试完成 ===")
	print("按F5查看测试按键说明")
