class_name JournalDocRow
extends PanelContainer

signal selected(id: int)
signal delete_requested(id: int)

@onready var hbox: HBoxContainer = $HBox
@onready var body: VBoxContainer = $HBox/Body
@onready var title_label: Label = $HBox/Body/TitleLabel
@onready var date_label: Label = $HBox/Body/DateLabel
@onready var delete_button: HoldButton = $HBox/DeleteButton

# 읽고 있는 문서는 세로로 두꺼워지고 잉크 워시가 같은 시간에 올라온다.
# 채움(쓸어 들어오기)은 안 쓴다 — nav는 뒤이어 콘텐츠가 들어오니 상태를 대표하지만
# 문서 행은 대표할 것이 없다(docs/specs/ui-animation.md 일지 문서 목록).
const SEL_SEC := 0.14          # 탭 선택 채움과 같은 급. 행 하나짜리 변화라 짧다. F6에서 맞출 값
const GROW_PX := 4.0           # 위아래 각각. 카드가 8px 두꺼워진다
# 잉크 8%를 행의 크림 배경 위에 얹은 색. 배경을 반투명 잉크로 갈아끼우면
# 카드의 크림이 사라져 구멍처럼 보인다.
const SEL_BG := Color(0.87905902, 0.85254902, 0.79984314, 1.0)

var _id: int = 0
var _style: StyleBoxFlat       # 테마 것을 복제해 이 행만 쓴다. 공용 스타일박스를 고치면 안 된다
var _base_bg: Color
var _base_margin := 0.0
var _selected := false
var _sel_t := 0.0              # 0 = 평소, 1 = 선택됨
var _sel_tween: Tween

# 자리가 열리고 닫히는 시간. 할 일 행(0.12/0.08/0.12)에서 출발하되 이 행은 두 줄이라 조금 길다.
# 거두는 쪽은 짧다 — 나가는 것보다 들어오는 것에 시간을 쓴다. F6에서 맞출 값.
const ENTER_SEC := 0.14    # 자리가 열리는 시간
const FADE_SEC := 0.09     # 내용이 스며드는 시간. 자리보다 짧아 열린 뒤에 채워진다
const EXIT_SEC := 0.12

var _flow_tween: Tween
var _empty_style := StyleBoxEmpty.new()

func _ready() -> void:
	body.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			selected.emit(_id))
	delete_button.held.connect(func(): delete_requested.emit(_id))
	HoverReveal.setup(self, [delete_button])
	# STOP이면 이 행 위에서 휠이 소비되어 목록 스크롤이 안 먹는다.
	# PASS도 gui_input은 그대로 받고, 쓰지 않은 이벤트만 부모로 넘긴다.
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	_adopt_style()

# 선택 스타일을 새로 만들면 테마가 갖고 있던 여백과 배경을 잃는다. 복제해서 쓴다.
func _adopt_style() -> void:
	var base := get_theme_stylebox("panel") as StyleBoxFlat
	if base == null:
		return
	_style = base.duplicate()
	_base_bg = _style.bg_color
	_base_margin = _style.content_margin_top
	add_theme_stylebox_override("panel", _style)
	_apply_sel(1.0 if _selected else 0.0)

func setup(doc: Dictionary, is_selected: bool) -> void:
	_id = int(doc.get("id", 0))
	var t := str(doc.get("title", "")).strip_edges()
	title_label.text = t if t != "" else "(제목 없음)"
	date_label.text = "생성됨 %s" % DateUtil.format_created(int(doc.get("ts", 0)))
	_set_selected(is_selected)

# 목록은 여러 이유로 다시 그려진다. 상태가 그대로면 아무것도 재생하지 않는다.
func _set_selected(on: bool) -> void:
	if on == _selected:
		return
	_selected = on
	if _style == null:
		return
	_kill_sel()
	var target := 1.0 if on else 0.0
	if not is_visible_in_tree():       # 화면에 아직 없으면 연출을 걸어도 보이지 않고 소진된다
		_apply_sel(target)
		return
	# 거두는 쪽도 같은 시간에 간다. 얇아지는 일이 아래 행 전부를 움직이기 때문이다.
	_sel_tween = create_tween()
	_sel_tween.tween_method(_apply_sel, _sel_t, target, SEL_SEC)

# 두께와 색을 한 값에서 뽑는다. 둘이 한 번의 움직임으로 읽혀야 한다.
func _apply_sel(t: float) -> void:
	_sel_t = t
	_style.bg_color = _base_bg.lerp(SEL_BG, t)
	_style.content_margin_top = _base_margin + GROW_PX * t
	_style.content_margin_bottom = _base_margin + GROW_PX * t
	update_minimum_size()      # 스타일박스 여백이 곧 최소 크기다. 컨테이너가 다시 재도록 직접 알린다
	queue_redraw()

# 높이가 열리며 내용이 스며든다. 아래 행들은 컨테이너 배치를 타고 따라 내려간다.
func play_enter(sec: float = ENTER_SEC) -> void:
	_kill_flow()
	var full := get_combined_minimum_size().y
	modulate.a = 0.0
	_collapse_shell()
	custom_minimum_size.y = 0.0
	_flow_tween = create_tween()
	_flow_tween.tween_property(self, "custom_minimum_size:y", full, sec) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_flow_tween.tween_callback(_restore_shell)
	_flow_tween.tween_property(self, "modulate:a", 1.0, FADE_SEC)

func play_exit(on_done: Callable, sec: float = EXIT_SEC) -> void:
	_kill_flow()
	var full := size.y
	_flow_tween = create_tween()
	_flow_tween.tween_property(self, "modulate:a", 0.0, FADE_SEC)
	_flow_tween.tween_callback(_collapse_shell)
	_flow_tween.tween_property(self, "custom_minimum_size:y", 0.0, sec).from(full) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_flow_tween.tween_callback(on_done)

# 내용을 숨기면 PanelContainer가 그만큼 높이를 놓는다. 배경도 같이 비워야 껍데기가 안 남는다.
func _collapse_shell() -> void:
	hbox.visible = false
	add_theme_stylebox_override("panel", _empty_style)

func _restore_shell() -> void:
	if _style != null:
		add_theme_stylebox_override("panel", _style)   # 선택 표시용 복제본으로 되돌린다
	else:
		remove_theme_stylebox_override("panel")
	hbox.visible = true
	custom_minimum_size.y = 0.0    # 고정해두면 나중에 제목이 길어져도 높이가 안 따라간다

func _kill_flow() -> void:
	if _flow_tween != null and _flow_tween.is_valid():
		_flow_tween.kill()
	_flow_tween = null

func _kill_sel() -> void:
	if _sel_tween != null and _sel_tween.is_valid():
		_sel_tween.kill()
	_sel_tween = null
