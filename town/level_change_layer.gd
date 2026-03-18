extends CanvasLayer

@export var stage1: Button
@export var stage2: Button
@export var stage3: Button
@export var stage4: Button
@export var stage5: Button
@export var stage6: Button
@export var stage7: Button
@export var stage8: Button

@export var rect1: Area2D
@export var rect2: Area2D
@export var rect3: Area2D
@export var rect4: Area2D
@export var rect5: Area2D
@export var rect6: Area2D
@export var rect7: Area2D
@export var rect8: Area2D

const FADE_DURATION := 0.1 # 过渡动画时长
const MOUSE_OFFSET := Vector2(39, 26) # 鼠标右下角偏移量

var _tweens: Dictionary = {} # 存储每个按钮的Tween
var _is_showing: Dictionary = {} # 跟踪每个按钮的显示状态
var _active_button: Button = null # 当前激活的按钮（用于跟随鼠标）

func _ready() -> void:
	stage1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage4.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage5.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage6.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage7.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage8.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 连接 Area2D 的 input_event 信号来检测点击
	rect1.input_event.connect(_on_rect_input_event.bind(stage1))
	rect2.input_event.connect(_on_rect_input_event.bind(stage2))
	rect3.input_event.connect(_on_rect_input_event.bind(stage3))
	rect4.input_event.connect(_on_rect_input_event.bind(stage4))
	rect5.input_event.connect(_on_rect_input_event.bind(stage5))
	rect6.input_event.connect(_on_rect_input_event.bind(stage6))
	rect7.input_event.connect(_on_rect_input_event.bind(stage7))
	rect8.input_event.connect(_on_rect_input_event.bind(stage8))


# 每帧更新激活按钮的位置，跟随鼠标
func _process(_delta: float) -> void:
	if _active_button != null and _active_button.visible:
		var mouse_pos = get_viewport().get_mouse_position()
		# 修正：根据 CanvasLayer 的缩放和偏移计算按钮位置
		_active_button.global_position = (mouse_pos + MOUSE_OFFSET - offset) / scale


# 通过 Area2D 检测点击，手动触发按钮的 pressed 信号
func _on_rect_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, button: Button) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if button.visible and button.modulate.a > 0.5:
				# 检查是否为未开放关卡 (5, 6, 7, 8)
				if button == stage5 or button == stage6 or button == stage7 or button == stage8:
					var current_scene = get_tree().current_scene
					if current_scene and "tip" in current_scene and current_scene.tip:
						if current_scene.tip.has_method("start_animation"):
							current_scene.tip.start_animation("当前测试版本该关卡暂未开放", 0.5)
					return # 阻止进入关卡
				
				button.pressed.emit()

# 渐入效果
func _fade_in(button: Button, rect: Area2D) -> void:
	if _is_showing.get(button, false):
		return # 已经在显示状态，跳过
	_is_showing[button] = true
	_active_button = button # 设置当前激活的按钮
	_stop_tween(button)
	# 初始化位置到鼠标右下角
	var mouse_pos = get_viewport().get_mouse_position()
	# 修正：根据 CanvasLayer 的缩放和偏移计算按钮位置
	button.global_position = (mouse_pos + MOUSE_OFFSET - offset) / scale
	button.visible = true
	button.modulate.a = 0.0
	var tween := create_tween()
	_tweens[button] = tween
	tween.tween_property(button, "modulate:a", 1.0, FADE_DURATION).set_ease(Tween.EASE_OUT)


# 渐出效果
func _fade_out(button: Button, rect: Area2D) -> void:
	if not _is_showing.get(button, false):
		return # 已经在隐藏状态，跳过
	_is_showing[button] = false
	if _active_button == button:
		_active_button = null # 清除激活按钮
	_stop_tween(button)
	var tween := create_tween()
	_tweens[button] = tween
	tween.tween_property(button, "modulate:a", 0.0, FADE_DURATION).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): button.visible = false)


# 停止当前按钮的Tween
func _stop_tween(button: Button) -> void:
	if _tweens.has(button) and _tweens[button] != null and _tweens[button].is_valid():
		_tweens[button].kill()


func _on_rect_1_mouse_entered() -> void:
	_fade_in(stage1, rect1)

func _on_rect_1_mouse_exited() -> void:
	_fade_out(stage1, rect1)


func _on_rect_2_mouse_entered() -> void:
	_fade_in(stage2, rect2)

func _on_rect_2_mouse_exited() -> void:
	_fade_out(stage2, rect2)
	
func _on_rect_3_mouse_entered() -> void:
	_fade_in(stage3, rect3)

func _on_rect_3_mouse_exited() -> void:
	_fade_out(stage3, rect3)
	
func _on_rect_4_mouse_entered() -> void:
	_fade_in(stage4, rect4)

func _on_rect_4_mouse_exited() -> void:
	_fade_out(stage4, rect4)
	
func _on_rect_5_mouse_entered() -> void:
	_fade_in(stage5, rect5)

func _on_rect_5_mouse_exited() -> void:
	_fade_out(stage5, rect5)
	
func _on_rect_6_mouse_entered() -> void:
	_fade_in(stage6, rect6)

func _on_rect_6_mouse_exited() -> void:
	_fade_out(stage6, rect6)
	
func _on_rect_7_mouse_entered() -> void:
	_fade_in(stage7, rect7)

func _on_rect_7_mouse_exited() -> void:
	_fade_out(stage7, rect7)
	
func _on_rect_8_mouse_entered() -> void:
	_fade_in(stage8, rect8)

func _on_rect_8_mouse_exited() -> void:
	_fade_out(stage8, rect8)
