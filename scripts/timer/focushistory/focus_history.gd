class_name FocusHistory
extends PanelContainer

const ROW_SCENE := preload("res://scenes/timer/FocusHistoryRow.tscn")
const SESSION_TYPES := {"pomodoro_session": true, "timer": true}

@onready var summary_label: Label = $Margin/VBox/Header/Summary
@onready var empty_label: Label = $Margin/VBox/EmptyLabel
@onready var list: VBoxContainer = $Margin/VBox/Scroll/List

var _editing := false                    # 편집 중엔 재빌드 보류 — 입력 중인 노드가 파괴되지 않게
var _dirty := false

func _ready() -> void:
	Save.activity_log.changed.connect(_on_activity_changed)
	refresh()

func refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	var day := DateUtil.today_iso()
	var rows := []
	var total := 0
	for e in Save.activity_entries_for(day):
		if not SESSION_TYPES.has(str(e.get("type", ""))):
			continue
		var start_ts := ActivityFormat.start_ts_of(e)
		if start_ts == 0:
			continue
		total += int(e.get("seconds", 0))
		rows.append({
			"id": int(e.get("id", 0)),
			"span": ActivityFormat.span_text(start_ts, int(e.get("ts", 0)), day),
			"label": ActivityFormat.session_label(e),
			"note": Save.activity_log.note_of(int(e.get("id", 0))),
			"accent": ActivityFormat.accent_of(str(e.get("type", ""))),
		})
	rows.reverse()                       # activity_entries_for는 시각 오름차순 — 최근 것을 위로
	summary_label.text = TranslationServer.translate("TIMER_HISTORY_SUMMARY").format({
		"n": rows.size(), "time": DateUtil.format_hm(total)})
	empty_label.visible = rows.is_empty()
	for d in rows:
		var row := ROW_SCENE.instantiate() as FocusHistoryRow
		list.add_child(row)              # setup 전에 트리에 넣어야 @onready가 채워짐
		row.setup(d)
		row.note_committed.connect(_on_note_committed)
		row.edit.focus_entered.connect(func(): _editing = true)

func _on_note_committed(event_id: int, text: String) -> void:
	_editing = false
	Save.activity_log.set_note(event_id, text)   # changed → _on_activity_changed
	if _dirty:
		_dirty = false
		refresh()

func _on_activity_changed() -> void:
	if _editing:
		_dirty = true                    # 입력 중이면 미뤘다가 편집 끝나고 한 번에
		return
	refresh()
