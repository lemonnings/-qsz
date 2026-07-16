extends RefCounted
class_name TownCompanionDialogue

## 城镇同伴对话数据与转换工具。
##
## DIALOGS 的 key 使用“当前操控角色_to_目标角色_随机编号”：
##   noam_to_yanqiu_1
##   noam_to_yanqiu_2
##
## 每组可以写多行。speaker 填内部名或中文名均可：
##   moning / yanqiu / yiqiu / noam / kansel
##   墨宁 / 言秋 / 诺姆 / 坎塞尔
##
## 运行时会转换成 normal_dialog.tscn / dialog_manager.gd 使用的完整 Dictionary 格式。

const HERO_DISPLAY_NAMES := {
	"moning": "墨宁",
	"yiqiu": "言秋",
	"noam": "诺姆",
	"kansel": "坎塞尔",
	"xueming": "雪铭",
}

const HERO_PORTRAITS := {
	"moning": "res://AssetBundle/Sprites/npc/moning_full.png",
	"yiqiu": "res://AssetBundle/Sprites/npc/yanqiu_full.png",
	"noam": "res://AssetBundle/Sprites/npc/noam_full.png",
	"kansel": "res://AssetBundle/Sprites/npc/kansel.png",
	"xueming": "res://AssetBundle/Sprites/town/xueming.png",
}

const HERO_KEY_ALIASES := {
	"moning": "moning",
	"墨宁": "moning",
	"yiqiu": "yiqiu",
	"yanqiu": "yiqiu",
	"言秋": "yiqiu",
	"noam": "noam",
	"诺姆": "noam",
	"kansel": "kansel",
	"坎塞尔": "kansel",
	"xueming": "xueming",
	"雪铭": "xueming",
}

const HERO_DIALOG_KEY_NAMES := {
	"moning": "moning",
	"yiqiu": "yanqiu",
	"noam": "noam",
	"kansel": "kansel",
	"xueming": "xueming",
}

const TOWN_NPC_DISPLAY_NAMES := {
	"kan": "坎",
	"kun": "坤",
	"qian": "乾",
	"xun": "巽",
	"bard": "异国诗人",
}

const TOWN_NPC_PORTRAITS := {
	"kan": "res://AssetBundle/Sprites/npc/kan.png",
	"kun": "res://AssetBundle/Sprites/npc/kun.png",
	"qian": "res://AssetBundle/Sprites/npc/qian_full.png",
	"xun": "res://AssetBundle/Sprites/npc/xun_full.png",
	"bard": "res://AssetBundle/Sprites/npc/bard.png",
}

const TOWN_NPC_KEY_ALIASES := {
	"kan": "kan",
	"坎": "kan",
	"merchant": "kan",
	"kun": "kun",
	"坤": "kun",
	"levelUpMan2": "kun",
	"levelupman2": "kun",
	"qian": "qian",
	"乾": "qian",
	"cystal": "qian",
	"crystal": "qian",
	"xun": "xun",
	"巽": "xun",
	"levelUpMan": "xun",
	"levelupman": "xun",
	"bard": "bard",
	"poet": "bard",
	"异国诗人": "bard",
}

const TOWN_NPC_DIALOGS := {
	"npc_kan_1": [
		{"dialog": "今日铺子开张，灵石、材料、丹药都擦得亮亮的!"},
	],
	"npc_kan_2": [
		{"dialog": "我卖的东西贵吗？不贵不贵，贵的是机缘啦~"},
	],
	"npc_kan_3": [
		{"dialog": "宗门里总要有人会讲价，不然长老们只会把好材料全拿去炼丹布阵了……"},
		{"dialog": "真是好辛苦呀，下个月不会又要收支不平衡了吧~"},
	],
	"npc_kan_4": [
		{"dialog": "这些货都来路正当……大概？"},
		{"dialog": "咳，总之我会把每一笔都记进宗门账里！"},
	],
	"npc_kan_5": [
		{"dialog": "怎么才能多赚点钱呢……不如你直接把钱给我点儿吧？嘿嘿~"},
	],
	"npc_kun_1": [
		{"dialog": "天赋修炼讲究顺势而为，根基稳了，后面的路才不易偏。"},
	],
	"npc_kun_2": [
		{"dialog": "修行急不得。当下每多打坐修行一刻，未来便可少走一步弯路。"},
	],
	"npc_kun_3": [
		{"dialog": "能走多远，还要看心性。"},
	],
	"npc_qian_1": [
		{"dialog": "天衍宗弟子，当先明己身，再论破局之法。"},
	],
	"npc_qian_2": [
		{"dialog": "强者不可只恃锋芒。越是危局，越要把每一步看清楚。"},
	],
	"npc_qian_3": [
		{"dialog": "阵外风波未止，宗门中人更该守住心神。"},
		{"dialog": "心不乱，剑与阵才不会乱。"},
	],
	"npc_xun_1": [
		{"dialog": "轻功并不是用来一味的躲避攻击的，而是在风暴前先找到落脚之处，以及……破局之处。"},
	],
	"npc_xun_2": [
		{"dialog": "阵法之妙，不在图案繁复，而在于能借来多少天地灵气相助，这一点上就算是我也还得继续学习精进呐。"},
	],
	"npc_xun_3": [
		{"dialog": "墨宁那孩子心思细……但是出手却还不够果断。"},
	],
	"npc_bard_1": [
		{"dialog": "我来自很远的海那边……那里的人把苦难写进歌里，再唱给明天听。"},
	],
	"npc_bard_2": [
		{"dialog": "诗想……是把英雄带到传说边缘的诗歌，可要做足准备了哦。"},
	],
	"npc_bard_3": [
		{"dialog": "我被大家称作异国的诗人，在此歌颂这片土地上的英雄事迹。"},
	],
}

const DIALOGS := {
	"moning_to_yanqiu_1": [
		{"speaker": "moning", "dialog": "小秋还适应幻境中的战斗吗？"},
		{"speaker": "yanqiu", "dialog": "那当然，别小看我！"},
		{"speaker": "moning", "dialog": "我不是小看你，只是里面的真气越来越混乱了。"},
		{"speaker": "yanqiu", "dialog": "知道啦知道啦，快支撑不住的时候我会捏传送符的。"},
	],
	"moning_to_yanqiu_2": [
		{"speaker": "moning", "dialog": "你上次说打坐很无聊，今天有认真修习吗？"},
		{"speaker": "yanqiu", "dialog": "认真了！我认真地无聊了整整一炷香！"},
		{"speaker": "moning", "dialog": "……那也算进步吧。"},
	],
	"moning_to_noam_1": [
		{"speaker": "moning", "dialog": "小诺姆，今天还有哪里不舒服吗？这里的真气和你说的奥术不太一样。"},
		{"speaker": "noam", "dialog": "嗯……有一点点晕，不过比刚来的时候好多了。"},
		{"speaker": "moning", "dialog": "有不适就告诉我们，不要一个人硬撑。"},
	],
	"moning_to_noam_2": [
		{"speaker": "moning", "dialog": "你那个翻译魔法很厉害，原理是什么？"},
		{"speaker": "noam", "dialog": "本来是和动物沟通用的，我只是稍微改了一点点……大概。"},
		{"speaker": "moning", "dialog": "稍微一点点就能让不同语言互通？罗穆阿尔多的魔法真奇妙。"},
	],
	"moning_to_noam_3": [
		{"speaker": "moning", "dialog": "如果想家了，可以不用勉强装作没事。"},
		{"speaker": "noam", "dialog": "我、我才没有装作没事……只是大家都在努力，我也想帮上忙。"},
		{"speaker": "moning", "dialog": "嗯，那我们一起想办法。"},
	],
	"moning_to_kansel_1": [
		{"speaker": "moning", "dialog": "坎塞尔，你说的位面裂缝，我还是有很多地方没听懂。"},
		{"speaker": "kansel", "dialog": "正常。若用你们的说法……它更接近一种失控的跨界大阵。"},
		{"speaker": "moning", "dialog": "这么厉害！之后能再教我一些吗？"},
	],
	"moning_to_kansel_2": [
		{"speaker": "moning", "dialog": "你一个人调查到现在，应该很累吧。"},
		{"speaker": "kansel", "dialog": "累并不是停下的理由。只是现在……可能确实需要同伴。"},
		{"speaker": "moning", "dialog": "好！那就别再什么都自己扛着了。"},
	],
	"moning_to_kansel_3": [
		{"speaker": "moning", "dialog": "诺姆其实很在意你。"},
		{"speaker": "kansel", "dialog": "我知道。所以我更不能再让他失望。"},
		{"speaker": "moning", "dialog": "或许可以……从少说些吓人的复杂理论开始？"},
		{"speaker": "kansel", "dialog": "……呃，我会尝试。"},
	],
	"yanqiu_to_moning_1": [
		{"speaker": "yanqiu", "dialog": "墨宁，我们什么时候再进幻境？我感觉今天手感特别好！"},
		{"speaker": "moning", "dialog": "先检查传送符，再补充丹药。"},
		{"speaker": "yanqiu", "dialog": "你看，你又开始唠叨了。"},
		{"speaker": "moning", "dialog": "这是准备，不是唠叨。"},
	],
	"yanqiu_to_moning_2": [
		{"speaker": "yanqiu", "dialog": "上次那个机关鸟真是你修坏的吗？"},
		{"speaker": "moning", "dialog": "……那是意外。"},
		{"speaker": "yanqiu", "dialog": "我就问一句，你怎么脸都红了！"},
	],
	"yanqiu_to_moning_3": [
		{"speaker": "yanqiu", "dialog": "墨宁，你要是累了就说，我可以站前面。"},
		{"speaker": "moning", "dialog": "你站前面可以，但不要一兴奋就冲出阵形。"},
		{"speaker": "yanqiu", "dialog": "好啦，我会看着你的位置再冲的！"},
		{"speaker": "moning", "dialog": "……这听起来并没有放心多少。"},
	],
	"yanqiu_to_noam_1": [
		{"speaker": "yanqiu", "dialog": "诺姆，你们那边真的会骑着扫帚飞吗？"},
		{"speaker": "noam", "dialog": "我、我不会！那是很危险的飞行训练。"},
		{"speaker": "yanqiu", "dialog": "听起来好玩！"},
		{"speaker": "noam", "dialog": "重点是危险啦！"},
	],
	"yanqiu_to_noam_2": [
		{"speaker": "yanqiu", "dialog": "说起来你别老道歉嘛，我们现在不是同伴了吗？"},
		{"speaker": "noam", "dialog": "嗯……可是之前我确实误会你们了。"},
		{"speaker": "yanqiu", "dialog": "那你下次战斗多给我套几个白魔法，就算扯平啦！"},
	],
	"yanqiu_to_noam_3": [
		{"speaker": "yanqiu", "dialog": "小诺姆，你个子小小的，胆子倒是不小嘛。"},
		{"speaker": "noam", "dialog": "我、我不是小小的！我只是还会长高！"},
		{"speaker": "yanqiu", "dialog": "好好好，未来的个子小小的大白魔法师！"},
		{"speaker": "noam", "dialog": "怎么听着还是不太对……？"},
	],
	"yanqiu_to_kansel_1": [
		{"speaker": "yanqiu", "dialog": "坎塞尔，你之前把诺姆弄哭这件事，我可还记着呢。"},
		{"speaker": "kansel", "dialog": "我不会辩解。那确实是我的错。"},
		{"speaker": "yanqiu", "dialog": "知道就好。以后要是再让他难过……揍你哦！"},
	],
	"yanqiu_to_kansel_2": [
		{"speaker": "yanqiu", "dialog": "你那些火冰雷魔法，能不能教我一招？听起来很威风。"},
		{"speaker": "kansel", "dialog": "你的力量体系与以太回路不同，直接照搬很危险。"},
		{"speaker": "yanqiu", "dialog": "啧，怎么你也和墨宁一样，一开口就是危险。"},
	],
	"yanqiu_to_kansel_3": [
		{"speaker": "yanqiu", "dialog": "你说话总是绕好大一圈。"},
		{"speaker": "kansel", "dialog": "我习惯先说明前提。"},
		{"speaker": "yanqiu", "dialog": "下次先说结论！比如敌人在哪，能不能打。"},
		{"speaker": "kansel", "dialog": "……这个建议很实用。"},
	],
	"noam_to_moning_1": [
		{"speaker": "noam", "dialog": "墨宁，你们修炼的时候真的要一直打坐吗？"},
		{"speaker": "moning", "dialog": "大多数时候是这样，静下心才能炼化真气。"},
		{"speaker": "noam", "dialog": "听起来比背魔法咒文还难……"},
	],
	"noam_to_moning_2": [
		{"speaker": "noam", "dialog": "谢谢你那时候愿意相信我。"},
		{"speaker": "moning", "dialog": "你愿意解释，我们当然也该听。"},
		{"speaker": "noam", "dialog": "嗯！我以后也会先听清楚，再决定要不要动手。"},
	],
	"noam_to_moning_3": [
		{"speaker": "noam", "dialog": "小诺姆这个称呼……能不能换一个？"},
		{"speaker": "moning", "dialog": "抱歉，是我叫顺口了。那直接叫诺姆？"},
		{"speaker": "noam", "dialog": "嗯！这样比较像正式的皇家白魔法师预备役！"},
		{"speaker": "moning", "dialog": "这有很大的区别吗……"},
		{"speaker": "noam", "dialog": "那当然啦！你才比我大……3岁？不能叫我小诺姆~"},
	],
	"noam_to_yanqiu_1": [
		{"speaker": "noam", "dialog": "言秋，你战斗的时候不害怕吗？"},
		{"speaker": "yanqiu", "dialog": "害怕也要打呀，打赢了就不怕了！"},
		{"speaker": "noam", "dialog": "这、这是什么很厉害的……内功吗？"},
		{"speaker": "yanqiu", "dialog": "不是，这是经验，哼哼！"},
	],
	"noam_to_yanqiu_2": [
		{"speaker": "noam", "dialog": "你说我长得很奇怪……现在还觉得奇怪吗？"},
		{"speaker": "yanqiu", "dialog": "还是有点，不过是很容易认出来的那种奇怪！"},
		{"speaker": "noam", "dialog": "这听起来也不像夸奖……"},
		{"speaker": "yanqiu", "dialog": "说你长得好看~！"},
		{"speaker": "noam", "dialog": "咦、咦！？"},
	],
	"noam_to_yanqiu_3": [
		{"speaker": "noam", "dialog": "言秋，你能不能教我怎么更勇敢一点？"},
		{"speaker": "yanqiu", "dialog": "简单！先把大喊出来自己的招式，然后就往前冲！"},
		{"speaker": "noam", "dialog": "我觉得墨宁听到会阻止我们，并且说这样很蠢……"},
		{"speaker": "yanqiu", "dialog": "切，所以我在偷偷练啦~要不要一起？"},
	],
	"noam_to_kansel_1": [
		{"speaker": "noam", "dialog": "坎塞尔，你以后不会再突然攻击我了吧？"},
		{"speaker": "kansel", "dialog": "不会。我向你保证。"},
		{"speaker": "noam", "dialog": "那、那我就暂时相信你吧……"},
		{"speaker": "kansel", "dialog": "…………嗯。"},
	],
	"noam_to_kansel_2": [
		{"speaker": "noam", "dialog": "你以前教我的那个魔力回路，我现在还记得。"},
		{"speaker": "kansel", "dialog": "我看得出来。你的施法稳定了很多。"},
		{"speaker": "noam", "dialog": "哼，那当然，我也不是一直只会被你带着玩的小孩了。"},
	],
	"noam_to_kansel_3": [
		{"speaker": "noam", "dialog": "如果真的能回去……你会和我一起回罗穆阿尔多吗？"},
		{"speaker": "kansel", "dialog": "如果还有回去的路，我会先确保你能安全回家。"},
		{"speaker": "noam", "dialog": "喂，我问的是你要不要和我一起回家！"},
		{"speaker": "kansel", "dialog": "嗯……到那时，我会给你一个答案。"},
	],
	"kansel_to_moning_1": [
		{"speaker": "kansel", "dialog": "墨宁，你对阵法的感知很敏锐啊。"},
		{"speaker": "moning", "dialog": "嘿嘿，我只是按师父教的方法观察真气流向。"},
		{"speaker": "kansel", "dialog": "在我的世界，这已经足以称作优秀的现场判断。"},
		{"speaker": "moning", "dialog": "这样的吗……谢谢夸奖！"},
	],
	"kansel_to_moning_2": [
		{"speaker": "kansel", "dialog": "在战斗中……你似乎总是先确认退路，再决定是否前进？"},
		{"speaker": "moning", "dialog": "因为大家的安全更重要。"},
		{"speaker": "kansel", "dialog": "嗯……确实，我以前缺少的正是这种判断。"},
	],
	"kansel_to_moning_3": [
		{"speaker": "kansel", "dialog": "若有机会，我想请教你们天衍宗的修炼体系。"},
		{"speaker": "moning", "dialog": "我能讲的不多……不过基础吐纳和真气运转可以试着说明一下！"},
		{"speaker": "kansel", "dialog": "足够了。跨体系比较往往从基础开始。"},
		{"speaker": "moning", "dialog": "好哦，那晚上有空你可以找我？"},
	],
	"kansel_to_yanqiu_1": [
		{"speaker": "kansel", "dialog": "言秋，你的战斗直觉很强，但……风险控制近乎没有。"},
		{"speaker": "yanqiu", "dialog": "这句话听着像夸我，又不像夸我。"},
		{"speaker": "kansel", "dialog": "嗯……前半句是夸奖，后半句是提醒。"},
		{"speaker": "yanqiu", "dialog": "好吧……"},
	],
	"kansel_to_yanqiu_2": [
		{"speaker": "kansel", "dialog": "如果你愿意，我可以帮你分析敌人的攻击模式。"},
		{"speaker": "yanqiu", "dialog": "分析完能打得更快吗？"},
		{"speaker": "kansel", "dialog": "通常可以。"},
		{"speaker": "yanqiu", "dialog": "那你早说嘛！"},
	],
	"kansel_to_yanqiu_3": [
		{"speaker": "kansel", "dialog": "你似乎很擅长让气氛变轻松。"},
		{"speaker": "yanqiu", "dialog": "总不能大家都板着脸吧？那也太闷了。"},
		{"speaker": "kansel", "dialog": "在长期危机中，这也是一种重要能力。"},
		{"speaker": "yanqiu", "dialog": "哼哼，终于听出来你是在夸我了。"},
	],
	"kansel_to_noam_1": [
		{"speaker": "kansel", "dialog": "诺姆，你的白魔法别再为了省魔力而压到最低输出。受伤的人需要稳定治疗。"},
		{"speaker": "noam", "dialog": "你、你怎么又开始像老师一样说话了。"},
		{"speaker": "kansel", "dialog": "抱歉。只是习惯了。"},
	],
	"kansel_to_noam_2": [
		{"speaker": "kansel", "dialog": "你已经能独立判断战况了，比我记忆里成长了很多。"},
		{"speaker": "noam", "dialog": "那当然！我现在可是和大家一起战斗的同伴。"},
		{"speaker": "kansel", "dialog": "嗯。我很高兴听你这么说。"},
	],
	"kansel_to_noam_3": [
		{"speaker": "kansel", "dialog": "关于过去的事，我欠你很多解释。"},
		{"speaker": "noam", "dialog": "那你以后就慢慢解释。不要再一个人消失那么久。"},
		{"speaker": "kansel", "dialog": "我会尽量做到。"},
		{"speaker": "noam", "dialog": "不是尽量，是一定要做到。"},
		{"speaker": "kansel", "dialog": "……好。"},
	],
}

static func get_random_dialog(current_hero: String, target_hero: String) -> Array:
	var current_key := normalize_hero_key(current_hero)
	var target_key := normalize_hero_key(target_hero)
	if current_key.is_empty() or target_key.is_empty() or current_key == target_key:
		return []

	var prefix := "%s_to_%s_" % [_get_dialog_key_name(current_key), _get_dialog_key_name(target_key)]
	var candidates: Array[String] = []
	for dialog_key in DIALOGS.keys():
		var key_text := str(dialog_key)
		if key_text.begins_with(prefix):
			candidates.append(key_text)

	if candidates.is_empty():
		return _build_dialog(_get_fallback_dialog(current_key, target_key), current_key, target_key)

	var selected_key := _pick_dialog_key_without_repeat(prefix, candidates)
	return _build_dialog(DIALOGS[selected_key], current_key, target_key)

static func get_random_npc_dialog(npc_id: String) -> Array:
	var npc_key := normalize_town_npc_key(npc_id)
	if npc_key.is_empty():
		return []

	var prefix := "npc_%s_" % npc_key
	var candidates: Array[String] = []
	for dialog_key in TOWN_NPC_DIALOGS.keys():
		var key_text := str(dialog_key)
		if key_text.begins_with(prefix):
			candidates.append(key_text)

	if candidates.is_empty():
		return []

	var selected_key := _pick_dialog_key_without_repeat(prefix, candidates)
	return _build_npc_dialog(TOWN_NPC_DIALOGS[selected_key], npc_key)

static func normalize_hero_key(hero_key: String) -> String:
	var text := hero_key.strip_edges()
	if HERO_KEY_ALIASES.has(text):
		return HERO_KEY_ALIASES[text]
	var lower_text := text.to_lower()
	if HERO_KEY_ALIASES.has(lower_text):
		return HERO_KEY_ALIASES[lower_text]
	return ""

static func normalize_town_npc_key(npc_id: String) -> String:
	var text := npc_id.strip_edges()
	if TOWN_NPC_KEY_ALIASES.has(text):
		return TOWN_NPC_KEY_ALIASES[text]
	var lower_text := text.to_lower()
	if TOWN_NPC_KEY_ALIASES.has(lower_text):
		return TOWN_NPC_KEY_ALIASES[lower_text]
	return ""

static func get_display_name(hero_key: String) -> String:
	var normalized_key := normalize_hero_key(hero_key)
	return str(HERO_DISPLAY_NAMES.get(normalized_key, hero_key))

static func _get_dialog_key_name(hero_key: String) -> String:
	return str(HERO_DIALOG_KEY_NAMES.get(hero_key, hero_key))

static func _get_portrait(hero_key: String) -> String:
	return str(HERO_PORTRAITS.get(hero_key, ""))

static func _get_npc_display_name(npc_key: String) -> String:
	return str(TOWN_NPC_DISPLAY_NAMES.get(npc_key, npc_key))

static func _get_npc_portrait(npc_key: String) -> String:
	return str(TOWN_NPC_PORTRAITS.get(npc_key, ""))

static func _get_fallback_dialog(current_key: String, target_key: String) -> Array:
	var key_name := "%s_to_%s_1" % [_get_dialog_key_name(current_key), _get_dialog_key_name(target_key)]
	return [
		{
			"speaker": target_key,
			"dialog": "（待补充：" + key_name + "）",
		}
	]

static func _pick_dialog_key_without_repeat(prefix: String, candidates: Array[String]) -> String:
	var history: Dictionary = {}
	if typeof(Global) != TYPE_NIL and Global != null and typeof(Global.town_companion_dialogue_history) == TYPE_DICTIONARY:
		history = Global.town_companion_dialogue_history

	var used_raw = history.get(prefix, [])
	var used: Array[String] = []
	if typeof(used_raw) == TYPE_ARRAY:
		for key in used_raw:
			var key_text := str(key)
			if candidates.has(key_text) and not used.has(key_text):
				used.append(key_text)

	var remaining: Array[String] = []
	for candidate in candidates:
		if not used.has(candidate):
			remaining.append(candidate)

	var pool := remaining if not remaining.is_empty() else candidates.duplicate()
	pool.shuffle()
	var selected_key := pool[0]

	if not remaining.is_empty():
		used.append(selected_key)
	history[prefix] = used
	if typeof(Global) != TYPE_NIL and Global != null:
		Global.town_companion_dialogue_history = history
		Global.save_game()
	return selected_key

static func _build_dialog(raw_rows: Array, current_key: String, target_key: String) -> Array:
	var dialog_data: Array = []
	for raw_row in raw_rows:
		if not (raw_row is Dictionary):
			continue
		var row: Dictionary = raw_row
		var speaker_key := normalize_hero_key(str(row.get("speaker", current_key)))
		if speaker_key.is_empty():
			speaker_key = current_key

		var left_speaking := speaker_key == current_key
		var right_speaking := speaker_key == target_key
		var speaker_position := str(row.get("speaker_position", ""))
		if speaker_position.is_empty():
			speaker_position = "right" if right_speaking else "left"

		var line := {
			"speaker": str(row.get("speaker_name", get_display_name(speaker_key))),
			"speaker2": str(row.get("speaker2", "")),
			"speaker_position": speaker_position,
			"illustrationLeft": str(row.get("illustrationLeft", _get_portrait(current_key))),
			"illustrationLeftStatus": bool(row.get("illustrationLeftStatus", left_speaking)),
			"illustrationMiddle": str(row.get("illustrationMiddle", "")),
			"illustrationMiddleStatus": bool(row.get("illustrationMiddleStatus", false)),
			"illustrationRight": str(row.get("illustrationRight", _get_portrait(target_key))),
			"illustrationRightStatus": bool(row.get("illustrationRightStatus", right_speaking)),
			"dialog": str(row.get("dialog", row.get("text", ""))),
		}

		for extra_key in row.keys():
			if extra_key in ["speaker", "speaker_name", "text", "dialog"]:
				continue
			line[extra_key] = row[extra_key]

		dialog_data.append(line)

	return dialog_data

static func _build_npc_dialog(raw_rows: Array, npc_key: String) -> Array:
	var dialog_data: Array = []
	var display_name := _get_npc_display_name(npc_key)
	var portrait := _get_npc_portrait(npc_key)
	for raw_row in raw_rows:
		if not (raw_row is Dictionary):
			continue
		var row: Dictionary = raw_row
		var line := {
			"speaker": str(row.get("speaker_name", display_name)),
			"speaker2": str(row.get("speaker2", "")),
			"speaker_position": str(row.get("speaker_position", "left")),
			"illustrationLeft": str(row.get("illustrationLeft", portrait)),
			"illustrationLeftStatus": bool(row.get("illustrationLeftStatus", true)),
			"illustrationMiddle": str(row.get("illustrationMiddle", "")),
			"illustrationMiddleStatus": bool(row.get("illustrationMiddleStatus", false)),
			"illustrationRight": str(row.get("illustrationRight", "")),
			"illustrationRightStatus": bool(row.get("illustrationRightStatus", false)),
			"dialog": str(row.get("dialog", row.get("text", ""))),
		}

		for extra_key in row.keys():
			if extra_key in ["speaker", "speaker_name", "text", "dialog"]:
				continue
			line[extra_key] = row[extra_key]

		dialog_data.append(line)

	return dialog_data
