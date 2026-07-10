class_name PomoSegmentChip
extends PanelContainer

enum State { PENDING, ACTIVE, DONE }

@onready var icon: Label = $VBox/Icon
@onready var bar: ProgressBar = $VBox/Bar

var _type: int = 0

func setup(type: int) -> void:
	_type = type
	bar.show_percentage = false      # "%" 텍스트 숨김
	bar.max_value = 1.0
	bar.value = 0.0
	icon.text = _symbol(type)

func set_state(state: int) -> void:
	match state:
		State.PENDING:
			modulate = Color(1, 1, 1, 0.4)   # 흐리게
			icon.text = _symbol(_type)
			bar.value = 0.0
		State.ACTIVE:
			modulate = Color(1, 1, 1, 1.0)   # 또렷
			icon.text = _symbol(_type)
		State.DONE:
			modulate = Color(1, 1, 1, 1.0)
			icon.text = "✓"
			bar.value = 1.0

func set_progress(ratio: float) -> void:   # 활성 구간 동안만 호출
	bar.value = clamp(ratio, 0.0, 1.0)

func _symbol(type: int) -> String:
	match type:
		Pomodoro.SegmentType.FOCUS:
			return TranslationServer.translate("CLOCK_POMO_FOCUS")
		Pomodoro.SegmentType.SHORT_BREAK:
			return TranslationServer.translate("CLOCK_POMO_SHORT_BREAK")
		Pomodoro.SegmentType.LONG_BREAK:
			return TranslationServer.translate("CLOCK_POMO_LONG_BREAK")
	return ""
