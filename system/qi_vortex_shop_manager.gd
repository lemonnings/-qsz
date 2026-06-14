extends Node
class_name QiVortexShopManager

signal opened
signal closed

const SHOP_CHANGE_SCENE: PackedScene = preload("res://Scenes/global/shop_change.tscn")
const TWO_CHOICE_Y := [201.0, 451.0]
const THREE_CHOICE_Y := [84.0, 285.0, 486.0]
const COST_BONUS_PER_PREVIOUS_PURCHASE: int = 100

var stage: Node = null
var canvas_layer: CanvasLayer = null
var level_up_manager: LevelUpManager = null

var shop_ui: Control = null
var info_label: RichTextLabel = null
var next_button: Button = null
var exit_button: Button = null
var reward_buttons: Array[Button] = []

var shop_round: int = 1
var _is_open: bool = false
var _selection_locked: bool = false
var _pending_shop_advance_name: String = ""
var _purchase_count_in_run: int = 0
var _current_shop_cost_bonus: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func open(p_stage: Node, p_canvas_layer: CanvasLayer) -> void:
	stage = p_stage
	canvas_layer = p_canvas_layer
	level_up_manager = null
	if canvas_layer:
		level_up_manager = canvas_layer.get("level_up_manager") as LevelUpManager
	if not level_up_manager:
		return
	_ensure_ui()
	_is_open = true
	_selection_locked = false
	_pending_shop_advance_name = ""
	shop_round = 1
	_current_shop_cost_bonus = _purchase_count_in_run * COST_BONUS_PER_PREVIOUS_PURCHASE
	Global.is_level_up = true
	level_up_manager.pause_battle_for_external_popup(get_tree())
	if canvas_layer and canvas_layer.has_method("set_qi_vortex_shop_manual_level_up_hidden"):
		canvas_layer.set_qi_vortex_shop_manual_level_up_hidden(true)
	_hide_reward_buttons()
	_update_info_label()
	_update_navigation_buttons(false)
	shop_ui.visible = true
	shop_ui.modulate.a = 0.0
	opened.emit()
	_fade_control(shop_ui, 1.0, 0.25)

func _ensure_ui() -> void:
	if shop_ui and is_instance_valid(shop_ui):
		return
	shop_ui = SHOP_CHANGE_SCENE.instantiate() as Control
	canvas_layer.add_child(shop_ui)
	_set_process_always_recursive(shop_ui)
	shop_ui.visible = false
	info_label = shop_ui.get_node("LevelUpChange_Panel#RefreshNum") as RichTextLabel
	next_button = shop_ui.get_node("Next") as Button
	exit_button = shop_ui.get_node("Exit") as Button
	reward_buttons = [
		shop_ui.get_node("LvUpChange1Button") as Button,
		shop_ui.get_node("LvUpChange2Button") as Button,
		shop_ui.get_node("LvUpChange3Button") as Button
	]
	if not next_button.pressed.is_connected(_on_next_pressed):
		next_button.pressed.connect(_on_next_pressed)
	if not exit_button.pressed.is_connected(_on_exit_pressed):
		exit_button.pressed.connect(_on_exit_pressed)
	_hide_refresh_and_lock_buttons()

func _set_process_always_recursive(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	for child in node.get_children():
		_set_process_always_recursive(child)

func _hide_refresh_and_lock_buttons() -> void:
	var paths := [
		"LvUpChange1Button/RefreshButton",
		"LvUpChange1Button/LockButton",
		"LvUpChange2Button/RefreshButton2",
		"LvUpChange2Button/LockButton2",
		"LvUpChange3Button/RefreshButton3",
		"LvUpChange3Button/LockButton3"
	]
	for path in paths:
		var node := shop_ui.get_node_or_null(path) as Control
		if node:
			node.visible = false

func _on_next_pressed() -> void:
	if not _is_open or _selection_locked:
		return
	var cost := _get_round_cost(shop_round)
	if not stage or not stage.has_method("spend_spirit") or stage.call("spend_spirit", cost) != true:
		_update_info_label()
		_update_navigation_buttons(true)
		return
	_selection_locked = true
	_hide_reward_buttons()
	var choice_count := 2 if shop_round <= 2 else 3
	shop_round += 1
	_purchase_count_in_run += 1
	AchievementManager.record_qi_vortex_purchase()
	_update_info_label()
	await _fade_navigation_buttons(false)
	_present_reward_choices("", choice_count)

func _on_exit_pressed() -> void:
	if not _is_open or _selection_locked:
		return
	_close_shop()

func _present_reward_choices(main_skill_name: String, choice_count: int) -> void:
	_selection_locked = false
	_pending_shop_advance_name = ""
	_hide_reward_buttons()
	_hide_refresh_and_lock_buttons()
	var rewards := _roll_rewards(main_skill_name, choice_count)
	var positions := TWO_CHOICE_Y if choice_count == 2 else THREE_CHOICE_Y
	for i in range(choice_count):
		if i >= reward_buttons.size() or i >= rewards.size():
			continue
		var reward = rewards[i]
		if reward == null:
			continue
		var button := reward_buttons[i]
		level_up_manager.configure_reward_button_for_external(button, reward, i + 1, Callable(self, "_on_reward_selected"))
		level_up_manager.set_external_reward_button_y(button, float(positions[i]))
		button.visible = true
		button.disabled = false
		button.modulate = Color(1, 1, 1, 0.0)
	_fade_reward_buttons(true)

func _roll_rewards(main_skill_name: String, choice_count: int) -> Array:
	var rewards: Array = []
	var advance_pool_is_empty := false
	if main_skill_name != "":
		advance_pool_is_empty = LvUp.is_advance_pool_empty(main_skill_name)
	for _i in range(choice_count):
		var reward = LvUp.get_reward_level(randf_range(0.0, 100.0), main_skill_name)
		if reward == null:
			rewards.append(null)
			continue
		if reward.reward_name == "noReward":
			rewards.append(null)
			continue
		if main_skill_name != "" and not advance_pool_is_empty and reward.id == "NoAdvance":
			rewards.append(null)
			continue
		rewards.append(reward)
	if main_skill_name != "" and _all_rewards_empty(rewards):
		rewards[0] = LvUp._get_no_advance_reward()
	return rewards

func _all_rewards_empty(rewards: Array) -> bool:
	for reward in rewards:
		if reward != null:
			return false
	return true

func _on_reward_selected(reward) -> void:
	if _selection_locked:
		return
	_selection_locked = true
	var selected_main_skill_name := ""
	if reward != null and reward.if_main_skill and not reward.if_advance:
		selected_main_skill_name = str(reward.faction)
	_apply_reward(reward)
	_update_after_reward_applied()
	await _fade_reward_buttons(false)
	_pending_shop_advance_name = ""
	if not selected_main_skill_name.is_empty() and level_up_manager:
		_pending_shop_advance_name = level_up_manager.pop_pending_advance_name_for(selected_main_skill_name)
	if not _pending_shop_advance_name.is_empty():
		await _wait_unscaled(0.25)
		_show_next_pending_advance()
	else:
		_return_to_shop_idle()

func _apply_reward(reward) -> void:
	if reward == null:
		return
	var callback := Callable(LvUp, reward.on_selected)
	if not callback.is_valid():
		printerr("[QiVortexShop] 找不到奖励回调: ", reward.on_selected)
		return
	LvUp.begin_qi_vortex_shop_reward_context()
	callback.call()
	if LvUp.reward_apply_context == LvUp.REWARD_CONTEXT_QI_VORTEX_SHOP:
		LvUp.clear_reward_context()

func _update_after_reward_applied() -> void:
	if canvas_layer and canvas_layer.has_method("_refresh_faze_ui"):
		canvas_layer._refresh_faze_ui()
	if canvas_layer and canvas_layer.has_method("check_and_update_skill_icons") and PC.player_instance:
		canvas_layer.check_and_update_skill_icons(PC.player_instance)
	if stage and canvas_layer and canvas_layer.has_method("update_score_display"):
		canvas_layer.update_score_display(int(stage.get("point")), int(stage.get("spirit")))
	_update_info_label()

func _show_next_pending_advance() -> void:
	var main_skill_name := _pending_shop_advance_name
	_pending_shop_advance_name = ""
	if main_skill_name.is_empty():
		_return_to_shop_idle()
		return
	_update_info_label()
	_update_navigation_buttons(false)
	_present_reward_choices(main_skill_name, 2)

func _return_to_shop_idle() -> void:
	_selection_locked = false
	_pending_shop_advance_name = ""
	_hide_reward_buttons()
	_update_info_label()
	_update_navigation_buttons(not _navigation_buttons_visible())

func _close_shop() -> void:
	_is_open = false
	_selection_locked = false
	_pending_shop_advance_name = ""
	_hide_reward_buttons()
	closed.emit()
	_fade_control(shop_ui, 0.0, 0.2)
	await _wait_unscaled(0.2)
	if shop_ui:
		shop_ui.visible = false
		shop_ui.modulate.a = 1.0
	if level_up_manager:
		level_up_manager.resume_battle_from_external_popup(get_tree())
	Global.is_level_up = false
	if canvas_layer and canvas_layer.has_method("set_qi_vortex_shop_manual_level_up_hidden"):
		canvas_layer.set_qi_vortex_shop_manual_level_up_hidden(false)
	if canvas_layer and canvas_layer.has_method("_update_lv_up_start_button_badge"):
		canvas_layer._update_lv_up_start_button_badge()

func _hide_reward_buttons() -> void:
	for button in reward_buttons:
		if button:
			button.visible = false
			button.disabled = true
			button.modulate.a = 1.0

func _fade_reward_buttons(fade_in: bool) -> void:
	var target_alpha := 1.0 if fade_in else 0.0
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	tween.set_parallel(true)
	var has_visible := false
	for button in reward_buttons:
		if button and button.visible:
			has_visible = true
			tween.tween_property(button, "modulate:a", target_alpha, 0.25)
	if not has_visible:
		tween.kill()
		return
	await tween.finished
	if not fade_in:
		_hide_reward_buttons()

func _fade_navigation_buttons(fade_in: bool) -> void:
	if fade_in:
		_update_navigation_buttons(false)
	var target_alpha := 1.0 if fade_in else 0.0
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	tween.set_parallel(true)
	var controls: Array[Control] = [next_button, exit_button]
	for control in controls:
		if control and control.visible:
			tween.tween_property(control, "modulate:a", target_alpha, 0.2)
	await tween.finished
	if not fade_in:
		for control in controls:
			if control:
				control.visible = false
				control.modulate.a = 1.0

func _update_navigation_buttons(animate: bool) -> void:
	if not next_button or not exit_button:
		return
	var can_afford := _get_stage_spirit() >= _get_round_cost(shop_round)
	next_button.visible = can_afford
	next_button.disabled = not can_afford
	exit_button.visible = true
	exit_button.disabled = false
	if animate:
		var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.set_ignore_time_scale(true)
		tween.set_parallel(true)
		if next_button.visible:
			next_button.modulate.a = 0.0
			tween.tween_property(next_button, "modulate:a", 1.0, 0.2)
		if exit_button.visible:
			exit_button.modulate.a = 0.0
			tween.tween_property(exit_button, "modulate:a", 1.0, 0.2)
	else:
		next_button.modulate.a = 1.0
		exit_button.modulate.a = 1.0

func _navigation_buttons_visible() -> bool:
	return exit_button != null and exit_button.visible

func _update_info_label() -> void:
	if not info_label:
		return
	info_label.text = "下轮\n所需\n精魄\n\n%d\n\n当前\n精魄\n\n%d" % [_get_round_cost(shop_round), _get_stage_spirit()]

func _get_stage_spirit() -> int:
	if not stage:
		return 0
	return int(stage.get("spirit"))

func _get_round_cost(round: int) -> int:
	var base_cost := 0
	if round <= 1:
		base_cost = 500
	elif round == 2:
		base_cost = 700
	elif round == 3:
		base_cost = 1000
	else:
		base_cost = 1000
		var increment := 400
		for _i in range(4, round + 1):
			base_cost += increment
			increment += 100
	return int(ceil(float(base_cost + _current_shop_cost_bonus) * Global.get_qi_vortex_cost_multiplier()))

func _fade_control(control: CanvasItem, target_alpha: float, duration: float) -> void:
	if not control:
		return
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	tween.tween_property(control, "modulate:a", target_alpha, duration)

func _wait_unscaled(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
