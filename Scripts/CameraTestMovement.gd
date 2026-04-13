extends Camera3D

@export var target: Node3D
@export var look_speed: float = 5.0
@export var height_offset: float = 1.0

func _process(delta: float) -> void:
	if target == null:
		return

	# Точка, куда смотрим (чуть выше центра игрока)
	var look_at_pos = target.global_position + Vector3(0, height_offset, 0)

	# Направление до цели
	var direction = (look_at_pos - global_position).normalized()

	# Желаемый поворот
	var target_basis = Transform3D().looking_at(direction, Vector3.UP).basis

	# Плавный поворот
	global_transform.basis = global_transform.basis.slerp(target_basis, look_speed * delta)
