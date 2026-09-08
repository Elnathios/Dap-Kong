extends Node

@export var note_scene: PackedScene
@export var note_approach_time = 2.0
@onready var audio_conductor = $"../Conductor"

var next_note_index = 0

var chart = [
	{
		"beat": 4,
		"type": "highfive"
	},
	{
		"beat": 5,
		"type": "fist"
	},
	{
		"beat": 6,
		"type": "highfive"
	},
	{
		"beat": 7,
		"type": "fist"
	}
]


func _process(_delta):
	if next_note_index >= chart.size():
		return
	
	var note_data = chart[next_note_index]
	var target_time = note_data["beat"] * audio_conductor.sec_per_beat
	
	if audio_conductor.song_position >= target_time - note_approach_time:
		spawn_note(note_data)
		next_note_index += 1


func spawn_note(note_data):
	var note = note_scene.instantiate()

	note.note_type = note_data["type"]
	note.target_beat = note_data["beat"]

	note.target_time = note_data["beat"] * audio_conductor.sec_per_beat
	note.approach_time = note_approach_time

	add_child(note)
