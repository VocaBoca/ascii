extends Node

var points: Dictionary = {}

func _ready() -> void:
	add_to_group("location_manager")
	print("LocationManager ready: ", name)


func register_point(point: PointOfInterest) -> void:
	if point == null:
		return

	var key := point.location_id.strip_edges().to_lower()
	print("Trying register:", point.name, " id=", point.location_id, " normalized=", key)

	if key.is_empty():
		push_warning("PointOfInterest has empty location_id: " + point.name)
		return

	if points.has(key):
		push_warning("Duplicate location_id: " + key)

	points[key] = point
	print("Registered point: ", key)
	print("All registered points: ", points.keys())


func get_point(location_id: String) -> PointOfInterest:
	var key := location_id.strip_edges().to_lower()
	print("Searching for key:", key)
	print("Available keys:", points.keys())
	return points.get(key, null)

func get_all_point_ids() -> Array:
	return points.keys()
