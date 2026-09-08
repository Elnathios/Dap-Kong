extends Node

@export var note_scene: PackedScene

@onready var audio_conductor = $"../Conductor"

var chart = [
	{
		"beat": 1,
		"type": "highfive"
	},
	{
		"beat": 2,
		"type": "fist"
	},
	{
		"beat": 3,
		"type": "highfive"
	},
	{
		"beat": 4,
		"type": "fist"
	}
]


func _ready():
	audio_conductor.beat_changed.connect(_on_beat_changed)


func _on_beat_changed(beat):
	print("Batida recebida: ", beat)
