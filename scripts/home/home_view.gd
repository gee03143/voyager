extends VBoxContainer

## 홈 패널(docs/specs/day-verdict.md 의 "계기 — 홈").
## 하루에 이름을 붙일 수 있으면 그 상태와 헤이즐을 부르는 버튼을, 아니면 마지막으로 붙인 이름을 보인다.
## 문구는 헤이즐의 목소리가 아니라 중립 UI 언어다(docs/companion-persona.md §5 "목소리의 경계").
## 판정은 여기서 받지 않는다. 헤이즐을 불러 대화에서 받는다.
##
## 아래 카드는 최근 판정 도장과 판정한 날 수다. 날짜가 아니라 판정 단위라 빈칸이 생기지 않는다.
## 선으로 잇지 않는다 — 오르내림이 생기면 자기 판정이 점수가 된다. 해금까지 남은 수는 보이지 않는다.

signal verdict_requested         # MainShell 이 받아 시메지 루트로 넘긴다

const DAY_VERDICT := preload("res://scripts/data/day_verdict.gd")   # class_name 이 전역 목록에 오르기 전에도 잡히게
const STAMP_SCRIPT := preload("res://scripts/home/verdict_stamp.gd")
const RECHECK_SEC := 60.0        # 보는 동안 판정 간격이 지나면 버튼이 돌아오게 가끔 다시 본다
const RECENT := 7
## 도장에 찍는 글자. 언어마다 고르게 번역 키로 둔다. custom 은 연필을 그린다
const STAMP_KEYS := {"held": "VERDICT_STAMP_HELD", "endured": "VERDICT_STAMP_ENDURED", "drifted": "VERDICT_STAMP_DRIFTED"}

@onready var caption: Label = %Caption
@onready var name_label: Label = %NameLabel
@onready var date_label: Label = %DateLabel
@onready var call_button: Button = %CallButton

var _recheck: Timer
var _trend_card: PanelContainer
var _stamps: HBoxContainer
var _total: Label

func _ready() -> void:
	call_button.pressed.connect(verdict_requested.emit)
	Save.verdict.changed.connect(_refresh)
	_recheck = Timer.new()
	_recheck.wait_time = RECHECK_SEC
	add_child(_recheck)
	_recheck.timeout.connect(_refresh)
	_build_trend()
	_refresh()


## 씬을 고치지 않고 코드로 만든다. 판정 카드 아래에 붙는다
func _build_trend() -> void:
	_trend_card = PanelContainer.new()
	_trend_card.theme_type_variation = &"VgCard"
	add_child(_trend_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_trend_card.add_child(box)
	var cap := Label.new()
	cap.theme_type_variation = &"VgMutedLabel"
	cap.text = tr("HOME_VERDICT_RECENT")
	box.add_child(cap)
	_stamps = HBoxContainer.new()
	_stamps.add_theme_constant_override("separation", 12)
	box.add_child(_stamps)
	_total = Label.new()
	box.add_child(_total)

func on_shown() -> void:
	_refresh()
	_recheck.start()

func on_hidden() -> void:
	_recheck.stop()

func _refresh() -> void:
	_refresh_trend()
	var v := Save.verdict
	if v.can_judge(DateUtil.now_unix()):
		caption.text = tr("HOME_VERDICT_OPEN")
		name_label.visible = false
		date_label.visible = false
		call_button.visible = true
		return
	var e := v.latest()
	caption.text = tr("HOME_VERDICT_LAST")
	name_label.text = DAY_VERDICT.name_of(e)
	name_label.visible = true
	date_label.text = DateUtil.format_day(DateUtil.local_day_iso(int(e["ts"])))
	date_label.visible = true
	call_button.visible = false


func _refresh_trend() -> void:
	var v := Save.verdict
	_trend_card.visible = v.count() > 0
	for c in _stamps.get_children():
		_stamps.remove_child(c)                  # 같은 프레임에 트리에서 빼고 지운다(docs/architecture/list-rebuild.md)
		c.queue_free()
	var from := maxi(0, v.entries.size() - RECENT)
	for i in range(from, v.entries.size()):     # 왼쪽이 오래된 것, 오른쪽이 최근이다
		_stamps.add_child(_stamp_cell(v.entries[i]))
	_total.text = tr("HOME_VERDICT_TOTAL").format({"n": v.count()})


## 도장 하나와 그 아래 날짜
func _stamp_cell(e: Dictionary) -> Control:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)
	var day := _short_day(int(e["ts"]))
	var stamp: Control = STAMP_SCRIPT.new()
	var key: String = STAMP_KEYS.get(str(e["kind"]), "")
	stamp.setup(tr(key) if key != "" else "", "%s · %s" % [DAY_VERDICT.name_of(e), day], int(e["id"]))
	cell.add_child(stamp)
	var d := Label.new()
	d.theme_type_variation = &"VgMutedLabel"
	d.add_theme_font_size_override("font_size", 12)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.text = day
	cell.add_child(d)
	return cell


## "월/일". 도장 아래는 좁아서 오늘·어제를 쓰지 않고 늘 같은 꼴로 둔다
func _short_day(ts: int) -> String:
	var p := DateUtil.local_day_iso(ts).split("-")
	return "%d/%d" % [int(p[1]), int(p[2])]
