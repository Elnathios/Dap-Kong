extends Node2D

@export var note_type = "highfive"
@export var target_beat = 0

var target_time := 0.0
var approach_time := 2.0
var start_position := Vector2.ZERO
var target_position := Vector2.ZERO

@onready var audio_conductor = get_parent().get_node("Conductor")


func _ready():
	start_position = Vector2(100, 300)
	target_position = Vector2(700, 300)

	position = start_position


func _process(_delta):
	var current_time = audio_conductor.song_position
	var time_until_hit = target_time - current_time

	var progress = 1.0 - (time_until_hit / approach_time)

	progress = clamp(progress, 0.0, 1.0)

	position = start_position.lerp(target_position, progress)
