extends VBoxContainer

const SESSION_TYPES := {"pomodoro_session": true, "timer": true}

const NOTE_MARK := "✎ "    # 노트 있음 표시
const ROW_H := 18.0        # 점 이벤트 한 줄 높이
const ROW_GAP := 2.0       # 밀어낼 때 줄 사이 최소 간격
const LABEL_H := 24.0      # 블록 라벨 한 줄 높이 — 블록 최소 높이 겸 점 회피 구간
const INSET := 22.0        # 블록 안에 들어간 점의 들여쓰기
const RIGHT_PAD := 8.0

const MOOD_LEVEL_KEYS := ["MOOD_LEVEL_1", "MOOD_LEVEL_2", "MOOD_LEVEL_3", "MOOD_LEVEL_4", "MOOD_LEVEL_5"]

const BLOCK_SCENE := preload("res://scenes/record/Timeline/TimelineBlock.tscn")
const POINT_ROW_SCENE := preload("res://scenes/record/Timeline/TimelinePointRow.tscn")
const HABIT_CHIP_SCENE := preload("res://scenes/record/Timeline/TimelineHabitChip.tscn")

@onready var day_label: Label = $Header/DayLabel
@onready var play_label: Label = $Header/PlayLabel
@onready var habit_band: HFlowContainer = $HabitBand
@onready var empty_label: Label = $EmptyLabel
@onready var scroll: ScrollContainer = $Scroll
@onready var track: TimelineTrack = $Scroll/Track

signal entry_selected(event_id: int, meta: String, title: String)
signal rendered

var _selected_id: int = 0
var _entries: Dictionary = {}      # event_id → {node, meta, title}
var _day: String = ""

func render_day(date_iso: String) -> void:
	var keep_scroll := (_day == date_iso)      # 같은 날 재빌드 → 보던 위치 유지
	var prev_scroll := scroll.scroll_vertical
	_day = date_iso
	_entries.clear()
	var day_entries := Save.activity_entries_for(date_iso)
	day_label.text = DateUtil.format_day(date_iso)
	play_label.text = "⏳ %s · %s" % [
		_fmt_hms(int(Save.activity_log.play_days.get(date_iso, 0.0))),
		TranslationServer.translate("RECORD_DAY_COUNT").format({"n": day_entries.size()})]
	for c in habit_band.get_children():
		c.queue_free()
	for c in track.get_children():
		c.queue_free()

	var blocks := []
	var points := []
	for e in day_entries:
		if str(e.get("type", "")) == "habit":
			_add_habit_chip(str(e.get("title", "")))
			continue
		var span := _span_of(e)
		if span.is_empty():
			points.append({"min": DateUtil.local_minutes(int(e.get("ts", 0))), "e": e})
		else:
			span["e"] = e
			blocks.append(span)

	empty_label.text = TranslationServer.translate("RECORD_EMPTY")
	empty_label.visible = blocks.is_empty() and points.is_empty() and habit_band.get_child_count() == 0
	var reserved := []
	for b in blocks:
		_add_block(b)
		var top: float = b["start_min"] * TimelineTrack.MIN_PX
		reserved.append({"y0": top, "y1": top + LABEL_H})
	reserved.sort_custom(func(a, c): return float(a["y0"]) < float(c["y0"]))

	var last_bottom := -1000.0
	for p in points:
		var minute: float = p["min"]
		var y: float = maxf(minute * TimelineTrack.MIN_PX - ROW_H * 0.5, last_bottom + ROW_GAP)
		for r in reserved:
			if y < float(r["y1"]) and y + ROW_H > float(r["y0"]):
				y = float(r["y1"])
		last_bottom = y + ROW_H
		_add_point(p["e"], y, _inside_block(minute, blocks))

	_apply_selection()
	if keep_scroll:
		scroll.scroll_vertical = prev_scroll
	else:
		_scroll_to_first(blocks, points)
	rendered.emit()

# 세션이면 {start_min, end_min, approx, start_ts, clip_start, clip_end}, 점 이벤트면 빈 딕셔너리
func _span_of(e: Dictionary) -> Dictionary:
	if not SESSION_TYPES.has(str(e.get("type", ""))):
		return {}
	var end_ts := int(e.get("ts", 0))
	var start_ts := ActivityFormat.start_ts_of(e)
	if start_ts == 0:                        # 역산 불가한 구버전 — 블록으로 못 그림
		return {}
	var approx := ActivityFormat.is_approx(e)
	var clip_start := DateUtil.local_day_iso(start_ts) != _day    # 시작이 전날 → 축 상단으로
	var clip_end := DateUtil.local_day_iso(end_ts) != _day        # 끝이 다음날 → 축 하단까지
	var start_min := 0.0 if clip_start else DateUtil.local_minutes(start_ts)
	var end_min := 1440.0 if clip_end else DateUtil.local_minutes(end_ts)
	if end_min <= start_min:
		end_min = start_min + 1.0
	return {"start_min": start_min, "end_min": end_min, "approx": approx,
		"start_ts": start_ts, "clip_start": clip_start, "clip_end": clip_end}

func _add_block(b: Dictionary) -> void:
	var e: Dictionary = b["e"]
	var approx: bool = b["approx"]
	var range_text := ActivityFormat.span_text(int(b["start_ts"]), int(e.get("ts", 0)), _day)
	var accent := ActivityFormat.accent_of(str(e.get("type", "")))
	var block := BLOCK_SCENE.instantiate() as TimelineBlock
	track.add_child(block)                        # setup 전에 트리에 넣어야 @onready가 채워짐
	var eid := int(e.get("id", 0))
	var mark := NOTE_MARK if Save.activity_log.note_of(eid) != "" else ""
	var label := _format_event(e)
	block.setup("%s%s · %s" % [mark, label, ("≈ " + range_text) if approx else range_text],
		accent, approx, bool(b["clip_start"]), bool(b["clip_end"]), eid)
	_register(eid, block, range_text, label, accent, int(e.get("ts", 0)))
	_stretch(block, TimelineTrack.GUTTER,
		b["start_min"] * TimelineTrack.MIN_PX,
		maxf((b["end_min"] - b["start_min"]) * TimelineTrack.MIN_PX, LABEL_H))

func _add_point(e: Dictionary, y: float, inset: bool) -> void:
	var row := POINT_ROW_SCENE.instantiate() as TimelinePointRow
	track.add_child(row)
	var eid := int(e.get("id", 0))
	var time_text := DateUtil.format_time_hm(int(e.get("ts", 0)))
	var mark := NOTE_MARK if Save.activity_log.note_of(eid) != "" else ""
	var accent := ActivityFormat.accent_of(str(e.get("type", "")))
	var label := _format_event(e)
	row.setup(time_text, accent, mark + label, eid)
	_register(eid, row, time_text, label, accent, int(e.get("ts", 0)))
	_stretch(row, TimelineTrack.GUTTER + (INSET if inset else 0.0), y, ROW_H)

func _add_habit_chip(title: String) -> void:
	var chip := HABIT_CHIP_SCENE.instantiate() as TimelineHabitChip
	habit_band.add_child(chip)
	chip.setup(title)

# 폭은 앵커로 트랙에 묶고(빌드 시점 size가 0이어도 안전), 세로만 절대 배치
func _stretch(c: Control, left: float, top: float, height: float) -> void:
	c.anchor_right = 1.0
	c.offset_left = left
	c.offset_right = -RIGHT_PAD
	c.offset_top = top
	c.offset_bottom = top + height

func _inside_block(minute: float, blocks: Array) -> bool:
	for b in blocks:
		if minute >= float(b["start_min"]) and minute <= float(b["end_min"]):
			return true
	return false

func _scroll_to_first(blocks: Array, points: Array) -> void:
	var first := 1440.0
	for b in blocks:
		first = minf(first, float(b["start_min"]))
	for p in points:
		first = minf(first, float(p["min"]))
	if first >= 1440.0:
		first = 8.0 * 60.0                        # 활동 없는 날은 08:00 근처로
	var y := floorf(first / 60.0) * TimelineTrack.HOUR_PX
	await get_tree().process_frame                # 트랙 크기가 잡힌 뒤라야 값이 안 잘림
	scroll.scroll_vertical = int(y)

func _format_event(e: Dictionary) -> String:
	var type := str(e.get("type", ""))
	if SESSION_TYPES.has(type):
		return ActivityFormat.session_label(e)
	match type:
		"todo":
			return TranslationServer.translate("RECORD_EVENT_TODO").format({"title": str(e.get("title", ""))})
		"journal":
			var t := Save.journal.doc_title(int(e.get("doc_id", 0)))
			return TranslationServer.translate("RECORD_EVENT_JOURNAL").format({"title": t if t != "" else TranslationServer.translate("RECORD_JOURNAL_DELETED")})
		"gratitude":
			return TranslationServer.translate("RECORD_EVENT_GRATITUDE")
		"mood":
			var m := Save.mood.entry_by_id(int(e.get("entry_id", 0)))
			if m.is_empty():
				return TranslationServer.translate("RECORD_MOOD_DELETED")
			var lvl := clampi(int(m.get("level", 3)), 1, 5)
			var label := TranslationServer.translate("RECORD_EVENT_MOOD").format({"level": TranslationServer.translate(MOOD_LEVEL_KEYS[lvl - 1])})
			var memo := str(m.get("memo", "")).strip_edges()
			if memo != "":
				label += " · %s" % memo
			return label
	return ""

func _fmt_hms(total: int) -> String:
	return "%02d:%02d:%02d" % [total / 3600, (total % 3600) / 60, total % 60]
	
func _register(event_id: int, node: Control, meta: String, title: String, accent: Color, ts: int) -> void:
	if event_id == 0:                       # 습관 파생 이벤트는 id가 없음 — 노트 대상 아님
		return
	_entries[event_id] = {"node": node, "meta": meta, "title": title, "accent": accent, "ts": ts}
	node.selected.connect(_on_child_selected)

func _on_child_selected(event_id: int) -> void:
	_selected_id = event_id
	_apply_selection()
	var d: Dictionary = _entries[event_id]
	entry_selected.emit(event_id, str(d["meta"]), str(d["title"]))

func _apply_selection() -> void:
	for id in _entries:
		_entries[id]["node"].set_selected(int(id) == _selected_id)

func clear_selection() -> void:
	_selected_id = 0
	_apply_selection()
	
func entries_with_notes() -> Array:
	var out := []
	for id in _entries:
		var note := Save.activity_log.note_of(int(id))
		if note == "":
			continue
		var d: Dictionary = _entries[id]
		out.append({"id": int(id), "meta": d["meta"], "title": d["title"],
			"note": note, "accent": d["accent"], "ts": int(d["ts"])})
	out.sort_custom(func(a, b): return int(a["ts"]) < int(b["ts"]))   # _entries는 블록→점 순이라 시각순 아님
	return out

func select_entry(event_id: int) -> void:
	if not _entries.has(event_id):
		return
	_selected_id = event_id
	_apply_selection()                      # 시그널 재발신 없음 — 스트림에서 부르는 경로라 되돌아올 필요 없음
