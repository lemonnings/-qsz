extends Node
class_name SettingsManager

# 设置配置文件路径
const SETTINGS_CONFIG_PATH = "user://settings_config.cfg"

# 分辨率选项
const RESOLUTION_OPTIONS = {
	0: Vector2i(1024, 576),
	1: Vector2i(1366, 768),
	2: Vector2i(1920, 1080),
	3: Vector2i(2260, 1260)
}

# 默认设置
var current_resolution_index: int = 1 # 默认1366x768
var is_fullscreen: bool = false
var vignetting_enabled: bool = true
var particle_enabled: bool = true

# 信号
signal resolution_changed(new_resolution: Vector2i)
signal fullscreen_changed(is_fullscreen: bool)
signal vignetting_changed(enabled: bool)
signal particle_changed(enabled: bool)

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
	
	# 应用分辨率设置
	DisplayServer.window_set_size(new_resolution)
	
	# 居中窗口
	var screen_size = DisplayServer.screen_get_size()
	var window_pos = (screen_size - new_resolution) / 2
	DisplayServer.window_set_position(window_pos)
	
	resolution_changed.emit(new_resolution)
	save_settings()

# 设置全屏模式
func set_fullscreen(enabled: bool) -> void:
	is_fullscreen = enabled
	
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		# 如果退出全屏，重新应用分辨率设置
		set_resolution(current_resolution_index)
	
	fullscreen_changed.emit(enabled)
	save_settings()
	print("全屏模式: ", enabled)

# 设置暗角效果
func set_vignetting(enabled: bool) -> void:
	vignetting_enabled = enabled
	
	# 通过Global.SoftGlowManager控制暗角效果
	if Global.SoftGlowManager and Global.SoftGlowManager.has_method("toggle_filter"):
		Global.SoftGlowManager.toggle_filter(enabled)
		print("暗角效果: ", enabled)
	else:
		print("警告: SoftGlowManager未找到或未正确初始化")
	
	vignetting_changed.emit(enabled)
	save_settings()

# 设置粒子效果（暂未实现）
func set_particle(enabled: bool) -> void:
	particle_enabled = enabled
	
	# TODO: 实现粒子效果控制
	print("粒子效果设置: ", enabled, " (功能暂未实现)")
	
	particle_changed.emit(enabled)
	save_settings()

# 获取当前设置
func get_current_resolution_index() -> int:
	return current_resolution_index

func get_current_resolution() -> Vector2i:
	return RESOLUTION_OPTIONS[current_resolution_index]

func is_fullscreen_enabled() -> bool:
	return is_fullscreen

func is_vignetting_enabled() -> bool:
	return vignetting_enabled

func is_particle_enabled() -> bool:
	return particle_enabled

# 应用所有设置
func apply_all_settings() -> void:
	set_resolution(current_resolution_index)
	set_fullscreen(is_fullscreen)
	set_vignetting(vignetting_enabled)
	set_particle(particle_enabled)

# 保存设置
func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("display", "resolution_index", current_resolution_index)
	config.set_value("display", "fullscreen", is_fullscreen)
	config.set_value("effects", "vignetting", vignetting_enabled)
	config.set_value("effects", "particle", particle_enabled)
	
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
	
	current_resolution_index = config.get_value("display", "resolution_index", 1)
	is_fullscreen = config.get_value("display", "fullscreen", false)
	vignetting_enabled = config.get_value("effects", "vignetting", true)
	particle_enabled = config.get_value("effects", "particle", true)
	
	# 验证分辨率索引的有效性
	if current_resolution_index < 0 or current_resolution_index >= RESOLUTION_OPTIONS.size():
		current_resolution_index = 1 # 重置为默认值
	
	print("设置加载成功")

# 重置为默认设置
func reset_to_defaults() -> void:
	current_resolution_index = 1
	is_fullscreen = false
	vignetting_enabled = true
	particle_enabled = true
	
	apply_all_settings()
	save_settings()
	
	print("设置已重置为默认值")