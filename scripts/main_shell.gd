extends HBoxContainer

const TODO_SCENE := preload("res://scenes/todo/TodoListView.tscn")
const HABIT_SCENE := preload("res://scenes/habittracker/HabitTrackerView.tscn")
const TIMER_SCENE := preload("res://scenes/timer/TimerDashboard.tscn")
const RECORD_SCENE := preload("res://scenes/record/RecordDashboard.tscn")
const JOURNAL_SCENE := preload("res://scenes/record/journal/JournalDashboard.tscn")

const NAV_TARGETS := {&"todo": 1, &"habit": 2, &"timer": 3, &"record": 5, &"journal": 4}

const MINI_WIDGET_GROUP := "mini_widget"

# 화면 전체가 바뀌는 가장 큰 변화라 탭 전환보다 길게 잡았다. F6에서 눈으로 조정할 값.
const SWAP_ENTER_SEC := 0.35

@onready var nav_list: VBoxContainer = $Sidebar/Margin/VBox/NavList
@onready var content_area: PanelContainer = $MainColumn/BodyRow/ContentArea

@onready var sidebar: PanelContainer = $Sidebar
@onready var sidebar_vbox: VBoxContainer = $Sidebar/Margin/VBox
@onready var main_column: VBoxContainer = $MainColumn
@onready var mini_timer: PanelContainer = $Sidebar/Margin/VBox/MiniTimer
@onready var mini_toggle_button: Button = $Sidebar/Margin/VBox/MiniTimer/OuterVBox/Header/Togglebutton
@onready var banner: PanelContainer = $MainColumn/Banner

const CONTENT_SCENES := {
	1: TODO_SCENE,
	2: HABIT_SCENE,
	3: TIMER_SCENE,
	4: JOURNAL_SCENE,
	5: RECORD_SCENE,
}

var _nav := ButtonGroupNav.new()
var _content: Node = null
var _swap_wrap: Control          # 들어오는 패널을 담는 자리 — 컨테이너가 위치를 되돌리지 못하게 한 겹 끼운다
var _swap_tween: Tween
var _mini_mode := false
var _mini_dragging := false
var _mini_drag_start_mouse := Vector2i.ZERO
var _mini_drag_start_window := Vector2i.ZERO
var _empty_style := StyleBoxEmpty.new()

func _ready() -> void:
	_init_swap_wrap()
	_nav.setup_from(nav_list, false)
	_nav.selected.connect(_on_nav_selected)
	_nav.select(0)
	_init_mini_widget()
	banner.navigate_requested.connect(_on_banner_navigate)

func _on_banner_navigate(target: StringName) -> void:
	if NAV_TARGETS.has(target):
		_nav.select(NAV_TARGETS[target])   # 눌림 표시 + selected 발신 → 콘텐츠 전환까지 한 번에

func _on_nav_selected(index: int) -> void:
	_kill_swap_tween()
	if _content != null:
		if _content.has_method("on_hidden"):
			_content.on_hidden()
		_content.visible = false
		# keep_global_transform을 끄지 않으면 옮길 때마다 보정 오프셋이 남는다
		_content.reparent(PanelPool, false)        # 퇴장 연출이 없으니 기다리지 않고 곧바로 돌려보낸다
		_content = null
	if CONTENT_SCENES.has(index):
		_content = PanelPool.get_instance(CONTENT_SCENES[index], null)
		PanelEnter.adopt(_swap_wrap, _content as Control)
		_content.visible = true
		if _content.has_method("on_shown"):
			_content.on_shown()
		# 사이드바에서 고르는 화면이라 옆에서 들어온다. 탭은 콘텐츠 안이라 아래에서 올라온다.
		_swap_tween = PanelEnter.play(self, _content as Control, SWAP_ENTER_SEC, PanelEnter.FROM_LEFT)

# 콘텐츠 영역은 PanelContainer라 자식의 위치를 재배치 때마다 되돌린다(docs/architecture/ui-animation.md).
# 패널 안 목록이 다시 그려질 때마다 그 재배치가 일어나므로 래퍼를 한 겹 끼운다.
func _init_swap_wrap() -> void:
	_swap_wrap = PanelEnter.make_wrap()
	content_area.add_child(_swap_wrap)

func _kill_swap_tween() -> void:
	PanelEnter.kill(_swap_tween)
	_swap_tween = null

func _init_mini_widget() -> void:
	mini_timer.add_to_group(MINI_WIDGET_GROUP)
	mini_timer.gui_input.connect(_on_mini_timer_input)
	mini_toggle_button.pressed.connect(_on_mini_toggle_pressed)
	HoverReveal.setup(mini_timer, [mini_toggle_button])
	Clock.pomodoro.session_completed.connect(_on_mini_session_completed)
	Clock.timer.timer_finished.connect(_on_mini_session_completed)
	
func _on_mini_toggle_pressed() -> void:
	if _mini_mode:
		_exit_mini_widget()
	else:
		_enter_mini_widget()

func _on_mini_timer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mini_drag_start_mouse = DisplayServer.mouse_get_position()
			_mini_drag_start_window = DisplayServer.window_get_position()
			_mini_dragging = _mini_mode
		else:
			_mini_dragging = false
	elif event is InputEventMouseMotion and _mini_dragging:
		var delta := DisplayServer.mouse_get_position() - _mini_drag_start_mouse
		DisplayServer.window_set_position(_mini_drag_start_window + delta)

func _set_sidebar_normal_visible(value: bool) -> void:
	for child in sidebar_vbox.get_children():
		if not child.is_in_group(MINI_WIDGET_GROUP):
			child.visible = value

func _enter_mini_widget() -> void:
	_mini_mode = true
	_set_sidebar_normal_visible(false)
	main_column.visible = false
	mini_toggle_button.text = "↩"
	sidebar_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_stylebox_override("panel", _empty_style)
	Screen.enter_companion()

func _exit_mini_widget() -> void:
	_mini_mode = false
	Screen.exit_companion()
	sidebar.size_flags_horizontal = Control.SIZE_FILL
	sidebar_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	sidebar.remove_theme_stylebox_override("panel")
	mini_toggle_button.text = "⇲"
	main_column.visible = true
	_set_sidebar_normal_visible(true)

func _on_mini_session_completed() -> void:
	if _mini_mode and Save.settings.auto_exit_companion:
		_exit_mini_widget()
