class_name HoverReveal
extends RefCounted

# host에 마우스가 올라가 있을 때만 controls(버튼 등)를 노출한다.
#   숨김 = modulate.a 0 + mouse_filter IGNORE (클릭이 host로 통과 → 행 선택 등 유지)
#   보임 = modulate.a 1 + mouse_filter STOP   (버튼이 클릭 소비)
# 주의: host가 마우스를 받아야 함(Control 기본 STOP. 컨테이너가 IGNORE면 호출 전 STOP으로).
static func setup(host: Control, controls: Array) -> void:
	_apply(controls, false)
	host.mouse_entered.connect(func(): _apply(controls, true))
	host.mouse_exited.connect(func(): _apply(controls, false))

static func _apply(controls: Array, shown: bool) -> void:
	for c in controls:
		var ctrl := c as Control
		if ctrl == null:
			continue
		ctrl.modulate.a = 1.0 if shown else 0.0
		ctrl.mouse_filter = Control.MOUSE_FILTER_PASS if shown else Control.MOUSE_FILTER_IGNORE
		
