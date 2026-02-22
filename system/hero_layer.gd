extends CanvasLayer

@export var exit_button: Button
@export var now_hero: AnimatedSprite2D
@export var now_hero_name: RichTextLabel
@export var hero_detail: RichTextLabel
@export var hero1: Panel
@export var hero2: Panel
@export var hero3: Panel
@export var hero4: Panel
@export var hero5: Panel
@export var hero6: Panel
@export var hero7: Panel
@export var hero8: Panel
@export var tips: Panel

var hero_panels: Dictionary = {}
var hero_texts: Dictionary = {}
var hero_icons: Dictionary = {}
var hero_display_names: Dictionary = {}
var hero_unlocks: Dictionary = {}

func _ready() -> void:
	hero_panels = {
		"moning": hero1,
		"yiqiu": hero2,
		"noam": hero3,
		"kansel": hero4
	}
	hero_texts = {
		"moning": "初始武器 气功波\n特殊技能 元气弹，迷踪步\n身份背景 天衍宗的少年天才",
		"yiqiu": "初始武器 剑气诀\n特殊技能 魔化，剑气乱击\n身份背景 魔教小少主",
		"noam": "初始武器 光弹\n特殊技能 苦难，天赐\n身份背景 误入异界的白魔法师",
		"kansel": "初始武器 冰刺术\n特殊技能 魔纹阵，以太变移\n身份背景 误入异界的黑魔法师"
	}
	hero_display_names = {
		"moning": "墨宁",
		"yiqiu": "奕秋",
		"noam": "诺姆",
		"kansel": "坎塞尔"
	}
	hero_icons = {
		"moning": "res://AssetBundle/Sprites/town/moning.png",
		"yiqiu": "res://AssetBundle/Sprites/town/yiqiu.png",
		"noam": "res://AssetBundle/Sprites/town/noam.png",
		"kansel": "res://AssetBundle/Sprites/town/kansel.png"
	}
	hero_unlocks = {
		"moning": Global.unlock_moning,
		"yiqiu": Global.unlock_yiqiu,
		"noam": Global.unlock_noam,
		"kansel": Global.unlock_kansel
	}
	_setup_hero_panels()
	_select_hero(PC.player_name)
	exit_button.pressed.connect(_on_exit_pressed)

func _setup_hero_panels() -> void:
	for hero_key in hero_panels.keys():
		var panel: Panel = hero_panels[hero_key]
		_setup_hero_icon(panel, hero_key)
		panel.gui_input.connect(_on_hero_gui_input.bind(hero_key))
	_update_locked_states()
	# hero5.visible = false
	# hero6.visible = false
	# hero7.visible = false
	# hero8.visible = false

func _setup_hero_icon(panel: Panel, hero_key: String) -> void:
	var icon_node = panel.get_node_or_null("Icon")
	if !icon_node:
		icon_node = TextureRect.new()
		icon_node.name = "Icon"
		icon_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_node.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_node.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_node.offset_left = 6
		icon_node.offset_top = 6
		icon_node.offset_right = -6
		icon_node.offset_bottom = -6
		panel.add_child(icon_node)
	var icon_texture: Texture2D = load(hero_icons[hero_key])
	icon_node.texture = icon_texture

func _update_locked_states() -> void:
	for hero_key in hero_panels.keys():
		var panel: Panel = hero_panels[hero_key]
		var icon_node: TextureRect = panel.get_node("Icon")
		var is_unlocked: bool = hero_unlocks[hero_key]
		if is_unlocked:
			icon_node.modulate = Color(1, 1, 1, 1)
		else:
			icon_node.modulate = Color(0.5, 0.5, 0.5, 0.7)

func _on_hero_gui_input(event: InputEvent, hero_key: String) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if hero_unlocks[hero_key]:
				_select_hero(hero_key)
				tips.start_animation("已切换为 " + hero_display_names[hero_key], 0.5)
				Global.save_game()
			else:
				tips.start_animation("角色未开放！", 0.5)
	

func _select_hero(hero_key: String) -> void:
	PC.player_name = hero_key
	_update_now_hero(hero_key)
	var player = get_tree().current_scene.get_node("Player")
	player.change_hero(hero_key)
	var bag_layer = get_tree().current_scene.get_node("BagLayer")
	bag_layer.refresh_character_display()

func _update_now_hero(hero_key: String) -> void:
	now_hero.scale = Vector2(8, 8)
	now_hero.play(hero_key)
	now_hero_name.text = "当前出战\n" + hero_display_names[hero_key]
	hero_detail.text = hero_texts[hero_key]

func _on_exit_pressed() -> void:
	visible = false
