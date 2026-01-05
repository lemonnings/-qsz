extends CanvasLayer

@export var stage1: Button
@export var stage2: Button
@export var stage3: Button
@export var stage4: Button
@export var stage5: Button

@export var rect1: Area2D
@export var rect2: Area2D
@export var rect3: Area2D
@export var rect4: Area2D
@export var rect5: Area2D

const FADE_DURATION := 0.2 # 过渡动画时长

var _tweens: Dictionary = {} # 存储每个按钮的Tween
var _is_showing: Dictionary = {} # 跟踪每个按钮的显示状态

func _ready() -> void:
	stage1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage4.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage5.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 连接 Area2D 的 input_event 信号来检测点击
	rect1.input_event.connect(_on_rect_input_event.bind(stage1))
	rect2.input_event.connect(_on_rect_input_event.bind(stage2))
	rect3.input_event.connect(_on_rect_input_event.bind(stage3))
	rect4.input_event.connect(_on_rect_input_event.bind(stage4))
	rect5.input_event.connect(_on_rect_input_event.bind(stage5))


# 通过 Area2D 检测点击，手动触发按钮的 pressed 信号
func _on_rect_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, button: Button) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if button.visible and button.modulate.a > 0.5:
				button.pressed.emit()

# 渐入效果
func _fade_in(button: Button) -> void:
	print("[FADE_IN] button=%s, is_showing=%s" % [button.name, _is_showing.get(button, false)])
	if _is_showing.get(button, false):
		print("[FADE_IN] 跳过 - 已经在显示状态")
		return # 已经在显示状态，跳过
	print("[FADE_IN] 执行渐入动画")
	_is_showing[button] = true
	_stop_tween(button)
	button.visible = true
	button.modulate.a = 0.0
	var tween := create_tween()
	_tweens[button] = tween
	tween.tween_property(button, "modulate:a", 1.0, FADE_DURATION).set_ease(Tween.EASE_OUT)


# 渐出效果
func _fade_out(button: Button) -> void:
	print("[FADE_OUT] button=%s, is_showing=%s" % [button.name, _is_showing.get(button, false)])
	if not _is_showing.get(button, false):
		print("[FADE_OUT] 跳过 - 已经在隐藏状态")
		return # 已经在隐藏状态，跳过
	print("[FADE_OUT] 执行渐出动画")
	_is_showing[button] = false
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
	_fade_in(stage1)

func _on_rect_1_mouse_exited() -> void:
	_fade_out(stage1)


func _on_rect_2_mouse_entered() -> void:
	_fade_in(stage2)

func _on_rect_2_mouse_exited() -> void:
	_fade_out(stage2)
	
func _on_rect_3_mouse_entered() -> void:
	_fade_in(stage3)

func _on_rect_3_mouse_exited() -> void:
	_fade_out(stage3)
	
func _on_rect_4_mouse_entered() -> void:
	_fade_in(stage4)

func _on_rect_4_mouse_exited() -> void:
	_fade_out(stage4)
	
func _on_rect_5_mouse_entered() -> void:
	_fade_in(stage5)

func _on_rect_5_mouse_exited() -> void:
	_fade_out(stage5)
