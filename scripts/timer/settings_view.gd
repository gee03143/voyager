extends VBoxContainer

@onready var auto_minimize_option: OptionButton = $Grid/AutoMinimizeOption
@onready var hide_countdown_option: OptionButton = $Grid/HideCountdownOption
@onready var sound_set_option: OptionButton = $Grid/SoundRow/SoundSetOption
@onready var preview_button: Button = $Grid/SoundRow/PreviewButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 초기값 = Save (select 는 item_selected 를 안 쏘므로 순서 무관)
	auto_minimize_option.select(1 if Save.settings.auto_minimize else 0)
	hide_countdown_option.select(1 if Save.settings.hide_countdown else 0)

	auto_minimize_option.item_selected.connect(_on_auto_minimize)
	hide_countdown_option.item_selected.connect(_on_hide_countdown)
	
	sound_set_option.select(Save.settings.sound_set)
	sound_set_option.item_selected.connect(_on_sound_set)
	preview_button.pressed.connect(_on_preview)

func _on_auto_minimize(idx: int) -> void:
	Save.settings.auto_minimize = (idx == 1)
	Save.settings.changed.emit()        # → 자동 저장 (TODO: 실제 효과 구현 Week7)

func _on_hide_countdown(idx: int) -> void:
	Save.settings.hide_countdown = (idx == 1)
	Save.settings.changed.emit()        # → 자동 저장 + 뷰 전파
	
func _on_sound_set(idx: int) -> void:
	Save.settings.sound_set = idx
	Save.settings.changed.emit()        # 저장

func _on_preview() -> void:
	Sound.play_set(sound_set_option.selected)   # 현재 선택 미리듣기
