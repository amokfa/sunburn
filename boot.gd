extends Node
## Prepare browser audio buffers before any gameplay or music starts.
const GAME_SCENE := "res://scale_prototype.tscn"
const AUDIO_PATHS := [
	"res://assets/sfx/forest.wav",
	"res://assets/sfx/launch.mp3",
	"res://assets/sfx/rocket_layer.mp3",
	"res://assets/sfx/pickup.mp3",
	"res://assets/sfx/sun.mp3",
	"res://assets/sfx/sun_trigger.mp3",
	"res://assets/sfx/warzone.mp3",
	"res://assets/sfx/explosion1.mp3",
	"res://assets/sfx/explosion2.mp3",
	"res://assets/sfx/you_died.mp3",
	"res://assets/sfx/mus/mus1.mp3",
	"res://assets/sfx/mus/mus2.ogg",
	"res://assets/sfx/mus/mus3.ogg",
	"res://assets/sfx/mus/mus4.mp3",
]
const LOOPING_PATHS := [
	"res://assets/sfx/rocket_layer.mp3",
	"res://assets/sfx/sun.mp3",
	"res://assets/sfx/warzone.mp3",
	"res://assets/sfx/mus/mus2.ogg",
	"res://assets/sfx/mus/mus4.mp3",
]
# Hold the exact resources that the game will reuse through ResourceLoader's cache.
var _audio: Array[AudioStream] = []
@onready var status: Label = $Screen/Status


func _ready() -> void:
	await RenderingServer.frame_post_draw
	var error := ResourceLoader.load_threaded_request(GAME_SCENE, "PackedScene")
	if error != OK:
		status.text = "Unable to load the game. Please reload."
		push_error("Could not start loading the game: %s" % error_string(error))
		return
	while ResourceLoader.load_threaded_get_status(GAME_SCENE) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(GAME_SCENE) != ResourceLoader.THREAD_LOAD_LOADED:
		status.text = "Unable to load the game. Please reload."
		push_error("Could not load the game scene.")
		return
	var game := ResourceLoader.load_threaded_get(GAME_SCENE) as PackedScene
	if OS.has_feature("web"):
		for path: String in AUDIO_PATHS:
			status.text = "Preparing audio · %d / %d" % [_audio.size() + 1, AUDIO_PATHS.size()]
			await RenderingServer.frame_post_draw
			var stream := load(path) as AudioStream
			if stream == null:
				status.text = "Unable to load audio. Please reload."
				push_error("Could not prepare audio: %s" % path)
				return
			_audio.append(stream)
			# Web Audio copies loop settings during registration.
			if path in LOOPING_PATHS:
				if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
					stream.loop = true
			if stream.can_be_sampled() and not AudioServer.is_stream_registered_as_sample(stream):
				AudioServer.register_stream_as_sample(stream)
			# Decode one sound per loading frame, rather than during gameplay.
			await get_tree().process_frame
	status.text = "Ready"
	await RenderingServer.frame_post_draw
	error = get_tree().change_scene_to_packed(game)
	if error != OK:
		status.text = "Unable to start the game. Please reload."
		push_error("Could not start the game: %s" % error_string(error))
