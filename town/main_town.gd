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
var dialog_file_to_start: String = "res://AssetBundle/Dialog/test_dialog.txt"
var qian_dialog: String = "res://AssetBundle/Dialog/qian_dialog.txt"
var bard_dialog: String = "res://AssetBundle/Dialog/bard_dialog.txt"

var transition_tween: Tween
# UI动画相关变量
var ui_tweens: Dictionary = {}
var ui_states: Dictionary = {}

var player: CharacterBody2D
const SHOP_LAYER_SCENE := preload("res://Scenes/town/shop_layer.tscn")
const JC_LAYER_SCENE := preload("res://Scenes/town/jc_layer.tscn")
const ACHIEVEMENT_LAYER_SCENE := preload("res://Scenes/town/achievement‌_layer.tscn")
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


func _ready() -> void:
	Global.reset_game_speed()
	# 设置音效使用SFX总线
	setup_audio_buses()
	player = $Player
	Global.load_game()
	Global.reset_camera_zoom_locks()
	Global.in_synthesis = false
	
	# 重置玩家属性
	PC.reset_player_attr()
	
	Global.in_town = true
	player.change_hero(PC.player_name)
	
	# 功能解锁检查
	_apply_feature_unlocks()
	
	# 为NPC添加脚底阴影
	_setup_npc_shadows()
	
	# 城镇内不应用关卡的体型缩小(0.9)
	player.scale = Vector2(1.2, 1.2)
	
	defaultLayer.unlock_setting_button()
	
	# 播放城镇BGM和环境音
	Global.emit_signal("stage_bgm", "town")

	# 随机生成小动物
	_spawn_animals()

	# 按顺序检查并触发教程
	_check_and_trigger_tutorials()

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
			_create_npc_shadow(merchant)
	
	# 坤(study_tree)：通关ruin后解锁
	var levelUpMan2_unlocked = Global.is_stage_cleared("ruin")
	if levelUpMan2:
		levelUpMan2.visible = levelUpMan2_unlocked
		if levelUpMan2_unlocked:
			_create_npc_shadow(levelUpMan2)
	
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
## 阴影需在脚底下方，使用show_behind_parent确保绘制在NPC后面
func _create_npc_shadow(npc: AnimatedSprite2D, offset_y: float = 21.0) -> void:
	if npc.has_node("Shadow"):
		return
	var shadow = CharacterEffects.create_shadow(npc, 40.0, 14.0, offset_y)
	shadow.z_index = 0
	shadow.z_as_relative = true
	shadow.show_behind_parent = true

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

	# 初始化 JC 教程层
	_ensure_jc_layer()

	Global.emit_signal("reset_camera")
	Global.connect("press_f", Callable(self , "press_interact"))
	Global.connect("press_g", Callable(self , "press_interact2"))
	Global.connect("press_h", Callable(self , "press_interact3"))
	heroLayer.exit_button.pressed.connect(_on_exit_pressed)
	_ensure_shop_layer()
	_ensure_achievement_layer()
	if defaultLayer.has_signal("achievement_pressed") and not defaultLayer.achievement_pressed.is_connected(_on_achievement_button_pressed):
		defaultLayer.achievement_pressed.connect(_on_achievement_button_pressed)
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

func animate_ui_element(ui_element: Control, ui_name: String, should_show: bool) -> void:
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

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return

	if player.global_position.distance_to(cystal.global_position) < interaction_distance + 10:
		animate_ui_element(cystalTips, "cystalTips", true)
		levelUpManTips.change_name("乾
		<侠士切换>")
		cystalTips.change_label1_text("切换侠士 [F]")
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
		levelUpMan2Tips.change_name("震
		<进阶>")
		levelUpMan2Tips.change_label1_text("进阶 [F]")
		levelUpMan2Tips.change_function2_visible(true)
		levelUpMan2Tips.change_label2_text("交谈 [G]")
	else:
		animate_ui_element(levelUpMan2Tips, "levelUpMan2Tips", false)
	
	if player.global_position.distance_to(bard.global_position) < interaction_distance + 5 and bard.visible:
		animate_ui_element(bardTips, "bardTips", true)
		bardTips.change_name("异国的诗人
		<旅人>")
		bardTips.change_label1_text("交谈 [F]")
	else:
		animate_ui_element(bardTips, "bardTips", false)

	if player.global_position.distance_to(merchant.global_position) < interaction_distance + 15 and merchant.visible:
		animate_ui_element(merchantTips, "merchantTips", true)
		merchantTips.change_name("坎
		<货摊>")
		merchantTips.change_label1_text("交易 [F]")
	else:
		animate_ui_element(merchantTips, "merchantTips", false)
	
				
	if player.global_position.distance_to(danlu.global_position) < interaction_distance + 20 and danlu.visible:
		animate_ui_element(danluTips, "danluTips", true)
		danluTips.change_name("八卦炉
		<合成>")
		danluTips.change_label1_text("合成 [F]")
		danluTips.change_function2_visible(true)
		danluTips.change_label2_text("交谈 [G]")
	else:
		animate_ui_element(danluTips, "danluTips", false)
				
	if player.global_position.distance_to(portal.global_position) < interaction_distance + 20:
		animate_ui_element(portalTips, "portalTips", true)
		portalTips.change_name("衍阵
		<关卡选择>")
		portalTips.change_label1_text("传送 [F]")
	else:
		animate_ui_element(portalTips, "portalTips", false)
	
	if Input.is_action_just_pressed("interact"):
		press_interact()
		
	if Input.is_action_just_pressed("Interact2"):
		press_interact2()
		
# F交互
func press_interact():
	defaultLayer.lock_setting_button()
	if player.global_position.distance_to(cystal.global_position) < interaction_distance:
		PC.movement_disabled = true
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
	
	if player.global_position.distance_to(merchant.global_position) < interaction_distance + 15 and merchant.visible:
		_open_shop_layer()
	
	if player.global_position.distance_to(portal.global_position) < interaction_distance + 20:
		PC.movement_disabled = true
		defaultLayer.visible = false
		Global.lock_camera_zoom(CAMERA_ZOOM_LOCK_LEVEL_SELECT)
		if dark_overlay:
			if ui_tweens.has("dark_overlay") and ui_tweens["dark_overlay"]:
				ui_tweens["dark_overlay"].kill()
			
			ui_tweens["dark_overlay"] = create_tween()
			dark_overlay.visible = true
			dark_overlay.modulate.a = 0.0
			ui_tweens["dark_overlay"].tween_property(dark_overlay, "modulate:a", 1.0, 0.15)
		
		# 渐进显示关卡选择界面
		if ui_tweens.has("levelChangeLayer") and ui_tweens["levelChangeLayer"]:
			ui_tweens["levelChangeLayer"].kill()
		
		ui_tweens["levelChangeLayer"] = create_tween()
		ui_tweens["levelChangeLayer"].set_parallel(true)
		if levelChangeLayer != null and levelChangeLayer.has_method("prepare_for_open"):
			levelChangeLayer.prepare_for_open()
		levelChangeLayer.visible = true
		
		# 对CanvasLayer的所有子节点进行动画
		for child in levelChangeLayer.get_children():
			if child.has_method("set_modulate"):
				child.modulate.a = 0.0
				ui_tweens["levelChangeLayer"].tween_property(child, "modulate:a", 1.0, 0.15).set_delay(0.15)

	if player.global_position.distance_to(levelUpMan.global_position) < interaction_distance - 5:
		PC.movement_disabled = true
		Global.lock_camera_zoom(CAMERA_ZOOM_LOCK_CULTIVATION)
		
		if dark_overlay:
			if ui_tweens.has("dark_overlay") and ui_tweens["dark_overlay"]:
				ui_tweens["dark_overlay"].kill()
			
			ui_tweens["dark_overlay"] = create_tween()
			dark_overlay.visible = true
			dark_overlay.modulate.a = 0.0
			ui_tweens["dark_overlay"].tween_property(dark_overlay, "modulate:a", 1.0, 0.15)
			
		refresh_point()
		
		# 渐进显示修炼界面
		if ui_tweens.has("cultivationLayer") and ui_tweens["cultivationLayer"]:
			ui_tweens["cultivationLayer"].kill()
		
		ui_tweens["cultivationLayer"] = create_tween()
		ui_tweens["cultivationLayer"].set_parallel(true)
		cultivationLayer.visible = true
		
		# 对CanvasLayer的所有子节点进行动画
		for child in cultivationLayer.get_children():
			if child.has_method("set_modulate"):
				child.modulate.a = 0.0
				ui_tweens["cultivationLayer"].tween_property(child, "modulate:a", 1.0, 0.15).set_delay(0.15)

	if player.global_position.distance_to(danlu.global_position) < interaction_distance + 20 and danlu.visible:
		PC.movement_disabled = true
		Global.lock_camera_zoom("synthesis")
		
		if dark_overlay:
			if ui_tweens.has("dark_overlay") and ui_tweens["dark_overlay"]:
				ui_tweens["dark_overlay"].kill()
			
			ui_tweens["dark_overlay"] = create_tween()
			dark_overlay.visible = true
			dark_overlay.modulate.a = 0.0
			ui_tweens["dark_overlay"].tween_property(dark_overlay, "modulate:a", 1.0, 0.15)
		
		# 渐进显示合成界面
		if ui_tweens.has("synthesisLayer") and ui_tweens["synthesisLayer"]:
			ui_tweens["synthesisLayer"].kill()
		
		ui_tweens["synthesisLayer"] = create_tween()
		ui_tweens["synthesisLayer"].set_parallel(true)
		synthesisLayer.visible = true
		
		# 对CanvasLayer的所有子节点进行动画
		for child in synthesisLayer.get_children():
			if child.has_method("set_modulate"):
				child.modulate.a = 0.0
				ui_tweens["synthesisLayer"].tween_property(child, "modulate:a", 1.0, 0.15).set_delay(0.15)
				
		# 进入合成页面，不允许标滚轮缩放
		Global.in_synthesis = true
		
		
	if player.global_position.distance_to(levelUpMan2.global_position) < interaction_distance - 5 and levelUpMan2.visible:
		PC.movement_disabled = true
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
		
		# 对CanvasLayer的所有子节点进行动画
		for child in studyLayer.get_children():
			if child.has_method("set_modulate"):
				child.modulate.a = 0.0
				ui_tweens["studyLayer"].tween_property(child, "modulate:a", 1.0, 0.15).set_delay(0.15)

	if player.global_position.distance_to(bard.global_position) < interaction_distance + 5 and bard.visible:
		if not dialog_control.visible:
			start_dialog_interaction("bard")


# G交互
func press_interact2():
	defaultLayer.lock_setting_button()
	if player.global_position.distance_to(levelUpMan.global_position) < interaction_distance:
		if not dialog_control.visible:
			start_dialog_interaction("qian")
		
# H交互
func press_interact3():
	pass


func start_dialog_interaction(npc_id: String) -> void:
	PC.movement_disabled = true
	if not dialog_control.is_inside_tree():
		add_child(dialog_control)
	
	# 确保 dialog_control 可见
	dialog_control.visible = true

	if npc_id == "qian":
		Global.start_dialog.emit(qian_dialog)
	elif npc_id == "bard":
		Global.start_dialog.emit(bard_dialog)


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
		exit_tween.tween_callback(Callable(defaultLayer, "refresh_entry_buttons_enabled")).set_delay(0.25)
	
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
