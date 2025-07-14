extends Node2D

@export var dialog_control : Control
@export var levelChangeLayer : CanvasLayer
@export var canvasLayer : CanvasLayer

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

@export var interaction_distance : float = 35.0 
var dialog_file_to_start: String = "res://AssetBundle/Dialog/test_dialog.txt"
var qian_dialog: String = "res://AssetBundle/Dialog/qian_dialog.txt"

var transition_tween: Tween


var player: CharacterBody2D


func _ready() -> void:
	if $Player is CharacterBody2D:
		player = $Player

	Global.emit_signal("reset_camera")
	Global.connect("press_f", Callable(self, "press_interact"))
	Global.connect("press_g", Callable(self, "press_interact2"))
	Global.connect("press_h", Callable(self, "press_interact3"))

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	# 检测 F 键 (映射到 "interact" 动作) 是否按下天才黑魔法师研究出来了可以从未知位面获得以太的方法，然后一直在吸收，直到吸收的太多了导致出现了裂隙，两个世界开始逐渐交汇
	# 直到一次增大获取以太的实验出了事故，把黑魔法师传过来了，传到了朝天山上，过来了之后因为人生地不熟很怕，开启了幻境避免人打扰，却发现魔物在他不知道的地方越来越多。
	# 主角进入了幻境探索，发现每次在击败一个地区的头目之后，幻境都会出现紊乱把他传送出去，但在这段时间击杀的魔物会转化为以太加强自身。
	if player.global_position.distance_to(cystal2.global_position) < interaction_distance:
		cystalTips.visible = true
		cystalTips.change_label1_text("切换英雄 [F]")
	else:
		cystalTips.visible = false
		
				
	if player.global_position.distance_to(levelUpMan.global_position) < interaction_distance:
		levelUpManTips.visible = true
		levelUpManTips.change_name("乾
		<引导者>")
		levelUpManTips.change_label1_text("修习 [F]")
		levelUpManTips.change_function2_visible(true)
		levelUpManTips.change_label2_text("交谈 [G]")
	else:
		levelUpManTips.visible = false
	
				
	if player.global_position.distance_to(portal.global_position) < interaction_distance:
		portalTips.change_name("传送阵
		<关卡选择>")
		portalTips.change_label1_text("传送 [F]")
		portalTips.visible = true
	else:
		portalTips.visible = false
	
	if Input.is_action_just_pressed("interact"):
		press_interact()
		
	if Input.is_action_just_pressed("Interact2"):
		press_interact2()
					

		#if player.global_position.distance_to($NPC2/AnimatedSprite2D.global_position) < interaction_distance:
			#if not dialog_control.visible:
				#start_dialog_interaction(2)
			#else:
				#print_debug("Dialog is already active.")
# 右侧关卡阵，左侧山洞里密宗长老开隐藏本，左上铁匠圣器打造升级，右上修炼室局外养成加点，中间巨大水晶可以切换人物
# 1个其他世界的黑魔法师，他的世界因为过渡开发以太能源矿，导致以太崩溃，浓缩的以太凝聚成了各种各样的魔物，并且大地上的以太大量减少，寸草不生，人类陷入生存危机。

func press_interact():
	if player.global_position.distance_to(cystal2.global_position) < interaction_distance:
		if not dialog_control.visible:
			start_dialog_interaction("crystal")
	
	if player.global_position.distance_to(portal.global_position) < interaction_distance:
			_transition_to_layer(levelChangeLayer, [canvasLayer], [], true)
			levelChangeLayer.visible = true
			

func press_interact2():
	if player.global_position.distance_to(levelUpMan.global_position) < interaction_distance:
		if not dialog_control.visible:
			start_dialog_interaction("qian")
		
func press_interact3():
	pass

func start_dialog_interaction(npc_id: String) -> void:
	if not dialog_control.is_inside_tree():
		add_child(dialog_control)
	
	# 确保 dialog_control 可见
	dialog_control.visible = true

	if npc_id == "qian":
		Global.start_dialog.emit(qian_dialog)
		

func _on_exit_pressed() -> void:
	levelChangeLayer.visible = false
	_transition_to_layer(canvasLayer, [levelChangeLayer], [], true)

	
func _on_stage_1_pressed() -> void:
	Global.in_town = false
	PC.reset_player_attr()
	SceneChange.change_scene(battle_scene, true)
	
func _on_stage_2_pressed() -> void:
	Global.in_town = true
	PC.reset_player_attr()



func _switch_layers(target_layer: CanvasLayer, hide_layers: Array, show_controls: Array, show_controls_immediately: bool) -> void:
	# 隐藏旧层
	for layer in hide_layers:
		if layer:
			layer.visible = false
			# 重置所有子节点的透明度
			for child in layer.get_children():
				if child.has_method("set_modulate"):
					child.modulate.a = 1.0
	
	# 处理控件显示
	for control in show_controls:
		if control:
			control.visible = show_controls_immediately
			
			

func _transition_to_layer(target_layer: CanvasLayer, hide_layers: Array, show_controls: Array = [], show_controls_immediately: bool = false) -> void:
	if transition_tween:
		transition_tween.kill()
	
	transition_tween = create_tween()
	transition_tween.set_parallel(true)
	
	# 淡出当前显示的层的所有子节点
	for layer in hide_layers:
		if layer and layer.visible:
			for child in layer.get_children():
				if child.has_method("set_modulate"):
					transition_tween.tween_property(child, "modulate:a", 0.0, 0.125)
	
	# 等待淡出完成后切换显示状态
	transition_tween.tween_callback(_switch_layers.bind(target_layer, hide_layers, show_controls, show_controls_immediately)).set_delay(0.125)
	
	# 淡入目标层的所有子节点
	if target_layer:
		target_layer.visible = true
		for child in target_layer.get_children():
			if child.has_method("set_modulate"):
				child.modulate.a = 0.0
				transition_tween.tween_property(child, "modulate:a", 1.0, 0.125).set_delay(0.125)
	
