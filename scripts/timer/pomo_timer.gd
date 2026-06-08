extends Control

signal session_finished

@export var focus_seconds: float = 20.0*60.0

@onready var clock: Timer = $Clock
@onready var time_label: Label = $VBox/TimeLabel
@onready var progress: ProgressBar = $VBox/Progress
@onready var start_button: Button = $VBox/Buttons/StartButton
@onready var reset_button: Button = $VBox/Buttons/ResetButton

func _ready() -> void:
	clock.one_shot = true
	clock.wait_time = focus_seconds
	progress.max_value = focus_seconds
	
	start_button.pressed.connect(_on_start_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	clock.timeout.connect(_on_clock_timeout)


func _process(_delta: float) -> void:
	if not clock.is_stopped():
		_update_display(clock.time_left)

func _on_start_pressed() -> void:
	clock.start()
	start_button.disabled = true

func _on_reset_pressed() -> void:
	clock.stop()
	start_button.disabled = false
	_update_display(focus_seconds)
	
func _on_clock_timeout() -> void:
	start_button.disabled = false
	_update_display(0.0)
	session_finished.emit()
	print("세션 완료!")
	
func _update_display(seconds: float) -> void:
	var total := int(ceil(seconds))
	time_label.text = "%02d:%02d" % [total / 60, total % 60]
	progress.value = focus_seconds - seconds
