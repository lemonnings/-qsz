extends CanvasLayer

@export var continue_button: Button
@export var setting_button: Button
@export var exit_button: Button

@export var tips_panel: Panel
@export var ok_button: Button
@export var return_button: Button

var main_panel: Panel
var setting_layer_ref: Panel # 由 battle_canvas_layer 传入

const FADE_DURATION: float = 0.15

func _ready() -> void:
	main_panel = continue_button.get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	continue_button.pressed.connect(_on_continue_pressed)
	setting_button.pressed.connect(_on_setting_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	ok_button.pressed.connect(_on_ok_pressed)
	return_button.pressed.connect(_on_return_pressed)
	
	visible = false
	tips_panel.visible = false

## 由 battle_canvas_layer 调用，传入设定面板引用并连接其关闭按钮
func setup(p_setting_layer: Panel) -> void:
	setting_layer_ref = p_setting_layer
	setting_layer_ref.process_mode = Node.PROCESS_MODE_ALWAYS
	var exit_btn = p_setting_layer.get_node_or_null("Exit2")
	if exit_btn:
		exit_btn.pressed.connect(_close_setting)

# ==================== 打开 / 关闭暂停菜单 ====================

func open() -> void:
	visible = true
	main_panel.modulate = Color(1, 1, 1, 0)
	tips_panel.visible = false
	get_tree().paused = true
	Global.in_menu = true
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(main_panel, "modulate:a", 1.0, FADE_DURATION)

func close() -> void:
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(main_panel, "modulate:a", 0.0, FADE_DURATION)
	await tween.finished
	visible = false
	get_tree().paused = false
	Global.in_menu = false

# ==================== 按钮回调 ====================

func _on_continue_pressed() -> void:
	close()

func _on_setting_pressed() -> void:
	if not setting_layer_ref:
		return
	setting_layer_ref.modulate = Color(1, 1, 1, 0)
	setting_layer_ref.visible = true
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(setting_layer_ref, "modulate:a", 1.0, FADE_DURATION)

func _close_setting() -> void:
	if not setting_layer_ref:
		return
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(setting_layer_ref, "modulate:a", 0.0, FADE_DURATION)
	await tween.finished
	setting_layer_ref.visible = false

func _on_exit_pressed() -> void:
	main_panel.visible = false
	tips_panel.modulate = Color(1, 1, 1, 0)
	tips_panel.visible = true
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(tips_panel, "modulate:a", 1.0, FADE_DURATION)

func _on_ok_pressed() -> void:
	get_tree().paused = false
	Global.in_menu = false
	SceneChange.change_scene("res://Scenes/main_town.tscn", true)

func _on_return_pressed() -> void:
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(tips_panel, "modulate:a", 0.0, FADE_DURATION)
	await tween.finished
	tips_panel.visible = false
	main_panel.visible = true
