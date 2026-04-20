extends Control

## save_tip展示时长（秒）
const DISPLAY_TIME := 2.0

## 提示文本容器
@onready var tip_container: VBoxContainer = $TipContainer

func _ready() -> void:
	# 测试模式：跳过save_tip，直接进入主菜单
	if Global.is_test:
		_go_to_main_menu()
		return
	
	# 正常模式：淡入 → 停留2秒 → 淡出 → 进入主菜单
	tip_container.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(tip_container, "modulate:a", 1.0, 0.3)
	tween.tween_interval(DISPLAY_TIME)
	tween.tween_property(tip_container, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_go_to_main_menu)

## 进入主菜单
func _go_to_main_menu() -> void:
	SceneChange.change_scene("res://Scenes/start/main_menu.tscn", true, true)
