extends Node2D

@export var dialog_control : Control
@export var npc1 : AnimatableBody2D 
@export var npc2 : AnimatableBody2D 
@export var npc3 : AnimatableBody2D 
@export var interaction_distance : float = 40.0 
@export var dialog_file_to_start: String = "res://AssetBundle/Dialog/test_dialog.txt"

var player: CharacterBody2D


func _ready() -> void:
	if $Player is CharacterBody2D:
		player = $Player
	else:
		printerr("Player node not found or not a CharacterBody2D at path: $Player")
		return

	if not Global:
		printerr("Global singleton not found. Make sure it's autoloaded.")
		return

	Global.emit_signal("reset_camera")

	# 确保在项目设置 -> Input Map 中定义了 "interact" 动作并绑定到 F 键
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var event_f_key = InputEventKey.new()
		event_f_key.physical_keycode = KEY_F # Godot 4.x
		InputMap.action_add_event("interact", event_f_key)


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	# 检测 F 键 (映射到 "interact" 动作) 是否按下天才黑魔法师研究出来了可以从未知位面获得以太的方法，然后一直在吸收，直到吸收的太多了导致出现了裂隙，两个世界开始逐渐交汇
	# 直到一次增大获取以太的实验出了事故，把黑魔法师传过来了，传到了朝天山上，过来了之后因为人生地不熟很怕，开启了幻境避免人打扰，却发现魔物在他不知道的地方越来越多。
	# 主角进入了幻境探索，发现每次在击败一个地区的头目之后，幻境都会出现紊乱把他传送出去，但在这段时间击杀的魔物会转化为以太加强自身。
	if Input.is_action_just_pressed("interact"):
		if player.global_position.distance_to($NPC1/AnimatedSprite2D.global_position) < interaction_distance:
			if not dialog_control.visible:
				start_dialog_interaction(1)
			else:
				print_debug("Dialog is already active.")

		#if player.global_position.distance_to($NPC2/AnimatedSprite2D.global_position) < interaction_distance:
			#if not dialog_control.visible:
				#start_dialog_interaction(2)
			#else:
				#print_debug("Dialog is already active.")
# 右侧关卡阵，左侧山洞里密宗长老开隐藏本，左上铁匠圣器打造升级，右上修炼室局外养成加点，中间巨大水晶可以切换人物
# 1个其他世界的黑魔法师，他的世界因为过渡开发以太能源矿，导致以太崩溃，浓缩的以太凝聚成了各种各样的魔物，并且大地上的以太大量减少，寸草不生，人类陷入生存危机。

func start_dialog_interaction(npc_id: int) -> void:
	if not dialog_control.is_inside_tree():
		add_child(dialog_control)
	
	# 确保 dialog_control 可见
	dialog_control.visible = true

	Global.start_dialog.emit(dialog_file_to_start)
