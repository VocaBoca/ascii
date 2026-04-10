extends MeshInstance3D

@export var rotation_speed := 90.0
@export var float_height := 0.2    # амплитуда (насколько вверх-вниз)
@export var float_speed := .8     # скорость движения

var time := 0.0
var base_y := 0.0

func _ready() -> void:
	base_y = position.y

func _process(delta: float) -> void:
	# вращение
	rotation_degrees.y += rotation_speed * delta
	rotation_degrees.x += rotation_speed * delta
	
	# движение вверх-вниз
	time += delta
	position.y = base_y + sin(time * float_speed) * float_height
