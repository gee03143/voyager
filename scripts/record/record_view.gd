extends VBoxContainer

@onready var day_label: Label = $Header/DayLabel
@onready var play_label: Label = $Header/PlayLabel
@onready var list: VBoxContainer = $ScrollContainer/List

const ACCENT := {
	"pomodoro_session": Color("c0392b"),   # 빨강
	"timer": Color("2e86de"),              # 파랑
	"todo": Color("d9b38c"),               # 베이지
	"habit": Color("27ae60"),              # 초록
}
const ICON := {
	"pomodoro_session": "🍅", "timer": "⏲", "todo": "☑", "habit": "✅",
}

var _day: String = ""   # 현재 표시 중인 날짜 iso

func render_day(date_iso: String) -> void:
	_day = date_iso
	day_label.text = DateUtil.format_day(date_iso)
	play_label.text = "⏳ %s" % _fmt_hms(int(Save.activity_log.play_days.get(date_iso, 0.0)))
	for c in list.get_children():
		c.queue_free()
	var entries := _entries_for(date_iso)
	if entries.is_empty():
		var empty := Label.new()
		empty.text = "기록이 없습니다."
		empty.modulate.a = 0.5
		list.add_child(empty)
		return
	for e in entries:
		list.add_child(_make_row(e))

func _entries_for(date_iso: String) -> Array:
	var out := []
	for e in Save.activity_log.events:                       # 로그 이벤트(스트림 → 날짜 프로젝션)
		if DateUtil.local_day_iso(int(e.get("ts", 0))) == date_iso:
			out.append({"ts": int(e.get("ts", 0)), "type": str(e.get("type", "")), "text": _format_event(e)})
	var titles := {}                                          # 파생 습관 (id→title)
	for d in Save.habit_defs:
		titles[int(d["id"])] = str(d.get("title", ""))
	for wk in Save.habit_weeks:
		var ws := str(wk.get("week_start", ""))
		var checks: Dictionary = wk.get("checks", {})
		for k in checks:
			var hid := int(k)
			if not titles.has(hid):
				continue                                      # 정의 없으면(삭제됨) 미표시
			var arr = checks[k]
			for di in 7:
				if di < arr.size() and bool(arr[di]) and DateUtil.add_days(ws, di) == date_iso:
					out.append({"ts": 1 << 62, "type": "habit", "text": titles[hid]})   # 시간 없음 → 맨 뒤
	out.sort_custom(func(a, b): return a["ts"] < b["ts"])     # 시간순, 습관은 끝
	return out

func _format_event(e: Dictionary) -> String:
	match str(e.get("type", "")):
		"todo":
			return "\"%s\" 완료." % str(e.get("title", ""))
		"timer":
			return "%s 타이머." % _fmt_ms(int(e.get("seconds", 0)))
		"pomodoro_session":
			var cnt := int(e.get("focus_count", 0))
			var each := (int(e.get("seconds", 0)) / cnt) if cnt > 0 else 0
			return "%d x %s 세션." % [cnt, _fmt_ms(each)]
	return ""

func _make_row(e: Dictionary) -> Control:
	var type := str(e.get("type", ""))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var bar := ColorRect.new()
	bar.color = ACCENT.get(type, Color.GRAY)
	bar.custom_minimum_size = Vector2(4, 0)
	bar.size_flags_vertical = Control.SIZE_FILL
	row.add_child(bar)
	var icon := Label.new()
	icon.text = ICON.get(type, "•")
	row.add_child(icon)
	var label := Label.new()
	label.text = str(e.get("text", ""))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row

func _fmt_ms(secs: int) -> String:    # M:SS
	return "%d:%02d" % [secs / 60, secs % 60]

func _fmt_hms(total: int) -> String:  # HH:MM:SS
	return "%02d:%02d:%02d" % [total / 3600, (total % 3600) / 60, total % 60]
