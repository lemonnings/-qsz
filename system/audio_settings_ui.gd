extends Control
class_name AudioSettingsUI

# UI组件引用
@onready var master_volume_slider: HSlider
@onready var bgm_volume_slider: HSlider
@onready var sfx_volume_slider: HSlider

@onready var master_volume_label: Label
@onready var bgm_volume_label: Label
@onready var sfx_volume_label: Label

@onready var master_mute_button: Button
@onready var bgm_mute_button: Button
@onready var sfx_mute_button: Button

@onready var reset_button: Button
@onready var close_button: Button

# 音频管理器引用
var audio_manager: AudioManager

func _ready() -> void:
	# 获取音频管理器引用
	audio_manager = Global.audio_manager
	
	# 创建UI
	setup_ui()
	
	# 连接信号
	connect_signals()
	
	# 初始化UI值
	update_ui_values()

func setup_ui() -> void:
	# 设置窗口属性
	name = "AudioSettingsUI"
	size = Vector2(400, 300)
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -200
	offset_top = -150
	offset_right = 200
	offset_bottom = 150
	
	# 创建背景面板
	var background = Panel.new()
	background.name = "Background"
	background.anchors_preset = Control.PRESET_FULL_RECT
	add_child(background)
	
	# 创建主容器
	var main_container = VBoxContainer.new()
	main_container.name = "MainContainer"
	main_container.anchors_preset = Control.PRESET_FULL_RECT
	main_container.add_theme_constant_override("separation", 10)
	add_child(main_container)
	
	# 标题
	var title_label = Label.new()
	title_label.text = "音频设置"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	main_container.add_child(title_label)
	
	# 总体音量设置
	create_volume_control(main_container, "总体音量", "master")
	
	# BGM音量设置
	create_volume_control(main_container, "背景音乐音量", "bgm")
	
	# 音效音量设置
	create_volume_control(main_container, "音效音量", "sfx")
	
	# 按钮容器
	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 20)
	main_container.add_child(button_container)
	
	# 重置按钮
	reset_button = Button.new()
	reset_button.text = "重置默认"
	reset_button.custom_minimum_size = Vector2(80, 30)
	button_container.add_child(reset_button)
	
	# 关闭按钮
	close_button = Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(80, 30)
	button_container.add_child(close_button)

func create_volume_control(parent: Container, label_text: String, volume_type: String) -> void:
	# 创建容器
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	parent.add_child(container)
	
	# 标签和静音按钮容器
	var header_container = HBoxContainer.new()
	header_container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(header_container)
	
	# 音量标签
	var volume_label = Label.new()
	volume_label.text = label_text
	volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_container.add_child(volume_label)
	
	# 静音按钮
	var mute_button = Button.new()
	mute_button.text = "🔊"
	mute_button.custom_minimum_size = Vector2(30, 30)
	header_container.add_child(mute_button)
	
	# 滑块和数值容器
	var slider_container = HBoxContainer.new()
	slider_container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(slider_container)
	
	# 音量滑块
	var volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.01
	volume_slider.custom_minimum_size = Vector2(200, 20)
	slider_container.add_child(volume_slider)
	
	# 音量数值标签
	var value_label = Label.new()
	value_label.custom_minimum_size = Vector2(50, 20)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slider_container.add_child(value_label)
	
	# 根据类型保存引用
	match volume_type:
		"master":
			master_volume_slider = volume_slider
			master_volume_label = value_label
			master_mute_button = mute_button
		"bgm":
			bgm_volume_slider = volume_slider
			bgm_volume_label = value_label
			bgm_mute_button = mute_button
		"sfx":
			sfx_volume_slider = volume_slider
			sfx_volume_label = value_label
			sfx_mute_button = mute_button

func connect_signals() -> void:
	# 连接滑块信号
	if master_volume_slider:
		master_volume_slider.value_changed.connect(_on_master_volume_changed)
	if bgm_volume_slider:
		bgm_volume_slider.value_changed.connect(_on_bgm_volume_changed)
	if sfx_volume_slider:
		sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	
	# 连接静音按钮信号
	if master_mute_button:
		master_mute_button.pressed.connect(_on_master_mute_pressed)
	if bgm_mute_button:
		bgm_mute_button.pressed.connect(_on_bgm_mute_pressed)
	if sfx_mute_button:
		sfx_mute_button.pressed.connect(_on_sfx_mute_pressed)
	
	# 连接其他按钮信号
	if reset_button:
		reset_button.pressed.connect(_on_reset_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# 连接音频管理器信号
	if audio_manager:
		audio_manager.volume_changed.connect(_on_volume_changed)

func update_ui_values() -> void:
	if not audio_manager:
		return
	
	# 更新滑块值
	if master_volume_slider:
		master_volume_slider.value = audio_manager.get_master_volume()
	if bgm_volume_slider:
		bgm_volume_slider.value = audio_manager.get_bgm_volume()
	if sfx_volume_slider:
		sfx_volume_slider.value = audio_manager.get_sfx_volume()
	
	# 更新标签
	update_volume_labels()
	
	# 更新静音按钮状态
	update_mute_buttons()

func update_volume_labels() -> void:
	if master_volume_label and audio_manager:
		master_volume_label.text = str(int(audio_manager.get_master_volume() * 100)) + "%"
	if bgm_volume_label and audio_manager:
		bgm_volume_label.text = str(int(audio_manager.get_bgm_volume() * 100)) + "%"
	if sfx_volume_label and audio_manager:
		sfx_volume_label.text = str(int(audio_manager.get_sfx_volume() * 100)) + "%"

func update_mute_buttons() -> void:
	# 检查静音状态并更新按钮文本
	var master_bus_index = AudioServer.get_bus_index("Master")
	var bgm_bus_index = AudioServer.get_bus_index("BGM")
	var sfx_bus_index = AudioServer.get_bus_index("SFX")
	
	if master_mute_button:
		if AudioServer.is_bus_mute(master_bus_index):
			master_mute_button.text = "🔇"
		else:
			master_mute_button.text = "🔊"
	
	if bgm_mute_button and bgm_bus_index != -1:
		if AudioServer.is_bus_mute(bgm_bus_index):
			bgm_mute_button.text = "🔇"
		else:
			bgm_mute_button.text = "🔊"
	
	if sfx_mute_button and sfx_bus_index != -1:
		if AudioServer.is_bus_mute(sfx_bus_index):
			sfx_mute_button.text = "🔇"
		else:
			sfx_mute_button.text = "🔊"

# 信号处理函数
func _on_master_volume_changed(value: float) -> void:
	if audio_manager:
		audio_manager.set_master_volume(value)

func _on_bgm_volume_changed(value: float) -> void:
	if audio_manager:
		audio_manager.set_bgm_volume(value)

func _on_sfx_volume_changed(value: float) -> void:
	if audio_manager:
		audio_manager.set_sfx_volume(value)

func _on_master_mute_pressed() -> void:
	if audio_manager:
		audio_manager.toggle_master_mute()
		update_mute_buttons()

func _on_bgm_mute_pressed() -> void:
	if audio_manager:
		audio_manager.toggle_bgm_mute()
		update_mute_buttons()

func _on_sfx_mute_pressed() -> void:
	if audio_manager:
		audio_manager.toggle_sfx_mute()
		update_mute_buttons()

func _on_reset_pressed() -> void:
	if audio_manager:
		audio_manager.reset_to_defaults()
		update_ui_values()

func _on_close_pressed() -> void:
	# 隐藏或删除UI
	queue_free()

func _on_volume_changed(bus_name: String, volume: float) -> void:
	# 当音量改变时更新UI
	update_volume_labels()
	
	# 如果需要，可以在这里添加其他响应逻辑
	match bus_name:
		"Master":
			if master_volume_slider:
				master_volume_slider.value = volume
		"BGM":
			if bgm_volume_slider:
				bgm_volume_slider.value = volume
		"SFX":
			if sfx_volume_slider:
				sfx_volume_slider.value = volume

# 静态函数：创建并显示音频设置窗口
static func show_audio_settings(parent: Node) -> AudioSettingsUI:
	var audio_settings = AudioSettingsUI.new()
	parent.add_child(audio_settings)
	return audio_settings