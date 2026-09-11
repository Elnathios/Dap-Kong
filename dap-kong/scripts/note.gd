extends Node2D

@export var note_type = "highfive"
@export var target_beat = 0

var target_time := 0.0
var approach_time := 2.0
var start_position := Vector2.ZERO
var target_position := Vector2.ZERO

@onready var audio_conductor = get_parent().get_node("Conductor")
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


func _ready():
	

	start_position = Vector2(100, 400)
	target_position = Vector2(900, 400)

	position = start_position
	if note_type == "fist":
		$AnimatedSprite2D.flip_h
		
	elif note_type == "backhand":
		$AnimatedSprite2D.rotate(180)

	elif note_type == "highfive":
		$AnimatedSprite2D.rotate(90)


func _process(_delta):
	var current_time = audio_conductor.song_position
	
	# Quanto tempo já passou desde que a nota nasceu
	var elapsed_time = current_time - (target_time - approach_time)

	var progress = elapsed_time / approach_time

	progress = clamp(progress, 0.0, 1.0)

	position = start_position.lerp(target_position, progress)
