class_name HoldButton
extends Button

signal held                          # 홀드 완료(게이지 가득)

@export var hold_time: float = 0.6   # 채우는 데 걸리는 시간(초)

@onready var gauge: ProgressBar = $Gauge

var _holding := false
var _start_ms := 0

func _ready() -> void:
	gauge.min_value = 0.0
	gauge.max_value = 1.0
	gauge.value = 0.0
	gauge.visible = false
	gauge.show_percentage = false
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	set_process(false)

func _on_down() -> void:
	_holding = true
	_start_ms = Time.get_ticks_msec()      # 클럭 기반 측정(틱은 게이지 표시만)
	gauge.value = 0.0
	gauge.visible = true
	set_process(true)

func _on_up() -> void:
	_reset()                               # 다 차기 전 떼면 취소

func _process(_delta: float) -> void:
	if not _holding:
		return
	var ratio := float(Time.get_ticks_msec() - _start_ms) / maxf(hold_time, 0.01) / 1000.0
	gauge.value = clampf(ratio, 0.0, 1.0)
	if ratio >= 1.0:
		_reset()
		held.emit()

func _reset() -> void:
	_holding = false
	set_process(false)
	gauge.visible = false
	gauge.value = 0.0
