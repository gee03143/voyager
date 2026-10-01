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

## 효과음(docs/architecture/sound.md). id → [파일 이름들, 음량 dB]. 파일은 SFX_DIR 의 .ogg 다.
## 임시 소리다 — Kenney CC0 팩에서 골랐고 이름은 원본 그대로다. 파일마다 크기가 달라 음량을 id 단위로 맞춘다
const SFX_DIR := "res://assets/sounds/sfx/"
const SFX := {
	&"knock": [["impactWood_light_000", "impactWood_light_001", "impactWood_light_002"], 0.0],
	&"step": [["footstep_carpet_000", "footstep_carpet_001", "footstep_carpet_002"], -6.0],
	&"cloth": [["cloth1", "cloth2"], 2.0],
	&"latch": [["metalLatch"], -4.0],
	&"lid": [["dropLeather"], -6.0],
	&"book_take": [["bookPlace2"], -6.0],
	&"book_open": [["bookOpen", "bookFlip3"], 6.0],
	&"page": [["bookFlip1"], 4.0],
	&"sharpen": [["scratch_004", "scratch_005"], -8.0],
	&"write": [["scratch_001", "scratch_002", "scratch_003"], -10.0],
	&"pluck": [["pluck_001", "pluck_002"], -4.0],
	&"land": [["impactSoft_medium_000"], -10.0],
	&"drag": [["trunk_drag"], 2.0],
	&"drag_short": [["trunk_drag_short"], 2.0],
}
const SFX_PITCH_JITTER := 0.05
const SFX_VOICES := 6                   # 겹쳐 울려도 앞 소리를 끊지 않을 만큼
const SFX_FADE_SEC := 0.15

var _player: AudioStreamPlayer
var _voice: AudioStreamPlayer           # 발화음 전용 — 완료음과 한 재생기를 쓰면 서로 끊는다
var _sfx_streams := {}                  # id → Array[AudioStream]. 있는 파일만 담긴다
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _sfx_serial := 0                    # 재생마다 다는 표식 — 잦아드는 중에 재생기가 다시 쓰였는지 본다

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_voice = AudioStreamPlayer.new()
	_voice.stream = _load_voice()
	add_child(_voice)
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_pool.append(p)
	_load_sfx()
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

## 효과음 하나를 울리고 울린 재생기를 돌려준다. 파일이 없으면 null — 무음으로 동작한다
func play_sfx(id: StringName) -> AudioStreamPlayer:
	var streams: Array = _sfx_streams.get(id, [])
	if streams.is_empty():
		return null
	var p := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	_sfx_serial += 1
	p.set_meta(&"serial", _sfx_serial)
	p.stream = streams[randi() % streams.size()]
	p.volume_db = float(SFX[id][1])
	p.pitch_scale = 1.0 + randf_range(-SFX_PITCH_JITTER, SFX_PITCH_JITTER)
	p.play()
	return p

## 이어지는 소리를 짧게 잦아들게 하며 멈춘다. 그 사이 재생기가 다른 소리에 다시 쓰였으면 건드리지 않는다
func stop_sfx(p: AudioStreamPlayer) -> void:
	if p == null or not p.playing:
		return
	var serial: int = p.get_meta(&"serial", 0)
	var mine := func() -> bool: return p.get_meta(&"serial", 0) == serial
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		if mine.call():
			p.volume_db = v, p.volume_db, p.volume_db - 30.0, SFX_FADE_SEC)
	tw.tween_callback(func() -> void:
		if mine.call():
			p.stop())

## 같은 소리를 gap 초 간격으로 count 번 울린다. 기다리지 않고 바로 돌아온다
func play_sfx_repeat(id: StringName, count: int, gap: float) -> void:
	for i in count:
		if i == 0:
			play_sfx(id)
		else:
			get_tree().create_timer(gap * i).timeout.connect(play_sfx.bind(id))

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

func _load_sfx() -> void:
	for id in SFX:
		var streams: Array = []
		for name in SFX[id][0]:
			var path := SFX_DIR + str(name) + ".ogg"
			if ResourceLoader.exists(path):
				streams.append(load(path))
		_sfx_streams[id] = streams
