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
@onready var zhen_sprite: AnimatedSprite2D = $zhen
@onready var moning_sprite: AnimatedSprite2D = $moning
@onready var yiqiu_sprite: AnimatedSprite2D = $yiqiu

var char_zhen: Node2D # dialog_character 震
var char_moning: Node2D # dialog_character 墨宁
var char_yiqiu: Node2D # dialog_character 言秋
var normal: Control # normal_dialog

var _skip_requested: bool = false

# 立绘路径
var ill_zhen := "res://AssetBundle/Sprites/npc/zhen.png"
var ill_moning := "res://AssetBundle/Sprites/npc/moning_full.png"
var ill_yiqiu := "res://AssetBundle/Sprites/npc/yanqiu_full.png"

func _ready() -> void:
	Global.emit_signal("stage_bgm", "town")
	_setup_scene()
	skip_layer.visible = false
	skip_layer.layer = 200
	_set_skip_children_mouse(Control.MOUSE_FILTER_IGNORE)
	skip_button.pressed.connect(_on_skip_pressed)
	skip_ok_button.pressed.connect(_on_skip_ok_pressed)
	skip_cansel_button.pressed.connect(_on_skip_cancel_pressed)
	start_story.call_deferred()


func _setup_scene() -> void:
	var zhen_pos := zhen_sprite.position
	var moning_pos := moning_sprite.position
	var yiqiu_pos := yiqiu_sprite.position
	var zhen_sc := zhen_sprite.scale
	var moning_sc := moning_sprite.scale
	var yiqiu_sc := yiqiu_sprite.scale

	# 隐藏原始精灵
	zhen_sprite.visible = false
	moning_sprite.visible = false
	yiqiu_sprite.visible = false

	# 创建 dialog_character 实例
	char_zhen = DIALOG_CHAR_SCENE.instantiate()
	char_moning = DIALOG_CHAR_SCENE.instantiate()
	char_yiqiu = DIALOG_CHAR_SCENE.instantiate()
	normal = NORMAL_DIALOG_SCENE.instantiate()

	char_zhen.name = "DialogZhen"
	char_moning.name = "DialogMoning"
	char_yiqiu.name = "DialogYiqiu"
	normal.name = "NormalDialog"

	char_zhen.scale = zhen_sc
	char_moning.scale = moning_sc
	char_yiqiu.scale = yiqiu_sc
	char_zhen.position = zhen_pos
	char_moning.position = moning_pos
	char_yiqiu.position = yiqiu_pos

	add_child(char_zhen)
	add_child(char_moning)
	add_child(char_yiqiu)

	# 将原始精灵重新挂载到 dialog_character 下
	zhen_sprite.reparent(char_zhen)
	zhen_sprite.position = Vector2.ZERO
	zhen_sprite.scale = Vector2(1, 1)

	moning_sprite.reparent(char_moning)
	moning_sprite.position = Vector2.ZERO
	moning_sprite.scale = Vector2(1, 1)

	yiqiu_sprite.reparent(char_yiqiu)
	yiqiu_sprite.position = Vector2.ZERO
	yiqiu_sprite.scale = Vector2(1, 1)

	# 初始化 dialog_character
	char_zhen.init(zhen_sprite, "震")
	char_moning.init(moning_sprite, "墨宁")
	char_yiqiu.init(yiqiu_sprite, "言秋")

	# 确保精灵播放 idle 动画
	zhen_sprite.play("default")
	moning_sprite.play("idle")
	yiqiu_sprite.play("idle")

	# 为每个角色创建脚底阴影
	CharacterEffects.create_shadow(char_zhen, 14.0, 5.0, 105.0)
	CharacterEffects.create_shadow(char_moning, 14.0, 5.0, 105.0)
	CharacterEffects.create_shadow(char_yiqiu, 14.0, 5.0, 105.0)

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
	char_zhen.type_speed = 0.04
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

	# 字幕：刚从幻境中出来，一个穿着明黄色衣服的青年便跑了过来……
	await director.show_subtitle(
		"刚从幻境中出来，一个穿着明黄色衣服的青年便跑了过来……",
		3.0
	)
	if _skip_requested:
		await _skip_to_town()
		return

	# ── 第一段对话 ──
	await director.run([
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "震", "speaker_position": "left",
					"dialog": "咦，你们从幻境中回来了啊？",
					"illustrationLeft": ill_zhen, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
				},
				{
					"speaker": "墨宁", "speaker_position": "right",
					"dialog": "震长老？您来这里是？",
					"illustrationLeft": ill_zhen, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_moning, "illustrationRightStatus": true,
				},
				{
					"speaker": "震", "speaker_position": "left",
					"dialog": "这不是巽喊我来的么，他说这镇子上有个年久失修的炼丹炉，让我过来修理修理。",
					"illustrationLeft": ill_zhen, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_moning, "illustrationRightStatus": false,
				},
				{
					"speaker": "震", "speaker_position": "left",
					"dialog": "这不，给你们修好了，之后你们就可以用这炉子制作丹药，熔炼灵石什么的了！",
					"illustrationLeft": ill_zhen, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_moning, "illustrationRightStatus": false,
				},
				{
					"speaker": "言秋", "speaker_position": "right",
					"dialog": "哇，震长老太厉害了，手艺真是巧夺天工呀！",
					"illustrationLeft": ill_zhen, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_yiqiu, "illustrationRightStatus": true,
				},
				{
					"speaker": "言秋", "speaker_position": "right",
					"dialog": "不像墨宁，上次修个机关鸟都给它彻底修报废了……",
					"illustrationLeft": ill_zhen, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_yiqiu, "illustrationRightStatus": true,
				},
				{
					"speaker": "墨宁", "speaker_position": "right",
					"dialog": "…………呃。",
					"illustrationLeft": ill_zhen, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_moning, "illustrationRightStatus": true,
				},
				{
					"speaker": "震", "speaker_position": "left",
					"dialog": "哈哈哈，自在天的小少主还真会夸人！不过墨宁你也别气馁，接下来我还会在桃源镇呆一段时间，我可以给你指点一二。",
					"illustrationLeft": ill_zhen, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_yiqiu, "illustrationRightStatus": false,
				},
				{
					"speaker": "震", "speaker_position": "left",
					"dialog": "另外，如果你们有什么幻境里的特殊材料，可以给我看看，我对里面的生态环境，各式材料还是很感兴趣的。",
					"illustrationLeft": ill_zhen, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_yiqiu, "illustrationRightStatus": false,
				},
				{
					"speaker": "震", "speaker_position": "left",
					"dialog": "当然，好处也是少不了你们的！",
					"illustrationLeft": ill_zhen, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_yiqiu, "illustrationRightStatus": false,
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
	for char_node in [char_zhen, char_moning, char_yiqiu]:
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
	for char_node in [char_zhen, char_moning, char_yiqiu]:
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
