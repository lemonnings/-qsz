extends Node2D

const DIALOG_CHAR_SCENE = preload("res://Scenes/global/dialog_character.tscn")
const NORMAL_DIALOG_SCENE = preload("res://Scenes/global/normal_dialog.tscn")

@onready var director: DialogDirector = $DialogDirector
@onready var skip_button: Button = $skip_button_layer/skip
@onready var skip_layer: CanvasLayer = $skipLayer
@onready var skip_button_layer: CanvasLayer = $skip_button_layer
@onready var skip_ok_button: Button = $skipLayer/Control/skip
@onready var skip_cansel_button: Button = $skipLayer/Control/cancel

@onready var _black_overlay: ColorRect = $ColorRect

# 场景中原有的 AnimatedSprite2D
# story_5.tscn 中使用 qian 节点作为诺姆的精灵
@onready var noam_sprite: AnimatedSprite2D = $noam
@onready var stone_sprite: AnimatedSprite2D = $sdtone
@onready var moning_sprite: AnimatedSprite2D = $moning
@onready var yiqiu_sprite: AnimatedSprite2D = $yiqiu

var char_noam: Node2D # dialog_character 诺姆
var char_stone: Node2D # dialog_character 石头人
var char_moning: Node2D # dialog_character 墨宁
var char_yiqiu: Node2D # dialog_character 言秋
var normal: Control # normal_dialog

var _skip_requested: bool = false

# 立绘路径
var ill_noam := "res://AssetBundle/Sprites/npc/noam_full.png"
var ill_moning := "res://AssetBundle/Sprites/npc/moning_full.png"
var ill_yiqiu := "res://AssetBundle/Sprites/npc/yanqiu_full.png"


func _ready() -> void:
	_setup_scene()
	skip_layer.visible = false
	skip_layer.layer = 200
	_set_skip_children_mouse(Control.MOUSE_FILTER_IGNORE)
	skip_button.pressed.connect(_on_skip_pressed)
	skip_ok_button.pressed.connect(_on_skip_ok_pressed)
	skip_cansel_button.pressed.connect(_on_skip_cancel_pressed)
	start_story.call_deferred()


func _setup_scene() -> void:
	var noam_pos := noam_sprite.position
	var stone_pos := stone_sprite.position
	var moning_pos := moning_sprite.position
	var yiqiu_pos := yiqiu_sprite.position
	var noam_sc := noam_sprite.scale
	var stone_sc := stone_sprite.scale
	var moning_sc := moning_sprite.scale
	var yiqiu_sc := yiqiu_sprite.scale

	# 隐藏原始精灵
	noam_sprite.visible = false
	stone_sprite.visible = false
	moning_sprite.visible = false
	yiqiu_sprite.visible = false

	# 隐藏不需要的角色精灵
	if has_node("yanlie"):
		$yanlie.visible = false

	# 创建 dialog_character 实例
	char_noam = DIALOG_CHAR_SCENE.instantiate()
	char_stone = DIALOG_CHAR_SCENE.instantiate()
	char_moning = DIALOG_CHAR_SCENE.instantiate()
	char_yiqiu = DIALOG_CHAR_SCENE.instantiate()
	normal = NORMAL_DIALOG_SCENE.instantiate()

	char_noam.name = "DialogNoam"
	char_stone.name = "DialogStone"
	char_moning.name = "DialogMoning"
	char_yiqiu.name = "DialogYiqiu"
	normal.name = "NormalDialog"

	char_noam.scale = noam_sc
	char_stone.scale = stone_sc
	char_moning.scale = moning_sc
	char_yiqiu.scale = yiqiu_sc
	char_noam.position = noam_pos
	char_stone.position = stone_pos
	char_moning.position = moning_pos
	char_yiqiu.position = yiqiu_pos

	add_child(char_noam)
	add_child(char_stone)
	add_child(char_moning)
	add_child(char_yiqiu)

	# 将原始精灵重新挂载到 dialog_character 下
	noam_sprite.reparent(char_noam)
	noam_sprite.position = Vector2.ZERO
	noam_sprite.scale = Vector2(1, 1)

	stone_sprite.reparent(char_stone)
	stone_sprite.position = Vector2.ZERO
	stone_sprite.scale = Vector2(1, 1)

	moning_sprite.reparent(char_moning)
	moning_sprite.position = Vector2.ZERO
	moning_sprite.scale = Vector2(1, 1)

	yiqiu_sprite.reparent(char_yiqiu)
	yiqiu_sprite.position = Vector2.ZERO
	yiqiu_sprite.scale = Vector2(1, 1)

	# 初始化 dialog_character
	char_noam.init(noam_sprite, "诺姆")
	char_stone.init(stone_sprite, "？？")
	char_moning.init(moning_sprite, "墨宁")
	char_yiqiu.init(yiqiu_sprite, "言秋")

	# 确保精灵播放动画
	noam_sprite.play("default")
	stone_sprite.play("default")
	moning_sprite.play("idle")
	yiqiu_sprite.play("idle")

	# 为每个角色创建脚底阴影
	CharacterEffects.create_shadow(char_noam, 14.0, 5.0, 105.0)
	CharacterEffects.create_shadow(char_stone, 14.0, 5.0, 105.0)
	CharacterEffects.create_shadow(char_moning, 14.0, 5.0, 105.0)
	CharacterEffects.create_shadow(char_yiqiu, 14.0, 5.0, 105.0)

	# 诺姆初始不可见，等剧情中出现
	char_noam.visible = false

	# NormalDialog 放入 CanvasLayer
	var dialog_layer := CanvasLayer.new()
	dialog_layer.name = "DialogLayer"
	dialog_layer.layer = 128
	dialog_layer.add_child(normal)
	add_child(dialog_layer)
	normal.visible = false

	# skip_button_layer 提高层级，避免被 DialogLayer / 其他 UI 遮挡
	skip_button_layer.layer = 190

	# 打字速度
	char_noam.type_speed = 0.04
	char_stone.type_speed = 0.04
	char_moning.type_speed = 0.04
	char_yiqiu.type_speed = 0.04


func start_story() -> void:
	# 第一行字幕开始播放 0.5 秒后，渐出开场黑屏（参考 story1 模式）
	if _black_overlay:
		get_tree().create_timer(0.5).timeout.connect(func():
			if _black_overlay:
				var tw = create_tween()
				tw.tween_property(_black_overlay, "color:a", 0.0, 0.5)
				await tw.finished
				_black_overlay.queue_free()
				_black_overlay = null

			# 黑屏渐出后，显示 skip_button_layer 并渐变出现
			_show_skip_button_layer()
		)

	# 字幕
	await director.show_subtitle(
		"一番苦战之后，墨宁和言秋总算是把这个奇怪的石头人打倒了……",
		3.5
	)
	if _skip_requested:
		await _skip_to_story6()
		return

	# ── 第一段对话：战斗后的对话 ──
	await director.run([
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "言秋", "speaker_position": "left",
					"dialog": "呼……这石头人还真是难缠，这幻境里还能诞生出这样的精怪吗？",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": "", "illustrationRightStatus": false,
				},
				{
					"speaker": "墨宁", "speaker_position": "left",
					"dialog": "我们这也只是打到他不能动弹为止……似乎还没有真正把他摧毁掉，要小心点，以防他又恢复行动。",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": "", "illustrationRightStatus": false,
				},
				{
					"speaker": "言秋", "speaker_position": "left",
					"dialog": "知道啦……那我们现在把他彻底拆个稀巴烂？",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": "", "illustrationRightStatus": false,
				},
				{
					"speaker": "墨宁", "speaker_position": "left",
					"dialog": "……嘘，我好像听到了什么动静？",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": "", "illustrationRightStatus": false,
				},
			]
		},
		# 石头人弹出小对话框
		{"type": "callback", "func": func(): char_stone.speak("！？……")},
	])
	# 等待对话框展示
	await get_tree().create_timer(2.0).timeout
	if _skip_requested:
		await _skip_to_story6()
		return

	# ── 第三段：发现石头人里有人 ──
	await director.run([
		{"type": "callback", "func": func(): char_moning.show_emote("slient", 1.5)},
		{"type": "wait", "duration": 1.5},
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "墨宁", "speaker_position": "left",
					"dialog": "……不会这石头人里面，是有人在操控吧？",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": "", "illustrationRightStatus": false,
				},
				{
					"speaker": "言秋", "speaker_position": "left",
					"dialog": "啊？",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": "", "illustrationRightStatus": false,
				},
			]
		},
		# 墨宁向右走30像素
		{"type": "callback", "func": func(): create_tween().tween_property(char_moning, "position:x", char_moning.position.x + 30.0, 0.4)},
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "墨宁", "speaker_position": "left",
					"dialog": "还不出来吗？那就别怪我们不客气了！",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": "", "illustrationRightStatus": false,
				},
			]
		},
		{"type": "wait", "duration": 0.5},
		{"type": "callback", "func": func(): char_noam.show_emote("surprise", 1.5)},
		{"type": "wait", "duration": 1.5},
	])
	if _skip_requested:
		await _skip_to_story6()
		return

	# ── 诺姆跳出来 ──
	await _transition_stone_to_noam()
	# 诺姆弹出小对话框（语言不通）
	char_noam.init(noam_sprite, "诺姆")
	char_noam.speak("%@&^@#！")
	await get_tree().create_timer(2.0).timeout
	if _skip_requested:
		await _skip_to_story6()
		return

	# ── 第四段：语言不通 ──
	await director.run([
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "言秋", "speaker_position": "left",
					"dialog": "还真有人啊！呃，你在说些什么？",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": "", "illustrationRightStatus": false,
				},
			]
		},
	])
	if _skip_requested:
		await _skip_to_story6()
		return

	# 诺姆再次小对话框
	char_noam.speak("&#^~#@%？")
	await get_tree().create_timer(2.0).timeout
	if _skip_requested:
		await _skip_to_story6()
		return

	await director.run([
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "墨宁", "speaker_position": "left",
					"dialog": "……我们听不懂哎。",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": "", "illustrationRightStatus": false,
				},
			]
		},
	])
	if _skip_requested:
		await _skip_to_story6()
		return

	# 诺姆沉默
	char_noam.speak("……")
	await get_tree().create_timer(2.0).timeout
	if _skip_requested:
		await _skip_to_story6()
		return

	# ── 诺姆升级动画（翻译魔法） ──
	char_noam.show_emote("idea", 1.5)
	await get_tree().create_timer(2).timeout
	if _skip_requested:
		await _skip_to_story6()
		return

	# 金光闪烁效果
	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 180
	add_child(flash_layer)
	var flash_rect := ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1.0, 0.95, 0.5, 0.0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_layer.add_child(flash_rect)
	var flash_tw := create_tween()
	flash_tw.tween_property(flash_rect, "color:a", 0.6, 0.15)
	flash_tw.tween_property(flash_rect, "color:a", 0.0, 0.35)
	await flash_tw.finished
	flash_layer.queue_free()

	await get_tree().create_timer(1.0).timeout
	if _skip_requested:
		await _skip_to_story6()
		return

	# ── 第五段：语言通了 ──
	await director.run([
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "诺姆", "speaker_position": "right",
					"dialog": "啊……现在可以听懂了吗？",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_noam, "illustrationRightStatus": true,
				},
				{
					"speaker": "墨宁", "speaker_position": "left",
					"dialog": "嗯？现在可以了……你这是用了什么法术？",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_noam, "illustrationRightStatus": false,
				},
				{
					"speaker": "诺姆", "speaker_position": "right",
					"dialog": "法……术？是指的魔法吗？确实是一种魔法，本来是用来和动物沟通的，不过改编了一些之后也可以拿来和语言不通的人沟通……",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_noam, "illustrationRightStatus": true,
				},
				{
					"speaker": "墨宁", "speaker_position": "left",
					"dialog": "听起来和唤兽宗的秘法差不多？不对不对，你先别动！你怎么突然过来袭击我们？",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_noam, "illustrationRightStatus": false,
				},
				{
					"speaker": "诺姆", "speaker_position": "right",
					"dialog": "我我我我以为你们是坏人，怎么一进遗迹就开始把这些纸人，红纸团都打烂了！",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_noam, "illustrationRightStatus": true,
				},
				{
					"speaker": "墨宁", "speaker_position": "left",
					"dialog": "他们是被暴动的真气侵蚀成了不分善恶的精怪，会主动袭击我们。我们是为了探索幻境的更深处才收拾掉他们的。",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_noam, "illustrationRightStatus": false,
				},
				{
					"speaker": "诺姆", "speaker_position": "right",
					"dialog": "这……这样吗，我是刚来到这里的，这里看起来和我之前呆的地方完全不一样……我也不知道我为什么会来到这里。",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_noam, "illustrationRightStatus": true,
				},
				{
					"speaker": "诺姆", "speaker_position": "right",
					"dialog": "我以为你们是坏人，就想把你们赶走……对不起……",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_noam, "illustrationRightStatus": true,
				},
				{
					"speaker": "言秋", "speaker_position": "left",
					"dialog": "所以你不是坏人？",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_noam, "illustrationRightStatus": false,
				},
				{
					"speaker": "诺姆", "speaker_position": "right",
					"dialog": "不、不是的！真的很抱歉……",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_noam, "illustrationRightStatus": true,
				},
				{
					"speaker": "言秋", "speaker_position": "left",
					"dialog": "好啦好啦，怎么感觉你跟我年纪差不多？而且长得也很奇怪，第一次见到你这种长相的！",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_noam, "illustrationRightStatus": false,
				},
				{
					"speaker": "诺姆", "speaker_position": "right",
					"dialog": "诶、诶？我是罗穆阿尔多人！今年11岁，是罗穆阿尔多的皇家白魔法师……的预备役之一。这是哪里？",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_noam, "illustrationRightStatus": true,
				},
				{
					"speaker": "墨宁", "speaker_position": "left",
					"dialog": "这里是明珑天衍宗治下，罗穆阿尔多是哪？没听说过啊。",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_noam, "illustrationRightStatus": false,
				},
				{
					"speaker": "诺姆", "speaker_position": "right",
					"dialog": "明珑？我也没听说过……呜，这下糟糕了，我该怎么回去啊……",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_noam, "illustrationRightStatus": true,
				},
				{
					"speaker": "墨宁", "speaker_position": "left",
					"dialog": "你先别急，正好这附近精怪暂且都被我们清光了，我们来跟你说下现在事情的经过，看看对你有没有什么帮助。",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_noam, "illustrationRightStatus": false,
				},
			]
		},
	])
	if _skip_requested:
		await _skip_to_story6()
		return

	# ── 黑屏字幕：解释幻境 ──
	await director.show_subtitle(
		"墨宁和言秋与诺姆解释了他们的目的，以及幻境、裂缝的未解之谜。",
		3.0
	)
	if _skip_requested:
		await _skip_to_story6()
		return

	# ── 第七段：诺姆的推测 ──
	await director.run([
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "诺姆", "speaker_position": "right",
					"dialog": "怎么会这样……按你的描述，我可能知道是为什么了……不过也只是我的猜测。",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_noam, "illustrationRightStatus": true,
				},
				{
					"speaker": "诺姆", "speaker_position": "right",
					"dialog": "看到前面那个山洞了吗，我刚来到这里的时候，我感受到在山洞的深处有一股十分熟悉而强大的奥术力量。",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_noam, "illustrationRightStatus": true,
				},
				{
					"speaker": "墨宁", "speaker_position": "left",
					"dialog": "奥术……力量？那是什么？",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_noam, "illustrationRightStatus": false,
				},
				{
					"speaker": "诺姆", "speaker_position": "right",
					"dialog": "就是我们用的魔法力量啦，也许跟你们使出的力量也差不多？",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_noam, "illustrationRightStatus": true,
				},
				{
					"speaker": "诺姆", "speaker_position": "right",
					"dialog": "那个强大的奥术力量背后，可能就是制造了这个幻境的坏人！不过凭我们现在的实力，恐怕还很难抗衡那个力量……",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_noam, "illustrationRightStatus": true,
				},
				{
					"speaker": "墨宁", "speaker_position": "left",
					"dialog": "实力不足吗……要不这样，小诺姆你先跟我们回桃源镇，或许在修习一番过后，实力还能增强一些。",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_noam, "illustrationRightStatus": false,
				},
				{
					"speaker": "诺姆", "speaker_position": "right",
					"dialog": "小诺姆是什么称呼……",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_noam, "illustrationRightStatus": true,
				},
				{
					"speaker": "诺姆", "speaker_position": "right",
					"dialog": "不过……我还不知道我能不能正常离开这个幻境来着。毕竟我跟你们好像不太一样？",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_noam, "illustrationRightStatus": true,
				},
				{
					"speaker": "言秋", "speaker_position": "left",
					"dialog": "试试嘛，如果不行的话我们再想办法！",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_noam, "illustrationRightStatus": false,
				},
				{
					"speaker": "诺姆", "speaker_position": "right",
					"dialog": "嗯……好吧！",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_noam, "illustrationRightStatus": true,
				},
			]
		},
	])

	# 结束，传送到story_6
	await _fade_to_story6()


# ============== 跳过按钮逻辑 ==============

func _set_skip_children_mouse(mode: int) -> void:
	for child in skip_layer.get_children():
		if child is Control:
			child.mouse_filter = mode


func _show_skip_button_layer() -> void:
	if not skip_button:
		return
	skip_button.visible = true
	skip_button.modulate.a = 0.0
	skip_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tw := get_tree().create_tween()
	tw.tween_property(skip_button, "modulate:a", 1.0, 0.4)
	await tw.finished

	skip_button.mouse_filter = Control.MOUSE_FILTER_STOP


func _on_skip_pressed() -> void:
	_fade_in_skip_layer()


func _fade_in_skip_layer() -> void:
	skip_layer.visible = true
	skip_ok_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_cansel_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in skip_layer.get_children():
		if child is CanvasItem:
			child.modulate.a = 0.0
			var tw := create_tween()
			tw.tween_property(child, "modulate:a", 1.0, 0.3)
	await get_tree().create_timer(0.3).timeout
	skip_ok_button.mouse_filter = Control.MOUSE_FILTER_STOP
	skip_cansel_button.mouse_filter = Control.MOUSE_FILTER_STOP


func _on_skip_ok_pressed() -> void:
	_skip_requested = true
	director.cancel()
	if normal.has_signal("dialog_completed"):
		normal.emit_signal("dialog_completed")
	for char_node in [char_noam, char_stone, char_moning, char_yiqiu]:
		if char_node and char_node.has_signal("speech_completed"):
			char_node.emit_signal("speech_completed")
	_fade_out_skip_layer()


func _on_skip_cancel_pressed() -> void:
	_fade_out_skip_layer()


func _fade_out_skip_layer() -> void:
	skip_ok_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_cansel_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in skip_layer.get_children():
		if child is CanvasItem:
			var tw := create_tween()
			tw.tween_property(child, "modulate:a", 0.0, 0.3)
	await get_tree().create_timer(0.3).timeout
	skip_layer.visible = false


func _skip_to_story6() -> void:
	_skip_requested = false
	_cleanup_all_dialog_ui()
	await _fade_out_skip_layer()
	await _fade_to_story6()


func _cleanup_all_dialog_ui() -> void:
	normal.visible = false
	for char_node in [char_noam, char_stone, char_moning, char_yiqiu]:
		if not char_node:
			continue
		var panel = char_node.get("dialog_panel")
		if panel:
			panel.visible = false
			panel.modulate.a = 1.0
		var emote_node = char_node.get("emote")
		if emote_node:
			emote_node.visible = false
			emote_node.modulate.a = 1.0
		char_node.modulate.a = 1.0
	for child in director.get_children():
		if child is CanvasLayer:
			child.queue_free()


func _transition_stone_to_noam() -> void:
	char_stone.visible = true
	char_stone.modulate.a = 1.0
	char_noam.visible = true
	char_noam.modulate.a = 0.0

	var tw := create_tween().set_parallel(true)
	tw.tween_property(char_stone, "modulate:a", 0.0, 1.0)
	tw.tween_property(char_noam, "modulate:a", 1.0, 1.0)
	await tw.finished

	char_stone.visible = false
	char_stone.modulate.a = 1.0
	char_noam.modulate.a = 1.0


func _fade_to_story6() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 200
	add_child(overlay)

	var container := Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(container)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0)
	container.add_child(bg)

	var fade_in := create_tween()
	fade_in.tween_property(bg, "color:a", 1.0, 0.8)
	await fade_in.finished

	SceneChange.change_scene("res://Scenes/story/story_6.tscn", true)
