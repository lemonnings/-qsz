extends "res://Script/battleScene/base_stage.gd"

# ============== stage1 特有导出变量 ==============
@export var slime_scene: PackedScene
@export var peach_yao_scene: PackedScene
@export var bat_scene: PackedScene
@export var frog_scene: PackedScene

# ============== 关卡配置 ==============
func _setup_stage_config() -> void:
	STAGE_ID = "peach_grove"
	SPAWN_INTERVAL_SECONDS = 5.0
	INITIAL_MONSTER_LIMIT = 50
	MAX_MONSTER_CAP = 100
	DYNAMIC_BALANCE_SPAWN_LOW_THRESHOLD = 0.4 # stage1 特有：40%（其他关卡是0.3）
	DYNAMIC_BALANCE_SPAWN_MAX_BONUS = 1.0
	DYNAMIC_BALANCE_HP_MAX_REDUCTION = 0.4
	LOW_POPULATION_FORCE_WAVE_MIN_TIME_LEFT = 1.25
	LATE_GAME_TIME_THRESHOLD = 180.0
	LATE_GAME_LOW_POPULATION_RATIO = 0.35
	BASIC_TYPES = ["slime", "peach_yao"]
	OTHER_TYPE_PER_WAVE_MAX = 1
	OTHER_TYPE_TOTAL_MAX = 4
	ELITE_MAX = 3
	# PEACH_GROVE: slime(5), peach_yao(3), frog(1)
	stage_spawn_pool = [
		{"type": "slime", "weight": 5, "blocked_early": false},
		{"type": "peach_yao", "weight": 3, "blocked_early": false},
		{"type": "frog", "weight": 1, "blocked_early": true}
	]

# ============== 初始化 ==============
func _ready() -> void:
	super () # 调用基类 _ready()（含 _setup_stage_config、计时器、信号连接等）

	# stage1 特有的相机参数
	$Player.camera.zoom = Vector2(2.7, 2.7)
	$Player.min_zoom = 2.5

	# 播放桃林BGM和环境音
	Global.emit_signal("stage_bgm", "peach_grove")

# ============== Boss位置（覆盖基类默认值）==============
func _get_boss_position() -> Vector2:
	return Vector2(-370, randf_range(185, 259))

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
				_spawn_single_slime()
			"peach_yao":
				_spawn_single_peach_yao()
			"bat":
				_spawn_single_bat()
			"frog":
				_spawn_single_frog()
		if i < spawn_list.size() - 1:
			if not is_inside_tree():
				return
			await get_tree().create_timer(0.1).timeout
			if not is_inside_tree():
				return

	monster_spawn_timer.start()

# ============== 单体怪物生成 ==============
func _spawn_single_slime() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var slime_node = slime_scene.instantiate()
	var spawn_edge = randi_range(0, 3)
	var spawn_position = Vector2.ZERO
	slime_node.move_direction = randi_range(2, 8)
	match spawn_edge:
		0: # Top
			spawn_position = Vector2(randf_range(-590, 590), 100)
		1: # Bottom
			spawn_position = Vector2(randf_range(-590, 590), 480)
		2: # Left
			spawn_position = Vector2(-590, randf_range(0, 480))
		3: # Right
			spawn_position = Vector2(590, randf_range(0, 480))
	slime_node.position = spawn_position
	get_tree().current_scene.add_child(slime_node)
	_try_make_elite(slime_node)
	_apply_dynamic_hp_reduction(slime_node)
	slime_node.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(slime_node, "modulate:a", 1.0, 0.7)
	current_monster_count += 1
	slime_node.connect("tree_exiting", Callable(self , "_on_monster_defeated"))

func _spawn_single_peach_yao() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var peach_yao_node = peach_yao_scene.instantiate()
	var spawn_edge = randi_range(0, 3)
	var spawn_position = Vector2.ZERO
	peach_yao_node.move_direction = randi_range(2, 8)
	match spawn_edge:
		0: # Top
			spawn_position = Vector2(randf_range(-590, 590), 100)
		1: # Bottom
			spawn_position = Vector2(randf_range(-590, 590), 480)
		2: # Left
			spawn_position = Vector2(-590, randf_range(0, 480))
		3: # Right
			spawn_position = Vector2(590, randf_range(0, 480))
	peach_yao_node.position = spawn_position
	get_tree().current_scene.add_child(peach_yao_node)
	_try_make_elite(peach_yao_node)
	_apply_dynamic_hp_reduction(peach_yao_node)
	peach_yao_node.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(peach_yao_node, "modulate:a", 1.0, 0.7)
	current_monster_count += 1
	peach_yao_node.connect("tree_exiting", Callable(self , "_on_monster_defeated"))

func _spawn_single_bat() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var bat_node = bat_scene.instantiate()
	var spawn_edge = randi_range(0, 3)
	var spawn_position = Vector2.ZERO
	match spawn_edge:
		0: # Top
			spawn_position = Vector2(randf_range(-590, 590), -25)
		1: # Bottom
			spawn_position = Vector2(randf_range(-590, 590), 480)
		2: # Left
			spawn_position = Vector2(-590, randf_range(0, 480))
		3: # Right
			spawn_position = Vector2(590, randf_range(0, 480))
	bat_node.position = spawn_position
	get_tree().current_scene.add_child(bat_node)
	_try_make_elite(bat_node)
	_apply_dynamic_hp_reduction(bat_node)
	bat_node.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(bat_node, "modulate:a", 1.0, 0.7)
	current_monster_count += 1
	bat_node.connect("tree_exiting", Callable(self , "_on_monster_defeated"))

func _spawn_single_frog() -> void:
	if not is_inside_tree() or get_tree().current_scene == null:
		return
	var frog_node = frog_scene.instantiate()
	var spawn_edge = randi_range(0, 3)
	var spawn_position = Vector2.ZERO
	match spawn_edge:
		0: # Top
			spawn_position = Vector2(randf_range(-590, 590), 100)
		1: # Bottom
			spawn_position = Vector2(randf_range(-590, 590), 480)
		2: # Left
			spawn_position = Vector2(-590, randf_range(0, 480))
		3: # Right
			spawn_position = Vector2(590, randf_range(0, 480))
	frog_node.position = spawn_position
	get_tree().current_scene.add_child(frog_node)
	_try_make_elite(frog_node)
	_apply_dynamic_hp_reduction(frog_node)
	frog_node.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(frog_node, "modulate:a", 1.0, 0.7)
	current_monster_count += 1
	frog_node.connect("tree_exiting", Callable(self , "_on_monster_defeated"))
	frog_node.connect("tree_exiting", func(): other_type_alive = max(0, other_type_alive - 1))
