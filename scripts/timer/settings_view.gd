extends VBoxContainer

@onready var auto_minimize_option: OptionButton = $Grid/AutoMinimizeOption
@onready var auto_maximize_option: OptionButton = $Grid/AutoMaximizeOption
@onready var hide_countdown_option: OptionButton = $Grid/HideCountdownOption

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 초기값 = Save (select 는 item_selected 를 안 쏘므로 순서 무관)
	auto_minimize_option.select(1 if Save.settings.auto_minimize else 0)
	auto_minimize_option.item_selected.connect(_on_auto_minimize)
	auto_maximize_option.select(1 if Save.settings.auto_exit_companion else 0)
	auto_maximize_option.item_selected.connect(_on_auto_maximize)
	hide_countdown_option.select(1 if Save.settings.hide_countdown else 0)
	hide_countdown_option.item_selected.connect(_on_hide_countdown)

func _on_auto_minimize(idx: int) -> void:
	Save.settings.auto_minimize = (idx == 1)
	Save.settings.changed.emit()

func _on_auto_maximize(idx: int) -> void:
	Save.settings.auto_exit_companion = (idx == 1)
	Save.settings.changed.emit()

func _on_hide_countdown(idx: int) -> void:
	Save.settings.hide_countdown = (idx == 1)
	Save.settings.changed.emit()        # → 자동 저장 + 뷰 전파
