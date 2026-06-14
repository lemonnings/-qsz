extends CanvasLayer

@export var continue_button: Button
@export var setting_button: Button
@export var exit_button: Button

@export var tips_panel: Panel
@export var ok_button: Button
@export var return_button: Button

var main_panel: Panel
var setting_layer_ref: Panel # 由 battle_canvas_layer 传入

const FADE_DURATION: float = 0.15

func _ready() -> void:
	main_panel = continue_button.get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	continue_button.pressed.connect(_on_continue_pressed)
	setting_button.pressed.connect(_on_setting_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	ok_button.pressed.connect(_on_ok_pressed)
	return_button.pressed.connect(_on_return_pressed)
	
	visible = false
	tips_panel.visible = false

## 由 battle_canvas_layer 调用，传入设定面板引用并连接其关闭按钮
func setup(p_setting_layer: Panel) -> void:
	setting_layer_ref = p_setting_layer
	setting_layer_ref.process_mode = Node.PROCESS_MODE_ALWAYS
	var exit_btn = p_setting_layer.get_node_or_null("Exit2")
	if exit_btn:
		exit_btn.pressed.connect(_close_setting)
	# 初始化设定面板UI控件的信号连接
	_setup_settings_ui(p_setting_layer)


## 初始化设定UI控件，连接信号到 SettingsManager
func _setup_settings_ui(panel: Panel) -> void:
	# 声音设置
	var main_volume = panel.get_node_or_null("shengyin2/MainVolume") as HSlider
	var bgm_volume = panel.get_node_or_null("shengyin2/BGMVolume") as HSlider
	var se_volume = panel.get_node_or_null("shengyin2/SEVolume") as HSlider
	var bg_volume = panel.get_node_or_null("shengyin2/BGVolume") as HSlider

	if main_volume:
		main_volume.min_value = 0.0
		main_volume.max_value = 1.0
		main_volume.step = 0.01
		main_volume.value = Global.audio_manager.get_master_volume()
		main_volume.value_changed.connect(func(v): Global.audio_manager.set_master_volume(v); Global.save_game())
	if bgm_volume:
		bgm_volume.min_value = 0.0
		bgm_volume.max_value = 1.0
		bgm_volume.step = 0.01
		bgm_volume.value = Global.audio_manager.get_bgm_volume()
		bgm_volume.value_changed.connect(func(v): Global.audio_manager.set_bgm_volume(v); Global.save_game())
	if se_volume:
		se_volume.min_value = 0.0
		se_volume.max_value = 1.0
		se_volume.step = 0.01
		se_volume.value = Global.audio_manager.get_sfx_volume()
		se_volume.value_changed.connect(func(v): Global.audio_manager.set_sfx_volume(v); Global.save_game())
	if bg_volume:
		bg_volume.min_value = 0.0
		bg_volume.max_value = 1.0
		bg_volume.step = 0.01
		bg_volume.value = Global.audio_manager.get_bg_volume()
		bg_volume.value_changed.connect(func(v): Global.audio_manager.set_bg_volume(v); Global.save_game())

	# 画面设置
	var screen_resolution = panel.get_node_or_null("huamian2/ScreenResolution") as OptionButton
	var full_screen = panel.get_node_or_null("huamian2/FullScreen") as CheckButton
	var vignetting = panel.get_node_or_null("huamian2/Vignetting") as CheckButton
	var noborder = panel.get_node_or_null("huamian2/Noborder") as CheckButton

	if screen_resolution:
		screen_resolution.selected = Global.settings_manager.get_current_resolution_index()
		screen_resolution.item_selected.connect(func(idx): Global.settings_manager.set_resolution(idx); Global.save_game())
	if full_screen:
		full_screen.button_pressed = Global.settings_manager.is_fullscreen_enabled()
		full_screen.toggled.connect(func(p): Global.settings_manager.set_fullscreen(p); Global.save_game())
	if vignetting:
		vignetting.button_pressed = Global.settings_manager.is_vignetting_enabled()
		vignetting.toggled.connect(func(p): Global.settings_manager.set_vignetting(p); Global.save_game())
	if noborder:
		noborder.button_pressed = Global.settings_manager.is_noborder_enabled()
		noborder.toggled.connect(func(p): Global.settings_manager.set_noborder(p); Global.save_game())

	# 游戏设置
	var particle = panel.get_node_or_null("youxi/Particle") as CheckButton
	var damage_show = panel.get_node_or_null("youxi/DamageShow") as CheckButton
	var damage_type_item = panel.get_node_or_null("youxi/DamageTypeItem") as OptionButton
	var moretip = panel.get_node_or_null("youxi/moretip") as CheckButton
	var time_slow_button = panel.get_node_or_null("youxi/TimeSlow") as CheckButton
	var super_test_button = panel.get_node_or_null("youxi/SuperTest") as CheckButton

	if particle:
		particle.set_pressed_no_signal(Global.settings_manager.is_particle_enabled())
		particle.toggled.connect(func(p): Global.settings_manager.set_particle(p); Global.save_game())
	if moretip:
		moretip.set_pressed_no_signal(Global.moretip)
		moretip.toggled.connect(func(p): Global.set_moretip_enabled(p); Global.save_game())
	if damage_show:
		damage_show.set_pressed_no_signal(Global.settings_manager.is_damage_show_enabled())
		damage_show.toggled.connect(func(p):
			Global.settings_manager.set_damage_show(p)
			if damage_type_item: damage_type_item.disabled = not p
			Global.save_game()
		)
	if damage_type_item:
		damage_type_item.clear()
		damage_type_item.add_item("原始数字")
		damage_type_item.add_item("中式缩写（万/亿）")
		damage_type_item.add_item("英式缩写（k/m/b）")
		damage_type_item.selected = Global.damage_show_type
		damage_type_item.disabled = not Global.settings_manager.is_damage_show_enabled()
		damage_type_item.item_selected.connect(func(idx): Global.damage_show_type = idx; Global.save_game())
	if time_slow_button:
		time_slow_button.set_pressed_no_signal(Global.time_slow_enabled)
		time_slow_button.toggled.connect(func(p): Global.time_slow_enabled = p; Global.save_game())
	if super_test_button:
		super_test_button.set_pressed_no_signal(Global.is_test)
		super_test_button.toggled.connect(func(p): Global.is_test = p; Global.save_game())

# ==================== 打开 / 关闭暂停菜单 ====================

func open() -> void:
	# 升级过程中（树已暂停）不允许打开暂停菜单
	if get_tree().paused:
		return
	visible = true
	main_panel.modulate = Color(1, 1, 1, 0)
	tips_panel.visible = false
	# 暂停技能节点计时（武器冷却等）
	_pause_skill_nodes(true)
	# 暂停玩家武器Timer
	if PC.player_instance and is_instance_valid(PC.player_instance) and PC.player_instance.has_method("pause_all_skill_cooldowns"):
		PC.player_instance.pause_all_skill_cooldowns(true)
	# 暂停敌人和玩家动画
	_pause_all_animations()
	get_tree().paused = true
	Global.in_menu = true
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(main_panel, "modulate:a", 1.0, FADE_DURATION)

func close() -> void:
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(main_panel, "modulate:a", 0.0, FADE_DURATION)
	await tween.finished
	visible = false
	get_tree().paused = false
	Global.in_menu = false
	# 恢复技能节点暂停状态
	_pause_skill_nodes(false)
	# 恢复玩家武器Timer
	if PC.player_instance and is_instance_valid(PC.player_instance) and PC.player_instance.has_method("pause_all_skill_cooldowns"):
		PC.player_instance.pause_all_skill_cooldowns(false)
	# 恢复敌人和玩家动画
	_resume_all_animations()

# ==================== 按钮回调 ====================

func _on_continue_pressed() -> void:
	close()

func _on_setting_pressed() -> void:
	if not setting_layer_ref:
		return
	setting_layer_ref.modulate = Color(1, 1, 1, 0)
	setting_layer_ref.visible = true
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(setting_layer_ref, "modulate:a", 1.0, FADE_DURATION)

func _close_setting() -> void:
	if not setting_layer_ref:
		return
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(setting_layer_ref, "modulate:a", 0.0, FADE_DURATION)
	await tween.finished
	setting_layer_ref.visible = false

func _on_exit_pressed() -> void:
	main_panel.visible = false
	tips_panel.modulate = Color(1, 1, 1, 0)
	tips_panel.visible = true
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(tips_panel, "modulate:a", 1.0, FADE_DURATION)

func _on_ok_pressed() -> void:
	get_tree().paused = false
	Global.in_menu = false
	Global.reset_game_speed()
	AchievementManager.record_stage_finished()
	Global.save_game()
	SceneChange.change_scene("res://Scenes/main_town.tscn", true)

func _on_return_pressed() -> void:
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(tips_panel, "modulate:a", 0.0, FADE_DURATION)
	await tween.finished
	tips_panel.visible = false
	main_panel.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			if tips_panel.visible:
				_on_return_pressed()
			elif setting_layer_ref and setting_layer_ref.visible:
				_close_setting()
			else:
				close()
			get_viewport().set_input_as_handled()
		elif not get_tree().paused and not Global.in_menu:
			open()
			get_viewport().set_input_as_handled()

# ==================== 暂停/恢复动画与技能计时 ====================

func _pause_skill_nodes(pause: bool) -> void:
	var parent_layer = get_parent()
	if not parent_layer:
		return
	# 递归查找所有含 set_game_paused 的 TextureButton（技能图标可能在子容器中）
	var skill_nodes = parent_layer.find_children("", "TextureButton", true, false)
	for child in skill_nodes:
		if child.has_method("set_game_paused"):
			child.set_game_paused(pause)

func _pause_all_animations() -> void:
	var tree = get_tree()
	if not tree:
		return
	# 暂停玩家动画
	for player in tree.get_nodes_in_group("player"):
		var sprite = player.get_node_or_null("AnimatedSprite2D")
		if sprite and sprite is AnimatedSprite2D:
			sprite.pause()
	# 通过 PC.player_instance 兜底
	if PC.player_instance and is_instance_valid(PC.player_instance):
		var sprite = PC.player_instance.get_node_or_null("AnimatedSprite2D")
		if sprite and sprite is AnimatedSprite2D and not sprite.is_playing():
			pass # 已经暂停
		elif sprite and sprite is AnimatedSprite2D:
			sprite.pause()
	# 暂停敌人动画
	for enemy in tree.get_nodes_in_group("enemies"):
		var sprite = enemy.get_node_or_null("AnimatedSprite2D")
		if sprite and sprite is AnimatedSprite2D:
			sprite.pause()

func _resume_all_animations() -> void:
	var tree = get_tree()
	if not tree:
		return
	# 恢复玩家动画
	for player in tree.get_nodes_in_group("player"):
		var sprite = player.get_node_or_null("AnimatedSprite2D")
		if sprite and sprite is AnimatedSprite2D:
			sprite.play()
	# 通过 PC.player_instance 兜底
	if PC.player_instance and is_instance_valid(PC.player_instance):
		var sprite = PC.player_instance.get_node_or_null("AnimatedSprite2D")
		if sprite and sprite is AnimatedSprite2D:
			sprite.play()
	# 恢复敌人动画
	for enemy in tree.get_nodes_in_group("enemies"):
		var sprite = enemy.get_node_or_null("AnimatedSprite2D")
		if sprite and sprite is AnimatedSprite2D:
			sprite.play()
