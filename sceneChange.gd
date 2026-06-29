extends CanvasLayer

const LOADING_SCENE_PATH: String = "res://Scenes/global/loading.tscn"

var loading_path: String = ""
var is_changing_scene: bool = false
@onready var animation: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	self.hide()
	pass
	
	
func _process(_delta: float) -> void:
	pass

func is_scene_transition_active() -> bool:
	return is_changing_scene

func change_scene(path: Variant, isLoading: bool = false, skip_reset: bool = false) -> void:
	is_changing_scene = true
	_prepare_scene_tree_for_transition()
	self.show()
	self.set_layer(999)
	animation.play("new_animation")
	await animation.animation_finished
	_prepare_scene_tree_for_transition()
	# 在场景切换之前重置玩家属性，包括Faze层数
	# 启动流程场景（logo/save_tip/main_menu）切换时跳过重置
	if not skip_reset:
		PC.reset_player_attr() # 调用重置函数
	if isLoading:
		loading_path = str(path)
		get_tree().change_scene_to_file(LOADING_SCENE_PATH)
	else:
		if typeof(path) == TYPE_STRING:
			get_tree().change_scene_to_file(path)
		else:
			get_tree().change_scene_to_packed(path)
	animation.play_backwards("new_animation")
	await animation.animation_finished
	self.set_layer(-1)
	self.hide()
	if not isLoading:
		is_changing_scene = false
	pass

func _prepare_scene_tree_for_transition() -> void:
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.paused = false
	Global.in_menu = false
	Global.reset_game_speed()
