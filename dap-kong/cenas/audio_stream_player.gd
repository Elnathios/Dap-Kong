extends AudioStreamPlayer

@export var bpm = 120.0
@export var note_scene: PackedScene

var song_position = 0.0
var song_position_in_beats = 0
var sec_per_beat = 0.0
var last_reported_beat = -1

var detected_events = []
var next_event_index = 0

signal beat_changed(beat)


func _ready():
	sec_per_beat = 60.0 / bpm

	load_chart()

	play()


func _physics_process(_delta):
	if playing:
		var current_playback_position = get_playback_position()

		song_position = (
			current_playback_position
			+ AudioServer.get_time_since_last_mix()
			- AudioServer.get_output_latency()
		)

		spawn_upcoming_notes()

		song_position_in_beats = int(
			floor(song_position / sec_per_beat)
		)

		if song_position_in_beats > last_reported_beat:
			last_reported_beat = song_position_in_beats
			beat_changed.emit(song_position_in_beats)


func load_chart():
	var file = FileAccess.open(
		"res://charts/song_chart.json",
		FileAccess.READ
	)

	if file == null:
		print("ERRO: não foi possível encontrar o chart.")
		return

	var json_text = file.get_as_text()
	file.close()

	var loaded_events = JSON.parse_string(json_text)

	if loaded_events is Array:
		detected_events = loaded_events
		next_event_index = 0

		print("================================")
		print("CHART CARREGADO!")
		print("Eventos carregados: ", detected_events.size())
		print("================================")
	else:
		print("ERRO: o arquivo de chart não contém uma lista válida.")


func spawn_upcoming_notes():
	if next_event_index >= detected_events.size():
		return

	var event = detected_events[next_event_index]
	var event_time = event["time"]

	var note_approach_time = 2.0

	if song_position >= event_time - note_approach_time:
		var note = note_scene.instantiate()

		note.note_type = event["type"]
		note.target_time = event_time

		# Se a nota acontece antes dos 2 segundos,
		# ela nasce no início da música e usa
		# o tempo restante até o ataque.
		if event_time < note_approach_time:
			note.approach_time = event_time
		else:
			note.approach_time = note_approach_time

		get_parent().add_child(note)

		next_event_index += 1
