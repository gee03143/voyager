extends VBoxContainer

## 설정 패널(docs/specs/settings.md). 일반 탭과 헤이즐 탭.
## 헤이즐의 목소리가 아니라 중립 UI 언어다(docs/companion-persona.md §5 "목소리의 경계").
## 화면은 코드로 만든다. 값은 바뀔 때마다 AppSettings 에 넣고 changed 로 저장한다(전역 설정 = save-on-change).

const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
const SOUND_SETS := 2                  # Sound.play_set 이 아는 세트 수
const NICK_MAX := 12                   # 온보딩의 호칭 칸과 같다(dialogue_mode.ask_name)
const LABEL_W := 180.0
const SLIDER_W := 220.0
## 달마다 마지막 날. 2월은 29일까지 받는다 — 연도가 없으니 윤년을 가리지 않는다
const MONTH_DAYS := [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

var _tabs: TabNavSlot
var _pages: Array[Control] = []

var _size_option: OptionButton
var _volume: HSlider
var _sound_set: OptionButton
var _nickname: LineEdit
var _voice: HSlider
var _month: OptionButton
var _day: OptionButton


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	_tabs = TabNavSlot.new()
	add_child(_tabs)
	_pages = [_build_general(), _build_hazel()]
	for p in _pages:
		add_child(p)
	_tabs.tab_selected.connect(_on_tab)
	var labels: Array[String] = ["SETTINGS_TAB_GENERAL", "SETTINGS_TAB_HAZEL"]
	_tabs.set_tabs(labels)
	_sync()


func on_shown() -> void:
	_sync()


func _on_tab(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = (i == index)


## 저장된 값으로 화면을 맞춘다. 신호를 쏘지 않는 쪽으로만 바꾼다
func _sync() -> void:
	var s := Save.settings
	_size_option.select(RESOLUTIONS.find(s.window_size))   # 목록에 없으면 -1(선택 없음)
	_volume.set_value_no_signal(s.master_volume)
	_sound_set.select(clampi(s.sound_set, 0, SOUND_SETS - 1))
	_nickname.text = s.nickname
	_voice.set_value_no_signal(s.companion_voice_volume)
	var m := 0
	var d := 0
	var p := s.birthday.split("-")
	if p.size() == 2 and p[0].is_valid_int() and p[1].is_valid_int():
		m = clampi(int(p[0]), 0, 12)
		d = clampi(int(p[1]), 0, 31)
	_month.select(m)
	_fill_days(m)
	_day.select(mini(d, _day.item_count - 1))


# ── 일반 ──

func _build_general() -> Control:
	var page := _page()
	_size_option = OptionButton.new()
	for r in RESOLUTIONS:
		_size_option.add_item("%d × %d" % [r.x, r.y])
	_size_option.item_selected.connect(_on_size)
	_row(page, "SETTINGS_WINDOW_SIZE", _size_option)

	_volume = _slider()
	_volume.value_changed.connect(_on_volume)
	_volume.drag_ended.connect(_commit_on_drag)
	_row(page, "SETTINGS_VOLUME", _volume)

	var sound_box := HBoxContainer.new()
	_sound_set = OptionButton.new()
	for i in SOUND_SETS:
		_sound_set.add_item(tr("SETTINGS_SOUND_SET").format({"n": i + 1}))
	_sound_set.item_selected.connect(_on_sound_set)
	sound_box.add_child(_sound_set)
	var preview := Button.new()
	preview.text = "▶"
	preview.pressed.connect(func() -> void: Sound.play_set(_sound_set.selected))
	sound_box.add_child(preview)
	_row(page, "SETTINGS_ALARM_SOUND", sound_box)

	var quit := Button.new()
	quit.text = tr("SETTINGS_QUIT")
	quit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	quit.pressed.connect(Save.quit_game)       # 밀린 쓰기까지 저장하고 끝낸다
	page.add_child(_spacer())
	page.add_child(quit)
	return page


func _on_size(idx: int) -> void:
	Save.settings.window_size = RESOLUTIONS[idx]
	Screen.apply_window_size()
	Save.settings.changed.emit()


func _on_volume(v: float) -> void:
	Save.settings.master_volume = v
	Sound.set_master_volume(v)                  # 끄는 동안 바로 들린다. 저장은 놓을 때


func _on_sound_set(idx: int) -> void:
	Save.settings.sound_set = idx
	Save.settings.changed.emit()


func _commit_on_drag(_changed: bool) -> void:
	Save.settings.changed.emit()


# ── 헤이즐 ──

func _build_hazel() -> Control:
	var page := _page()
	_nickname = LineEdit.new()
	_nickname.max_length = NICK_MAX
	_nickname.placeholder_text = tr("SETTINGS_NICKNAME_EMPTY")
	_nickname.custom_minimum_size.x = SLIDER_W
	_nickname.text_submitted.connect(func(_t: String) -> void: _nickname.release_focus())
	_nickname.focus_exited.connect(_commit_nickname)   # 엔터든 바깥 클릭이든 포커스가 풀릴 때 저장한다
	var blur := LineEditAutoBlur.new()
	blur.target = _nickname
	_nickname.add_child(blur)
	_row(page, "SETTINGS_NICKNAME", _nickname)

	_voice = _slider()
	_voice.value_changed.connect(_on_voice)
	_voice.drag_ended.connect(_commit_on_drag)
	_row(page, "SETTINGS_VOICE_VOLUME", _voice)

	var bday := HBoxContainer.new()
	_month = OptionButton.new()
	_month.add_item(tr("SETTINGS_BIRTHDAY_NONE"))
	for m in range(1, 13):
		_month.add_item(tr("SETTINGS_BIRTHDAY_MONTH").format({"m": m}))
	_month.item_selected.connect(_on_month)
	bday.add_child(_month)
	_day = OptionButton.new()
	_day.item_selected.connect(func(_i: int) -> void: _commit_birthday())
	bday.add_child(_day)
	_row(page, "SETTINGS_BIRTHDAY", bday)
	return page


func _commit_nickname() -> void:
	var t := _nickname.text.strip_edges()
	_nickname.text = t
	if t == Save.settings.nickname:
		return
	Save.settings.nickname = t
	Save.settings.changed.emit()


func _on_voice(v: float) -> void:
	Save.settings.companion_voice_volume = v
	Sound.set_voice_volume(v)


## 달을 바꾸면 그 달에 없는 날은 마지막 날로 당긴다
func _on_month(m: int) -> void:
	var keep := _day.selected
	_fill_days(m)
	_day.select(mini(keep, _day.item_count - 1))
	_commit_birthday()


## 0번은 비어 있음이다. 달이 비어 있으면 날도 고를 수 없다
func _fill_days(m: int) -> void:
	_day.clear()
	_day.add_item(tr("SETTINGS_BIRTHDAY_NONE"))
	if m <= 0:
		_day.disabled = true
		return
	_day.disabled = false
	for d in range(1, MONTH_DAYS[m - 1] + 1):
		_day.add_item(tr("SETTINGS_BIRTHDAY_DAY").format({"d": d}))


## 달과 날이 둘 다 있어야 생일이다. 하나라도 비면 없음
func _commit_birthday() -> void:
	var m := _month.selected
	var d := _day.selected
	var v := "%02d-%02d" % [m, d] if m > 0 and d > 0 else ""
	if v == Save.settings.birthday:
		return
	Save.settings.birthday = v
	Save.settings.changed.emit()


# ── 만들기 ──

func _page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return page


func _row(page: VBoxContainer, label_key: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = tr(label_key)
	l.custom_minimum_size.x = LABEL_W
	row.add_child(l)
	row.add_child(control)
	page.add_child(row)


func _slider() -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.01
	s.custom_minimum_size.x = SLIDER_W
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return s


func _spacer() -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = 12
	return c
