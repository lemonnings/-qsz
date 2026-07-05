extends "res://Script/battleScene/base_stage.gd"

# ============== stage2 特有导出变量 ==============
@export var lantern_scene: PackedScene
@export var paper_scene: PackedScene
@export var yao_scene: PackedScene
@export var grey_slime_scene: PackedScene
@export var gu_insect_scene: PackedScene

const SPAWN_TOP_X_MIN := -65.0
const SPAWN_TOP_X_MAX := 70.0
const SPAWN_TOP_Y := -220.0
const SPAWN_BOTTOM_X_MIN := -365.0
const SPAWN_BOTTOM_X_MAX := 360.0
const SPAWN_BOTTOM_Y := 740.0
const SPAWN_LEFT_X := -370.0
const SPAWN_LEFT_Y_MIN := 150.0
const SPAWN_LEFT_Y_MAX := 700.0
const SPAWN_RIGHT_X := 360.0
const SPAWN_RIGHT_Y_MIN := 150.0
const SPAWN_RIGHT_Y_MAX := 700.0

# frog类型（yao）数量上限（stage2独有）
const FROG_MAX: int = 3 # frog类型同时存在最多3个（含精英）
var frog_alive: int = 0 # 当前存活的frog类型数量
const GU_INSECT_MAX: int = 2
var gu_insect_alive: int = 0

# ============== 关卡配置 ==============
func _setup_stage_config() -> void:
	STAGE_ID = "ruin"
	SPAWN_INTERVAL_SECONDS = 4.75
	INITIAL_MONSTER_LIMIT = 35
	WAVE_SPAWN_INCREASE_STEP = 11
	DYNAMIC_BALANCE_SPAWN_LOW_THRESHOLD = 0.3
	DYNAMIC_BALANCE_SPAWN_MAX_BONUS = 1.0
	DYNAMIC_BALANCE_HP_MAX_REDUCTION = 0.4
	BASIC_TYPES = ["slime", "bat", "extra"]
	OTHER_TYPE_PER_WAVE_MAX = 1
	OTHER_TYPE_TOTAL_MAX = 3
	ELITE_MAX = 3
	# RUIN: slime->lantern, bat->paper, frog->yao, extra->grey_slime, gu_insect(0.05)
	stage_spawn_pool = [
		{"type": "slime", "weight": 400, "blocked_early": false},
		{"type": "bat", "weight": 400, "blocked_early": false},
		{"type": "frog", "weight": 100, "blocked_early": false},
		{"type": "extra", "weight": 100, "blocked_early": false},
		{"type": "gu_insect", "weight": 5, "blocked_early": false, "never_elite": true}
	]

func _get_corrupted_elite_spawn_data(spawn_type: String) -> Dictionary:
	match spawn_type:
		"slime":
			return {"scene": lantern_scene, "monster_id": "lantern"}
		"bat":
			return {"scene": paper_scene, "monster_id": "paper"}
		"frog":
			return {"scene": yao_scene, "monster_id": "bat"}
		"extra":
			return {"scene": grey_slime_scene, "monster_id": "slime_grey"}
		"gu_insect":
			return {}
		_:
			return {}

func _can_choose_spawn_entry(entry: Dictionary, wave_other_type_counts: Dictionary) -> bool:
	if str(entry.get("type", "")) == "gu_insect":
		var planned_count := int(wave_other_type_counts.get("gu_insect", 0))
		return gu_insect_alive + planned_count < GU_INSECT_MAX and gu_insect_scene != null
	return true

# ============== 初始化 ==============
func _ready() -> void:
	super ()
	$Player.camera.zoom = Vector2(2.9, 2.9)
	$Player.min_zoom = 2.7
	GU.reset_kill_count()
	# stage2 特有：BGM 和 map_mechanism_num_max 覆盖
	Global.emit_signal("stage_bgm", "ruin")
	# map_mechanism_num_max = 5

# ============== Boss位置 ==============
func _get_boss_position() -> Vector2:
	return Vector2(0, 250)

# ============== 覆盖 _on_warning_finished（boss_stone）==============
func _on_warning_finished() -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(3).timeout
	if not is_inside_tree():
		return

	# 实例化新的石头人Boss
	var boss_scene = preload("res://Scenes/moster/boss_stone.tscn")
	var boss_node = boss_scene.instantiate()

	# 逐步缩放相机
	for i in range(7):
		Global.emit_signal("zoom_camera", -0.08)
		if not is_inside_tree():
			return
		await get_tree().create_timer(0.2).timeout
		if not is_inside_tree():
			return

	boss_node.position = _get_boss_position()
	get_tree().current_scene.add_child(boss_node)
	_apply_mobile_boss_balance(boss_node)
	_clear_non_boss_enemies()

	if not Global.has_seen_ruin_boss:
		Global.has_seen_ruin_boss = true
		Global.save_game()
		await _wait_unpaused(1.0)
		if not is_inside_tree():
			return
		await _push_teammate_dialogue_sequence([
			{"speaker": "言秋", "text": "这石巨人怎么一身石甲，砍上去好钝！"},
			{"speaker": "言秋", "text": "哇哇哇，还有横着滚过来的滚石！"},
			{"speaker": "墨宁", "text": "先找空隙躲，别被石块和滚石一起卡住。"},
			{"speaker": "墨宁", "text": "我感觉它的石甲似乎会减少受到的伤害。"},
			{"speaker": "墨宁", "text": "或许……我们注意下落石留下的石块，大概可以诱导它冲锋来撞碎石块？"},
			{"speaker": "言秋", "text": "对哦！也许还能把它的石甲给震下来~"},
		])

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
				_spawn_single_lantern()
			"bat":
				_spawn_single_paper()
			"frog":
				_spawn_single_yao()
			"extra":
				_spawn_single_grey_slime()
			"gu_insect":
				_spawn_single_gu_insect()
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

func _get_spawn_position(use_weighted_edges: bool = true) -> Vector2:
	return _get_player_spawn_safe_position(_get_raw_spawn_position(use_weighted_edges), Callable(self, "_get_raw_spawn_position").bind(use_weighted_edges))

func _get_raw_spawn_position(use_weighted_edges: bool = true) -> Vector2:
	var spawn_edge_max := 6 if use_weighted_edges else 3
	var spawn_edge := randi_range(0, spawn_edge_max)
	var resolved_edge := spawn_edge
	var fallback_position := Vector2.ZERO
	match spawn_edge:
		0:
			fallback_position = Vector2(randf_range(SPAWN_TOP_X_MIN, SPAWN_TOP_X_MAX), SPAWN_TOP_Y)
		1, 4:
			resolved_edge = 1
			fallback_position = Vector2(randf_range(SPAWN_BOTTOM_X_MIN, SPAWN_BOTTOM_X_MAX), SPAWN_BOTTOM_Y)
		2, 5:
			resolved_edge = 2
			fallback_position = Vector2(SPAWN_LEFT_X, randf_range(SPAWN_LEFT_Y_MIN, SPAWN_LEFT_Y_MAX))
		_:
			resolved_edge = 3
			fallback_position = Vector2(SPAWN_RIGHT_X, randf_range(SPAWN_RIGHT_Y_MIN, SPAWN_RIGHT_Y_MAX))
	return _get_monster_spawn_position_for_edge(resolved_edge, fallback_position)

# ============== 单怪生成 ==============
func _spawn_single_lantern() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var slime_node = lantern_scene.instantiate()
	slime_node.move_direction = 2 # 朝向角色移动
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

func _spawn_single_yao() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	if frog_alive >= FROG_MAX:
		# frog类型已达上限，改为生成普通怪（lantern）
		_spawn_single_lantern()
		return
	var frog_node = yao_scene.instantiate()

	var spawn_position = _get_spawn_position()
	var bounds := _get_scene_boundary_rect()
	if bounds.size.x > 1.0 and bounds.size.y > 1.0:
		spawn_position = _clamp_point_to_rect(spawn_position, _shrink_rect(bounds, 24.0))
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
	frog_alive += 1
	current_monster_count += 1
	frog_node.connect("tree_exiting", Callable(self , "_on_monster_defeated"))
	frog_node.connect("tree_exiting", Callable(self , "_on_other_type_monster_tree_exiting"))
	frog_node.connect("tree_exiting", Callable(self , "_on_frog_type_monster_tree_exiting"))

func _spawn_single_paper() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var bat_node = paper_scene.instantiate()
	bat_node.move_direction = 2 # 朝向角色移动
	var spawn_position = _get_spawn_position()
	var bounds := _get_scene_boundary_rect()
	if bounds.size.x > 1.0 and bounds.size.y > 1.0:
		spawn_position = _clamp_point_to_rect(spawn_position, _shrink_rect(bounds, 24.0))
	bat_node.position = spawn_position
	get_tree().current_scene.add_child(bat_node)
	_mark_spirit_enemy_type(bat_node, false)
	_try_make_elite(bat_node)
	_apply_dynamic_hp_reduction(bat_node)
	_apply_late_game_speed_bonus(bat_node)
	_apply_mobile_monster_balance(bat_node)
	bat_node.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(bat_node, "modulate:a", 1.0, 0.7)
	current_monster_count += 1
	bat_node.connect("tree_exiting", Callable(self , "_on_monster_defeated"))

func _spawn_single_grey_slime() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var extra_node = grey_slime_scene.instantiate()
	extra_node.move_direction = 2 # 朝向角色移动
	var spawn_position = _get_spawn_position(false)
	extra_node.position = spawn_position
	get_tree().current_scene.add_child(extra_node)
	_mark_spirit_enemy_type(extra_node, false)
	_try_make_elite(extra_node)
	_apply_dynamic_hp_reduction(extra_node)
	_apply_late_game_speed_bonus(extra_node)
	_apply_mobile_monster_balance(extra_node)
	extra_node.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(extra_node, "modulate:a", 1.0, 0.7)
	current_monster_count += 1
	extra_node.connect("tree_exiting", Callable(self , "_on_monster_defeated"))
	extra_node.connect("tree_exiting", Callable(self , "_on_other_type_monster_tree_exiting"))

func _spawn_single_gu_insect() -> void:
	if not is_inside_tree() or get_tree().current_scene == null or gu_insect_scene == null:
		other_type_alive = max(0, other_type_alive - 1)
		return
	if gu_insect_alive >= GU_INSECT_MAX:
		other_type_alive = max(0, other_type_alive - 1)
		_spawn_single_lantern()
		return
	var gu_insect_node = gu_insect_scene.instantiate()
	gu_insect_node.position = _get_spawn_position()
	get_tree().current_scene.add_child(gu_insect_node)
	gu_insect_alive += 1
	_register_spawned_monster(gu_insect_node, true, false, true)
	gu_insect_node.connect("tree_exiting", Callable(self, "_on_gu_insect_tree_exiting"))

func _on_frog_type_monster_tree_exiting() -> void:
	frog_alive = max(0, frog_alive - 1)

func _on_gu_insect_tree_exiting() -> void:
	gu_insect_alive = max(0, gu_insect_alive - 1)
