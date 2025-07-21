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

	# 检测 F 键 (映射到 "interact" 动作) 是否按下一个其他世界的黑魔法师，他的世界因为过渡开发以太能源矿，导致以太崩溃，浓缩的以太凝聚成了各种各样的魔物，并且大地上的以太大量减少，寸草不生，人类陷入生存危机。天才黑魔法师研究出来了可以从未知位面获得以太的方法，然后一直在吸收，直到吸收的太多了导致出现了裂隙，两个世界开始逐渐交汇
	# 直到一次增大获取以太的实验出了事故，把黑魔法师传过来了，传到了朝天山上，过来了之后因为人生地不熟很怕，开启了幻境避免人打扰，却发现魔物在他不知道的地方越来越多。
	# 主角进入了幻境探索，发现每次在击败一个地区的头目之后，幻境都会出现紊乱把他传送出去，但在这段时间击杀的魔物会转化为以太加强自身。
	# 右侧关卡阵，左侧山洞里密宗长老开隐藏本，左上铁匠圣器打造升级，右上修炼室局外养成加点，中间巨大水晶可以切换人物
	# 
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
		
# F交互
func press_interact():
	if player.global_position.distance_to(cystal2.global_position) < interaction_distance:
		if not dialog_control.visible:
			start_dialog_interaction("crystal")
	
	if player.global_position.distance_to(portal.global_position) < interaction_distance:
			_transition_to_layer(levelChangeLayer, [canvasLayer], [], true)
			levelChangeLayer.visible = true
# 在一个以魔法为主的世界里，人们依靠水晶（灵石）里存储的以太来释放法术，法术在日常生活中逐渐被滥用，在一次大规模战争中，因过度开采“以太矿”引发了能量崩溃，浓缩以太异化为魔物，大地生机断绝。
# 这个世界的一名黑魔法师为拯救故土，研发跨位面以太汲取术，却因过量吸收撕裂时空，导致其世界与本位面通过“裂隙”产生交融，黑魔法师也在实验事故中被传至朝天山，因恐慌展开幻境屏障，却未察觉裂隙正加速魔物涌入，而大量未经提纯的以太也涌入朝天山，诱使朝天山的魔物也开始滋生。
# 察觉到朝天山被封锁，山脚下的村民向管辖这片区域的八玄阁求助，派出的中级弟子在进入幻境后便杳无音讯，让八玄阁的上层重视了起来，并准备先派一名八部中的领袖来解决此事。
# 主角团是来协助解决这件事的侠士，精通传送技术的巽在村落外围铺设了返回锚点，然后把主角传送到了幻境的外围。
# 在外围击杀了一众小怪之后，主角发现这些小怪身上因为有大量的“以太”（可以解释成这个世界中的真气一类的），在击杀了之后一部分以太外溢，可以吸收了之后增加实力，另一部分过于精纯的以太化作了灵石（游戏内货币）。因为魔法世界的人都把以太当做外置能量，用来释放魔法，而修仙的是吸纳这些能量储存在自己身体里。
# 因为已经被巽预设了返回的地点+遇到生命危险时紧急传回的符咒，在击杀了boss/或者死了之后，会返回村落处
# G交互
func press_interact2():
	if player.global_position.distance_to(levelUpMan.global_position) < interaction_distance:
		if not dialog_control.visible:
			start_dialog_interaction("qian")
		
# H交互
func press_interact3():
	#1层，主动技能闪避，解锁世界树之枝，召唤蓝紫，幸运提升，剑气/树枝强化初始等级提升1~3
	#2层，闪避无敌时间增加，闪避cd降低，主动技能加速，解锁扫帚，召唤金红，经验获得提升，魔焰初始1~3
	#3层，加速效果提升，持续时间增加，cd降低，主动技能魔化，解锁ry，召唤金红进阶，幸运系，幸运提升，ry初始1~3
	#4层，魔化效果提升，持续时间增加，cd降低，主动技能乱击，解锁环火，主武器+1，经验获得提升，环火初始1~3
	#5层，乱击范围提升，子弹数量提升，cd降低，幸运，经验获得提升，幸运系金红

	#1层，主动技能魔罩，解锁炽炎，催化系蓝紫
	#催化，提升怪的数量，换取其他加成，白绿怪+5%，蓝紫+10%，金红+15%，经验加成+15%/22%/37%/44%/59%/66%，最终伤害提升4%/5.5%/9.5%/11%/15%/16.5%
	# 提升怪的属性，换取经验加成或者减伤率2%~8.3%
	#2层，命运系，初始20面骰，1大失败20大成功，2~10失败，11~19成功
	#紫，成功判定点+1
	#金，大成功判定点+1
	#红，
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




# 凌奕秋，初始武器：剑气，特殊技能：闪避、魔化，可掌握技能：加速，乱击，可掌握武器：扫帚，ry，环火
# 诺姆，初始武器：冰针，特殊技能：魔纹、激情咏唱，可掌握技能：魔罩，究极，掌握武器：世界树之枝，炽炎，


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
				transition_tween.tween_property(child, "modulate:a", 1.0, 0.125).set_delay(0.25)
	
