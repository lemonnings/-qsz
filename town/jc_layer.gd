extends CanvasLayer

@export var jc_sprite: Sprite2D
@export var exit: Button

const JC_TEXTURES = [
	preload("res://AssetBundle/Sprites/image/start1.png"),
]

var current_page: int = 0
var is_animating: bool = false
var page_tween: Tween

signal exit_requested

func _ready() -> void:
	visible = false
	current_page = 0
	exit.pressed.connect(_on_exit_pressed)

func open_layer() -> void:
	current_page = 0
	jc_sprite.texture = JC_TEXTURES[0]
	visible = true
	# 渐入动画
	for child in get_children():
		if child.has_method("set_modulate"):
			child.modulate.a = 0.0
	var tw = create_tween()
	tw.set_parallel(true)
	for child in get_children():
		if child.has_method("set_modulate"):
			tw.tween_property(child, "modulate:a", 1.0, 0.2)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 排除 exit 按钮自身区域点击（exit 按钮有自己的信号处理）
		var exit_rect = Rect2(exit.global_position, exit.size)
		if not exit_rect.has_point(event.global_position):
			_next_page()
			get_viewport().set_input_as_handled()

func _next_page() -> void:
	if is_animating:
		return
	var next = current_page + 1
	if next >= JC_TEXTURES.size():
		# 已经是最后一页，关闭
		_close_layer()
		return
	is_animating = true
	# 渐出当前图，渐入下一图
	if page_tween:
		page_tween.kill()
	page_tween = create_tween()
	page_tween.tween_property(jc_sprite, "modulate:a", 0.0, 0.15)
	page_tween.tween_callback(func():
		current_page = next
		jc_sprite.texture = JC_TEXTURES[current_page]
	)
	page_tween.tween_property(jc_sprite, "modulate:a", 1.0, 0.15)
	page_tween.tween_callback(func(): is_animating = false)

func _on_exit_pressed() -> void:
	_close_layer()

func _close_layer() -> void:
	is_animating = true
	# 渐出动画
	var tw = create_tween()
	tw.set_parallel(true)
	for child in get_children():
		if child.has_method("set_modulate"):
			tw.tween_property(child, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		visible = false
		is_animating = false
		current_page = 0
		# 重置子节点透明度
		for child in get_children():
			if child.has_method("set_modulate"):
				child.modulate.a = 1.0
		exit_requested.emit()
	).set_delay(0.2)
