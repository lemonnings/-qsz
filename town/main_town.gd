extends Node2D

@export var dialog_control: Control
@export var defaultLayer: CanvasLayer
@export var levelChangeLayer: CanvasLayer
@export var cultivationLayer: CanvasLayer
@export var canvasLayer: CanvasLayer
@export var synthesisLayer: CanvasLayer
@export var studyLayer: CanvasLayer
@export var heroLayer: CanvasLayer
@export var jcLayer: CanvasLayer

@export var tip: Node

@export var battle_scene: String
@export var battle_scene_stage2: String
@export var battle_scene_stage3: String
@export var battle_scene_stage4: String

@export var cystal: AnimatedSprite2D
@export var levelUpMan: AnimatedSprite2D
@export var levelUpMan2: AnimatedSprite2D
@export var bard: AnimatedSprite2D
@export var merchant: AnimatedSprite2D
@export var danlu: AnimatedSprite2D
@export var portal: AnimatedSprite2D
@export var cystalTips: Control
@export var levelUpManTips: Control
@export var levelUpMan2Tips: Control
@export var bardTips: Control
@export var merchantTips: Control
@export var danluTips: Control
@export var portalTips: Control

@export var dark_overlay: Control # 黑色滤镜

@export var cultivation_msg: RichTextLabel
@export var point_label: Label

@export var interaction_distance: float = 40.0

var transition_tween: Tween
# UI动画相关变量
var ui_tweens: Dictionary = {}
var ui_states: Dictionary = {}

var player: CharacterBody2D
const SHOP_LAYER_SCENE := preload("res://Scenes/town/shop_layer.tscn")
const JC_LAYER_SCENE := preload("res://Scenes/town/jc_layer.tscn")
const ACHIEVEMENT_LAYER_SCENE := preload("res://Scenes/town/achievement‌_layer.tscn")
const ACTION_TIPS_SCENE := preload("res://Scenes/global/action_tips.tscn")
const MOBILE_INTERACTION_BUTTON_THEME := preload("res://Scenes/global/dialog_tips_theme.tres")
const TOWN_COMPANION_DIALOGUE := preload("res://Script/town/town_companion_dialogue.gd")
const STORY6_MAGIC_CORE_REWARD := {
	"item_097": 6,
	"item_098": 6,
	"item_099": 6,
	"item_100": 6,
	"item_101": 6,
}
var jcLayerInstance: CanvasLayer
var achievementLayerInstance: CanvasLayer
const CHICK_SCENE := preload("res://Scenes/town/animal/chick.tscn")
const RABBIT_SCENE := preload("res://Scenes/town/animal/rabbit.tscn")
var shopLayer: CanvasLayer

const CAMERA_ZOOM_LOCK_ACHIEVEMENT := "achievement"
const CAMERA_ZOOM_LOCK_SHOP := "shop"
const CAMERA_ZOOM_LOCK_HERO := "hero"
const CAMERA_ZOOM_LOCK_LEVEL_SELECT := "level_select"
const CAMERA_ZOOM_LOCK_CULTIVATION := "cultivation"
const CAMERA_ZOOM_LOCK_STUDY := "study"

const HERO_KEYS := ["moning", "yiqiu", "noam", "kansel", "xueming"]
const HERO_DISPLAY_NAMES := {
	"moning": "墨宁",
	"yiqiu": "言秋",
	"noam": "诺姆",
	"kansel": "坎塞尔",
	"xueming": "雪铭",
}
const RANDOM_COMPANION_AREA_NAMES := [
	"Random1_left",
	"Random2_right",
	"Random3_right",
	"Random4_left",
	"Random5_left",
	"Random6_right",
]
const COMPANION_INTERACTION_DISTANCE: float = 45.0
const COMPANION_SCALE := Vector2(0.72, 0.72)
const BACKGROUND2_Z_INDEX: int = 1
const TOWN_CHARACTER_FRONT_Z_INDEX: int = BACKGROUND2_Z_INDEX - 1
const PLAYER_TOWN_Z_INDEX: int = 0
const COMPANION_ROOT_Z_INDEX: int = 0
const COMPANION_UPPER_Z_INDEX: int = TOWN_CHARACTER_FRONT_Z_INDEX
const COMPANION_LOWER_Z_INDEX: int = -1
const COMPANION_BEHIND_Z_INDEX: int = -1
const COMPANION_LAYER_SWITCH_BODY_RATIO: float = 0.7
const COMPANION_REFERENCE_BODY_HEIGHT: float = 50.0
const COMPANION_LAYER_SWITCH_Y_EPSILON: float = 4.0
const COMPANION_WORLD_COLLISION_MASK: int = 1
const COMPANION_SHADOW_OFFSET_Y: float = 21.0
const COMPANION_FADE_DURATION: float = 0.18
const COMPANION_STOP_NEAR_PLAYER_DISTANCE: float = 50.0
const COMPANION_MOVE_SPEED: float = 30.0
const COMPANION_IDLE_TIME_MIN: float = 8.0
const COMPANION_IDLE_TIME_MAX: float = 16.0
const COMPANION_RUN_TIME_MIN: float = 1.0
const COMPANION_RUN_TIME_MAX: float = 4.0
const COMPANION_TIPS_POSITION := Vector2(-570.0, -295.0)
const COMPANION_TIPS_SCALE := Vector2(0.672, 0.672)
const COMPANION_TIPS_Z_INDEX: int = 80
const MOBILE_INTERACTION_PANEL_ANCHOR_LEFT: float = 0.75
const MOBILE_INTERACTION_PANEL_ANCHOR_TOP: float = 0.5
const MOBILE_INTERACTION_PANEL_BUTTON_SIZE := Vector2(146.0, 75.0)
const MOBILE_INTERACTION_PANEL_FADE_DURATION: float = 0.12

var _town_companions: Array[Dictionary] = []
var _town_current_hero: String = ""
var _companion_clip_shader: Shader
var _mobile_interaction_layer: CanvasLayer = null
var _mobile_interaction_container: VBoxContainer = null
var _mobile_interaction_keys: Array[String] = []
var _mobile_interaction_tween: Tween = null


func _ready() -> void:
	Global.reset_game_speed()
	# 设置音效使用SFX总线
	setup_audio_buses()
	player = $Player
	player.z_as_relative = false
	player.z_index = PLAYER_TOWN_Z_INDEX
	_sync_player_shadow_layer()
	_sync_player_shadow_layer_deferred()
	Global.load_game()
	_grant_missing_story6_magic_core_reward()
	Global.reset_camera_zoom_locks()
	Global.in_synthesis = false
	
	# 重置玩家属性
	PC.reset_player_attr()
	
	Global.in_town = true
	player.change_hero(PC.player_name)
	_town_current_hero = PC.player_name
	
	# 功能解锁检查
	_apply_feature_unlocks()
	
	# 为NPC添加脚底阴影
	_setup_npc_shadows()
	
	# 城镇内不应用关卡的体型缩小(0.9)
	player.scale = Vector2(1.2, 1.2)
	
	defaultLayer.unlock_setting_button()
	_set_town_panel_open(false)
	
	# 播放城镇BGM和环境音
	Global.emit_signal("stage_bgm", "town")

	# 随机生成小动物
	_spawn_animals()
	_refresh_town_companions()

	# 按顺序检查并触发教程
	_check_and_trigger_tutorials()


func _grant_missing_story6_magic_core_reward() -> void:
	if Global.has_received_story_6_magic_core_reward:
		return
	if not Global.has_seen_story_6 and not Global.has_seen_story_5:
		return
	for item_id in STORY6_MAGIC_CORE_REWARD.keys():
		Global.add_item_count(item_id, int(STORY6_MAGIC_CORE_REWARD[item_id]))
	Global.has_seen_story_6 = true
	Global.has_received_story_6_magic_core_reward = true
	Global.save_game(true)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.alt_pressed or key_event.ctrl_pressed or key_event.meta_pressed:
		return
	if _is_key_event(key_event, KEY_ESCAPE):
		if _handle_escape_shortcut():
			get_viewport().set_input_as_handled()
		return
	if _is_entry_shortcut_blocked():
		return
	var handled := false
	if _is_key_event(key_event, KEY_I):
		handled = defaultLayer.has_method("try_open_bag") and defaultLayer.try_open_bag()
	elif _is_key_event(key_event, KEY_K):
		handled = defaultLayer.has_method("try_open_skill_config") and defaultLayer.try_open_skill_config()
	elif _is_key_event(key_event, KEY_U):
		handled = _try_open_achievement_shortcut()
	if handled:
		get_viewport().set_input_as_handled()

func _is_key_event(event: InputEventKey, key: Key) -> bool:
	return event.keycode == key or event.physical_keycode == key

func _handle_escape_shortcut() -> bool:
	if defaultLayer.has_method("close_current_entry_ui") and defaultLayer.close_current_entry_ui():
		return true
	if _is_town_panel_visible():
		return _close_visible_town_panel()
	if _is_entry_shortcut_blocked():
		return false
	return defaultLayer.has_method("try_open_setting") and defaultLayer.try_open_setting()

func _try_open_achievement_shortcut() -> bool:
	if _is_entry_shortcut_blocked():
		return false
	_on_achievement_button_pressed()
	return true

func _is_entry_shortcut_blocked() -> bool:
	if dialog_control != null and dialog_control.visible:
		return true
	if defaultLayer.has_method("is_entry_ui_open") and defaultLayer.is_entry_ui_open():
		return true
	return _is_town_panel_visible()

func _is_town_panel_visible() -> bool:
	return (
		(is_instance_valid(levelChangeLayer) and levelChangeLayer.visible)
		or (is_instance_valid(cultivationLayer) and cultivationLayer.visible)
		or (is_instance_valid(synthesisLayer) and synthesisLayer.visible)
		or (is_instance_valid(studyLayer) and studyLayer.visible)
		or (is_instance_valid(heroLayer) and heroLayer.visible)
		or (is_instance_valid(shopLayer) and shopLayer.visible)
		or (is_instance_valid(achievementLayerInstance) and achievementLayerInstance.visible)
		or (is_instance_valid(jcLayerInstance) and jcLayerInstance.visible)
	)

func _set_town_panel_open(open: bool) -> void:
	if defaultLayer != null and defaultLayer.has_method("set_town_panel_open"):
		defaultLayer.set_town_panel_open(open)

func _close_visible_town_panel() -> bool:
	if is_instance_valid(synthesisLayer) and synthesisLayer.visible:
		if synthesisLayer.has_method("_on_exit_pressed"):
			synthesisLayer.call("_on_exit_pressed")
		else:
			_on_exit_pressed()
		return true
	if is_instance_valid(shopLayer) and shopLayer.visible:
		if shopLayer.has_method("_on_exit_button_pressed"):
			shopLayer.call("_on_exit_button_pressed")
		else:
			_on_exit_pressed()
		return true
	if is_instance_valid(studyLayer) and studyLayer.visible:
		if studyLayer.has_method("_on_exit_pressed"):
			studyLayer.call("_on_exit_pressed")
		else:
			_on_exit_pressed()
		return true
	if is_instance_valid(heroLayer) and heroLayer.visible:
		if heroLayer.has_method("_on_exit_pressed"):
			heroLayer.call("_on_exit_pressed")
		_on_exit_pressed()
		return true
	if is_instance_valid(levelChangeLayer) and levelChangeLayer.visible:
		_on_exit_pressed()
		return true
	if is_instance_valid(cultivationLayer) and cultivationLayer.visible:
		_on_exit_pressed()
		return true
	if is_instance_valid(achievementLayerInstance) and achievementLayerInstance.visible:
		_on_exit_pressed()
		return true
	if is_instance_valid(jcLayerInstance) and jcLayerInstance.visible:
		_on_exit_pressed()
		return true
	return false

## 首次进入城镇触发城镇教程
func _trigger_town_tutorial() -> void:
	await get_tree().create_timer(0.75).timeout
	if not is_inside_tree() or get_tree() == null:
		return
	if Global.has_seen_town_tutorial:
		return
	var tutorial_scene = load("res://Scenes/town/town_tutorial.tscn")
	if tutorial_scene:
		var tutorial = tutorial_scene.instantiate()
		add_child(tutorial)
	Global.has_seen_town_tutorial = true
	Global.save_game()

## 按顺序检查并触发待显示的教程
func _check_and_trigger_tutorials() -> void:
	# 首次进入城镇教程
	if not Global.has_seen_town_tutorial:
		await _trigger_town_tutorial()
	# 看完story3后触发炼丹炉教程
	if Global.has_seen_story_3 and not Global.has_seen_liandan_tutorial:
		await _trigger_liandan_tutorial()
	# 看完story4后触发神秘商铺教程
	if Global.has_seen_story_4 and not Global.has_seen_shop_tutorial:
		await _trigger_shop_tutorial()
	# 看完story8后触发诗想难度教程
	if Global.has_seen_story_8 and not Global.has_seen_poem_tutorial:
		await _trigger_poem_tutorial()

## 看完story3后触发炼丹炉教程
func _trigger_liandan_tutorial() -> void:
	await get_tree().create_timer(0.75).timeout
	if not is_inside_tree() or get_tree() == null:
		return
	if Global.has_seen_liandan_tutorial:
		return
	var tutorial_scene = load("res://Scenes/town/liandan_tutorial.tscn")
	if tutorial_scene:
		var tutorial = tutorial_scene.instantiate()
		add_child(tutorial)
	Global.has_seen_liandan_tutorial = true
	Global.save_game()

## 看完story8后触发诗想难度教程
func _trigger_poem_tutorial() -> void:
	await get_tree().create_timer(0.75).timeout
	if not is_inside_tree() or get_tree() == null:
		return
	if Global.has_seen_poem_tutorial:
		return
	var tutorial_scene = load("res://Scenes/town/poem_tutorial.tscn")
	if tutorial_scene:
		var tutorial = tutorial_scene.instantiate()
		add_child(tutorial)
	Global.has_seen_poem_tutorial = true
	Global.save_game()

## 看完story4后触发神秘商铺教程
func _trigger_shop_tutorial() -> void:
	await get_tree().create_timer(0.75).timeout
	if not is_inside_tree() or get_tree() == null:
		return
	if Global.has_seen_shop_tutorial:
		return
	var tutorial_scene = load("res://Scenes/town/shop_tutorial.tscn")
	if tutorial_scene:
		var tutorial = tutorial_scene.instantiate()
		add_child(tutorial)
	Global.has_seen_shop_tutorial = true
	Global.save_game()

## 随机生成小动物（1~2只小鸡和1~2只兔子）
func _spawn_animals() -> void:
	var regions = [
		Rect2(-500, 55, 300, 35), # 区域1: x=-500~-200, y=55~90
		Rect2(225, 50, 230, 60), # 区域2: x=225~455, y=50~110
	]

	# var chick_count = randi_range(1, 2)
	# for i in range(chick_count):
	# 	var chick = CHICK_SCENE.instantiate()
	# 	var region = regions[randi() % regions.size()]
	# 	chick.position = Vector2(
	# 		randf_range(region.position.x, region.position.x + region.size.x),
	# 		randf_range(region.position.y, region.position.y + region.size.y)
	# 	)
	# 	add_child(chick)

	var rabbit_count = randi_range(1, 2)
	for i in range(rabbit_count):
		var rabbit = RABBIT_SCENE.instantiate()
		var region = regions[randi() % regions.size()]
		rabbit.position = Vector2(
			randf_range(region.position.x, region.position.x + region.size.x),
			randf_range(region.position.y, region.position.y + region.size.y)
		)
		add_child(rabbit)

func _refresh_town_companions(use_fade: bool = false) -> void:
	if use_fade:
		_fade_refresh_town_companions()
		return

	for companion_data in _town_companions:
		var companion_node = companion_data.get("node")
		if is_instance_valid(companion_node):
			companion_node.queue_free()
	_town_companions.clear()

	var available_heroes := _get_available_companion_heroes()
	if available_heroes.is_empty():
		return

	var random_areas := _get_random_companion_areas()
	if random_areas.is_empty():
		return

	available_heroes.shuffle()
	random_areas.shuffle()
	var spawn_count: int = mini(available_heroes.size(), random_areas.size())
	for i in range(spawn_count):
		_spawn_town_companion(available_heroes[i], random_areas[i])

func _fade_refresh_town_companions() -> void:
	var old_nodes: Array[Node2D] = []
	for companion_data in _town_companions:
		var companion_node := companion_data.get("node") as Node2D
		if is_instance_valid(companion_node):
			companion_node.set_meta("companion_transitioning", true)
			old_nodes.append(companion_node)
	_town_companions.clear()

	for companion_node in old_nodes:
		var fade_out := create_tween()
		fade_out.tween_property(companion_node, "modulate:a", 0.0, COMPANION_FADE_DURATION)
		fade_out.tween_callback(func():
			if is_instance_valid(companion_node):
				companion_node.queue_free()
		)

	var spawn_tween := create_tween()
	spawn_tween.tween_callback(func():
		if not is_inside_tree():
			return
		_refresh_town_companions()
		for companion_data in _town_companions:
			var companion_node := companion_data.get("node") as Node2D
			if is_instance_valid(companion_node):
				companion_node.modulate.a = 0.0
				var fade_in := create_tween()
				fade_in.tween_property(companion_node, "modulate:a", 1.0, COMPANION_FADE_DURATION)
	).set_delay(COMPANION_FADE_DURATION)

func _get_available_companion_heroes() -> Array[String]:
	var heroes: Array[String] = []
	for hero_key in HERO_KEYS:
		if hero_key == PC.player_name:
			continue
		if _is_hero_unlocked(hero_key):
			heroes.append(hero_key)
	return heroes

func _is_hero_unlocked(hero_key: String) -> bool:
	match hero_key:
		"moning":
			return Global.unlock_moning
		"yiqiu":
			return Global.unlock_yiqiu
		"noam":
			return Global.unlock_noam
		"kansel":
			return Global.unlock_kansel
		"xueming":
			return Global.unlock_xueming
	return false

func _get_random_companion_areas() -> Array[Area2D]:
	var areas: Array[Area2D] = []
	for area_name in RANDOM_COMPANION_AREA_NAMES:
		var area := get_node_or_null(area_name) as Area2D
		if area != null:
			areas.append(area)
	return areas

func _spawn_town_companion(hero_key: String, area: Area2D) -> void:
	_spawn_town_companion_at(hero_key, _get_random_point_in_area(area), _is_companion_area_facing_left(area))

func _spawn_town_companion_at(hero_key: String, spawn_position: Vector2, face_left: bool, replace_index: int = -1) -> Dictionary:
	var companion := CharacterBody2D.new()
	companion.name = "TownCompanion_" + hero_key
	companion.add_to_group("npc")
	companion.add_to_group("town_companion")
	companion.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	companion.collision_layer = 0
	companion.collision_mask = COMPANION_WORLD_COLLISION_MASK
	companion.z_as_relative = false
	companion.z_index = COMPANION_ROOT_Z_INDEX
	companion.scale = COMPANION_SCALE

	var lower_sprite := AnimatedSprite2D.new()
	lower_sprite.name = "LowerSprite"
	lower_sprite.z_as_relative = false
	lower_sprite.z_index = COMPANION_LOWER_Z_INDEX
	lower_sprite.flip_h = face_left
	_apply_companion_clip_material(lower_sprite, false)

	var upper_sprite := AnimatedSprite2D.new()
	upper_sprite.name = "UpperSprite"
	upper_sprite.z_as_relative = false
	upper_sprite.z_index = COMPANION_UPPER_Z_INDEX
	upper_sprite.flip_h = face_left
	_apply_companion_clip_material(upper_sprite, true)

	var hero_sprite := player.get_node_or_null(hero_key) as AnimatedSprite2D
	if hero_sprite != null:
		lower_sprite.sprite_frames = hero_sprite.sprite_frames
		upper_sprite.sprite_frames = hero_sprite.sprite_frames
		lower_sprite.play("idle")
		upper_sprite.play("idle")

	add_child(companion)
	companion.global_position = spawn_position
	companion.add_child(lower_sprite)
	companion.add_child(upper_sprite)
	_create_npc_shadow(companion, _get_companion_shadow_offset_y(hero_key))
	var collision_shape := _add_companion_collision(companion)

	var tips := ACTION_TIPS_SCENE.instantiate() as Control
	tips.name = "Tips"
	tips.position = COMPANION_TIPS_POSITION
	tips.scale = COMPANION_TIPS_SCALE
	tips.z_as_relative = false
	tips.z_index = COMPANION_TIPS_Z_INDEX
	tips.visible = false
	tips.modulate.a = 0.0
	companion.add_child(tips)
	if tips.has_method("change_name"):
		tips.change_name(_get_hero_display_name(hero_key) + "\n<同伴>")
	if tips.has_method("change_label1_text"):
		tips.change_label1_text("闲聊 [F]")
	if tips.has_method("change_function2_visible"):
		tips.change_function2_visible(true)
	if tips.has_method("change_label2_text"):
		tips.change_label2_text("切换 [G]")

	var state_key := "companionTips_" + hero_key
	ui_states[state_key] = false
	var companion_data := {
		"hero_key": hero_key,
		"node": companion,
		"lower_sprite": lower_sprite,
		"upper_sprite": upper_sprite,
		"collision_shape": collision_shape,
		"tips": tips,
		"state_key": state_key,
		"move_state": "idle",
		"move_timer": randf_range(COMPANION_IDLE_TIME_MIN, COMPANION_IDLE_TIME_MAX),
		"move_direction": Vector2.ZERO,
		"draw_front": false,
	}
	_update_companion_draw_order(companion_data, true)
	if replace_index >= 0 and replace_index < _town_companions.size():
		_town_companions[replace_index] = companion_data
	else:
		_town_companions.append(companion_data)
	return companion_data

func _add_companion_collision(companion: CharacterBody2D) -> CollisionShape2D:
	var shape_node := CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	shape_node.position = Vector2(0, 10.0)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(21.0, 21.0)
	shape_node.shape = shape
	companion.add_child(shape_node)
	return shape_node

func _apply_companion_clip_material(sprite: AnimatedSprite2D, upper_half: bool) -> void:
	var material := ShaderMaterial.new()
	material.shader = _get_companion_clip_shader()
	material.set_shader_parameter("upper_half", upper_half)
	sprite.material = material

func _get_companion_clip_shader() -> Shader:
	if _companion_clip_shader != null:
		return _companion_clip_shader
	_companion_clip_shader = Shader.new()
	_companion_clip_shader.code = """
shader_type canvas_item;
uniform bool upper_half = true;
varying vec2 local_vertex;

void vertex() {
	local_vertex = VERTEX;
}

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	if (upper_half) {
		if (local_vertex.y > 0.0) {
			color.a = 0.0;
		}
	} else {
		if (local_vertex.y <= 0.0) {
			color.a = 0.0;
		}
	}
	COLOR = color;
}
"""
	return _companion_clip_shader

func _get_random_point_in_area(area: Area2D) -> Vector2:
	var collision_shape := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null or collision_shape.shape == null:
		return area.global_position

	if collision_shape.shape is RectangleShape2D:
		var rect_shape := collision_shape.shape as RectangleShape2D
		var half_size := rect_shape.size * 0.5
		var local_point := collision_shape.position + Vector2(
			randf_range(-half_size.x, half_size.x),
			randf_range(-half_size.y, half_size.y)
		)
		return area.to_global(local_point)

	return collision_shape.global_position

func _is_companion_area_facing_left(area: Area2D) -> bool:
	return area.name.to_lower().ends_with("_left")

func _get_companion_shadow_offset_y(hero_key: String) -> float:
	match hero_key:
		"kansel":
			return COMPANION_SHADOW_OFFSET_Y + 4.0
		"yiqiu", "yanqiu":
			return COMPANION_SHADOW_OFFSET_Y - 2.0
		"noam":
			return COMPANION_SHADOW_OFFSET_Y - 3.0
	return COMPANION_SHADOW_OFFSET_Y

func _get_hero_display_name(hero_key: String) -> String:
	return str(HERO_DISPLAY_NAMES.get(hero_key, hero_key))

## 根据游戏进度控制功能解锁
## - 全局第2次失败后：炼丹炉解锁
## - 全局第3次失败后：坎(神秘商铺)解锁
## - 通关ruin后：坤(study_tree加点)解锁
## - 通关cave后：异国的诗人解锁，诗想难度开启
func _apply_feature_unlocks() -> void:
	# 炼丹炉：全局第2次失败后解锁
	var danlu_unlocked = Global.total_defeat_count >= 2
	if danlu:
		danlu.visible = danlu_unlocked
	
	# 坎(神秘商铺)：全局第3次失败后解锁
	var merchant_unlocked = Global.total_defeat_count >= 3
	if merchant:
		merchant.visible = merchant_unlocked
		if merchant_unlocked:
			_create_npc_shadow(merchant, 17.0)
	
	# 坤(study_tree)：通关ruin后解锁
	var levelUpMan2_unlocked = Global.is_stage_cleared("ruin")
	if levelUpMan2:
		levelUpMan2.visible = levelUpMan2_unlocked
		if levelUpMan2_unlocked:
			_create_npc_shadow(levelUpMan2, 23.0)
	
	# 异国的诗人：通关cave后解锁
	var bard_unlocked = Global.is_stage_cleared("cave")
	if bard:
		bard.visible = bard_unlocked
		if bard_unlocked:
			_create_npc_shadow(bard)

## 为初始可见的NPC添加脚底阴影
func _setup_npc_shadows() -> void:
	for npc in [levelUpMan]:
		if npc:
			_create_npc_shadow(npc)
	# 乾长老体型较大，阴影偏移y=40
	if cystal:
		_create_npc_shadow(cystal, 34.0)
	if portal:
		return

## 为NPC创建脚底阴影
func _create_npc_shadow(npc: Node2D, offset_y: float = 21.0) -> void:
	var shadow := npc.get_node_or_null("Shadow") as Sprite2D
	if npc.has_node("Shadow"):
		_sync_town_shadow_layer(shadow)
		return
	shadow = CharacterEffects.create_shadow(npc, 40.0, 14.0, offset_y)
	_sync_town_shadow_layer(shadow)

func _sync_player_shadow_layer() -> void:
	if not is_instance_valid(player):
		return
	var shadow := player.get_node_or_null("Shadow") as Sprite2D
	if shadow == null:
		return
	_sync_town_shadow_layer(shadow)

func _sync_town_shadow_layer(shadow: Sprite2D) -> void:
	if shadow == null:
		return
	shadow.z_as_relative = false
	shadow.z_index = CharacterEffects.SHADOW_Z_INDEX
	shadow.show_behind_parent = false

func _sync_player_shadow_layer_deferred() -> void:
	await get_tree().process_frame
	_sync_player_shadow_layer()

func setup_audio_buses() -> void:
	# 设置所有音效使用SFX总线
	if has_node("LevelUP"):
		$LevelUP.bus = "SFX"
	if has_node("Buzzer"):
		$Buzzer.bus = "SFX"

	PC.movement_disabled = false
	PC.is_game_over = false
	# 初始化UI状态
	ui_states["cystalTips"] = false
	ui_states["levelUpManTips"] = false
	ui_states["levelUpMan2Tips"] = false
	ui_states["bardTips"] = false
	ui_states["merchantTips"] = false
	ui_states["danluTips"] = false
	ui_states["portalTips"] = false
	ui_states["dark_overlay"] = false
	
	# 确保UI元素初始状态正确
	cystalTips.visible = false
	cystalTips.modulate.a = 0.0
	levelUpManTips.visible = false
	levelUpManTips.modulate.a = 0.0
	levelUpMan2Tips.visible = false
	levelUpMan2Tips.modulate.a = 0.0
	bardTips.visible = false
	bardTips.modulate.a = 0.0
	merchantTips.visible = false
	merchantTips.modulate.a = 0.0
	danluTips.visible = false
	danluTips.modulate.a = 0.0
	portalTips.visible = false
	portalTips.modulate.a = 0.0
	
	# 初始化黑色滤镜
	if dark_overlay:
		dark_overlay.visible = false
		dark_overlay.modulate.a = 0.0
	
	# 初始化界面层（CanvasLayer本身不需要设置modulate）
	if levelChangeLayer:
		levelChangeLayer.visible = false
	
	if cultivationLayer:
		cultivationLayer.visible = false
	
	if synthesisLayer:
		synthesisLayer.visible = false
	
	if studyLayer:
		studyLayer.visible = false
		if studyLayer.has_signal("exit_requested") and not studyLayer.exit_requested.is_connected(_on_exit_pressed):
			studyLayer.exit_requested.connect(_on_exit_pressed)
	
	if heroLayer:
		heroLayer.visible = false
		var hero_changed_callable := Callable(self , "_on_hero_layer_hero_changed")
		if heroLayer.has_signal("hero_changed") and not heroLayer.is_connected("hero_changed", hero_changed_callable):
			heroLayer.connect("hero_changed", hero_changed_callable)

	# 初始化 JC 教程层
	_ensure_jc_layer()

	Global.emit_signal("reset_camera")
	Global.connect("press_f", Callable(self , "press_interact"))
	Global.connect("press_g", Callable(self , "press_interact2"))
	Global.connect("press_h", Callable(self , "press_interact3"))
	if dialog_control != null and dialog_control.has_signal("dialog_completed"):
		var dialog_completed_callable := Callable(self , "_on_town_dialog_completed")
		if not dialog_control.is_connected("dialog_completed", dialog_completed_callable):
			dialog_control.connect("dialog_completed", dialog_completed_callable)
	heroLayer.exit_button.pressed.connect(_on_exit_pressed)
	_ensure_shop_layer()
	_ensure_achievement_layer()
	if defaultLayer.has_signal("achievement_pressed") and not defaultLayer.achievement_pressed.is_connected(_on_achievement_button_pressed):
		defaultLayer.achievement_pressed.connect(_on_achievement_button_pressed)
	_setup_mobile_interaction_panel()
	call_deferred("_play_pending_achievement_unlocks")

func _ensure_jc_layer() -> void:
	if is_instance_valid(jcLayerInstance):
		return
	if jcLayer != null:
		jcLayerInstance = jcLayer
	else:
		jcLayerInstance = JC_LAYER_SCENE.instantiate()
		add_child(jcLayerInstance)
	jcLayerInstance.visible = false
	if jcLayerInstance.has_signal("exit_requested") and not jcLayerInstance.exit_requested.is_connected(_on_exit_pressed):
		jcLayerInstance.exit_requested.connect(_on_exit_pressed)

func _on_jc_button_pressed() -> void:
	_ensure_jc_layer()
	PC.movement_disabled = true
	_set_town_panel_open(true)
	defaultLayer.visible = false
	if dark_overlay:
		if ui_tweens.has("dark_overlay") and ui_tweens["dark_overlay"]:
			ui_tweens["dark_overlay"].kill()
		ui_tweens["dark_overlay"] = create_tween()
		dark_overlay.visible = true
		dark_overlay.modulate.a = 0.0
		ui_tweens["dark_overlay"].tween_property(dark_overlay, "modulate:a", 0.55, 0.15)
	if jcLayerInstance.has_method("open_layer"):
		jcLayerInstance.open_layer()

func _ensure_achievement_layer() -> void:
	if is_instance_valid(achievementLayerInstance):
		return
	achievementLayerInstance = ACHIEVEMENT_LAYER_SCENE.instantiate()
	if canvasLayer != null:
		achievementLayerInstance.layer = canvasLayer.layer + 1
	achievementLayerInstance.visible = false
	add_child(achievementLayerInstance)
	if achievementLayerInstance.has_signal("exit_requested") and not achievementLayerInstance.exit_requested.is_connected(_on_exit_pressed):
		achievementLayerInstance.exit_requested.connect(_on_exit_pressed)

func _on_achievement_button_pressed() -> void:
	_ensure_achievement_layer()
	PC.movement_disabled = true
	if defaultLayer.has_method("set_achievement_layer_open"):
		defaultLayer.set_achievement_layer_open(true)
	defaultLayer.visible = false
	Global.lock_camera_zoom(CAMERA_ZOOM_LOCK_ACHIEVEMENT)
	if dark_overlay:
		if ui_tweens.has("dark_overlay") and ui_tweens["dark_overlay"]:
			ui_tweens["dark_overlay"].kill()
		ui_tweens["dark_overlay"] = create_tween()
		dark_overlay.visible = true
		dark_overlay.modulate.a = 0.0
		ui_tweens["dark_overlay"].tween_property(dark_overlay, "modulate:a", 0.55, 0.15)
	if ui_tweens.has("achievementLayer") and ui_tweens["achievementLayer"]:
		ui_tweens["achievementLayer"].kill()
	ui_tweens["achievementLayer"] = create_tween()
	ui_tweens["achievementLayer"].set_parallel(true)
	if achievementLayerInstance.has_method("open_layer"):
		achievementLayerInstance.open_layer()
	var achievement_panel := achievementLayerInstance.get_node_or_null("Panel")
	if achievement_panel and achievement_panel.has_method("set_modulate"):
		achievement_panel.modulate.a = 0.0
		ui_tweens["achievementLayer"].tween_property(achievement_panel, "modulate:a", 1.0, 0.15).set_delay(0.15)

func _play_pending_achievement_unlocks() -> void:
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	AchievementManager.show_pending_popups()

# UI动画处理函数
func _ensure_shop_layer() -> void:
	if is_instance_valid(shopLayer):
		return
	shopLayer = SHOP_LAYER_SCENE.instantiate()
	shopLayer.visible = false
	add_child(shopLayer)
	if shopLayer.has_signal("exit_requested") and not shopLayer.exit_requested.is_connected(_on_exit_pressed):
		shopLayer.exit_requested.connect(_on_exit_pressed)

func _open_shop_layer() -> void:
	_ensure_shop_layer()
	PC.movement_disabled = true
	_set_town_panel_open(true)
	defaultLayer.visible = false
	Global.lock_camera_zoom(CAMERA_ZOOM_LOCK_SHOP)
	if dark_overlay:
		if ui_tweens.has("dark_overlay") and ui_tweens["dark_overlay"]:
			ui_tweens["dark_overlay"].kill()
		ui_tweens["dark_overlay"] = create_tween()
		dark_overlay.visible = true
		dark_overlay.modulate.a = 0.0
		ui_tweens["dark_overlay"].tween_property(dark_overlay, "modulate:a", 1.0, 0.15)
	if ui_tweens.has("shopLayer") and ui_tweens["shopLayer"]:
		ui_tweens["shopLayer"].kill()
	ui_tweens["shopLayer"] = create_tween()
	ui_tweens["shopLayer"].set_parallel(true)
	shopLayer.visible = true
	if shopLayer.has_method("open_shop"):
		shopLayer.open_shop()
	for child in shopLayer.get_children():
		if child.has_method("set_modulate"):
			child.modulate.a = 0.0
			ui_tweens["shopLayer"].tween_property(child, "modulate:a", 1.0, 0.15).set_delay(0.15)

func _open_hero_layer() -> void:
	PC.movement_disabled = true
	_set_town_panel_open(true)
	defaultLayer.visible = false
	Global.lock_camera_zoom(CAMERA_ZOOM_LOCK_HERO)
	if dark_overlay:
		if ui_tweens.has("dark_overlay") and ui_tweens["dark_overlay"]:
			ui_tweens["dark_overlay"].kill()
		ui_tweens["dark_overlay"] = create_tween()
		dark_overlay.visible = true
		dark_overlay.modulate.a = 0.0
		ui_tweens["dark_overlay"].tween_property(dark_overlay, "modulate:a", 1.0, 0.15)
	if ui_tweens.has("heroLayer") and ui_tweens["heroLayer"]:
		ui_tweens["heroLayer"].kill()
	ui_tweens["heroLayer"] = create_tween()
	ui_tweens["heroLayer"].set_parallel(true)
	heroLayer.visible = true
	for child in heroLayer.get_children():
		if child.has_method("set_modulate"):
			child.modulate.a = 0.0
			ui_tweens["heroLayer"].tween_property(child, "modulate:a", 1.0, 0.15).set_delay(0.15)

func _open_level_change_layer() -> void:
	PC.movement_disabled = true
	_set_town_panel_open(true)
	defaultLayer.visible = false
	Global.lock_camera_zoom(CAMERA_ZOOM_LOCK_LEVEL_SELECT)
	if dark_overlay:
		if ui_tweens.has("dark_overlay") and ui_tweens["dark_overlay"]:
			ui_tweens["dark_overlay"].kill()
		ui_tweens["dark_overlay"] = create_tween()
		dark_overlay.visible = true
		dark_overlay.modulate.a = 0.0
		ui_tweens["dark_overlay"].tween_property(dark_overlay, "modulate:a", 1.0, 0.15)
	if ui_tweens.has("levelChangeLayer") and ui_tweens["levelChangeLayer"]:
		ui_tweens["levelChangeLayer"].kill()
	ui_tweens["levelChangeLayer"] = create_tween()
	ui_tweens["levelChangeLayer"].set_parallel(true)
	if levelChangeLayer != null and levelChangeLayer.has_method("prepare_for_open"):
		levelChangeLayer.prepare_for_open()
	levelChangeLayer.visible = true
	for child in levelChangeLayer.get_children():
		if child.has_method("set_modulate"):
			child.modulate.a = 0.0
			ui_tweens["levelChangeLayer"].tween_property(child, "modulate:a", 1.0, 0.15).set_delay(0.15)

func _open_cultivation_layer() -> void:
	PC.movement_disabled = true
	_set_town_panel_open(true)
	defaultLayer.visible = false
	Global.lock_camera_zoom(CAMERA_ZOOM_LOCK_CULTIVATION)
	if dark_overlay:
		if ui_tweens.has("dark_overlay") and ui_tweens["dark_overlay"]:
			ui_tweens["dark_overlay"].kill()
		ui_tweens["dark_overlay"] = create_tween()
		dark_overlay.visible = true
		dark_overlay.modulate.a = 0.0
		ui_tweens["dark_overlay"].tween_property(dark_overlay, "modulate:a", 1.0, 0.15)
	refresh_point()
	if ui_tweens.has("cultivationLayer") and ui_tweens["cultivationLayer"]:
		ui_tweens["cultivationLayer"].kill()
	ui_tweens["cultivationLayer"] = create_tween()
	ui_tweens["cultivationLayer"].set_parallel(true)
	cultivationLayer.visible = true
	for child in cultivationLayer.get_children():
		if child.has_method("set_modulate"):
			child.modulate.a = 0.0
			ui_tweens["cultivationLayer"].tween_property(child, "modulate:a", 1.0, 0.15).set_delay(0.15)

func _open_synthesis_layer() -> void:
	PC.movement_disabled = true
	_set_town_panel_open(true)
	defaultLayer.visible = false
	Global.lock_camera_zoom("synthesis")
	if dark_overlay:
		if ui_tweens.has("dark_overlay") and ui_tweens["dark_overlay"]:
			ui_tweens["dark_overlay"].kill()
		ui_tweens["dark_overlay"] = create_tween()
		dark_overlay.visible = true
		dark_overlay.modulate.a = 0.0
		ui_tweens["dark_overlay"].tween_property(dark_overlay, "modulate:a", 1.0, 0.15)
	if ui_tweens.has("synthesisLayer") and ui_tweens["synthesisLayer"]:
		ui_tweens["synthesisLayer"].kill()
	ui_tweens["synthesisLayer"] = create_tween()
	ui_tweens["synthesisLayer"].set_parallel(true)
	synthesisLayer.visible = true
	for child in synthesisLayer.get_children():
		if child.has_method("set_modulate"):
			child.modulate.a = 0.0
			ui_tweens["synthesisLayer"].tween_property(child, "modulate:a", 1.0, 0.15).set_delay(0.15)
	Global.in_synthesis = true

func _open_study_layer() -> void:
	PC.movement_disabled = true
	_set_town_panel_open(true)
	defaultLayer.visible = false
	Global.lock_camera_zoom(CAMERA_ZOOM_LOCK_STUDY)
	if dark_overlay:
		if ui_tweens.has("dark_overlay") and ui_tweens["dark_overlay"]:
			ui_tweens["dark_overlay"].kill()
		ui_tweens["dark_overlay"] = create_tween()
		dark_overlay.visible = true
		dark_overlay.modulate.a = 0.0
		ui_tweens["dark_overlay"].tween_property(dark_overlay, "modulate:a", 1.0, 0.15)
	if ui_tweens.has("studyLayer") and ui_tweens["studyLayer"]:
		ui_tweens["studyLayer"].kill()
	ui_tweens["studyLayer"] = create_tween()
	ui_tweens["studyLayer"].set_parallel(true)
	studyLayer.visible = true
	for child in studyLayer.get_children():
		if child.has_method("set_modulate"):
			child.modulate.a = 0.0
			ui_tweens["studyLayer"].tween_property(child, "modulate:a", 1.0, 0.15).set_delay(0.15)

func _setup_mobile_interaction_panel() -> void:
	if _mobile_interaction_layer != null and is_instance_valid(_mobile_interaction_layer):
		return
	_mobile_interaction_layer = CanvasLayer.new()
	_mobile_interaction_layer.name = "MobileTownInteractions"
	_mobile_interaction_layer.layer = 95
	add_child(_mobile_interaction_layer)

	_mobile_interaction_container = VBoxContainer.new()
	_mobile_interaction_container.name = "ButtonList"
	_mobile_interaction_container.anchor_left = MOBILE_INTERACTION_PANEL_ANCHOR_LEFT
	_mobile_interaction_container.anchor_right = MOBILE_INTERACTION_PANEL_ANCHOR_LEFT
	_mobile_interaction_container.anchor_top = MOBILE_INTERACTION_PANEL_ANCHOR_TOP
	_mobile_interaction_container.anchor_bottom = MOBILE_INTERACTION_PANEL_ANCHOR_TOP
	_mobile_interaction_container.offset_left = 0.0
	_mobile_interaction_container.offset_top = 0.0
	_mobile_interaction_container.offset_right = MOBILE_INTERACTION_PANEL_BUTTON_SIZE.x
	_mobile_interaction_container.offset_bottom = 0.0
	_mobile_interaction_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	_mobile_interaction_container.add_theme_constant_override("separation", 20)
	_mobile_interaction_container.visible = false
	_mobile_interaction_container.modulate.a = 0.0
	_mobile_interaction_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_mobile_interaction_layer.add_child(_mobile_interaction_container)

	if not Global.input_device_mode_changed.is_connected(_on_town_input_device_mode_changed):
		Global.input_device_mode_changed.connect(_on_town_input_device_mode_changed)

func _on_town_input_device_mode_changed(_mode: String) -> void:
	_mobile_interaction_keys.clear()
	if not Global.is_mobile_input_mode():
		_hide_mobile_interaction_panel()

func _update_mobile_interaction_panel() -> void:
	if not Global.is_mobile_input_mode():
		_hide_mobile_interaction_panel()
		return
	if _is_entry_shortcut_blocked():
		_hide_mobile_interaction_panel()
		return
	_setup_mobile_interaction_panel()
	var actions: Array[Dictionary] = _collect_mobile_interaction_actions()
	var keys: Array[String] = []
	for action: Dictionary in actions:
		keys.append(str(action.get("key", "")))
	if keys == _mobile_interaction_keys:
		return
	_mobile_interaction_keys = keys
	_rebuild_mobile_interaction_buttons(actions)

func _collect_mobile_interaction_actions() -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if _is_player_near(cystal, interaction_distance + 10):
		actions.append({"key": "npc:qian:switch", "text": "乾-切换", "target": "qian", "action": "hero"})
		actions.append({"key": "npc:qian:talk", "text": "乾-交谈", "target": "qian", "action": "talk_npc"})
	if _is_player_near(levelUpMan, interaction_distance - 5):
		actions.append({"key": "npc:xun:cultivation", "text": "巽-修习", "target": "xun", "action": "cultivation"})
		actions.append({"key": "npc:xun:talk", "text": "巽-交谈", "target": "xun", "action": "talk_npc"})
	if _is_player_near(levelUpMan2, interaction_distance - 5) and levelUpMan2.visible:
		actions.append({"key": "npc:kun:study", "text": "坤-进阶", "target": "kun", "action": "study"})
		actions.append({"key": "npc:kun:talk", "text": "坤-交谈", "target": "kun", "action": "talk_npc"})
	if _is_player_near(bard, interaction_distance + 5) and bard.visible:
		actions.append({"key": "npc:bard:talk", "text": "异国诗人-交谈", "target": "bard", "action": "talk_npc"})
	if _is_player_near(merchant, interaction_distance + 15) and merchant.visible:
		actions.append({"key": "npc:kan:shop", "text": "坎-交易", "target": "kan", "action": "shop"})
		actions.append({"key": "npc:kan:talk", "text": "坎-交谈", "target": "kan", "action": "talk_npc"})
	if _is_player_near(danlu, interaction_distance + 20) and danlu.visible:
		actions.append({"key": "npc:danlu:synthesis", "text": "八卦炉-合成", "target": "danlu", "action": "synthesis"})
	if _is_player_near(portal, interaction_distance + 20):
		actions.append({"key": "npc:portal:level", "text": "衍阵-传送", "target": "portal", "action": "level"})
	for companion_data: Dictionary in _get_interactable_companions():
		var hero_key := str(companion_data.get("hero_key", ""))
		var display_name := _get_hero_display_name(hero_key)
		actions.append({"key": "companion:%s:talk" % hero_key, "text": "%s-交谈" % display_name, "target": hero_key, "action": "talk_companion"})
		actions.append({"key": "companion:%s:switch" % hero_key, "text": "%s-切换" % display_name, "target": hero_key, "action": "switch_companion"})
	return actions

func _rebuild_mobile_interaction_buttons(actions: Array[Dictionary]) -> void:
	if _mobile_interaction_container == null or not is_instance_valid(_mobile_interaction_container):
		return
	if actions.is_empty():
		_hide_mobile_interaction_panel()
		return
	var copied_actions: Array[Dictionary] = _duplicate_mobile_interaction_actions(actions)
	if _mobile_interaction_container.visible and _mobile_interaction_container.get_child_count() > 0:
		if _mobile_interaction_tween != null and _mobile_interaction_tween.is_valid():
			_mobile_interaction_tween.kill()
		_mobile_interaction_tween = create_tween()
		_mobile_interaction_tween.tween_property(_mobile_interaction_container, "modulate:a", 0.0, MOBILE_INTERACTION_PANEL_FADE_DURATION)
		_mobile_interaction_tween.tween_callback(_populate_mobile_interaction_buttons.bind(copied_actions))
		_mobile_interaction_tween.tween_property(_mobile_interaction_container, "modulate:a", 1.0, MOBILE_INTERACTION_PANEL_FADE_DURATION)
		return
	_populate_mobile_interaction_buttons(copied_actions)
	_show_mobile_interaction_panel()

func _duplicate_mobile_interaction_actions(actions: Array[Dictionary]) -> Array[Dictionary]:
	var copied_actions: Array[Dictionary] = []
	for action: Dictionary in actions:
		copied_actions.append(action.duplicate(true))
	return copied_actions

func _populate_mobile_interaction_buttons(actions: Array[Dictionary]) -> void:
	if _mobile_interaction_container == null or not is_instance_valid(_mobile_interaction_container):
		return
	for child: Node in _mobile_interaction_container.get_children():
		child.queue_free()
	for action: Dictionary in actions:
		var button: Button = Button.new()
		button.text = str(action.get("text", ""))
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = MOBILE_INTERACTION_PANEL_BUTTON_SIZE
		button.theme = MOBILE_INTERACTION_BUTTON_THEME
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.pressed.connect(_on_mobile_interaction_pressed.bind(action.duplicate(true)))
		_mobile_interaction_container.add_child(button)

func _show_mobile_interaction_panel() -> void:
	if _mobile_interaction_container == null or not is_instance_valid(_mobile_interaction_container):
		return
	if _mobile_interaction_tween != null and _mobile_interaction_tween.is_valid():
		_mobile_interaction_tween.kill()
	_mobile_interaction_container.visible = true
	_mobile_interaction_container.modulate.a = 0.0
	_mobile_interaction_tween = create_tween()
	_mobile_interaction_tween.tween_property(_mobile_interaction_container, "modulate:a", 1.0, MOBILE_INTERACTION_PANEL_FADE_DURATION)

func _hide_mobile_interaction_panel() -> void:
	if _mobile_interaction_container == null or not is_instance_valid(_mobile_interaction_container):
		return
	if not _mobile_interaction_container.visible and _mobile_interaction_keys.is_empty():
		return
	_mobile_interaction_keys.clear()
	if _mobile_interaction_tween != null and _mobile_interaction_tween.is_valid():
		_mobile_interaction_tween.kill()
	_mobile_interaction_tween = create_tween()
	_mobile_interaction_tween.tween_property(_mobile_interaction_container, "modulate:a", 0.0, MOBILE_INTERACTION_PANEL_FADE_DURATION)
	_mobile_interaction_tween.tween_callback(func():
		if is_instance_valid(_mobile_interaction_container):
			_mobile_interaction_container.visible = false
			for child: Node in _mobile_interaction_container.get_children():
				child.queue_free()
	)

func _on_mobile_interaction_pressed(action: Dictionary) -> void:
	if not Global.is_mobile_input_mode() or _is_entry_shortcut_blocked():
		return
	defaultLayer.lock_setting_button()
	_hide_mobile_interaction_panel()
	var target := str(action.get("target", ""))
	match str(action.get("action", "")):
		"hero":
			_open_hero_layer()
		"cultivation":
			_open_cultivation_layer()
		"study":
			_open_study_layer()
		"shop":
			_open_shop_layer()
		"synthesis":
			_open_synthesis_layer()
		"level":
			_open_level_change_layer()
		"talk_npc":
			start_dialog_interaction(target)
		"talk_companion":
			_start_companion_dialog(target)
		"switch_companion":
			_switch_to_companion(target)
		_:
			defaultLayer.unlock_setting_button()

func animate_ui_element(ui_element: Control, ui_name: String, should_show: bool) -> void:
	if ui_element == null:
		return
	if not ui_states.has(ui_name):
		ui_states[ui_name] = false
	# 如果状态没有改变，直接返回
	if ui_states[ui_name] == should_show:
		return
	
	# 更新状态
	ui_states[ui_name] = should_show
	
	# 停止之前的动画
	if ui_tweens.has(ui_name) and ui_tweens[ui_name]:
		ui_tweens[ui_name].kill()
	
	# 创建新的动画
	ui_tweens[ui_name] = create_tween()
	
	if should_show:
		# 渐入动画
		ui_element.visible = true
		ui_element.modulate.a = 0.0
		ui_tweens[ui_name].tween_property(ui_element, "modulate:a", 1.0, 0.15)
	else:
		# 渐出动画
		ui_tweens[ui_name].tween_property(ui_element, "modulate:a", 0.0, 0.15)
		ui_tweens[ui_name].tween_callback(func(): ui_element.visible = false)

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	_update_companion_draw_orders()
	if Global.is_mobile_input_mode():
		_hide_town_action_tips()
		_update_companion_tips()
		_update_mobile_interaction_panel()
		return

	if player.global_position.distance_to(cystal.global_position) < interaction_distance + 10:
		animate_ui_element(cystalTips, "cystalTips", true)
		cystalTips.change_name("乾
		<侠士切换>")
		cystalTips.change_label1_text("切换侠士 [F]")
		cystalTips.change_function2_visible(true)
		cystalTips.change_label2_text("交谈 [G]")
	else:
		animate_ui_element(cystalTips, "cystalTips", false)
		
				
	if player.global_position.distance_to(levelUpMan.global_position) < interaction_distance - 5:
		animate_ui_element(levelUpManTips, "levelUpManTips", true)
		levelUpManTips.change_name("巽
		<修炼>")
		levelUpManTips.change_label1_text("修习 [F]")
		levelUpManTips.change_function2_visible(true)
		levelUpManTips.change_label2_text("交谈 [G]")
	else:
		animate_ui_element(levelUpManTips, "levelUpManTips", false)
	
				
	if player.global_position.distance_to(levelUpMan2.global_position) < interaction_distance - 5 and levelUpMan2.visible:
		animate_ui_element(levelUpMan2Tips, "levelUpMan2Tips", true)
		levelUpMan2Tips.change_name("坤
		<进阶>")
		levelUpMan2Tips.change_label1_text("进阶 [F]")
		levelUpMan2Tips.change_function2_visible(true)
		levelUpMan2Tips.change_label2_text("交谈 [G]")
	else:
		animate_ui_element(levelUpMan2Tips, "levelUpMan2Tips", false)
	
	if player.global_position.distance_to(bard.global_position) < interaction_distance + 5 and bard.visible:
		animate_ui_element(bardTips, "bardTips", true)
		bardTips.change_name("异国诗人
		<旅人>")
		bardTips.change_label1_text("交谈 [F]")
		bardTips.change_function2_visible(false)
	else:
		animate_ui_element(bardTips, "bardTips", false)

	if player.global_position.distance_to(merchant.global_position) < interaction_distance + 15 and merchant.visible:
		animate_ui_element(merchantTips, "merchantTips", true)
		merchantTips.change_name("坎
		<货摊>")
		merchantTips.change_label1_text("交易 [F]")
		merchantTips.change_function2_visible(true)
		merchantTips.change_label2_text("交谈 [G]")
	else:
		animate_ui_element(merchantTips, "merchantTips", false)
	
				
	if player.global_position.distance_to(danlu.global_position) < interaction_distance + 20 and danlu.visible:
		animate_ui_element(danluTips, "danluTips", true)
		danluTips.change_name("八卦炉
		<合成>")
		danluTips.change_label1_text("合成 [F]")
	else:
		animate_ui_element(danluTips, "danluTips", false)
				
	if player.global_position.distance_to(portal.global_position) < interaction_distance + 20:
		animate_ui_element(portalTips, "portalTips", true)
		portalTips.change_name("衍阵
		<关卡选择>")
		portalTips.change_label1_text("传送 [F]")
	else:
		animate_ui_element(portalTips, "portalTips", false)

	_update_companion_tips()
	_update_mobile_interaction_panel()
	
	if Input.is_action_just_pressed("interact"):
		press_interact()
		
	if Input.is_action_just_pressed("Interact2"):
		press_interact2()

func _hide_town_action_tips() -> void:
	animate_ui_element(cystalTips, "cystalTips", false)
	animate_ui_element(levelUpManTips, "levelUpManTips", false)
	animate_ui_element(levelUpMan2Tips, "levelUpMan2Tips", false)
	animate_ui_element(bardTips, "bardTips", false)
	animate_ui_element(merchantTips, "merchantTips", false)
	animate_ui_element(danluTips, "danluTips", false)
	animate_ui_element(portalTips, "portalTips", false)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	_update_companion_movement(delta)
		
# F交互
func press_interact():
	defaultLayer.lock_setting_button()
	var handled := false

	if player.global_position.distance_to(cystal.global_position) < interaction_distance:
		handled = true
		_open_hero_layer()
	
	if player.global_position.distance_to(merchant.global_position) < interaction_distance + 15 and merchant.visible:
		handled = true
		_open_shop_layer()
	
	if player.global_position.distance_to(portal.global_position) < interaction_distance + 20:
		handled = true
		_open_level_change_layer()

	if player.global_position.distance_to(levelUpMan.global_position) < interaction_distance - 5:
		handled = true
		_open_cultivation_layer()

	if player.global_position.distance_to(danlu.global_position) < interaction_distance + 20 and danlu.visible:
		handled = true
		_open_synthesis_layer()
		
		
	if player.global_position.distance_to(levelUpMan2.global_position) < interaction_distance - 5 and levelUpMan2.visible:
		handled = true
		_open_study_layer()

	if player.global_position.distance_to(bard.global_position) < interaction_distance + 5 and bard.visible:
		handled = true
		if not dialog_control.visible:
			start_dialog_interaction("bard")

	if not handled:
		var nearest_companion := _get_nearest_interactable_companion()
		if not nearest_companion.is_empty():
			_start_companion_dialog(str(nearest_companion.get("hero_key", "")))
			return
		defaultLayer.unlock_setting_button()


# G交互
func press_interact2():
	defaultLayer.lock_setting_button()
	var handled := false

	if _is_player_near(cystal, interaction_distance + 10):
		handled = true
		if not dialog_control.visible:
			start_dialog_interaction("qian")
	elif _is_player_near(levelUpMan, interaction_distance - 5):
		handled = true
		if not dialog_control.visible:
			start_dialog_interaction("xun")
	elif _is_player_near(levelUpMan2, interaction_distance - 5) and levelUpMan2.visible:
		handled = true
		if not dialog_control.visible:
			start_dialog_interaction("kun")
	elif _is_player_near(merchant, interaction_distance + 15) and merchant.visible:
		handled = true
		if not dialog_control.visible:
			start_dialog_interaction("kan")

	if handled:
		return

	var nearest_companion := _get_nearest_interactable_companion()
	if not nearest_companion.is_empty():
		_switch_to_companion(str(nearest_companion.get("hero_key", "")))
		return

	if not handled:
		defaultLayer.unlock_setting_button()
		
# H交互
func press_interact3():
	pass

func _is_player_near(target: Node2D, distance: float) -> bool:
	return is_instance_valid(player) and is_instance_valid(target) and player.global_position.distance_to(target.global_position) < distance

func start_dialog_interaction(npc_id: String) -> void:
	if dialog_control == null or dialog_control.visible:
		defaultLayer.unlock_setting_button()
		return
	var dialog_data: Array = TOWN_COMPANION_DIALOGUE.get_random_npc_dialog(npc_id)
	if dialog_data.is_empty():
		if tip != null and tip.has_method("start_animation"):
			tip.start_animation("暂无可用对话", 0.5)
		defaultLayer.unlock_setting_button()
		return

	if not dialog_control.is_inside_tree():
		add_child(dialog_control)
	
	PC.movement_disabled = true
	dialog_control.visible = true
	if dialog_control.has_method("start_dialog_from_data"):
		dialog_control.start_dialog_from_data(dialog_data)
	else:
		push_warning("Dialog control missing start_dialog_from_data; cannot start town npc dialog.")
		defaultLayer.unlock_setting_button()

func _update_companion_tips() -> void:
	if Global.is_mobile_input_mode():
		for companion_data: Dictionary in _town_companions:
			var mobile_tips_node: Control = companion_data.get("tips") as Control
			var mobile_state_key: String = str(companion_data.get("state_key", ""))
			animate_ui_element(mobile_tips_node, mobile_state_key, false)
		return
	var nearest_data := _get_nearest_interactable_companion()
	for companion_data: Dictionary in _town_companions:
		var companion_node: Variant = companion_data.get("node")
		var tips_node := companion_data.get("tips") as Control
		var state_key := str(companion_data.get("state_key", ""))
		var should_show: bool = (
			not nearest_data.is_empty()
			and nearest_data.get("node") == companion_node
			and not _is_entry_shortcut_blocked()
		)
		animate_ui_element(tips_node, state_key, should_show)

func _update_companion_draw_orders() -> void:
	for i in range(_town_companions.size()):
		var companion_data := _town_companions[i]
		_update_companion_draw_order(companion_data)
		_town_companions[i] = companion_data

func _update_companion_draw_order(companion_data: Dictionary, force: bool = false) -> void:
	if not is_instance_valid(player):
		return
	var companion_node := companion_data.get("node") as Node2D
	var lower_sprite := companion_data.get("lower_sprite") as AnimatedSprite2D
	var upper_sprite := companion_data.get("upper_sprite") as AnimatedSprite2D
	if not is_instance_valid(companion_node) or not is_instance_valid(lower_sprite) or not is_instance_valid(upper_sprite):
		return

	var companion_in_front := bool(companion_data.get("draw_front", false))
	var switch_offset_y := (COMPANION_LAYER_SWITCH_BODY_RATIO - 0.5) * COMPANION_REFERENCE_BODY_HEIGHT * absf(companion_node.global_scale.y)
	var y_diff := companion_node.global_position.y + switch_offset_y - player.global_position.y
	if force:
		companion_in_front = y_diff > 0.0
	elif companion_in_front:
		if y_diff < -COMPANION_LAYER_SWITCH_Y_EPSILON:
			companion_in_front = false
	else:
		if y_diff > COMPANION_LAYER_SWITCH_Y_EPSILON:
			companion_in_front = true
	companion_data["draw_front"] = companion_in_front

	if companion_in_front:
		upper_sprite.z_index = COMPANION_UPPER_Z_INDEX
		lower_sprite.z_index = COMPANION_UPPER_Z_INDEX
	else:
		upper_sprite.z_index = COMPANION_BEHIND_Z_INDEX
		lower_sprite.z_index = COMPANION_BEHIND_Z_INDEX

func _update_companion_movement(delta: float) -> void:
	for i in range(_town_companions.size()):
		var companion_data := _town_companions[i]
		var companion_node := companion_data.get("node") as CharacterBody2D
		if companion_node == null or not is_instance_valid(companion_node):
			continue
		if bool(companion_node.get_meta("companion_transitioning", false)):
			continue
		if player.global_position.distance_to(companion_node.global_position) <= COMPANION_STOP_NEAR_PLAYER_DISTANCE:
			_set_companion_idle(companion_data, true)
			_town_companions[i] = companion_data
			continue

		var move_timer := float(companion_data.get("move_timer", 0.0)) - delta
		companion_data["move_timer"] = move_timer
		var move_state := str(companion_data.get("move_state", "idle"))
		match move_state:
			"idle":
				if move_timer <= 0.0:
					_enter_companion_run(companion_data)
			"run":
				var move_direction := companion_data.get("move_direction", Vector2.ZERO) as Vector2
				if move_direction != Vector2.ZERO:
					companion_node.velocity = move_direction * COMPANION_MOVE_SPEED
					companion_node.move_and_slide()
					if companion_node.is_on_wall():
						_change_companion_direction(companion_data)
				if move_timer <= 0.0:
					_set_companion_idle(companion_data)
			_:
				_set_companion_idle(companion_data)
		_sync_companion_sprite_frames(companion_data)
		_town_companions[i] = companion_data

func _set_companion_idle(companion_data: Dictionary, keep_timer: bool = false) -> void:
	var companion_node := companion_data.get("node") as CharacterBody2D
	companion_data["move_state"] = "idle"
	companion_data["move_direction"] = Vector2.ZERO
	if not keep_timer:
		companion_data["move_timer"] = randf_range(COMPANION_IDLE_TIME_MIN, COMPANION_IDLE_TIME_MAX)
	if is_instance_valid(companion_node):
		companion_node.velocity = Vector2.ZERO
	_play_companion_animation(companion_data, "idle")

func _enter_companion_run(companion_data: Dictionary) -> void:
	companion_data["move_state"] = "run"
	companion_data["move_timer"] = randf_range(COMPANION_RUN_TIME_MIN, COMPANION_RUN_TIME_MAX)
	_change_companion_direction(companion_data)
	_play_companion_animation(companion_data, "run")

func _change_companion_direction(companion_data: Dictionary) -> void:
	var angle := randf_range(0.0, TAU)
	var move_direction := Vector2(cos(angle), sin(angle))
	companion_data["move_direction"] = move_direction
	if move_direction.x != 0.0:
		_set_companion_facing_left(companion_data, move_direction.x < 0.0)

func _play_companion_animation(companion_data: Dictionary, animation_name: String) -> void:
	for key in ["lower_sprite", "upper_sprite"]:
		var sprite := companion_data.get(key) as AnimatedSprite2D
		if is_instance_valid(sprite) and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
			if sprite.animation != StringName(animation_name):
				sprite.play(animation_name)
	_sync_companion_sprite_frames(companion_data)

func _sync_companion_sprite_frames(companion_data: Dictionary) -> void:
	var lower_sprite := companion_data.get("lower_sprite") as AnimatedSprite2D
	var upper_sprite := companion_data.get("upper_sprite") as AnimatedSprite2D
	if not is_instance_valid(lower_sprite) or not is_instance_valid(upper_sprite):
		return
	if upper_sprite.animation != lower_sprite.animation:
		upper_sprite.play(lower_sprite.animation)
	upper_sprite.frame = lower_sprite.frame
	upper_sprite.frame_progress = lower_sprite.frame_progress

func _set_companion_facing_left(companion_data: Dictionary, face_left: bool) -> void:
	for key in ["lower_sprite", "upper_sprite"]:
		var sprite := companion_data.get(key) as AnimatedSprite2D
		if is_instance_valid(sprite):
			sprite.flip_h = face_left

func _is_companion_facing_left(companion_data: Dictionary) -> bool:
	var lower_sprite := companion_data.get("lower_sprite") as AnimatedSprite2D
	if is_instance_valid(lower_sprite):
		return lower_sprite.flip_h
	var upper_sprite := companion_data.get("upper_sprite") as AnimatedSprite2D
	return is_instance_valid(upper_sprite) and upper_sprite.flip_h

func _get_nearest_interactable_companion() -> Dictionary:
	if not is_instance_valid(player):
		return {}
	if _is_entry_shortcut_blocked():
		return {}

	var nearest: Dictionary = {}
	var nearest_distance := INF
	for companion_data in _town_companions:
		var companion_node := companion_data.get("node") as Node2D
		if companion_node == null or not is_instance_valid(companion_node) or not companion_node.visible:
			continue
		if bool(companion_node.get_meta("companion_transitioning", false)):
			continue
		var distance := player.global_position.distance_to(companion_node.global_position)
		if distance <= COMPANION_INTERACTION_DISTANCE and distance < nearest_distance:
			nearest = companion_data
			nearest_distance = distance
	return nearest

func _get_interactable_companions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_instance_valid(player) or _is_entry_shortcut_blocked():
		return result
	for companion_data in _town_companions:
		var companion_node := companion_data.get("node") as Node2D
		if companion_node == null or not is_instance_valid(companion_node) or not companion_node.visible:
			continue
		if bool(companion_node.get_meta("companion_transitioning", false)):
			continue
		if player.global_position.distance_to(companion_node.global_position) <= COMPANION_INTERACTION_DISTANCE:
			result.append(companion_data)
	return result

func _start_companion_dialog(target_hero: String) -> void:
	if target_hero.is_empty() or dialog_control == null or dialog_control.visible:
		return
	var dialog_data: Array = TOWN_COMPANION_DIALOGUE.get_random_dialog(PC.player_name, target_hero)
	if dialog_data.is_empty():
		if tip != null and tip.has_method("start_animation"):
			tip.start_animation("暂无可用对话", 0.5)
		return

	PC.movement_disabled = true
	if not dialog_control.is_inside_tree():
		add_child(dialog_control)
	dialog_control.visible = true
	if dialog_control.has_method("start_dialog_from_data"):
		dialog_control.start_dialog_from_data(dialog_data)
	else:
		push_warning("Dialog control missing start_dialog_from_data; cannot start companion dialog.")

func _switch_to_companion(target_hero: String) -> void:
	if target_hero.is_empty() or not _is_hero_unlocked(target_hero):
		return
	if PC.player_name == target_hero:
		return

	var previous_hero := PC.player_name
	PC.player_name = target_hero
	_town_current_hero = target_hero
	player.change_hero(target_hero)
	_refresh_bag_character_display()
	Global.save_game()
	if defaultLayer != null:
		defaultLayer.unlock_setting_button()
	if tip != null and tip.has_method("start_animation"):
		tip.start_animation("已切换为 " + _get_hero_display_name(target_hero), 0.5)
	_replace_switched_companion(target_hero, previous_hero)

func _replace_switched_companion(target_hero: String, replacement_hero: String) -> void:
	if replacement_hero.is_empty() or replacement_hero == target_hero or not _is_hero_unlocked(replacement_hero):
		return
	var replace_index := _find_town_companion_index(target_hero)
	if replace_index < 0:
		_refresh_town_companions(true)
		return

	var old_data := _town_companions[replace_index]
	var old_node := old_data.get("node") as CharacterBody2D
	if old_node == null or not is_instance_valid(old_node):
		return

	old_node.set_meta("companion_transitioning", true)
	var old_tips := old_data.get("tips") as Control
	if old_tips != null and is_instance_valid(old_tips):
		old_tips.visible = false
		old_tips.modulate.a = 0.0

	var spawn_position := old_node.global_position
	var face_left := _is_companion_facing_left(old_data)
	var old_state_key := str(old_data.get("state_key", ""))
	if not old_state_key.is_empty():
		ui_states.erase(old_state_key)

	var fade_out := create_tween()
	fade_out.tween_property(old_node, "modulate:a", 0.0, COMPANION_FADE_DURATION)
	fade_out.tween_callback(func():
		if is_instance_valid(old_node):
			old_node.queue_free()
		var new_data := _spawn_town_companion_at(replacement_hero, spawn_position, face_left, replace_index)
		var new_node := new_data.get("node") as CharacterBody2D
		if is_instance_valid(new_node):
			new_node.modulate.a = 0.0
			var fade_in := create_tween()
			fade_in.tween_property(new_node, "modulate:a", 1.0, COMPANION_FADE_DURATION)
	)

func _find_town_companion_index(hero_key: String) -> int:
	for i in range(_town_companions.size()):
		if str(_town_companions[i].get("hero_key", "")) == hero_key:
			return i
	return -1

func _on_hero_layer_hero_changed(_hero_key: String) -> void:
	_town_current_hero = PC.player_name
	_refresh_town_companions(true)

func _refresh_bag_character_display() -> void:
	var bag_layer := get_node_or_null("BagLayer")
	if bag_layer == null:
		return
	if bag_layer.has_method("refresh_character_display"):
		bag_layer.refresh_character_display()
	elif bag_layer.has_method("refresh_bag"):
		bag_layer.refresh_bag()

func _on_town_dialog_completed() -> void:
	if defaultLayer != null:
		defaultLayer.unlock_setting_button()


func _on_exit_pressed() -> void:
	PC.movement_disabled = false
	defaultLayer.visible = true
	defaultLayer.unlock_setting_button()
	defaultLayer.close_setting_panel()
	if defaultLayer.has_method("refresh_entry_buttons_enabled"):
		defaultLayer.refresh_entry_buttons_enabled()
	
	var exit_tween = create_tween()
	exit_tween.set_parallel(true)
	
	if dark_overlay and dark_overlay.visible:
		exit_tween.tween_property(dark_overlay, "modulate:a", 0.0, 0.2)
		exit_tween.tween_callback(func():
			dark_overlay.visible = false
			dark_overlay.modulate.a = 0.0
		).set_delay(0.2)
	
	# 渐出关卡选择界面
	if is_instance_valid(levelChangeLayer) and levelChangeLayer.visible:
		for child in levelChangeLayer.get_children():
			if child.has_method("set_modulate"):
				exit_tween.tween_property(child, "modulate:a", 0.0, 0.2)
		exit_tween.tween_callback(func():
			if is_instance_valid(levelChangeLayer):
				levelChangeLayer.visible = false
				Global.unlock_camera_zoom(CAMERA_ZOOM_LOCK_LEVEL_SELECT)
				# 重置子节点透明度
				for child in levelChangeLayer.get_children():
					if child.has_method("set_modulate"):
						child.modulate.a = 1.0
		).set_delay(0.2)
	
	# 渐出修炼界面
	if is_instance_valid(cultivationLayer) and cultivationLayer.visible:
		for child in cultivationLayer.get_children():
			if child.has_method("set_modulate"):
				exit_tween.tween_property(child, "modulate:a", 0.0, 0.1)
		exit_tween.tween_callback(func():
			if is_instance_valid(cultivationLayer):
				cultivationLayer.visible = false
				Global.unlock_camera_zoom(CAMERA_ZOOM_LOCK_CULTIVATION)
				# 重置子节点透明度
				for child in cultivationLayer.get_children():
					if child.has_method("set_modulate"):
						child.modulate.a = 1.0
		).set_delay(0.1)

	# 渐出合成界面
	if is_instance_valid(synthesisLayer) and synthesisLayer.visible:
		# 退出合成界面时，重置合成状态标志
		Global.in_synthesis = false
		Global.unlock_camera_zoom("synthesis")
		for child in synthesisLayer.get_children():
			if child.has_method("set_modulate"):
				exit_tween.tween_property(child, "modulate:a", 0.0, 0.1)
		exit_tween.tween_callback(func():
			if is_instance_valid(synthesisLayer):
				synthesisLayer.visible = false
				# 重置子节点透明度
				for child in synthesisLayer.get_children():
					if child.has_method("set_modulate"):
						child.modulate.a = 1.0
		).set_delay(0.1)

	if is_instance_valid(heroLayer) and heroLayer.visible:
		for child in heroLayer.get_children():
			if child.has_method("set_modulate"):
				exit_tween.tween_property(child, "modulate:a", 0.0, 0.2)
		exit_tween.tween_callback(func():
			if is_instance_valid(heroLayer):
				heroLayer.visible = false
				Global.unlock_camera_zoom(CAMERA_ZOOM_LOCK_HERO)
				for child in heroLayer.get_children():
					if child.has_method("set_modulate"):
						child.modulate.a = 1.0
		).set_delay(0.2)
	
	if is_instance_valid(shopLayer) and shopLayer.visible:
		if shopLayer.has_method("prepare_for_close"):
			shopLayer.prepare_for_close()
		for child in shopLayer.get_children():
			if child.has_method("set_modulate"):
				exit_tween.tween_property(child, "modulate:a", 0.0, 0.2)
		exit_tween.tween_callback(func():
			if is_instance_valid(shopLayer):
				shopLayer.visible = false
				Global.unlock_camera_zoom(CAMERA_ZOOM_LOCK_SHOP)
				for child in shopLayer.get_children():
					if child.has_method("set_modulate"):
						child.modulate.a = 1.0
		).set_delay(0.2)

	if is_instance_valid(achievementLayerInstance) and achievementLayerInstance.visible:
		var achievement_panel := achievementLayerInstance.get_node_or_null("Panel")
		if achievement_panel and achievement_panel.has_method("set_modulate"):
			exit_tween.tween_property(achievement_panel, "modulate:a", 0.0, 0.2)
		exit_tween.tween_callback(func():
			if is_instance_valid(achievementLayerInstance):
				if achievementLayerInstance.has_method("close_layer"):
					achievementLayerInstance.close_layer(false)
				else:
					achievementLayerInstance.visible = false
				Global.unlock_camera_zoom(CAMERA_ZOOM_LOCK_ACHIEVEMENT)
				var panel := achievementLayerInstance.get_node_or_null("Panel")
				if panel and panel.has_method("set_modulate"):
					panel.modulate.a = 1.0
				if defaultLayer.has_method("set_achievement_layer_open"):
					defaultLayer.set_achievement_layer_open(false)
		).set_delay(0.2)

	# 渐出修习界面
	if is_instance_valid(studyLayer) and studyLayer.visible:
		for child in studyLayer.get_children():
			if child.has_method("set_modulate"):
				exit_tween.tween_property(child, "modulate:a", 0.0, 0.2)
		exit_tween.tween_callback(func():
			if is_instance_valid(studyLayer):
				studyLayer.visible = false
				Global.unlock_camera_zoom(CAMERA_ZOOM_LOCK_STUDY)
				for child in studyLayer.get_children():
					if child.has_method("set_modulate"):
						child.modulate.a = 1.0
		).set_delay(0.2)

	# jcLayer 由自身的 _close_layer 处理渐出，此处仅需确保它存在时调用
	if is_instance_valid(jcLayerInstance) and jcLayerInstance.visible:
		if jcLayerInstance.has_method("_close_layer"):
			jcLayerInstance._close_layer()
	if defaultLayer.has_method("refresh_entry_buttons_enabled"):
		exit_tween.tween_callback(_finish_town_panel_close).set_delay(0.25)

func _finish_town_panel_close() -> void:
	_set_town_panel_open(false)
	if defaultLayer.has_method("refresh_entry_buttons_enabled"):
		defaultLayer.refresh_entry_buttons_enabled()
	
var poetry_choice_layer_scene = preload("res://Scenes/town/poetry_choice_layer.tscn")
var current_poetry_layer = null

func _enter_stage(stage_scene_path: String, stage_id: String) -> void:
	if stage_scene_path.is_empty():
		if tip != null and tip.has_method("start_animation"):
			tip.start_animation("该关卡场景尚未配置", 0.5)
		if has_node("Buzzer"):
			$Buzzer.play()
		return
		
	var diff = Global.validate_stage_difficulty_id(Global.selected_stage_difficulty)
	if diff == Global.STAGE_DIFFICULTY_POETRY:
		if levelChangeLayer != null:
			if levelChangeLayer.has_method("suppress_stage_tooltips"):
				levelChangeLayer.suppress_stage_tooltips(true)
			elif levelChangeLayer.has_method("reset_stage_tooltip_state"):
				levelChangeLayer.reset_stage_tooltip_state()
		if not is_instance_valid(current_poetry_layer):
			current_poetry_layer = poetry_choice_layer_scene.instantiate()
			add_child(current_poetry_layer)
		if not current_poetry_layer.has_method("show_layer"):
			push_error("PoetryChoiceLayer missing show_layer; script=%s" % [current_poetry_layer.get_script()])
			if tip != null and tip.has_method("start_animation"):
				tip.start_animation("诗想备战界面加载失败", 0.5)
			return
		current_poetry_layer.show_layer(stage_scene_path, stage_id, self )
		return
		
	_do_enter_stage(stage_scene_path, stage_id, diff, false)

func _do_enter_stage(stage_scene_path: String, stage_id: String, diff: String, skip_reset: bool = false) -> void:
	Global.current_stage_id = stage_id
	Global.current_stage_difficulty = diff
	if diff == Global.STAGE_DIFFICULTY_CORE:
		Global.current_core_depth = Global.clamp_core_depth(Global.selected_core_depth)
	else:
		Global.current_core_depth = Global.CORE_DEPTH_MIN
	Global.reset_camera_zoom_locks()
	Global.in_synthesis = false
	Global.in_town = false
	PC.movement_disabled = false
	if not skip_reset:
		PC.reset_player_attr()
	SceneChange.change_scene(stage_scene_path, true)

func _on_stage_1_pressed() -> void:
	_enter_stage(battle_scene, "peach_grove")
	
func _on_stage_2_pressed() -> void:
	_enter_stage(battle_scene_stage2, "ruin")
	
func _on_stage_3_pressed() -> void:
	_enter_stage(battle_scene_stage3, "cave")

func _on_stage_4_pressed() -> void:
	_enter_stage(battle_scene_stage4, "forest")
	
func refresh_point() -> void:
	point_label.text = str(Global.total_points)

# 修炼配置数据
var cultivation_configs = {
	"poxu": {"name": "破虚", "type": "atk", "level_var": "cultivation_poxu_level", "max_level_var": "cultivation_poxu_level_max"},
	"xuanyuan": {"name": "玄元", "type": "hp", "level_var": "cultivation_xuanyuan_level", "max_level_var": "cultivation_xuanyuan_level_max"},
	"liuguang": {"name": "流光", "type": "atk_speed", "level_var": "cultivation_liuguang_level", "max_level_var": "cultivation_liuguang_level_max"},
	"hualing": {"name": "化灵", "type": "spirit_gain", "level_var": "cultivation_hualing_level", "max_level_var": "cultivation_hualing_level_max"},
	"fengrui": {"name": "锋锐", "type": "crit_chance", "level_var": "cultivation_fengrui_level", "max_level_var": "cultivation_fengrui_level_max"},
	"huti": {"name": "护体", "type": "damage_reduction", "level_var": "cultivation_huti_level", "max_level_var": "cultivation_huti_level_max"},
	"zhuifeng": {"name": "追风", "type": "move_speed", "level_var": "cultivation_zhuifeng_level", "max_level_var": "cultivation_zhuifeng_level_max"},
	"liejin": {"name": "烈劲", "type": "crit_damage", "level_var": "cultivation_liejin_level", "max_level_var": "cultivation_liejin_level_max"}
}

func _on_cme(cultivation_key: String) -> void:
	var config = cultivation_configs[cultivation_key]
	var current_level = Global.get(config["level_var"])
	var max_level = Global.get(config["max_level_var"])
	var next_level = current_level + 1
	var next_level_exp = 0
	if cultivation_key == "poxu" or cultivation_key == "xuanyuan" or cultivation_key == "hualing" or cultivation_key == "liejin":
		next_level_exp = CL.get_cultivation_exp_for_level_normal(current_level)
	else:
		next_level_exp = CL.get_cultivation_exp_for_level_high(current_level)
	var current_bonus = CL.get_cultivation_bonus_text(config["type"], current_level)
	var next_bonus = CL.get_cultivation_bonus_text(config["type"], next_level)
	
	# 判断是否已达到最高等级
	if current_level >= max_level:
		cultivation_msg.text = "[font_size=40]" + config["name"] + "  LV " + str(current_level) + " / " + str(max_level) + "[/font_size]\n\n当前  " + current_bonus + "\n\n[color=gold]已达到最高等级[/color]"
	else:
		cultivation_msg.text = "[font_size=40]" + config["name"] + "  LV " + str(current_level) + " / " + str(max_level) + "[/font_size]\n\n当前  " + current_bonus + "\n下一级  " + next_bonus + "\n修炼消耗  " + str(next_level_exp) + " 真气\n\n再次点击即可修炼"
	cultivation_msg.visible = true

func _on_cmex(_cultivation_key: String) -> void:
	cultivation_msg.visible = false

func _on_cmp(cultivation_key: String) -> void:
	var config = cultivation_configs[cultivation_key]
	var current_level = Global.get(config["level_var"])
	var max_level = Global.get(config["max_level_var"])
	
	# 检查是否已达到最高等级
	if current_level >= max_level:
		tip.start_animation(config["name"] + "已达到最高等级！", 0.5)
		$Buzzer.play()
		return
	
	var next_level_exp = 0
	if cultivation_key == "poxu" or cultivation_key == "xuanyuan" or cultivation_key == "hualing" or cultivation_key == "liejin":
		next_level_exp = CL.get_cultivation_exp_for_level_normal(current_level)
	else:
		next_level_exp = CL.get_cultivation_exp_for_level_high(current_level)
	
	if Global.total_points >= next_level_exp:
		Global.set(config["level_var"], current_level + 1)
		Global.total_points -= next_level_exp
		
		$LevelUP.play()
		
		tip.start_animation(config["name"] + "修炼成功！当前等级：" + str(Global.get(config["level_var"])) + " / " + str(max_level), 0.5)

		AchievementManager.scan_meta_progress(false)
		Global.save_game()
		refresh_point()
		
		if cultivation_msg.visible:
			_on_cme(cultivation_key)
	else:
		tip.start_animation("真气不足！需要 " + str(next_level_exp) + " 真气，当前只有 " + str(Global.total_points) + " 真气", 0.5)
		$Buzzer.play()

func _on_poxu_mouse_entered() -> void:
	_on_cme("poxu")

func _on_poxu_mouse_exited() -> void:
	_on_cmex("poxu")

func _on_poxu_pressed() -> void:
	_on_cmp("poxu")

func _on_xuanyuan_mouse_entered() -> void:
	_on_cme("xuanyuan")

func _on_xuanyuan_mouse_exited() -> void:
	_on_cmex("xuanyuan")

func _on_xuanyuan_pressed() -> void:
	_on_cmp("xuanyuan")

func _on_liuguang_mouse_entered() -> void:
	_on_cme("liuguang")

func _on_liuguang_mouse_exited() -> void:
	_on_cmex("liuguang")

func _on_liuguang_pressed() -> void:
	_on_cmp("liuguang")

func _on_hualing_mouse_entered() -> void:
	_on_cme("hualing")

func _on_hualing_mouse_exited() -> void:
	_on_cmex("hualing")

func _on_hualing_pressed() -> void:
	_on_cmp("hualing")

func _on_fengrui_mouse_entered() -> void:
	_on_cme("fengrui")

func _on_fengrui_mouse_exited() -> void:
	_on_cmex("fengrui")

func _on_fengrui_pressed() -> void:
	_on_cmp("fengrui")

func _on_huti_mouse_entered() -> void:
	_on_cme("huti")

func _on_huti_mouse_exited() -> void:
	_on_cmex("huti")

func _on_huti_pressed() -> void:
	_on_cmp("huti")

func _on_zhuifeng_mouse_entered() -> void:
	_on_cme("zhuifeng")

func _on_zhuifeng_mouse_exited() -> void:
	_on_cmex("zhuifeng")

func _on_zhuifeng_pressed() -> void:
	_on_cmp("zhuifeng")

func _on_liejin_mouse_entered() -> void:
	_on_cme("liejin")

func _on_liejin_mouse_exited() -> void:
	_on_cmex("liejin")

func _on_liejin_pressed() -> void:
	_on_cmp("liejin")

# ============== 游戏结果 ==============
func show_game_over() -> void:
	PC.is_game_over = true
	EmblemManager.clear_all_emblems()
	DpsManager.stop_dps_counter()
	
	if tip != null and tip.has_method("start_animation"):
		tip.start_animation("您在城镇中力竭倒下，已被重新救起", 2.0)
		
	# 在城镇中意外死亡时，自动回复满血并重置状态，防止卡死
	PC.reset_player_attr()
	PC.is_game_over = false
	if is_instance_valid(player):
		player.stop_all_skill_cooldowns()
		if player.has_method("revive"):
			player.revive()
		elif player.has_node("Animator"):
			var animator = player.get_node("Animator")
			if animator.has_animation("idle"):
				animator.play("idle")
		player.velocity = Vector2.ZERO
