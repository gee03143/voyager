extends Node

## 조합 확정 문자의 오배달을 막는다.
##
## Windows에서 조합 중에 마우스 클릭이 들어오면 OS가 조합을 끝내고 확정 문자를 만든다.
## 그 문자는 Godot의 키 버퍼에 적립되고, 버퍼는 메시지 펌프가 끝난 뒤에야 이벤트로 풀린다.
## 클릭은 그 버퍼를 거치지 않고 펌프 도중에 곧바로 나가므로 항상 문자보다 먼저 배달된다.
## 그래서 포커스가 옮겨간 뒤에 문자가 도착해 엉뚱한 칸으로 들어간다.
##
## 대책은 두 단계다.
## - 클릭을 처리하기 전에, 확정 대기 중인 문자를 아직 포커스를 가진 칸에 넣는다
## - 뒤따라 도착하는 문자 이벤트를 그 길이만큼 흡수한다
##
## 흡수는 값을 비교하지 않고 개수로만 센다. IME 후보 변환을 거치면 확정 문자가
## 조합 문자와 달라질 수 있고, 그때 값 비교로 통과시키면 떠돌이 문자가 다시 생긴다.
## 개수 기반이면 최악의 경우에도 변환 전 글자가 남을 뿐 중복은 생기지 않는다.
##
## Tab·Enter로 포커스를 옮길 때는 문자와 키가 같은 버퍼에 순서대로 들어가므로 이 문제가 없다.
##
## 주의: autoload의 `_input`은 입력 그룹을 트리 역순으로 도는 탓에 씬 노드보다 **늦게** 불린다.
## 입력 단계에서 포커스를 직접 푸는 `LineEditAutoBlur`는 `release_focus()` 전에 `flush()`를 부른다.

const DEBUG := false

var _focused: Control = null        # 현재 포커스된 LineEdit/TextEdit
var _composing: String = ""         # 조합 중(미확정) 문자열
var _pending: String = ""           # 조합은 끝났지만 아직 문자 이벤트로 도착하지 않은 확정분
var _pending_frame: int = -1
var _swallow: int = 0               # 되메운 뒤 흡수할 문자 이벤트 개수
var _swallow_frame: int = -1
var _swallow_viewport: Viewport = null
var _hooked: Array[Viewport] = []

func _ready() -> void:
	_hook_tree(get_tree().root)
	get_tree().node_added.connect(_on_node_added)

# ── 포커스 추적 ──────────────────────────────────────────────
# PopupPanel 등 Window는 자기 뷰포트로 포커스 변경을 알린다.
# 루트만 들으면 팝업 안의 입력을 관측하지 못한다.

func _hook_tree(n: Node) -> void:
	if n is Window:
		_hook(n)
	for c in n.get_children():
		_hook_tree(c)

func _on_node_added(n: Node) -> void:
	if n is Window:
		_hook(n)

func _hook(vp: Viewport) -> void:
	for i in range(_hooked.size() - 1, -1, -1):   # 해제된 팝업 Window를 걷어낸다
		if not is_instance_valid(_hooked[i]):
			_hooked.remove_at(i)
	if vp in _hooked:
		return
	_hooked.append(vp)
	vp.gui_focus_changed.connect(_on_gui_focus_changed)

func _on_gui_focus_changed(node: Control) -> void:
	_composing = ""
	if node is LineEdit or node is TextEdit:
		_focused = node
	else:
		_focused = null
	_log("FOCUS_IN %s" % (node.name if node else "<none>"))

# ── 조합 상태 관측 ───────────────────────────────────────────

func _notification(what: int) -> void:
	if what != NOTIFICATION_OS_IME_UPDATE:
		return
	var ime := DisplayServer.ime_get_text()
	if ime != "":
		_composing = ime
		_log("조합 '%s'" % ime)
		return
	if _composing == "":
		return
	# 조합 종료 — 확정분은 키 버퍼에 있고 곧 문자 이벤트로 도착한다.
	_pending = _composing
	_pending_frame = Engine.get_process_frames()
	_composing = ""
	_log("확정 대기 '%s'" % _pending)

# ── 되메우기와 흡수 ──────────────────────────────────────────

func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and key.unicode != 0:
		if _swallow > 0 and Engine.get_process_frames() - _swallow_frame <= 1:
			_swallow -= 1
			_log("흡수 '%s'" % String.chr(key.unicode))
			_consume()
			return
		# 확정 문자가 제대로 도착했다 — 되메울 것이 없다.
		_swallow = 0
		_pending = ""
		return
	if event is InputEventMouseButton and event.pressed:
		flush()

## 확정 대기 중인 문자를 지금 포커스된 칸에 되메운다.
## 입력 단계에서 포커스를 푸는 쪽이 `release_focus()` 직전에 호출한다.
func flush() -> void:
	if _pending == "":
		return
	var text := _pending
	_pending = ""
	if Engine.get_process_frames() - _pending_frame > 1:
		_log("확정 대기 만료 '%s'" % text)
		return
	if _focused == null or not is_instance_valid(_focused):
		return
	if not _focused.has_focus() or not _focused.editable:
		return
	_focused.insert_text_at_caret(text)
	_swallow = text.length()
	_swallow_frame = Engine.get_process_frames()
	_swallow_viewport = _focused.get_viewport()
	_log("되메움 '%s' → %s" % [text, _focused.name])

func _consume() -> void:
	# handled 플래그는 가장 가까운 Window 단위로 보관된다. 되메운 칸과
	# 문자 이벤트가 도착하는 칸이 다른 Window일 수 있어(팝업 개폐) 양쪽에 건다.
	for vp in [_swallow_viewport, _focused.get_viewport() if _focused and is_instance_valid(_focused) else null, get_viewport()]:
		if vp != null and is_instance_valid(vp) and vp.is_inside_tree():
			vp.set_input_as_handled()

func _log(msg: String) -> void:
	if DEBUG:
		print("[IME] f%d %8d %s" % [Engine.get_process_frames(), Time.get_ticks_msec(), msg])
