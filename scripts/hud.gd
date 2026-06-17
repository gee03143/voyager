extends PanelContainer

const ICON_PAUSE := preload("res://assets/placeholder/pause.svg")
const ICON_PLAY := preload("res://assets/placeholder/play.svg")

@onready var _ring: RadialProgress = $Margin/VBox/RingBox/Ring
@onready var _time_label: Label = $Margin/VBox/RingBox/TimeLabel
@onready var _caption: Label = $Margin/VBox/CaptionRow/Caption
@onready var _timeline: SegmentTimeline = $Margin/VBox/Timeline
@onready var _pause_button: Button = $Margin/VBox/Buttons/PauseButton
@onready var _skip_button: Button = $Margin/VBox/Buttons/SkipButton
@onready var _reset_button: Button = $Margin/VBox/Buttons/ResetButton

func _ready() -> void:
	_pause_button.pressed.connect(Clock.active_toggle)
	_skip_button.pressed.connect(Clock.active_skip)
	_reset_button.pressed.connect(Clock.active_reset)
	
	Clock.pomodoro.running_changed.connect(_refresh)
	Clock.pomodoro.segment_changed.connect(func(_i: int): _refresh())
	Clock.pomodoro.session_completed.connect(_refresh)
	Clock.timer.running_changed.connect(_refresh)
	Clock.timer.timer_finished.connect(_refresh)
	_refresh()

func _process(_delta: float) -> void:
	if not Clock.is_active():
		visible = false
		return
	visible = true
	var total := Clock.active_total()
	_ring.value = (Clock.active_time_left() / total) if total > 0.0 else 0.0
	_time_label.text = _format(Clock.active_time_left())

func _refresh() -> void:
	visible = Clock.is_active()
	if not visible:
		return
	_pause_button.icon = ICON_PLAY if Clock.active_paused() else ICON_PAUSE
	_skip_button.visible = Clock.active_kind() == Clock.Kind.POMODORO
	_caption.text = _caption_text()
	_update_timeline()
	
func _update_timeline() -> void:
	if Clock.active_kind() == Clock.Kind.POMODORO:
		var p: Pomodoro = Clock.pomodoro
		_timeline.visible = true
		_timeline.render(p.segment_types, p.index, p.finished)
	else:
		_timeline.visible = false

func _format(seconds: float) -> String:
	var s := int(ceil(seconds))
	return "%02d:%02d" % [s / 60, s % 60]

func _caption_text() -> String:
	match Clock.active_kind():
		Clock.Kind.POMODORO:
			return _pomo_caption()
		Clock.Kind.TIMER:
			return "타이머"
	return ""

func _pomo_caption() -> String:
	var p: Pomodoro = Clock.pomodoro
	var type := p.segment_type_at(p.index)
	if type == Pomodoro.SegmentType.FOCUS:
		return "%s %d / %d" % [Pomodoro.type_name(type), _focus_number(p), p.total_focus_count]
	return Pomodoro.type_name(type)        # 휴식 단계면 단계명

func _focus_number(p: Pomodoro) -> int:
	var n := 0
	for i in range(p.index + 1):
		if p.segment_type_at(i) == Pomodoro.SegmentType.FOCUS:
			n += 1
	return n
