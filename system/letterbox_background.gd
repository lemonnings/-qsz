# extends Node

# ## 全屏超宽屏黑边填充背景
# ## 当屏幕宽高比超过 16:9 时，用 start1.png 填充两侧黑边区域

# var _canvas_layer: CanvasLayer
# var _bg_rect: TextureRect

# func _ready() -> void:
# 	# 创建最底层 CanvasLayer，确保在所有游戏内容之下
# 	_canvas_layer = CanvasLayer.new()
# 	_canvas_layer.layer = -100
# 	add_child(_canvas_layer)
	
# 	# 创建覆盖全视口的背景纹理
# 	_bg_rect = TextureRect.new()
# 	_bg_rect.texture = preload("res://AssetBundle/Sprites/image/start1.png")
# 	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
# 	_bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
# 	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
# 	_canvas_layer.add_child(_bg_rect)
	
# 	# 监听视口大小变化
# 	get_viewport().size_changed.connect(_update_visibility)
# 	_update_visibility()

# func _update_visibility() -> void:
# 	var vp_size = get_viewport().get_visible_rect().size
# 	var aspect = vp_size.x / float(vp_size.y) if vp_size.y > 0 else 1.0
# 	# 16:9 ≈ 1.7778，只有更宽时才显示背景（21:9 等超宽屏）
# 	_canvas_layer.visible = aspect > 1.79
