extends Node2D

# ============== 关卡配置 ==============
@export var slime_scene: PackedScene
@export var bat_scene: PackedScene
@export var frog_scene: PackedScene
@export var boss_robot_scene: PackedScene

@export var warning_scene: Control

# 出怪间隔配置
var MIN_SPAWN_INTERVAL: float = 0.5
# var MIN_SPAWN_INTERVAL: float = 2.25
# var next_spawn_interval: float = 4
var next_spawn_interval: float = 1
var SPAWN_INTERVAL_DECREMENT: float = 0.05

# 怪物生成阈值
var SLIME_MAX_SPAWN_INCREASE_THRESHOLD: int = 8
var SLIME_MIN_SPAWN_INCREASE_THRESHOLD: int = 10
var BAT_MAX_SPAWN_INCREASE_THRESHOLD: int = 10
var BAT_MIN_SPAWN_INCREASE_THRESHOLD: int = 15
var FROG_MIN_SPAWN_INCREASE_THRESHOLD: int = 15
var FROG_MAX_SPAWN_INCREASE_THRESHOLD: int = 20

# 怪物生成数量
var slime_min_spawn: int = 2
var slime_max_spawn: int = 4
var slime_upper_limit: int = 12
var bat_min_spawn: int = 1
var bat_max_spawn: int = 2
var bat_upper_limit: int = 8
var frog_min_spawn: int = 1
var frog_max_spawn: int = 1
var frog_upper_limit: int = 4

@export var monster_spawn_timer: Timer

@export var point: int
var monster_move_direction: int
var map_mechanism_num: float
var map_mechanism_num_max: float

var spawn_count: int = 0
var current_monster_count: int = 0
var max_monster_limit: int = 12
const MAX_MONSTER_CAP: int = 60
const MONSTER_LIMIT_INCREASE_INTERVAL: float = 6.0
var monster_limit_increase_timer: float = 0.0

var boss_event_triggered: bool = false

# 精英怪配置
const ELITE_SPAWN_CHANCE: float = 0.05 # 5%概率生成精英怪
const ELITE_SCALE_MULTIPLIER: float = 1.3 # 体型增加30%
const ELITE_ATK_MULTIPLIER: float = 1.2 # 攻击提升20%
const ELITE_HP_MULTIPLIER: float = 9.0 # 血量提升800%
const ELITE_EXP_MULTIPLIER: float = 5.0 # 经验5倍
const ELITE_POINT_MULTIPLIER: float = 5.0 # 真气5倍
const ELITE_DROP_MULTIPLIER: float = 10.0 # 掉落率10倍

# UI子场景引用
@export var layer_ui: CanvasLayer

# ============== 初始化 ==============
func _ready() -> void:
	PC.player_instance = $Player
	Global.emit_signal("reset_camera")
	
	# stage1 特定的相机设置
	$Player.camera.zoom = Vector2(2.55, 2.55)
	$Player.min_zoom = 2.25
	
	map_mechanism_num = 0
	map_mechanism_num_max = 1800
	# map_mechanism_num_max = 14000
	
	Global.reset_dps_counter()
	
	# 连接关卡特定信号
	Global.connect("monster_mechanism_gained", Callable(self, "_on_monster_mechanism_gained"))
	Global.connect("boss_defeated", Callable(self, "_on_boss_defeated"))
	
	# 初始化主技能图标
	layer_ui.init_main_skill($Player.fire_speed.wait_time)
	
	# 初始化怪物生成计时器
	monster_spawn_timer = Timer.new()
	add_child(monster_spawn_timer)
	monster_spawn_timer.wait_time = 0.1
	monster_spawn_timer.one_shot = false
	monster_spawn_timer.connect("timeout", Callable(self, "_on_monster_spawn_timer_timeout"))
	monster_spawn_timer.start()
	
	# 初始化技能冷却显示
	layer_ui.update_skill_cooldowns($Player)

# ============== 每帧更新 ==============
func _process(_delta: float) -> void:
	# 更新分数显示
	layer_ui.update_score_display(point)
	
	# 检查并更新技能图标
	layer_ui.check_and_update_skill_icons($Player)
	
	# 更新DPS显示
	layer_ui.update_dps_display()

func _physics_process(_delta: float) -> void:
	# 怪物上限递增
	monster_limit_increase_timer += _delta
	if monster_limit_increase_timer >= MONSTER_LIMIT_INCREASE_INTERVAL:
		monster_limit_increase_timer = 0.0
		if max_monster_limit < MAX_MONSTER_CAP:
			max_monster_limit += 1

	# 机关进度更新
	if not boss_event_triggered:
		map_mechanism_num += _delta * 30
	
	# 难度递增
	if PC.current_time < 0.3:
		PC.current_time = PC.current_time + 0.00024
	elif PC.current_time > 0.6 and PC.current_time <= 6.4:
		PC.current_time = PC.current_time + 0.00048
	else:
		PC.current_time = PC.current_time + 0.001
	
	# 检查Boss触发
	if map_mechanism_num >= map_mechanism_num_max and not boss_event_triggered:
		boss_event_triggered = true
		_trigger_boss_event()
		return
	
	PC.real_time += _delta
	
	# 更新UI显示
	layer_ui.update_time_display(PC.real_time)
	_check_level_up()
	layer_ui.update_hp_bar(PC.pc_hp, PC.pc_max_hp)
	layer_ui.update_lv_up_visibility()
	layer_ui.update_exp_bar(PC.pc_exp, layer_ui.get_required_lv_up_value(PC.pc_lv))
	layer_ui.update_mechanism_bar(map_mechanism_num, map_mechanism_num_max, boss_event_triggered)
	layer_ui.update_level_display(PC.pc_lv)

# ============== 升级检查 ==============
func _check_level_up() -> void:
	if PC.pc_exp >= layer_ui.get_required_lv_up_value(PC.pc_lv):
		layer_ui.add_pending_level_up()
		PC.pc_lv += 1
		PC.pc_exp = clamp((PC.pc_exp - layer_ui.get_required_lv_up_value(PC.pc_lv)), 0, layer_ui.get_required_lv_up_value(PC.pc_lv))
		Global.emit_signal("player_lv_up")
	

# ============== Boss事件 ==============
func _trigger_boss_event() -> void:
	print("Boss event triggered!")
	monster_spawn_timer.stop()
	
	# 播放Warning动画
	layer_ui.play_warning_animation()
	
	_on_warning_finished()

func _on_warning_finished() -> void:
	await get_tree().create_timer(3).timeout
	
	Global.emit_signal("boss_bgm", 1)
	
	var boss_node = boss_robot_scene.instantiate()
	
	# 逐步缩放相机
	for i in range(7):
		Global.emit_signal("zoom_camera", -0.08)
		await get_tree().create_timer(0.2).timeout

	boss_node.position = Vector2(-370, randf_range(185, 259))
	get_tree().current_scene.add_child(boss_node)


func _on_monster_spawn_timer_timeout() -> void:
	# Boss出现后不再生成怪物
	if boss_event_triggered:
		return
		
	spawn_count += 1

	next_spawn_interval = max(MIN_SPAWN_INTERVAL, next_spawn_interval - SPAWN_INTERVAL_DECREMENT)
	monster_spawn_timer.wait_time = next_spawn_interval

	if spawn_count % SLIME_MAX_SPAWN_INCREASE_THRESHOLD == 0:
		slime_max_spawn = min(slime_max_spawn + 1, slime_upper_limit)
	if spawn_count % SLIME_MIN_SPAWN_INCREASE_THRESHOLD == 0:
		slime_min_spawn = min(slime_min_spawn + 1, slime_max_spawn)
	if spawn_count % BAT_MAX_SPAWN_INCREASE_THRESHOLD == 0:
		bat_max_spawn = min(bat_max_spawn + 1, bat_upper_limit)
	if spawn_count % BAT_MIN_SPAWN_INCREASE_THRESHOLD == 0:
		bat_min_spawn = min(bat_min_spawn + 1, bat_max_spawn)
	if spawn_count % FROG_MIN_SPAWN_INCREASE_THRESHOLD == 0:
		frog_min_spawn = min(frog_min_spawn + 1, frog_max_spawn)
	if spawn_count % FROG_MAX_SPAWN_INCREASE_THRESHOLD == 0:
		frog_max_spawn = min(frog_max_spawn + 1, frog_upper_limit)
		
	# 检查是否还有空间生成怪物，如果没有则跳过本次生成
	if current_monster_count >= max_monster_limit:
		return

	# 创建怪物生成任务数组
	var spawn_tasks = []
	
	# 添加青蛙生成任务
	var num_frogs_to_spawn = randi_range(frog_min_spawn, frog_max_spawn)
	spawn_tasks.append({"type": "frog", "count": num_frogs_to_spawn})
	
	# 添加蝙蝠生成任务
	var num_bats_to_spawn = randi_range(bat_min_spawn, bat_max_spawn)
	spawn_tasks.append({"type": "bat", "count": num_bats_to_spawn})
	
	# 添加史莱姆生成任务
	var num_slimes_to_spawn = randi_range(slime_min_spawn, slime_max_spawn)
	spawn_tasks.append({"type": "slime", "count": num_slimes_to_spawn})
	
	# 随机打乱生成顺序
	spawn_tasks.shuffle()
	
	# 按随机顺序执行生成任务
	for task in spawn_tasks:
		if current_monster_count >= max_monster_limit:
			break
			
		match task.type:
			"frog":
				_spawn_frog(task.count)
			"bat":
				_spawn_bat(task.count)
			"slime":
				_spawn_slime(task.count)


func _spawn_slime(count: int) -> void:
	for _i in range(count):
		if current_monster_count >= max_monster_limit:
			return
		var slime_node = slime_scene.instantiate()
		
		# Determine spawn edge (0: top, 1: bottom, 2: left, 3: right)
		var spawn_edge = randi_range(0, 3)
		var spawn_position = Vector2.ZERO
		
		# 所有slime都使用追踪玩家模式（取消左右平移）
		slime_node.move_direction = randi_range(2, 8)
		
		match spawn_edge:
			0: # Top - 基于Camera2D limit_top=-18
				spawn_position = Vector2(randf_range(-590, 590), -25)
			1: # Bottom - 基于Camera2D limit_bottom=485
				spawn_position = Vector2(randf_range(-590, 590), 480)
			2: # Left - 基于Camera2D limit_left=-600
				spawn_position = Vector2(-590, randf_range(0, 480))
			3: # Right - 基于Camera2D limit_right=595
				spawn_position = Vector2(590, randf_range(0, 480))

		slime_node.position = spawn_position
		get_tree().current_scene.add_child(slime_node)
		
		# 精英怪判定（5%概率）
		_try_make_elite(slime_node)
		
		# 渐显效果 0.7秒
		slime_node.modulate.a = 0
		var tween = create_tween()
		tween.tween_property(slime_node, "modulate:a", 1.0, 0.7)
		
		current_monster_count += 1
		slime_node.connect("tree_exiting", Callable(self, "_on_monster_defeated"))
		
		# 同一波次每个怪物生成间隔0.1秒
		if _i < count - 1:
			await get_tree().create_timer(0.1).timeout

func _spawn_frog(count: int) -> void:
	for _i in range(count):
		if current_monster_count >= max_monster_limit:
			return
		var frog_node = frog_scene.instantiate()
		# Frog always spawns from left or right and moves towards player
		# frog保留特殊行动模式
		
		var spawn_side = randi_range(0, 1) # 0 for left, 1 for right
		if spawn_side == 0:
			frog_node.position = Vector2(-590, randf_range(15, 259))
		else:
			frog_node.position = Vector2(590, randf_range(15, 259))
		# Frog move_direction is handled within its own script, typically towards player

		get_tree().current_scene.add_child(frog_node)
		
		# 精英怪判定（5%概率）
		_try_make_elite(frog_node)
		
		# 渐显效果 0.7秒
		frog_node.modulate.a = 0
		var tween = create_tween()
		tween.tween_property(frog_node, "modulate:a", 1.0, 0.7)
		
		current_monster_count += 1
		frog_node.connect("tree_exiting", Callable(self, "_on_monster_defeated"))
		
		# 同一波次每个怪物生成间隔0.1秒
		if _i < count - 1:
			await get_tree().create_timer(0.1).timeout

func _spawn_bat(count: int) -> void:
	for _i in range(count):
		if current_monster_count >= max_monster_limit:
			return
		var bat_node = bat_scene.instantiate()

		var spawn_edge = randi_range(0, 3)
		var spawn_position = Vector2.ZERO

		# 所有bat都使用追踪玩家模式（取消左右平移）
		bat_node.move_direction = randi_range(2, 8)

		match spawn_edge:
			0: # Top - 基于Camera2D limit_top=-18
				spawn_position = Vector2(randf_range(-590, 590), -25)
			1: # Bottom - 基于Camera2D limit_bottom=485
				spawn_position = Vector2(randf_range(-590, 590), 480)
			2: # Left - 基于Camera2D limit_left=-600
				spawn_position = Vector2(-590, randf_range(0, 480))
			3: # Right - 基于Camera2D limit_right=595
				spawn_position = Vector2(590, randf_range(0, 480))

		bat_node.position = spawn_position
		get_tree().current_scene.add_child(bat_node)
		
		# 精英怪判定（5%概率）
		_try_make_elite(bat_node)
		
		# 渐显效果 0.7秒
		bat_node.modulate.a = 0
		var tween = create_tween()
		tween.tween_property(bat_node, "modulate:a", 1.0, 0.7)
		
		current_monster_count += 1
		bat_node.connect("tree_exiting", Callable(self, "_on_monster_defeated"))
		
		# 同一波次每个怪物生成间隔0.1秒
		if _i < count - 1:
			await get_tree().create_timer(0.1).timeout

func _on_monster_defeated():
	current_monster_count -= 1
	# 确保计数器不会变为负数
	current_monster_count = max(0, current_monster_count)

## 尝试将怪物升级为精英怪（5%概率）
func _try_make_elite(monster_node: Node) -> void:
	if randf() > ELITE_SPAWN_CHANCE:
		return # 未触发精英怪
	
	# 标记为精英怪
	monster_node.is_elite = true
	
	# 体型增加30%
	monster_node.scale *= ELITE_SCALE_MULTIPLIER
	
	# 攻击提升20%
	monster_node.atk *= ELITE_ATK_MULTIPLIER
	
	# 血量提升800%
	monster_node.hp *= ELITE_HP_MULTIPLIER
	monster_node.hpMax *= ELITE_HP_MULTIPLIER
	
	# 经验5倍
	monster_node.get_exp = int(monster_node.get_exp * ELITE_EXP_MULTIPLIER)
	
	# 真气5倍
	monster_node.get_point = int(monster_node.get_point * ELITE_POINT_MULTIPLIER)
	
	# 掉落率10倍
	monster_node.drop_rate_multiplier = ELITE_DROP_MULTIPLIER
	
	# 添加金色滤镜（透明度0.2）
	_apply_elite_visual(monster_node)

## 应用精英怪视觉效果（金色滤镜）
func _apply_elite_visual(monster_node: Node) -> void:
	# 获取精灵节点并添加金色色调
	var sprite = monster_node.get_node_or_null("AnimatedSprite2D")
	if sprite:
		# 使用金色色调修改精灵颜色（保留原始颜色但添加金色叠加）
		# RGB(255, 215, 0) 是金色，混合后能让怪物带有金色光泽
		sprite.modulate = Color(1.0, 0.9, 0.5, 1.0) # 金色色调
	
	# 给怪物添加金色光晕效果（可选）
	monster_node.set_meta("is_elite_monster", true)
	
# ============== 游戏结果 ==============
func show_game_over():
	layer_ui.show_game_over()
	await get_tree().create_timer(2).timeout
	Global.emit_signal("normal_bgm")
	SceneChange.change_scene("res://Scenes/main_town.tscn", true)

func _on_boss_defeated(get_point: int):
	if not PC.is_game_over:
		$Victory.play()
		layer_ui.show_victory()
		get_tree().current_scene.point += get_point
		Global.total_points += get_point
		Global.save_game()
		await get_tree().create_timer(5).timeout
		
		Global.emit_signal("normal_bgm")
		Global.in_menu = true
		SceneChange.change_scene("res://Scenes/main_town.tscn", true)

func _on_monster_mechanism_gained(mechanism_value: int) -> void:
	map_mechanism_num += mechanism_value

# ============== UI回调代理 ==============
func _on_attr_button_focus_entered() -> void:
	layer_ui.show_attr_label()

func _on_attr_button_focus_exited() -> void:
	layer_ui.hide_attr_label()

func _on_skill_icon_1_mouse_entered() -> void:
	layer_ui.show_skill1_label($Player)

func _on_skill_icon_1_mouse_exited() -> void:
	layer_ui.hide_skill1_label()

func _on_refresh_button_pressed() -> void:
	layer_ui.handle_refresh_button(1)

func _on_refresh_button_2_pressed() -> void:
	layer_ui.handle_refresh_button(2)

func _on_refresh_button_3_pressed() -> void:
	layer_ui.handle_refresh_button(3)

# 纹章鼠标事件
func _on_emblem_1_mouse_entered() -> void:
	layer_ui.show_emblem_detail(1)

func _on_emblem_1_mouse_exited() -> void:
	layer_ui.hide_emblem_detail(1)

func _on_emblem_2_mouse_entered() -> void:
	layer_ui.show_emblem_detail(2)

func _on_emblem_2_mouse_exited() -> void:
	layer_ui.hide_emblem_detail(2)

func _on_emblem_3_mouse_entered() -> void:
	layer_ui.show_emblem_detail(3)

func _on_emblem_3_mouse_exited() -> void:
	layer_ui.hide_emblem_detail(3)

func _on_emblem_4_mouse_entered() -> void:
	layer_ui.show_emblem_detail(4)

func _on_emblem_4_mouse_exited() -> void:
	layer_ui.hide_emblem_detail(4)

func _on_emblem_5_mouse_entered() -> void:
	layer_ui.show_emblem_detail(5)

func _on_emblem_5_mouse_exited() -> void:
	layer_ui.hide_emblem_detail(5)

func _on_emblem_6_mouse_entered() -> void:
	layer_ui.show_emblem_detail(6)

func _on_emblem_6_mouse_exited() -> void:
	layer_ui.hide_emblem_detail(6)

func _on_emblem_7_mouse_entered() -> void:
	layer_ui.show_emblem_detail(7)

func _on_emblem_7_mouse_exited() -> void:
	layer_ui.hide_emblem_detail(7)

func _on_emblem_8_mouse_entered() -> void:
	layer_ui.show_emblem_detail(8)

func _on_emblem_8_mouse_exited() -> void:
	layer_ui.hide_emblem_detail(8)
