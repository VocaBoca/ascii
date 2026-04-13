extends Node

@export var terminal_path: NodePath
@export var player_path: NodePath
@export var location_manager_path: NodePath

var terminal: Node
var player: CharacterBody3D
var location_manager: Node

func _ready() -> void:
	terminal = get_node_or_null(terminal_path)
	player = get_node_or_null(player_path) as CharacterBody3D
	location_manager = get_node_or_null(location_manager_path)

	if terminal == null:
		push_error("Terminal not found")
		return

	if player == null:
		push_error("Player not found")
		return

	if location_manager == null:
		push_error("LocationManager not found")
		return

	terminal.MoveToPointRequested.connect(_on_move_to_point_requested)


func _on_move_to_point_requested(point_name: String) -> void:
	var target = location_manager.get_point(point_name)

	if target == null:
		terminal.print_error("Location not found: " + point_name)
		return

	player.move_to_target(target)
	terminal.print_output("Moving to: " + target.display_name)
