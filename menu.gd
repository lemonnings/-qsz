extends Node2D

@export var background: Sprite2D

@export var battle_scene: String
@export var town_test_scene: String

@export var point_label: Label
@export var point_shop_label: Label
@export var shop_layer: CanvasLayer
@export var canvas_layer: CanvasLayer
@export var level_layer: CanvasLayer

@export var atk_speed_button: Button
@export var move_speed_button: Button
@export var point_add_button: Button
@export var next_button: Button

@export var change_stage_button: Button
@export var stage1_button: Button
@export var stage2_button: Button

@export var hero1_button: Button
@export var hero2_button: Button
@export var hero3_button: Button
@export var hero4_button: Button

@export var atk_speed_label: Label
@export var move_speed_label: Label
@export var point_add_label: Label
@export var bullet_size_label: Label

@export var tip: Node
@export var shop_tip: Node

@export var world_level_option: OptionButton

@export var page_no: int = 1

@export var bgm_change_button: Button

var in_shop: bool
var transition_tween: Tween

func _ready() -> void:
	Global.load_game()
	Global.in_menu = true
	world_level_option.selected = Global.world_level - 1
	
func _process(_delta: float) -> void:
	point_label.text = "剩余Point  " + str(Global.total_points)
	Global.main_menu_instance = preload("res://Scenes/main_menu.tscn")
	

func _on_start_pressed() -> void :
	pass
	
func _on_stage_1_pressed() -> void:
	Global.in_town = false
	reset_player_attr()
	SceneChange.change_scene(battle_scene, true)
	
func _on_stage_2_pressed() -> void:
	Global.in_town = true
	reset_player_attr()
	get_tree().change_scene_to_file(town_test_scene)

func reset_player_attr() -> void :
	# 重置玩家奖励权重
	if PlayerRewardWeights:
		PlayerRewardWeights.reset_all_weights()
		
	# 初始化一系列单局内会发生变化的变量
	Global.in_menu = false
	PC.is_game_over = false
	
	PC.selected_rewards = ["SplitSwordQi2"] # "swordWaveTrace"
	
	exec_pc_atk()
	exec_pc_hp()
	exec_pc_bullet_size()
	exec_lucky_level()
	
	PC.real_time = 0
	PC.current_time = 0
	
	PC.pc_lv = 1
	PC.pc_exp = 0
	PC.pc_speed = 0
	PC.pc_atk_speed = 0
	
	PC.invincible = false
	
	PC.ring_bullet_enabled = false
	PC.ring_bullet_count = 8
	PC.ring_bullet_size_multiplier = 0.9
	PC.ring_bullet_damage_multiplier = 1
	PC.ring_bullet_interval = 2.5
	PC.ring_bullet_last_shot_time = 0.0
	
	# 重置反弹子弹相关属性
	PC.rebound_size_multiplier = 0.9
	PC.rebound_damage_multiplier = 0.35
	
	PC.summon_count = 0 
	PC.summon_count_max  = 3
	PC.summon_damage_multiplier = 0.0
	PC.summon_interval_multiplier = 1.0
	PC.summon_bullet_size_multiplier = 1.0
	
	# 重置暴击相关属性
	PC.crit_chance = 0.1 + (Global.crit_chance_level * 0.005) # 基础暴击率 + 局外成长
	PC.crit_damage_multiplier = 1.5 + (Global.crit_damage_level * 0.01) # 基础暴击伤害倍率 + 局外成长
	
	PC.damage_reduction_rate = min(0.0 + (Global.damage_reduction_level * 0.002), 0.7) # 基础减伤率 + 局外成长，最高70%
	PC.body_size = 0
	PC.last_atk_speed = 0
	PC.last_speed = 0
	PC.last_lunky_level = 1
	
	# 重置主要技能等级
	PC.main_skill_swordQi = 0
	PC.main_skill_swordQi_advance = 0
	PC.main_skill_swordQi_damage = 1
	PC.swordQi_penetration_count = 1
	PC.swordQi_other_sword_wave_damage = 0.5
	
	PC.refresh_num = Global.refresh_max_num
	BuffManager.clear_all_buffs()
	
func exec_pc_atk() -> void:
	PC.pc_atk = int (15 + int(get_total_increase(Global.atk_level)))
	
func exec_pc_hp() -> void:
	PC.pc_max_hp = int (15 + int(get_total_increase_hp(Global.hp_level)))
	PC.pc_hp = PC.pc_max_hp
	
func exec_pc_bullet_size() -> void:
	PC.bullet_size = 1 + (Global.bullet_size_level * 0.02)

func exec_lucky_level() -> void:
	PC.now_lunky_level = Global.lunky_level
	PC.now_red_p = Global.red_p
	PC.now_gold_p = Global.gold_p
	PC.now_purple_p = Global.purple_p
	PC.now_blue_p = Global.blue_p
	PC.now_green_p = Global.green_p


func _on_shop_pressed(not_move_background  : bool = true) -> void:
	hero1_button.set_pressed(true)
	_update_shop_content()
	if not_move_background:
		move_background_down()
	if !in_shop:
		_transition_to_layer(shop_layer, [canvas_layer], [world_level_option, bgm_change_button])

func _update_shop_content() -> void:
	point_shop_label.text = "剩余Point  " + str(Global.total_points)
	if page_no == 1:
		atk_speed_label.text = "Level " + str(Global.atk_level) + "\n需 " + str(get_exp_for_level(Global.atk_level)) + " Point  当前 +" + get_total_increase(Global.atk_level) + " 下一级 +" + get_total_increase(Global.atk_level + 1)
		move_speed_label.text = "Level " + str(Global.hp_level) + "\n需 " + str(get_exp_for_level(Global.hp_level)) + " Point  当前 +" + get_total_increase_hp(Global.hp_level) + " 下一级 +" + get_total_increase_hp(Global.hp_level + 1)
		point_add_label.text = "Level " + str(Global.point_add_level) + "\n需 " + str(get_exp_for_level(Global.point_add_level)) + " Point  当前 +" + str(Global.point_add_level * 10) + "% 下一级 +" + str((Global.point_add_level + 1) * 10) + "%"
	elif page_no == 2:
		atk_speed_label.text = "Level " + str(Global.atk_speed_level) + "\n需 " + str(get_exp_for_level_more(Global.atk_speed_level)) + " Point  当前 +" + str(Global.atk_speed_level * 2) + "% 下一级 +" + str((Global.atk_speed_level + 1) * 2) + "%"
		move_speed_label.text = "Level " + str(Global.move_speed_level) + "\n需 " + str(get_exp_for_level_more(Global.move_speed_level)) + " Point  当前 +" + str(Global.move_speed_level * 3) + "% 下一级 +" + str((Global.move_speed_level + 1) * 3) + "%"
		point_add_label.text = "Level " + str(Global.bullet_size_level) + "\n需 " + str(get_exp_for_level_most(Global.bullet_size_level)) + " Point  当前 +" + str(Global.bullet_size_level * 5) + "% 下一级 +" + str((Global.bullet_size_level + 1) * 5) + "%"

func get_total_increase(level) -> String:
	var total_attack = 1
	var current_level = 1  # 当前已经处理到第几级
	var attack_value = 1   # 当前每级增加的攻击力
	var duration = 2       # 第一个攻击值(+1)持续2次升级

	while current_level < level:
		var remaining_levels = level - current_level
		var add_times = min(duration, remaining_levels)

		total_attack += attack_value * add_times
		current_level += add_times

		if current_level < level:
			attack_value += 1
			duration = int(attack_value * attack_value)  # 每个攻击力持续attack_value + 1次
	return str(total_attack)

func get_total_increase_hp(level) -> String:
	var total_hp = 1
	var current_level = 1  # 当前已经处理到第几级
	var hp_value = 1   
	var duration = 6      

	while current_level < level:
		var remaining_levels = level - current_level
		var add_times = min(duration, remaining_levels)

		total_hp += hp_value * add_times
		current_level += add_times

		if current_level < level:
			hp_value += 1
			duration = 6 + int((hp_value + 4) * hp_value)  
	return str(total_hp)

func get_exp_for_level(level: int) -> int:
	level = level + 1
	var base_exp = 200
	var increment = 125
	var multiplier = 1.025
	var exp_now = base_exp
	for i in range(1, level):
		exp_now = ceil((exp_now + increment) * multiplier)
	return exp_now

func get_exp_for_level_more(level: int) -> int:
	level = level + 1
	var base_exp = 400
	var increment = 300
	var multiplier = 1.1
	var exp_now = base_exp
	for i in range(1, level):
		exp_now = ceil((exp_now + increment) * multiplier)
	return exp_now

func get_exp_for_level_most(level: int) -> int:
	level = level + 1
	var base_exp = 600
	var increment = 400
	var multiplier = 1.2
	var exp_now = base_exp
	for i in range(1, level):
		exp_now = ceil((exp_now + increment) * multiplier)
	return exp_now

	
func _on_exit_pressed() -> void:
	in_shop = false
	move_background_up()
	_transition_to_layer(canvas_layer, [shop_layer, level_layer], [bgm_change_button, world_level_option], true)
		
func _on_exit_pressed_stage() -> void:
	in_shop = false
	move_background_up()
	scale_background_to_1() 
	_transition_to_layer(canvas_layer, [shop_layer, level_layer], [bgm_change_button, world_level_option], true)
	
func _on_next_pressed() -> void:
	if page_no == 1:
		page_no = 2
		atk_speed_button.text = '攻击速度'
		move_speed_button.text = '移动速度'
		point_add_button.text = '子弹大小'
	elif page_no == 2:
		page_no = 1
		atk_speed_button.text = '攻击'
		move_speed_button.text = 'HP'
		point_add_button.text = 'Point获取'
	_update_shop_content()

func _transition_to_layer(target_layer: CanvasLayer, hide_layers: Array, show_controls: Array = [], show_controls_immediately: bool = false) -> void:
	if transition_tween:
		transition_tween.kill()
	
	transition_tween = create_tween()
	transition_tween.set_parallel(true)
	
	# 淡出当前显示的层的所有子节点
	for layer in hide_layers:
		if layer and layer.visible:
			for child in layer.get_children():
				if child.has_method("set_modulate"):
					transition_tween.tween_property(child, "modulate:a", 0.0, 0.125)
	
	# 等待淡出完成后切换显示状态
	transition_tween.tween_callback(_switch_layers.bind(target_layer, hide_layers, show_controls, show_controls_immediately)).set_delay(0.125)
	
	# 淡入目标层的所有子节点
	if target_layer:
		target_layer.visible = true
		for child in target_layer.get_children():
			if child.has_method("set_modulate"):
				child.modulate.a = 0.0
				transition_tween.tween_property(child, "modulate:a", 1.0, 0.125).set_delay(0.125)
	

func _switch_layers(target_layer: CanvasLayer, hide_layers: Array, show_controls: Array, show_controls_immediately: bool) -> void:
	# 隐藏旧层
	for layer in hide_layers:
		if layer:
			layer.visible = false
			# 重置所有子节点的透明度
			for child in layer.get_children():
				if child.has_method("set_modulate"):
					child.modulate.a = 1.0
	
	# 处理控件显示
	for control in show_controls:
		if control:
			control.visible = show_controls_immediately
			
func _on_bullet_size_pressed() -> void:
	in_shop = true
	if page_no == 1:
		var next_level_exp = get_exp_for_level(Global.point_add_level)
		if Global.total_points >= next_level_exp:
			$LevelUP.play()
			Global.point_add_level += 1
			Global.total_points -= next_level_exp
			shop_tip.start_animation('升级成功！', 0.25)
			Global.save_game()
			_on_shop_pressed(false)
		else:
			shop_tip.start_animation('Point不足！', 0.25)
			$Buzzer.play()
	elif page_no == 2:
		var next_level_exp = get_exp_for_level_more(Global.bullet_size_level)
		if Global.total_points >= next_level_exp:
			$LevelUP.play()
			Global.bullet_size_level += 1
			Global.total_points -= next_level_exp
			shop_tip.start_animation('升级成功！', 0.25)
			Global.save_game()
			_on_shop_pressed(false)
		else:
			shop_tip.start_animation('Point不足！', 0.25)
			$Buzzer.play()
	

func _on_point_add_pressed() -> void:
	in_shop = true
	if page_no == 1:
		var next_level_exp = get_exp_for_level(Global.point_add_level)
		if Global.total_points >= next_level_exp:
			$LevelUP.play()
			Global.point_add_level += 1
			Global.total_points -= next_level_exp
			shop_tip.start_animation('升级成功！', 0.25)
			Global.save_game()
			_on_shop_pressed(false)
		else:
			shop_tip.start_animation('Point不足！', 0.25)
			$Buzzer.play()
	elif page_no == 2:
		var next_level_exp = get_exp_for_level_most(Global.bullet_size_level)
		if Global.total_points >= next_level_exp:
			$LevelUP.play()
			Global.bullet_size_level += 1
			Global.total_points -= next_level_exp
			shop_tip.start_animation('升级成功！', 0.25)
			Global.save_game()
			_on_shop_pressed(false)
		else:
			shop_tip.start_animation('Point不足！', 0.25)
			$Buzzer.play()
		

func _on_move_speed_pressed() -> void:
	in_shop = true
	if page_no == 1:
		var next_level_exp = get_exp_for_level(Global.hp_level)
		if Global.total_points >= next_level_exp:
			$LevelUP.play()
			Global.hp_level += 1
			Global.total_points -= next_level_exp
			shop_tip.start_animation('升级成功！', 0.25)
			Global.save_game()
			_on_shop_pressed(false)
		else:
			shop_tip.start_animation('Point不足！', 0.25)
			$Buzzer.play()
	elif page_no == 2:
		var next_level_exp = get_exp_for_level_more(Global.move_speed_level)
		if Global.total_points >= next_level_exp:
			$LevelUP.play()
			Global.move_speed_level += 1
			Global.total_points -= next_level_exp
			shop_tip.start_animation('升级成功！', 0.25)
			Global.save_game()
			_on_shop_pressed(false)
		else:
			shop_tip.start_animation('Point不足！', 0.25)
			$Buzzer.play()


func _on_atk_speed_pressed() -> void:
	in_shop = true
	if page_no == 1:
		var next_level_exp = get_exp_for_level(Global.atk_level)
		if Global.total_points >= next_level_exp:
			$LevelUP.play()
			Global.atk_level += 1
			Global.total_points -= next_level_exp
			shop_tip.start_animation('升级成功！', 0.25)
			Global.save_game()
			_on_shop_pressed(false)
		else:
			shop_tip.start_animation('Point不足！', 0.25)
			$Buzzer.play()
	elif page_no == 2:
		var next_level_exp = get_exp_for_level_more(Global.atk_speed_level)
		if Global.total_points >= next_level_exp:
			$LevelUP.play()
			Global.atk_speed_level += 1
			Global.total_points -= next_level_exp
			shop_tip.start_animation('升级成功！', 0.25)
			Global.save_game()
			_on_shop_pressed(false)
		else:
			shop_tip.start_animation('Point不足！', 0.25)
			$Buzzer.play()


func _on_bgm_change_pressed() -> void:
	Bgm.random_bgm()


func _on_world_level_item_focused(index: int) -> void:
	if index == 0:
		Global.world_level = 1
		Global.world_level_multiple = 1
		Global.world_level_reward_multiple = 1
	if index == 1:
		Global.world_level = 2
		Global.world_level_multiple = 2
		Global.world_level_reward_multiple = 1.4
	if index == 2:
		Global.world_level = 3
		Global.world_level_multiple = 4
		Global.world_level_reward_multiple = 2
	if index == 3:
		Global.world_level = 4
		Global.world_level_multiple = 8
		Global.world_level_reward_multiple = 2.8
	if index == 4:
		Global.world_level = 5
		Global.world_level_multiple = 16
		Global.world_level_reward_multiple = 4
	if index == 5:
		Global.world_level = 6
		Global.world_level_multiple = 32
		Global.world_level_reward_multiple = 5.6
	if index == 6:
		Global.world_level = 7
		Global.world_level_multiple = 64
		Global.world_level_reward_multiple = 7.6
	if index == 7:
		Global.world_level = 8
		Global.world_level_multiple = 128
		Global.world_level_reward_multiple = 9
	if index == 8:
		Global.world_level = 9
		Global.world_level_multiple = 192
		Global.world_level_reward_multiple = 12
	if index == 9:
		Global.world_level = 10
		Global.world_level_multiple = 320
		Global.world_level_reward_multiple = 16
	tip.start_animation('世界等级: ' + str(Global.world_level) + '，敌人属性' + str(Global.world_level_multiple * 100) + '%，收益' + str(Global.world_level_reward_multiple * 100) + '%！', 0.7)
	Global.save_game()


func _on_change_stage_button_pressed() -> void:
	scale_background_to_2()
	_transition_to_layer(level_layer, [shop_layer, canvas_layer], [bgm_change_button, world_level_option])


func _on_atk_speed_mouse_entered() -> void:
	atk_speed_label.visible = true


func _on_atk_speed_mouse_exited() -> void:
	atk_speed_label.visible = false
	

func _on_hp_move_speed_focus_entered() -> void:
	move_speed_label.visible = true

func _on_hp_move_speed_focus_exited() -> void:
	move_speed_label.visible = false


func _on_bullet_size_point_add_mouse_entered() -> void:
	point_add_label.visible = true


func _on_bullet_size_point_add_mouse_exited() -> void:
	point_add_label.visible = false


func _on_button_pressed() -> void:
	shop_tip.start_animation('切换成功！', 0.35)
	change_stage_button.disabled = false
	hero2_button.set_pressed(false)
	hero3_button.set_pressed(false)
	hero4_button.set_pressed(false)

func move_background_down() -> void:
	if background:
		var tween = create_tween()
		var start_position = background.position
		var target_position = start_position + Vector2(0, -240)
		tween.tween_property(background, "position", target_position, 0.4)

func move_background_up() -> void:
	if background:
		var tween = create_tween()
		var start_position = background.position
		var target_position = start_position + Vector2(0, 240)
		tween.tween_property(background, "position", target_position, 0.4)

func scale_background_to_2() -> void:
	if background:
		var tween = create_tween()
		tween.tween_property(background, "scale", Vector2(2.0, 2.0), 0.4)
		
func scale_background_to_1() -> void:
	if background:
		var tween = create_tween()
		tween.tween_property(background, "scale", Vector2(1.048, 1.097), 0.4)

func _on_button_2_pressed() -> void:
	shop_tip.start_animation('角色未开放！', 0.35)
	change_stage_button.disabled = true
	hero1_button.set_pressed(false)
	hero3_button.set_pressed(false)
	hero4_button.set_pressed(false)


func _on_button_3_pressed() -> void:
	shop_tip.start_animation('角色未开放！', 0.35)
	change_stage_button.disabled = true
	hero2_button.set_pressed(false)
	hero1_button.set_pressed(false)
	hero4_button.set_pressed(false)


func _on_button_4_pressed() -> void:
	shop_tip.start_animation('角色未开放！', 0.35)
	change_stage_button.disabled = true
	hero2_button.set_pressed(false)
	hero3_button.set_pressed(false)
	hero1_button.set_pressed(false)
