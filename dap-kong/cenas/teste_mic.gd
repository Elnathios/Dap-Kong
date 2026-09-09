extends Control

var mic_bus_idx: int
var noise_threshold_db: float = -15.0 # O filtro: se o barulho da sala bater na barra, aumente para -10, etc.
var max_volume_db: float = -1.0    # O volume de um Dap perfeito
var cooldown: float = 0.0             # Tempo de espera após um Dap

@onready var volume_bar = $ProgressBar
@onready var rank_label = $Label

func _ready():
	mic_bus_idx = AudioServer.get_bus_index("Mic")
	# Configura a barra de progresso para ir de 0 a 100
	volume_bar.max_value = 100.0 
	rank_label.text = "Mande o DAP!"

func _process(delta):
	# Captura o volume atual do microfone
	var volume_db = AudioServer.get_bus_peak_volume_left_db(mic_bus_idx, 0)
	
	# Transforma os decibéis (que são negativos) em porcentagem pra barra visual
	volume_bar.value = db_to_linear(volume_db) * 100 
	
	# Sistema de resfriamento para não ler o mesmo tapa 50 vezes num milissegundo
	if cooldown > 0:
		cooldown -= delta
		return
		
	# Detecta o DAP: Se o som for mais alto que o barulho de fundo
	if volume_db > noise_threshold_db:
		avaliar_dap(volume_db)
		cooldown = 0.5 # Fica meio segundo sem ouvir nada até o próximo Dap

func avaliar_dap(pico_db):
	print("Pico real detectado: ", pico_db, " dB")
	# Transforma os decibéis num score de 0 a 100
	var score = remap(pico_db, noise_threshold_db, max_volume_db, 0.0, 100.0)
	score = clamp(score, 0.0, 100.0) # Trava o valor entre 0 e 100
	
	var rank = ""
	
	if score < 40:
		rank = "FRACO..."
	elif score < 70:
		rank = "BOM!"
	elif score < 90:
		rank = "BRABO!!"
	else:
		rank = "PERFEITO (ESTOUROU!)"
		
	rank_label.text = "Nota: %d\nRank: %s" % [score, rank]
