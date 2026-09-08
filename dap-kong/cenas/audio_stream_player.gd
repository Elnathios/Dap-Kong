extends AudioStreamPlayer

@export var bpm := 100.0

var song_position := 0.0
var song_position_in_beats := 0
var sec_per_beat := 0.0
var last_reported_beat := -1

signal beat_changed(beat)


func _ready():
	sec_per_beat = 60.0 / bpm


func _physics_process(_delta):
	if playing:
		song_position = (
			get_playback_position()
			+ AudioServer.get_time_since_last_mix()
			- AudioServer.get_output_latency()
		)

		song_position_in_beats = int(floor(song_position / sec_per_beat))

		if song_position_in_beats > last_reported_beat:
			last_reported_beat = song_position_in_beats
			beat_changed.emit(song_position_in_beats)
