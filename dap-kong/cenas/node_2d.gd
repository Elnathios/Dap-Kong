extends Node2D

const ACTION_TO_NOTE_TYPE := {
	"SocoSima": "fist",
	"TapaBaixo": "highfive",
	"CostaLado": "backhand",
}

var notes_in_area_maior: Array[Area2D] = []
var notes_in_area_menor: Array[Area2D] = []


func _unhandled_input(event: InputEvent) -> void:
	for action in ACTION_TO_NOTE_TYPE.keys():
		if event.is_action_pressed(action):
			_try_hit(ACTION_TO_NOTE_TYPE[action])
			return


func _try_hit(expected_type: String) -> void:
	if notes_in_area_maior.is_empty():
		return  # nenhuma nota na zona, o aperto não faz nada

	var target_note: Area2D = notes_in_area_maior[0]
	var note := target_note.get_parent().get_parent()  # CollisionArea2D -> AnimatedSprite2D -> Note

	if note.note_type != expected_type:
		note.judge("erro")
	elif notes_in_area_menor.has(target_note):
		note.judge("excelente")
	else:
		note.judge("acerto")


func _on_destruct_area_area_entered(area: Area2D) -> void:
	var note = area.get_parent().get_parent()
	note.judge("miss")


func _on_area_2d_area_shape_entered(
	area_rid: RID,
	area: Area2D,
	area_shape_index: int,
	local_shape_index: int
) -> void:
	if not is_instance_valid(area):
		return
	if local_shape_index == 0:
		if not notes_in_area_maior.has(area):
			notes_in_area_maior.append(area)

			var note = area.get_parent().get_parent()
			if not note.judged.is_connected(_on_note_judged):
				note.judged.connect(_on_note_judged.bind(area))

		#print("Nota entrou na AreaMaior: ", area.name)

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

	if local_shape_index == 0:
		notes_in_area_maior.erase(area)
		#print("Nota saiu da AreaMaior: ", area.name)

	elif local_shape_index == 1:
		notes_in_area_menor.erase(area)
		#print("Nota saiu da AreaMenor: ", area.name)


func _on_note_judged(area: Area2D) -> void:
	notes_in_area_maior.erase(area)
	notes_in_area_menor.erase(area)
