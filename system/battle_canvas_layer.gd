extends CanvasLayer

# ============== UI 组件引用 ==============
@export var hp_bar: ProgressBar
@export var sheild_bar: ProgressBar
@export var exp_bar: ProgressBar
@export var map_mechanism_bar: ProgressBar
@export var hp_num: Label
@export var score_label: Label
@export var gameover_label: Label
@export var victory_label: Label
@export var attr_label: RichTextLabel

@export var buff_box: HBoxContainer

@export var now_time: Label
@export var current_multi: Label
@export var now_lv: Label
@export var exit_button: Button

# 技能图标
@export var skill1: TextureButton
@export var skill2: TextureButton
@export var skill3: TextureButton
@export var skill4: TextureButton
@export var skill5: TextureButton
@export var skill6: TextureButton
@export var skill7: TextureButton
@export var skill8: TextureButton
@export var skill9: TextureButton

# 主动技能
@export var active1: TextureButton
@export var active2: TextureButton
@export var active3: TextureButton

# 升级选择UI
@export var lv_up_change: Node2D
@export var lv_up_change_b1: Button
@export var lv_up_change_b2: Button
@export var lv_up_change_b3: Button

# 纹章相关
@export var emblem1: TextureRect
@export var emblem1_panel: Panel
@export var emblem1_detail: RichTextLabel
@export var emblem2: TextureRect
@export var emblem2_panel: Panel
@export var emblem2_detail: RichTextLabel
@export var emblem3: TextureRect
@export var emblem3_panel: Panel
@export var emblem3_detail: RichTextLabel
@export var emblem4: TextureRect
@export var emblem4_panel: Panel
@export var emblem4_detail: RichTextLabel
@export var emblem5: TextureRect
@export var emblem5_panel: Panel
@export var emblem5_detail: RichTextLabel
@export var emblem6: TextureRect
@export var emblem6_panel: Panel
@export var emblem6_detail: RichTextLabel
@export var emblem7: TextureRect
@export var emblem7_panel: Panel
@export var emblem7_detail: RichTextLabel
@export var emblem8: TextureRect
@export var emblem8_panel: Panel
@export var emblem8_detail: RichTextLabel

# 技能标签
@export var skill_label1: RichTextLabel

# ============== 管理器引用 ==============
var level_up_manager: LevelUpManager
var emblem_manager: EmblemManager

# ============== 信号 ==============
signal refresh_button_pressed(button_id: int)
signal skill_icon_hovered(skill_id: int, is_hovered: bool)

# ============== 初始化 ==============
func _ready() -> void:
	_init_managers()
	_connect_signals()
	_init_active_skills()

func _init_managers() -> void:
	# 初始化升级管理器
	level_up_manager = LevelUpManager.new()
	add_child(level_up_manager)
	var skill_nodes_array: Array[TextureButton] = [skill1, skill2, skill3, skill4, skill5, skill6, skill7, skill8, skill9]
	level_up_manager.initialize(self, lv_up_change, lv_up_change_b1, lv_up_change_b2, lv_up_change_b3, self, skill_nodes_array)
	
	# 连接刷新按钮信号
	_connect_refresh_buttons()
	
	# 初始化纹章管理器
	emblem_manager = EmblemManager.new()
	add_child(emblem_manager)
	emblem_manager.setup_emblem_container(buff_box)
	var icons := [emblem1, emblem2, emblem3, emblem4, emblem5, emblem6, emblem7, emblem8]
	var panels := [emblem1_panel, emblem2_panel, emblem3_panel, emblem4_panel, emblem5_panel, emblem6_panel, emblem7_panel, emblem8_panel]
	var details := [emblem1_detail, emblem2_detail, emblem3_detail, emblem4_detail, emblem5_detail, emblem6_detail, emblem7_detail, emblem8_detail]
	emblem_manager.setup_emblem_ui(icons, panels, details)
	
	# 连接纹章鼠标事件信号
	_connect_emblem_signals(icons)
	
	# 连接技能图标鼠标事件信号
	_connect_skill_icon_signals()
	
	# 连接主动技能图标鼠标事件信号
	_connect_active_skill_signals()

func _connect_signals() -> void:
	Global.connect("skill_attack_speed_updated", Callable(self, "_on_skill_attack_speed_updated"))
	Global.connect("player_lv_up", Callable(self, "_on_level_up"))
	Global.connect("level_up_selection_complete", Callable(self, "_check_and_process_pending_level_ups"))
	
	# 连接主动技能信号
	if Global.ActiveSkillManager:
		Global.ActiveSkillManager.skill_cooldown_started.connect(_on_active_skill_cooldown_started)
		Global.ActiveSkillManager.skill_cooldown_finished.connect(_on_active_skill_cooldown_finished)

## 连接刷新按钮信号
func _connect_refresh_buttons() -> void:
	# 刷新按钮是升级按钮的子节点
	var refresh_button1 = lv_up_change_b1.get_node_or_null("RefreshButton")
	var refresh_button2 = lv_up_change_b2.get_node_or_null("RefreshButton2")
	var refresh_button3 = lv_up_change_b3.get_node_or_null("RefreshButton3")
	
	if refresh_button1:
		refresh_button1.process_mode = Node.PROCESS_MODE_ALWAYS
		if not refresh_button1.pressed.is_connected(_on_refresh_button_1_pressed):
			refresh_button1.pressed.connect(_on_refresh_button_1_pressed)
	
	if refresh_button2:
		refresh_button2.process_mode = Node.PROCESS_MODE_ALWAYS
		if not refresh_button2.pressed.is_connected(_on_refresh_button_2_pressed):
			refresh_button2.pressed.connect(_on_refresh_button_2_pressed)
	
	if refresh_button3:
		refresh_button3.process_mode = Node.PROCESS_MODE_ALWAYS
		if not refresh_button3.pressed.is_connected(_on_refresh_button_3_pressed):
			refresh_button3.pressed.connect(_on_refresh_button_3_pressed)

func _on_refresh_button_1_pressed() -> void:
	handle_refresh_button(1)

func _on_refresh_button_2_pressed() -> void:
	handle_refresh_button(2)

func _on_refresh_button_3_pressed() -> void:
	handle_refresh_button(3)

## 连接纹章鼠标事件信号
func _connect_emblem_signals(icons: Array) -> void:
	for i in range(icons.size()):
		var icon = icons[i]
		if icon:
			var emblem_index = i + 1 # emblem 索引从 1 开始
			icon.mouse_entered.connect(_on_emblem_mouse_entered.bind(emblem_index))
			icon.mouse_exited.connect(_on_emblem_mouse_exited.bind(emblem_index))

func _on_emblem_mouse_entered(emblem_index: int) -> void:
	show_emblem_detail(emblem_index)

func _on_emblem_mouse_exited(emblem_index: int) -> void:
	hide_emblem_detail(emblem_index)

## 连接技能图标鼠标事件信号
func _connect_skill_icon_signals() -> void:
	var skill_icons := [skill1, skill2, skill3, skill4, skill5, skill6, skill7, skill8, skill9]
	for i in range(skill_icons.size()):
		var icon = skill_icons[i]
		if icon:
			var skill_index = i + 1 # skill 索引从 1 开始
			icon.mouse_entered.connect(_on_skill_icon_mouse_entered.bind(skill_index))
			icon.mouse_exited.connect(_on_skill_icon_mouse_exited.bind(skill_index))

func _on_skill_icon_mouse_entered(skill_index: int) -> void:
	if skill_index == 1 and PC.player_instance:
		show_skill1_label(PC.player_instance)
	# TODO: 其他技能的详情显示可在此扩展

func _on_skill_icon_mouse_exited(skill_index: int) -> void:
	if skill_index == 1:
		hide_skill1_label()
	# TODO: 其他技能的详情隐藏可在此扩展

## 连接主动技能图标鼠标事件信号
func _connect_active_skill_signals() -> void:
	var active_icons := [active1, active2, active3]
	var slot_keys := ["space", "q", "e"]
	for i in range(active_icons.size()):
		var icon = active_icons[i]
		if icon:
			var slot_key = slot_keys[i]
			icon.mouse_entered.connect(_on_active_skill_mouse_entered.bind(slot_key))
			icon.mouse_exited.connect(_on_active_skill_mouse_exited)

func _on_active_skill_mouse_entered(slot_key: String) -> void:
	show_active_skill_label(slot_key)

func _on_active_skill_mouse_exited() -> void:
	hide_active_skill_label()

## 显示主动技能详情
func show_active_skill_label(slot_key: String) -> void:
	# 获取槽位绑定的技能
	var skill_config = Global.player_now_active_skill.get(slot_key, {})
	var skill_name = skill_config.get("name", "")
	if skill_name == "":
		return
	
	# 获取技能等级数据
	var skill_data = Global.player_active_skill_data.get(skill_name, {})
	var level = skill_data.get("level", 1)
	
	var text = ""
	
	match skill_name:
		"dodge":
			text = _build_dodge_skill_text(level)
		"random_strike":
			text = _build_random_strike_skill_text(level)
		_:
			text = "[未知技能]"
	
	skill_label1.text = text
	skill_label1.visible = true

## 隐藏主动技能详情
func hide_active_skill_label() -> void:
	skill_label1.visible = false

## 构建闪避技能详情文本
func _build_dodge_skill_text(level: int) -> String:
	var text = "[font_size=24]闪避  LV. " + str(level) + "[/font_size]\n"
	text += "快捷键：Space\n\n"
	text += "效果：向移动方向位移一小段距离并获得无敌\n\n"
	
	# 计算当前无敌时间
	var invincible_time = 0.5
	for lv in [2, 4, 6, 8, 10, 12, 14]:
		if level >= lv:
			invincible_time += 0.1
	text += "无敌时间：" + ("%.1f" % invincible_time) + "秒\n"
	
	# 计算当前冷却时间
	var cooldown = 6.0
	for lv in [3, 5, 7, 9, 11, 13, 15]:
		if level >= lv:
			cooldown -= 0.5
	cooldown = max(1.0, cooldown)
	# 应用冷却缩减
	var final_cooldown = cooldown * (1 - PC.cooldown)
	text += "冷却时间：" + ("%.1f" % final_cooldown) + "秒"
	if PC.cooldown > 0:
		text += " [color=#88ff88](-" + str(int(PC.cooldown * 100)) + "%)[/color]"
	
	return text

## 构建乱击技能详情文本
func _build_random_strike_skill_text(level: int) -> String:
	var text = "[font_size=24]乱击  LV. " + str(level) + "[/font_size]\n"
	text += "快捷键：Q\n\n"
	text += "效果：向随机方向每0.1秒射出剑气\n\n"
	
	# 计算当前伤害倍率
	var damage_multi = 50
	for lv in [2, 5, 8, 11, 14]:
		if level >= lv:
			damage_multi += 5
	text += "伤害倍率：" + str(damage_multi) + "%\n"
	
	# 计算当前子弹数量
	var bullet_count = 10
	for lv in [3, 6, 9, 12, 15]:
		if level >= lv:
			bullet_count += 1
	text += "剑气数量：" + str(bullet_count) + "发\n"
	
	# 计算当前冷却时间
	var cooldown = 20.0
	for lv in [4, 7, 10, 13]:
		if level >= lv:
			cooldown -= 1.0
	cooldown = max(5.0, cooldown)
	# 应用冷却缩减
	var final_cooldown = cooldown * (1 - PC.cooldown)
	text += "冷却时间：" + ("%.1f" % final_cooldown) + "秒"
	if PC.cooldown > 0:
		text += " [color=#88ff88](-" + str(int(PC.cooldown * 100)) + "%)[/color]"
	
	return text

func _init_active_skills() -> void:
	"""初始化主动技能UI"""
	# 加载主动技能图标脚本
	var active_skill_script = preload("res://Script/skill/active_skill_icon.gd")
	
	# 配置三个主动技能槽位：空格、Q、E
	if active1:
		# 替换脚本
		active1.set_script(active_skill_script)
		# 调用_ready模拟初始化
		if active1.has_method("_setup_ui_nodes"):
			active1._setup_ui_nodes()
		if active1.has_method("setup_active_skill"):
			active1.setup_active_skill("space", "Space")
		active1.visible = _has_skill_in_slot("space")
	
	if active2:
		active2.set_script(active_skill_script)
		if active2.has_method("_setup_ui_nodes"):
			active2._setup_ui_nodes()
		if active2.has_method("setup_active_skill"):
			active2.setup_active_skill("q", "Q")
		active2.visible = _has_skill_in_slot("q")
	
	if active3:
		active3.set_script(active_skill_script)
		if active3.has_method("_setup_ui_nodes"):
			active3._setup_ui_nodes()
		if active3.has_method("setup_active_skill"):
			active3.setup_active_skill("e", "E")
		active3.visible = _has_skill_in_slot("e")

func _has_skill_in_slot(slot: String) -> bool:
	"""检查槽位是否有技能"""
	var skill_config = Global.player_now_active_skill.get(slot, {})
	return skill_config.get("name", "") != ""

func _on_active_skill_cooldown_started(skill_id: String, cooldown_time: float) -> void:
	"""主动技能冷却开始"""
	# UI更新由active_skill_icon.gd自己处理
	pass

func _on_active_skill_cooldown_finished(skill_id: String) -> void:
	"""主动技能冷却完成"""
	# UI更新由active_skill_icon.gd自己处理
	pass

func refresh_active_skills() -> void:
	"""刷新主动技能UI（当技能配置变化时调用）"""
	_init_active_skills()

# ============== UI 更新方法 ==============

## 更新血条
func update_hp_bar(current_hp: int, max_hp: int, current_shield: int) -> void:
	var target_value = (float(current_hp) / max_hp) * 100
	if hp_bar.value != target_value:
		if abs(target_value - hp_bar.value) > 2:
			var tween = create_tween()
			tween.tween_property(hp_bar, "value", target_value, 0.15)
		else:
			hp_bar.value = target_value
	
	var shield_display = min(current_shield, max_hp)
	var shield_target_value = (float(shield_display) / max_hp) * 100
	if sheild_bar.value != shield_target_value:
		if abs(shield_target_value - sheild_bar.value) > 2:
			var shield_tween = create_tween()
			shield_tween.tween_property(sheild_bar, "value", shield_target_value, 0.15)
		else:
			sheild_bar.value = shield_target_value
	
	var hp_value = current_hp
	if current_hp <= 0:
		hp_value = 0
	
	if current_shield > 0:
		hp_num.text = str(hp_value) + " (+" + str(current_shield) + ") / " + str(max_hp)
	else:
		hp_num.text = str(hp_value) + " / " + str(max_hp)

## 更新经验条
func update_exp_bar(current_exp: int, required_exp: int) -> void:
	var target_value = (float(current_exp) / required_exp) * 100
	if exp_bar.value != target_value:
		if abs(target_value - exp_bar.value) > 2:
			var tween = create_tween()
			tween.tween_property(exp_bar, "value", target_value, 0.15)
		else:
			exp_bar.value = target_value

## 更新机关进度条
func update_mechanism_bar(current_value: float, max_value: float, is_boss_triggered: bool = false) -> void:
	if not is_boss_triggered:
		map_mechanism_bar.value = (current_value / max_value) * 100
	else:
		map_mechanism_bar.value = 100

## 更新时间显示
func update_time_display(real_time: float) -> void:
	if now_time:
		var minutes = int(real_time) / 60
		var seconds = int(real_time) % 60
		now_time.text = "%02d : %02d" % [minutes, seconds]

## 更新等级显示
func update_level_display(level: int) -> void:
	now_lv.text = "Lv." + str(level)

## 更新分数显示
func update_score_display(point: int) -> void:
	var formatted_point: String
	if point >= 10000000:
		formatted_point = "%.3fm 真气" % (point / 1000000.0)
	elif point >= 100000:
		formatted_point = "%.2fk 真气" % (point / 1000.0)
	else:
		formatted_point = str(point)
	score_label.text = formatted_point

## 更新DPS显示
func update_dps_display() -> void:
	var current_dps = Global.get_current_dps()
	var formatted_dps = "%.1f" % current_dps
	current_multi.text = "DPS: " + formatted_dps

## 更新升级选择UI可见性
func update_lv_up_visibility() -> void:
	if Global.is_level_up == false:
		lv_up_change.visible = false

# ============== 技能图标更新 ==============

## 初始化主技能图标
func init_main_skill(fire_speed_wait_time: float) -> void:
	skill1.visible = true
	skill1.update_skill(1, fire_speed_wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/slash.png")

## 检查并更新技能图标可见性
func check_and_update_skill_icons(player_node: Node) -> void:
	if PC.has_branch and PC.first_has_branch:
		skill2.visible = true
		skill2.update_skill(2, player_node.branch_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/branch.png")
		PC.first_has_branch = false

	if PC.has_moyan and PC.first_has_moyan:
		skill3.visible = true
		skill3.update_skill(3, player_node.moyan_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/moyan.png")
		PC.first_has_moyan = false

	if PC.has_riyan and PC.first_has_riyan:
		skill4.visible = true
		skill4.update_skill(4, player_node.riyan_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/riyan.png")
		PC.first_has_riyan = false

	if PC.has_ringFire and PC.first_has_ringFire:
		skill5.visible = true
		skill5.update_skill(5, player_node.ringFire_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/ringFire.png")
		PC.first_has_ringFire = false

	if PC.has_thunder and PC.first_has_thunder:
		skill6.visible = true
		skill6.update_skill(6, player_node.thunder_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/branch.png")
		PC.first_has_thunder = false

	if PC.has_bloodwave and PC.first_has_bloodwave:
		skill7.visible = true
		skill7.update_skill(7, player_node.bloodwave_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/branch.png")
		PC.first_has_bloodwave = false
	
	if PC.has_bloodboardsword and PC.first_has_bloodboardsword:
		skill8.visible = true
		skill8.update_skill(8, player_node.bloodboardsword_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/branch.png")
		PC.first_has_bloodboardsword = false
	
	if PC.has_ice and PC.first_has_ice:
		skill9.visible = true
		skill9.update_skill(9, player_node.ice_flower_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/branch.png") # 需要确认是否有冰刺图标，暂时用branch
		PC.first_has_ice = false


## 更新技能冷却时间显示
func update_skill_cooldowns(player_node: Node) -> void:
	if skill1.visible:
		skill1.update_skill(1, player_node.fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/slash.png")
	
	if PC.has_branch and skill2.visible:
		skill2.update_skill(2, player_node.branch_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/branch.png")
	
	if PC.has_moyan and skill3.visible:
		skill3.update_skill(3, player_node.moyan_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/moyan.png")
	
	if PC.has_riyan and skill4.visible:
		skill4.update_skill(4, player_node.riyan_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/riyan.png")
	
	if PC.has_ringFire and skill5.visible:
		skill5.update_skill(5, player_node.ringFire_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/ringFire.png")
	
	if PC.has_thunder and skill6.visible:
		skill6.update_skill(6, player_node.thunder_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/branch.png")
	
	if PC.has_bloodwave and skill7.visible:
		skill7.update_skill(7, player_node.bloodwave_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/branch.png")
	
	if PC.has_bloodboardsword and skill8.visible:
		skill8.update_skill(8, player_node.bloodboardsword_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/branch.png")

	if PC.has_ice and skill9.visible:
		skill9.update_skill(9, player_node.ice_flower_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/branch.png")

func _on_skill_attack_speed_updated() -> void:
	# 需要获取player节点来更新，通过信号通知父场景
	if PC.player_instance:
		update_skill_cooldowns(PC.player_instance)

# ============== 属性标签显示 ==============

# 属性标签过渡动画 Tween
var attr_label_tween: Tween = null

# 开悟ID到中文名的映射
const REWARD_NAMES: Dictionary = {
	"R01": "血气", "SR01": "血气", "SSR01": "血气", "UR01": "血气",
	"R02": "破阵", "SR02": "破阵", "SSR02": "破阵", "UR02": "破阵",
	"R03": "惊鸿", "SR03": "惊鸿", "SSR03": "惊鸿", "UR03": "惊鸿",
	"R04": "踏风", "SR04": "踏风", "SSR04": "踏风", "UR04": "踏风",
	"R05": "沉静", "SR05": "沉静", "SSR05": "沉静", "UR05": "沉静",
	"R06": "炼体", "SR06": "炼体", "SSR06": "炼体", "UR06": "炼体",
	"R07": "健步", "SR07": "健步", "SSR07": "健步", "UR07": "健步",
	"R08": "蛮力", "SR08": "蛮力", "SSR08": "蛮力", "UR08": "蛮力",
	"R09": "天命", "SR09": "天命", "SSR09": "天命", "UR09": "天命",
	"R10": "融会贯通", "SR10": "融会贯通", "SSR10": "融会贯通", "UR10": "融会贯通",
	"R11": "行云", "SR11": "行云", "SSR11": "行云", "UR11": "行云",
	"R12": "加护", "SR12": "加护", "SSR12": "加护", "UR12": "加护",
	"R13": "归元", "SR13": "归元", "SSR13": "归元", "UR13": "归元",
	"R14": "精准", "SR14": "精准", "SSR14": "精准", "UR14": "精准",
	"R15": "致命", "SR15": "致命", "SSR15": "致命", "UR15": "致命",
	"R16": "优雅", "SR16": "优雅", "SSR16": "优雅", "UR16": "优雅",
	"R17": "凝势", "SR17": "凝势", "SSR17": "凝势", "UR17": "凝势",
	"R18": "破血", "SR18": "破血", "SSR18": "破血", "UR18": "破血",
	"R19": "坚守", "SR19": "坚守", "SSR19": "坚守", "UR19": "坚守",
	"R20": "唤物·幻灵", "SR20": "唤物·浮灵", "SSR20": "唤物·追魂", "UR20": "唤物·双极",
	"SR21": "唤物·愈灵", "SSR21": "唤物·护灵", "UR21": "唤物·生灵",
	"SR22": "唤物·谐灵", "SSR22": "唤物·灵律", "UR22": "唤物·灵枢",
	"R23": "唤物强化", "SR23": "唤物强化", "SSR23": "唤物强化", "UR23": "唤物强化",
	"R24": "唤物巨化", "SR24": "唤物巨化", "SSR24": "唤物巨化", "UR24": "唤物巨化",
	"R25": "唤物注能", "SR25": "唤物注能", "SSR25": "唤物注能", "UR25": "唤物注能",
	"SR26": "唤物扩充", "SSR26": "唤物扩充", "UR26": "唤物扩充",
	"SR27": "技艺·环", "SR30": "技艺·浪",
	"R28": "环·增伤", "SR28": "环·增伤", "SSR28": "环·增伤", "UR28": "环·增伤",
	"R29": "环·起势", "SR29": "环·起势", "SSR29": "环·起势", "UR29": "环·起势",
	"R31": "浪·增伤", "SR31": "浪·增伤", "SSR31": "浪·增伤", "UR31": "浪·增伤",
	"R32": "浪·起势", "SR32": "浪·起势", "SSR32": "浪·起势", "UR32": "浪·起势",
	"RSwordQi": "剑气强化", "SRSwordQi": "剑气强化", "SSRSwordQi": "剑气强化", "URSwordQi": "剑气强化",
	"SplitSwordQi1": "分光剑气", "SplitSwordQi2": "无上剑痕", "SplitSwordQi3": "穿云剑气", "SplitSwordQi4": "追踪剑气",
	"SplitSwordQi11": "分光剑气-逆", "SplitSwordQi12": "分光剑气-裂", "SplitSwordQi13": "分光剑气-环",
	"SplitSwordQi21": "无上剑痕-精", "SplitSwordQi22": "无上剑痕-复", "SplitSwordQi23": "无上剑痕-囚",
	"SplitSwordQi31": "穿云剑气-透", "SplitSwordQi32": "穿云剑气-利", "SplitSwordQi33": "穿云剑气-伤",
	"Branch": "世界树之枝", "Moyan": "魔焰", "RingFire": "炎轮", "Riyan": "赤曜",
	"RBranch": "树枝强化", "SRBranch": "树枝强化", "SSRBranch": "树枝强化", "URBranch": "树枝强化",
	"Rmoyan": "魔焰强化", "SRmoyan": "魔焰强化", "SSRmoyan": "魔焰强化", "URmoyan": "魔焰强化",
	"RRingFire": "炎轮强化", "SRRingFire": "炎轮强化", "SSRRingFire": "炎轮强化", "URRingFire": "炎轮强化",
	"RRiyan": "赤曜强化", "SRRiyan": "赤曜强化", "SSRRiyan": "赤曜强化", "URRiyan": "赤曜强化",
	"Branch1": "多重分裂", "Branch2": "冲势渐强", "Branch3": "枝繁叶茂", "Branch4": "重型树枝",
	"Branch11": "多重分裂-返", "Branch12": "多重分裂-刺", "Branch21": "冲势渐强-继", "Branch22": "冲势渐强-利", "Branch31": "枝繁叶茂-复",
	"Moyan1": "蓄能火球", "Moyan2": "速爆火球", "Moyan3": "巨大魔焰",
	"Moyan12": "速爆火球-极", "Moyan13": "蓄能火球-伤", "Moyan23": "巨大魔焰-速",
	"RingFire1": "分炎", "RingFire2": "轮转", "RingFire3": "灵焰", "RingFire4": "爆炎",
	"RingFire11": "分炎-暴", "RingFire44": "爆炎-破",
	"Riyan1": "炎甲", "Riyan2": "心能", "Riyan3": "生蕴", "Riyan4": "炎潮",
	"Riyan11": "炎甲-护", "Riyan22": "心能-极"
}

## 获取开悟的中文名列表
func _get_reward_chinese_names() -> String:
	var names: Array[String] = []
	for reward_id in PC.selected_rewards:
		if reward_id == "":
			continue
		if REWARD_NAMES.has(reward_id):
			var name = REWARD_NAMES[reward_id]
			if not names.has(name): # 避免重复名称
				names.append(name)
			else:
				# 相同名称的统计次数
				var count = 0
				for r_id in PC.selected_rewards:
					if REWARD_NAMES.has(r_id) and REWARD_NAMES[r_id] == name:
						count += 1
				if count > 1:
					# 更新为带数量的名称
					var idx = names.find(name)
					if idx >= 0:
						names[idx] = name + "x" + str(count)
		else:
			names.append(reward_id) # 未知的ID直接显示
	if names.is_empty():
		return "无"
	return ", ".join(names)

func show_attr_label() -> void:
	# 停止之前的动画
	if attr_label_tween and attr_label_tween.is_valid():
		attr_label_tween.kill()
	
	# 构建美化的属性文本
	var text = ""
	
	# ===== 基本属性 =====
	text += "[font_size=17][color=#87CEEB]═══ 基本属性 ═══[/color][/font_size]\n"
	text += "攻击：" + str(PC.pc_atk) + "    "
	text += "HP：" + str(PC.pc_hp) + "/" + str(PC.pc_max_hp) + "\n"
	text += "攻击速度：+" + str(int(PC.pc_atk_speed * 100)) + "%    "
	text += "移动速度：+" + str(int(PC.pc_speed * 100)) + "%\n"
	text += "暴击率：" + str(int(PC.crit_chance * 100)) + "%    "
	text += "暴击伤害：" + str(int(PC.crit_damage_multi * 100)) + "%\n"
	text += "减伤率：" + str(int(PC.damage_reduction_rate * 100)) + "%    "
	text += "天命：" + str(PC.now_lunky_level) + "\n"
	text += "[color=#FF6B6B]DPS：%.1f[/color]\n" % Global.get_current_dps()
	
	# ===== 次要属性 =====
	text += "[font_size=17][color=#98FB98]═══ 次要属性 ═══[/color][/font_size]\n"
	text += "攻击范围：+" + str(int(PC.bullet_size * 100)) + "%    "
	text += "体型大小：" + str(int(PC.body_size * 100)) + "%\n"
	text += "真气获取：+" + str(int(PC.point_multi * 100)) + "%    "
	text += "经验获取：+" + str(int(PC.exp_multi * 100)) + "%\n"
	text += "掉落率：+" + str(int(PC.drop_multi * 100)) + "%    "
	text += "最终伤害：+" + str(int(PC.pc_final_atk * 100)) + "%\n"
	text += "治疗加成：+" + str(int(PC.heal_multi * 100)) + "%    "
	text += "护盾加成：+" + str(int(PC.sheild_multi * 100)) + "%\n"
	text += "对小怪增伤：+" + str(int(PC.normal_monster_multi * 100)) + "%    "
	text += "对精英首领增伤：+" + str(int(PC.boss_multi * 100)) + "%\n"
	text += "主动技能冷却缩减：" + str(int(PC.cooldown * 100)) + "%    "
	text += "主动技能增伤：+" + str(int(PC.active_skill_multi * 100)) + "%\n"
	
	# ===== 技艺 =====
	if PC.ring_bullet_enabled or PC.wave_bullet_enabled:
		text += "[font_size=17][color=#DDA0DD]═══ 技艺 ═══[/color][/font_size]\n"
		# 技艺·环
		if PC.ring_bullet_enabled:
			text += "[color=#FFB6C1]【环】[/color] "
			text += "伤害：" + str(int(PC.ring_bullet_damage_multiplier * 100)) + "%  "
			text += "数量：" + str(PC.ring_bullet_count) + "  "
			text += "大小：" + str(int(PC.ring_bullet_size_multiplier * 100)) + "%  "
			text += "间隔：" + ("%.2f" % PC.ring_bullet_interval) + "秒\n"
		# 技艺·浪
		if PC.wave_bullet_enabled:
			text += "[color=#87CEFA]【浪】[/color] "
			text += "伤害：" + str(int(PC.wave_bullet_damage_multiplier * 100)) + "%  "
			text += "数量：" + str(PC.wave_bullet_count) + "  "
			text += "间隔：" + ("%.2f" % PC.wave_bullet_interval) + "秒\n"
	
	# ===== 召唤物 =====
	if PC.summon_count > 0 or PC.summon_count_max > 0:
		text += "[font_size=17][color=#E2CBF7]═══ 召唤物 ═══[/color][/font_size]\n"
		text += "当前数量：" + str(PC.summon_count) + "/" + str(PC.summon_count_max) + "    "
		text += "伤害倍率：" + str(int(PC.summon_damage_multiplier * 100)) + "%\n"
		text += "弹体大小：" + str(int(PC.summon_bullet_size_multiplier * 100)) + "%    "
		text += "攻击间隔倍率：" + str(int(PC.summon_interval_multiplier * 100)) + "%\n"
	
	# ===== 开悟获取 =====
	text += "[font_size=17][color=#FFA500]═══ 开悟获取 ═══[/color][/font_size]\n"
	text += _get_reward_chinese_names()
	
	attr_label.text = text
	
	# 设置初始透明度并显示
	if not attr_label.visible:
		attr_label.modulate.a = 0.0
		attr_label.visible = true
	
	# 渐入动画
	attr_label_tween = create_tween()
	attr_label_tween.tween_property(attr_label, "modulate:a", 1.0, 0.3)

func hide_attr_label() -> void:
	# 停止之前的动画
	if attr_label_tween and attr_label_tween.is_valid():
		attr_label_tween.kill()
	
	# 渐出动画
	attr_label_tween = create_tween()
	attr_label_tween.tween_property(attr_label, "modulate:a", 0.0, 0.3)
	attr_label_tween.tween_callback(func(): attr_label.visible = false)

# ============== 技能标签显示 ==============

func show_skill1_label(player_node: Node) -> void:
	var skill1Text = "[font_size=17]剑气  LV. " + str(PC.main_skill_swordQi) + "[/font_size]"
	skill1Text = skill1Text + "\n基本伤害倍率： " + str((PC.main_skill_swordQi_damage * 100)) + "%"
	skill1Text = skill1Text + "\n基本攻击速度：" + str(("%.2f" % (player_node.fire_speed.wait_time))) + "秒/次"
	skill1Text = skill1Text + "\n附加效果："
	if PC.selected_rewards.has("SplitSwordQi1"):
		skill1Text = skill1Text + "\n分光剑气"
	if PC.selected_rewards.has("SplitSwordQi2"):
		skill1Text = skill1Text + "\n无上剑痕"
	if PC.selected_rewards.has("SplitSwordQi3"):
		skill1Text = skill1Text + "\n穿云剑气"
	if PC.selected_rewards.has("SplitSwordQi4"):
		skill1Text = skill1Text + "\n追踪剑气"
	if PC.selected_rewards.has("SplitSwordQi11"):
		skill1Text = skill1Text + "\n分光剑气-逆"
	if PC.selected_rewards.has("SplitSwordQi12"):
		skill1Text = skill1Text + "\n分光剑气-裂"
	if PC.selected_rewards.has("SplitSwordQi13"):
		skill1Text = skill1Text + "\n分光剑气-环"
	if PC.selected_rewards.has("SplitSwordQi21"):
		skill1Text = skill1Text + "\n无上剑痕-精"
	if PC.selected_rewards.has("SplitSwordQi22"):
		skill1Text = skill1Text + "\n无上剑痕-复"
	if PC.selected_rewards.has("SplitSwordQi23"):
		skill1Text = skill1Text + "\n无上剑痕-囚"
	if PC.selected_rewards.has("SplitSwordQi31"):
		skill1Text = skill1Text + "\n穿云剑气-透"
	if PC.selected_rewards.has("SplitSwordQi32"):
		skill1Text = skill1Text + "\n穿云剑气-利"
	if PC.selected_rewards.has("SplitSwordQi33"):
		skill1Text = skill1Text + "\n穿云剑气-伤"
	
	skill_label1.text = skill1Text
	skill_label1.visible = true

func hide_skill1_label() -> void:
	skill_label1.visible = false

# ============== 纹章鼠标事件 ==============

func show_emblem_detail(emblem_index: int) -> void:
	var detail: RichTextLabel
	var panel: Panel
	match emblem_index:
		1: detail = emblem1_detail; panel = emblem1_panel
		2: detail = emblem2_detail; panel = emblem2_panel
		3: detail = emblem3_detail; panel = emblem3_panel
		4: detail = emblem4_detail; panel = emblem4_panel
		5: detail = emblem5_detail; panel = emblem5_panel
		6: detail = emblem6_detail; panel = emblem6_panel
		7: detail = emblem7_detail; panel = emblem7_panel
		8: detail = emblem8_detail; panel = emblem8_panel
		_: return
	
	if detail and detail.text != "":
		detail.visible = true
		panel.visible = true

func hide_emblem_detail(emblem_index: int) -> void:
	var detail: RichTextLabel
	var panel: Panel
	match emblem_index:
		1: detail = emblem1_detail; panel = emblem1_panel
		2: detail = emblem2_detail; panel = emblem2_panel
		3: detail = emblem3_detail; panel = emblem3_panel
		4: detail = emblem4_detail; panel = emblem4_panel
		5: detail = emblem5_detail; panel = emblem5_panel
		6: detail = emblem6_detail; panel = emblem6_panel
		7: detail = emblem7_detail; panel = emblem7_panel
		8: detail = emblem8_detail; panel = emblem8_panel
		_: return
	
	if detail:
		detail.visible = false
		panel.visible = false

# ============== 游戏结果显示 ==============

func show_game_over() -> void:
	gameover_label.visible = true

func show_victory() -> void:
	victory_label.visible = true

# ============== 升级管理 ==============

func _on_level_up(main_skill_name: String = '', refresh_id: int = 0) -> void:
	level_up_manager.handle_level_up(main_skill_name, refresh_id, get_tree(), get_viewport())

func _check_and_process_pending_level_ups() -> void:
	level_up_manager.check_and_process_pending_level_ups(get_tree(), get_viewport())

func handle_refresh_button(button_id: int) -> void:
	level_up_manager.handle_refresh_button(button_id, get_tree(), get_viewport())

func get_required_lv_up_value(level: int) -> int:
	return level_up_manager.get_required_lv_up_value(level)

func add_pending_level_up() -> void:
	level_up_manager.add_pending_level_up()

# ============== Warning动画 ==============

func play_warning_animation() -> void:
	var warning_node = get_node_or_null("Warning")
	if warning_node == null:
		print("ERROR: Warning node not found in CanvasLayer!")
		return
	
	warning_node.process_mode = Node.PROCESS_MODE_ALWAYS
	warning_node.visible = false
	warning_node.modulate = Color(1, 1, 1, 0)
	
	var warning_audio = warning_node.get_node_or_null("warning") as AudioStreamPlayer
	if warning_audio:
		warning_audio.play()
	
	warning_node.visible = true
	
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.set_process_mode(1)
	tween.tween_property(warning_node, "modulate:a", 1.0, 0.5)
	tween.tween_interval(2.0)
	tween.tween_property(warning_node, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): warning_node.visible = false)
