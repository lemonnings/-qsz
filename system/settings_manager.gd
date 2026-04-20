extends Node
class_name SettingsManager

# 设置配置文件路径
const SETTINGS_CONFIG_PATH = "user://settings_config.cfg"

# 分辨率选项
const RESOLUTION_OPTIONS = {
	0: Vector2i(800, 600),
	1: Vector2i(1024, 768),
	2: Vector2i(1280, 960),
	3: Vector2i(1366, 768),
	4: Vector2i(1400, 1050),
	5: Vector2i(1440, 900),
	6: Vector2i(1920, 1080),
	7: Vector2i(1920, 1200),
	8: Vector2i(2560, 1440),
	9: Vector2i(3440, 1440),
	10: Vector2i(3840, 2160)
}

# 默认设置
var current_resolution_index: int = 6 # 默认1920x1080
var is_fullscreen: bool = true
var noborder_enabled: bool = true
var vignetting_enabled: bool = true
var particle_enabled: bool = true
var damage_show_enabled: bool = true

# 信号
@warning_ignore("unused_signal")
signal resolution_changed(new_resolution: Vector2i)
@warning_ignore("unused_signal")
signal fullscreen_changed(is_fullscreen: bool)
@warning_ignore("unused_signal")
signal noborder_changed(enabled: bool)
@warning_ignore("unused_signal")
signal vignetting_changed(enabled: bool)
@warning_ignore("unused_signal")
signal particle_changed(enabled: bool)
@warning_ignore("unused_signal")
signal damage_show_changed(enabled: bool)

func _ready() -> void:
	# 加载设置
	load_settings()
	# 应用设置
	apply_all_settings()

# 设置分辨率
func set_resolution(resolution_index: int) -> void:
	if resolution_index < 0 or resolution_index >= RESOLUTION_OPTIONS.size():
		push_error("无效的分辨率索引: " + str(resolution_index))
		return
	
	current_resolution_index = resolution_index
	var new_resolution = RESOLUTION_OPTIONS[resolution_index]
	
	# 窗口模式下调整物理窗口大小
	if not is_fullscreen:
		DisplayServer.window_set_size(new_resolution)
		# 居中窗口
		var screen_size = DisplayServer.screen_get_size()
		var window_pos = (screen_size - new_resolution) / 2
		DisplayServer.window_set_position(window_pos)
	else:
		# 全屏模式下切换为独占全屏以应用分辨率
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	resolution_changed.emit(new_resolution)
	save_settings()

# 设置全屏模式
func set_fullscreen(enabled: bool) -> void:
	is_fullscreen = enabled
	var new_resolution = RESOLUTION_OPTIONS[current_resolution_index]
	
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		# 退出全屏时，延迟一帧再设置分辨率（窗口模式切换需要时间生效）
		_deferred_apply_window_size.call_deferred()
	
	# 如果启用了无边框，在非全屏时应用
	if not enabled and noborder_enabled:
		set_noborder(true)
	
	fullscreen_changed.emit(enabled)
	save_settings()
	print("全屏模式: ", enabled)

# 延迟应用窗口大小（全屏切换后需要等一帧）
func _deferred_apply_window_size() -> void:
	var new_resolution = RESOLUTION_OPTIONS[current_resolution_index]
	DisplayServer.window_set_size(new_resolution)
	var screen_size = DisplayServer.screen_get_size()
	var window_pos = (screen_size - new_resolution) / 2
	DisplayServer.window_set_position(window_pos)

# 设置无边框模式
func set_noborder(enabled: bool) -> void:
	noborder_enabled = enabled
	
	# 全屏模式下无边框无意义，跳过
	if is_fullscreen:
		noborder_changed.emit(enabled)
		save_settings()
		return
	
	if enabled:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	else:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	
	noborder_changed.emit(enabled)
	save_settings()
	print("无边框模式: ", enabled)

# 设置暗角效果
func set_vignetting(enabled: bool) -> void:
	vignetting_enabled = enabled
	
	# 通过Global.soft_glow_manager控制暗角效果
	if Global.soft_glow_manager and Global.soft_glow_manager.has_method("toggle_filter"):
		Global.soft_glow_manager.toggle_filter(enabled)
		print("暗角效果: ", enabled)
	else:
		print("警告: soft_glow_manager未找到或未正确初始化")
	
	vignetting_changed.emit(enabled)
	save_settings()

# 设置粒子效果
func set_particle(enabled: bool) -> void:
	particle_enabled = enabled
	
	# 同步更新 Global.particle_enable
	Global.particle_enable = enabled
	
	particle_changed.emit(enabled)
	save_settings()

# 设置伤害跳字显示
func set_damage_show(enabled: bool) -> void:
	damage_show_enabled = enabled
	
	# 同步更新 Global.damage_show_enabled
	Global.damage_show_enabled = enabled
	
	damage_show_changed.emit(enabled)
	save_settings()

# 获取当前设置
func get_current_resolution_index() -> int:
	return current_resolution_index

func get_current_resolution() -> Vector2i:
	return RESOLUTION_OPTIONS[current_resolution_index]

func is_fullscreen_enabled() -> bool:
	return is_fullscreen

func is_noborder_enabled() -> bool:
	return noborder_enabled

func is_vignetting_enabled() -> bool:
	return vignetting_enabled

func is_particle_enabled() -> bool:
	return particle_enabled

func is_damage_show_enabled() -> bool:
	return damage_show_enabled

# 应用所有设置
func apply_all_settings() -> void:
	# 先设置全屏模式，再设置分辨率（全屏模式下窗口大小设置无效）
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var new_resolution = RESOLUTION_OPTIONS[current_resolution_index]
		DisplayServer.window_set_size(new_resolution)
		var screen_size = DisplayServer.screen_get_size()
		var window_pos = (screen_size - new_resolution) / 2
		DisplayServer.window_set_position(window_pos)
	# 应用无边框设置
	if noborder_enabled and not is_fullscreen:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	set_vignetting(vignetting_enabled)
	set_particle(particle_enabled)
	set_damage_show(damage_show_enabled)

# 保存设置
func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("display", "resolution_index", current_resolution_index)
	config.set_value("display", "fullscreen", is_fullscreen)
	config.set_value("display", "noborder", noborder_enabled)
	config.set_value("effects", "vignetting", vignetting_enabled)
	config.set_value("effects", "particle", particle_enabled)
	config.set_value("effects", "damage_show", damage_show_enabled)
	
	var err = config.save(SETTINGS_CONFIG_PATH)
	if err == OK:
		print("设置保存成功")
	else:
		print("设置保存失败: ", err)

# 加载设置
func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_CONFIG_PATH)
	
	if err != OK:
		print("未找到设置配置文件，使用默认设置")
		return
	
	current_resolution_index = config.get_value("display", "resolution_index", 6)
	is_fullscreen = config.get_value("display", "fullscreen", true)
	noborder_enabled = config.get_value("display", "noborder", true)
	vignetting_enabled = config.get_value("effects", "vignetting", true)
	particle_enabled = config.get_value("effects", "particle", true)
	damage_show_enabled = config.get_value("effects", "damage_show", true)
	
	# 验证分辨率索引的有效性
	if current_resolution_index < 0 or current_resolution_index >= RESOLUTION_OPTIONS.size():
		current_resolution_index = 6 # 重置为默认值
	
	print("设置加载成功")

# 重置为默认设置
func reset_to_defaults() -> void:
	current_resolution_index = 6
	is_fullscreen = true
	noborder_enabled = true
	vignetting_enabled = true
	particle_enabled = true
	damage_show_enabled = true
	
	apply_all_settings()
	save_settings()
	
	print("设置已重置为默认值")
