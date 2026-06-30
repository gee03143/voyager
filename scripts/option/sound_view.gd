extends VBoxContainer

@onready var volume_slider: HSlider = $VolumeRow/VolumeSlider
@onready var sound_set_option: OptionButton = $SoundSetRow/SoundSetOption
@onready var preview_button: Button = $SoundSetRow/PreviewButton

func _ready() -> void:
	volume_slider.value = Save.settings.master_volume
	volume_slider.value_changed.connect(_on_volume_changed)   # 라이브 적용
	volume_slider.drag_ended.connect(_on_volume_commit)       # 저장(디바운스 대용)

	sound_set_option.select(Save.settings.sound_set)
	sound_set_option.item_selected.connect(_on_sound_set)
	preview_button.pressed.connect(_on_preview)

func _on_volume_changed(value: float) -> void:
	Save.settings.master_volume = value
	Sound.set_master_volume(value)            # 즉시 들림 (저장은 안 함)

func _on_volume_commit(_value_changed: bool) -> void:
	Save.settings.changed.emit()              # 드래그 끝날 때만 저장

func _on_sound_set(idx: int) -> void:
	Save.settings.sound_set = idx
	Save.settings.changed.emit()

func _on_preview() -> void:
	Sound.play_set(sound_set_option.selected)
