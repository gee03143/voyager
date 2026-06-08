extends Control

@onready var pomodoro: Pomodoro = $Pomodoro
@onready var phase_label: Label = $VBox/PhaseLabel
@onready var display: CountdownDisplay = $VBox/Display
@onready var start_button: Button = $VBox/Buttons/StartButton
@onready var skip_button: Button = $VBox/Buttons/SkipButton
@onready var stop_button: Button = $VBox/Buttons/StopButton

func _ready() -> void:
	pomodoro.ticked.connect(_on_ticked)
	pomodoro.segment_changed.connect(_on_segment_changed)
	pomodoro.focus_finished.connect(_on_focus_finished)
	pomodoro.session_completed.connect(_on_session_completed)

	start_button.pressed.connect(_on_start_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	
	if pomodoro.segment_count() > 0:
		_on_segment_changed(pomodoro.index)

func _on_start_pressed() -> void:
	if pomodoro.is_running():
		pomodoro.pause()
	else:
		pomodoro.start()
	_refresh_controls()

func _on_skip_pressed() -> void:
	pomodoro.skip()

func _on_stop_pressed() -> void:
	pomodoro.reset()
	_refresh_controls()

func _on_segment_changed(i: int) -> void:
	var type := pomodoro.segment_type_at(i)
	display.set_total(pomodoro.duration_of(type))
	phase_label.text = "%s  ·  %d / %d 구간" % [_type_name(type), i + 1, pomodoro.segment_count()]
	_refresh_controls()

func _on_ticked(time_left: float) -> void:
	display.render(time_left)

func _on_focus_finished() -> void:
	print("집중 1구간 완료! (나중에 항해 진행)")

func _on_session_completed() -> void:
	phase_label.text = "세션 완료!"
	display.render(0.0)
	_refresh_controls()

func _refresh_controls() -> void:
	start_button.text = "일시정지" if pomodoro.is_running() else "시작"
	start_button.disabled = pomodoro.finished
	skip_button.disabled = pomodoro.finished or not pomodoro.started

func _type_name(type: int) -> String:
	match type:
		Pomodoro.SegmentType.FOCUS:
			return "집중"
		Pomodoro.SegmentType.SHORT_BREAK:
			return "짧은 휴식"
		Pomodoro.SegmentType.LONG_BREAK:
			return "긴 휴식"
	return "집중"
