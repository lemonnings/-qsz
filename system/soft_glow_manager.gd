extends Node

var soft_glow_filter: CanvasLayer
var is_enabled: bool = true

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

func set_vignette_strength(strength: float):
	if soft_glow_filter:
		soft_glow_filter.set_vignette_strength(strength)

func toggle_filter(enabled: bool):
	is_enabled = enabled
	if soft_glow_filter:
		soft_glow_filter.toggle_filter(enabled)

func is_filter_enabled() -> bool:
	return is_enabled
