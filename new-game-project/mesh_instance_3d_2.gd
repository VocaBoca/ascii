extends MeshInstance3D

@export var rotation_speed := 90.0

func _process(delta: float) -> void:
	rotation_degrees.y += rotation_speed * delta
