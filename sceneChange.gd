extends CanvasLayer

var loading_path = ""
@onready var animation: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	self.hide()
	pass
	
	
func _process(_delta: float) -> void:
	pass
	
func change_scene(path, isLoading: bool = false, skip_reset: bool = false):
	self.show()
	self.set_layer(999)
	animation.play("new_animation")
	await animation.animation_finished
	# 在场景切换之前重置玩家属性，包括Faze层数
	# 启动流程场景（logo/save_tip/main_menu）切换时跳过重置
	if not skip_reset:
		PC.reset_player_attr() # 调用重置函数
	if isLoading:
		loading_path = path
		get_tree().change_scene_to_file("res://Scenes/global/loading.tscn")
	else:
		if typeof(path) == TYPE_STRING:
			get_tree().change_scene_to_file(path)
		else:
			get_tree().change_scene_to_packed(path)
	animation.play_backwards("new_animation")
	await animation.animation_finished
	self.set_layer(-1)
	self.hide()
	pass
