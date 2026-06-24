extends HBoxContainer

const SAVE_DEBOUNCE := 0.5

const DOC_ROW := preload("res://scenes/record/journal/JournalDocRow.tscn")
const GROUP_HEADER := preload("res://scenes/record/journal/JournalGroupHeader.tscn")

@onready var list: VBoxContainer = $Left/Scroll/List
@onready var add_button: Button = $Left/AddButton
@onready var title_edit: LineEdit = $Editor/TitleEdit
@onready var body_edit: TextEdit = $Editor/BodyEdit
@onready var group_option: OptionButton = $Editor/GroupRow/GroupOption
@onready var add_group_button: Button = $Editor/GroupRow/AddGroupButton
@onready var filter_option: OptionButton = $Left/FilterOption

var _save_timer: Timer
var _current_id: int = 0      # 편집 중 문서 id (0=없음)
var _collapsed: Dictionary = {}   # group_id → true (접힘, 비영속 UI 상태)

var _group_dialog: AcceptDialog
var _group_name_edit: LineEdit
var _dialog_group_id: int = 0     # 0 = 새 그룹 / else = 이름변경 대상

var _filter_mode: String = "groups"    # "groups" | "dates" | "one"
var _filter_gid: int = 0               # "one"일 때 대상(0=그룹 없음만)
var _filter_specs: Array = []          # filter_option 인덱스 → spec

func _ready() -> void:
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DEBOUNCE
	add_child(_save_timer)
	_save_timer.timeout.connect(_on_debounce)
	add_button.pressed.connect(_on_add)
	add_group_button.pressed.connect(_on_add_group)
	group_option.item_selected.connect(_on_group_selected)
	filter_option.item_selected.connect(_on_filter_selected)
	title_edit.text_changed.connect(func(_t): _save_timer.start())
	body_edit.text_changed.connect(func(): _save_timer.start())
	visibility_changed.connect(_on_visibility)
	_build_group_dialog()
	_refresh_filter_dropdown()
	_load_editor()
	_rebuild_list()

func _build_group_dialog() -> void:
	_group_dialog = AcceptDialog.new()
	_group_dialog.title = "그룹 이름"
	_group_name_edit = LineEdit.new()
	_group_name_edit.custom_minimum_size.x = 200
	_group_dialog.add_child(_group_name_edit)
	_group_dialog.register_text_enter(_group_name_edit)
	_group_dialog.confirmed.connect(_on_group_dialog_confirmed)
	add_child(_group_dialog)

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
	var has_content := title_edit.text.strip_edges() != "" or body_edit.text.strip_edges() != ""
	if has_content and not _has_journal_event(_current_id):
		Save.activity_log.add("journal", {"doc_id": _current_id})

func _has_journal_event(doc_id: int) -> bool:
	for e in Save.activity_log.events:
		if str(e.get("type", "")) == "journal" and int(e.get("doc_id", 0)) == doc_id:
			return true
	return false

func _load_editor() -> void:
	var d = _find(_current_id)
	_set_editor_enabled(d != null)
	title_edit.text = str(d.get("title", "")) if d != null else ""
	body_edit.text = str(d.get("body", "")) if d != null else ""
	_refresh_group_dropdown()

func _set_editor_enabled(on: bool) -> void:
	title_edit.editable = on
	body_edit.editable = on
	group_option.disabled = not on
	add_group_button.disabled = not on
	
# --- 그룹 드롭다운 ---
func _refresh_group_dropdown() -> void:
	group_option.clear()
	group_option.add_item("그룹 없음", 0)
	for g in Save.journal.groups:
		group_option.add_item(str(g.get("name", "")), int(g.get("id", 0)))
	var cur := _group_of(_current_id)
	for i in group_option.item_count:
		if group_option.get_item_id(i) == cur:
			group_option.select(i)
			break

func _on_group_selected(index: int) -> void:
	if _current_id == 0:
		return
	var gid := group_option.get_item_id(index)
	Save.journal.update_doc(_current_id, title_edit.text, body_edit.text, gid)
	_rebuild_list()
	
# --- 그룹 CRUD (다이얼로그) ---
func _on_add_group() -> void:
	_dialog_group_id = 0
	_group_name_edit.text = ""
	_group_dialog.popup_centered()
	_group_name_edit.grab_focus()

func _on_rename_group(gid: int, current_name: String) -> void:
	_dialog_group_id = gid
	_group_name_edit.text = current_name
	_group_dialog.popup_centered()
	_group_name_edit.grab_focus()

func _on_group_dialog_confirmed() -> void:
	var name := _group_name_edit.text.strip_edges()
	if name == "":
		return
	if _dialog_group_id == 0:
		var gid := Save.journal.add_group(name)
		if _current_id != 0:                       # 새 그룹 = 현재 문서에 바로 적용
			Save.journal.update_doc(_current_id, title_edit.text, body_edit.text, gid)
	else:
		Save.journal.rename_group(_dialog_group_id, name)
	_refresh_filter_dropdown()
	_refresh_group_dropdown()
	_rebuild_list()

# --- 목록 (그룹별 + 접기) ---
func _rebuild_list() -> void:
	for c in list.get_children():
		c.queue_free()
	match _filter_mode:
		"dates":
			_rebuild_by_date()
		"one":
			_add_group_section(_filter_gid, _filter_label(_filter_gid), _docs_for_filter(_filter_gid))
		_:
			_rebuild_by_group()

func _rebuild_by_group() -> void:
	for g in Save.journal.groups:
		var gid := int(g.get("id", 0))
		_add_group_section(gid, str(g.get("name", "")), _docs_in(gid))
	_add_group_section(0, "그룹 없음", _ungrouped_docs())

func _add_group_section(gid: int, name: String, docs_arr: Array) -> void:
	var header := GROUP_HEADER.instantiate()
	list.add_child(header)
	header.setup(gid, name, docs_arr.size(), _collapsed.has(gid))
	header.toggled.connect(_toggle_group)
	header.rename_requested.connect(_on_rename_group)
	header.delete_requested.connect(_on_delete_group)
	if not _collapsed.has(gid):
		for d in docs_arr:
			_add_doc_row(d)

func _toggle_group(gid: int) -> void:
	if _collapsed.has(gid):
		_collapsed.erase(gid)
	else:
		_collapsed[gid] = true
	_rebuild_list()

func _on_delete_group(gid: int) -> void:
	Save.journal.remove_group(gid)
	_refresh_filter_dropdown()
	_refresh_group_dropdown()
	_rebuild_list()

func _refresh_filter_dropdown() -> void:
	filter_option.clear()
	_filter_specs = []
	filter_option.add_item("그룹별");      _filter_specs.append({"mode": "groups"})
	filter_option.add_item("작성일별");    _filter_specs.append({"mode": "dates"})
	for g in Save.journal.groups:
		filter_option.add_item("그룹: %s" % str(g.get("name", "")))
		_filter_specs.append({"mode": "one", "gid": int(g.get("id", 0))})
	filter_option.add_item("그룹 없음만"); _filter_specs.append({"mode": "one", "gid": 0})
	var sel := 0
	for i in _filter_specs.size():
		var s = _filter_specs[i]
		if s["mode"] == _filter_mode and (s["mode"] != "one" or int(s.get("gid", 0)) == _filter_gid):
			sel = i
			break
	if sel == 0 and _filter_mode != "groups":     # 필터 그룹이 삭제됨 → 복귀
		_filter_mode = "groups"
		_filter_gid = 0
	filter_option.select(sel)

func _on_filter_selected(index: int) -> void:
	var s = _filter_specs[index]
	_filter_mode = s["mode"]
	_filter_gid = int(s.get("gid", 0))
	_rebuild_list()

func _rebuild_by_date() -> void:
	var today := []
	var yest := []
	var older := []
	for d in Save.journal.docs:
		var du := DateUtil.days_until(DateUtil.local_day_iso(int(d.get("ts", 0))))
		if du >= 0:
			today.append(d)
		elif du == -1:
			yest.append(d)
		else:
			older.append(d)
	_add_date_section("오늘", today)
	_add_date_section("어제", yest)
	_add_date_section("이전", older)

func _add_date_section(title: String, docs_arr: Array) -> void:
	if docs_arr.is_empty():
		return
	var hdr := Label.new()
	hdr.text = title
	hdr.modulate.a = 0.7
	list.add_child(hdr)
	for d in docs_arr:
		_add_doc_row(d)

func _ungrouped_docs() -> Array:
	var valid := {}
	for g in Save.journal.groups:
		valid[int(g.get("id", 0))] = true
	var out := []
	for d in Save.journal.docs:
		if not valid.has(int(d.get("group_id", 0))):
			out.append(d)
	return out

func _docs_for_filter(gid: int) -> Array:
	return _ungrouped_docs() if gid == 0 else _docs_in(gid)

func _filter_label(gid: int) -> String:
	return "그룹 없음" if gid == 0 else Save.journal.group_name(gid)

func _docs_in(gid: int) -> Array:
	var out := []
	for d in Save.journal.docs:
		if int(d.get("group_id", 0)) == gid:
			out.append(d)
	return out

func _add_doc_row(d: Dictionary) -> void:
	var indent := MarginContainer.new()
	indent.add_theme_constant_override("margin_left", 16)
	var row := DOC_ROW.instantiate()
	indent.add_child(row)
	list.add_child(indent)                          # 트리에 먼저 → @onready 준비
	row.setup(d, int(d.get("id", 0)) == _current_id)
	row.selected.connect(_select)
	row.delete_requested.connect(_on_delete)

func _find(id: int):
	for d in Save.journal.docs:
		if int(d.get("id", 0)) == id:
			return d
	return null

func _group_of(id: int) -> int:
	var d = _find(id)
	return int(d.get("group_id", 0)) if d != null else 0
