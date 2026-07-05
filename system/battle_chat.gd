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
const EXTRA_HOLD_DURATION: float = 0.3
const IDLE_CHAT_INTERVAL: float = 20.0
const LOW_HP_THRESHOLD: float = 0.2
const LOW_HP_CHANCE: float = 0.5
const MAX_LOW_HP_TRIGGERS: int = 2
const SEQUENCE_DELAY: float = 0.5
const WEAPON_LEVEL_DIALOGUE_THRESHOLD: int = 15
const PROGRESS_DIALOGUE_MIN_INTERVAL: float = 5.0
const LAW_DIALOGUE_THRESHOLDS: Array = [12, 20, 26]

const WEAPON_LEVEL_PROPS: Array = [
	{"prop": "main_skill_swordQi", "name": "剑气诀"},
	{"prop": "main_skill_branch", "name": "仙枝"},
	{"prop": "main_skill_moyan", "name": "爆炎诀"},
	{"prop": "main_skill_riyan", "name": "赤曜"},
	{"prop": "main_skill_ringFire", "name": "离火诀"},
	{"prop": "main_skill_thunder", "name": "震雷诀"},
	{"prop": "main_skill_bloodwave", "name": "血气波"},
	{"prop": "main_skill_bloodboardsword", "name": "饮血刀"},
	{"prop": "main_skill_ice", "name": "冰刺术"},
	{"prop": "main_skill_thunder_break", "name": "天雷破"},
	{"prop": "main_skill_light_bullet", "name": "光弹"},
	{"prop": "main_skill_water", "name": "坎水诀"},
	{"prop": "main_skill_qiankun", "name": "乾坤双剑"},
	{"prop": "main_skill_xuanwu", "name": "玄武盾"},
	{"prop": "main_skill_xunfeng", "name": "巽风诀"},
	{"prop": "main_skill_genshan", "name": "艮山诀"},
	{"prop": "main_skill_duize", "name": "兑泽诀"},
	{"prop": "main_skill_holylight", "name": "圣光术"},
	{"prop": "main_skill_qigong", "name": "气功波"},
	{"prop": "main_skill_dragonwind", "name": "风龙杖"},
]

const LAW_LEVEL_PROPS: Array = [
	{"prop": "faze_blood_level", "name": "浴血法则"},
	{"prop": "faze_sword_level", "name": "刀剑法则"},
	{"prop": "faze_thunder_level", "name": "鸣雷法则"},
	{"prop": "faze_heal_level", "name": "愈疗法则"},
	{"prop": "faze_summon_level", "name": "御灵法则"},
	{"prop": "faze_shield_level", "name": "护佑法则"},
	{"prop": "faze_fire_level", "name": "炽焰法则"},
	{"prop": "faze_destroy_level", "name": "破坏法则"},
	{"prop": "faze_life_level", "name": "生灵法则"},
	{"prop": "faze_bullet_level", "name": "弹雨法则"},
	{"prop": "faze_wide_level", "name": "广域法则"},
	{"prop": "faze_bagua_level", "name": "八卦法则"},
	{"prop": "faze_treasure_level", "name": "宝器法则"},
	{"prop": "faze_chaos_level", "name": "混沌法则"},
	{"prop": "faze_skill_level", "name": "技艺法则"},
	{"prop": "faze_sixsense_level", "name": "六识法则"},
	{"prop": "faze_wind_level", "name": "啸风法则"},
]

const QI_VORTEX_DIALOGUES: Dictionary = {
	"言秋": [
		"灵气突然这么浓烈，冲过去看看有什么好东西~",
		"哇，这漩涡看着就像在催我们进去！",
		"灵气漩涡！别让它跑了，我闻到变强的味道了！",
	],
	"墨宁": [
		"灵气汇聚成漩，里面或许藏着一次机缘。",
		"漩涡成形了，靠近时稳住气息。",
	],
	"诺姆": [
		"灵气漩涡……那团能量好亮，像以太在自己旋转！",
		"这个漩涡不会把人吸进去吧？应该不会吧？",
		"如果能解析灵气漩涡的流向，也许能获得很有用的东西！",
	],
	"坎塞尔": [
		"灵气漩涡？高浓度能量聚合点，建议立刻利用。",
		"漩涡结构稳定，短时间内不会崩解。",
	],
}

const GOLD_BALL_DIALOGUES: Dictionary = {
	"言秋": [
		"金团团！别跑别跑，让我砍一下！",
		"那只金灿灿的家伙，一看就很值钱！",
		"快看快看，会掉好东西的东西出现了！",
	],
	"墨宁": [
		"金团团出现了，优先处理它。",
		"金团团的灵气反应很强，别让它溜走。",
		"集中一下，先把那团金光留下。",
	],
	"诺姆": [
		"那个金色的生物好可爱……但是要打吗？",
		"金团团！它身上的以太好浓，难怪你们都盯着它！",
	],
	"坎塞尔": [
		"金团团……？金色目标优先级上调。",
	],
}

const WEAPON_LEVEL_DIALOGUES: Dictionary = {
	"言秋": [
		"这门武器练到这个火候，终于有点像样了！",
		"接下来该轮到我大显身手啦！",
		"手感来了，继续继续！",
		"这武器现在顺手多了！",
		"嘿嘿，这下打起来更痛快了！",
	],
	"墨宁": [
		"武器的运用熟练到这个程度，战斗节奏会顺很多。",
		"这些武器领悟的积累会在之后派上用场。",
		"这武器现在好用多了！",
	],
	"诺姆": [
		"这件武器的以太回路变清晰了！",
		"这件武器……我能感觉到它在回应我。",
		"继续这样强化下去，说不定会出现新变化！",
	],
	"坎塞尔": [
		"武器强度已经抵达某个上限了……不，还能更高。",
		"武器强度这么高了……输出模型可以重新评估。",
		"看起来输出的稳定性提升了不少，值得继续投入。",
		"当前武器……已具备核心战斗价值。",
	],
}

const LAW_LEVEL_DIALOGUES: Dictionary = {
	"言秋": [
		"感觉周围的气都在帮我们打架，这就是法则的力量嘛！",
		"再多来积累一些法则，我看它们还怎么围上来！",
		"很好，这条法则越来越强了！",
	],
	"墨宁": [
		"法则层数似乎突破了，灵气流向正在改变。",
		"法则节点果然很关键……看起来威力会明显抬升。",
		"长老们说过法则彼此牵引，注意利用新的节奏。",
		"长老们说层数越高，越要稳住运转。",
		"很好，这条法则已经开始成势。",
	],
	"诺姆": [
		"这种法则的叠加，和魔法增幅很像！",
		"法则变强了……也就是能量纹路变复杂了，我得记下来！",
		"法则如果继续叠上去，会不会超过幻境承载？",
		"这就是你们说的法则共鸣吗？",
	],
	"坎塞尔": [
		"法则抵达关键层级。",
		"法则的增幅曲线开始抬升……继续观察。",
	],
}

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

# === 阈值对话状态 ===
var _weapon_level_dialogue_triggered: Dictionary = {}
var _law_level_dialogue_triggered: Dictionary = {}
var _progress_dialogue_queue: Array[Dictionary] = []
var _progress_dialogue_cooldown: float = 0.0


func _ready() -> void:
	var teammate_callable := Callable(self , "_on_any_teammate_dialogue")
	if not Global.is_connected("teammate_dialogue", teammate_callable):
		Global.connect("teammate_dialogue", teammate_callable)
	var reward_progress_callable := Callable(self , "_on_reward_progress_changed")
	if not Global.is_connected("level_up_selection_complete", reward_progress_callable):
		Global.connect("level_up_selection_complete", reward_progress_callable)
	if not LvUp.is_connected("qi_vortex_shop_reward_selected", reward_progress_callable):
		LvUp.connect("qi_vortex_shop_reward_selected", reward_progress_callable)
	_build_idle_chats()


## 初始化（由 base_stage 调用）
func initialize(dialogue_mgr: TeammateDialogueManager) -> void:
	_dialogue_mgr = dialogue_mgr
	_initialized = true
	_idle_timer = 0.0
	_capture_progress_dialogue_state()


func _process(delta: float) -> void:
	if not _initialized or PC.is_game_over:
		return
	if get_tree().paused:
		return

	_check_low_hp()
	_check_kill_milestones()
	var real_delta := _get_real_delta(delta)
	_check_idle_chat(real_delta)
	_process_sequence(real_delta)
	_process_progress_dialogue_queue(real_delta)


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
	if _is_boss_fight_active():
		_stop_idle_chat_sequence()
		return
	# 序列对话进行中不触发新闲聊
	if _sequence_active:
		return

	_idle_timer += delta
	if _idle_timer >= IDLE_CHAT_INTERVAL:
		_trigger_idle_chat()


func _trigger_idle_chat() -> void:
	if _is_boss_fight_active():
		_stop_idle_chat_sequence()
		return
	var available = _get_available_idle_chats()
	if available.is_empty():
		return
	var chat = available[randi() % available.size()]
	_start_dialogue_sequence(chat.lines)


func _is_boss_fight_active() -> bool:
	var parent_node := get_parent()
	if parent_node != null:
		var triggered = parent_node.get("boss_event_triggered")
		if typeof(triggered) == TYPE_BOOL and triggered:
			return true
	return get_tree().get_first_node_in_group("boss") != null


func _stop_idle_chat_sequence() -> void:
	_idle_timer = 0.0
	if _sequence_active:
		_sequence_lines.clear()
		_sequence_index = 0
		_sequence_wait = 0.0
		_sequence_active = false


func _get_available_idle_chats() -> Array:
	var result: Array[Dictionary] = []
	for chat in _idle_chats:
		if _is_chat_available(chat):
			result.append(chat)
	return result


func _is_chat_available(chat: Dictionary) -> bool:
	var stage_only := str(chat.get("stage_only", ""))
	if not stage_only.is_empty() and Global.current_stage_id != stage_only:
		return false
	# 检查所有参与者是否已解锁
	var available_speakers := _get_unlocked_characters()
	for line in chat.get("lines", []):
		var speaker := str(line.get("speaker", ""))
		if not available_speakers.has(speaker):
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
	var display_time = BASE_DURATION + text_len * DURATION_PER_CHAR + EXTRA_HOLD_DURATION
	_sequence_wait = display_time + SEQUENCE_DELAY
	_sequence_index += 1


func _process_sequence(delta: float) -> void:
	if not _sequence_active:
		return
	_sequence_wait -= delta
	if _sequence_wait <= 0.0:
		_push_sequence_line()


# ============================================================
# 战斗事件对话
# ============================================================

func notify_qi_vortex_spawned() -> void:
	_trigger_random_single_dialogue(QI_VORTEX_DIALOGUES)


func notify_gold_ball_spawned() -> void:
	_trigger_random_single_dialogue(GOLD_BALL_DIALOGUES)


func check_progress_dialogue_triggers() -> void:
	_check_weapon_level_dialogue()
	_check_law_level_dialogue()


func _on_reward_progress_changed(_viewport: Viewport = null) -> void:
	check_progress_dialogue_triggers()


func _check_weapon_level_dialogue() -> void:
	for data in WEAPON_LEVEL_PROPS:
		var prop := str(data.get("prop", ""))
		if prop.is_empty():
			continue
		if _weapon_level_dialogue_triggered.get(prop, false):
			continue
		var level := _get_pc_int(prop)
		if level >= WEAPON_LEVEL_DIALOGUE_THRESHOLD:
			_weapon_level_dialogue_triggered[prop] = true
			var weapon_name := str(data.get("name", "武器"))
			_queue_progress_dialogue(WEAPON_LEVEL_DIALOGUES, weapon_name)


func _check_law_level_dialogue() -> void:
	for data in LAW_LEVEL_PROPS:
		var prop := str(data.get("prop", ""))
		if prop.is_empty():
			continue
		var level := _get_pc_int(prop)
		for threshold in LAW_DIALOGUE_THRESHOLDS:
			var threshold_value := int(threshold)
			var key := "%s:%d" % [prop, threshold_value]
			if _law_level_dialogue_triggered.get(key, false):
				continue
			if level >= threshold_value:
				_law_level_dialogue_triggered[key] = true
				var law_name := str(data.get("name", "法则"))
				_queue_progress_dialogue(LAW_LEVEL_DIALOGUES, "%s%d层" % [law_name, threshold_value])


func _queue_progress_dialogue(lines_by_speaker: Dictionary, context_text: String = "") -> void:
	_progress_dialogue_queue.append({
		"lines_by_speaker": lines_by_speaker,
		"context_text": context_text,
	})


func _process_progress_dialogue_queue(delta: float) -> void:
	if _progress_dialogue_cooldown > 0.0:
		_progress_dialogue_cooldown = max(0.0, _progress_dialogue_cooldown - delta)
	if _progress_dialogue_cooldown > 0.0:
		return
	if _progress_dialogue_queue.is_empty():
		return
	if _sequence_active:
		return
	var entry: Dictionary = _progress_dialogue_queue.pop_front()
	var lines_by_speaker: Dictionary = entry.get("lines_by_speaker", {}) as Dictionary
	var context_text := str(entry.get("context_text", ""))
	_trigger_random_single_dialogue(lines_by_speaker, context_text)
	_progress_dialogue_cooldown = PROGRESS_DIALOGUE_MIN_INTERVAL


func _capture_progress_dialogue_state() -> void:
	_weapon_level_dialogue_triggered.clear()
	_law_level_dialogue_triggered.clear()
	for data in WEAPON_LEVEL_PROPS:
		var weapon_prop := str(data.get("prop", ""))
		if weapon_prop.is_empty():
			continue
		if _get_pc_int(weapon_prop) >= WEAPON_LEVEL_DIALOGUE_THRESHOLD:
			_weapon_level_dialogue_triggered[weapon_prop] = true
	for data in LAW_LEVEL_PROPS:
		var law_prop := str(data.get("prop", ""))
		if law_prop.is_empty():
			continue
		var law_level := _get_pc_int(law_prop)
		for threshold in LAW_DIALOGUE_THRESHOLDS:
			var threshold_value := int(threshold)
			if law_level >= threshold_value:
				_law_level_dialogue_triggered["%s:%d" % [law_prop, threshold_value]] = true


func _trigger_random_single_dialogue(lines_by_speaker: Dictionary, context_text: String = "") -> void:
	var speakers := _get_available_event_speakers(lines_by_speaker)
	if speakers.is_empty():
		return
	var speaker := speakers[randi() % speakers.size()]
	var lines: Array = lines_by_speaker.get(speaker, [])
	if lines.is_empty():
		return
	var text := str(lines[randi() % lines.size()])
	if not context_text.is_empty():
		text = "【%s】\n%s" % [context_text, text]
	_push_single(speaker, text)


func _get_available_event_speakers(lines_by_speaker: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for speaker in _get_unlocked_characters():
		if lines_by_speaker.has(speaker):
			var lines: Array = lines_by_speaker.get(speaker, [])
			if not lines.is_empty():
				result.append(speaker)
	return result


func _get_pc_int(prop: String) -> int:
	if prop.is_empty():
		return 0
	var value: Variant = PC.get(prop)
	if value == null:
		return 0
	return int(value)


func _get_real_delta(delta: float) -> float:
	return delta / max(Engine.time_scale, 0.001)


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
	if Global.current_stage_id == "ruin":
		return result
	if Global.unlock_noam:
		result.append("诺姆")
	if Global.current_stage_id == "cave":
		return result
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
				{"speaker": "言秋", "text": "咦！对不起对不起！"},
				{"speaker": "墨宁", "text": "……其实已经习惯了。"},
			],
		},
		{
			"lines": [ {"speaker": "言秋", "text": "怎么还没打完啊，胳膊都酸了。"}],
		},
		{
			"lines": [ {"speaker": "墨宁", "text": "这里面的气息真令我不舒服……"}],
		},
		{
			"lines": [ {"speaker": "墨宁", "text": "这里都是些狂暴的真气四处流窜，那些精怪似乎都没了自己的意识。"}],
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
				{"speaker": "墨宁", "text": "嗯……你说得对哦，是我多想了。"},
			],
		},
		{
			"lines": [
				{"speaker": "墨宁", "text": "小秋，你别只顾着追最近的敌人呀，先看周围有没有被围住。"},
				{"speaker": "言秋", "text": "哎呀，知道知道，我眼睛和耳朵可灵着呢。"},
				{"speaker": "墨宁", "text": "嗯……你上次也是这么说的，然后一头扎进了怪堆里。"},
				{"speaker": "言秋", "text": "呃……嗯……那是它们围得太快了！"},
			],
		},
		{
			"lines": [
				{"speaker": "墨宁", "text": "幻境似乎会记录我们的战斗方式，后面的敌人可能会越来越难缠。"},
				{"speaker": "言秋", "text": "那我们就多换换套路嘛！它总不能什么都学会吧？"},
			],
		},
		{
			"lines": [
				{"speaker": "言秋", "text": "等回镇子上，我要吃两碗热汤面。"},
				{"speaker": "墨宁", "text": "唔，你看这周围的精怪还有这么多呢……"},
				{"speaker": "言秋", "text": "……喂！就是因为还没打完，才要想点开心的事嘛！"},
				{"speaker": "墨宁", "text": "那……我想吃镇子东头的肉饼……"},
				{"speaker": "言秋", "text": "对嘛对嘛，就该这样！"},
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
		{
			"lines": [
				{"speaker": "诺姆", "text": "你们战斗的时候总能马上明白彼此要做什么，好厉害。"},
				{"speaker": "言秋", "text": "那当然，我们可是一起挨过好多打的交情！"},
				{"speaker": "墨宁", "text": "这个说法听起来一点也不威风……"},
			],
		},
		{
			"lines": [
				{"speaker": "墨宁", "text": "诺姆，治疗魔法不要留到最后一刻才用。"},
				{"speaker": "诺姆", "text": "好哦，我是想着把魔力用得更精确一点……"},
				{"speaker": "言秋", "text": "哼哼，精确到我差点以为自己要倒下啦？"},
				{"speaker": "诺姆", "text": "那、那是意外！"},
				{"speaker": "诺姆", "text": "好吧……下次我会注意的。"},
			],
		},
		{
			"lines": [
				{"speaker": "言秋", "text": "诺姆，你那个白魔法能不能把怪物变慢一点？"},
				{"speaker": "诺姆", "text": "可以尝试，但要先确认它们的以太结构。"},
				{"speaker": "言秋", "text": "嗯……听不懂！总之能帮我砍得更准就行！"},
			],
		},

		# ── 坎塞尔解锁后新增 ──
		{
			"lines": [ {"speaker": "坎塞尔", "text": "吸收了这么多以太，黑魔法的力量都变强了，这种感觉有点令人着迷……"}],
		},
		{
			"lines": [ {"speaker": "坎塞尔", "text": "在幻境里的魔法力量居然提升的这么快，掌控这么强大的力量的感觉真是危险啊。"}],
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
		{
			"lines": [
				{"speaker": "坎塞尔", "text": "敌人的行动轨迹有明显收束趋势，下一波可能会从侧面挤压。"},
				{"speaker": "言秋", "text": "呃，你直接说它们要包过来不就好了！"},
				{"speaker": "坎塞尔", "text": "……它们要包过来了。"},
			],
		},
		{
			"lines": [
				{"speaker": "诺姆", "text": "坎塞尔，你刚才是不是又想一个人冲到前面？"},
				{"speaker": "坎塞尔", "text": "嗯？刚才？……哦，我只是在判断最短施法距离。"},
				{"speaker": "诺姆", "text": "那也先告诉我们一声呀！"},
				{"speaker": "墨宁", "text": "嗯，队形乱了会很危险。"},
				{"speaker": "坎塞尔", "text": "好……我只是有些习惯单枪匹马的战斗了。"},
			],
		},
		{
			"lines": [
				{"speaker": "墨宁", "text": "坎塞尔，你的冰魔法和我们这边的冰系术法很不一样。"},
				{"speaker": "坎塞尔", "text": "黑魔法更偏向强制改写以太状态，和这边依赖天地灵气的做法不太一样。"},
				{"speaker": "诺姆", "text": "但是都殊途同归！嘿嘿，这次我会这个成语了。"},
				{"speaker": "言秋", "text": "学的蛮快的嘛~"},
				{"speaker": "墨宁", "text": "说起来，小秋你今天的日课我还没检验成果呢，这可是乾长老委托我的。"},
				{"speaker": "言秋", "text": "呃……你能不能你当我刚才那句话没说。"},
			],
		},
		{
			"lines": [
				{"speaker": "坎塞尔", "text": "诺姆，你的治疗落点比以前稳定。"},
				{"speaker": "诺姆", "text": "哼，我现在可是有实战经验了。"},
				{"speaker": "言秋", "text": "对对对，我们这边的实战经验特别多。"},
			],
		},
		{
			"lines": [
				{"speaker": "墨宁", "text": "四个人一起行动后，能覆盖的方位确实多了不少。"},
				{"speaker": "坎塞尔", "text": "前提是每个人都保持节奏。"},
				{"speaker": "言秋", "text": "我节奏很好啊！"},
				{"speaker": "诺姆", "text": "你只要不突然变快就很好啦……"},
			],
		},
		{
			"lines": [
				{"speaker": "诺姆", "text": "好饿，镇子里的饭菜真好吃……"},
				{"speaker": "言秋", "text": "你们那的饭菜很难吃吗？"},
				{"speaker": "坎塞尔", "text": "嗯……因为皇家学院强调进食效率。"},
				{"speaker": "坎塞尔", "text": "所以吃的东西都挺难以下咽的。"},
				{"speaker": "坎塞尔", "text": "但是补充能量的效率很高。"},
				{"speaker": "诺姆", "text": "都是吃了那些我才长不高的！"},
				{"speaker": "坎塞尔", "text": "嗯……会长高的、会长高的。"},
				{"speaker": "诺姆", "text": "敷衍！"},
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
		{
			"lines": [
				{"speaker": "言秋", "text": "这些纸人飘来飘去的，看着比桃林里那些还烦。"},
				{"speaker": "墨宁", "text": "别被它们带偏位置了哦，刚才你差点被绊倒了。"},
				{"speaker": "言秋", "text": "哎呀哎呀，别说了！"},
			],
			"stage_only": "ruin",
		},
		{
			"lines": [
				{"speaker": "墨宁", "text": "这地方不像自然形成的幻境，更像有人刻意留下的试炼场。"},
				{"speaker": "言秋", "text": "那就把留下试炼的人也一起打服！"},
				{"speaker": "墨宁", "text": "先别急着把还不知道存不存在的人列入敌人……"},
			],
			"stage_only": "ruin",
		},
		{
			"lines": [
				{"speaker": "墨宁", "text": "这些是纸人和灯笼精？"},
				{"speaker": "言秋", "text": "感觉好像都没见过哎……"},
				{"speaker": "墨宁", "text": "可能是烧纸的遗留吧？"},
				{"speaker": "言秋", "text": "突然以后不想再烧纸了……嗯，起码不在这烧纸。"},
			],
			"stage_only": "ruin",
		},
		{
			"lines": [
				{"speaker": "诺姆", "text": "深窟里的以太很沉，像一直压在肩膀上。"},
				{"speaker": "墨宁", "text": "这里的灵气也更浑浊，呼吸节奏别乱。"},
			],
			"stage_only": "cave",
		},
		{
			"lines": [
				{"speaker": "言秋", "text": "这里黑漆漆的，怪物还会从石头缝里钻出来！"},
				{"speaker": "诺姆", "text": "别、别说得这么吓人……"},
				{"speaker": "墨宁", "text": "都靠近一些，不要被地形分开。"},
			],
			"stage_only": "cave",
		},
		{
			"lines": [
				{"speaker": "诺姆", "text": "那些幽影的轮廓不稳定，可能不是正常生物。"},
				{"speaker": "言秋", "text": "不是正常生物也会被打散吧？"},
				{"speaker": "诺姆", "text": "理论上……应该会？"},
				{"speaker": "言秋", "text": "噫……诺姆快用你的白魔法净化它们！"},
				{"speaker": "诺姆", "text": "我我我我会努力的！"},
			],
			"stage_only": "cave",
		},
		{
			"lines": [
				{"speaker": "坎塞尔", "text": "密林里的以太活性异常高，植物和魔物都可能被持续强化。"},
				{"speaker": "言秋", "text": "说人话！"},
				{"speaker": "坎塞尔", "text": "拖得越久越麻烦。"},
			],
			"stage_only": "forest",
		},
		{
			"lines": [
				{"speaker": "诺姆", "text": "这里的树影一直在动……是风吗？"},
				{"speaker": "墨宁", "text": "不是普通的风……它们像是在回应幻境里的某些东西？"},
			],
			"stage_only": "forest",
		},
		{
			"lines": [
				{"speaker": "墨宁", "text": "四周太密了，远处的敌人容易被叶影遮住。"},
				{"speaker": "坎塞尔", "text": "我会盯住以太活跃区域的高能反应，你们注意近身威胁。"},
				{"speaker": "诺姆", "text": "嗯，我负责看大家状态好啦。"},
				{"speaker": "言秋", "text": "真令人放心~"},
			],
			"stage_only": "forest",
		},
		{
			"lines": [
				{"speaker": "言秋", "text": "我们现在是不是离真相更近了？"},
				{"speaker": "坎塞尔", "text": "是……也可能离更大的麻烦更近。"},
				{"speaker": "诺姆", "text": "你就不能说点让人安心的吗……？"},
				{"speaker": "墨宁", "text": "至少我们是一起走到这里的，加油加油！"},
			],
			"stage_only": "forest",
		},
	]
