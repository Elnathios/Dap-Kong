extends Node2D

@onready var label: Label = $Label
@onready var label_2: Label = $VBoxContainer/Label2
@onready var v_box_container: VBoxContainer = $VBoxContainer
@onready var button: Button = $VBoxContainer/Button
@onready var conductor = $Conductor
@onready var animated_sprite_2d_2: AnimatedSprite2D = $AnimatedSprite2D2
@onready var perfeito: AudioStreamPlayer2D = $perfeito
@onready var legal: AudioStreamPlayer2D = $legal
@onready var errou: AudioStreamPlayer2D = $errou
@onready var fundo: AnimatedSprite2D = $AnimatedSprite2D4  # nome corrigido (era AnimatedSprite2D3)

const TIO = preload("res://cenas/tiro.tscn")

# Mapeamento das ações de input para os tipos de nota
const ACTION_TO_NOTE_TYPE := {
	"SocoSima": "fist",
	"TapaBaixo": "highfive",
	"CostaLado": "backhand",
}

# Notas que estão dentro das áreas de acerto
var notes_in_area_maior: Array[Area2D] = []
var notes_in_area_menor: Array[Area2D] = []

# ============================================================
# ANIMAÇÃO DE FUNDO (sprite sheet "dap")
# ============================================================
# Toca antes de cada timing. Se o frame 6 for alcançado sem o
# jogador ter acertado a nota atual, a animação congela ali.
# Se o jogador acertar (a qualquer momento), ela é liberada e
# toca até o fim, mesmo que já tenha travado no frame 6.

const FRAME_DE_TRAVA := 6
const NOME_ANIMACAO_FUNDO := "dap"

var _fundo_liberado: bool = false   # true = pode passar do frame 6
var _fundo_reinicio_pendente: bool = false  # true = tem nota nova esperando a animação atual terminar
var _nota_referencia = null          # guarda qual nota está "na vez" agora
var _hora_ultima_nota: float = -1.0  # timestamp (segundos) da última troca de nota
var _intervalo_estimado: float = 0.5 # estimativa de tempo entre notas, auto-ajustada


func _ready() -> void:
	fundo.frame_changed.connect(_on_fundo_frame_changed)
	fundo.animation_finished.connect(_on_fundo_animation_finished)


func _process(_delta: float) -> void:
	label.text = str(Global.pontos) + " Pontos"

	# Mostra ou esconde o menu de fim de jogo
	if Global.fim:
		v_box_container.visible = true
	else:
		v_box_container.visible = false

	# Avaliação da pontuação
	if Global.modo:
		if Global.pontos > 4000:
			label_2.text = "Excelente"
			label_2.label_settings.font_color = Color("36c829")

		elif Global.pontos <= 4000 and Global.pontos >= 2300:
			label_2.text = "Bom"
			label_2.label_settings.font_color = Color("038dff")

		else:
			label_2.text = "Mau"
			label_2.label_settings.font_color = Color("a30704")

	else:
		if Global.pontos > 5500:
			label_2.text = "Excelente"
			label_2.label_settings.font_color = Color("36c829")

		elif Global.pontos <= 5500 and Global.pontos >= 3200:
			label_2.text = "Bom"
			label_2.label_settings.font_color = Color("038dff")

		else:
			label_2.text = "Mau"
			label_2.label_settings.font_color = Color("a30704")

	_verificar_novo_timing()


func _on_button_pressed() -> void:
	Global.fim = false
	Global.pontos = 0
	Global.modo = false

	get_tree().change_scene_to_file("res://cenas/menu.tscn")


# ============================================================
# LÓGICA DA ANIMAÇÃO DE FUNDO
# ============================================================

# Detecta quando uma nova nota vira "a nota da vez" (a próxima a ser
# julgada). Se a animação atual ainda estiver tocando o final (depois
# de um acerto, indo até o frame 10), NÃO interrompe: guarda um pedido
# pendente e só reinicia quando ela realmente terminar.
# Ajuste aqui se a "nota da vez" do seu jogo vier de outro lugar
# (ex: um sinal do Conductor em vez de olhar active_notes toda hora).
func _verificar_novo_timing() -> void:
	if conductor.active_notes.is_empty():
		return

	var nota_da_vez = conductor.active_notes[0]
	if nota_da_vez != _nota_referencia:
		var agora := Time.get_ticks_msec() / 1000.0
		if _hora_ultima_nota > 0.0:
			# Usa o intervalo real desde a última nota como estimativa
			# pra essa (o Conductor não expõe o timing diretamente,
			# então medimos "de fora").
			_intervalo_estimado = agora - _hora_ultima_nota
		_hora_ultima_nota = agora

		_nota_referencia = nota_da_vez
		_pedir_novo_ciclo_fundo()


func _pedir_novo_ciclo_fundo() -> void:
	# Se acabou de acertar e a animação ainda está tocando o final
	# (frame 6 -> 10), espera ela terminar antes de reiniciar.
	if _fundo_liberado and fundo.is_playing():
		_fundo_reinicio_pendente = true
	else:
		# NOTA: velocidade dinâmica (via _intervalo_estimado) desligada
		# por enquanto — a estimativa por intervalo passado estava
		# dessincronizando a animação em vez de ajudar. Voltando pra
		# velocidade fixa até termos o tempo real do Conductor.
		iniciar_fundo_para_nota()


func _on_fundo_animation_finished() -> void:
	if _fundo_reinicio_pendente:
		_fundo_reinicio_pendente = false
		iniciar_fundo_para_nota()


## Começa a animação do zero para a nota atual.
## tempo_ate_julgamento: quantos segundos faltam até a nota precisar
## ser acertada. Se não for informado (ou for <= 0), toca na velocidade normal.
func iniciar_fundo_para_nota(tempo_ate_julgamento: float = -1.0) -> void:
	_fundo_liberado = false
	_fundo_reinicio_pendente = false
	fundo.stop()
	fundo.play(NOME_ANIMACAO_FUNDO)

	if tempo_ate_julgamento > 0.0:
		var fps := fundo.sprite_frames.get_animation_speed(NOME_ANIMACAO_FUNDO)
		if fps <= 0.0:
			fps = 12.0  # fallback, ajuste pro fps real da sua animação

		var tempo_original_ate_trava := float(FRAME_DE_TRAVA) / fps
		fundo.speed_scale = tempo_original_ate_trava / tempo_ate_julgamento
	else:
		fundo.speed_scale = 1.0


## Chame isso quando o jogador acertar a nota atual.
## Se a animação já estiver travada no frame 6, ela retoma dali.
func liberar_fundo() -> void:
	_fundo_liberado = true
	fundo.play()  # SEM argumento -> retoma do frame onde pausou (não reinicia)


func _on_fundo_frame_changed() -> void:
	if fundo.animation != NOME_ANIMACAO_FUNDO:
		return
	# ">=" em vez de "==": com speed_scale dinâmico, a animação pode
	# pular direto do frame 5 pro 8 (ou mais) sem passar exatamente
	# pelo 6, dependendo da velocidade. Assim garantimos que ela
	# sempre trava, mesmo que tenha "pulado" o frame exato.
	if fundo.frame >= FRAME_DE_TRAVA and not _fundo_liberado:
		fundo.pause()
		fundo.frame = FRAME_DE_TRAVA  # trava visualmente sempre na mesma pose


# ============================================================
# INPUT DO JOGADOR
# ============================================================

func _unhandled_input(event: InputEvent) -> void:

	for action in ACTION_TO_NOTE_TYPE.keys():

		if event.is_action_pressed(action) and not event.is_echo():

			var tipo_apertado = ACTION_TO_NOTE_TYPE[action]

			# Verifica se existe alguma nota atualmente spawnada
			if conductor.active_notes.is_empty():
				return

			# Pega SEMPRE a primeira nota da fila
			var note = conductor.active_notes[0]

			# ------------------------------------------------
			# BOTÃO ERRADO
			# ------------------------------------------------

			if note.note_type != tipo_apertado:



				# Julga imediatamente a primeira nota como erro
				note.judge("erro")
				errou.play()
				$AnimatedSprite2D2.play("falha")

				return

			# ------------------------------------------------
			# BOTÃO CORRETO
			# ------------------------------------------------

			# Aqui continua sendo necessário que a nota
			# esteja dentro da HitArea.
			_try_hit(tipo_apertado)

			return


# ============================================================
# ACERTO DA NOTA
# ============================================================

func _try_hit(expected_type: String) -> void:

	# Se não existe nota dentro da área maior,
	# o jogador apertou cedo demais.
	if notes_in_area_maior.is_empty():
		return

	# Pega a primeira nota que entrou na área
	var target_note: Area2D = notes_in_area_maior[0]

	# Sobe na hierarquia até o nó principal da nota
	var note := target_note.get_parent().get_parent()

	# Verifica se o tipo da nota está correto
	if note.note_type != expected_type:

		note.judge("erro")



	elif notes_in_area_menor.has(target_note):

		# Acerto perfeito
		note.judge("excelente")
		Global.pontos += 200
		$AnimatedSprite2D2.play("acerto")
		perfeito.play()
		liberar_fundo()

	else:

		# Acerto normal
		note.judge("acerto")
		Global.pontos += 100
		$AnimatedSprite2D2.play("ok")
		legal.play()
		liberar_fundo()

# ============================================================
# TIRO QUANDO O JOGADOR APERTA O BOTÃO ERRADO
# ============================================================



# ============================================================
# NOTA SAIU DA ÁREA DE DESTRUIÇÃO
# ============================================================

func _on_destruct_area_area_entered(area: Area2D) -> void:

	var note = area.get_parent().get_parent()

	note.judge("miss")
	$AnimatedSprite2D2.play("falha")
	errou.play()



# ============================================================
# NOTA ENTROU NAS ÁREAS DE ACERTO
# ============================================================

func _on_area_2d_area_shape_entered(
	area_rid: RID,
	area: Area2D,
	area_shape_index: int,
	local_shape_index: int
) -> void:

	if not is_instance_valid(area):
		return

	# Shape 0 = área maior
	if local_shape_index == 0:

		if not notes_in_area_maior.has(area):

			notes_in_area_maior.append(area)

			var note = area.get_parent().get_parent()

			# Quando a nota for julgada,
			# remove ela das listas das áreas
			if not note.judged.is_connected(_on_note_judged):
				note.judged.connect(_on_note_judged.bind(area))

	# Shape 1 = área menor / excelente
	elif local_shape_index == 1:

		if not notes_in_area_menor.has(area):
			notes_in_area_menor.append(area)


# ============================================================
# NOTA SAIU DAS ÁREAS DE ACERTO
# ============================================================

func _on_area_2d_area_shape_exited(
	area_rid: RID,
	area: Area2D,
	area_shape_index: int,
	local_shape_index: int
) -> void:

	if not is_instance_valid(area):
		return

	# Shape 0 = área maior
	if local_shape_index == 0:

		notes_in_area_maior.erase(area)

	# Shape 1 = área menor
	elif local_shape_index == 1:

		notes_in_area_menor.erase(area)


# ============================================================
# NOTA FOI JULGADA
# ============================================================

func _on_note_judged(area: Area2D) -> void:

	notes_in_area_maior.erase(area)
	notes_in_area_menor.erase(area)
