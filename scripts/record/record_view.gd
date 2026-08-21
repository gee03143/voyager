extends VBoxContainer

const LOG_ROW := preload("res://scenes/record/RecordLogRow.tscn")

@onready var day_label: Label = $Header/DayLabel
@onready var play_label: Label = $Header/PlayLabel
@onready var list: VBoxContainer = $ScrollContainer/List

const ACCENT := {
	"pomodoro_session": Color("c0392b"),   # 빨강
	"timer": Color("2e86de"),              # 파랑
	"todo": Color("d9b38c"),               # 베이지
	"habit": Color("27ae60"),              # 초록
	"journal": Color("9575cd"),            # 보라
	"gratitude": Color("f6b93b"),
	"mood": Color("38ada9"),
}

const TYPE_LABEL_KEY := {
	"pomodoro_session": "RECORD_TYPE_POMO",
	"timer": "RECORD_TYPE_TIMER",
	"todo": "RECORD_TYPE_TODO",
	"habit": "RECORD_TYPE_HABIT",
	"journal": "RECORD_TYPE_JOURNAL",
	"gratitude": "RECORD_TYPE_GRATITUDE",
	"mood": "RECORD_TYPE_MOOD",
}

const MOOD_LEVEL_KEYS := ["MOOD_LEVEL_1", "MOOD_LEVEL_2", "MOOD_LEVEL_3", "MOOD_LEVEL_4", "MOOD_LEVEL_5"]

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
		empty.text = TranslationServer.translate("RECORD_EMPTY")
		empty.modulate.a = 0.5
		list.add_child(empty)
		return
	for e in entries:
		_make_row(e)

func _entries_for(date_iso: String) -> Array:
	var out := []
	for e in Save.activity_entries_for(date_iso):
		out.append({"ts": int(e.get("ts", 0)), "type": str(e.get("type", "")), "text": _format_event(e)})
	return out

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
		"habit":
			return str(e.get("title", ""))
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

func _make_row(e: Dictionary) -> void:
	var type := str(e.get("type", ""))
	var row := LOG_ROW.instantiate() as RecordLogRow
	list.add_child(row)
	row.setup(TYPE_LABEL_KEY.get(type, ""), ACCENT.get(type, Color.GRAY), str(e.get("text", "")))
	
func _subj(e: Dictionary) -> String:
	var key := str(e.get("subject", ""))
	return "%s · " % ActivityVocab.ko(key) if key != "" else ""

func _fmt_ms(secs: int) -> String:    # M:SS
	return "%d:%02d" % [secs / 60, secs % 60]

func _fmt_hms(total: int) -> String:  # HH:MM:SS
	return "%02d:%02d:%02d" % [total / 3600, (total % 3600) / 60, total % 60]
