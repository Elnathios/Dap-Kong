extends Control

@onready var label_2: Label = $VBoxContainer/Label2
@onready var button_easy: Button = $VBoxContainer/ButtonEasy
@onready var button_hard: Button = $VBoxContainer/ButtonHard


func _ready() -> void:
	button_easy.pressed.connect(_on_button_easy_pressed)
	button_hard.pressed.connect(_on_button_hard_pressed)
	
	_atualizar_label()

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("select"):
		get_tree().change_scene_to_file("res://cenas/node_2d.tscn")
		print(Global.modo)


func _on_button_easy_pressed() -> void:
	Global.modo = false
	_atualizar_label()


func _on_button_hard_pressed() -> void:
	Global.modo = true
	_atualizar_label()


func _atualizar_label() -> void:
	if Global.modo:
		label_2.text = "Hard"
		label_2.label_settings.font_color = Color("a30704")
	else:
		label_2.text = "Easy"
		label_2.label_settings.font_color = Color.WHITE
