extends Node2D

#@export var joystick_left : VirtualJoystick

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

var current_monster_count: int = 0
var max_monster_limit: int = 90
const MAX_MONSTER_CAP: int = 240
const MONSTER_LIMIT_INCREASE_INTERVAL: float = 3.0 # seconds
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
var buff_manager: BuffManager

@export var now_time: Label
@export var current_multi: Label
@export var now_lv: Label
@export var exit_button: Button

@export var skill1: TextureButton
@export var skill2: TextureButton
@export var skill3: TextureButton
@export var skill4: TextureButton

var pending_level_ups: int = 0

@export var lv_up_change: Node2D
@export var lv_up_change_b1: Button
@export var lv_up_change_b2: Button
@export var lv_up_change_b3: Button

var now_main_skill_name : String

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
	
	skill1.visible = true
	skill1.update_skill(1, $Player.fire_speed.wait_time, "res://AssetBundle/Sprites/Sprite sheets/skillIcon/slash.png")
	
	# 测试添加一些buff（可以删除这部分）
	_test_buffs()


func _process(delta: float) -> void:
	# 计算时间出怪
	slime_spawn_timer.wait_time -= 0.016 * delta
	#slime_spawn_timer.wait_time = clamp(slime_spawn_timer.wait_time, 0.125, 1.1)
	slime_spawn_timer.wait_time = clamp(slime_spawn_timer.wait_time, 0.125, 0.125)
	bat_spawn_timer.wait_time -= 0.011 * delta
	#bat_spawn_timer.wait_time = clamp(bat_spawn_timer.wait_time, 0.55, 2)
	bat_spawn_timer.wait_time = clamp(bat_spawn_timer.wait_time, 0.55, 0.55)
	frog_spawn_timer.wait_time -= 0.01 * delta
	#frog_spawn_timer.wait_time = clamp(frog_spawn_timer.wait_time, 2, 6)
	frog_spawn_timer.wait_time = clamp(frog_spawn_timer.wait_time, 2, 2)
	
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
	monster_limit_increase_timer += _delta
	if monster_limit_increase_timer >= MONSTER_LIMIT_INCREASE_INTERVAL:
		monster_limit_increase_timer = 0.0
		if max_monster_limit < MAX_MONSTER_CAP:
			max_monster_limit += 1

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
		map_mechanism_bar.value = 100 # 例如设为满
	
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
	# 重新启动计时器 (如果需要的话，或者根据游戏逻辑决定是否重启)
	# slime_spawn_timer.start()
	# bat_spawn_timer.start()
	# frog_spawn_timer.start()
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
	# 清理升级选择时创建的背景变暗效果
	var dark_overlay = get_meta("dark_overlay", null)
	if dark_overlay != null:
		dark_overlay.queue_free()
		remove_meta("dark_overlay")
	
	# 断开信号连接
	if Global.is_connected("level_up_selection_complete", _on_level_up_selection_complete):
		Global.disconnect("level_up_selection_complete", _on_level_up_selection_complete)


func _spawn_slime() -> void:
	if current_monster_count >= max_monster_limit:
		return
	var slime_node = slime_scene.instantiate()
	monster_move_direction = randi_range(0, 9)
	slime_node.move_direction = monster_move_direction
	if monster_move_direction == 0:
		slime_node.position = Vector2(-400, randf_range(15, 259))
	if monster_move_direction == 1:
		slime_node.position = Vector2(400, randf_range(15, 259))
	if monster_move_direction >= 2 and monster_move_direction <= 8:
		slime_node.position = Vector2( randf_range(-400, 400),300)
	else:
		slime_node.position = Vector2(400, randf_range(15, 259))
	get_tree().current_scene.add_child(slime_node)
	current_monster_count += 1
	slime_node.connect("tree_exiting", Callable(self, "_on_monster_defeated"))

func _spawn_frog() -> void:
	if current_monster_count >= max_monster_limit:
		return
	var frog_node = frog_scene.instantiate()
	monster_move_direction = randi_range(0, 1)
	if monster_move_direction == 0:
		frog_node.position = Vector2(-400, randf_range(15, 259))
	if monster_move_direction == 1:
		frog_node.position = Vector2(400, randf_range(15, 259))
	get_tree().current_scene.add_child(frog_node)
	current_monster_count += 1
	frog_node.connect("tree_exiting", Callable(self, "_on_monster_defeated"))


func _spawn_bat() -> void:
	if current_monster_count >= max_monster_limit:
		return
	var bat_node = bat_scene.instantiate()
	monster_move_direction = randi_range(0, 9)
	bat_node.move_direction = monster_move_direction
	if monster_move_direction == 0:
		bat_node.position = Vector2(-400, randf_range(15, 244))
	if monster_move_direction == 1:
		bat_node.position = Vector2(400, randf_range(15, 244))
	if monster_move_direction >= 2 and monster_move_direction <= 8:
		bat_node.position = Vector2( randf_range(-400, 400),300)
	else:
		bat_node.position = Vector2(400, randf_range(15, 259))
	get_tree().current_scene.add_child(bat_node)
	current_monster_count += 1
	bat_node.connect("tree_exiting", Callable(self, "_on_monster_defeated"))

func _on_monster_defeated():
	current_monster_count -= 1
	# 确保计数器不会变为负数
	current_monster_count = max(0, current_monster_count)
	
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
			SceneChange.change_scene(Global.main_menu_instance, true)


func get_required_lv_up_value(level: int) -> float:
	var value: float = 1000
	for i in range(level):
		value = (value + 200) * 1.1
	return value

func _on_level_up(main_skill_name : String = '', refresh_id : int = 0):
	now_main_skill_name = main_skill_name # Always update now_main_skill_name from the parameter
	pending_level_ups -= 1
	Global.is_level_up = true
	lv_up_change.visible = true
	
	PC.last_speed = PC.pc_speed
	PC.last_atk_speed = PC.pc_atk_speed
	PC.last_lunky_level = PC.now_lunky_level
	
	# 确定刷出来的三个升级奖励的等级
	var r1_rand = randf_range(0, 100)
	var r2_rand = randf_range(0, 100)
	var r3_rand = randf_range(0, 100)
	
	# 0是默认三个抽选的，123是单独刷新
	var reward1 = null
	var reward2 = null
	var reward3 = null
	if refresh_id == 0 or refresh_id == 1:
		reward1 = LvUp.get_reward_level(r1_rand, main_skill_name)
	if refresh_id == 0 or refresh_id == 2:
		reward2 = LvUp.get_reward_level(r2_rand, main_skill_name)
	if refresh_id == 0 or refresh_id == 3:
		reward3 = LvUp.get_reward_level(r3_rand, main_skill_name)
	# 创建背景变暗效果
	if main_skill_name == '' and refresh_id == 0:
		var dark_overlay = ColorRect.new()
		dark_overlay.color = Color(0, 0, 0, 0.35)  # 黑色，50%透明度
		dark_overlay.size = get_viewport().get_visible_rect().size * 2
		dark_overlay.position = Vector2(-1000, -66)
		dark_overlay.z_index = 100  # 确保在其他元素之上，但在CanvasLayer之下
		dark_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(dark_overlay)
		# 存储dark_overlay引用以便后续清理
		set_meta("dark_overlay", dark_overlay)
	
	# 设置按钮初始状态为不可见
	lv_up_change_b1.visible = true
	lv_up_change_b2.visible = true
	lv_up_change_b3.visible = true
	if refresh_id == 0:
		lv_up_change_b1.modulate.a = 0.0
		lv_up_change_b2.modulate.a = 0.0
		lv_up_change_b3.modulate.a = 0.0
	
	
	# 连接升级选择完成信号，用于清理dark_overlay
	if !Global.is_connected("level_up_selection_complete", _on_level_up_selection_complete):
		Global.connect("level_up_selection_complete", _on_level_up_selection_complete)
	
	var rect_ready = Rect2(4, 176, 8, 16)
	var rect_off = Rect2(20, 176, 8, 16)
	var rect_on = Rect2(36, 176, 8, 16)
		
	if reward1 != null:
		# 配置button内部要显示的数据
		var lvcb1: Sprite2D = lv_up_change_b1.get_node("Pic")
		var lvTitle1: RichTextLabel = lv_up_change_b1.get_node("Panel/Title")
		var lvcbd1: RichTextLabel = lv_up_change_b1.get_node("Panel/Detail")
		var lvSkillLv1: RichTextLabel = lv_up_change_b1.get_node("Panel/SkillLv")
		var lvAdvanceProgress11: Sprite2D = lv_up_change_b1.get_node("Panel/AdvanceProgress1")
		var lvAdvanceProgress12: Sprite2D = lv_up_change_b1.get_node("Panel/AdvanceProgress2")
		var lvAdvanceProgress13: Sprite2D = lv_up_change_b1.get_node("Panel/AdvanceProgress3")
		var lvAdvanceProgress14: Sprite2D = lv_up_change_b1.get_node("Panel/AdvanceProgress4")
		var lvAdvanceProgress15: Sprite2D = lv_up_change_b1.get_node("Panel/AdvanceProgress5")
		lvSkillLv1.visible = false
		lvAdvanceProgress11.visible = false
		lvAdvanceProgress12.visible = false
		lvAdvanceProgress13.visible = false
		lvAdvanceProgress14.visible = false
		lvAdvanceProgress15.visible = false
		lvcbd1.size = Vector2(158, 141)
		lvcbd1.position = Vector2(0, 62)
		
		# 如果抽取到的是主要技能，则渲染进阶状态
		if reward1.if_main_skill and !reward1.if_advance:
			lvcbd1.size = Vector2(158, 89)
			lvcbd1.position = Vector2(0, 102)
			lvSkillLv1.visible = true
			lvAdvanceProgress11.visible = true
			lvAdvanceProgress12.visible = true
			lvAdvanceProgress13.visible = true
			lvAdvanceProgress14.visible = true
			lvAdvanceProgress15.visible = true
			
			lvAdvanceProgress11.region_rect = rect_off
			lvAdvanceProgress12.region_rect = rect_off
			lvAdvanceProgress13.region_rect = rect_off
			lvAdvanceProgress14.region_rect = rect_off
			lvAdvanceProgress15.region_rect = rect_off
			
			var mainLV = LvUp._select_PC_main_skill_lv(reward1.faction)
			lvSkillLv1.text = "LV. " + str(mainLV)
			
			var lights_to_turn_on = min(mainLV % 5, mainLV)
			if lights_to_turn_on >= 0 :
				lvAdvanceProgress11.region_rect = rect_ready
			if lights_to_turn_on >= 1 :
				lvAdvanceProgress11.region_rect = rect_on
				lvAdvanceProgress12.region_rect = rect_ready
			if lights_to_turn_on >= 2 :
				lvAdvanceProgress12.region_rect = rect_on
				lvAdvanceProgress13.region_rect = rect_ready
			if lights_to_turn_on >= 3 :
				lvAdvanceProgress13.region_rect = rect_on
				lvAdvanceProgress14.region_rect = rect_ready
			if lights_to_turn_on >= 4 :
				lvAdvanceProgress14.region_rect = rect_on
				lvAdvanceProgress15.region_rect = rect_ready
		
		lvcb1.region_rect = GU.parse_rect_from_func_string(reward1.icon)
		lvTitle1.text = "[color=" +reward1.rarity +"]" +  reward1.reward_name + "[/color]"
		lvcbd1.text = reward1.detail
		var callbackB1: Callable = Callable(LvUp, reward1.on_selected)
		var connect_array = lv_up_change_b1.pressed.get_connections()
		if !connect_array.is_empty():
			for conn in connect_array:
				lv_up_change_b1.pressed.disconnect(conn.callable)
		lv_up_change_b1.pressed.connect(callbackB1)
	elif refresh_id == 0:
		lv_up_change_b1.visible = false
	
	if reward2 != null:
		var lvcb2: Sprite2D = lv_up_change_b2.get_node("Pic")
		var lvTitle2: RichTextLabel = lv_up_change_b2.get_node("Panel/Title")
		var lvcbd2: RichTextLabel = lv_up_change_b2.get_node("Panel/Detail")
		var lvSkillLv2: RichTextLabel = lv_up_change_b2.get_node("Panel/SkillLv")
		var lvAdvanceProgress21: Sprite2D = lv_up_change_b2.get_node("Panel/AdvanceProgress1")
		var lvAdvanceProgress22: Sprite2D = lv_up_change_b2.get_node("Panel/AdvanceProgress2")
		var lvAdvanceProgress23: Sprite2D = lv_up_change_b2.get_node("Panel/AdvanceProgress3")
		var lvAdvanceProgress24: Sprite2D = lv_up_change_b2.get_node("Panel/AdvanceProgress4")
		var lvAdvanceProgress25: Sprite2D = lv_up_change_b2.get_node("Panel/AdvanceProgress5")
		lvSkillLv2.visible = false
		lvAdvanceProgress21.visible = false
		lvAdvanceProgress22.visible = false
		lvAdvanceProgress23.visible = false
		lvAdvanceProgress24.visible = false
		lvAdvanceProgress25.visible = false
		lvcbd2.size = Vector2(158, 141)
		lvcbd2.position = Vector2(0, 62)
		
		
			# 如果抽取到的是主要技能，则渲染进阶状态
		if reward2.if_main_skill and !reward2.if_advance:
			lvcbd2.size = Vector2(158, 89)
			lvcbd2.position = Vector2(0, 102)
			lvSkillLv2.visible = true
			lvAdvanceProgress21.visible = true
			lvAdvanceProgress22.visible = true
			lvAdvanceProgress23.visible = true
			lvAdvanceProgress24.visible = true
			lvAdvanceProgress25.visible = true
			
			lvAdvanceProgress21.region_rect = rect_off
			lvAdvanceProgress22.region_rect = rect_off
			lvAdvanceProgress23.region_rect = rect_off
			lvAdvanceProgress24.region_rect = rect_off
			lvAdvanceProgress25.region_rect = rect_off
			
			var mainLV = LvUp._select_PC_main_skill_lv(reward2.faction)
			lvSkillLv2.text = "LV. " + str(mainLV)
			
			var lights_to_turn_on = min(mainLV % 5, mainLV)
			if lights_to_turn_on >= 0 :
				lvAdvanceProgress21.region_rect = rect_ready
			if lights_to_turn_on >= 1 :
				lvAdvanceProgress21.region_rect = rect_on
				lvAdvanceProgress22.region_rect = rect_ready
			if lights_to_turn_on >= 2 :
				lvAdvanceProgress22.region_rect = rect_on
				lvAdvanceProgress23.region_rect = rect_ready
			if lights_to_turn_on >= 3 :
				lvAdvanceProgress23.region_rect = rect_on
				lvAdvanceProgress24.region_rect = rect_ready
			if lights_to_turn_on >= 4 :
				lvAdvanceProgress24.region_rect = rect_on
				lvAdvanceProgress25.region_rect = rect_ready
				
		lvTitle2.text = "[color=" +reward2.rarity +"]" +  reward2.reward_name + "[/color]"
		lvcb2.region_rect = GU.parse_rect_from_func_string(reward2.icon)
		lvcbd2.text = reward2.detail
		var callbackB2: Callable = Callable(LvUp, reward2.on_selected)
		var connect_array2 = lv_up_change_b2.pressed.get_connections()
		if !connect_array2.is_empty():
			for conn in connect_array2:
				lv_up_change_b2.pressed.disconnect(conn.callable)
		lv_up_change_b2.pressed.connect(callbackB2)
	elif refresh_id == 0:
		lv_up_change_b2.visible = false
	
	if reward3 != null:
		var lvcb3: Sprite2D = lv_up_change_b3.get_node("Pic")
		var lvTitle3: RichTextLabel = lv_up_change_b3.get_node("Panel/Title")
		var lvcbd3: RichTextLabel = lv_up_change_b3.get_node("Panel/Detail")
		var lvSkillLv3: RichTextLabel = lv_up_change_b3.get_node("Panel/SkillLv")
		var lvAdvanceProgress31: Sprite2D = lv_up_change_b3.get_node("Panel/AdvanceProgress1")
		var lvAdvanceProgress32: Sprite2D = lv_up_change_b3.get_node("Panel/AdvanceProgress2")
		var lvAdvanceProgress33: Sprite2D = lv_up_change_b3.get_node("Panel/AdvanceProgress3")
		var lvAdvanceProgress34: Sprite2D = lv_up_change_b3.get_node("Panel/AdvanceProgress4")
		var lvAdvanceProgress35: Sprite2D = lv_up_change_b3.get_node("Panel/AdvanceProgress5")
		lvSkillLv3.visible = false
		lvAdvanceProgress31.visible = false
		lvAdvanceProgress32.visible = false
		lvAdvanceProgress33.visible = false
		lvAdvanceProgress34.visible = false
		lvAdvanceProgress35.visible = false
		lvcbd3.size = Vector2(158, 141)
		lvcbd3.position = Vector2(0, 62)
		
		# 如果抽取到的是主要技能，则渲染进阶状态
		if reward3.if_main_skill and !reward3.if_advance:
			lvcbd3.size = Vector2(158, 89)
			lvcbd3.position = Vector2(0, 102)
			lvSkillLv3.visible = true
			lvAdvanceProgress31.visible = true
			lvAdvanceProgress32.visible = true
			lvAdvanceProgress33.visible = true
			lvAdvanceProgress34.visible = true
			lvAdvanceProgress35.visible = true
			
			lvAdvanceProgress31.region_rect = rect_off
			lvAdvanceProgress32.region_rect = rect_off
			lvAdvanceProgress33.region_rect = rect_off
			lvAdvanceProgress34.region_rect = rect_off
			lvAdvanceProgress35.region_rect = rect_off
			
			var mainLV = LvUp._select_PC_main_skill_lv(reward3.faction)
			lvSkillLv3.text = "LV. " + str(mainLV)
			
			var lights_to_turn_on = min(mainLV % 5, mainLV)
			if lights_to_turn_on >= 0 :
				lvAdvanceProgress31.region_rect = rect_ready
			if lights_to_turn_on >= 1 :
				lvAdvanceProgress31.region_rect = rect_on
				lvAdvanceProgress32.region_rect = rect_ready
			if lights_to_turn_on >= 2 :
				lvAdvanceProgress32.region_rect = rect_on
				lvAdvanceProgress33.region_rect = rect_ready
			if lights_to_turn_on >= 3 :
				lvAdvanceProgress33.region_rect = rect_on
				lvAdvanceProgress34.region_rect = rect_ready
			if lights_to_turn_on >= 4 :
				lvAdvanceProgress34.region_rect = rect_on
				lvAdvanceProgress35.region_rect = rect_ready
				
		lvTitle3.text = "[color=" +reward3.rarity +"]" +  reward3.reward_name + "[/color]"
		lvcb3.region_rect = GU.parse_rect_from_func_string(reward3.icon)
		lvcbd3.text = reward3.detail
		var callbackB3: Callable = Callable(LvUp, reward3.on_selected)
		var connect_array3 = lv_up_change_b3.pressed.get_connections()
		if !connect_array3.is_empty():
			for conn in connect_array3:
				lv_up_change_b3.pressed.disconnect(conn.callable)
		lv_up_change_b3.pressed.connect(callbackB3)

	elif refresh_id == 0:
		lv_up_change_b3.visible = false
	
	# 创建渐显动画
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)  # 允许并行动画
	tween.set_ignore_time_scale(true) # 确保tween在暂停时也能运行
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	# 设置升级界面相关节点在暂停时仍能处理
	layer_ui.process_mode = Node.PROCESS_MODE_ALWAYS # 通常不需要对根CanvasLayer设置
	lv_up_change.process_mode = Node.PROCESS_MODE_ALWAYS
	lv_up_change_b1.process_mode = Node.PROCESS_MODE_ALWAYS
	lv_up_change_b2.process_mode = Node.PROCESS_MODE_ALWAYS
	lv_up_change_b3.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 立即暂停游戏
	skill1.set_game_paused(true)
	skill2.set_game_paused(true)
	skill3.set_game_paused(true)
	skill4.set_game_paused(true)
	get_tree().set_pause(true)

	
	# 0.5秒渐显动画
	tween.tween_property(lv_up_change_b1, "modulate:a", 1.0, 0.3)
	tween.tween_property(lv_up_change_b2, "modulate:a", 1.0, 0.3)
	tween.tween_property(lv_up_change_b3, "modulate:a", 1.0, 0.3)
	# await get_tree().create_timer(0.3).timeout # 移除此行，因为tween.set_ignore_time_scale(true)会处理暂停
	

func _check_and_process_pending_level_ups():
	skill1.set_game_paused(false)
	skill2.set_game_paused(false)
	skill3.set_game_paused(false)
	skill4.set_game_paused(false)
	var advance_change = int(PC.main_skill_swordQi / 5)
	if PC.main_skill_swordQi != 0 and (PC.main_skill_swordQi % 5 == 0) and PC.main_skill_swordQi_advance < advance_change :
		PC.main_skill_swordQi_advance += 1
		_on_level_up("swordQi")
		# 主技能进阶完成后清空now_main_skill_name
	# 如果没有主技能进阶，或者主技能进阶处理完毕后，再处理普通待升级
	elif pending_level_ups > 0: 
		_on_level_up()
		# 清理升级选择时创建的背景变暗效果（仅普通升级时）
		now_main_skill_name = ""
	var dark_overlay = get_meta("dark_overlay", null)
	if dark_overlay != null:
		dark_overlay.queue_free()
		remove_meta("dark_overlay")


func _on_attr_button_focus_entered() -> void:
	attr_label.visible = true
	attr_label.text = "攻击：" + str(PC.pc_atk) + "  额外攻速：" + str(PC.pc_atk_speed) + "\n额外移速：" + str(PC.pc_speed) + "  弹体大小：" + str(PC.bullet_size) + "\n天命：" + str(PC.now_lunky_level) + "  减伤：" + str(PC.damage_reduction_rate)+ "\n暴击率：" + str(PC.crit_chance) + "  暴击伤害：" + str(PC.crit_damage_multiplier) + "\n环形剑气攻击/数量/大小/射速：" + str(PC.ring_bullet_damage_multiplier) + "/"+ str(PC.ring_bullet_count) + "/"+ str(PC.ring_bullet_size_multiplier) + "/"+ str(PC.ring_bullet_interval) + "/" + "\n召唤物数量/最大数量/攻击/弹体大小/射速：" + str(PC.summon_count)+ "/" + str(PC.summon_count_max)+ "/" + str(PC.summon_damage_multiplier)+ "/" + str(PC.summon_bullet_size_multiplier)+ "/" + str(PC.summon_interval_multiplier)+ "/" + "\n开悟获取：" + str(PC.selected_rewards)


func _on_attr_button_focus_exited() -> void:
	attr_label.visible = false


func _on_monster_mechanism_gained(mechanism_value: int) -> void:
	map_mechanism_num += mechanism_value

# 测试buff功能的函数（可以删除）
func _test_buffs():
	pass
	# # 等待一帧确保buff管理器完全初始化
	# await get_tree().process_frame
	
	# # 添加一些测试buff
	# buff_manager.add_buff("attack_boost", 15.0, 3)  # 攻击力提升，15秒，3层
	# buff_manager.add_buff("speed_boost", 8.0, 1)   # 移动速度提升，8秒，1层
	# buff_manager.add_buff("health_regen", 0.0, 1)  # 生命回复，永久buff
	
	# # 5秒后添加更多buff
	# await get_tree().create_timer(5.0).timeout
	# buff_manager.add_buff("crit_chance", 12.0, 5)  # 暴击率提升，12秒，5层
	# buff_manager.add_buff("damage_reduction", 6.0, 1)  # 伤害减免，6秒，1层
	
	# # 10秒后移除一个buff
	# await get_tree().create_timer(5.0).timeout
	# buff_manager.remove_buff("speed_boost")


func _on_skill_icon_1_mouse_entered() -> void:
	var skill1Text = "[font_size=32]剑气  LV. " + str(PC.main_skill_swordQi) +"[/font_size]" 
	skill1Text = skill1Text +  "\n基本伤害倍率： " + str((PC.main_skill_swordQi_damage * 100))  + "%"
	skill1Text = skill1Text +  "\n基本攻击速度：" + str($Player.fire_speed.wait_time) + "秒/次"
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
	if PC.refresh_num > 0:
		PC.refresh_num -= 1
	
	# 只有在当前升级界面确实是主技能进阶时才传递main_skill_name
	# 通过检查当前是否有有效的main_skill_name来判断
	var current_main_skill = now_main_skill_name if now_main_skill_name != "" else ""
	_on_level_up(current_main_skill, 1)
