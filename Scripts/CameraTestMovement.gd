extends Node3D

@export var rotation_angle := 30.0 # угол в градусах
@export var speed := .3           # скорость колебания

var time_passed := 0.0

func _process(delta):
	time_passed += delta * speed
	
	# Синус делает плавное "туда-сюда" движение
	var angle = sin(time_passed) * deg_to_rad(rotation_angle)
	
	rotation.y = angle
