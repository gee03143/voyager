extends HBoxContainer

const SAVE_DEBOUNCE := 0.5

# 행 하나가 아니라 섹션 전체가 움직이므로 행 하나짜리보다 조금 길다.
# 접기는 시야에서 치우려는 조작이라 더 짧다. F6에서 맞출 값.
const GROUP_OPEN_SEC := 0.18
const GROUP_CLOSE_SEC := 0.11

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

# 목록 노드는 파괴하지 않고 키로 찾아 재사용한다. 값은 전부 `list`에 직접 들어가는 노드다.
var _doc_wraps: Dictionary = {}       # 문서 id → 들여쓰기 래퍼(안에 JournalDocRow 하나)
var _group_headers: Dictionary = {}   # 그룹 id → JournalGroupHeader
var _date_headers: Dictionary = {}    # 날짜 제목 → Label

# 연출은 조작에 응답한다. 목록이 다른 이유로 다시 그려질 때는 행이 그냥 나타나고 사라진다.
var _entering: Dictionary = {}        # 문서 id → 펼치는 데 쓸 시간
var _exiting: Array = []              # [{node, index}] 접히는 중이라 아직 목록에 남아 있는 래퍼

var _group_dialog: AcceptDialog
var _group_name_edit: LineEdit
var _dialog_group_id: int = 0     # 0 = 새 그룹 / else = 이름변경 대상

var _filter_mode: String = "groups"    # "groups" | "dates" | "one"
var _filter_gid: int = 0               # "one"일 때 대상(0=그룹 없음만)
var _filter_specs: Array = []          # filter_option 인덱스 → spec

var _group_ids: Array = []             # group_option 인덱스 → 실제 group_id (OptionButton id는 32비트라 randi id를 못 담음)

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
	title_edit.text_changed.connect(func(_t): _touch())
	body_edit.text_changed.connect(_touch)
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

# 이 신호는 래퍼로 옮겨지는 도중(reparent)에도 터진다. 그때는 트리 진입 전파가 끝나기 전이라
# 새로 붙인 행의 _ready가 아직 안 돌아 @onready가 비어 있다.
func _on_visibility() -> void:
	if not is_inside_tree():
		return
	if is_visible_in_tree():
		_rebuild_list()
	else:
		_commit()                 # 탭 떠날 때 저장

func _on_add() -> void:
	_commit()
	_current_id = Save.journal.add_doc()    # 그룹 없음(0)
	_entering[_current_id] = JournalDocRow.ENTER_SEC
	_load_editor()
	_rebuild_list()
	title_edit.grab_focus()

func _on_delete(id: int) -> void:
	var wrap: MarginContainer = _doc_wraps.get(id)
	Save.journal.remove_doc(id)
	if id == _current_id:
		_current_id = 0
		_load_editor()
	if wrap != null and is_visible_in_tree():
		_hold_exit(id, wrap, JournalDocRow.EXIT_SEC)   # 노드를 남겨 제자리에서 접히게 한다
	_rebuild_list()

# 지워진 문서의 행은 목록 계획에서 빠지지만 노드는 접히는 동안 자리를 지킨다.
func _hold_exit(id: int, wrap: MarginContainer, sec: float) -> void:
	_doc_wraps.erase(id)
	var entry := {"id": id, "node": wrap, "index": wrap.get_index()}
	_exiting.append(entry)
	(wrap.get_child(0) as JournalDocRow).play_exit(func(): _finish_exit(entry), sec)

# 접히던 중에 같은 문서가 다시 나타나야 하면 접힘을 버리고 즉시 치운다.
func _cancel_exit(id: int) -> void:
	for e in _exiting:
		if int(e["id"]) == id:
			_finish_exit(e)
			return

func _finish_exit(entry: Dictionary) -> void:
	_exiting.erase(entry)
	var node: Node = entry["node"]
	if node.is_queued_for_deletion():
		return
	if node.get_parent() == list:
		list.remove_child(node)
	node.queue_free()

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

# 타이핑마다 불린다. 모델은 즉시 맞추고 무거운 목록 갱신만 미룬다.
# 모델을 미루면 디바운스가 터지기 전에 창을 닫을 때 그동안 쓴 것이 통째로 사라진다.
func _touch() -> void:
	_commit_text()
	_save_timer.start()

func _commit() -> void:
	if not _commit_text():
		return
	var has_content := title_edit.text.strip_edges() != "" or body_edit.text.strip_edges() != ""
	if has_content and not _has_journal_event(_current_id):
		Save.activity_log.add("journal", {"doc_id": _current_id})

## 모델의 제목·본문만 맞춘다. 활동 이벤트 판정은 이벤트 전체를 훑어 비싸므로 여기서 안 한다.
func _commit_text() -> bool:
	if _current_id == 0 or _find(_current_id) == null:
		return false
	Save.journal.update_doc(_current_id, title_edit.text, body_edit.text, _group_of(_current_id))
	return true

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
	_group_ids = [0]
	group_option.add_item("그룹 없음")
	for g in Save.journal.groups:
		group_option.add_item(str(g.get("name", "")))
		_group_ids.append(int(g.get("id", 0)))
	var cur := _group_of(_current_id)
	for i in _group_ids.size():
		if _group_ids[i] == cur:
			group_option.select(i)
			break

func _on_group_selected(index: int) -> void:
	if _current_id == 0:
		return
	var gid = _group_ids[index]
	Save.journal.update_doc(_current_id, title_edit.text, body_edit.text, gid)
	_rebuild_list()
	
# --- 그룹 CRUD (다이얼로그) ---
func _on_add_group() -> void:
	_dialog_group_id = 0
	_group_name_edit.text = ""
	_group_dialog.popup_centered()
	_group_name_edit.grab_focus()
	_group_name_edit.select_all()

func _on_rename_group(gid: int, current_name: String) -> void:
	_dialog_group_id = gid
	_group_name_edit.text = current_name
	_group_dialog.popup_centered()
	_group_name_edit.grab_focus()
	_group_name_edit.select_all()

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
# 목록을 다시 그릴 때 노드를 파괴하지 않는다. 문서 id·그룹 id·날짜 제목으로 키를 잡아
# 재사용하고 순서만 다시 잡는다. 파괴하면 움직여야 할 행이 같은 프레임에 사라져
# 연출을 걸 자리가 없고, 헤더가 다시 만들어지면 접기 조작 중에 호버 상태가 리셋된다.
func _rebuild_list() -> void:
	var plan := _list_plan()
	var used_docs := {}
	var used_groups := {}
	var used_dates := {}
	for i in plan.size():
		var e: Dictionary = plan[i]
		var node: Control
		match str(e["kind"]):
			"group":
				node = _sync_group_header(int(e["gid"]), str(e["name"]), int(e["count"]), e["collapsed"])
				used_groups[int(e["gid"])] = true
			"date":
				node = _sync_date_header(str(e["title"]))
				used_dates[str(e["title"])] = true
			_:
				var d: Dictionary = e["doc"]
				node = _sync_doc_row(d)
				used_docs[int(d.get("id", 0))] = true
		list.move_child(node, i)         # 앞자리는 이미 확정됐다. 남은 것들은 뒤로 밀린다
	_drop_unused(_group_headers, used_groups)
	_drop_unused(_date_headers, used_dates)
	_drop_unused(_doc_wraps, used_docs)
	for e in _exiting:                   # 접히는 중인 행은 원래 자리에서 접혀야 한다
		list.move_child(e["node"], mini(int(e["index"]), list.get_child_count() - 1))

# 무엇이 어떤 순서로 놓일지만 정한다. 노드는 만들지 않는다.
func _list_plan() -> Array:
	match _filter_mode:
		"dates":
			return _plan_by_date()
		"one":
			return _plan_group_section(_filter_gid, _filter_label(_filter_gid), _docs_for_filter(_filter_gid))
		_:
			return _plan_by_group()

func _plan_by_group() -> Array:
	var plan := []
	for g in Save.journal.groups:
		var gid := int(g.get("id", 0))
		plan.append_array(_plan_group_section(gid, str(g.get("name", "")), _docs_in(gid)))
	plan.append_array(_plan_group_section(0, "그룹 없음", _ungrouped_docs()))
	return plan

func _plan_group_section(gid: int, name: String, docs_arr: Array) -> Array:
	var collapsed := _collapsed.has(gid)
	var plan := [{"kind": "group", "gid": gid, "name": name, "count": docs_arr.size(), "collapsed": collapsed}]
	if not collapsed:
		for d in docs_arr:
			plan.append({"kind": "doc", "doc": d})
	return plan

func _plan_by_date() -> Array:
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
	var plan := []
	plan.append_array(_plan_date_section("오늘", today))
	plan.append_array(_plan_date_section("어제", yest))
	plan.append_array(_plan_date_section("이전", older))
	return plan

func _plan_date_section(title: String, docs_arr: Array) -> Array:
	if docs_arr.is_empty():
		return []
	var plan := [{"kind": "date", "title": title}]
	for d in docs_arr:
		plan.append({"kind": "doc", "doc": d})
	return plan

# 시그널은 만들 때 한 번만 묶는다. 키가 곧 대상 id라 재사용해도 대상이 바뀌지 않는다.
func _sync_group_header(gid: int, name: String, count: int, collapsed: bool) -> Control:
	var header: JournalGroupHeader = _group_headers.get(gid)
	if header == null:
		header = GROUP_HEADER.instantiate()
		list.add_child(header)
		header.toggled.connect(_toggle_group)
		header.rename_requested.connect(_on_rename_group)
		header.delete_requested.connect(_on_delete_group)
		_group_headers[gid] = header
	header.setup(gid, name, count, collapsed)
	return header

func _sync_date_header(title: String) -> Control:
	var hdr: Label = _date_headers.get(title)
	if hdr == null:
		hdr = Label.new()
		hdr.text = title
		hdr.modulate.a = 0.7
		list.add_child(hdr)
		_date_headers[title] = hdr
	return hdr

func _sync_doc_row(d: Dictionary) -> Control:
	var id := int(d.get("id", 0))
	var wrap: MarginContainer = _doc_wraps.get(id)
	if wrap == null:
		wrap = MarginContainer.new()
		wrap.add_theme_constant_override("margin_left", 16)
		var row := DOC_ROW.instantiate()
		wrap.add_child(row)
		list.add_child(wrap)                        # 트리에 먼저 → @onready 준비
		row.selected.connect(_select)
		row.delete_requested.connect(_on_delete)
		_doc_wraps[id] = wrap
	var row := wrap.get_child(0) as JournalDocRow
	row.setup(d, id == _current_id)
	if _entering.has(id):
		var sec: float = _entering[id]
		_entering.erase(id)
		if is_visible_in_tree():
			row.play_enter(sec)
	return wrap

func _drop_unused(map: Dictionary, used: Dictionary) -> void:
	for key in map.keys():
		if used.has(key):
			continue
		var node: Node = map[key]
		list.remove_child(node)     # queue_free만 하면 이번 프레임 안의 다음 갱신까지 자식으로 남는다
		node.queue_free()
		map.erase(key)

# 섹션 안의 행들이 각자 자기 높이를 동시에 접고 편다. 순서를 어긋내지 않는다 —
# 문서가 많은 그룹에서 조작 하나에 대한 응답이 늘어지면 방해가 된다.
func _toggle_group(gid: int) -> void:
	var docs_arr := _docs_for_filter(gid)
	if _collapsed.has(gid):
		_collapsed.erase(gid)
		for d in docs_arr:
			var id := int(d.get("id", 0))
			_cancel_exit(id)                  # 접히다 만 행이 남아 있으면 겹친다
			_entering[id] = GROUP_OPEN_SEC
	else:
		_collapsed[gid] = true
		if is_visible_in_tree():
			for d in docs_arr:
				var id := int(d.get("id", 0))
				var wrap: MarginContainer = _doc_wraps.get(id)
				if wrap != null:
					_hold_exit(id, wrap, GROUP_CLOSE_SEC)
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

func _find(id: int):
	for d in Save.journal.docs:
		if int(d.get("id", 0)) == id:
			return d
	return null

func _group_of(id: int) -> int:
	var d = _find(id)
	return int(d.get("group_id", 0)) if d != null else 0
