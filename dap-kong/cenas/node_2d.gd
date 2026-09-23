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


func _on_button_pressed() -> void:
	Global.fim = false
	Global.pontos = 0
	Global.modo = false

	get_tree().change_scene_to_file("res://cenas/menu.tscn")


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

	else:

		# Acerto normal
		note.judge("acerto")
		Global.pontos += 100
		$AnimatedSprite2D2.play("ok")
		legal.play()

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
