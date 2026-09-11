extends Node

@export var audio_player: AudioStreamPlayer

var last_energy = 0.0
var onset_threshold = 0.06
var last_onset_time = -1.0
var onset_cooldown = 0.50

var high_frequency_boost = 5.0

var detected_events = []

var spectrum_instance

var analyzing = true


func _ready():
	var bus_index = AudioServer.get_bus_index("Master")
	spectrum_instance = AudioServer.get_bus_effect_instance(bus_index, 0)

	audio_player.finished.connect(finish_analysis)

	audio_player.play()


func _physics_process(_delta):
	if audio_player == null:
		return

	if not audio_player.playing:
		return

	var song_position = audio_player.get_playback_position()

	var bass_energy = get_frequency_energy()
	var high_energy = get_high_frequency_energy()

	var total_energy = bass_energy + high_energy
	var energy_change = total_energy - last_energy

	if energy_change > onset_threshold:
		if song_position - last_onset_time > onset_cooldown:

			var note_type = ""

			var adjusted_high_energy = (
				high_energy * high_frequency_boost
			)

			var total_frequency_energy = (
				bass_energy + adjusted_high_energy
			)

			if total_frequency_energy > 0.0:
				var bass_ratio = (
					bass_energy / total_frequency_energy
				)

				if bass_ratio > 0.70:
					note_type = "fist"

				elif bass_ratio < 0.50:
					note_type = "backhand"

				else:
					note_type = "highfive"

				detected_events.append({
					"time": song_position,
					"type": note_type
				})

				print(
					"ATAQUE DETECTADO! | Tipo: ",
					note_type,
					" | Tempo: ",
					song_position
				)

				last_onset_time = song_position

	last_energy = total_energy


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


func finish_analysis():
	if not analyzing:
		return

	analyzing = false

	audio_player.stop()

	var file = FileAccess.open(
		"res://charts/song_chart.json",
		FileAccess.WRITE
	)

	if file:
		var json_text = JSON.stringify(
			detected_events,
			"\t"
		)

		file.store_string(json_text)
		file.close()

		print("================================")
		print("ANÁLISE CONCLUÍDA!")
		print("Eventos encontrados: ", detected_events.size())
		print("Chart salvo em: res://charts/song_chart.json")
		print("================================")
	else:
		print("ERRO: não foi possível salvar o chart.")
