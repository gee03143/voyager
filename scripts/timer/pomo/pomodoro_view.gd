extends ClockToolView

const SEGMENT_CHIP := preload("res://scenes/timer/PomoSegmentChip.tscn")

@onready var pomodoro: Pomodoro = $Pomodoro
@onready var phase_label: Label = $VBox/PhaseLabel
@onready var timeline: HBoxContainer = $VBox/Timeline
@onready var start_button: Button = $VBox/Buttons/StartButton
@onready var skip_button: Button = $VBox/Buttons/SkipButton
@onready var stop_button: Button = $VBox/Buttons/StopButton
@onready var focus_spin: SpinBox = $VBox/Config/FocusSpin
@onready var short_break_spin: SpinBox = $VBox/Config/ShortBreakSpin
@onready var long_break_spin: SpinBox = $VBox/Config/LongBreakSpin
@onready var count_spin: SpinBox = $VBox/Config/CountSpin

var _chips: Array[PomoSegmentChip] = []

func _ready() -> void:
	pomodoro.ticked.connect(_on_ticked)
	pomodoro.segment_changed.connect(_on_segment_changed)
	pomodoro.focus_finished.connect(_on_focus_finished)
	pomodoro.session_completed.connect(_on_session_completed)
	pomodoro.plan_built.connect(_rebuild_timeline)

	start_button.pressed.connect(_on_start_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	
	focus_spin.value = Save.settings.focus_seconds / 60.0
	short_break_spin.value = Save.settings.short_break_seconds / 60.0
	long_break_spin.value = Save.settings.long_break_seconds / 60.0
	count_spin.value = Save.settings.total_focus_count

	focus_spin.value_changed.connect(_on_config_changed)
	short_break_spin.value_changed.connect(_on_config_changed)
	long_break_spin.value_changed.connect(_on_config_changed)
	count_spin.value_changed.connect(_on_config_changed)
	
	_configure_pomodoro()
	
	_init_clock_tool()
	
func _configure_pomodoro() -> void:
	pomodoro.focus_seconds = focus_spin.value * 60.0
	pomodoro.short_break_seconds = short_break_spin.value * 60.0
	pomodoro.long_break_seconds = long_break_spin.value * 60.0
	pomodoro.total_focus_count = int(count_spin.value)
	pomodoro.build_plan()
	
func _on_config_changed(_v: float) -> void:
	if pomodoro.started:
		return
	_configure_pomodoro()

func _save_settings() -> void:
	Save.settings.focus_seconds = focus_spin.value * 60.0
	Save.settings.short_break_seconds = short_break_spin.value * 60.0
	Save.settings.long_break_seconds = long_break_spin.value * 60.0
	Save.settings.total_focus_count = int(count_spin.value)
	Save.save_game()

func _on_start_pressed() -> void:
	if pomodoro.is_running():
		pomodoro.pause()
	else:
		var fresh := not pomodoro.started
		pomodoro.start()
		if fresh:
			_save_settings()
			_play_alert()
			_try_minimize()
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
	_update_chip_states()
	_refresh_controls()

func _on_ticked(time_left: float) -> void:
	display.render(time_left)
	if pomodoro.index < _chips.size():
		var total := pomodoro.duration_of(pomodoro.segment_type_at(pomodoro.index))
		var ratio := ((total - time_left) / total) if total > 0.0 else 0.0
		_chips[pomodoro.index].set_progress(ratio)

func _on_focus_finished() -> void:
	print("집중 1구간 완료! (나중에 항해 진행)")

func _on_session_completed() -> void:
	phase_label.text = "세션 완료!"
	display.render(0.0)
	_update_chip_states()
	_refresh_controls()
	_play_alert()

func _refresh_controls() -> void:
	start_button.text = "일시정지" if pomodoro.is_running() else "시작"
	start_button.disabled = pomodoro.finished
	skip_button.disabled = pomodoro.finished or not pomodoro.started
	
	var locked := pomodoro.started
	focus_spin.editable = not locked
	short_break_spin.editable = not locked
	long_break_spin.editable = not locked
	count_spin.editable = not locked
	
func _rebuild_timeline() -> void:
	for chip in _chips:
		chip.queue_free()
	_chips.clear()
	for i in pomodoro.segment_count():
		var chip := SEGMENT_CHIP.instantiate() as PomoSegmentChip
		timeline.add_child(chip)          # 먼저 트리에 넣어야 chip 의 @onready 가 준비됨
		chip.setup(pomodoro.segment_type_at(i))
		_chips.append(chip)
	_update_chip_states()
	
func _update_chip_states() -> void:
	for i in _chips.size():
		var state: int
		if pomodoro.finished or i < pomodoro.index:
			state = PomoSegmentChip.State.DONE
		elif i == pomodoro.index:
			state = PomoSegmentChip.State.ACTIVE
		else:
			state = PomoSegmentChip.State.PENDING
		_chips[i].set_state(state)

func _type_name(type: int) -> String:
	match type:
		Pomodoro.SegmentType.FOCUS:
			return "집중"
		Pomodoro.SegmentType.SHORT_BREAK:
			return "짧은 휴식"
		Pomodoro.SegmentType.LONG_BREAK:
			return "긴 휴식"
	return "집중"
	
func _is_active() -> bool:
	return pomodoro.is_running()
