extends Node2D

## Story 1 — 乾与巽的幻境对话
##
## 场景：幻境入口前，乾和巽讨论进入幻境的方案。
## 巽尝试两次进入幻境，均被奇力弹出。

const DIALOG_CHAR_SCENE = preload("res://Scenes/global/dialog_character.tscn")
const NORMAL_DIALOG_SCENE = preload("res://Scenes/global/normal_dialog.tscn")

@onready var director: DialogDirector = $DialogDirector
@onready var skip_button: Button = $skip_button_layer/skip
@onready var skip_layer: CanvasLayer = $skipLayer
@onready var skip_button_layer: CanvasLayer = $skip_button_layer
@export var skip_ok_button: Button

@export var skip_cansel_button: Button

@onready var _black_overlay: ColorRect = $ColorRect

# 角色选择界面
@onready var _select_layer: CanvasLayer = $CanvasLayer

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
var _xun_origin_pos: Vector2 # 巽的原始位置

# ── 角色选择 ──
var _selection_made: bool = false
var _selected_character: String = ""
var _hover_tweens: Dictionary = {}
## 角色选择界面中的节点名 → PC.player_name 映射（言秋在游戏内 key 为 yiqiu）
const _SELECT_TO_HERO: Dictionary = {"moning": "moning", "yanqiu": "yiqiu"}

var _skip_requested: bool = false


func _ready() -> void:
	_setup_scene()
	_select_layer.visible = false
	_select_layer.layer = 210 # 确保角色选择层在所有 UI 之上
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
	_xun_origin_pos = xun_pos
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

	# ── 创建 dialog_character 实例 ──
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

	# ── 将原始精灵重新挂载到 dialog_character 下 ──
	qian_sprite.reparent(char_qian)
	qian_sprite.position = Vector2.ZERO
	qian_sprite.scale = Vector2(1, 1)
	qian_sprite.flip_h = false # dialog_director 用 scale.x 控制朝向
	qian_sprite.scale.x = -1 # 乾初始面向左

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

	# ── 初始化 dialog_character ──
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

	# ── 为每个角色创建脚底阴影 ──
	CharacterEffects.create_shadow(char_qian, 14.0, 5.0, 105.0)
	CharacterEffects.create_shadow(char_xun, 14.0, 5.0, 105.0)
	CharacterEffects.create_shadow(char_moning, 14.0, 5.0, 105.0)
	CharacterEffects.create_shadow(char_yiqiu, 14.0, 5.0, 105.0)
	CharacterEffects.create_shadow(char_yanlie, 14.0, 5.0, 105.0)

	# 墨宁、言秋、言烈在 Part 1-5 期间不可见，后续通过字幕过渡显示
	char_moning.visible = false
	char_yiqiu.visible = false
	char_yanlie.visible = false

	# NormalDialog 放入 CanvasLayer，避免 Camera2D zoom 影响
	var dialog_layer := CanvasLayer.new()
	dialog_layer.name = "DialogLayer"
	dialog_layer.layer = 128
	dialog_layer.add_child(normal)
	add_child(dialog_layer)
	normal.visible = false

	# skip_button 另起 CanvasLayer 避免被 DialogLayer / 其他 UI 遮挡
	var skip_canvas := CanvasLayer.new()
	skip_canvas.name = "SkipCanvas"
	skip_canvas.layer = 190
	var skip_pos = skip_button.position
	skip_canvas.add_child(skip_button)
	skip_button.position = skip_pos
	add_child(skip_canvas)

	# 打字速度
	char_qian.type_speed = 0.04
	char_xun.type_speed = 0.04
	char_moning.type_speed = 0.04
	char_yiqiu.type_speed = 0.04
	char_yanlie.type_speed = 0.04


func start_story() -> void:
	# 立绘路径
	var ill_qian := "res://AssetBundle/Sprites/npc/qian_full.png"
	var ill_xun := "res://AssetBundle/Sprites/npc/xun_full.png"

	# 第一行字幕开始播放 0.5 秒后，渐出开场黑屏
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

	await director.show_subtitle(
		"天衍宗内阵法和轻功造诣最高的巽长老听闻此事，带上了他的亲传弟子，赶到了幻境外围与乾长老汇合……",
		3
	)
	if _skip_requested:
		await _skip_to_selection()
		return

	await director.run([
		# 乾先向右走 30 像素，再向左走回
		#{"type": "callback", "func": func(): qian_sprite.play("walk")},
		#{"type": "move", "char": char_qian, "x": char_qian.position.x + 60, "duration": 1, "facing": "right"},
		#{"type": "wait", "duration": 0.6},
		#{"type": "callback", "func": func(): qian_sprite.play("walk")},
		#{"type": "move", "char": char_qian, "x": char_qian.position.x, "duration": 1, "facing": "left"},
		#{"type": "callback", "func": func(): qian_sprite.play("idle")},

		{"type": "emote", "char": char_qian, "anim": "slient", "duration": 1.3},
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "乾", "speaker_position": "right",
					# , "speaker2": "乾",
					"dialog": "小巽，这次得你来看看了。这幻境虚实难辨，我与我门下弟子皆已尝试过进入其中，但每次都在数息之间就被一股奇力推了出来。",
					# "illustrationLeft": ill_xun, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": true,
				},
			]
		},
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "巽", "speaker_position": "left",
					"dialog": "哦？连乾大长老都吃了亏？我来之前碰到过在医馆疗伤的镇民，那镇民据说是被这奇力推出了数十米，伤得不轻啊。",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": false,
				},
			]
		},
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "乾", "speaker_position": "right",
					"dialog": "是啊，那股拒斥之力连我都抵抗不住，凡人进去只会更危险。",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": true,
				},
				{
					"speaker": "乾", "speaker_position": "right",
					"dialog": "我进去的数息之中，隐约感受到了幻境深处的剧烈能量波动，但幻境外围却看不出什么异样。",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": true,
				},
				{
					"speaker": "乾", "speaker_position": "right",
					"dialog": "而且这幻境与明珑道修一脉的阵道体系截然不同。可这些年我从未听闻过大陆上又出了什么阵法奇才。",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": true,
				},
			]
		},
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "巽", "speaker_position": "left",
					"dialog": "方才我在外围以灵识探过，这力量不仅不似道修阵法，也不是妖修、魔修、佛修的阵法路数。",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": false,
				},
			]
		},
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "乾", "speaker_position": "right",
					"dialog": "这就有些蹊跷了……还有一事，据桃源镇镇长说，不少镇民此前亲眼瞧见天边裂开一道墨色裂隙，随即一座形状怪异的建筑坠落了在龙门山上。",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": true,
				},
				{
					"speaker": "乾", "speaker_position": "right",
					"dialog": "可如今幻境中的龙门山，既无裂隙，也寻不见那建筑的半分痕迹——就像从未发生过一样。",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": true,
				},
			]
		},
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "巽", "speaker_position": "left",
					"dialog": "也就是说，幻境是在那裂隙出现之后才展开的……很可能是人为的？那裂隙又是什么？",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": false,
				},
				{
					"speaker": "巽", "speaker_position": "left",
					"dialog": "……罢了，在这猜来猜去也不是办法。我先进去看看，顺带在外围布一圈道标。",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": false,
				},
			]
		},
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "乾", "speaker_position": "right",
					"dialog": "嗯，万事小心。",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": true,
				},
			]
		},

		# ══════════════════════════════════════════════════
		#  Part 2 : 巽第一次尝试进入幻境
		# ══════════════════════════════════════════════════

		# 巽向左转，向左上移动 30 像素并渐隐消失
		{"type": "callback", "func": func(): _xun_enter_barrier()},
		# 1 秒等待，期间面向切换为向右（在 _xun_bounced_back 中处理）
		{"type": "wait", "duration": 2.0},
		{"type": "emote", "char": char_qian, "anim": "slient", "duration": 1.3},
		{"type": "wait", "duration": 1.0},

		# 巽被弹出：defeat 动画 + 快速右下位移
		{"type": "callback", "func": func(): _xun_bounced_back()},
		# 等待 defeat 动画播完（16帧 / 12fps ≈ 1.4s）
		{"type": "wait", "duration": 1.4},
		# defeat 播完 0.3 秒后，切换为 idle
		{"type": "wait", "duration": 0.5},
		{"type": "callback", "func": func(): _xun_recover_idle()},

		# ══════════════════════════════════════════════════
		#  Part 3 : 短暂交流
		# ══════════════════════════════════════════════════
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "乾", "speaker_position": "right",
					"dialog": "你也被那奇力推出来了？",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": true,
				},
			]
		},

		# 巽显示 emote happy
		{"type": "emote", "char": char_xun, "anim": "happy", "duration": 1.3},

		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "巽", "speaker_position": "left",
					"dialog": "有趣，有趣……等我再试试。",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": false,
				},
			]
		},

		# ══════════════════════════════════════════════════
		#  Part 4 : 巽第二次尝试进入幻境
		# ══════════════════════════════════════════════════

		# 巽再次向左上移动并渐隐
		{"type": "callback", "func": func(): _xun_enter_barrier()},
		{"type": "wait", "duration": 1.6},

		# 震动了一下
		{"type": "shake", "duration": 0.5, "intensity": 7.0},
		{"type": "wait", "duration": 1.0},

		# 巽又被弹出
		{"type": "callback", "func": func(): _xun_bounced_back()},
		{"type": "wait", "duration": 1.4},
		{"type": "wait", "duration": 0.5},
		{"type": "callback", "func": func(): _xun_recover_idle()},

		# 巽显示 emote slient
		{"type": "emote", "char": char_xun, "anim": "speechless", "duration": 1},
		{"type": "emote", "char": char_qian, "anim": "speechless", "duration": 1},

		# ══════════════════════════════════════════════════
		#  Part 5 : 后续对话
		# ══════════════════════════════════════════════════
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "巽", "speaker_position": "left",
					"dialog": "有些难办了。方才我已将轻功提至极限，本以为能勉强抗衡，谁知那股推力简直不讲道理，硬生生将我震退出来。这等霸道的拒斥之力，我还是头一回见。",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": false,
				},
			]
		},
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "乾", "speaker_position": "right",
					"dialog": "当今天衍宗内，论轻功与阵法造诣，无人能出你之右。连你都无法深入，这事就棘手了。",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": true,
				},
			]
		},
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "巽", "speaker_position": "left",
					"dialog": "倒也不是全无所获……",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": false,
				},
				{
					"speaker": "巽", "speaker_position": "left",
					"dialog": "我第二次入阵时试着攻击了幻境边缘，若是为了入侵的阵法，必定会有攻击机制在，但这幻境只是加大了推拒之力，并没有什么实质性的攻击。",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": false,
				},
				{
					"speaker": "巽", "speaker_position": "left",
					"dialog": "。",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": true,
					"illustrationMiddle": "幻境外围我已经铺设了一圈传送道标，外围倒是看起来没什么危险，只是越往深处走，真气浓度就越高。",
					"illustrationRight": ill_qian, "illustrationRightStatus": false,
				},
				{
					"speaker": "巽", "speaker_position": "left",
					"dialog": "我隐约的感觉到，这幻境应该并不是推拒所有人，更像是在挑选着某种东西。",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": false,
				},
			]
		},

		# 乾显示 emote slient
		{"type": "emote", "char": char_qian, "anim": "slient", "duration": 1.3},

		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "乾", "speaker_position": "right",
					"dialog": "既是如此，我看幻境外围也没什么危险，不妨让你门下弟子也来试试？",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": true,
				},
			]
		},
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "巽", "speaker_position": "left",
					"dialog": "也好，一直僵在这里也不是个办法。",
					"illustrationLeft": ill_xun, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": false,
				},
			]
		},
	])
	if _skip_requested:
		await _skip_to_selection()
		return

	# ══════════════════════════════════════════════════
	#  过渡字幕 1 → 墨宁与言秋登场
	# ══════════════════════════════════════════════════
	await director.show_subtitle(
		"巽长老很快就召集了跟他一起前来的亲传弟子们……",
		1.3,
		_on_subtitle11_transition,
		true # keep_black → 保留黑屏
	)
	if _skip_requested:
		await _skip_to_selection()
		return

	await director.show_subtitle(
		"经过一番尝试，只有巽长老门下的墨宁，和刚好来天衍宗玩的魔教小少主言秋二人可以深入幻境内部……",
		3.2,
		_on_subtitle1_transition
	)
	if _skip_requested:
		await _skip_to_selection()
		return

	# ══════════════════════════════════════════════════
	#  Part 6 : 墨宁与言秋登场后的对话
	# ══════════════════════════════════════════════════
	var ill_moning := "res://AssetBundle/Sprites/npc/moning_full.png"
	var ill_yiqiu := "res://AssetBundle/Sprites/npc/yanqiu_full.png"

	await director.run([
		# 乾 → 墨宁
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "乾", "speaker_position": "right",
					"dialog": "嗯……还真的有弟子能自由进出这幻境啊。我记得你是墨宁吧？上次大比里是少年组的第二名？",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": true,
				},
			]
		},
		{"type": "emote", "char": char_moning, "anim": "surprise", "duration": 1.5},
		{"type": "move", "char": char_moning, "x": char_moning.position.x + 140, "duration": 0.4, "facing": "right"},
		{"type": "callback", "func": func(): moning_sprite.play("idle")},
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "墨宁", "speaker_position": "left",
					"dialog": "大、大长老好！是的，晚辈在上次宗门大比中是第二名，输给了沈承师兄……",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": false,
				},
			]
		},
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "乾", "speaker_position": "right",
					"dialog": "离长老下的沈承啊……输给他倒是不冤，他是名门沈家的继承者，享受的修炼资源连我都有些羡慕。",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": true,
				},
			]
		},
		# 乾 → 言秋
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "乾", "speaker_position": "right",
					"dialog": "不错不错。然后这位小友是……自在天的小少主，言秋？",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": true,
				},
			]
		},
		# 言秋 emote happy
		{"type": "move", "char": char_yiqiu, "x": char_yiqiu.position.x + 130, "duration": 0.4, "facing": "right"},
		{"type": "callback", "func": func(): yiqiu_sprite.play("idle")},
		{"type": "emote", "char": char_yiqiu, "anim": "happy", "duration": 1.3},
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "言秋", "speaker_position": "left",
					"dialog": "对！我是来找墨宁玩的，刚才跟着他去试了一下，看来这幻境对我也没什么恶意嘛！我能和他一起去调查么？",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": false,
				},
			]
		},
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "乾", "speaker_position": "right",
					"dialog": "嗯……虽说幻境外围由老夫和巽长老检测过，并没有太大的危险，但是以防意外，小少主还是不要涉险了。",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": true,
				},
			]
		},
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "墨宁", "speaker_position": "left",
					"dialog": "是啊，言秋你要是出了什么事……",
					"illustrationLeft": ill_moning, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_yiqiu, "illustrationRightStatus": false,
				},
			]
		},
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "言秋", "speaker_position": "left",
					"dialog": "小问题！我给我家老爷子去个飞信喊他过来看看！",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_moning, "illustrationRightStatus": false,
				},
			]
		},
		# 言秋转向左侧
		{"type": "face", "char": char_yiqiu, "facing": "left"},
		{"type": "wait", "duration": 0.8},
		{"type": "face", "char": char_moning, "facing": "left"},
		{"type": "face", "char": char_xun, "facing": "left"},
		{"type": "face", "char": char_qian, "facing": "left"},
		# 墨宁、乾均显示 emote speechless
		{"type": "callback", "func": func(): char_moning.show_emote("speechless", 1.5)},
		{"type": "callback", "func": func(): char_xun.show_emote("speechless", 1.5)},
		{"type": "callback", "func": func(): char_qian.show_emote("speechless", 1.5)},
		{"type": "wait", "duration": 2.0},
	])
	if _skip_requested:
		await _skip_to_selection()
		return

	# ══════════════════════════════════════════════════
	#  过渡字幕 2 → 言烈登场
	# ══════════════════════════════════════════════════
	var ill_yanlie := "res://AssetBundle/Sprites/npc/yanlie_full.png"

	await director.show_subtitle(
		"片刻之后，自在天的教主言烈便通过衍阵传送到了幻境前",
		3.0,
		_on_subtitle2_transition
	)
	if _skip_requested:
		await _skip_to_selection()
		return

	# ══════════════════════════════════════════════════
	#  Part 7 : 言烈登场后的对话 + 退场
	# ══════════════════════════════════════════════════
	await director.run([
		# 言烈 emote doubt
		{"type": "emote", "char": char_yanlie, "anim": "doubt", "duration": 1.5},
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "言烈", "speaker_position": "left",
					"dialog": "嗯？乾和巽都在这啊。小秋说的就是这个幻境？",
					"illustrationLeft": ill_yanlie, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": false,
				},
			]
		},
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "乾", "speaker_position": "right",
					"dialog": "言教主，有失远迎，这个幻境现在只有墨宁和言秋能够进入，其他人只要进入就会被强烈的拒斥之力弹出。",
					"illustrationLeft": ill_yanlie, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": true,
				},
			]
		},
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "言烈", "speaker_position": "left",
					"dialog": "这幻境也不像是魔教的路数……言秋说你们已经在浅层看过，没什么危险？",
					"illustrationLeft": ill_yanlie, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": false,
				},
			]
		},
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "乾", "speaker_position": "right",
					"dialog": "是，不过我们并不想让小少主涉险，因为这幻境还充满着未知……",
					"illustrationLeft": ill_yanlie, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_qian, "illustrationRightStatus": true,
				},
			]
		},
		
		{"type": "face", "char": char_yanlie, "facing": "left"},
		{"type": "wait", "duration": 0.8},
		{"type": "callback", "func": func(): char_yanlie.show_emote("slient", 1)},
		{"type": "wait", "duration": 0.8},
		{"type": "face", "char": char_yanlie, "facing": "right"},
		{"type": "wait", "duration": 0.8},
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "言烈", "speaker_position": "left",
					"dialog": "我看让他进去玩玩也没什么不好，正好两个人也有个照应。至于安全性……这不是还有小巽在这么。",
					"illustrationLeft": ill_yanlie, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_xun, "illustrationRightStatus": false,
				},
			]
		},
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "巽", "speaker_position": "right",
					"dialog": "那是，传送道标我已经铺设好了，这是我炼制的一批传送符，遇到危险的时候会自动触发，可以瞬间传送回镇子里。",
					"illustrationLeft": ill_yanlie, "illustrationLeftStatus": false,
					"illustrationMiddle": "",
					"illustrationRight": ill_xun, "illustrationRightStatus": true,
				},
			]
		},
		
		# 言秋跳到巽长老身边，面向左，再跳回来，面向右
		{"type": "jump", "char": char_yiqiu, "to": char_xun.position + Vector2(32, 15), "duration": 0.3},
		{"type": "face", "char": char_yiqiu, "facing": "left"},
		{"type": "wait", "duration": 0.3},
		{"type": "jump", "char": char_yiqiu, "to": char_yiqiu.position, "duration": 0.3},
		{"type": "face", "char": char_yiqiu, "facing": "right"},

		{"type": "callback", "func": func(): char_yiqiu.show_emote("happy", 1.5)},
		{"type": "wait", "duration": 1.5},
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "言秋", "speaker_position": "left",
					"dialog": "多谢巽长老！这下问题不都解决啦？那我跟墨宁就进去玩玩了！",
					"illustrationLeft": ill_yiqiu, "illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": ill_moning, "illustrationRightStatus": false,
				}
			]
		},
		{"type": "callback", "func": func(): char_yiqiu.speak("玩去喽~")},
		{"type": "wait", "duration": 1},
		# 言秋向右移动 5 像素，然后和墨宁一起转左、向左上移动并渐隐消失
		{"type": "callback", "func": func(): _yiqiu_move_right()},
		{"type": "wait", "duration": 0.5},
		{"type": "callback", "func": func(): _yiqiu_moning_exit()},
		{"type": "callback", "func": func(): char_moning.speak("诶，小秋……")},
		{"type": "wait", "duration": 1},
		{"type": "callback", "func": func(): char_qian.show_emote("slient", 1.5)},
		{"type": "wait", "duration": 1.5},
		{"type": "callback", "func": func(): char_qian.speak("……罢了。")},
		{"type": "wait", "duration": 1.5},
		{"type": "callback", "func": func(): char_qian.speak("让他们历练历练也好。")},
		{"type": "wait", "duration": 3},
	])
	if _skip_requested:
		await _skip_to_selection()
		return

	# 角色选择 → 切换操控角色 → 黑屏过渡并进入幻境
	await _fade_out_skip_button()
	await _show_character_selection()
	if _selected_character != "":
		PC.player_name = _SELECT_TO_HERO.get(_selected_character, _selected_character)
	await _fade_to_stage1()


# ═══════════════════════════════════════════════════════
#  跳过按钮逻辑
# ═══════════════════════════════════════════════════════

## 将 skip_layer 下所有 Control 子节点的 mouse_filter 设为指定模式
func _set_skip_children_mouse(mode: int) -> void:
	for child in skip_layer.get_children():
		if child is Control:
			child.mouse_filter = mode


## 渐显 skip_layer（仅内部两个按钮可交互）
func _fade_in_skip_layer() -> void:
	skip_layer.visible = true
	# 非按钮子节点保持 IGNORE，不阻挡 skip_button 点击
	skip_ok_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_cansel_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in skip_layer.get_children():
		if child is CanvasItem:
			child.modulate.a = 0.0
			var tw := create_tween()
			tw.tween_property(child, "modulate:a", 1.0, 0.3)
	await get_tree().create_timer(0.3).timeout
	# 渐显完成后才启用按钮交互
	skip_ok_button.mouse_filter = Control.MOUSE_FILTER_STOP
	skip_cansel_button.mouse_filter = Control.MOUSE_FILTER_STOP


## 渐隐 skip_layer
func _fade_out_skip_layer() -> void:
	skip_ok_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_cansel_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in skip_layer.get_children():
		if child is CanvasItem:
			var tw := create_tween()
			tw.tween_property(child, "modulate:a", 0.0, 0.3)
	await get_tree().create_timer(0.3).timeout
	skip_layer.visible = false


## 渐显 skip_button_layer（黑屏渐出后调用）
func _show_skip_button_layer() -> void:
	if not skip_button_layer:
		return
	# 先确保所有子节点 visible 为 true，再统一渐入
	for child in skip_button_layer.get_children():
		if child is CanvasItem:
			child.visible = true
			child.modulate.a = 0.0
			if child is Control:
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_button_layer.visible = true

	# 用 get_tree().create_tween() 避免 lambda 作用域下 create_tween() 失效
	var tw := get_tree().create_tween()
	for child in skip_button_layer.get_children():
		if child is CanvasItem:
			tw.parallel().tween_property(child, "modulate:a", 1.0, 0.4)
	await tw.finished

	# 渐显完成后启用交互
	for child in skip_button_layer.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_STOP


## 渐隐跳过按钮
func _fade_out_skip_button() -> void:
	var tw := create_tween()
	tw.tween_property(skip_button, "modulate:a", 0.0, 0.3)
	await tw.finished
	skip_button.visible = false


## 点击跳过按钮：渐显 skip_layer
func _on_skip_pressed() -> void:
	_fade_in_skip_layer()


## 确认跳过：停止所有对话并立即跳到选人
func _on_skip_ok_pressed() -> void:
	# 1. 先设跳过标志（必须在 emit signal 之前，避免重入时 start_story 读不到）
	_skip_requested = true
	# 2. 让 director 停止当前 run 循环
	director.cancel()
	# 3. 强制 complete 当前对话/气泡，让 director 的 await 立刻突破
	if normal.has_signal("dialog_completed"):
		normal.emit_signal("dialog_completed")
	for char_node in [char_qian, char_xun, char_moning, char_yiqiu, char_yanlie]:
		if char_node and char_node.has_signal("speech_completed"):
			char_node.emit_signal("speech_completed")
	# 4. 隐藏跳过界面
	_fade_out_skip_layer()


## 取消跳过：隐藏 skip_layer
func _on_skip_cancel_pressed() -> void:
	_fade_out_skip_layer()


## 跳过剧情后直接进入角色选择 + 场景切换
func _skip_to_selection() -> void:
	_skip_requested = false
	# 清理所有对话 UI，确保不阻挡角色选择交互
	_cleanup_all_dialog_ui()
	await _fade_out_skip_layer()
	await _fade_out_skip_button()
	await _show_character_selection()
	if _selected_character != "":
		PC.player_name = _SELECT_TO_HERO.get(_selected_character, _selected_character)
	await _fade_to_stage1()


## 清理所有对话相关 UI（角色气泡、emote、normal_dialog、覆盖层）
func _cleanup_all_dialog_ui() -> void:
	# 隐藏全屏对话框
	normal.visible = false
	# 隐藏每个角色的气泡/emote并重置状态
	for char_node in [char_qian, char_xun, char_moning, char_yiqiu, char_yanlie]:
		if not char_node:
			continue
		# 隐藏气泡对话面板
		var panel = char_node.get("dialog_panel")
		if panel:
			panel.visible = false
			panel.modulate.a = 1.0
		# 隐藏 emote
		var emote_node = char_node.get("emote")
		if emote_node:
			emote_node.visible = false
			emote_node.modulate.a = 1.0
		# 让角色恢复完全不透明
		char_node.modulate.a = 1.0
		char_node.visible = false
	# 清除可能残留的 show_subtitle 覆盖层
	for child in director.get_children():
		if child is CanvasLayer:
			child.queue_free()


# ── 自定义动画方法（fire-and-forget，由 callback 步骤触发）─────────

## 黑屏渐入后切换到浅层难度 Stage 1
func _fade_to_stage1() -> void:
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

	# 设置浅层难度并切换场景
	Global.current_stage_id = "peach_grove"
	Global.current_stage_difficulty = Global.STAGE_DIFFICULTY_SHALLOW
	SceneChange.change_scene("res://Scenes/level/peach_grove.tscn", true)


## 巽向左上移动 30 像素并渐隐消失
func _xun_enter_barrier() -> void:
	var sprite := char_xun.get("character") as AnimatedSprite2D
	if sprite:
		sprite.scale.x = - abs(sprite.scale.x) # 面向左

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(char_xun, "position",
		char_xun.position + Vector2(-60, -60), 0.8)
	tween.tween_property(char_xun, "modulate:a", 0.0, 0.8)


## 巽被弹出：面向右 → 出现 → 播放 defeat → 快速右下位移 30px
func _xun_bounced_back() -> void:
	var sprite := char_xun.get("character") as AnimatedSprite2D
	if sprite:
		sprite.scale.x = abs(sprite.scale.x) # 面向右

	# 从原位略偏左上处出现
	char_xun.position = _xun_origin_pos + Vector2(-5, -5)
	char_xun.modulate.a = 1.0

	# 播放 defeat 动画
	if sprite and sprite.sprite_frames \
			and sprite.sprite_frames.has_animation("defeat"):
		sprite.play("defeat")

	# 快速向右下位移（0.3s）
	var tween := create_tween()
	tween.tween_property(char_xun, "position",
		_xun_origin_pos + Vector2(55, 55), 0.2)


## 巽恢复 idle 状态，回到原始位置
func _xun_recover_idle() -> void:
	var sprite := char_xun.get("character") as AnimatedSprite2D
	if sprite:
		sprite.play("idle")
	char_xun.position = _xun_origin_pos


## 言秋向右移动 5 像素
func _yiqiu_move_right() -> void:
	var tween := create_tween()
	tween.tween_property(char_yiqiu, "position",
		char_yiqiu.position + Vector2(18, 0), 0.3)


## 言秋和墨宁转向左侧，共同向左上移动 30 像素并渐隐消失
func _yiqiu_moning_exit() -> void:
	# 转向左
	var yiqiu_sp := char_yiqiu.get("character") as AnimatedSprite2D
	if yiqiu_sp:
		yiqiu_sp.scale.x = - abs(yiqiu_sp.scale.x)
	var moning_sp := char_moning.get("character") as AnimatedSprite2D
	if moning_sp:
		moning_sp.scale.x = - abs(moning_sp.scale.x)

	# 共同向左上移动并渐隐
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(char_yiqiu, "position",
		char_yiqiu.position + Vector2(-135, -135), 1.0)
	tween.tween_property(char_yiqiu, "modulate:a", 0.0, 1.0)
	tween.tween_property(char_moning, "position",
		char_moning.position + Vector2(-135, -135), 1.0)
	tween.tween_property(char_moning, "modulate:a", 0.0, 1.0)


## 字幕过渡 1 回调：墨宁与言秋登场
func _on_subtitle1_transition() -> void:
	char_moning.visible = true
	char_yiqiu.visible = true
	# 相机向左移动 40 像素
	var camera := get_viewport().get_camera_2d()
	if camera:
		camera.position.x -= 135
		camera.position.y += 12
	char_qian.position.x -= 20
	char_xun.position.x += 5
	var xun_sp := char_xun.get("character") as AnimatedSprite2D
	if xun_sp:
		xun_sp.scale.x = - abs(xun_sp.scale.x)
	
func _on_subtitle11_transition() -> void:
	pass

## 字幕过渡 2 回调：言烈登场，全员调整朝向和位置
func _on_subtitle2_transition() -> void:
	char_yanlie.visible = true
	# 除 qian 面向左外，其他人面向全部改为朝右
	var yiqiu_sp := char_yiqiu.get("character") as AnimatedSprite2D
	if yiqiu_sp:
		yiqiu_sp.scale.x = abs(yiqiu_sp.scale.x)
	var moning_sp := char_moning.get("character") as AnimatedSprite2D
	if moning_sp:
		moning_sp.scale.x = abs(moning_sp.scale.x)
	var xun_sp := char_xun.get("character") as AnimatedSprite2D
	if xun_sp:
		xun_sp.scale.x = - abs(xun_sp.scale.x)
	var yanlie_sp := char_yanlie.get("character") as AnimatedSprite2D
	if yanlie_sp:
		yanlie_sp.scale.x = abs(yanlie_sp.scale.x)
	# 乾保持面向左
	var qian_sp := char_qian.get("character") as AnimatedSprite2D
	if qian_sp:
		qian_sp.scale.x = - abs(qian_sp.scale.x)
	# 墨宁和言秋向左瞬移 20 像素（恢复之前向右移动的偏移）
	char_moning.position.x -= 130
	char_yiqiu.position.x -= 115


# ═══════════════════════════════════════════════════════
#  角色选择：hover 亮度提升 + 点击确定
# ═══════════════════════════════════════════════════════

## 显示角色选择界面，等待玩家选择，返回角色名 "moning" 或 "yanqiu"
func _show_character_selection() -> void:
	_selection_made = false
	_selected_character = ""
	_select_layer.visible = true

	# 遍历 CanvasLayer 下所有子节点（包括 Control 容器内部），找到 Sprite2D 并添加可点击区域
	for child in _select_layer.get_children():
		if child is Sprite2D:
			_make_hoverable(child as Sprite2D, child.name)
		elif child is Control:
			# Control 节点需要设为 IGNORE，否则会拦截鼠标事件导致 Area2D 无法响应
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for sub in child.get_children():
				if sub is Sprite2D:
					_make_hoverable(sub as Sprite2D, sub.name)
				elif sub is Control:
					sub.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 等待玩家做出选择
	while not _selection_made:
		await get_tree().process_frame

	_select_layer.visible = false


func _make_hoverable(sprite: Sprite2D, char_name: String) -> void:
	var area := Area2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	var tex := sprite.texture
	shape.size = tex.get_size() * sprite.scale if tex else Vector2(100, 100)
	collision.shape = shape
	area.add_child(collision)
	sprite.add_child(area)
	area.position = Vector2.ZERO

	area.mouse_entered.connect(_on_sprite_hover_start.bind(sprite))
	area.mouse_exited.connect(_on_sprite_hover_end.bind(sprite))
	area.input_event.connect(_on_sprite_clicked.bind(sprite, char_name))


func _on_sprite_hover_start(sprite: Sprite2D) -> void:
	if _hover_tweens.get(sprite) as Tween:
		_hover_tweens[sprite].kill()
	var tw := create_tween()
	tw.tween_property(sprite, "self_modulate", Color(1.2, 1.2, 1.2, 1), 0.2)
	_hover_tweens[sprite] = tw


func _on_sprite_hover_end(sprite: Sprite2D) -> void:
	if _hover_tweens.get(sprite) as Tween:
		_hover_tweens[sprite].kill()
	var tw := create_tween()
	tw.tween_property(sprite, "self_modulate", Color(1, 1, 1, 1), 0.2)
	_hover_tweens[sprite] = tw


func _on_sprite_clicked(_viewport_node: Node, event: InputEvent, _shape_idx: int, _sprite: Sprite2D, char_name: String) -> void:
	if _selection_made:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_selection_made = true
		_selected_character = char_name
