extends ClockToolView

const ICON_PAUSE := preload("res://assets/placeholder/pause.svg")
const ICON_PLAY := preload("res://assets/placeholder/play.svg")

@onready var hours_spin: SpinBox = $VBox/TimeInput/HoursSpin
@onready var minutes_spin: SpinBox = $VBox/TimeInput/MinutesSpin
@onready var seconds_spin: SpinBox = $VBox/TimeInput/SecondsSpin
@onready var start_button: Button = $VBox/Buttons/StartButton
@onready var reset_button: Button = $VBox/Buttons/ResetButton

var _timer: SimpleTimer

func _ready() -> void:
	_timer = Clock.timer
	_timer.running_changed.connect(_refresh_controls)
	
	start_button.pressed.connect(_on_start_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	
	var total := int(Save.settings.timer_seconds)
	hours_spin.value = total / 3600
	minutes_spin.value = (total % 3600) / 60
	seconds_spin.value = total % 60
	
	hours_spin.value_changed.connect(_on_time_changed)
	minutes_spin.value_changed.connect(_on_time_changed)
	seconds_spin.value_changed.connect(_on_time_changed)

	display.set_total(_timer.duration)
	_refresh_controls()

	_init_clock_tool()
	
func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	display.render(_timer.time_left())

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
		var was_started := _timer.started
		_timer.start()
		if not was_started and _timer.started:
			_save_settings()
			_play_alert()
			_try_minimize()
	_refresh_controls()

func _save_settings() -> void:
	Save.settings.timer_seconds = _input_seconds()
	Save.save_game()

func _on_reset_pressed() -> void:
	_timer.reset()
	_refresh_controls()

func _refresh_controls() -> void:
	var running := _timer.is_running()
	var is_standby := not _timer.started
	start_button.icon = ICON_PAUSE if running else ICON_PLAY
	start_button.disabled = _timer.finished
	reset_button.disabled = is_standby

	hours_spin.editable = is_standby
	minutes_spin.editable = is_standby
	seconds_spin.editable = is_standby

func _is_active() -> bool:
	return _timer.is_running()
