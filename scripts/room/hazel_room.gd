extends Control

## 헤이즐의 방(docs/specs/hazel-room.md). 셸 상단에서 들여다보이는 방 한 칸을 그린다.
##
## 헤이즐의 몸이 바탕화면 시메지에 있는 동안 방에는 헤이즐이 없다. 내보내면 방 안에 들어와 산다 —
## 그 몸은 이 노드가 그리지 않고 배너가 붙이는 room_hazel.gd 가 맡는다(docs/specs/settings.md).
## 그리는 것은 헤이즐이 모은 날들이다 — 온 날마다 수첩 한 권, 계절이 바뀌면 묶여 트렁크 위로.
##
## 기록은 읽기만 한다. 만난 날은 ActivityLog.play_days 의 날짜 키로 센다. 새 데이터를 만들지 않는다.
## 방·가구·수첩은 도형 임시 소품이다(docs/architecture/companion-rig.md 의 임시 파츠 원칙).
##
## 두 곳에 놓인다. 셸 상단(배너)에서는 들여다보는 크기 그대로, 대화 모드에서는 창을 채우도록 확대해 배경이 된다(fill).

const SHELF_ROWS := 3
const SHELF_PILES := 4               # 한 칸에 놓이는 더미 수
const PILE_MAX := 8                  # 한 더미의 권 수
const SHELF_SLOTS := 92              # 한 계절의 최대 일수. 매일 와도 넘치지 않는다
const BUNDLE_CAP := 8                # 트렁크 위에 보이는 묶음 상한(2년치). 넘으면 트렁크 안으로
const REFRESH_SEC := 60.0            # 자정 넘김과 오늘의 수첩을 잡는 주기
const LAYOUT_W := 500.0              # 창문부터 트렁크까지의 가로 폭. fill 이면 이 폭이 창 폭에 맞게 확대된다
const TRUNK_SCRIPT := preload("res://scripts/onboarding/trunk.gd")
const TRUNK_SCALE := 0.56            # 헤이즐의 트렁크(trunk.gd)를 방 크기로 줄인 배율
const TRUNK_X := 416.0               # 트렁크 왼쪽 끝. 방 좌표
const GROUP := &"hazel_room"          # 개발자 콘솔이 날짜·미리보기를 바꾸면 이 그룹에 refresh 를 부른다

## 개발자 콘솔의 미리보기(docs/specs/dev-console.md). 0 이상이면 기록 대신 이 값으로 그린다. 저장하지 않는다
static var preview_shelf := -1
static var preview_bundles := -1

const C_LINE := Color("#2A2320")
const C_WOOD := Color("#8A5A3C")
const C_WOOD_DARK := Color("#5E4430")
const C_FLOOR := Color("#C9A57C")
const C_PAPER := Color("#FFFDF4")
const C_COVERS := [Color("#3C4A5C"), Color("#46566A"), Color("#5E4430"), Color("#6B4426"), Color("#3F5A4A")]

## 계절 — [하늘, 벽]. 순서는 봄·여름·가을·겨울
const SEASON_COLORS := [
	[Color("#D8E8EE"), Color("#ECE0CC")],
	[Color("#BFDCEA"), Color("#EADFC6")],
	[Color("#E2D8C8"), Color("#E8DCC6")],
	[Color("#E6ECEF"), Color("#E4DCCF")],
]

var _season := 0                     # 0 봄 1 여름 2 가을 3 겨울
var _shelf_count := 0                # 이번 계절의 지난 날들
var _bundles := 0                    # 트렁크 위에 보이는 묶음
var _lamp := false
var _t := 0.0

## 대화 모드의 배경. 창 폭에 맞춰 방 전체를 확대한다
var fill := false :
	set(v):
		fill = v
		queue_redraw()
## 바닥선 높이. 방 높이 비율. 대화 모드는 헤이즐이 서는 바닥에 맞춘다
var floor_ratio := 0.82 :
	set(v):
		floor_ratio = v
		queue_redraw()
## 헤이즐이 오기 전의 방에는 트렁크가 없다. 트렁크는 헤이즐이 끌고 와 놓는다(온보딩 5비트)
var show_trunk := true :
	set(v):
		show_trunk = v
		queue_redraw()
## 헤이즐이 오기 전의 방에는 수첩이 없다. 책장·책상·트렁크 위 묶음 전부
var show_notebooks := true :
	set(v):
		show_notebooks = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # 클릭은 배너가 받는다(쪽지 스킵·헤이즐 부르기)
	add_to_group(GROUP)
	var timer := Timer.new()
	timer.wait_time = REFRESH_SEC
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(refresh)
	Clock.pomodoro.running_changed.connect(_update_lamp)   # 인자 없는 시그널이다
	Clock.timer.running_changed.connect(_update_lamp)
	resized.connect(queue_redraw)
	refresh()


func _process(delta: float) -> void:
	if _lamp:
		_t += delta
		queue_redraw()               # 램프 불빛이 아주 조금 흔들린다


## 기록을 다시 읽는다. 날이 바뀌거나 계절이 넘어간 것도 여기서 잡힌다
func refresh() -> void:
	var today := DateUtil.today_iso()
	var start := season_start(today)
	_season = season_of(today)
	var days: Array = Save.activity_log.play_days.keys()
	var shelf := 0
	var past_seasons := {}
	for d in days:
		var iso := str(d)
		if iso >= today:
			continue                 # 오늘 것은 책상 위에 펼쳐져 있다
		if iso >= start:
			shelf += 1
		else:
			past_seasons[season_start(iso)] = true   # 지난 계절 하나 = 묶음 하나. 한 번도 안 온 계절은 묶음이 없다
	if preview_shelf >= 0:
		shelf = preview_shelf
	var bundles := past_seasons.size() if preview_bundles < 0 else preview_bundles
	_shelf_count = mini(shelf, SHELF_SLOTS)
	_bundles = mini(bundles, BUNDLE_CAP)
	_update_lamp()
	queue_redraw()


## 세션이 실제로 돌 때만 켠다. Clock.is_active() 는 일시정지된 세션도 참이라 쓰지 않는다
func _update_lamp() -> void:
	_lamp = Clock.pomodoro.is_running() or Clock.timer.is_running()
	queue_redraw()


## 계절은 달로 나눈다. 3~5월 봄, 6~8월 여름, 9~11월 가을, 12~2월 겨울(북반구)
static func season_of(iso: String) -> int:
	var m := int(iso.substr(5, 2))
	if m >= 3 and m <= 5:
		return 0
	if m >= 6 and m <= 8:
		return 1
	if m >= 9 and m <= 11:
		return 2
	return 3


## 그 날이 속한 계절의 첫날. 겨울은 해를 넘기므로 1~2월이면 전년 12월 1일이다
static func season_start(iso: String) -> String:
	var y := int(iso.substr(0, 4))
	var m := int(iso.substr(5, 2))
	match season_of(iso):
		0:
			return "%04d-03-01" % y
		1:
			return "%04d-06-01" % y
		2:
			return "%04d-09-01" % y
		_:
			return "%04d-12-01" % (y if m == 12 else y - 1)


## 방 좌표를 화면 좌표로 바꾸는 배율
func _zoom() -> float:
	return size.x / LAYOUT_W if fill else 1.0


## 방 좌표의 x 를 이 노드 기준 화면 좌표로. 방 안의 헤이즐을 대화 모드의 방에 같은 자리로 세울 때 쓴다
func to_screen_x(room_x: float) -> float:
	return room_x * _zoom()


func to_room_x(screen_x: float) -> float:
	return screen_x / _zoom()


## 트렁크 가운데의 x. 이 노드 기준 화면 좌표다. 온보딩이 헤이즐의 트렁크를 이 자리에 놓는다
func trunk_center_x() -> float:
	return (TRUNK_X + TRUNK_SCRIPT.W * TRUNK_SCALE * 0.5) * _zoom()


# ── 그리기 ──
# 왼쪽부터 창문 · 책장 · 책상(오늘의 수첩) · 램프 · 트렁크. 배너에서는 오른쪽을 쪽지가 차지한다
# 방 좌표로 그리고 _zoom() 배율을 통째로 건다

func _draw() -> void:
	var k := _zoom()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	var h := size.y / k
	var w := size.x / k
	var fy := h * floor_ratio                           # 바닥선
	var sky: Color = SEASON_COLORS[_season][0]
	var wall: Color = SEASON_COLORS[_season][1]
	draw_rect(Rect2(0, 0, w, fy), wall)
	draw_rect(Rect2(0, fy, w, h - fy), C_FLOOR)
	_draw_window(Rect2(20, h * 0.12, 74, h * 0.5), sky)
	_draw_shelf(Rect2(112, h * 0.08, 4 * 34 + 10, fy - h * 0.08))
	var desk_x := 112 + 4 * 34 + 10 + 22
	_draw_desk(desk_x, fy)
	_draw_lamp(desk_x + 100, fy)
	if show_trunk:
		_draw_trunk(TRUNK_X, fy)
	draw_set_transform(Vector2.ZERO)


func _draw_window(r: Rect2, sky: Color) -> void:
	draw_rect(r, sky)
	match _season:
		0:                                              # 봄 — 꽃잎
			for p in [Vector2(0.2, 0.25), Vector2(0.45, 0.6), Vector2(0.8, 0.3), Vector2(0.65, 0.75)]:
				draw_circle(r.position + r.size * p, 3.5, Color("#F2B8C6"))
			draw_rect(Rect2(r.position.x, r.end.y - 8, r.size.x, 8), Color("#A9C98A"))
		1:                                              # 여름 — 볕과 나무
			draw_circle(r.position + r.size * Vector2(0.78, 0.25), 8, Color("#F4D36B"))
			draw_rect(Rect2(r.position.x, r.end.y - 14, r.size.x, 14), Color("#6E9B54"))
			draw_circle(r.position + r.size * Vector2(0.25, 0.78), 9, Color("#5C8A45"))
		2:                                              # 가을 — 낙엽
			draw_rect(Rect2(r.position.x, r.end.y - 7, r.size.x, 7), Color("#C9965A"))
			for q in [[Vector2(0.2, 0.3), Color("#D08A3C")], [Vector2(0.65, 0.5), Color("#C0563F")], [Vector2(0.8, 0.2), Color("#D9A040")]]:
				draw_circle(r.position + r.size * q[0], 3.5, q[1])
		_:                                              # 겨울 — 눈
			draw_rect(Rect2(r.position.x, r.end.y - 10, r.size.x, 10), Color("#FAFAFA"))
			for p in [Vector2(0.15, 0.2), Vector2(0.4, 0.45), Vector2(0.7, 0.25), Vector2(0.85, 0.6), Vector2(0.3, 0.7)]:
				draw_circle(r.position + r.size * p, 2.0, Color.WHITE)
	draw_rect(r, C_WOOD, false, 4.0)
	draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), C_WOOD, 3.0)


## 책장. 이번 계절의 지난 날들이 수첩 한 권씩 눕혀 쌓인다. 빈 칸은 그리지 않는다
func _draw_shelf(r: Rect2) -> void:
	draw_rect(r, Color("#D8C8AC"))
	draw_rect(r, C_WOOD, false, 3.0)
	var row_h := r.size.y / SHELF_ROWS
	for i in range(1, SHELF_ROWS):
		var y := r.position.y + row_h * i
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), C_WOOD, 3.0)
	if not show_notebooks:
		return
	var per_row := SHELF_PILES * PILE_MAX
	for i in _shelf_count:
		var row := i / per_row
		var in_row := i % per_row
		var pile := in_row / PILE_MAX
		var k := in_row % PILE_MAX
		var base_y := r.position.y + row_h * (row + 1) - 3.0
		var x := r.position.x + 6 + pile * 34
		var y := base_y - 3.0 - k * 3.0
		draw_rect(Rect2(x, y, 28, 3), C_COVERS[(i * 7) % C_COVERS.size()])
		draw_rect(Rect2(x, y, 28, 3), C_LINE, false, 0.5)


## 책상과 오늘의 수첩. 오늘 온 것만으로 펼쳐져 있다
func _draw_desk(x: float, fy: float) -> void:
	draw_rect(Rect2(x, fy - 34, 80, 5), C_WOOD)
	draw_rect(Rect2(x + 5, fy - 29, 4, 29), C_WOOD)
	draw_rect(Rect2(x + 71, fy - 29, 4, 29), C_WOOD)
	if not show_notebooks:
		return                                          # 헤이즐이 오기 전에는 펼쳐진 수첩이 없다
	var bx := x + 18
	var by := fy - 42
	draw_rect(Rect2(bx, by, 21, 7), C_PAPER)
	draw_rect(Rect2(bx + 22, by, 21, 7), C_PAPER)
	draw_rect(Rect2(bx, by, 43, 7), Color("#B59C72"), false, 0.8)
	draw_line(Vector2(bx + 21.5, by), Vector2(bx + 21.5, by + 7), Color("#B59C72"), 0.8)
	draw_line(Vector2(bx + 30, by - 6), Vector2(bx + 38, by + 2), Color("#E2B34A"), 2.0)   # 연필


## 램프. 집중 세션이 도는 동안 불이 들어온다
func _draw_lamp(x: float, fy: float) -> void:
	if _lamp:
		var flick := 1.0 + sin(_t * 3.1) * 0.03
		draw_circle(Vector2(x, fy - 52), 52 * flick, Color(1.0, 0.78, 0.40, 0.22))
		draw_circle(Vector2(x, fy - 52), 30 * flick, Color(1.0, 0.82, 0.45, 0.30))
	draw_rect(Rect2(x - 2, fy - 50, 4, 50), C_WOOD_DARK)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 12, fy - 50), Vector2(x + 12, fy - 50), Vector2(x + 7, fy - 62), Vector2(x - 7, fy - 62)]),
		Color("#F2DCA8") if _lamp else Color("#D9C19A"))


## 트렁크와 지난 계절의 묶음. 헤이즐이 끌고 온 그 트렁크다(trunk.gd 의 모양을 줄여 그린다).
## 상한을 넘은 묶음은 트렁크 안에 들어가 보이지 않는다
func _draw_trunk(x: float, fy: float) -> void:
	var k := _zoom()
	var tw := TRUNK_SCRIPT.W * TRUNK_SCALE
	var top := fy - TRUNK_SCRIPT.H * TRUNK_SCALE
	draw_set_transform(Vector2(x + tw * 0.5, fy) * k, 0.0, Vector2.ONE * k * TRUNK_SCALE)
	TRUNK_SCRIPT.draw_body(self)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	if not show_notebooks:
		return
	for i in _bundles:
		var bx := x + 2 + (i % 4) * 16
		var by := top - 9 - (i / 4) * 9
		draw_rect(Rect2(bx, by, 14, 8), C_COVERS[i % C_COVERS.size()])
		draw_rect(Rect2(bx, by, 14, 8), C_LINE, false, 0.6)
		draw_line(Vector2(bx + 7, by), Vector2(bx + 7, by + 8), Color("#C9A06A"), 1.2)   # 끈
