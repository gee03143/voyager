extends Node

const SETS := [
	preload("res://assets/sounds/Piano_Ui_Set1.wav"),
	preload("res://assets/sounds/Piano_Ui_Set2.wav"),
]

# 발화음은 에셋이 아직 없을 수 있어 preload를 못 쓴다(없는 경로는 파싱 단계에서 실패).
# 파일을 넣고 다시 실행하면 그때부터 소리가 난다.
const VOICE_PATHS := [
	"res://assets/sounds/companion_voice.wav",
	"res://assets/sounds/companion_voice.ogg",
]
const VOICE_PITCH_JITTER := 0.06        # 같은 파일을 반복 재생해도 기계적으로 안 들릴 만큼만

var _player: AudioStreamPlayer
var _voice: AudioStreamPlayer           # 발화음 전용 — 완료음과 한 재생기를 쓰면 서로 끊는다

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_voice = AudioStreamPlayer.new()
	_voice.stream = _load_voice()
	add_child(_voice)
	set_master_volume(Save.settings.master_volume)
	set_voice_volume(Save.settings.companion_voice_volume)

func play_set(index: int) -> void:
	if index < 0 or index >= SETS.size():
		return
	_player.stream = SETS[index]
	_player.play()

func play_voice() -> void:
	if _voice.stream == null:
		return                                          # 에셋 없음 — 무음으로 동작
	_voice.pitch_scale = 1.0 + randf_range(-VOICE_PITCH_JITTER, VOICE_PITCH_JITTER)
	_voice.play()

func set_master_volume(linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(0, linear <= 0.0)          # 0 = 음소거(-inf dB 회피)
	if linear > 0.0:
		AudioServer.set_bus_volume_db(0, linear_to_db(linear))

# 마스터는 버스에, 발화음은 재생기에 걸린다 — 둘이 곱해진다.
# 발화음만 0으로 두면 알람과 완료음은 그대로 울린다.
func set_voice_volume(linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	_voice.volume_db = linear_to_db(linear) if linear > 0.0 else -80.0

func _load_voice() -> AudioStream:
	for path in VOICE_PATHS:
		if ResourceLoader.exists(path):
			return load(path)
	return null
