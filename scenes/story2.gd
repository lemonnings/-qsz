extends Node2D

const DIALOG_CHAR_SCENE = preload("res://Scenes/global/dialog_character.tscn")
const NORMAL_DIALOG_SCENE = preload("res://Scenes/global/normal_dialog.tscn")

@onready var director: DialogDirector = $DialogDirector
@onready var skip_button: Button = $skip_button_layer/skip
@onready var skip_layer: CanvasLayer = $skipLayer
@onready var skip_button_layer: CanvasLayer = $skip_button_layer
@export var skip_ok_button: Button
@export var skip_cansel_button: Button

@onready var _black_overlay: ColorRect = $ColorRect

# 场景中原有的 AnimatedSprite2D
@onready var qian_sprite: AnimatedSprite2D = $qian
@onready var xun_sprite: AnimatedSprite2D = $xun
@onready var moning_sprite: AnimatedSprite2D = $moning
@onready var yiqiu_sprite: AnimatedSprite2D = $yiqiu
@onready var yanlie_sprite: AnimatedSprite2D = $yanlie

var char_qian: Node2D # dialog_character 乾
var char_xun: Node2D # dialog_character 巽
var char_moning: Node2D # dialog_character 墨宁
var char_yiqiu: Node2D # dialog_character 言秋
var char_yanlie: Node2D # dialog_character 言烈
var normal: Control # normal_dialog

var _skip_requested: bool = false

# 立绘路径
var ill_qian := "res://AssetBundle/Sprites/npc/qian_full.png"
var ill_xun := "res://AssetBundle/Sprites/npc/xun_full.png"
var ill_yanlie := "res://AssetBundle/Sprites/npc/yanlie_full.png"
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
	# 记录所有角色的原始位置 / 缩放
	var qian_pos := qian_sprite.position
	var xun_pos := xun_sprite.position
	var qian_sc := qian_sprite.scale
	var xun_sc := xun_sprite.scale
	var moning_pos := moning_sprite.position
	var yiqiu_pos := yiqiu_sprite.position
	var yanlie_pos := yanlie_sprite.position
	var moning_sc := moning_sprite.scale
	var yiqiu_sc := yiqiu_sprite.scale
	var yanlie_sc := yanlie_sprite.scale

	# 隐藏原始精灵（即将重新挂载到 dialog_character 下）
	qian_sprite.visible = false
	xun_sprite.visible = false
	moning_sprite.visible = false
	yiqiu_sprite.visible = false
	yanlie_sprite.visible = false

	# 创建 dialog_character 实例
	char_qian = DIALOG_CHAR_SCENE.instantiate()
	char_xun = DIALOG_CHAR_SCENE.instantiate()
	char_moning = DIALOG_CHAR_SCENE.instantiate()
	char_yiqiu = DIALOG_CHAR_SCENE.instantiate()
	char_yanlie = DIALOG_CHAR_SCENE.instantiate()
	normal = NORMAL_DIALOG_SCENE.instantiate()

	char_qian.name = "DialogQian"
	char_xun.name = "DialogXun"
	char_moning.name = "DialogMoning"
	char_yiqiu.name = "DialogYiqiu"
	char_yanlie.name = "DialogYanlie"
	normal.name = "NormalDialog"

	char_qian.scale = qian_sc
	char_xun.scale = xun_sc
	char_moning.scale = moning_sc
	char_yiqiu.scale = yiqiu_sc
	char_yanlie.scale = yanlie_sc
	char_qian.position = qian_pos
	char_xun.position = xun_pos
	char_moning.position = moning_pos
	char_yiqiu.position = yiqiu_pos
	char_yanlie.position = yanlie_pos

	add_child(char_qian)
	add_child(char_xun)
	add_child(char_moning)
	add_child(char_yiqiu)
	add_child(char_yanlie)

	# 将原始精灵重新挂载到 dialog_character 下
	qian_sprite.reparent(char_qian)
	qian_sprite.position = Vector2.ZERO
	qian_sprite.scale = Vector2(1, 1)

	xun_sprite.reparent(char_xun)
	xun_sprite.position = Vector2.ZERO
	xun_sprite.scale = Vector2(1, 1)

	moning_sprite.reparent(char_moning)
	moning_sprite.position = Vector2.ZERO
	moning_sprite.scale = Vector2(1, 1)

	yiqiu_sprite.reparent(char_yiqiu)
	yiqiu_sprite.position = Vector2.ZERO
	yiqiu_sprite.scale = Vector2(1, 1)

	yanlie_sprite.reparent(char_yanlie)
	yanlie_sprite.position = Vector2.ZERO
	yanlie_sprite.scale = Vector2(1, 1)

	# 初始化 dialog_character
	char_qian.init(qian_sprite, "乾")
	char_xun.init(xun_sprite, "巽")
	char_moning.init(moning_sprite, "墨宁")
	char_yiqiu.init(yiqiu_sprite, "言秋")
	char_yanlie.init(yanlie_sprite, "言烈")

	# 确保精灵播放 idle 动画
	qian_sprite.play("idle")
	xun_sprite.play("idle")
	moning_sprite.play("idle")
	yiqiu_sprite.play("idle")
	yanlie_sprite.play("idle")

	# 为每个角色创建脚底阴影
	CharacterEffects.create_shadow(char_qian, 14.0, 5.0, 105.0)
	CharacterEffects.create_shadow(char_xun, 14.0, 5.0, 105.0)
	CharacterEffects.create_shadow(char_moning, 14.0, 5.0, 105.0)
	CharacterEffects.create_shadow(char_yiqiu, 14.0, 5.0, 105.0)
	CharacterEffects.create_shadow(char_yanlie, 14.0, 5.0, 105.0)

	# NormalDialog 放入 CanvasLayer，避免 Camera2D zoom 影响
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
	char_xun.type_speed = 0.04
	char_moning.type_speed = 0.04
	char_yiqiu.type_speed = 0.04
	char_yanlie.type_speed = 0.04


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

	# 显示字幕：墨宁、言秋通过巽长老的传送符，成功返回了桃源镇……
	await director.show_subtitle(
		"墨宁、言秋通过巽长老的传送符，成功返回了桃源镇……",
		3.0
	)
	if _skip_requested:
		await _skip_to_town()
		return
	
	# 巽、乾、言烈同时播放emote：surprise，持续1.5秒
	char_xun.show_emote("surprise", 1.5)
	char_qian.show_emote("surprise", 1.5)
	char_yanlie.show_emote("surprise", 1.5)
	await get_tree().create_timer(1.5).timeout
	
	# ── 第一段对话（巽→言秋→言烈，无emote打断，合并为一个run）──
	await director.run([
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "巽", "speaker_position": "left",
					"dialog": "墨宁，言秋，你们回来了？还好吗？",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
				},
				{
					"speaker": "墨宁", "speaker_position": "right",
					"dialog": "幻境里的真气不知为何非常狂暴，桃林里不少树叶和桃花都化作了精怪攻击我们。",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_moning, "illustrationRightStatus": true,
				},
				{
					"speaker": "巽", "speaker_position": "left",
					"dialog": "嗯，这我们也注意到了，不过桃林里还没什么特别强大的精怪，很适合你们稍作锻炼。",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_moning, "illustrationRightStatus": true,
				},
				{
					"speaker": "言秋", "speaker_position": "right",
					"dialog": "真、真的吗？刚才好险啊！我们探索的越深入，精怪们就越强大！",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_yiqiu, "illustrationRightStatus": true,
				},
				{
					"speaker": "言烈", "speaker_position": "left",
					"dialog": "看你这活蹦乱跳的样子，也不像是受伤了。",
					"illustrationLeft": ill_yanlie, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_yiqiu, "illustrationRightStatus": false,
				},
			]
		},
	])
	if _skip_requested:
		await _skip_to_town()
		return
	
	# ── 分歧点：根据是否击败了桃林boss ──
	if Global.has_defeated_peach_grove_boss:
		# 如果在桃林击败了boss后回到的城镇
		# 言秋播放happy的emote1.5秒
		await director.run([
			{"type": "emote", "char": char_yiqiu, "anim": "happy", "duration": 1.5},
			{
				"type": "speak_normal",
				"normal_dialog": normal,
				"lines": [
					{
						"speaker": "言秋", "speaker_position": "right",
						"dialog": "嘿嘿，那是，我们可是击败了桃林的桃树精王呢！",
						"illustrationLeft": ill_yanlie, "illustrationLeftStatus": false,
						"illustrationMiddle": "",
						"illustrationRight": ill_yiqiu, "illustrationRightStatus": true,
					},
					{
						"speaker": "乾", "speaker_position": "left",
						"dialog": "嗯……初次进入幻境就取得这般佳绩，做的不错！",
						"illustrationLeft": ill_qian, "illustrationLeftStatus": true,
						"illustrationMiddle": "",
						"illustrationRight": ill_yiqiu, "illustrationRightStatus": false,
					},
				]
			},
		])
	else:
		# 如果是战败后回到的城镇
		# 言秋播放speechless1.5秒
		await director.run([
			{"type": "emote", "char": char_yiqiu, "anim": "speechless", "duration": 1.5},
			{
				"type": "speak_normal",
				"normal_dialog": normal,
				"lines": [
					{
						"speaker": "言秋", "speaker_position": "right",
						"dialog": "这不是有巽长老的传送符嘛！",
						"illustrationLeft": ill_yanlie, "illustrationLeftStatus": false,
						"illustrationMiddle": "",
						"illustrationRight": ill_yiqiu, "illustrationRightStatus": true,
					},
					{
						"speaker": "乾", "speaker_position": "left",
						"dialog": "量力而行，修为不够就不要硬闯到幻境深处去了。",
						"illustrationLeft": ill_qian, "illustrationLeftStatus": true,
						"illustrationMiddle": "",
						"illustrationRight": ill_yiqiu, "illustrationRightStatus": false,
					},
				]
			},
		])
	if _skip_requested:
		await _skip_to_town()
		return
	
	# ── 第二段对话（巽→墨宁→言秋→乾，无emote打断）──
	await director.run([
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "巽", "speaker_position": "left",
					"dialog": "对了，我把道标设置之法也教给你们，如果能探到幻境的更深处，可以把这些道标铺设上去，以便通过衍阵直接前往。",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_yiqiu, "illustrationRightStatus": false,
				},
				{
					"speaker": "巽", "speaker_position": "left",
					"dialog": "而且，我看你们真气充盈，看来在那里面收获颇丰？",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_yiqiu, "illustrationRightStatus": false,
				},
				{
					"speaker": "墨宁", "speaker_position": "right",
					"dialog": "的确是这样……在杀掉那些精怪后，我们身上的力量便明显变强了不少。",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_moning, "illustrationRightStatus": true,
				},
				{
					"speaker": "墨宁", "speaker_position": "right",
					"dialog": "不过只要我们离开了幻境，那些附着在我们身上的真气就消散了大半。",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_moning, "illustrationRightStatus": true,
				},
				{
					"speaker": "言秋", "speaker_position": "right",
					"dialog": "呜，果然没这么容易提升实力……",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_yiqiu, "illustrationRightStatus": true,
				},
				{
					"speaker": "乾", "speaker_position": "left",
					"dialog": "嗯……那里面的真气比外面活跃了太多，这情况也正常。",
					"illustrationLeft": ill_qian, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_yiqiu, "illustrationRightStatus": false,
				},
				{
					"speaker": "巽", "speaker_position": "left",
					"dialog": "不过也别灰心，你们还是收集到了不少可以修炼用的真气，之后来找我吧，我来指导你们修习。",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_yiqiu, "illustrationRightStatus": false,
				},
				{
					"speaker": "乾", "speaker_position": "right",
					"dialog": "不错，借着这个奇特的幻境，多提升提升自身实力吧。",
					"illustrationLeft": ill_qian, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_yiqiu, "illustrationRightStatus": false,
				},
				{
					"speaker": "言烈", "speaker_position": "left",
					"dialog": "行，如果没什么事我就先回自在天了，小秋，如果有事再给我飞信。",
					"illustrationLeft": ill_yanlie, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_yiqiu, "illustrationRightStatus": false,
				},
				{
					"speaker": "言秋", "speaker_position": "left",
					"dialog": "好好好，父亲再见！",
					"illustrationLeft": ill_yanlie, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_yiqiu, "illustrationRightStatus": true,
				},
			]
		},
		# 言烈播放slient1.5秒
		{"type": "emote", "char": char_yanlie, "anim": "slient", "duration": 1.5},
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "乾", "speaker_position": "right",
					"dialog": "我和巽会留在这里，不久之后，坤长老也会过来协助我们调查。",
					"illustrationLeft": ill_qian, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_moning, "illustrationRightStatus": false,
				}, {
					"speaker": "墨宁", "speaker_position": "left",
					"dialog": "那接下来……我和言秋先熟悉一下这桃源镇吧？",
					"illustrationLeft": ill_qian, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_moning, "illustrationRightStatus": true,
				},
			]
		},
	])
	
	# 结束，传送到main_town.tscn
	await _fade_to_town()


# 跳过按钮逻辑
func _set_skip_children_mouse(mode: int) -> void:
	for child in skip_layer.get_children():
		if child is Control:
			child.mouse_filter = mode


func _show_skip_button_layer() -> void:
	if not skip_button_layer:
		return
	for child in skip_button_layer.get_children():
		if child is CanvasItem:
			child.visible = true
			child.modulate.a = 0.0
			if child is Control:
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_button_layer.visible = true
	
	var tw := get_tree().create_tween()
	for child in skip_button_layer.get_children():
		if child is CanvasItem:
			tw.parallel().tween_property(child, "modulate:a", 1.0, 0.4)
	await tw.finished
	
	for child in skip_button_layer.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_STOP


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
	for char_node in [char_qian, char_xun, char_moning, char_yiqiu, char_yanlie]:
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
	for char_node in [char_qian, char_xun, char_moning, char_yiqiu, char_yanlie]:
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
