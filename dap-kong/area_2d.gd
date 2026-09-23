extends Area2D

# Velocidade do projétil em pixels por segundo
@export var speed: float = 400.0

# Posicao inicial customizavel pelo Inspetor da Godot
@export var initial_position: Vector2 = Vector2.ZERO

# Chamado quando o nó entra na árvore da cena pela primeira vez.
func _ready() -> void:
	# Define a posição global inicial
	global_position = initial_position


func _process(delta: float) -> void:
	position += Vector2.RIGHT * speed * delta
