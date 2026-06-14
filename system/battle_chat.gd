extends Node
class_name BattleChat

## 战斗内动态对话系统
## 管理基于战斗状态（HP、击杀数、闲聊）的动态对话触发
##
## 触发条件：
## 1. 低体力：HP ≤ 20% 最大体力时，50% 概率触发，每局最多 2 次
## 2. 击杀里程碑：100/500/2000 只怪时，从已解锁角色中随机一个发言
## 3. 随机闲聊：20 秒无对话后触发（诗想难度不触发）
##
## 闲聊计时器规则：
## - 任何剧情/条件对话出现时，重置闲聊计时器
## - 闲聊序列完整结束后，才重新开始计时

# === 常量 ===
const BASE_DURATION: float = 1.5
const DURATION_PER_CHAR: float = 0.15
const IDLE_CHAT_INTERVAL: float = 20.0
const LOW_HP_THRESHOLD: float = 0.2
const LOW_HP_CHANCE: float = 0.5
const MAX_LOW_HP_TRIGGERS: int = 2
const SEQUENCE_DELAY: float = 0.5

# === 对话管理器引用 ===
var _dialogue_mgr: TeammateDialogueManager = null

# === 低体力触发状态 ===
var _low_hp_count: int = 0
var _prev_hp_ratio: float = 1.0

# === 击杀里程碑触发状态 ===
var _kill_100_triggered: bool = false
var _kill_500_triggered: bool = false
var _kill_2000_triggered: bool = false

# === 闲聊状态 ===
var _idle_timer: float = 0.0

# === 序列对话状态 ===
var _sequence_lines: Array = []
var _sequence_index: int = 0
var _sequence_wait: float = 0.0
var _sequence_active: bool = false

# === 初始化标志 ===
var _initialized: bool = false

# === 闲聊数据 ===
var _idle_chats: Array = []


func _ready() -> void:
	Global.connect("teammate_dialogue", Callable(self , "_on_any_teammate_dialogue"))
	_build_idle_chats()


## 初始化（由 base_stage 调用）
func initialize(dialogue_mgr: TeammateDialogueManager) -> void:
	_dialogue_mgr = dialogue_mgr
	_initialized = true
	_idle_timer = 0.0


func _process(delta: float) -> void:
	if not _initialized or PC.is_game_over:
		return
	if get_tree().paused:
		return

	_check_low_hp()
	_check_kill_milestones()
	_check_idle_chat(delta)
	_process_sequence(delta)


# ============================================================
# 低体力对话
# ============================================================

func _check_low_hp() -> void:
	if _low_hp_count >= MAX_LOW_HP_TRIGGERS:
		return
	if PC.pc_max_hp <= 0:
		return
	var hp_ratio = float(PC.pc_hp) / float(PC.pc_max_hp)
	if hp_ratio <= LOW_HP_THRESHOLD and _prev_hp_ratio > LOW_HP_THRESHOLD:
		if randf() < LOW_HP_CHANCE:
			_trigger_low_hp_dialogue()
			_low_hp_count += 1
	_prev_hp_ratio = hp_ratio


func _trigger_low_hp_dialogue() -> void:
	var unlocked = _get_unlocked_characters()
	if unlocked.is_empty():
		return
	var speaker = unlocked[randi() % unlocked.size()]
	var text = _get_low_hp_line(speaker)
	_push_single(speaker, text)


func _get_low_hp_line(speaker: String) -> String:
	match speaker:
		"言秋": return "唔……有点不妙！"
		"墨宁": return "小心！体力不多了！"
		"诺姆": return "要撑住啊！"
		"坎塞尔": return "……还没结束。"
		_: return "注意体力！"


# ============================================================
# 击杀里程碑对话
# ============================================================

func _check_kill_milestones() -> void:
	var kills = GU.kill_count
	if kills >= 100 and not _kill_100_triggered:
		_kill_100_triggered = true
		_trigger_kill_milestone(100)
	if kills >= 500 and not _kill_500_triggered:
		_kill_500_triggered = true
		_trigger_kill_milestone(500)
	if kills >= 2000 and not _kill_2000_triggered:
		_kill_2000_triggered = true
		_trigger_kill_milestone(2000)


func _trigger_kill_milestone(count: int) -> void:
	var unlocked = _get_unlocked_characters()
	if unlocked.is_empty():
		return
	var speaker = unlocked[randi() % unlocked.size()]
	var text = _get_kill_milestone_line(speaker, count)
	if text.is_empty():
		return
	# 角色台词 + 换行 + 系统提示
	text += "\n【已击败%d名敌人】" % count
	_push_single(speaker, text)


func _get_kill_milestone_line(speaker: String, count: int) -> String:
	match count:
		100:
			match speaker:
				"言秋": return "热身结束！"
				"墨宁": return "做的不错！"
				"诺姆": return "这么多敌人……"
				"坎塞尔": return "继续……"
		500:
			match speaker:
				"言秋": return "今天战果不错嘛！"
				"墨宁": return "呼……已经这么多了？"
				"诺姆": return "幻境中的以太越来越活跃了……"
				"坎塞尔": return "有些研究价值。"
		2000:
			match speaker:
				"言秋": return "还不够！"
				"墨宁": return "手都酸了……"
				"诺姆": return "以太逐渐狂暴了……"
				"坎塞尔": return "状态真是不错。"
	return ""


# ============================================================
# 随机闲聊
# ============================================================

func _check_idle_chat(delta: float) -> void:
	# 诗想难度不触发闲聊
	if Global.current_stage_difficulty == Global.STAGE_DIFFICULTY_POETRY:
		return
	# 序列对话进行中不触发新闲聊
	if _sequence_active:
		return

	_idle_timer += delta
	if _idle_timer >= IDLE_CHAT_INTERVAL:
		_trigger_idle_chat()


func _trigger_idle_chat() -> void:
	var available = _get_available_idle_chats()
	if available.is_empty():
		return
	var chat = available[randi() % available.size()]
	_start_dialogue_sequence(chat.lines)


func _get_available_idle_chats() -> Array:
	var result: Array[Dictionary] = []
	for chat in _idle_chats:
		if _is_chat_available(chat):
			result.append(chat)
	return result


func _is_chat_available(chat: Dictionary) -> bool:
	# 检查所有参与者是否已解锁
	for line in chat.lines:
		var speaker = line.speaker
		if speaker == "诺姆" and not Global.unlock_noam:
			return false
		if speaker == "坎塞尔" and not Global.unlock_kansel:
			return false
	# 检查桃林限定
	if chat.get("peach_grove_only", false) and Global.current_stage_id != "peach_grove":
		return false
	return true


# ============================================================
# 序列对话（多句对话，0.5秒间隔）
# ============================================================

func _start_dialogue_sequence(lines: Array) -> void:
	_sequence_lines = lines
	_sequence_index = 0
	_sequence_active = true
	_sequence_wait = 0.0
	_idle_timer = 0.0
	_push_sequence_line()


func _push_sequence_line() -> void:
	if _sequence_index >= _sequence_lines.size():
		_sequence_active = false
		return
	var line = _sequence_lines[_sequence_index]
	_push_single(line.speaker, line.text)
	# 计算当前行的显示时间，显示结束后等待 0.5 秒再推送下一句
	var text_len = line.text.length()
	var display_time = BASE_DURATION + text_len * DURATION_PER_CHAR
	_sequence_wait = display_time + SEQUENCE_DELAY
	_sequence_index += 1


func _process_sequence(delta: float) -> void:
	if not _sequence_active:
		return
	_sequence_wait -= delta
	if _sequence_wait <= 0.0:
		_push_sequence_line()


# ============================================================
# 工具方法
# ============================================================

func _push_single(speaker: String, text: String) -> void:
	if _dialogue_mgr and is_instance_valid(_dialogue_mgr):
		_dialogue_mgr.push_dialogue(speaker, text)
	_idle_timer = 0.0


## 任何队友对话信号都会重置闲聊计时
func _on_any_teammate_dialogue(_speaker: String, _text: String) -> void:
	_idle_timer = 0.0


func _get_unlocked_characters() -> Array[String]:
	var result: Array[String] = ["言秋", "墨宁"]
	if Global.unlock_noam:
		result.append("诺姆")
	if Global.unlock_kansel:
		result.append("坎塞尔")
	return result


# ============================================================
# 闲聊数据
# ============================================================

func _build_idle_chats() -> void:
	_idle_chats = [
		# ── 基础闲聊（仅需言秋、墨宁）──
		{
			"lines": [ {"speaker": "言秋", "text": "嘿嘿，本少主的剑意似乎更纯粹了一些！"}],
		},
		{
			"lines": [
				{"speaker": "言秋", "text": "墨宁，来聊聊天嘛，你不无聊吗？"},
				{"speaker": "墨宁", "text": "还好吧？平时修炼的时候不是更无聊吗？"},
				{"speaker": "言秋", "text": "切，也就是你总喜欢一天到晚的修炼了。"},
				{"speaker": "墨宁", "text": "……有实力才能保护其他人啊。"},
				{"speaker": "言秋", "text": "咦，墨宁你突然变得好严肃哦……"},
				{"speaker": "墨宁", "text": "没事没事，想起了什么不太好的事情罢了。"},
			],
		},
		{
			"lines": [ {"speaker": "墨宁", "text": "不知道外面的天色如何了……"}],
		},
		{
			"lines": [
				{"speaker": "墨宁", "text": "小秋，在东张西望什么呢？"},
				{"speaker": "言秋", "text": "那边地上好像怪物有掉了些什么……"},
				{"speaker": "墨宁", "text": "一会去拿，一会去拿。"},
			],
		},
		{
			"lines": [ {"speaker": "言秋", "text": "吃我一刀！看招看招！"}],
		},
		{
			"lines": [
				{"speaker": "墨宁", "text": "小秋，打累了要不要休息会？"},
				{"speaker": "言秋", "text": "你都没累，我我我……好吧，我稍微有点累了。"},
			],
		},
		{
			"lines": [ {"speaker": "言秋", "text": "哎呀，差点就砍歪了！"},
				{"speaker": "墨宁", "text": "你那一刀差点打到我身上……"},
			],
		},
		{
			"lines": [ {"speaker": "言秋", "text": "怎么还没打完啊，胳膊都酸了。"}],
		},
		{
			"lines": [
				{"speaker": "言秋", "text": "墨宁！你看我这招帅不帅！"},
				{"speaker": "墨宁", "text": "真不错！"},
				{"speaker": "言秋", "text": "嘿嘿……"},
			],
		},
		{
			"lines": [
				{"speaker": "墨宁", "text": "不知道我的小雀在镇子上怎么样了……"},
				{"speaker": "言秋", "text": "它不会自己飞跑吗？"},
				{"speaker": "墨宁", "text": "不会的，它灵智已经初开，会主动找我的。"},
				{"speaker": "言秋", "text": "哇，我也想养一只！"},
				{"speaker": "墨宁", "text": "你可以喊它也跟你一块玩嘛，不过别伤着它就好……"},
				{"speaker": "言秋", "text": "知道知道，我一定小心！"},
			],
		},
		{
			"lines": [
				{"speaker": "言秋", "text": "这敌人无穷无尽，我开始觉得下棋更好玩了。"},
				{"speaker": "墨宁", "text": "等一会战斗结束了我跟你回去下棋。"},
				{"speaker": "言秋", "text": "好耶，一言为定！"},
			],
		},
		{
			"lines": [
				{"speaker": "言秋", "text": "墨宁，你腰间挂的玉佩有啥用？"},
				{"speaker": "墨宁", "text": "就是天衍宗弟子的信物啊。"},
				{"speaker": "言秋", "text": "那长老们怎么有的人没带？"},
				{"speaker": "墨宁", "text": "……可能是觉得不好看？"},
				{"speaker": "言秋", "text": "这么随便的理由吗！"},
			],
		},
		{
			"lines": [
				{"speaker": "墨宁", "text": "小秋，你怎么能瞬间变成狗狗形态的？"},
				{"speaker": "言秋", "text": "那是狼，是狼！"},
				{"speaker": "墨宁", "text": "不是一只大黑狗吗？"},
				{"speaker": "言秋", "text": "哪里像狗了？我打你哦！"},
			],
		},
		{
			"lines": [
				{"speaker": "墨宁", "text": "也不知道这些精怪到底有没有自己的意识……"},
				{"speaker": "言秋", "text": "怎么在想这个？"},
				{"speaker": "墨宁", "text": "嗯……可能是有些不忍心？"},
				{"speaker": "言秋", "text": "你不忍心他们不会不忍心啊！受了重伤可不好！"},
				{"speaker": "言秋", "text": "我们最终的目标应该是拆掉这个幻境嘛。"},
				{"speaker": "言秋", "text": "这样他们就不会受到控制了呀。"},
				{"speaker": "墨宁", "text": "嗯……是我多想了。"},
			],
		},

		# ── 诺姆解锁后新增 ──
		{
			"lines": [
				{"speaker": "墨宁", "text": "诺姆，为何当时用石头人来攻击我们，白魔法也可以统御植物吧？"},
				{"speaker": "诺姆", "text": "嗯……因为我之前见到了桃树精王，如果再操控植物攻击人就显得我没什么特色了！"},
				{"speaker": "墨宁", "text": "……啊？"},
			],
		},
		{
			"lines": [
				{"speaker": "言秋", "text": "诺姆诺姆！"},
				{"speaker": "诺姆", "text": "怎么了？有什么事嘛？"},
				{"speaker": "言秋", "text": "就是觉得名字还挺好玩的……"},
				{"speaker": "诺姆", "text": "……呃，谢谢。"},
			],
		},
		{
			"lines": [
				{"speaker": "诺姆", "text": "墨宁，你的气功波的真气运作方式和白魔法里的风魔法真的很像哎！"},
				{"speaker": "墨宁", "text": "嗯，是有一些殊途同归。"},
				{"speaker": "诺姆", "text": "属兔……通规？什么意思？"},
				{"speaker": "墨宁", "text": "……就是虽然方法不同，最后结果相似。"},
				{"speaker": "诺姆", "text": "哦哦，你们的语言真是太复杂了……"},
			],
		},
		{
			"lines": [ {"speaker": "诺姆", "text": "打的衣服都脏了……好想回去洗衣服洗个澡……"}],
		},
		{
			"lines": [
				{"speaker": "诺姆", "text": "这里的怪物跟我们那边的差异好大啊……"},
				{"speaker": "墨宁", "text": "诺姆那边的精怪都长什么样？"},
				{"speaker": "诺姆", "text": "比如黏糊糊的史莱姆，挂着腐肉的骷髅人之类的？"},
				{"speaker": "言秋", "text": "噫，好恶心……"},
			],
		},

		# ── 坎塞尔解锁后新增 ──
		{
			"lines": [ {"speaker": "坎塞尔", "text": "吸收了这么多以太，黑魔法的力量都变强了，这种感觉有点令人着迷……"}],
		},
		{
			"lines": [ {"speaker": "坎塞尔", "text": "在幻境里的魔法力量居然提升的这么快，掌控这么强大的力量的感觉真是危险……"}],
		},
		{
			"lines": [
				{"speaker": "诺姆", "text": "唔……突然有些怀念之前在魔法学院时候的日子。"},
				{"speaker": "坎塞尔", "text": "嗯？"},
				{"speaker": "诺姆", "text": "那时候感觉还没那么复杂，现在这样……我有些讨厌。"},
				{"speaker": "坎塞尔", "text": "还有我呢。"},
				{"speaker": "诺姆", "text": "……嗯。"},
			],
		},

		# ── 桃林关卡专属 ──
		{
			"lines": [ {"speaker": "言秋", "text": "喂！那边的树叶精，看什么看！"}],
			"peach_grove_only": true,
		},
		{
			"lines": [ {"speaker": "墨宁", "text": "这些精怪的动作都有规律，看仔细了。"}],
			"peach_grove_only": true,
		},
		{
			"lines": [
				{"speaker": "墨宁", "text": "这桃林的布局，似乎暗合某种古老的阵法……"},
				{"speaker": "言秋", "text": "你还懂这个？"},
				{"speaker": "墨宁", "text": "是啊，我是巽长老门下的弟子，当然会学些阵法的知识。"},
				{"speaker": "言秋", "text": "真厉害！"},
			],
			"peach_grove_only": true,
		},
		{
			"lines": [
				{"speaker": "言秋", "text": "周围的桃花香气似乎变淡了……"},
				{"speaker": "墨宁", "text": "嗯……可能是被我的风系法术吹散了吧？"},
				{"speaker": "言秋", "text": "正好闻的有些腻啦！"},
			],
			"peach_grove_only": true,
		},
	]
