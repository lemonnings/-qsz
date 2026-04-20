extends Control

@onready var progressBar: ProgressBar = $ProgressBar
@onready var label: Label = $Label
@onready var tips: Label = $Tips
@onready var animatedSprite2D: AnimatedSprite2D = $"../Control/AnimatedSprite2D"

var progress = []
var scene_load_status = 0

# 预定义的提示文本列表
var tip_texts = [
	"等级非常重要！每升一级可以提升5点攻击，并提升10%的总攻击",
	"每升两级可以获取一次领悟的刷新次数",
	"感电会让目标每秒受到50%角色攻击的伤害",
	"流血可以叠加到最多5层，每层会让目标每秒受到15%角色攻击的伤害",
	"燃烧会让目标每秒受到40%角色攻击的伤害，并对小范围内的其他敌人造成一半伤害",
	"法则非常重要，多多尝试不同的法则组合吧~",
	"易伤会使目标受到伤害加深20%",
	"脆弱可以让目标造成伤害降低25%",
	"减速会使目标移动速度降低25%",
	"麻痹和眩晕会让目标暂时无法移动，但对首领敌人无效",
	"设置里可以开关伤害显示与粒子特效，如果感觉卡顿建议关闭",
	"部分领悟内容有前置解锁条件，请多多探索吧~"
	# "墨宁是天衍宗最为优秀的少年弟子之一，擅长风系与轻功",
	# "墨宁虽然话不多，但内心良善，经常帮助宗门里的其他弟子与长辈"
]

func _ready() -> void:
	progressBar.max_value = 100.0
	animatedSprite2D.play()
	
	# 随机选择一条提示
	var random_index = randi_range(0, tip_texts.size() - 1)
	tips.text = "Tips：" + tip_texts[random_index]
	
	ResourceLoader.load_threaded_request(SceneChange.loading_path)

func _process(delta: float) -> void:
	scene_load_status = ResourceLoader.load_threaded_get_status(SceneChange.loading_path, progress)
	progressBar.value = progress[0] * 100
	
	if scene_load_status == ResourceLoader.THREAD_LOAD_LOADED:
		set_process(false)
		await get_tree().create_timer(0.3).timeout
		SceneChange.change_scene(ResourceLoader.load_threaded_get(SceneChange.loading_path))
