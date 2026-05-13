extends Node

# 音频资源缓存
var _audio_cache: Dictionary = {}
# AudioStreamPlayer 对象池
var _player_pool: Array[AudioStreamPlayer] = []
# 最大同时播放数
const MAX_PLAYERS := 16

func _ready():
	SEConfig.load_data()
	# 预创建对象池
	for i in range(MAX_PLAYERS):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		player.finished.connect(_on_player_finished.bind(player))
		add_child(player)
		_player_pool.append(player)

func play(se_id: String) -> void:
	# 1. 检查条目是否存在
	if not SEConfig.has_entry(se_id):
		push_warning("SEManager: 未找到音效配置 id=" + se_id)
		return
	
	# 2. 获取或加载音频资源
	var audio_path = "res://AssetBundle/Audio/se/" + se_id + ".mp3"
	var stream: AudioStream = null
	if _audio_cache.has(se_id):
		stream = _audio_cache[se_id]
	else:
		if not ResourceLoader.exists(audio_path):
			push_warning("SEManager: 音频文件不存在 " + audio_path)
			return
		stream = load(audio_path)
		if stream:
			_audio_cache[se_id] = stream
	
	if stream == null:
		return
	
	# 3. 从对象池获取空闲播放器
	var player = _get_available_player()
	if player == null:
		push_warning("SEManager: 无可用播放器")
		return
	
	# 4. 设置音高
	var pitch_range = SEConfig.get_pitch_range(se_id)
	if pitch_range.size() == 2:
		player.pitch_scale = randf_range(pitch_range[0], pitch_range[1])
	else:
		player.pitch_scale = 1.0
	
	# 5. 播放
	player.stream = stream
	player.play()

func _get_available_player() -> AudioStreamPlayer:
	for player in _player_pool:
		if not player.playing:
			return player
	return null

func _on_player_finished(player: AudioStreamPlayer) -> void:
	player.stream = null
