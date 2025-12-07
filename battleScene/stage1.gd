extends Node2D

#@export var joystick_left : VirtualJoystick

@export var slime_scene: PackedScene
@export var bat_scene: PackedScene
@export var frog_scene: PackedScene
@export var boss_robot_scene: PackedScene

@export var warning_scene: Control

var MIN_SPAWN_INTERVAL : float = 2.25
var next_spawn_interval : float = 4
var SPAWN_INTERVAL_DECREMENT : float = 0.05
var SLIME_MAX_SPAWN_INCREASE_THRESHOLD : int = 8
var SLIME_MIN_SPAWN_INCREASE_THRESHOLD : int = 10
var BAT_MAX_SPAWN_INCREASE_THRESHOLD : int = 10
var BAT_MIN_SPAWN_INCREASE_THRESHOLD : int = 15
var FROG_MIN_SPAWN_INCREASE_THRESHOLD : int = 15
var FROG_MAX_SPAWN_INCREASE_THRESHOLD : int = 20
var slime_min_spawn : int = 2
var slime_max_spawn : int = 4
var slime_upper_limit : int = 12
var bat_min_spawn : int = 1
var bat_max_spawn : int = 2
var bat_upper_limit : int = 8
var frog_min_spawn : int = 1
var frog_max_spawn : int = 1
var frog_upper_limit : int = 4

@export var monster_spawn_timer: Timer # Added new unified timer

@export var point: int
var monster_move_direction: int
var map_mechanism_num: float
var map_mechanism_num_max: float

var spawn_count : int = 0

var current_monster_count: int = 0
var max_monster_limit: int = 12
const MAX_MONSTER_CAP: int = 60
const MONSTER_LIMIT_INCREASE_INTERVAL: float = 6.0 # seconds
var monster_limit_increase_timer: float = 0.0

@export var layer_ui: CanvasLayer
@export var hp_bar: ProgressBar
@export var exp_bar: ProgressBar
@export var map_mechanism_bar: ProgressBar
@export var hp_num: Label
@export var score_label: Label
@export var gameover_label: Label
@export var victory_label: Label
@export var attr_label: RichTextLabel

@export var buff_box: HBoxContainer
var emblem_manager: EmblemManager

@export var now_time: Label
@export var current_multi: Label
@export var now_lv: Label
@export var exit_button: Button

@export var skill1: TextureButton
@export var skill2: TextureButton
@export var skill3: TextureButton
@export var skill4: TextureButton
@export var skill5: TextureButton
var skill1_remain_time :float
var skill2_remain_time :float
var skill3_remain_time :float
var skill4_remain_time :float
var skill5_remain_time :float

@export var lv_up_change: Node2D
@export var lv_up_change_b1: Button
@export var lv_up_change_b2: Button
@export var lv_up_change_b3: Button

# 纹章相关
@export var emblem1 : TextureRect
@export var emblem1_panel : Panel
@export var emblem1_detail : RichTextLabel
@export var emblem2 : TextureRect
@export var emblem2_panel : Panel
@export var emblem2_detail : RichTextLabel
@export var emblem3 : TextureRect
@export var emblem3_panel : Panel
@export var emblem3_detail : RichTextLabel
@export var emblem4 : TextureRect
@export var emblem4_panel : Panel
@export var emblem4_detail : RichTextLabel
@export var emblem5 : TextureRect
@export var emblem5_panel : Panel
@export var emblem5_detail : RichTextLabel
@export var emblem6 : TextureRect
@export var emblem6_panel : Panel
@export var emblem6_detail : RichTextLabel
@export var emblem7 : TextureRect
@export var emblem7_panel : Panel
@export var emblem7_detail : RichTextLabel
@export var emblem8 : TextureRect
@export var emblem8_panel : Panel
@export var emblem8_detail : RichTextLabel





# 升级管理器
var level_up_manager: LevelUpManager

# 主要是第一个场景的基本ui和出怪逻辑，包含了升级逻辑
func _ready() -> void:
	PC.player_instance = $Player
	# 连接技能攻速更新信号
	Global.connect("skill_attack_speed_updated", Callable(self, "update_skill_cooldowns"))
	Global.emit_signal("reset_camera")
	map_mechanism_num = 0
	map_mechanism_num_max = 10800
	
	# 重置DPS计数器
	Global.reset_dps_counter()
	
	# 初始化升级管理器
	level_up_manager = LevelUpManager.new()
	add_child(level_up_manager)
	var skill_nodes_array: Array[TextureButton] = [skill1, skill2, skill3, skill4]
	level_up_manager.initialize($CanvasLayer, lv_up_change, lv_up_change_b1, lv_up_change_b2, lv_up_change_b3, layer_ui, skill_nodes_array)
	
	Global.connect("player_lv_up", Callable(self, "_on_level_up"))
	Global.connect("level_up_selection_complete", Callable(self, "_check_and_process_pending_level_ups"))
	Global.connect("monster_mechanism_gained", Callable(self, "_on_monster_mechanism_gained"))
	Global.connect("boss_defeated", Callable(self, "_on_boss_defeated"))
	
	# 初始化纹章管理器
	emblem_manager = EmblemManager.new()
	add_child(emblem_manager)
	emblem_manager.setup_emblem_container(buff_box)
	# 向纹章管理器注册 UI 槽位（TextureRect、Panel、RichTextLabel）
	var icons := [emblem1, emblem2, emblem3, emblem4, emblem5, emblem6, emblem7, emblem8]
	var panels := [emblem1_panel, emblem2_panel, emblem3_panel, emblem4_panel, emblem5_panel, emblem6_panel, emblem7_panel, emblem8_panel]
	var details := [emblem1_detail, emblem2_detail, emblem3_detail, emblem4_detail, emblem5_detail, emblem6_detail, emblem7_detail, emblem8_detail]
	emblem_manager.setup_emblem_ui(icons, panels, details)

	skill1.visible = true
	skill1.update_skill(1, $Player.fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/slash.png")

	# Initialize and start the new monster spawn timer
	monster_spawn_timer = Timer.new()
	add_child(monster_spawn_timer)
	monster_spawn_timer.wait_time = 0.1 # Start almost immediately for the first spawn
	monster_spawn_timer.one_shot = false # Make it recurring
	monster_spawn_timer.connect("timeout", Callable(self, "_on_monster_spawn_timer_timeout"))
	monster_spawn_timer.start()
	
	# 测试添加一些buff（可以删除这部分）
	_test_buffs()
	
	# 初始化技能冷却时间显示
	update_skill_cooldowns()


func _process(delta: float) -> void:
	# 格式化分数显示
	var formatted_point: String
	if point >= 10000000:
		formatted_point = "%.3fm 真气" % (point / 1000000.0)
	elif point >= 100000:
		formatted_point = "%.2fk 真气" % (point / 1000.0)
	else:
		formatted_point = str(point)
	
	if PC.has_branch and PC.first_has_branch:
		skill2.visible = true
		skill2.update_skill(2, $Player.branch_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/branch.png")
		PC.first_has_branch = false

	if PC.has_moyan and PC.first_has_moyan:
		skill3.visible = true
		skill3.update_skill(3, $Player.moyan_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/moyan.png")
		PC.first_has_moyan = false

	if PC.has_riyan and PC.first_has_riyan:
		skill4.visible = true
		skill4.update_skill(4, $Player.riyan_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/riyan.png")
		PC.first_has_riyan = false

	if PC.has_ringFire and PC.first_has_ringFire:
		skill5.visible = true
		skill5.update_skill(5, $Player.ringFire_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/ringFire.png")
		PC.first_has_ringFire = false
	
	score_label.text = formatted_point
	
	# 更新DPS显示
	var current_dps = Global.get_current_dps()
	var formatted_dps = "%.1f" % current_dps
	current_multi.text = "DPS: " + formatted_dps
	
var boss_event_triggered: bool = false # 新增标志位，防止重复触发

# 更新技能冷却时间显示
func update_skill_cooldowns() -> void:
	# 更新主攻击技能
	if skill1.visible:
		skill1.update_skill(1, $Player.fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/slash.png")
	
	# 更新分支技能
	if PC.has_branch and skill2.visible:
		skill2.update_skill(2, $Player.branch_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/branch.png")
	
	# 更新魔焰技能
	if PC.has_moyan and skill3.visible:
		skill3.update_skill(3, $Player.moyan_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/moyan.png")
	
	# 更新日焰技能
	if PC.has_riyan and skill4.visible:
		skill4.update_skill(4, $Player.riyan_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/riyan.png")
	
	# 更新环形火焰技能
	if PC.has_ringFire and skill5.visible:
		skill5.update_skill(5, $Player.ringFire_fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/ringFire.png")


func _physics_process(_delta: float) -> void:
	monster_limit_increase_timer += _delta
	if monster_limit_increase_timer >= MONSTER_LIMIT_INCREASE_INTERVAL:
		monster_limit_increase_timer = 0.0
		if max_monster_limit < MAX_MONSTER_CAP:
			max_monster_limit += 1

	if not boss_event_triggered:
		map_mechanism_num += _delta * 30
		# 随着时间增长，提高怪物的属性
	#print(PC.current_time,' ',slime_spawn_timer.wait_time,' ',bat_spawn_timer.wait_time,' ',frog_spawn_timer.wait_time)
	if PC.current_time < 0.3:
		PC.current_time = PC.current_time + 0.00024
	elif PC.current_time > 0.6 and PC.current_time <= 6.4:
		PC.current_time = PC.current_time + 0.00048
	else:
		PC.current_time = PC.current_time + 0.001
	
	if map_mechanism_num >= map_mechanism_num_max and not boss_event_triggered:
		boss_event_triggered = true
		_trigger_boss_event()
		return
	
	PC.real_time += _delta
	
	# 更新时间显示 (MM:ss 格式)
	if now_time:
		var minutes = int(PC.real_time) / 60
		var seconds = int(PC.real_time) % 60
		now_time.text = "%02d : %02d" % [minutes, seconds]
	
	if PC.pc_exp >= level_up_manager.get_required_lv_up_value(PC.pc_lv):
		level_up_manager.add_pending_level_up()
		PC.pc_lv += 1
		PC.pc_exp = clamp((PC.pc_exp - level_up_manager.get_required_lv_up_value(PC.pc_lv)), 0, level_up_manager.get_required_lv_up_value(PC.pc_lv))
		Global.emit_signal("player_lv_up")
		
	var target_value_hp = (float(PC.pc_hp) / PC.pc_max_hp) * 100
	if hp_bar.value != target_value_hp:
		if abs(target_value_hp - hp_bar.value) > 2:
			var tween = create_tween()
			tween.tween_property(hp_bar, "value", target_value_hp, 0.15)
		else:
			hp_bar.value = target_value_hp
		
	if PC.pc_hp <= 0:
		hp_num.text = '0 / ' + str(PC.pc_max_hp)
	else:
		hp_num.text = str(PC.pc_hp) + ' / ' + str(PC.pc_max_hp)
		
	if Global.is_level_up == false:
		lv_up_change.visible = false
		
	var target_value = (float(PC.pc_exp) / level_up_manager.get_required_lv_up_value(PC.pc_lv)) * 100
	if exp_bar.value != target_value:
		if abs(target_value - exp_bar.value) > 2:
			var tween = create_tween()
			tween.tween_property(exp_bar, "value", target_value, 0.15)
		else:
			exp_bar.value = target_value
			
	if not boss_event_triggered:
		map_mechanism_bar.value = (map_mechanism_num / map_mechanism_num_max) * 100
	else:
		map_mechanism_bar.value = 100 # 例如设为满
	
	now_lv.text = "Lv."+str(PC.pc_lv)
	

func _trigger_boss_event() -> void:
	print("Boss event triggered!")
	#slime_spawn_timer.wait_time += 2.0
	#bat_spawn_timer.wait_time += 3.0
	#frog_spawn_timer.wait_time += 4.0
	
	 # 停止计时器，防止在warning期间继续生成小怪
	#slime_spawn_timer.stop() # Removed
	#bat_spawn_timer.stop() # Removed
	#frog_spawn_timer.stop() # Removed
	monster_spawn_timer.stop() # Stop the new timer
	
	# 获取场景中的warning节点
	var warning_node = get_node_or_null("CanvasLayer/Warning")
	if warning_node == null:
		print("ERROR: warning_tip node not found in scene!")
		return
	
	# 设置warning节点不受暂停影响
	warning_node.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 设置warning节点初始状态为不可见
	warning_node.visible = false
	warning_node.modulate = Color(1, 1, 1, 0)
	
	# 获取音频节点并播放
	var warning_audio = warning_node.get_node_or_null("warning") as AudioStreamPlayer
	if warning_audio:
		warning_audio.play()
	
	# 显示节点并开始动画
	warning_node.visible = true
	
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 设置tween不受暂停影响
	tween.set_process_mode(1)
	# 渐入动画
	tween.tween_property(warning_node, "modulate:a", 1.0, 0.5)
	# 持续显示2秒
	tween.tween_interval(2.0)
	# 渐出动画
	tween.tween_property(warning_node, "modulate:a", 0.0, 0.5)
	
	# 动画结束后隐藏节点
	tween.tween_callback(func(): warning_node.visible = false)
	
	_on_warning_finished()


func _on_warning_finished() -> void:
	# 重新启动计时器 (如果需要的话，或者根据游戏逻辑决定是否重启)
	# slime_spawn_timer.start()
	# bat_spawn_timer.start()
	# frog_spawn_timer.start() 
	# monster_spawn_timer.start() 
	await get_tree().create_timer(3).timeout
	
	Global.emit_signal("boss_bgm", 1)
	
	# 添加Boss
	var boss_node = boss_robot_scene.instantiate()
	
	# 逐步缩放相机，每0.2秒-0.1，总共10次达到-1
	for i in range(7):
		Global.emit_signal("zoom_camera", -0.08)
		await get_tree().create_timer(0.2).timeout

	boss_node.position = Vector2(-370, randf_range(185, 259))
	get_tree().current_scene.add_child(boss_node)


func _on_level_up_selection_complete() -> void:
	# 委托给升级管理器处理
	level_up_manager._on_level_up_selection_complete(get_viewport())

func _on_monster_spawn_timer_timeout() -> void:
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
		
		match spawn_edge:
			0: # Top
				spawn_position = Vector2(randf_range(-400, 400), -300)
				slime_node.move_direction = randi_range(2,8) # Move towards player (downwards bias)
			1: # Bottom
				spawn_position = Vector2(randf_range(-400, 400), 300)
				slime_node.move_direction = randi_range(2,8) # Move towards player (upwards bias)
			2: # Left
				spawn_position = Vector2(-400, randf_range(15, 259))
				if randf() < 0.1:
					slime_node.move_direction = 0 # Move right (away from player)
				else:
					slime_node.move_direction = randi_range(2,8) # Move towards player (rightwards bias)
			3: # Right
				spawn_position = Vector2(400, randf_range(15, 259))
				if randf() < 0.1:
					slime_node.move_direction = 1 # Move left (away from player)
				else:
					slime_node.move_direction = randi_range(2,8) # Move towards player (leftwards bias)

		slime_node.position = spawn_position
		get_tree().current_scene.add_child(slime_node)
		current_monster_count += 1
		slime_node.connect("tree_exiting", Callable(self, "_on_monster_defeated"))

func _spawn_frog(count: int) -> void:
	for _i in range(count):
		if current_monster_count >= max_monster_limit:
			return
		var frog_node = frog_scene.instantiate()
		# Frog always spawns from left or right and moves towards player
		
		var spawn_side = randi_range(0,1) # 0 for left, 1 for right
		if spawn_side == 0:
			frog_node.position = Vector2(-400, randf_range(15, 259))
		else:
			frog_node.position = Vector2(400, randf_range(15, 259))
		# Frog move_direction is handled within its own script, typically towards player


		get_tree().current_scene.add_child(frog_node)
		current_monster_count += 1
		frog_node.connect("tree_exiting", Callable(self, "_on_monster_defeated"))

func _spawn_bat(count: int) -> void:
	for _i in range(count):
		if current_monster_count >= max_monster_limit:
			return
		var bat_node = bat_scene.instantiate()

		var spawn_edge = randi_range(0, 3)
		var spawn_position = Vector2.ZERO

		match spawn_edge:
			0: # Top
				spawn_position = Vector2(randf_range(-400, 400), -300)
				bat_node.move_direction = randi_range(2,8) # Move towards player (downwards bias)
			1: # Bottom
				spawn_position = Vector2(randf_range(-400, 400), 300)
				bat_node.move_direction = randi_range(2,8) # Move towards player (upwards bias)
			2: # Left
				spawn_position = Vector2(-400, randf_range(15, 244))
				if randf() < 0.1:
					bat_node.move_direction = 0 # Move right (away from player)
				else:
					bat_node.move_direction = randi_range(2,8) # Move towards player (rightwards bias)
			3: # Right
				spawn_position = Vector2(400, randf_range(15, 244))
				if randf() < 0.1:
					bat_node.move_direction = 1 # Move left (away from player)
				else:
					bat_node.move_direction = randi_range(2,8) # Move towards player (leftwards bias)

		bat_node.position = spawn_position
		get_tree().current_scene.add_child(bat_node)
		current_monster_count += 1
		bat_node.connect("tree_exiting", Callable(self, "_on_monster_defeated"))

func _on_monster_defeated():
	current_monster_count -= 1
	# 确保计数器不会变为负数
	current_monster_count = max(0, current_monster_count)
	
func show_game_over():
	gameover_label.visible = true
	# 等待2秒后返回主城
	await get_tree().create_timer(2).timeout
	Global.emit_signal("normal_bgm")
	# 返回主城
	SceneChange.change_scene("res://Scenes/main_town.tscn", true)

func _on_boss_defeated(get_point : int):
	if not PC.is_game_over:
		# 播放胜利音效
		$Victory.play()
		# 调用player_action.gd中的show_victory()函数
		victory_label.visible = true
		get_tree().current_scene.point += get_point
		Global.total_points += get_point
		Global.save_game()
		await get_tree().create_timer(4).timeout
		
		Global.emit_signal("normal_bgm")
		# 返回主菜单
		if Global.main_menu_instance != null:
			# 设置菜单状态
			Global.in_menu = true
			SceneChange.change_scene("res://Scenes/main_menu.tscn", true)


func _on_level_up(main_skill_name: String = '', refresh_id: int = 0):
	# 委托给升级管理器处理
	level_up_manager.handle_level_up(main_skill_name, refresh_id, get_tree(), get_viewport())
	

func _check_and_process_pending_level_ups():
	# 委托给升级管理器处理
	level_up_manager.check_and_process_pending_level_ups(get_tree(), get_viewport())

func _on_attr_button_focus_entered() -> void:
	attr_label.visible = true
	attr_label.text = "dps：" + str(Global.get_current_dps()) + "\n攻击：" + str(PC.pc_atk) + "  额外攻速：" + str(PC.pc_atk_speed) + "\n额外移速：" + str(PC.pc_speed) + "  弹体大小：" + str(PC.bullet_size) + "\n天命：" + str(PC.now_lunky_level) + "  减伤：" + str(PC.damage_reduction_rate)+ "\n暴击率：" + str(PC.crit_chance) + "  暴击伤害：" + str(PC.crit_damage_multi) + "\n环形剑气攻击/数量/大小/射速：" + str(PC.ring_bullet_damage_multiplier) + "/"+ str(PC.ring_bullet_count) + "/"+ str(PC.ring_bullet_size_multiplier) + "/"+ str(PC.ring_bullet_interval) + "/" + "\n召唤物数量/最大数量/攻击/弹体大小/射速：" + str(PC.summon_count)+ "/" + str(PC.summon_count_max)+ "/" + str(PC.summon_damage_multiplier)+ "/" + str(PC.summon_bullet_size_multiplier)+ "/" + str(PC.summon_interval_multiplier)+ "/" + "\n开悟获取：" + str(PC.selected_rewards)

func _on_attr_button_focus_exited() -> void:
	attr_label.visible = false


func _on_monster_mechanism_gained(mechanism_value: int) -> void:
	map_mechanism_num += mechanism_value

# 测试buff功能的函数
func _test_buffs():
	pass


func _on_skill_icon_1_mouse_entered() -> void:
	var skill1Text = "[font_size=32]剑气  LV. " + str(PC.main_skill_swordQi) +"[/font_size]" 
	skill1Text = skill1Text +  "\n基本伤害倍率： " + str((PC.main_skill_swordQi_damage * 100))  + "%"
	skill1Text = skill1Text +  "\n基本攻击速度：" + str(("%.2f" % ($Player.fire_speed.wait_time))) + "秒/次"
	skill1Text = skill1Text +  "\n附加效果："
	if PC.selected_rewards.has("SplitSwordQi1"):
		skill1Text = skill1Text +  "\n分光剑气"
	if PC.selected_rewards.has("SplitSwordQi2"):
		skill1Text = skill1Text +  "\n无上剑痕"
	if PC.selected_rewards.has("SplitSwordQi3"):
		skill1Text = skill1Text +  "\n穿云剑气"
	if PC.selected_rewards.has("SplitSwordQi4"):
		skill1Text = skill1Text +  "\n追踪剑气"
	if PC.selected_rewards.has("SplitSwordQi11"):
		skill1Text = skill1Text +  "\n分光剑气-逆"
	if PC.selected_rewards.has("SplitSwordQi12"):
		skill1Text = skill1Text +  "\n分光剑气-裂"
	if PC.selected_rewards.has("SplitSwordQi13"):
		skill1Text = skill1Text +  "\n分光剑气-环"
	if PC.selected_rewards.has("SplitSwordQi21"):
		skill1Text = skill1Text +  "\n无上剑痕-精"
	if PC.selected_rewards.has("SplitSwordQi22"):
		skill1Text = skill1Text +  "\n无上剑痕-复"
	if PC.selected_rewards.has("SplitSwordQi23"):
		skill1Text = skill1Text +  "\n无上剑痕-囚"
	if PC.selected_rewards.has("SplitSwordQi31"):
		skill1Text = skill1Text +  "\n穿云剑气-透"
	if PC.selected_rewards.has("SplitSwordQi32"):
		skill1Text = skill1Text +  "\n穿云剑气-利"
	if PC.selected_rewards.has("SplitSwordQi33"):
		skill1Text = skill1Text +  "\n穿云剑气-伤"

	$CanvasLayer/SkillLabel1.text = skill1Text
	$CanvasLayer/SkillLabel1.visible = true


func _on_skill_icon_1_mouse_exited() -> void:
	$CanvasLayer/SkillLabel1.visible = false


func _on_refresh_button_pressed() -> void:
	# 委托给升级管理器处理
	level_up_manager.handle_refresh_button(1, get_tree(), get_viewport())


func _on_refresh_button_2_pressed() -> void:
	# 委托给升级管理器处理
	level_up_manager.handle_refresh_button(2, get_tree(), get_viewport())


func _on_refresh_button_3_pressed() -> void:
	# 委托给升级管理器处理
	level_up_manager.handle_refresh_button(3, get_tree(), get_viewport())


func _on_emblem_1_mouse_entered() -> void:
	if emblem1_detail.text != "":
		emblem1_detail.visible = true
		emblem1_panel.visible = true


func _on_emblem_1_mouse_exited() -> void:
	emblem1_detail.visible = false
	emblem1_panel.visible = false


func _on_emblem_2_mouse_entered() -> void:
	if emblem2_detail.text != "":
		emblem2_detail.visible = true
		emblem2_panel.visible = true


func _on_emblem_2_mouse_exited() -> void:
	emblem2_detail.visible = false
	emblem2_panel.visible = false


func _on_emblem_3_mouse_entered() -> void:
	if emblem3_detail.text != "":
		emblem3_detail.visible = true
		emblem3_panel.visible = true


func _on_emblem_3_mouse_exited() -> void:
	emblem3_detail.visible = false
	emblem3_panel.visible = false


func _on_emblem_4_mouse_entered() -> void:
	if emblem4_detail.text != "":
		emblem4_detail.visible = true
		emblem4_panel.visible = true


func _on_emblem_4_mouse_exited() -> void:
	emblem4_detail.visible = false
	emblem4_panel.visible = false


func _on_emblem_5_mouse_entered() -> void:
	if emblem5_detail.text != "":
		emblem5_detail.visible = true
		emblem5_panel.visible = true


func _on_emblem_5_mouse_exited() -> void:
	emblem5_detail.visible = false
	emblem5_panel.visible = false


func _on_emblem_6_mouse_entered() -> void:
	if emblem6_detail.text != "":
		emblem6_detail.visible = true
		emblem6_panel.visible = true


func _on_emblem_6_mouse_exited() -> void:
	emblem6_detail.visible = false
	emblem6_panel.visible = false


func _on_emblem_7_mouse_entered() -> void:
	if emblem7_detail.text != "":
		emblem7_detail.visible = true
		emblem7_panel.visible = true


func _on_emblem_7_mouse_exited() -> void:
	emblem7_detail.visible = false
	emblem7_panel.visible = false


func _on_emblem_8_mouse_entered() -> void:
	if emblem8_detail.text != "":
		emblem8_detail.visible = true
		emblem8_panel.visible = true


func _on_emblem_8_mouse_exited() -> void:
	emblem8_detail.visible = false
	emblem8_panel.visible = false
