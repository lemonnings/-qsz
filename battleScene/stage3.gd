extends "res://Script/battleScene/base_stage.gd"

# ============== stage3 特有导出变量 ==============
@export var slime_scene: PackedScene
@export var bat_scene: PackedScene
@export var frog_scene: PackedScene
@export var extra_scene: PackedScene
@export var copper_scene: PackedScene
@export var gu_insect_scene: PackedScene

const SPAWN_TOP_X_MIN := -10.0
const SPAWN_TOP_X_MAX := 150.0
const SPAWN_TOP_Y := 130.0
const SPAWN_LEFT_X := -420.0
const SPAWN_LEFT_Y_MIN := 350.0
const SPAWN_LEFT_Y_MAX := 540.0
const SPAWN_RIGHT_X := 425.0
const SPAWN_RIGHT_Y_MIN := 290.0
const SPAWN_RIGHT_Y_MAX := 550.0
const GU_INSECT_MAX: int = 2
const GHOST_MAX: int = 3
var gu_insect_alive: int = 0
var ghost_alive: int = 0

# ============== 关卡配置 ==============
func _setup_stage_config() -> void:
	STAGE_ID = "cave"
	SPAWN_INTERVAL_SECONDS = 4.65
	INITIAL_MONSTER_LIMIT = 35
	WAVE_SPAWN_INCREASE_STEP = 11
	DYNAMIC_BALANCE_SPAWN_LOW_THRESHOLD = 0.3
	DYNAMIC_BALANCE_SPAWN_MAX_BONUS = 1.0
	DYNAMIC_BALANCE_HP_MAX_REDUCTION = 0.4
	BASIC_TYPES = ["bat", "extra", "copper"]
	OTHER_TYPE_PER_WAVE_MAX = 2
	OTHER_TYPE_TOTAL_MAX = 5
	ELITE_MAX = 3
	# CAVE: armor_stone(8), slime(4), ghost(2), stone_man(2), copper(0.3), gu_insect(0.05)
	stage_spawn_pool = [
		{"type": "bat", "weight": 800, "blocked_early": false},
		{"type": "extra", "weight": 400, "blocked_early": false},
		{"type": "slime", "weight": 200, "blocked_early": false},
		{"type": "frog", "weight": 200, "blocked_early": false},
		{"type": "copper", "weight": 30, "blocked_early": false, "never_elite": true},
		{"type": "gu_insect", "weight": 5, "blocked_early": false, "never_elite": true}
	]

func _get_corrupted_elite_spawn_data(spawn_type: String) -> Dictionary:
	match spawn_type:
		"bat":
			return {"scene": bat_scene, "monster_id": "armor_stone"}
		"extra":
			return {"scene": extra_scene, "monster_id": "slime"}
		"slime":
			return {"scene": slime_scene, "monster_id": "ghost"}
		"frog":
			return {"scene": frog_scene, "monster_id": "stone_man"}
		"copper", "gu_insect":
			return {}
		_:
			return {}

func _can_choose_spawn_entry(entry: Dictionary, wave_other_type_counts: Dictionary) -> bool:
	var spawn_type: String = str(entry.get("type", ""))
	if spawn_type == "gu_insect":
		var planned_gu_insect_count: int = int(wave_other_type_counts.get("gu_insect", 0))
		return gu_insect_alive + planned_gu_insect_count < GU_INSECT_MAX and gu_insect_scene != null
	if spawn_type == "slime":
		var planned_ghost_count: int = int(wave_other_type_counts.get("slime", 0))
		return ghost_alive + planned_ghost_count < GHOST_MAX and slime_scene != null
	return true

# ============== 初始化 ==============
func _ready() -> void:
	super ()
	$Player.camera.zoom = Vector2(2.7, 2.7)
	$Player.min_zoom = 2.4
	GU.reset_kill_count()
	# stage3 的 map_mechanism_num_max = 5（特殊值，快速触发Boss）
	# map_mechanism_num_max = 5
	# 播放深窟BGM和环境音
	Global.emit_signal("stage_bgm", "cave")

# ============== Boss位置 ==============
func _get_boss_position() -> Vector2:
	return Vector2(-15, 290)

# ============== Boss出场对话（神秘人）==============
func _on_warning_finished() -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(3).timeout
	if not is_inside_tree():
		return

	var boss_node = boss_robot_scene.instantiate()

	for i in range(7):
		Global.emit_signal("zoom_camera", -0.08)
		if not is_inside_tree():
			return
		await get_tree().create_timer(0.2).timeout
		if not is_inside_tree():
			return

	boss_node.position = _get_boss_position()
	boss_node.modulate.a = 0.0
	get_tree().current_scene.add_child(boss_node)
	_apply_mobile_boss_balance(boss_node)
	var boss_tween = boss_node.create_tween()
	boss_tween.tween_property(boss_node, "modulate:a", 1.0, 0.8)
	_clear_non_boss_enemies()

	if not Global.has_seen_cave_boss:
		Global.has_seen_cave_boss = true
		Global.save_game()
		await _wait_unpaused(1.0)
		if not is_inside_tree():
			return
		await _push_teammate_dialogue_sequence([
			{"speaker": "诺姆", "text": "怎、怎么是他……"},
			{"speaker": "诺姆", "text": "大家，要注意他的黑魔法！"},
			{"speaker": "墨宁", "text": "他的咏唱技能伤害范围怎么这么大！"},
		])

# ============== 怪物生成 ==============
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
			"bat":
				_spawn_single_bat()
			"frog":
				_spawn_single_frog()
			"extra":
				_spawn_single_extra()
			"copper":
				_spawn_single_copper()
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

func _get_spawn_position() -> Vector2:
	return _get_player_spawn_safe_position(_get_raw_spawn_position(), Callable(self , "_get_raw_spawn_position"))

func _get_raw_spawn_position() -> Vector2:
	var spawn_edge = randi_range(0, 2)
	match spawn_edge:
		0:
			return Vector2(randf_range(SPAWN_TOP_X_MIN, SPAWN_TOP_X_MAX), SPAWN_TOP_Y)
		1:
			return Vector2(SPAWN_LEFT_X, randf_range(SPAWN_LEFT_Y_MIN, SPAWN_LEFT_Y_MAX))
		_:
			return Vector2(SPAWN_RIGHT_X, randf_range(SPAWN_RIGHT_Y_MIN, SPAWN_RIGHT_Y_MAX))

func _spawn_single_slime() -> void:
	if not is_inside_tree() or get_tree().current_scene == null or slime_scene == null:
		other_type_alive = max(0, other_type_alive - 1)
		return
	if ghost_alive >= GHOST_MAX:
		other_type_alive = max(0, other_type_alive - 1)
		_spawn_single_bat()
		return
	var slime_node = slime_scene.instantiate()
	var spawn_position = _get_spawn_position()
	slime_node.position = spawn_position
	get_tree().current_scene.add_child(slime_node)
	_mark_spirit_enemy_type(slime_node, true)
	_try_make_elite(slime_node)
	_apply_dynamic_hp_reduction(slime_node)
	_apply_late_game_speed_bonus(slime_node)
	_apply_mobile_monster_balance(slime_node)
	slime_node.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(slime_node, "modulate:a", 1.0, 0.7)
	current_monster_count += 1
	ghost_alive += 1
	slime_node.connect("tree_exiting", Callable(self , "_on_monster_defeated"))
	slime_node.connect("tree_exiting", Callable(self , "_on_other_type_monster_tree_exiting"))
	slime_node.connect("tree_exiting", Callable(self , "_on_ghost_tree_exiting"))

func _spawn_single_bat() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var bat_node = bat_scene.instantiate()
	bat_node.move_direction = 2 # armor_stone: 靠近角色移动
	var spawn_position = _get_spawn_position()
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

func _spawn_single_frog() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var frog_node = frog_scene.instantiate()
	frog_node.move_direction = 2 # 朝向角色移动
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
	frog_node.connect("tree_exiting", Callable(self , "_on_other_type_monster_tree_exiting"))

func _spawn_single_extra() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var extra_node = extra_scene.instantiate()
	extra_node.move_direction = 2 # 朝向角色移动
	var spawn_position = _get_spawn_position()
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

func _spawn_single_copper() -> void:
	if not is_inside_tree() or get_tree().current_scene == null or copper_scene == null:
		return
	var copper_node = copper_scene.instantiate()
	copper_node.move_direction = 2
	copper_node.position = _get_spawn_position()
	get_tree().current_scene.add_child(copper_node)
	_register_spawned_monster(copper_node, false, false, false)

func _spawn_single_gu_insect() -> void:
	if not is_inside_tree() or get_tree().current_scene == null or gu_insect_scene == null:
		other_type_alive = max(0, other_type_alive - 1)
		return
	if gu_insect_alive >= GU_INSECT_MAX:
		other_type_alive = max(0, other_type_alive - 1)
		_spawn_single_bat()
		return
	var gu_insect_node = gu_insect_scene.instantiate()
	gu_insect_node.position = _get_spawn_position()
	get_tree().current_scene.add_child(gu_insect_node)
	gu_insect_alive += 1
	_register_spawned_monster(gu_insect_node, true, false, true)
	gu_insect_node.connect("tree_exiting", Callable(self , "_on_gu_insect_tree_exiting"))

func _on_gu_insect_tree_exiting() -> void:
	gu_insect_alive = max(0, gu_insect_alive - 1)

func _on_ghost_tree_exiting() -> void:
	ghost_alive = max(0, ghost_alive - 1)
