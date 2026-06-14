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
@onready var noam_sprite: AnimatedSprite2D = $noam
@onready var yiqiu_sprite: AnimatedSprite2D = $yiqiu
@onready var moning_sprite: AnimatedSprite2D = $moning
@onready var kansel_sprite: AnimatedSprite2D = $kansel

var char_noam: Node2D # dialog_character 诺姆
var char_yiqiu: Node2D # dialog_character 言秋
var char_moning: Node2D # dialog_character 墨宁
var char_kansel: Node2D # dialog_character 坎塞尔
var normal: Control # normal_dialog

var _skip_requested: bool = false

var _ste_overlay: CanvasLayer = null
var _ste_texture: TextureRect = null

# 立绘路径
var ill_noam := "res://AssetBundle/Sprites/npc/noam_full.png"
var ill_yiqiu := "res://AssetBundle/Sprites/npc/yanqiu_full.png"
var ill_moning := "res://AssetBundle/Sprites/npc/moning_full.png"
var ill_kansel := "res://AssetBundle/Sprites/npc/kansel.png"


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
	var yiqiu_pos := yiqiu_sprite.position
	var moning_pos := moning_sprite.position
	var kansel_pos := kansel_sprite.position
	var noam_sc := noam_sprite.scale
	var yiqiu_sc := yiqiu_sprite.scale
	var moning_sc := moning_sprite.scale
	var kansel_sc := kansel_sprite.scale

	# 隐藏原始精灵
	noam_sprite.visible = false
	yiqiu_sprite.visible = false
	moning_sprite.visible = false
	kansel_sprite.visible = false

	# 创建 dialog_character 实例
	char_noam = DIALOG_CHAR_SCENE.instantiate()
	char_yiqiu = DIALOG_CHAR_SCENE.instantiate()
	char_moning = DIALOG_CHAR_SCENE.instantiate()
	char_kansel = DIALOG_CHAR_SCENE.instantiate()
	normal = NORMAL_DIALOG_SCENE.instantiate()

	char_noam.name = "DialogNoam"
	char_yiqiu.name = "DialogYiqiu"
	char_moning.name = "DialogMoning"
	char_kansel.name = "DialogKansel"
	normal.name = "NormalDialog"

	char_noam.scale = noam_sc
	char_yiqiu.scale = yiqiu_sc
	char_moning.scale = moning_sc
	char_kansel.scale = kansel_sc
	char_noam.position = noam_pos
	char_yiqiu.position = yiqiu_pos
	char_moning.position = moning_pos
	char_kansel.position = kansel_pos

	add_child(char_noam)
	add_child(char_yiqiu)
	add_child(char_moning)
	add_child(char_kansel)

	# 将原始精灵重新挂载到 dialog_character 下
	noam_sprite.reparent(char_noam)
	noam_sprite.position = Vector2.ZERO
	noam_sprite.scale = Vector2(1, 1)

	yiqiu_sprite.reparent(char_yiqiu)
	yiqiu_sprite.position = Vector2.ZERO
	yiqiu_sprite.scale = Vector2(1, 1)

	moning_sprite.reparent(char_moning)
	moning_sprite.position = Vector2.ZERO
	moning_sprite.scale = Vector2(1, 1)

	kansel_sprite.reparent(char_kansel)
	kansel_sprite.position = Vector2.ZERO
	kansel_sprite.scale = Vector2(1, 1)

	# 初始化 dialog_character
	char_noam.init(noam_sprite, "诺姆")
	char_yiqiu.init(yiqiu_sprite, "言秋")
	char_moning.init(moning_sprite, "墨宁")
	char_kansel.init(kansel_sprite, "坎塞尔")

	# 确保精灵播放 idle 动画
	noam_sprite.play("default")
	yiqiu_sprite.play("idle")
	moning_sprite.play("idle")
	kansel_sprite.play("idle")

	# 为每个角色创建脚底阴影
	CharacterEffects.create_shadow(char_noam, 14.0, 5.0, 105.0)
	CharacterEffects.create_shadow(char_yiqiu, 14.0, 5.0, 105.0)
	CharacterEffects.create_shadow(char_moning, 14.0, 5.0, 105.0)
	CharacterEffects.create_shadow(char_kansel, 14.0, 5.0, 105.0)

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
	char_yiqiu.type_speed = 0.04
	char_moning.type_speed = 0.04
	char_kansel.type_speed = 0.04


func _show_ste_image() -> void:
	_ste_overlay = CanvasLayer.new()
	_ste_overlay.layer = 100
	add_child(_ste_overlay)
	var container := Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ste_overlay.add_child(container)
	_ste_texture = TextureRect.new()
	_ste_texture.texture = load("res://AssetBundle/Sprites/image/ste.png")
	_ste_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ste_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_ste_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ste_texture.modulate.a = 0.0
	container.add_child(_ste_texture)
	var tween := create_tween()
	tween.tween_property(_ste_texture, "modulate:a", 1.0, 1.0)


func _transition_ste_image() -> void:
	if not _ste_texture or not is_instance_valid(_ste_texture):
		return
	var old_tex := _ste_texture
	var new_tex := TextureRect.new()
	new_tex.texture = load("res://AssetBundle/Sprites/image/ste_f.png")
	new_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	new_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	new_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	new_tex.modulate.a = 0.0
	old_tex.get_parent().add_child(new_tex)
	_ste_texture = new_tex
	var tween := create_tween()
	tween.tween_property(new_tex, "modulate:a", 1.0, 1.0)
	tween.tween_callback(old_tex.queue_free)


func _hide_ste_image() -> void:
	if not _ste_texture or not is_instance_valid(_ste_texture):
		return
	var tex := _ste_texture
	var overlay := _ste_overlay
	_ste_texture = null
	_ste_overlay = null
	var tween := create_tween()
	tween.tween_property(tex, "modulate:a", 0.0, 1.0)
	tween.tween_callback(overlay.queue_free)


func start_story() -> void:
	# 第一行字幕开始播放 0.5 秒后，渐出开场黑屏
	if _black_overlay:
		get_tree().create_timer(0.5).timeout.connect(func(): _fade_out_black_overlay())

	# ── 开场字幕 ──
	await director.show_subtitle(
		"一行人击败了出现在深窟深处的紫衣神秘人……",
		3.0
	)
	if _skip_requested:
		await _skip_to_story8()
		return

	# ── 第一段：诺姆沉默 → 言秋询问 → 诺姆解释 ──
	await director.run([
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "诺姆", "speaker_position": "left",
					"dialog": "……",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
				},
				{
					"speaker": "言秋", "speaker_position": "left",
					"dialog": "诺姆，你认识他？我看你在战斗的时候……",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
				},
				{
					"speaker": "诺姆", "speaker_position": "left",
					"dialog": "……我当然认识他，他是罗穆阿尔多的首席黑魔法师，坎塞尔。",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
				},
			]
		},
		# 坎塞尔沉默
		{"type": "emote", "char": char_kansel, "anim": "slient", "duration": 1.5},
	])
	if _skip_requested:
		await _skip_to_story8()
		return

	# ── 第二段：墨宁追问 → 诺姆讲述过去 → 言秋气愤 → 坎塞尔开口 → 诺姆回应 ──
	await director.run([
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "墨宁", "speaker_position": "left",
					"dialog": "所以到底是怎么回事？是敌人吗？",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
				},
				{
					"speaker": "诺姆", "speaker_position": "left",
					"dialog": "我、我也不知道……小时候他家离我家很近，经常带着我玩，也教会了我很多东西。",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
				},
				{
					"speaker": "诺姆", "speaker_position": "left",
					"dialog": "但是后来……他去了皇室任职，在这之后我们就没见过面了，再之后……他很快就成了王国最年轻的首席黑魔法师。",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
				},
				{
					"speaker": "诺姆", "speaker_position": "left",
					"dialog": "我之所以想要成为皇家白魔法师，也是因为他……我也想变得那么厉害。",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
				},
				{
					"speaker": "诺姆", "speaker_position": "left",
					"dialog": "但是他……怎么能看到我就打我呢!",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
				},
				{
					"speaker": "言秋", "speaker_position": "left",
					"dialog": "太可恶了这个叫坎塞尔的家伙，把我们诺姆弄得那么难过！",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "诺姆……我，能解释一下么？",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "诺姆", "speaker_position": "left",
					"dialog": "哼，你说呗，我们三个人还怕你一个吗！",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
			]
		},
		# 坎塞尔沉默后开始讲述
		{"type": "emote", "char": char_kansel, "anim": "slient", "duration": 1.5},
	])
	if _skip_requested:
		await _skip_to_story8()
		return

	# ── 第三段：坎塞尔讲述全部真相（从学院到统一大陆） ──
	await director.run([
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "就从我进入皇家魔法学院开始说吧。因为我对火，冰，雷以太的共鸣力极高，所以高层很快就打算专注培养我。",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "我拿到了学院里可以说是最顶尖的资源。很快，我便突破了大魔法师，顺理成章的成为了皇家黑魔法师。",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "此后，我便一直在协助他们研究\"域外以太汲取\"，来填补能源越来越短缺的情况。这个计划非常成功，给王国补充了大量以太供能。",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "然而在那之后一次偶然的机会，他们皇室能源纠察队在研究所里落下了走查记录，我才知道罗穆阿尔多皇室到底在做什么……",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "你也知道，罗穆阿尔多的魔法高度发达，甚至到了滥用的地步。世界的运转需要大量的以太。",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "而人类天生就能吸纳环境中大量的以太。所以他们为了维持统治，在很久之前便将底层人民通过秘术炼制成凝缩的以太，把他们称作\"燃料\"。",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "他们强迫那些身体尚健康的奴隶去不断生产新的燃料，来维持王国的运转。",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "靠着这些燃料，罗穆阿尔多才能维持皇城的运转，大幅扩张军备，最后几近统一整片大陆。",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "诺姆", "speaker_position": "left",
					"dialog": "怎、怎么会这样？",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "言秋", "speaker_position": "left",
					"dialog": "这不是和那些邪教一样了，还是那种最坏的邪教！",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "你说得对。但我就算知道他们的做法，凭我一个人也很难阻止他们。",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "所以我一直在努力完成他们想要进行的\"域外以太汲取\"，希望靠这项技术来让王国不再残害那些奴隶。",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "但……他们获取了更多的以太后，只想着继续扩张军备，统一大陆。",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "而现在这个情况，也是他们对以太需求已经到丧心病狂的地步所带来的结果。",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "这跟我之前说的\"域外以太汲取\"相关。详细展开的话有些太复杂了，之后我再详细告诉你们。",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "简单地说，我和诺姆所在的世界，也就是罗穆阿尔多所在的世界，和现在这里，不是一个世界。",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "诺姆", "speaker_position": "left",
					"dialog": "你……你在说什么呢……不是一个世界，那我怎么过来的，又要怎么回家？",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "……有我的责任，这次的实验太复杂了。本来已经平稳运行了一段时间，但皇室觉得抽取的以太量不够，擅自加大了转换率。",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "这导致原本稳定的位面裂缝瞬间扩大，将整个研究所吸入，转移到了这里。",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "诺姆", "speaker_position": "left",
					"dialog": "所以山顶掉落下来的那个建筑，就是皇室的秘密研究所？那我为什么也会被转移到这里呢？",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "诺姆", "speaker_position": "left",
					"dialog": "我当时明明是在劳尼荒原那边执行……等等？",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "……是的，研究所就在劳尼荒原的地下，我也没想到会这么巧合的把你也卷进这场事故之中。",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "诺姆", "speaker_position": "left",
					"dialog": "呜……你继续说吧。",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "嗯，来到了这边之后，我才发现情况远比我想象中的要复杂。。",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "位面裂缝无法关闭，而我们世界的能量在之前被肆意使用，以太几近枯竭，导致这个世界的能量比罗穆阿尔多的能量要多得多。",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "这道裂缝持续的吸取着这个世界精纯的能量，而那些驳杂的，散发着狂暴气息的以太被过滤、丢弃掉，迅速扩散到了整片山脉。",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "也就是说……越靠近裂缝那儿，也就是山顶那里，以太就会越狂暴，孕育出的怪物的实力连我都很难想象。",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "墨宁", "speaker_position": "left",
					"dialog": "虽然你说的一些词汇的意思我还没太理解……但是我有一个问题，笼罩了这山脉的结界也是你做的么？",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "墨宁", "speaker_position": "left",
					"dialog": "我们天衍宗已经来了好几位长老，他们的实力都比我强得多，但他们被结界阻拦，无法进入到这里。",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "墨宁", "speaker_position": "left",
					"dialog": "如果可以的话，你把结界解除掉？长老们或许能解决这件事。",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "不，这个笼罩整片山脉的法阵并不是出自我手，这也是我要说的……最严重的问题。",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
			]
		},
	])
	if _skip_requested:
		await _skip_to_story8()
		return

	# 创建并渐入全屏示意图
	_show_ste_image()

	# ── 第七段：坎塞尔讲述灵魂界 → 言秋类比 → 三界交融 → 墨宁追问 → 坎塞尔推测 ──
	await director.run([
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "在这两个世界之间，还存在着一个被我们称作\"灵魂界\"的地方，在我们看来，人死后的灵魂会去往那个世界。",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "言秋", "speaker_position": "left",
					"dialog": "听起来跟我们所说的地府有些像……？",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
			]
		},
		{"type": "callback", "func": _transition_ste_image},
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "简单地说，平常这三个世界在各自的轨道上各自运转前行，这里与罗穆阿尔多的中间便是灵魂界……你们所说的地府。",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "但这次，因为裂缝的原因，三个世界都交融在了一起……这个结界，就像是这个世界为了包扎裂开的伤口一样，自然生成的隔绝带。",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "墨宁", "speaker_position": "left",
					"dialog": "那为什么只有我们能进来？",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "这点我也不太清楚……不过只是从外界进入被驱逐出去还好，但如果在结界展开前，便已经身处内部……",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "我看见的那些人，他们被狂暴的以太不断地侵蚀，变成野兽一般的存在。",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "在山洞外的那片密林里，我遇到很多异化的怪人，他们恐怕曾经都是这个世界的人。",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "那些人可能是猎人？或者是路过的商人？无论是谁，他们都已经完全丧失了人的意志……",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "为了从根源解决这个事件，我需要想办法靠近裂缝，研究关闭它的方法，哪怕代价是我永远不能回到我原来的世界里去。",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "诺姆", "speaker_position": "left",
					"dialog": "怎么会这样……",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "我本来只想靠我一个人解决问题，认为你们太弱小，只会阻碍我……但是现在看来我错了。",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "如果你们愿意相信我说的话，我希望能和你刚才所说的比我强得多的长老们交流学习，尽快解决这个问题。",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
			]
		},
	])
	if _skip_requested:
		await _skip_to_story8()
		return

	# 三人同时沉默反应
	await director.run([
		{"type": "callback", "func": func(): char_noam.show_emote("slient", 1.5)},
		{"type": "callback", "func": func(): char_moning.show_emote("slient", 1.5)},
		{"type": "callback", "func": func(): char_yiqiu.show_emote("slient", 1.5)},
		{"type": "wait", "duration": 3.5},
	])
	if _skip_requested:
		await _skip_to_story8()
		return

	# ── 第九段：众人反应 → 坎塞尔表态 → 墨宁同意 → 收尾 ──
	await director.run([
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "墨宁", "speaker_position": "left",
					"dialog": "你说的这些……",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "言秋", "speaker_position": "left",
					"dialog": "信息量有些太大了！",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "诺姆", "speaker_position": "left",
					"dialog": "连我都没太听懂……",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "呃……总之，在刚才的战斗之后，我认识到了我自己的力量可能并不太够。",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "如果你们不接受我，我会自己前去调查这件事的……这件事我负有很大责任，我不能坐视不理。",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "墨宁", "speaker_position": "left",
					"dialog": "罢了罢了，你跟我们回桃源镇上，和那些长老们沟通一下吧，",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "桃源镇是？",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "诺姆", "speaker_position": "left",
					"dialog": "喏，他们有超级好用的传送符，比我们随机性那么大的传送魔法好用多了！",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "坎塞尔", "speaker_position": "right",
					"dialog": "嗯……或许留在这个世界研究一下也不错……",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
				{
					"speaker": "诺姆", "speaker_position": "left",
					"dialog": "啊，我、我还是有点想回家的……",
					"illustrationLeft": ill_noam, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_kansel, "illustrationRightStatus": true,
				},
			]
		},
	])

	# 结束，进入 story8
	await _fade_to_story8()


# ============== 跳过按钮逻辑 ==============

func _set_skip_children_mouse(mode: int) -> void:
	for child in skip_layer.get_children():
		if child is Control:
			child.mouse_filter = mode


func _fade_out_black_overlay() -> void:
	if _black_overlay:
		var tw = create_tween()
		tw.tween_property(_black_overlay, "color:a", 0.0, 0.5)
		await tw.finished
		if _black_overlay:
			_black_overlay.queue_free()
			_black_overlay = null
	# 黑屏渐出后，显示 skip_button_layer 并渐变出现
	_show_skip_button_layer()

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
	for char_node in [char_noam, char_yiqiu, char_moning, char_kansel]:
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


func _skip_to_story8() -> void:
	_skip_requested = false
	_cleanup_all_dialog_ui()
	await _fade_out_skip_layer()
	await _fade_to_story8()


func _cleanup_all_dialog_ui() -> void:
	if _ste_overlay and is_instance_valid(_ste_overlay):
		_ste_overlay.queue_free()
		_ste_overlay = null
		_ste_texture = null
	normal.visible = false
	for char_node in [char_noam, char_yiqiu, char_moning, char_kansel]:
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


func _fade_to_story8() -> void:
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

	# 切换到 story_8 场景
	SceneChange.change_scene("res://Scenes/story/story_8.tscn", true)
