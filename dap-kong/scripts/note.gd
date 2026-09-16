extends Node2D

signal judged(note: Node2D)

@export var note_type = "highfive"
@export var target_beat = 0

var target_time := 0.0
var approach_time := 2.0
var start_position := Vector2.ZERO
var target_position := Vector2.ZERO
var _is_judged := false

@onready var audio_conductor = get_parent().get_node("Conductor")
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


func _ready():
	add_to_group("notes")

	start_position = Vector2(100, 500)
	target_position = Vector2(1000, 500)

	position = start_position

	if note_type == "fist":
		$AnimatedSprite2D.play("soco")
	elif note_type == "backhand":
		$AnimatedSprite2D.play("costa")
	elif note_type == "highfive":
		$AnimatedSprite2D.play("costa")


func _process(_delta):
	if _is_judged:
		return

	var current_time = audio_conductor.song_position
	var elapsed_time = current_time - (target_time - approach_time)
	var progress = elapsed_time / approach_time
	progress = clamp(progress, 0.0, 1.0)
	position = start_position.lerp(target_position, progress)


func judge(result: String) -> void:
	if _is_judged:
		return
	_is_judged = true

	print("Nota julgada: ", note_type, " -> ", result)

	judged.emit(self)
	queue_free()
