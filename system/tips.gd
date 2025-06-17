extends Panel

@export var tips_text : RichTextLabel
var animation_queue := []
var is_animating := false

func _ready():
	# 创建一个新的 StyleBoxFlat
	var style_box = StyleBoxFlat.new()
	
	# 设置背景颜色
	style_box.bg_color = Color(0.1, 0.1, 0.1, 0.7) # 深灰色
	
	# 设置边框颜色和宽度
	style_box.border_color = Color(1, 1, 1) # 白色边框
	style_box.border_width_top = 0
	style_box.border_width_bottom = 0
	style_box.border_width_left = 0
	style_box.border_width_right = 0
	
	# 设置圆角半径
	style_box.corner_radius_top_left = 20
	style_box.corner_radius_top_right = 20
	style_box.corner_radius_bottom_left = 20
	style_box.corner_radius_bottom_right = 20
	
	# 将 StyleBox 应用于当前 Panel
	self.add_theme_stylebox_override("panel", style_box)
	# 设置初始位置
	self.visible = false
	self.position.y = 130
	self.modulate.a = 0
	
func start_animation(text: String, tips_time: float) -> void:
	if not is_animating:
		_perform_animation(text, tips_time)
	else:
		animation_queue.append(text)
		
func _perform_animation(text: String, tips_time: float):
	is_animating = true
	self.visible = true
	tips_text.text = text
	var tween = create_tween()
	
	self.modulate.a = 1
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1, tips_time * 0.3)
	tween.tween_property(self, "position:y", 100, tips_time * 0.3)
	
	tween.tween_interval(tips_time)
	tween.set_parallel(false)
	
	tween.tween_property(self, "modulate:a", 0, tips_time * 0.6)
	tween.connect("finished", Callable(self, "_on_tween_completed").bind(text,tips_time))


# 当暂停结束时调用的函数
func _on_tween_completed(_object, _key):
	is_animating = false
	self.visible = false
	self.position.y = 130
	self.modulate.a = 0
	if animation_queue.size() > 0:
		var text = animation_queue.pop_front()
		_perform_animation(text, _key)
