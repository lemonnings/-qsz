extends Node2D

@export var dialog_control : Control
@export var levelChangeLayer : CanvasLayer
@export var cultivationLayer : CanvasLayer
@export var setting : Panel
@export var settingButton : Button
@export var canvasLayer : CanvasLayer
@export var synthesisLayer : CanvasLayer

@export var tip : Node

@export var battle_scene: String

@export var cystal : AnimatedSprite2D 
@export var cystal2 : AnimatedSprite2D 
@export var levelUpMan : AnimatedSprite2D 
@export var blackSmith : AnimatedSprite2D 
@export var merchant : AnimatedSprite2D 
@export var danlu : AnimatedSprite2D 
@export var portal : AnimatedSprite2D
@export var cystalTips : Control 
@export var levelUpManTips : Control
@export var blackSmithTips : Control
@export var merchantTips : Control
@export var danluTips : Control
@export var portalTips : Control

@export var dark_overlay : Control  # 黑色滤镜

@export var cultivation_msg : RichTextLabel
@export var point_label : Label

@export var interaction_distance : float = 35.0 
var dialog_file_to_start: String = "res://AssetBundle/Dialog/test_dialog.txt"
var qian_dialog: String = "res://AssetBundle/Dialog/qian_dialog.txt"

var transition_tween: Tween
# UI动画相关变量
var ui_tweens: Dictionary = {}
var ui_states: Dictionary = {}

var player: CharacterBody2D


func _ready() -> void:
	# 设置音效使用SFX总线
	setup_audio_buses()
	Global.load_game()
	Global.in_town = true
	
	if $Player is CharacterBody2D:
		player = $Player

func setup_audio_buses() -> void:
	# 设置所有音效使用SFX总线
	if has_node("LevelUP"):
		$LevelUP.bus = "SFX"
	if has_node("Buzzer"):
		$Buzzer.bus = "SFX"

	PC.movement_disabled = false
	PC.is_game_over = false
	# 初始化UI状态
	ui_states["cystalTips"] = false
	ui_states["levelUpManTips"] = false
	ui_states["danluTips"] = false
	ui_states["portalTips"] = false
	ui_states["dark_overlay"] = false
	
	# 确保UI元素初始状态正确
	cystalTips.visible = false
	cystalTips.modulate.a = 0.0
	levelUpManTips.visible = false
	levelUpManTips.modulate.a = 0.0
	danluTips.visible = false
	danluTips.modulate.a = 0.0
	portalTips.visible = false
	portalTips.modulate.a = 0.0
	
	# 初始化黑色滤镜
	if dark_overlay:
		dark_overlay.visible = false
		dark_overlay.modulate.a = 0.0
	
	# 初始化界面层（CanvasLayer本身不需要设置modulate）
	if levelChangeLayer:
		levelChangeLayer.visible = false
	
	if cultivationLayer:
		cultivationLayer.visible = false
	
	if synthesisLayer:
		synthesisLayer.visible = false

	Global.emit_signal("reset_camera")
	Global.connect("press_f", Callable(self, "press_interact"))
	Global.connect("press_g", Callable(self, "press_interact2"))
	Global.connect("press_h", Callable(self, "press_interact3"))

# UI动画处理函数
func animate_ui_element(ui_element: Control, ui_name: String, should_show: bool) -> void:
	# 如果状态没有改变，直接返回
	if ui_states[ui_name] == should_show:
		return
	
	# 更新状态
	ui_states[ui_name] = should_show
	
	# 停止之前的动画
	if ui_tweens.has(ui_name) and ui_tweens[ui_name]:
		ui_tweens[ui_name].kill()
	
	# 创建新的动画
	ui_tweens[ui_name] = create_tween()
	
	if should_show:
		# 渐入动画
		ui_element.visible = true
		ui_element.modulate.a = 0.0
		ui_tweens[ui_name].tween_property(ui_element, "modulate:a", 1.0, 0.15)
	else:
		# 渐出动画
		ui_tweens[ui_name].tween_property(ui_element, "modulate:a", 0.0, 0.15)
		ui_tweens[ui_name].tween_callback(func(): ui_element.visible = false)

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	if player.global_position.distance_to(cystal2.global_position) < interaction_distance:
		animate_ui_element(cystalTips, "cystalTips", true)
		cystalTips.change_label1_text("切换英雄 [F]")
	else:
		animate_ui_element(cystalTips, "cystalTips", false)
		
				
	if player.global_position.distance_to(levelUpMan.global_position) < interaction_distance:
		animate_ui_element(levelUpManTips, "levelUpManTips", true)
		levelUpManTips.change_name("乾
		<引导者>")
		levelUpManTips.change_label1_text("修习 [F]")
		levelUpManTips.change_function2_visible(true)
		levelUpManTips.change_label2_text("交谈 [G]")
	else:
		animate_ui_element(levelUpManTips, "levelUpManTips", false)
	
				
	if player.global_position.distance_to(danlu.global_position) < interaction_distance+20:
		animate_ui_element(danluTips, "danluTips", true)
		danluTips.change_name("兑
		<合成>")
		danluTips.change_label1_text("合成 [F]")
		danluTips.change_function2_visible(true)
		danluTips.change_label2_text("交谈 [G]")
	else:
		animate_ui_element(danluTips, "danluTips", false)
				
	if player.global_position.distance_to(portal.global_position) < interaction_distance:
		animate_ui_element(portalTips, "portalTips", true)
		portalTips.change_name("传送阵
		<关卡选择>")
		portalTips.change_label1_text("传送 [F]")
	else:
		animate_ui_element(portalTips, "portalTips", false)
	
	if Input.is_action_just_pressed("interact"):
		press_interact()
		
	if Input.is_action_just_pressed("Interact2"):
		press_interact2()
		
# F交互
func press_interact():
	settingButton.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if player.global_position.distance_to(cystal2.global_position) < interaction_distance:
		if not dialog_control.visible:
			start_dialog_interaction("crystal")
	
	if player.global_position.distance_to(portal.global_position) < interaction_distance:
		PC.movement_disabled = true
		
		if dark_overlay:
			if ui_tweens.has("dark_overlay") and ui_tweens["dark_overlay"]:
				ui_tweens["dark_overlay"].kill()
			
			ui_tweens["dark_overlay"] = create_tween()
			dark_overlay.visible = true
			dark_overlay.modulate.a = 0.0
			ui_tweens["dark_overlay"].tween_property(dark_overlay, "modulate:a", 1.0, 0.15)
		
		# 渐进显示关卡选择界面
		if ui_tweens.has("levelChangeLayer") and ui_tweens["levelChangeLayer"]:
			ui_tweens["levelChangeLayer"].kill()
		
		ui_tweens["levelChangeLayer"] = create_tween()
		ui_tweens["levelChangeLayer"].set_parallel(true)
		levelChangeLayer.visible = true
		
		# 对CanvasLayer的所有子节点进行动画
		for child in levelChangeLayer.get_children():
			if child.has_method("set_modulate"):
				child.modulate.a = 0.0
				ui_tweens["levelChangeLayer"].tween_property(child, "modulate:a", 1.0, 0.15).set_delay(0.15)

	if player.global_position.distance_to(levelUpMan.global_position) < interaction_distance:
		PC.movement_disabled = true
		
		if dark_overlay:
			if ui_tweens.has("dark_overlay") and ui_tweens["dark_overlay"]:
				ui_tweens["dark_overlay"].kill()
			
			ui_tweens["dark_overlay"] = create_tween()
			dark_overlay.visible = true
			dark_overlay.modulate.a = 0.0
			ui_tweens["dark_overlay"].tween_property(dark_overlay, "modulate:a", 1.0, 0.15)
			
		refresh_point()
		
		# 渐进显示修炼界面
		if ui_tweens.has("cultivationLayer") and ui_tweens["cultivationLayer"]:
			ui_tweens["cultivationLayer"].kill()
		
		ui_tweens["cultivationLayer"] = create_tween()
		ui_tweens["cultivationLayer"].set_parallel(true)
		cultivationLayer.visible = true
		
		# 对CanvasLayer的所有子节点进行动画
		for child in cultivationLayer.get_children():
			if child.has_method("set_modulate"):
				child.modulate.a = 0.0
				ui_tweens["cultivationLayer"].tween_property(child, "modulate:a", 1.0, 0.15).set_delay(0.15)

	if player.global_position.distance_to(danlu.global_position) < interaction_distance + 20:
		PC.movement_disabled = true
		
		if dark_overlay:
			if ui_tweens.has("dark_overlay") and ui_tweens["dark_overlay"]:
				ui_tweens["dark_overlay"].kill()
			
			ui_tweens["dark_overlay"] = create_tween()
			dark_overlay.visible = true
			dark_overlay.modulate.a = 0.0
			ui_tweens["dark_overlay"].tween_property(dark_overlay, "modulate:a", 1.0, 0.15)
		
		# 渐进显示合成界面
		if ui_tweens.has("synthesisLayer") and ui_tweens["synthesisLayer"]:
			ui_tweens["synthesisLayer"].kill()
		
		ui_tweens["synthesisLayer"] = create_tween()
		ui_tweens["synthesisLayer"].set_parallel(true)
		synthesisLayer.visible = true
		
		# 对CanvasLayer的所有子节点进行动画
		for child in synthesisLayer.get_children():
			if child.has_method("set_modulate"):
				child.modulate.a = 0.0
				ui_tweens["synthesisLayer"].tween_property(child, "modulate:a", 1.0, 0.15).set_delay(0.15)
		
# G交互
func press_interact2():
	settingButton.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if player.global_position.distance_to(levelUpMan.global_position) < interaction_distance:
		if not dialog_control.visible:
			start_dialog_interaction("qian")
		
# H交互
func press_interact3():
	pass


func start_dialog_interaction(npc_id: String) -> void:
	PC.movement_disabled = true
	if not dialog_control.is_inside_tree():
		add_child(dialog_control)
	
	# 确保 dialog_control 可见
	dialog_control.visible = true

	if npc_id == "qian":
		Global.start_dialog.emit(qian_dialog)


func _on_exit_pressed() -> void:
	PC.movement_disabled = false
	settingButton.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var exit_tween = create_tween()
	exit_tween.set_parallel(true)
	
	if dark_overlay and dark_overlay.visible:
		exit_tween.tween_property(dark_overlay, "modulate:a", 0.0, 0.2)
		exit_tween.tween_callback(func(): 
			dark_overlay.visible = false
			dark_overlay.modulate.a = 0.0
		).set_delay(0.2)
	
	# 渐出关卡选择界面
	if levelChangeLayer.visible:
		for child in levelChangeLayer.get_children():
			if child.has_method("set_modulate"):
				exit_tween.tween_property(child, "modulate:a", 0.0, 0.2)
		exit_tween.tween_callback(func(): 
			levelChangeLayer.visible = false
			# 重置子节点透明度
			for child in levelChangeLayer.get_children():
				if child.has_method("set_modulate"):
					child.modulate.a = 1.0
		).set_delay(0.2)
	
	# 渐出修炼界面
	if cultivationLayer.visible:
		for child in cultivationLayer.get_children():
			if child.has_method("set_modulate"):
				exit_tween.tween_property(child, "modulate:a", 0.0, 0.1)
		exit_tween.tween_callback(func(): 
			cultivationLayer.visible = false
			# 重置子节点透明度
			for child in cultivationLayer.get_children():
				if child.has_method("set_modulate"):
					child.modulate.a = 1.0
		).set_delay(0.1)

	# 渐出合成界面
	if synthesisLayer.visible:
		for child in synthesisLayer.get_children():
			if child.has_method("set_modulate"):
				exit_tween.tween_property(child, "modulate:a", 0.0, 0.1)
		exit_tween.tween_callback(func(): 
			synthesisLayer.visible = false
			# 重置子节点透明度
			for child in synthesisLayer.get_children():
				if child.has_method("set_modulate"):
					child.modulate.a = 1.0
		).set_delay(0.1)

	# 渐出设置界面
	if setting.visible:
		# 先淡出子节点
		for child in setting.get_children():
			if child.has_method("set_modulate"):
				exit_tween.tween_property(child, "modulate:a", 0.0, 0.2)
		
		# 然后淡出设置面板本身
		exit_tween.tween_property(setting, "modulate:a", 0.0, 0.2)
		exit_tween.tween_callback(func(): 
			setting.visible = false
			setting.modulate.a = 1.0
			# 重置子节点透明度
			for child in setting.get_children():
				if child.has_method("set_modulate"):
					child.modulate.a = 1.0
		).set_delay(0.2)
	
func _on_stage_1_pressed() -> void:
	Global.in_town = false
	PC.movement_disabled = false
	PC.reset_player_attr()
	SceneChange.change_scene(battle_scene, true)
	
func _on_stage_2_pressed() -> void:
	Global.in_town = true
	PC.reset_player_attr()

func refresh_point() -> void:
	point_label.text = "真气 " + str(Global.total_points)

# 修炼配置数据
var cultivation_configs = {
	"poxu": {"name": "破虚", "type": "atk", "level_var": "cultivation_poxu_level"},
	"xuanyuan": {"name": "玄元", "type": "hp", "level_var": "cultivation_xuanyuan_level"},
	"liuguang": {"name": "流光", "type": "atk_speed", "level_var": "cultivation_liuguang_level"},
	"hualing": {"name": "化灵", "type": "spirit_gain", "level_var": "cultivation_hualing_level"},
	"fengrui": {"name": "锋锐", "type": "crit_chance", "level_var": "cultivation_fengrui_level"},
	"huti": {"name": "护体", "type": "damage_reduction", "level_var": "cultivation_huti_level"},
	"zhuifeng": {"name": "追风", "type": "move_speed", "level_var": "cultivation_zhuifeng_level"},
	"liejin": {"name": "烈劲", "type": "crit_damage", "level_var": "cultivation_liejin_level"}
}

func _on_cme(cultivation_key: String) -> void:
	var config = cultivation_configs[cultivation_key]
	var current_level = Global.get(config["level_var"])
	var next_level = current_level + 1
	var next_level_exp = 0
	if cultivation_key == "poxu" or cultivation_key == "xuanyuan" or cultivation_key == "hualing" or cultivation_key == "liejin":
		next_level_exp = CL.get_cultivation_exp_for_level_normal(current_level)
	else:
		next_level_exp = CL.get_cultivation_exp_for_level_high(current_level)
	var current_bonus = CL.get_cultivation_bonus_text(config["type"], current_level)
	var next_bonus = CL.get_cultivation_bonus_text(config["type"], next_level)
	
	cultivation_msg.text = "[font_size=64]" + config["name"] + "  LV " + str(current_level) + "[/font_size]

当前：" + current_bonus + "
下一级：" + next_bonus + "
修炼消耗： " + str(next_level_exp) + " 真气

再次点击即可修炼"
	cultivation_msg.visible = true

func _on_cmex(_cultivation_key: String) -> void:
	cultivation_msg.visible = false

func _on_cmp(cultivation_key: String) -> void:
	var config = cultivation_configs[cultivation_key]
	var current_level = Global.get(config["level_var"])
	var next_level_exp = 0
	if cultivation_key == "poxu" or cultivation_key == "xuanyuan" or cultivation_key == "hualing" or cultivation_key == "liejin":
		next_level_exp = CL.get_cultivation_exp_for_level_normal(current_level)
	else:
		next_level_exp = CL.get_cultivation_exp_for_level_high(current_level)
	
	if Global.total_points >= next_level_exp:
		Global.set(config["level_var"], current_level + 1)
		Global.total_points -= next_level_exp
		
		$LevelUP.play()
		
		print(config["name"] + "修炼成功！当前等级：" + str(Global.get(config["level_var"])))
		tip.start_animation(config["name"] + "修炼成功！当前等级：" + str(Global.get(config["level_var"])), 0.5)

		Global.save_game()
		refresh_point()
		
		if cultivation_msg.visible:
			_on_cme(cultivation_key)
	else:
		print("Point不足！需要 " + str(next_level_exp) + " Point，当前只有 " + str(Global.total_points) + " Point")
		$Buzzer.play()

func _on_poxu_mouse_entered() -> void:
	_on_cme("poxu")

func _on_poxu_mouse_exited() -> void:
	_on_cmex("poxu")

func _on_poxu_pressed() -> void:
	_on_cmp("poxu")

func _on_xuanyuan_mouse_entered() -> void:
	_on_cme("xuanyuan")

func _on_xuanyuan_mouse_exited() -> void:
	_on_cmex("xuanyuan")

func _on_xuanyuan_pressed() -> void:
	_on_cmp("xuanyuan")

func _on_liuguang_mouse_entered() -> void:
	_on_cme("liuguang")

func _on_liuguang_mouse_exited() -> void:
	_on_cmex("liuguang")

func _on_liuguang_pressed() -> void:
	_on_cmp("liuguang")

func _on_hualing_mouse_entered() -> void:
	_on_cme("hualing")

func _on_hualing_mouse_exited() -> void:
	_on_cmex("hualing")

func _on_hualing_pressed() -> void:
	_on_cmp("hualing")

func _on_fengrui_mouse_entered() -> void:
	_on_cme("fengrui")

func _on_fengrui_mouse_exited() -> void:
	_on_cmex("fengrui")

func _on_fengrui_pressed() -> void:
	_on_cmp("fengrui")

func _on_huti_mouse_entered() -> void:
	_on_cme("huti")

func _on_huti_mouse_exited() -> void:
	_on_cmex("huti")

func _on_huti_pressed() -> void:
	_on_cmp("huti")

func _on_zhuifeng_mouse_entered() -> void:
	_on_cme("zhuifeng")

func _on_zhuifeng_mouse_exited() -> void:
	_on_cmex("zhuifeng")

func _on_zhuifeng_pressed() -> void:
	_on_cmp("zhuifeng")

func _on_liejin_mouse_entered() -> void:
	_on_cme("liejin")

func _on_liejin_mouse_exited() -> void:
	_on_cmex("liejin")

func _on_liejin_pressed() -> void:
	_on_cmp("liejin")


func _on_setting_pressed() -> void:
	if !setting.visible:
		PC.movement_disabled = true
		
		if dark_overlay:
			if ui_tweens.has("dark_overlay") and ui_tweens["dark_overlay"]:
				ui_tweens["dark_overlay"].kill()
			
			ui_tweens["dark_overlay"] = create_tween()
			dark_overlay.visible = true
			dark_overlay.modulate.a = 0.0
			ui_tweens["dark_overlay"].tween_property(dark_overlay, "modulate:a", 1.0, 0.15)
		
		# 渐进显示设置界面
		if ui_tweens.has("setting") and ui_tweens["setting"]:
			ui_tweens["setting"].kill()
		
		ui_tweens["setting"] = create_tween()
		ui_tweens["setting"].set_parallel(true)
		setting.visible = true
		setting.modulate.a = 0.0
		
		# 然后对设置面板的所有子节点进行动画
		for child in setting.get_children():
			if child.has_method("set_modulate"):
				child.modulate.a = 0.0
				ui_tweens["setting"].tween_property(child, "modulate:a", 1.0, 0.15).set_delay(0.15)
		
		# 先显示设置面板本身
		ui_tweens["setting"].tween_property(setting, "modulate:a", 1.0, 0.15)
