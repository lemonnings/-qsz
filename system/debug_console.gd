extends CanvasLayer

## F12 调试控制台
## 指令列表：
##   add_xxx        — 执行一次 reward_xxx（如 add_R01 → LvUp.reward_R01()）
##   refresh         — 添加 1000 次刷新次数
##   lock            — 添加 1000 次锁定次数
##   addfaze_xxx_y   — 给 xxx 法则层数 +y（如 addfaze_destory_3 → PC.faze_destroy_level += 3）
##   additem_xxx_y   — 添加物品 id=xxx 的 y 个
##   mapmech_max     — 将当前关卡的 map_mechanism_num 提升到最大值 -100
##   mapmech_min     — 将当前关卡的 map_mechanism_num 重置为 0

var _panel: PanelContainer
var _input: LineEdit
var _log: RichTextLabel
var _visible := false

func _ready() -> void:
	layer = 9999
	_build_ui()
	visible = false

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "DebugConsole"
	_panel.anchors_preset = Control.PRESET_TOP_LEFT
	_panel.offset_top = 0
	_panel.offset_bottom = 360
	_panel.offset_right = 360
	# 半透明黑色背景
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.border_color = Color(0.4, 0.8, 1.0, 0.8)
	style.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	# 输入框
	_input = LineEdit.new()
	_input.placeholder_text = "输入调试指令，如：help"
	_input.clear_button_enabled = true
	var input_style = StyleBoxFlat.new()
	input_style.bg_color = Color(0.1, 0.1, 0.15, 1.0)
	input_style.set_border_width_all(1)
	input_style.border_color = Color(0.4, 0.8, 1.0, 0.5)
	_input.add_theme_stylebox_override("normal", input_style)
	_input.add_theme_stylebox_override("focus", input_style)
	_input.add_theme_font_size_override("font_size", 16)
	_input.custom_minimum_size.y = 32
	vbox.add_child(_input)

	# 日志区
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.custom_minimum_size.y = 280
	_log.add_theme_font_size_override("normal_font_size", 14)
	# 日志区背景
	var log_style = StyleBoxFlat.new()
	log_style.bg_color = Color(0.05, 0.05, 0.08, 1.0)
	_log.add_theme_stylebox_override("normal", log_style)
	vbox.add_child(_log)

	_input.text_submitted.connect(_on_text_submitted)

func toggle() -> void:
	_visible = not _visible
	visible = _visible
	if _visible:
		_input.grab_focus()
		_log_append("[color=cyan]── 调试控制台已打开 ──[/color]")

func _on_text_submitted(text: String) -> void:
	_input.clear()
	if text.strip_edges().is_empty():
		return
	_execute(text.strip_edges())

func _execute(cmd: String) -> void:
	_log_append("[color=gray]> %s[/color]" % cmd)

	# --- help : 显示帮助 ---
	if cmd == "help":
		_log_append("[color=cyan]=== 调试控制台指令 ===[/color]")
		_log_append("[color=yellow]add_xxx[/color]         — 执行一次 reward_xxx")
		_log_append("  例: [color=white]add_R01[/color] → 执行 reward_R01()")
		_log_append("")
		_log_append("[color=yellow]refresh[/color]         — 添加 1000 次刷新次数")
		_log_append("[color=yellow]lock[/color]            — 添加 1000 次锁定次数")
		_log_append("")
		_log_append("[color=yellow]addfaze_xxx_y[/color]   — 给 xxx 法则 +y 层数")
		_log_append("  例: [color=white]addfaze_destory_3[/color] → PC.faze_destroy_level += 3")
		_log_append("")
		_log_append("[color=yellow]additem_xxx_y[/color]   — 添加物品 id=xxx 的 y 个")
		_log_append("  例: [color=white]additem_item_001_5[/color] → 添加 item_001 × 5")
		_log_append("")
		_log_append("[color=yellow]mapmech_max[/color]     — 将关卡进度提升到最大值")
		_log_append("[color=yellow]mapmech_min[/color]     — 将关卡进度重置为 0")
		_log_append("")
		_log_append("[color=yellow]lucky_x[/color]         — 提升天命值 x 点")
		_log_append("  例: [color=white]lucky_10[/color] → PC.lucky += 10")
		_log_append("")
		_log_append("[color=yellow]help[/color]            — 显示帮助信息")
		return

	# --- add_xxx : 执行 reward_xxx ---
	if cmd.begins_with("add_"):
		var reward_id = cmd.substr(4) # 去掉 "add_"
		if reward_id.is_empty():
			_log_append("[color=red]用法: add_xxx（如 add_R01）[/color]")
			return
		var fn_name = "reward_" + reward_id
		if LvUp.has_method(fn_name):
			LvUp.call(fn_name)
			_log_append("[color=green]已执行 LvUp.%s()[/color]" % fn_name)
		else:
			_log_append("[color=red]未找到函数 LvUp.%s()[/color]" % fn_name)
		return

	# --- refresh : 添加1000次刷新 ---
	if cmd == "refresh":
		PC.refresh_num += 1000
		Global.shop_battle_refresh_count = mini(Global.shop_battle_refresh_count + 1000, Global.refresh_max_num)
		_log_append("[color=green]刷新次数 +1000（当前: %d / 战斗刷新: %d）[/color]" % [PC.refresh_num, Global.shop_battle_refresh_count])
		return

	# --- lock : 添加1000次锁定 ---
	if cmd == "lock":
		PC.lock_num += 1000
		_log_append("[color=green]锁定次数 +1000（当前: %d）[/color]" % PC.lock_num)
		return

	# --- addfaze_xxx_y : 法则层数 +y ---
	if cmd.begins_with("addfaze_"):
		var rest = cmd.substr(8) # 去掉 "addfaze_"
		var last_underscore = rest.rfind("_")
		if last_underscore <= 0:
			_log_append("[color=red]用法: addfaze_xxx_y（如 addfaze_destory_3）[/color]")
			return
		var faze_name = rest.substr(0, last_underscore)
		var amount_str = rest.substr(last_underscore + 1)
		var amount = int(amount_str)
		if amount == 0 and amount_str != "0":
			_log_append("[color=red]层数必须是整数，收到: %s[/color]" % amount_str)
			return
		var var_name = "faze_" + faze_name + "_level"
		if var_name in PC:
			PC.set(var_name, PC.get(var_name) + amount)
			_log_append("[color=green]PC.%s += %d（当前: %d）[/color]" % [var_name, amount, PC.get(var_name)])
		else:
			_log_append("[color=red]未找到变量 PC.%s[/color]" % var_name)
		return

	# --- additem_xxx_y : 添加物品 ---
	if cmd.begins_with("additem_"):
		var rest = cmd.substr(8) # 去掉 "additem_"
		var last_underscore = rest.rfind("_")
		if last_underscore <= 0:
			_log_append("[color=red]用法: additem_xxx_y（如 additem_item_001_5）[/color]")
			return
		var item_id = rest.substr(0, last_underscore)
		var count_str = rest.substr(last_underscore + 1)
		var count = int(count_str)
		if count <= 0:
			_log_append("[color=red]数量必须是正整数，收到: %s[/color]" % count_str)
			return
		Global.add_item_count(item_id, count)
		_log_append("[color=green]添加物品 %s × %d[/color]" % [item_id, count])
		return

	# --- mapmech_max : 机关进度推到最大-100 ---
	if cmd == "mapmech_max":
		var stage = _get_current_stage()
		if stage and "map_mechanism_num_max" in stage:
			stage.map_mechanism_num = stage.map_mechanism_num_max - 100
			_log_append("[color=green]机关进度设为 %d / %d[/color]" % [stage.map_mechanism_num, stage.map_mechanism_num_max])
		else:
			_log_append("[color=red]当前场景不是关卡（无 map_mechanism_num_max）[/color]")
		return

	# --- mapmech_min : 机关进度归零 ---
	if cmd == "mapmech_min":
		var stage = _get_current_stage()
		if stage and "map_mechanism_num" in stage:
			stage.map_mechanism_num = 0
			_log_append("[color=green]机关进度已归零[/color]")
		else:
			_log_append("[color=red]当前场景不是关卡（无 map_mechanism_num）[/color]")
		return

	# --- lucky_x : 提升天命值 x 点 ---
	if cmd.begins_with("lucky_"):
		var amount_str = cmd.substr(6) # 去掉 "lucky_"
		var amount = int(amount_str)
		if amount == 0 and amount_str != "0":
			_log_append("[color=red]用法: lucky_x（如 lucky_10），x 必须是整数[/color]")
			return
		PC.lucky += amount
		_log_append("[color=green]天命值 +%d（当前: %d）[/color]" % [amount, PC.lucky])
		return

	# --- 未知指令 ---
	_log_append("[color=red]未知指令: %s[/color]" % cmd)
	_log_append("[color=gray]输入 [color=yellow]help[/color] 查看完整指令列表[/color]")

func _get_current_stage():
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return null
	return tree.current_scene

func _log_append(bbcode: String) -> void:
	_log.append_text(bbcode + "\n")
	# 滚动到底部
	await get_tree().process_frame
	_log.scroll_to_line(_log.get_line_count() - 1)
