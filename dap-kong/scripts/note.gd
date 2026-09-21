extends Node2D

# Sinal emitido quando a nota é julgada (acerto, erro, excelente ou miss)
signal judged(note: Node2D)

# Propriedades da nota configuráveis no Inspetor
@export var note_type = "highfive"
@export var target_beat = 0

# Variáveis de controle de tempo e movimento da nota
var target_time = 0.0
var approach_time = 2.0
var start_position = Vector2.ZERO
var target_position = Vector2.ZERO
var _is_judged = false

# Referência ao nó condutor de áudio e ao sprite animado
@onready var audio_conductor = get_parent().get_node("Conductor")
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


func _ready():
	# Adiciona esta instância ao grupo "notes" para facilitar buscas ou operações em lote
	add_to_group("notes")

	# Define a posição inicial (onde a nota nasce) e a posição final (hitbox/alvo)
	start_position = Vector2(100, 500)
	target_position = Vector2(1000, 500)

	# Posiciona a nota no ponto inicial ao ser carregada
	position = start_position

	# Seleciona a animação do sprite de acordo com o tipo da nota
	if note_type == "fist":
		$AnimatedSprite2D.play("soco")
	elif note_type == "backhand":
		$AnimatedSprite2D.play("costa")
	elif note_type == "highfive":
		$AnimatedSprite2D.play("palma")


func _process(_delta):
	# Se a nota já foi julgada, interrompe a atualização de movimento
	if _is_judged:
		return

	# Pega o tempo atual da música através do Conductor
	var current_time = audio_conductor.song_position
	# Calcula quanto tempo já se passou desde que a nota começou a se mover
	var elapsed_time = current_time - (target_time - approach_time)
	# Determina o progresso da interpolação de 0.0 (início) até 1.0 (momento do acerto)
	var progress = elapsed_time / approach_time
	progress = clamp(progress, 0.0, 1.0)
	
	# Interpola linearmente a posição da nota entre a origem e o alvo
	position = start_position.lerp(target_position, progress)


func judge(result: String) -> void:
	# Evita que a nota seja julgada mais de uma vez
	if _is_judged:
		return
	_is_judged = true

	print("Nota julgada: ", note_type, " -> ", result)

	# Notifica que a nota foi julgada e a remove da árvore de nós
	judged.emit(self)
	queue_free()
