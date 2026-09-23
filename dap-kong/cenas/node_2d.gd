extends Node2D

@onready var label: Label = $Label
@onready var label_2: Label = $VBoxContainer/Label2
@onready var v_box_container: VBoxContainer = $VBoxContainer
@onready var button: Button = $VBoxContainer/Button

# Mapeamento das ações de input registradas na Godot para os tipos de notas do jogo
const ACTION_TO_NOTE_TYPE := {
	"SocoSima": "fist",
	"TapaBaixo": "highfive",
	"CostaLado": "backhand",
}

# Listas que armazenam as áreas das notas presentes nas zonas de acerto (maior e menor/precisa)
var notes_in_area_maior: Array[Area2D] = []
var notes_in_area_menor: Array[Area2D] = []

func _process(delta: float) -> void:
	label.text = str(Global.pontos) + " Pontos"

	if Global.fim == true:
		v_box_container.visible = true
	else:
		v_box_container.visible = false

	if Global.modo:
		if Global.pontos > 4000:
			label_2.text = "Exelete"
			label_2.label_settings.font_color = Color("36c829")
		elif Global.pontos <= 4000 and Global.pontos >= 2300: 
			label_2.text = "Bom"
			label_2.label_settings.font_color = Color("038dff")
		else:
			label_2.text = "Mau"
			label_2.label_settings.font_color = Color("a30704")
	else:
		if Global.pontos > 5500:
			label_2.text = "Exelete"
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


func _unhandled_input(event: InputEvent) -> void:
	# Percorre todas as ações mapeadas para verificar se alguma foi pressionada
	for action in ACTION_TO_NOTE_TYPE.keys():
		if event.is_action_pressed(action):
			_try_hit(ACTION_TO_NOTE_TYPE[action])
			return


func _try_hit(expected_type: String) -> void:
	# Se a lista da área maior estiver vazia, não há notas alcancáveis e o clique é ignorado
	if notes_in_area_maior.is_empty():
		return  # nenhuma nota na zona, o aperto não faz nada

	# Pega a primeira nota da fila que entrou na área maior
	var target_note: Area2D = notes_in_area_maior[0]
	# Sobe na hierarquia do nó para obter o nó principal da nota (CollisionArea2D -> AnimatedSprite2D -> Note)
	var note := target_note.get_parent().get_parent()

	# Processa o julgamento com base no tipo da nota e na área em que se encontra
	if note.note_type != expected_type:
		note.judge("erro")
	elif notes_in_area_menor.has(target_note):
		note.judge("excelente")
		Global.pontos += 200
	else:
		note.judge("acerto")
		Global.pontos += 100


func _on_destruct_area_area_entered(area: Area2D) -> void:
	# Quando a nota sai do alcance sem ser atingida, notifica que ela foi perdedora (miss)
	var note = area.get_parent().get_parent()
	note.judge("miss")


func _on_area_2d_area_shape_entered(
	area_rid: RID,
	area: Area2D,
	area_shape_index: int,
	local_shape_index: int
) -> void:
	# Garante que a área detectada é uma instância válida antes de continuar
	if not is_instance_valid(area):
		return
		
	# `local_shape_index == 0` refere-se à Hitbox Maior (zona de tolerância)
	if local_shape_index == 0:
		if not notes_in_area_maior.has(area):
			notes_in_area_maior.append(area)

			var note = area.get_parent().get_parent()
			# Conecta o sinal de julgamento da nota para removê-la das listas assim que for julgada
			if not note.judged.is_connected(_on_note_judged):
				note.judged.connect(_on_note_judged.bind(area))

		#print("Nota entrou na AreaMaior: ", area.name)

	# `local_shape_index == 1` refere-se à Hitbox Menor (zona de precisão/excelente)
	elif local_shape_index == 1:
		if not notes_in_area_menor.has(area):
			notes_in_area_menor.append(area)
		#print("Nota entrou na AreaMenor: ", area.name)


func _on_area_2d_area_shape_exited(
	area_rid: RID,
	area: Area2D,
	area_shape_index: int,
	local_shape_index: int
) -> void:
	if not is_instance_valid(area):
		return

	# Remove a nota da área maior caso ela saia do formato colisor 0
	if local_shape_index == 0:
		notes_in_area_maior.erase(area)
		#print("Nota saiu da AreaMaior: ", area.name)

	# Remove a nota da área menor caso ela saia do formato colisor 1
	elif local_shape_index == 1:
		notes_in_area_menor.erase(area)
		#print("Nota saiu da AreaMenor: ", area.name)


func _on_note_judged(area: Area2D) -> void:
	# Callback executado quando a nota é julgada, limpando-a de ambas as áreas
	notes_in_area_maior.erase(area)
	notes_in_area_menor.erase(area)
