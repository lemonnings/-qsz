extends Panel

## ── 子节点引用 ──────────────────────────────
## 发言人名称标签
@onready var speaker_name_label: RichTextLabel = $SpeakerNameLabel
## 对话文本标签（打字机效果目标）
@onready var dialog_label: RichTextLabel = $DialogLabel
## 发言人名称背景面板
@onready var speaker_name_panel: Panel = $SpeakerNamePanel

# ── tscn 基础尺寸常量（1x 基准值）──────────────
const BASE_PANEL_SIZE := Vector2(165, 62)
const BASE_NAME_PANEL_OFFSET := Vector2(8, 6)
const BASE_NAME_PANEL_SIZE := Vector2(48, 22)
const BASE_NAME_LABEL_OFFSET := Vector2(3, 6)
const BASE_NAME_LABEL_SIZE := Vector2(59, 21)
const BASE_DIALOG_OFFSET := Vector2(0, 23)
const BASE_DIALOG_SIZE := Vector2(128, 22)
const BASE_FONT_SIZE := 11
const BASE_NAME_OUTLINE := 3
const BASE_DIALOG_OUTLINE := 2


## ── 公开方法 ─────────────────────────────────

## 设置发言人名称
func set_speaker_name(text: String) -> void:
	speaker_name_label.text = text


## 设置对话文本并重置打字进度
func set_text(t: String) -> void:
	dialog_label.text = t
	dialog_label.visible_characters = 0


## 获取文本总长度（字符数）
func get_text_length() -> int:
	return dialog_label.text.length()


## 按倍率放大面板所有子节点尺寸和字号（不使用 scale，避免像素模糊）
func apply_zoom(z: float) -> void:
	# 根面板尺寸
	size = BASE_PANEL_SIZE * z
	scale = Vector2.ONE # 确保不叠加 scale

	# SpeakerNamePanel
	speaker_name_panel.position = BASE_NAME_PANEL_OFFSET * z
	speaker_name_panel.size = BASE_NAME_PANEL_SIZE * z

	# SpeakerNameLabel
	speaker_name_label.position = BASE_NAME_LABEL_OFFSET * z
	speaker_name_label.size = BASE_NAME_LABEL_SIZE * z
	var name_fs := int(BASE_FONT_SIZE * z)
	speaker_name_label.add_theme_font_size_override("normal_font_size", name_fs)
	speaker_name_label.add_theme_constant_override("outline_size", int(BASE_NAME_OUTLINE * z))

	# DialogLabel
	dialog_label.position = BASE_DIALOG_OFFSET * z
	dialog_label.size = BASE_DIALOG_SIZE * z
	var dlg_fs := int(BASE_FONT_SIZE * z)
	dialog_label.add_theme_font_size_override("normal_font_size", dlg_fs)
	dialog_label.add_theme_font_size_override("bold_font_size", int(20 * z))
	dialog_label.add_theme_constant_override("outline_size", int(BASE_DIALOG_OUTLINE * z))


## 重置面板为初始状态
func reset() -> void:
	dialog_label.text = ""
	dialog_label.visible_characters = 0
	speaker_name_label.text = ""
	visible = false
	modulate.a = 1.0
