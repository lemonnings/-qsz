extends Node

# 音频资源缓存（用 preload 预加载，确保导出时资源被包含）
var _audio_cache: Dictionary = {}
# AudioStreamPlayer 对象池
var _player_pool: Array[AudioStreamPlayer] = []
# 最大同时播放数
const MAX_PLAYERS := 64
# 同一音效最大同时播放数
const MAX_SAME_SE := 4
# 每个播放器当前播放的音效ID，用于并发计数
var _player_se_id: Dictionary = {}
# 同一音效并发时的音量缩放: 第1个=1.0, 第2个=0.7, 第3个=0.5, 第4个=0.3
const SAME_SE_VOLUME_SCALE: Array[float] = [1.0, 0.7, 0.5, 0.3]

# ============== preload 所有音效资源 ==============
# 确保 Godot 导出时包含这些资源，同时避免运行时加载失败
const _PRELOADS: Dictionary = {
	"1": preload("res://AssetBundle/Audio/se/1.wav"),
	"2": preload("res://AssetBundle/Audio/se/2.wav"),
	"3": preload("res://AssetBundle/Audio/se/3.mp3"),
	"4": preload("res://AssetBundle/Audio/se/4.wav"),
	"5": preload("res://AssetBundle/Audio/se/5.wav"),
	"9": preload("res://AssetBundle/Audio/se/9.mp3"),
	"10": preload("res://AssetBundle/Audio/se/10.mp3"),
	"11": preload("res://AssetBundle/Audio/se/11.mp3"),
	"12": preload("res://AssetBundle/Audio/se/12.mp3"),
	"13": preload("res://AssetBundle/Audio/se/13.mp3"),
	"14": preload("res://AssetBundle/Audio/se/14.mp3"),
	"15": preload("res://AssetBundle/Audio/se/15.mp3"),
	"16": preload("res://AssetBundle/Audio/se/16.mp3"),
	"17": preload("res://AssetBundle/Audio/se/17.mp3"),
	"18": preload("res://AssetBundle/Audio/se/18.wav"),
	"20": preload("res://AssetBundle/Audio/se/20.mp3"),
	"22": preload("res://AssetBundle/Audio/se/22.wav"),
	"23": preload("res://AssetBundle/Audio/se/23.mp3"),
	"24": preload("res://AssetBundle/Audio/se/24.mp3"),
	"30": preload("res://AssetBundle/Audio/se/30.mp3"),
	"31": preload("res://AssetBundle/Audio/se/31.mp3"),
	"34": preload("res://AssetBundle/Audio/se/34.mp3"),
	"35": preload("res://AssetBundle/Audio/se/35.mp3"),
	"50": preload("res://AssetBundle/Audio/se/50.mp3"),
	"60": preload("res://AssetBundle/Audio/se/60.mp3"),
	"63": preload("res://AssetBundle/Audio/se/63.ogg"),
	"64": preload("res://AssetBundle/Audio/se/64.wav"),
	"65": preload("res://AssetBundle/Audio/se/65.wav"),
	"66": preload("res://AssetBundle/Audio/se/66.wav"),
	"67": preload("res://AssetBundle/Audio/se/67.wav"),
	"68": preload("res://AssetBundle/Audio/se/68.mp3"),
	"69": preload("res://AssetBundle/Audio/se/69.mp3"),
	"111": preload("res://AssetBundle/Audio/se/111.mp3"),
	"112": preload("res://AssetBundle/Audio/se/112.mp3"),
	"131": preload("res://AssetBundle/Audio/se/131.mp3"),
	"132": preload("res://AssetBundle/Audio/se/132.mp3"),
	"137": preload("res://AssetBundle/Audio/se/137.wav"),
	"139": preload("res://AssetBundle/Audio/se/139.mp3"),
	"200": preload("res://AssetBundle/Audio/se/200.wav"),
	"201": preload("res://AssetBundle/Audio/se/201.wav"),
	"202": preload("res://AssetBundle/Audio/se/202.wav"),
	"203": preload("res://AssetBundle/Audio/se/203.wav"),
	"212": preload("res://AssetBundle/Audio/se/212.wav"),
}

func _ready():
	SEConfig.load_data()
	# 将预加载资源填入缓存
	_audio_cache = _PRELOADS.duplicate()
	# 预创建对象池
	for i in range(MAX_PLAYERS):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		player.finished.connect(_on_player_finished.bind(player))
		add_child(player)
		_player_pool.append(player)

func play(se_id: String, ignore_pause: bool = false) -> void:
	# 1. 检查条目是否存在
	if not SEConfig.has_entry(se_id):
		push_warning("SEManager: 未找到音效配置 id=" + se_id)
		return
	
	# 2. 统计当前同一音效的播放数量
	var same_count := _get_same_se_count(se_id)
	if same_count >= MAX_SAME_SE:
		return
	
	# 3. 获取音频资源
	var stream: AudioStream = _get_stream(se_id)
	if stream == null:
		push_warning("SEManager: 无法获取音频 id=" + se_id)
		return
	
	# 4. 从对象池获取空闲播放器
	var player = _get_available_player()
	if player == null:
		push_warning("SEManager: 无可用播放器")
		return
	
	# 5. 根据并发数设置音量缩放，叠加配置表中的db偏移
	var volume_scale := SAME_SE_VOLUME_SCALE[same_count] if same_count < SAME_SE_VOLUME_SCALE.size() else 0.0
	var db_offset := SEConfig.get_db(se_id)
	player.volume_db = linear_to_db(volume_scale) + db_offset
	
	# 6. 设置音高
	var pitch_range = SEConfig.get_pitch_range(se_id)
	if pitch_range.size() == 2:
		player.pitch_scale = randf_range(pitch_range[0], pitch_range[1])
	else:
		player.pitch_scale = 1.0
	
	# 7. 暂停时不中断播放
	if ignore_pause:
		player.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 8. 播放并记录音效ID
	player.stream = stream
	_player_se_id[player.get_instance_id()] = se_id
	player.play()

func _get_stream(se_id: String) -> AudioStream:
	# 优先从缓存（含预加载）获取
	if _audio_cache.has(se_id):
		return _audio_cache[se_id]
	# 回退：运行时动态加载（仅开发环境有效，导出后不应走到这里）
	var audio_path := _find_audio_path(se_id)
	if audio_path != "":
		var stream := load(audio_path) as AudioStream
		if stream:
			_audio_cache[se_id] = stream
			return stream
	return null

func _find_audio_path(se_id: String) -> String:
	const BASE_PATH := "res://AssetBundle/Audio/se/"
	const EXTENSIONS: Array[String] = [".wav", ".mp3", ".ogg"]
	for ext in EXTENSIONS:
		var path := BASE_PATH + se_id + ext
		if ResourceLoader.exists(path):
			return path
	return ""

func _get_same_se_count(se_id: String) -> int:
	var count := 0
	for player in _player_pool:
		if player.playing and _player_se_id.get(player.get_instance_id(), "") == se_id:
			count += 1
	return count

func _get_available_player() -> AudioStreamPlayer:
	for player in _player_pool:
		if not player.playing:
			return player
	return null

func _on_player_finished(player: AudioStreamPlayer) -> void:
	player.stream = null
	_player_se_id.erase(player.get_instance_id())
	# 恢复默认处理模式，避免该播放器下次被复用时仍不受暂停影响
	if player.process_mode == Node.PROCESS_MODE_ALWAYS:
		player.process_mode = Node.PROCESS_MODE_PAUSABLE
