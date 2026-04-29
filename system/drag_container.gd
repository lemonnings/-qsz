extends Control

## 可拖拽容器 —— 配合父节点 Polygon2D 的 clip_children 实现多边形区域裁剪 + 拖拽
## 使用 _gui_input 接收初始点击（尊重 z_order，back 按钮优先），
## 拖拽中通过 _input 处理移动和释放（鼠标移出区域时不断线）
## 自动从父 Polygon2D 获取包围矩形，限制拖拽不超出可见范围

var _dragging := false
var _drag_offset := Vector2.ZERO
var _clip_rect := Rect2() # 父节点多边形的包围矩形

## 至少保留多少像素的内容在可见区域内
@export var drag_padding := 100.0


func _ready() -> void:
	# 从父 Control 的 rect 获取裁剪边界
	var parent_ctrl = get_parent() as Control
	if parent_ctrl:
		_clip_rect = Rect2(Vector2.ZERO, parent_ctrl.size)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			var parent_local = _to_parent_local(event.global_position)
			_drag_offset = position - parent_local
			accept_event()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			_dragging = false
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var parent_local = _to_parent_local(event.global_position)
		position = _clamp_position(parent_local + _drag_offset)
		get_viewport().set_input_as_handled()


## 将全局坐标转换为父节点局部坐标（兼容 Control 和 Node2D）
func _to_parent_local(global_pos: Vector2) -> Vector2:
	var p = get_parent() as CanvasItem
	if p:
		return p.get_global_transform().affine_inverse() * global_pos
	return global_pos


func _clamp_position(pos: Vector2) -> Vector2:
	if _clip_rect.size == Vector2.ZERO:
		return pos
	# 限制：DragContainer 至少保留 drag_padding 像素在可见区域内
	var min_pos = _clip_rect.position - size + Vector2(drag_padding, drag_padding)
	var max_pos = _clip_rect.end - Vector2(drag_padding, drag_padding)
	pos.x = clamp(pos.x, min_pos.x, max_pos.x)
	pos.y = clamp(pos.y, min_pos.y, max_pos.y)
	return pos
