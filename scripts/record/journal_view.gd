extends HBoxContainer

const SAVE_DEBOUNCE := 0.5

@onready var list: VBoxContainer = $Left/Scroll/List
@onready var add_button: Button = $Left/AddButton
@onready var title_edit: LineEdit = $Editor/TitleEdit
@onready var body_edit: TextEdit = $Editor/BodyEdit

var _save_timer: Timer
var _current_id: int = 0      # 편집 중 문서 id (0=없음)

func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DEBOUNCE
	add_child(_save_timer)
	_save_timer.timeout.connect(_on_debounce)
	add_button.pressed.connect(_on_add)
	title_edit.text_changed.connect(func(_t): _save_timer.start())
	body_edit.text_changed.connect(func(): _save_timer.start())
	visibility_changed.connect(_on_visibility)
	_load_editor()
	_rebuild_list()

func _on_visibility() -> void:
	if visible:
		_rebuild_list()
	else:
		_commit()                 # 탭 떠날 때 저장

func _on_add() -> void:
	_commit()
	_current_id = Save.journal.add_doc()    # 그룹 없음(0)
	_load_editor()
	_rebuild_list()
	title_edit.grab_focus()

func _on_delete(id: int) -> void:
	Save.journal.remove_doc(id)
	if id == _current_id:
		_current_id = 0
		_load_editor()
	_rebuild_list()

func _select(id: int) -> void:
	if id == _current_id:
		return
	_commit()                     # 이전 문서 저장
	_current_id = id
	_load_editor()
	_rebuild_list()

func _on_debounce() -> void:
	_commit()
	_rebuild_list()               # 제목 변경을 목록에 반영

func _commit() -> void:
	if _current_id == 0 or _find(_current_id) == null:
		return
	Save.journal.update_doc(_current_id, title_edit.text, body_edit.text, _group_of(_current_id))

func _load_editor() -> void:
	var d = _find(_current_id)
	_set_editor_enabled(d != null)
	title_edit.text = str(d.get("title", "")) if d != null else ""
	body_edit.text = str(d.get("body", "")) if d != null else ""

func _set_editor_enabled(on: bool) -> void:
	title_edit.editable = on
	body_edit.editable = on

func _rebuild_list() -> void:
	for c in list.get_children():
		c.queue_free()
	for d in Save.journal.docs:
		list.add_child(_make_row(d))

func _make_row(d: Dictionary) -> Control:
	var id := int(d.get("id", 0))
	var row := PanelContainer.new()
	if id == _current_id:
		var sel := StyleBoxFlat.new()
		sel.bg_color = Color(1, 1, 1, 0.10)
		row.add_theme_stylebox_override("panel", sel)
	var hb := HBoxContainer.new()
	row.add_child(hb)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	var title := str(d.get("title", "")).strip_edges()
	var tl := Label.new()
	tl.text = title if title != "" else "(제목 없음)"
	vb.add_child(tl)
	var dl := Label.new()
	dl.text = "생성됨 %s" % _fmt_date(int(d.get("ts", 0)))
	dl.modulate.a = 0.6
	vb.add_child(dl)
	var del := Button.new()
	del.text = "✕"
	del.pressed.connect(_on_delete.bind(id))
	hb.add_child(del)
	row.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_select(id))
	return row

func _find(id: int):
	for d in Save.journal.docs:
		if int(d.get("id", 0)) == id:
			return d
	return null

func _group_of(id: int) -> int:
	var d = _find(id)
	return int(d.get("group_id", 0)) if d != null else 0

func _fmt_date(ts: int) -> String:                        # D/M/YYYY (이미지 형식)
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var d := Time.get_datetime_dict_from_unix_time(ts + bias * 60)
	return "%d/%d/%d" % [d.day, d.month, d.year]
