extends "res://Script/battleScene/base_stage.gd"

# ============== stage3 特有导出变量 ==============
@export var slime_scene: PackedScene
@export var bat_scene: PackedScene
@export var frog_scene: PackedScene
@export var extra_scene: PackedScene

const SPAWN_TOP_X_MIN := -10.0
const SPAWN_TOP_X_MAX := 150.0
const SPAWN_TOP_Y := 130.0
const SPAWN_LEFT_X := -420.0
const SPAWN_LEFT_Y_MIN := 350.0
const SPAWN_LEFT_Y_MAX := 540.0
const SPAWN_RIGHT_X := 425.0
const SPAWN_RIGHT_Y_MIN := 290.0
const SPAWN_RIGHT_Y_MAX := 550.0

# ============== 关卡配置 ==============
func _setup_stage_config() -> void:
	STAGE_ID = "cave"
	SPAWN_INTERVAL_SECONDS = 4.65
	INITIAL_MONSTER_LIMIT = 50
	WAVE_SPAWN_INCREASE_STEP = 10
	DYNAMIC_BALANCE_SPAWN_LOW_THRESHOLD = 0.3
	DYNAMIC_BALANCE_SPAWN_MAX_BONUS = 1.0
	DYNAMIC_BALANCE_HP_MAX_REDUCTION = 0.4
	BASIC_TYPES = ["bat", "extra"]
	OTHER_TYPE_PER_WAVE_MAX = 2
	OTHER_TYPE_TOTAL_MAX = 5
	ELITE_MAX = 3
	# CAVE: armor_stone(8), slime(4), ghost(2), stone_man(2)
	stage_spawn_pool = [
		{"type": "bat", "weight": 8, "blocked_early": false},
		{"type": "extra", "weight": 4, "blocked_early": false},
		{"type": "slime", "weight": 2, "blocked_early": false},
		{"type": "frog", "weight": 2, "blocked_early": false}
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
		_:
			return {}

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
	return Vector2(-15, 240)

# ============== 怪物生成 ==============
func _spawn_wave() -> void:
	if boss_event_triggered:
		return

	var current_frame = Engine.get_process_frames()
	if current_frame == last_wave_spawn_frame:
		return
	last_wave_spawn_frame = current_frame

	spawn_count += 1
	_update_wave_monster_limit()
	if current_monster_count >= max_monster_limit:
		monster_spawn_timer.start()
		return

	# 计算动态平衡参数
	var spawn_multiplier = _calculate_spawn_count_multiplier()
	current_wave_hp_reduction = _calculate_hp_reduction()

	var base_wave_spawn_count = _get_wave_spawn_count()
	var wave_spawn_count = int(ceil(float(base_wave_spawn_count) * spawn_multiplier))
	var available_slots = max_monster_limit - current_monster_count
	var spawn_target_count = min(wave_spawn_count, available_slots)
	if spawn_target_count <= 0:
		monster_spawn_timer.start()
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

	# 逐个生成，间隔0.1秒
	for i in range(spawn_list.size()):
		if boss_event_triggered:
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
		if i < spawn_list.size() - 1:
			if not is_inside_tree() or boss_event_triggered:
				return
			await get_tree().create_timer(0.1).timeout
			if not is_inside_tree() or boss_event_triggered:
				return

	if boss_event_triggered:
		return
	monster_spawn_timer.start()

func _get_spawn_position() -> Vector2:
	var spawn_edge = randi_range(0, 2)
	match spawn_edge:
		0:
			return Vector2(randf_range(SPAWN_TOP_X_MIN, SPAWN_TOP_X_MAX), SPAWN_TOP_Y)
		1:
			return Vector2(SPAWN_LEFT_X, randf_range(SPAWN_LEFT_Y_MIN, SPAWN_LEFT_Y_MAX))
		_:
			return Vector2(SPAWN_RIGHT_X, randf_range(SPAWN_RIGHT_Y_MIN, SPAWN_RIGHT_Y_MAX))

func _spawn_single_slime() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var slime_node = slime_scene.instantiate()
	var spawn_position = _get_spawn_position()
	slime_node.position = spawn_position
	get_tree().current_scene.add_child(slime_node)
	_mark_spirit_enemy_type(slime_node, true)
	_try_make_elite(slime_node)
	_apply_dynamic_hp_reduction(slime_node)
	_apply_late_game_speed_bonus(slime_node)
	slime_node.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(slime_node, "modulate:a", 1.0, 0.7)
	current_monster_count += 1
	slime_node.connect("tree_exiting", Callable(self , "_on_monster_defeated"))

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
	frog_node.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(frog_node, "modulate:a", 1.0, 0.7)
	current_monster_count += 1
	frog_node.connect("tree_exiting", Callable(self , "_on_monster_defeated"))
	frog_node.connect("tree_exiting", Callable(self, "_on_other_type_monster_tree_exiting"))

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
	extra_node.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(extra_node, "modulate:a", 1.0, 0.7)
	current_monster_count += 1
	extra_node.connect("tree_exiting", Callable(self , "_on_monster_defeated"))
	extra_node.connect("tree_exiting", Callable(self, "_on_other_type_monster_tree_exiting"))
