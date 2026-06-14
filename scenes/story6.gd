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
@onready var kun_sprite: AnimatedSprite2D = $kun
@onready var xun_sprite: AnimatedSprite2D = $xun
@onready var moning_sprite: AnimatedSprite2D = $moning
@onready var yiqiu_sprite: AnimatedSprite2D = $yiqiu
var char_noam: Node2D # dialog_character 诺姆
@onready var noam_sprite: AnimatedSprite2D = $noam
var char_qian: Node2D # dialog_character 乾
var char_kun: Node2D # dialog_character 坤
var char_xun: Node2D # dialog_character 巽
var char_moning: Node2D # dialog_character 墨宁
var char_yiqiu: Node2D # dialog_character 言秋
var normal: Control # normal_dialog

var _skip_requested: bool = false

# 立绘路径
var ill_qian := "res://AssetBundle/Sprites/npc/qian_full.png"
var ill_xun := "res://AssetBundle/Sprites/npc/xun_full.png"
var ill_kun := "res://AssetBundle/Sprites/npc/kun.png"
var ill_moning := "res://AssetBundle/Sprites/npc/moning_full.png"
var ill_yiqiu := "res://AssetBundle/Sprites/npc/yanqiu_full.png"
var ill_noam := "res://AssetBundle/Sprites/npc/noam_full.png"


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
	var qian_pos := qian_sprite.position
	var kun_pos := kun_sprite.position
	var xun_pos := xun_sprite.position
	var moning_pos := moning_sprite.position
	var yiqiu_pos := yiqiu_sprite.position
	var noam_pos := noam_sprite.position
	var qian_sc := qian_sprite.scale
	var kun_sc := kun_sprite.scale
	var xun_sc := xun_sprite.scale
	var moning_sc := moning_sprite.scale
	var yiqiu_sc := yiqiu_sprite.scale
	var noam_sc := noam_sprite.scale

	# 隐藏原始精灵
	qian_sprite.visible = false
	kun_sprite.visible = false
	xun_sprite.visible = false
	moning_sprite.visible = false
	yiqiu_sprite.visible = false
	noam_sprite.visible = false

	# 创建 dialog_character 实例
	char_qian = DIALOG_CHAR_SCENE.instantiate()
	char_kun = DIALOG_CHAR_SCENE.instantiate()
	char_xun = DIALOG_CHAR_SCENE.instantiate()
	char_moning = DIALOG_CHAR_SCENE.instantiate()
	char_yiqiu = DIALOG_CHAR_SCENE.instantiate()
	char_noam = DIALOG_CHAR_SCENE.instantiate()
	normal = NORMAL_DIALOG_SCENE.instantiate()

	char_qian.name = "DialogQian"
	char_kun.name = "DialogKun"
	char_xun.name = "DialogXun"
	char_moning.name = "DialogMoning"
	char_yiqiu.name = "DialogYiqiu"
	char_noam.name = "DialogNoam"
	normal.name = "NormalDialog"

	char_qian.scale = qian_sc
	char_kun.scale = kun_sc
	char_xun.scale = xun_sc
	char_moning.scale = moning_sc
	char_yiqiu.scale = yiqiu_sc
	char_noam.scale = noam_sc
	char_qian.position = qian_pos
	char_kun.position = kun_pos
	char_xun.position = xun_pos
	char_moning.position = moning_pos
	char_yiqiu.position = yiqiu_pos
	char_noam.position = noam_pos

	add_child(char_qian)
	add_child(char_kun)
	add_child(char_xun)
	add_child(char_moning)
	add_child(char_yiqiu)
	add_child(char_noam)

	# 将原始精灵重新挂载到 dialog_character 下
	qian_sprite.reparent(char_qian)
	qian_sprite.position = Vector2.ZERO
	qian_sprite.scale = Vector2(1, 1)

	kun_sprite.reparent(char_kun)
	kun_sprite.position = Vector2.ZERO
	kun_sprite.scale = Vector2(1, 1)

	xun_sprite.reparent(char_xun)
	xun_sprite.position = Vector2.ZERO
	xun_sprite.scale = Vector2(1, 1)

	moning_sprite.reparent(char_moning)
	moning_sprite.position = Vector2.ZERO
	moning_sprite.scale = Vector2(1, 1)

	yiqiu_sprite.reparent(char_yiqiu)
	yiqiu_sprite.position = Vector2.ZERO
	yiqiu_sprite.scale = Vector2(1, 1)

	noam_sprite.reparent(char_noam)
	noam_sprite.position = Vector2.ZERO
	noam_sprite.scale = Vector2(1, 1)

	# 初始化 dialog_character
	char_qian.init(qian_sprite, "乾")
	char_kun.init(kun_sprite, "坤")
	char_xun.init(xun_sprite, "巽")
	char_moning.init(moning_sprite, "墨宁")
	char_yiqiu.init(yiqiu_sprite, "言秋")
	char_noam.init(noam_sprite, "诺姆")

	# 确保精灵播放 idle 动画
	qian_sprite.play("idle")
	kun_sprite.play("default")
	xun_sprite.play("idle")
	moning_sprite.play("idle")
	yiqiu_sprite.play("idle")
	noam_sprite.play("default")

	# 为每个角色创建脚底阴影
	CharacterEffects.create_shadow(char_qian, 14.0, 5.0, 105.0)
	CharacterEffects.create_shadow(char_kun, 14.0, 5.0, 105.0)
	CharacterEffects.create_shadow(char_xun, 14.0, 5.0, 105.0)
	CharacterEffects.create_shadow(char_moning, 14.0, 5.0, 105.0)
	CharacterEffects.create_shadow(char_yiqiu, 14.0, 5.0, 105.0)
	CharacterEffects.create_shadow(char_noam, 14.0, 5.0, 105.0)

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
	char_qian.type_speed = 0.04
	char_kun.type_speed = 0.04
	char_xun.type_speed = 0.04
	char_moning.type_speed = 0.04
	char_yiqiu.type_speed = 0.04
	char_noam.type_speed = 0.04


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
		"诺姆顺利的通过传送符与墨宁、言秋一同回到了桃源镇里……",
		3.0
	)
	if _skip_requested:
		await _skip_to_town()
		return

	# ── 第一段对话：遇到坤长老 ──
	await director.run([
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "坤", "speaker_position": "left",
					"dialog": "哦？这位金发的小友是……？",
					"illustrationLeft": ill_kun, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
				},
				{
					"speaker": "墨宁", "speaker_position": "right",
					"dialog": "坤长老？您也来这里了啊！这位是我和言秋在幻境里面遇到的来自罗什么……",
					"illustrationLeft": ill_kun, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_moning, "illustrationRightStatus": true,
				},
			]
		},
		# 诺姆小对话框
		{"type": "callback", "func": func(): char_noam.speak("罗穆阿尔多！")},
	])
	await get_tree().create_timer(1.5).timeout
	if _skip_requested:
		await _skip_to_town()
		return

	await director.run([
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "墨宁", "speaker_position": "right",
					"dialog": "哦对……罗穆阿尔多的皇家白什么……",
					"illustrationLeft": "", "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_moning, "illustrationRightStatus": true,
				},
			]
		},
		# 诺姆再次小对话框
		{"type": "callback", "func": func(): char_noam.speak("白魔法师……预备役！")},
	])
	await get_tree().create_timer(2.0).timeout
	if _skip_requested:
		await _skip_to_town()
		return

	await director.run([
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "墨宁", "speaker_position": "right",
					"dialog": "……总之，他是另一个地方来到这里的一名白魔法师。",
					"illustrationLeft": "", "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_moning, "illustrationRightStatus": true,
				},
			]
		},
		# 乾、巽、坤头顶同时出现 slient 的 emote，1.5秒
		{"type": "callback", "func": func(): char_qian.show_emote("slient", 1.5)},
		{"type": "callback", "func": func(): char_xun.show_emote("slient", 1.5)},
		{"type": "callback", "func": func(): char_kun.show_emote("slient", 1.5)},
		{"type": "wait", "duration": 1.5},
	])
	if _skip_requested:
		await _skip_to_town()
		return

	# ── 黑屏字幕：三人跟几位长老说明了来龙去脉 ──
	await director.show_subtitle(
		"三人跟几位长老说明了来龙去脉……",
		3.0
	)
	if _skip_requested:
		await _skip_to_town()
		return

	# ── 第二段对话：长老们的反应 ──
	await director.run([
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "巽", "speaker_position": "left",
					"dialog": "所以这幻境大阵，可能真的并非是明珑大陆上的阵法，罗穆阿尔多……我从未听说过。",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
				},
				{
					"speaker": "乾", "speaker_position": "left",
					"dialog": "这\"魔法\"能让说着不同语言的人理解对方的意思，着实有趣。",
					"illustrationLeft": ill_qian, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
				},
				{
					"speaker": "乾", "speaker_position": "left",
					"dialog": "如果你有兴趣的话，也可以了解一下我们这边的修炼体系，或许也对你有用。",
					"illustrationLeft": ill_qian, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
				},
				{
					"speaker": "坤", "speaker_position": "left",
					"dialog": "哦，说到这儿，老乾找我来就是为了此事。",
					"illustrationLeft": ill_kun, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
				},
				{
					"speaker": "坤", "speaker_position": "left",
					"dialog": "听闻你们已经拿到了幻境里首领内部的魔核，这里面的力量如果凝缩起来，对你们的修炼大有裨益。",
					"illustrationLeft": ill_kun, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
				},
				{
					"speaker": "坤", "speaker_position": "left",
					"dialog": "之后你们便可以找我，我可以为你们凝缩魔核之中的力量，在你们修炼之途上助一臂之力。",
					"illustrationLeft": ill_kun, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
				},
				{
					"speaker": "诺姆", "speaker_position": "right",
					"dialog": "……虽然没听太懂，但是谢谢你们！",
					"illustrationLeft": ill_kun, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_noam, "illustrationRightStatus": true,
				},
				{
					"speaker": "乾", "speaker_position": "left",
					"dialog": "嗯，看你本质不坏，希望你能坚守本心，不要心生歹意，否则墨宁和言秋都不会再手下留情的。",
					"illustrationLeft": ill_qian, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_noam, "illustrationRightStatus": false,
				},
				{
					"speaker": "诺姆", "speaker_position": "right",
					"dialog": "都说了之前是误会啦！之后我们会好好相处的！",
					"illustrationLeft": ill_qian, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_noam, "illustrationRightStatus": true,
				},
				{
					"speaker": "言秋", "speaker_position": "right",
					"dialog": "好哦！顺利解决！接下来再修炼一番，就可以去那个深窟里探险了！",
					"illustrationLeft": ill_qian, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_yiqiu, "illustrationRightStatus": true,
				},
			]
		},
	])

	# 结束，传送到main_town.tscn
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
	for char_node in [char_qian, char_kun, char_xun, char_moning, char_yiqiu, char_noam]:
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
	for char_node in [char_qian, char_kun, char_xun, char_moning, char_yiqiu, char_noam]:
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

	# 切换到 main_town 场景
	Global.has_visited_town = true
	SceneChange.change_scene("res://Scenes/main_town.tscn", true)
