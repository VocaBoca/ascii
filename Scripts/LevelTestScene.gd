extends Node3D

@onready var terminal : Control = $CanvasLayer/ConsoleWindow

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_QUOTELEFT:
			terminal.visible = !terminal.visible

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
