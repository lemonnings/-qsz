extends "res://Script/battleScene/base_stage.gd"

# ============== stage1 特有导出变量 ==============
@export var slime_scene: PackedScene
@export var peach_yao_scene: PackedScene
@export var bat_scene: PackedScene
@export var frog_scene: PackedScene
@export var copper_scene: PackedScene

# ============== 关卡配置 ==============
func _setup_stage_config() -> void:
	STAGE_ID = "peach_grove"
	SPAWN_INTERVAL_SECONDS = 5.0
	INITIAL_MONSTER_LIMIT = 35
	DYNAMIC_BALANCE_SPAWN_LOW_THRESHOLD = 0.3 # stage1 特有：40%（其他关卡是0.3）
	DYNAMIC_BALANCE_SPAWN_MAX_BONUS = 1.0
	DYNAMIC_BALANCE_HP_MAX_REDUCTION = 0.4
	LOW_POPULATION_FORCE_WAVE_MIN_TIME_LEFT = 1.25
	LATE_GAME_TIME_THRESHOLD = 180.0
	LATE_GAME_LOW_POPULATION_RATIO = 0.35
	BASIC_TYPES = ["slime", "peach_yao", "copper"]
	OTHER_TYPE_PER_WAVE_MAX = 1
	OTHER_TYPE_TOTAL_MAX = 4
	ELITE_MAX = 3
	# PEACH_GROVE: slime(5), peach_yao(3), frog(1), copper(0.3)
	stage_spawn_pool = [
		{"type": "slime", "weight": 500, "blocked_early": false},
		{"type": "peach_yao", "weight": 300, "blocked_early": false},
		{"type": "frog", "weight": 100, "blocked_early": true},
		{"type": "copper", "weight": 30, "blocked_early": false, "never_elite": true}
	]

func _get_corrupted_elite_spawn_data(spawn_type: String) -> Dictionary:
	match spawn_type:
		"slime":
			return {"scene": slime_scene, "monster_id": "slime_blue"}
		"peach_yao":
			return {"scene": peach_yao_scene, "monster_id": "peach_yao"}
		"frog":
			return {"scene": frog_scene, "monster_id": "frog"}
		"copper":
			return {}
		_:
			return {}

# ============== 初始化 ==============
func _ready() -> void:
	super () # 调用基类 _ready()（含 _setup_stage_config、计时器、信号连接等）

	# stage1 特有的相机参数
	$Player.camera.zoom = Vector2(2.7, 2.7)
	$Player.min_zoom = 2.5

	# 播放桃林BGM和环境音
	Global.emit_signal("stage_bgm", "peach_grove")
	
	# 首次进入桃林触发战斗教程
	if not Global.has_seen_battle_tutorial:
		_trigger_battle_tutorial()

	# 首次进入桃林触发队友对话
	if not Global.has_seen_peach_grove_dialogue:
		_trigger_peach_grove_dialogue()

# ============== Boss出场对话（覆盖基类）==============
func _on_warning_finished() -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(3).timeout
	if not is_inside_tree():
		return

	var boss_node = boss_robot_scene.instantiate()

	# 逐步缩放相机
	for i in range(7):
		Global.emit_signal("zoom_camera", -0.08)
		if not is_inside_tree():
			return
		await get_tree().create_timer(0.2).timeout
		if not is_inside_tree():
			return

	boss_node.position = _get_boss_position()
	# Boss渐变出现效果
	boss_node.modulate.a = 0.0
	get_tree().current_scene.add_child(boss_node)
	_apply_mobile_boss_balance(boss_node)
	var boss_tween = boss_node.create_tween()
	boss_tween.tween_property(boss_node, "modulate:a", 1.0, 0.8)
	_clear_non_boss_enemies()

	# 首次见到桃林Boss触发对话
	if not Global.has_seen_peach_grove_boss:
		Global.has_seen_peach_grove_boss = true
		Global.save_game()
		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree():
			return
		var dialogue_mgr = layer_ui.teammate_dialogue_mgr
		if dialogue_mgr:
			dialogue_mgr.push_dialogue("言秋", "哇啊啊啊这是什么大树精，怎么眼睛还是红的！")
			var delay1 = 1.0 + "哇啊啊啊这是什么大树精，怎么眼睛还是红的！".length() * 0.15 + 0.5 + 0.2
			await _wait_unpaused(delay1)
			if not is_inside_tree():
				return
			dialogue_mgr.push_dialogue("墨宁", "这是桃树精王？怎么连它都……")
			var delay2 = 1.0 + "这是桃树精王？怎么连它都……".length() * 0.15 + 0.5 + 0.2
			await _wait_unpaused(delay2)
			if not is_inside_tree():
				return
			dialogue_mgr.push_dialogue("墨宁", "这些花瓣的气息好奇怪，尽量不要蹭到！")

func _trigger_battle_tutorial() -> void:
	if not Global.has_seen_battle_tutorial:
		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree() or get_tree() == null:
			return
		if Global.has_seen_battle_tutorial: # Double check in case it changed
			return
		var tutorial_scene = load("res://Scenes/town/tutorial.tscn")
		if tutorial_scene:
			var tutorial = tutorial_scene.instantiate()
			# 添加到 CanvasLayer 保证在最上层显示
			var ui_layer = get_node_or_null("CanvasLayer")
			if ui_layer:
				ui_layer.add_child(tutorial)
			else:
				add_child(tutorial)
		Global.has_seen_battle_tutorial = true
		Global.save_game()

# ============== Boss位置（覆盖基类默认值）==============
func _get_boss_position() -> Vector2:
	return Vector2(-220, randf_range(185, 259))

# ============== 怪物波生成 ==============
func _spawn_wave() -> void:
	if not _begin_wave_spawn():
		return

	spawn_count += 1
	_update_wave_monster_limit()
	if current_monster_count >= max_monster_limit:
		_finish_wave_spawn()
		return

	# 计算动态平衡参数
	var spawn_multiplier = _calculate_spawn_count_multiplier()
	current_wave_hp_reduction = _calculate_hp_reduction()

	var base_wave_spawn_count = _get_wave_spawn_count()
	var wave_spawn_count = int(ceil(float(base_wave_spawn_count) * spawn_multiplier))
	var available_slots = max_monster_limit - current_monster_count
	var spawn_target_count = min(wave_spawn_count, available_slots)
	if spawn_target_count <= 0:
		_finish_wave_spawn()
		return

	# 每个怪物单独按权重判断类型
	var wave_other_type_counts: Dictionary = {}
	var spawn_list: Array[String] = []
	for i in range(spawn_target_count):
		var chosen_type = _choose_individual_type(wave_other_type_counts)
		if not BASIC_TYPES.has(chosen_type):
			if not wave_other_type_counts.has(chosen_type):
				wave_other_type_counts[chosen_type] = 0
			wave_other_type_counts[chosen_type] += 1
			other_type_alive += 1
		spawn_list.append(chosen_type)

	var spawned_this_frame := 0
	for i in range(spawn_list.size()):
		if boss_event_triggered:
			_finish_wave_spawn(false)
			return
		if current_monster_count >= max_monster_limit:
			break
		match spawn_list[i]:
			"slime":
				_spawn_single_slime()
			"peach_yao":
				_spawn_single_peach_yao()
			"bat":
				_spawn_single_bat()
			"frog":
				_spawn_single_frog()
			"copper":
				_spawn_single_copper()
		if i < spawn_list.size() - 1:
			spawned_this_frame += 1
			if spawned_this_frame < WAVE_SPAWNS_PER_FRAME:
				continue
			spawned_this_frame = 0
			if not is_inside_tree() or boss_event_triggered:
				_finish_wave_spawn(false)
				return
			await get_tree().process_frame
			if not is_inside_tree() or boss_event_triggered:
				_finish_wave_spawn(false)
				return

	if boss_event_triggered:
		_finish_wave_spawn(false)
		return
	_finish_wave_spawn()

# ============== 单体怪物生成 ==============
func _get_spawn_position(top_y: float = 100.0) -> Vector2:
	return _get_player_spawn_safe_position(_get_raw_spawn_position(top_y), Callable(self, "_get_raw_spawn_position").bind(top_y))

func _get_raw_spawn_position(top_y: float = 100.0) -> Vector2:
	var spawn_edge = randi_range(0, 3)
	match spawn_edge:
		0:
			return Vector2(randf_range(-590, 590), top_y)
		1:
			return Vector2(randf_range(-590, 590), 480)
		2:
			return Vector2(-590, randf_range(0, 480))
		_:
			return Vector2(590, randf_range(0, 480))

func _spawn_single_slime() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var slime_node = slime_scene.instantiate()
	slime_node.move_direction = randi_range(2, 8)
	var spawn_position = _get_spawn_position()
	slime_node.position = spawn_position
	get_tree().current_scene.add_child(slime_node)
	_mark_spirit_enemy_type(slime_node, false)
	_try_make_elite(slime_node)
	_apply_dynamic_hp_reduction(slime_node)
	_apply_late_game_speed_bonus(slime_node)
	_apply_mobile_monster_balance(slime_node)
	slime_node.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(slime_node, "modulate:a", 1.0, 0.7)
	current_monster_count += 1
	slime_node.connect("tree_exiting", Callable(self , "_on_monster_defeated"))

func _spawn_single_peach_yao() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var peach_yao_node = peach_yao_scene.instantiate()
	peach_yao_node.move_direction = randi_range(2, 8)
	var spawn_position = _get_spawn_position()
	peach_yao_node.position = spawn_position
	get_tree().current_scene.add_child(peach_yao_node)
	_mark_spirit_enemy_type(peach_yao_node, false)
	_try_make_elite(peach_yao_node)
	_apply_dynamic_hp_reduction(peach_yao_node)
	_apply_late_game_speed_bonus(peach_yao_node)
	_apply_mobile_monster_balance(peach_yao_node)
	peach_yao_node.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(peach_yao_node, "modulate:a", 1.0, 0.7)
	current_monster_count += 1
	peach_yao_node.connect("tree_exiting", Callable(self , "_on_monster_defeated"))

func _spawn_single_bat() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var bat_node = bat_scene.instantiate()
	var spawn_position = _get_spawn_position(-25.0)
	bat_node.position = spawn_position
	get_tree().current_scene.add_child(bat_node)
	_mark_spirit_enemy_type(bat_node, true)
	_try_make_elite(bat_node)
	_apply_dynamic_hp_reduction(bat_node)
	_apply_late_game_speed_bonus(bat_node)
	_apply_mobile_monster_balance(bat_node)
	bat_node.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(bat_node, "modulate:a", 1.0, 0.7)
	current_monster_count += 1
	bat_node.connect("tree_exiting", Callable(self , "_on_monster_defeated"))

func _spawn_single_frog() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var frog_node = frog_scene.instantiate()
	var spawn_position = _get_spawn_position()
	frog_node.position = spawn_position
	get_tree().current_scene.add_child(frog_node)
	_mark_spirit_enemy_type(frog_node, true)
	_try_make_elite(frog_node)
	_apply_dynamic_hp_reduction(frog_node)
	_apply_late_game_speed_bonus(frog_node)
	_apply_mobile_monster_balance(frog_node)
	frog_node.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(frog_node, "modulate:a", 1.0, 0.7)
	current_monster_count += 1
	frog_node.connect("tree_exiting", Callable(self , "_on_monster_defeated"))
	frog_node.connect("tree_exiting", Callable(self, "_on_other_type_monster_tree_exiting"))

func _spawn_single_copper() -> void:
	if not is_inside_tree() or get_tree().current_scene == null or copper_scene == null:
		return
	var copper_node = copper_scene.instantiate()
	copper_node.move_direction = 2
	var spawn_position = _get_spawn_position()
	copper_node.position = spawn_position
	get_tree().current_scene.add_child(copper_node)
	_register_spawned_monster(copper_node, false, false, false)

# ============== 首次进入桃林队友对话 ==============
func _trigger_peach_grove_dialogue() -> void:
	# 第3秒开始出现对话（暂停期间不计时）
	await _wait_unpaused(3.0)
	if not is_inside_tree():
		return
	if Global.has_seen_peach_grove_dialogue:
		return

	# 获取队友对话管理器
	var dialogue_mgr = layer_ui.teammate_dialogue_mgr
	if dialogue_mgr == null:
		return

	# 桃林首次进入对话序列
	var dialogues: Array[Dictionary] = [
		{"speaker": "言秋", "text": "这里便是幻境内部？除了里面的真气混乱了些，其他的看起来没什么不同啊。"},
		{"speaker": "墨宁", "text": "小心些，桃林里的树叶和桃花似乎都变成了精怪，对我们不怀好意。"},
		{"speaker": "言秋", "text": "几刀一个，轻松得很嘛。"},
		{"speaker": "墨宁", "text": "……你有没有发现，杀掉这些精怪后，它们溢散出的真气似乎会附着到我们身上一部分。"},
		{"speaker": "言秋", "text": "真的哎！那在这里修习不是快得很了！"},
		{"speaker": "墨宁", "text": "哪这么简单！这些真气只能短暂增强实力，之后打坐炼化吸收掉它们才能真正提升自己。"},
		{"speaker": "言秋", "text": "唉……不想打坐，好无聊……"},
		{"speaker": "墨宁", "text": "好像出现了少量的树精，他们平时不是最温顺的精怪吗，怎么会主动攻击我们？"},
		{"speaker": "言秋", "text": "在这呆久了我身体也不太舒服，魔兽血脉都要被点燃了……"},
		{"speaker": "墨宁", "text": "这些混乱的真气恐怕会侵蚀这些灵智不高的精怪。"},
		{"speaker": "墨宁", "text": "小秋，快要支撑不住的时候可以主动捏碎传送符，安全更重要！"},
		{"speaker": "言秋", "text": "好啦好啦，我知道了，墨宁你真唠叨……"},
		{"speaker": "墨宁", "text": "……"},
	]

	# 逐条推送对话，前一条完全消失后停留1秒再显示下一条
	for i in range(dialogues.size()):
		if not is_inside_tree():
			return
		dialogue_mgr.push_dialogue(dialogues[i].speaker, dialogues[i].text)
		# 计算当前消息完全消失所需时间：显示时长 + 渐隐时间(0.5s) + 基础停留间隔(0.2s)
		var text_len = dialogues[i].text.length()
		var display_duration = 1.0 + text_len * 0.15
		var delay = display_duration + 0.5 + 0.2
		await _wait_unpaused(delay)
		if not is_inside_tree():
			return

	# 标记已触发并保存
	Global.has_seen_peach_grove_dialogue = true
	Global.save_game()
