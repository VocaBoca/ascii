extends SubViewportContainer

@onready var subviewport = $SubViewport

func _input(event):
	subviewport.push_input(event)
