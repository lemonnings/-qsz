extends Control

# UI组件引用
@export var point_label: Label
@export var cultivation_layer: CanvasLayer
@export var tip: Node

# 8个修炼项目的按钮和标签
@export var cultivation_buttons: Array[Button] = []
@export var cultivation_labels: Array[Label] = []

# 修炼项目配置
var cultivation_items = [
	{"name": "破虚", "type": "atk", "level_var": "cultivation_poxu_level", "unlock_progress": 0},
	{"name": "玄元", "type": "hp", "level_var": "cultivation_xuanyuan_level", "unlock_progress": 0},
	{"name": "流光", "type": "atk_speed", "level_var": "cultivation_liuguang_level", "unlock_progress": 1},
	{"name": "化灵", "type": "spirit_gain", "level_var": "cultivation_hualing_level", "unlock_progress": 2},
	{"name": "锋锐", "type": "crit_chance", "level_var": "cultivation_fengrui_level", "unlock_progress": 3},
	{"name": "护体", "type": "damage_reduction", "level_var": "cultivation_huti_level", "unlock_progress": 4},
	{"name": "追风", "type": "move_speed", "level_var": "cultivation_zhuifeng_level", "unlock_progress": 5},
	{"name": "烈劲", "type": "crit_damage", "level_var": "cultivation_liejin_level", "unlock_progress": 6}
]

# 修炼等级变量名映射
var cultivation_level_vars = [
	"cultivation_poxu_level",
	"cultivation_xuanyuan_level", 
	"cultivation_liuguang_level",
	"cultivation_hualing_level",
	"cultivation_fengrui_level",
	"cultivation_huti_level",
	"cultivation_zhuifeng_level",
	"cultivation_liejin_level"
]

var transition_tween: Tween

func _ready() -> void:
	# 设置音效使用SFX总线
	setup_audio_buses()
	# 更新界面显示
	update_cultivation_display()
	# 连接按钮信号
	connect_button_signals()

func setup_audio_buses() -> void:
	# 设置所有音效使用SFX总线主菜单 新的游戏 读取存档 设置 
	if has_node("LevelUP"):
		$LevelUP.bus = "SFX"
	if has_node("Buzzer"):
		$Buzzer.bus = "SFX"

func _process(_delta: float) -> void:
	if point_label:
		point_label.text = "剩余Point  " + str(Global.total_points)

func get_cultivation_level(level_var: String) -> int:
	# 直接从Global获取修炼等级
	return Global.get(level_var)

func set_cultivation_level(level_var: String, value: int) -> void:
	# 直接设置Global中的修炼等级
	Global.set(level_var, value)
	# 触发游戏保存
	Global.save_game()

func connect_button_signals() -> void:
	# 连接每个修炼按钮的信号
	for i in range(cultivation_buttons.size()):
		if cultivation_buttons[i]:
			cultivation_buttons[i].pressed.connect(_on_cultivation_button_pressed.bind(i))
			cultivation_buttons[i].mouse_entered.connect(_on_cultivation_button_mouse_entered.bind(i))
			cultivation_buttons[i].mouse_exited.connect(_on_cultivation_button_mouse_exited.bind(i))

func update_cultivation_display() -> void:
	# 更新所有修炼项目的显示
	for i in range(cultivation_items.size()):
		update_single_cultivation_display(i)

func update_single_cultivation_display(index: int) -> void:
	if index >= cultivation_items.size():
		return
	
	var item = cultivation_items[index]
	var is_unlocked = Global.cultivation_unlock_progress >= item["unlock_progress"]
	
	# 更新按钮状态
	if index < cultivation_buttons.size() and cultivation_buttons[index]:
		cultivation_buttons[index].disabled = !is_unlocked
		cultivation_buttons[index].text = item["name"]
		if !is_unlocked:
			cultivation_buttons[index].text += "\n(未解锁)"
	
	# 更新标签显示
	if index < cultivation_labels.size() and cultivation_labels[index]:
		if is_unlocked:
			var current_level = get_cultivation_level(item["level_var"])
			var next_level_exp = get_cultivation_exp_for_level(current_level)
			var current_bonus = get_cultivation_bonus_text(item["type"], current_level)
			var next_bonus = get_cultivation_bonus_text(item["type"], current_level + 1)
			
			cultivation_labels[index].text = "Level " + str(current_level) + "\n需 " + str(next_level_exp) + " Point\n当前 " + current_bonus + "\n下一级 " + next_bonus
			cultivation_labels[index].visible = false  # 默认隐藏，鼠标悬停时显示
		else:
			cultivation_labels[index].text = "需要解锁进度: " + str(item["unlock_progress"])
			cultivation_labels[index].visible = false

func get_cultivation_exp_for_level(level: int) -> int:
	# 参考menu.gd中的升级公式，修炼系统使用更高的消耗
	# 
	level = level + 1
	var base_exp = 50
	var increment = 25
	var multiplier = 1.15
	var exp_now = base_exp
	for i in range(1, level):
		exp_now = ceil((exp_now + increment) * multiplier)
	return exp_now

func get_cultivation_bonus_text(type: String, level: int) -> String:
	# 根据修炼类型返回加成文本
	match type:
		"atk":
			return "+" + str(level * 2) + " 攻击力"
		"hp":
			return "+" + str(level * 5) + " 生命值"
		"atk_speed":
			return "+" + str(level * 3) + "% 攻速"
		"spirit_gain":
			return "+" + str(level * 5) + "% 灵气获取"
		"crit_chance":
			return "+" + str(level * 0.5) + "% 暴击率"
		"damage_reduction":
			return "+" + str(level * 0.3) + "% 减伤率"
		"move_speed":
			return "+" + str(level * 2) + "% 移速"
		"crit_damage":
			return "+" + str(level * 1) + "% 暴击伤害"
		_:
			return "+0"

func get_cultivation_bonus_value(type: String, level: int) -> float:
	# 返回实际的加成数值
	match type:
		"atk":
			return level * 2.0
		"hp":
			return level * 5.0
		"atk_speed":
			return level * 0.03  # 3%转换为0.03
		"spirit_gain":
			return level * 0.05  # 5%转换为0.05
		"crit_chance":
			return level * 0.005  # 0.5%转换为0.005
		"damage_reduction":
			return level * 0.003  # 0.3%转换为0.003
		"move_speed":
			return level * 0.02  # 2%转换为0.02
		"crit_damage":
			return level * 0.01  # 1%转换为0.01
		_:
			return 0.0

func _on_cultivation_button_pressed(index: int) -> void:
	if index >= cultivation_items.size():
		return
	
	var item = cultivation_items[index]
	var is_unlocked = Global.cultivation_unlock_progress >= item["unlock_progress"]
	
	if !is_unlocked:
		if tip:
			tip.start_animation('修炼项目未解锁！', 0.25)
		return
	
	var current_level = get_cultivation_level(item["level_var"])
	var next_level_exp = get_cultivation_exp_for_level(current_level)
	
	if Global.total_points >= next_level_exp:
		# 升级成功
		set_cultivation_level(item["level_var"], current_level + 1)
		Global.total_points -= next_level_exp
		
		# 播放升级音效（如果存在）
		if has_node("LevelUP"):
			$LevelUP.play()
		
		# 显示成功提示
		if tip:
			tip.start_animation('修炼成功！', 0.25)
		
		# 更新显示
		update_single_cultivation_display(index)
	else:
		# Point不足
		if tip:
			tip.start_animation('Point不足！', 0.25)
		# 播放错误音效（如果存在）
		if has_node("Buzzer"):
			$Buzzer.play()

func _on_cultivation_button_mouse_entered(index: int) -> void:
	if index < cultivation_labels.size() and cultivation_labels[index]:
		cultivation_labels[index].visible = true

func _on_cultivation_button_mouse_exited(index: int) -> void:
	if index < cultivation_labels.size() and cultivation_labels[index]:
		cultivation_labels[index].visible = false

# 获取修炼加成总和（供其他系统调用）
func get_total_cultivation_bonus(type: String) -> float:
	var total_bonus = 0.0
	for item in cultivation_items:
		if item["type"] == type:
			var level = get_cultivation_level(item["level_var"])
			total_bonus += get_cultivation_bonus_value(type, level)
	return total_bonus

# 界面切换相关函数
func show_cultivation_interface() -> void:
	if cultivation_layer:
		_transition_to_layer(cultivation_layer, [])

func hide_cultivation_interface() -> void:
	if cultivation_layer:
		cultivation_layer.visible = false

func _transition_to_layer(target_layer: CanvasLayer, hide_layers: Array) -> void:
	if transition_tween:
		transition_tween.kill()
	
	transition_tween = create_tween()
	transition_tween.set_parallel(true)
	
	# 淡出当前显示的层
	for layer in hide_layers:
		if layer and layer.visible:
			for child in layer.get_children():
				if child.has_method("set_modulate"):
					transition_tween.tween_property(child, "modulate:a", 0.0, 0.125)
	
	# 等待淡出完成后切换显示状态
	transition_tween.tween_callback(_switch_to_cultivation_layer.bind(target_layer, hide_layers)).set_delay(0.125)
	
	# 淡入目标层
	if target_layer:
		target_layer.visible = true
		for child in target_layer.get_children():
			if child.has_method("set_modulate"):
				child.modulate.a = 0.0
				transition_tween.tween_property(child, "modulate:a", 1.0, 0.125).set_delay(0.125)

func _switch_to_cultivation_layer(target_layer: CanvasLayer, hide_layers: Array) -> void:
	# 隐藏旧层
	for layer in hide_layers:
		if layer:
			layer.visible = false
			# 重置透明度
			for child in layer.get_children():
				if child.has_method("set_modulate"):
					child.modulate.a = 1.0
