extends Node2D

## 对话序列测试场景
## 演示 dialog_character + dialog_director + normal_dialog 的组合使用

const DIALOG_CHAR_SCENE = preload("res://Scenes/global/dialog_character.tscn")
const NORMAL_DIALOG_SCENE = preload("res://Scenes/global/normal_dialog.tscn")


@onready var director: DialogDirector = $DialogDirector


func _ready() -> void:
	_setup_scene()
	start_test.call_deferred()


func _setup_scene() -> void:
	# 创建两个 dialog_character 实例
	var char_a: Node2D = DIALOG_CHAR_SCENE.instantiate() # 墨宁
	var char_b: Node2D = DIALOG_CHAR_SCENE.instantiate() # 言秋
	var normal: Control = NORMAL_DIALOG_SCENE.instantiate()

	# 命名方便调试
	char_a.name = "Moning"
	char_b.name = "Yiqiu"
	normal.name = "NormalDialog"
	char_a.scale = Vector2(3, 3)
	char_b.scale = Vector2(3, 3)

	add_child(char_a)
	add_child(char_b)

	# ★ normal_dialog 必须放在 CanvasLayer 中，避免被 Camera2D 的 zoom 影响
	var dialog_layer := CanvasLayer.new()
	dialog_layer.name = "DialogLayer"
	dialog_layer.layer = 128
	dialog_layer.add_child(normal)
	add_child(dialog_layer)

	# 初始化角色
	char_a.init(char_a.get_node("moning"), "墨宁")
	char_b.init(char_b.get_node("yiqiu"), "言秋")

	# normal_dialog 初始隐藏，由 speak_normal 步骤控制显隐
	normal.visible = false

	# A（墨宁）从右侧边缘开始
	char_a.position = Vector2(920, 350)

	# B（言秋）从左侧边缘开始
	char_b.position = Vector2(320, 350)

	# 打字速度调慢以便观察
	char_a.type_speed = 0.04
	char_b.type_speed = 0.04

	# 存入自定义属性供后续引用
	set_meta("char_a", char_a)
	set_meta("char_b", char_b)
	set_meta("normal_dialog", normal)


func start_test() -> void:
	var char_a = get_meta("char_a")
	var char_b = get_meta("char_b")
	var normal = get_meta("normal_dialog")

	await director.run([
		# ── ① 墨宁从右侧入场，向左走 150px，面朝左 ──
		{"type": "move", "char": char_a, "x": 770, "duration": 1.5, "facing": "left"},

		# ── ② 停顿 ──
		{"type": "wait", "duration": 0.5},

		# ── ③ 弹出疑惑气泡 ──
		{"type": "emote", "char": char_a, "anim": "doubt", "duration": 1.0},

		# ── 面期右 ──
		{"type": "face", "char": char_a, "facing": "right"},

		# ── 等待0.5s ──
		{"type": "wait", "duration": 0.5},

		# ── 面期左 ──
		{"type": "face", "char": char_a, "facing": "left"},

		# ── ④ 气泡文字 ──
		{"type": "speak_char", "char": char_a, "text": "测试头顶气泡！"},

		# ── ④ 气泡文字 ──
		{"type": "speak_char", "char": char_a, "text": "测试头顶气泡!!！"},

		# ── ⑤ 全屏 normal_dialog（墨宁的内心独白） ──
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "墨宁",
					"speaker_position": "right",
					"dialog": "测试说话第一句，这是一段测试话。测试说话第一句，这是一段测试话。测试说话第一句，这是一段测试话。",
					"illustrationLeft": "",
					"illustrationMiddle": "",
					"illustrationRight": "res://AssetBundle/Sprites/npc/qian_full.png",
					"illustrationRightStatus": true
				}
			]
		},

		# ── ⑥ 言秋从左侧入场，向右走 200px ──
		{"type": "move", "char": char_b, "x": 520, "duration": 1.5},

		# ── ⑦ 停顿 ──
		{"type": "wait", "duration": 0.5},

		# ── ⑧ 弹出惊讶气泡 ──
		{"type": "emote", "char": char_b, "anim": "surprise", "duration": 1.0},

		# ── ⑨ 震屏，强调相遇的震撼 ──
		{"type": "callback", "func": func(): director._do_shake({"duration": 0.3, "intensity": 6.0})},

		# ── ⑩ 全屏 normal_dialog（言秋解释） ──
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "言秋",
					"speaker_position": "left",
					"speaker2": "墨宁",
					"dialog": "测试说话第二句，这是一段测试话。测试说话第二句，这是一段测试话。测试说话第二句",
					"illustrationLeft": "res://AssetBundle/Dialog/zhanwei2.png",
					"illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": "res://AssetBundle/Sprites/npc/qian_full.png",
					"illustrationRightStatus": false
				}
			]
		},
		# ── ⑩ 全屏 normal_dialog（两侧都显示名称） ──
		{
			"type": "speak_normal",
			"normal_dialog": normal,
			"lines": [
				{
					"speaker": "言秋",
					"speaker_position": "both",
					"speaker2": "墨宁",
					"dialog": "测试说话第二句，这是一段测试话。测试说话第二句，这是一段测试话。测试说话第二句",
					"illustrationLeft": "res://AssetBundle/Dialog/zhanwei2.png",
					"illustrationLeftStatus": true,
					"illustrationMiddle": "",
					"illustrationRight": "res://AssetBundle/Dialog/zhanwei.png",
					"illustrationRightStatus": false
				}
			]
		},
	])

	print("🎉 对话序列完成！")
