extends Node

# 玩家技能集成示例
# 展示如何在现有的玩家控制器中集成主动技能系统

class_name PlayerSkillIntegration

# 这个脚本展示了如何将主动技能系统集成到现有的player_action.gd中
# 注意：这只是一个示例，实际集成时需要根据具体情况调整

# 在player_action.gd中添加以下代码：

# === 1. 在变量声明部分添加 ===
# var skill_manager: ActiveSkillManager
# var skill_config_ui: SkillHotkeyConfig

# === 2. 在_ready()函数中添加 ===
func setup_skill_system():
	"""设置技能系统（在player_action.gd的_ready()中调用）"""
	# 获取技能管理器引用
	# skill_manager = Global.ActiveSkillManager
	
	# 连接技能事件
	# if skill_manager:
	#     skill_manager.skill_used.connect(_on_skill_used)
	#     skill_manager.skill_cooldown_started.connect(_on_skill_cooldown_started)
	#     skill_manager.skill_cooldown_finished.connect(_on_skill_cooldown_finished)
	#     print("玩家技能系统已初始化")
	pass

# === 3. 添加技能事件处理函数 ===
func _on_skill_used(skill_id: String):
	"""技能使用时的处理"""
	# 可以在这里添加技能使用的视觉效果、音效等
	print("玩家使用技能: ", skill_id)
	
	# 根据技能类型添加特殊效果
	match skill_id:
		"dash":
			# 闪避技能的额外效果
			add_dash_visual_effects()
			play_dash_sound()

func _on_skill_cooldown_started(skill_id: String, cooldown_time: float):
	"""技能冷却开始时的处理"""
	# 可以在这里更新UI显示冷却状态
	print("技能进入冷却: ", skill_id, ", 时间: ", cooldown_time, "秒")
	
	# 更新技能UI显示
	update_skill_ui_cooldown(skill_id, cooldown_time)

func _on_skill_cooldown_finished(skill_id: String):
	"""技能冷却完成时的处理"""
	# 可以在这里播放冷却完成的提示
	print("技能冷却完成: ", skill_id)
	
	# 更新技能UI显示
	update_skill_ui_ready(skill_id)

# === 4. 在_input()函数中添加技能配置快捷键 ===
func handle_skill_config_input(event: InputEvent):
	"""处理技能配置相关输入（在player_action.gd的_input()中调用）"""
	# if event is InputEventKey and event.pressed:
	#     if event.keycode == KEY_TAB:  # 使用Tab键打开技能配置
	#         show_skill_config()
	pass

# === 5. 添加辅助函数 ===
func add_dash_visual_effects():
	"""添加闪避技能的视觉效果"""
	# 创建残影效果
	create_dash_afterimage()
	
	# 添加粒子效果
	create_dash_particles()
	
	# 屏幕震动效果
	add_screen_shake()

func create_dash_afterimage():
	"""创建闪避残影效果"""
	# TODO: 实现残影效果
	# 可以创建一个半透明的玩家精灵副本
	# 然后让它逐渐消失
	pass

func create_dash_particles():
	"""创建闪避粒子效果"""
	# TODO: 实现粒子效果
	# 可以在起始位置和结束位置添加粒子效果
	pass

func add_screen_shake():
	"""添加屏幕震动效果"""
	# TODO: 实现屏幕震动
	# 可以通过摄像头的轻微震动来增强冲击感
	pass

func play_dash_sound():
	"""播放闪避音效"""
	# TODO: 播放闪避音效
	# 可以播放风声或者冲刺音效
	pass

func update_skill_ui_cooldown(skill_id: String, cooldown_time: float):
	"""更新技能UI冷却显示"""
	# TODO: 更新UI显示技能冷却状态
	# 可以显示冷却进度条或倒计时
	pass

func update_skill_ui_ready(skill_id: String):
	"""更新技能UI就绪显示"""
	# TODO: 更新UI显示技能就绪状态
	# 可以恢复技能图标的正常显示
	pass

func show_skill_config():
	"""显示技能配置窗口"""
	# if not skill_config_ui:
	#     skill_config_ui = SkillHotkeyConfig.new()
	#     get_parent().add_child(skill_config_ui)
	#     skill_config_ui.config_confirmed.connect(_on_skill_config_confirmed)
	#     skill_config_ui.config_cancelled.connect(_on_skill_config_cancelled)
	# 
	# skill_config_ui.show_config()
	pass

func _on_skill_config_confirmed():
	"""技能配置确认"""
	print("技能配置已保存")
	# 可以在这里保存配置到文件

func _on_skill_config_cancelled():
	"""技能配置取消"""
	print("技能配置已取消")

# === 6. 获取玩家面向方向的方法 ===
func get_facing_direction() -> Vector2:
	"""获取玩家面向方向（在player_action.gd中实现）"""
	# 这个方法应该在player_action.gd中实现
	# 基于sprite_direction_right变量返回方向
	# if sprite_direction_right:
	#     return Vector2.RIGHT
	# else:
	#     return Vector2.LEFT
	return Vector2.RIGHT

# === 集成步骤说明 ===
"""
将主动技能系统集成到现有player_action.gd的步骤：

1. 在player_action.gd的变量声明部分添加：
   var skill_manager: ActiveSkillManager
   var skill_config_ui: SkillHotkeyConfig

2. 在_ready()函数的末尾添加：
   setup_skill_system()

3. 在_input()函数中添加：
   handle_skill_config_input(event)

4. 复制本文件中的所有函数到player_action.gd中

5. 根据需要实现TODO标记的功能

6. 测试技能系统是否正常工作

注意事项：
- 确保Global.ActiveSkillManager已正确初始化
- 技能系统只在非城镇环境下工作
- 可以根据游戏需求调整技能效果和UI显示
- 建议先使用测试脚本验证系统功能
"""

# === 完整的集成示例代码 ===
"""
以下是在player_action.gd中需要添加的完整代码示例：

# 在变量声明部分添加
var skill_manager: ActiveSkillManager
var skill_config_ui: SkillHotkeyConfig

# 在_ready()函数末尾添加
setup_skill_system()

# 在_input()函数中添加
if event is InputEventKey and event.pressed:
    if event.keycode == KEY_TAB:
        show_skill_config()

# 添加get_facing_direction方法
func get_facing_direction() -> Vector2:
    if sprite_direction_right:
        return Vector2.RIGHT
    else:
        return Vector2.LEFT

# 然后复制本文件中的所有函数
"""