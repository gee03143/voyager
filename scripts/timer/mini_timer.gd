extends Control

@onready var title_label: Label = $OuterVBox/Header/TitleLabel
@onready var icon_label: Label = $OuterVBox/HBox/Icon
@onready var time_label: Label = $OuterVBox/HBox/VBox/TimeLabel
@onready var status_label: Label = $OuterVBox/HBox/VBox/StatusLabel

func _ready() -> void:
	Clock.pomodoro.running_changed.connect(_refresh_status)
	Clock.pomodoro.segment_changed.connect(func(_i: int): _refresh_status())
	Clock.pomodoro.session_completed.connect(_refresh_status)
	Clock.timer.running_changed.connect(_refresh_status)
	Clock.timer.timer_finished.connect(_refresh_status)
	_refresh_status()

func _process(_delta: float) -> void:
	time_label.text = _format(Clock.active_time_left()) if Clock.is_active() else "00:00"

func _refresh_status() -> void:
	var is_timer := Clock.active_kind() == Clock.Kind.TIMER
	title_label.text = tr("CLOCK_TAB_TIMER") if is_timer else tr("CLOCK_POMO_TITLE")
	icon_label.text = "⏱" if is_timer else "🍅"
	if Clock.is_active():
		status_label.text = tr("CLOCK_POMO_STATUS").format({"type": _type_name()})
	else:
		status_label.text = tr("CLOCK_POMO_IDLE")

func _type_name() -> String:
	match Clock.active_kind():
		Clock.Kind.POMODORO:
			return Pomodoro.type_name(Clock.pomodoro.segment_type_at(Clock.pomodoro.index))
		Clock.Kind.TIMER:
			return tr("CLOCK_POMO_FOCUS")   # 타이머는 별도 문구 없이 '집중'으로 취급(Clock.is_focusing()과 동일 관점)
	return ""

func _format(seconds: float) -> String:
	var s := int(ceil(seconds))
	return "%02d:%02d" % [s / 60, s % 60]
