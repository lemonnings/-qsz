extends CanvasLayer

# ============== UI 组件引用 ==============
@export var hp_bar: ProgressBar
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
	var skill_nodes_array: Array[TextureButton] = [skill1, skill2, skill3, skill4]
	level_up_manager.initialize(self, lv_up_change, lv_up_change_b1, lv_up_change_b2, lv_up_change_b3, self, skill_nodes_array)
	
	# 初始化纹章管理器
	emblem_manager = EmblemManager.new()
	add_child(emblem_manager)
	emblem_manager.setup_emblem_container(buff_box)
	var icons := [emblem1, emblem2, emblem3, emblem4, emblem5, emblem6, emblem7, emblem8]
	var panels := [emblem1_panel, emblem2_panel, emblem3_panel, emblem4_panel, emblem5_panel, emblem6_panel, emblem7_panel, emblem8_panel]
	var details := [emblem1_detail, emblem2_detail, emblem3_detail, emblem4_detail, emblem5_detail, emblem6_detail, emblem7_detail, emblem8_detail]
	emblem_manager.setup_emblem_ui(icons, panels, details)

func _connect_signals() -> void:
	Global.connect("skill_attack_speed_updated", Callable(self, "_on_skill_attack_speed_updated"))
	Global.connect("player_lv_up", Callable(self, "_on_level_up"))
	Global.connect("level_up_selection_complete", Callable(self, "_check_and_process_pending_level_ups"))
	
	# 连接主动技能信号
	if Global.ActiveSkillManager:
		Global.ActiveSkillManager.skill_cooldown_started.connect(_on_active_skill_cooldown_started)
		Global.ActiveSkillManager.skill_cooldown_finished.connect(_on_active_skill_cooldown_finished)

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
func update_hp_bar(current_hp: int, max_hp: int) -> void:
	var target_value = (float(current_hp) / max_hp) * 100
	if hp_bar.value != target_value:
		if abs(target_value - hp_bar.value) > 2:
			var tween = create_tween()
			tween.tween_property(hp_bar, "value", target_value, 0.15)
		else:
			hp_bar.value = target_value
	
	if current_hp <= 0:
		hp_num.text = '0 / ' + str(max_hp)
	else:
		hp_num.text = str(current_hp) + ' / ' + str(max_hp)

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

func _on_skill_attack_speed_updated() -> void:
	# 需要获取player节点来更新，通过信号通知父场景
	if PC.player_instance:
		update_skill_cooldowns(PC.player_instance)

# ============== 属性标签显示 ==============

func show_attr_label() -> void:
	attr_label.visible = true
	attr_label.text = "dps：" + str(Global.get_current_dps()) + "\n攻击：" + str(PC.pc_atk) + "  额外攻速：" + str(PC.pc_atk_speed) + "\n额外移速：" + str(PC.pc_speed) + "  弹体大小：" + str(PC.bullet_size) + "\n天命：" + str(PC.now_lunky_level) + "  减伤：" + str(PC.damage_reduction_rate) + "\n暴击率：" + str(PC.crit_chance) + "  暴击伤害：" + str(PC.crit_damage_multi) + "\n环形剑气攻击/数量/大小/射速：" + str(PC.ring_bullet_damage_multiplier) + "/" + str(PC.ring_bullet_count) + "/" + str(PC.ring_bullet_size_multiplier) + "/" + str(PC.ring_bullet_interval) + "/" + "\n召唤物数量/最大数量/攻击/弹体大小/射速：" + str(PC.summon_count) + "/" + str(PC.summon_count_max) + "/" + str(PC.summon_damage_multiplier) + "/" + str(PC.summon_bullet_size_multiplier) + "/" + str(PC.summon_interval_multiplier) + "/" + "\n开悟获取：" + str(PC.selected_rewards)

func hide_attr_label() -> void:
	attr_label.visible = false

# ============== 技能标签显示 ==============

func show_skill1_label(player_node: Node) -> void:
	var skill1Text = "[font_size=32]剑气  LV. " + str(PC.main_skill_swordQi) + "[/font_size]"
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
