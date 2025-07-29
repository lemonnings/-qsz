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

@export var dark_overlay : Control  # 黑色滤镜

@export var interaction_distance : float = 35.0 
var dialog_file_to_start: String = "res://AssetBundle/Dialog/test_dialog.txt"
var qian_dialog: String = "res://AssetBundle/Dialog/qian_dialog.txt"

var transition_tween: Tween
# UI动画相关变量
var ui_tweens: Dictionary = {}
var ui_states: Dictionary = {}

var player: CharacterBody2D


func _ready() -> void:
	if $Player is CharacterBody2D:
		player = $Player

	PC.movement_disabled = false
	PC.is_game_over = false
	# 初始化UI状态
	ui_states["cystalTips"] = false
	ui_states["levelUpManTips"] = false
	ui_states["portalTips"] = false
	ui_states["dark_overlay"] = false
	
	# 确保UI元素初始状态正确
	cystalTips.visible = false
	cystalTips.modulate.a = 0.0
	levelUpManTips.visible = false
	levelUpManTips.modulate.a = 0.0
	portalTips.visible = false
	portalTips.modulate.a = 0.0
	
	# 初始化黑色滤镜
	if dark_overlay:
		dark_overlay.visible = false
		dark_overlay.modulate.a = 0.0

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

	# 检测 F 键 (映射到 "interact" 动作) 是否按下
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
	if player.global_position.distance_to(cystal2.global_position) < interaction_distance:
		if not dialog_control.visible:
			start_dialog_interaction("crystal")
	
	if player.global_position.distance_to(portal.global_position) < interaction_distance:
		# 禁用玩家移动
		PC.movement_disabled = true
		
		# 立即显示黑色滤镜，避免被层级切换影响
		if dark_overlay:
			# 停止之前的动画
			if ui_tweens.has("dark_overlay") and ui_tweens["dark_overlay"]:
				ui_tweens["dark_overlay"].kill()
			
			# 直接设置状态并显示滤镜，不依赖其他动画
			dark_overlay.visible = true
			dark_overlay.modulate.a = 1  # 直接设置透明度
		
		# 显示关卡选择界面，但不使用会重置透明度的过渡动画
		levelChangeLayer.visible = true
# 在一个以魔法为主的世界里，人们依靠水晶（灵石）里存储的以太来释放法术，法术在日常生活中逐渐被滥用，在一次大规模战争中，因过度开采“以太矿”引发了能量崩溃，浓缩以太异化为魔物，大地生机断绝。
# 这个世界的一名黑魔法师为了拯救故土，研发跨位面以太汲取术，在一次实验中，因为过量吸收以太，导致其世界与本位面通过“裂隙”产生交融，黑魔法师也在实验事故中被传至龙门山，他因恐慌展开了一道幻境屏障，却未察觉时空裂隙正导致魔物的涌入，而大量未经提纯的以太也一并涌入龙门山，诱使龙门山的魔物也开始滋生。
# 察觉到龙门山被幻境封锁，山脚下的村民向管辖这片区域的八玄阁求助，八玄阁派出的中级弟子在进入幻境后便杳无音讯，这让八玄阁的上层开始重视这件事，并准备先派一名八部中的领袖来解决此事。
# 经过一番探测后，八玄阁发现这个幻境的构造超出了他们所有人的知识范畴（因为都不是一个世界的），因此决定除了派遣本阁弟子之外，也广招天下侠士前来共同探索这个幻境。
# 主角团是来协助解决这件事的侠士，精通传送技术的巽在村落外围铺设了返回锚点，然后把主角传送到了幻境的外围。
# 在幻境外围和幻境内部连续击败几个镇守一个区域的boss后，幻境的效力下降，开启了通往幻境深处的道路，在幻境深处可以抓住幻境的始作俑者黑魔法师诺姆。
# 在战斗中击败了诺姆后，诺姆无奈的表示自己的幻境在展开之后就发现无法关闭了，这个世界的以太太过丰富，导致幻境的后备能源几乎是无尽的，而且幻境的核心处由于凝结了过多的以太，有一个连他都无法控制的boss诞生了。
# 一部分简单设定
# 地图分为4个区域，外围，内部，深处，核心；每次进入地图的某个区域，会有一个以太活跃度的设定，通过在区域里战斗的时间+杀怪提升活跃度，活跃度达到满值后随机出现一个这个区域的boss（比如外围会随机从千年树精，晶矿化巨虎，腐蚀粘液怪中出现一个）
# 其中每个区域都有一个探索度，以太活跃度的提升也可以同步提升探索进度，当探索度高于70%后，下次关卡中以太活跃度满值后出现的boss就是镇守这个区域的最终boss，击败后可以开启下个区域
# 通过收集关卡内掉落，还可以合成进入隐藏地图的钥匙，用来开启特殊关卡
# 杀怪后获得的真气、灵石：在外围击杀了一众小怪之后，主角发现这些小怪身上因为有大量的“以太”（可以解释成这个世界中的真气一类的），在击杀了之后一部分以太外溢，可以吸收了之后增加实力，另一部分过于精纯的以太化作了灵石（游戏内货币）。因为魔法世界的人都把以太当做外置能量，用来释放魔法，而修仙的是吸纳这些能量储存在自己身体里。
# hp归0之后：巽预设了返回的地点，由兑绘制的返回符，是在遇到生命危险时可以紧急传回的符咒，击杀了boss之后，也可以用来返回村落处
# 队友：初始是奕秋，击败诺姆之后诺姆也是可用角色，后面可以通过支线来添加其他角色，暂时做两个
# 奕秋，初始武器：剑气，专属技能：闪避、兽化，可掌握技能：加速，乱击，可掌握武器：扫帚，赤曜，环火
# 诺姆，初始武器：冰针，专属技能：魔纹、激情咏唱，可掌握技能：魔罩，究极，掌握武器：世界树之枝，魔焰，星弹
# NPC：
# 乾：召唤水晶维护（切换角色的地方）自信满满，有点傲娇的天才少年。自认为是"天命之子"，说话时常带着"本座认为..."的口吻。虽然有点自大，但确实有真才实学，能准确判断每个人最适合的角色定位。喜欢用星象和命运来解释事物，有点中二但很可爱。
# 坤：炼丹（eg：小怪材料，boss材料加上坎卖的材料，可以组合炼丹）圆脸，赭石色粗布道袍，有一些烧焦的破烂痕迹，袖口沾着药草碎屑。温柔体贴，像大哥哥一样照顾每个人。有点笨拙但非常认真，经常因为炼丹太专注而忘记吃饭。对各种材料的特性了如指掌，但不善言辞，说话时常常结巴
# 离：铁匠（局外养成之一，强化法宝）铁匠围裙，但花纹繁复一些，衣角焦黑，随身携带沾着火星的锤子。说话声音洪亮，喜欢大笑。对锻造工艺极其热爱，一谈到法宝就眼睛发亮。有点火爆脾气，但来得快去得也快。非常重视承诺，答应的事一定会做到。虽然看起来粗犷，但对细节非常讲究。
# 巽：关卡传送阵，长发束起，穿着花青色轻便服饰，周围飘着羽毛。机智灵活，像风一样难以捉摸。说话带点神秘感，喜欢用谜语和暗示。作为传送阵的管理者，知道很多秘密通道和捷径。有点爱玩，喜欢捉弄别人，但心地不坏。经常突然出现又突然消失，让人捉摸不透。
# 坎，云游商人（每次完成关卡后刷新，如果通关刷新出好东西概率更高）年龄最小，湖蓝色短衫，手持一把画着水波纹的折扇。是精明的商人，说话滴水不漏。擅长察言观色，能准确判断对方想要什么。有点狡猾，但不会做太过分的事。
# 震：进阶（局外养成之二，被动/主动技能树->可以强化升级选项）短发凌乱，藤黄色劲装，腰间别着闪电形状的小铃铛。活力四射的热血少年，总是充满干劲。说话大声，行动迅速，常常不等别人说完就行动。虽然冲动但很讲义气，喜欢挑战高难度的技能升级。有点孩子气，但关键时刻很可靠。经常因为太急躁而犯小错误，然后红着脸道歉。
# 艮：修炼（局外养成之三，直接提升基础属性）敦实体格，雄黄色朴素衣裳。沉稳内敛的修行者，话不多但每句都很有分量。修炼时能保持数小时不动，专注力极强。有点固执，认定的事情很难改变。虽然看起来严肃，但对真心求教的人会耐心指导。
# 兑：合成（eg：通过材料合成新法宝，开启隐藏关卡）石绿色轻便衣裳，衣角缝着贝壳风铃，手里捏着符咒。说话风趣幽默，很会调节气氛。对合成有独特天赋，经常能想到别人想不到的组合。有点话痨。

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
	# 恢复玩家移动
	PC.movement_disabled = false
	
	# 直接隐藏黑色滤镜，无需动画
	if dark_overlay:
		dark_overlay.visible = false
		dark_overlay.modulate.a = 0.0
	
	# 隐藏关卡选择界面
	levelChangeLayer.visible = false

	
func _on_stage_1_pressed() -> void:
	Global.in_town = false
	PC.movement_disabled = false
	PC.reset_player_attr()
	SceneChange.change_scene(battle_scene, true)
	
func _on_stage_2_pressed() -> void:
	Global.in_town = true
	PC.reset_player_attr()




# 凌奕秋，初始武器：剑气，特殊技能：闪避、魔化，可掌握技能：加速，乱击，可掌握武器：扫帚，ry，环火
# 诺姆，初始武器：冰针，特殊技能：魔纹、激情咏唱，可掌握技能：魔罩，究极，掌握武器：世界树之枝，炽炎，星弹


func _switch_layers(target_layer: CanvasLayer, hide_layers: Array, show_controls: Array, show_controls_immediately: bool) -> void:
	# 隐藏旧层
	for layer in hide_layers:
		if layer:
			layer.visible = false
			# 重置所有子节点的透明度，但跳过黑色滤镜
			for child in layer.get_children():
				if child.has_method("set_modulate") and child != dark_overlay:
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
	
	# 淡出当前显示的层的所有子节点，但跳过黑色滤镜
	for layer in hide_layers:
		if layer and layer.visible:
			for child in layer.get_children():
				if child.has_method("set_modulate") and child != dark_overlay:
					transition_tween.tween_property(child, "modulate:a", 0.0, 0.125)
	
	# 等待淡出完成后切换显示状态
	transition_tween.tween_callback(_switch_layers.bind(target_layer, hide_layers, show_controls, show_controls_immediately)).set_delay(0.125)
	
	# 淡入目标层的所有子节点，但跳过黑色滤镜
	if target_layer:
		target_layer.visible = true
		for child in target_layer.get_children():
			if child.has_method("set_modulate") and child != dark_overlay:
				child.modulate.a = 0.0
				transition_tween.tween_property(child, "modulate:a", 1.0, 0.125).set_delay(0.25)
	
