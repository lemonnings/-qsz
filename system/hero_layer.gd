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
		"moning": "初始武器 气功波\n特殊技能 迷踪步\n身份背景 天衍宗巽长老的得意门生，精通风系法术与轻功。",
		"yiqiu": "初始武器 剑气诀\n特殊技能 兽化\n身份背景 魔教自在天的小少主，擅使枪剑，体内有着魔兽的血脉。",
		"noam": "初始武器 光弹\n特殊技能 神圣灼烧\n身份背景 误入异界的白魔法师，是帝国最年轻的皇家白魔法师。",
		"kansel": "初始武器 冰刺术\n特殊技能 魔纹阵\n身份背景 误入异界的黑魔法师，是帝国黑魔法研究院首席。"
	}
	hero_display_names = {
		"moning": "墨宁",
		"yiqiu": "言秋",
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
				tips.start_animation("角色暂未解锁，可通过后续剧情解锁！", 0.5)
	

func _select_hero(hero_key: String) -> void:
	PC.player_name = hero_key
	_update_now_hero(hero_key)
	var player = get_tree().current_scene.get_node("Player")
	player.change_hero(hero_key)
	_refresh_bag_character_display()

func _refresh_bag_character_display() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var bag_layer := scene.get_node_or_null("BagLayer")
	if bag_layer == null:
		return
	if bag_layer.has_method("refresh_character_display"):
		bag_layer.refresh_character_display()
	elif bag_layer.has_method("refresh_bag"):
		bag_layer.refresh_bag()

func _update_now_hero(hero_key: String) -> void:
	now_hero.scale = Vector2(3.4, 3.4)
	# 从玩家身上获取对应角色的精灵帧
	var player = get_tree().current_scene.get_node_or_null("Player")
	if player:
		var character_sprite = player.get_node(hero_key) as AnimatedSprite2D
		if character_sprite:
			now_hero.sprite_frames = character_sprite.sprite_frames
	now_hero.play("idle")
	now_hero_name.text = "当前出战\n" + hero_display_names[hero_key]
	hero_detail.text = hero_texts[hero_key]

func _on_exit_pressed() -> void:
	Global.unlock_camera_zoom("hero")
	visible = false
