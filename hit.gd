extends Node

signal critical_hit_played


@export var gun_hit_anime :AnimatedSprite2D 
@export var gun_hit_sound :AudioStreamPlayer
@export var gun_hit_crit_anime :AnimatedSprite2D
@export var gun_hit_crit_sound :AudioStreamPlayer


func _ready() -> void:
	gun_hit_anime = $GunHit
	gun_hit_sound = $GunHitSound
	gun_hit_crit_anime = $GunHitCri
	gun_hit_crit_sound = $GunHitCriSound
	gun_hit_anime.stop()
	gun_hit_crit_anime.stop()
