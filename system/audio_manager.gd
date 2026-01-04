extends Node

# 音频管理器 - 管理总体音量、BGM音量、音效音量
class_name AudioManager

# 音量设置（0.0 到 1.0）
@export var master_volume: float = 1.0  # 总体音量
@export var bgm_volume: float = 1.0     # BGM音量
@export var sfx_volume: float = 1.0     # 音效音量

# 音频总线名称
const MASTER_BUS = "Master"
const BGM_BUS = "BGM"
const SFX_BUS = "SFX"

# 配置文件路径
const AUDIO_CONFIG_PATH = "user://audio_config.cfg"

# 信号
signal volume_changed(bus_name: String, volume: float)

func _ready() -> void:
	# 确保音频总线存在
	setup_audio_buses()
	# 加载音频设置
	load_audio_settings()
	# 应用音量设置
	apply_volume_settings()

func setup_audio_buses() -> void:
	# 检查并创建音频总线
	# 注意：在Godot 4中，不需要调用get_bus_layout()
	
	# 确保BGM总线存在
	if AudioServer.get_bus_index(BGM_BUS) == -1:
		AudioServer.add_bus()  # 不指定索引，让系统自动分配
		var bgm_index = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(bgm_index, BGM_BUS)
		AudioServer.set_bus_send(bgm_index, MASTER_BUS)
	
	# 确保SFX总线存在
	if AudioServer.get_bus_index(SFX_BUS) == -1:
		AudioServer.add_bus()
		var sfx_index = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(sfx_index, SFX_BUS)
		AudioServer.set_bus_send(sfx_index, MASTER_BUS)

func set_master_volume(volume: float) -> void:
	master_volume = clamp(volume, 0.0, 1.0)
	apply_master_volume()
	volume_changed.emit(MASTER_BUS, master_volume)
	save_audio_settings()

func set_bgm_volume(volume: float) -> void:
	bgm_volume = clamp(volume, 0.0, 1.0)
	apply_bgm_volume()
	volume_changed.emit(BGM_BUS, bgm_volume)
	save_audio_settings()

func set_sfx_volume(volume: float) -> void:
	sfx_volume = clamp(volume, 0.0, 1.0)
	apply_sfx_volume()
	volume_changed.emit(SFX_BUS, sfx_volume)
	save_audio_settings()

func apply_volume_settings() -> void:
	apply_master_volume()
	apply_bgm_volume()
	apply_sfx_volume()

func apply_master_volume() -> void:
	var master_bus_index = AudioServer.get_bus_index(MASTER_BUS)
	if master_bus_index == -1:
		push_error("Master音频总线不存在")
		return
	
	if master_volume <= 0.0:
		AudioServer.set_bus_mute(master_bus_index, true)
	else:
		AudioServer.set_bus_mute(master_bus_index, false)
		var db = linear_to_db(master_volume)
		AudioServer.set_bus_volume_db(master_bus_index, db)

func apply_bgm_volume() -> void:
	var bgm_bus_index = AudioServer.get_bus_index(BGM_BUS)
	if bgm_bus_index == -1:
		push_error("BGM音频总线不存在")
		return

	if bgm_volume <= 0.0:
		AudioServer.set_bus_mute(bgm_bus_index, true)
	else:
		AudioServer.set_bus_mute(bgm_bus_index, false)
		var db = linear_to_db(bgm_volume)
		AudioServer.set_bus_volume_db(bgm_bus_index, db)

func apply_sfx_volume() -> void:
	var sfx_bus_index = AudioServer.get_bus_index(SFX_BUS)
	if sfx_bus_index == -1:
		push_error("SFX音频总线不存在")
		return
	
	if sfx_volume <= 0.0:
		AudioServer.set_bus_mute(sfx_bus_index, true)
	else:
		AudioServer.set_bus_mute(sfx_bus_index, false)
		var db = linear_to_db(sfx_volume)
		AudioServer.set_bus_volume_db(sfx_bus_index, db)

func get_master_volume() -> float:
	return master_volume

func get_bgm_volume() -> float:
	return bgm_volume

func get_sfx_volume() -> float:
	return sfx_volume

# 静音/取消静音功能
func toggle_master_mute() -> void:
	var master_bus_index = AudioServer.get_bus_index(MASTER_BUS)
	if master_bus_index == -1:
		push_error("Master音频总线不存在")
		return
	
	var is_muted = AudioServer.is_bus_mute(master_bus_index)
	AudioServer.set_bus_mute(master_bus_index, not is_muted)
	# 发送信号通知UI更新静音状态
	volume_changed.emit(MASTER_BUS, master_volume if not is_muted else 0.0)

func toggle_bgm_mute() -> void:
	var bgm_bus_index = AudioServer.get_bus_index(BGM_BUS)
	if bgm_bus_index == -1:
		push_error("BGM音频总线不存在")
		return
	
	var is_muted = AudioServer.is_bus_mute(bgm_bus_index)
	AudioServer.set_bus_mute(bgm_bus_index, not is_muted)
	# 发送信号通知UI更新静音状态
	volume_changed.emit(BGM_BUS, bgm_volume if not is_muted else 0.0)

func toggle_sfx_mute() -> void:
	var sfx_bus_index = AudioServer.get_bus_index(SFX_BUS)
	if sfx_bus_index == -1:
		push_error("SFX音频总线不存在")
		return
	
	var is_muted = AudioServer.is_bus_mute(sfx_bus_index)
	AudioServer.set_bus_mute(sfx_bus_index, not is_muted)
	# 发送信号通知UI更新静音状态
	volume_changed.emit(SFX_BUS, sfx_volume if not is_muted else 0.0)

# 保存音频设置
func save_audio_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "bgm_volume", bgm_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	
	var err = config.save(AUDIO_CONFIG_PATH)
	if err != OK:
		print("音频设置保存失败: ", err)

# 加载音频设置
func load_audio_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(AUDIO_CONFIG_PATH)
	
	if err != OK:
		print("未找到音频配置文件，使用默认设置")
		return
	
	master_volume = config.get_value("audio", "master_volume", 1.0)
	bgm_volume = config.get_value("audio", "bgm_volume", 1.0)
	sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
	
	# 确保音量值在有效范围内
	master_volume = clamp(master_volume, 0.0, 1.0)
	bgm_volume = clamp(bgm_volume, 0.0, 1.0)
	sfx_volume = clamp(sfx_volume, 0.0, 1.0)
	
	print("音频设置加载成功")

# 重置为默认设置
func reset_to_defaults() -> void:
	master_volume = 1.0
	bgm_volume = 1.0
	sfx_volume = 1.0
	apply_volume_settings()
	save_audio_settings()
	
	# 发送信号通知UI更新
	volume_changed.emit(MASTER_BUS, master_volume)
	volume_changed.emit(BGM_BUS, bgm_volume)
	volume_changed.emit(SFX_BUS, sfx_volume)

# 辅助函数：线性音量转换为分贝
func linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0  # 静音
	return 20.0 * log(linear) / log(10.0)

# 辅助函数：分贝转换为线性音量
func db_to_linear(db: float) -> float:
	if db <= -80.0:
		return 0.0
	return pow(10.0, db / 20.0)
