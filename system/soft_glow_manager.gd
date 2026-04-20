extends Node

var soft_glow_filter: CanvasLayer
var is_enabled: bool = true
## 是否处于游戏场景（main_town等），暗角只在游戏场景中显示
var in_gameplay: bool = false

func _ready():
	# 延迟加载柔光滤镜，避免在节点设置期间添加子节点
	call_deferred("_setup_filter")

func _setup_filter():
	# 加载柔光滤镜场景
	var filter_scene = preload("res://Scenes/global/soft_glow_filter.tscn")
	soft_glow_filter = filter_scene.instantiate()
	
	# 添加到场景树的根节点
	get_tree().root.add_child(soft_glow_filter)
	
	# 确保滤镜在正确的层级
	soft_glow_filter.layer = 10
	
	# 启动时先不显示暗角，等进入游戏场景后再开启
	soft_glow_filter.visible = false

func set_vignette_strength(strength: float):
	if soft_glow_filter:
		soft_glow_filter.set_vignette_strength(strength)

func toggle_filter(enabled: bool):
	is_enabled = enabled
	_apply_visibility()

func is_filter_enabled() -> bool:
	return is_enabled

## 进入游戏场景时调用，开启暗角（如果用户偏好也开启的话）
func enter_gameplay() -> void:
	in_gameplay = true
	_apply_visibility()

## 离开游戏场景（返回菜单等）时调用，关闭暗角
func leave_gameplay() -> void:
	in_gameplay = false
	_apply_visibility()

## 根据用户偏好和当前场景状态，决定暗角是否显示
func _apply_visibility() -> void:
	if soft_glow_filter:
		soft_glow_filter.visible = is_enabled and in_gameplay
