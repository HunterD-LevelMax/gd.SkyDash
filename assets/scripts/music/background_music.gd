extends AudioStreamPlayer

@onready var background_player = $"."

var music_tracks: Array[String] = [
	"res://assets/audio/background/euphoric_drive.ogg",
	"res://assets/audio/background/pixel_dreams.ogg",
	"res://assets/audio/background/pixel_love.ogg",
	"res://assets/audio/background/retro_adventure.ogg",
	"res://assets/audio/background/trance_subuplifting.ogg"
]

var is_fading: bool = false
const FADE_TIME: float = 1.0
const TARGET_VOLUME: float = -10.0
const MIN_VOLUME: float = -80.0

func _ready() -> void:
	randomize()
	volume_db = MIN_VOLUME
	finished.connect(_on_track_finished)  
	play_random_music()

func play_random_music() -> void:
	if music_tracks.is_empty():
		push_warning("No music tracks available!")
		return
	
	var random_track_path := music_tracks[randi() % music_tracks.size()]
	var audio_stream := load(random_track_path) as AudioStream
	
	if audio_stream:
		stream = audio_stream  
		create_tween().tween_property(self, "volume_db", TARGET_VOLUME, FADE_TIME)
		play()

func _on_track_finished() -> void:
	if is_fading: 
		return
	is_fading = true
	var tween = create_tween()
	tween.tween_property(self, "volume_db", MIN_VOLUME, FADE_TIME)
	tween.tween_callback(_play_next_track)

func _play_next_track() -> void:
	play_random_music()
	is_fading = false
