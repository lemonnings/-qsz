extends Control

@onready var progressBar: ProgressBar = $ProgressBar
@onready var label: Label = $Label
@onready var tips: Label = $Tips
@onready var animatedSprite2D: AnimatedSprite2D = $"../Control/AnimatedSprite2D"

var progress = []
var scene_load_status = 0

# 预定义的提示文本列表
var tip_texts = [
	"等级非常重要，升级可以提升大量的攻击与少量的体力上限",
	"每升两级可以获取一次领悟的刷新次数",
	"天命可以提升获取更高品质领悟选项的概率",
	"感电会让目标每秒受到50%角色攻击的伤害",
	"流血可以叠加到最多5层，每层会让目标每秒受到15%角色攻击的伤害",
	"燃烧会让目标每秒受到40%角色攻击的伤害，并对小范围内的其他敌人造成一半伤害",
	"每种法则升级到最高阶级后都会有极其强大的增益效果",
	"深层和核心会获取更多的灵气",
	"深层和核心难度下，首领会掉落更多的稀有材料",
	"易伤会使目标受到伤害加深20%",
	"脆弱可以让目标造成伤害降低25%",
	"减速会使目标移动速度降低25%",
	"麻痹和眩晕会让目标暂时无法移动，但对首领敌人无效",
	"设置里可以开关伤害显示与武器粒子特效，如果感觉卡顿建议关闭",
	"攻击速度与移动速度超过80%之后的部分会大幅衰减效果",
	"适当的提升最大体力可以有效的提升容错率",
	"均衡的提升攻击力，攻击速度，暴击率与暴击伤害会让角色造成的伤害更高",
	"越到战局后期，纹章的效果就越突出",
	"如果不想战斗环节被领悟打断，可以勾选领悟界面左下角的手动升级",
	"如果升级领悟之后容易找不到自己在哪，可以开启设置中的领悟结束后时缓选项",
	"可以在设置中勾选快速进入游戏，跳过起始界面快速进入桃源镇",
	"浅层难度下，首领造成的伤害会被大幅降低，是了解基础机制的好方法",
	"部分领悟内容有前置的解锁条件"
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
