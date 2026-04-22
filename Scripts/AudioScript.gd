extends Node

const POOL_SIZE := 12

@export var key_volume_db: float = -12.0
@export var baby_volume_db: float = -4.0
@export var audio_bus: String = "Master"

var keysounds: Array[AudioStream] = []
var babysound: AudioStream
var players: Array[AudioStreamPlayer] = []
var _next_player_idx := 0


func _ready() -> void:
	keysounds = [
		preload("res://Audio/Keyboard/click1.wav"),
		preload("res://Audio/Keyboard/click2.wav"),
	]
	babysound = preload("res://Audio/Other/baby.wav")

	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = audio_bus
		p.volume_db = key_volume_db
		add_child(p)
		players.append(p)


func _play_sound(sound: AudioStream, pitch: float = 1.0, volume: float = 0.0) -> void:
	var player := players[_next_player_idx]
	_next_player_idx = (_next_player_idx + 1) % players.size()

	player.stop()
	player.stream = sound
	player.pitch_scale = pitch
	player.volume_db = volume
	player.play()


func _on_console_window_console_key_pressed() -> void:
	_play_sound(
		keysounds.pick_random(),
		randf_range(0.65, 0.75),
		key_volume_db
	)


func _on_console_window_screamer_baby_spawn() -> void:
	_play_sound(
		babysound,
		0.4,
		baby_volume_db
	)
