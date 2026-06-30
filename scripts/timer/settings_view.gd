extends VBoxContainer

@onready var auto_minimize_option: OptionButton = $Grid/AutoMinimizeOption
@onready var hide_countdown_option: OptionButton = $Grid/HideCountdownOption

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 초기값 = Save (select 는 item_selected 를 안 쏘므로 순서 무관)
	auto_minimize_option.select(1 if Save.settings.auto_minimize else 0)
	hide_countdown_option.select(1 if Save.settings.hide_countdown else 0)

func _on_auto_minimize(idx: int) -> void:
	Save.settings.auto_minimize = (idx == 1)
	Save.settings.changed.emit()        # → 자동 저장 (TODO: 실제 효과 구현 Week7)

func _on_hide_countdown(idx: int) -> void:
	Save.settings.hide_countdown = (idx == 1)
	Save.settings.changed.emit()        # → 자동 저장 + 뷰 전파
