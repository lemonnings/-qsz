extends Control

@onready var progressBar : ProgressBar = $ProgressBar
@onready var label : Label = $Label
@onready var animatedSprite2D : AnimatedSprite2D = $AnimatedSprite2D
var progress = []
var scene_load_status = 0

func _ready() -> void:
	progressBar.max_value  = 100.0
	animatedSprite2D.play()
	ResourceLoader.load_threaded_request(SceneChange.loading_path)
	pass
	
func _process(delta: float) -> void:
	scene_load_status = ResourceLoader.load_threaded_get_status(SceneChange.loading_path, progress)
	progressBar.value = progress[0] * 100
	if scene_load_status == ResourceLoader.THREAD_LOAD_LOADED:
		set_process(false)
		await  get_tree().create_timer(1).timeout
		SceneChange.change_scene(ResourceLoader.load_threaded_get(SceneChange.loading_path))
	pass
