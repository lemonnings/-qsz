extends Control

@onready var progressBar: ProgressBar = $ProgressBar
@onready var label: Label = $Label
@onready var tips: Label = $Tips
@export var animatedSprite2D: AnimatedSprite2D


var progress = []
var scene_load_status = 0

# 预定义的提示文本列表
var tip_texts = [
	"等级非常重要，升级可以提升大量的攻击与少量的体力上限",
	"初始拥有2次领悟刷新次数，每升3级可以再获取1次",
	"每升5级可以获取一次领悟的锁定次数",
	"天命可以提升获取更高品质领悟选项的概率",
	"感电会让目标每秒受到50%角色攻击的伤害",
	"流血可以叠加到最多5层，每层会让目标每秒受到15%角色攻击的伤害",
	"燃烧会让目标每秒受到40%角色攻击的伤害，并对小范围内的其他敌人造成一半伤害",
	"每种法则升级到高阶级后都会有极其强大的增益效果",
	"深层和核心会获取更多的灵气",
	"深层和核心难度下，首领会掉落更多的稀有材料",
	"易伤会使目标受到伤害加深20%",
	"脆弱可以让目标造成伤害降低25%",
	"减速会使目标移动速度降低25%",
	"麻痹和眩晕会让目标暂时无法移动，但对首领敌人无效",
	"设置里可以开关伤害显示与武器粒子特效，如果感觉卡顿建议关闭",
	"攻击速度与移动速度超过80%之后的部分会大幅衰减效果",
	"适当的提升防御可以有效的提升与首领战斗中的容错率",
	"逆天级别（红色）的领悟有着改变战局的强大威力",
	"均衡的提升攻击力，攻击速度，暴击率与暴击伤害会让角色造成的伤害更高",
	"均衡的提升最大体力，护甲与减伤率会让角色能承受更多的伤害",
	"越到战局后期，纹章的效果就越突出",
	"如果不想战斗环节被领悟打断，可以勾选领悟界面左下角的手动升级",
	"如果升级领悟之后容易找不到自己在哪，可以开启设置中的领悟结束后时缓选项",
	"可以在设置中勾选快速进入游戏，跳过起始界面快速进入桃源镇",
	"浅层难度下，首领造成的伤害会被小幅降低，是了解基础机制的好方法",
	"流血、感电、燃烧效果会随着等级提升而增强基础伤害",
	"部分领悟内容有前置的解锁条件"
	# "墨宁是天衍宗最为优秀的少年弟子之一，擅长风系与轻功",
	# "墨宁虽然话不多，但内心良善，经常帮助宗门里的其他弟子与长辈"
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	Global.in_menu = false
	progressBar.max_value = 100.0
	# 播放当前角色的奔跑动画
	var anim_name = _get_character_anim_name()
	if animatedSprite2D.sprite_frames and animatedSprite2D.sprite_frames.has_animation(anim_name):
		animatedSprite2D.play(anim_name)
	else:
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

## 根据当前选中的角色返回对应的loading动画名（兼容sprite_frames中的命名差异）
func _get_character_anim_name() -> String:
	match PC.player_name:
		"moning":
			return "moning"
		"yiqiu":
			return "yanqiu"
		"noam":
			return "noam"
		"kansel":
			return "kansel"
		"xueming":
			return "xueming"
		_:
			return "moning"
