extends AnimationPlayer

@onready var terminal : Control = $Terminal/ConsoleWindow

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	play('SpotlightBlink');
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

#BADBADBAD
func _on_animation_finished(anim_name: StringName) -> void:
	await get_tree().create_timer(randf_range(5.0,15.0)).timeout;
	play('SpotlightBlink');
	pass # Replace with function body.


func _on_console_window_toggle_console_visibility(state : bool) -> void:
	if state == false:
		play("ConsoleClose")
		await get_tree().create_timer(1).timeout;
	else:
		play("ConsoleOpen")
		await get_tree().create_timer(1).timeout;
