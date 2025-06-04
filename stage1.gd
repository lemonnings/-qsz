extends Node2D

@export var joystick_left : VirtualJoystick

@export var slime_scene: PackedScene
@export var bat_scene: PackedScene
@export var frog_scene: PackedScene
@export var boss_robot_scene: PackedScene

@export var warning_scene: Control

@export var slime_spawn_timer: Timer
@export var bat_spawn_timer: Timer
@export var frog_spawn_timer: Timer

@export var point: int
var monster_move_direction: int
var map_mechanism_num: float
var map_mechanism_num_max: float

@export var hp_bar: ProgressBar
@export var exp_bar: ProgressBar
@export var map_mechanism_bar: ProgressBar
@export var hp_num: Label
@export var score_label: Label
@export var gameover_label: Label
@export var victory_label: Label
@export var attr_label: RichTextLabel

@export var buff_box: HBoxContainer
var buff_manager: BuffManager

@export var now_time: Label
@export var current_multi: Label
@export var now_lv: Label
@export var exit_button: Button

var pending_level_ups: int = 0

@export var lv_up_change: Node2D
@export var lv_up_change_b1: Button
@export var lv_up_change_b2: Button
@export var lv_up_change_b3: Button

# 主要是第一个场景的基本ui和出怪逻辑，包含了升级逻辑
func _ready() -> void:
	PC.player_instance = $Player
	Global.emit_signal("reset_camera")
	map_mechanism_num = 0
	map_mechanism_num_max = 10800
	Global.connect("player_lv_up", Callable(self, "_on_level_up"))
	Global.connect("level_up_selection_complete", Callable(self, "_check_and_process_pending_level_ups"))
	Global.connect("monster_mechanism_gained", Callable(self, "_on_monster_mechanism_gained"))
	Global.connect("boss_defeated", Callable(self, "_on_boss_defeated"))
	
	# 初始化buff管理器
	buff_manager = BuffManager.new()
	add_child(buff_manager)
	buff_manager.setup_buff_container(buff_box)
	
	# 测试添加一些buff（可以删除这部分）
	_test_buffs()


func _process(delta: float) -> void:
	# 计算时间出怪
	slime_spawn_timer.wait_time -= 0.032 * delta
	slime_spawn_timer.wait_time = clamp(slime_spawn_timer.wait_time, 0.4, 2.5)
	bat_spawn_timer.wait_time -= 0.022 * delta
	bat_spawn_timer.wait_time = clamp(bat_spawn_timer.wait_time, 1.5, 5)
	frog_spawn_timer.wait_time -= 0.02 * delta
	frog_spawn_timer.wait_time = clamp(frog_spawn_timer.wait_time, 2.5, 8)
	
	# 格式化分数显示
	var formatted_point: String
	if point >= 10000000:
		formatted_point = "%.2fm" % (point / 1000000.0)
	elif point >= 100000:
		formatted_point = "%.2fk" % (point / 1000.0)
	else:
		formatted_point = str(point)
	
	score_label.text = formatted_point
	
var boss_event_triggered: bool = false # 新增标志位，防止重复触发

func _physics_process(_delta: float) -> void:
	if not boss_event_triggered:
		map_mechanism_num += _delta * 60
		# 随着时间增长，提高怪物的属性
	#print(PC.current_time,' ',slime_spawn_timer.wait_time,' ',bat_spawn_timer.wait_time,' ',frog_spawn_timer.wait_time)
	if PC.current_time < 0.3:
		PC.current_time = PC.current_time + 0.00034
	elif PC.current_time >= 0.3 and PC.current_time <= 1.92:
		PC.current_time = PC.current_time + 0.001
	elif PC.current_time > 1.92 and PC.current_time <= 6.4:
		PC.current_time = PC.current_time + 0.0025
	elif PC.current_time > 6.4 and PC.current_time <= 19.2 and Global.world_level != 1:
		PC.current_time = PC.current_time + 0.007
	elif PC.current_time > 19.2 and PC.current_time <= 76.8 and Global.world_level != 1:
		PC.current_time = PC.current_time + 0.022
	elif PC.current_time > 76.8 and PC.current_time <= 307.2 and Global.world_level != 1:
		PC.current_time = PC.current_time + 0.075
	elif Global.world_level != 1:
		PC.current_time = PC.current_time * 1.0012
	else:
		PC.current_time = PC.current_time + 0.005
	
	if map_mechanism_num >= map_mechanism_num_max and not boss_event_triggered:
		boss_event_triggered = true
		_trigger_boss_event()
		return

	# rampage_notice
	if PC.current_time >= 0.3 and PC.current_time < 0.301:
		Global.emit_signal("rampage_notice", 1)
	
	if PC.current_time >= 1.2 and PC.current_time < 1.203:
		Global.emit_signal("rampage_notice", 2)
	
	if PC.current_time >= 4 and PC.current_time < 4.009:
		Global.emit_signal("rampage_notice", 3)
	
	if PC.current_time >= 12 and PC.current_time < 12.027:
		Global.emit_signal("rampage_notice", 4)
	
	if PC.current_time >= 48 and PC.current_time < 48.081:
		Global.emit_signal("rampage_notice", 5)
	
	if PC.current_time >= 192 and PC.current_time < 192.486:
		Global.emit_signal("rampage_notice", 6)
	
	PC.real_time += _delta
	
	# 更新时间显示 (MM:ss 格式)
	if now_time:
		var minutes = int(PC.real_time) / 60
		var seconds = int(PC.real_time) % 60
		now_time.text = "%02d : %02d" % [minutes, seconds]
	
	if PC.pc_exp >= get_required_lv_up_value(PC.pc_lv):
		pending_level_ups += 1
		PC.pc_lv += 1
		PC.pc_exp = clamp((PC.pc_exp - get_required_lv_up_value(PC.pc_lv)), 0, get_required_lv_up_value(PC.pc_lv))
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
		
	var target_value = (float(PC.pc_exp) / get_required_lv_up_value(PC.pc_lv)) * 100
	if exp_bar.value != target_value:
		if abs(target_value - exp_bar.value) > 2:
			var tween = create_tween()
			tween.tween_property(exp_bar, "value", target_value, 0.15)
		else:
			exp_bar.value = target_value
			
	if not boss_event_triggered: # 只有在boss事件未触发时才更新机制条
		map_mechanism_bar.value = (map_mechanism_num / map_mechanism_num_max) * 100
	else:
		map_mechanism_bar.value = 100
	
	now_lv.text = "Lv."+str(PC.pc_lv)
	

func _trigger_boss_event() -> void:
	print("Boss event triggered!")
	#slime_spawn_timer.wait_time += 2.0
	#bat_spawn_timer.wait_time += 3.0
	#frog_spawn_timer.wait_time += 4.0
	
	 # 停止计时器，防止在warning期间继续生成小怪
	slime_spawn_timer.stop()
	bat_spawn_timer.stop()
	frog_spawn_timer.stop()
	
	if warning_scene == null:
		print("ERROR: warning_scene is null!")
		return
	
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
	else:
		print("Warning: Could not find audio node 'warning'")
	
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
	#
	## 初始化并显示Boss血条
#
	#if boss_hp_bar_node and boss_hp_bar_node.has_method("_on_boss_hp_bar_initialize") and boss_hp_bar_node.has_method("_on_boss_hp_bar_show"):
		#boss_hp_bar_node.call("_on_boss_hp_bar_initialize", boss_max_hp, boss_max_hp, 12, "测试BOSS") # 假设Boss名字
		#boss_hp_bar_node.call("_on_boss_hp_bar_show")
		## boss_hp_bar_node.visible = true
		## if boss_hp_bar_node.has_method("fade_in"):
		## 	boss_hp_bar_node.call("fade_in", 0.5) # 0.5秒渐入
	#else:
		#printerr("BossHpBar node not found or methods missing!")

func _spawn_slime() -> void:
	var slime_node = slime_scene.instantiate()
	monster_move_direction = randi_range(0, 1)
	slime_node.move_direction = monster_move_direction
	if monster_move_direction == 0:
		slime_node.position = Vector2(-370, randf_range(185, 259))
	if monster_move_direction == 1:
		slime_node.position = Vector2(370, randf_range(185, 259))
	get_tree().current_scene.add_child(slime_node)

func _spawn_frog() -> void:
	var frog_node = frog_scene.instantiate()
	monster_move_direction = randi_range(0, 1)
	if monster_move_direction == 0:
		frog_node.position = Vector2(-370, randf_range(185, 259))
	if monster_move_direction == 1:
		frog_node.position = Vector2(370, randf_range(185, 259))
	get_tree().current_scene.add_child(frog_node)


func _spawn_bat() -> void:
	var bat_node = bat_scene.instantiate()
	monster_move_direction = randi_range(0, 1)
	bat_node.move_direction = monster_move_direction
	if monster_move_direction == 0:
		bat_node.position = Vector2(-370, randf_range(185, 244))
	if monster_move_direction == 1:
		bat_node.position = Vector2(370, randf_range(185, 244))
	get_tree().current_scene.add_child(bat_node)
	

func show_game_over():
	gameover_label.visible = true


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
			get_tree().change_scene_to_packed(Global.main_menu_instance)


func get_required_lv_up_value(level: int) -> float:
	var value: float = 1000
	for i in range(level):
		value = (value + 200) * 1.1
	return value

func reset_joystick() -> void:
	if joystick_left and joystick_left is VirtualJoystick:
		joystick_left._reset()
		joystick_left.hide()
	
func _on_level_up():
	pending_level_ups -= 1
	await get_tree().create_timer(0.15).timeout
	# 重置玩家摇杆
	reset_joystick()
	Global.is_level_up = true
	get_tree().set_pause(true)
	lv_up_change.visible = true
	PC.last_speed = PC.pc_speed
	PC.last_atk_speed = PC.pc_atk_speed
	PC.last_lunky_level = PC.now_lunky_level
	# 确定刷出来的三个升级奖励的等级
	var r1_rand = randf_range(0, 100)
	var r2_rand = randf_range(0, 100)
	var r3_rand = randf_range(0, 100)
	var reward1 = get_reward_level(r1_rand)
	var reward2 = get_reward_level(r2_rand)
	var reward3 = get_reward_level(r3_rand)
	var lvcb1: Sprite2D = lv_up_change_b1.get_node("Pic")
	lvcb1.region_rect = reward1.icon
	var lvcbd1: RichTextLabel = lv_up_change_b1.get_node("Detail")
	lvcbd1.text = reward1.text
	var callbackB1: Callable = reward1.on_selected
	var connect_array = lv_up_change_b1.pressed.get_connections()
	if !connect_array.is_empty():
		for conn in connect_array:
			lv_up_change_b1.pressed.disconnect(conn.callable)
	lv_up_change_b1.pressed.connect(callbackB1)
	
	var lvcb2: Sprite2D = lv_up_change_b2.get_node("Pic")
	lvcb2.region_rect = reward2.icon
	var lvcbd2: RichTextLabel = lv_up_change_b2.get_node("Detail")
	lvcbd2.text = reward2.text
	var callbackB2: Callable = reward2.on_selected
	var connect_array2 = lv_up_change_b2.pressed.get_connections()
	if !connect_array2.is_empty():
		for conn in connect_array2:
			lv_up_change_b2.pressed.disconnect(conn.callable)
	lv_up_change_b2.pressed.connect(callbackB2)
	
	var lvcb3: Sprite2D = lv_up_change_b3.get_node("Pic")
	lvcb3.region_rect = reward3.icon
	var lvcbd3: RichTextLabel = lv_up_change_b3.get_node("Detail")
	lvcbd3.text = reward3.text
	var callbackB3: Callable = reward3.on_selected
	var connect_array3 = lv_up_change_b3.pressed.get_connections()
	if !connect_array3.is_empty():
		for conn in connect_array3:
			lv_up_change_b3.pressed.disconnect(conn.callable)
	lv_up_change_b3.pressed.connect(callbackB3)


func _check_and_process_pending_level_ups():
	if pending_level_ups > 0:
		_on_level_up()

func get_reward_level(rand_num: float) -> LvUp.Reward:
	if rand_num <= PC.now_gold_p:
		return LvUp.unbelievable_gold()
	elif rand_num <= PC.now_orange_p + PC.now_gold_p:
		return LvUp.super2_rare_orange()
	elif rand_num <= PC.now_purple_p + PC.now_orange_p + PC.now_gold_p:
		return LvUp.super_rare_purple()
	elif rand_num <= PC.now_blue_p + PC.now_purple_p + PC.now_orange_p + PC.now_gold_p:
		return LvUp.rare_blue()
	elif rand_num <= PC.now_green_p + PC.now_blue_p + PC.now_purple_p + PC.now_orange_p + PC.now_gold_p:
		return LvUp.pro_green()
	return LvUp.normal_white()

func _on_attr_button_focus_entered() -> void:
	attr_label.visible = true
	attr_label.text = "攻击：" + str(PC.pc_atk) + "  额外攻速：" + str(PC.pc_atk_speed) + "\n额外移速：" + str(PC.pc_speed) + "  弹体大小：" + str(PC.bullet_size) + "\n天命：" + str(PC.now_lunky_level) + "  减伤：" + str(PC.damage_reduction_rate)+ "\n暴击率：" + str(PC.crit_chance) + "  暴击伤害：" + str(PC.crit_damage_multiplier) + "\n环形剑气攻击/数量/大小/射速：" + str(PC.ring_bullet_damage_multiplier) + "/"+ str(PC.ring_bullet_count) + "/"+ str(PC.ring_bullet_size_multiplier) + "/"+ str(PC.ring_bullet_interval) + "/" + "\n召唤物数量/最大数量/攻击/弹体大小/射速：" + str(PC.summon_count)+ "/" + str(PC.summon_count_max)+ "/" + str(PC.summon_damage_multiplier)+ "/" + str(PC.summon_bullet_size_multiplier)+ "/" + str(PC.summon_interval_multiplier)+ "/" + "\n开悟获取：" + str(PC.selected_rewards)


func _on_attr_button_focus_exited() -> void:
	attr_label.visible = false

func _on_monster_mechanism_gained(mechanism_value: int) -> void:
	map_mechanism_num += mechanism_value

func _test_buffs():
	pass
	# # 等待一帧确保buff管理器完全初始化
	# await get_tree().process_frame
	
	# # 添加一些测试buff
	# buff_manager.add_buff("attack_boost", 15.0, 3)
