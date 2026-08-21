extends Node

var _pending_text: String = ""
var _bound_control: Control = null
var _bound_callable: Callable = Callable()

func _ready() -> void:
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_OS_IME_UPDATE:
		var text := DisplayServer.ime_get_text()
		if text != "":
			_pending_text = text
			print("[ImeFocusGuard] pending_text 갱신: '%s'" % _pending_text)

func _on_gui_focus_changed(node: Control) -> void:
	if _bound_control and is_instance_valid(_bound_control) and _bound_callable.is_valid():
		if _bound_control.focus_exited.is_connected(_bound_callable):
			_bound_control.focus_exited.disconnect(_bound_callable)
	_bound_control = null
	_bound_callable = Callable()
	if node and (node is LineEdit or node is TextEdit):
		_bound_callable = _on_focus_exited.bind(node)
		node.focus_exited.connect(_bound_callable)
		_bound_control = node
		print("[ImeFocusGuard] 새 포커스 — %s에 바인딩" % node.name)

func _on_focus_exited(target: Control) -> void:
	print("[ImeFocusGuard] focus_exited — target: %s, pending_text: '%s'" % [target, _pending_text])
	if target:
		target.cancel_ime()
		if _pending_text != "":
			target.insert_text_at_caret(_pending_text)
			_pending_text = ""
