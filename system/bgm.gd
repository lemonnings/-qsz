extends Node

func _ready() -> void:
	random_bgm()
	Global.connect("normal_bgm", Callable(self, "random_bgm"))
	Global.connect("boss_bgm", Callable(self, "boss_bgm"))

func stop_all_bgm() -> void:
	$AudioStreamPlayer.stop()
	$AudioStreamPlayer2.stop()
	$AudioStreamPlayer3.stop()
	$AudioStreamPlayer4.stop()
	$AudioStreamPlayer5.stop()
	$AudioStreamPlayer6.stop()
	$AudioStreamPlayer7.stop()
	$AudioStreamPlayer8.stop()
	$AudioStreamPlayer9.stop()
	$AudioStreamPlayer10.stop()
	$AudioStreamPlayer11.stop()
	$AudioStreamPlayer12.stop()
	$AudioStreamPlayer13.stop()
	$AudioStreamPlayer14.stop()
	
func random_bgm() -> void:
	stop_all_bgm()
	var randi_bgm = randi_range(0, 12)
	if randi_bgm == 1:
		$AudioStreamPlayer.play(0.0)
	if randi_bgm == 2:
		$AudioStreamPlayer2.play(0.0)
	if randi_bgm == 3:
		$AudioStreamPlayer3.play(0.0)
	if randi_bgm == 4:
		$AudioStreamPlayer4.play(0.0)
	if randi_bgm == 5:
		$AudioStreamPlayer5.play(0.0)
	if randi_bgm == 6:
		$AudioStreamPlayer6.play(0.0)
	if randi_bgm == 7:
		$AudioStreamPlayer7.play(0.0)
	if randi_bgm == 8:
		$AudioStreamPlayer8.play(0.0)
	if randi_bgm == 9:
		$AudioStreamPlayer9.play(0.0)
	if randi_bgm == 0:
		$AudioStreamPlayer10.play(0.0)	
	if randi_bgm == 10:
		$AudioStreamPlayer11.play(0.0)
	if randi_bgm == 11:
		$AudioStreamPlayer12.play(0.0)
	if randi_bgm == 12:
		$AudioStreamPlayer13.play(0.0)


func boss_bgm(stage : int) -> void:
	stop_all_bgm()
	
	if stage == 1:
		$AudioStreamPlayer14.play(0.0)
	else:
		$AudioStreamPlayer14.play(0.0)
