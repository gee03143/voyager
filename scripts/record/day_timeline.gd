extends VBoxContainer

const SESSION_TYPES := {"pomodoro_session": true, "timer": true}

const ROW_H := 18.0        # 점 이벤트 한 줄 높이
const ROW_GAP := 2.0       # 밀어낼 때 줄 사이 최소 간격
const LABEL_H := 24.0      # 블록 라벨 한 줄 높이 — 블록 최소 높이 겸 점 회피 구간
const INSET := 22.0        # 블록 안에 들어간 점의 들여쓰기
const RIGHT_PAD := 8.0

const ACCENT := {
	"pomodoro_session": Color("c0392b"),
	"timer": Color("2e86de"),
	"todo": Color("d9b38c"),
	"habit": Color("27ae60"),
	"journal": Color("9575cd"),
	"gratitude": Color("f6b93b"),
	"mood": Color("38ada9"),
}

const MOOD_LEVEL_KEYS := ["MOOD_LEVEL_1", "MOOD_LEVEL_2", "MOOD_LEVEL_3", "MOOD_LEVEL_4", "MOOD_LEVEL_5"]

const BLOCK_SCENE := preload("res://scenes/record/TimelineBlock.tscn")
const POINT_ROW_SCENE := preload("res://scenes/record/TimelinePointRow.tscn")
const HABIT_CHIP_SCENE := preload("res://scenes/record/TimelineHabitChip.tscn")

@onready var day_label: Label = $Header/DayLabel
@onready var play_label: Label = $Header/PlayLabel
@onready var habit_band: HFlowContainer = $HabitBand
@onready var empty_label: Label = $EmptyLabel
@onready var scroll: ScrollContainer = $Scroll
@onready var track: TimelineTrack = $Scroll/Track

var _day: String = ""

func render_day(date_iso: String) -> void:
	_day = date_iso
	day_label.text = DateUtil.format_day(date_iso)
	play_label.text = "⏳ %s" % _fmt_hms(int(Save.activity_log.play_days.get(date_iso, 0.0)))
	for c in habit_band.get_children():
		c.queue_free()
	for c in track.get_children():
		c.queue_free()

	var blocks := []
	var points := []
	for e in Save.activity_entries_for(date_iso):
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

	_scroll_to_first(blocks, points)

# 세션이면 {start_min, end_min, approx, start_ts, clip_start, clip_end}, 점 이벤트면 빈 딕셔너리
func _span_of(e: Dictionary) -> Dictionary:
	if not SESSION_TYPES.has(str(e.get("type", ""))):
		return {}
	var end_ts := int(e.get("ts", 0))
	var start_ts := 0
	var approx := false
	if e.has("start_ts"):
		start_ts = int(e["start_ts"])
	else:
		var secs := int(e.get("seconds", 0))     # 구버전 기록 — 계획치로 역산한 근사
		if secs <= 0:
			return {}
		start_ts = end_ts - secs
		approx = true
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
	var start_ts := int(b["start_ts"])
	var end_ts := int(e.get("ts", 0))
	var start_text := DateUtil.format_time_hm(start_ts)
	var end_text := DateUtil.format_time_hm(end_ts)
	var range_text := ""
	if bool(b["clip_start"]):                     # 시작이 다른 날 — 그쪽에 날짜를 붙임
		range_text = TranslationServer.translate("RECORD_SPAN_CROSSDAY").format({
			"day": DateUtil.format_day(DateUtil.local_day_iso(start_ts)),
			"start": start_text, "end": end_text})
	elif bool(b["clip_end"]):                     # 끝이 다른 날
		range_text = TranslationServer.translate("RECORD_SPAN_CROSSDAY_END").format({
			"day": DateUtil.format_day(DateUtil.local_day_iso(end_ts)),
			"start": start_text, "end": end_text})
	else:
		range_text = "%s–%s" % [start_text, end_text]
	var block := BLOCK_SCENE.instantiate() as TimelineBlock
	track.add_child(block)                        # setup 전에 트리에 넣어야 @onready가 채워짐
	block.setup("%s · %s" % [_format_event(e), ("≈ " + range_text) if approx else range_text],
		ACCENT.get(str(e.get("type", "")), Color.GRAY), approx,
		bool(b["clip_start"]), bool(b["clip_end"]))
	_stretch(block, TimelineTrack.GUTTER,
		b["start_min"] * TimelineTrack.MIN_PX,
		maxf((b["end_min"] - b["start_min"]) * TimelineTrack.MIN_PX, LABEL_H))

func _add_point(e: Dictionary, y: float, inset: bool) -> void:
	var row := POINT_ROW_SCENE.instantiate() as TimelinePointRow
	track.add_child(row)
	row.setup(DateUtil.format_time_hm(int(e.get("ts", 0))),
		ACCENT.get(str(e.get("type", "")), Color.GRAY), _format_event(e))
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
	match str(e.get("type", "")):
		"todo":
			return TranslationServer.translate("RECORD_EVENT_TODO").format({"title": str(e.get("title", ""))})
		"timer":
			return TranslationServer.translate("RECORD_EVENT_TIMER").format({"subj": _subj(e), "time": _fmt_ms(int(e.get("seconds", 0)))})
		"pomodoro_session":
			var cnt := int(e.get("focus_count", 0))
			var each := (int(e.get("seconds", 0)) / cnt) if cnt > 0 else 0
			return TranslationServer.translate("RECORD_EVENT_POMO").format({"subj": _subj(e), "count": cnt, "time": _fmt_ms(each)})
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

func _subj(e: Dictionary) -> String:
	var key := str(e.get("subject", ""))
	return "%s · " % ActivityVocab.ko(key) if key != "" else ""

func _fmt_ms(secs: int) -> String:
	return "%d:%02d" % [secs / 60, secs % 60]

func _fmt_hms(total: int) -> String:
	return "%02d:%02d:%02d" % [total / 3600, (total % 3600) / 60, total % 60]
