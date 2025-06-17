extends Node

# Signal to notify when a critical hit animation/sound should play
signal critical_hit_played


@export var gun_hit_anime :AnimatedSprite2D 
@export var gun_hit_sound :AudioStreamPlayer
@export var gun_hit_crit_anime :AnimatedSprite2D
@export var gun_hit_crit_sound :AudioStreamPlayer


func _ready() -> void:
	gun_hit_anime = $GunHit
	gun_hit_sound = $GunHitSound
	gun_hit_crit_anime = $GunHitCri # Assuming the node is named GunHitCri
	gun_hit_crit_sound = $GunHitCriSound # Assuming the node is named GunHitCriSound
	gun_hit_anime.stop()
	gun_hit_crit_anime.stop()
