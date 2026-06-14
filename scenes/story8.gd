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
@onready var qian_sprite: AnimatedSprite2D = $qian
@onready var xun_sprite: AnimatedSprite2D = $xun
@onready var kun_sprite: AnimatedSprite2D = $kun
@onready var kansel_sprite: AnimatedSprite2D = $kansel
@onready var noam_sprite: AnimatedSprite2D = $noam
@onready var moning_sprite: AnimatedSprite2D = $moning
@onready var yiqiu_sprite: AnimatedSprite2D = $yiqiu
@onready var bard_sprite: AnimatedSprite2D = $bard

var char_qian: Node2D
var char_xun: Node2D
var char_kansel: Node2D
var char_noam: Node2D
var char_moning: Node2D
var char_yiqiu: Node2D
var char_bard: Node2D
var normal: Control

var _skip_requested: bool = false

# 立绘路径
var ill_qian := "res://AssetBundle/Sprites/npc/qian_full.png"
var ill_xun := "res://AssetBundle/Sprites/npc/xun_full.png"
var ill_kansel := "res://AssetBundle/Sprites/npc/kansel.png"
var ill_noam := "res://AssetBundle/Sprites/npc/noam_full.png"
var ill_moning := "res://AssetBundle/Sprites/npc/moning_full.png"
var ill_yiqiu := "res://AssetBundle/Sprites/npc/yanqiu_full.png"
var ill_bard := "res://AssetBundle/Sprites/npc/bard.png"


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
	var sprites := [qian_sprite, xun_sprite, kansel_sprite, noam_sprite, moning_sprite, yiqiu_sprite, bard_sprite]
	var names := ["qian", "xun", "kansel", "noam", "moning", "yiqiu", "bard"]
	var display_names := ["乾", "巽", "坎塞尔", "诺姆", "墨宁", "言秋", "异国诗人"]
	var anim_names := ["idle", "idle", "idle", "default", "idle", "idle", "default"]
	var chars: Array[Node2D] = []

	for i in range(sprites.size()):
		var sp: AnimatedSprite2D = sprites[i]
		sp.visible = false
		var ch = DIALOG_CHAR_SCENE.instantiate()
		ch.name = "Dialog" + names[i].capitalize()
		ch.scale = sp.scale
		ch.position = sp.position
		add_child(ch)
		sp.reparent(ch)
		sp.position = Vector2.ZERO
		sp.scale = Vector2(1, 1)
		sp.play(anim_names[i])
		ch.init(sp, display_names[i])
		CharacterEffects.create_shadow(ch, 14.0, 5.0, 105.0)
		chars.append(ch)

	char_qian = chars[0]
	char_xun = chars[1]
	char_kansel = chars[2]
	char_noam = chars[3]
	char_moning = chars[4]
	char_yiqiu = chars[5]
	char_bard = chars[6]

	normal = NORMAL_DIALOG_SCENE.instantiate()
	normal.name = "NormalDialog"

	var dialog_layer := CanvasLayer.new()
	dialog_layer.name = "DialogLayer"
	dialog_layer.layer = 128
	dialog_layer.add_child(normal)
	add_child(dialog_layer)
	normal.visible = false

	# skip_button_layer 提高层级，避免被 DialogLayer / 其他 UI 遮挡
	skip_button_layer.layer = 190

	var type_chars := [char_qian, char_xun, char_kansel, char_noam, char_moning, char_yiqiu, char_bard]
	for ch in type_chars:
		ch.type_speed = 0.04


func start_story() -> void:
	if _black_overlay:
		get_tree().create_timer(0.5).timeout.connect(func():
			if _black_overlay:
				var tw = create_tween()
				tw.tween_property(_black_overlay, "color:a", 0.0, 0.5)
				await tw.finished
				_black_overlay.queue_free()
				_black_overlay = null
			_show_skip_button_layer()
		)

	# ── 开场字幕 ──
	await director.show_subtitle("一行人回到了桃源镇……", 3.0)
	if _skip_requested:
		await _skip_to_town()
		return

	# ── 第一段：巽发现新面孔 → 坎塞尔自我介绍 ──
	await director.run([
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "巽", "speaker_position": "left",
					"dialog": "嗯？又是没见过的新面孔？好强的真气波动……",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "各位长老好，我是跟诺姆同属罗穆阿尔多的黑魔法师坎塞尔。",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
			]
		},
	])
	if _skip_requested:
		await _skip_to_town()
		return

	# ── 第二段：乾评价坎塞尔 → 坎塞尔说明年龄和级别 → 乾观察心虚 ──
	await director.run([
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "乾", "speaker_position": "left",
					"dialog": "有意思，你的修为估计都跟巽差不多了，看起来还这么年轻？",
					"illustrationLeft": ill_qian, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "我今年18岁，如果修为指的是魔法水平的话，我已经突破了大魔法师级别，不知道和这边的评级如何对比……",
					"illustrationLeft": ill_qian, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "乾", "speaker_position": "left",
					"dialog": "这不重要，但是我能看到……你现在有些心虚。",
					"illustrationLeft": ill_qian, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "乾", "speaker_position": "left",
					"dialog": "你如果心怀歹意，老夫绝不会手下留情。说说吧，你来到这的目的是什么？",
					"illustrationLeft": ill_qian, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "……真是好敏锐的观察力。",
					"illustrationLeft": ill_qian, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
			]
		},
	])
	if _skip_requested:
		await _skip_to_town()
		return

	# ── 黑屏字幕：坎塞尔向长老们说明情况 ──
	await director.show_subtitle("坎塞尔和众长老们说了他所了解到的事情，以及裂缝的情况……", 3.5)
	if _skip_requested:
		await _skip_to_town()
		return

	# ── 第三段：巽分析 → 乾提问 ──
	await director.run([
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "巽", "speaker_position": "left",
					"dialog": "难怪我无法进入，如果是按灵魂的活跃程度来筛选的话，我们这些有些年纪的，确实不如风系的墨宁和自在天的小少主言秋了。",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "巽", "speaker_position": "left",
					"dialog": "不过，现在看里面真气的狂暴程度，这种自愈的行为似乎并没有起到什么作用。",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "乾", "speaker_position": "left",
					"dialog": "确实，你说的话能解除我们一部分的疑惑，但我还有几个问题想问。",
					"illustrationLeft": ill_qian, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "乾", "speaker_position": "left",
					"dialog": "你说你们皇室会将活人炼制成\"燃料\"，这已经极其残忍，但他们为何要在这个时间点突然加大\"跨位面以太汲取\"的速率？",
					"illustrationLeft": ill_qian, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
			]
		},
	])
	if _skip_requested:
		await _skip_to_town()
		return

	# 坎塞尔沉默表情
	await director.run([
		{"type": "callback", "func": func(): char_kansel.show_emote("slient", 1.5)},
		{"type": "wait", "duration": 1.5},
	])
	if _skip_requested:
		await _skip_to_town()
		return

	# ── 第四段：坎塞尔推测 → 乾追问研究所其他人 ──
	await director.run([
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "说实话，我也不太清楚。皇室的命令对于我们来说，我们只需要遵循，不应该提问。",
					"illustrationLeft": ill_qian, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "不过据我推测，可能和他们在研发之中的巨型战争兵器，究极神兵相关，那是一个运转需要巨量以太的人形兵器，皇室想用那个来打倒大陆上的另一个宿敌国家。",
					"illustrationLeft": ill_qian, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "乾", "speaker_position": "left",
					"dialog": "又是为了战争啊……嗯，我记下了。那接下来下一个问题，你说你整个研究所都被裂缝吸引了过来，那研究所里的其他人呢？",
					"illustrationLeft": ill_qian, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "关于这个……我有一个很不好的推测。他们的灵魂活跃程度应该都不及我和诺姆，如果已经被狂暴的以太侵蚀，他们恐怕会变为极其强大的敌人。",
					"illustrationLeft": ill_qian, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "乾", "speaker_position": "left",
					"dialog": "也就是幻境里面的危险程度会更高……",
					"illustrationLeft": ill_qian, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
			]
		},
	])
	if _skip_requested:
		await _skip_to_town()
		return

	# ── 第五段：巽提议诗人试炼 → 乾同意 → 异国诗人出现 ──
	await director.run([
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "巽", "speaker_position": "left",
					"dialog": "乾长老，不如让他们去试试之前那个诗人编织出来的试炼？我认为在那里面可以大幅提升战斗技巧，对他们有利无弊啊。",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "乾", "speaker_position": "left",
					"dialog": "嗯……说的也是。之前有一位从结界里连滚带爬跑出来的诗人，他的能力还挺有趣的，你们可以去尝试体验一下。",
					"illustrationLeft": ill_qian, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
			]
		},
		# 异国诗人跳跃到指定位置
		{"type": "callback", "func": func(): create_tween().tween_property(char_bard, "position", Vector2(1260, 660), 0.4)},
	])
	if _skip_requested:
		await _skip_to_town()
		return

	# ── 第六段：异国诗人自我介绍 ──
	await director.run([
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "异国诗人", "speaker_position": "right",
					"dialog": "是提到了我吧？你们好啊，我是来自罗穆阿尔多的吟游诗人，你们就叫我异国诗人就好了。",
					"illustrationLeft": ill_qian, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_bard, "illustrationRightStatus": true,
				},
				{
					"speaker": "异国诗人", "speaker_position": "right",
					"dialog": "你们可以告诉我在幻境中所经历过的艰险的战斗，我的能力便是将这些战斗编织成更为史诗壮丽的诗篇，你们可以进入其中体验比以往困难数倍的战斗。",
					"illustrationLeft": ill_qian, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_bard, "illustrationRightStatus": true,
				},
				{
					"speaker": "异国诗人", "speaker_position": "right",
					"dialog": "我所编织的并非普通的冒险故事！而是将你们经历过的危机进一步改编成\"另一种可能性\"——敌人会更残暴，更刁钻，稍有不慎便会失败。",
					"illustrationLeft": ill_qian, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_bard, "illustrationRightStatus": true,
				},
				{
					"speaker": "异国诗人", "speaker_position": "right",
					"dialog": "这种战斗可以快速帮助你们成长，让你们触摸到实力的极限。当然，前提是你们拥有能够跨越绝望的勇气与默契。",
					"illustrationLeft": ill_qian, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_bard, "illustrationRightStatus": true,
				},
			]
		},
	])
	if _skip_requested:
		await _skip_to_town()
		return

	# ── 第七段：乾收尾 ──
	await director.run([
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "乾", "speaker_position": "left",
					"dialog": "呵呵，就是这样，虽然他遣词用句有些……奇怪，不过老夫之前和巽已经体验过了，着实有趣。你们接下来好好休整一番吧，提升实力的事要抓紧了。",
					"illustrationLeft": ill_qian, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_bard, "illustrationRightStatus": true,
				},
			]
		},
	])

	# 结束，返回 main_town
	await _fade_to_town()


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
	for char_node in [char_qian, char_xun, char_kansel, char_noam, char_moning, char_yiqiu, char_bard]:
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


func _skip_to_town() -> void:
	_skip_requested = false
	_cleanup_all_dialog_ui()
	await _fade_out_skip_layer()
	await _fade_to_town()


func _cleanup_all_dialog_ui() -> void:
	normal.visible = false
	for char_node in [char_qian, char_xun, char_kansel, char_noam, char_moning, char_yiqiu, char_bard]:
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


func _fade_to_town() -> void:
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

	Global.has_visited_town = true
	Global.has_seen_story_8 = true
	Global.save_game()
	SceneChange.change_scene("res://Scenes/main_town.tscn", true)
