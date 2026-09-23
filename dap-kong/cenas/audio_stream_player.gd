extends AudioStreamPlayer

# BPM (Batimentos Por Minuto) da música
@export var bpm = 120.0
# Cena da nota que será instanciada na tela
@export var note_scene: PackedScene


@export var musicas: Array[AudioStream] = []
@export var musica_atual: int = 0
# Posição atual da música em segundos
var song_position = 0.0
# Posição atual da música convertida para batidas (beats)
var song_position_in_beats = 0
# Duração de cada batida em segundos
var sec_per_beat = 0.0
# Guarda a última batida emitida para evitar sinalizar o mesmo beat múltiplas vezes
var last_reported_beat = -1

var active_notes: Array[Node2D] = []
# Lista que armazenará os eventos do chart carregados do JSON
var detected_events = []
# Índice que aponta para o próximo evento a ser spawnado
var next_event_index = 0

# Sinal emitido sempre que o beat da música muda
signal beat_changed(beat)


func _ready():

	selecionar_musica(musica_atual)

	# Calcula quantos segundos dura cada batida
	sec_per_beat = 60.0 / bpm

	# Carrega o arquivo com o mapeamento das notas (chart)
	load_chart()

	# Inicia a reprodução do áudio
	play()
	


func selecionar_musica(indice: int):
	if indice < 0 or indice >= musicas.size():
		print("ERRO: índice de música inválido!")
		return
	else: 
		if Global.modo == true:
			musica_atual = 1
		else:
			musica_atual = 0
			
	stream = musicas[musica_atual]

func _physics_process(_delta):
	if playing:
		# Posição bruta do player de áudio
		var current_playback_position = get_playback_position()

		# Calcula a posição precisa do áudio compensando o atraso da mixagem e latência de saída
		song_position = (
			current_playback_position
			+ AudioServer.get_time_since_last_mix()
			- AudioServer.get_output_latency()
		)

		# Verifica e instancia as notas que devem aparecer na tela
		spawn_upcoming_notes()

		# Converte o tempo em segundos para batidas (beats)
		song_position_in_beats = int(
			floor(song_position / sec_per_beat)
		)

		# Se avançou para um novo beat, atualiza o controle e emite o sinal
		if song_position_in_beats > last_reported_beat:
			last_reported_beat = song_position_in_beats
			beat_changed.emit(song_position_in_beats)


func load_chart():
	# Define o caminho do arquivo dinamicamente antes de abrir
	var chart_path = ""
	if Global.modo:
		chart_path = "res://charts/hard/song_chart.json"
	else:
		chart_path = "res://charts/easy/song_chart.json"

	var file = FileAccess.open(chart_path, FileAccess.READ)

	if file == null:
		print("ERRO: não foi possível encontrar o chart no caminho: ", chart_path)
		return

	var json_text = file.get_as_text()
	file.close()

	var loaded_events = JSON.parse_string(json_text)

	if loaded_events is Array:
		detected_events = loaded_events
		next_event_index = 0

		print("================================")
		print("CHART CARREGADO: ", chart_path)
		print("Eventos carregados: ", detected_events.size())
		print("================================")
	else:
		print("ERRO: O arquivo JSON não contém uma lista válida (Array).")
		

func spawn_upcoming_notes():
	# Se já spawnou todas as notas da lista, encerra a verificação
	if next_event_index >= detected_events.size():
		return

	# Pega o próximo evento da lista e o tempo exato em que a nota deve ser atingida
	var event = detected_events[next_event_index]
	var event_time = event["time"]

	# Tempo de antecedência (em segundos) com que a nota deve aparecer antes do impacto
	var note_approach_time = 2.0

	# Instancia a nota se o tempo atual da música atingiu o momento de pré-carregamento
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

		# Adiciona a nota na cena (no nó pai)
		get_parent().add_child(note)

		active_notes.append(note)

		note.judged.connect(_on_note_judged)

		next_event_index += 1

func _on_finished() -> void:
		Global.fim = true
		print(Global.fim)

func _on_note_judged(note: Node2D) -> void:
	active_notes.erase(note)
