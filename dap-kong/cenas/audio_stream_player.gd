extends AudioStreamPlayer

@export var bpm = 120.0
@export var note_scene: PackedScene

var song_position = 0.0
var song_position_in_beats = 0
var sec_per_beat = 0.0
var last_reported_beat = -1

var last_energy = 0.0
var onset_threshold = 0.06
var last_onset_time = -1.0
var onset_cooldown = 0.15

var high_frequency_boost = 5.0

var spectrum_instance

signal beat_changed(beat)


func _ready():
	sec_per_beat = 60.0 / bpm

	var bus_index = AudioServer.get_bus_index("Master")
	spectrum_instance = AudioServer.get_bus_effect_instance(
		bus_index,
		0
	)


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

		var bass_energy = get_frequency_energy()
		var high_energy = get_high_frequency_energy()

		var total_energy = bass_energy + high_energy
		var energy_change = total_energy - last_energy

		if energy_change > onset_threshold:
			if song_position - last_onset_time > onset_cooldown:

				var note_type = ""

				var adjusted_high_energy = high_energy * high_frequency_boost

				if bass_energy > adjusted_high_energy:
					note_type = "fist"
				else:
					note_type = "highfive"

				spawn_note(note_type)

				print(
					"ATAQUE DETECTADO! | Tipo: ",
					note_type,
					" | Graves: ",
					bass_energy,
					" | Agudos: ",
					high_energy,
					" | Agudos ajustados: ",
					adjusted_high_energy
				)

				last_onset_time = song_position

		last_energy = total_energy


func spawn_note(note_type):
	var note = note_scene.instantiate()

	note.note_type = note_type
	note.target_time = song_position + 2.0
	note.approach_time = 2.0

	get_parent().add_child(note)


func get_frequency_energy():
	if spectrum_instance == null:
		return 0.0

	var magnitude = spectrum_instance.get_magnitude_for_frequency_range(
		20.0,
		200.0
	)

	return magnitude.length()


func get_high_frequency_energy():
	if spectrum_instance == null:
		return 0.0

	var magnitude = spectrum_instance.get_magnitude_for_frequency_range(
		2000.0,
		8000.0
	)

	return magnitude.length()
