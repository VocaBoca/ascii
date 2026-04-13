extends AudioStreamPlayer

var keysounds: Array[AudioStream] = []
var babysound: AudioStream

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	keysounds = [
		preload("res://Audio/Keyboard/click1.wav"),
		preload("res://Audio/Keyboard/click2.wav")
	]
	babysound = preload("res://Audio/Other/baby.wav")
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_console_window_console_key_pressed() -> void:
	stream = keysounds.pick_random()
	play()
	pass # Replace with function body.


func _on_console_window_screamer_baby_spawn() -> void:
	stream = babysound
	play()
	pass # Replace with function body.
