extends CanvasLayer

@export var start_button: Button
@export var change_save_button: Button
@export var setting_button: Button
@export var about_button: Button
@export var background: Sprite2D
@export var settings_layer: CanvasLayer

## 背景动态动画参数
const BG_ANIM_DURATION := 5.0 ## 每次动画持续秒数
const BG_SCALE_RANGE := 0.1 ## 缩放变化范围（±0.1倍）
const BG_MOVE_RANGE_MIN := 10.0 ## 移动最小像素
const BG_MOVE_RANGE_MAX := 15.0 ## 移动最大像素

## 背景初始数据（从场景读取）
var _bg_base_position: Vector2
var _bg_base_scale: Vector2
var _bg_tween: Tween

func _ready() -> void:
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	if change_save_button:
		change_save_button.pressed.connect(_on_change_save_pressed)
	if setting_button:
		setting_button.pressed.connect(_on_setting_pressed)
	if about_button:
		about_button.pressed.connect(_on_about_pressed)
	# 隐藏设置面板中的背包/技能/设定按钮（主菜单不需要）
	if settings_layer:
		var bag_btn = settings_layer.get_node_or_null("Bag")
		var skill_btn = settings_layer.get_node_or_null("Skill")
		var setting_btn = settings_layer.get_node_or_null("Setting")
		if bag_btn:
			bag_btn.visible = false
		if skill_btn:
			skill_btn.visible = false
		if setting_btn:
			setting_btn.visible = false
		# 将Exit2按钮重连到主菜单自己的关闭逻辑
		var exit_btn = settings_layer.get_node_or_null("Panel/Exit2")
		if exit_btn:
			if not exit_btn.pressed.is_connected(_on_exit_setting):
				if exit_btn.pressed.is_connected(settings_layer._on_exit_pressed):
					exit_btn.pressed.disconnect(settings_layer._on_exit_pressed)
				exit_btn.pressed.connect(_on_exit_setting)
	# 记录背景初始数据并启动循环动画
	if background:
		_bg_base_position = background.position
		_bg_base_scale = background.scale
		_start_bg_anim()
	# 播放城镇BGM（不播放环境音效）
	Global.emit_signal("stage_bgm", "town")
	Bgm.stop_ambient()

func _on_start_pressed() -> void:
	Global.in_menu = false
	if Global.is_first_game:
		Global.is_first_game = false
		Global.save_game()
		# 白屏渐变过渡到开篇剧情
		_fade_to_white_then_start_story()
		return
	Global.soft_glow_manager.enter_gameplay()
	SceneChange.change_scene("res://Scenes/main_town.tscn", true)

func _fade_to_white_then_start_story() -> void:
	# 创建黑色全屏遮罩
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 9999
	add_child(overlay)
	var tween = create_tween()
	tween.tween_property(overlay, "color:a", 1.0, 0.6)
	tween.tween_callback(func():
		Global.soft_glow_manager.enter_gameplay()
		SceneChange.change_scene("res://Scenes/town/start_story.tscn", false, true)
	)

func _on_change_save_pressed() -> void:
	_show_tip("该功能暂未制作")

func _on_setting_pressed() -> void:
	if not settings_layer:
		return
	settings_layer.visible = true
	var panel = settings_layer.get_node_or_null("Panel")
	if panel and not panel.visible:
		panel.visible = true
		panel.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(panel, "modulate:a", 1.0, 0.15)

func _on_exit_setting() -> void:
	if not settings_layer:
		return
	var panel = settings_layer.get_node_or_null("Panel")
	if panel and panel.visible:
		var tween = create_tween()
		tween.tween_property(panel, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func():
			panel.visible = false
			panel.modulate.a = 1.0
			settings_layer.visible = false
		)

func _on_about_pressed() -> void:
	_show_tip("该功能暂未制作")

func _show_tip(msg: String) -> void:
	Tip.start_animation(msg, 0.5)

## 背景动态动画：随机缩放 + 随机方向移动，5秒一个周期循环
func _start_bg_anim() -> void:
	# 随机缩放变化（±0.1倍）
	var scale_offset = randf_range(-BG_SCALE_RANGE, BG_SCALE_RANGE)
	var target_scale = _bg_base_scale * (1.0 + scale_offset)
	
	# 随机方向移动（10~15像素）
	var angle = randf() * TAU
	var distance = randf_range(BG_MOVE_RANGE_MIN, BG_MOVE_RANGE_MAX)
	var target_position = _bg_base_position + Vector2(cos(angle), sin(angle)) * distance
	
	# 创建动画
	if _bg_tween and _bg_tween.is_running():
		_bg_tween.kill()
	_bg_tween = create_tween()
	_bg_tween.set_ease(Tween.EASE_IN_OUT)
	_bg_tween.set_trans(Tween.TRANS_SINE)
	_bg_tween.tween_property(background, "scale", target_scale, BG_ANIM_DURATION)
	_bg_tween.parallel().tween_property(background, "position", target_position, BG_ANIM_DURATION)
	_bg_tween.tween_callback(_start_bg_anim)
