extends Node

# 场景专属BGM播放器和环境音效播放器
var stage_bgm_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer

# 场景BGM映射表
var bgm_map: Dictionary = {}
# 场景环境音映射表
var ambient_map: Dictionary = {}

func _ready() -> void:
	_setup_stage_audio()
	Global.connect("stage_bgm", Callable(self , "play_stage_bgm"))
	Global.connect("stage_ambient", Callable(self , "play_stage_ambient"))
	Global.connect("stop_ambient", Callable(self , "stop_ambient"))

func _setup_stage_audio() -> void:
	# 创建场景专属BGM播放器
	stage_bgm_player = AudioStreamPlayer.new()
	stage_bgm_player.name = "StageBGM"
	stage_bgm_player.bus = "BGM"
	stage_bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(stage_bgm_player)
	
	# 创建环境音效播放器
	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "Ambient"
	ambient_player.bus = "BG"
	ambient_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ambient_player)
	
	# 载入场景BGM资源并设置循环
	var _bgm_town: AudioStreamMP3 = load("res://AssetBundle/Audio/Town_normal.mp3")
	var _bgm_peach: AudioStreamMP3 = load("res://AssetBundle/Audio/Peach_normal.mp3")
	var _bgm_ruin: AudioStreamMP3 = load("res://AssetBundle/Audio/Ruin_normal.mp3")
	var _bgm_cave: AudioStreamMP3 = load("res://AssetBundle/Audio/Cave_normal.mp3")
	var _bgm_forest: AudioStreamMP3 = load("res://AssetBundle/Audio/Forest_normal.mp3")
	for bgm_stream in [_bgm_town, _bgm_peach, _bgm_ruin, _bgm_cave, _bgm_forest]:
		bgm_stream.loop = true
	bgm_map = {
		"town": _bgm_town,
		"peach_grove": _bgm_peach,
		"ruin": _bgm_ruin,
		"cave": _bgm_cave,
		"forest": _bgm_forest,
	}
	
	# 载入环境音资源（导入时已启用循环）
	var _amb_town: AudioStreamMP3 = load("res://AssetBundle/Audio/gm/town.mp3")
	var _amb_peach: AudioStreamMP3 = load("res://AssetBundle/Audio/gm/peach_grove.mp3")
	var _amb_cave: AudioStreamMP3 = load("res://AssetBundle/Audio/gm/cave.mp3")
	for amb_stream in [_amb_town, _amb_peach, _amb_cave]:
		amb_stream.loop = true
	ambient_map = {
		"town": _amb_town,
		"peach_grove": _amb_peach,
		"cave": _amb_cave,
	}

## 播放场景专属BGM和环境音
func play_stage_bgm(stage_id: String) -> void:
	# 同一首BGM正在播放时，不重启，继续播放
	if bgm_map.has(stage_id) and stage_bgm_player.playing \
		and stage_bgm_player.stream == bgm_map[stage_id]:
		play_stage_ambient(stage_id)
		return
	stop_all_bgm()
	stop_ambient()
	if bgm_map.has(stage_id) and bgm_map[stage_id] != null:
		stage_bgm_player.stream = bgm_map[stage_id]
		stage_bgm_player.play(0.0)
	play_stage_ambient(stage_id)

## 播放场景环境音
func play_stage_ambient(stage_id: String) -> void:
	# 环境音映射：ruin和cave使用cave.wav，forest使用town.wav，其他使用同名
	var ambient_key = stage_id
	match stage_id:
		"ruin":
			ambient_key = "cave"
		"forest":
			ambient_key = "town"
	if ambient_map.has(ambient_key) and ambient_map[ambient_key] != null:
		ambient_player.stream = ambient_map[ambient_key]
		ambient_player.play(0.0)

## 停止环境音
func stop_ambient() -> void:
	if ambient_player:
		ambient_player.stop()

## 停止所有BGM
func stop_all_bgm() -> void:
	if stage_bgm_player:
		stage_bgm_player.stop()
