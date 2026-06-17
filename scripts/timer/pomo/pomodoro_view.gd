extends ClockToolView

const SEGMENT_CHIP := preload("res://scenes/timer/PomoSegmentChip.tscn")
const ICON_PAUSE := preload("res://assets/placeholder/pause.svg")
const ICON_PLAY := preload("res://assets/placeholder/play.svg")

@onready var phase_label: Label = $VBox/PhaseLabel
@onready var timeline: HBoxContainer = $VBox/Timeline
@onready var start_button: Button = $VBox/Buttons/StartButton
@onready var skip_button: Button = $VBox/Buttons/SkipButton
@onready var stop_button: Button = $VBox/Buttons/StopButton
@onready var focus_spin: SpinBox = $VBox/Config/FocusSpin
@onready var short_break_spin: SpinBox = $VBox/Config/ShortBreakSpin
@onready var long_break_spin: SpinBox = $VBox/Config/LongBreakSpin
@onready var count_spin: SpinBox = $VBox/Config/CountSpin

var pomodoro: Pomodoro
var _chips: Array[PomoSegmentChip] = []

func _ready() -> void:
	pomodoro = Clock.pomodoro
	pomodoro.segment_changed.connect(_on_segment_changed)
	pomodoro.running_changed.connect(_refresh_controls)
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
	
	_rebuild_timeline()
	_on_segment_changed(pomodoro.index)
	
	_init_clock_tool()
	
func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var t := pomodoro.time_left()
	display.render(t)
	if pomodoro.index < _chips.size():
		var total := pomodoro.duration_of(pomodoro.segment_type_at(pomodoro.index))
		if total > 0.0:
			_chips[pomodoro.index].set_progress((total - t) / total)
	
func _on_config_changed(_v: float) -> void:
	if pomodoro.started:
		return
	pomodoro.focus_seconds = focus_spin.value * 60.0
	pomodoro.short_break_seconds = short_break_spin.value * 60.0
	pomodoro.long_break_seconds = long_break_spin.value * 60.0
	pomodoro.total_focus_count = int(count_spin.value)
	pomodoro.build_plan()

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
	phase_label.text = "%s  ·  %d / %d 구간" % [Pomodoro.type_name(type), i + 1, pomodoro.segment_count()]
	_update_chip_states()
	_refresh_controls()

func _on_focus_finished() -> void:
	print("집중 1구간 완료! (나중에 항해 진행)")

func _on_session_completed() -> void:
	_play_alert()

func _refresh_controls() -> void:
	start_button.icon = ICON_PAUSE if pomodoro.is_running() else ICON_PLAY
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
	
func _is_active() -> bool:
	return pomodoro.is_running()
