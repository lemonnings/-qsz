extends Control

## Logo展示时长（秒）
const LOGO_DISPLAY_TIME := 2.0
## 淡入时长（秒）
const FADE_IN_TIME := 0.5
## 淡出时长（秒）
const FADE_OUT_TIME := 0.5

## logo容器节点（包含图标和标题）
@onready var logo_container: VBoxContainer = $LogoContainer

func _ready() -> void:
	# 测试模式：跳过开屏动画，直接进入游戏
	if Global.is_test:
		_go_to_main_town()
		return
	
	# 正常模式：播放logo动画（淡入 → 停留 → 淡出 → 切换场景）
	logo_container.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(logo_container, "modulate:a", 1.0, FADE_IN_TIME)
	tween.tween_interval(LOGO_DISPLAY_TIME)
	tween.tween_property(logo_container, "modulate:a", 0.0, FADE_OUT_TIME)
	tween.tween_callback(_go_to_save_tip)

## 进入save_tip场景
func _go_to_save_tip() -> void:
	SceneChange.change_scene("res://Scenes/start/save_tip.tscn", false, true)

## 测试模式：直接进入主城镇
func _go_to_main_town() -> void:
	Global.soft_glow_manager.enter_gameplay()
	SceneChange.change_scene("res://Scenes/main_town.tscn", true)
