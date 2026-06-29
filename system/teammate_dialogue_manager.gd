extends Node
class_name TeammateDialogueManager

## 局内队友会话管理器
##
## 管理战斗中队友对话气泡的显示与生命周期。
## 支持三种触发方式：条件触发、Boss技能触发、剧情触发。
## 通过 Global.teammate_dialogue 信号接收消息。
##
## 规则：
## - dialogue_container 内最多同时显示2条消息
## - 每条消息持续时间 = 1 + 文字数量 * 0.15 秒
## - 持续时间到了之后渐隐消失，下一条消息顺次上移
## - 第3条消息出现时，立即销毁第1条（FIFO）
## - 暂停期间停止计时

const DIALOGUE_SCENE_PATH: String = "res://Scenes/global/dialogue.tscn"
const MAX_VISIBLE: int = 2
const BASE_DURATION: float = 1.0
const DURATION_PER_CHAR: float = 0.15
const EXTRA_HOLD_DURATION: float = 0.3
const FADE_OUT_DURATION: float = 0.5

# 头像纹理缓存
var _portrait_cache: Dictionary = {}

# 当前显示的对话项 [{node, timer_remaining}]
var _active_dialogues: Array[Dictionary] = []

# 待显示的消息队列
var _pending_queue: Array[Dictionary] = []

# 对话容器引用
var _container: VBoxContainer = null

# 预加载的对话场景
var _dialogue_scene: PackedScene = null

# 是否已初始化
var _initialized: bool = false


# 是否正在处理信号（防止 push_dialogue 发信号时重复处理）
var _signal_guard: bool = false


func _ready() -> void:
	Global.connect("teammate_dialogue", Callable(self , "_on_teammate_dialogue"))


## 初始化管理器，传入对话容器
func initialize(container: VBoxContainer) -> void:
	_container = container
	_dialogue_scene = load(DIALOGUE_SCENE_PATH)
	if _container == null:
		push_error("TeammateDialogueManager: dialogue_container 为 null!")
		return
	# 清空容器中可能存在的占位子节点
	for child in _container.get_children():
		child.queue_free()
	_initialized = true


func _process(delta: float) -> void:
	if not _initialized:
		return
	# 暂停期间不计时
	if get_tree().paused:
		return
	var real_delta := _get_real_delta(delta)

	# 更新所有活跃对话的剩余时间
	var to_remove: Array[int] = []
	for i in range(_active_dialogues.size()):
		_active_dialogues[i].timer_remaining -= real_delta
		if _active_dialogues[i].timer_remaining <= 0.0 and not _active_dialogues[i].get("fading", false):
			to_remove.append(i)

	# 从后往前移除已过期的消息（渐隐）
	for i in range(to_remove.size() - 1, -1, -1):
		_fade_out_dialogue(to_remove[i])

	# 处理队列中带延迟的消息
	if _pending_queue.size() > 0 and _pending_queue[0].has("_wait_remaining"):
		_pending_queue[0]._wait_remaining -= real_delta
		if _pending_queue[0]._wait_remaining <= 0.0:
			_pending_queue[0].erase("_wait_remaining")

	# 如果有空位且队列中有待显示的消息，显示它们
	_try_show_pending()


## 接收信号回调
func _on_teammate_dialogue(speaker: String, text: String) -> void:
	if _signal_guard:
		return
	var msg := {"speaker": speaker, "text": text}
	_enqueue_message(msg)


## 程序化推送一条对话（供外部直接调用）
## 会发出 teammate_dialogue 信号，以便 BattleChat 等系统重置闲聊计时器
func push_dialogue(speaker: String, text: String) -> void:
	_signal_guard = true
	var msg := {"speaker": speaker, "text": text}
	_enqueue_message(msg)
	Global.emit_signal("teammate_dialogue", speaker, text)
	_signal_guard = false


## 批量推送对话序列（带间隔）
func push_dialogue_sequence(dialogues: Array[Dictionary], interval: float = 0.0) -> void:
	for i in range(dialogues.size()):
		var d = dialogues[i]
		var delay = interval * i
		if delay > 0.0:
			# 添加延迟属性
			d["delay"] = delay
		_pending_queue.append(d)
	_try_show_pending()


## 将消息加入队列
func _enqueue_message(msg: Dictionary) -> void:
	if not _initialized:
		_pending_queue.append(msg)
		return

	# 如果当前显示数已满（>=2），立即移除最早的一条
	if _active_dialogues.size() >= MAX_VISIBLE:
		_force_remove_oldest()

	# 显示这条消息
	_show_dialogue(msg)


## 尝试从队列中显示等待的消息
func _try_show_pending() -> void:
	if not _initialized:
		return
	while _pending_queue.size() > 0 and _active_dialogues.size() < MAX_VISIBLE:
		var msg = _pending_queue[0]
		# 如果消息有延迟且尚未到期，停止处理
		if msg.has("delay") and msg.delay > 0.0:
			_start_delayed_message(msg)
			break
		if msg.has("_wait_remaining") and msg._wait_remaining > 0.0:
			break
		_pending_queue.pop_front()
		_show_dialogue(msg)


## 延迟显示消息
func _start_delayed_message(msg: Dictionary) -> void:
	var delay = msg.delay
	msg.erase("delay")
	# 使用 get_tree().create_timer 但需要考虑暂停
	# 由于暂停时不应推进，使用 _process 中手动计时
	msg["_wait_remaining"] = delay
	_pending_queue.push_front(msg)


## 显示一条对话
func _show_dialogue(msg: Dictionary) -> void:
	if _dialogue_scene == null or _container == null:
		return

	var dialogue_node = _dialogue_scene.instantiate()
	_container.add_child(dialogue_node)

	# 设置头像和文本
	var portrait_texture = _get_portrait(msg.speaker)
	dialogue_node.setup(portrait_texture, msg.text)

	# 计算持续时间
	var text_length = msg.text.length()
	var duration = BASE_DURATION + text_length * DURATION_PER_CHAR + EXTRA_HOLD_DURATION

	# 淡入效果
	dialogue_node.modulate.a = 0.0
	var fade_in_tween = dialogue_node.create_tween()
	fade_in_tween.set_ignore_time_scale(true)
	fade_in_tween.tween_property(dialogue_node, "modulate:a", 1.0, 0.3)

	_active_dialogues.append({
		"node": dialogue_node,
		"timer_remaining": duration,
		"fading": false
	})


## 渐隐移除指定索引的对话
func _fade_out_dialogue(index: int) -> void:
	if index < 0 or index >= _active_dialogues.size():
		return

	var entry = _active_dialogues[index]
	if entry.fading:
		return
	entry.fading = true

	var node = entry.node
	if not is_instance_valid(node):
		_active_dialogues.remove_at(index)
		return

	var tween = node.create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(node, "modulate:a", 0.0, FADE_OUT_DURATION)
	tween.tween_callback(func():
		if is_instance_valid(node):
			node.queue_free()
		# 从活跃列表中移除
		for i in range(_active_dialogues.size() - 1, -1, -1):
			if _active_dialogues[i].node == node:
				_active_dialogues.remove_at(i)
				break
		_try_show_pending()
	)


## 强制立即移除最早的消息（第3条进来时调用）
func _force_remove_oldest() -> void:
	if _active_dialogues.is_empty():
		return

	var oldest = _active_dialogues[0]
	var node = oldest.node
	_active_dialogues.remove_at(0)

	if is_instance_valid(node):
		# 快速淡出并销毁
		var tween = node.create_tween()
		tween.set_ignore_time_scale(true)
		tween.tween_property(node, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func():
			if is_instance_valid(node):
				node.queue_free()
		)


## 获取角色头像纹理（带缓存）
func _get_portrait(speaker: String) -> Texture2D:
	if _portrait_cache.has(speaker):
		return _portrait_cache[speaker]

	var texture_path := ""
	match speaker:
		"言秋", "yiqiu":
			texture_path = "res://AssetBundle/Sprites/town/yiqiu.png"
		"墨宁", "moning":
			texture_path = "res://AssetBundle/Sprites/town/moning.png"
		"诺姆", "noam":
			texture_path = "res://AssetBundle/Sprites/town/noam.png"
		"坎塞尔", "kansel":
			texture_path = "res://AssetBundle/Sprites/town/kansel.png"
		"雪铭", "xueming":
			texture_path = "res://AssetBundle/Sprites/town/xueming.png"
		"":
			return null # 系统消息无头像
		_:
			push_warning("TeammateDialogueManager: 未知说话人 '%s'" % speaker)
			return null

	var texture = load(texture_path) as Texture2D
	if texture:
		_portrait_cache[speaker] = texture
	return texture


## 清空所有对话（关卡结束时调用）
func clear_all() -> void:
	for entry in _active_dialogues:
		if is_instance_valid(entry.node):
			entry.node.queue_free()
	_active_dialogues.clear()
	_pending_queue.clear()


func _get_real_delta(delta: float) -> float:
	return delta / max(Engine.time_scale, 0.001)
