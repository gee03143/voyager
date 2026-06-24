extends VBoxContainer

@onready var subject_option: OptionButton = $SubjectRow/SubjectOption
@onready var state_option: OptionButton = $StateRow/StateOption
@onready var template_option: OptionButton = $TemplateRow/TemplateOption
@onready var preview: Label = $Preview
@onready var send_button: Button = $SendButton

var _subjects: Array = []   # 오늘 한 활동: [{key, fact}]

func _ready() -> void:
	_populate_states()
	_populate_templates()
	subject_option.item_selected.connect(func(_i): _refresh_preview())
	state_option.item_selected.connect(func(_i): _refresh_preview())
	template_option.item_selected.connect(func(_i): _refresh_preview())
	send_button.pressed.connect(_on_send)
	visibility_changed.connect(func(): if visible: _reload_today())
	_reload_today()

func _reload_today() -> void:
	_subjects = _today_subjects()
	subject_option.clear()
	var has := not _subjects.is_empty()
	subject_option.disabled = not has
	send_button.disabled = not has
	if not has:
		subject_option.add_item("오늘 한 활동 없음")
	else:
		for s in _subjects:
			subject_option.add_item("%s (%s)" % [ActivityVocab.ko(s["key"]), s["fact"]])
	_refresh_preview()

func _today_subjects() -> Array:
	var today := DateUtil.today_iso()
	var secs := {}                                   # subject key → 오늘 집중초 합
	for e in Save.activity_log.events:
		var key := str(e.get("subject", ""))
		if key == "" or DateUtil.local_day_iso(int(e.get("ts", 0))) != today:
			continue
		secs[key] = int(secs.get(key, 0)) + int(e.get("seconds", 0))
	var out := []
	for key in secs:
		out.append({"key": key, "fact": _fmt_duration(int(secs[key]))})
	return out

func _populate_states() -> void:
	state_option.clear()
	for s in StateVocab.STATES:
		state_option.add_item(str(s["ko"]))

func _populate_templates() -> void:
	template_option.clear()
	for i in TelegraphContent.TEMPLATES.size():
		template_option.add_item("형식 %d" % (i + 1))

func _refresh_preview() -> void:
	preview.text = _current_line()

func _current_line() -> String:
	if _subjects.is_empty():
		return ""
	var subj = _subjects[subject_option.selected]
	var state_key := str(StateVocab.STATES[state_option.selected]["key"])
	return TelegraphContent.render(template_option.selected, str(subj["key"]), str(subj["fact"]), state_key)

func _on_send() -> void:
	if _subjects.is_empty():
		return
	var subj = _subjects[subject_option.selected]
	Save.letters.add(                                # 통합 아카이브, author 기본 "" = 내가 보낸 것
		template_option.selected,
		str(subj["key"]),
		str(subj["fact"]),
		str(StateVocab.STATES[state_option.selected]["key"]))
	preview.text = "🍾 띄웠습니다 — %s" % _current_line()

func _fmt_duration(total_secs: int) -> String:
	var h := total_secs / 3600
	var m := (total_secs % 3600) / 60
	if h > 0 and m > 0:
		return "%d시간 %d분" % [h, m]
	if h > 0:
		return "%d시간" % h
	return "%d분" % max(m, 1)
