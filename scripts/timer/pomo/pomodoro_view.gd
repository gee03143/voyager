extends ClockToolView

const SEGMENT_CHIP := preload("res://scenes/timer/PomoSegmentChip.tscn")
const ICON_PAUSE := preload("res://assets/placeholder/pause.svg")
const ICON_PLAY := preload("res://assets/placeholder/play.svg")
const WINDOW_SIZE := 4     # 타임라인에 한 번에 보여줄 칩 개수(현재+다음+다다음+나머지)

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
var _active_chip: PomoSegmentChip = null

func _ready() -> void:
	pomodoro = Clock.pomodoro
	pomodoro.segment_changed.connect(_on_segment_changed)
	pomodoro.running_changed.connect(_refresh_controls)
	pomodoro.focus_finished.connect(_on_focus_finished)

	start_button.pressed.connect(_on_start_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	
	focus_spin.value = Save.settings.focus_seconds / 60.0
	short_break_spin.value = Save.settings.short_break_seconds / 60.0
	long_break_spin.value = Save.settings.long_break_seconds / 60.0
	count_spin.value = Save.settings.total_focus_count
	
	focus_spin.suffix = tr("SUFFIX_MIN")
	short_break_spin.suffix = tr("SUFFIX_MIN")
	long_break_spin.suffix = tr("SUFFIX_MIN")
	count_spin.suffix = tr("SUFFIX_CNT")

	focus_spin.value_changed.connect(_on_config_changed)
	short_break_spin.value_changed.connect(_on_config_changed)
	long_break_spin.value_changed.connect(_on_config_changed)
	count_spin.value_changed.connect(_on_config_changed)
	
	_on_segment_changed(pomodoro.index)
	
	_init_clock_tool()
	
func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	var t := pomodoro.time_left()
	display.render(t)
	if _active_chip != null:
		var total := pomodoro.duration_of(pomodoro.segment_type_at(pomodoro.index))
		if total > 0.0:
			_active_chip.set_progress((total - t) / total)
	
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
	_refresh_controls()

func _on_skip_pressed() -> void:
	pomodoro.skip()

func _on_stop_pressed() -> void:
	pomodoro.reset()
	_refresh_controls()

func _on_segment_changed(i: int) -> void:
	var type := pomodoro.segment_type_at(i)
	display.set_total(pomodoro.duration_of(type))
	phase_label.text = TranslationServer.translate("CLOCK_POMO_PHASE_LABEL").format({
		"type": Pomodoro.type_name(type),
		"current": i + 1,
		"total": pomodoro.segment_count(),
	})
	_build_window()
	_refresh_controls()

func _on_focus_finished() -> void:
	print("집중 1구간 완료! (나중에 항해 진행)")

func _refresh_controls() -> void:
	start_button.icon = ICON_PAUSE if pomodoro.is_running() else ICON_PLAY
	start_button.disabled = pomodoro.finished
	skip_button.disabled = pomodoro.finished or not pomodoro.started
	
	var locked := pomodoro.started
	focus_spin.editable = not locked
	short_break_spin.editable = not locked
	long_break_spin.editable = not locked
	count_spin.editable = not locked
	
# 현재 위치 기준 윈도우(최대 4칩)를 다시 그림.
# - 여유 있을 때: 현재+다음+다다음+"+N"(나머지 개수)
# - 꼬리 구간(끝까지 4개 이하로 남으면): 마지막 4개를 고정 표시, active만 이동
func _build_window() -> void:
	for chip in _chips:
		chip.queue_free()
	_chips.clear()
	_active_chip = null

	var total := pomodoro.segment_count()
	var idx := pomodoro.index
	var indices: Array[int] = []
	var count_after := 0

	if total <= WINDOW_SIZE or idx >= total - WINDOW_SIZE:
		var start: int = max(0, total - WINDOW_SIZE)
		for i in range(start, total):
			indices.append(i)
	else:
		indices = [idx, idx + 1, idx + 2]
		count_after = total - (idx + 3)

	for i in indices:
		var chip := SEGMENT_CHIP.instantiate() as PomoSegmentChip
		timeline.add_child(chip)          # 먼저 트리에 넣어야 chip 의 @onready 가 준비됨
		chip.setup(pomodoro.segment_type_at(i))
		var state: int
		if i < idx:
			state = PomoSegmentChip.State.DONE
		elif i == idx:
			state = PomoSegmentChip.State.ACTIVE
			_active_chip = chip
		else:
			state = PomoSegmentChip.State.PENDING
		chip.set_state(state)
		_chips.append(chip)

	if count_after > 0:
		var count_chip := SEGMENT_CHIP.instantiate() as PomoSegmentChip
		timeline.add_child(count_chip)
		count_chip.setup_count(count_after)
		_chips.append(count_chip)
	
func _is_active() -> bool:
	return pomodoro.is_running()
