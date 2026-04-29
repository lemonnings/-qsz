extends "res://Script/battleScene/base_stage.gd"

# ============== stage2 特有导出变量 ==============
@export var lantern_scene: PackedScene
@export var paper_scene: PackedScene
@export var yao_scene: PackedScene
@export var grey_slime_scene: PackedScene

# frog类型（yao）数量上限（stage2独有）
const FROG_MAX: int = 3 # frog类型同时存在最多3个（含精英）
var frog_alive: int = 0 # 当前存活的frog类型数量

# ============== 关卡配置 ==============
func _setup_stage_config() -> void:
	STAGE_ID = "ruin"
	SPAWN_INTERVAL_SECONDS = 4.75
	INITIAL_MONSTER_LIMIT = 50
	MAX_MONSTER_CAP = 100
	DYNAMIC_BALANCE_SPAWN_LOW_THRESHOLD = 0.3
	DYNAMIC_BALANCE_SPAWN_MAX_BONUS = 1.0
	DYNAMIC_BALANCE_HP_MAX_REDUCTION = 0.4
	BASIC_TYPES = ["slime", "bat", "extra"]
	OTHER_TYPE_PER_WAVE_MAX = 1
	OTHER_TYPE_TOTAL_MAX = 3
	ELITE_MAX = 3
	# RUIN: slime->lantern, bat->paper, frog->yao, extra->grey_slime
	stage_spawn_pool = [
		{"type": "slime", "weight": 4, "blocked_early": false},
		{"type": "bat", "weight": 4, "blocked_early": false},
		{"type": "frog", "weight": 1, "blocked_early": false},
		{"type": "extra", "weight": 1, "blocked_early": false}
	]

# ============== 初始化 ==============
func _ready() -> void:
	super ()
	$Player.camera.zoom = Vector2(3, 3)
	$Player.min_zoom = 2.9
	GU.reset_kill_count()
	# stage2 特有：BGM 和 map_mechanism_num_max 覆盖
	Global.emit_signal("stage_bgm", "ruin")
	map_mechanism_num_max = 5

# ============== Boss位置 ==============
func _get_boss_position() -> Vector2:
	return Vector2(0, 100)

# ============== 覆盖 _on_warning_finished（boss_stele特殊逻辑）==============
func _on_warning_finished() -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(3).timeout
	if not is_inside_tree():
		return

	# 实例化新的石碑Boss
	var boss_scene = preload("res://Scenes/moster/boss_stele.tscn")
	var boss_node = boss_scene.instantiate()

	# 逐步缩放相机
	for i in range(7):
		Global.emit_signal("zoom_camera", -0.08)
		if not is_inside_tree():
			return
		await get_tree().create_timer(0.2).timeout
		if not is_inside_tree():
			return

	boss_node.position = Vector2(0, 100)
	get_tree().current_scene.add_child(boss_node)
	_clear_non_boss_enemies()

# ============== 怪物波生成 ==============
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
		if i < spawn_list.size() - 1:
			if not is_inside_tree():
				return
			await get_tree().create_timer(0.1).timeout
			if not is_inside_tree():
				return

	monster_spawn_timer.start()

# ============== 单怪生成 ==============
func _spawn_single_lantern() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var slime_node = lantern_scene.instantiate()
	slime_node.move_direction = 2 # 朝向角色移动
	var spawn_edge = randi_range(0, 6)
	var spawn_position = Vector2.ZERO
	match spawn_edge:
		0: # Top
			spawn_position = Vector2(randf_range(-105, -30), -22)
		1: # Bottom
			spawn_position = Vector2(randf_range(-310, 305), 580)
		2: # Left
			spawn_position = Vector2(-340, randf_range(40, 560))
		3: # Right
			spawn_position = Vector2(335, randf_range(40, 560))
		4: # Bottom
			spawn_position = Vector2(randf_range(-310, 305), 580)
		5: # Left
			spawn_position = Vector2(-340, randf_range(40, 560))
		6: # Right
			spawn_position = Vector2(335, randf_range(40, 560))
	slime_node.position = spawn_position
	get_tree().current_scene.add_child(slime_node)
	_try_make_elite(slime_node)
	_apply_dynamic_hp_reduction(slime_node)
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

	var spawn_edge = randi_range(0, 6)
	var spawn_position = Vector2.ZERO
	match spawn_edge:
		0: # Top
			spawn_position = Vector2(randf_range(-105, -30), -22)
		1: # Bottom
			spawn_position = Vector2(randf_range(-310, 305), 580)
		2: # Left
			spawn_position = Vector2(-340, randf_range(40, 560))
		3: # Right
			spawn_position = Vector2(335, randf_range(40, 560))
		4: # Bottom
			spawn_position = Vector2(randf_range(-310, 305), 580)
		5: # Left
			spawn_position = Vector2(-340, randf_range(40, 560))
		6: # Right
			spawn_position = Vector2(335, randf_range(40, 560))
	frog_node.position = spawn_position
	get_tree().current_scene.add_child(frog_node)
	_try_make_elite(frog_node)
	_apply_dynamic_hp_reduction(frog_node)
	frog_node.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(frog_node, "modulate:a", 1.0, 0.7)
	frog_alive += 1
	current_monster_count += 1
	frog_node.connect("tree_exiting", Callable(self , "_on_monster_defeated"))
	frog_node.connect("tree_exiting", func(): other_type_alive = max(0, other_type_alive - 1))
	frog_node.connect("tree_exiting", func(): frog_alive = max(0, frog_alive - 1))

func _spawn_single_paper() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var bat_node = paper_scene.instantiate()
	bat_node.move_direction = 2 # 朝向角色移动
	var spawn_edge = randi_range(0, 6)
	var spawn_position = Vector2.ZERO
	match spawn_edge:
		0: # Top
			spawn_position = Vector2(randf_range(-105, -30), -22)
		1: # Bottom
			spawn_position = Vector2(randf_range(-310, 305), 580)
		2: # Left
			spawn_position = Vector2(-340, randf_range(40, 560))
		3: # Right
			spawn_position = Vector2(335, randf_range(40, 560))
		4: # Bottom
			spawn_position = Vector2(randf_range(-310, 305), 580)
		5: # Left
			spawn_position = Vector2(-340, randf_range(40, 560))
		6: # Right
			spawn_position = Vector2(335, randf_range(40, 560))
	bat_node.position = spawn_position
	get_tree().current_scene.add_child(bat_node)
	_try_make_elite(bat_node)
	_apply_dynamic_hp_reduction(bat_node)
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
	var spawn_edge = randi_range(0, 3)
	var spawn_position = Vector2.ZERO
	match spawn_edge:
		0: # Top
			spawn_position = Vector2(randf_range(-90, -45), -22)
		1: # Bottom
			spawn_position = Vector2(randf_range(-310, 305), 580)
		2: # Left
			spawn_position = Vector2(-340, randf_range(40, 560))
		3: # Right
			spawn_position = Vector2(335, randf_range(40, 560))
	extra_node.position = spawn_position
	get_tree().current_scene.add_child(extra_node)
	_try_make_elite(extra_node)
	_apply_dynamic_hp_reduction(extra_node)
	extra_node.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(extra_node, "modulate:a", 1.0, 0.7)
	current_monster_count += 1
	extra_node.connect("tree_exiting", Callable(self , "_on_monster_defeated"))
	extra_node.connect("tree_exiting", func(): other_type_alive = max(0, other_type_alive - 1))
