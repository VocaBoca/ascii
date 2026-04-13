extends CharacterBody3D

@export var move_speed: float = 4.0
@export var stop_distance: float = 0.15
@export var rotation_speed: float = 6.0 # чем больше, тем быстрее поворот

var target_node: Node3D = null
var is_moving: bool = false

func move_to_target(node: Node3D) -> void:
	if node == null:
		print("Player: target is null")
		return

	target_node = node
	is_moving = true
	print("Player: moving to ", target_node.name)


func stop_moving() -> void:
	is_moving = false
	target_node = null
	velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if not is_moving:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if target_node == null or not is_instance_valid(target_node):
		print("Player: target invalid")
		stop_moving()
		move_and_slide()
		return

	var to_target: Vector3 = target_node.global_position - global_position
	to_target.y = 0.0

	var distance := to_target.length()

	if distance <= stop_distance:
		print("Player: arrived at ", target_node.name)
		stop_moving()
		move_and_slide()
		return

	var direction := to_target.normalized()

	# Движение
	velocity = direction * move_speed
	move_and_slide()

	# Плавный поворот
	_rotate_towards(direction, delta)


func _rotate_towards(direction: Vector3, delta: float) -> void:
	if direction.length() <= 0.001:
		return

	# Угол, в который хотим повернуться
	var target_yaw := atan2(direction.x, direction.z)

	# Плавно интерполируем текущий угол к целевому
	rotation.y = lerp_angle(rotation.y, target_yaw, rotation_speed * delta)
