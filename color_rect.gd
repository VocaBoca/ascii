extends ColorRect

@export var viewport: SubViewport

func _ready() -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		print("NO MATERIAL")
		return

	if viewport == null:
		print("NO VIEWPORT")
		return

	print("Viewport size: ", viewport.size)
	print("Viewport texture: ", viewport.get_texture())

	mat.set_shader_parameter("source_tex", viewport.get_texture())
