extends Node3D
class_name PointOfInterest

@export var location_id: String = ""
@export var display_name: String = ""

func _ready() -> void:
	call_deferred("_register_to_manager")

func _register_to_manager() -> void:
	var manager = get_tree().get_first_node_in_group("location_manager")
	if manager == null:
		print("PointOfInterest: LocationManager not found for ", name)
		return

	manager.register_point(self)
	print("PointOfInterest registered: ", location_id)
