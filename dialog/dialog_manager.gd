extends Control

@onready var speaker_left: TextureRect = $SpeakerLeft
@onready var speaker_middle: TextureRect = $SpeakerMiddle
@onready var speaker_right: TextureRect = $SpeakerRight
@onready var dialog_panel: Panel = $DialogPanel
@onready var speaker_name_panel_left: Panel = $SpeakerNamePanelLeft
@onready var speaker_name_left: RichTextLabel = $SpeakerNamePanelLeft/SpeakerName
@onready var speaker_info_button_left: Button = $SpeakerNamePanelLeft/SpeakerInfoButton
@onready var speaker_name_panel_right: Panel = $SpeakerNamePanelRight
@onready var speaker_name_right: RichTextLabel = $SpeakerNamePanelRight/SpeakerName
@onready var speaker_info_button_right: Button = $SpeakerNamePanelRight/SpeakerInfoButton
@onready var dialog_text_label: RichTextLabel = $DialogText
@onready var history_button: Button = $ToolButton/HistoryButton
@onready var change_container: VBoxContainer = $ChangeContainer
@onready var change_button_1: Button = $ChangeContainer/Change1
@onready var change_button_2: Button = $ChangeContainer/Change2
@onready var change_button_3: Button = $ChangeContainer/Change3
@onready var change_button_4: Button = $ChangeContainer/Change4

var current_dialog_data: Array = []
var current_dialog_index: int = -1
var current_line_data: Dictionary = {}
var is_displaying_text: bool = false
var text_display_speed: float = 0.03 # Seconds per character
var choices_already_shown: bool = false # 标记选项是否已经显示过
var is_animating_illustrations: bool = false

# 颜色
const COLOR_DIM: Color = Color("#5b5b5b")
const COLOR_NORMAL: Color = Color.WHITE

func _ready():
	Global.connect("start_dialog", Callable(self, "_on_start_dialog"))
	# 初始化时隐藏选项容器和按钮
	change_container.visible = false
	change_button_1.visible = false
	change_button_2.visible = false
	change_button_3.visible = false
	change_button_4.visible = false
	# 连接选项按钮信号
	change_button_1.pressed.connect(_on_choice_pressed.bind(1))
	change_button_2.pressed.connect(_on_choice_pressed.bind(2))
	change_button_3.pressed.connect(_on_choice_pressed.bind(3))
	change_button_4.pressed.connect(_on_choice_pressed.bind(4))

func _on_start_dialog(dialog_file_path: String):
	current_dialog_data = _read_dialog_data(dialog_file_path)
	if current_dialog_data.is_empty():
		printerr("Dialog data is empty or failed to load: ", dialog_file_path)
		return

	current_dialog_index = 0 # 从第一个有效行开始（数组索引0，csv的第2行）
	_process_current_dialog_line()

# 从CSV文件读取对话数据的功能。
func _read_dialog_data_from_csv(file_path: String) -> Array:
	print("Attempting to read dialog data from CSV: ", file_path)
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not FileAccess.file_exists(file_path) or file == null:
		printerr("Error opening CSV dialog file: ", file_path)
		return []

	var dialog_lines: Array = []
	var headers: Array = []
	var is_first_line = true

	while not file.eof_reached():
		var csv_line = file.get_csv_line()
		if csv_line.is_empty() or (csv_line.size() == 1 and csv_line[0].is_empty()): # 跳过空行或实际上的空行
			continue

		if is_first_line:
			headers = csv_line
			is_first_line = false
		else:
			if csv_line.size() != headers.size():
				printerr("CSV header/row size mismatch in line: ", csv_line, " in file: ", file_path)
				continue # 跳过格式错误的行或根据需要处理错误
			var line_dict: Dictionary = {}
			# 按类型处理
			for i in range(headers.size()):
				var key = headers[i].strip_edges()
				var value_str = csv_line[i].strip_edges()
				if value_str.to_lower() == "true":
					line_dict[key] = true
				elif value_str.to_lower() == "false":
					line_dict[key] = false
				elif value_str.is_valid_float():
					line_dict[key] = value_str.to_float()
				elif value_str.is_valid_int():
					line_dict[key] = value_str.to_int()
				else:
					line_dict[key] = value_str # 存储为字符串
			dialog_lines.append(line_dict)
	
	file.close()
	return dialog_lines

# 从CSV文件读取对话数据的功能。
func _read_dialog_data(file_path: String) -> Array:
	var extension = file_path.get_extension().to_lower()
	if extension == "csv":
		return _read_dialog_data_from_csv(file_path)
	else:
		printerr("Unsupported file type for dialog: ", file_path, ". Please use .csv files.")
		return []

func _process_current_dialog_line():
	print("Processing dialog line. Index: ", current_dialog_index)
	if current_dialog_index < 0 or current_dialog_index >= current_dialog_data.size():
		_end_dialog()
		return

	# _advance_dialog_with_transition 处理了潜在过渡之后调用
	# 这块主要是防止动画没过渡完就跳过导致显示不正确
	current_line_data = current_dialog_data[current_dialog_index]
	# 重置选项显示标志，为新对话行做准备
	choices_already_shown = false

	var speaker_name_text = current_line_data.get("speaker", "")
	var ill_left_status = current_line_data.get("illustrationLeftStatus", false)
	var ill_mid_status = current_line_data.get("illustrationMiddleStatus", false)
	var ill_right_status = current_line_data.get("illustrationRightStatus", false)

	speaker_name_panel_left.visible = false
	speaker_name_panel_right.visible = false

	if ill_left_status or ill_mid_status:
		speaker_name_panel_left.visible = true
		speaker_name_left.text = speaker_name_text
	elif ill_right_status:
		speaker_name_panel_right.visible = true
		speaker_name_right.text = speaker_name_text
	else:
		if not speaker_name_text.is_empty():
			speaker_name_panel_left.visible = true
			speaker_name_left.text = speaker_name_text

	# 立绘 - 带过渡更新
	_update_illustration(speaker_left, current_line_data.get("illustrationLeft", ""), ill_left_status, true)
	_update_illustration(speaker_middle, current_line_data.get("illustrationMiddle", ""), ill_mid_status, true)
	_update_illustration(speaker_right, current_line_data.get("illustrationRight", ""), ill_right_status, true)

	# 对话文本（打字机效果）
	var dialog_content = current_line_data.get("dialog", "")
	_display_text_typewriter(dialog_content)

func _update_illustration(texture_rect: TextureRect, path: String, is_speaking: bool, use_transition: bool = false):
	var target_modulate = COLOR_NORMAL if is_speaking else COLOR_DIM
	var should_be_visible = not path.is_empty() and ResourceLoader.exists(path)
	var transition_duration = 0.35

	var tween = get_tree().create_tween()
	# 顺序动画
	tween.set_parallel(false) 
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)

	if use_transition:
		is_animating_illustrations = true
		if not should_be_visible:
			if texture_rect.visible and texture_rect.modulate.a > 0.01: # 如果当前可见则淡出
				tween.tween_property(texture_rect, "modulate:a", 0.0, transition_duration)
				tween.tween_callback(func(): texture_rect.visible = false)
				tween.tween_callback(func(): is_animating_illustrations = false)
			else:
				texture_rect.visible = false # 已经不可见或完全淡出
				tween.kill() # 不需要动画
				is_animating_illustrations = false
		else:
			var new_texture = load(path)
			if not texture_rect.visible or texture_rect.texture != new_texture:
				# 如果不可见或纹理更改，则设置新纹理，使其透明，然后淡入
				texture_rect.texture = new_texture
				texture_rect.modulate.a = 0.0
				texture_rect.visible = true
				tween.tween_property(texture_rect, "modulate", target_modulate, transition_duration)
				tween.tween_callback(func(): is_animating_illustrations = false)
			elif texture_rect.modulate != target_modulate:
				# 如果可见且纹理相同，但说话状态（变暗/正常）发生变化
				tween.tween_property(texture_rect, "modulate", target_modulate, transition_duration)
				tween.tween_callback(func(): is_animating_illustrations = false)
			else:
				tween.kill() # 如果状态已正确，则无需动画
				is_animating_illustrations = false
	else: 
		tween.kill() # 如果不使用过渡，则终止补间动画
		if not should_be_visible:
			texture_rect.visible = false
		else:
			texture_rect.texture = load(path)
			texture_rect.visible = true
			texture_rect.modulate = target_modulate
		is_animating_illustrations = false


# 添加一个变量来跟踪当前的文本显示tween
var current_text_tween: Tween = null

func _display_text_typewriter(text_to_display: String):
	is_displaying_text = true
	dialog_text_label.text = ""
	dialog_text_label.visible_characters = 0
	
	# 如果有正在进行的文本tween，先停止它
	if current_text_tween and current_text_tween.is_valid():
		current_text_tween.kill()
	
	current_text_tween = get_tree().create_tween()
	var duration = text_to_display.length() * text_display_speed
	current_text_tween.tween_property(dialog_text_label, "visible_characters", text_to_display.length(), duration)
	current_text_tween.tween_callback(func():
		is_displaying_text = false
		current_text_tween = null
		_check_for_choices() # 文本完成后，检查并显示选项
	)
	dialog_text_label.text = text_to_display # 设置完整文本以进行bbcode解析，visible_characters 处理显示

func _check_for_choices():
	# 如果选项已经显示过，则不再重复显示
	if choices_already_shown:
		return
	
	var choice1_text = current_line_data.get("change1", "")
	# 确保在检查选项之前隐藏所有选项按钮和容器
	change_button_1.visible = false
	change_button_2.visible = false
	change_button_3.visible = false
	change_button_4.visible = false
	change_container.visible = false

	if not choice1_text.is_empty():
		# 标记选项已经显示
		choices_already_shown = true
		
		# 如果有选项，则显示选项容器，先看选项1，只要选项1存在就算该行有选项
		change_container.visible = true
		change_button_1.text = choice1_text
		change_button_1.visible = texture

		_fade_in_node(change_button_1)

		var choice2_text = current_line_data.get("change2", "")
		if not choice2_text.is_empty():
			change_button_2.text = choice2_text
			change_button_2.visible = true
			_fade_in_node(change_button_2)

		var choice3_text = current_line_data.get("change3", "")
		if not choice3_text.is_empty():
			change_button_3.text = choice3_text
			change_button_3.visible = true
			_fade_in_node(change_button_3)

		var choice4_text = current_line_data.get("change4", "")
		if not choice4_text.is_empty():
			change_button_4.text = choice4_text
			change_button_4.visible = true
			_fade_in_node(change_button_4)
	else:
		pass 

func _fade_in_node(node: Control, duration: float = 0.15): 
	node.modulate.a = 0
	var tween = get_tree().create_tween()
	tween.tween_property(node, "modulate:a", 1.0, duration)

# 辅助函数，用于在处理新行之前为正在更改/消失的立绘制作淡出动画
func _animate_illustration_fade_out_if_changing(main_transition_tween: Tween, texture_rect: TextureRect, next_path: String):
	var current_path = ""
	if texture_rect.texture:
		current_path = texture_rect.texture.resource_path
	
	var current_is_visible_and_has_texture = texture_rect.visible and not current_path.is_empty() and texture_rect.modulate.a > 0.01
	var next_will_have_different_texture = next_path.is_empty() or not ResourceLoader.exists(next_path) or (ResourceLoader.exists(next_path) and current_path != next_path)

	if current_is_visible_and_has_texture and next_will_have_different_texture:
		main_transition_tween.parallel().tween_property(texture_rect, "modulate:a", 0.0, 0.15)

func _on_choice_pressed(choice_number: int):
	var target_condition_id = ""
	match choice_number:
		1: target_condition_id = current_line_data.get("change1id", "")
		2: target_condition_id = current_line_data.get("change2id", "")
		3: target_condition_id = current_line_data.get("change3id", "")
		4: target_condition_id = current_line_data.get("change4id", "")

	var choice_buttons = [change_button_1, change_button_2, change_button_3, change_button_4]
	var fade_out_tween = get_tree().create_tween()
	for button in choice_buttons:
		if button.visible:
			fade_out_tween.parallel().tween_property(button, "modulate:a", 0.0, 0.2)
	await fade_out_tween.finished
	for button in choice_buttons:
		button.visible = false
		button.modulate.a = 1.0 # 为下次重置 alpha 值
	change_container.visible = false 
	
	# 重置选项显示标志，为下一行对话做准备
	choices_already_shown = false

	if not target_condition_id.is_empty():
		_advance_dialog_line(target_condition_id) # 使用带条件的advance

func _find_next_line_by_condition(condition_id: String):
	for i in range(current_dialog_data.size()):
		var line = current_dialog_data[i]
		if line.get("condition", "") == condition_id:
			current_dialog_index = i
			_process_current_dialog_line()
			return
	printerr("Could not find dialog line with condition: ", condition_id)
	# 如果未找到条件，则默认推进到下一行（不带条件）
	current_dialog_index += 1
	_process_current_dialog_line()

func _find_next_available_line():
	# 寻找id大于当前index且condition为空的下一个可用对话行
	for i in range(current_dialog_index + 1, current_dialog_data.size()):
		var line = current_dialog_data[i]
		# 检查这一行是否有有效的对话内容且condition为空
		if not line.get("dialog", "").is_empty() and line.get("condition", "").is_empty():
			current_dialog_index = i
			_process_current_dialog_line()
			return
	# 如果没有找到更多可用的对话行，结束对话
	_end_dialog()

func _advance_dialog_line(condition_id: String = ""):
	print("Advancing dialog line. Current index: ", current_dialog_index, " Next index: ", current_dialog_index + 1, " with condition: ", condition_id)
	
	var current_change_end = current_line_data.get("changeEnd", false)
	
	# 如果当前行有changeEnd且没有指定跳转条件，寻找下一个可用的对话行
	if current_change_end and condition_id.is_empty():
		_find_next_available_line()
		return

	# 如果有条件ID，按条件查找
	if not condition_id.is_empty():
		_find_next_line_by_condition(condition_id)
	else:
		# 否则，推进到下一行
		current_dialog_index += 1
		# 如果上一行有changeEnd标志，寻找下一个可用的对话行
		if current_change_end:
			_find_next_available_line()
		else:
			_process_current_dialog_line()

func _end_dialog():
	print("Dialog ended.")
	# 重置所有立绘状态
	speaker_left.visible = false
	speaker_left.texture = null
	speaker_left.modulate = Color.WHITE
	
	speaker_middle.visible = false
	speaker_middle.texture = null
	speaker_middle.modulate = Color.WHITE
	
	speaker_right.visible = false
	speaker_right.texture = null
	speaker_right.modulate = Color.WHITE
	
	# 重置动画状态
	is_animating_illustrations = false
	choices_already_shown = false
	
	# 隐藏或移除对话UI
	self.visible = false 


func _input(event: InputEvent):
	# 如果对话框隐藏（也就是不在对话状态中），则不处理输入
	if not self.visible: return 

	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		# 如果立绘正在进行动画，则阻止输入
		if is_animating_illustrations:
			return
		
		# 检查当前行是否有选项，如果有选项且选项已显示，则阻止快速点击
		if is_displaying_text:
			# 如果文本正在显示，则跳过打字效果，显示完整文本
			# 停止当前的文本显示tween
			if current_text_tween and current_text_tween.is_valid():
				current_text_tween.kill()
				current_text_tween = null
			dialog_text_label.text = current_line_data.dialog
			dialog_text_label.visible_characters = dialog_text_label.text.length()
			is_displaying_text = false
			_check_for_choices()
			return # 文本显示完成后，等待下一次点击再进入下一行
		
		# 只有当文本完全显示后，才允许推进到下一个对话
		if not is_displaying_text and not _are_choices_visible():
			_advance_dialog_line() # 推进时不带特定条件

func _has_choices_in_current_line() -> bool:
	return not current_line_data.get("change1", "").is_empty()

func _are_choices_visible() -> bool:
	return change_button_1.visible or change_button_2.visible or change_button_3.visible or change_button_4.visible

func _advance_dialog_with_transition():
	if current_dialog_index + 1 >= current_dialog_data.size() and not current_line_data.get("changeEnd", false):
		# 如果是最后一行并且没有明确结束，则准备在过渡后结束对话
		var end_transition_tween = get_tree().create_tween()
		end_transition_tween.set_parallel(true)
		end_transition_tween.tween_property(dialog_text_label, "modulate:a", 0.0, 0.15)
		_animate_illustration_fade_out_if_changing(end_transition_tween, speaker_left, "")
		_animate_illustration_fade_out_if_changing(end_transition_tween, speaker_middle, "")
		_animate_illustration_fade_out_if_changing(end_transition_tween, speaker_right, "")
		await end_transition_tween.finished
		_end_dialog()
		return

	var transition_tween = get_tree().create_tween()
	transition_tween.set_parallel(true)

	# 淡出当前文本
	transition_tween.tween_property(dialog_text_label, "modulate:a", 0.0, 0.15)

	# 在推进索引之前，查看下一行以决定立绘的淡出效果
	if current_dialog_index + 1 < current_dialog_data.size():
		var next_line_data_peek = current_dialog_data[current_dialog_index + 1]
		_animate_illustration_fade_out_if_changing(transition_tween, speaker_left, next_line_data_peek.get("illustrationLeft", ""))
		_animate_illustration_fade_out_if_changing(transition_tween, speaker_middle, next_line_data_peek.get("illustrationMiddle", ""))
		_animate_illustration_fade_out_if_changing(transition_tween, speaker_right, next_line_data_peek.get("illustrationRight", ""))
	else: # 如果从实际的最后一行推进（例如，通过导致结束的跳转）
		_animate_illustration_fade_out_if_changing(transition_tween, speaker_left, "")
		_animate_illustration_fade_out_if_changing(transition_tween, speaker_middle, "")
		_animate_illustration_fade_out_if_changing(transition_tween, speaker_right, "")

	await transition_tween.finished
	dialog_text_label.modulate.a = 1.0 # 为下一行的打字机效果重置
	_advance_dialog_line()

func set_text_display_speed(speed: float):
	text_display_speed = max(0.01, speed) # 确保速度不要太快或为零
