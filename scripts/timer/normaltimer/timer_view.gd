extends Control

@onready var hours_spin: SpinBox = $VBox/TimeInput/HoursSpin
@onready var minutes_spin: SpinBox = $VBox/TimeInput/MinutesSpin
@onready var seconds_spin: SpinBox = $VBox/TimeInput/SecondsSpin
@onready var display: CountdownDisplay = $VBox/Display
@onready var start_button: Button = $VBox/Buttons/StartButton
@onready var reset_button: Button = $VBox/Buttons/ResetButton

var _timer: SimpleTimer

func _ready() -> void:
	_timer = SimpleTimer.new()
	add_child(_timer)
	_timer.ticked.connect(_on_ticked)
	_timer.timer_finished.connect(_on_finished)

	hours_spin.value_changed.connect(_on_time_changed)
	minutes_spin.value_changed.connect(_on_time_changed)
	seconds_spin.value_changed.connect(_on_time_changed)
	start_button.pressed.connect(_on_start_pressed)
	reset_button.pressed.connect(_on_reset_pressed)

	_apply_duration()

func _input_seconds() -> float:
	return hours_spin.value * 3600.0 + minutes_spin.value * 60.0 + seconds_spin.value

func _apply_duration() -> void:
	var secs := _input_seconds()
	display.set_total(secs)
	_timer.configure(secs)
	_refresh_controls()

func _on_time_changed(_v: float) -> void:
	if not _timer.is_running():
		_apply_duration()

func _on_start_pressed() -> void:
	if _timer.is_running():
		_timer.pause()
	else:
		_timer.start()
	_refresh_controls()

func _on_reset_pressed() -> void:
	_timer.reset()
	_refresh_controls()

func _on_ticked(time_left: float) -> void:
	display.render(time_left)

func _on_finished() -> void:
	print("타이머 완료!")
	_refresh_controls()

func _refresh_controls() -> void:
	var running := _timer.is_running()
	start_button.text = "일시정지" if running else "시작"
	start_button.disabled = _timer.finished
	reset_button.disabled = not _timer.started

	hours_spin.editable = not running
	minutes_spin.editable = not running
	seconds_spin.editable = not running
