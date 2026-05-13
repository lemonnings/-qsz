extends Panel

@export var sprite: Sprite2D
@export var dialogue_detail: RichTextLabel


func _ready() -> void:
	# 设置最小尺寸，确保VBoxContainer布局时Panel背景正确绘制
	custom_minimum_size = Vector2(384, 95)
	# 强制设置半透明黑色圆角背景
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	add_theme_stylebox_override("panel", style)


## 设置说话人头像和对话内容
func setup(speaker_texture: Texture2D, text: String) -> void:
	if sprite:
		sprite.texture = speaker_texture
	if dialogue_detail:
		dialogue_detail.text = text


## 获取文本字数（用于计算显示时长）
func get_text_length() -> int:
	if dialogue_detail:
		return dialogue_detail.text.length()
	return 0
