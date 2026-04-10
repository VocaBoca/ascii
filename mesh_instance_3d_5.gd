extends MeshInstance3D

@export var hidden_time := 8
@export var visible_time := 4

@export var appear_scale := 0.9
@export var scale_time := 0.2

var original_scale: Vector3

func _ready() -> void:
	original_scale = scale
	loop()

func loop() -> void:
	while true:
		visible = false
		await get_tree().create_timer(hidden_time).timeout

		# появление
		visible = true
		scale = original_scale * appear_scale

		var tween = create_tween()
		tween.tween_property(self, "scale", original_scale, scale_time)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_IN)

		await get_tree().create_timer(visible_time).timeout
